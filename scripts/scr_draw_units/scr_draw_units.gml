// ============================================================
// scr_draw_units: every unit is drawn from shapes for now.
// Shapes are drawn around (0, 0) at the tile centre and scaled by SHAPE_SCALE.
// The role decides the basic look, the tier (1 to 5) makes it fancier:
//   tier colour trim, bigger weapons, plumes and capes.
// ============================================================

function get_unit_tier_colour(_tier) {
	switch (_tier) {
		case 1: return make_colour_rgb(205, 127, 50);
		case 2: return make_colour_rgb(205, 212, 225);
		case 3: return make_colour_rgb(255, 210, 60);
		case 4: return make_colour_rgb(110, 225, 255);
		case 5: return make_colour_rgb(240, 100, 255);
	}
	return make_colour_rgb(180, 180, 180);
}

function draw_unit_head(_x, _y, _r) {
	draw_set_colour(make_colour_rgb(235, 205, 170));
	draw_circle(_x, _y, _r, false);
}

function draw_unit(_unit, _selected) {
	var _worldX = tile_to_world_x(_unit.visGx, _unit.visGy);
	var _worldY = tile_to_world_y(_unit.visGx, _unit.visGy);
	matrix_set(matrix_world, matrix_build(_worldX, _worldY, 0, 0, 0, 0, SHAPE_SCALE, SHAPE_SCALE, 1));
	var _stats = global.unitStats[_unit.type];
	var _col = get_owner_colour(_unit.owner);
	var _tc = get_unit_tier_colour(_stats.tier);
	var _tier = _stats.tier;

	// Shadow and selection ring
	draw_set_alpha(0.3);
	draw_set_colour(c_black);
	draw_ellipse(-9, -3, 9, 4, false);
	draw_set_alpha(1);
	if (_selected) {
		draw_set_colour(c_yellow);
		draw_ellipse(-13, -6, 13, 7, true);
	}

	// Envoys are drawn a little see through, as nobody targets them by default
	if (!_stats.targetable) {
		draw_set_alpha(0.8);
	}

	var _by = -2;
	if (_stats.domain == DOMAIN.WATER) {
		draw_boat_unit(_unit.type, _col, _tc);
	} else if (_unit.type == UNIT_TYPE.EXPLORER) {
		// Round body with a small flag
		draw_set_colour(_col);
		draw_circle(0, _by - 7, 6, false);
		draw_set_colour(c_black);
		draw_circle(0, _by - 7, 6, true);
		draw_line_width(5, _by - 12, 5, _by - 22, 1);
		draw_set_colour(c_white);
		draw_triangle(5, _by - 22, 5, _by - 16, 12, _by - 19, false);
	} else if (_unit.type == UNIT_TYPE.ENVOY) {
		draw_set_colour(merge_colour(_col, c_white, 0.4));
		draw_rectangle(-5, _by - 13, 5, _by, false);
		draw_set_colour(c_black);
		draw_rectangle(-5, _by - 13, 5, _by, true);
		draw_unit_head(0, _by - 17, 4);
		// White flag and a scroll
		draw_set_colour(c_white);
		draw_line_width(-8, _by - 6, -8, _by - 26, 1);
		draw_triangle(-8, _by - 26, -8, _by - 18, 2, _by - 22, false);
		draw_rectangle(5, _by - 9, 10, _by - 5, false);
	} else {
		draw_land_unit(_unit.type, _stats, _col, _tc, _tier, _by);
	}
	draw_set_alpha(1);

	// Passenger count badge on boats that carry units
	if (array_length(_unit.cargo) > 0) {
		draw_set_colour(c_black);
		draw_circle(12, _by - 22, 7, false);
		draw_set_colour(c_white);
		draw_circle(12, _by - 22, 7, true);
		draw_set_halign(fa_center);
		draw_set_valign(fa_middle);
		draw_text_transformed(12, _by - 22, string(array_length(_unit.cargo)), 0.6, 0.6, 0);
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
	}

	// Health bar when hurt
	if (_unit.hp < _stats.maxHp) {
		var _frac = _unit.hp / _stats.maxHp;
		draw_set_colour(c_black);
		draw_rectangle(-11, _by - 33, 11, _by - 30, false);
		draw_set_colour(merge_colour(c_red, c_lime, _frac));
		draw_rectangle(-10, _by - 32, -10 + 20 * _frac, _by - 31, false);
	}
	draw_set_colour(c_white);
	matrix_set(matrix_world, matrix_build_identity());
}

