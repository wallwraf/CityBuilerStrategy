// ============================================================
// scr_config: constants, enums and static game data
// ============================================================

// Tile size: a 32x32 tile is a 32 wide, 16 tall diamond top plus 16 pixels of depth (2:1 isometric)
#macro TILE_W 32
#macro TILE_H 16

// The code drawn shapes were designed for 64 wide tiles, this scales them to the tile size
#macro SHAPE_SCALE (TILE_W / 64)

// Nations and ownership
#macro MAX_NATIONS 8
#macro TRIBE_OWNER -1
#macro NO_ID -1

// Cities
#macro MAX_CITY_LEVEL 9

// Camera
#macro MIN_ZOOM 0.5
#macro MAX_ZOOM 4

// Misc
#macro START_GOLD 150
#macro DRAG_THRESHOLD 6
#macro ELEVATION_MOUNTAIN 8

// Diplomacy (seconds)
#macro WAR_DELAY 120
#macro BETRAY_WAR_DELAY 30

// Notices and offers
#macro NOTICE_ALL -2
#macro NOTICE_LIFETIME 8
#macro OFFER_LIFETIME 90

// Bot diplomacy
#macro DOMINANCE_RATIO 1.25
#macro ALIGN_ACCEPT 0.6
#macro BOT_FAVOUR_MAX 60

// Research
#macro BASE_RP_RATE 0.5

// UI
#macro BUTTON_W 158
#macro BUTTON_H 50
#macro TOP_H 36
#macro PANEL_W 290

enum BIOME {
	GRASSLAND,
	FOREST,
	DESERT,
	SNOW,
	MOUNTAIN,
	WATER,
	COUNT
}

// Resource overlay on land tiles (for quarries and mines)
enum RES {
	NONE,
	STONE,
	ORE,
	TREES
}

enum DOMAIN {
	LAND,
	WATER
}

// The order here must match the order of the nation unitNames arrays
enum UNIT_TYPE {
	EXPLORER,
	// Level 1 (city hall)
	WARRIOR,
	SHIELDMAN,
	ARCHER,
	HORSEMAN,
	MEDIC,
	// Level 2 (city hall level 3)
	DUELIST,
	IRONCLAD,
	CROSSBOWMAN,
	LIGHT_CAVALRY,
	COMBAT_ENGINEER,
	// Level 3 (barracks)
	EXECUTIONER,
	TOWER_SHIELD,
	ARTILLERIST,
	WARHOUND,
	SAPPER,
	// Level 4 (barracks level 3)
	ROYAL_CHAMPION,
	BASTION_KNIGHT,
	SIEGE_MARKSMAN,
	SKY_LANCER,
	WAR_PRIEST,
	// Level 5 (garrison)
	DREADNOUGHT_SLAYER,
	COLOSSUS,
	SIEGEBREAKER,
	STORMWING,
	GRAND_ARCANIST,
	// Port and embassy
	BUILDING_BOAT,
	MINESEEKER,
	BATTLESHIP,
	ENVOY,
	TRAVELER_BOAT,
	ENVOY_BOAT,
	COUNT
}

// Where a unit can be bought
enum UNIT_SRC {
	CITY_HALL,
	BARRACKS,
	GARRISON,
	HOSPITAL,
	PORT,
	EMBASSY,
	NONE
}

enum ABILITY {
	NONE,
	HEAL,
	ENGINEER,
	MINELAYER,
	MINESEEK,
	BUFF,
	SLOW,
	ENVOY
}

enum ORDER {
	NONE,
	MOVE,
	ATTACK_UNIT,
	ATTACK_BUILDING,
	ATTACK_CITY,
	DELIVER
}

enum BUILDING {
	BARRACKS,
	PORT,
	WALL,
	GATE,
	PATH,
	TOWER,
	NAVAL_MINE,
	GARRISON,
	HOSPITAL,
	LABORATORY,
	LUMBER_MILL,
	QUARRY,
	MINE,
	MARKET,
	EMBASSY,
	TRAP,
	COUNT
}

// Where a building is allowed to be placed
enum PLACE {
	LAND,
	COAST,
	FOREST,
	STONE,
	ORE,
	WATER,
	NEAR_CITY,
	EDGE,
	PATH
}

enum IDEO {
	FASCIST,
	LIBERAL,
	SOCIALIST,
	COMMUNIST,
	CONSERVATIST,
	COUNT
}

enum RESEARCH {
	FIELD_MEDIC,
	COMBAT_ENGINEERING,
	NAVAL_MINES,
	MINE_RECON,
	// Offense
	SHARPENED_STEEL,
	BATTLE_TACTICS,
	// Defense
	TEMPERED_ARMOR,
	REINFORCED_PLATING,
	// Economy
	TRADE_ROUTES,
	SCHOLARS,
	MERCHANT_GUILDS,
	GRAND_LIBRARY,
	COUNT
}

// The three research branches (the City Hall is the root of the tree)
enum BRANCH {
	OFFENSE,
	DEFENSE,
	ECONOMY
}

// What a research node does besides unlocking things
enum RFX {
	NONE,
	DAMAGE,
	ARMOR,
	GOLD,
	RP
}

enum SLOT_TYPE {
	VACANT,
	BOT,
	HUMAN
}

