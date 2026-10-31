// ============================================================
// scr_hud: buttons, side panels, selection info, treaty popup and notices (Draw GUI)
//
// Buttons are rebuilt from the game state every time they are needed
// (get_hud_buttons), and the same list is used for drawing and clicking.
// zone: 0 = top tabs, 1 = side panel, 2 = bottom bar, 3 = treaty popup
// ============================================================

#macro RESEARCH_NODE_W 132
#macro RESEARCH_NODE_H 64

draw_set_font(fnt_txt);

function make_button(_label, _sub, _action, _arg, _arg2, _enabled, _why, _tip) {
	return {
		x: 0, y: 0, w: BUTTON_W, h: BUTTON_H,
		colour: -1,
		label: _label,
		sub: _sub,
		action: _action,
		arg: _arg,
		arg2: _arg2,
		enabled: _enabled,
		why: _why,
		tip: _tip,
		active: false,
		zone: 2,
		branch: NO_ID,
		state: 0
	};
}

function get_relation_text(_world, _a, _b) {
	var _t = get_treaty_between(_world, _a, _b);
	if (_t == undefined) {
		return "No treaty";
	}
	if (_t.state == 1) {
		return "Treaty ends in " + string(ceil(_t.timer)) + "s";
	}
	return "At peace";
}

function get_unit_tip(_type) {
	var _s = global.unitStats[_type];
	var _text = _s.desc + "\\nHP " + string(_s.maxHp) + "   Damage " + string(_s.damage) + "   Range " + string(_s.range) + "   Move " + string(_s.moveRange) + "   Weight " + string(_s.weight);
	if (_s.capacity > 0) {
		_text += "\\nCarries up to " + string(_s.capacity) + " weight of land units";
	}
  	_text += "\\nBuildings x" + string(_s.buildingMult) + (_s.hitsAir ? "   Hits aircraft" : "   Cannot hit aircraft");
  	if (_s.domain == DOMAIN.AIR) {
  		_text += "\\nFlies: ignores weight, terrain and walls";
  	}
	_text += "\\nPopulation " + string(_s.popCost);
	return _text;
}

// ------------------------------------------------------------
// Button lists
// ------------------------------------------------------------

function get_hud_buttons(_g) {
	if (_g.hudCache == undefined) {
		_g.hudCache = build_hud_buttons(_g);
	}
	return _g.hudCache;
}

function build_hud_buttons(_g) {
	var _list = [];
	var _world = _g.world;
	var _local = _g.localNation;
	if (_local == NO_ID) {
		return _list;
	}
	var _state = _world.nationStates[_local];

	// A treaty offer takes over the screen
	var _offer = get_offer_for(_world, _local);
	if (_offer != undefined) {
		var _cx = _g.screenW / 2;
		var _cy = _g.screenH / 2;
		var _accept = make_button("Accept", _offer.betray ? "Betrays your treaty" : "Sign the treaty", UI_ACT.ANSWER_OFFER, true, NO_ID, true, "", "");
		_accept.x = _cx - 170; _accept.y = _cy + 30; _accept.w = 160; _accept.h = 44; _accept.zone = 3;
		var _decline = make_button("Decline", "Keep things as they are", UI_ACT.ANSWER_OFFER, false, NO_ID, true, "", "");
		_decline.x = _cx + 10; _decline.y = _cy + 30; _decline.w = 160; _decline.h = 44; _decline.zone = 3;
		array_push(_list, _accept);
		array_push(_list, _decline);
		return _list;
	}

	// Tabs along the top right
	var _tabNames = ["Build", "Research", "Diplomacy", "Ideology"];
	var _tabPanels = [PANEL.BUILD, PANEL.RESEARCH, PANEL.DIPLOMACY, PANEL.IDEOLOGY];
	var _tabW = 100;
	var _tabX = _g.screenW - 4 * (_tabW + 4);
	for (var _t = 0; _t < 4; _t++) {
		var _tab = make_button(_tabNames[_t], "", UI_ACT.TOGGLE_PANEL, _tabPanels[_t], NO_ID, true, "", "");
		_tab.x = _tabX + _t * (_tabW + 4);
		_tab.y = 4;
		_tab.w = _tabW;
		_tab.h = TOP_H - 8;
		_tab.zone = 0;
		_tab.active = (_g.panel == _tabPanels[_t]);
		array_push(_list, _tab);
	}

	if (_g.panel == PANEL.BUILD) {
		add_build_buttons(_g, _list, _state);
	} else if (panel_is_overlay(_g.panel)) {
		add_overlay_buttons(_g, _list, _state);
	}

	// The unit and building buttons are hidden behind an overlay screen
	if (!panel_is_overlay(_g.panel)) {
		add_bottom_buttons(_g, _list, _state);
	}
	add_final_vote_buttons(_g, _list);
	return _list;
}

// ------------------------------------------------------------
// Build menu (scrollable) and overlay screens
// ------------------------------------------------------------

function panel_is_overlay(_panel) {
	return (_panel == PANEL.RESEARCH) || (_panel == PANEL.DIPLOMACY) || (_panel == PANEL.IDEOLOGY);
}

// The centred rectangle the overlay screens are drawn in
function get_overlay_rect(_g) {
	var _w = min(_g.screenW - 40, 900);
	var _h = min(_g.screenH - TOP_H - 40, 540);
	return {
		x: (_g.screenW - _w) / 2,
		y: TOP_H + (_g.screenH - TOP_H - _h) / 2,
		w: _w,
		h: _h
	};
}

function point_in_overlay(_g, _mx, _my) {
	var _r = get_overlay_rect(_g);
	return (_mx >= _r.x) && (_mx <= _r.x + _r.w) && (_my >= _r.y) && (_my <= _r.y + _r.h);
}

function get_build_list_top() {
	return TOP_H + 44;
}

function get_build_item_count() {
	var _count = 0;
	for (var _t = 0; _t < BUILDING.COUNT; _t++) {
		var _def = global.buildingDefs[_t];
		if (_def.buildable && !_def.hidden) {
			_count++;
		}
	}
	return _count + 1;
}

