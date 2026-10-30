function unit_type_is_machine(_type) {
	return (_type == UNIT_TYPE.BATTERING_RAM) || (_type == UNIT_TYPE.CATAPULT) || (_type == UNIT_TYPE.MANGONEL)
		|| (_type == UNIT_TYPE.HEAVY_TANK) || (_type == UNIT_TYPE.BREAKER_TANK) || (_type == UNIT_TYPE.ROCKET_ARTILLERY);
}

// Aircraft, seen from the side and facing right. The caller has already lifted the matrix off the ground.
function draw_air_unit(_type, _col, _tc) {
	var _s = 1;
	if (_type == UNIT_TYPE.TRANSPORT_PLANE) {
		_s = 1.3;
	} else if (_type == UNIT_TYPE.HEAVY_BOMBER) {
		_s = 1.6;
	}
	var _body = merge_colour(_col, c_white, 0.2);
	var _dark = merge_colour(_col, c_black, 0.45);

	// Tail fin
	draw_set_colour(_dark);
	draw_triangle(-15 * _s, -4 * _s, -8 * _s, -4 * _s, -15 * _s, -12 * _s, false);

	// Far wing (behind the body)
	draw_set_colour(_dark);
	draw_triangle(-3 * _s, -5 * _s, 6 * _s, -5 * _s, 1 * _s, -12 * _s, false);

	// Fuselage
	draw_set_colour(_body);
	draw_ellipse(-15 * _s, -8 * _s, 15 * _s, -1 * _s, false);
	draw_set_colour(c_black);
	draw_ellipse(-15 * _s, -8 * _s, 15 * _s, -1 * _s, true);

	// Near wing
	draw_set_colour(_col);
	draw_triangle(-3 * _s, -4 * _s, 7 * _s, -4 * _s, -5 * _s, 5 * _s, false);
	draw_set_colour(c_black);
	draw_line(-3 * _s, -4 * _s, -5 * _s, 5 * _s);
	draw_line(-5 * _s, 5 * _s, 7 * _s, -4 * _s);

	// Tier stripe and cockpit
	draw_set_colour(_tc);
	draw_line_width(-10 * _s, -4.5 * _s, -4 * _s, -4.5 * _s, 2);
	draw_set_colour(make_colour_rgb(170, 220, 255));
	draw_circle(5 * _s, -6 * _s, 1.8 * _s, false);

	switch (_type) {
		case UNIT_TYPE.BIPLANE:
			// A second wing above the first
			draw_set_colour(_col);
			draw_triangle(-3, -9, 7, -9, -5, -2, false);
			draw_set_colour(c_black);
			draw_line(-4, -9.5, 6, -9.5);
			break;

		case UNIT_TYPE.DIVE_BOMBER:
			// A bomb under the belly
			draw_set_colour(make_colour_rgb(40, 40, 46));
			draw_ellipse(-3, 0, 5, 4, false);
			break;

		case UNIT_TYPE.TRANSPORT_PLANE:
			// A row of windows
			draw_set_colour(make_colour_rgb(170, 220, 255));
			for (var _w = 0; _w < 4; _w++) {
				draw_circle(-9 + _w * 4, -4.5 * _s, 1, false);
			}
			break;

		case UNIT_TYPE.HEAVY_BOMBER:
			// Engines on the wings
			draw_set_colour(make_colour_rgb(50, 50, 56));
			draw_circle(-2, 3, 2.6, false);
			draw_circle(3, -10, 2.4, false);
			break;
	}

	// Spinning propeller
	var _spin = sin(current_time * 0.08) * 5 * _s;
	draw_set_colour(c_ltgray);
	draw_line_width(15 * _s, -4.5 * _s - _spin, 15 * _s, -4.5 * _s + _spin, 1);
}

