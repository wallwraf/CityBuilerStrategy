// ============================================================
// scr_menu: main menu pages, input, and the simulated background game
//
// Controls: left click or Enter to continue, right click or Escape to go back,
// the mouse (or up and down arrows) highlights, left and right arrows change a value.
// ============================================================

#macro GAME_TITLE "CITY RTS"
#macro GAME_TAGLINE "Build. Ally. Conquer."
#macro GAME_VERSION "26.0.0.10b"

#macro MENU_ITEM_H 48
#macro MENU_ITEM_GAP 10
#macro MENU_SLANT 24
#macro MENU_JUT 28
#macro MENU_TOP 210
#macro MENU_MAX_ITEMS 24

enum GAME_STATE {
	MENU,
	PLAYING
}

enum MENU_PAGE {
	MAIN,
	PLAY,
	SETTINGS,
	VIDEO,
	AUDIO,
	CONTROLS,
	ACCESSIBILITY,
	GAMEPLAY,
	HOWTO,
	CREDITS,
	MULTI,
	HOST,
	JOIN,
	LOBBY
}

enum MENU_ACT {
	NONE,
	OPEN_PAGE,
	BACK,
	START,
	QUIT,
	RESET,
	OPTION,
	MAP_TYPE,
	SEED,
	HOST_NEXT,
	JOIN_CODE,
	JOIN_GO,
	LOBBY_SLOT,
	LOBBY_COPY,
	LOBBY_START,
	LOBBY_CANCEL
}

enum MENU_KIND {
	BUTTON,
	CHOICE,
	TOGGLE,
	SLIDER,
	SEED,
	TEXT
}

// ------------------------------------------------------------
// Setup
// ------------------------------------------------------------

// Called once from the Create event
function menu_init(_g) {
	_g.menuSeed = 0;
	_g.menuSeedText = "";
	_g.menuLastMx = -1;
	_g.menuLastMy = -1;
	_g.menuFade = 1;
	_g.menuFocusX = 0;
	_g.menuFocusY = 0;
	_g.menuTargetX = 0;
	_g.menuTargetY = 0;
	_g.menuWait = 0;
	_g.demoWarm = 0;
	_g.menuExitTimer = 0;
	_g.menuCode = "";
	_g.menuEditCode = false;
	menu_reset_page(_g);
}

// Back to the main page (used at start up and when returning from a game)
function menu_reset_page(_g) {
	_g.menuPage = MENU_PAGE.MAIN;
	_g.menuStack = [];
	_g.menuAnim = array_create(MENU_MAX_ITEMS, 0);
	_g.menuEditing = false;
	_g.menuDragSlider = NO_ID;
	_g.menuFocus = menu_first_focus(menu_get_items(_g));
}

function menu_panel_width(_g) {
	return clamp(floor(_g.screenW * 0.34), 480, 600);
}

// ------------------------------------------------------------
// Item builders
// ------------------------------------------------------------

function make_menu_item(_kind, _label) {
	return {
		kind: _kind,
		label: _label,
		act: MENU_ACT.NONE,
		arg: 0,
		enabled: true,
		key: "",
		value: "",
		number: 0,
		minValue: 0,
		maxValue: 1,
		step: 1,
		choices: [],
		apply: OPT_APPLY.NONE,
		x: 0,
		y: 0,
		w: 0,
		h: MENU_ITEM_H
	};
}

function menu_button(_label, _act, _arg) {
	var _item = make_menu_item(MENU_KIND.BUTTON, _label);
	_item.act = _act;
	_item.arg = _arg;
	return _item;
}

function menu_text(_label) {
	return make_menu_item(MENU_KIND.TEXT, _label);
}

function menu_option_toggle(_label, _key, _apply) {
	var _item = make_menu_item(MENU_KIND.TOGGLE, _label);
	_item.act = MENU_ACT.OPTION;
	_item.key = _key;
	_item.apply = _apply;
	_item.value = (variable_struct_get(global.options, _key) == 1) ? "On" : "Off";
	return _item;
}

function menu_option_choice(_label, _key, _choices, _apply) {
	var _item = make_menu_item(MENU_KIND.CHOICE, _label);
	_item.act = MENU_ACT.OPTION;
	_item.key = _key;
	_item.choices = _choices;
	_item.apply = _apply;
	_item.value = _choices[variable_struct_get(global.options, _key)];
	return _item;
}

