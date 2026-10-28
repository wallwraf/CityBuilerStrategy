// ============================================================
// scr_net: multiplayer connection, join codes and the lobby.
//
// The host opens a TCP server on NET_PORT. A join code is the host's public address (IP and port)
// packed into 11 letters and digits. Everything about how players find each other is in this
// script, so if you later move to a relay or matchmaking server only net_host_open, net_join,
// net_host_find_address and the code functions change.
//
// The game itself is synchronised by scr_net_sim (lockstep): everyone runs the same simulation
// and only the player commands travel over the network.
// ============================================================

#macro NET_PORT 6510
#macro NET_VERSION 1
#macro NET_TIMEOUT 10000
#macro NET_CONNECT_TIMEOUT 8000
#macro NET_BEAT 2000
#macro NET_ALPHABET "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

enum NET_MODE {
	OFF,
	HOST,
	CLIENT
}

enum NET_MSG {
	HELLO,
	WELCOME,
	REJECT,
	LOBBY,
	START,
	CMD,
	TURN,
	ACK,
	HASH,
	CANCEL
}

enum LOBBY_SLOT {
	HOST,
	PLAYER,
	AI,
	EMPTY
}

// ------------------------------------------------------------
// Setup and state
// ------------------------------------------------------------

// Call once from the Create event of obj_game
function net_init() {
	global.net = {
		turns: ds_map_create()
	};
	net_reset_state();
}

function net_reset_state() {
	var _n = global.net;
	_n.mode = NET_MODE.OFF;
	_n.server = -1;
	_n.socket = -1;
	_n.clients = [];
	_n.connecting = false;
	_n.connectStart = 0;
	_n.code = "";
	_n.httpId = -1;
	_n.mySlot = 0;
	_n.lobbyPlayers = 1;
	_n.lobbyAi = 1;
	_n.started = false;
	_n.tick = 0;
	_n.turnTick = 0;
	_n.acc = 0;
	_n.pendingCmds = [];
	_n.pendingDrops = [];
	_n.hashes = {};
	_n.desync = false;
	_n.stalled = false;
	_n.lastRecv = current_time;
	_n.lastBeat = current_time;
	ds_map_clear(_n.turns);
}

function net_is_online() {
	return (global.net.mode != NET_MODE.OFF) && global.net.started;
}

// Closes everything. The host tells the players first. Safe to call at any time.
function net_close() {
	var _n = global.net;
	if (_n.mode == NET_MODE.HOST) {
		net_broadcast(NET_MSG.CANCEL, { reason: "The host closed the game" });
		if (_n.server != -1) {
			network_destroy(_n.server);
		}
	} else if (_n.mode == NET_MODE.CLIENT) {
		if (_n.socket != -1) {
			network_destroy(_n.socket);
		}
	}
	net_reset_state();
}

function net_cleanup() {
	net_close();
	ds_map_destroy(global.net.turns);
}

// ------------------------------------------------------------
// Join codes: the host's IP and port as 10 letters and digits plus a check character
// ------------------------------------------------------------

function net_parse_ip(_ip) {
	var _text = string_replace_all(string_replace_all(_ip, " ", ""), chr(10), "");
	var _parts = [];
	repeat (3) {
		var _dot = string_pos(".", _text);
		if (_dot == 0) {
			return undefined;
		}
		array_push(_parts, real(string_digits(string_copy(_text, 1, _dot - 1))));
		_text = string_delete(_text, 1, _dot);
	}
	if (string_digits(_text) == "") {
		return undefined;
	}
	array_push(_parts, real(string_digits(_text)));
	for (var _i = 0; _i < 4; _i++) {
		if (_parts[_i] > 255) {
			return undefined;
		}
	}
	return _parts;
}