// Foot soldiers, riders and specials
function draw_land_unit(_type, _stats, _col, _tc, _tier, _by) {
	var _role = _stats.role;
	var _k = 1 + _tier * 0.07;

	if (_role == "DPS") {
		// Cape for the top tiers
		if (_tier >= 4) {
			draw_set_colour(merge_colour(_col, c_black, 0.35));
			draw_triangle(-6 * _k, _by - 15 * _k, 6 * _k, _by - 15 * _k, 0, _by + 1, false);
		}
		draw_set_colour(_col);
		draw_rectangle(-5 * _k, _by - 13 * _k, 5 * _k, _by, false);
		draw_set_colour(_tc);
		draw_rectangle(-5 * _k, _by - 13 * _k, 5 * _k, _by, true);
		draw_unit_head(0, _by - 17 * _k, 4 * _k);
		// Helmet crest from tier 3
		if (_tier >= 3) {
			draw_set_colour(_tc);
			draw_rectangle(-1, _by - 24 * _k, 1, _by - 20 * _k, false);
		}
		// Weapon: thin blade for duelists, axe for executioners, long blade otherwise
		draw_set_colour(c_ltgray);
		if (_type == UNIT_TYPE.EXECUTIONER) {
			draw_line_width(8, _by - 4, 8, _by - 22, 2);
			draw_set_colour(_tc);
			draw_triangle(8, _by - 22, 8, _by - 12, 15, _by - 17, false);
		} else if (_type == UNIT_TYPE.DUELIST) {
			draw_line_width(7, _by - 6, 15, _by - 22, 1);
		} else {
			draw_line_width(8, _by - 4, 8, _by - 12 - _tier * 2.5, 2);
			if (_tier >= 4) {
				draw_set_colour(_tc);
				draw_line_width(5, _by - 6, 11, _by - 6, 1);
			}
		}
	} else if (_role == "Tank") {
		var _tk = (_type == UNIT_TYPE.COLOSSUS) ? 1.55 : _k;
		draw_set_colour(merge_colour(_col, c_black, 0.15));
		draw_rectangle(-7 * _tk, _by - 14 * _tk, 7 * _tk, _by, false);
		draw_set_colour(c_black);
		draw_rectangle(-7 * _tk, _by - 14 * _tk, 7 * _tk, _by, true);
		draw_unit_head(0, _by - 18 * _tk, 4 * _tk);
		// Helmet
		draw_set_colour(_tc);
		draw_rectangle(-4 * _tk, _by - 22 * _tk, 4 * _tk, _by - 19 * _tk, false);
		// Big shield in front, with the owner colour as its emblem
		var _sw = 4 + _tier * 0.9;
		var _sh = 9 + _tier * 1.6;
		draw_set_colour(_tc);
		draw_rectangle(-9 * _tk - _sw, _by - _sh - 1, -9 * _tk + _sw, _by, false);
		draw_set_colour(_col);
		draw_rectangle(-9 * _tk - _sw + 2, _by - _sh + 2, -9 * _tk + _sw - 2, _by - 2, false);
		draw_set_colour(c_black);
		draw_rectangle(-9 * _tk - _sw, _by - _sh - 1, -9 * _tk + _sw, _by, true);
	} else if (_role == "Ranged") {
		draw_set_colour(_col);
		draw_rectangle(-4, _by - 12, 4, _by, false);
		draw_set_colour(_tc);
		draw_rectangle(-4, _by - 12, 4, _by, true);
		draw_unit_head(0, _by - 16, 3.5);
		if (_type == UNIT_TYPE.SIEGEBREAKER) {
			// A wheeled cannon
			draw_set_colour(make_colour_rgb(70, 70, 75));
			draw_line_width(-2, _by - 8, 15, _by - 14, 5);
			draw_set_colour(make_colour_rgb(110, 75, 40));
			draw_circle(2, _by - 2, 4, false);
			draw_set_colour(_tc);
			draw_circle(2, _by - 2, 1.5, false);
		} else if ((_type == UNIT_TYPE.ARTILLERIST) || (_type == UNIT_TYPE.SIEGE_MARKSMAN)) {
			// A long gun
			draw_set_colour(make_colour_rgb(60, 60, 65));
			draw_line_width(2, _by - 8, 16 + _tier, _by - 12, 2);
			draw_set_colour(_tc);
			draw_line_width(2, _by - 8, 6, _by - 9, 2);
		} else if (_type == UNIT_TYPE.CROSSBOWMAN) {
			draw_set_colour(make_colour_rgb(110, 75, 40));
			draw_line_width(5, _by - 12, 5, _by - 3, 1);
			draw_line_width(1, _by - 8, 12, _by - 8, 2);
		} else {
			// Archer's bow
			draw_set_colour(make_colour_rgb(110, 75, 40));
			draw_line_width(8, _by - 14, 11, _by - 8, 1);
			draw_line_width(11, _by - 8, 8, _by - 2, 1);
			draw_set_colour(c_white);
			draw_line(8, _by - 14, 8, _by - 2);
		}
	} else if (_role == "Movement") {
		// Horse body with legs, neck and head
		var _horse = merge_colour(_col, c_black, 0.25);
		if ((_type == UNIT_TYPE.WARHOUND) || (_type == UNIT_TYPE.STORMWING)) {
			_horse = (_type == UNIT_TYPE.WARHOUND) ? make_colour_rgb(95, 80, 70) : merge_colour(_col, c_white, 0.3);
		}
		// Wings for the flying lancers
		if ((_type == UNIT_TYPE.SKY_LANCER) || (_type == UNIT_TYPE.STORMWING)) {
			var _wing = (_type == UNIT_TYPE.STORMWING) ? 15 : 10;
			draw_set_colour(_tc);
			draw_triangle(-4, _by - 10, -4 - _wing, _by - 18, -4, _by - 15, false);
			draw_triangle(4, _by - 10, 4 + _wing, _by - 18, 4, _by - 15, false);
		}
		draw_set_colour(_horse);
		draw_rectangle(-11, _by - 9, 11, _by - 3, false);
		draw_rectangle(-10, _by - 3, -8, _by, false);
		draw_rectangle(8, _by - 3, 10, _by, false);
		draw_triangle(8, _by - 9, 13, _by - 17, 14, _by - 9, false);
		draw_set_colour(c_black);
		draw_rectangle(-11, _by - 9, 11, _by - 3, true);
		// Rider
		draw_set_colour(_col);
		draw_triangle(-4, _by - 9, 4, _by - 9, 0, _by - 20, false);
		draw_unit_head(0, _by - 23, 3);
		// Lance, longer with tier
		draw_set_colour(c_ltgray);
		draw_line_width(2, _by - 12, 12 + _tier * 2, _by - 24 - _tier, 1);
		if (_tier >= 2) {
			draw_set_colour(_tc);
			draw_rectangle(-11, _by - 9, 11, _by - 8, false);
		}
		// Speed lines
		if (_tier >= 3) {
			draw_set_colour(c_white);
			draw_line(-16, _by - 7, -12, _by - 7);
			draw_line(-18, _by - 5, -13, _by - 5);
		}
	} else {
		draw_special_unit(_type, _col, _tc, _by);
	}
}

