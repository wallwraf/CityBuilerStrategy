// ============================================================
// scr_expansion: balance pass, siege + tank workshops, airfield and aircraft, new research.
// Call init_expansion() once, right after init_nations() (where init_unit_stats and friends run).
// ============================================================

// Tuning knobs
#macro BUILDING_HP_SCALE 2
#macro CITY_HP_SCALE 1.5

function init_expansion() {
	init_expansion_units();
	init_expansion_buildings();
	init_expansion_research();
	apply_balance_changes();
	pad_nation_unit_names();
	global.researchLayout = build_research_layout();
}

// ------------------------------------------------------------
// New units
// define_unit(type, name, role, description, source, cost, hp, damage, range, moveRange, moveDelay, attackDelay, extras)
// buildingMult is how hard the unit hits buildings and cities (ordinary units default to 0.4).
// ------------------------------------------------------------

function init_expansion_units() {
	// Siege Workshop. Rams crack gates, catapults level buildings, mangonels shred crowds.
	define_unit(UNIT_TYPE.BATTERING_RAM, "Battering Ram", "Siege", "Smashes gates, walls and buildings. Weak against troops", UNIT_SRC.SIEGE, 160, 160, 8, 1, 1, 1.4, 1.2, { tier: 2, armor: 0.3, buildingMult: 12, weight: 3, hitsAir: false, reqResearch: RESEARCH.SIEGE_ENGINEERING });
	define_unit(UNIT_TYPE.CATAPULT, "Catapult", "Siege", "Long range building breaker with a small splash", UNIT_SRC.SIEGE, 230, 70, 20, 3, 1, 1.6, 3.0, { tier: 3, splash: 1, buildingMult: 7, weight: 2, hitsAir: false, reqBuildingLevel: 2, reqResearch: RESEARCH.SIEGE_ARTILLERY });
	define_unit(UNIT_TYPE.MANGONEL, "Mangonel", "Siege", "Hurls rocks that hit everything in a 2 tile radius. Made for hordes", UNIT_SRC.SIEGE, 280, 60, 26, 3, 1, 1.6, 2.6, { tier: 4, splash: 2, buildingMult: 1.5, weight: 2, hitsAir: false, reqBuildingLevel: 3, reqResearch: RESEARCH.SIEGE_ARTILLERY });

	// Tank Workshop: the late game versions of the siege weapons
	define_unit(UNIT_TYPE.HEAVY_TANK, "Heavy Tank", "Siege", "Armoured gun platform with splash. Hard to kill", UNIT_SRC.TANK, 650, 520, 30, 2, 1, 1.1, 1.2, { tier: 5, armor: 0.55, splash: 1, buildingMult: 2.5, weight: 4, hitsAir: false, reqResearch: RESEARCH.ARMOURED_WARFARE });
	define_unit(UNIT_TYPE.BREAKER_TANK, "Breaker Tank", "Siege", "Erases gates and buildings in a few hits", UNIT_SRC.TANK, 720, 420, 16, 1, 1, 1.0, 1.0, { tier: 5, armor: 0.5, buildingMult: 9, weight: 4, hitsAir: false, reqBuildingLevel: 2, reqResearch: RESEARCH.ARMOURED_WARFARE });
	define_unit(UNIT_TYPE.ROCKET_ARTILLERY, "Rocket Artillery", "Siege", "Huge range and a wide splash, but fragile", UNIT_SRC.TANK, 780, 120, 38, 5, 1, 1.5, 3.2, { tier: 5, armor: 0.1, splash: 2, buildingMult: 3, weight: 3, hitsAir: false, reqBuildingLevel: 3, reqResearch: RESEARCH.HEAVY_ORDNANCE });

	// Airfield. Aircraft fly over everything: they ignore tile weight, walls, mountains and water.
	// Only ranged units, towers, ships and fighters can hit them. Melee troops cannot.
	define_unit(UNIT_TYPE.BIPLANE, "Biplane Fighter", "Air", "Fast fighter that hits both aircraft and ground units", UNIT_SRC.AIRFIELD, 420, 75, 12, 2, 3, 0.7, 0.7, { tier: 4, domain: DOMAIN.AIR, passSolid: true, buildingMult: 0.3, hitsAir: true, reqResearch: RESEARCH.AVIATION });
	define_unit(UNIT_TYPE.TRANSPORT_PLANE, "Transport Plane", "Air", "Press E to load land units on or next to it, E again to unload", UNIT_SRC.AIRFIELD, 480, 140, 0, 1, 2, 0.9, 1.0, { tier: 4, domain: DOMAIN.AIR, passSolid: true, capacity: 8, hitsAir: false, reqBuildingLevel: 2, reqResearch: RESEARCH.AIR_TRANSPORT });
	define_unit(UNIT_TYPE.DIVE_BOMBER, "Dive Bomber", "Air", "Bombs ground targets and buildings. Cannot hit aircraft", UNIT_SRC.AIRFIELD, 560, 90, 38, 1, 3, 0.8, 1.6, { tier: 4, domain: DOMAIN.AIR, passSolid: true, splash: 1, buildingMult: 3, hitsAir: false, reqBuildingLevel: 2, reqResearch: RESEARCH.DIVE_BOMBERS });
	define_unit(UNIT_TYPE.HEAVY_BOMBER, "Heavy Bomber", "Air", "Carpet bombs a wide area. Slow, tough, and devastating to buildings", UNIT_SRC.AIRFIELD, 900, 240, 60, 1, 2, 1.0, 3.0, { tier: 5, domain: DOMAIN.AIR, passSolid: true, splash: 2, buildingMult: 5, hitsAir: false, reqBuildingLevel: 3, reqResearch: RESEARCH.STRATEGIC_BOMBING });
}

