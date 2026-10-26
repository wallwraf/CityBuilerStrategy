// ============================================================
// scr_camera_input: camera, zoom, panning and all mouse input
// _g is the obj_game instance (we pass it in so these scripts can read its variables)
//
// Controls:
//   Left click          select unit / city / building, or give a move or attack order
//   Left click + drag   box select your units
//   Shift + left click  add or remove a unit from the selection
//   Middle drag         pan the camera
//   Middle scroll       zoom
//   Right click         cancel placing a building, or deselect all
//   Escape              cancel placing a building
// ============================================================

function camera_init(_g) {
	_g.screenW = window_get_width();
	_g.screenH = window_get_height();
	// Zoom 2 shows 32x32 pixel art at a comfortable size
	_g.zoom = 2;
	_g.camX = 0;
	_g.camY = 0;

	view_enabled = true;
	view_visible[0] = true;
	// camera_create_view is needed here, plain camera_create ignores the view position and size
	_g.cam = camera_create_view(0, 0, _g.screenW, _g.screenH);
	view_camera[0] = _g.cam;
	camera_update_size(_g, true);
}

// Keeps the view matched to the window size (so 1 world pixel = 1 screen pixel at zoom 1)
function camera_update_size(_g, _force) {
	var _w = window_get_width();
	var _h = window_get_height();
	if ((_w <= 0) || (_h <= 0)) {
		return;
	}
	if (_force || (_w != _g.screenW) || (_h != _g.screenH)) {
		_g.screenW = _w;
		_g.screenH = _h;
		view_wport[0] = _w;
		view_hport[0] = _h;
		surface_resize(application_surface, _w, _h);
		display_set_gui_size(_w, _h);
	}
	camera_refresh_view(_g);
}

function camera_refresh_view(_g) {
	camera_set_view_pos(_g.cam, _g.camX, _g.camY);
	camera_set_view_size(_g.cam, _g.screenW / _g.zoom, _g.screenH / _g.zoom);
}

function camera_focus_tile(_g, _gx, _gy) {
	_g.camX = tile_to_world_x(_gx, _gy) - (_g.screenW / _g.zoom) / 2;
	_g.camY = tile_to_world_y(_gx, _gy) - (_g.screenH / _g.zoom) / 2;
	camera_refresh_view(_g);
}

function set_toast(_g, _text) {
	_g.toastText = _text;
	_g.toastTimer = 2.5;
}

function id_in_list(_list, _id) {
	for (var _i = 0; _i < array_length(_list); _i++) {
		if (_list[_i] == _id) {
			return true;
		}
	}
	return false;
}

// Drops units that have died from the selection
function prune_selection(_g) {
	var _kept = [];
	for (var _i = 0; _i < array_length(_g.selectedUnitIds); _i++) {
		if (_g.world.units[_g.selectedUnitIds[_i]].alive) {
			array_push(_kept, _g.selectedUnitIds[_i]);
		}
	}
	_g.selectedUnitIds = _kept;
}

