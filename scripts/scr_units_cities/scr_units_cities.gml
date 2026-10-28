// ============================================================
// scr_units_cities: units, pathfinding, combat, cities, economy and commands
// ============================================================

// Tribes can never be traded with or allied with
function can_trade_or_ally(_ownerA, _ownerB) {
	if ((_ownerA == TRIBE_OWNER) || (_ownerB == TRIBE_OWNER)) {
		return false;
	}
	return _ownerA != _ownerB;
}

// ------------------------------------------------------------
// Units
// ------------------------------------------------------------

function create_unit(_world, _owner, _type, _gx, _gy) {
	var _stats = global.unitStats[_type];
	var _unit = {
		unitId: array_length(_world.units),
		owner: _owner,
		type: _type,
		gx: _gx,
		gy: _gy,
		visGx: _gx,
		visGy: _gy,
		hp: _stats.maxHp,
		alive: true,
		actionTimer: 0.5,
		abilityTimer: 3,
		order: ORDER.NONE,
		targetId: NO_ID,
		targetNation: NO_ID,
		goalGx: _gx,
		goalGy: _gy,
		path: [],
		pathIndex: 0,
		repathTimer: 0,
		stuckCount: 0,
		// Boats: ids of the units inside. Land units: the boat that carries them (NO_ID when not aboard)
		cargo: [],
		carriedBy: NO_ID,
		// Tribe units wander around the tile they spawned on
		homeGx: _gx,
		homeGy: _gy,
		wanderTimer: sim_random_range(_world, 2, 6)
	};
	array_push(_world.units, _unit);
	if (_stats.diplomat) {
		ds_grid_set(_world.ghostGrid, _gx, _gy, _unit.unitId);
	} else {
		ds_grid_set(_world.unitGrid, _gx, _gy, _unit.unitId);
	}
	return _unit;
}

function kill_unit(_world, _unit, _killerOwner) {
	if (!_unit.alive) {
		return;
	}
	_unit.alive = false;
	_unit.order = ORDER.NONE;
	if (ds_grid_get(_world.unitGrid, _unit.gx, _unit.gy) == _unit.unitId) {
		ds_grid_set(_world.unitGrid, _unit.gx, _unit.gy, NO_ID);
	}
	if (ds_grid_get(_world.ghostGrid, _unit.gx, _unit.gy) == _unit.unitId) {
		ds_grid_set(_world.ghostGrid, _unit.gx, _unit.gy, NO_ID);
	}
	if ((_killerOwner >= 0) && (_killerOwner != _unit.owner)) {
		_world.nationStates[_killerOwner].kills++;
	}
	// Everyone aboard goes down with the boat
	var _cargo = _unit.cargo;
	_unit.cargo = [];
	for (var _i = 0; _i < array_length(_cargo); _i++) {
		var _passenger = _world.units[_cargo[_i]];
		_passenger.carriedBy = NO_ID;
		kill_unit(_world, _passenger, _killerOwner);
	}
}

// ------------------------------------------------------------
// Boats and cargo
// ------------------------------------------------------------

function unit_is_aboard(_unit) {
	return (_unit.carriedBy != NO_ID);
}

// Only land units walking on their own legs can be carried (no sea or air units, no envoys)
function unit_can_be_carried(_unit) {
	var _stats = global.unitStats[_unit.type];
	return _unit.alive && (_unit.carriedBy == NO_ID) && (_stats.domain == DOMAIN.LAND) && !_stats.passSolid && (array_length(_unit.cargo) == 0);
}

function get_boat_cargo_weight(_world, _boat) {
	var _total = 0;
	for (var _i = 0; _i < array_length(_boat.cargo); _i++) {
		_total += global.unitStats[_world.units[_boat.cargo[_i]].type].weight;
	}
	return _total;
}

// Loads every land unit of the boat's nation within 1 tile, as far as the boat's weight capacity allows
function load_boat(_world, _boat) {
	var _capacity = global.unitStats[_boat.type].capacity;
	var _used = get_boat_cargo_weight(_world, _boat);
	var _loaded = 0;
	var _full = false;
	for (var _dx = -1; _dx <= 1; _dx++) {
		for (var _dy = -1; _dy <= 1; _dy++) {
			if ((_dx == 0) && (_dy == 0)) {
				continue;
			}
			var _u = get_unit_at(_world, _boat.gx + _dx, _boat.gy + _dy);
			if ((_u == undefined) || (_u.owner != _boat.owner) || !unit_can_be_carried(_u)) {
				continue;
			}
			var _weight = global.unitStats[_u.type].weight;
			if (_used + _weight > _capacity) {
				_full = true;
				continue;
			}
			ds_grid_set(_world.unitGrid, _u.gx, _u.gy, NO_ID);
			clear_unit_order(_u);
			_u.carriedBy = _boat.unitId;
			_u.gx = _boat.gx;
			_u.gy = _boat.gy;
			array_push(_boat.cargo, _u.unitId);
			_used += _weight;
			_loaded++;
		}
	}
	if (_loaded == 0) {
		return _full ? "The boat is full" : "No land units of yours within 1 tile";
	}
	return "";
}

// A free tile within 1 tile of the boat where this unit may stand
function find_unload_tile(_world, _boat, _unit) {
	for (var _dx = -1; _dx <= 1; _dx++) {
		for (var _dy = -1; _dy <= 1; _dy++) {
			var _gx = _boat.gx + _dx;
			var _gy = _boat.gy + _dy;
			if (((_dx == 0) && (_dy == 0)) || !tile_is_free(_world, _gx, _gy)) {
				continue;
			}
			if (unit_terrain_ok(_world, _unit, _gx, _gy)) {
				return [_gx, _gy];
			}
		}
	}
	return undefined;
}

// Puts everyone aboard onto valid tiles within 1 tile. Anyone who does not fit stays aboard.
function unload_boat(_world, _boat) {
	var _remaining = [];
	var _unloaded = 0;
	for (var _i = 0; _i < array_length(_boat.cargo); _i++) {
		var _u = _world.units[_boat.cargo[_i]];
		var _spot = find_unload_tile(_world, _boat, _u);
		if (_spot == undefined) {
			array_push(_remaining, _u.unitId);
			continue;
		}
		_u.carriedBy = NO_ID;
		_u.gx = _spot[0];
		_u.gy = _spot[1];
		_u.visGx = _boat.gx;
		_u.visGy = _boat.gy;
		_u.actionTimer = 0.5;
		ds_grid_set(_world.unitGrid, _u.gx, _u.gy, _u.unitId);
		_unloaded++;
	}
	_boat.cargo = _remaining;
	if (_unloaded == 0) {
		return "No free land within 1 tile to unload onto";
	}
	return "";
}

