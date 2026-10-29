// ============================================================
// scr_sfx: the sound effect and ambience manager.
//
//   sfx_play(key)                   a one shot sound (UI)
//   sfx_play_world(g, key, gx, gy)  a one shot that gets quieter the further it is from the screen
//   audio_event(world, ...)         the game simulation says "something happened here". The
//                                   manager plays the right sound, so the game logic never plays
//                                   sounds itself (this also suits multiplayer later).
//   loops ("layers")                ambience and battle sounds that fade in and out smoothly
// ============================================================

function audio_init(_g) {
	global.audioTicks = 0;
	init_audio();
	sfx_init();
	music_init();
}

function audio_update(_g, _dt) {
	global.audioTicks++;
	sfx_update(_g, _dt);
	music_update(_g, _dt);
}

function audio_cleanup() {
	sfx_cleanup();
	music_cleanup();
}

// ------------------------------------------------------------
// Definitions
// ------------------------------------------------------------

function sfx_define(_key, _assetNames, _volume, _pitchLow, _pitchHigh, _cooldown) {
	variable_struct_set(global.sfxDefs, _key, {
		assetNames: _assetNames,
		volume: _volume,
		pitchLow: _pitchLow,
		pitchHigh: _pitchHigh,
		cooldown: _cooldown,
		priority: 5,
		loop: false
	});
}

function sfx_define_loop(_key, _assetName, _volume) {
	variable_struct_set(global.sfxDefs, _key, {
		assetNames: [_assetName],
		volume: _volume,
		pitchLow: 1,
		pitchHigh: 1,
		cooldown: 0,
		priority: 1,
		loop: true
	});
}

function sfx_define_building(_type, _assetNames) {
	sfx_define("build_" + string(_type), _assetNames, 0.8, 0.95, 1.05, 60);
}

function sfx_define_unit(_type, _assetNames) {
	sfx_define("spawn_" + string(_type), _assetNames, 0.7, 0.95, 1.05, 80);
}

function sfx_get_building_key(_type) {
	var _key = "build_" + string(_type);
	return variable_struct_exists(global.sfxDefs, _key) ? _key : "build_default";
}

function sfx_get_unit_key(_type) {
	var _key = "spawn_" + string(_type);
	return variable_struct_exists(global.sfxDefs, _key) ? _key : "spawn_default";
}

// Finds a sound asset by name. A missing asset gives -1 (and is remembered, so it is only looked up once).
function audio_get_asset(_name) {
	if (variable_struct_exists(global.audioAssets, _name)) {
		return variable_struct_get(global.audioAssets, _name);
	}
	var _index = asset_get_index(_name);
	if ((_index < 0) || !audio_exists(_index)) {
		_index = -1;
	}
	variable_struct_set(global.audioAssets, _name, _index);
	return _index;
}

// ------------------------------------------------------------
// Setup
// ------------------------------------------------------------

function sfx_init() {
	global.sfx = {
		lastPlayed: {},
		lastVariant: {},
		layers: {},
		emitter: audio_emitter_create(),
		battleX: 0,
		battleY: 0,
		battleActive: false,
		hoverKey: "",
		menuKey: "",
		menuPage: ""
	};
	audio_falloff_set_model(audio_falloff_linear_distance_clamped);
	audio_emitter_falloff(global.sfx.emitter, SFX_FALLOFF_REF, SFX_FALLOFF_MAX, 1);
	audio_emitter_gain(global.sfx.emitter, 1);
}

function sfx_cleanup() {
	if (variable_global_exists("sfx")) {
		audio_emitter_free(global.sfx.emitter);
	}
}

function sfx_volume_setting() {
	return global.options.sfxVolume / 100;
}

// ------------------------------------------------------------
// One shots
// ------------------------------------------------------------

function sfx_pick_asset(_key, _def) {
	var _count = array_length(_def.assetNames);
	if (_count == 0) {
		return -1;
	}
	var _start = irandom(_count - 1);
	var _last = variable_struct_exists(global.sfx.lastVariant, _key) ? variable_struct_get(global.sfx.lastVariant, _key) : -1;
	if ((_count > 1) && (_start == _last)) {
		_start = (_start + 1) mod _count;
	}
	// Take the first variant that exists, starting from the random pick
	for (var _i = 0; _i < _count; _i++) {
		var _index = (_start + _i) mod _count;
		var _asset = audio_get_asset(_def.assetNames[_index]);
		if (_asset != -1) {
			variable_struct_set(global.sfx.lastVariant, _key, _index);
			return _asset;
		}
	}
	return -1;
}

