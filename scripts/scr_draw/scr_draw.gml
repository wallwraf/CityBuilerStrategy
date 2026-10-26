// ============================================================
// scr_draw: world drawing (Draw event)
// Everything is drawn from shapes for now, swap in sprites later.
// Units are in scr_draw_units, buildings in scr_draw_buildings, the HUD in scr_hud.
// ============================================================

function draw_world(_g) {
	var _world = _g.world;
	var _local = _g.localNation;
	var _hw = TILE_W / 2;
	var _hh = TILE_H / 2;

	// Work out which tiles are on screen from the four view corners
	var _x1 = _g.camX;
	var _y1 = _g.camY;
	var _x2 = _g.camX + _g.screenW / _g.zoom;
	var _y2 = _g.camY + _g.screenH / _g.zoom;
	var _minGx = max(0, floor(min(world_to_tile_gx(_x1, _y1), world_to_tile_gx(_x2, _y1), world_to_tile_gx(_x1, _y2), world_to_tile_gx(_x2, _y2))) - 2);
	var _maxGx = min(_world.mapW - 1, ceil(max(world_to_tile_gx(_x1, _y1), world_to_tile_gx(_x2, _y1), world_to_tile_gx(_x1, _y2), world_to_tile_gx(_x2, _y2))) + 2);
	var _minGy = max(0, floor(min(world_to_tile_gy(_x1, _y1), world_to_tile_gy(_x2, _y1), world_to_tile_gy(_x1, _y2), world_to_tile_gy(_x2, _y2))) - 2);
	var _maxGy = min(_world.mapH - 1, ceil(max(world_to_tile_gy(_x1, _y1), world_to_tile_gy(_x2, _y1), world_to_tile_gy(_x1, _y2), world_to_tile_gy(_x2, _y2))) + 2);

	// Pass 1: terrain, back to front
	for (var _gy = _minGy; _gy <= _maxGy; _gy++) {
		for (var _gx = _minGx; _gx <= _maxGx; _gx++) {
			var _cx = tile_to_world_x(_gx, _gy);
			var _cy = tile_to_world_y(_gx, _gy);
			var _biome = ds_grid_get(_world.biome, _gx, _gy);
			var _lift = (_biome == BIOME.MOUNTAIN) ? ELEVATION_MOUNTAIN : 0;
			var _col = global.biomeColours[_biome];
			if (((_gx + _gy) mod 2) == 0) {
				_col = merge_colour(_col, c_black, 0.06);
			}

			// Raised sides for mountains
			if (_lift > 0) {
				draw_quad_colour(_cx - _hw, _cy - _lift, _cx, _cy + _hh - _lift, _cx, _cy + _hh, _cx - _hw, _cy, merge_colour(_col, c_black, 0.35), 1);
				draw_quad_colour(_cx, _cy + _hh - _lift, _cx + _hw, _cy - _lift, _cx + _hw, _cy, _cx, _cy + _hh, merge_colour(_col, c_black, 0.2), 1);
			}
			draw_diamond(_cx, _cy - _lift, _hw, _hh, _col, 1);
		}
	}

	// Pass 2: overlays (borders, resources, habitable markers, hover). Drawn after all terrain so
	// neighbouring tiles cannot paint over them.
	for (var _gy = _minGy; _gy <= _maxGy; _gy++) {
		for (var _gx = _minGx; _gx <= _maxGx; _gx++) {
			var _cx = tile_to_world_x(_gx, _gy);
			var _cy = tile_to_world_y(_gx, _gy);
			var _biome = ds_grid_get(_world.biome, _gx, _gy);
			var _lift = (_biome == BIOME.MOUNTAIN) ? ELEVATION_MOUNTAIN : 0;

			// Nation border tint and edge lines
			var _owner = ds_grid_get(_world.borderOwner, _gx, _gy);
			if (_owner != NO_ID) {
				var _ownerCol = get_owner_colour(_owner);
				draw_diamond(_cx, _cy - _lift, _hw, _hh, _ownerCol, 0.22);
				draw_border_edges(_world, _gx, _gy, _cx, _cy - _lift, _owner, _ownerCol);
			}

			// Stone and ore deposits (for quarries and mines)
			var _resource = ds_grid_get(_world.resource, _gx, _gy);
			if ((_resource != RES.NONE) && (ds_grid_get(_world.buildingGrid, _gx, _gy) == NO_ID)) {
				draw_resource_marker(_cx, _cy - _lift, _resource);
			}

			// Habitable tile marker
			if ((ds_grid_get(_world.habitable, _gx, _gy) == 1) && (ds_grid_get(_world.cityGrid, _gx, _gy) == NO_ID)) {
				draw_set_colour(make_colour_rgb(255, 225, 90));
				draw_ellipse(_cx - 9 * SHAPE_SCALE, _cy - 4 * SHAPE_SCALE, _cx + 9 * SHAPE_SCALE, _cy + 4 * SHAPE_SCALE, true);
				draw_ellipse(_cx - 3 * SHAPE_SCALE, _cy - 1 * SHAPE_SCALE, _cx + 3 * SHAPE_SCALE, _cy + 1 * SHAPE_SCALE, false);
			}

			// Hover highlight
			if ((_gx == _g.hoverGx) && (_gy == _g.hoverGy)) {
				draw_diamond_outline(_cx, _cy - _lift, _hw, _hh, c_white, 1);
			}
		}
	}

	// Pass 3: buildings, cities and units, back to front so they overlap correctly.
	// Walls and gates sit on the down right (axis 0) and down left (axis 1) edge of a tile,
	// so they are drawn right after that tile.
	for (var _gy = _minGy; _gy <= _maxGy; _gy++) {
		for (var _gx = _minGx; _gx <= _maxGx; _gx++) {
			var _buildingId = ds_grid_get(_world.buildingGrid, _gx, _gy);
			if (_buildingId != NO_ID) {
				var _b = _world.buildings[_buildingId];
				if (building_visible_to(_world, _b, _local)) {
					draw_building(_b, (_buildingId == _g.selectedBuildingId), 1);
				}
			}
			var _cityId = ds_grid_get(_world.cityGrid, _gx, _gy);
			if (_cityId != NO_ID) {
				draw_city(_world, _world.cities[_cityId], tile_to_world_x(_gx, _gy), tile_to_world_y(_gx, _gy), (_cityId == _g.selectedCityId));
			}
			var _unitId = ds_grid_get(_world.unitGrid, _gx, _gy);
			if (_unitId != NO_ID) {
				draw_unit(_world.units[_unitId], id_in_list(_g.selectedUnitIds, _unitId));
			}
			var _wallX = ds_grid_get(_world.edgeGridX, _gx, _gy);
			if (_wallX != NO_ID) {
				draw_building(_world.buildings[_wallX], (_wallX == _g.selectedBuildingId), 1);
			}
			var _wallY = ds_grid_get(_world.edgeGridY, _gx, _gy);
			if (_wallY != NO_ID) {
				draw_building(_world.buildings[_wallY], (_wallY == _g.selectedBuildingId), 1);
			}
		}
	}

	// Building about to be placed
	if (_g.placeType != NO_ID) {
		draw_placement_ghost(_g);
	}

	// Drag selection box
	if (_g.dragging && (_g.placeType == NO_ID) && (point_distance(_g.dragStartMx, _g.dragStartMy, device_mouse_x_to_gui(0), device_mouse_y_to_gui(0)) >= DRAG_THRESHOLD)) {
		draw_set_colour(c_white);
		draw_set_alpha(0.18);
		draw_rectangle(_g.dragStartX, _g.dragStartY, _g.mouseWx, _g.mouseWy, false);
		draw_set_alpha(1);
		draw_rectangle(_g.dragStartX, _g.dragStartY, _g.mouseWx, _g.mouseWy, true);
	}

	// Debug (F1): cross at the mouse position in the world
	if (_g.debugOverlay) {
		draw_set_colour(c_red);
		draw_line(_g.mouseWx - 6, _g.mouseWy, _g.mouseWx + 6, _g.mouseWy);
		draw_line(_g.mouseWx, _g.mouseWy - 6, _g.mouseWx, _g.mouseWy + 6);
	}
	draw_set_colour(c_white);
	draw_set_alpha(1);
}

