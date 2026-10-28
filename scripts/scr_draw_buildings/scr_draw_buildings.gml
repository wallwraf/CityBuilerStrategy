// ============================================================
// scr_draw_buildings: drawing for buildings, the placement preview and the city star label
// Tile buildings are drawn from shapes around (0, 0) at the tile centre, scaled by SHAPE_SCALE.
// ============================================================

// Level tiers: levels 1-3 bronze, 4-6 silver, 7-9 gold
function get_tier_colour(_level) {
	if (_level >= 7) {
		return make_colour_rgb(255, 210, 60);
	}
	if (_level >= 4) {
		return make_colour_rgb(205, 212, 225);
	}
	return make_colour_rgb(205, 127, 50);
}

// A five pointed star centred on (_cx, _cy)
function draw_star_shape(_cx, _cy, _radius, _colour) {
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(_cx, _cy, _colour, 1);
	for (var _i = 0; _i <= 10; _i++) {
		var _r = ((_i mod 2) == 0) ? _radius : _radius * 0.4;
		var _a = 90 + _i * 36;
		draw_vertex_colour(_cx + lengthdir_x(_r, _a), _cy - lengthdir_y(_r, _a), _colour, 1);
	}
	draw_primitive_end();
}

// Draws any building (a real one, or a ghost struct with the same fields)
function draw_building(_b, _selected, _alpha) {
	if (_b.isEdge) {
		draw_edge_building(_b, _selected, _alpha);
	} else {
		draw_tile_building(_b, _selected, _alpha);
	}

	// Health bar once damaged
	if (_b.hp < _b.maxHp) {
		var _bx = tile_to_world_x(_b.gx, _b.gy);
		var _by = tile_to_world_y(_b.gx, _b.gy) - 14;
		if (_b.isEdge) {
			var _p = edge_world_points(_b.gx, _b.gy, _b.axis);
			_bx = (_p[0] + _p[2]) / 2;
			_by = (_p[1] + _p[3]) / 2 - 14;
		}
		draw_set_colour(c_black);
		draw_rectangle(_bx - 8, _by - 1, _bx + 8, _by + 2, false);
		draw_set_colour(merge_colour(c_red, c_lime, _b.hp / _b.maxHp));
		draw_rectangle(_bx - 7, _by, _bx - 7 + 14 * (_b.hp / _b.maxHp), _by + 1, false);
		draw_set_colour(c_white);
	}
}

function draw_edge_building(_b, _selected, _alpha) {
	var _p = edge_world_points(_b.gx, _b.gy, _b.axis);
	var _col = get_owner_colour(_b.owner);
	var _tier = get_tier_colour(_b.level);
	var _height = 6 + _b.level;

	// Wood at level 1, stone at level 2, dark stone at level 3
	var _body = make_colour_rgb(140, 100, 62);
	if (_b.level == 2) {
		_body = make_colour_rgb(150, 148, 142);
	} else if (_b.level >= 3) {
		_body = make_colour_rgb(100, 104, 118);
	}

	draw_quad_colour(_p[0], _p[1] - _height, _p[2], _p[3] - _height, _p[2], _p[3], _p[0], _p[1], _body, _alpha);
	if (_b.type == BUILDING.GATE) {
		// A dark doorway in the middle with the owner's colour around it
		var _x1 = lerp(_p[0], _p[2], 0.3);
		var _y1 = lerp(_p[1], _p[3], 0.3);
		var _x2 = lerp(_p[0], _p[2], 0.7);
		var _y2 = lerp(_p[1], _p[3], 0.7);
		draw_quad_colour(_x1, _y1 - _height + 2, _x2, _y2 - _height + 2, _x2, _y2, _x1, _y1, c_black, _alpha);
		draw_set_alpha(_alpha);
		draw_line_width_colour(_x1, _y1 - _height + 2, _x2, _y2 - _height + 2, 1, _col, _col);
		draw_line_width_colour(_x1, _y1, _x1, _y1 - _height + 2, 1, _col, _col);
		draw_line_width_colour(_x2, _y2, _x2, _y2 - _height + 2, 1, _col, _col);
	}
	draw_set_alpha(_alpha);
	// Owner stripe in the middle of the wall, level tier colour along the top
	draw_line_width_colour(_p[0], _p[1] - _height / 2, _p[2], _p[3] - _height / 2, 1, _col, _col);
	draw_line_width_colour(_p[0], _p[1] - _height, _p[2], _p[3] - _height, 2, _tier, _tier);
	if (_selected) {
		draw_line_width_colour(_p[0], _p[1], _p[2], _p[3], 2, c_yellow, c_yellow);
	}
	draw_set_alpha(1);
}