// Every player action goes through a command (this is what we will send over the network later)
enum CMD {
	MOVE,
	ATTACK,
	FOUND_CITY,
	BUY_UNIT,
	UPGRADE_CITY,
	BUILD,
	UPGRADE_BUILDING,
	TRAIN_UNIT,
	RESEARCH,
	SEND_ENVOY,
	PLACE_MINE,
	DECLARE_WAR,
	ANSWER_OFFER,
	TOGGLE_CARGO,
	CONNECT_PATH,
	DEMOLISH,
	RENAME_CITY
}

// Which side panel is open
enum PANEL {
	NONE,
	BUILD,
	RESEARCH,
	DIPLOMACY,
	IDEOLOGY
}

// What a HUD button does when clicked
enum UI_ACT {
	TOGGLE_PANEL,
	PICK_BUILDING,
	BUY_UNIT,
	TRAIN_UNIT,
	UPGRADE_CITY,
	UPGRADE_BUILDING,
	FOUND_CITY,
	RESEARCH,
	SEND_ENVOY,
	PLACE_MINE,
	DECLARE_WAR,
	ANSWER_OFFER,
	TOGGLE_CARGO,
	TOGGLE_DEMOLISH,
	DEMOLISH,
	RENAME_CITY,
	NONE
}

function init_game_data() {
	init_biomes();
	init_unit_stats();
	init_building_defs();
	init_research_defs();
	init_nations();
	init_map_presets();
	init_ideologies();
}

function init_biomes() {
	global.biomeColours = [];
	global.biomeColours[BIOME.GRASSLAND] = make_colour_rgb(106, 170, 80);
	global.biomeColours[BIOME.FOREST] = make_colour_rgb(58, 120, 62);
	global.biomeColours[BIOME.DESERT] = make_colour_rgb(222, 195, 120);
	global.biomeColours[BIOME.SNOW] = make_colour_rgb(228, 238, 245);
	global.biomeColours[BIOME.MOUNTAIN] = make_colour_rgb(128, 124, 120);
	global.biomeColours[BIOME.WATER] = make_colour_rgb(58, 110, 184);
}

// ------------------------------------------------------------
// Units
// ------------------------------------------------------------

// Fills in defaults, then copies every field from _extra over the top
function define_unit(_type, _subtitle, _role, _desc, _source, _cost, _hp, _damage, _range, _moveRange, _moveDelay, _attackDelay, _extra) {
	var _def = {
		subtitle: _subtitle,
		role: _role,
		desc: _desc,
		source: _source,
		cost: _cost,
		maxHp: _hp,
		damage: _damage,
		range: _range,
		moveRange: _moveRange,
		moveDelay: _moveDelay,
		attackDelay: _attackDelay,
		tier: 1,
		domain: DOMAIN.LAND,
		armor: 0,
		passSolid: false,
		targetable: true,
		ability: ABILITY.NONE,
		splash: 0,
		buildingMult: 1,
		healRate: 0,
		healRadius: 0,
		buffMult: 1,
		slowRadius: 0,
		slowMult: 1,
		seekRadius: 0,
		reqCityLevel: 1,
		reqBuildingLevel: 1,
		reqResearch: NO_ID,
		weight: 1,
		capacity: 0,
		diplomat: false
	};
	var _names = variable_struct_get_names(_extra);
	for (var _i = 0; _i < array_length(_names); _i++) {
		variable_struct_set(_def, _names[_i], variable_struct_get(_extra, _names[_i]));
	}
	global.unitStats[_type] = _def;
}

