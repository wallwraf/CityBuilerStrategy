// ============================================================
// scr_menu_draw: drawing the main menu (called from the Draw GUI event)
// The simulated game behind it is drawn by draw_world in the Draw event.
// ============================================================

function draw_menu(_g) {
	var _items = menu_layout(_g);

	// Fade in from black once the demo game has been fast forwarded
	if (_g.menuFade > 0) {
		draw_set_colour(c_black);
		draw_set_alpha(_g.menuFade);
		draw_rectangle(0, 0, _g.screenW, _g.screenH, false);
		draw_set_alpha(1);
	}

	draw_menu_panel(_g);
	draw_menu_title(_g);

	// Page heading
	var _heading = menu_page_title(_g.menuPage);
	if (_heading != "") {
		draw_set_halign(fa_left);
		draw_set_valign(fa_bottom);
		draw_set_colour(c_ltgray);
		draw_text(28, MENU_TOP - 12, _heading);
	}

	for (var _i = 0; _i < array_length(_items); _i++) {
		draw_menu_item(_g, _items[_i], _i);
	}

	draw_menu_footer(_g);

	if (_g.toastTimer > 0) {
		draw_menu_toast(_g);
	}
	draw_set_colour(c_white);
	draw_set_alpha(1);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

// Dark, semi-transparent panel that fades toward the right, with a diagonal edge
function draw_menu_panel(_g) {
	var _w = menu_panel_width(_g);
	var _lean = 40;
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(0, 0, c_black, 0.88);
	draw_vertex_colour(_w + _lean, 0, c_black, 0.55);
	draw_vertex_colour(_w - _lean, _g.screenH, c_black, 0.55);
	draw_vertex_colour(0, _g.screenH, c_black, 0.88);
	draw_primitive_end();
	draw_set_alpha(0.5);
	draw_line_width_colour(_w + _lean, 0, _w - _lean, _g.screenH, 2, c_white, c_white);
	draw_set_alpha(1);
}

function draw_menu_title(_g) {
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_colour(c_black);
	draw_text_transformed(31, 49, GAME_TITLE, 4, 4, 0);
	draw_set_colour(c_white);
	draw_text_transformed(28, 46, GAME_TITLE, 4, 4, 0);
	draw_set_colour(c_ltgray);
	draw_text_transformed(30, 112, GAME_TAGLINE, 1.5, 1.5, 0);
}

function draw_menu_item(_g, _item, _index) {
	if (_item.kind == MENU_KIND.TEXT) {
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
		draw_set_colour(c_ltgray);
		draw_text_ext(_item.x + 28, _item.y + 4, _item.label, 20, _item.w - 40);
		return;
	}

	var _focused = (_index == _g.menuFocus) && _item.enabled;
	var _jut = _g.menuAnim[_index] * MENU_JUT;
	var _x = _item.x;
	var _y = _item.y;
	var _w = _item.w + _jut;
	var _h = _item.h;
	var _back = _focused ? c_white : c_black;
	var _front = _focused ? c_black : c_white;
	if (!_item.enabled) {
		_front = c_gray;
	}

	// Slanted button shape: the right edge leans in toward the bottom
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(_x, _y, _back, 0.94);
	draw_vertex_colour(_x + _w, _y, _back, 0.94);
	draw_vertex_colour(_x + _w - MENU_SLANT, _y + _h, _back, 0.94);
	draw_vertex_colour(_x, _y + _h, _back, 0.94);
	draw_primitive_end();
	if (!_focused) {
		var _edge = _item.enabled ? c_white : c_gray;
		draw_set_alpha(0.55);
		draw_line_width_colour(_x, _y, _x + _w, _y, 2, _edge, _edge);
		draw_line_width_colour(_x + _w, _y, _x + _w - MENU_SLANT, _y + _h, 2, _edge, _edge);
		draw_line_width_colour(_x + _w - MENU_SLANT, _y + _h, _x, _y + _h, 2, _edge, _edge);
		draw_set_alpha(1);
	}

	// Label on the left
	draw_set_valign(fa_middle);
	draw_set_halign(fa_left);
	draw_set_colour(_front);
	draw_text(_x + 28, _y + _h / 2, _item.label);

	// Value on the right, or a slider track
	draw_set_halign(fa_right);
	var _valueX = _x + _w - MENU_SLANT - 16;
	if (_item.kind == MENU_KIND.SLIDER) {
		var _bar = menu_slider_bar(_item);
		var _fraction = (_item.number - _item.minValue) / (_item.maxValue - _item.minValue);
		draw_line_width_colour(_bar[0], _bar[2], _bar[1], _bar[2], 2, _front, _front);
		var _knobX = lerp(_bar[0], _bar[1], _fraction);
		draw_rectangle_colour(_knobX - 4, _bar[2] - 10, _knobX + 4, _bar[2] + 10, _front, _front, _front, _front, false);
		draw_text(_valueX, _y + _h / 2, _item.value);
	} else if (_item.value != "") {
		var _text = _item.value;
		if (_item.kind == MENU_KIND.CHOICE) {
			_text = "<  " + _text + "  >";
		}
		draw_text(_valueX, _y + _h / 2, _text);
	}
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

function draw_menu_footer(_g) {
	draw_set_halign(fa_left);
	draw_set_valign(fa_bottom);
	draw_set_colour(c_gray);
	var _hint = "";
	if (_g.menuEditing) {
		_hint = "Type a number (0 = random)     Enter: confirm     Esc: cancel";
	}
	if (_g.menuRebind != NO_ID) {
		_hint = "Press the new key     Esc: cancel";
	}
	draw_text(28, _g.screenH - 36, _hint);
	draw_text(28, _g.screenH - 14, "Build " + GAME_VERSION);
}

function draw_menu_toast(_g) {
	var _w = max(260, string_width(_g.toastText) + 32);
	var _x = menu_panel_width(_g) + (_g.screenW - menu_panel_width(_g)) / 2;
	draw_set_colour(c_black);
	draw_set_alpha(0.75);
	draw_rectangle(_x - _w / 2, 24, _x + _w / 2, 56, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);
	draw_text(_x, 40, _g.toastText);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}