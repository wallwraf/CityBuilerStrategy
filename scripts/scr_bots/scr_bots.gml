// ============================================================
// scr_bots: nation bot AI. Bots only use apply_command(),
// exactly like a human player, so they follow the same rules.
// ============================================================

function update_bots(_world, _dt) {
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		var _state = _world.nationStates[_n];
		if (!_state.active || _state.eliminated || (_state.slotType != SLOT_TYPE.BOT)) {
			continue;
		}
		_state.botTimer -= _dt;
		_state.botBuildTimer -= _dt;
		_state.botMilTimer -= _dt;
		if (_state.botTimer <= 0) {
			_state.botTimer = 2;
			run_bot_turn(_world, _n);
		}
		if (_state.botBuildTimer <= 0) {
			_state.botBuildTimer = 10;
			run_bot_builder(_world, _n);
		}
		if (_state.botMilTimer <= 0) {
			_state.botMilTimer = 45;
			run_bot_military(_world, _n);
		}
	}
}

function bot_get_first_city(_world, _owner) {
	var _capital = get_capital_city(_world, _owner);
	if (_capital != undefined) {
		return _capital;
	}
	for (var _i = 0; _i < array_length(_world.cities); _i++) {
		if (_world.cities[_i].owner == _owner) {
			return _world.cities[_i];
		}
	}
	return undefined;
}

// Explorers, buying units, upgrades and research
function run_bot_turn(_world, _owner) {
	var _state = _world.nationStates[_owner];
	var _explorers = 0;
	var _military = 0;
	var _cityCount = count_nation_cities(_world, _owner);

	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (!_u.alive || (_u.owner != _owner)) {
			continue;
		}
		if (_u.type != UNIT_TYPE.EXPLORER) {
			if (global.unitStats[_u.type].damage > 0) {
				_military++;
			}
			continue;
		}
		_explorers++;
		if (_u.order != ORDER.NONE) {
			continue;
		}
		var _target = bot_find_city_site(_world, _owner, _u);
		if (_target == undefined) {
			continue;
		}
		if ((_target[0] == _u.gx) && (_target[1] == _u.gy)) {
			var _found = make_command(CMD.FOUND_CITY, _owner);
			array_push(_found.unitIds, _u.unitId);
			apply_command(_world, _found);
		} else {
			var _move = make_command(CMD.MOVE, _owner);
			array_push(_move.unitIds, _u.unitId);
			_move.gx = _target[0];
			_move.gy = _target[1];
			apply_command(_world, _move);
		}
	}

	var _capital = bot_get_first_city(_world, _owner);
	if (_capital == undefined) {
		return;
	}

	// Research whatever is affordable
	for (var _r = 0; _r < RESEARCH.COUNT; _r++) {
		var _rdef = global.researchDefs[_r];
		if (!_state.researched[_r] && (_state.rp >= _rdef.cost)) {
			var _research = make_command(CMD.RESEARCH, _owner);
			_research.researchId = _r;
			apply_command(_world, _research);
		}
	}

	// Spend gold: expand first, then army, then city upgrades
	if ((_explorers < 1) && (_cityCount < 6) && (_state.gold >= global.unitStats[UNIT_TYPE.EXPLORER].cost)) {
		var _buyExplorer = make_command(CMD.BUY_UNIT, _owner);
		_buyExplorer.cityId = _capital.cityId;
		_buyExplorer.unitType = UNIT_TYPE.EXPLORER;
		apply_command(_world, _buyExplorer);
	} else if (_military < _cityCount * 3 + 2) {
		bot_buy_soldier(_world, _owner, _capital, _military);
	} else if (_state.gold > get_city_upgrade_cost(_capital) + 120) {
		var _up = make_command(CMD.UPGRADE_CITY, _owner);
		_up.cityId = _capital.cityId;
		apply_command(_world, _up);
	}
}