function draw_tile_building(_b, _selected, _alpha) {
	var _worldX = tile_to_world_x(_b.gx, _b.gy);
	var _worldY = tile_to_world_y(_b.gx, _b.gy);
	matrix_set(matrix_world, matrix_build(_worldX, _worldY, 0, 0, 0, 0, SHAPE_SCALE, SHAPE_SCALE, 1));
	var _col = get_owner_colour(_b.owner);
	var _tier = get_tier_colour(_b.level);
	var _stone = make_colour_rgb(150, 148, 142);
	var _wood = make_colour_rgb(140, 100, 62);

	// Shadow and selection ring
	draw_set_alpha(_alpha * 0.3);
	draw_set_colour(c_black);
	draw_ellipse(-16, -5, 16, 6, false);
	draw_set_alpha(_alpha);
	if (_selected) {
		draw_set_colour(c_yellow);
		draw_ellipse(-26, -11, 26, 11, true);
	}

	switch (_b.type) {
		case BUILDING.BARRACKS:
			draw_set_colour(_wood);
			draw_rectangle(-18, -14, 18, 0, false);
			draw_set_colour(_col);
			draw_triangle(-20, -14, 20, -14, 0, -26, false);
			draw_set_colour(_tier);
			draw_rectangle(-18, -14, 18, 0, true);
			draw_set_colour(c_black);
			draw_rectangle(-4, -8, 4, 0, false);
			break;

		case BUILDING.PORT:
			draw_set_colour(_wood);
			draw_rectangle(-22, -5, 22, 0, false);
			draw_rectangle(-16, -16, -12, -5, false);
			draw_line_width(-14, -16, 10, -16, 2);
			draw_line_width(10, -16, 10, -8, 1);
			draw_set_colour(_col);
			draw_rectangle(-18, -22, -10, -16, false);
			draw_set_colour(_tier);
			draw_rectangle(-22, -5, 22, 0, true);
			break;

		case BUILDING.TOWER:
			// Taller with every level
			var _top = -22 - _b.level * 1.6;
			draw_set_colour(_stone);
			draw_rectangle(-7, _top, 7, 0, false);
			draw_rectangle(-8, _top - 4, -4, _top, false);
			draw_rectangle(-2, _top - 4, 2, _top, false);
			draw_rectangle(4, _top - 4, 8, _top, false);
			draw_set_colour(_tier);
			draw_rectangle(-7, _top, 7, 0, true);
			draw_set_colour(c_black);
			draw_line(0, _top - 4, 0, _top - 14);
			draw_set_colour(_col);
			draw_triangle(0, _top - 14, 0, _top - 8, 8, _top - 11, false);
			break;

		case BUILDING.NAVAL_MINE:
			draw_set_colour(make_colour_rgb(50, 50, 55));
			for (var _a = 0; _a < 360; _a += 60) {
				draw_line_width(lengthdir_x(7, _a), -4 + lengthdir_y(7, _a), lengthdir_x(12, _a), -4 + lengthdir_y(12, _a), 2);
			}
			draw_circle(0, -4, 7, false);
			draw_set_colour(_col);
			draw_circle(0, -4, 2.5, false);
			break;

		case BUILDING.GARRISON:
			draw_set_colour(_stone);
			draw_rectangle(-22, -16, 22, 0, false);
			draw_rectangle(-26, -26, -16, 0, false);
			draw_rectangle(16, -26, 26, 0, false);
			draw_set_colour(_col);
			draw_rectangle(-26, -30, -16, -26, false);
			draw_rectangle(16, -30, 26, -26, false);
			draw_set_colour(_tier);
			draw_rectangle(-22, -16, 22, 0, true);
			draw_set_colour(c_black);
			draw_rectangle(-4, -9, 4, 0, false);
			break;

		case BUILDING.HOSPITAL:
			draw_set_colour(c_white);
			draw_rectangle(-16, -16, 16, 0, false);
			draw_set_colour(_tier);
			draw_rectangle(-16, -16, 16, 0, true);
			draw_set_colour(c_red);
			draw_rectangle(-2, -13, 2, -3, false);
			draw_rectangle(-6, -9, 6, -7, false);
			break;

		case BUILDING.LABORATORY:
			draw_set_colour(make_colour_rgb(190, 200, 215));
			draw_rectangle(-15, -14, 15, 0, false);
			draw_set_colour(_tier);
			draw_rectangle(-15, -14, 15, 0, true);
			draw_set_colour(c_white);
			draw_rectangle(-2, -30, 2, -22, false);
			draw_set_colour(make_colour_rgb(80, 200, 255));
			draw_circle(0, -19, 6, false);
			break;

		case BUILDING.LUMBER_MILL:
			draw_set_colour(_wood);
			draw_rectangle(-16, -12, 16, 0, false);
			draw_set_colour(merge_colour(_wood, c_black, 0.4));
			draw_triangle(-18, -12, 18, -12, 0, -22, false);
			draw_set_colour(_tier);
			draw_rectangle(-16, -12, 16, 0, true);
			draw_set_colour(make_colour_rgb(110, 75, 40));
			draw_circle(-22, -3, 3, false);
			draw_circle(-22, -9, 3, false);
			break;

		case BUILDING.QUARRY:
			draw_set_colour(make_colour_rgb(95, 92, 90));
			draw_ellipse(-18, -8, 18, 6, false);
			draw_set_colour(_stone);
			draw_rectangle(-12, -14, -4, -6, false);
			draw_rectangle(2, -12, 10, -5, false);
			draw_set_colour(_tier);
			draw_ellipse(-18, -8, 18, 6, true);
			break;

		case BUILDING.MINE:
			draw_set_colour(make_colour_rgb(110, 95, 85));
			draw_triangle(-20, 0, 20, 0, 0, -22, false);
			draw_set_colour(c_black);
			draw_rectangle(-6, -10, 6, 0, false);
			draw_set_colour(_wood);
			draw_line_width(-6, -10, -6, 0, 2);
			draw_line_width(6, -10, 6, 0, 2);
			draw_set_colour(_tier);
			draw_triangle(-20, 0, 20, 0, 0, -22, true);
			break;

		case BUILDING.MARKET:
			draw_set_colour(_wood);
			draw_rectangle(-14, -6, 14, 0, false);
			draw_line_width(-14, -16, -14, -6, 2);
			draw_line_width(14, -16, 14, -6, 2);
			for (var _i = 0; _i < 4; _i++) {
				draw_set_colour(((_i mod 2) == 0) ? _col : c_white);
				draw_rectangle(-14 + _i * 7, -16, -7 + _i * 7, -10, false);
			}
			draw_set_colour(_tier);
			draw_rectangle(-14, -6, 14, 0, true);
			break;

		case BUILDING.EMBASSY:
			draw_set_colour(c_white);
			draw_rectangle(-18, -12, 18, 0, false);
			draw_triangle(-20, -12, 20, -12, 0, -22, false);
			draw_set_colour(_stone);
			for (var _k = 0; _k < 4; _k++) {
				draw_rectangle(-15 + _k * 10, -12, -12 + _k * 10, 0, false);
			}
			draw_set_colour(_tier);
			draw_rectangle(-18, -12, 18, 0, true);
			draw_set_colour(c_black);
			draw_line(0, -22, 0, -32);
			draw_set_colour(_col);
			draw_triangle(0, -32, 0, -26, 8, -29, false);
			break;
	}

	// Level pips under the building: one per level, coloured by tier
	if (global.buildingDefs[_b.type].maxLevel > 1) {
		draw_set_colour(_tier);
		var _pipStart = -(_b.level * 5.5) / 2;
		for (var _p = 0; _p < _b.level; _p++) {
			draw_rectangle(_pipStart + _p * 5.5, 5, _pipStart + _p * 5.5 + 4, 9, false);
		}
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
	matrix_set(matrix_world, matrix_build_identity());
}

// Shows where the building being placed would go, green if it is allowed and red if not
function draw_placement_ghost(_g) {
	var _def = global.buildingDefs[_g.placeType];
	var _ok = (_g.placeMsg == "");
	var _tint = _ok ? c_lime : c_red;
	// A path is only a patch of ground
	if (_def.place == PLACE.PATH) {
		draw_diamond(tile_to_world_x(_g.placeGx, _g.placeGy), tile_to_world_y(_g.placeGx, _g.placeGy), TILE_W * 0.3, TILE_H * 0.3, _tint, 0.7);
		return;
	}
	var _ghost = {
		type: _g.placeType, gx: _g.placeGx, gy: _g.placeGy, axis: _g.placeAxis, isEdge: (_def.place == PLACE.EDGE),
		level: 1, owner: _g.localNation, hp: 1, maxHp: 1
	};
	if (_def.place == PLACE.EDGE) {
		var _p = edge_world_points(_g.placeGx, _g.placeGy, _g.placeAxis);
		draw_line_width_colour(_p[0], _p[1], _p[2], _p[3], 3, _tint, _tint);
	} else {
		draw_diamond(tile_to_world_x(_g.placeGx, _g.placeGy), tile_to_world_y(_g.placeGx, _g.placeGy), TILE_W / 2, TILE_H / 2, _tint, 0.4);
	}
	draw_building(_ghost, false, 0.7);
}

// Small marks for stone and ore deposits
function draw_resource_marker(_cx, _cy, _resource) {
	if (_resource == RES.STONE) {
		draw_set_colour(make_colour_rgb(170, 168, 162));
		draw_circle(_cx - 4, _cy, 2.5, false);
		draw_circle(_cx + 3, _cy + 1, 2, false);
		draw_circle(_cx, _cy - 2, 1.5, false);
		draw_set_colour(make_colour_rgb(70, 68, 66));
		draw_circle(_cx - 4, _cy, 2.5, true);
		draw_circle(_cx + 3, _cy + 1, 2, true);
	} else if (_resource == RES.ORE) {
		draw_diamond(_cx - 3, _cy, 3, 2.5, make_colour_rgb(170, 90, 220), 1);
		draw_diamond(_cx + 3, _cy + 1, 3, 2.5, make_colour_rgb(255, 205, 70), 1);
	} else if (_resource == RES.TREES) {
		// Two little pine trees
		draw_set_colour(make_colour_rgb(90, 60, 35));
		draw_rectangle(_cx - 5, _cy - 1, _cx - 3, _cy + 3, false);
		draw_rectangle(_cx + 3, _cy, _cx + 5, _cy + 4, false);
		draw_set_colour(make_colour_rgb(24, 96, 44));
		draw_triangle(_cx - 4, _cy - 9, _cx - 9, _cy, _cx + 1, _cy, false);
		draw_triangle(_cx + 4, _cy - 8, _cx - 1, _cy + 1, _cx + 9, _cy + 1, false);
		draw_set_colour(make_colour_rgb(12, 52, 24));
		draw_triangle(_cx - 4, _cy - 9, _cx - 9, _cy, _cx - 4, _cy, false);
		draw_triangle(_cx + 4, _cy - 8, _cx - 1, _cy + 1, _cx + 4, _cy + 1, false);
	}
}
