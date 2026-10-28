// ============================================================
// scr_options: player options, saved to options.ini
// Every option is stored as a number (toggles are 0 or 1) so it can go straight into the ini file.
// ============================================================

#macro OPTIONS_FILE "options.ini"

enum OPT_APPLY {
	NONE,
	VIDEO,
	AUDIO
}

function get_default_options() {
	return {
		// Video. windowSize 0 leaves the window alone, 1 and up pick from get_window_sizes()
		fullscreen: 0,
		windowSize: 0,
		vsync: 1,
		showFps: 0,
		// Audio (0 to 100)
		masterVolume: 80,
		musicVolume: 70,
		sfxVolume: 80,
		// Controls
		zoomSpeed: 5,
		panSpeed: 5,
		invertZoom: 0,
		edgeScroll: 0,
		// Accessibility
		reducedMotion: 0,
		thickBorders: 0,
		// Gameplay
		tooltips: 1,
		// Game setup (Play screen)
		mapSize: 64,
		bandits: 1,
		botFactions: 3
	};
}

function get_window_sizes() {
	return [[1280, 720], [1600, 900], [1920, 1080], [2560, 1440]];
}

function load_options() {
	global.options = get_default_options();
	ini_open(OPTIONS_FILE);
	var _names = variable_struct_get_names(global.options);
	for (var _i = 0; _i < array_length(_names); _i++) {
		var _default = variable_struct_get(global.options, _names[_i]);
		variable_struct_set(global.options, _names[_i], ini_read_real("options", _names[_i], _default));
	}
	ini_close();
	apply_video_options();
	apply_audio_options();
}

function save_options() {
	ini_open(OPTIONS_FILE);
	var _names = variable_struct_get_names(global.options);
	for (var _i = 0; _i < array_length(_names); _i++) {
		ini_write_real("options", _names[_i], variable_struct_get(global.options, _names[_i]));
	}
	ini_close();
}

function apply_video_options() {
	var _o = global.options;
	window_set_fullscreen(_o.fullscreen == 1);
	if ((_o.fullscreen == 0) && (_o.windowSize > 0)) {
		var _size = get_window_sizes()[_o.windowSize - 1];
		window_set_size(_size[0], _size[1]);
		window_center();
	}
	display_reset(0, _o.vsync == 1);
}

function apply_audio_options() {
	audio_master_gain(global.options.masterVolume / 100);
}

function apply_options_group(_group) {
	if (_group == OPT_APPLY.VIDEO) {
		apply_video_options();
	} else if (_group == OPT_APPLY.AUDIO) {
		apply_audio_options();
	}
}

// Small FPS readout in the top middle of the screen (called from the Draw GUI event)
function draw_fps_counter(_g) {
	if (global.options.showFps != 1) {
		return;
	}
	draw_set_halign(fa_center);
	draw_set_valign(fa_top);
	draw_set_colour(c_black);
	draw_text(_g.screenW / 2 + 1, 9, "FPS " + string(fps));
	draw_set_colour(c_lime);
	draw_text(_g.screenW / 2, 8, "FPS " + string(fps));
	draw_set_colour(c_white);
	draw_set_halign(fa_left);
}