function menu_option_slider(_label, _key, _min, _max, _step, _apply) {
	var _item = make_menu_item(MENU_KIND.SLIDER, _label);
	_item.act = MENU_ACT.OPTION;
	_item.key = _key;
	_item.minValue = _min;
	_item.maxValue = _max;
	_item.step = _step;
	_item.apply = _apply;
	_item.number = variable_struct_get(global.options, _key);
	_item.value = string(_item.number);
	return _item;
}

// ------------------------------------------------------------
// Pages
// ------------------------------------------------------------

function menu_get_items(_g) {
	var _items = [];
	switch (_g.menuPage) {
		case MENU_PAGE.MAIN:
			array_push(_items, menu_button("Play", MENU_ACT.OPEN_PAGE, MENU_PAGE.PLAY));
			array_push(_items, menu_button("Multiplayer", MENU_ACT.OPEN_PAGE, MENU_PAGE.MULTI));
			array_push(_items, menu_button("How to Play", MENU_ACT.OPEN_PAGE, MENU_PAGE.HOWTO));
			array_push(_items, menu_button("Settings", MENU_ACT.OPEN_PAGE, MENU_PAGE.SETTINGS));
			array_push(_items, menu_button("Credits", MENU_ACT.OPEN_PAGE, MENU_PAGE.CREDITS));
			array_push(_items, menu_button("Quit Game", MENU_ACT.QUIT, 0));
			break;

		case MENU_PAGE.PLAY:
			menu_add_setup_items(_g, _items, true);
			array_push(_items, menu_button("Start Game", MENU_ACT.START, 0));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.SETTINGS:
			array_push(_items, menu_button("Video and Display", MENU_ACT.OPEN_PAGE, MENU_PAGE.VIDEO));
			array_push(_items, menu_button("Audio", MENU_ACT.OPEN_PAGE, MENU_PAGE.AUDIO));
			array_push(_items, menu_button("Controls", MENU_ACT.OPEN_PAGE, MENU_PAGE.CONTROLS));
			array_push(_items, menu_button("Accessibility", MENU_ACT.OPEN_PAGE, MENU_PAGE.ACCESSIBILITY));
			array_push(_items, menu_button("Gameplay", MENU_ACT.OPEN_PAGE, MENU_PAGE.GAMEPLAY));
			array_push(_items, menu_button("Reset to Defaults", MENU_ACT.RESET, 0));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.VIDEO:
			array_push(_items, menu_option_toggle("Fullscreen", "fullscreen", OPT_APPLY.VIDEO));
			array_push(_items, menu_option_choice("Window Size", "windowSize", ["Default", "1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"], OPT_APPLY.VIDEO));
			array_push(_items, menu_option_toggle("VSync", "vsync", OPT_APPLY.VIDEO));
			array_push(_items, menu_option_toggle("Show FPS", "showFps", OPT_APPLY.NONE));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.AUDIO:
			array_push(_items, menu_option_slider("Master Volume", "masterVolume", 0, 100, 5, OPT_APPLY.AUDIO));
			array_push(_items, menu_option_slider("Music Volume", "musicVolume", 0, 100, 5, OPT_APPLY.AUDIO));
			array_push(_items, menu_option_slider("Effects Volume", "sfxVolume", 0, 100, 5, OPT_APPLY.AUDIO));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.CONTROLS:
			array_push(_items, menu_option_slider("Zoom Speed", "zoomSpeed", 1, 10, 1, OPT_APPLY.NONE));
			array_push(_items, menu_option_slider("Pan Speed", "panSpeed", 1, 10, 1, OPT_APPLY.NONE));
			array_push(_items, menu_option_toggle("Invert Zoom", "invertZoom", OPT_APPLY.NONE));
			array_push(_items, menu_option_toggle("Edge Scrolling", "edgeScroll", OPT_APPLY.NONE));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.ACCESSIBILITY:
			array_push(_items, menu_option_toggle("Reduced Motion", "reducedMotion", OPT_APPLY.NONE));
			array_push(_items, menu_option_toggle("Thick Borders", "thickBorders", OPT_APPLY.NONE));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.GAMEPLAY:
			array_push(_items, menu_option_toggle("Tooltips", "tooltips", OPT_APPLY.NONE));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.HOWTO:
			array_push(_items, menu_text("Left click selects a unit, city or building. With units selected, click the ground to move or click an enemy to attack."));
			array_push(_items, menu_text("Drag with left click to box select. Middle mouse or WASD / arrow keys pan, the wheel zooms, right click deselects."));
			array_push(_items, menu_text("Explorers found cities on the glowing habitable tiles. Cities grow your border and make gold."));
			array_push(_items, menu_text("Use the Build tab for barracks, towers, walls and more. Laboratories earn research points."));
			array_push(_items, menu_text("An Embassy sends envoys to offer peace. Bots decide using their ideology."));
			array_push(_items, menu_text("Take every enemy city to win. Lose your last city and you are out."));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.CREDITS:
			array_push(_items, menu_text("Design and direction: wallwraf"));
			array_push(_items, menu_text("Made in GameMaker Studio 2"));
			array_push(_items, menu_text("Inspired by Sid Meier's Civilization series"));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;
			
		case MENU_PAGE.MULTI:
			array_push(_items, menu_button("Host", MENU_ACT.OPEN_PAGE, MENU_PAGE.HOST));
			array_push(_items, menu_button("Join", MENU_ACT.OPEN_PAGE, MENU_PAGE.JOIN));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.HOST:
			menu_add_setup_items(_g, _items, false);
			array_push(_items, menu_button("Next", MENU_ACT.HOST_NEXT, 0));
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.JOIN:
			var _codeItem = make_menu_item(MENU_KIND.SEED, "Code");
			_codeItem.act = MENU_ACT.JOIN_CODE;
			if (_g.menuEditing) {
				_codeItem.value = net_code_format(_g.menuSeedText) + (((current_time div 400) mod 2 == 0) ? "|" : " ");
			} else {
				_codeItem.value = (_g.menuCode == "") ? "Enter code" : net_code_format(_g.menuCode);
			}
			array_push(_items, _codeItem);
			var _join = menu_button("Join", MENU_ACT.JOIN_GO, 0);
			_join.enabled = net_code_valid(_g.menuCode) && !global.net.connecting;
			if (global.net.connecting) {
				_join.value = "Connecting...";
			}
			array_push(_items, _join);
			array_push(_items, menu_button("Back", MENU_ACT.BACK, 0));
			break;

		case MENU_PAGE.LOBBY:
			var _net = global.net;
			var _isHost = (_net.mode == NET_MODE.HOST);
			var _codeText = (_net.code == "") ? "Finding address..." : net_code_format(_net.code);
			array_push(_items, menu_text("Code: " + _codeText));
			var _copy = menu_button("Copy to Clipboard", MENU_ACT.LOBBY_COPY, 0);
			_copy.enabled = (_net.code != "");
			array_push(_items, _copy);
			for (var _s = 0; _s < MAX_NATIONS; _s++) {
				var _slot = make_menu_item(MENU_KIND.CHOICE, "Slot " + string(_s + 1));
				_slot.act = MENU_ACT.LOBBY_SLOT;
				_slot.arg = _s;
				_slot.h = 36;
				var _kind = net_slot_kind(_s);
				switch (_kind) {
					case LOBBY_SLOT.HOST: _slot.value = "Host"; break;
					case LOBBY_SLOT.PLAYER: _slot.value = "Player"; break;
					case LOBBY_SLOT.AI: _slot.value = "AI"; break;
					case LOBBY_SLOT.EMPTY: _slot.value = "Empty"; break;
				}
				if (_s == _net.mySlot) {
					_slot.value += " (You)";
				}
				_slot.enabled = _isHost && ((_kind == LOBBY_SLOT.AI) || (_kind == LOBBY_SLOT.EMPTY));
				array_push(_items, _slot);
			}
			var _start = menu_button("Start", MENU_ACT.LOBBY_START, 0);
			_start.enabled = _isHost && (_net.lobbyPlayers + _net.lobbyAi >= 2);
			if (!_isHost) {
				_start.value = "Host only";
			} else if (!_start.enabled) {
				_start.value = "Need 2 or more";
			}
			array_push(_items, _start);
			array_push(_items, menu_button(_isHost ? "Cancel" : "Leave", MENU_ACT.LOBBY_CANCEL, 0));
			break;
	}
	return _items;
}