// How far the build menu can scroll (0 when everything fits)
function get_build_scroll_max(_g) {
	var _content = get_build_item_count() * 52;
	var _visible = _g.screenH - get_build_list_top() - 8;
	return max(0, _content - _visible);
}

function mouse_over_build_panel(_g, _mx, _my) {
	return (_g.panel == PANEL.BUILD) && (_mx >= _g.screenW - PANEL_W) && (_my >= TOP_H);
}

function add_build_buttons(_g, _list, _state) {
	var _world = _g.world;
	var _local = _g.localNation;
	_g.panelScroll = clamp(_g.panelScroll, 0, get_build_scroll_max(_g));
	var _x = _g.screenW - PANEL_W + 8;
	var _listTop = get_build_list_top();
	var _w = PANEL_W - 16;
	var _h = 46;
	var _index = 0;

	for (var _t = 0; _t < BUILDING.COUNT; _t++) {
		var _def = global.buildingDefs[_t];
		if (!_def.buildable || _def.hidden) {
			continue;
		}
		var _needs = ((_def.reqResearch != NO_ID) && !nation_has_research(_world, _local, _def.reqResearch));
		var _sub = string(_def.cost) + " gold";
		if (_t == BUILDING.HOUSING) {
			_sub += "   " + string(count_nation_buildings(_world, _local, _t)) + "/" + string(HOUSING_MAX);
		}
		if (_def.solid) {
			_sub += "   solid";
		}
		var _why = "";
		if (_needs) {
			_why = "Needs: " + global.researchDefs[_def.reqResearch].researchName;
		} else if ((_t == BUILDING.HOUSING) && (count_nation_buildings(_world, _local, _t) >= HOUSING_MAX)) {
			_why = "Limit reached";
		} else if (_state.gold < _def.cost) {
			_why = "Not enough gold";
		}
		var _tip = _def.desc;
		if (_def.place == PLACE.EDGE) {
			_tip += "\\nPlaced on the tile edge closest to the cursor";
		}
		var _b = make_button(_def.buildingName, (_why != "") ? _why : _sub, UI_ACT.PICK_BUILDING, _t, NO_ID, (_why == ""), _why, _tip);
		_b.x = _x;
		_b.y = _listTop + _index * 52 - _g.panelScroll;
		_b.w = _w;
		_b.h = _h;
		_b.zone = 1;
		_index++;

		// Skip the ones scrolled completely out of view
		if ((_b.y + _b.h < _listTop) || (_b.y > _g.screenH)) {
			continue;
		}
		array_push(_list, _b);
		
	}
	
	// The demolish tool sits at the end of the list
	var _demo = make_button("Demolish", "Click a building or path", UI_ACT.TOGGLE_DEMOLISH, 0, NO_ID, true, "", "Removes your buildings and paths and refunds half their cost");
	_demo.x = _x;
	_demo.y = _listTop + _index * 52 - _g.panelScroll;
	_demo.w = _w;
	_demo.h = _h;
	_demo.zone = 1;
	_demo.active = _g.demolishMode;
	if (!((_demo.y + _demo.h < _listTop) || (_demo.y > _g.screenH))) {
		array_push(_list, _demo);
	}
}

function add_overlay_buttons(_g, _list, _state) {
	var _world = _g.world;
	var _local = _g.localNation;
	var _o = get_overlay_rect(_g);

	// Close button
	var _close = make_button("Close", "", UI_ACT.TOGGLE_PANEL, _g.panel, NO_ID, true, "", "");
	_close.x = _o.x + _o.w - 90;
	_close.y = _o.y + 10;
	_close.w = 80;
	_close.h = 30;
	_close.zone = 4;
	array_push(_list, _close);

		if (_g.panel == PANEL.RESEARCH) {
		clamp_research_pan(_g);
		var _view = get_research_view(_g);
		for (var _r = 0; _r < RESEARCH.COUNT; _r++) {
			var _rdef = global.researchDefs[_r];
			var _rect = get_research_node_rect(_g, _r);
			// Nodes scrolled out of view cannot be clicked
			if (!point_in_rectangle(_rect.x + _rect.w / 2, _rect.y + _rect.h / 2, _view.x, _view.y, _view.x + _view.w, _view.y + _view.h)) {
				continue;
			}
			var _rSub = string(_rdef.cost) + " RP";
			var _rWhy = "";
			var _rState = 1;
			if (_state.researched[_r]) {
				_rSub = "Researched";
				_rWhy = "Already researched";
				_rState = 2;
			} else if (!research_prereqs_met(_state, _rdef)) {
				_rSub = "Locked";
				_rWhy = "Needs: " + get_research_missing_text(_state, _rdef);
				_rState = 0;
			} else if (_state.rp < _rdef.cost) {
				_rWhy = "Not enough research points";
			}
			var _node = make_button(_rdef.researchName, _rSub, UI_ACT.RESEARCH, _r, NO_ID, (_rWhy == ""), _rWhy, _rdef.desc + "\\nCost: " + string(_rdef.cost) + " RP");
			_node.x = _rect.x;
			_node.y = _rect.y;
			_node.w = _rect.w;
			_node.h = _rect.h;
			_node.zone = 4;
			_node.branch = _rdef.branch;
			_node.state = _rState;
			array_push(_list, _node);
		}
	} else if (_g.panel == PANEL.DIPLOMACY) {
		var _row = 0;
		for (var _n = 0; _n < MAX_NATIONS; _n++) {
			var _other = _world.nationStates[_n];
			if ((_n == _local) || !_other.active || _other.eliminated) {
				continue;
			}
			var _treaty = get_treaty_between(_world, _local, _n);
			var _canWar = ((_treaty != undefined) && (_treaty.state == 0));
			var _dSub = get_relation_text(_world, _local, _n);
			if (_canWar) {
				_dSub += " - click to declare war";
			}
			var _dTip = "Land " + string(_other.stats.land) + "   Units " + string(_other.stats.units) + "   Income " + string_format(_other.stats.income, 1, 1) + "/s";
			if (_other.slotType == SLOT_TYPE.BOT) {
				_dTip += "\\nIdeology: " + global.ideologyNames[_other.ideology];
			}
			var _card = make_button(get_owner_name(_n), _dSub, UI_ACT.DECLARE_WAR, _n, NO_ID, _canWar, "You have no peace treaty with them", _dTip);
			_card.x = _o.x + 20;
			_card.y = _o.y + 56 + _row * 56;
			_card.w = _o.w - 40;
			_card.h = 50;
			_card.zone = 4;
			array_push(_list, _card);
			_row++;
		}
	}
}