function get_unit_at(_world, _gx, _gy) {
	if (!tile_in_bounds(_world, _gx, _gy)) {
		return undefined;
	}
	var _id = ds_grid_get(_world.unitGrid, _gx, _gy);
	if (_id == NO_ID) {
		_id = ds_grid_get(_world.ghostGrid, _gx, _gy);
	}
	if (_id == NO_ID) {
		return undefined;
	}
	return _world.units[_id];
}

function move_unit_to(_world, _unit, _gx, _gy) {
	if (unit_is_ghost(_unit)) {
		if (ds_grid_get(_world.ghostGrid, _unit.gx, _unit.gy) == _unit.unitId) {
			ds_grid_set(_world.ghostGrid, _unit.gx, _unit.gy, NO_ID);
		}
		_unit.gx = _gx;
		_unit.gy = _gy;
		ds_grid_set(_world.ghostGrid, _gx, _gy, _unit.unitId);
		// Envoys turn into a boat on water, and back into a walking envoy on land
		_unit.type = tile_is_water(_world, _gx, _gy) ? UNIT_TYPE.ENVOY_BOAT : UNIT_TYPE.ENVOY;
	} else {
		ds_grid_set(_world.unitGrid, _unit.gx, _unit.gy, NO_ID);
		_unit.gx = _gx;
		_unit.gy = _gy;
		ds_grid_set(_world.unitGrid, _gx, _gy, _unit.unitId);
	}
	// Passengers travel with the boat
	for (var _c = 0; _c < array_length(_unit.cargo); _c++) {
		var _passenger = _world.units[_unit.cargo[_c]];
		_passenger.gx = _gx;
		_passenger.gy = _gy;
	}
	// Naval mines and traps go off when an enemy lands on them
	trigger_building_on_enter(_world, _unit);
}

// Armour soaks a fraction of the damage
function damage_unit(_world, _unit, _amount, _attackerOwner) {
	if (!_unit.alive) {
		return;
	}
	register_combat(_world, _unit.gx, _unit.gy, _unit.owner, _attackerOwner);
	var _armor = global.unitStats[_unit.type].armor;
	if (_unit.owner >= 0) {
		_armor += get_research_bonus(_world, _unit.owner, RFX.ARMOR);
	}
	_unit.hp -= _amount * (1 - min(0.9, _armor));
	if (_unit.hp <= 0) {
		kill_unit(_world, _unit, _attackerOwner);
	}
}

function clear_unit_order(_unit) {
	_unit.order = ORDER.NONE;
	_unit.targetId = NO_ID;
	_unit.targetNation = NO_ID;
	_unit.path = [];
	_unit.pathIndex = 0;
	_unit.stuckCount = 0;
}

function give_move_order(_unit, _gx, _gy) {
	clear_unit_order(_unit);
	_unit.order = ORDER.MOVE;
	_unit.goalGx = _gx;
	_unit.goalGy = _gy;
	_unit.repathTimer = 0;
}

function give_attack_order(_unit, _kind, _targetId) {
	clear_unit_order(_unit);
	_unit.order = _kind;
	_unit.targetId = _targetId;
	_unit.repathTimer = 0;
}

function tile_distance(_gx1, _gy1, _gx2, _gy2) {
	return max(abs(_gx1 - _gx2), abs(_gy1 - _gy2));
}

// ------------------------------------------------------------
// Auras (healing, damage buff, attack slow)
// ------------------------------------------------------------

// Finds a unit with the given ability close enough to affect _unit.
// _friendly true = looks for allies of _unit, false = looks for enemies of _unit.
function find_aura_source(_world, _unit, _ability, _friendly) {
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _o = _world.units[_i];
		if (!_o.alive || (_o.unitId == _unit.unitId) || unit_is_aboard(_o)) {
			continue;
		}
		var _s = global.unitStats[_o.type];
		if (_s.ability != _ability) {
			continue;
		}
		var _radius = (_ability == ABILITY.SLOW) ? _s.slowRadius : _s.healRadius;
		var _related = _friendly ? (_o.owner == _unit.owner) : are_hostile(_world, _o.owner, _unit.owner);
		if (_related && (tile_distance(_o.gx, _o.gy, _unit.gx, _unit.gy) <= _radius)) {
			return _o;
		}
	}
	return undefined;
}

function get_unit_attack_damage(_world, _unit) {
	var _damage = global.unitStats[_unit.type].damage;
	var _priest = find_aura_source(_world, _unit, ABILITY.BUFF, true);
	if (_priest != undefined) {
		_damage *= global.unitStats[_priest.type].buffMult;
	}
	if (_unit.owner >= 0) {
		_damage *= 1 + get_research_bonus(_world, _unit.owner, RFX.DAMAGE);
	}
	return _damage;
}

function get_unit_attack_delay(_world, _unit) {
	var _delay = global.unitStats[_unit.type].attackDelay;
	var _arcanist = find_aura_source(_world, _unit, ABILITY.SLOW, false);
	if (_arcanist != undefined) {
		_delay *= global.unitStats[_arcanist.type].slowMult;
	}
	return _delay;
}

// ------------------------------------------------------------
// Targeting and attacking
// ------------------------------------------------------------

// The nearest enemy unit within range (envoys are ignored, they are not targetable by default)
function find_enemy_unit_near(_world, _owner, _gx, _gy, _range) {
	var _best = undefined;
	var _bestDist = 999;
	for (var _ox = -_range; _ox <= _range; _ox++) {
		for (var _oy = -_range; _oy <= _range; _oy++) {
			var _other = get_unit_at(_world, _gx + _ox, _gy + _oy);
			if ((_other == undefined) || !global.unitStats[_other.type].targetable) {
				continue;
			}
			if (!are_hostile(_world, _owner, _other.owner)) {
				continue;
			}
			var _dist = max(abs(_ox), abs(_oy));
			if (_dist < _bestDist) {
				_bestDist = _dist;
				_best = _other;
			}
		}
	}
	return _best;
}

