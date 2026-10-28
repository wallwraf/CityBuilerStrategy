// ============================================================
// scr_buildings: buildings, wall edges, placement rules, passing rules
//
// Two kinds of building:
//   Tile buildings sit on a tile (buildingGrid holds the building id).
//   Edge buildings (walls and gates) sit on the border between two tiles.
//     axis 0 = the edge between (x, y) and (x + 1, y)
//     axis 1 = the edge between (x, y) and (x, y + 1)
//
// Each building definition has two flags (see define_building in scr_config):
//   solid      = CERTAIN units can pass it (units with passSolid, and the gate owner)
//   forceSolid = NO unit can pass it
// Both default to false, so units walk straight through unless a building says otherwise.
// ============================================================

function get_building_max_hp(_type, _level) {
	var _def = global.buildingDefs[_type];
	return floor(_def.hp * (1 + 0.5 * (_level - 1)));
}

function create_building(_world, _owner, _type, _gx, _gy, _axis) {
	var _isEdge = (global.buildingDefs[_type].place == PLACE.EDGE);
	var _b = {
		buildingId: array_length(_world.buildings),
		type: _type,
		owner: _owner,
		gx: _gx,
		gy: _gy,
		axis: _axis,
		isEdge: _isEdge,
		level: 1,
		hp: get_building_max_hp(_type, 1),
		maxHp: get_building_max_hp(_type, 1),
		alive: true,
		attackTimer: 0.5
	};
	array_push(_world.buildings, _b);
	if (_isEdge) {
		if (_axis == 0) {
			ds_grid_set(_world.edgeGridX, _gx, _gy, _b.buildingId);
		} else {
			ds_grid_set(_world.edgeGridY, _gx, _gy, _b.buildingId);
		}
	} else {
		ds_grid_set(_world.buildingGrid, _gx, _gy, _b.buildingId);
	}
	audio_event(_world, "build", _type, _gx, _gy, _owner);
	return _b;
}

function remove_building(_world, _b) {
	_b.alive = false;
	if (_b.isEdge) {
		if (_b.axis == 0) {
			ds_grid_set(_world.edgeGridX, _b.gx, _b.gy, NO_ID);
		} else {
			ds_grid_set(_world.edgeGridY, _b.gx, _b.gy, NO_ID);
		}
	} else {
		ds_grid_set(_world.buildingGrid, _b.gx, _b.gy, NO_ID);
	}
}

// The building standing on a tile, or undefined
function get_tile_building(_world, _gx, _gy) {
	if (!tile_in_bounds(_world, _gx, _gy)) {
		return undefined;
	}
	var _id = ds_grid_get(_world.buildingGrid, _gx, _gy);
	if (_id == NO_ID) {
		return undefined;
	}
	return _world.buildings[_id];
}

// The wall or gate on an edge, or undefined
function get_edge_building_at(_world, _ex, _ey, _axis) {
	if (!tile_in_bounds(_world, _ex, _ey)) {
		return undefined;
	}
	var _id = (_axis == 0) ? ds_grid_get(_world.edgeGridX, _ex, _ey) : ds_grid_get(_world.edgeGridY, _ex, _ey);
	if (_id == NO_ID) {
		return undefined;
	}
	return _world.buildings[_id];
}

// ------------------------------------------------------------
// Edge geometry
// ------------------------------------------------------------

// Finds the tile edge closest to a world position
function find_nearest_edge(_wx, _wy) {
	var _tx = world_to_tile_gx(_wx, _wy);
	var _ty = world_to_tile_gy(_wx, _wy);
	var _gx = round(_tx);
	var _gy = round(_ty);
	var _fx = _tx - _gx;
	var _fy = _ty - _gy;
	if (abs(_fx) >= abs(_fy)) {
		return { ex: (_fx >= 0) ? _gx : _gx - 1, ey: _gy, axis: 0, dist: 0.5 - abs(_fx) };
	}
	return { ex: _gx, ey: (_fy >= 0) ? _gy : _gy - 1, axis: 1, dist: 0.5 - abs(_fy) };
}

// The tile on the far side of an edge
function edge_second_tile(_ex, _ey, _axis) {
	if (_axis == 0) {
		return [_ex + 1, _ey];
	}
	return [_ex, _ey + 1];
}

function edge_in_bounds(_world, _ex, _ey, _axis) {
	var _t2 = edge_second_tile(_ex, _ey, _axis);
	return tile_in_bounds(_world, _ex, _ey) && tile_in_bounds(_world, _t2[0], _t2[1]);
}