// Buttons for whatever is selected, laid out in rows from the bottom left
function add_bottom_buttons(_g, _list, _state) {
	var _world = _g.world;
	var _local = _g.localNation;
	var _items = [];

		if (_g.placeType != NO_ID) {
		array_push(_items, make_button("Cancel", "Stop placing (right click)", UI_ACT.PICK_BUILDING, NO_ID, NO_ID, true, "", ""));
		} else if (_g.demolishMode) {
			array_push(_items, make_button("Stop Demolishing", "Right click", UI_ACT.TOGGLE_DEMOLISH, 0, NO_ID, true, "", ""));
		} else if ((_g.selectedCityId != NO_ID) && (_world.cities[_g.selectedCityId].owner == _local)) {
			var _city = _world.cities[_g.selectedCityId];
			for (var _t = 0; _t < UNIT_TYPE.COUNT; _t++) {
			if (global.unitStats[_t].source == UNIT_SRC.CITY_HALL) {
				array_push(_items, make_unit_button(_world, _local, _state, _t, _city.level, UI_ACT.BUY_UNIT, NO_ID));
			}
		}
		var _upSub = "Max level";
		var _upWhy = "City is at max level";
		if (_city.level < MAX_CITY_LEVEL) {
			var _cost = get_city_upgrade_cost(_city);
			_upSub = "Lv " + string(_city.level) + " > " + string(_city.level + 1) + "  -  " + string(_cost) + " gold";
			_upWhy = (_state.gold >= _cost) ? "" : "Not enough gold";
		}
		array_push(_items, make_button("Upgrade City", _upSub, UI_ACT.UPGRADE_CITY, 0, NO_ID, (_upWhy == ""), _upWhy, "Bigger border, more income, and unlocks level 2 units at level 3"));
		array_push(_items, make_button("Rename City", "F2", UI_ACT.RENAME_CITY, 0, NO_ID, true, "", "Give this city a new name"));
		} else if ((_g.selectedBuildingId != NO_ID) && _world.buildings[_g.selectedBuildingId].alive && (_world.buildings[_g.selectedBuildingId].owner == _local)) {
		var _b = _world.buildings[_g.selectedBuildingId];
		var _source = get_building_unit_source(_b.type);

		if (_b.type == BUILDING.EMBASSY) {
			// One envoy button per nation: pick the capital to deliver a treaty to
			for (var _n = 0; _n < MAX_NATIONS; _n++) {
				var _other = _world.nationStates[_n];
				if ((_n == _local) || !_other.active || _other.eliminated) {
					continue;
				}
				var _cost2 = global.unitStats[UNIT_TYPE.ENVOY].cost;
				var _eWhy = "";
				if (get_treaty_between(_world, _local, _n) != undefined) {
					_eWhy = "You already have a treaty with them";
				} else if (get_active_treaty(_world, _local) != undefined) {
					_eWhy = "You already have a treaty. Declare war first";
				} else if (_state.gold < _cost2) {
					_eWhy = "Not enough gold";
				}
				var _eSub = (_eWhy == "") ? ("Envoy  -  " + string(_cost2) + " gold") : _eWhy;
				array_push(_items, make_button("Treaty: " + get_owner_name(_n), _eSub, UI_ACT.SEND_ENVOY, _n, _b.buildingId, (_eWhy == ""), _eWhy, "Sends an envoy to their capital. Envoys move 1 tile at a time"));
			}
		} else if (_source != NO_ID) {
			for (var _u = 0; _u < UNIT_TYPE.COUNT; _u++) {
				if (global.unitStats[_u].source == _source) {
					array_push(_items, make_unit_button(_world, _local, _state, _u, _b.level, UI_ACT.TRAIN_UNIT, _b.buildingId));
				}
			}
		}

		var _bdef = global.buildingDefs[_b.type];
		var _bUpSub = "Max level";
		var _bUpWhy = "Already at max level";
		if (_b.level < _bdef.maxLevel) {
			var _bCost = get_building_upgrade_cost(_b);
			_bUpSub = "Lv " + string(_b.level) + " > " + string(_b.level + 1) + "  -  " + string(_bCost) + " gold";
			_bUpWhy = (_state.gold >= _bCost) ? "" : "Not enough gold";
		}
		array_push(_items, make_button("Upgrade", _bUpSub, UI_ACT.UPGRADE_BUILDING, _b.buildingId, NO_ID, (_bUpWhy == ""), _bUpWhy, ""));
		array_push(_items, make_button("Demolish", "Refund " + string(get_demolish_refund(_b.type)) + " gold", UI_ACT.DEMOLISH, _b.buildingId, NO_ID, true, "", "Removes the building and refunds half its cost (Delete key)"));
	} else if (array_length(_g.selectedUnitIds) > 0) {
		var _explorer = get_selected_explorer_on_habitable(_g);
		if (_explorer != undefined) {
			array_push(_items, make_button("Found City", get_unit_name(_local, UNIT_TYPE.EXPLORER), UI_ACT.FOUND_CITY, _explorer.unitId, NO_ID, true, "", "Turn this habitable tile into a city"));
		}
		var _carrier = get_selected_carrier(_g);
		if (_carrier != undefined) {
			var _capacity = global.unitStats[_carrier.type].capacity;
			var _used = get_boat_cargo_weight(_world, _carrier);
			var _hasCargo = (array_length(_carrier.cargo) > 0);
			array_push(_items, make_button(_hasCargo ? "Unload (" + keybind_name(KEY_ACT.CARGO) + ")" : "Load (" + keybind_name(KEY_ACT.CARGO) + ")", "Weight " + string(_used) + "/" + string(_capacity), UI_ACT.TOGGLE_CARGO, _carrier.unitId, NO_ID, true, "", "Load: takes every land unit of your nation within 1 tile\\nUnload: puts them on free tiles within 1 tile"));
		}
		var _boat = get_selected_boat(_g);
		if (_boat != undefined) {
			var _mineCost = global.buildingDefs[BUILDING.NAVAL_MINE].cost;
			var _mWhy = "";
			if (!nation_has_research(_world, _local, RESEARCH.NAVAL_MINES)) {
				_mWhy = "Needs: Naval Mines";
			} else if (_state.gold < _mineCost) {
				_mWhy = "Not enough gold";
			}
			array_push(_items, make_button("Lay Mine", (_mWhy == "") ? (string(_mineCost) + " gold") : _mWhy, UI_ACT.PLACE_MINE, _boat.unitId, NO_ID, (_mWhy == ""), _mWhy, "Drops a naval mine on the boat's tile. Enemies cannot see it until they are close"));
		}
	}

	// Lay out from the bottom left, wrapping upward. The side panel takes space on the right.
	var _gap = 8;
	var _availW = _g.screenW - 24 - ((_g.panel == PANEL.BUILD) ? (PANEL_W + 8) : 0);
	var _perRow = max(1, floor((_availW + _gap) / (BUTTON_W + _gap)));
	for (var _i = 0; _i < array_length(_items); _i++) {
		var _row = floor(_i / _perRow);
		var _col = _i mod _perRow;
		_items[_i].x = 12 + _col * (BUTTON_W + _gap);
		_items[_i].y = _g.screenH - 26 - BUTTON_H - _row * (BUTTON_H + _gap);
		_items[_i].zone = 2;
		array_push(_list, _items[_i]);
	}
}