// Siege engines and tanks
function draw_machine_unit(_type, _col, _tc, _by) {
	var _wood = make_colour_rgb(130, 92, 56);
	var _iron = make_colour_rgb(80, 84, 94);
	var _dark = merge_colour(_col, c_black, 0.4);

	switch (_type) {
		case UNIT_TYPE.BATTERING_RAM:
			// Roofed wooden frame on wheels, with a log poking out the front
			draw_set_colour(_wood);
			draw_rectangle(-9, _by - 11, 9, _by - 3, false);
			draw_set_colour(_col);
			draw_triangle(-11, _by - 11, 11, _by - 11, 0, _by - 18, false);
			draw_set_colour(_iron);
			draw_rectangle(7, _by - 8, 17, _by - 6, false);
			draw_circle(17, _by - 7, 2.2, false);
			draw_set_colour(c_black);
			draw_circle(-6, _by - 2, 2.5, false);
			draw_circle(6, _by - 2, 2.5, false);
			break;

		case UNIT_TYPE.CATAPULT:
			draw_set_colour(_wood);
			draw_rectangle(-9, _by - 5, 9, _by - 2, false);
			draw_line_width(-3, _by - 5, 5, _by - 17, 2);
			draw_set_colour(_iron);
			draw_circle(6, _by - 18, 3, false);
			draw_set_colour(_col);
			draw_rectangle(-9, _by - 5, -5, _by - 2, false);
			draw_set_colour(c_black);
			draw_circle(-6, _by - 1, 2.5, false);
			draw_circle(6, _by - 1, 2.5, false);
			break;

		case UNIT_TYPE.MANGONEL:
			// A tall arm with a bucket and a heavy counterweight
			draw_set_colour(_wood);
			draw_rectangle(-10, _by - 5, 10, _by - 2, false);
			draw_line_width(-2, _by - 5, 8, _by - 20, 2);
			draw_set_colour(_iron);
			draw_rectangle(5, _by - 24, 12, _by - 19, false);
			draw_set_colour(_col);
			draw_rectangle(-9, _by - 12, -3, _by - 5, false);
			draw_set_colour(c_black);
			draw_circle(-6, _by - 1, 2.5, false);
			draw_circle(6, _by - 1, 2.5, false);
			break;

		case UNIT_TYPE.HEAVY_TANK:
			draw_set_colour(_iron);
			draw_rectangle(-13, _by - 8, 13, _by, false);
			draw_set_colour(c_black);
			draw_rectangle(-13, _by - 3, 13, _by, false);
			draw_set_colour(_col);
			draw_rectangle(-7, _by - 15, 7, _by - 8, false);
			draw_set_colour(_dark);
			draw_rectangle(7, _by - 13, 18, _by - 11, false);
			draw_set_colour(_tc);
			draw_rectangle(-7, _by - 15, 7, _by - 8, true);
			break;

		case UNIT_TYPE.BREAKER_TANK:
			// Low hull with a big blade on the front
			draw_set_colour(_iron);
			draw_rectangle(-12, _by - 8, 12, _by, false);
			draw_set_colour(c_black);
			draw_rectangle(-12, _by - 3, 12, _by, false);
			draw_set_colour(_col);
			draw_rectangle(-8, _by - 13, 4, _by - 8, false);
			draw_set_colour(c_ltgray);
			draw_triangle(12, _by + 1, 12, _by - 14, 20, _by - 3, false);
			draw_set_colour(_tc);
			draw_rectangle(-8, _by - 13, 4, _by - 8, true);
			break;

		case UNIT_TYPE.ROCKET_ARTILLERY:
			// Truck with a tilted rocket rack
			draw_set_colour(_iron);
			draw_rectangle(-12, _by - 6, 12, _by, false);
			draw_set_colour(c_black);
			draw_circle(-7, _by, 2.5, false);
			draw_circle(7, _by, 2.5, false);
			draw_set_colour(_col);
			draw_triangle(-10, _by - 6, 10, _by - 6, 10, _by - 20, false);
			draw_set_colour(c_white);
			draw_line_width(-6, _by - 8, 8, _by - 17, 1);
			draw_line_width(-4, _by - 6, 9, _by - 14, 1);
			draw_set_colour(_tc);
			draw_line_width(-10, _by - 6, 10, _by - 20, 1);
			break;
	}
}