function net_code_encode(_ip, _port) {
	var _p = net_parse_ip(_ip);
	if (_p == undefined) {
		return "";
	}
	var _value = (((_p[0] * 256 + _p[1]) * 256 + _p[2]) * 256 + _p[3]) * 65536 + _port;
	var _text = "";
	var _sum = 0;
	for (var _i = 9; _i >= 0; _i--) {
		var _digit = floor(_value / power(32, _i)) mod 32;
		_text += string_char_at(NET_ALPHABET, _digit + 1);
		_sum += _digit * (10 - _i);
	}
	return _text + string_char_at(NET_ALPHABET, (_sum mod 32) + 1);
}

// Upper case, with everything that is not a code character removed
function net_code_clean(_text) {
	var _upper = string_upper(_text);
	var _out = "";
	for (var _i = 1; _i <= string_length(_upper); _i++) {
		var _c = string_char_at(_upper, _i);
		if (string_pos(_c, NET_ALPHABET) > 0) {
			_out += _c;
		}
	}
	return _out;
}

// "ABCD-EFGH-JKM" (also works on a half typed code)
function net_code_format(_text) {
	var _clean = net_code_clean(_text);
	var _out = "";
	for (var _i = 1; _i <= string_length(_clean); _i++) {
		if ((_i == 5) || (_i == 9)) {
			_out += "-";
		}
		_out += string_char_at(_clean, _i);
	}
	return _out;
}

// Gives { ip, port }, or undefined when the code is not valid. The code TEST joins this computer
// (handy for testing with two copies of the game).
function net_code_decode(_text) {
	var _clean = net_code_clean(_text);
	if (_clean == "TEST") {
		return { ip: "127.0.0.1", port: NET_PORT };
	}
	if (string_length(_clean) != 11) {
		return undefined;
	}
	var _value = 0;
	var _sum = 0;
	for (var _i = 0; _i < 10; _i++) {
		var _digit = string_pos(string_char_at(_clean, _i + 1), NET_ALPHABET) - 1;
		_value = _value * 32 + _digit;
		_sum += _digit * (_i + 1);
	}
	var _check = string_pos(string_char_at(_clean, 11), NET_ALPHABET) - 1;
	if ((_sum mod 32) != _check) {
		return undefined;
	}
	var _port = _value mod 65536;
	var _rest = floor(_value / 65536);
	var _d = _rest mod 256;
	_rest = floor(_rest / 256);
	var _c = _rest mod 256;
	_rest = floor(_rest / 256);
	var _b = _rest mod 256;
	var _a = floor(_rest / 256);
	if ((_port < 1024) || (_a > 255)) {
		return undefined;
	}
	return { ip: string(_a) + "." + string(_b) + "." + string(_c) + "." + string(_d), port: _port };
}

function net_code_valid(_text) {
	return (net_code_decode(_text) != undefined);
}

// ------------------------------------------------------------
// Sending and receiving
// ------------------------------------------------------------

function net_send(_socket, _type, _data) {
	var _buffer = buffer_create(256, buffer_grow, 1);
	buffer_write(_buffer, buffer_u8, _type);
	buffer_write(_buffer, buffer_string, json_stringify(_data));
	network_send_packet(_socket, _buffer, buffer_tell(_buffer));
	buffer_delete(_buffer);
}

// To every player who has joined (host only)
function net_broadcast(_type, _data) {
	var _n = global.net;
	for (var _i = 0; _i < array_length(_n.clients); _i++) {
		var _c = _n.clients[_i];
		if (_c.joined && !_c.dropped) {
			net_send(_c.socket, _type, _data);
		}
	}
}

function net_find_client(_socket) {
	var _n = global.net;
	for (var _i = 0; _i < array_length(_n.clients); _i++) {
		if (_n.clients[_i].socket == _socket) {
			return _i;
		}
	}
	return -1;
}

// ------------------------------------------------------------
// Hosting
// ------------------------------------------------------------

// Opens the lobby. Returns false when the port could not be opened.
function net_host_open(_g) {
	net_close();
	var _server = network_create_server(network_socket_tcp, NET_PORT, 7);
	if (_server < 0) {
		return false;
	}
	var _n = global.net;
	_n.mode = NET_MODE.HOST;
	_n.server = _server;
	_n.lobbyPlayers = 1;
	_n.lobbyAi = 1;
	_n.mySlot = 0;
	net_host_find_address();
	return true;
}