// Buys a mix of troops from the city hall, or from a barracks or garrison once they exist
function bot_buy_soldier(_world, _owner, _capital, _militaryCount) {
	var _state = _world.nationStates[_owner];
	// Rotate through the roles so the army is mixed
	var _role = _militaryCount mod 4;
	var _roleTypes = [
		[UNIT_TYPE.WARRIOR, UNIT_TYPE.DUELIST, UNIT_TYPE.EXECUTIONER, UNIT_TYPE.ROYAL_CHAMPION, UNIT_TYPE.DREADNOUGHT_SLAYER],
		[UNIT_TYPE.SHIELDMAN, UNIT_TYPE.IRONCLAD, UNIT_TYPE.TOWER_SHIELD, UNIT_TYPE.BASTION_KNIGHT, UNIT_TYPE.COLOSSUS],
		[UNIT_TYPE.ARCHER, UNIT_TYPE.CROSSBOWMAN, UNIT_TYPE.ARTILLERIST, UNIT_TYPE.SIEGE_MARKSMAN, UNIT_TYPE.SIEGEBREAKER],
		[UNIT_TYPE.HORSEMAN, UNIT_TYPE.LIGHT_CAVALRY, UNIT_TYPE.WARHOUND, UNIT_TYPE.SKY_LANCER, UNIT_TYPE.STORMWING]
	];

	// Try the best tier first and work down
	for (var _tier = 4; _tier >= 0; _tier--) {
		var _type = _roleTypes[_role][_tier];
		var _stats = global.unitStats[_type];
		if (_state.gold < _stats.cost) {
			continue;
		}
		if (_stats.source == UNIT_SRC.CITY_HALL) {
			if (get_unit_lock_reason(_world, _owner, _type, _capital.level) != "") {
				continue;
			}
			var _buy = make_command(CMD.BUY_UNIT, _owner);
			_buy.cityId = _capital.cityId;
			_buy.unitType = _type;
			if (apply_command(_world, _buy) == "") {
				return;
			}
		} else {
			for (var _b = 0; _b < array_length(_world.buildings); _b++) {
				var _site = _world.buildings[_b];
				if (!_site.alive || (_site.owner != _owner) || (get_building_unit_source(_site.type) != _stats.source)) {
					continue;
				}
				if (get_unit_lock_reason(_world, _owner, _type, _site.level) != "") {
					continue;
				}
				var _train = make_command(CMD.TRAIN_UNIT, _owner);
				_train.buildingId = _site.buildingId;
				_train.unitType = _type;
				if (apply_command(_world, _train) == "") {
					return;
				}
			}
		}
	}
}

// Builds the next useful building, and upgrades what it has
function run_bot_builder(_world, _owner) {
	var _state = _world.nationStates[_owner];
	var _capital = bot_get_first_city(_world, _owner);
	if (_capital == undefined) {
		return;
	}
	var _wanted = [BUILDING.MARKET, BUILDING.BARRACKS, BUILDING.LABORATORY, BUILDING.LUMBER_MILL, BUILDING.QUARRY, BUILDING.MINE, BUILDING.TOWER, BUILDING.HOSPITAL, BUILDING.EMBASSY, BUILDING.GARRISON];
	var _maxCounts = [2, 1, 1, 2, 2, 2, 3, 1, 1, 1];

	for (var _i = 0; _i < array_length(_wanted); _i++) {
		var _type = _wanted[_i];
		if (count_nation_buildings(_world, _owner, _type) >= _maxCounts[_i]) {
			continue;
		}
		if (_state.gold < global.buildingDefs[_type].cost + 40) {
			return;
		}
		var _spot = bot_find_build_spot(_world, _owner, _type, _capital);
		if (_spot == undefined) {
			continue;
		}
		var _build = make_command(CMD.BUILD, _owner);
		_build.buildingType = _type;
		_build.gx = _spot[0];
		_build.gy = _spot[1];
		apply_command(_world, _build);
		return;
	}

	// Nothing left to build: upgrade the cheapest upgradable building
	for (var _b = 0; _b < array_length(_world.buildings); _b++) {
		var _site = _world.buildings[_b];
		if (!_site.alive || (_site.owner != _owner) || _site.isEdge) {
			continue;
		}
		if ((_site.level < global.buildingDefs[_site.type].maxLevel) && (_state.gold > get_building_upgrade_cost(_site) + 150)) {
			var _upgrade = make_command(CMD.UPGRADE_BUILDING, _owner);
			_upgrade.buildingId = _site.buildingId;
			apply_command(_world, _upgrade);
			return;
		}
	}

	bot_try_diplomacy(_world, _owner);
}