// Looks at a unit's attack order and says whether the target is still valid, where it is, and how far away
function get_target_info(_world, _unit) {
	var _info = { valid: false, dist: 999, tx: 0, ty: 0, owner: NO_ID };
	switch (_unit.order) {
		case ORDER.ATTACK_UNIT:
			var _tu = _world.units[_unit.targetId];
			if (_tu.alive) {
				_info.valid = true;
				_info.tx = _tu.gx;
				_info.ty = _tu.gy;
				_info.owner = _tu.owner;
			}
			break;

		case ORDER.ATTACK_BUILDING:
			var _tb = _world.buildings[_unit.targetId];
			if (_tb.alive) {
				_info.valid = true;
				_info.tx = _tb.gx;
				_info.ty = _tb.gy;
				_info.owner = _tb.owner;
				if (_tb.isEdge) {
					// A wall can be hit from either side, so aim for whichever tile is closer
					var _far = edge_second_tile(_tb.gx, _tb.gy, _tb.axis);
					if (tile_distance(_unit.gx, _unit.gy, _far[0], _far[1]) < tile_distance(_unit.gx, _unit.gy, _tb.gx, _tb.gy)) {
						_info.tx = _far[0];
						_info.ty = _far[1];
					}
				}
			}
			break;

		case ORDER.ATTACK_CITY:
			var _tc = _world.cities[_unit.targetId];
			_info.valid = true;
			_info.tx = _tc.gx;
			_info.ty = _tc.gy;
			_info.owner = _tc.owner;
			break;
	}
	if (_info.valid && !are_hostile(_world, _unit.owner, _info.owner)) {
		// A peace treaty was signed, the fight is off
		_info.valid = false;
	}
	if (_info.valid) {
		_info.dist = tile_distance(_unit.gx, _unit.gy, _info.tx, _info.ty);
	}
	return _info;
}

function damage_building(_world, _b, _amount, _attackerOwner) {
	if (!_b.alive) {
		return;
	}
	register_combat(_world, _b.gx, _b.gy, _b.owner, _attackerOwner);
	_b.hp -= _amount;
	if (_b.hp <= 0) {
		remove_building(_world, _b);
		if (_attackerOwner >= 0) {
			_world.nationStates[_attackerOwner].kills++;
		}
	}
}

function strike_unit(_world, _attacker, _target) {
	var _stats = global.unitStats[_attacker.type];
	var _damage = get_unit_attack_damage(_world, _attacker);
	damage_unit(_world, _target, _damage, _attacker.owner);
	// Splash hits enemies standing next to the target for half damage
	if (_stats.splash > 0) {
		for (var _ox = -_stats.splash; _ox <= _stats.splash; _ox++) {
			for (var _oy = -_stats.splash; _oy <= _stats.splash; _oy++) {
				if ((_ox == 0) && (_oy == 0)) {
					continue;
				}
				var _near = get_unit_at(_world, _target.gx + _ox, _target.gy + _oy);
				if ((_near != undefined) && are_hostile(_world, _attacker.owner, _near.owner)) {
					damage_unit(_world, _near, _damage * 0.5, _attacker.owner);
				}
			}
		}
	}
}

function unit_perform_attack(_world, _unit) {
	var _stats = global.unitStats[_unit.type];
	switch (_unit.order) {
		case ORDER.ATTACK_UNIT:
			strike_unit(_world, _unit, _world.units[_unit.targetId]);
			break;
		case ORDER.ATTACK_BUILDING:
			damage_building(_world, _world.buildings[_unit.targetId], get_unit_attack_damage(_world, _unit) * _stats.buildingMult, _unit.owner);
			break;
		case ORDER.ATTACK_CITY:
			damage_city(_world, _world.cities[_unit.targetId], get_unit_attack_damage(_world, _unit) * _stats.buildingMult, _unit.owner);
			break;
	}
	_unit.actionTimer = get_unit_attack_delay(_world, _unit);
}

// Idle fighters shoot at the nearest enemy unit in range
function unit_auto_attack(_world, _unit, _stats) {
	var _target = find_enemy_unit_near(_world, _unit.owner, _unit.gx, _unit.gy, _stats.range);
	if (_target == undefined) {
		return;
	}
	strike_unit(_world, _unit, _target);
	_unit.actionTimer = get_unit_attack_delay(_world, _unit);
}

// ------------------------------------------------------------
// Pathfinding (A*). Every step goes through unit_step_ok, so walls, gates,
// solid buildings and terrain are all respected.
// ------------------------------------------------------------

// Returns an array of [gx, gy] tiles to walk through (not including the start tile).
// If the goal cannot be reached the path leads to the reachable tile closest to it.
function find_path(_world, _unit, _goalGx, _goalGy, _blockOccupied) {
	var _w = _world.mapW;
	var _startNode = _unit.gy * _w + _unit.gx;
	if ((_unit.gx == _goalGx) && (_unit.gy == _goalGy)) {
		return [];
	}

	// Paths make a step cheaper (the unit moves one tile further), so the search takes them
	// whenever they get the unit there sooner
	var _usePaths = (_world.pathTotal > 0) && unit_can_use_paths(_unit);
	var _pathStepCost = 1;
	if (_usePaths) {
		var _moveRange = global.unitStats[_unit.type].moveRange;
		_pathStepCost = _moveRange / (_moveRange + 1);
	}
	var _maxExpanded = _usePaths ? 9000 : 3000;

	ds_grid_clear(_world.pfCost, 999999);
	ds_grid_clear(_world.pfParent, -1);
	ds_grid_clear(_world.pfClosed, 0);
	var _open = ds_priority_create();
	ds_grid_set(_world.pfCost, _unit.gx, _unit.gy, 0);
	ds_priority_add(_open, _startNode, 0);

	var _bestNode = _startNode;
	var _bestH = tile_distance(_unit.gx, _unit.gy, _goalGx, _goalGy);
	var _expanded = 0;

	while (!ds_priority_empty(_open) && (_expanded < _maxExpanded)) {
		var _node = ds_priority_delete_min(_open);
		var _cx = _node mod _w;
		var _cy = _node div _w;
		if (ds_grid_get(_world.pfClosed, _cx, _cy) == 1) {
			continue;
		}
		ds_grid_set(_world.pfClosed, _cx, _cy, 1);
		_expanded++;

		var _h = tile_distance(_cx, _cy, _goalGx, _goalGy);
		if (_h < _bestH) {
			_bestH = _h;
			_bestNode = _node;
		}
		if ((_cx == _goalGx) && (_cy == _goalGy)) {
			_bestNode = _node;
			break;
		}

		var _g = ds_grid_get(_world.pfCost, _cx, _cy);
		var _onPath = _usePaths && tile_has_path_of(_world, _unit.owner, _cx, _cy);
		for (var _ox = -1; _ox <= 1; _ox++) {
			for (var _oy = -1; _oy <= 1; _oy++) {
				if ((_ox == 0) && (_oy == 0)) {
					continue;
				}
				var _nx = _cx + _ox;
				var _ny = _cy + _oy;
				if (!tile_in_bounds(_world, _nx, _ny) || (ds_grid_get(_world.pfClosed, _nx, _ny) == 1)) {
					continue;
				}
				if (_blockOccupied && !unit_is_ghost(_unit) && (_ny == _goalGy)) {
					var _occupant = ds_grid_get(_world.unitGrid, _nx, _ny);
					if ((_occupant != NO_ID) && (_occupant != _unit.unitId)) {
						continue;
					}
				}
				if (!unit_step_ok(_world, _unit, _cx, _cy, _nx, _ny)) {
					continue;
				}
				var _step = (_onPath && tile_has_path_of(_world, _unit.owner, _nx, _ny)) ? _pathStepCost : 1;
				var _ng = _g + _step;
				if (_ng < ds_grid_get(_world.pfCost, _nx, _ny)) {
					ds_grid_set(_world.pfCost, _nx, _ny, _ng);
					ds_grid_set(_world.pfParent, _nx, _ny, _node);
					// The small extra term makes the search lean toward the goal instead of fanning out
					var _hn = tile_distance(_nx, _ny, _goalGx, _goalGy) * _pathStepCost + 0.001 * (abs(_nx - _goalGx) + abs(_ny - _goalGy));
					ds_priority_add(_open, _ny * _w + _nx, _ng + _hn);
				}
			}
		}
	}
	ds_priority_destroy(_open);

	var _path = [];
	var _n = _bestNode;
	while ((_n != _startNode) && (_n != -1)) {
		array_insert(_path, 0, [_n mod _w, _n div _w]);
		_n = ds_grid_get(_world.pfParent, _n mod _w, _n div _w);
	}
	return _path;
}