// The settings shared by the Play and Host pages. Hosts have no Bot Factions slider because
// the lobby decides how many AI there are.
function menu_add_setup_items(_g, _items, _includeBots) {
	var _seed = make_menu_item(MENU_KIND.SEED, "Seed");
	_seed.act = MENU_ACT.SEED;
	if (_g.menuEditing) {
		_seed.value = _g.menuSeedText + (((current_time div 400) mod 2 == 0) ? "|" : " ");
	} else {
		_seed.value = (_g.menuSeed == 0) ? "Random" : string(_g.menuSeed);
	}
	array_push(_items, _seed);
	var _map = make_menu_item(MENU_KIND.CHOICE, "Map Type");
	_map.act = MENU_ACT.MAP_TYPE;
	_map.value = global.mapPresets[_g.settings.mapPreset].presetName;
	array_push(_items, _map);

	var _size = menu_option_slider("Map Size", "mapSize", 32, 128, 8, OPT_APPLY.NONE);
	_size.value = string(_size.number) + " x " + string(_size.number);
	array_push(_items, _size);

	array_push(_items, menu_option_toggle("Bandits", "bandits", OPT_APPLY.NONE));
	if (_includeBots) {
		array_push(_items, menu_option_slider("Bot Factions", "botFactions", 1, MAX_NATIONS - 1, 1, OPT_APPLY.NONE));
	}
	array_push(_items, menu_option_choice("AI Difficulty", "aiDifficulty", ["Easy", "Normal", "Hard", "Brutal"], OPT_APPLY.NONE));
}