// World coordinates of the two ends of an edge: [x1, y1, x2, y2]
function edge_world_points(_ex, _ey, _axis) {
	if (_axis == 0) {
		return [
			tile_to_world_x(_ex + 0.5, _ey - 0.5), tile_to_world_y(_ex + 0.5, _ey - 0.5),
			tile_to_world_x(_ex + 0.5, _ey + 0.5), tile_to_world_y(_ex + 0.5, _ey + 0.5)
		];
	}
	return [
		tile_to_world_x(_ex - 0.5, _ey + 0.5), tile_to_world_y(_ex - 0.5, _ey + 0.5),
		tile_to_world_x(_ex + 0.5, _ey + 0.5), tile_to_world_y(_ex + 0.5, _ey + 0.5)
	];
}

// The edge between two side by side tiles: [ex, ey, axis]
function edge_between(_x1, _y1, _x2, _y2) {
	if (_x1 != _x2) {
		return [min(_x1, _x2), _y1, 0];
	}
	return [_x1, min(_y1, _y2), 1];
}

// ------------------------------------------------------------
// Who can pass what
// ------------------------------------------------------------

function building_blocks_unit(_b, _unit) {
	// Envoys slip through every gate
	if (global.unitStats[_unit.type].diplomat && (_b.type == BUILDING.GATE)) {
		return false;
	}
	var _def = global.buildingDefs[_b.type];
	if (!_def.solid) {
		return false;
	}
	// forceSolid: no unit passes
	if (_def.forceSolid) {
		return true;
	}
	// Gates open for the nation that owns them
	if ((_b.type == BUILDING.GATE) && (_b.owner == _unit.owner)) {
		return false;
	}
	// Some units can pass certain solid buildings
	if (global.unitStats[_unit.type].passSolid) {
		return false;
	}
	return true;
}

function edge_blocks_unit(_world, _ex, _ey, _axis, _unit) {
	var _b = get_edge_building_at(_world, _ex, _ey, _axis);
	if (_b == undefined) {
		return false;
	}
	return _b.alive && building_blocks_unit(_b, _unit);
}

// Can this unit stand on this kind of terrain
function unit_terrain_ok(_world, _unit, _gx, _gy) {
	// Envoys can stand on land or water (they turn into a boat on water)
	if (global.unitStats[_unit.type].diplomat) {
		return tile_is_water(_world, _gx, _gy) || tile_is_walkable(_world, _gx, _gy);
	}
	if (global.unitStats[_unit.type].domain == DOMAIN.WATER) {
		return tile_is_water(_world, _gx, _gy);
	}
	// Land units also need the tile to be able to hold their weight
	return tile_is_walkable(_world, _gx, _gy)
		&& (global.unitStats[_unit.type].weight <= get_tile_weight_limit(_world, _gx, _gy));
}

// Can a unit make a single step from one tile to a neighbouring tile.
// This checks terrain, solid buildings and walls, but not other units standing in the way.
function unit_step_ok(_world, _unit, _x1, _y1, _x2, _y2) {
	if (!unit_terrain_ok(_world, _unit, _x2, _y2)) {
		return false;
	}
	var _bid = ds_grid_get(_world.buildingGrid, _x2, _y2);
	if (_bid != NO_ID) {
		var _tb = _world.buildings[_bid];
		if (_tb.alive && building_blocks_unit(_tb, _unit)) {
			return false;
		}
	}
	var _dx = _x2 - _x1;
	var _dy = _y2 - _y1;
	if ((_dx != 0) && (_dy != 0)) {
		// Diagonal step: all four edges around the corner must be open, so nobody slips past a wall corner
		var _exA = min(_x1, _x2);
		var _eyA = min(_y1, _y2);
		if (edge_blocks_unit(_world, _exA, _y1, 0, _unit)) { return false; }
		if (edge_blocks_unit(_world, _exA, _y2, 0, _unit)) { return false; }
		if (edge_blocks_unit(_world, _x1, _eyA, 1, _unit)) { return false; }
		if (edge_blocks_unit(_world, _x2, _eyA, 1, _unit)) { return false; }
		return true;
	}
	var _e = edge_between(_x1, _y1, _x2, _y2);
	return !edge_blocks_unit(_world, _e[0], _e[1], _e[2], _unit);
}

// ------------------------------------------------------------
// Placement rules. Returns "" when the spot is fine, otherwise the reason it is not.
// ------------------------------------------------------------

function city_is_adjacent(_world, _owner, _gx, _gy) {
	for (var _ox = -1; _ox <= 1; _ox++) {
		for (var _oy = -1; _oy <= 1; _oy++) {
			if (!tile_in_bounds(_world, _gx + _ox, _gy + _oy)) {
				continue;
			}
			var _cid = ds_grid_get(_world.cityGrid, _gx + _ox, _gy + _oy);
			if ((_cid != NO_ID) && (_world.cities[_cid].owner == _owner)) {
				return true;
			}
		}
	}
	return false;
}

