// ============================================================
// scr_diplomacy: notices, research lookup, nation stats, ideology,
// treaties, treaty offers and war declarations
// ============================================================

// ------------------------------------------------------------
// Notices (the little messages shown on screen)
// ------------------------------------------------------------

// _target is a nation index, or NOTICE_ALL to show it to everyone
function push_notice(_world, _target, _text) {
	array_push(_world.notices, { target: _target, text: _text, age: 0 });
	if (array_length(_world.notices) > 40) {
		array_delete(_world.notices, 0, 1);
	}
}

function update_notices(_world, _dt) {
	for (var _i = array_length(_world.notices) - 1; _i >= 0; _i--) {
		_world.notices[_i].age += _dt;
		if (_world.notices[_i].age > NOTICE_LIFETIME) {
			array_delete(_world.notices, _i, 1);
		}
	}
}

// ------------------------------------------------------------
// Small lookups
// ------------------------------------------------------------

function nation_has_research(_world, _owner, _researchId) {
	if ((_owner < 0) || (_owner >= MAX_NATIONS)) {
		return false;
	}
	return _world.nationStates[_owner].researched[_researchId];
}

// Tribes are hostile to everyone, nations are hostile unless a treaty protects them
function are_hostile(_world, _a, _b) {
	if (_a == _b) {
		return false;
	}
	if ((_a < 0) || (_b < 0)) {
		return true;
	}
	// A treaty keeps the peace even while a war declaration is counting down
	return (get_treaty_between(_world, _a, _b) == undefined);
}

function get_treaty_between(_world, _a, _b) {
	for (var _i = 0; _i < array_length(_world.treaties); _i++) {
		var _t = _world.treaties[_i];
		if (((_t.a == _a) && (_t.b == _b)) || ((_t.a == _b) && (_t.b == _a))) {
			return _t;
		}
	}
	return undefined;
}

// A nation can only be in one treaty at a time
function get_active_treaty(_world, _owner) {
	for (var _i = 0; _i < array_length(_world.treaties); _i++) {
		var _t = _world.treaties[_i];
		if ((_t.a == _owner) || (_t.b == _owner)) {
			return _t;
		}
	}
	return undefined;
}

function get_treaty_partner(_treaty, _owner) {
	return (_treaty.a == _owner) ? _treaty.b : _treaty.a;
}

// ------------------------------------------------------------
// Nation stats (used by the ideology system)
// ------------------------------------------------------------

function update_nation_stats(_world) {
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		var _s = _world.nationStates[_n].stats;
		_s.land = 0;
		_s.units = 0;
		_s.power = 0;
		_s.gold = _world.nationStates[_n].gold;
		_s.income = get_nation_income(_world, _n);
	}
	for (var _gx = 0; _gx < _world.mapW; _gx++) {
		for (var _gy = 0; _gy < _world.mapH; _gy++) {
			var _o = ds_grid_get(_world.borderOwner, _gx, _gy);
			if (_o >= 0) {
				_world.nationStates[_o].stats.land++;
			}
		}
	}
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (!_u.alive || (_u.owner < 0) || (_u.type == UNIT_TYPE.EXPLORER) || (global.unitStats[_u.type].diplomat)) {
			continue;
		}
		var _st = _world.nationStates[_u.owner].stats;
		_st.units++;
		// Power is roughly what the army cost, scaled by how healthy it is
		_st.power += global.unitStats[_u.type].cost * (_u.hp / global.unitStats[_u.type].maxHp);
	}
}

// ------------------------------------------------------------
// Ideology
// Every score is 0 to 1, measured against the strongest living nation.
// ------------------------------------------------------------