// Draws a line on each tile edge that faces a tile with a different owner
function draw_border_edges(_world, _gx, _gy, _cx, _cy, _owner, _colour) {
	var _hw = TILE_W / 2;
	var _hh = TILE_H / 2;
	// Neighbour (gx+1, gy) is down-right, (gx, gy+1) down-left, (gx-1, gy) up-left, (gx, gy-1) up-right
	if (get_border_owner_safe(_world, _gx + 1, _gy) != _owner) {
		draw_line_width_colour(_cx + _hw, _cy, _cx, _cy + _hh, 3, _colour, _colour);
	}
	if (get_border_owner_safe(_world, _gx, _gy + 1) != _owner) {
		draw_line_width_colour(_cx, _cy + _hh, _cx - _hw, _cy, 3, _colour, _colour);
	}
	if (get_border_owner_safe(_world, _gx - 1, _gy) != _owner) {
		draw_line_width_colour(_cx - _hw, _cy, _cx, _cy - _hh, 3, _colour, _colour);
	}
	if (get_border_owner_safe(_world, _gx, _gy - 1) != _owner) {
		draw_line_width_colour(_cx, _cy - _hh, _cx + _hw, _cy, 3, _colour, _colour);
	}
}

function get_border_owner_safe(_world, _gx, _gy) {
	if (!tile_in_bounds(_world, _gx, _gy)) {
		return NO_ID;
	}
	return ds_grid_get(_world.borderOwner, _gx, _gy);
}