// Walks up to moveRange tiles along the path. Returns true if the unit moved.
function unit_follow_path(_world, _unit) {
	var _stats = global.unitStats[_unit.type];
	var _count = array_length(_unit.path);
	if (_unit.pathIndex >= _count) {
		return false;
	}
	var _px = _unit.gx;
	var _py = _unit.gy;
	var _landing = -1;
	// Standing on one of your own paths adds one tile to each move
	var _range = _stats.moveRange + get_path_move_bonus(_world, _unit);
	for (var _k = 0; _k < _range; _k++) {
		var _idx = _unit.pathIndex + _k;
		if (_idx >= _count) {
			break;
		}
		var _node = _unit.path[_idx];
		if (!unit_step_ok(_world, _unit, _px, _py, _node[0], _node[1])) {
			break;
		}
		_px = _node[0];
		_py = _node[1];
		// Fast units can hop over a unit in the way, but must land on an empty tile
		var _occupant = ds_grid_get(_world.unitGrid, _px, _py);
		if ((_occupant == NO_ID) || (_occupant == _unit.unitId) || unit_is_ghost(_unit)) {
			_landing = _idx;
		}
	}
	if (_landing < 0) {
		return false;
	}
	var _dest = _unit.path[_landing];
	move_unit_to(_world, _unit, _dest[0], _dest[1]);
	_unit.pathIndex = _landing + 1;
	return true;
}

// Heads toward a tile, planning a path when needed. Returns true if the unit moved this turn.
function unit_move_toward(_world, _unit, _gx, _gy) {
	var _stats = global.unitStats[_unit.type];
	var _needsPath = (_unit.pathIndex >= array_length(_unit.path)) || (_unit.goalGx != _gx) || (_unit.goalGy != _gy) || (_unit.repathTimer <= 0);
	if (_needsPath) {
		_unit.goalGx = _gx;
		_unit.goalGy = _gy;
		// When blocked repeatedly, plan around other units too
		_unit.path = find_path(_world, _unit, _gx, _gy, _unit.stuckCount >= 2);
		_unit.pathIndex = 0;
		_unit.repathTimer = 2;
	}
	if (unit_follow_path(_world, _unit)) {
		_unit.stuckCount = 0;
		_unit.actionTimer = _stats.moveDelay;
		return true;
	}
	_unit.stuckCount++;
	_unit.actionTimer = 0.3;
	_unit.path = [];
	return false;
}

// ------------------------------------------------------------
// Per frame unit update
// ------------------------------------------------------------

function update_units(_world, _dt) {
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (!_u.alive || unit_is_aboard(_u)) {
			continue;
		}
		var _stats = global.unitStats[_u.type];

		// Smooth the drawn position toward the real tile
		_u.visGx = lerp(_u.visGx, _u.gx, min(1, _dt * 10));
		_u.visGy = lerp(_u.visGy, _u.gy, min(1, _dt * 10));

		update_unit_ability(_world, _u, _stats, _dt);

		_u.repathTimer -= _dt;
		_u.actionTimer = max(0, _u.actionTimer - _dt);
		if (_u.actionTimer > 0) {
			continue;
		}
		update_unit_order(_world, _u, _stats);
	}
}

function update_unit_order(_world, _u, _stats) {
	switch (_u.order) {
		case ORDER.NONE:
			if (_stats.damage > 0) {
				unit_auto_attack(_world, _u, _stats);
			}
			if ((_u.owner == TRIBE_OWNER) && (_u.order == ORDER.NONE)) {
				update_tribe_wander(_world, _u);
			}
			break;

		case ORDER.MOVE:
			if ((_u.gx == _u.goalGx) && (_u.gy == _u.goalGy)) {
				clear_unit_order(_u);
				break;
			}
			var _standing = get_unit_at(_world, _u.goalGx, _u.goalGy);
			if ((_standing != undefined) && (tile_distance(_u.gx, _u.gy, _u.goalGx, _u.goalGy) <= 1)) {
				// Someone else is standing on the goal, stop next to them
				clear_unit_order(_u);
				break;
			}
			unit_move_toward(_world, _u, _u.goalGx, _u.goalGy);
			if (_u.stuckCount >= 5) {
				clear_unit_order(_u);
			}
			break;

		case ORDER.ATTACK_UNIT:
		case ORDER.ATTACK_BUILDING:
		case ORDER.ATTACK_CITY:
			var _info = get_target_info(_world, _u);
			if (!_info.valid) {
				clear_unit_order(_u);
				break;
			}
			if (_info.dist <= _stats.range) {
				unit_perform_attack(_world, _u);
				break;
			}
			unit_move_toward(_world, _u, _info.tx, _info.ty);
			if (_u.stuckCount >= 5) {
				clear_unit_order(_u);
			}
			break;

		case ORDER.DELIVER:
			// Envoys walk to the capital of the nation they were sent to
			var _capital = get_capital_city(_world, _u.targetNation);
			if (_capital == undefined) {
				clear_unit_order(_u);
				break;
			}
			if (tile_distance(_u.gx, _u.gy, _capital.gx, _capital.gy) <= 1) {
				var _sender = _u.owner;
				var _receiver = _u.targetNation;
				kill_unit(_world, _u, NO_ID);
				deliver_treaty(_world, _sender, _receiver);
				break;
			}
			unit_move_toward(_world, _u, _capital.gx, _capital.gy);
			if (_u.stuckCount >= 8) {
				clear_unit_order(_u);
			}
			break;
	}
}

