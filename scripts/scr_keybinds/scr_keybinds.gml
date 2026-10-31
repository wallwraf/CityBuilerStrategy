// ============================================================
// scr_keybinds: rebindable keys. The keys are stored in global.options (as key codes),
// so they save to options.ini and reset with "Reset to Defaults" like every other option.
// ============================================================

#macro KEY_NONE 0

enum KEY_ACT {
	CAM_UP,
	CAM_DOWN,
	CAM_LEFT,
	CAM_RIGHT,
	CAM_FAST,
	MODIFIER,
	CARGO,
	RENAME,
	COUNT
}

// The name of the option that stores this action's key
function get_keybind_option(_act) {
	switch (_act) {
		case KEY_ACT.CAM_UP: return "keyCamUp";
		case KEY_ACT.CAM_DOWN: return "keyCamDown";
		case KEY_ACT.CAM_LEFT: return "keyCamLeft";
		case KEY_ACT.CAM_RIGHT: return "keyCamRight";
		case KEY_ACT.CAM_FAST: return "keyCamFast";
		case KEY_ACT.MODIFIER: return "keyModifier";
		case KEY_ACT.CARGO: return "keyCargo";
		case KEY_ACT.RENAME: return "keyRename";
	}
	return "";
}

function get_keybind_label(_act) {
	switch (_act) {
		case KEY_ACT.CAM_UP: return "Camera Up";
		case KEY_ACT.CAM_DOWN: return "Camera Down";
		case KEY_ACT.CAM_LEFT: return "Camera Left";
		case KEY_ACT.CAM_RIGHT: return "Camera Right";
		case KEY_ACT.CAM_FAST: return "Camera Fast";
		case KEY_ACT.MODIFIER: return "Add / Keep Placing";
		case KEY_ACT.CARGO: return "Load / Unload Cargo";
		case KEY_ACT.RENAME: return "Rename City";
	}
	return "";
}

function get_keybind_default(_act) {
	switch (_act) {
		case KEY_ACT.CAM_UP: return ord("W");
		case KEY_ACT.CAM_DOWN: return ord("S");
		case KEY_ACT.CAM_LEFT: return ord("A");
		case KEY_ACT.CAM_RIGHT: return ord("D");
		case KEY_ACT.CAM_FAST: return vk_shift;
		case KEY_ACT.MODIFIER: return vk_shift;
		case KEY_ACT.CARGO: return ord("E");
		case KEY_ACT.RENAME: return vk_f2;
	}
	return KEY_NONE;
}

// Call from get_default_options so every key has a default (and arrow keys are on)
function add_default_keybinds(_options) {
	for (var _a = 0; _a < KEY_ACT.COUNT; _a++) {
		variable_struct_set(_options, get_keybind_option(_a), get_keybind_default(_a));
	}
	_options.arrowKeys = 1;
}

function reset_keybinds() {
	for (var _a = 0; _a < KEY_ACT.COUNT; _a++) {
		variable_struct_set(global.options, get_keybind_option(_a), get_keybind_default(_a));
	}
}

function keybind_get(_act) {
	return variable_struct_get(global.options, get_keybind_option(_act));
}

// Held down. The camera actions also answer to the arrow keys when that option is on.
function keybind_check(_act) {
	if (keyboard_check(keybind_get(_act))) {
		return true;
	}
	if (global.options.arrowKeys == 1) {
		switch (_act) {
			case KEY_ACT.CAM_UP: return keyboard_check(vk_up);
			case KEY_ACT.CAM_DOWN: return keyboard_check(vk_down);
			case KEY_ACT.CAM_LEFT: return keyboard_check(vk_left);
			case KEY_ACT.CAM_RIGHT: return keyboard_check(vk_right);
		}
	}
	return false;
}

function keybind_pressed(_act) {
	return keyboard_check_pressed(keybind_get(_act));
}

function keybind_name(_act) {
	return keybind_key_name(keybind_get(_act));
}