function menu_page_title(_page) {
	switch (_page) {
		case MENU_PAGE.PLAY: return "NEW GAME";
		case MENU_PAGE.SETTINGS: return "SETTINGS";
		case MENU_PAGE.VIDEO: return "SETTINGS  /  VIDEO AND DISPLAY";
		case MENU_PAGE.AUDIO: return "SETTINGS  /  AUDIO";
		case MENU_PAGE.CONTROLS: return "SETTINGS  /  CONTROLS";
		case MENU_PAGE.ACCESSIBILITY: return "SETTINGS  /  ACCESSIBILITY";
		case MENU_PAGE.GAMEPLAY: return "SETTINGS  /  GAMEPLAY";
		case MENU_PAGE.HOWTO: return "HOW TO PLAY";
		case MENU_PAGE.CREDITS: return "CREDITS";
		case MENU_PAGE.MULTI: return "MULTIPLAYER";
		case MENU_PAGE.HOST: return "MULTIPLAYER  /  HOST";
		case MENU_PAGE.JOIN: return "MULTIPLAYER  /  JOIN";
		case MENU_PAGE.LOBBY: return "LOBBY";
	}
	return "";
}

// Items with their screen positions filled in
function menu_layout(_g) {
	var _items = menu_get_items(_g);
	var _y = MENU_TOP;
	var _w = menu_panel_width(_g) - 70;
	for (var _i = 0; _i < array_length(_items); _i++) {
		var _item = _items[_i];
		_item.x = 0;
		_item.y = _y;
		_item.w = _w;
		if (_item.kind == MENU_KIND.TEXT) {
			_item.h = max(24, string_height_ext(_item.label, 20, _w - 40) + 8);
			_y += _item.h + 2;
		} else {
			_y += _item.h + MENU_ITEM_GAP;
		}
	}
	return _items;
}

// ------------------------------------------------------------
// Navigation
// ------------------------------------------------------------

function menu_item_interactive(_item) {
	return (_item.kind != MENU_KIND.TEXT) && _item.enabled;
}

function menu_first_focus(_items) {
	for (var _i = 0; _i < array_length(_items); _i++) {
		if (menu_item_interactive(_items[_i])) {
			return _i;
		}
	}
	return 0;
}

function menu_step_focus(_items, _focus, _dir) {
	var _count = array_length(_items);
	var _i = _focus;
	repeat (_count) {
		_i = (_i + _dir + _count) mod _count;
		if (menu_item_interactive(_items[_i])) {
			return _i;
		}
	}
	return _focus;
}

function menu_open_page(_g, _page) {
	array_push(_g.menuStack, { page: _g.menuPage, focus: _g.menuFocus });
	_g.menuPage = _page;
	_g.menuAnim = array_create(MENU_MAX_ITEMS, 0);
	_g.menuFocus = menu_first_focus(menu_get_items(_g));
}

function menu_go_back(_g) {
	if (_g.menuPage == MENU_PAGE.LOBBY) {
		sfx_play("ui_back");
		menu_leave_lobby(_g);
		return;
	}
	if (array_length(_g.menuStack) == 0) {
		return;
	}
	if (_g.menuPage == MENU_PAGE.JOIN) {
		net_close();
	}
	sfx_play("ui_back");
	save_options();
	var _previous = array_pop(_g.menuStack);
	_g.menuPage = _previous.page;
	_g.menuFocus = _previous.focus;
	_g.menuAnim = array_create(MENU_MAX_ITEMS, 0);
}