function init_unit_stats() {
	// define_unit(type, generic name, role, description, source, cost, hp, damage, range, moveRange, moveDelay, attackDelay, extras)
	// moveDelay and attackDelay are in seconds. range and moveRange are in tiles.
	// armor is the fraction of damage ignored. passSolid lets a unit cross solid (not forced solid) buildings.
	global.unitStats = [];

	define_unit(UNIT_TYPE.EXPLORER, "Explorer", "Special", "Founds cities on habitable tiles", UNIT_SRC.CITY_HALL, 50, 30, 0, 1, 1, 0.9, 1.0, { tier: 0 });

	// Level 1
	define_unit(UNIT_TYPE.WARRIOR, "Warrior", "DPS", "Basic melee damage", UNIT_SRC.CITY_HALL, 60, 50, 10, 1, 1, 1.0, 1.0, { tier: 1 });
	define_unit(UNIT_TYPE.SHIELDMAN, "Shieldman", "Tank", "Frontline defender", UNIT_SRC.CITY_HALL, 70, 90, 4, 1, 1, 1.1, 1.1, { tier: 1, armor: 0.25 });
	define_unit(UNIT_TYPE.ARCHER, "Archer", "Ranged", "Basic ranged attacker", UNIT_SRC.CITY_HALL, 75, 32, 8, 2, 1, 1.0, 1.1, { tier: 1 });
	define_unit(UNIT_TYPE.HORSEMAN, "Horseman", "Movement", "Fast reconnaissance", UNIT_SRC.CITY_HALL, 90, 40, 6, 1, 2, 0.8, 0.9, { tier: 1 });
	define_unit(UNIT_TYPE.MEDIC, "Medic", "Special", "Low-level healing support", UNIT_SRC.HOSPITAL, 65, 30, 0, 1, 1, 1.0, 1.0, { tier: 1, ability: ABILITY.HEAL, healRate: 2.5, healRadius: 1, reqResearch: RESEARCH.FIELD_MEDIC });

	// Level 2 (city hall level 3)
	define_unit(UNIT_TYPE.DUELIST, "Duelist", "DPS", "High single-target melee damage", UNIT_SRC.CITY_HALL, 110, 55, 19, 1, 1, 1.0, 0.8, { tier: 2, reqCityLevel: 3 });
	define_unit(UNIT_TYPE.IRONCLAD, "Ironclad", "Tank", "Armoured infantry", UNIT_SRC.CITY_HALL, 130, 140, 6, 1, 1, 1.2, 1.1, { tier: 2, armor: 0.4, reqCityLevel: 3 });
	define_unit(UNIT_TYPE.CROSSBOWMAN, "Crossbowman", "Ranged", "Higher ranged damage", UNIT_SRC.CITY_HALL, 120, 38, 14, 2, 1, 1.0, 1.3, { tier: 2, reqCityLevel: 3 });
	define_unit(UNIT_TYPE.LIGHT_CAVALRY, "Light Cavalry", "Movement", "Same speed, better damage", UNIT_SRC.CITY_HALL, 130, 48, 9, 1, 2, 0.8, 0.9, { tier: 2, reqCityLevel: 3 });
	define_unit(UNIT_TYPE.COMBAT_ENGINEER, "Combat Engineer", "Special", "Lays low damage traps around itself", UNIT_SRC.BARRACKS, 100, 40, 3, 1, 1, 1.0, 1.2, { tier: 2, ability: ABILITY.ENGINEER, reqResearch: RESEARCH.COMBAT_ENGINEERING });

	// Level 3 (barracks)
	define_unit(UNIT_TYPE.EXECUTIONER, "Executioner", "DPS", "Heavy melee damage", UNIT_SRC.BARRACKS, 190, 70, 30, 1, 1, 1.1, 1.5, { tier: 3 });
	define_unit(UNIT_TYPE.TOWER_SHIELD, "Tower Shield", "Tank", "Heavy defense", UNIT_SRC.BARRACKS, 200, 200, 5, 1, 1, 1.3, 1.2, { tier: 3, armor: 0.55 });
	define_unit(UNIT_TYPE.ARTILLERIST, "Artillerist", "Ranged", "Longer ranged damage", UNIT_SRC.BARRACKS, 210, 40, 22, 3, 1, 1.2, 2.0, { tier: 3 });
	define_unit(UNIT_TYPE.WARHOUND, "Warhound Cavalry", "Movement", "Faster movement", UNIT_SRC.BARRACKS, 200, 55, 12, 1, 3, 0.7, 0.9, { tier: 3 });
	define_unit(UNIT_TYPE.SAPPER, "Sapper", "Special", "Breaches walls and buildings (4x building damage)", UNIT_SRC.BARRACKS, 180, 45, 8, 1, 1, 1.0, 1.2, { tier: 3, buildingMult: 4 });

	// Level 4 (barracks level 3)
	define_unit(UNIT_TYPE.ROYAL_CHAMPION, "Royal Champion", "DPS", "Elite melee damage", UNIT_SRC.BARRACKS, 330, 110, 32, 1, 1, 1.0, 0.9, { tier: 4, reqBuildingLevel: 3 });
	define_unit(UNIT_TYPE.BASTION_KNIGHT, "Bastion Knight", "Tank", "Elite frontline anchor", UNIT_SRC.BARRACKS, 340, 260, 10, 1, 1, 1.3, 1.1, { tier: 4, armor: 0.6, reqBuildingLevel: 3 });
	define_unit(UNIT_TYPE.SIEGE_MARKSMAN, "Siege Marksman", "Ranged", "Precision ranged attacker", UNIT_SRC.BARRACKS, 350, 50, 38, 3, 1, 1.1, 1.8, { tier: 4, reqBuildingLevel: 3 });
	define_unit(UNIT_TYPE.SKY_LANCER, "Sky Lancer", "Movement", "High mobile assault unit, leaps over walls", UNIT_SRC.BARRACKS, 360, 80, 26, 1, 3, 0.7, 0.9, { tier: 4, passSolid: true, reqBuildingLevel: 3 });
	define_unit(UNIT_TYPE.WAR_PRIEST, "War Priest", "Special", "High-level healing and +25% damage for allies within 2 tiles", UNIT_SRC.BARRACKS, 380, 70, 8, 1, 1, 1.0, 1.2, { tier: 4, ability: ABILITY.BUFF, healRate: 5, healRadius: 2, buffMult: 1.25, reqBuildingLevel: 3 });

	// Level 5 (garrison)
	define_unit(UNIT_TYPE.DREADNOUGHT_SLAYER, "Dreadnought Slayer", "DPS", "Ultimate damage dealer", UNIT_SRC.GARRISON, 600, 180, 55, 1, 1, 1.0, 1.0, { tier: 5 });
	define_unit(UNIT_TYPE.COLOSSUS, "Colossus", "Tank", "Ultimate frontline tank", UNIT_SRC.GARRISON, 600, 450, 14, 1, 1, 1.5, 1.3, { tier: 5, armor: 0.65 });
	define_unit(UNIT_TYPE.SIEGEBREAKER, "Siegebreaker Cannon", "Ranged", "Ultimate long-range artillery with splash", UNIT_SRC.GARRISON, 650, 70, 60, 4, 1, 1.4, 2.5, { tier: 5, splash: 1, buildingMult: 2 });
	define_unit(UNIT_TYPE.STORMWING, "Stormwing", "Movement", "Ultimate mobility assassination unit", UNIT_SRC.GARRISON, 640, 90, 42, 1, 4, 0.6, 0.8, { tier: 5, passSolid: true });
	define_unit(UNIT_TYPE.GRAND_ARCANIST, "Grand Arcanist", "Special", "Slows enemy attack speed within 2 tiles", UNIT_SRC.GARRISON, 700, 100, 10, 2, 1, 1.1, 1.3, { tier: 5, ability: ABILITY.SLOW, slowRadius: 2, slowMult: 1.6 });

	// Port
	define_unit(UNIT_TYPE.BUILDING_BOAT, "Building Boat", "Special", "Places naval mines", UNIT_SRC.PORT, 120, 60, 0, 1, 1, 1.0, 1.0, { tier: 0, domain: DOMAIN.WATER, ability: ABILITY.MINELAYER, reqResearch: RESEARCH.NAVAL_MINES });
	define_unit(UNIT_TYPE.MINESEEKER, "Mineseeker", "Special", "Spots naval mines in a 3 tile radius", UNIT_SRC.PORT, 110, 50, 0, 1, 1, 0.9, 1.0, { tier: 0, domain: DOMAIN.WATER, ability: ABILITY.MINESEEK, seekRadius: 3, reqResearch: RESEARCH.MINE_RECON });
	define_unit(UNIT_TYPE.BATTLESHIP, "Battleship", "Ranged", "Hits everything within 2 tiles, land troops included", UNIT_SRC.PORT, 420, 260, 24, 2, 1, 1.2, 1.6, { tier: 3, domain: DOMAIN.WATER });

	// Embassy
	define_unit(UNIT_TYPE.ENVOY, "Envoy", "Special", "Carries a peace treaty to a capital. Walks through units and gates, and sails across water", UNIT_SRC.EMBASSY, 40, 15, 0, 1, 1, 1.0, 1.0, { tier: 0, passSolid: true, targetable: false, diplomat: true, ability: ABILITY.ENVOY });
	define_unit(UNIT_TYPE.ENVOY_BOAT, "Envoy Boat", "Special", "An envoy at sea. Naval mines still sink it", UNIT_SRC.NONE, 40, 15, 0, 1, 1, 1.0, 1.0, { tier: 0, domain: DOMAIN.WATER, passSolid: true, targetable: false, diplomat: true, ability: ABILITY.ENVOY });
	// Port: carries land units across the water (press E next to units to load them, E again to unload)
	define_unit(UNIT_TYPE.TRAVELER_BOAT, "Traveler Boat", "Special", "Press E to load land units within 1 tile, E again to unload", UNIT_SRC.PORT, 140, 80, 0, 1, 1, 1.0, 1.0, { tier: 0, domain: DOMAIN.WATER, capacity: 6 });

	// Weight: every unit weighs 1 or more. A boat holds up to its capacity, and a tile only
	// holds units up to its weight limit (see get_tile_weight_limit). Flyers and envoys cannot be carried.
	global.unitStats[UNIT_TYPE.IRONCLAD].weight = 2;
	global.unitStats[UNIT_TYPE.EXECUTIONER].weight = 2;
	global.unitStats[UNIT_TYPE.TOWER_SHIELD].weight = 2;
	global.unitStats[UNIT_TYPE.ARTILLERIST].weight = 2;
	global.unitStats[UNIT_TYPE.LIGHT_CAVALRY].weight = 2;
	global.unitStats[UNIT_TYPE.WARHOUND].weight = 2;
	global.unitStats[UNIT_TYPE.SIEGE_MARKSMAN].weight = 2;
	global.unitStats[UNIT_TYPE.ROYAL_CHAMPION].weight = 2;
	global.unitStats[UNIT_TYPE.BASTION_KNIGHT].weight = 3;
	global.unitStats[UNIT_TYPE.SIEGEBREAKER].weight = 3;
	global.unitStats[UNIT_TYPE.DREADNOUGHT_SLAYER].weight = 2;
	global.unitStats[UNIT_TYPE.COLOSSUS].weight = 4;
}