function make_unit_button(_world, _local, _state, _type, _level, _action, _siteId) {
	var _stats = global.unitStats[_type];
	var _lock = get_unit_lock_reason(_world, _local, _type, _level);
	var _why = _lock;
	if ((_why == "") && (_state.gold < _stats.cost)) {
		_why = "Not enough gold";
	}
	if ((_why == "") && (_stats.popCost > 0)) {
		var _pop = get_pop_cached(_world, _local);
		if (_pop.used + _stats.popCost > _pop.cap) {
			_why = "Population full";
		}
	}
	var _popText = (_stats.popCost > 0) ? ("  -  " + string(_stats.popCost) + " pop") : "";
	var _sub = (_why == "Population full") ? _why : ((_lock != "") ? _lock : (_stats.subtitle + "  -  " + string(_stats.cost) + "g" + _popText));
	return make_button(get_unit_name(_local, _type), _sub, _action, _type, _siteId, (_why == ""), _why, get_unit_tip(_type));
}

function get_selected_explorer_on_habitable(_g) {
	for (var _i = 0; _i < array_length(_g.selectedUnitIds); _i++) {
		var _u = _g.world.units[_g.selectedUnitIds[_i]];
		if (_u.alive && (_u.type == UNIT_TYPE.EXPLORER) && (ds_grid_get(_g.world.habitable, _u.gx, _u.gy) == 1) && (ds_grid_get(_g.world.cityGrid, _u.gx, _u.gy) == NO_ID)) {
			return _u;
		}
	}
	return undefined;
}

function get_selected_carrier(_g) {
	for (var _i = 0; _i < array_length(_g.selectedUnitIds); _i++) {
		var _u = _g.world.units[_g.selectedUnitIds[_i]];
		if (_u.alive && (global.unitStats[_u.type].capacity > 0)) {
			return _u;
		}
	}
	return undefined;
}

function get_selected_boat(_g) {
	for (var _i = 0; _i < array_length(_g.selectedUnitIds); _i++) {
		var _u = _g.world.units[_g.selectedUnitIds[_i]];
		if (_u.alive && (_u.type == UNIT_TYPE.BUILDING_BOAT)) {
			return _u;
		}
	}
	return undefined;
}

function point_in_button(_b, _mx, _my) {
	// Build menu buttons are clipped by the top of the list
	if ((_b.zone == 1) && (_my < get_build_list_top())) {
		return false;
	}
	return (_mx >= _b.x) && (_mx <= _b.x + _b.w) && (_my >= _b.y) && (_my <= _b.y + _b.h);
}

function get_hud_button_at(_g, _mx, _my) {
	var _buttons = get_hud_buttons(_g);
	for (var _i = 0; _i < array_length(_buttons); _i++) {
		if (point_in_button(_buttons[_i], _mx, _my)) {
			return _buttons[_i];
		}
	}
	return undefined;
}

// True when the cursor is over any part of the HUD, so the world should ignore it
function hud_captures_mouse(_g, _mx, _my) {
	if (_g.localNation != NO_ID) {
		// A treaty offer blocks the whole screen
		if (get_offer_for(_g.world, _g.localNation) != undefined) {
			return true;
		}
	}
	if (_my < TOP_H) {
		return true;
	}
	// An overlay screen blocks everything below the top bar
	if (panel_is_overlay(_g.panel)) {
		return true;
	}
	if (mouse_over_build_panel(_g, _mx, _my)) {
		return true;
	}
	return (get_hud_button_at(_g, _mx, _my) != undefined);
}

