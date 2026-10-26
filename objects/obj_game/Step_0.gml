// Step event of obj_game

var _dt = min(delta_time / 1000000, 0.1);

camera_update_size(id, false);
update_input(id);

update_world(world, _dt);

// F1 toggles the debug overlay (mouse and camera numbers)
if (keyboard_check_pressed(vk_f1)) {
	debugOverlay = !debugOverlay;
}

if (toastTimer > 0) {
	toastTimer -= _dt;
}

// Debug: regenerate the map until we have a lobby screen
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