// Returns the units a building type can sell, in enum order
function get_units_for_source(_source) {
	var _list = [];
	for (var _t = 0; _t < UNIT_TYPE.COUNT; _t++) {
		if (global.unitStats[_t].source == _source) {
			array_push(_list, _t);
		}
	}
	return _list;
}

// ------------------------------------------------------------
// Buildings
// ------------------------------------------------------------

function define_building(_type, _name, _desc, _cost, _maxLevel, _hp, _place, _extra) {
	var _def = {
		buildingName: _name,
		desc: _desc,
		cost: _cost,
		maxLevel: _maxLevel,
		hp: _hp,
		place: _place,
		// solid: certain units can pass. forceSolid: NO unit can pass. Both default to false.
		solid: false,
		forceSolid: false,
		buildable: true,
		hidden: false,
		incomeBase: 0,
		incomePerLevel: 0,
		triggerDamage: 0,
		reqResearch: NO_ID
	};
	var _names = variable_struct_get_names(_extra);
	for (var _i = 0; _i < array_length(_names); _i++) {
		variable_struct_set(_def, _names[_i], variable_struct_get(_extra, _names[_i]));
	}
	global.buildingDefs[_type] = _def;
}

function init_building_defs() {
	// define_building(type, name, description, cost, max level, hp, placement, extras)
	global.buildingDefs = [];
	define_building(BUILDING.BARRACKS, "Barracks", "Trains level 3 units. Level 3 trains level 4 units", 120, 3, 160, PLACE.LAND, {});
	define_building(BUILDING.PORT, "Port", "Builds ships. Must touch water", 150, 3, 180, PLACE.COAST, {});
	define_building(BUILDING.WALL, "Wall", "Blocks the edge of a tile. Sky units can leap it", 25, 3, 120, PLACE.EDGE, { solid: true });
	define_building(BUILDING.GATE, "Gate", "A wall your own units walk straight through", 45, 3, 120, PLACE.EDGE, { solid: true });
	define_building(BUILDING.PATH, "Path", "Units on your paths move 1 tile further. Sits under buildings, drag to paint. Nearby networks can be linked for gold", 10, 1, 1, PLACE.PATH, {});
	define_building(BUILDING.TOWER, "Tower", "Shoots enemies within 1 tile. Level 9 is twice as fast", 130, 9, 140, PLACE.LAND, {});
	define_building(BUILDING.NAVAL_MINE, "Naval Mine", "Water only. Hidden until enemies get within 1 tile", 60, 1, 20, PLACE.WATER, { hidden: true, triggerDamage: 70, reqResearch: RESEARCH.NAVAL_MINES });
	define_building(BUILDING.GARRISON, "Garrison", "Trains level 5 units", 260, 3, 220, PLACE.LAND, {});
	define_building(BUILDING.HOSPITAL, "Hospital", "Heals your units within 1 tile. Trains Medics", 140, 5, 150, PLACE.LAND, {});
	define_building(BUILDING.LABORATORY, "Laboratory", "+0.5 research points per second per level", 160, 5, 140, PLACE.LAND, {});
	define_building(BUILDING.LUMBER_MILL, "Lumber Mill", "Makes gold. Tree tiles only", 70, 5, 100, PLACE.FOREST, { incomeBase: 0.6, incomePerLevel: 0.3 });
	define_building(BUILDING.QUARRY, "Quarry", "Makes gold. Stone tiles only", 100, 5, 110, PLACE.STONE, { incomeBase: 0.9, incomePerLevel: 0.4 });
	define_building(BUILDING.MINE, "Mine", "Makes gold. Ore tiles only", 150, 5, 120, PLACE.ORE, { incomeBase: 1.4, incomePerLevel: 0.6 });
	define_building(BUILDING.MARKET, "Market", "Makes gold. Within 1 tile of a city centre", 110, 5, 110, PLACE.NEAR_CITY, { incomeBase: 0.8, incomePerLevel: 0.4 });
	define_building(BUILDING.EMBASSY, "Embassy", "Sends envoys to other capitals to offer peace", 180, 3, 150, PLACE.LAND, {});
	define_building(BUILDING.TRAP, "Trap", "Laid by Combat Engineers", 0, 1, 5, PLACE.LAND, { buildable: false, hidden: true, triggerDamage: 14 });
}