function execute_hud_button(_g, _button) {
	_g.hudCache = undefined;
	if (!_button.enabled) {
		sfx_play("ui_error");
		if (_button.why != "") {
			set_toast(_g, _button.why);
		}
		return;
	}
	sfx_play("ui_click");
	var _local = _g.localNation;
	var _cmd;
	switch (_button.action) {
		case UI_ACT.TOGGLE_PANEL:
			_g.panel = (_g.panel == _button.arg) ? PANEL.NONE : _button.arg;
			_g.panelScroll = 0;
			return;

		case UI_ACT.PICK_BUILDING:
			// NO_ID cancels placing
			_g.demolishMode = false;
			_g.placeType = _button.arg;
			_g.placeMsg = "";
			if (_button.arg != NO_ID) {
				clear_selection(_g);
			}
			return;

		case UI_ACT.BUY_UNIT:
			_cmd = make_command(CMD.BUY_UNIT, _local);
			_cmd.cityId = _g.selectedCityId;
			_cmd.unitType = _button.arg;
			break;

		case UI_ACT.TRAIN_UNIT:
			_cmd = make_command(CMD.TRAIN_UNIT, _local);
			_cmd.buildingId = _button.arg2;
			_cmd.unitType = _button.arg;
			break;

		case UI_ACT.UPGRADE_CITY:
			_cmd = make_command(CMD.UPGRADE_CITY, _local);
			_cmd.cityId = _g.selectedCityId;
			break;

		case UI_ACT.UPGRADE_BUILDING:
			_cmd = make_command(CMD.UPGRADE_BUILDING, _local);
			_cmd.buildingId = _button.arg;
			break;

		case UI_ACT.FOUND_CITY:
			_cmd = make_command(CMD.FOUND_CITY, _local);
			array_push(_cmd.unitIds, _button.arg);
			break;

		case UI_ACT.RESEARCH:
			_cmd = make_command(CMD.RESEARCH, _local);
			_cmd.researchId = _button.arg;
			break;

		case UI_ACT.SEND_ENVOY:
			_cmd = make_command(CMD.SEND_ENVOY, _local);
			_cmd.targetNation = _button.arg;
			_cmd.buildingId = _button.arg2;
			break;

		case UI_ACT.PLACE_MINE:
			_cmd = make_command(CMD.PLACE_MINE, _local);
			array_push(_cmd.unitIds, _button.arg);
			break;
		
		case UI_ACT.TOGGLE_DEMOLISH:
			_g.demolishMode = !_g.demolishMode;
			_g.placeType = NO_ID;
			_g.placeMsg = "";
			if (_g.demolishMode) {
				clear_selection(_g);
			}
			return;

		case UI_ACT.DEMOLISH:
			var _demoB = _g.world.buildings[_button.arg];
			var _demoRefund = get_demolish_refund(_demoB.type);
			_cmd = make_command(CMD.DEMOLISH, _local);
			_cmd.buildingId = _button.arg;
			if (run_player_command(_g, _cmd) == "") {
				set_toast(_g, "Demolished. Refunded " + string(_demoRefund) + " gold");
				_g.selectedBuildingId = NO_ID;
			}
			return;
		
		case UI_ACT.TOGGLE_CARGO:
			_cmd = make_command(CMD.TOGGLE_CARGO, _local);
			for (var _s = 0; _s < array_length(_g.selectedUnitIds); _s++) {
				var _sel = _g.world.units[_g.selectedUnitIds[_s]];
				if (global.unitStats[_sel.type].capacity > 0) {
					array_push(_cmd.unitIds, _sel.unitId);
				}
			}
			break;

		case UI_ACT.DECLARE_WAR:
			_cmd = make_command(CMD.DECLARE_WAR, _local);
			_cmd.targetNation = _button.arg;
			break;

		case UI_ACT.ANSWER_OFFER:
			_cmd = make_command(CMD.ANSWER_OFFER, _local);
			_cmd.flag = _button.arg;
			break;

		default:
			return;
			
		case UI_ACT.RENAME_CITY:
			rename_begin(_g, _g.selectedCityId);
			return;
			
		case UI_ACT.FINAL_VOTE:
			_cmd = make_command(CMD.FINAL_VOTE, _local);
			_cmd.flag = _button.arg;
			break;
	}
	run_player_command(_g, _cmd);
}

// ------------------------------------------------------------
// Selection information (the name and level of a building only show when it is selected)
// ------------------------------------------------------------

function get_selection_lines(_g) {
	var _world = _g.world;
	var _lines = [];
	
	if (_g.demolishMode) {
		array_push(_lines, "Demolish: click one of your buildings or paths (right click to stop). Half the cost is refunded.");
		return _lines;
	}

	if (_g.placeType != NO_ID) {
		var _def = global.buildingDefs[_g.placeType];
		array_push(_lines, "Placing: " + _def.buildingName + "   (click to place, right click to cancel, shift keeps placing)");
		if (_g.placeMsg != "") {
			array_push(_lines, _g.placeMsg);
		}
		return _lines;
	}

	if (_g.selectedBuildingId != NO_ID) {
		var _b = _world.buildings[_g.selectedBuildingId];
		if (!_b.alive) {
			return _lines;
		}
		var _bdef = global.buildingDefs[_b.type];
		var _owner = (_b.owner == _g.localNation) ? "" : ("   (" + get_owner_name(_b.owner) + ")");
		array_push(_lines, _bdef.buildingName + "   Lv " + string(_b.level) + "/" + string(_bdef.maxLevel) + "   HP " + string(ceil(_b.hp)) + "/" + string(_b.maxHp) + _owner);
		array_push(_lines, _bdef.desc);
		switch (_b.type) {
			case BUILDING.TOWER:
				array_push(_lines, "Damage " + string_format(get_tower_damage(_b.level), 1, 1) + "   Shoots every " + string_format(get_tower_delay(_b.level), 1, 2) + "s   Range 1 tile");
				break;
			case BUILDING.LABORATORY:
				array_push(_lines, "+" + string_format(0.5 * _b.level, 1, 1) + " research points per second");
				break;
			case BUILDING.HOSPITAL:
				array_push(_lines, "Heals " + string_format(get_hospital_heal_rate(_b.level), 1, 1) + " HP per second within 1 tile");
				break;
			case BUILDING.LUMBER_MILL:
			case BUILDING.QUARRY:
			case BUILDING.MINE:
			case BUILDING.MARKET:
				array_push(_lines, "+" + string_format(get_building_income(_b), 1, 1) + " gold per second");
				break;
			case BUILDING.GATE:
				array_push(_lines, "Your units walk through it, everyone else is blocked");
				break;
			case BUILDING.HOUSING:
				array_push(_lines, "+" + string(_b.level * HOUSING_POP_PER_LEVEL) + " population");
				break;
		}
		return _lines;
	}

	if (_g.selectedCityId != NO_ID) {
		var _c = _world.cities[_g.selectedCityId];
		var _capital = ((_c.owner >= 0) && (_world.nationStates[_c.owner].capitalId == _c.cityId)) ? "   Capital" : "";
		array_push(_lines, _c.cityName + "   Lv " + string(_c.level) + "/" + string(MAX_CITY_LEVEL) + "   HP " + string(ceil(_c.hp)) + "/" + string(_c.maxHp) + _capital + "   (" + get_owner_name(_c.owner) + ")");
		array_push(_lines, "Income " + string_format(get_city_income(_c), 1, 1) + "/s   Border " + string(get_city_border_radius(_c.level)) + " tiles");
		return _lines;
	}

	var _count = array_length(_g.selectedUnitIds);
	if (_count == 1) {
		var _u = _world.units[_g.selectedUnitIds[0]];
		var _s = global.unitStats[_u.type];
		array_push(_lines, get_unit_name(_u.owner, _u.type) + "   (" + _s.subtitle + ")   HP " + string(ceil(_u.hp)) + "/" + string(_s.maxHp));
		array_push(_lines, _s.desc + "   Damage " + string(_s.damage) + "   Range " + string(_s.range) + "   Weight " + string(_s.weight));
		if (_s.capacity > 0) {
			array_push(_lines, "Cargo: " + string(array_length(_u.cargo)) + " units, weight " + string(get_boat_cargo_weight(_world, _u)) + "/" + string(_s.capacity) + "   (E loads land units within 1 tile, E again unloads)");
		}
	} else if (_count > 1) {
		array_push(_lines, "Selected units: " + string(_count));
	}
	return _lines;
}

