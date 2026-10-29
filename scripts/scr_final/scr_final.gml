// ============================================================
// scr_final: the final decision vote and the lose / victory banners
// ============================================================

#macro FINAL_GRACE 60
#macro FINAL_BOT_DELAY 3
#macro END_BIG_TIME 3
#macro END_SHRINK_TIME 1.2
#macro END_AUTO_RETURN 30
#macro FINAL_BANNER_H 44

enum FINAL_PHASE {
	NONE,
	VOTING,
	WAR
}

// ------------------------------------------------------------
// The vote (part of the simulation)
// ------------------------------------------------------------

function make_final_vote() {
	return { phase: FINAL_PHASE.NONE, nations: [], votes: array_create(MAX_NATIONS, -1), timer: 0 };
}

function count_final_votes(_f) {
	var _count = 0;
	for (var _i = 0; _i < array_length(_f.nations); _i++) {
		if (_f.votes[_f.nations[_i]] != -1) {
			_count++;
		}
	}
	return _count;
}

// Call from update_world every tick
function update_final_vote(_world, _dt) {
	var _f = _world.finalVote;
	if (_world.winner != NO_ID) {
		return;
	}
	switch (_f.phase) {
		case FINAL_PHASE.NONE:
			var _alive = [];
			for (var _n = 0; _n < MAX_NATIONS; _n++) {
				if (_world.nationStates[_n].active && !_world.nationStates[_n].eliminated) {
					array_push(_alive, _n);
				}
			}
			if (array_length(_alive) == 2) {
				var _treaty = get_treaty_between(_world, _alive[0], _alive[1]);
				if ((_treaty != undefined) && (_treaty.state == 0)) {
					_f.phase = FINAL_PHASE.VOTING;
					_f.nations = _alive;
					_f.votes = array_create(MAX_NATIONS, -1);
					_f.timer = 0;
				}
			}
			break;

		case FINAL_PHASE.VOTING:
			_f.timer += _dt;
			var _a = _f.nations[0];
			var _b = _f.nations[1];

			// A war declaration cancels the vote
			var _t = get_treaty_between(_world, _a, _b);
			if ((_t == undefined) || (_t.state != 0)) {
				_f.phase = FINAL_PHASE.NONE;
				_f.nations = [];
				push_notice(_world, NOTICE_ALL, "The final decision was cancelled");
				break;
			}

			// Bots vote No
			for (var _i = 0; _i < 2; _i++) {
				var _nation = _f.nations[_i];
				if ((_world.nationStates[_nation].slotType == SLOT_TYPE.BOT) && (_f.votes[_nation] == -1) && (_f.timer >= FINAL_BOT_DELAY)) {
					_f.votes[_nation] = 0;
				}
			}

			if (count_final_votes(_f) == 2) {
				if ((_f.votes[_a] == 1) || (_f.votes[_b] == 1)) {
					// One Yes is enough: a grace period, then the treaty ends and the final war starts
					_t.state = 1;
					_t.timer = FINAL_GRACE;
					_t.declarer = (_f.votes[_a] == 1) ? _a : _b;
					_f.phase = FINAL_PHASE.WAR;
					push_notice(_world, NOTICE_ALL, get_owner_name(_a) + " and " + get_owner_name(_b) + ": the final war begins in " + string(FINAL_GRACE) + " seconds!");
				} else {
					// Both said No: the game ends and they share the win
					_world.winner = _a;
					_world.coWinner = _b;
					push_notice(_world, NOTICE_ALL, get_owner_name(_a) + " and " + get_owner_name(_b) + " chose peace and share the world");
				}
			}
			break;
	}
}

// ------------------------------------------------------------
// The vote (screen)
// ------------------------------------------------------------

function final_vote_open(_g) {
	return (_g.world.winner == NO_ID) && (_g.world.finalVote.phase == FINAL_PHASE.VOTING);
}

