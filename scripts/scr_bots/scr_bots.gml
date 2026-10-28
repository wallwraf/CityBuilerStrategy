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
			_state.botBuildTimer = 6;
			run_bot_builder(_world, _n);
		}
		if (_state.botMilTimer <= 0) {
			_state.botMilTimer = 30;
			run_bot_military(_world, _n);
		}
	}
}

// Economy first: explorers found cities, then research, city upgrades, and only then an army
function run_bot_turn(_world, _owner) {
	var _state = _world.nationStates[_owner];
	var _explorers = 0;
	var _military = 0;
	var _cityCount = count_nation_cities(_world, _owner);
	var _claimed = [];

	// Sites other explorers of ours are already heading for
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (_u.alive && (_u.owner == _owner) && (_u.type == UNIT_TYPE.EXPLORER) && (_u.order != ORDER.NONE)) {
			array_push(_claimed, [_u.goalGx, _u.goalGy]);
		}
	}

	for (var _j = 0; _j < array_length(_world.units); _j++) {
		var _unit = _world.units[_j];
		if (!_unit.alive || (_unit.owner != _owner) || unit_is_aboard(_unit)) {
			continue;
		}
		if (_unit.type != UNIT_TYPE.EXPLORER) {
			if ((global.unitStats[_unit.type].damage > 0) && (global.unitStats[_unit.type].domain == DOMAIN.LAND)) {
				_military++;
			}
			continue;
		}
		_explorers++;
		if (_unit.order != ORDER.NONE) {
			continue;
		}
		var _target = bot_find_city_site(_world, _owner, _unit, _claimed);
		if (_target == undefined) {
			continue;
		}
		if ((_target[0] == _unit.gx) && (_target[1] == _unit.gy)) {
			var _found = make_command(CMD.FOUND_CITY, _owner);
			array_push(_found.unitIds, _unit.unitId);
			apply_command(_world, _found);
		} else {
			array_push(_claimed, _target);
			var _move = make_command(CMD.MOVE, _owner);
			array_push(_move.unitIds, _unit.unitId);
			_move.gx = _target[0];
			_move.gy = _target[1];
			apply_command(_world, _move);
		}
	}

	var _capital = bot_get_first_city(_world, _owner);
	if (_capital == undefined) {
		return;
	}

	// Research the cheapest thing that is affordable
	var _bestResearch = NO_ID;
	for (var _r = 0; _r < RESEARCH.COUNT; _r++) {
		var _rdef = global.researchDefs[_r];
		if (_state.researched[_r] || ((_rdef.prereq != NO_ID) && !_state.researched[_rdef.prereq]) || (_state.rp < _rdef.cost)) {
			continue;
		}
		if ((_bestResearch == NO_ID) || (_rdef.cost < global.researchDefs[_bestResearch].cost)) {
			_bestResearch = _r;
		}
	}
	if (_bestResearch != NO_ID) {
		var _research = make_command(CMD.RESEARCH, _owner);
		_research.researchId = _bestResearch;
		apply_command(_world, _research);
	}

	// Spend gold in order: a new explorer, city upgrades, then the army
	var _wantExplorer = (_explorers < 1) && (_cityCount < 8) && bot_has_free_site(_world, _owner);
	var _quota = min(30, 2 + _cityCount * 2 + floor(_world.time / 180));
	var _upgradeCity = bot_find_upgrade_city(_world, _owner);
	if (_wantExplorer && (_state.gold >= global.unitStats[UNIT_TYPE.EXPLORER].cost)) {
		var _buyExplorer = make_command(CMD.BUY_UNIT, _owner);
		_buyExplorer.cityId = _capital.cityId;
		_buyExplorer.unitType = UNIT_TYPE.EXPLORER;
		apply_command(_world, _buyExplorer);
	} else if ((_upgradeCity != undefined) && (_state.gold >= get_city_upgrade_cost(_upgradeCity)) && ((_military >= 2) || (_world.time > 120))) {
		var _up = make_command(CMD.UPGRADE_CITY, _owner);
		_up.cityId = _upgradeCity.cityId;
		apply_command(_world, _up);
	} else if (_military < _quota) {
		// Keep a small reserve so the builder can still afford its next economy building
		if ((_state.gold > 60) || (_military < 2)) {
			bot_buy_soldier(_world, _owner, _capital, _military);
		}
	}
}

// The lowest level city of ours that can still be upgraded
function bot_find_upgrade_city(_world, _owner) {
	var _best = undefined;
	for (var _c = 0; _c < array_length(_world.cities); _c++) {
		var _city = _world.cities[_c];
		if ((_city.owner != _owner) || (_city.level >= MAX_CITY_LEVEL)) {
			continue;
		}
		if ((_best == undefined) || (_city.level < _best.level)) {
			_best = _city;
		}
	}
	return _best;
}