// Healing auras and trap laying
function update_unit_ability(_world, _u, _stats, _dt) {
	switch (_stats.ability) {
		case ABILITY.HEAL:
		case ABILITY.BUFF:
			var _r = _stats.healRadius;
			for (var _ox = -_r; _ox <= _r; _ox++) {
				for (var _oy = -_r; _oy <= _r; _oy++) {
					if ((_ox == 0) && (_oy == 0)) {
						continue;
					}
					var _ally = get_unit_at(_world, _u.gx + _ox, _u.gy + _oy);
					if ((_ally != undefined) && (_ally.owner == _u.owner)) {
						_ally.hp = min(global.unitStats[_ally.type].maxHp, _ally.hp + _stats.healRate * _dt);
					}
				}
			}
			break;

		case ABILITY.ENGINEER:
			_u.abilityTimer -= _dt;
			if ((_u.abilityTimer <= 0) && (_u.order == ORDER.NONE)) {
				_u.abilityTimer = 6;
				if (count_nation_buildings(_world, _u.owner, BUILDING.TRAP) < 12) {
					// Pick a free neighbouring tile, starting from a different direction each time
					var _start = floor(hash_2d(_u.unitId, floor(_world.time), _world.seed) * 8);
					for (var _k = 0; _k < 8; _k++) {
						var _dir = (_start + _k) mod 8;
						var _ox2 = [-1, 0, 1, -1, 1, -1, 0, 1][_dir];
						var _oy2 = [-1, -1, -1, 0, 0, 1, 1, 1][_dir];
						var _tx = _u.gx + _ox2;
						var _ty = _u.gy + _oy2;
						if (tile_is_free(_world, _tx, _ty) && (ds_grid_get(_world.habitable, _tx, _ty) != 1)) {
							create_building(_world, _u.owner, BUILDING.TRAP, _tx, _ty, -1);
							break;
						}
					}
				}
			}
			break;
	}
}

// ------------------------------------------------------------
// Cities
// ------------------------------------------------------------

function get_city_max_hp(_level) {
	return 200 + 80 * _level;
}

function create_city(_world, _owner, _gx, _gy) {
	var _state = _world.nationStates[_owner];
	var _names = global.nations[_owner].cityNames;
	var _idx = _state.cityNameIndex;
	var _name = _names[_idx mod array_length(_names)];
	// Once the name list runs out, add a numeral so names stay unique
	if (_idx >= array_length(_names)) {
		_name += " " + string(floor(_idx / array_length(_names)) + 1);
	}
	_state.cityNameIndex++;

	var _city = {
		cityId: array_length(_world.cities),
		owner: _owner,
		gx: _gx,
		gy: _gy,
		level: 1,
		cityName: _name,
		hp: get_city_max_hp(1),
		maxHp: get_city_max_hp(1)
	};
	array_push(_world.cities, _city);
	ds_grid_set(_world.cityGrid, _gx, _gy, _city.cityId);
	return _city;
}

function get_city_upgrade_cost(_city) {
	return _city.level * 60;
}

function get_city_income(_city) {
	// Gold per second
	return 0.5 + 0.5 * _city.level;
}

function count_nation_cities(_world, _owner) {
	var _count = 0;
	for (var _i = 0; _i < array_length(_world.cities); _i++) {
		if (_world.cities[_i].owner == _owner) {
			_count++;
		}
	}
	return _count;
}

// The capital is the city a nation started with, unless it was lost
function get_capital_city(_world, _owner) {
	if ((_owner < 0) || (_owner >= MAX_NATIONS)) {
		return undefined;
	}
	var _id = _world.nationStates[_owner].capitalId;
	if ((_id != NO_ID) && (_world.cities[_id].owner == _owner)) {
		return _world.cities[_id];
	}
	return undefined;
}

// After losing the capital, the highest level city takes over
function reassign_capital(_world, _owner) {
	var _best = undefined;
	for (var _i = 0; _i < array_length(_world.cities); _i++) {
		var _c = _world.cities[_i];
		if ((_c.owner == _owner) && ((_best == undefined) || (_c.level > _best.level))) {
			_best = _c;
		}
	}
	if (_best == undefined) {
		_world.nationStates[_owner].capitalId = NO_ID;
		return;
	}
	_world.nationStates[_owner].capitalId = _best.cityId;
	push_notice(_world, _owner, _best.cityName + " is your new capital");
}

function damage_city(_world, _city, _amount, _attackerOwner) {
	register_combat(_world, _city.gx, _city.gy, _city.owner, _attackerOwner);
	_city.hp -= _amount;
	if (_city.hp <= 0) {
		capture_city(_world, _city, _attackerOwner);
	}
}

function capture_city(_world, _city, _newOwner) {
	var _oldOwner = _city.owner;
	_city.owner = _newOwner;
	_city.level = max(1, _city.level - 1);
	_city.maxHp = get_city_max_hp(_city.level);
	_city.hp = floor(_city.maxHp * 0.4);
	if (_newOwner >= 0) {
		_world.nationStates[_newOwner].captures++;
	}
	recalculate_borders(_world);

	// Buildings that now sit inside the new owner's border change hands
	for (var _i = 0; _i < array_length(_world.buildings); _i++) {
		var _b = _world.buildings[_i];
		if (!_b.alive || (_b.owner != _oldOwner)) {
			continue;
		}
		var _taken = (ds_grid_get(_world.borderOwner, _b.gx, _b.gy) == _newOwner);
		if (_b.isEdge) {
			var _far = edge_second_tile(_b.gx, _b.gy, _b.axis);
			_taken = _taken || (ds_grid_get(_world.borderOwner, _far[0], _far[1]) == _newOwner);
		}
		if (_taken) {
			_b.owner = _newOwner;
		}
	}

	push_notice(_world, NOTICE_ALL, get_owner_name(_newOwner) + " captured " + _city.cityName);
	if (_world.nationStates[_oldOwner].capitalId == _city.cityId) {
		reassign_capital(_world, _oldOwner);
	}
	if (count_nation_cities(_world, _oldOwner) == 0) {
		eliminate_nation(_world, _oldOwner);
	}
}