// Closes the lobby (the host's players are sent home) and goes back to the Multiplayer page
function menu_leave_lobby(_g) {
	net_close();
	while ((array_length(_g.menuStack) > 0) && (_g.menuPage != MENU_PAGE.MULTI)) {
		var _previous = array_pop(_g.menuStack);
		_g.menuPage = _previous.page;
		_g.menuFocus = _previous.focus;
	}
	_g.menuAnim = array_create(MENU_MAX_ITEMS, 0);
}

// True when the point is inside the slanted button shape
function menu_item_hit(_item, _mx, _my) {
	if ((_my < _item.y) || (_my > _item.y + _item.h) || (_mx < _item.x)) {
		return false;
	}
	var _rightEdge = _item.x + _item.w - MENU_SLANT * ((_my - _item.y) / _item.h);
	return (_mx <= _rightEdge);
}

// The track of a slider: [left x, right x, y]
function menu_slider_bar(_item) {
	return [_item.x + _item.w * 0.45, _item.x + _item.w - MENU_SLANT - 56, _item.y + _item.h / 2];
}

// ------------------------------------------------------------
// Changing values
// ------------------------------------------------------------

// _dir is 1 for next, -1 for previous
function menu_adjust(_g, _item, _dir) {
	if (_item.act == MENU_ACT.LOBBY_SLOT) {
		net_lobby_toggle(_item.arg);
		return;
	}
	sfx_play("ui_tick");
	if (_item.act == MENU_ACT.MAP_TYPE) {
		var _presets = array_length(global.mapPresets);
		_g.settings.mapPreset = (_g.settings.mapPreset + _dir + _presets) mod _presets;
		return;
	}
	if (_item.act != MENU_ACT.OPTION) {
		return;
	}
	var _value = variable_struct_get(global.options, _item.key);
	var _choiceCount = array_length(_item.choices);
	switch (_item.kind) {
		case MENU_KIND.TOGGLE:
			_value = (_value == 0) ? 1 : 0;
			break;
		case MENU_KIND.CHOICE:
			_value = (_value + _dir + _choiceCount) mod _choiceCount;
			break;
		case MENU_KIND.SLIDER:
			_value = clamp(_value + _dir * _item.step, _item.minValue, _item.maxValue);
			break;
	}
	variable_struct_set(global.options, _item.key, _value);
	apply_options_group(_item.apply);
}

function menu_set_slider_from_mouse(_item, _mx) {
	var _bar = menu_slider_bar(_item);
	var _fraction = clamp((_mx - _bar[0]) / (_bar[1] - _bar[0]), 0, 1);
	var _value = _item.minValue + round(_fraction * (_item.maxValue - _item.minValue) / _item.step) * _item.step;
	variable_struct_set(global.options, _item.key, _value);
	apply_options_group(_item.apply);
}

function menu_activate(_g, _item) {
	sfx_play("ui_click");
	switch (_item.act) {
		case MENU_ACT.OPEN_PAGE:
			menu_open_page(_g, _item.arg);
			break;
		case MENU_ACT.BACK:
			menu_go_back(_g);
			break;
		case MENU_ACT.START:
			menu_start_game(_g);
			break;
		case MENU_ACT.QUIT:
			save_options();
			game_end();
			break;
		case MENU_ACT.RESET:
			global.options = get_default_options();
			apply_video_options();
			apply_audio_options();
			set_toast(_g, "Settings reset to defaults");
			break;
		case MENU_ACT.SEED:
			_g.menuEditCode = false;
			_g.menuEditing = true;
			_g.menuSeedText = (_g.menuSeed == 0) ? "" : string(_g.menuSeed);
			keyboard_string = _g.menuSeedText;
			break;
		case MENU_ACT.MAP_TYPE:
		case MENU_ACT.OPTION:
			if (_item.kind != MENU_KIND.SLIDER) {
				menu_adjust(_g, _item, 1);
			}
			break;
		case MENU_ACT.HOST_NEXT:
			save_options();
			if (net_host_open(_g)) {
				menu_open_page(_g, MENU_PAGE.LOBBY);
			} else {
				set_toast(_g, "Could not open the lobby (is port " + string(NET_PORT) + " already in use?)");
			}
			break;
		case MENU_ACT.JOIN_CODE:
			_g.menuEditing = true;
			_g.menuEditCode = true;
			_g.menuSeedText = _g.menuCode;
			keyboard_string = _g.menuCode;
			break;
		case MENU_ACT.JOIN_GO:
			net_join(_g, _g.menuCode);
			break;
		case MENU_ACT.LOBBY_SLOT:
			net_lobby_toggle(_item.arg);
			break;
		case MENU_ACT.LOBBY_COPY:
			clipboard_set_text(net_code_format(global.net.code));
			set_toast(_g, "Code copied");
			break;
		case MENU_ACT.LOBBY_START:
			net_host_launch(_g);
			break;
		case MENU_ACT.LOBBY_CANCEL:
			menu_leave_lobby(_g);
			break;
	}
}

