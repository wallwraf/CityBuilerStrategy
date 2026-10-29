// The window the tree scrolls inside (below the title and the research point line)
function get_research_view(_g) {
	var _o = get_overlay_rect(_g);
	return { x: _o.x + 8, y: _o.y + 76, w: _o.w - 16, h: _o.h - 84 };
}

function clamp_research_pan(_g) {
	var _view = get_research_view(_g);
	var _layout = global.researchLayout;
	var _maxX = max(0, _layout.width - _view.w);
	var _maxY = max(0, _layout.height - _view.h);
	// The first time the tree is shown, start centred
	if (!_g.researchPanPlaced) {
		_g.researchPanX = _maxX / 2;
		_g.researchPanPlaced = true;
	}
	_g.researchPanX = clamp(_g.researchPanX, 0, _maxX);
	_g.researchPanY = clamp(_g.researchPanY, 0, _maxY);
}

// Where a research node is on screen right now (pan included)
function get_research_node_rect(_g, _r) {
	var _def = global.researchDefs[_r];
	var _view = get_research_view(_g);
	var _layout = global.researchLayout;
	return {
		x: _view.x - _g.researchPanX + _layout.bandX[_def.branch] + _def.col * RESEARCH_COL_W,
		y: _view.y - _g.researchPanY + RESEARCH_FIRST_ROW_Y + (_def.row - 1) * RESEARCH_ROW_H,
		w: RESEARCH_NODE_W,
		h: RESEARCH_NODE_H
	};
}

// Wheel scrolls up and down (hold Shift to go sideways). Left or middle drag on empty space pans.
// Call this every step from update_input, right before the left mouse press handling.
function update_research_pan(_g, _mx, _my) {
	if (_g.panel != PANEL.RESEARCH) {
		_g.researchDrag = false;
		return;
	}
	var _view = get_research_view(_g);
	var _inView = point_in_rectangle(_mx, _my, _view.x, _view.y, _view.x + _view.w, _view.y + _view.h);

	var _wheel = mouse_wheel_up() - mouse_wheel_down();
	if (_inView && (_wheel != 0)) {
		if (keyboard_check(vk_shift)) {
			_g.researchPanX -= _wheel * 90;
		} else {
			_g.researchPanY -= _wheel * 90;
		}
	}

	var _startDrag = mouse_check_button_pressed(mb_middle) || (mouse_check_button_pressed(mb_left) && (get_hud_button_at(_g, _mx, _my) == undefined));
	if (_inView && _startDrag) {
		_g.researchDrag = true;
		_g.researchDragMx = _mx;
		_g.researchDragMy = _my;
	}
	if (_g.researchDrag) {
		if (mouse_check_button(mb_left) || mouse_check_button(mb_middle)) {
			_g.researchPanX -= (_mx - _g.researchDragMx);
			_g.researchPanY -= (_my - _g.researchDragMy);
			_g.researchDragMx = _mx;
			_g.researchDragMy = _my;
		} else {
			_g.researchDrag = false;
		}
	}
	clamp_research_pan(_g);
}

function draw_research_tree(_g, _o) {
	var _local = _g.localNation;
	var _state = _g.world.nationStates[_local];
	var _dim = make_colour_rgb(70, 75, 90);
	var _layout = global.researchLayout;
	var _view = get_research_view(_g);
	clamp_research_pan(_g);

	draw_set_halign(fa_left);
	draw_set_valign(fa_top);
	draw_set_colour(c_aqua);
	draw_text(_o.x + 20, _o.y + 44, "Research points: " + string(floor(_state.rp)) + "  (+" + string_format(get_rp_rate(_g.world, _local), 1, 1) + "/s)");
	draw_set_halign(fa_right);
	draw_set_colour(c_gray);
	draw_text(_o.x + _o.w - 20, _o.y + 44, "Drag or scroll to look around   (Shift + wheel: sideways)");
	draw_set_halign(fa_left);

	// Everything below is clipped to the view
	var _oldScissor = gpu_get_scissor();
	gpu_set_scissor(_view.x, _view.y, _view.w, _view.h);

	var _ox = _view.x - _g.researchPanX;
	var _oy = _view.y - _g.researchPanY;

	// The City Hall is the root and is always researched
	var _rootW = 150;
	var _rootH = 44;
	var _rootX = _ox + _layout.width / 2;
	var _rootY = _oy + 20;
	var _gold = make_colour_rgb(255, 210, 60);
	var _headerY = _oy + 100;

	for (var _br = 0; _br < BRANCH.COUNT; _br++) {
		var _cx = _ox + _layout.bandX[_br] + _layout.bandW[_br] / 2;
		var _hw = _layout.bandW[_br] / 2 - 6;
		var _bc = get_branch_colour(_br);

		// Root to branch header
		draw_tree_link(_rootX, _rootY + _rootH, _cx, _headerY, _bc, 3);

		draw_set_colour(merge_colour(_bc, c_black, 0.45));
		draw_rectangle(_cx - _hw, _headerY, _cx + _hw, _headerY + 28, false);
		draw_set_colour(_bc);
		draw_rectangle(_cx - _hw, _headerY, _cx + _hw, _headerY + 28, true);
		draw_set_halign(fa_center);
		draw_set_valign(fa_middle);
		draw_set_colour(c_white);
		draw_text(_cx, _headerY + 14, get_branch_name(_br));
	}

	// Links: nodes without a prerequisite hang off their branch header
	for (var _r = 0; _r < RESEARCH.COUNT; _r++) {
		var _def = global.researchDefs[_r];
		var _rect = get_research_node_rect(_g, _r);
		var _bcol = get_branch_colour(_def.branch);
		var _nodeX = _rect.x + _rect.w / 2;
		if (_def.prereq == NO_ID) {
			var _hx = _ox + _layout.bandX[_def.branch] + _layout.bandW[_def.branch] / 2;
			draw_tree_link(_hx, _headerY + 28, _nodeX, _rect.y, _bcol, 2);
		} else {
			var _pr = get_research_node_rect(_g, _def.prereq);
			var _linkCol = _state.researched[_def.prereq] ? _bcol : _dim;
			draw_tree_link(_pr.x + _pr.w / 2, _pr.y + _pr.h, _nodeX, _rect.y, _linkCol, 2);
		}
		if (_def.prereq2 != NO_ID) {
			var _pr2 = get_research_node_rect(_g, _def.prereq2);
			var _linkCol2 = _state.researched[_def.prereq2] ? get_branch_colour(global.researchDefs[_def.prereq2].branch) : _dim;
			draw_tree_link(_pr2.x + _pr2.w / 2, _pr2.y + _pr2.h, _nodeX + 10, _rect.y, _linkCol2, 2);
		}
	}

	// Root node on top of the links
	draw_set_colour(merge_colour(_gold, c_black, 0.6));
	draw_rectangle(_rootX - _rootW / 2, _rootY, _rootX + _rootW / 2, _rootY + _rootH, false);
	draw_set_colour(_gold);
	draw_rectangle(_rootX - _rootW / 2, _rootY, _rootX + _rootW / 2, _rootY + _rootH, true);
	draw_set_halign(fa_center);
	draw_set_valign(fa_middle);
	draw_set_colour(c_white);
	draw_text(_rootX, _rootY + 14, "City Hall");
	draw_set_colour(_gold);
	draw_text(_rootX, _rootY + 32, "Researched");
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);

	// The research nodes are drawn by draw_overlay while this clip is still active
	_g.researchScissor = _oldScissor;
}

