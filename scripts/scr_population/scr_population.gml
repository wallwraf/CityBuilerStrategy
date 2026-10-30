// ============================================================
// scr_population: how many units a nation may have
// cap = base + capital level bonus + housing. Every unit has a popCost (envoys and explorers cost 0).
// The calc_ functions read the world and are used by commands (they must be exact on every machine).
// get_pop_cached is for the HUD only, so it never loops over every unit many times per frame.
// ============================================================

#macro POP_BASE 15
#macro POP_PER_CAPITAL_LEVEL 4
#macro HOUSING_MAX 8
#macro HOUSING_POP_PER_LEVEL 3
#macro POP_COST_DIVISOR 120

// Called from init_expansion after apply_balance_changes
function init_population_costs() {
	for (var _t = 0; _t < UNIT_TYPE.COUNT; _t++) {
		var _s = global.unitStats[_t];
		_s.popCost = max(1, round(_s.cost / POP_COST_DIVISOR));
	}
	// They vanish after their job, so they never count
	global.unitStats[UNIT_TYPE.EXPLORER].popCost = 0;
	global.unitStats[UNIT_TYPE.ENVOY].popCost = 0;
	global.unitStats[UNIT_TYPE.ENVOY_BOAT].popCost = 0;
	// Hand tuned
	global.unitStats[UNIT_TYPE.BIPLANE].popCost = 3;
	global.unitStats[UNIT_TYPE.HEAVY_BOMBER].popCost = 10;
}

function calc_nation_pop_used(_world, _owner) {
	var _used = 0;
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (_u.alive && (_u.owner == _owner)) {
			_used += global.unitStats[_u.type].popCost;
		}
	}
	return _used;
}

function calc_nation_pop_cap(_world, _owner) {
	var _cap = POP_BASE;
	var _capital = get_capital_city(_world, _owner);
	if (_capital != undefined) {
		_cap += (_capital.level - 1) * POP_PER_CAPITAL_LEVEL;
	}
	for (var _i = 0; _i < array_length(_world.buildings); _i++) {
		var _b = _world.buildings[_i];
		if (_b.alive && (_b.owner == _owner) && (_b.type == BUILDING.HOUSING)) {
			_cap += _b.level * HOUSING_POP_PER_LEVEL;
		}
	}
	return _cap;
}

// "" when one more unit of this type fits, otherwise the reason
function get_pop_block_reason(_world, _owner, _type) {
	var _cost = global.unitStats[_type].popCost;
	if (_cost <= 0) {
		return "";
	}
	var _used = calc_nation_pop_used(_world, _owner);
	var _cap = calc_nation_pop_cap(_world, _owner);
	if (_used + _cost > _cap) {
		return "Population full (" + string(_used) + "/" + string(_cap) + ")";
	}
	return "";
}

// HUD only: { used, cap }, refreshed at most every 150 ms per nation
function get_pop_cached(_world, _owner) {
	if (!variable_global_exists("popCache")) {
		global.popCache = { world: undefined, stamp: array_create(MAX_NATIONS, -9999), used: array_create(MAX_NATIONS, 0), cap: array_create(MAX_NATIONS, POP_BASE) };
	}
	var _c = global.popCache;
	if (_c.world != _world) {
		_c.world = _world;
		array_resize(_c.stamp, 0);
		_c.stamp = array_create(MAX_NATIONS, -9999);
	}
	if (current_time - _c.stamp[_owner] > 150) {
		_c.stamp[_owner] = current_time;
		_c.used[_owner] = calc_nation_pop_used(_world, _owner);
		_c.cap[_owner] = calc_nation_pop_cap(_world, _owner);
	}
	return { used: _c.used[_owner], cap: _c.cap[_owner] };
}