// ------------------------------------------------------------
// Research
// ------------------------------------------------------------

function init_research_defs() {
	// The City Hall is the root of the tree and is always researched.
	// branch / row / col place a node in the tree (row 1 hangs off the City Hall, row 2 off a row 1 node).
	// fx / amount are a passive bonus: DAMAGE and ARMOR and GOLD are fractions, RP is research points per second.
	global.researchDefs = [];
	define_research(RESEARCH.COMBAT_ENGINEERING, "Combat Engineering", 45, NO_ID, BRANCH.OFFENSE, 1, 0, RFX.NONE, 0, "Barracks can train Combat Engineers");
	define_research(RESEARCH.SHARPENED_STEEL, "Sharpened Steel", 60, NO_ID, BRANCH.OFFENSE, 1, 1, RFX.DAMAGE, 0.10, "+10% damage for all your units");
	define_research(RESEARCH.NAVAL_MINES, "Naval Mines", 60, RESEARCH.COMBAT_ENGINEERING, BRANCH.OFFENSE, 2, 0, RFX.NONE, 0, "Unlocks naval mines and Building Boats");
	define_research(RESEARCH.BATTLE_TACTICS, "Battle Tactics", 110, RESEARCH.SHARPENED_STEEL, BRANCH.OFFENSE, 2, 1, RFX.DAMAGE, 0.15, "+15% damage for all your units");

	define_research(RESEARCH.FIELD_MEDIC, "Field Medic", 30, NO_ID, BRANCH.DEFENSE, 1, 0, RFX.NONE, 0, "Hospitals can train Medics");
	define_research(RESEARCH.TEMPERED_ARMOR, "Tempered Armor", 60, NO_ID, BRANCH.DEFENSE, 1, 1, RFX.ARMOR, 0.10, "Your units take 10% less damage");
	define_research(RESEARCH.MINE_RECON, "Mine Recon", 50, RESEARCH.FIELD_MEDIC, BRANCH.DEFENSE, 2, 0, RFX.NONE, 0, "Ports can build Mineseekers");
	define_research(RESEARCH.REINFORCED_PLATING, "Reinforced Plating", 110, RESEARCH.TEMPERED_ARMOR, BRANCH.DEFENSE, 2, 1, RFX.ARMOR, 0.10, "Your units take a further 10% less damage");

	define_research(RESEARCH.TRADE_ROUTES, "Trade Routes", 40, NO_ID, BRANCH.ECONOMY, 1, 0, RFX.GOLD, 0.10, "+10% gold income");
	define_research(RESEARCH.SCHOLARS, "Scholars", 40, NO_ID, BRANCH.ECONOMY, 1, 1, RFX.RP, 0.5, "+0.5 research points per second");
	define_research(RESEARCH.MERCHANT_GUILDS, "Merchant Guilds", 90, RESEARCH.TRADE_ROUTES, BRANCH.ECONOMY, 2, 0, RFX.GOLD, 0.15, "+15% gold income");
	define_research(RESEARCH.GRAND_LIBRARY, "Grand Library", 90, RESEARCH.SCHOLARS, BRANCH.ECONOMY, 2, 1, RFX.RP, 1.0, "+1 research point per second");
}

