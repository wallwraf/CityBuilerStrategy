// Create event of obj_game (place one instance of obj_game in your room)

// Load all static data (biomes, units, nations, map presets)
init_game_data();

// Keep the pixel look crisp
gpu_set_texfilter(false);

// Game settings. These will come from a lobby screen later.
// nationCount: nations in the game (2 to 8)
// botCount: how many of those are bots
// vacantCount: how many are left open for players to join
// The rest are human players
settings = {
	nationCount: 4,
	botCount: 3,
	vacantCount: 0,
	mapPreset: 0,
	mapWidth: 64,
	mapHeight: 64,
	seed: irandom(999999)
};

// Camera, input and UI state
camX = 0;
camY = 0;
zoom = 1;
screenW = window_get_width();
screenH = window_get_height();
panning = false;
panAnchorX = 0;
panAnchorY = 0;
dragging = false;
dragStartX = 0;
dragStartY = 0;
dragStartMx = 0;
dragStartMy = 0;
uiCapture = false;
mouseWx = 0;
mouseWy = 0;
hoverGx = -1;
hoverGy = -1;
selectedUnitIds = [];
selectedCityId = NO_ID;
toastText = "";
toastTimer = 0;
debugOverlay = false;
selectedBuildingId = NO_ID;

// Which side panel is open (PANEL.NONE, BUILD, RESEARCH, DIPLOMACY or IDEOLOGY)
panel = PANEL.NONE;

// Building placement mode: placeType is the building being placed, NO_ID when not placing
// For walls and gates placeGx / placeGy is the edge position and placeAxis is 0 or 1
placeType = NO_ID;
placeGx = 0;
placeGy = 0;
placeAxis = 0;
placeMsg = "";

// Build the world and start the camera on our capital
world = create_world(settings);
localNation = world.localNation;
camera_init(id);

if (localNation != NO_ID) {
	var _capital = bot_get_first_city(world, localNation);
	if (_capital != undefined) {
		camera_focus_tile(id, _capital.gx, _capital.gy);
	}
}
