// ============================================================
// scr_iso: isometric projection and shape drawing helpers
// Tile (gx, gy) is centred on its diamond. Tile centres sit on whole numbers.
// ============================================================

function tile_to_world_x(_gx, _gy) {
	return (_gx - _gy) * (TILE_W / 2);
}

function tile_to_world_y(_gx, _gy) {
	return (_gx + _gy) * (TILE_H / 2);
}

// These return fractional tile coordinates, use round() to get the tile under a point
function world_to_tile_gx(_wx, _wy) {
	return (_wx / (TILE_W / 2) + _wy / (TILE_H / 2)) / 2;
}

function world_to_tile_gy(_wx, _wy) {
	return (_wy / (TILE_H / 2) - _wx / (TILE_W / 2)) / 2;
}

// Filled diamond drawn as a triangle fan
function draw_diamond(_cx, _cy, _halfW, _halfH, _colour, _alpha) {
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(_cx, _cy, _colour, _alpha);
	draw_vertex_colour(_cx, _cy - _halfH, _colour, _alpha);
	draw_vertex_colour(_cx + _halfW, _cy, _colour, _alpha);
	draw_vertex_colour(_cx, _cy + _halfH, _colour, _alpha);
	draw_vertex_colour(_cx - _halfW, _cy, _colour, _alpha);
	draw_vertex_colour(_cx, _cy - _halfH, _colour, _alpha);
	draw_primitive_end();
}

// Filled convex quad (used for the sides of raised tiles)
function draw_quad_colour(_x1, _y1, _x2, _y2, _x3, _y3, _x4, _y4, _colour, _alpha) {
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(_x1, _y1, _colour, _alpha);
	draw_vertex_colour(_x2, _y2, _colour, _alpha);
	draw_vertex_colour(_x3, _y3, _colour, _alpha);
	draw_vertex_colour(_x4, _y4, _colour, _alpha);
	draw_primitive_end();
}

function draw_diamond_outline(_cx, _cy, _halfW, _halfH, _colour, _width) {
	draw_line_width_colour(_cx, _cy - _halfH, _cx + _halfW, _cy, _width, _colour, _colour);
	draw_line_width_colour(_cx + _halfW, _cy, _cx, _cy + _halfH, _width, _colour, _colour);
	draw_line_width_colour(_cx, _cy + _halfH, _cx - _halfW, _cy, _width, _colour, _colour);
	draw_line_width_colour(_cx - _halfW, _cy, _cx, _cy - _halfH, _width, _colour, _colour);
}

// ------------------------------------------------------------
// Extra shape helpers (stars, crowns and the ideology radar chart)
// ------------------------------------------------------------

// Five pointed star, point up
function draw_star(_cx, _cy, _r, _colour) {
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(_cx, _cy, _colour, 1);
	for (var _i = 0; _i <= 10; _i++) {
		var _ang = 90 + _i * 36;
		var _rad = ((_i mod 2) == 0) ? _r : _r * 0.42;
		draw_vertex_colour(_cx + lengthdir_x(_rad, _ang), _cy + lengthdir_y(_rad, _ang), _colour, 1);
	}
	draw_primitive_end();
}

// Small three spiked crown, used to mark a capital
function draw_crown(_x, _y, _s, _colour) {
	draw_set_colour(_colour);
	draw_rectangle(_x - 3 * _s, _y - 1 * _s, _x + 3 * _s, _y + 1 * _s, false);
	draw_triangle(_x - 3 * _s, _y - 1 * _s, _x - 1.6 * _s, _y - 1 * _s, _x - 3 * _s, _y - 3.5 * _s, false);
	draw_triangle(_x - 1 * _s, _y - 1 * _s, _x + 1 * _s, _y - 1 * _s, _x, _y - 4 * _s, false);
	draw_triangle(_x + 1.6 * _s, _y - 1 * _s, _x + 3 * _s, _y - 1 * _s, _x + 3 * _s, _y - 3.5 * _s, false);
}

// Filled pentagon radar. _values is an array of 0 to 1 numbers, first one points up
function draw_radar_fill(_cx, _cy, _radius, _values, _colour, _alpha) {
	var _count = array_length(_values);
	draw_primitive_begin(pr_trianglefan);
	draw_vertex_colour(_cx, _cy, _colour, _alpha);
	for (var _i = 0; _i <= _count; _i++) {
		var _v = _values[_i mod _count];
		var _ang = 90 - _i * (360 / _count);
		draw_vertex_colour(_cx + lengthdir_x(_radius * _v, _ang), _cy + lengthdir_y(_radius * _v, _ang), _colour, _alpha);
	}
	draw_primitive_end();
}

// Outline of the radar at a given fraction of the radius (used for the grid rings)
function draw_radar_ring(_cx, _cy, _radius, _count, _colour) {
	for (var _i = 0; _i < _count; _i++) {
		var _a1 = 90 - _i * (360 / _count);
		var _a2 = 90 - (_i + 1) * (360 / _count);
		draw_line_colour(_cx + lengthdir_x(_radius, _a1), _cy + lengthdir_y(_radius, _a1), _cx + lengthdir_x(_radius, _a2), _cy + lengthdir_y(_radius, _a2), _colour, _colour);
	}
}