function define_research(_id, _name, _cost, _prereq, _branch, _row, _col, _fx, _amount, _desc) {
	global.researchDefs[_id] = {
		researchName: _name,
		cost: _cost,
		prereq: _prereq,
		branch: _branch,
		row: _row,
		col: _col,
		fx: _fx,
		amount: _amount,
		desc: _desc
	};
}

function get_branch_colour(_branch) {
	switch (_branch) {
		case BRANCH.OFFENSE: return make_colour_rgb(200, 60, 60);
		case BRANCH.DEFENSE: return make_colour_rgb(70, 120, 220);
	}
	return make_colour_rgb(70, 180, 90);
}

function get_branch_name(_branch) {
	switch (_branch) {
		case BRANCH.OFFENSE: return "Offense";
		case BRANCH.DEFENSE: return "Defense";
	}
	return "Economy";
}

// Maximum unit weight a tile can hold. Units that weigh more cannot walk onto it.
function get_tile_weight_limit(_world, _gx, _gy) {
	if (!tile_in_bounds(_world, _gx, _gy)) {
		return 0;
	}
	switch (ds_grid_get(_world.biome, _gx, _gy)) {
		case BIOME.MOUNTAIN: return 0;
		case BIOME.WATER: return 99;
		case BIOME.DESERT: return 3;
		case BIOME.SNOW: return 3;
	}
	return 4;
}

// ------------------------------------------------------------
// Ideologies
// ------------------------------------------------------------

function init_ideologies() {
	global.ideologyNames = ["Fascist", "Liberal", "Socialist", "Communist", "Conservatist"];
	global.ideologyColours = [
		make_colour_rgb(190, 60, 60),
		make_colour_rgb(240, 200, 60),
		make_colour_rgb(90, 190, 90),
		make_colour_rgb(210, 90, 150),
		make_colour_rgb(80, 130, 220)
	];
	global.ideologyHints = [
		"Conquest: cities captured and kills",
		"Small territory compared to the average",
		"High gold income",
		"Large gold stockpile",
		"Large army"
	];
}

// ------------------------------------------------------------
// Nations
// ------------------------------------------------------------