// A nation with no cities left loses
function eliminate_nation(_world, _owner) {
	var _state = _world.nationStates[_owner];
	if (_state.eliminated) {
		return;
	}
	_state.eliminated = true;
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		if (_world.units[_i].alive && (_world.units[_i].owner == _owner)) {
			kill_unit(_world, _world.units[_i], NO_ID);
		}
	}
	for (var _j = 0; _j < array_length(_world.buildings); _j++) {
		if (_world.buildings[_j].alive && (_world.buildings[_j].owner == _owner)) {
			remove_building(_world, _world.buildings[_j]);
		}
	}
	for (var _t = array_length(_world.treaties) - 1; _t >= 0; _t--) {
		var _treaty = _world.treaties[_t];
		if ((_treaty.a == _owner) || (_treaty.b == _owner)) {
			array_delete(_world.treaties, _t, 1);
		}
	}
	push_notice(_world, NOTICE_ALL, get_owner_name(_owner) + " has been eliminated");

	// Last nation standing wins
	var _alive = 0;
	var _last = NO_ID;
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		if (_world.nationStates[_n].active && !_world.nationStates[_n].eliminated) {
			_alive++;
			_last = _n;
		}
	}
	if (_alive == 1) {
		_world.winner = _last;
		push_notice(_world, NOTICE_ALL, get_owner_name(_last) + " wins the game!");
	}
}

function update_cities(_world, _dt) {
	for (var _i = 0; _i < array_length(_world.cities); _i++) {
		var _c = _world.cities[_i];
		_c.hp = min(_c.maxHp, _c.hp + _dt);
	}
}

// ------------------------------------------------------------
// Economy
// ------------------------------------------------------------

function get_nation_income(_world, _owner) {
	var _total = 0;
	for (var _i = 0; _i < array_length(_world.cities); _i++) {
		if (_world.cities[_i].owner == _owner) {
			_total += get_city_income(_world.cities[_i]);
		}
	}
	for (var _j = 0; _j < array_length(_world.buildings); _j++) {
		var _b = _world.buildings[_j];
		if (_b.alive && (_b.owner == _owner)) {
			_total += get_building_income(_b);
		}
	}
	return _total * (1 + get_research_bonus(_world, _owner, RFX.GOLD));
}

// Sum of the passive bonuses (see RFX) from everything the nation has researched
function get_research_bonus(_world, _owner, _fx) {
	if ((_owner < 0) || (_owner >= MAX_NATIONS)) {
		return 0;
	}
	var _researched = _world.nationStates[_owner].researched;
	var _total = 0;
	for (var _r = 0; _r < RESEARCH.COUNT; _r++) {
		var _def = global.researchDefs[_r];
		if (_researched[_r] && (_def.fx == _fx)) {
			_total += _def.amount;
		}
	}
	return _total;
}

// Tribes idle by walking to a random tile 1 or 2 tiles from where they started,
// so anyone who builds near a camp gets visited
function update_tribe_wander(_world, _u) {
	if (_world.time < _u.wanderTimer) {
		return;
	}
	_u.wanderTimer = _world.time + sim_random_range(_world, 3, 7);
	for (var _try = 0; _try < 6; _try++) {
		var _gx = _u.homeGx + sim_irandom_range(_world, -2, 2);
		var _gy = _u.homeGy + sim_irandom_range(_world, -2, 2);
		if (tile_distance(_gx, _gy, _u.gx, _u.gy) == 0) {
			continue;
		}
		if (tile_is_free(_world, _gx, _gy) && unit_terrain_ok(_world, _u, _gx, _gy)) {
			give_move_order(_u, _gx, _gy);
			return;
		}
	}
}

function get_rp_rate(_world, _owner) {
	return BASE_RP_RATE + get_nation_lab_rate(_world, _owner) + get_research_bonus(_world, _owner, RFX.RP);
}

function update_economy(_world, _dt) {
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		var _state = _world.nationStates[_n];
		if (_state.active && !_state.eliminated) {
			_state.gold += get_nation_income(_world, _n) * _dt;
			_state.rp += get_rp_rate(_world, _n) * _dt;
		}
	}
}

function update_world(_world, _dt) {
	_world.time += _dt;
	update_units(_world, _dt);
	update_buildings(_world, _dt);
	update_cities(_world, _dt);
	update_economy(_world, _dt);
	update_treaties(_world, _dt);
	_world.statsTimer -= _dt;
	if (_world.statsTimer <= 0) {
		_world.statsTimer = 1;
		update_nation_stats(_world);
	}
	update_battles(_world, _dt);
	update_bots(_world, _dt);
}

// ------------------------------------------------------------
// Buying units
// ------------------------------------------------------------

// Which building type sells units for each source
function get_building_unit_source(_buildingType) {
	switch (_buildingType) {
		case BUILDING.BARRACKS: return UNIT_SRC.BARRACKS;
		case BUILDING.GARRISON: return UNIT_SRC.GARRISON;
		case BUILDING.HOSPITAL: return UNIT_SRC.HOSPITAL;
		case BUILDING.PORT: return UNIT_SRC.PORT;
		case BUILDING.EMBASSY: return UNIT_SRC.EMBASSY;
	}
	return NO_ID;
}

// Returns "" when the unit can be bought, otherwise the reason it is locked.
// _sourceLevel is the level of the city or building doing the selling.
function get_unit_lock_reason(_world, _owner, _type, _sourceLevel) {
	var _stats = global.unitStats[_type];
	if ((_stats.reqResearch != NO_ID) && !nation_has_research(_world, _owner, _stats.reqResearch)) {
		return "Needs: " + global.researchDefs[_stats.reqResearch].researchName;
	}
	if ((_stats.source == UNIT_SRC.CITY_HALL) && (_sourceLevel < _stats.reqCityLevel)) {
		return "Needs City Lv " + string(_stats.reqCityLevel);
	}
	if ((_stats.source == UNIT_SRC.BARRACKS) && (_sourceLevel < _stats.reqBuildingLevel)) {
		return "Needs Barracks Lv " + string(_stats.reqBuildingLevel);
	}
	return "";
}

function spawn_unit_near(_world, _owner, _type, _gx, _gy) {
	var _tile;
	if (global.unitStats[_type].domain == DOMAIN.WATER) {
		_tile = find_free_water_near(_world, _gx, _gy, 2);
	} else {
		_tile = find_free_tile_near(_world, _gx, _gy, 2);
	}
	if (_tile == undefined) {
		return undefined;
	}
	var _spawned = create_unit(_world, _owner, _type, _tile[0], _tile[1]);
	audio_event(_world, "spawn", _type, _tile[0], _tile[1], _owner);
	return _spawned;
}

