// ============================================================
// scr_tiles: several units can share a tile as long as their weights fit.
// unitGrid and ghostGrid cells hold NO_ID (empty) or an array of unit ids.
//   unitGrid  = everything that stands on the ground or floats on the water
//   ghostGrid = everything that moves "above" it: aircraft and envoys
// The ghost layer ignores weight, terrain and other units completely.
// ============================================================

#macro FORMATION_RX (TILE_W * 0.36)
#macro FORMATION_RY (TILE_H * 0.36)
#macro AIR_ALTITUDE 16

// Aircraft and envoys live on the ghost layer
function unit_is_ghost(_unit) {
	var _stats = global.unitStats[_unit.type];
	return _stats.diplomat || (_stats.domain == DOMAIN.AIR);
}

function unit_is_flyer(_unit) {
	return global.unitStats[_unit.type].domain == DOMAIN.AIR;
}

function get_unit_layer_grid(_world, _unit) {
	return unit_is_ghost(_unit) ? _world.ghostGrid : _world.unitGrid;
}

// The unit ids on one tile of one layer. Always a fresh array, so it is safe to loop while units die.
function get_tile_unit_ids(_grid, _gx, _gy) {
	var _cell = ds_grid_get(_grid, _gx, _gy);
	var _ids = [];
	if (is_array(_cell)) {
		for (var _i = 0; _i < array_length(_cell); _i++) {
			array_push(_ids, _cell[_i]);
		}
	}
	return _ids;
}

function put_unit_on_tile(_world, _unit, _gx, _gy) {
	var _grid = get_unit_layer_grid(_world, _unit);
	var _list = get_tile_unit_ids(_grid, _gx, _gy);
	array_push(_list, _unit.unitId);
	ds_grid_set(_grid, _gx, _gy, _list);
}

function take_unit_off_tile(_world, _unit, _gx, _gy) {
	var _grid = get_unit_layer_grid(_world, _unit);
	var _ids = get_tile_unit_ids(_grid, _gx, _gy);
	var _kept = [];
	for (var _i = 0; _i < array_length(_ids); _i++) {
		if (_ids[_i] != _unit.unitId) {
			array_push(_kept, _ids[_i]);
		}
	}
	ds_grid_set(_grid, _gx, _gy, (array_length(_kept) > 0) ? _kept : NO_ID);
}

// The units on a tile as structs. Ground layer first, then the air layer when _includeAir is true.
function get_units_at(_world, _gx, _gy, _includeAir) {
	var _list = [];
	if (!tile_in_bounds(_world, _gx, _gy)) {
		return _list;
	}
	var _ids = get_tile_unit_ids(_world.unitGrid, _gx, _gy);
	for (var _i = 0; _i < array_length(_ids); _i++) {
		if (_world.units[_ids[_i]].alive) {
			array_push(_list, _world.units[_ids[_i]]);
		}
	}
	if (_includeAir) {
		var _airIds = get_tile_unit_ids(_world.ghostGrid, _gx, _gy);
		for (var _j = 0; _j < array_length(_airIds); _j++) {
			if (_world.units[_airIds[_j]].alive) {
				array_push(_list, _world.units[_airIds[_j]]);
			}
		}
	}
	return _list;
}

// Any one unit on the tile (ground first). Use get_units_at when every unit matters.
function get_unit_at(_world, _gx, _gy) {
	var _list = get_units_at(_world, _gx, _gy, true);
	if (array_length(_list) == 0) {
		return undefined;
	}
	return _list[0];
}

function get_tile_weight_used(_world, _gx, _gy, _ignoreId) {
	var _ids = get_tile_unit_ids(_world.unitGrid, _gx, _gy);
	var _used = 0;
	for (var _i = 0; _i < array_length(_ids); _i++) {
		if (_ids[_i] == _ignoreId) {
			continue;
		}
		_used += global.unitStats[_world.units[_ids[_i]].type].weight;
	}
	return _used;
}

// Can a unit of this type and owner stand on this tile?
// Flyers and envoys always can. Everyone else needs the weight to fit, and enemies never share a tile.
function tile_can_hold_type(_world, _owner, _type, _gx, _gy, _ignoreId) {
	if (!tile_in_bounds(_world, _gx, _gy)) {
		return false;
	}
	var _stats = global.unitStats[_type];
	if (_stats.diplomat || (_stats.domain == DOMAIN.AIR)) {
		return true;
	}
	var _limit = get_tile_weight_limit(_world, _gx, _gy);
	if (_stats.weight > _limit) {
		return false;
	}
	var _ids = get_tile_unit_ids(_world.unitGrid, _gx, _gy);
	var _used = 0;
	for (var _i = 0; _i < array_length(_ids); _i++) {
		if (_ids[_i] == _ignoreId) {
			continue;
		}
		var _other = _world.units[_ids[_i]];
		if (are_hostile(_world, _owner, _other.owner)) {
			return false;
		}
		_used += global.unitStats[_other.type].weight;
	}
	return (_used + _stats.weight) <= _limit;
}