function sfx_play(_key) {
	return sfx_play_scaled(_key, 1);
}


function sfx_play_scaled(_key, _scale) {
    show_debug_message("=== SFX PLAY: " + string(_key) + " ===");

    if (!variable_struct_exists(global.sfxDefs, _key)) {
        show_debug_message("FAILED: sound definition missing");
        return -1;
    }

    var _def = variable_struct_get(global.sfxDefs, _key);

    var _last = variable_struct_exists(global.sfx.lastPlayed, _key)
        ? variable_struct_get(global.sfx.lastPlayed, _key)
        : -999999;

    var _elapsed = current_time - _last;

    show_debug_message("Cooldown: " + string(_def.cooldown));
    show_debug_message("Elapsed: " + string(_elapsed));

    if (_elapsed < _def.cooldown) {
        show_debug_message("FAILED: sound is on cooldown");
        return -1;
    }

    var _asset = sfx_pick_asset(_key, _def);

    show_debug_message("Selected asset: " + string(_asset));

    if (_asset == -1) {
        show_debug_message("FAILED: no valid asset selected");
        return -1;
    }

    var _handle = audio_play_sound(_asset, _def.priority, false);

    show_debug_message("Playback handle: " + string(_handle));

    if (_handle == -1) {
        show_debug_message("FAILED: audio_play_sound returned -1");
        return -1;
    }

    variable_struct_set(global.sfx.lastPlayed, _key, current_time);

    var _volume = _def.volume * _scale * sfx_volume_setting();
    audio_sound_gain(_handle, _volume, 0);
    audio_sound_pitch(_handle, random_range(_def.pitchLow, _def.pitchHigh));

    show_debug_message("Playback started. Volume: " + string(_volume));

    return _handle;
}


// 0 when zoomed right out, 1 when zoomed in (smooth in between)
function get_zoom_near_factor(_g) {
	var _t = clamp((_g.zoom - AMBIENCE_FAR_ZOOM) / (AMBIENCE_NEAR_ZOOM - AMBIENCE_FAR_ZOOM), 0, 1);
	return _t * _t * (3 - 2 * _t);
}

// A one shot at a tile: quieter the further it is from the middle of the screen
function sfx_play_world(_g, _key, _gx, _gy) {
	var _cx = _g.camX + _g.screenW / 2 / _g.zoom;
	var _cy = _g.camY + _g.screenH / 2 / _g.zoom;
	var _dist = point_distance(tile_to_world_x(_gx, _gy), tile_to_world_y(_gx, _gy), _cx, _cy) * _g.zoom;
	var _reach = point_distance(0, 0, _g.screenW, _g.screenH) * 0.75;
	var _volume = clamp(1 - _dist / _reach, 0, 1) * (0.4 + 0.6 * get_zoom_near_factor(_g));
	if (_volume < 0.05) {
		return -1;
	}
	return sfx_play_scaled(_key, _volume);
}

// ------------------------------------------------------------
// Events from the game simulation
// ------------------------------------------------------------

// kind: "build", "spawn", "upgrade" or "demolish". arg is the building or unit type.
function audio_event(_world, _kind, _arg, _gx, _gy, _owner) {
	if (array_length(_world.audioEvents) < 64) {
		array_push(_world.audioEvents, { kind: _kind, arg: _arg, gx: _gx, gy: _gy, owner: _owner });
	}
}

function sfx_process_events(_g) {
	var _events = _g.world.audioEvents;
	_g.world.audioEvents = [];
	for (var _i = 0; _i < array_length(_events); _i++) {
		var _e = _events[_i];
		var _key = "";
		switch (_e.kind) {
			case "build": _key = sfx_get_building_key(_e.arg); break;
			case "spawn": _key = sfx_get_unit_key(_e.arg); break;
			case "upgrade": _key = "upgrade"; break;
			case "demolish": _key = "demolish"; break;
		}
		if (_key != "") {
			sfx_play_world(_g, _key, _e.gx, _e.gy);
		}
	}
}

// ------------------------------------------------------------
// Battles (the simulation reports every hit here)
// ------------------------------------------------------------

function register_combat(_world, _gx, _gy, _ownerA, _ownerB) {
	if ((_ownerA >= 0) && (_ownerA < MAX_NATIONS)) {
		_world.combatTime[_ownerA] = _world.time;
	}
	if ((_ownerB >= 0) && (_ownerB < MAX_NATIONS)) {
		_world.combatTime[_ownerB] = _world.time;
	}
	// Join a battle that is already going nearby, or start a new one
	for (var _i = 0; _i < array_length(_world.battles); _i++) {
		var _b = _world.battles[_i];
		if (tile_distance(_b.gx, _b.gy, _gx, _gy) <= BATTLE_MERGE_RADIUS) {
			_b.gx = lerp(_b.gx, _gx, 0.15);
			_b.gy = lerp(_b.gy, _gy, 0.15);
			_b.heat = min(10, _b.heat + 0.6);
			return;
		}
	}
	array_push(_world.battles, { gx: _gx, gy: _gy, heat: 1 });
}

