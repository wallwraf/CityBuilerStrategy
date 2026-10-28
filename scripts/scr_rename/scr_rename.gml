// ============================================================
// scr_rename: the box for renaming one of your cities
// ============================================================

#macro CITY_NAME_MAX 20

// Removes control characters and outer spaces, and limits the length
function clean_city_name(_text) {
	var _out = "";
	for (var _i = 1; _i <= string_length(_text); _i++) {
		var _c = string_char_at(_text, _i);
		if (ord(_c) >= 32) {
			_out += _c;
		}
	}
	while (string_char_at(_out, 1) == " ") {
		_out = string_delete(_out, 1, 1);
	}
	if (string_length(_out) > CITY_NAME_MAX) {
		_out = string_copy(_out, 1, CITY_NAME_MAX);
	}
	while ((string_length(_out) > 0) && (string_char_at(_out, string_length(_out)) == " ")) {
		_out = string_delete(_out, string_length(_out), 1);
	}
	return _out;
}

function rename_begin(_g, _cityId) {
	_g.renameCityId = _cityId;
	_g.renameText = _g.world.cities[_cityId].cityName;
	keyboard_string = _g.renameText;
}

// Call at the very top of update_input. Returns true while the box is open (the rest of the input is skipped).
function rename_update(_g) {
	if (_g.renameCityId == NO_ID) {
		return false;
	}
	// The city was captured while typing
	if (_g.world.cities[_g.renameCityId].owner != _g.localNation) {
		_g.renameCityId = NO_ID;
		return true;
	}
	var _text = keyboard_string;
	if (string_length(_text) > CITY_NAME_MAX) {
		_text = string_copy(_text, 1, CITY_NAME_MAX);
		keyboard_string = _text;
	}
	_g.renameText = _text;
	if (keyboard_check_pressed(vk_enter)) {
		var _cmd = make_command(CMD.RENAME_CITY, _g.localNation);
		_cmd.cityId = _g.renameCityId;
		_cmd.text = _text;
		_g.renameCityId = NO_ID;
		sfx_play("ui_click");
		run_player_command(_g, _cmd);
	} else if (keyboard_check_pressed(vk_escape) || mouse_check_button_pressed(mb_right)) {
		_g.renameCityId = NO_ID;
		sfx_play("ui_back");
	}
	return true;
}

// Call after draw_hud in the Draw GUI event
function rename_draw(_g) {
	if (_g.renameCityId == NO_ID) {
		return;
	}
	var _w = 440;
	var _h = 140;
	var _x = (_g.screenW - _w) / 2;
	var _y = (_g.screenH - _h) / 2;
	draw_set_colour(c_black);
	draw_set_alpha(0.55);
	draw_rectangle(0, 0, _g.screenW, _g.screenH, false);
	draw_set_alpha(0.95);
	draw_rectangle(_x, _y, _x + _w, _y + _h, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
	draw_rectangle(_x, _y, _x + _w, _y + _h, true);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_text(_x + 20, _y + 14, "Rename city");
	draw_set_colour(make_colour_rgb(40, 44, 54));
	draw_rectangle(_x + 20, _y + 48, _x + _w - 20, _y + 84, false);
	draw_set_colour(c_white);
	draw_rectangle(_x + 20, _y + 48, _x + _w - 20, _y + 84, true);
	var _caret = (((current_time div 400) mod 2) == 0) ? "|" : " ";
	draw_text(_x + 30, _y + 56, _g.renameText + _caret);
	draw_set_colour(c_gray);
	draw_text(_x + 20, _y + 100, "Enter to confirm    Escape to cancel");
	draw_set_colour(c_white);
}