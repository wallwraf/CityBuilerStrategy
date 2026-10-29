// ============================================================
// scr_audio_config: everything you might want to change about the audio lives in THIS script.
//
// Sound assets are referenced by NAME (a string), so the game runs fine while a sound does not
// exist yet: a missing asset is simply silent. To add a sound, import it into GameMaker with the
// same name as written below (or change the name here).
//
// The audio is split into two independent modules that share this config:
//   scr_sfx    sound effects and ambience (UI, building, spawning, biome loops, battles)
//   scr_music  music tracks and the transitions between them
// ============================================================

// ------------------------------------------------------------
// Tuning
// ------------------------------------------------------------

// Seconds without combat before conflict music returns to ambience.
#macro MUSIC_PEACE_DELAY 15

// Zoom levels for ambience. At or above NEAR you hear the biome under the camera,
// at or below FAR you hear only the wind, and in between they crossfade.
#macro AMBIENCE_NEAR_ZOOM 1.3
#macro AMBIENCE_FAR_ZOOM  0.7

// Battle sounds come from a point in the world. The "listener" hovers above the camera, higher the
// further you zoom out, so zooming out makes the battle quieter. Distances are in world pixels.
#macro SFX_LISTENER_HEIGHT 900
#macro SFX_FALLOFF_REF 300
#macro SFX_FALLOFF_MAX 2400

// If battles pan to the wrong side (left and right swapped), change this from 1 to -1
#macro AUDIO_LISTENER_UP_Y 1

// How close hits must be (in tiles) to count as the same battle, and how fast a battle cools down
#macro BATTLE_MERGE_RADIUS 6
#macro BATTLE_COOL_RATE 1.5

// How fast loops fade in and out (higher is faster)
#macro SFX_LAYER_FADE_SPEED 2.5

// ------------------------------------------------------------
// The sound list
// ------------------------------------------------------------

function init_audio() {
	global.audioAssets = {};
	global.sfxDefs = {};
	global.musicDefs = {};
	global.musicTransitions = [];

	// ---------- User interface ----------
	// sfx_define(key, [asset names (a random one plays)], volume 0-1, pitch low, pitch high, cooldown in ms)
	sfx_define("ui_hover", ["snd_ui_hover"], 0.5, 0.95, 1.05, 40);
	sfx_define("ui_click", ["snd_ui_click"], 0.8, 0.97, 1.03, 40);
	sfx_define("ui_back", ["snd_ui_back"], 0.8, 0.97, 1.03, 40);
	sfx_define("ui_error", ["snd_ui_error"], 0.7, 1, 1, 150);
	sfx_define("ui_tick", ["snd_ui_tick"], 0.6, 0.95, 1.05, 40);

	// ---------- Buildings ----------
	// One sound per building type. "build_default" plays for any building without its own sound.
	sfx_define("build_default", ["snd_build_default"], 0.8, 0.95, 1.05, 60);
	sfx_define_building(BUILDING.BARRACKS, ["snd_build_barracks"]);
	sfx_define_building(BUILDING.PORT, ["snd_build_port"]);
	sfx_define_building(BUILDING.WALL, ["snd_build_wall"]);
	sfx_define_building(BUILDING.GATE, ["snd_build_gate"]);
	sfx_define_building(BUILDING.PATH, ["snd_build_path"]);
	sfx_define_building(BUILDING.TOWER, ["snd_build_tower"]);
	sfx_define_building(BUILDING.NAVAL_MINE, ["snd_build_naval_mine"]);
	sfx_define_building(BUILDING.GARRISON, ["snd_build_garrison"]);
	sfx_define_building(BUILDING.HOSPITAL, ["snd_build_hospital"]);
	sfx_define_building(BUILDING.LABORATORY, ["snd_build_laboratory"]);
	sfx_define_building(BUILDING.LUMBER_MILL, ["snd_build_lumber_mill"]);
	sfx_define_building(BUILDING.QUARRY, ["snd_build_quarry"]);
	sfx_define_building(BUILDING.MINE, ["snd_build_mine"]);
	sfx_define_building(BUILDING.MARKET, ["snd_build_market"]);
	sfx_define_building(BUILDING.EMBASSY, ["snd_build_embassy"]);

	sfx_define("upgrade", ["snd_upgrade"], 0.8, 0.98, 1.02, 80);
	sfx_define("demolish", ["snd_demolish"], 0.85, 0.95, 1.05, 80);

	// ---------- Units ----------
	// "spawn_default" plays for any unit without its own sound. Add one with sfx_define_unit, e.g.
	// sfx_define_unit(UNIT_TYPE.HORSEMAN, ["snd_spawn_horse"]);
	sfx_define("spawn_default", ["snd_spawn_unit"], 0.7, 0.95, 1.05, 80);
	sfx_define_unit(UNIT_TYPE.EXPLORER, ["snd_spawn_explorer"]);
	sfx_define_unit(UNIT_TYPE.HORSEMAN, ["snd_spawn_horse"]);

	// ---------- Ambience loops ----------
	// sfx_define_loop(key, asset name, volume 0-1)
	sfx_define_loop("amb_grassland", "snd_amb_grassland", 0.6);
	sfx_define_loop("amb_forest", "snd_amb_forest", 0.6);
	sfx_define_loop("amb_desert", "snd_amb_desert", 0.6);
	sfx_define_loop("amb_snow", "snd_amb_snow", 0.6);
	sfx_define_loop("amb_mountain", "snd_amb_mountain", 0.6);
	sfx_define_loop("amb_ocean", "snd_amb_ocean", 0.6);
	sfx_define_loop("amb_wind", "snd_amb_wind", 0.6);

	// Which loop plays for which biome under the middle of the screen, and the zoomed out loop
	global.ambienceKeys = [];
	global.ambienceKeys[BIOME.GRASSLAND] = "amb_grassland";
	global.ambienceKeys[BIOME.FOREST] = "amb_forest";
	global.ambienceKeys[BIOME.DESERT] = "amb_desert";
	global.ambienceKeys[BIOME.SNOW] = "amb_snow";
	global.ambienceKeys[BIOME.MOUNTAIN] = "amb_mountain";
	global.ambienceKeys[BIOME.WATER] = "amb_ocean";
	global.ambienceWindKey = "amb_wind";

	// ---------- Battles ----------
	// Two versions of the fighting loop. The muffled one takes over as you zoom out. If you only
	// have one sound, use the same asset name for both.
	sfx_define_loop("battle_near", "snd_battle_loop", 0.9);
	sfx_define_loop("battle_far", "snd_battle_loop_muffled", 0.9);
	// Battle Outcomes (win/loss)
	sfx_define("victory", ["snd_victory"], 1.0, 1, 1, 0);
	sfx_define("defeat", ["snd_defeat"], 1.0, 1, 1, 0);

	// ---------- Music ----------
	// music_define(key, asset name, volume 0-1)
	music_define("menu", "mus_menu", 0.8);
	music_define("ambient", "mus_ambient", 0.7);
	music_define("conflict", "mus_conflict", 0.85);

	// music_define_transition(from, to, seconds to fade the old track out, seconds to fade the new one in)
	// "*" matches any track. The most specific rule wins, and anything unlisted takes 2 seconds.
	music_define_transition("ambient", "conflict", 1.5, 1);
	music_define_transition("conflict", "ambient", 6, 6);
	music_define_transition("menu", "ambient", 3, 3);
	music_define_transition("*", "menu", 2, 1.5);
}