// ------------------------------------------------------------
// Commands (the single entry point for every player or bot action)
// Returns "" on success, or a short message explaining why it failed.
// ------------------------------------------------------------

function make_command(_type, _owner) {
	return {
		type: _type,
		owner: _owner,
		unitIds: [],
		cityId: NO_ID,
		buildingId: NO_ID,
		buildingType: BUILDING.BARRACKS,
		unitType: UNIT_TYPE.EXPLORER,
		researchId: NO_ID,
		targetKind: ORDER.ATTACK_UNIT,
		targetId: NO_ID,
		targetNation: NO_ID,
		flag: false,
		text: "",
		gx: 0,
		gy: 0,
		axis: 0
	};
}

function apply_command(_world, _cmd) {
	var _state = _world.nationStates[_cmd.owner];
	if (_state.eliminated) {
		return "Your nation has fallen";
	}
	if (_world.winner != NO_ID) {
		return "The game is over";
	}

	switch (_cmd.type) {
		case CMD.MOVE:
			var _moved = 0;
			for (var _i = 0; _i < array_length(_cmd.unitIds); _i++) {
				var _u = _world.units[_cmd.unitIds[_i]];
				if (_u.alive && !unit_is_aboard(_u) && (_u.owner == _cmd.owner) && unit_terrain_ok(_world, _u, _cmd.gx, _cmd.gy)) {
					give_move_order(_u, _cmd.gx, _cmd.gy);
					_moved++;
				}
			}
			if (_moved == 0) {
				return "Units cannot go there";
			}
			return "";

		case CMD.ATTACK:
			// targetKind is ORDER.ATTACK_UNIT, ORDER.ATTACK_BUILDING or ORDER.ATTACK_CITY
			var _targetOwner = NO_ID;
			if (_cmd.targetKind == ORDER.ATTACK_UNIT) {
				var _tu = _world.units[_cmd.targetId];
				if (!_tu.alive) {
					return "Invalid target";
				}
				_targetOwner = _tu.owner;
			} else if (_cmd.targetKind == ORDER.ATTACK_BUILDING) {
				var _tb = _world.buildings[_cmd.targetId];
				if (!_tb.alive || !building_visible_to(_world, _tb, _cmd.owner)) {
					return "Invalid target";
				}
				_targetOwner = _tb.owner;
			} else {
				_targetOwner = _world.cities[_cmd.targetId].owner;
			}
			if (!are_hostile(_world, _cmd.owner, _targetOwner)) {
				return "You are at peace with them";
			}
			var _attackers = 0;
			for (var _a = 0; _a < array_length(_cmd.unitIds); _a++) {
				var _atk = _world.units[_cmd.unitIds[_a]];
				if (_atk.alive && !unit_is_aboard(_atk) && (_atk.owner == _cmd.owner) && (global.unitStats[_atk.type].damage > 0)) {
					give_attack_order(_atk, _cmd.targetKind, _cmd.targetId);
					_attackers++;
				}
			}
			if (_attackers == 0) {
				return "These units cannot attack";
			}
			return "";

		case CMD.FOUND_CITY:
			var _explorer = _world.units[_cmd.unitIds[0]];
			if (!_explorer.alive || (_explorer.owner != _cmd.owner) || (_explorer.type != UNIT_TYPE.EXPLORER)) {
				return "Only explorers can found cities";
			}
			if (ds_grid_get(_world.habitable, _explorer.gx, _explorer.gy) != 1) {
				return "This tile is not habitable";
			}
			if (ds_grid_get(_world.cityGrid, _explorer.gx, _explorer.gy) != NO_ID) {
				return "There is already a city here";
			}
			var _borderOwner = ds_grid_get(_world.borderOwner, _explorer.gx, _explorer.gy);
			if ((_borderOwner != NO_ID) && (_borderOwner != _cmd.owner)) {
				return "This land belongs to another nation";
			}
			var _fx = _explorer.gx;
			var _fy = _explorer.gy;
			kill_unit(_world, _explorer, NO_ID);
			var _founded = create_city(_world, _cmd.owner, _fx, _fy);
			if (_state.capitalId == NO_ID) {
				_state.capitalId = _founded.cityId;
			}
			recalculate_borders(_world);
			return "";

		case CMD.BUY_UNIT:
			var _city = _world.cities[_cmd.cityId];
			var _buyStats = global.unitStats[_cmd.unitType];
			if (_city.owner != _cmd.owner) {
				return "Not your city";
			}
			if (_buyStats.source != UNIT_SRC.CITY_HALL) {
				return "The city hall does not sell this";
			}
			var _lock = get_unit_lock_reason(_world, _cmd.owner, _cmd.unitType, _city.level);
			if (_lock != "") {
				return _lock;
			}
			if (_state.gold < _buyStats.cost) {
				return "Not enough gold";
			}
			if (spawn_unit_near(_world, _cmd.owner, _cmd.unitType, _city.gx, _city.gy) == undefined) {
				return "No room around the city";
			}
			_state.gold -= _buyStats.cost;
			return "";

		case CMD.TRAIN_UNIT:
			var _site = _world.buildings[_cmd.buildingId];
			var _trainStats = global.unitStats[_cmd.unitType];
			if (!_site.alive || (_site.owner != _cmd.owner)) {
				return "Not your building";
			}
			if (get_building_unit_source(_site.type) != _trainStats.source) {
				return "This building does not sell that";
			}
			var _trainLock = get_unit_lock_reason(_world, _cmd.owner, _cmd.unitType, _site.level);
			if (_trainLock != "") {
				return _trainLock;
			}
			if (_state.gold < _trainStats.cost) {
				return "Not enough gold";
			}
			if (spawn_unit_near(_world, _cmd.owner, _cmd.unitType, _site.gx, _site.gy) == undefined) {
				return "No room around the building";
			}
			_state.gold -= _trainStats.cost;
			return "";

		case CMD.UPGRADE_CITY:
			var _up = _world.cities[_cmd.cityId];
			if (_up.owner != _cmd.owner) {
				return "Not your city";
			}
			if (_up.level >= MAX_CITY_LEVEL) {
				return "City is at max level";
			}
			var _upCost = get_city_upgrade_cost(_up);
			if (_state.gold < _upCost) {
				return "Not enough gold";
			}
			_state.gold -= _upCost;
			_up.level++;
			_up.maxHp = get_city_max_hp(_up.level);
			_up.hp = min(_up.maxHp, _up.hp + 80);
			audio_event(_world, "upgrade", 0, _up.gx, _up.gy, _cmd.owner);
			recalculate_borders(_world);
			return "";

		case CMD.BUILD:
			var _buildDef = global.buildingDefs[_cmd.buildingType];
			var _why = can_place_building(_world, _cmd.owner, _cmd.buildingType, _cmd.gx, _cmd.gy, _cmd.axis);
			if (_why != "") {
				return _why;
			}
			if (_state.gold < _buildDef.cost) {
				return "Not enough gold";
			}
			_state.gold -= _buildDef.cost;
			if (_buildDef.place == PLACE.PATH) {
				place_path_tile(_world, _cmd.owner, _cmd.gx, _cmd.gy);
			} else {
				create_building(_world, _cmd.owner, _cmd.buildingType, _cmd.gx, _cmd.gy, _cmd.axis);
			}
			return "";

		case CMD.UPGRADE_BUILDING:
			var _ub = _world.buildings[_cmd.buildingId];
			if (!_ub.alive || (_ub.owner != _cmd.owner)) {
				return "Not your building";
			}
			if (_ub.level >= global.buildingDefs[_ub.type].maxLevel) {
				return "Already at max level";
			}
			var _ubCost = get_building_upgrade_cost(_ub);
			if (_state.gold < _ubCost) {
				return "Not enough gold";
			}
			_state.gold -= _ubCost;
			_ub.level++;
			audio_event(_world, "upgrade", 0, _ub.gx, _ub.gy, _cmd.owner);
			var _newMax = get_building_max_hp(_ub.type, _ub.level);
			_ub.hp += _newMax - _ub.maxHp;
			_ub.maxHp = _newMax;
			return "";

		case CMD.RESEARCH:
			var _rdef = global.researchDefs[_cmd.researchId];
			if (_state.researched[_cmd.researchId]) {
				return "Already researched";
			}
			if ((_rdef.prereq != NO_ID) && !_state.researched[_rdef.prereq]) {
				return "Needs: " + global.researchDefs[_rdef.prereq].researchName;
			}
			if (_state.rp < _rdef.cost) {
				return "Not enough research points";
			}
			_state.rp -= _rdef.cost;
			_state.researched[_cmd.researchId] = true;
			return "";

		case CMD.SEND_ENVOY:
			var _embassy = _world.buildings[_cmd.buildingId];
			var _envoyStats = global.unitStats[UNIT_TYPE.ENVOY];
			if (!_embassy.alive || (_embassy.owner != _cmd.owner) || (_embassy.type != BUILDING.EMBASSY)) {
				return "You need an embassy";
			}
			var _target = _cmd.targetNation;
			if ((_target < 0) || (_target >= MAX_NATIONS) || (_target == _cmd.owner) || !_world.nationStates[_target].active || _world.nationStates[_target].eliminated) {
				return "No such nation";
			}
			if (get_treaty_between(_world, _cmd.owner, _target) != undefined) {
				return "You already have a treaty with them";
			}
			if (get_active_treaty(_world, _cmd.owner) != undefined) {
				return "You already have a treaty. Declare war first";
			}
			if (get_capital_city(_world, _target) == undefined) {
				return "They have no capital";
			}
			if (_state.gold < _envoyStats.cost) {
				return "Not enough gold";
			}
			var _envoy = spawn_unit_near(_world, _cmd.owner, UNIT_TYPE.ENVOY, _embassy.gx, _embassy.gy);
			if (_envoy == undefined) {
				return "No room around the embassy";
			}
			_state.gold -= _envoyStats.cost;
			clear_unit_order(_envoy);
			_envoy.order = ORDER.DELIVER;
			_envoy.targetNation = _target;
			return "";

		case CMD.PLACE_MINE:
			var _boat = _world.units[_cmd.unitIds[0]];
			var _mineDef = global.buildingDefs[BUILDING.NAVAL_MINE];
			if (!_boat.alive || (_boat.owner != _cmd.owner) || (_boat.type != UNIT_TYPE.BUILDING_BOAT)) {
				return "Only Building Boats place mines";
			}
			if (!nation_has_research(_world, _cmd.owner, RESEARCH.NAVAL_MINES)) {
				return "Needs: Naval Mines";
			}
			if (ds_grid_get(_world.buildingGrid, _boat.gx, _boat.gy) != NO_ID) {
				return "There is already a mine here";
			}
			if (_state.gold < _mineDef.cost) {
				return "Not enough gold";
			}
			_state.gold -= _mineDef.cost;
			create_building(_world, _cmd.owner, BUILDING.NAVAL_MINE, _boat.gx, _boat.gy, -1);
			return "";
			
		case CMD.TOGGLE_CARGO:
			// A boat with passengers unloads them, an empty boat loads whatever land units are next to it
			var _handled = 0;
			var _cargoMsg = "";
			for (var _b = 0; _b < array_length(_cmd.unitIds); _b++) {
				var _carrier = _world.units[_cmd.unitIds[_b]];
				if (!_carrier.alive || (_carrier.owner != _cmd.owner) || (global.unitStats[_carrier.type].capacity <= 0)) {
					continue;
				}
				_handled++;
				var _res = (array_length(_carrier.cargo) > 0) ? unload_boat(_world, _carrier) : load_boat(_world, _carrier);
				if (_res != "") {
					_cargoMsg = _res;
				} else {
					_cargoMsg = "";
				}
			}
			if (_handled == 0) {
				return "Select a Traveler Boat first";
			}
			return _cargoMsg;

		case CMD.CONNECT_PATH:
			return connect_path_link(_world, _cmd.owner, _cmd.gx, _cmd.gy, _cmd.targetId);

		case CMD.DEMOLISH:
			return demolish_target(_world, _cmd.owner, _cmd.buildingId, _cmd.gx, _cmd.gy);

		case CMD.DECLARE_WAR:
			return declare_war(_world, _cmd.owner, _cmd.targetNation, false);

		case CMD.ANSWER_OFFER:
			return answer_offer(_world, _cmd.owner, _cmd.flag);
			
		case CMD.RENAME_CITY:
			if ((_cmd.cityId < 0) || (_cmd.cityId >= array_length(_world.cities))) {
				return "No such city";
			}
			var _renamed = _world.cities[_cmd.cityId];
			if (_renamed.owner != _cmd.owner) {
				return "Not your city";
			}
			var _newName = clean_city_name(_cmd.text);
			if (_newName == "") {
				return "Enter a name";
			}
			_renamed.cityName = _newName;
			return "";
	}
	return "Unknown command";
}

// Envoys live on their own layer, so they walk through other units
function unit_is_ghost(_unit) {
	return global.unitStats[_unit.type].diplomat;
}