// Builds the economy around every city first, then the military buildings
function run_bot_builder(_world, _owner) {
	var _state = _world.nationStates[_owner];
	var _cities = [];
	for (var _c = 0; _c < array_length(_world.cities); _c++) {
		if (_world.cities[_c].owner == _owner) {
			array_push(_cities, _world.cities[_c]);
		}
	}
	var _cityCount = array_length(_cities);
	if (_cityCount == 0) {
		return;
	}

	// Economy buildings: income first, research next
	var _econTypes = [BUILDING.LUMBER_MILL, BUILDING.QUARRY, BUILDING.MINE, BUILDING.MARKET, BUILDING.LABORATORY];
	var _econMax = [_cityCount + 1, _cityCount, _cityCount, _cityCount, 1 + (_cityCount div 2)];
	var _econCount = 0;
	for (var _e = 0; _e < array_length(_econTypes); _e++) {
		_econCount += count_nation_buildings(_world, _owner, _econTypes[_e]);
	}
	if (bot_manage_paths(_world, _owner, _cities)) {
		return;
	}

	// Pick a different city each time so the economy spreads out
	var _anchor = _cities[sim_irandom(_world, _cityCount - 1)];

	for (var _i = 0; _i < array_length(_econTypes); _i++) {
		var _type = _econTypes[_i];
		if (count_nation_buildings(_world, _owner, _type) >= _econMax[_i]) {
			continue;
		}
		if (bot_try_build(_world, _owner, _type, _anchor)) {
			return;
		}
		if (_state.gold < global.buildingDefs[_type].cost) {
			// Save up for it instead of spending on something else
			return;
		}
	}

	// Military and support buildings wait until the economy has got going
	if (_econCount >= _cityCount + 2) {
		var _milTypes = [BUILDING.BARRACKS, BUILDING.TOWER, BUILDING.HOSPITAL, BUILDING.EMBASSY, BUILDING.GARRISON];
		var _milMax = [1 + (_cityCount div 3), _cityCount, 1, 1, 1];
		for (var _m = 0; _m < array_length(_milTypes); _m++) {
			if (count_nation_buildings(_world, _owner, _milTypes[_m]) >= _milMax[_m]) {
				continue;
			}
			if ((_milTypes[_m] == BUILDING.TOWER) && (_world.time < 240)) {
				continue;
			}
			if (bot_try_build(_world, _owner, _milTypes[_m], _anchor)) {
				return;
			}
		}
	}

	// Nothing left to build: upgrade a building we can afford
	for (var _b = 0; _b < array_length(_world.buildings); _b++) {
		var _site = _world.buildings[_b];
		if (!_site.alive || (_site.owner != _owner) || _site.isEdge) {
			continue;
		}
		if ((_site.level < global.buildingDefs[_site.type].maxLevel) && (_state.gold > get_building_upgrade_cost(_site) + 100)) {
			var _upgrade = make_command(CMD.UPGRADE_BUILDING, _owner);
			_upgrade.buildingId = _site.buildingId;
			apply_command(_world, _upgrade);
			return;
		}
	}

	bot_try_diplomacy(_world, _owner);
}

// Returns true when the building was placed
function bot_try_build(_world, _owner, _type, _anchor) {
	var _state = _world.nationStates[_owner];
	var _def = global.buildingDefs[_type];
	if ((_def.reqResearch != NO_ID) && !nation_has_research(_world, _owner, _def.reqResearch)) {
		return false;
	}
	if (_state.gold < _def.cost) {
		return false;
	}
	var _spot = bot_find_build_spot(_world, _owner, _type, _anchor);
	if (_spot == undefined) {
		return false;
	}
	var _build = make_command(CMD.BUILD, _owner);
	_build.buildingType = _type;
	_build.gx = _spot[0];
	_build.gy = _spot[1];
	return (apply_command(_world, _build) == "");
}

