// ============================================================
// scr_paths: paths (faster travel), links between path networks, and demolishing
//
// A path is not a building. Each tile has an owner in world.pathGrid (NO_ID = no path), so a path can
// sit underneath a building, a city or a resource. Neighbouring paths of the same nation join up
// when drawn. Two separate networks of one nation that are close enough get a "link": a line you
// can pay for, which fills in the paths between them.
// ============================================================

#macro PATH_LINK_RANGE 14
#macro PATH_LINK_BASE_COST 15
#macro PATH_LINK_TILE_COST 6
#macro DEMOLISH_REFUND 0.5
#macro PATH_FLAG 1

// ------------------------------------------------------------
// Path tiles
// ------------------------------------------------------------

// Any path at all, whoever's land it is in
function tile_has_path(_world, _gx, _gy) {
	return tile_in_bounds(_world, _gx, _gy) && (ds_grid_get(_world.pathGrid, _gx, _gy) != NO_ID);
}

// A path this nation may use: inside its own border, or outside every border
function tile_has_path_of(_world, _owner, _gx, _gy) {
	if ((_owner == NO_ID) || !tile_has_path(_world, _gx, _gy)) {
		return false;
	}
	var _border = ds_grid_get(_world.borderOwner, _gx, _gy);
	return (_border == NO_ID) || (_border == _owner);
}

function set_path_tile(_world, _owner, _gx, _gy) {
	if (ds_grid_get(_world.pathGrid, _gx, _gy) == NO_ID) {
		_world.pathTotal++;
	}
	ds_grid_set(_world.pathGrid, _gx, _gy, PATH_FLAG);
	ground_mark_dirty();
}

// A straight line between two path tiles must be land that no other nation owns
function path_line_is_clear(_world, _owner, _ax, _ay, _bx, _by) {
	var _dx = _bx - _ax;
	var _dy = _by - _ay;
	var _steps = max(abs(_dx), abs(_dy));
	for (var _i = 1; _i < _steps; _i++) {
		var _x = round(_ax + _dx * _i / _steps);
		var _y = round(_ay + _dy * _i / _steps);
		if (!tile_is_walkable(_world, _x, _y)) {
			return false;
		}
		var _border = ds_grid_get(_world.borderOwner, _x, _y);
		if ((_border != NO_ID) && (_border != _owner)) {
			return false;
		}
	}
	return true;
}

// Links are recalculated lazily: callers mark it dirty, readers call ensure_path_links
function recalc_path_links(_world) {
	_world.pathLinksDirty = true;
}

function ensure_path_links(_world) {
	if (variable_struct_exists(_world, "pathLinksDirty") && _world.pathLinksDirty) {
		rebuild_path_links(_world);
	}
}

