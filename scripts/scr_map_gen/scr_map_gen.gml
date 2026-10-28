// ============================================================
// scr_map_gen: deterministic world generation
// Everything here uses a seeded hash (never random()), so every
// player in a multiplayer game generates the exact same map from the seed.
// ============================================================

function hash_2d(_x, _y, _seed) {
	var _h = (_x * 374761393 + _y * 668265263 + _seed * 144665) & $7FFFFFFF;
	_h = (_h >> 13) ^ _h;
	_h = (_h * 1274126177) & $7FFFFFFF;
	_h = (_h >> 16) ^ _h;
	return (_h & $FFFF) / 65535;
}

function value_noise(_x, _y, _seed) {
	var _ix = floor(_x);
	var _iy = floor(_y);
	var _fx = _x - _ix;
	var _fy = _y - _iy;
	// Smoothstep
	_fx = _fx * _fx * (3 - 2 * _fx);
	_fy = _fy * _fy * (3 - 2 * _fy);
	var _a = hash_2d(_ix, _iy, _seed);
	var _b = hash_2d(_ix + 1, _iy, _seed);
	var _c = hash_2d(_ix, _iy + 1, _seed);
	var _d = hash_2d(_ix + 1, _iy + 1, _seed);
	return lerp(lerp(_a, _b, _fx), lerp(_c, _d, _fx), _fy);
}

function fractal_noise(_x, _y, _seed, _octaves) {
	var _total = 0;
	var _sum = 0;
	var _amp = 1;
	var _freq = 1;
	for (var _i = 0; _i < _octaves; _i++) {
		_total += value_noise(_x * _freq, _y * _freq, _seed + _i * 101) * _amp;
		_sum += _amp;
		_amp *= 0.5;
		_freq *= 2;
	}
	return _total / _sum;
}

// ------------------------------------------------------------
// World creation
// ------------------------------------------------------------

// _settings: nationCount, botCount, vacantCount, mapPreset, mapWidth, mapHeight, seed
function create_world(_settings) {
	var _w = _settings.mapWidth;
	var _h = _settings.mapHeight;
	var _world = {
		mapW: _w,
		mapH: _h,
		seed: _settings.seed,
		preset: global.mapPresets[_settings.mapPreset],
		settings: _settings,
		biome: ds_grid_create(_w, _h),
		resource: ds_grid_create(_w, _h),
		habitable: ds_grid_create(_w, _h),
		borderOwner: ds_grid_create(_w, _h),
		borderDist: ds_grid_create(_w, _h),
		cityGrid: ds_grid_create(_w, _h),
		unitGrid: ds_grid_create(_w, _h),
		ghostGrid: ds_grid_create(_w, _h),
		buildingGrid: ds_grid_create(_w, _h),
		// Walls and gates live on tile edges. edgeGridX holds the edge between (x, y) and (x + 1, y).
		// edgeGridY holds the edge between (x, y) and (x, y + 1).
		edgeGridX: ds_grid_create(_w, _h),
		edgeGridY: ds_grid_create(_w, _h),
		pathGrid: ds_grid_create(_w, _h),
		pathLinks: [],
		battles: [],
		rngState: max(1, ((_settings.seed * 2654435) + 987654321) & $7FFFFFFF),
		combatTime: array_create(MAX_NATIONS, -9999),
		audioEvents: [],
		pathTotal: 0,
		// Scratch grids for the pathfinder
		pfCost: ds_grid_create(_w, _h),
		pfParent: ds_grid_create(_w, _h),
		pfClosed: ds_grid_create(_w, _h),
		units: [],
		cities: [],
		buildings: [],
		nationStates: [],
		treaties: [],
		offers: [],
		notices: [],
		localNation: NO_ID,
		winner: NO_ID,
		time: 0,
		statsTimer: 0,
		treatyTimer: 0
	};
	ds_grid_clear(_world.resource, RES.NONE);
	ds_grid_clear(_world.habitable, 0);
	ds_grid_clear(_world.borderOwner, NO_ID);
	ds_grid_clear(_world.borderDist, 999);
	ds_grid_clear(_world.cityGrid, NO_ID);
	ds_grid_clear(_world.unitGrid, NO_ID);
	ds_grid_clear(_world.ghostGrid, NO_ID);
	ds_grid_clear(_world.buildingGrid, NO_ID);
	ds_grid_clear(_world.edgeGridX, NO_ID);
	ds_grid_clear(_world.edgeGridY, NO_ID);
	ds_grid_clear(_world.pathGrid, NO_ID);

	generate_terrain(_world);
	place_habitable_tiles(_world, _settings.nationCount + 6);
	generate_resources(_world);
	setup_nations(_world);
	// Bandit camps can be switched off from the Play screen (the menu demo has no setting, so it keeps them)
	if (!variable_struct_exists(_settings, "bandits") || _settings.bandits) {
		place_tribe_camps(_world);
	}
	recalculate_borders(_world);
	update_nation_stats(_world);
	return _world;
}

