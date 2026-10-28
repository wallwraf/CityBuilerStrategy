// Create event of obj_game (place one instance of obj_game in your room)

// Load all static data (biomes, units, nations, map presets), then the saved options
init_game_data();
load_options();

// Keep the pixel look crisp
gpu_set_texfilter(false);

// The game starts on the main menu
gameState = GAME_STATE.MENU;

// Game settings. The menu changes mapPreset and seed, the rest will come from a lobby later.
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
	seed: 0
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
panelScroll = 0;

// Building placement mode: placeType is the building being placed, NO_ID when not placing
// For walls and gates placeGx / placeGy is the edge position and placeAxis is 0 or 1
placeType = NO_ID;
placeGx = 0;
placeGy = 0;
placeAxis = 0;
placeMsg = "";

// Demolish tool and path painting
demolishMode = false;
painted = false;
paintGx = -1;
paintGy = -1;

// There is no world until the menu builds one (the menu shows a simulated game)
world = undefined;
localNation = NO_ID;
renameCityId = NO_ID;
renameText = "";

// Initialise game
camera_init(id);
menu_init(id);
menu_start_demo(id);
net_init();
audio_init(id);