// Asks a website for this computer's public address, then builds the join code (see net_http_event)
function net_host_find_address() {
	global.net.code = "";
	global.net.httpId = http_get("https://api.ipify.org");
}

// Call from the Async - HTTP event
function net_http_event(_g) {
	var _n = global.net;
	if (async_load[? "id"] != _n.httpId) {
		return;
	}
	if (async_load[? "status"] == 1) {
		return;
	}
	_n.httpId = -1;
	var _code = "";
	if (async_load[? "status"] == 0) {
		_code = net_code_encode(async_load[? "result"], NET_PORT);
	}
	if (_code == "") {
		_code = net_code_encode("127.0.0.1", NET_PORT);
		set_toast(_g, "Could not find your public address, so this code only works on this computer");
	}
	_n.code = _code;
}

// Slot numbers follow join order: the host is 0, then the players
function net_refresh_slots() {
	var _n = global.net;
	var _slot = 1;
	for (var _i = 0; _i < array_length(_n.clients); _i++) {
		var _c = _n.clients[_i];
		if (_c.joined && !_c.dropped) {
			_c.slot = _slot;
			_slot++;
		}
	}
	_n.lobbyPlayers = _slot;
	_n.lobbyAi = clamp(_n.lobbyAi, 0, MAX_NATIONS - _n.lobbyPlayers);
}

function net_broadcast_lobby() {
	var _n = global.net;
	for (var _i = 0; _i < array_length(_n.clients); _i++) {
		var _c = _n.clients[_i];
		if (_c.joined && !_c.dropped) {
			net_send(_c.socket, NET_MSG.LOBBY, { players: _n.lobbyPlayers, ai: _n.lobbyAi, you: _c.slot });
		}
	}
	_n.lastBeat = current_time;
}

// What a lobby slot holds: sorted Host, Players, AI, Empty
function net_slot_kind(_i) {
	var _n = global.net;
	if (_i == 0) {
		return LOBBY_SLOT.HOST;
	}
	if (_i < _n.lobbyPlayers) {
		return LOBBY_SLOT.PLAYER;
	}
	if (_i < _n.lobbyPlayers + _n.lobbyAi) {
		return LOBBY_SLOT.AI;
	}
	return LOBBY_SLOT.EMPTY;
}

// The host clicks an AI slot to empty it, or an empty slot to fill it with AI
function net_lobby_toggle(_slot) {
	var _n = global.net;
	if (_n.mode != NET_MODE.HOST) {
		return;
	}
	var _kind = net_slot_kind(_slot);
	if (_kind == LOBBY_SLOT.AI) {
		_n.lobbyAi--;
	} else if (_kind == LOBBY_SLOT.EMPTY) {
		_n.lobbyAi++;
	} else {
		return;
	}
	net_broadcast_lobby();
}

function net_drop_client(_g, _index) {
	var _n = global.net;
	var _c = _n.clients[_index];
	if (_c.dropped) {
		return;
	}
	network_destroy(_c.socket);
	if (_n.started) {
		// In a game the nation carries on as a bot
		_c.dropped = true;
		array_push(_n.pendingDrops, _c.slot);
		set_toast(_g, "Player " + string(_c.slot + 1) + " left, a bot takes over");
	} else {
		array_delete(_n.clients, _index, 1);
		net_refresh_slots();
		net_broadcast_lobby();
	}
}

// ------------------------------------------------------------
// Joining
// ------------------------------------------------------------