function destroy_world(_world) {
	ds_grid_destroy(_world.biome);
	ds_grid_destroy(_world.resource);
	ds_grid_destroy(_world.habitable);
	ds_grid_destroy(_world.borderOwner);
	ds_grid_destroy(_world.borderDist);
	ds_grid_destroy(_world.cityGrid);
	ds_grid_destroy(_world.unitGrid);
	ds_grid_destroy(_world.buildingGrid);
	ds_grid_destroy(_world.edgeGridX);
	ds_grid_destroy(_world.edgeGridY);
	ds_grid_destroy(_world.pfCost);
	ds_grid_destroy(_world.pfParent);
	ds_grid_destroy(_world.pfClosed);
	ds_grid_destroy(_world.pathGrid);
	ds_grid_destroy(_world.ghostGrid);
}

function generate_terrain(_world) {
	var _p = _world.preset;
	var _seed = _world.seed;
	for (var _gx = 0; _gx < _world.mapW; _gx++) {
		for (var _gy = 0; _gy < _world.mapH; _gy++) {
			var _height = fractal_noise(_gx * _p.scale, _gy * _p.scale, _seed, 4);

			// Sink the edges of the map into the sea
			var _nx = (_gx / _world.mapW) * 2 - 1;
			var _ny = (_gy / _world.mapH) * 2 - 1;
			var _edge = max(abs(_nx), abs(_ny));
			_height -= _p.falloff * _edge * _edge * 0.8;

			var _biome;
			if (_height < _p.waterLevel) {
				_biome = BIOME.WATER;
			} else if (_height > _p.mountainLevel) {
				_biome = BIOME.MOUNTAIN;
			} else {
				var _temp = fractal_noise(_gx * _p.scale * 0.6, _gy * _p.scale * 0.6, _seed + 500, 3) + _p.tempOffset;
				var _moist = fractal_noise(_gx * _p.scale * 0.6, _gy * _p.scale * 0.6, _seed + 900, 3) + _p.moistOffset;
				if (_temp < 0.4) {
					_biome = BIOME.SNOW;
				} else if ((_temp > 0.6) && (_moist < 0.5)) {
					_biome = BIOME.DESERT;
				} else if (_moist > 0.55) {
					_biome = BIOME.FOREST;
				} else {
					_biome = BIOME.GRASSLAND;
				}
			}
			ds_grid_set(_world.biome, _gx, _gy, _biome);
		}
	}
}

// Stone and ore tiles. They are common near mountains and rare everywhere else.
function generate_resources(_world) {
	for (var _gx = 0; _gx < _world.mapW; _gx++) {
		for (var _gy = 0; _gy < _world.mapH; _gy++) {
			if (!tile_is_walkable(_world, _gx, _gy)) {
				continue;
			}
			// Habitable tiles are kept clear so a city can always be founded there
			if (ds_grid_get(_world.habitable, _gx, _gy) == 1) {
				continue;
			}
			var _nearMountain = false;
			for (var _ox = -2; _ox <= 2; _ox++) {
				for (var _oy = -2; _oy <= 2; _oy++) {
					if (tile_in_bounds(_world, _gx + _ox, _gy + _oy) && (ds_grid_get(_world.biome, _gx + _ox, _gy + _oy) == BIOME.MOUNTAIN)) {
						_nearMountain = true;
					}
				}
			}
			var _stoneChance = _nearMountain ? 0.16 : 0.02;
			var _oreChance = _nearMountain ? 0.09 : 0.012;
			var _r = hash_2d(_gx, _gy, _world.seed + 101);
			if (_r < _stoneChance) {
				ds_grid_set(_world.resource, _gx, _gy, RES.STONE);
			} else if (_r > 1 - _oreChance) {
				ds_grid_set(_world.resource, _gx, _gy, RES.ORE);
			} else if ((ds_grid_get(_world.biome, _gx, _gy) == BIOME.FOREST) && (hash_2d(_gx, _gy, _world.seed + 202) < 0.12)) {
				// Trees only grow in forests, and only on some of the tiles
				ds_grid_set(_world.resource, _gx, _gy, RES.TREES);
			}
		}
	}
}