function init_nations() {
	// One entry per nation slot. unitNames has one name per UNIT_TYPE, in enum order:
	// explorer | warrior shieldman archer horseman medic | duelist ironclad crossbowman light cavalry engineer
	// | executioner tower shield artillerist warhound sapper | champion bastion marksman sky lancer priest
	// | dreadnought colossus siegebreaker stormwing arcanist | building boat, mineseeker, battleship, envoy
	global.nations = [];
	global.nations[0] = {
		nationName: "Valorian Empire", colour: make_colour_rgb(200, 50, 50),
		unitNames: [
			"Pathfinder",
			"Legionary", "Scutarius", "Sagittarius", "Cavalier", "Medicus",
			"Gladiator", "Praetorian", "Arcubalist", "Equites", "Architectus",
			"Carnifex", "Testudo Guard", "Ballistarius", "Hound Rider", "Fossor",
			"Imperial Champion", "Aegis Prefect", "Venator", "Sky Eques", "Pontifex",
			"Titan Slayer", "Colossus Maximus", "Onager Lord", "Aquila Wing", "Grand Augur",
			"Shipwright", "Speculator", "Dromon Lord", "Legate"
		],
		cityNames: ["Valoria", "Aurelia", "Castra", "Novum", "Ostia", "Vesta", "Capua", "Lucania", "Brundis", "Tarquin", "Ravenna", "Pompeia", "Cremona", "Aquileia", "Sabina", "Verona", "Cumae", "Fidenae", "Pisaurum", "Spoletum", "Nola", "Tarentum", "Arretium", "Placentia", "Segesta", "Mutina"]
	};
	global.nations[1] = {
		nationName: "Kingdom of Eldmark", colour: make_colour_rgb(60, 110, 220),
		unitNames: [
			"Scout",
			"Man-at-Arms", "Pavise Guard", "Longbowman", "Knight", "Field Surgeon",
			"Swordmaster", "Plate Guard", "Arbalester", "Courser", "Siege Smith",
			"Headsman", "Great Shield", "Bombardier", "Mastiff Rider", "Wallbreaker",
			"King's Champion", "Bastion Warden", "Kingsbow", "Griffon Lance", "Bishop",
			"Dragonbane", "Iron Colossus", "Trebuchet Master", "Gryphon Wing", "Archmage",
			"Boatwright", "Lookout", "War Galleon", "Herald"
		],
		cityNames: ["Eldmark", "Highfold", "Stonebridge", "Wexham", "Ravenhall", "Dunmere", "Oakhaven", "Brindle", "Thornwick", "Ashford", "Kingsbury", "Marlowe", "Whitcombe", "Hollowbrook", "Ironwood", "Wyndham", "Greymoor", "Fenwick", "Alderford", "Crowhurst", "Stanmere", "Harrowgate", "Elmsworth", "Blackthorn", "Winterbourne", "Larkspur"]
	};
	global.nations[2] = {
		nationName: "Sultanate of Zahran", colour: make_colour_rgb(235, 150, 40),
		unitNames: [
			"Wayfarer",
			"Scimitar", "Aspid Guard", "Qaws", "Sabre Rider", "Hakim",
			"Khanjar", "Mamluk", "Zanbarak", "Swift Sabre", "Muhandis",
			"Jallad", "Dar'a Guard", "Naffat", "Saluki Rider", "Naqqab",
			"Sultan's Blade", "Hisn Guard", "Qannas", "Falcon Lancer", "Mufti",
			"Djinn Slayer", "Brass Colossus", "Sand Cannon", "Simoom Wing", "Sage of Sands",
			"Dhow Builder", "Dhow Scout", "War Dhow", "Vizier's Envoy"
		],
		cityNames: ["Zahran", "Qasira", "Medina Noor", "Sahrim", "Amrah", "Dhalla", "Najmat", "Rawdan", "Qalat Sul", "Wadi Harith", "Marjan", "Tadmira", "Safwan", "Hadiya", "Bayt Zayn", "Sirhan", "Layyan", "Umm Daraj", "Karimah", "Ghazal", "Nashwan", "Qasr Amal", "Habbak", "Yasmira"]
	};
	global.nations[3] = {
		nationName: "Jade Dynasty", colour: make_colour_rgb(50, 170, 90),
		unitNames: [
			"Surveyor",
			"Halberdier", "Shield Warden", "Bowman", "Lancer", "Healer",
			"Jian Master", "Iron Guard", "Repeater", "Swift Lancer", "Artisan",
			"Dao Executioner", "Great Wall Guard", "Rocketeer", "Tiger Rider", "Tunneler",
			"Dragon Champion", "Imperial Warden", "Eagle Archer", "Crane Lancer", "Taoist Monk",
			"Dragon Slayer", "Stone Guardian", "Fire Dragon Cannon", "Phoenix Wing", "Grand Sage",
			"Junk Builder", "Junk Scout", "War Junk", "Emissary"
		],
		cityNames: ["Jinhai", "Longwei", "Qinglu", "Baishan", "Tianxi", "Yunzhou", "Fengcheng", "Mingshui", "Heyuan", "Chuanbei", "Lianhua", "Xuanwu", "Dongling", "Shanyue", "Zhuque", "Wenhai", "Yingtian", "Luoshui", "Guangyuan", "Bailing", "Nanxi", "Qingyun", "Hongqiao", "Taiyuan"]
	};
	global.nations[4] = {
		nationName: "Norsemen of Skarn", colour: make_colour_rgb(120, 220, 230),
		unitNames: [
			"Trailblazer",
			"Raider", "Shieldwall Guard", "Huntsman", "Horse Lord", "Rune Healer",
			"Blade-Singer", "Mail Guard", "Elk Hunter", "Fjord Rider", "Rune Smith",
			"Doom Axe", "Great Shieldwall", "Stone Thrower", "Wolf Rider", "Frost Sapper",
			"Jarl's Champion", "Aesir Guard", "Eagle-Eye", "Valkyrie Lancer", "Volva",
			"Ragnarok Slayer", "Frost Giant", "Thor's Cannon", "Raven Wing", "Rune Mage",
			"Longship Builder", "Scout Skiff", "Dragon Ship", "Skald"
		],
		cityNames: ["Skarnholm", "Frostvik", "Eldrheim", "Bjornfjord", "Hallgard", "Ulfsvik", "Ravnsund", "Stormvik", "Kaldhavn", "Svartfjell", "Gunnvik", "Thorsrud", "Vindheim", "Hrafnsey", "Asgrim", "Sigtun", "Njordvik", "Fenrisholm", "Brynhald", "Ulvang", "Skogsund", "Rimfaxe", "Draugvik", "Valdrsby"]
	};
	global.nations[5] = {
		nationName: "Tlaxco Confederacy", colour: make_colour_rgb(160, 80, 200),
		unitNames: [
			"Runner",
			"Jaguar Warrior", "Chimalli Guard", "Atlatl Thrower", "Plains Rider", "Curandero",
			"Eagle Duelist", "Obsidian Guard", "Dart Slinger", "Swift Rider", "Builder",
			"Sacrificer", "Stone Shield", "Sling Master", "Coyote Rider", "Tunneler",
			"Eagle Champion", "Temple Guard", "Quetzal Marksman", "Hummingbird Lance", "Shaman",
			"Sun Slayer", "Stone Colossus", "Fire Serpent Cannon", "Quetzal Wing", "Grand Nahual",
			"Canoe Builder", "Canoe Scout", "War Canoe", "Pochteca"
		],
		cityNames: ["Tlaxco", "Quetzal", "Coatl", "Tepec", "Ixmal", "Zihua", "Tenochca", "Xochitl", "Mictlan", "Cuauhtla", "Tecpan", "Ollin", "Yaotl", "Citlali", "Tezcoco", "Atzlan", "Chalco", "Huitzil", "Itzcoatl", "Metztli", "Tonala", "Coyotl", "Papan", "Tlachco", "Xicotl"]
	};
	global.nations[6] = {
		nationName: "Republic of Sarnia", colour: make_colour_rgb(30, 160, 160),
		unitNames: [
			"Pioneer",
			"Hoplite", "Aspis Guard", "Toxotes", "Hippeus", "Iatros",
			"Xiphos Duelist", "Thorakitai", "Gastraphetes", "Prodromos", "Technites",
			"Kopis Reaper", "Phalanx Guard", "Lithobolos", "Hound Rider", "Breacher",
			"Spartan Champion", "Bastion Hoplite", "Hawk Archer", "Pegasus Lance", "Oracle",
			"Hero of Olympus", "Bronze Colossus", "Greek Fire Cannon", "Harpy Wing", "Grand Pythia",
			"Trireme Builder", "Trireme Scout", "Great Trireme", "Proxenos"
		],
		cityNames: ["Sarnia", "Lykos", "Thessara", "Korinthe", "Delphia", "Meros", "Argolis", "Phyle", "Hellane", "Kyrenia", "Mykene", "Olympia", "Thaso", "Aegina", "Nikaia", "Chalcis", "Pylos", "Itharis", "Dorion", "Kallias", "Lemnos", "Rhodane", "Arkadia", "Tegea", "Elatea", "Thebara"]
	};
	global.nations[7] = {
		nationName: "Khanate of Ulgar", colour: make_colour_rgb(140, 90, 50),
		unitNames: [
			"Tracker",
			"Axeman", "Shield Brute", "Steppe Archer", "Wolf Rider", "Bonesetter",
			"Blade Dancer", "Iron Brute", "Horn Bow", "Raider Rider", "Tinker",
			"Skull Taker", "Wall Brute", "Rock Hurler", "Dire Wolf Rider", "Breaker",
			"Khan's Champion", "Mountain Guard", "Eagle Hunter", "Warg Lancer", "Shaman",
			"Doom Slayer", "Mammoth", "Bone Cannon", "Storm Rider", "Storm Shaman",
			"Raft Builder", "Raft Scout", "War Barge", "Talker"
		],
		cityNames: ["Ulgarth", "Grimtooth", "Bonehollow", "Skarg", "Dreth", "Mokar", "Gorrak", "Blightmaw", "Ashfang", "Krag Dur", "Thokk", "Vilegrub", "Ironjaw", "Scorchpit", "Zugrath", "Brakka", "Rotfang", "Gnashrock", "Dunghul", "Warhold", "Skullreach", "Molgor", "Hagrash", "Durkul"]
	};

	// Tribes are not a nation slot, they use TRIBE_OWNER
	global.tribe = {
		nationName: "Tribes", colour: make_colour_rgb(70, 70, 70)
	};
}