function rebuild_path_links(_world) {
	_world.pathLinksDirty = false;
	_world.pathLinks = [];
	if (_world.pathTotal < 2) {
		return;
	}
	var _w = _world.mapW;
	var _h = _world.mapH;

	// Label each network (8 way flood fill, whoever's land it is on)
	var _label = ds_grid_create(_w, _h);
	ds_grid_clear(_label, -1);
	var _tiles = [];
	var _comps = 0;
	for (var _gx = 0; _gx < _w; _gx++) {
		for (var _gy = 0; _gy < _h; _gy++) {
			if ((ds_grid_get(_world.pathGrid, _gx, _gy) == NO_ID) || (ds_grid_get(_label, _gx, _gy) != -1)) {
				continue;
			}
			var _stack = [[_gx, _gy]];
			ds_grid_set(_label, _gx, _gy, _comps);
			while (array_length(_stack) > 0) {
				var _t = array_pop(_stack);
				array_push(_tiles, [_t[0], _t[1], _comps]);
				for (var _ox = -1; _ox <= 1; _ox++) {
					for (var _oy = -1; _oy <= 1; _oy++) {
						var _nx = _t[0] + _ox;
						var _ny = _t[1] + _oy;
						if (tile_in_bounds(_world, _nx, _ny) && (ds_grid_get(_world.pathGrid, _nx, _ny) != NO_ID) && (ds_grid_get(_label, _nx, _ny) == -1)) {
							ds_grid_set(_label, _nx, _ny, _comps);
							array_push(_stack, [_nx, _ny]);
						}
					}
				}
			}
			_comps++;
		}
	}

	// The closest clear pair of tiles for every pair of networks.
	// The nation whose land an end is on can buy the link. Land owned by two different nations cannot be linked.
	var _best = ds_map_create();
	for (var _i = 0; _i < array_length(_tiles); _i++) {
		var _a = _tiles[_i];
		var _ownA = ds_grid_get(_world.borderOwner, _a[0], _a[1]);
		for (var _ox2 = -PATH_LINK_RANGE; _ox2 <= PATH_LINK_RANGE; _ox2++) {
			for (var _oy2 = -PATH_LINK_RANGE; _oy2 <= PATH_LINK_RANGE; _oy2++) {
				var _bx = _a[0] + _ox2;
				var _by = _a[1] + _oy2;
				if (!tile_in_bounds(_world, _bx, _by) || (ds_grid_get(_world.pathGrid, _bx, _by) == NO_ID)) {
					continue;
				}
				var _compB = ds_grid_get(_label, _bx, _by);
				if (_compB <= _a[2]) {
					continue;
				}
				var _dist = max(abs(_ox2), abs(_oy2));
				var _key = _a[2] * _comps + _compB;
				var _existing = ds_map_find_value(_best, _key);
				if (!is_undefined(_existing) && (_existing.dist <= _dist)) {
					continue;
				}
				var _ownB = ds_grid_get(_world.borderOwner, _bx, _by);
				var _payer = (_ownA != NO_ID) ? _ownA : _ownB;
				if ((_payer == NO_ID) || ((_ownA != NO_ID) && (_ownB != NO_ID) && (_ownA != _ownB))) {
					continue;
				}
				if (!path_line_is_clear(_world, _payer, _a[0], _a[1], _bx, _by)) {
					continue;
				}
				ds_map_set(_best, _key, { owner: _payer, ax: _a[0], ay: _a[1], bx: _bx, by: _by, dist: _dist, cost: get_path_link_cost(_dist) });
			}
		}
	}
	var _k = ds_map_find_first(_best);
	while (!is_undefined(_k)) {
		array_push(_world.pathLinks, ds_map_find_value(_best, _k));
		_k = ds_map_find_next(_best, _k);
	}
	ds_map_destroy(_best);
	ds_grid_destroy(_label);
}

// Only land units of a nation (not tribes) get the speed bonus
function unit_can_use_paths(_unit) {
	return (_unit.owner >= 0) && (global.unitStats[_unit.type].domain == DOMAIN.LAND);
}

// Extra tiles a unit can move this step: +1 while it stands on one of its nation's paths
function get_path_move_bonus(_world, _unit) {
	if (unit_can_use_paths(_unit) && tile_has_path_of(_world, _unit.owner, _unit.gx, _unit.gy)) {
		return 1;
	}
	return 0;
}

function place_path_tile(_world, _owner, _gx, _gy) {
	set_path_tile(_world, _owner, _gx, _gy);
	audio_event(_world, "build", BUILDING.PATH, _gx, _gy, _owner);
	recalc_path_links(_world);
}

function remove_path_tile(_world, _gx, _gy) {
	if (ds_grid_get(_world.pathGrid, _gx, _gy) != NO_ID) {
		ground_mark_dirty();
		_world.pathTotal--;
		ds_grid_set(_world.pathGrid, _gx, _gy, NO_ID);
		recalc_path_links(_world);
	}
}

// ------------------------------------------------------------
// Links between path networks
// ------------------------------------------------------------

function get_path_link_cost(_dist) {
	return PATH_LINK_BASE_COST + PATH_LINK_TILE_COST * _dist;
}