// The y below the top bar and the docked lose / victory banner
function get_top_banner_bottom(_g) {
	return TOP_H + 6 + ((_g.endKind != 0) ? 40 * _g.endBlend : 0);
}

// Where the notices and the toast start
function get_notice_top(_g) {
	var _y = get_top_banner_bottom(_g) + 6;
	if (final_vote_open(_g)) {
		_y += FINAL_BANNER_H + 6;
	}
	return _y;
}

function add_final_vote_buttons(_g, _list) {
	if (!final_vote_open(_g)) {
		return;
	}
	var _f = _g.world.finalVote;
	if (!id_in_list(_f.nations, _g.localNation) || (_f.votes[_g.localNation] != -1)) {
		return;
	}
	var _w = min(_g.screenW - 24, 820);
	var _x = (_g.screenW - _w) / 2;
	var _y = get_top_banner_bottom(_g);
	var _yes = make_button("Yes", "", UI_ACT.FINAL_VOTE, true, NO_ID, true, "", "Fight for the whole world. A one minute grace period, then war");
	_yes.x = _x + _w - 14 - 84 * 2 - 8;
	_yes.y = _y + 7;
	_yes.w = 84;
	_yes.h = 30;
	_yes.zone = 5;
	_yes.colour = make_colour_rgb(190, 50, 50);
	var _no = make_button("No", "", UI_ACT.FINAL_VOTE, false, NO_ID, true, "", "End the game now. You share the victory");
	_no.x = _x + _w - 14 - 84;
	_no.y = _y + 7;
	_no.w = 84;
	_no.h = 30;
	_no.zone = 5;
	_no.colour = make_colour_rgb(50, 150, 70);
	array_push(_list, _yes);
	array_push(_list, _no);
}

function draw_final_banner(_g, _buttons, _mx, _my) {
	if (!final_vote_open(_g)) {
		return;
	}
	var _f = _g.world.finalVote;
	var _w = min(_g.screenW - 24, 820);
	var _x = (_g.screenW - _w) / 2;
	var _y = get_top_banner_bottom(_g);
	var _votes = count_final_votes(_f);
	var _mine = (_g.localNation != NO_ID) && id_in_list(_f.nations, _g.localNation);
	var _text;
	if (_mine) {
		_text = "FINAL DECISION: Will you rule the world? (" + string(_votes) + "/2)";
		if (_f.votes[_g.localNation] != -1) {
			_text += "    You voted " + ((_f.votes[_g.localNation] == 1) ? "Yes" : "No") + ", waiting for the other nation";
		}
	} else {
		_text = "FINAL DECISION: The last two nations are deciding the fate of the world (" + string(_votes) + "/2)";
	}
	draw_set_colour(c_black);
	draw_set_alpha(0.88);
	draw_rectangle(_x, _y, _x + _w, _y + FINAL_BANNER_H, false);
	draw_set_alpha(1);
	draw_set_colour(make_colour_rgb(230, 190, 60));
	draw_rectangle(_x, _y, _x + _w, _y + FINAL_BANNER_H, true);
	draw_set_colour(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_middle);
	draw_text(_x + 14, _y + FINAL_BANNER_H / 2, _text);
	for (var _i = 0; _i < array_length(_buttons); _i++) {
		if (_buttons[_i].zone == 5) {
			draw_hud_button(_buttons[_i], _mx, _my);
		}
	}
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}

// ------------------------------------------------------------
// Lose and victory banners (screen only)
// ------------------------------------------------------------

function end_screen_reset(_g) {
	_g.endKind = 0;
	_g.endTimer = 0;
	_g.endBlend = 0;
	_g.endAutoTimer = END_AUTO_RETURN;
}