// Returns an array of 5 scores in IDEO order
function get_ideology_scores(_world, _owner) {
	var _maxLand = 1;
	var _maxIncome = 1;
	var _maxGold = 1;
	var _maxUnits = 1;
	var _maxPower = 1;
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		var _state = _world.nationStates[_n];
		if (!_state.active || _state.eliminated) {
			continue;
		}
		_maxLand = max(_maxLand, _state.stats.land);
		_maxIncome = max(_maxIncome, _state.stats.income);
		_maxGold = max(_maxGold, _state.stats.gold);
		_maxUnits = max(_maxUnits, _state.stats.units);
		_maxPower = max(_maxPower, _state.stats.power);
	}
	var _st = _world.nationStates[_owner].stats;
	var _scores = array_create(IDEO.COUNT, 0);
	_scores[IDEO.FASCIST] = clamp(_st.power / _maxPower, 0, 1);
	_scores[IDEO.LIBERAL] = clamp(1 - _st.land / _maxLand, 0, 1);
	_scores[IDEO.SOCIALIST] = clamp(_st.income / _maxIncome, 0, 1);
	_scores[IDEO.COMMUNIST] = clamp(_st.gold / _maxGold, 0, 1);
	_scores[IDEO.CONSERVATIST] = clamp(_st.units / _maxUnits, 0, 1);
	return _scores;
}

// Bots have a fixed ideology, players are described by whichever score is highest
function get_nation_ideology(_world, _owner) {
	var _state = _world.nationStates[_owner];
	if (_state.slotType == SLOT_TYPE.BOT) {
		return _state.ideology;
	}
	var _scores = get_ideology_scores(_world, _owner);
	var _best = 0;
	for (var _i = 1; _i < IDEO.COUNT; _i++) {
		if (_scores[_i] > _scores[_best]) {
			_best = _i;
		}
	}
	return _best;
}

// How well _other fits what the bot _bot likes, from 0 to 1
function get_ideology_alignment(_world, _bot, _other) {
	var _ideo = _world.nationStates[_bot].ideology;
	if (_ideo == IDEO.FASCIST) {
		return (get_nation_ideology(_world, _other) == IDEO.FASCIST) ? 1 : 0;
	}
	return get_ideology_scores(_world, _other)[_ideo];
}

// True when the bot is far ahead of _other in land, gold and power
function bot_is_dominant(_world, _bot, _other) {
	var _a = _world.nationStates[_bot].stats;
	var _b = _world.nationStates[_other].stats;
	return (_a.land > _b.land * DOMINANCE_RATIO) && (_a.gold > _b.gold * DOMINANCE_RATIO) && (_a.power > _b.power * DOMINANCE_RATIO);
}

// Would the bot be happy to be at peace with _other right now (ignoring any treaty it already has)
function bot_likes_nation(_world, _bot, _other) {
	// Not much to gain from attacking a nation that is close to your strength
	if (!bot_is_dominant(_world, _bot, _other)) {
		return true;
	}
	return (get_ideology_alignment(_world, _bot, _other) >= ALIGN_ACCEPT);
}

// ------------------------------------------------------------
// Treaties
// ------------------------------------------------------------

function make_treaty(_a, _b) {
	return {
		a: _a,
		b: _b,
		// 0 = peace, 1 = a war declaration is counting down
		state: 0,
		timer: 0,
		declarer: NO_ID,
		// Bots lose favour while they dislike their partner, and declare war at 0
		favour: BOT_FAVOUR_MAX,
		checkTimer: 1
	};
}

// Called when an envoy reaches the capital of _receiver
function deliver_treaty(_world, _sender, _receiver) {
	if (_world.finalVote.phase == FINAL_PHASE.WAR) {
		return;
	}
	var _state = _world.nationStates[_receiver];
	if (_state.eliminated || _world.nationStates[_sender].eliminated) {
		return;
	}
	if (get_treaty_between(_world, _sender, _receiver) != undefined) {
		return;
	}
	var _current = get_active_treaty(_world, _receiver);
	var _betray = (_current != undefined);

	if (_state.slotType == SLOT_TYPE.BOT) {
		var _accept = bot_likes_nation(_world, _receiver, _sender);
		if (_accept && _betray) {
			// Only betray an existing partner for someone who fits the bot's ideology better
			var _oldPartner = get_treaty_partner(_current, _receiver);
			_accept = (get_ideology_alignment(_world, _receiver, _sender) > get_ideology_alignment(_world, _receiver, _oldPartner));
		}
		if (_accept) {
			sign_treaty(_world, _sender, _receiver);
		} else {
			push_notice(_world, _sender, get_owner_name(_receiver) + " rejected your peace treaty");
		}
		return;
	}

	// A human receiver gets a popup. Only one offer per sender at a time
	for (var _i = 0; _i < array_length(_world.offers); _i++) {
		if ((_world.offers[_i].from == _sender) && (_world.offers[_i].to == _receiver)) {
			return;
		}
	}
	array_push(_world.offers, { from: _sender, to: _receiver, betray: _betray, age: 0 });
	push_notice(_world, _sender, "Your envoy reached " + get_owner_name(_receiver));
}