// The tile in the middle of a link, where its price tag is drawn and where you click to buy it
function get_link_mid(_link) {
	return [round((_link.ax + _link.bx) / 2), round((_link.ay + _link.by) / 2)];
}

function find_path_link_at(_world, _owner, _gx, _gy) {
	ensure_path_links(_world);
	for (var _i = 0; _i < array_length(_world.pathLinks); _i++) {
		var _link = _world.pathLinks[_i];
		var _mid = get_link_mid(_link);
		if ((_link.owner == _owner) && (_mid[0] == _gx) && (_mid[1] == _gy)) {
			return _link;
		}
	}
	return undefined;
}

// _packedB is by * mapW + bx, so a command can name a link by its two end tiles
function connect_path_link(_world, _owner, _ax, _ay, _packedB) {
	ensure_path_links(_world);
	var _link = undefined;
	for (var _i = 0; _i < array_length(_world.pathLinks); _i++) {
		var _l = _world.pathLinks[_i];
		if ((_l.owner == _owner) && (_l.ax == _ax) && (_l.ay == _ay) && ((_l.by * _world.mapW + _l.bx) == _packedB)) {
			_link = _l;
			break;
		}
	}
	if (_link == undefined) {
		return "That link is no longer available";
	}
	var _state = _world.nationStates[_owner];
	if (_state.gold < _link.cost) {
		return "Not enough gold";
	}
	_state.gold -= _link.cost;
	var _dx = _link.bx - _link.ax;
	var _dy = _link.by - _link.ay;
	var _steps = max(abs(_dx), abs(_dy));
	for (var _s = 1; _s < _steps; _s++) {
		set_path_tile(_world, _owner, round(_link.ax + _dx * _s / _steps), round(_link.ay + _dy * _s / _steps));
	}
	audio_event(_world, "build", BUILDING.PATH, round((_link.ax + _link.bx) / 2), round((_link.ay + _link.by) / 2), _owner);
	recalc_path_links(_world);
	return "";
}

// ------------------------------------------------------------
// Demolishing
// ------------------------------------------------------------

function get_demolish_refund(_type) {
	return floor(global.buildingDefs[_type].cost * DEMOLISH_REFUND);
}

// A building (by id) or, when buildingId is NO_ID, the path on a tile
function demolish_target(_world, _owner, _buildingId, _gx, _gy) {
	var _state = _world.nationStates[_owner];
	if (_buildingId != NO_ID) {
		var _b = _world.buildings[_buildingId];
		if (!_b.alive || (_b.owner != _owner)) {
			return "Not your building";
		}
		_state.gold += get_demolish_refund(_b.type);
		audio_event(_world, "demolish", 0, _b.gx, _b.gy, _owner);
		remove_building(_world, _b);
		return "";
	}
	if (!tile_has_path(_world, _gx, _gy) || (ds_grid_get(_world.borderOwner, _gx, _gy) != _owner)) {
		return "Nothing of yours to demolish here";
	}
	_state.gold += get_demolish_refund(BUILDING.PATH);
	audio_event(_world, "demolish", 0, _gx, _gy, _owner);
	remove_path_tile(_world, _gx, _gy);
	return "";
}

// ------------------------------------------------------------
// Drawing
// ------------------------------------------------------------

// One path tile: a small patch, joined to the neighbours of the same nation
function draw_path_tile(_world, _gx, _gy, _cx, _cy) {
	var _col = make_colour_rgb(196, 164, 112);
	var _edge = make_colour_rgb(120, 92, 56);
	// Only four neighbours are drawn from this side, so no line is drawn twice
	var _dirX = [1, 0, 1, 1];
	var _dirY = [0, 1, 1, -1];
	for (var _d = 0; _d < 4; _d++) {
		if (tile_has_path(_world, _gx + _dirX[_d], _gy + _dirY[_d])) {
			var _nx = tile_to_world_x(_gx + _dirX[_d], _gy + _dirY[_d]);
			var _ny = tile_to_world_y(_gx + _dirX[_d], _gy + _dirY[_d]);
			draw_line_width_colour(_cx, _cy, _nx, _ny, 7, _edge, _edge);
			draw_line_width_colour(_cx, _cy, _nx, _ny, 4, _col, _col);
		}
	}
	draw_diamond(_cx, _cy, TILE_W * 0.3, TILE_H * 0.3, _edge, 1);
	draw_diamond(_cx, _cy, TILE_W * 0.24, TILE_H * 0.24, _col, 1);
}