function update_battles(_world, _dt) {
	for (var _i = array_length(_world.battles) - 1; _i >= 0; _i--) {
		_world.battles[_i].heat -= BATTLE_COOL_RATE * _dt;
		if (_world.battles[_i].heat <= 0) {
			array_delete(_world.battles, _i, 1);
		}
	}
}

// ------------------------------------------------------------
// Loops (ambience and battles) that fade in and out
// ------------------------------------------------------------

function sfx_layers_clear_targets() {
	var _names = variable_struct_get_names(global.sfx.layers);
	for (var _i = 0; _i < array_length(_names); _i++) {
		variable_struct_get(global.sfx.layers, _names[_i]).target = 0;
	}
}

// Adds to the wanted volume of a loop for this frame (0 to 1)
function sfx_layer_want(_key, _amount, _positional) {
	if (_amount <= 0) {
		return;
	}
	if (!variable_struct_exists(global.sfx.layers, _key)) {
		variable_struct_set(global.sfx.layers, _key, { handle: -1, gain: 0, target: 0, positional: _positional });
	}
	var _layer = variable_struct_get(global.sfx.layers, _key);
	_layer.target = min(1, _layer.target + _amount);
}

function sfx_layers_step(_dt) {
	var _names = variable_struct_get_names(global.sfx.layers);
	for (var _i = 0; _i < array_length(_names); _i++) {
		var _key = _names[_i];
		var _layer = variable_struct_get(global.sfx.layers, _key);
		var _def = variable_struct_get(global.sfxDefs, _key);
		_layer.gain = lerp(_layer.gain, _layer.target, min(1, _dt * SFX_LAYER_FADE_SPEED));
		if (abs(_layer.gain - _layer.target) < 0.003) {
			_layer.gain = _layer.target;
		}

		// Lost the sound (for example the audio was stopped elsewhere): start it again when wanted
		if ((_layer.handle != -1) && !audio_is_playing(_layer.handle)) {
			_layer.handle = -1;
		}
		if ((_layer.handle == -1) && (_layer.target > 0.001)) {
			var _asset = audio_get_asset(_def.assetNames[0]);
			if (_asset != -1) {
				if (_layer.positional) {
					_layer.handle = audio_play_sound_on(global.sfx.emitter, _asset, true, _def.priority);
				} else {
					_layer.handle = audio_play_sound(_asset, _def.priority, true);
				}
				audio_sound_gain(_layer.handle, 0, 0);
			}
		}
		if (_layer.handle != -1) {
			audio_sound_gain(_layer.handle, _layer.gain * _def.volume * sfx_volume_setting(), 0);
			if ((_layer.gain <= 0.001) && (_layer.target <= 0.001)) {
				audio_stop_sound(_layer.handle);
				_layer.handle = -1;
			}
		}
	}
}

// Biome under the middle of the screen when zoomed in, wind when zoomed out
function sfx_update_ambience(_g) {
	var _world = _g.world;
	var _cx = _g.camX + _g.screenW / 2 / _g.zoom;
	var _cy = _g.camY + _g.screenH / 2 / _g.zoom;
	var _gx = round(world_to_tile_gx(_cx, _cy));
	var _gy = round(world_to_tile_gy(_cx, _cy));
	var _near = get_zoom_near_factor(_g);

	// Sample a few tiles around the middle so the sound blends as you move over a border
	var _weights = array_create(BIOME.COUNT, 0);
	for (var _ox = -1; _ox <= 1; _ox++) {
		for (var _oy = -1; _oy <= 1; _oy++) {
			var _tx = _gx + _ox * 3;
			var _ty = _gy + _oy * 3;
			var _biome = tile_in_bounds(_world, _tx, _ty) ? ds_grid_get(_world.biome, _tx, _ty) : BIOME.WATER;
			_weights[_biome] += 1 / 9;
		}
	}
	for (var _b = 0; _b < BIOME.COUNT; _b++) {
		sfx_layer_want(global.ambienceKeys[_b], _weights[_b] * _near, false);
	}
	sfx_layer_want(global.ambienceWindKey, 1 - _near, false);
}