function tile_in_bounds(_world, _gx, _gy) {
	return (_gx >= 0) && (_gy >= 0) && (_gx < _world.mapW) && (_gy < _world.mapH);
}

function tile_is_walkable(_world, _gx, _gy) {
	if (!tile_in_bounds(_world, _gx, _gy)) {
		return false;
	}
	var _biome = ds_grid_get(_world.biome, _gx, _gy);
	return (_biome != BIOME.WATER) && (_biome != BIOME.MOUNTAIN);
}

function tile_is_water(_world, _gx, _gy) {
	if (!tile_in_bounds(_world, _gx, _gy)) {
		return false;
	}
	return ds_grid_get(_world.biome, _gx, _gy) == BIOME.WATER;
}

// Land with no unit, city or building on it. Used for spawning and placing things.
function tile_is_free(_world, _gx, _gy) {
	if (!tile_is_walkable(_world, _gx, _gy)) {
		return false;
	}
	return (ds_grid_get(_world.unitGrid, _gx, _gy) == NO_ID)
		&& (ds_grid_get(_world.cityGrid, _gx, _gy) == NO_ID)
		&& (ds_grid_get(_world.buildingGrid, _gx, _gy) == NO_ID);
}

// Water with no unit or building on it
function water_tile_is_free(_world, _gx, _gy) {
	if (!tile_is_water(_world, _gx, _gy)) {
		return false;
	}
	return (ds_grid_get(_world.unitGrid, _gx, _gy) == NO_ID) && (ds_grid_get(_world.buildingGrid, _gx, _gy) == NO_ID);
}

// Habitable tiles are the only tiles an explorer can turn into a city
function place_habitable_tiles(_world, _needed) {
	var _minDist = 5;
	while (_minDist >= 2) {
		ds_grid_clear(_world.habitable, 0);
		var _count = 0;
		for (var _gx = 0; _gx < _world.mapW; _gx++) {
			for (var _gy = 0; _gy < _world.mapH; _gy++) {
				if (!tile_is_walkable(_world, _gx, _gy)) {
					continue;
				}
				if (hash_2d(_gx, _gy, _world.seed + 7) > 0.07) {
					continue;
				}
				// Keep habitable tiles spread apart
				var _tooClose = false;
				for (var _ox = -_minDist; _ox <= _minDist; _ox++) {
					for (var _oy = -_minDist; _oy <= _minDist; _oy++) {
						var _tx = _gx + _ox;
						var _ty = _gy + _oy;
						if (tile_in_bounds(_world, _tx, _ty) && (ds_grid_get(_world.habitable, _tx, _ty) == 1)) {
							_tooClose = true;
						}
					}
				}
				if (!_tooClose) {
					ds_grid_set(_world.habitable, _gx, _gy, 1);
					_count++;
				}
			}
		}
		if (_count >= _needed) {
			return;
		}
		_minDist--;
	}
}

// Picks start tiles that are as far from each other as possible
function pick_start_tiles(_world, _count) {
	var _cands = [];
	for (var _gx = 0; _gx < _world.mapW; _gx++) {
		for (var _gy = 0; _gy < _world.mapH; _gy++) {
			if (ds_grid_get(_world.habitable, _gx, _gy) == 1) {
				array_push(_cands, [_gx, _gy]);
			}
		}
	}
	var _starts = [];
	if (array_length(_cands) == 0) {
		return _starts;
	}
	var _first = clamp(floor(hash_2d(1, 2, _world.seed) * array_length(_cands)), 0, array_length(_cands) - 1);
	array_push(_starts, _cands[_first]);

	while (array_length(_starts) < _count) {
		var _best = -1;
		var _bestDist = -1;
		for (var _i = 0; _i < array_length(_cands); _i++) {
			var _minD = 999999;
			for (var _j = 0; _j < array_length(_starts); _j++) {
				var _dx = _cands[_i][0] - _starts[_j][0];
				var _dy = _cands[_i][1] - _starts[_j][1];
				_minD = min(_minD, _dx * _dx + _dy * _dy);
			}
			if (_minD > _bestDist) {
				_bestDist = _minD;
				_best = _i;
			}
		}
		if (_bestDist <= 0) {
			break;
		}
		array_push(_starts, _cands[_best]);
	}
	return _starts;
}