// Dotted lines (with a price) for the links the local player can buy
function draw_path_links(_g) {
	var _world = _g.world;
	ensure_path_links(_g.world);
	if (_g.localNation == NO_ID) {
		return;
	}
	for (var _i = 0; _i < array_length(_world.pathLinks); _i++) {
		var _link = _world.pathLinks[_i];
		if (_link.owner != _g.localNation) {
			continue;
		}
		var _x1 = tile_to_world_x(_link.ax, _link.ay);
		var _y1 = tile_to_world_y(_link.ax, _link.ay);
		var _x2 = tile_to_world_x(_link.bx, _link.by);
		var _y2 = tile_to_world_y(_link.bx, _link.by);
		var _mid = get_link_mid(_link);
		var _hover = ((_g.hoverGx == _mid[0]) && (_g.hoverGy == _mid[1]));
		var _col = _hover ? c_white : make_colour_rgb(240, 215, 150);
		var _segments = max(6, _link.dist * 4);
		for (var _s = 0; _s < _segments; _s += 2) {
			draw_line_width_colour(lerp(_x1, _x2, _s / _segments), lerp(_y1, _y2, _s / _segments), lerp(_x1, _x2, (_s + 1) / _segments), lerp(_y1, _y2, (_s + 1) / _segments), 2, _col, _col);
		}
		// Price tag in the middle
		var _mx = tile_to_world_x(_mid[0], _mid[1]);
		var _my = tile_to_world_y(_mid[0], _mid[1]);
		var _label = string(_link.cost) + "g";
		var _tw = string_width(_label) * 0.6 / 2 + 5;
		draw_set_colour(c_black);
		draw_set_alpha(0.8);
		draw_rectangle(_mx - _tw, _my - 7, _mx + _tw, _my + 7, false);
		draw_set_alpha(1);
		draw_set_colour(_col);
		draw_rectangle(_mx - _tw, _my - 7, _mx + _tw, _my + 7, true);
		draw_set_halign(fa_center);
		draw_set_valign(fa_middle);
		draw_text_transformed(_mx, _my, _label, 0.6, 0.6, 0);
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
	}
	draw_set_colour(c_white);
}

// The route of every selected unit: a thin yellow line along its path, and a ring where it ends
function draw_selected_paths(_g) {
	var _world = _g.world;
	for (var _i = 0; _i < array_length(_g.selectedUnitIds); _i++) {
		var _u = _world.units[_g.selectedUnitIds[_i]];
		if (!_u.alive || (_u.order == ORDER.NONE) || (_u.pathIndex >= array_length(_u.path))) {
			continue;
		}
		var _px = tile_to_world_x(_u.visGx, _u.visGy);
		var _py = tile_to_world_y(_u.visGx, _u.visGy);
		for (var _k = _u.pathIndex; _k < array_length(_u.path); _k++) {
			var _node = _u.path[_k];
			var _nx = tile_to_world_x(_node[0], _node[1]);
			var _ny = tile_to_world_y(_node[0], _node[1]);
			draw_line_width_colour(_px, _py, _nx, _ny, 1, c_yellow, c_yellow);
			_px = _nx;
			_py = _ny;
		}
		draw_set_colour(c_yellow);
		draw_ellipse(_px - 8, _py - 4, _px + 8, _py + 4, true);
		draw_ellipse(_px - 7, _py - 3.5, _px + 7, _py + 3.5, true);
	}
	draw_set_colour(c_white);
}