// Medics, engineers, sappers, priests and arcanists
function draw_special_unit(_type, _col, _tc, _by) {
	switch (_type) {
		case UNIT_TYPE.MEDIC:
			draw_set_colour(c_white);
			draw_rectangle(-5, _by - 13, 5, _by, false);
			draw_set_colour(c_red);
			draw_rectangle(-1, _by - 11, 1, _by - 2, false);
			draw_rectangle(-4, _by - 8, 4, _by - 6, false);
			draw_set_colour(c_black);
			draw_rectangle(-5, _by - 13, 5, _by, true);
			draw_unit_head(0, _by - 17, 4);
			break;

		case UNIT_TYPE.COMBAT_ENGINEER:
			draw_set_colour(_col);
			draw_rectangle(-5, _by - 13, 5, _by, false);
			draw_set_colour(c_black);
			draw_rectangle(-5, _by - 13, 5, _by, true);
			draw_unit_head(0, _by - 17, 4);
			// Hard hat and a wrench
			draw_set_colour(make_colour_rgb(255, 200, 40));
			draw_rectangle(-5, _by - 23, 5, _by - 19, false);
			draw_set_colour(c_ltgray);
			draw_line_width(8, _by - 3, 8, _by - 14, 2);
			draw_circle(8, _by - 15, 2.5, true);
			break;

		case UNIT_TYPE.SAPPER:
			draw_set_colour(_col);
			draw_rectangle(-5, _by - 13, 5, _by, false);
			draw_set_colour(_tc);
			draw_rectangle(-5, _by - 13, 5, _by, true);
			draw_unit_head(0, _by - 17, 4);
			// Powder keg on the back with a lit fuse
			draw_set_colour(make_colour_rgb(110, 75, 40));
			draw_rectangle(5, _by - 12, 12, _by - 3, false);
			draw_set_colour(c_black);
			draw_line(8, _by - 12, 10, _by - 17);
			draw_set_colour(c_orange);
			draw_circle(10, _by - 18, 1.8, false);
			break;

		case UNIT_TYPE.WAR_PRIEST:
			draw_set_colour(merge_colour(_col, c_white, 0.5));
			draw_triangle(-7, _by, 7, _by, 0, _by - 17, false);
			draw_unit_head(0, _by - 19, 4);
			// Halo and a staff
			draw_set_colour(_tc);
			draw_ellipse(-5, _by - 27, 5, _by - 24, true);
			draw_line_width(9, _by, 9, _by - 24, 1);
			draw_circle(9, _by - 26, 2.5, false);
			break;

		case UNIT_TYPE.GRAND_ARCANIST:
			draw_set_colour(make_colour_rgb(90, 50, 150));
			draw_triangle(-8, _by, 8, _by, 0, _by - 20, false);
			draw_unit_head(0, _by - 22, 4);
			// Tall pointed hat and a glowing orb
			draw_set_colour(make_colour_rgb(60, 30, 110));
			draw_triangle(-6, _by - 25, 6, _by - 25, 0, _by - 38, false);
			draw_set_colour(_tc);
			draw_circle(11, _by - 14, 3.5, false);
			draw_set_alpha(0.35);
			draw_circle(11, _by - 14, 6, false);
			draw_set_alpha(1);
			break;
	}
}