function update_input(_g) {
	// GUI coordinates match the window pixels the HUD is drawn in
	var _mx = device_mouse_x_to_gui(0);
	var _my = device_mouse_y_to_gui(0);
	var _wx = _g.camX + _mx / _g.zoom;
	var _wy = _g.camY + _my / _g.zoom;

	// Zoom toward the cursor (not while the cursor is over the HUD)
	var _wheel = mouse_wheel_up() - mouse_wheel_down();
	if ((_wheel != 0) && !hud_captures_mouse(_g, _mx, _my)) {
		_g.zoom = clamp(_g.zoom * power(1.15, _wheel), MIN_ZOOM, MAX_ZOOM);
		_g.camX = _wx - _mx / _g.zoom;
		_g.camY = _wy - _my / _g.zoom;
	}

	// Pan: keep the point that was under the cursor when the drag started under the cursor
	if (mouse_check_button_pressed(mb_middle)) {
		_g.panning = true;
		_g.panAnchorX = _wx;
		_g.panAnchorY = _wy;
	}
	if (!mouse_check_button(mb_middle)) {
		_g.panning = false;
	}
	if (_g.panning) {
		_g.camX = _g.panAnchorX - _mx / _g.zoom;
		_g.camY = _g.panAnchorY - _my / _g.zoom;
	}
	camera_refresh_view(_g);

	// Mouse position in the world after the camera moved
	_wx = _g.camX + _mx / _g.zoom;
	_wy = _g.camY + _my / _g.zoom;
	_g.mouseWx = _wx;
	_g.mouseWy = _wy;
	_g.hoverGx = round(world_to_tile_gx(_wx, _wy));
	_g.hoverGy = round(world_to_tile_gy(_wx, _wy));

	// Nothing else to do if there is no local player (spectating)
	if (_g.localNation == NO_ID) {
		return;
	}

	prune_selection(_g);
	update_placement_preview(_g);

	// Escape cancels placing a building
	if (keyboard_check_pressed(vk_escape)) {
		_g.placeType = NO_ID;
	}

	// Right click: cancel placing, otherwise deselect all
	if (mouse_check_button_pressed(mb_right)) {
		if (_g.placeType != NO_ID) {
			_g.placeType = NO_ID;
		} else {
			clear_selection(_g);
		}
		_g.dragging = false;
	}

	// Left press: either a HUD button or the start of a click / drag
	if (mouse_check_button_pressed(mb_left)) {
		var _button = get_hud_button_at(_g, _mx, _my);
		if (_button != undefined) {
			_g.uiCapture = true;
			execute_hud_button(_g, _button);
		} else if (hud_captures_mouse(_g, _mx, _my)) {
			_g.uiCapture = true;
		} else {
			_g.uiCapture = false;
			_g.dragging = true;
			_g.dragStartX = _wx;
			_g.dragStartY = _wy;
			_g.dragStartMx = _mx;
			_g.dragStartMy = _my;
		}
	}

	// Left release: click or box select
	if (mouse_check_button_released(mb_left) && _g.dragging) {
		_g.dragging = false;
		var _movedPx = point_distance(_g.dragStartMx, _g.dragStartMy, _mx, _my);
		if ((_movedPx < DRAG_THRESHOLD) || (_g.placeType != NO_ID)) {
			handle_world_click(_g, _g.hoverGx, _g.hoverGy);
		} else {
			box_select_units(_g, _g.dragStartX, _g.dragStartY, _wx, _wy);
		}
	}
}

function clear_selection(_g) {
	_g.selectedUnitIds = [];
	_g.selectedCityId = NO_ID;
	_g.selectedBuildingId = NO_ID;
}

// While placing a building, work out where it would go and whether that is allowed.
// Walls and gates snap to the tile edge nearest the cursor.
function update_placement_preview(_g) {
	if (_g.placeType == NO_ID) {
		return;
	}
	if (global.buildingDefs[_g.placeType].place == PLACE.EDGE) {
		var _edge = find_nearest_edge(_g.mouseWx, _g.mouseWy);
		_g.placeGx = _edge.ex;
		_g.placeGy = _edge.ey;
		_g.placeAxis = _edge.axis;
	} else {
		_g.placeGx = _g.hoverGx;
		_g.placeGy = _g.hoverGy;
		_g.placeAxis = 0;
	}
	_g.placeMsg = can_place_building(_g.world, _g.localNation, _g.placeType, _g.placeGx, _g.placeGy, _g.placeAxis);
}

function box_select_units(_g, _x1, _y1, _x2, _y2) {
	var _left = min(_x1, _x2);
	var _right = max(_x1, _x2);
	var _top = min(_y1, _y2);
	var _bottom = max(_y1, _y2);
	var _world = _g.world;
	var _picked = [];
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (!_u.alive || (_u.owner != _g.localNation)) {
			continue;
		}
		var _ux = tile_to_world_x(_u.visGx, _u.visGy);
		var _uy = tile_to_world_y(_u.visGx, _u.visGy) - 8 * SHAPE_SCALE;
		if ((_ux >= _left) && (_ux <= _right) && (_uy >= _top) && (_uy <= _bottom)) {
			array_push(_picked, _u.unitId);
		}
	}
	_g.selectedUnitIds = _picked;
	if (array_length(_picked) > 0) {
		_g.selectedCityId = NO_ID;
		_g.selectedBuildingId = NO_ID;
	}
}

// Sends a command and shows the reason on screen if it failed
function run_player_command(_g, _cmd) {
	var _result = apply_command(_g.world, _cmd);
	if (_result != "") {
		set_toast(_g, _result);
	}
	return _result;
}