// Extra cases for draw_tile_building's switch (called from its default case, see the edits)
function draw_expansion_building(_b, _col, _tier, _stone, _wood) {
	switch (_b.type) {
		case BUILDING.SIEGE_WORKSHOP:
			// Open timber shed with a small catapult arm sticking out
			draw_set_colour(_wood);
			draw_rectangle(-18, -12, 18, 0, false);
			draw_set_colour(_col);
			draw_triangle(-20, -12, 20, -12, 0, -22, false);
			draw_set_colour(c_black);
			draw_rectangle(-9, -9, 9, 0, false);
			draw_set_colour(_stone);
			draw_line_width(10, -12, 20, -26, 2);
			draw_circle(20, -27, 2.5, false);
			draw_set_colour(_tier);
			draw_rectangle(-18, -12, 18, 0, true);
			break;

		case BUILDING.TANK_WORKSHOP:
			// Wide steel hangar with a big shutter and a chimney
			draw_set_colour(_stone);
			draw_rectangle(-22, -16, 22, 0, false);
			draw_set_colour(merge_colour(_col, c_black, 0.35));
			draw_rectangle(-22, -20, 22, -16, false);
			draw_set_colour(c_black);
			draw_rectangle(-11, -11, 11, 0, false);
			draw_set_colour(c_dkgray);
			for (var _l = 0; _l < 4; _l++) {
				draw_line(-11, -9 + _l * 3, 11, -9 + _l * 3);
			}
			draw_rectangle(14, -30, 18, -20, false);
			draw_set_colour(_tier);
			draw_rectangle(-22, -16, 22, 0, true);
			break;

		case BUILDING.AIRFIELD:
			// Landing strip with a control tower and a windsock
			draw_set_colour(make_colour_rgb(70, 72, 78));
			draw_rectangle(-24, -5, 24, 0, false);
			draw_set_colour(c_white);
			for (var _d = 0; _d < 5; _d++) {
				draw_line(-18 + _d * 9, -2.5, -13 + _d * 9, -2.5);
			}
			draw_set_colour(_stone);
			draw_rectangle(-22, -22, -14, -5, false);
			draw_set_colour(make_colour_rgb(170, 220, 255));
			draw_rectangle(-23, -26, -13, -22, false);
			draw_set_colour(_col);
			draw_triangle(16, -18, 16, -12, 24, -15, false);
			draw_set_colour(c_ltgray);
			draw_line_width(16, -18, 16, -5, 1);
			draw_set_colour(_tier);
			draw_rectangle(-24, -5, 24, 0, true);
			break;
			
		case BUILDING.HOUSING:
			// Cottage that gains a floor every two levels, with one dot per level
			var _hFloors = 1 + (_b.level div 2);
			var _hTop = -8 * _hFloors;
			draw_set_colour(_wood);
			draw_rectangle(-13, _hTop, 13, 0, false);
			draw_set_colour(_col);
			draw_triangle(-16, _hTop, 16, _hTop, 0, _hTop - 9, false);
			draw_set_colour(make_colour_rgb(255, 225, 140));
			for (var _hf = 0; _hf < _hFloors; _hf++) {
				draw_rectangle(-8, -6 - _hf * 8, -4, -2 - _hf * 8, false);
				draw_rectangle(4, -6 - _hf * 8, 8, -2 - _hf * 8, false);
			}
			draw_set_colour(_tier);
			for (var _hl = 0; _hl < _b.level; _hl++) {
				draw_circle(-7 + _hl * 5, 3, 1.5, false);
			}
			draw_rectangle(-13, _hTop, 13, 0, true);
			break;
	}
}