function make_nation_state(_world, _index, _slot) {
	var _researched = [];
	for (var _r = 0; _r < RESEARCH.COUNT; _r++) {
		array_push(_researched, false);
	}
	return {
		active: _slot.active,
		slotType: _slot.slotType,
		gold: START_GOLD,
		rp: 0,
		researched: _researched,
		cityNameIndex: 0,
		capitalId: NO_ID,
		eliminated: false,
		// Bots get a fixed ideology that decides which peace treaties they accept
		ideology: floor(hash_2d(_index, 77, _world.seed) * IDEO.COUNT) mod IDEO.COUNT,
		kills: 0,
		captures: 0,
		stats: { land: 0, gold: 0, income: 0, units: 0, power: 0 },
		botTimer: 1 + _index * 0.3,
		botBuildTimer: 8 + _index,
		botMilTimer: 60 + _index * 6
	};
}

// Sets up slots and nation states, and gives every active nation a capital, an explorer and a warrior
function setup_nations(_world) {
	var _s = _world.settings;
	var _slots = build_slots(_s);

	for (var _i = 0; _i < MAX_NATIONS; _i++) {
		array_push(_world.nationStates, make_nation_state(_world, _i, _slots[_i]));
		if ((_slots[_i].slotType == SLOT_TYPE.HUMAN) && (_world.localNation == NO_ID)) {
			_world.localNation = _i;
		}
	}

	var _starts = pick_start_tiles(_world, _s.nationCount);
	for (var _n = 0; _n < array_length(_starts); _n++) {
		var _sx = _starts[_n][0];
		var _sy = _starts[_n][1];
		var _capital = create_city(_world, _n, _sx, _sy);
		_world.nationStates[_n].capitalId = _capital.cityId;
		var _t1 = find_free_tile_near(_world, _sx, _sy, 3);
		if (_t1 != undefined) {
			create_unit(_world, _n, UNIT_TYPE.EXPLORER, _t1[0], _t1[1]);
		}
		var _t2 = find_free_tile_near(_world, _sx, _sy, 3);
		if (_t2 != undefined) {
			create_unit(_world, _n, UNIT_TYPE.WARRIOR, _t2[0], _t2[1]);
		}
	}
}

// Slot setup: nationCount nations are in the game. Of those, botCount are bots,
// vacantCount are open for a player to join, and the rest are human players.
function build_slots(_settings) {
	var _slots = [];
	var _bots = _settings.botCount;
	var _vacant = _settings.vacantCount;
	var _humans = max(1, _settings.nationCount - _bots - _vacant);
	for (var _i = 0; _i < MAX_NATIONS; _i++) {
		var _slot = { active: false, slotType: SLOT_TYPE.VACANT };
		if (_i < _settings.nationCount) {
			_slot.active = true;
			if (_i < _humans) {
				_slot.slotType = SLOT_TYPE.HUMAN;
			} else if (_i < _humans + _vacant) {
				_slot.slotType = SLOT_TYPE.VACANT;
			} else {
				_slot.slotType = SLOT_TYPE.BOT;
			}
		}
		array_push(_slots, _slot);
	}
	return _slots;
}

// Finds the closest free land tile to a point, searching ring by ring
function find_free_tile_near(_world, _gx, _gy, _maxRadius) {
	for (var _r = 1; _r <= _maxRadius; _r++) {
		for (var _ox = -_r; _ox <= _r; _ox++) {
			for (var _oy = -_r; _oy <= _r; _oy++) {
				if (max(abs(_ox), abs(_oy)) != _r) {
					continue;
				}
				if (tile_is_free(_world, _gx + _ox, _gy + _oy)) {
					return [_gx + _ox, _gy + _oy];
				}
			}
		}
	}
	return undefined;
}