// The closest allowed tile to the capital
function bot_find_build_spot(_world, _owner, _type, _capital) {
	var _best = undefined;
	var _bestDist = 999999;
	for (var _gx = 0; _gx < _world.mapW; _gx++) {
		for (var _gy = 0; _gy < _world.mapH; _gy++) {
			if (ds_grid_get(_world.borderOwner, _gx, _gy) != _owner) {
				continue;
			}
			var _dist = tile_distance(_gx, _gy, _capital.gx, _capital.gy);
			if (_dist >= _bestDist) {
				continue;
			}
			if (can_place_building(_world, _owner, _type, _gx, _gy, 0) == "") {
				_bestDist = _dist;
				_best = [_gx, _gy];
			}
		}
	}
	return _best;
}

// With an embassy and no treaty, a bot sometimes sends an envoy to the weakest neighbour nation
function bot_try_diplomacy(_world, _owner) {
	if ((get_active_treaty(_world, _owner) != undefined) || (irandom(2) != 0)) {
		return;
	}
	var _embassy = undefined;
	for (var _b = 0; _b < array_length(_world.buildings); _b++) {
		var _site = _world.buildings[_b];
		if (_site.alive && (_site.owner == _owner) && (_site.type == BUILDING.EMBASSY)) {
			_embassy = _site;
			break;
		}
	}
	if (_embassy == undefined) {
		return;
	}
	var _options = [];
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		if ((_n != _owner) && _world.nationStates[_n].active && !_world.nationStates[_n].eliminated) {
			array_push(_options, _n);
		}
	}
	if (array_length(_options) == 0) {
		return;
	}
	var _send = make_command(CMD.SEND_ENVOY, _owner);
	_send.buildingId = _embassy.buildingId;
	_send.targetNation = _options[irandom(array_length(_options) - 1)];
	apply_command(_world, _send);
}

// Sends the army at the nearest enemy city once it is big enough
function run_bot_military(_world, _owner) {
	var _army = [];
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (!_u.alive || (_u.owner != _owner)) {
			continue;
		}
		var _stats = global.unitStats[_u.type];
		if ((_stats.damage > 0) && (_stats.domain == DOMAIN.LAND)) {
			array_push(_army, _u);
		}
	}
	if (array_length(_army) < 6) {
		return;
	}

	// Aim at the nearest city we are allowed to attack
	var _home = bot_get_first_city(_world, _owner);
	if (_home == undefined) {
		return;
	}
	var _target = undefined;
	var _bestDist = 999999;
	for (var _c = 0; _c < array_length(_world.cities); _c++) {
		var _city = _world.cities[_c];
		if ((_city.owner == _owner) || !are_hostile(_world, _owner, _city.owner)) {
			continue;
		}
		var _dist = tile_distance(_home.gx, _home.gy, _city.gx, _city.gy);
		if (_dist < _bestDist) {
			_bestDist = _dist;
			_target = _city;
		}
	}
	if (_target == undefined) {
		return;
	}

	// Keep a few units home to defend
	var _attack = make_command(CMD.ATTACK, _owner);
	_attack.targetKind = ORDER.ATTACK_CITY;
	_attack.targetId = _target.cityId;
	for (var _k = 3; _k < array_length(_army); _k++) {
		array_push(_attack.unitIds, _army[_k].unitId);
	}
	apply_command(_world, _attack);
}

// Nearest habitable tile that has no city and is not inside another nation's border
function bot_find_city_site(_world, _owner, _unit) {
	var _best = undefined;
	var _bestDist = 999999;
	for (var _gx = 0; _gx < _world.mapW; _gx++) {
		for (var _gy = 0; _gy < _world.mapH; _gy++) {
			if (ds_grid_get(_world.habitable, _gx, _gy) != 1) {
				continue;
			}
			if (ds_grid_get(_world.cityGrid, _gx, _gy) != NO_ID) {
				continue;
			}
			var _b = ds_grid_get(_world.borderOwner, _gx, _gy);
			if ((_b != NO_ID) && (_b != _owner)) {
				continue;
			}
			var _dist = tile_distance(_unit.gx, _unit.gy, _gx, _gy);
			if (_dist < _bestDist) {
				_bestDist = _dist;
				_best = [_gx, _gy];
			}
		}
	}
	return _best;
}
