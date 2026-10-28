// ============================================================
// scr_net_sim: keeps every player's game identical (lockstep).
//
// Everybody runs the same simulation with a fixed time step. Nobody applies a command at once:
// it is sent to the host, the host puts the commands of each tick into a "turn" and sends the
// turn to everyone, and every game applies tick N only when it has turn N. The host issues turns
// NET_INPUT_DELAY ticks ahead so the network has time to deliver them.
//
// For this to work the simulation must be exactly repeatable: no random() (use sim_random on the
// world instead), no real time, and no drawing code that changes the world.
// ============================================================

#macro TICK_RATE 30
#macro TICK_DT (1 / 30)
#macro NET_INPUT_DELAY 4
#macro NET_MAX_LAG 45
#macro NET_HASH_EVERY 60

// ------------------------------------------------------------
// The simulation's own random numbers (every game gets the same sequence)
// ------------------------------------------------------------

function sim_random(_world) {
	var _x = _world.rngState;
	_x = _x ^ ((_x << 13) & $FFFFFFFF);
	_x = _x ^ (_x >> 17);
	_x = _x ^ ((_x << 5) & $FFFFFFFF);
	_world.rngState = _x;
	return _x / 4294967296;
}

function sim_random_range(_world, _low, _high) {
	return _low + sim_random(_world) * (_high - _low);
}

// 0 up to and including _n
function sim_irandom(_world, _n) {
	return floor(sim_random(_world) * (_n + 1));
}

function sim_irandom_range(_world, _low, _high) {
	return _low + floor(sim_random(_world) * (_high - _low + 1));
}

// ------------------------------------------------------------
// Commands
// ------------------------------------------------------------

// A command made by the local player. Online it goes to the host instead of being applied.
function net_submit_command(_g, _cmd) {
	var _n = global.net;
	if (_n.mode == NET_MODE.HOST) {
		array_push(_n.pendingCmds, json_parse(json_stringify(_cmd)));
	} else {
		net_send(_n.socket, NET_MSG.CMD, _cmd);
	}
}

// ------------------------------------------------------------
// The tick loop (replaces update_world in the game)
// ------------------------------------------------------------

function net_update_world(_g, _dt) {
	var _n = global.net;
	if (!net_is_online()) {
		update_world(_g.world, _dt);
		return;
	}
	_n.acc = min(_n.acc + _dt, 0.5);
	_n.stalled = false;
	var _ran = 0;
	while ((_n.acc >= TICK_DT) && (_ran < 6)) {
		if (_n.mode == NET_MODE.HOST) {
			while (_n.turnTick < _n.tick + NET_INPUT_DELAY) {
				net_issue_turn();
			}
			// Wait for a player who is too far behind
			if ((_n.tick - net_min_ack()) > NET_MAX_LAG) {
				_n.stalled = true;
				break;
			}
		}
		if (!ds_map_exists(_n.turns, _n.tick)) {
			_n.stalled = true;
			break;
		}
		net_run_tick(_g);
		_n.acc -= TICK_DT;
		_ran++;
	}
}

function net_min_ack() {
	var _n = global.net;
	var _min = _n.tick;
	for (var _i = 0; _i < array_length(_n.clients); _i++) {
		var _c = _n.clients[_i];
		if (_c.joined && !_c.dropped) {
			_min = min(_min, _c.ack);
		}
	}
	return _min;
}

// The host collects the commands received so far into the next turn and sends it out
function net_issue_turn() {
	var _n = global.net;
	var _turn = { tick: _n.turnTick, cmds: _n.pendingCmds, drops: _n.pendingDrops };
	_n.pendingCmds = [];
	_n.pendingDrops = [];
	ds_map_add(_n.turns, _n.turnTick, _turn);
	net_broadcast(NET_MSG.TURN, _turn);
	_n.turnTick++;
}

function net_run_tick(_g) {
	var _n = global.net;
	var _world = _g.world;
	var _turn = ds_map_find_value(_n.turns, _n.tick);

	// A player who left becomes a bot, at the same moment in every game
	for (var _i = 0; _i < array_length(_turn.drops); _i++) {
		var _slot = _turn.drops[_i];
		if ((_slot >= 0) && (_slot < MAX_NATIONS)) {
			_world.nationStates[_slot].slotType = SLOT_TYPE.BOT;
		}
	}
	for (var _i = 0; _i < array_length(_turn.cmds); _i++) {
		var _cmd = _turn.cmds[_i];
		var _result = apply_command(_world, _cmd);
		if ((_cmd.owner == _g.localNation) && (_result != "")) {
			set_toast(_g, _result);
		}
	}
	update_world(_world, TICK_DT);

	ds_map_delete(_n.turns, _n.tick);
	_n.tick++;

	// Players tell the host how far they have got, and everyone compares a checksum now and then
	if ((_n.mode == NET_MODE.CLIENT) && ((_n.tick mod 5) == 0)) {
		net_send(_n.socket, NET_MSG.ACK, { tick: _n.tick });
	}
	if ((_n.tick mod NET_HASH_EVERY) == 0) {
		var _hash = net_state_hash(_world);
		if (_n.mode == NET_MODE.HOST) {
			net_broadcast(NET_MSG.HASH, { tick: _n.tick, hash: _hash });
		} else {
			net_hash_note(_g, _n.tick, _hash, true);
		}
	}
}

// ------------------------------------------------------------
// Catching a game that has drifted apart
// ------------------------------------------------------------

function net_state_hash(_world) {
	var _h = floor(_world.time * 100) mod 1000003;
	for (var _i = 0; _i < array_length(_world.units); _i++) {
		var _u = _world.units[_i];
		if (_u.alive) {
			_h = (_h * 31 + _u.gx * 7 + _u.gy * 13 + floor(_u.hp)) mod 1000003;
		}
	}
	for (var _n = 0; _n < MAX_NATIONS; _n++) {
		var _state = _world.nationStates[_n];
		if (_state.active) {
			_h = (_h * 31 + floor(_state.gold)) mod 1000003;
		}
	}
	return _h;
}

function net_hash_note(_g, _tick, _hash, _mine) {
	var _n = global.net;
	var _key = string(_tick);
	if (!variable_struct_exists(_n.hashes, _key)) {
		variable_struct_set(_n.hashes, _key, { mine: -1, theirs: -1 });
	}
	var _entry = variable_struct_get(_n.hashes, _key);
	if (_mine) {
		_entry.mine = _hash;
	} else {
		_entry.theirs = _hash;
	}
	if ((_entry.mine != -1) && (_entry.theirs != -1)) {
		if ((_entry.mine != _entry.theirs) && !_n.desync) {
			_n.desync = true;
			set_toast(_g, "Out of sync with the host");
			show_debug_message("DESYNC at tick " + string(_tick) + ": mine " + string(_entry.mine) + ", host " + string(_entry.theirs));
		}
		variable_struct_remove(_n.hashes, _key);
	}
}