function get_owner_colour(_owner) {
	if (_owner == TRIBE_OWNER) {
		return global.tribe.colour;
	}
	return global.nations[_owner].colour;
}

function get_owner_name(_owner) {
	if (_owner == TRIBE_OWNER) {
		return global.tribe.nationName;
	}
	return global.nations[_owner].nationName;
}

// The nation specific name. The generic name (global.unitStats[type].subtitle) is shown under it
function get_unit_name(_owner, _type) {
	if (_owner == TRIBE_OWNER) {
		return "Tribal " + global.unitStats[_type].subtitle;
	}
	var _names = global.nations[_owner].unitNames;
	if (_type < array_length(_names)) {
		return _names[_type];
	}
	return global.unitStats[_type].subtitle;
}

function init_map_presets() {
	// scale: lower = bigger landmasses. falloff: how strongly the map edges sink into water
	// tempOffset / moistOffset push the whole map toward a climate
	global.mapPresets = [];
	global.mapPresets[0] = { presetName: "Continents", scale: 0.07, waterLevel: 0.46, mountainLevel: 0.78, falloff: 0.5, tempOffset: 0, moistOffset: 0 };
	global.mapPresets[1] = { presetName: "Archipelago", scale: 0.12, waterLevel: 0.55, mountainLevel: 0.85, falloff: 0.3, tempOffset: 0, moistOffset: 0.05 };
	global.mapPresets[2] = { presetName: "Pangaea", scale: 0.05, waterLevel: 0.38, mountainLevel: 0.78, falloff: 0.6, tempOffset: 0, moistOffset: 0 };
	global.mapPresets[3] = { presetName: "Highlands", scale: 0.09, waterLevel: 0.30, mountainLevel: 0.62, falloff: 0.4, tempOffset: 0, moistOffset: 0 };
	global.mapPresets[4] = { presetName: "Frozen North", scale: 0.07, waterLevel: 0.44, mountainLevel: 0.76, falloff: 0.5, tempOffset: -0.25, moistOffset: 0 };
	global.mapPresets[5] = { presetName: "Scorched Lands", scale: 0.07, waterLevel: 0.40, mountainLevel: 0.78, falloff: 0.5, tempOffset: 0.25, moistOffset: -0.2 };
}