// The closest allowed tile to the given city, inside our own border
function bot_find_build_spot(_world, _owner, _type, _anchor) {
	var _best = undefined;
	var _bestDist = 999999;
	var _reach = get_city_border_radius(_anchor.level) + 1;
	for (var _gx = max(0, _anchor.gx - _reach); _gx <= min(_world.mapW - 1, _anchor.gx + _reach); _gx++) {
		for (var _gy = max(0, _anchor.gy - _reach); _gy <= min(_world.mapH - 1, _anchor.gy + _reach); _gy++) {
			if (ds_grid_get(_world.borderOwner, _gx, _gy) != _owner) {
				continue;
			}
			var _dist = tile_distance(_gx, _gy, _anchor.gx, _anchor.gy);
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

// Gathers an army at home and only attacks once it is big enough. Every wave needs a bigger army.
function run_bot_military(_world, _owner) {
	var _state = _world.nationStates[_owner];
	if (!variable_struct_exists(_state, "botWave")) {
		_state.botWave = 0;
	}
	var _cityCount = count_nation_cities(_world, _owner);
	var _army = [];
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (!_u.alive || (_u.owner != _owner) || unit_is_aboard(_u)) {
			continue;
		}
		var _stats = global.unitStats[_u.type];
		if ((_stats.damage > 0) && (_stats.domain == DOMAIN.LAND)) {
			array_push(_army, _u);
		}
	}

	// Too early, or too few cities to risk the army
	var _needed = min(26, 8 + _state.botWave * 2 + _cityCount);
	if ((_cityCount < 2) || (_world.time < 300) || (array_length(_army) < _needed)) {
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

	// Keep some units home to defend
	var _defenders = max(3, _cityCount);
	var _attack = make_command(CMD.ATTACK, _owner);
	_attack.targetKind = ORDER.ATTACK_CITY;
	_attack.targetId = _target.cityId;
	for (var _k = _defenders; _k < array_length(_army); _k++) {
		array_push(_attack.unitIds, _army[_k].unitId);
	}
	apply_command(_world, _attack);
	_state.botWave++;
}

// The nearest habitable tile that we can actually walk to, that nobody else owns and that no
// other explorer of ours has claimed. Islands are skipped (they need a Traveler Boat).
function bot_find_city_site(_world, _owner, _unit, _claimed) {
	var _candidates = [];
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
			if (bot_site_is_claimed(_claimed, _gx, _gy)) {
				continue;
			}
			array_push(_candidates, [tile_distance(_unit.gx, _unit.gy, _gx, _gy), _gx, _gy]);
		}
	}

	// Check the few nearest ones for a real land path
	for (var _try = 0; _try < 5; _try++) {
		var _bestIndex = -1;
		var _bestDist = 999999;
		for (var _i = 0; _i < array_length(_candidates); _i++) {
			if (_candidates[_i][0] < _bestDist) {
				_bestDist = _candidates[_i][0];
				_bestIndex = _i;
			}
		}
		if (_bestIndex < 0) {
			return undefined;
		}
		var _site = _candidates[_bestIndex];
		array_delete(_candidates, _bestIndex, 1);
		if (bot_path_reaches(_world, _unit, _site[1], _site[2])) {
			return [_site[1], _site[2]];
		}
	}
	return undefined;
}

function bot_site_is_claimed(_claimed, _gx, _gy) {
	for (var _i = 0; _i < array_length(_claimed); _i++) {
		if ((_claimed[_i][0] == _gx) && (_claimed[_i][1] == _gy)) {
			return true;
		}
	}
	return false;
}

function bot_path_reaches(_world, _unit, _gx, _gy) {
	if ((_unit.gx == _gx) && (_unit.gy == _gy)) {
		return true;
	}
	var _path = find_path(_world, _unit, _gx, _gy, false);
	var _len = array_length(_path);
	if (_len == 0) {
		return false;
	}
	return (_path[_len - 1][0] == _gx) && (_path[_len - 1][1] == _gy);
}

// True when any habitable tile is still free for us
function bot_has_free_site(_world, _owner) {
	for (var _gx = 0; _gx < _world.mapW; _gx++) {
		for (var _gy = 0; _gy < _world.mapH; _gy++) {
			if ((ds_grid_get(_world.habitable, _gx, _gy) == 1) && (ds_grid_get(_world.cityGrid, _gx, _gy) == NO_ID)) {
				var _b = ds_grid_get(_world.borderOwner, _gx, _gy);
				if ((_b == NO_ID) || (_b == _owner)) {
					return true;
				}
			}
		}
	}
	return false;
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

// With an embassy and no treaty, a bot sometimes sends an envoy to the weakest neighbour nation
function bot_try_diplomacy(_world, _owner) {
	if ((get_active_treaty(_world, _owner) != undefined) || (sim_irandom(_world, 2) != 0)) {
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
	_send.targetNation = _options[sim_irandom(_world, array_length(_options) - 1)];
	apply_command(_world, _send);
}

// A path under every city, then buy the cheapest link between them once there is spare gold
function bot_manage_paths(_world, _owner, _cities) {
	var _state = _world.nationStates[_owner];
	var _pathCost = global.buildingDefs[BUILDING.PATH].cost;
	for (var _c = 0; _c < array_length(_cities); _c++) {
		if (!tile_has_path_of(_world, _owner, _cities[_c].gx, _cities[_c].gy) && (_state.gold >= _pathCost + 40)) {
			var _build = make_command(CMD.BUILD, _owner);
			_build.buildingType = BUILDING.PATH;
			_build.gx = _cities[_c].gx;
			_build.gy = _cities[_c].gy;
			if (apply_command(_world, _build) == "") {
				return true;
			}
		}
	}
	var _cheapest = undefined;
	for (var _l = 0; _l < array_length(_world.pathLinks); _l++) {
		var _link = _world.pathLinks[_l];
		if ((_link.owner == _owner) && ((_cheapest == undefined) || (_link.cost < _cheapest.cost))) {
			_cheapest = _link;
		}
	}
	if ((_cheapest != undefined) && (_state.gold >= _cheapest.cost + 120)) {
		var _connect = make_command(CMD.CONNECT_PATH, _owner);
		_connect.gx = _cheapest.ax;
		_connect.gy = _cheapest.ay;
		_connect.targetId = _cheapest.by * _world.mapW + _cheapest.bx;
		return (apply_command(_world, _connect) == "");
	}
	return false;
}