// ------------------------------------------------------------
// New buildings
// ------------------------------------------------------------

function init_expansion_buildings() {
	define_building(BUILDING.SIEGE_WORKSHOP, "Siege Workshop", "Builds battering rams, catapults and mangonels", 200, 3, 200, PLACE.LAND, { reqResearch: RESEARCH.SIEGE_ENGINEERING });
	define_building(BUILDING.TANK_WORKSHOP, "Tank Workshop", "Builds tanks and rocket artillery", 520, 3, 320, PLACE.LAND, { reqResearch: RESEARCH.ARMOURED_WARFARE });
	define_building(BUILDING.AIRFIELD, "Airfield", "Builds aircraft. Level 2 and 3 unlock bigger planes", 520, 3, 260, PLACE.LAND, { reqResearch: RESEARCH.AVIATION });
}

// ------------------------------------------------------------
// Research (the tree is scrollable, so it can keep growing)
// ------------------------------------------------------------

function init_expansion_research() {
	// Offense, third column: the army ladder
	define_research(RESEARCH.STANDING_ARMY, "Standing Army", 50, NO_ID, BRANCH.OFFENSE, 1, 2, RFX.NONE, 0, "Unlocks level 2 units at the City Hall");
	define_research(RESEARCH.BARRACKS_DOCTRINE, "Barracks Doctrine", 90, RESEARCH.STANDING_ARMY, BRANCH.OFFENSE, 2, 2, RFX.NONE, 0, "Unlocks the Barracks and its level 3 units");
	define_research(RESEARCH.VETERAN_CORPS, "Veteran Corps", 170, RESEARCH.BARRACKS_DOCTRINE, BRANCH.OFFENSE, 3, 2, RFX.NONE, 0, "Level 3 Barracks can train level 4 units");
	define_research(RESEARCH.GARRISON_DOCTRINE, "Garrison Doctrine", 300, RESEARCH.VETERAN_CORPS, BRANCH.OFFENSE, 4, 2, RFX.NONE, 0, "Unlocks the Garrison and level 5 units");

	// Defense and economy extensions
	define_research(RESEARCH.COMPOSITE_ARMOR, "Composite Armor", 190, RESEARCH.REINFORCED_PLATING, BRANCH.DEFENSE, 3, 1, RFX.ARMOR, 0.08, "Your units take a further 8% less damage");
	define_research(RESEARCH.TRADE_EMPIRE, "Trade Empire", 160, RESEARCH.MERCHANT_GUILDS, BRANCH.ECONOMY, 3, 0, RFX.GOLD, 0.2, "+20% gold income");
	define_research(RESEARCH.ACADEMY, "Academy", 160, RESEARCH.GRAND_LIBRARY, BRANCH.ECONOMY, 3, 1, RFX.RP, 1.5, "+1.5 research points per second");

	// Industry: siege, armour and flight
	define_research(RESEARCH.SIEGE_ENGINEERING, "Siege Engineering", 110, RESEARCH.STANDING_ARMY, BRANCH.INDUSTRY, 1, 0, RFX.NONE, 0, "Unlocks the Siege Workshop and Battering Rams");
	define_research(RESEARCH.SIEGE_ARTILLERY, "Siege Artillery", 170, RESEARCH.SIEGE_ENGINEERING, BRANCH.INDUSTRY, 2, 0, RFX.NONE, 0, "Siege Workshop trains Catapults (level 2) and Mangonels (level 3)");
	define_research(RESEARCH.AVIATION, "Aviation", 340, RESEARCH.VETERAN_CORPS, BRANCH.INDUSTRY, 4, 1, RFX.NONE, 0, "Unlocks the Airfield and Biplane Fighters");
	define_research(RESEARCH.ARMOURED_WARFARE, "Armoured Warfare", 380, RESEARCH.SIEGE_ARTILLERY, BRANCH.INDUSTRY, 5, 0, RFX.NONE, 0, "Unlocks the Tank Workshop, Heavy Tanks and Breaker Tanks");
	global.researchDefs[RESEARCH.ARMOURED_WARFARE].prereq2 = RESEARCH.GARRISON_DOCTRINE;
	define_research(RESEARCH.AIR_TRANSPORT, "Air Transport", 380, RESEARCH.AVIATION, BRANCH.INDUSTRY, 5, 1, RFX.NONE, 0, "Airfield level 2 trains Transport Planes");
	define_research(RESEARCH.DIVE_BOMBERS, "Dive Bombers", 420, RESEARCH.AVIATION, BRANCH.INDUSTRY, 5, 2, RFX.NONE, 0, "Airfield level 2 trains Dive Bombers");
	define_research(RESEARCH.HEAVY_ORDNANCE, "Heavy Ordnance", 460, RESEARCH.ARMOURED_WARFARE, BRANCH.INDUSTRY, 6, 0, RFX.NONE, 0, "Level 3 Tank Workshop trains Rocket Artillery");
	define_research(RESEARCH.STRATEGIC_BOMBING, "Strategic Bombing", 600, RESEARCH.DIVE_BOMBERS, BRANCH.INDUSTRY, 6, 2, RFX.NONE, 0, "Level 3 Airfield trains Heavy Bombers");
	global.researchDefs[RESEARCH.STRATEGIC_BOMBING].prereq2 = RESEARCH.ARMOURED_WARFARE;
}