function net_join(_g, _text) {
	var _target = net_code_decode(_text);
	if (_target == undefined) {
		set_toast(_g, "That code is not valid");
		return;
	}
	net_close();
	var _n = global.net;
	_n.mode = NET_MODE.CLIENT;
	_n.code = net_code_clean(_text);
	_n.socket = network_create_socket(network_socket_tcp);
	network_set_config(network_config_connect_timeout, NET_CONNECT_TIMEOUT);
	if (network_connect_async(_n.socket, _target.ip, _target.port) < 0) {
		net_close();
		set_toast(_g, "Could not connect to that code");
		return;
	}
	_n.connecting = true;
	_n.connectStart = current_time;
	_n.lastRecv = current_time;
}

// ------------------------------------------------------------
// Messages
// ------------------------------------------------------------

// Call from the Async - Networking event
function net_async_event(_g) {
	var _n = global.net;
	var _type = async_load[? "type"];
	switch (_type) {
		case network_type_connect:
			if (_n.mode == NET_MODE.HOST) {
				array_push(_n.clients, { socket: async_load[? "socket"], joined: false, dropped: false, slot: -1, ack: 0, lastRecv: current_time });
			}
			break;

		case network_type_disconnect:
			if (_n.mode == NET_MODE.HOST) {
				var _index = net_find_client(async_load[? "socket"]);
				if (_index != -1) {
					net_drop_client(_g, _index);
				}
			}
			break;

		case network_type_non_blocking_connect:
			if (_n.mode == NET_MODE.CLIENT) {
				if (async_load[? "succeeded"] == 1) {
					_n.lastRecv = current_time;
					net_send(_n.socket, NET_MSG.HELLO, { version: NET_VERSION });
				} else {
					net_close();
					set_toast(_g, "Could not connect to that code");
				}
			}
			break;

		case network_type_data:
			var _buffer = async_load[? "buffer"];
			buffer_seek(_buffer, buffer_seek_start, 0);
			try {
				var _msgType = buffer_read(_buffer, buffer_u8);
				var _data = json_parse(buffer_read(_buffer, buffer_string));
				if (_n.mode == NET_MODE.HOST) {
					net_host_message(_g, async_load[? "id"], _msgType, _data);
				} else if (_n.mode == NET_MODE.CLIENT) {
					net_client_message(_g, _msgType, _data);
				}
			} catch (_error) {
				show_debug_message("Network message error: " + string(_error));
			}
			break;
	}
}

function net_host_message(_g, _socket, _type, _data) {
	var _n = global.net;
	var _index = net_find_client(_socket);
	if (_index == -1) {
		return;
	}
	var _c = _n.clients[_index];
	_c.lastRecv = current_time;
	switch (_type) {
		case NET_MSG.HELLO:
			if (_n.started) {
				net_send(_socket, NET_MSG.REJECT, { reason: "That game has already started" });
				net_drop_client(_g, _index);
			} else if (_data.version != NET_VERSION) {
				net_send(_socket, NET_MSG.REJECT, { reason: "Different game version" });
				net_drop_client(_g, _index);
			} else if (_n.lobbyPlayers >= MAX_NATIONS) {
				net_send(_socket, NET_MSG.REJECT, { reason: "The lobby is full" });
				net_drop_client(_g, _index);
			} else {
				_c.joined = true;
				net_refresh_slots();
				net_send(_socket, NET_MSG.WELCOME, { slot: _c.slot });
				net_broadcast_lobby();
			}
			break;

		case NET_MSG.CMD:
			// The nation comes from the connection, so nobody can send commands for someone else
			if (_n.started && _c.joined && !_c.dropped) {
				_data.owner = _c.slot;
				array_push(_n.pendingCmds, _data);
			}
			break;

		case NET_MSG.ACK:
			if (_data.tick >= 0) {
				_c.ack = _data.tick;
			}
			break;
	}
}