// Same as above but looks for open water (used to launch ships from a port)
function find_free_water_near(_world, _gx, _gy, _maxRadius) {
	for (var _r = 1; _r <= _maxRadius; _r++) {
		for (var _ox = -_r; _ox <= _r; _ox++) {
			for (var _oy = -_r; _oy <= _r; _oy++) {
				if (max(abs(_ox), abs(_oy)) != _r) {
					continue;
				}
				if (water_tile_is_free(_world, _gx + _ox, _gy + _oy)) {
					return [_gx + _ox, _gy + _oy];
				}
			}
		}
	}
	return undefined;
}

// Tribe camps are guarded by hostile tribe units
function place_tribe_camps(_world) {
	var _campCount = max(2, floor(_world.mapW * _world.mapH / 700));
	var _camps = [];
	var _nationCities = _world.cities;
	var _guards = [UNIT_TYPE.WARRIOR, UNIT_TYPE.ARCHER, UNIT_TYPE.HORSEMAN];

	for (var _c = 0; _c < _campCount; _c++) {
		for (var _attempt = 0; _attempt < 200; _attempt++) {
			var _gx = floor(hash_2d(_c, _attempt, _world.seed + 33) * _world.mapW);
			var _gy = floor(hash_2d(_attempt, _c, _world.seed + 34) * _world.mapH);
			if (!tile_is_free(_world, _gx, _gy)) {
				continue;
			}
			var _ok = true;
			for (var _i = 0; _i < array_length(_nationCities); _i++) {
				if (max(abs(_nationCities[_i].gx - _gx), abs(_nationCities[_i].gy - _gy)) < 10) {
					_ok = false;
				}
			}
			for (var _j = 0; _j < array_length(_camps); _j++) {
				if (max(abs(_camps[_j][0] - _gx), abs(_camps[_j][1] - _gy)) < 8) {
					_ok = false;
				}
			}
			if (!_ok) {
				continue;
			}
			array_push(_camps, [_gx, _gy]);
			create_unit(_world, TRIBE_OWNER, UNIT_TYPE.WARRIOR, _gx, _gy);
			for (var _g = 0; _g < array_length(_guards); _g++) {
				var _spot = find_free_tile_near(_world, _gx, _gy, 2);
				if (_spot != undefined) {
					create_unit(_world, TRIBE_OWNER, _guards[_g], _spot[0], _spot[1]);
				}
			}
			break;
		}
	}
}

// ------------------------------------------------------------
// Borders
// ------------------------------------------------------------

// Level 1-2: 1 tile, level 3-5: 2 tiles, level 6-8: 3 tiles, level 9: 4 tiles
function get_city_border_radius(_level) {
	return 1 + floor(_level / 3);
}

// The closest city claims a tile. On a tie the older city keeps it.
function recalculate_borders(_world) {
	ds_grid_clear(_world.borderOwner, NO_ID);
	ds_grid_clear(_world.borderDist, 999);
	for (var _i = 0; _i < array_length(_world.cities); _i++) {
		var _city = _world.cities[_i];
		var _r = get_city_border_radius(_city.level);
		for (var _ox = -_r; _ox <= _r; _ox++) {
			for (var _oy = -_r; _oy <= _r; _oy++) {
				var _tx = _city.gx + _ox;
				var _ty = _city.gy + _oy;
				if (!tile_in_bounds(_world, _tx, _ty)) {
					continue;
				}
				var _dist = max(abs(_ox), abs(_oy));
				if (_dist < ds_grid_get(_world.borderDist, _tx, _ty)) {
					ds_grid_set(_world.borderDist, _tx, _ty, _dist);
					ds_grid_set(_world.borderOwner, _tx, _ty, _city.owner);
				}
			}
		}
	}

	// Count how much land each nation owns (used by the ideology system)
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		_world.nationStates[_n].stats.land = 0;
	}
	for (var _gx = 0; _gx < _world.mapW; _gx++) {
		for (var _gy = 0; _gy < _world.mapH; _gy++) {
			var _owner = ds_grid_get(_world.borderOwner, _gx, _gy);
			if ((_owner != NO_ID) && tile_is_walkable(_world, _gx, _gy)) {
				_world.nationStates[_owner].stats.land++;
			}
		}
	}
}