// Call once per step in a game.
// Returns true when the victory timer runs out and the game should return to the menu.
function update_end_screen(_g, _dt) {
	var _world = _g.world;
	var _kind = 0;

	// Determine the outcome.
	// 0 = No game over
	// 1 = Defeat
	// 2 = Victory
	if (_world.winner != NO_ID) {
		_kind = 2;
	} else if ((_g.localNation != NO_ID) && _world.nationStates[_g.localNation].eliminated) {
		_kind = 1;
	}

	// Detect when the game-over state changes.
	if (_kind != _g.endKind) {
		if (_g.endKind == 0) {
			_g.endTimer = 0;
			_g.endBlend = 0;

			// Play the appropriate sound once when the game ends.
			if (_kind == 2) {
				sfx_play("victory");
			} else if (_kind == 1) {
				sfx_play("defeat");
			}
		}

		if (_kind == 2) {
			_g.endAutoTimer = END_AUTO_RETURN;
		}

		_g.endKind = _kind;
	}

	// No game over: nothing else to update.
	if (_kind == 0) {
		return false;
	}

	// Update the game-over animation.
	_g.endTimer += _dt;

	var _t = clamp(
		(_g.endTimer - END_BIG_TIME) / END_SHRINK_TIME,
		0,
		1
	);

	if (global.options.reducedMotion == 1) {
		_t = (_t > 0) ? 1 : 0;
	}

	_g.endBlend = _t * _t * (3 - 2 * _t);

	// Victory automatically returns to the menu after the timer expires.
	if (_kind == 2) {
		_g.endAutoTimer -= _dt;
		return (_g.endAutoTimer <= 0);
	}

	// Defeat does not automatically return to the menu.
	return false;
}

function get_end_text(_g) {
	var _w = _g.world;
	var _local = _g.localNation;
	if (_w.winner != NO_ID) {
		var _mine = (_local != NO_ID) && ((_w.winner == _local) || (_w.coWinner == _local));
		var _title;
		if (_w.coWinner != NO_ID) {
			_title = _mine ? "Shared victory!" : (get_owner_name(_w.winner) + " and " + get_owner_name(_w.coWinner) + " share the world");
		} else {
			_title = _mine ? "Victory!" : (get_owner_name(_w.winner) + " wins");
		}
		return { title: _title, sub: "Returning to the menu in " + string(ceil(max(0, _g.endAutoTimer))) + "s   |   Escape twice to leave now" };
	}
	return { title: "Your nation has fallen", sub: "Escape twice to return to the menu" };
}

// Starts as a big banner across the middle, then shrinks and slides up below the top bar
function draw_game_over(_g) {
	if (_g.endKind == 0) {
		return;
	}
	var _text = get_end_text(_g);
	var _e = _g.endBlend;
	var _cx = _g.screenW / 2;
	var _cy = lerp(_g.screenH / 2, TOP_H + 6 + 17, _e);
	var _h = lerp(80, 34, _e);
	var _w = lerp(_g.screenW, min(_g.screenW - 24, 760), _e);
	draw_set_colour(c_black);
	draw_set_alpha(lerp(0.7, 0.88, _e));
	draw_rectangle(_cx - _w / 2, _cy - _h / 2, _cx + _w / 2, _cy + _h / 2, false);
	if (_e > 0) {
		draw_set_alpha(_e);
		draw_set_colour(c_white);
		draw_rectangle(_cx - _w / 2, _cy - _h / 2, _cx + _w / 2, _cy + _h / 2, true);
	}
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);

	// The big title fades out while the one line version fades in
	draw_set_colour(c_white);
	draw_set_alpha(1 - _e);
	draw_text_transformed(_cx, _cy, _text.title, lerp(3, 1, _e), lerp(3, 1, _e), 0);
	if (_e > 0) {
		draw_set_alpha(_e);
		draw_set_halign(fa_left);
		var _gap = 28;
		var _total = string_width(_text.title) + _gap + string_width(_text.sub);
		var _x = _cx - _total / 2;
		draw_set_colour(c_white);
		draw_text(_x, _cy, _text.title);
		draw_set_colour(c_ltgray);
		draw_text(_x + string_width(_text.title) + _gap, _cy, _text.sub);
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
}