function tile_can_hold(_world, _unit, _gx, _gy) {
	return tile_can_hold_type(_world, _unit.owner, _unit.type, _gx, _gy, _unit.unitId);
}

// Land with no unit, city or building on it (the air layer does not count)
function tile_is_free(_world, _gx, _gy) {
	if (!tile_is_walkable(_world, _gx, _gy)) {
		return false;
	}
	return (array_length(get_tile_unit_ids(_world.unitGrid, _gx, _gy)) == 0)
		&& (ds_grid_get(_world.cityGrid, _gx, _gy) == NO_ID)
		&& (ds_grid_get(_world.buildingGrid, _gx, _gy) == NO_ID);
}

// Water with no unit or building on it
function water_tile_is_free(_world, _gx, _gy) {
	if (!tile_is_water(_world, _gx, _gy)) {
		return false;
	}
	return (array_length(get_tile_unit_ids(_world.unitGrid, _gx, _gy)) == 0) && (ds_grid_get(_world.buildingGrid, _gx, _gy) == NO_ID);
}

// Where a newly bought unit appears. Empty tiles are preferred so armies fan out, but when the
// surroundings are crowded units share tiles. Returns [gx, gy] or undefined.
function find_spawn_tile(_world, _owner, _type, _gx, _gy, _maxRadius) {
	var _stats = global.unitStats[_type];
	var _flying = (_stats.domain == DOMAIN.AIR);
	var _water = (_stats.domain == DOMAIN.WATER);
	for (var _pass = 0; _pass < 2; _pass++) {
		for (var _r = 1; _r <= _maxRadius; _r++) {
			for (var _ox = -_r; _ox <= _r; _ox++) {
				for (var _oy = -_r; _oy <= _r; _oy++) {
					if (max(abs(_ox), abs(_oy)) != _r) {
						continue;
					}
					var _tx = _gx + _ox;
					var _ty = _gy + _oy;
					if (!tile_in_bounds(_world, _tx, _ty)) {
						continue;
					}
					if (_flying) {
						if ((_pass == 0) && (array_length(get_tile_unit_ids(_world.ghostGrid, _tx, _ty)) > 0)) {
							continue;
						}
						return [_tx, _ty];
					}
					if (_water) {
						if (!tile_is_water(_world, _tx, _ty) || (ds_grid_get(_world.buildingGrid, _tx, _ty) != NO_ID)) {
							continue;
						}
					} else if (!tile_is_walkable(_world, _tx, _ty) || (ds_grid_get(_world.cityGrid, _tx, _ty) != NO_ID) || (ds_grid_get(_world.buildingGrid, _tx, _ty) != NO_ID)) {
						continue;
					}
					if ((_pass == 0) && (array_length(get_tile_unit_ids(_world.unitGrid, _tx, _ty)) > 0)) {
						continue;
					}
					if (tile_can_hold_type(_world, _owner, _type, _tx, _ty, NO_ID)) {
						return [_tx, _ty];
					}
				}
			}
		}
	}
	return undefined;
}

// ------------------------------------------------------------
// Formations: units sharing a tile spread out evenly on an ellipse (a circle seen in 2:1 isometric).
// 1 = centre, 2 = left and right, 3 = triangle, 4 = diamond, 5 = pentagon, 6 = hexagon and so on.
// ------------------------------------------------------------

function get_formation_slot(_world, _unit) {
	var _cell = ds_grid_get(get_unit_layer_grid(_world, _unit), _unit.gx, _unit.gy);
	if (!is_array(_cell) || (array_length(_cell) <= 1)) {
		return { ox: 0, oy: 0, size: 1 };
	}
	var _count = array_length(_cell);
	var _index = 0;
	for (var _i = 0; _i < _count; _i++) {
		if (_cell[_i] == _unit.unitId) {
			_index = _i;
			break;
		}
	}
	var _start = ((_count mod 2) == 1) ? -90 : 0;
	var _angle = _start + _index * (360 / _count);
	var _size = 1;
	if (_count >= 6) {
		_size = 0.8;
	} else if (_count >= 4) {
		_size = 0.9;
	}
	return { ox: lengthdir_x(FORMATION_RX, _angle), oy: lengthdir_y(FORMATION_RY, _angle), size: _size };
}