function end_research_clip(_g) {
	var _s = _g.researchScissor;
	gpu_set_scissor(_s.x, _s.y, _s.w, _s.h);
	var _view = get_research_view(_g);
	var _layout = global.researchLayout;

	// Scroll bars
	draw_set_colour(make_colour_rgb(60, 66, 84));
	if (_layout.width > _view.w) {
		var _bw = _view.w * (_view.w / _layout.width);
		var _bx = _view.x + (_view.w - _bw) * (_g.researchPanX / max(1, _layout.width - _view.w));
		draw_rectangle(_bx, _view.y + _view.h - 5, _bx + _bw, _view.y + _view.h - 2, false);
	}
	if (_layout.height > _view.h) {
		var _bh = _view.h * (_view.h / _layout.height);
		var _by = _view.y + (_view.h - _bh) * (_g.researchPanY / max(1, _layout.height - _view.h));
		draw_rectangle(_view.x + _view.w - 5, _by, _view.x + _view.w - 2, _by + _bh, false);
	}
	draw_set_colour(c_white);
}

// Replaces draw_overlay: same as before, but the research nodes are clipped to the scrolling view
function draw_overlay(_g, _buttons, _mx, _my) {
	var _o = get_overlay_rect(_g);
	var _local = _g.localNation;

	// Dim everything under the top bar
	draw_set_colour(c_black);
	draw_set_alpha(0.6);
	draw_rectangle(0, TOP_H, _g.screenW, _g.screenH, false);
	draw_set_alpha(1);
	draw_set_colour(make_colour_rgb(18, 24, 38));
	draw_rectangle(_o.x, _o.y, _o.x + _o.w, _o.y + _o.h, false);
	draw_set_colour(c_white);
	draw_rectangle(_o.x, _o.y, _o.x + _o.w, _o.y + _o.h, true);
	draw_set_halign(fa_left);
	draw_set_valign(fa_top);

	var _titles = ["", "", "Research Tree", "Diplomacy", "Ideology"];
	draw_text_transformed(_o.x + 20, _o.y + 12, _titles[_g.panel], 1.4, 1.4, 0);

	var _clipped = false;
	if (_local != NO_ID) {
		if (_g.panel == PANEL.RESEARCH) {
			draw_research_tree(_g, _o);
			_clipped = true;
		} else if (_g.panel == PANEL.DIPLOMACY) {
			draw_set_colour(c_ltgray);
			draw_text_ext(_o.x + 20, _o.y + _o.h - 56, "Build an Embassy, select it and pick a nation to send an envoy to their capital. Declaring war cannot be refused, and the treaty ends 2 minutes later.", 16, _o.w - 40);
			draw_set_colour(c_white);
		} else if (_g.panel == PANEL.IDEOLOGY) {
			draw_ideology_panel(_g, _o);
		}
	}

	// Research nodes first (still clipped), then the rest
	for (var _i = 0; _i < array_length(_buttons); _i++) {
		var _b = _buttons[_i];
		if ((_b.zone == 4) && (_b.branch != NO_ID)) {
			draw_research_node(_b, _mx, _my);
		}
	}
	if (_clipped) {
		end_research_clip(_g);
	}
	for (var _k = 0; _k < array_length(_buttons); _k++) {
		var _other = _buttons[_k];
		if ((_other.zone == 4) && (_other.branch == NO_ID)) {
			draw_hud_button(_other, _mx, _my);
		}
	}
}