// City hall with its name, and the level written below the name as a star and a number
function draw_city(_world, _city, _cx, _cy, _selected) {
	// Shapes are drawn around (0, 0) and scaled to the tile size
	var _worldX = _cx;
	var _worldY = _cy;
	matrix_set(matrix_world, matrix_build(_worldX, _worldY, 0, 0, 0, 0, SHAPE_SCALE, SHAPE_SCALE, 1));
	_cx = 0;
	_cy = 0;
	var _col = get_owner_colour(_city.owner);
	if (_selected) {
		draw_set_colour(c_yellow);
		draw_ellipse(_cx - 22, _cy - 10, _cx + 22, _cy + 10, true);
	}
	// Walls and towers
	draw_set_colour(merge_colour(_col, c_white, 0.35));
	draw_rectangle(_cx - 14, _cy - 16, _cx + 14, _cy, false);
	draw_set_colour(_col);
	draw_rectangle(_cx - 18, _cy - 22, _cx - 10, _cy, false);
	draw_rectangle(_cx + 10, _cy - 22, _cx + 18, _cy, false);
	// Roof
	draw_triangle(_cx - 14, _cy - 16, _cx + 14, _cy - 16, _cx, _cy - 30, false);
	draw_set_colour(c_black);
	draw_rectangle(_cx - 14, _cy - 16, _cx + 14, _cy, true);
	draw_rectangle(_cx - 3, _cy - 8, _cx + 3, _cy, false);

	// Back to normal scale for the text so it stays readable
	matrix_set(matrix_world, matrix_build_identity());

	// Line 1: the name. Line 2 (under the name): a star and the level
	var _lineH = string_height("A");
	var _levelY = _worldY - 32 * SHAPE_SCALE;
	var _nameY = _levelY - _lineH;
	var _levelText = string(_city.level);
	var _half = (string_width(_levelText) + _lineH * 0.7) / 2;

	draw_set_halign(fa_center);
	draw_set_valign(fa_bottom);
	draw_set_colour(c_black);
	draw_text(_worldX + 1, _nameY + 1, _city.cityName);
	draw_set_colour(c_white);
	draw_text(_worldX, _nameY, _city.cityName);

	// Star, then the number to its right
	var _starR = _lineH * 0.32;
	var _starX = _worldX - _half + _starR;
	var _starY = _levelY - _lineH * 0.5;
	draw_star(_starX + 1, _starY + 1, _starR, c_black);
	draw_star(_starX, _starY, _starR, make_colour_rgb(255, 215, 70));
	draw_set_halign(fa_left);
	var _numX = _worldX - _half + _starR * 2 + 3;
	draw_set_colour(c_black);
	draw_text(_numX + 1, _levelY + 1, _levelText);
	draw_set_colour(c_white);
	draw_text(_numX, _levelY, _levelText);

	// Capital marker above the name
	if ((_city.owner >= 0) && (_world.nationStates[_city.owner].capitalId == _city.cityId)) {
		draw_crown(_worldX, _nameY - _lineH * 0.85, 1.4, make_colour_rgb(255, 215, 70));
	}

	// Health bar once damaged
	if (_city.hp < _city.maxHp) {
		var _frac = _city.hp / _city.maxHp;
		var _by = _worldY + 4;
		draw_set_colour(c_black);
		draw_rectangle(_worldX - 11, _by - 1, _worldX + 11, _by + 2, false);
		draw_set_colour(merge_colour(c_red, c_lime, _frac));
		draw_rectangle(_worldX - 10, _by, _worldX - 10 + 20 * _frac, _by + 1, false);
	}
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_colour(c_white);
}