// Creates the treaty. If the receiver already had one it is betrayed and a short war countdown starts
function sign_treaty(_world, _sender, _receiver) {
	var _old = get_active_treaty(_world, _receiver);
	if (_old != undefined) {
		declare_war(_world, _receiver, get_treaty_partner(_old, _receiver), true);
	}
	array_push(_world.treaties, make_treaty(_sender, _receiver));
	push_notice(_world, NOTICE_ALL, get_owner_name(_sender) + " and " + get_owner_name(_receiver) + " signed a peace treaty");
}

// Declaring war is not up to the other side. The treaty only ends once the countdown finishes
function declare_war(_world, _owner, _target, _betrayal) {
	var _t = get_treaty_between(_world, _owner, _target);
	if (_t == undefined) {
		return "You have no treaty with them";
	}
	if (_t.state == 1) {
		return "War is already declared";
	}
	_t.state = 1;
	_t.timer = _betrayal ? BETRAY_WAR_DELAY : WAR_DELAY;
	_t.declarer = _owner;
	var _mins = string(round(_t.timer));
	push_notice(_world, NOTICE_ALL, get_owner_name(_owner) + " declared war on " + get_owner_name(_target) + ". The treaty ends in " + _mins + "s");
	return "";
}

// A human answers the oldest offer made to them
function answer_offer(_world, _owner, _accept) {
	var _index = NO_ID;
	for (var _i = 0; _i < array_length(_world.offers); _i++) {
		if (_world.offers[_i].to == _owner) {
			_index = _i;
			break;
		}
	}
	if (_index == NO_ID) {
		return "No treaty offer to answer";
	}
	var _offer = _world.offers[_index];
	array_delete(_world.offers, _index, 1);
	if (!_accept) {
		push_notice(_world, _offer.from, get_owner_name(_owner) + " rejected your peace treaty");
		return "";
	}
	if (_world.nationStates[_offer.from].eliminated || (get_active_treaty(_world, _offer.from) != undefined)) {
		return "That treaty is no longer possible";
	}
	sign_treaty(_world, _offer.from, _owner);
	return "";
}

function get_offer_for(_world, _owner) {
	for (var _i = 0; _i < array_length(_world.offers); _i++) {
		if (_world.offers[_i].to == _owner) {
			return _world.offers[_i];
		}
	}
	return undefined;
}

function update_treaties(_world, _dt) {
	update_notices(_world, _dt);

	// Unanswered offers run out
	for (var _o = array_length(_world.offers) - 1; _o >= 0; _o--) {
		_world.offers[_o].age += _dt;
		if (_world.offers[_o].age > OFFER_LIFETIME) {
			push_notice(_world, _world.offers[_o].from, "Your peace treaty offer expired");
			array_delete(_world.offers, _o, 1);
		}
	}

	for (var _i = array_length(_world.treaties) - 1; _i >= 0; _i--) {
		var _t = _world.treaties[_i];

		if (_t.state == 1) {
			_t.timer -= _dt;
			if (_t.timer <= 0) {
				push_notice(_world, NOTICE_ALL, "The treaty between " + get_owner_name(_t.a) + " and " + get_owner_name(_t.b) + " is over. War!");
				array_delete(_world.treaties, _i, 1);
			}
			continue;
		}

		// Bots slowly lose favour with partners they no longer like
		_t.checkTimer -= _dt;
		if (_t.checkTimer > 0) {
			continue;
		}
		_t.checkTimer = 1;
		for (var _side = 0; _side < 2; _side++) {
			var _bot = (_side == 0) ? _t.a : _t.b;
			var _other = (_side == 0) ? _t.b : _t.a;
			if (_world.nationStates[_bot].slotType != SLOT_TYPE.BOT) {
				continue;
			}
			if (bot_likes_nation(_world, _bot, _other)) {
				_t.favour = min(BOT_FAVOUR_MAX, _t.favour + 0.5);
			} else {
				_t.favour -= 1;
				if (_t.favour <= 0) {
					declare_war(_world, _bot, _other, false);
					break;
				}
			}
		}
	}
}