function tile_touches_water(_world, _gx, _gy) {
	for (var _ox = -1; _ox <= 1; _ox++) {
		for (var _oy = -1; _oy <= 1; _oy++) {
			if (tile_is_water(_world, _gx + _ox, _gy + _oy)) {
				return true;
			}
		}
	}
	return false;
}

// For walls and gates _gx and _gy are the edge position and _axis is 0 or 1
function can_place_building(_world, _owner, _type, _gx, _gy, _axis) {
	var _def = global.buildingDefs[_type];
	if (!_def.buildable) {
		return "This cannot be built";
	}
	if ((_def.reqResearch != NO_ID) && !nation_has_research(_world, _owner, _def.reqResearch)) {
		return "Needs research: " + global.researchDefs[_def.reqResearch].researchName;
	}

	if (_def.place == PLACE.EDGE) {
		if (!edge_in_bounds(_world, _gx, _gy, _axis)) {
			return "Out of bounds";
		}
		if (get_edge_building_at(_world, _gx, _gy, _axis) != undefined) {
			return "There is already a wall here";
		}
		var _t2 = edge_second_tile(_gx, _gy, _axis);
		var _ownA = ds_grid_get(_world.borderOwner, _gx, _gy);
		var _ownB = ds_grid_get(_world.borderOwner, _t2[0], _t2[1]);
		if ((_ownA != _owner) && (_ownB != _owner)) {
			return "Must be inside your borders";
		}
		if (((_ownA != NO_ID) && (_ownA != _owner)) || ((_ownB != NO_ID) && (_ownB != _owner))) {
			return "Another nation owns this edge";
		}
		if (!tile_is_walkable(_world, _gx, _gy) && !tile_is_walkable(_world, _t2[0], _t2[1])) {
			return "Walls need land";
		}
		return "";
	}
	
	// Paths sit under everything, so only the border, the land and other paths matter
	if (_def.place == PLACE.PATH) {
		if (!tile_in_bounds(_world, _gx, _gy)) {
			return "Out of bounds";
		}
		if (ds_grid_get(_world.borderOwner, _gx, _gy) != _owner) {
			return "Must be inside your borders";
		}
		if (!tile_is_walkable(_world, _gx, _gy)) {
			return "Land only";
		}
		if (ds_grid_get(_world.pathGrid, _gx, _gy) != NO_ID) {
			return "There is already a path here";
		}
		return "";
	}

	if (!tile_in_bounds(_world, _gx, _gy)) {
		return "Out of bounds";
	}
	if (ds_grid_get(_world.borderOwner, _gx, _gy) != _owner) {
		return "Must be inside your borders";
	}
	if (ds_grid_get(_world.cityGrid, _gx, _gy) != NO_ID) {
		return "A city is here";
	}
	if (ds_grid_get(_world.buildingGrid, _gx, _gy) != NO_ID) {
		return "This tile is taken";
	}

	var _res = ds_grid_get(_world.resource, _gx, _gy);
	var _habitable = (ds_grid_get(_world.habitable, _gx, _gy) == 1);
	switch (_def.place) {
		case PLACE.WATER:
			if (!tile_is_water(_world, _gx, _gy)) {
				return "Water tiles only";
			}
			return "";

		case PLACE.STONE:
			if (!tile_is_walkable(_world, _gx, _gy) || (_res != RES.STONE)) {
				return "Stone tiles only";
			}
			return "";

		case PLACE.ORE:
			if (!tile_is_walkable(_world, _gx, _gy) || (_res != RES.ORE)) {
				return "Ore tiles only";
			}
			return "";

		case PLACE.FOREST:
			if (!tile_is_walkable(_world, _gx, _gy) || (_res != RES.TREES)) {
				return "Tree tiles only";
			}
			return "";

		case PLACE.NEAR_CITY:
			if (!tile_is_walkable(_world, _gx, _gy)) {
				return "Land only";
			}
			if ((_res != RES.NONE) || _habitable) {
				return "This tile is reserved";
			}
			if (!city_is_adjacent(_world, _owner, _gx, _gy)) {
				return "Must be next to one of your cities";
			}
			return "";

		case PLACE.COAST:
			if (!tile_is_walkable(_world, _gx, _gy)) {
				return "Land only";
			}
			if ((_res != RES.NONE) || _habitable) {
				return "This tile is reserved";
			}
			if (!tile_touches_water(_world, _gx, _gy)) {
				return "Must touch water";
			}
			return "";

		case PLACE.LAND:
			if (!tile_is_walkable(_world, _gx, _gy)) {
				return "Land only";
			}
			if ((_res != RES.NONE) || _habitable) {
				return "This tile is reserved";
			}
			return "";
	}
	return "Cannot build here";
}