// A node is available once every prerequisite is researched
function research_prereqs_met(_state, _rdef) {
	if ((_rdef.prereq != NO_ID) && !_state.researched[_rdef.prereq]) {
		return false;
	}
	if ((_rdef.prereq2 != NO_ID) && !_state.researched[_rdef.prereq2]) {
		return false;
	}
	return true;
}

function get_research_missing_text(_state, _rdef) {
	var _text = "";
	if ((_rdef.prereq != NO_ID) && !_state.researched[_rdef.prereq]) {
		_text = global.researchDefs[_rdef.prereq].researchName;
	}
	if ((_rdef.prereq2 != NO_ID) && !_state.researched[_rdef.prereq2]) {
		_text += ((_text != "") ? " + " : "") + global.researchDefs[_rdef.prereq2].researchName;
	}
	return _text;
}

// ------------------------------------------------------------
// Balance pass: research locks, weaker damage to buildings, tier 5 nerfs, boat weights
// ------------------------------------------------------------

function apply_balance_changes() {
	var _u = global.unitStats;

	// Level 2 City Hall units need Standing Army
	_u[UNIT_TYPE.DUELIST].reqResearch = RESEARCH.STANDING_ARMY;
	_u[UNIT_TYPE.IRONCLAD].reqResearch = RESEARCH.STANDING_ARMY;
	_u[UNIT_TYPE.CROSSBOWMAN].reqResearch = RESEARCH.STANDING_ARMY;
	_u[UNIT_TYPE.LIGHT_CAVALRY].reqResearch = RESEARCH.STANDING_ARMY;

	// Level 4 units (Barracks level 3) need Veteran Corps
	_u[UNIT_TYPE.ROYAL_CHAMPION].reqResearch = RESEARCH.VETERAN_CORPS;
	_u[UNIT_TYPE.BASTION_KNIGHT].reqResearch = RESEARCH.VETERAN_CORPS;
	_u[UNIT_TYPE.SIEGE_MARKSMAN].reqResearch = RESEARCH.VETERAN_CORPS;
	_u[UNIT_TYPE.SKY_LANCER].reqResearch = RESEARCH.VETERAN_CORPS;
	_u[UNIT_TYPE.WAR_PRIEST].reqResearch = RESEARCH.VETERAN_CORPS;

	// The buildings themselves
	global.buildingDefs[BUILDING.BARRACKS].reqResearch = RESEARCH.BARRACKS_DOCTRINE;
	global.buildingDefs[BUILDING.GARRISON].reqResearch = RESEARCH.GARRISON_DOCTRINE;

	// Ordinary units now hurt buildings much less (default buildingMult is 0.4, see define_unit).
	// Specialists keep an edge, and the siege units above hit far harder than this.
	_u[UNIT_TYPE.SAPPER].buildingMult = 2.5;
	_u[UNIT_TYPE.SIEGEBREAKER].buildingMult = 1.5;

	// Tier 5 nerfs
	var _d = _u[UNIT_TYPE.DREADNOUGHT_SLAYER];
	_d.damage = 42;
	_d.attackDelay = 1.2;
	_d.moveDelay = 1.15;
	var _c = _u[UNIT_TYPE.COLOSSUS];
	_c.damage = 12;
	_c.moveDelay = 1.7;
	var _s = _u[UNIT_TYPE.SIEGEBREAKER];
	_s.damage = 46;
	_s.attackDelay = 2.9;
	_s.moveDelay = 1.6;
	var _w = _u[UNIT_TYPE.STORMWING];
	_w.damage = 32;
	_w.moveRange = 3;
	_w.moveDelay = 0.85;
	_w.attackDelay = 1.0;
	var _a = _u[UNIT_TYPE.GRAND_ARCANIST];
	_a.damage = 8;
	_a.slowMult = 1.4;

	// Heavy artillery cannot shoot up
	_s.hitsAir = false;

	// Water tiles now hold a weight of 4, so ships have weights too
	_u[UNIT_TYPE.BATTLESHIP].weight = 3;
	_u[UNIT_TYPE.TRAVELER_BOAT].weight = 2;
}