function keybind_key_name(_key) {
	switch (_key) {
		case KEY_NONE: return "None";
		case vk_shift: return "Shift";
		case vk_control: return "Ctrl";
		case vk_alt: return "Alt";
		case vk_space: return "Space";
		case vk_tab: return "Tab";
		case vk_enter: return "Enter";
		case vk_backspace: return "Backspace";
		case vk_up: return "Up Arrow";
		case vk_down: return "Down Arrow";
		case vk_left: return "Left Arrow";
		case vk_right: return "Right Arrow";
		case vk_home: return "Home";
		case vk_end: return "End";
		case vk_insert: return "Insert";
		case vk_delete: return "Delete";
		case vk_pageup: return "Page Up";
		case vk_pagedown: return "Page Down";
	}
	if ((_key >= vk_f1) && (_key <= vk_f12)) {
		return "F" + string(_key - vk_f1 + 1);
	}
	if ((_key >= vk_numpad0) && (_key <= vk_numpad9)) {
		return "Num " + string(_key - vk_numpad0);
	}
	if (((_key >= 48) && (_key <= 57)) || ((_key >= 65) && (_key <= 90))) {
		return chr(_key);
	}
	return "Key " + string(_key);
}

// Left and right versions of a modifier count as the same key
function keybind_normalize(_key) {
	if ((_key == vk_lshift) || (_key == vk_rshift)) {
		return vk_shift;
	}
	if ((_key == vk_lcontrol) || (_key == vk_rcontrol)) {
		return vk_control;
	}
	if ((_key == vk_lalt) || (_key == vk_ralt)) {
		return vk_alt;
	}
	return _key;
}

// Binds a key. If another action already used it, the two swap keys (except Camera Fast and the
// modifier, which may share a key because Shift is the default for both).
function keybind_assign(_act, _key) {
	var _old = keybind_get(_act);
	var _soft = (_act == KEY_ACT.CAM_FAST) || (_act == KEY_ACT.MODIFIER);
	for (var _a = 0; _a < KEY_ACT.COUNT; _a++) {
		if ((_a == _act) || (keybind_get(_a) != _key)) {
			continue;
		}
		var _otherSoft = (_a == KEY_ACT.CAM_FAST) || (_a == KEY_ACT.MODIFIER);
		if (_soft && _otherSoft) {
			continue;
		}
		variable_struct_set(global.options, get_keybind_option(_a), _old);
	}
	variable_struct_set(global.options, get_keybind_option(_act), _key);
}

// Waiting for the new key (called from menu_update while g.menuRebind is set)
function menu_update_rebind(_g) {
	if (keyboard_check_pressed(vk_escape) || mouse_check_button_pressed(mb_right)) {
		_g.menuRebind = NO_ID;
		keyboard_lastkey = KEY_NONE;
		return;
	}
	if (keyboard_check_pressed(vk_anykey)) {
		var _key = keybind_normalize(keyboard_lastkey);
		if (_key != KEY_NONE) {
			keybind_assign(_g.menuRebind, _key);
		}
		_g.menuRebind = NO_ID;
		keyboard_lastkey = KEY_NONE;
	}
}

// WASD and the arrow keys move the camera (and scroll the research tree while it is open)
// Call from update_input in place of your old keyboard camera block, before camera_refresh_view.
function update_keyboard_camera(_g) {
	if (_g.gameState != GAME_STATE.PLAYING) {
		return;
	}
	// Typing a city name must not move anything
	if (_g.renameCityId != NO_ID) {
		return;
	}
	var _dt = min(delta_time / 1000000, 0.1);
	var _dx = keybind_check(KEY_ACT.CAM_RIGHT) - keybind_check(KEY_ACT.CAM_LEFT);
	var _dy = keybind_check(KEY_ACT.CAM_DOWN) - keybind_check(KEY_ACT.CAM_UP);
	if ((_dx == 0) && (_dy == 0)) {
		return;
	}
	var _fast = keybind_check(KEY_ACT.CAM_FAST) ? 2 : 1;
	var _len = point_distance(0, 0, _dx, _dy);

	// With the research tree open the keys scroll it instead
	if (_g.panel == PANEL.RESEARCH) {
		_g.researchPanX += _dx / _len * 500 * _fast * _dt;
		_g.researchPanY += _dy / _len * 500 * _fast * _dt;
		return;
	}
	var _speed = (200 + global.options.panSpeed * 60) / _g.zoom * _fast;
	_g.camX += _dx / _len * _speed * _dt;
	_g.camY += _dy / _len * _speed * _dt;
}