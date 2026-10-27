// Step event of obj_game

var _dt = min(delta_time / 1000000, 0.1);

camera_update_size(id, false);

if (toastTimer > 0) {
	toastTimer -= _dt;
}

// The main menu runs its own input and the background demo game
if (gameState == GAME_STATE.MENU) {
	menu_update(id, _dt);
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
update_world(world, _dt);

// F1 toggles the debug overlay (mouse and camera numbers)
if (keyboard_check_pressed(vk_f1)) {
	debugOverlay = !debugOverlay;
}

// Debug: regenerate the map
// R = new seed, Tab = next map type
if (keyboard_check_pressed(ord("R")) || keyboard_check_pressed(vk_tab)) {
	if (keyboard_check_pressed(vk_tab)) {
		settings.mapPreset = (settings.mapPreset + 1) mod array_length(global.mapPresets);
	}
	settings.seed = irandom(999999);
	destroy_world(world);
	world = create_world(settings);
	localNation = world.localNation;
	selectedUnitIds = [];
	selectedCityId = NO_ID;
	selectedBuildingId = NO_ID;
	panel = PANEL.NONE;
	placeType = NO_ID;
	if (localNation != NO_ID) {
		var _capital = bot_get_first_city(world, localNation);
		if (_capital != undefined) {
			camera_focus_tile(id, _capital.gx, _capital.gy);
		}
	}
}