// Nations only name the original units. Anything new falls back to the generic name.
function pad_nation_unit_names() {
	for (var _n = 0; _n < array_length(global.nations); _n++) {
		var _names = global.nations[_n].unitNames;
		for (var _t = array_length(_names); _t < UNIT_TYPE.COUNT; _t++) {
			array_push(_names, global.unitStats[_t].subtitle);
		}
		global.nations[_n].unitNames = _names;
	}
}

function get_source_name(_source) {
	switch (_source) {
		case UNIT_SRC.BARRACKS: return "Barracks";
		case UNIT_SRC.SIEGE: return "Siege Workshop";
		case UNIT_SRC.TANK: return "Tank Workshop";
		case UNIT_SRC.AIRFIELD: return "Airfield";
	}
	return "building";
}

// ------------------------------------------------------------
// Research tree layout. Every branch gets a band of columns, rows run downward.
// Everything is in "canvas" pixels, the research view scrolls over it.
// ------------------------------------------------------------

#macro RESEARCH_COL_W (RESEARCH_NODE_W + 12)
#macro RESEARCH_ROW_H 100
#macro RESEARCH_FIRST_ROW_Y 150

function build_research_layout() {
	var _bandCols = [];
	for (var _b = 0; _b < BRANCH.COUNT; _b++) {
		array_push(_bandCols, 1);
	}
	var _maxRow = 1;
	for (var _r = 0; _r < RESEARCH.COUNT; _r++) {
		var _def = global.researchDefs[_r];
		_bandCols[_def.branch] = max(_bandCols[_def.branch], _def.col + 1);
		_maxRow = max(_maxRow, _def.row);
	}
	var _x = 40;
	var _bandX = [];
	var _bandW = [];
	for (var _i = 0; _i < BRANCH.COUNT; _i++) {
		array_push(_bandX, _x);
		array_push(_bandW, _bandCols[_i] * RESEARCH_COL_W);
		_x += _bandCols[_i] * RESEARCH_COL_W + 48;
	}
	return {
		bandX: _bandX,
		bandW: _bandW,
		width: _x - 48 + 40,
		height: RESEARCH_FIRST_ROW_Y + (_maxRow - 1) * RESEARCH_ROW_H + RESEARCH_NODE_H + 50
	};
}