// ------------------------------------------------------------
// Economy and upgrades
// ------------------------------------------------------------

function get_building_income(_b) {
	var _def = global.buildingDefs[_b.type];
	if (_def.incomeBase <= 0) {
		return 0;
	}
	return _def.incomeBase + _def.incomePerLevel * (_b.level - 1);
}

function get_building_upgrade_cost(_b) {
	return floor(global.buildingDefs[_b.type].cost * 0.75 * _b.level);
}

// Extra research points per second from every laboratory (0.5 per level)
function get_nation_lab_rate(_world, _owner) {
	var _rate = 0;
	for (var _i = 0; _i < array_length(_world.buildings); _i++) {
		var _b = _world.buildings[_i];
		if (_b.alive && (_b.owner == _owner) && (_b.type == BUILDING.LABORATORY)) {
			_rate += 0.5 * _b.level;
		}
	}
	return _rate;
}

function count_nation_buildings(_world, _owner, _type) {
	var _count = 0;
	for (var _i = 0; _i < array_length(_world.buildings); _i++) {
		var _b = _world.buildings[_i];
		if (_b.alive && (_b.owner == _owner) && (_b.type == _type)) {
			_count++;
		}
	}
	return _count;
}

// ------------------------------------------------------------
// Tower, hospital and visibility
// ------------------------------------------------------------

// A little weaker than a warrior (10) at level 1, stronger every level
function get_tower_damage(_level) {
	return 8 + 1.5 * (_level - 1);
}

// Attack speed grows with level, twice as fast at level 9. Range stays at 1 tile.
function get_tower_delay(_level) {
	return 1.0 / (1 + (_level - 1) / 8);
}

function get_hospital_heal_rate(_level) {
	return 1.5 + 0.75 * (_level - 1);
}

// Mines and traps are hidden from their enemies until an enemy unit gets close.
// Mineseekers spot naval mines from further away.
function building_visible_to(_world, _b, _viewer) {
	var _def = global.buildingDefs[_b.type];
	if (!_def.hidden || (_b.owner == _viewer) || (_viewer == NO_ID)) {
		return true;
	}
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (!_u.alive || (_u.owner != _viewer)) {
			continue;
		}
		var _dist = tile_distance(_u.gx, _u.gy, _b.gx, _b.gy);
		if (_dist <= 1) {
			return true;
		}
		var _stats = global.unitStats[_u.type];
		if ((_b.type == BUILDING.NAVAL_MINE) && (_stats.ability == ABILITY.MINESEEK) && (_dist <= _stats.seekRadius)) {
			return true;
		}
	}
	return false;
}

function update_buildings(_world, _dt) {
	for (var _i = 0; _i < array_length(_world.buildings); _i++) {
		var _b = _world.buildings[_i];
		if (!_b.alive) {
			continue;
		}
		switch (_b.type) {
			case BUILDING.TOWER:
				_b.attackTimer = max(0, _b.attackTimer - _dt);
				if (_b.attackTimer <= 0) {
					var _target = find_enemy_unit_near(_world, _b.owner, _b.gx, _b.gy, 1);
					if (_target != undefined) {
						damage_unit(_world, _target, get_tower_damage(_b.level), _b.owner);
						_b.attackTimer = get_tower_delay(_b.level);
					}
				}
				break;

			case BUILDING.HOSPITAL:
				var _rate = get_hospital_heal_rate(_b.level) * _dt;
				for (var _j = 0; _j < array_length(_world.units); _j++) {
					var _u = _world.units[_j];
					if (_u.alive && (_u.owner == _b.owner) && (tile_distance(_u.gx, _u.gy, _b.gx, _b.gy) <= 1)) {
						_u.hp = min(global.unitStats[_u.type].maxHp, _u.hp + _rate);
					}
				}
				break;
		}
	}
}

// Called whenever a unit lands on a tile. Naval mines and traps go off for enemy units.
function trigger_building_on_enter(_world, _unit) {
	var _id = ds_grid_get(_world.buildingGrid, _unit.gx, _unit.gy);
	if (_id == NO_ID) {
		return;
	}
	var _b = _world.buildings[_id];
	var _def = global.buildingDefs[_b.type];
	if (!_b.alive || (_def.triggerDamage <= 0) || !are_hostile(_world, _b.owner, _unit.owner)) {
		return;
	}
	remove_building(_world, _b);
	push_notice(_world, _unit.owner, "A " + _def.buildingName + " went off under your " + global.unitStats[_unit.type].subtitle);
	damage_unit(_world, _unit, _def.triggerDamage, _b.owner);
}