function handle_world_click(_g, _gx, _gy) {
	var _world = _g.world;
	var _local = _g.localNation;

	// Placing a building: the click drops it
	if (_g.placeType != NO_ID) {
		var _build = make_command(CMD.BUILD, _local);
		_build.buildingType = _g.placeType;
		_build.gx = _g.placeGx;
		_build.gy = _g.placeGy;
		_build.axis = _g.placeAxis;
		if ((run_player_command(_g, _build) == "") && !keyboard_check(vk_shift)) {
			_g.placeType = NO_ID;
		}
		return;
	}

	if (!tile_in_bounds(_world, _gx, _gy)) {
		return;
	}
	var _unit = get_unit_at(_world, _gx, _gy);
	var _cityId = ds_grid_get(_world.cityGrid, _gx, _gy);
	var _tileBuilding = get_tile_building(_world, _gx, _gy);
	if ((_tileBuilding != undefined) && !building_visible_to(_world, _tileBuilding, _local)) {
		_tileBuilding = undefined;
	}

	// A wall or gate when the cursor is right on a tile edge
	var _edgeInfo = find_nearest_edge(_g.mouseWx, _g.mouseWy);
	var _edgeBuilding = undefined;
	if (_edgeInfo.dist < 0.16) {
		_edgeBuilding = get_edge_building_at(_world, _edgeInfo.ex, _edgeInfo.ey, _edgeInfo.axis);
	}

	var _hasUnits = (array_length(_g.selectedUnitIds) > 0);

	// Click one of your units: select it (shift toggles)
	if ((_unit != undefined) && (_unit.owner == _local) && (_edgeBuilding == undefined)) {
		if (keyboard_check(vk_shift)) {
			if (id_in_list(_g.selectedUnitIds, _unit.unitId)) {
				var _kept = [];
				for (var _i = 0; _i < array_length(_g.selectedUnitIds); _i++) {
					if (_g.selectedUnitIds[_i] != _unit.unitId) {
						array_push(_kept, _g.selectedUnitIds[_i]);
					}
				}
				_g.selectedUnitIds = _kept;
			} else {
				array_push(_g.selectedUnitIds, _unit.unitId);
			}
		} else {
			_g.selectedUnitIds = [_unit.unitId];
		}
		_g.selectedCityId = NO_ID;
		_g.selectedBuildingId = NO_ID;
		return;
	}

	// With units selected, clicking something hostile is an attack order
	if (_hasUnits) {
		var _cmd = undefined;
		if ((_edgeBuilding != undefined) && are_hostile(_world, _local, _edgeBuilding.owner) && building_visible_to(_world, _edgeBuilding, _local)) {
			_cmd = make_command(CMD.ATTACK, _local);
			_cmd.targetKind = ORDER.ATTACK_BUILDING;
			_cmd.targetId = _edgeBuilding.buildingId;
		} else if ((_unit != undefined) && are_hostile(_world, _local, _unit.owner)) {
			_cmd = make_command(CMD.ATTACK, _local);
			_cmd.targetKind = ORDER.ATTACK_UNIT;
			_cmd.targetId = _unit.unitId;
		} else if ((_tileBuilding != undefined) && are_hostile(_world, _local, _tileBuilding.owner)) {
			_cmd = make_command(CMD.ATTACK, _local);
			_cmd.targetKind = ORDER.ATTACK_BUILDING;
			_cmd.targetId = _tileBuilding.buildingId;
		} else if ((_cityId != NO_ID) && are_hostile(_world, _local, _world.cities[_cityId].owner)) {
			_cmd = make_command(CMD.ATTACK, _local);
			_cmd.targetKind = ORDER.ATTACK_CITY;
			_cmd.targetId = _cityId;
		}
		if (_cmd != undefined) {
			_cmd.unitIds = _g.selectedUnitIds;
			run_player_command(_g, _cmd);
			return;
		}
	}

	// Select a wall or gate
	if (_edgeBuilding != undefined) {
		_g.selectedBuildingId = _edgeBuilding.buildingId;
		_g.selectedUnitIds = [];
		_g.selectedCityId = NO_ID;
		return;
	}

	// Select a building (any visible one, enemy buildings only show information)
	if (_tileBuilding != undefined) {
		_g.selectedBuildingId = _tileBuilding.buildingId;
		_g.selectedUnitIds = [];
		_g.selectedCityId = NO_ID;
		return;
	}

	// Select a city
	if (_cityId != NO_ID) {
		_g.selectedCityId = _cityId;
		_g.selectedUnitIds = [];
		_g.selectedBuildingId = NO_ID;
		return;
	}

	// Units are selected: this click is a move order
	if (_hasUnits) {
		var _move = make_command(CMD.MOVE, _local);
		_move.gx = _gx;
		_move.gy = _gy;
		_move.unitIds = _g.selectedUnitIds;
		run_player_command(_g, _move);
		return;
	}

	// Clicked nothing useful
	_g.selectedCityId = NO_ID;
	_g.selectedBuildingId = NO_ID;
}