// ------------------------------------------------------------
// Drawing
// ------------------------------------------------------------

function draw_hud_button(_b, _mx, _my) {
	var _hover = point_in_button(_b, _mx, _my);
	var _fill = (_b.colour != -1) ? _b.colour : make_colour_rgb(40, 55, 85);
	if (!_b.enabled) {
		_fill = make_colour_rgb(50, 50, 50);
	} else if (_b.active) {
		_fill = make_colour_rgb(90, 120, 170);
	} else if (_hover) {
		_fill = (_b.colour != -1) ? merge_colour(_b.colour, c_white, 0.25) : make_colour_rgb(70, 90, 130);
	}
	draw_set_colour(_fill);
	draw_rectangle(_b.x, _b.y, _b.x + _b.w, _b.y + _b.h, false);
	draw_set_colour(_b.enabled ? c_white : c_gray);
	draw_rectangle(_b.x, _b.y, _b.x + _b.w, _b.y + _b.h, true);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	if (_b.sub == "") {
		draw_set_valign(fa_middle);
		draw_set_halign(fa_center);
		draw_text(_b.x + _b.w / 2, _b.y + _b.h / 2, _b.label);
	} else {
		draw_text(_b.x + 8, _b.y + 6, _b.label);
		draw_set_colour(_b.enabled ? c_aqua : c_gray);
		draw_text(_b.x + 8, _b.y + _b.h - 6 - string_height("A"), _b.sub);
	}
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

function draw_tooltip(_text, _mx, _my, _screenW, _screenH) {
	var _w = min(340, string_width_ext(_text, 16, 320) + 16);
	var _h = string_height_ext(_text, 16, 320) + 12;
	var _x = clamp(_mx - _w - 14, 4, _screenW - _w - 4);
	var _y = clamp(_my - _h - 8, TOP_H + 4, _screenH - _h - 4);
	draw_set_colour(c_black);
	draw_set_alpha(0.88);
	draw_rectangle(_x, _y, _x + _w, _y + _h, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
	draw_rectangle(_x, _y, _x + _w, _y + _h, true);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_text_ext(_x + 8, _y + 6, _text, 16, 320);
}

function draw_hud(_g) {
	var _world = _g.world;
	var _local = _g.localNation;
	var _mx = device_mouse_x_to_gui(0);
	var _my = device_mouse_y_to_gui(0);

	// Top bar
	draw_set_colour(c_black);
	draw_set_alpha(0.75);
	draw_rectangle(0, 0, _g.screenW, TOP_H, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_middle);

	if (_local != NO_ID) {
		var _state = _world.nationStates[_local];
		draw_set_colour(get_owner_colour(_local));
		draw_rectangle(8, 8, 28, 28, false);
		draw_set_colour(c_white);
		draw_text(36, TOP_H / 2, get_owner_name(_local)
			+ "    Gold " + string(floor(_state.gold)) + " (+" + string_format(get_nation_income(_world, _local), 1, 1) + "/s)"
			+ "    RP " + string(floor(_state.rp)) + " (+" + string_format(get_rp_rate(_world, _local), 1, 1) + "/s)"
			+ "    Cities " + string(count_nation_cities(_world, _local))
			+ "    Pop " + string(get_pop_cached(_world, _local).used) + "/" + string(get_pop_cached(_world, _local).cap));
	} else {
		draw_text(12, TOP_H / 2, "Spectating    Map: " + _world.preset.presetName + "    Seed: " + string(_world.seed));
	}

	// Side panel
	// Build menu (the other tabs are overlay screens, drawn after the buttons)
	var _buttons = get_hud_buttons(_g);
	if (_g.panel == PANEL.BUILD) {
		draw_side_panel(_g, _buttons, _mx, _my);
	}

	// Buttons
	var _bottomTop = _g.screenH - 26 - BUTTON_H;
	for (var _i = 0; _i < array_length(_buttons); _i++) {
		var _b = _buttons[_i];
		if ((_b.zone == 1) || (_b.zone == 3) || (_b.zone == 4) || (_b.zone == 5)) {
			continue;
		}
		draw_hud_button(_b, _mx, _my);
		if ((_b.zone == 2) && (_b.y < _bottomTop)) {
			_bottomTop = _b.y;
		}
	}

	// Selection info sits just above the bottom buttons
	var _lines = get_selection_lines(_g);
	if (array_length(_lines) > 0) {
		var _text = "";
		for (var _l = 0; _l < array_length(_lines); _l++) {
			_text += ((_l > 0) ? "\n" : "") + _lines[_l];
		}
		var _tw = string_width(_text) + 16;
		var _th = string_height(_text) + 10;
		draw_set_colour(c_black);
		draw_set_alpha(0.7);
		draw_rectangle(12, _bottomTop - 8 - _th, 12 + _tw, _bottomTop - 8, false);
		draw_set_alpha(1);
		draw_set_colour(c_white);
		draw_set_valign(fa_top);
		draw_text(20, _bottomTop - 8 - _th + 5, _text);
	}

	// Controls hint
	draw_set_halign(fa_right);
	draw_set_valign(fa_bottom);
	draw_set_colour(c_ltgray);
	draw_text(_g.screenW - 12 - ((_g.panel == PANEL.BUILD) ? PANEL_W : 0), _g.screenH - 6, "LMB select / order  |  drag box  |  MMB / WASD pan  |  wheel zoom  |  RMB cancel / deselect  |  E load / unload boat  |  F1 debug");
	draw_set_halign(fa_left);
	
	// Overlay screens (research tree, diplomacy, ideology)
	if (panel_is_overlay(_g.panel)) {
		draw_overlay(_g, _buttons, _mx, _my);
	}
	
	draw_notices(_g);
	draw_final_banner(_g, _buttons, _mx, _my);

	// Hover tooltip
	for (var _t = 0; _t < array_length(_buttons); _t++) {
		if ((global.options.tooltips == 1) && (_buttons[_t].tip != "") && point_in_button(_buttons[_t], _mx, _my)) {
			draw_tooltip(string_replace_all(_buttons[_t].tip, "\\n", "\n"), _mx, _my, _g.screenW, _g.screenH);
			break;
		}
	}

	// Debug (F1)
	if (_g.debugOverlay) {
		draw_set_halign(fa_left);
		draw_set_valign(fa_top);
		draw_set_colour(c_yellow);
		draw_text(12, 150, "gui mouse: " + string(_mx) + ", " + string(_my)
			+ "\nwindow mouse: " + string(window_mouse_get_x()) + ", " + string(window_mouse_get_y())
			+ "\nscreen: " + string(_g.screenW) + " x " + string(_g.screenH)
			+ "\ncam: " + string_format(_g.camX, 1, 1) + ", " + string_format(_g.camY, 1, 1) + "  zoom: " + string_format(_g.zoom, 1, 2)
			+ "\nworld mouse: " + string_format(_g.mouseWx, 1, 1) + ", " + string_format(_g.mouseWy, 1, 1)
			+ "\nhover tile: " + string(_g.hoverGx) + ", " + string(_g.hoverGy)
			+ "\nmap: " + _world.preset.presetName + "  seed: " + string(_world.seed));
		draw_set_colour(c_white);
	}

	// Toast message
	if (_g.toastTimer > 0) {
		draw_set_halign(fa_center);
		draw_set_valign(fa_top);
		var _toastW = max(320, string_width(_g.toastText) + 32);
		draw_set_colour(c_black);
		draw_set_alpha(0.7);
		draw_rectangle(_g.screenW / 2 - _toastW / 2, get_notice_top(_g), _g.screenW / 2 + _toastW / 2, get_notice_top(_g) + 28, false);
		draw_set_alpha(1);
		draw_set_colour(c_white);
		draw_text(_g.screenW / 2, get_notice_top(_g) + 6, _g.toastText);
		draw_set_halign(fa_left);
	}

	draw_offer_popup(_g, _buttons, _mx, _my);
	draw_game_over(_g);
	draw_set_colour(c_white);
	draw_set_alpha(1);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

function draw_notices(_g) {
	var _y = get_notice_top(_g);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	var _shown = 0;
	for (var _i = array_length(_g.world.notices) - 1; _i >= 0; _i--) {
		var _n = _g.world.notices[_i];
		if ((_n.target != NOTICE_ALL) && (_n.target != _g.localNation)) {
			continue;
		}
		var _fade = clamp((NOTICE_LIFETIME - _n.age) / 2, 0, 1);
		draw_set_alpha(0.7 * _fade);
		draw_set_colour(c_black);
		draw_rectangle(12, _y - 2, 20 + string_width(_n.text), _y + string_height(_n.text) + 2, false);
		draw_set_alpha(_fade);
		draw_set_colour(c_white);
		draw_text(16, _y, _n.text);
		_y += string_height(_n.text) + 6;
		_shown++;
		if (_shown >= 6) {
			break;
		}
	}
	draw_set_alpha(1);
}

function draw_side_panel(_g, _buttons, _mx, _my) {
	var _x = _g.screenW - PANEL_W;
	var _listTop = get_build_list_top();
	draw_set_colour(make_colour_rgb(18, 24, 38));
	draw_set_alpha(0.9);
	draw_rectangle(_x, TOP_H, _g.screenW, _g.screenH, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
	draw_line(_x, TOP_H, _x, _g.screenH);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_text(_x + 12, TOP_H + 12, "Buildings");

	// The list is clipped so scrolled buttons cannot draw over the title
	gpu_set_scissor(_x, _listTop, PANEL_W, _g.screenH - _listTop);
	for (var _i = 0; _i < array_length(_buttons); _i++) {
		if (_buttons[_i].zone == 1) {
			draw_hud_button(_buttons[_i], _mx, _my);
		}
	}
	gpu_set_scissor(0, 0, _g.screenW, _g.screenH);

	// Scrollbar
	var _scrollMax = get_build_scroll_max(_g);
	if (_scrollMax > 0) {
		var _trackH = _g.screenH - _listTop - 8;
		var _thumbH = max(24, _trackH * _trackH / (_trackH + _scrollMax));
		var _thumbY = _listTop + (_trackH - _thumbH) * (_g.panelScroll / _scrollMax);
		draw_set_colour(make_colour_rgb(50, 55, 70));
		draw_rectangle(_g.screenW - 6, _listTop, _g.screenW - 2, _listTop + _trackH, false);
		draw_set_colour(c_ltgray);
		draw_rectangle(_g.screenW - 6, _thumbY, _g.screenW - 2, _thumbY + _thumbH, false);
	}
	draw_set_colour(c_white);
}

// ------------------------------------------------------------
// Overlay screens
// ------------------------------------------------------------

// Draws an elbow link: down from the first point, across, and down to the second
function draw_tree_link(_x1, _y1, _x2, _y2, _col, _width) {
	var _midY = (_y1 + _y2) / 2;
	draw_set_colour(_col);
	draw_line_width(_x1, _y1, _x1, _midY, _width);
	draw_line_width(_x1, _midY, _x2, _midY, _width);
	draw_line_width(_x2, _midY, _x2, _y2, _width);
}

function draw_research_node(_b, _mx, _my) {
	var _hover = point_in_button(_b, _mx, _my);
	var _bc = get_branch_colour(_b.branch);
	var _fill = make_colour_rgb(28, 32, 46);
	var _border = _bc;
	var _textCol = c_white;
	var _subCol = c_aqua;
	if (_b.state == 2) {
		_fill = merge_colour(_bc, c_black, 0.4);
		_subCol = c_white;
	} else if (_b.state == 0) {
		_fill = make_colour_rgb(26, 26, 32);
		_border = make_colour_rgb(80, 80, 90);
		_textCol = c_gray;
		_subCol = c_gray;
	} else if (!_b.enabled) {
		// Prerequisite done, but not enough research points yet
		_subCol = make_colour_rgb(255, 130, 120);
	} else if (_hover) {
		_fill = merge_colour(_bc, c_black, 0.65);
	}
	draw_set_colour(_fill);
	draw_rectangle(_b.x, _b.y, _b.x + _b.w, _b.y + _b.h, false);
	draw_set_colour(_border);
	draw_rectangle(_b.x, _b.y, _b.x + _b.w, _b.y + _b.h, true);
	draw_rectangle(_b.x + 1, _b.y + 1, _b.x + _b.w - 1, _b.y + _b.h - 1, true);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_colour(_textCol);
	draw_text_ext(_b.x + 6, _b.y + 4, _b.label, 16, _b.w - 12);
	draw_set_colour(_subCol);
	draw_text(_b.x + 6, _b.y + _b.h - 20, _b.sub);
}

function draw_ideology_panel(_g, _o) {
	var _world = _g.world;
	var _local = _g.localNation;
	var _scores = get_ideology_scores(_world, _local);
	var _radius = min(110, (_o.h - 150) / 2);
	var _cx = _o.x + 250;
	var _cy = _o.y + 70 + _radius + 24;
	var _x = _o.x + _o.w * 0.55;
	var _barW = _o.x + _o.w - 30 - (_x + 110);

	// Grid
	for (var _ring = 1; _ring <= 4; _ring++) {
		draw_radar_ring(_cx, _cy, _radius * _ring / 4, IDEO.COUNT, make_colour_rgb(70, 80, 100));
	}
	for (var _i = 0; _i < IDEO.COUNT; _i++) {
		var _ang = 90 - _i * (360 / IDEO.COUNT);
		draw_line_colour(_cx, _cy, _cx + lengthdir_x(_radius, _ang), _cy + lengthdir_y(_radius, _ang), make_colour_rgb(70, 80, 100), make_colour_rgb(70, 80, 100));
	}

	// The nation's stance
	draw_radar_fill(_cx, _cy, _radius, _scores, get_owner_colour(_local), 0.5);
	for (var _p = 0; _p < IDEO.COUNT; _p++) {
		var _pa = 90 - _p * (360 / IDEO.COUNT);
		var _px = _cx + lengthdir_x(_radius * _scores[_p], _pa);
		var _py = _cy + lengthdir_y(_radius * _scores[_p], _pa);
		draw_set_colour(global.ideologyColours[_p]);
		draw_circle(_px, _py, 4, false);
	}

	// Labels
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);
	for (var _j = 0; _j < IDEO.COUNT; _j++) {
		var _la = 90 - _j * (360 / IDEO.COUNT);
		draw_set_colour(global.ideologyColours[_j]);
		draw_text(_cx + lengthdir_x(_radius + 28, _la), _cy + lengthdir_y(_radius + 18, _la), global.ideologyNames[_j]);
	}

	// Bars with what each score means
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	var _by = _o.y + 80;
	for (var _k = 0; _k < IDEO.COUNT; _k++) {
		draw_set_colour(global.ideologyColours[_k]);
		draw_text(_x, _by, global.ideologyNames[_k]);
		draw_set_colour(make_colour_rgb(50, 55, 70));
		draw_rectangle(_x + 110, _by + 3, _x + 110 + _barW, _by + 13, false);
		draw_set_colour(global.ideologyColours[_k]);
		draw_rectangle(_x + 110, _by + 3, _x + 110 + _barW * _scores[_k], _by + 13, false);
		_by += 26;
	}
	draw_set_colour(c_ltgray);
	draw_text_ext(_x, _by + 12, "Bots that are far ahead of you in land, gold and power only sign peace if your stance fits their ideology. Real players ignore this.", 16, _o.x + _o.w - 30 - _x);
	draw_set_colour(c_white);
}

function draw_offer_popup(_g, _buttons, _mx, _my) {
	if (_g.localNation == NO_ID) {
		return;
	}
	var _offer = get_offer_for(_g.world, _g.localNation);
	if (_offer == undefined) {
		return;
	}
	var _cx = _g.screenW / 2;
	var _cy = _g.screenH / 2;
	draw_set_colour(c_black);
	draw_set_alpha(0.55);
	draw_rectangle(0, 0, _g.screenW, _g.screenH, false);
	draw_set_alpha(1);
	draw_set_colour(make_colour_rgb(25, 32, 50));
	draw_rectangle(_cx - 200, _cy - 90, _cx + 200, _cy + 90, false);
	draw_set_colour(c_white);
	draw_rectangle(_cx - 200, _cy - 90, _cx + 200, _cy + 90, true);
	draw_set_halign(fa_center);
	draw_set_valign(fa_top);
	draw_text(_cx, _cy - 78, "Peace treaty offer");
	var _msg = get_owner_name(_offer.from) + " has sent an envoy to your capital offering a peace treaty.";
	if (_offer.betray) {
		var _current = get_active_treaty(_g.world, _g.localNation);
		if (_current != undefined) {
			_msg += "\nAccepting betrays your treaty with " + get_owner_name(get_treaty_partner(_current, _g.localNation)) + ". War with them is declared in " + string(BETRAY_WAR_DELAY) + "s.";
		}
	}
	draw_text_ext(_cx, _cy - 52, _msg, 16, 370);
	for (var _i = 0; _i < array_length(_buttons); _i++) {
		if (_buttons[_i].zone == 3) {
			draw_hud_button(_buttons[_i], _mx, _my);
		}
	}
}