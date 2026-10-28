// ============================================================
// scr_music: the music manager. It knows nothing about sound effects.
//
// Tracks are defined in scr_audio_config. music_request(key) crossfades to a track using the
// fade times of the matching music_define_transition rule. Each track keeps its own fade, so
// asking for the old track again halfway through a fade just turns it back up.
// ============================================================

function music_init() {
	global.music = {
		current: "",
		tracks: {}
	};
}

function music_define(_key, _assetName, _volume) {
	variable_struct_set(global.musicDefs, _key, { assetName: _assetName, volume: _volume });
}

function music_define_transition(_from, _to, _fadeOut, _fadeIn) {
	array_push(global.musicTransitions, { from: _from, to: _to, fadeOut: _fadeOut, fadeIn: _fadeIn });
}

// Exact rule first, then "from to *", then "* to to", then "* to *", then 2 seconds each way
function music_get_transition(_from, _to) {
	var _best = { fadeOut: 2, fadeIn: 2 };
	var _bestScore = -1;
	for (var _i = 0; _i < array_length(global.musicTransitions); _i++) {
		var _t = global.musicTransitions[_i];
		var _fromMatch = (_t.from == _from);
		var _toMatch = (_t.to == _to);
		if (!(_fromMatch || (_t.from == "*")) || !(_toMatch || (_t.to == "*"))) {
			continue;
		}
		var _score = (_fromMatch ? 2 : 0) + (_toMatch ? 1 : 0);
		if (_score > _bestScore) {
			_bestScore = _score;
			_best = _t;
		}
	}
	return _best;
}

function music_get_track(_key) {
	if (!variable_struct_exists(global.music.tracks, _key)) {
		variable_struct_set(global.music.tracks, _key, { handle: -1, gain: 0, target: 0, rate: 1 });
	}
	return variable_struct_get(global.music.tracks, _key);
}

// Crossfades to a track. Asking for the track that is already playing does nothing.
function music_request(_key) {
	if ((_key == global.music.current) || !variable_struct_exists(global.musicDefs, _key)) {
		return;
	}
	var _transition = music_get_transition(global.music.current, _key);

	// Everything playing fades out...
	var _names = variable_struct_get_names(global.music.tracks);
	for (var _i = 0; _i < array_length(_names); _i++) {
		var _old = variable_struct_get(global.music.tracks, _names[_i]);
		if (_old.target > 0) {
			_old.target = 0;
			_old.rate = 1 / max(0.05, _transition.fadeOut);
		}
	}
	// ...while the new track fades in
	var _track = music_get_track(_key);
	_track.target = 1;
	_track.rate = 1 / max(0.05, _transition.fadeIn);
	global.music.current = _key;
}

function music_step(_dt) {
	var _volume = global.options.musicVolume / 100;
	var _names = variable_struct_get_names(global.music.tracks);
	for (var _i = 0; _i < array_length(_names); _i++) {
		var _key = _names[_i];
		var _track = variable_struct_get(global.music.tracks, _key);
		var _def = variable_struct_get(global.musicDefs, _key);

		// Linear fade toward the target
		if (_track.gain < _track.target) {
			_track.gain = min(_track.target, _track.gain + _track.rate * _dt);
		} else if (_track.gain > _track.target) {
			_track.gain = max(_track.target, _track.gain - _track.rate * _dt);
		}

		if ((_track.handle != -1) && !audio_is_playing(_track.handle)) {
			_track.handle = -1;
		}
		if ((_track.handle == -1) && (_track.target > 0)) {
			var _asset = audio_get_asset(_def.assetName);
			if (_asset != -1) {
				_track.handle = audio_play_sound(_asset, 0, true);
				audio_sound_gain(_track.handle, 0, 0);
			}
		}
		if (_track.handle != -1) {
			audio_sound_gain(_track.handle, _track.gain * _def.volume * _volume, 0);
			if ((_track.gain <= 0) && (_track.target <= 0)) {
				audio_stop_sound(_track.handle);
				_track.handle = -1;
			}
		}
	}
}

// Picks the track for what is going on: menu, ambient, or conflict while the local player is fighting
function music_update(_g, _dt) {
	if ((_g.gameState == GAME_STATE.MENU) || (_g.world == undefined)) {
		music_request("menu");
	} else {
		var _inCombat = false;
		if (_g.localNation != NO_ID) {
			_inCombat = ((_g.world.time - _g.world.combatTime[_g.localNation]) < MUSIC_PEACE_DELAY);
		}
		music_request(_inCombat ? "conflict" : "ambient");
	}
	music_step(_dt);
}

function music_cleanup() {
	if (variable_global_exists("music")) {
		var _names = variable_struct_get_names(global.music.tracks);
		for (var _i = 0; _i < array_length(_names); _i++) {
			var _track = variable_struct_get(global.music.tracks, _names[_i]);
			if (_track.handle != -1) {
				audio_stop_sound(_track.handle);
			}
		}
	}
}