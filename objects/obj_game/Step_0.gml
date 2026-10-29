// Step event of obj_game

var _dt = min(delta_time / 1000000, 0.1);

audio_update(id, _dt);
net_step(id);
camera_update_size(id, false);

if (toastTimer > 0) {
	toastTimer -= _dt;
}

// The main menu runs its own input and the background demo game
if (gameState == GAME_STATE.MENU) {
	menu_update(id, _dt);
	sfx_menu_hover(id);
	exit;
}

// Escape twice (with nothing selected to cancel) goes back to the main menu
if (menuExitTimer > 0) {
	menuExitTimer -= _dt;
}
if (keyboard_check_pressed(vk_escape) && (placeType == NO_ID) && (array_length(selectedUnitIds) == 0) && (selectedCityId == NO_ID) && (selectedBuildingId == NO_ID) && (panel == PANEL.NONE)) {
	if (menuExitTimer > 0) {
		menu_return(id);
		exit;
	}
	menuExitTimer = 2.5;
	set_toast(id, "Press Escape again to return to the main menu");
}

update_input(id);
net_update_world(id, _dt);

if (update_end_screen(id, _dt)) {
	menu_return(id);
	exit;
}

// F1 toggles the debug overlay (mouse and camera numbers)
if (keyboard_check_pressed(vk_f1)) {
	debugOverlay = !debugOverlay;
}

if (keyboard_check_pressed(ord("K"))) {
    var _asset = audio_get_asset("snd_victory");

    show_debug_message("=== DIRECT VICTORY TEST ===");
    show_debug_message("Asset: " + string(_asset));

    var _handle = audio_play_sound(_asset, 0, false);

    show_debug_message("Direct playback handle: " + string(_handle));
}

if (keyboard_check_pressed(ord("L"))) {
    var _asset = audio_get_asset("snd_defeat");

    show_debug_message("=== DIRECT DEFEAT TEST ===");
    show_debug_message("Asset: " + string(_asset));

    var _handle = audio_play_sound(_asset, 0, false);

    show_debug_message("Direct playback handle: " + string(_handle));
}