function net_client_message(_g, _type, _data) {
	var _n = global.net;
	_n.lastRecv = current_time;
	switch (_type) {
		case NET_MSG.WELCOME:
			_n.connecting = false;
			_n.mySlot = _data.slot;
			_g.menuEditing = false;
			menu_open_page(_g, MENU_PAGE.LOBBY);
			break;

		case NET_MSG.REJECT:
			net_close();
			set_toast(_g, _data.reason);
			break;

		case NET_MSG.LOBBY:
			_n.lobbyPlayers = _data.players;
			_n.lobbyAi = _data.ai;
			_n.mySlot = _data.you;
			break;

		case NET_MSG.START:
			net_begin_game(_g, _data.settings, _data.slot);
			break;

		case NET_MSG.TURN:
			if (!ds_map_exists(_n.turns, _data.tick)) {
				ds_map_add(_n.turns, _data.tick, _data);
			}
			break;

		case NET_MSG.HASH:
			net_hash_note(_g, _data.tick, _data.hash, false);
			break;

		case NET_MSG.CANCEL:
			net_remote_closed(_g, _data.reason);
			break;
	}
}

// The other side is gone: back to the menu with a message
function net_remote_closed(_g, _reason) {
	var _playing = (global.net.started && (_g.gameState == GAME_STATE.PLAYING));
	net_close();
	set_toast(_g, _reason);
	if (_playing) {
		menu_return(_g);
	} else {
		menu_leave_lobby(_g);
	}
}

// Once per step, in the menu and in a game: heartbeats and time outs
function net_step(_g) {
	var _n = global.net;
	if (_n.mode == NET_MODE.CLIENT) {
		if (_n.connecting) {
			if ((current_time - _n.connectStart) > NET_CONNECT_TIMEOUT) {
				net_close();
				set_toast(_g, "Could not connect to that code");
			}
			return;
		}
		if ((current_time - _n.lastRecv) > NET_TIMEOUT) {
			net_remote_closed(_g, "Lost connection to the host");
			return;
		}
		if (!_n.started && ((current_time - _n.lastBeat) > NET_BEAT)) {
			_n.lastBeat = current_time;
			net_send(_n.socket, NET_MSG.ACK, { tick: -1 });
		}
	} else if (_n.mode == NET_MODE.HOST) {
		for (var _i = array_length(_n.clients) - 1; _i >= 0; _i--) {
			if (!_n.clients[_i].dropped && ((current_time - _n.clients[_i].lastRecv) > NET_TIMEOUT)) {
				net_drop_client(_g, _i);
			}
		}
		if (!_n.started && ((current_time - _n.lastBeat) > NET_BEAT)) {
			net_broadcast_lobby();
		}
	}
}

// ------------------------------------------------------------
// Starting
// ------------------------------------------------------------

// The host presses Start: everyone gets the same settings and their own nation
function net_host_launch(_g) {
	var _n = global.net;
	if ((_n.mode != NET_MODE.HOST) || (_n.lobbyPlayers + _n.lobbyAi < 2)) {
		return;
	}
	// Anyone who connected but never said hello is let go
	for (var _i = array_length(_n.clients) - 1; _i >= 0; _i--) {
		if (!_n.clients[_i].joined) {
			network_destroy(_n.clients[_i].socket);
			array_delete(_n.clients, _i, 1);
		}
	}
	net_refresh_slots();
	var _settings = menu_make_settings(_g);
	_settings.nationCount = _n.lobbyPlayers + _n.lobbyAi;
	_settings.botCount = _n.lobbyAi;
	_settings.vacantCount = 0;
	for (var _i = 0; _i < array_length(_n.clients); _i++) {
		net_send(_n.clients[_i].socket, NET_MSG.START, { settings: _settings, slot: _n.clients[_i].slot });
	}
	net_begin_game(_g, _settings, 0);
}

// Everyone (host and players) builds the same world from the same settings
function net_begin_game(_g, _settings, _slot) {
	var _n = global.net;
	_g.settings = _settings;
	_n.started = true;
	_n.mySlot = _slot;
	_n.tick = 0;
	_n.turnTick = 0;
	_n.acc = 0;
	_n.pendingCmds = [];
	_n.pendingDrops = [];
	_n.hashes = {};
	_n.desync = false;
	ds_map_clear(_n.turns);
	menu_begin_world(_g, _slot);
}