// Presentation only: slides a unit toward its formation slot (called from update_units)
function update_unit_offset(_world, _unit, _dt) {
	var _cell = ds_grid_get(get_unit_layer_grid(_world, _unit), _unit.gx, _unit.gy);
	var _k = min(1, _dt * 10);
	// Alone on its tile: the common case, so no struct and no maths once it has settled
	if (!is_array(_cell) || (array_length(_cell) <= 1)) {
		if ((abs(_unit.offX) < 0.05) && (abs(_unit.offY) < 0.05) && (abs(_unit.drawScale - 1) < 0.01)) {
			_unit.offX = 0;
			_unit.offY = 0;
			_unit.drawScale = 1;
			return;
		}
		_unit.offX = lerp(_unit.offX, 0, _k);
		_unit.offY = lerp(_unit.offY, 0, _k);
		_unit.drawScale = lerp(_unit.drawScale, 1, _k);
		return;
	}
	var _slot = get_formation_slot(_world, _unit);
	_unit.offX = lerp(_unit.offX, _slot.ox, _k);
	_unit.offY = lerp(_unit.offY, _slot.oy, _k);
	_unit.drawScale = lerp(_unit.drawScale, _slot.size, _k);
}

function get_unit_draw_x(_unit) {
	return tile_to_world_x(_unit.visGx, _unit.visGy) + _unit.offX;
}

function get_unit_draw_y(_unit) {
	var _y = tile_to_world_y(_unit.visGx, _unit.visGy) + _unit.offY;
	if (global.unitStats[_unit.type].domain == DOMAIN.AIR) {
		_y -= AIR_ALTITUDE;
	}
	return _y;
}

// The ground units of one tile, back to front, ready to be drawn
function get_units_for_drawing(_world, _gx, _gy) {
	var _list = get_units_at(_world, _gx, _gy, false);
	for (var _i = 1; _i < array_length(_list); _i++) {
		var _item = _list[_i];
		var _j = _i - 1;
		while ((_j >= 0) && (_list[_j].offY > _item.offY)) {
			_list[_j + 1] = _list[_j];
			_j--;
		}
		_list[_j + 1] = _item;
	}
	return _list;
}

// Click picking. Aircraft are drawn above their tile, so one is picked when the cursor is right on it.
// Otherwise the ground unit drawn closest to the cursor on the hovered tile is picked.
function pick_unit_at_mouse(_g, _gx, _gy) {
	var _world = _g.world;
	var _best = undefined;
	var _bestDist = 12;
	for (var _ox = -2; _ox <= 2; _ox++) {
		for (var _oy = -2; _oy <= 2; _oy++) {
			if (!tile_in_bounds(_world, _gx + _ox, _gy + _oy)) {
				continue;
			}
			var _air = get_units_at(_world, _gx + _ox, _gy + _oy, true);
			for (var _i = 0; _i < array_length(_air); _i++) {
				var _a = _air[_i];
				if (!unit_is_flyer(_a)) {
					continue;
				}
				var _dist = point_distance(_g.mouseWx, _g.mouseWy, get_unit_draw_x(_a), get_unit_draw_y(_a) - 8 * SHAPE_SCALE);
				if (_dist < _bestDist) {
					_bestDist = _dist;
					_best = _a;
				}
			}
		}
	}
	if (_best != undefined) {
		return _best;
	}
	_bestDist = 99999;
	var _here = get_units_at(_world, _gx, _gy, true);
	for (var _j = 0; _j < array_length(_here); _j++) {
		var _u = _here[_j];
		if (unit_is_flyer(_u)) {
			continue;
		}
		var _d = point_distance(_g.mouseWx, _g.mouseWy, get_unit_draw_x(_u), get_unit_draw_y(_u) - 8 * SHAPE_SCALE);
		if (_d < _bestDist) {
			_bestDist = _d;
			_best = _u;
		}
	}
	return _best;
}

// ------------------------------------------------------------
// Who can hit whom
// ------------------------------------------------------------

// Aircraft can only be hit by units with hitsAir (ranged units, towers and fighters); melee cannot reach them
function unit_type_can_target(_attackerType, _targetType) {
	var _a = global.unitStats[_attackerType];
	if (global.unitStats[_targetType].domain == DOMAIN.AIR) {
		return _a.hitsAir;
	}
	return _a.hitsGround;
}

function unit_can_target(_attacker, _target) {
	return unit_type_can_target(_attacker.type, _target.type);
}

// Only the two envoy types swap between walking and sailing
function unit_is_envoy(_unit) {
	return (_unit.type == UNIT_TYPE.ENVOY) || (_unit.type == UNIT_TYPE.ENVOY_BOAT);
}