// Typing a seed (digits only, 0 means random) or a join code (letters and digits, Ctrl+V pastes).
// Enter or a click confirms, Escape or right click cancels.
function menu_update_seed_edit(_g) {
	var _text;
	if (_g.menuEditCode) {
		if (keyboard_check(vk_control) && keyboard_check_pressed(ord("V")) && clipboard_has_text()) {
			keyboard_string = clipboard_get_text();
		}
		_text = net_code_clean(keyboard_string);
		if (string_length(_text) > 11) {
			_text = string_copy(_text, 1, 11);
		}
	} else {
		_text = string_digits(keyboard_string);
		if (string_length(_text) > 6) {
			_text = string_copy(_text, 1, 6);
		}
	}
	keyboard_string = _text;
	_g.menuSeedText = _text;
	if (keyboard_check_pressed(vk_enter) || mouse_check_button_pressed(mb_left)) {
		if (_g.menuEditCode) {
			_g.menuCode = _text;
		} else {
			_g.menuSeed = (_text == "") ? 0 : real(_text);
		}
		_g.menuEditing = false;
	} else if (keyboard_check_pressed(vk_escape) || mouse_check_button_pressed(mb_right)) {
		_g.menuEditing = false;
	}
}

// ------------------------------------------------------------
// Per frame update
// ------------------------------------------------------------

function menu_update(_g, _dt) {
	menu_update_demo(_g, _dt);
	menu_update_camera(_g, _dt);

	var _mx = device_mouse_x_to_gui(0);
	var _my = device_mouse_y_to_gui(0);
	var _items = menu_layout(_g);
	var _count = array_length(_items);
	_g.menuFocus = clamp(_g.menuFocus, 0, max(0, _count - 1));

	if (_g.menuEditing) {
		menu_update_seed_edit(_g);
		menu_update_anim(_g, _count, _dt);
		return;
	}

	// The mouse highlights, but only when it actually moved so it does not fight the arrow keys
	var _moved = (_mx != _g.menuLastMx) || (_my != _g.menuLastMy);
	_g.menuLastMx = _mx;
	_g.menuLastMy = _my;
	var _hover = NO_ID;
	for (var _i = 0; _i < _count; _i++) {
		if (menu_item_interactive(_items[_i]) && menu_item_hit(_items[_i], _mx, _my)) {
			_hover = _i;
		}
	}
	if (_moved && (_hover != NO_ID)) {
		_g.menuFocus = _hover;
	}

	// Keyboard
	if (keyboard_check_pressed(vk_down)) {
		_g.menuFocus = menu_step_focus(_items, _g.menuFocus, 1);
	}
	if (keyboard_check_pressed(vk_up)) {
		_g.menuFocus = menu_step_focus(_items, _g.menuFocus, -1);
	}
	var _focused = _items[_g.menuFocus];
	if (menu_item_interactive(_focused)) {
		if (keyboard_check_pressed(vk_left)) {
			menu_adjust(_g, _focused, -1);
		}
		if (keyboard_check_pressed(vk_right)) {
			menu_adjust(_g, _focused, 1);
		}
		if (keyboard_check_pressed(vk_enter)) {
			menu_activate(_g, _focused);
			menu_update_anim(_g, _count, _dt);
			return;
		}
	}

	// Left click activates, or starts dragging a slider
	if (mouse_check_button_pressed(mb_left) && (_hover != NO_ID)) {
		_g.menuFocus = _hover;
		if (_items[_hover].kind == MENU_KIND.SLIDER) {
			_g.menuDragSlider = _hover;
		} else {
			menu_activate(_g, _items[_hover]);
			menu_update_anim(_g, _count, _dt);
			return;
		}
	}
	if (_g.menuDragSlider != NO_ID) {
		if (mouse_check_button(mb_left) && (_g.menuDragSlider < _count)) {
			menu_set_slider_from_mouse(_items[_g.menuDragSlider], _mx);
		} else {
			_g.menuDragSlider = NO_ID;
		}
	}

	// Right click or Escape goes back
	if (mouse_check_button_pressed(mb_right) || keyboard_check_pressed(vk_escape)) {
		menu_go_back(_g);
	}
	menu_update_anim(_g, _count, _dt);
}