// The loudest battle becomes a sound that comes from its centre
function sfx_update_battle(_g) {
	var _world = _g.world;
	var _cx = _g.camX + _g.screenW / 2 / _g.zoom;
	var _cy = _g.camY + _g.screenH / 2 / _g.zoom;
	audio_listener_position(_cx, _cy, SFX_LISTENER_HEIGHT / _g.zoom);
	audio_listener_orientation(0, 0, 1000, 0, AUDIO_LISTENER_UP_Y, 0);

	var _best = undefined;
	var _bestScore = 999999999;
	for (var _i = 0; _i < array_length(_world.battles); _i++) {
		var _b = _world.battles[_i];
		var _dist = point_distance(tile_to_world_x(_b.gx, _b.gy), tile_to_world_y(_b.gx, _b.gy), _cx, _cy);
		var _score = _dist / (0.5 + _b.heat);
		if (_score < _bestScore) {
			_bestScore = _score;
			_best = _b;
		}
	}
	if (_best == undefined) {
		global.sfx.battleActive = false;
		return;
	}
	var _bx = tile_to_world_x(_best.gx, _best.gy);
	var _by = tile_to_world_y(_best.gx, _best.gy);
	if (global.sfx.battleActive) {
		global.sfx.battleX = lerp(global.sfx.battleX, _bx, 0.15);
		global.sfx.battleY = lerp(global.sfx.battleY, _by, 0.15);
	} else {
		global.sfx.battleX = _bx;
		global.sfx.battleY = _by;
	}
	global.sfx.battleActive = true;
	audio_emitter_position(global.sfx.emitter, global.sfx.battleX, global.sfx.battleY, 0);

	// Zoomed in you hear the full fight, zoomed out the muffled version
	var _intensity = clamp(_best.heat / 4, 0.35, 1);
	var _near = get_zoom_near_factor(_g);
	sfx_layer_want("battle_near", _intensity * _near, true);
	sfx_layer_want("battle_far", _intensity * (1 - _near), true);
}

function sfx_update(_g, _dt) {
	sfx_layers_clear_targets();
	if (_g.world != undefined) {
		if (_g.gameState == GAME_STATE.PLAYING) {
			sfx_process_events(_g);
			sfx_update_ambience(_g);
			sfx_update_battle(_g);
		} else {
			// The menu's background game is silent apart from the music
			_g.world.audioEvents = [];
		}
	}
	sfx_layers_step(_dt);
}

// ------------------------------------------------------------
// Hover sounds (call these once per step)
// ------------------------------------------------------------

// In game: plays ui_hover when the mouse moves onto a different HUD button
function sfx_hud_hover(_g) {
	var _button = get_hud_button_at(_g, device_mouse_x_to_gui(0), device_mouse_y_to_gui(0));
	var _key = "";
	if (_button != undefined) {
		_key = string(_button.zone) + ":" + string(_button.x) + ":" + string(_button.y);
	}
	if ((_key != "") && (_key != global.sfx.hoverKey)) {
		sfx_play("ui_hover");
	}
	global.sfx.hoverKey = _key;
}

// In the main menu: plays ui_hover when the highlighted item changes (mouse or keys)
function sfx_menu_hover(_g) {
	var _key = string(_g.menuPage) + ":" + string(_g.menuFocus);
	if ((global.sfx.menuKey != "") && (_key != global.sfx.menuKey) && (string(_g.menuPage) == global.sfx.menuPage)) {
		sfx_play("ui_hover");
	}
	global.sfx.menuKey = _key;
	global.sfx.menuPage = string(_g.menuPage);
}

// Shows what the audio system is doing.
function audio_debug_text() {
	var _s = "AUDIO updates: " + string(global.audioTicks) + "\n";
	_s += "music current: " + global.music.current + "\n";
	var _names = variable_struct_get_names(global.music.tracks);
	for (var _i = 0; _i < array_length(_names); _i++) {
		var _t = variable_struct_get(global.music.tracks, _names[_i]);
		var _def = variable_struct_get(global.musicDefs, _names[_i]);
		_s += _names[_i] + ": asset " + string(audio_get_asset(_def.assetName)) + ", handle " + string(_t.handle) + ", gain " + string(_t.gain) + "\n";
	}
	var _layers = variable_struct_get_names(global.sfx.layers);
	for (var _i = 0; _i < array_length(_layers); _i++) {
		var _l = variable_struct_get(global.sfx.layers, _layers[_i]);
		_s += _layers[_i] + ": handle " + string(_l.handle) + ", gain " + string(_l.gain) + "\n";
	}
	return _s;
}