// Boats: hull, deck and a special part per type
function draw_boat_unit(_type, _col, _tc) {
	var _hull = make_colour_rgb(110, 75, 40);
	var _size = (_type == UNIT_TYPE.BATTLESHIP) ? 1.4 : 1;

	// Waves under the hull
	draw_set_colour(c_white);
	draw_line(-14 * _size, 1, -8 * _size, 2);
	draw_line(8 * _size, 2, 14 * _size, 1);

	draw_set_colour(_hull);
	draw_triangle(-13 * _size, -7, 13 * _size, -7, 9 * _size, 0, false);
	draw_triangle(-13 * _size, -7, 9 * _size, 0, -9 * _size, 0, false);
	draw_set_colour(c_black);
	draw_line(-13 * _size, -7, -9 * _size, 0);
	draw_line(13 * _size, -7, 9 * _size, 0);
	draw_line(-9 * _size, 0, 9 * _size, 0);
	draw_set_colour(_col);
	draw_rectangle(-12 * _size, -9, 12 * _size, -7, false);

	switch (_type) {
		case UNIT_TYPE.BUILDING_BOAT:
			// Crane with a mine hanging from it
			draw_set_colour(c_ltgray);
			draw_line_width(-4, -9, -4, -22, 2);
			draw_line_width(-4, -22, 8, -22, 2);
			draw_line(8, -22, 8, -15);
			draw_set_colour(make_colour_rgb(50, 50, 55));
			draw_circle(8, -13, 3, false);
			break;

		case UNIT_TYPE.MINESEEKER:
			// Radar dish
			draw_set_colour(c_ltgray);
			draw_line_width(0, -9, 0, -17, 2);
			draw_set_colour(c_lime);
			draw_ellipse(-7, -23, 7, -16, true);
			draw_line(0, -20, 0, -26);
			break;

		case UNIT_TYPE.TRAVELER_BOAT:
			// Wide open hull with a mast and a sail
			draw_set_colour(c_white);
			draw_line_width(0, -9, 0, -26, 2);
			draw_set_colour(make_colour_rgb(240, 230, 200));
			draw_triangle(0, -26, 0, -12, 11, -13, false);
			draw_set_colour(_col);
			draw_triangle(0, -26, 0, -22, -6, -24, false);
			break;

		case UNIT_TYPE.BATTLESHIP:
			draw_set_colour(make_colour_rgb(95, 100, 110));
			draw_rectangle(-10, -15, 10, -9, false);
			draw_rectangle(-4, -22, 4, -15, false);
			draw_set_colour(c_black);
			draw_line_width(-6, -13, -16, -17, 3);
			draw_line_width(6, -13, 16, -17, 3);
			draw_set_colour(_tc);
			draw_rectangle(-10, -15, 10, -14, false);
			break;
			
		case UNIT_TYPE.ENVOY_BOAT:
			draw_set_colour(c_white);
			draw_line_width(-2, -9, -2, -27, 1);
			draw_triangle(-2, -27, -2, -19, 8, -23, false);
			draw_rectangle(3, -13, 8, -9, false);
			break;
	}
}