// How far each button juts out (0 to 1). With Reduced Motion it snaps instead of sliding.
function menu_update_anim(_g, _count, _dt) {
	for (var _i = 0; _i < MENU_MAX_ITEMS; _i++) {
		var _target = ((_i == _g.menuFocus) && (_i < _count)) ? 1 : 0;
		if (global.options.reducedMotion == 1) {
			_g.menuAnim[_i] = _target;
		} else {
			_g.menuAnim[_i] = lerp(_g.menuAnim[_i], _target, min(1, _dt * 14));
		}
	}
}

// ------------------------------------------------------------
// Starting and leaving a game
// ------------------------------------------------------------

function menu_start_game(_g) {
	save_options();
	_g.settings.seed = (_g.menuSeed == 0) ? irandom_range(1, 999999) : _g.menuSeed;

	// Setup from the Play screen
	var _o = global.options;
	_g.settings.mapWidth = _o.mapSize;
	_g.settings.mapHeight = _o.mapSize;
	_g.settings.botCount = clamp(_o.botFactions, 1, MAX_NATIONS - 1);
	_g.settings.nationCount = _g.settings.botCount + 1;
	_g.settings.vacantCount = 0;
	_g.settings.bandits = (_o.bandits == 1);
	_g.settings.aiDifficulty = _o.aiDifficulty;
	menu_begin_world(_g, NO_ID);
}

// The settings for a multiplayer game from the Host page (the lobby fills in the nation counts)
function menu_make_settings(_g) {
	var _settings = {};
	var _names = variable_struct_get_names(_g.settings);
	for (var _i = 0; _i < array_length(_names); _i++) {
		variable_struct_set(_settings, _names[_i], variable_struct_get(_g.settings, _names[_i]));
	}
	var _o = global.options;
	_settings.seed = (_g.menuSeed == 0) ? irandom_range(1, 999999) : _g.menuSeed;
	_settings.mapWidth = _o.mapSize;
	_settings.mapHeight = _o.mapSize;
	_settings.bandits = (_o.bandits == 1);
	_settings.aiDifficulty = _o.aiDifficulty;
	return _settings;
}

// Builds the world from _g.settings and starts playing. _slot is the nation this player controls
// (NO_ID keeps the generator's default).
function menu_begin_world(_g, _slot) {
	if (_g.world != undefined) {
		destroy_world(_g.world);
	}
	_g.world = create_world(_g.settings);
	if (_slot != NO_ID) {
		_g.world.localNation = _slot;
	}
	_g.localNation = _g.world.localNation;
	_g.gameState = GAME_STATE.PLAYING;
	_g.zoom = 2;
	clear_selection(_g);
	_g.panel = PANEL.NONE;
	_g.placeType = NO_ID;
	_g.dragging = false;
	end_screen_reset(_g);
	_g.renameCityId = NO_ID;
	_g.menuExitTimer = 0;
	if (_g.localNation != NO_ID) {
		var _capital = bot_get_first_city(_g.world, _g.localNation);
		if (_capital != undefined) {
			camera_focus_tile(_g, _capital.gx, _capital.gy);
		}
	}
}

// From a running game back to the main menu
function menu_return(_g) {
	net_close();
	if (_g.world != undefined) {
		destroy_world(_g.world);
		_g.world = undefined;
	}
	clear_selection(_g);
	_g.panel = PANEL.NONE;
	_g.placeType = NO_ID;
	_g.dragging = false;
	_g.localNation = NO_ID;
	_g.zoom = 2;
	_g.hoverGx = -1;
	_g.hoverGy = -1;
	_g.gameState = GAME_STATE.MENU;
	menu_reset_page(_g);
	menu_start_demo(_g);
}

// ------------------------------------------------------------
// The simulated game behind the menu: six bots, a random map, started at a random point in time
// ------------------------------------------------------------

function menu_start_demo(_g) {
	if (_g.world != undefined) {
		destroy_world(_g.world);
	}
	var _demo = {
		nationCount: 6,
		botCount: 5,
		vacantCount: 0,
		mapPreset: irandom(array_length(global.mapPresets) - 1),
		mapWidth: 64,
		mapHeight: 64,
		seed: irandom_range(1, 999999)
	};
	_g.world = create_world(_demo);

	// The generator always makes nation 0 a human player, so turn it into a bot and just watch
	_g.world.nationStates[0].slotType = SLOT_TYPE.BOT;
	_g.world.localNation = NO_ID;
	_g.localNation = NO_ID;

	// Nations start at different stages of progress
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		var _state = _g.world.nationStates[_n];
		if (_state.active) {
			_state.gold += irandom(600);
			_state.rp += irandom(80);
		}
	}

	// Fast forward a random amount of game time (a little each frame while the screen is black)
	_g.demoWarm = random_range(120, 420);
	_g.demoAge = 0;
	_g.menuFade = 1;
	_g.menuWait = 0;
	menu_pick_camera_target(_g, true);
}

function menu_update_demo(_g, _dt) {
	if (_g.demoWarm > 0) {
		var _start = get_timer();
		// At most about 8 ms of simulation per frame, so the menu never stalls
		while ((_g.demoWarm > 0) && ((get_timer() - _start) < 8000)) {
			update_world(_g.world, 0.25);
			_g.demoWarm -= 0.25;
		}
		if (_g.demoWarm <= 0) {
			menu_pick_camera_target(_g, true);
		}
		return;
	}
	_g.menuFade = max(0, _g.menuFade - _dt * 0.8);
	update_world(_g.world, _dt);
	_g.demoAge += _dt;

	// A new demo when the game ends, or after ten minutes
	if ((_g.world.winner != NO_ID) || (_g.demoAge > 600)) {
		menu_start_demo(_g);
	}
}

// Picks a city to drift toward. _snap jumps straight there.
function menu_pick_camera_target(_g, _snap) {
	var _world = _g.world;
	var _all = [];
	var _near = [];
	for (var _i = 0; _i < array_length(_world.cities); _i++) {
		var _c = _world.cities[_i];
		var _cx = tile_to_world_x(_c.gx, _c.gy);
		var _cy = tile_to_world_y(_c.gx, _c.gy);
		array_push(_all, [_cx, _cy]);
		var _dist = point_distance(_g.menuFocusX, _g.menuFocusY, _cx, _cy);
		if ((_dist > 80) && (_dist < 520)) {
			array_push(_near, [_cx, _cy]);
		}
	}
	var _pool = ((array_length(_near) > 0) && !_snap) ? _near : _all;
	var _tx = tile_to_world_x(_world.mapW / 2, _world.mapH / 2);
	var _ty = tile_to_world_y(_world.mapW / 2, _world.mapH / 2);
	if (array_length(_pool) > 0) {
		var _pick = _pool[irandom(array_length(_pool) - 1)];
		_tx = _pick[0];
		_ty = _pick[1];
	}
	_g.menuTargetX = _tx;
	_g.menuTargetY = _ty;
	if (_snap) {
		_g.menuFocusX = _tx;
		_g.menuFocusY = _ty;
	}
}

// Slowly pans toward the target. The focus point sits in the middle of the area to the right of the panel.
function menu_update_camera(_g, _dt) {
	if ((_g.demoWarm <= 0) && (global.options.reducedMotion != 1)) {
		var _dist = point_distance(_g.menuFocusX, _g.menuFocusY, _g.menuTargetX, _g.menuTargetY);
		if (_dist < 6) {
			_g.menuWait -= _dt;
			if (_g.menuWait <= 0) {
				menu_pick_camera_target(_g, false);
				_g.menuWait = 3;
			}
		} else {
			var _speed = 26 * clamp(_dist / 80, 0.15, 1);
			var _dir = point_direction(_g.menuFocusX, _g.menuFocusY, _g.menuTargetX, _g.menuTargetY);
			var _move = min(_speed * _dt, _dist);
			_g.menuFocusX += lengthdir_x(_move, _dir);
			_g.menuFocusY += lengthdir_y(_move, _dir);
		}
	}
	var _panelW = menu_panel_width(_g);
	var _screenX = _panelW + (_g.screenW - _panelW) / 2;
	_g.camX = _g.menuFocusX - _screenX / _g.zoom;
	_g.camY = _g.menuFocusY - (_g.screenH / 2) / _g.zoom;
	camera_refresh_view(_g);
}