// ============================================================
// scr_ground: the whole ground is one shader draw.
// Every tile becomes a number in a small map texture (R = material, G = path strength).
// The shader looks at the four tiles around each pixel, so edges, corners and coasts come out by themselves.
// Materials, in layer order: 0 sand, 1 dirt, 2 grass, 3 forest, 4 snow, 5 water. Higher layers overhang lower ones.
// ============================================================

#macro MOUNTAIN_LIFT_BASE 8
#macro MOUNTAIN_LIFT_STEP 3
#macro MOUNTAIN_MAX_LEVEL 4

// How high a tile is raised (0 for anything that is not a mountain)
function get_tile_lift(_gx, _gy) {
	if (!variable_global_exists("mountainLift") || (_gx < 0) || (_gy < 0) || (_gx >= ds_grid_width(global.mountainLift)) || (_gy >= ds_grid_height(global.mountainLift))) {
		return 0;
	}
	return ds_grid_get(global.mountainLift, _gx, _gy);
}

function mountain_vertex(_vb, _x, _y, _down, _face, _level) {
	vertex_position_3d(_vb, _x, _y, 0);
	vertex_colour(_vb, make_colour_rgb(0, _down * 255, _face * 255), _level / MOUNTAIN_MAX_LEVEL);
}

// Works out every mountain's height from how deep inside its range it is, and builds the geometry once
function ground_build_mountains(_world) {
	var _w = _world.mapW;
	var _h = _world.mapH;
	if (variable_global_exists("mountainVB")) {
		vertex_delete_buffer(global.mountainVB);
		ds_grid_destroy(global.mountainLift);
	}
	if (!variable_global_exists("mountainFormat")) {
		vertex_format_begin();
		vertex_format_add_position_3d();
		vertex_format_add_colour();
		global.mountainFormat = vertex_format_end();
	}

	// Distance from the edge of the range (1 = on the edge)
	var _depth = ds_grid_create(_w, _h);
	var _queue = [];
	var _dxs = [1, -1, 0, 0];
	var _dys = [0, 0, 1, -1];
	for (var _y = 0; _y < _h; _y++) {
		for (var _x = 0; _x < _w; _x++) {
			ds_grid_set(_depth, _x, _y, (ds_grid_get(_world.biome, _x, _y) == BIOME.MOUNTAIN) ? -1 : 0);
		}
	}
	for (var _y2 = 0; _y2 < _h; _y2++) {
		for (var _x2 = 0; _x2 < _w; _x2++) {
			if (ds_grid_get(_depth, _x2, _y2) != -1) {
				continue;
			}
			for (var _d = 0; _d < 4; _d++) {
				var _nx = _x2 + _dxs[_d];
				var _ny = _y2 + _dys[_d];
				if (!tile_in_bounds(_world, _nx, _ny) || (ds_grid_get(_depth, _nx, _ny) == 0)) {
					ds_grid_set(_depth, _x2, _y2, 1);
					array_push(_queue, [_x2, _y2]);
					break;
				}
			}
		}
	}
	var _head = 0;
	while (_head < array_length(_queue)) {
		var _t = _queue[_head];
		_head++;
		var _td = ds_grid_get(_depth, _t[0], _t[1]);
		for (var _e = 0; _e < 4; _e++) {
			var _ex = _t[0] + _dxs[_e];
			var _ey = _t[1] + _dys[_e];
			if (tile_in_bounds(_world, _ex, _ey) && (ds_grid_get(_depth, _ex, _ey) == -1)) {
				ds_grid_set(_depth, _ex, _ey, _td + 1);
				array_push(_queue, [_ex, _ey]);
			}
		}
	}

	// Geometry, back to front
	global.mountainLift = ds_grid_create(_w, _h);
	ds_grid_clear(global.mountainLift, 0);
	global.mountainVB = vertex_create_buffer();
	var _vb = global.mountainVB;
	var _hw = TILE_W / 2;
	var _hh = TILE_H / 2;
	vertex_begin(_vb, global.mountainFormat);
	for (var _gy = 0; _gy < _h; _gy++) {
		for (var _gx = 0; _gx < _w; _gx++) {
			var _dd = ds_grid_get(_depth, _gx, _gy);
			if (_dd <= 0) {
				continue;
			}
			// A few random bumps so ranges are not perfectly smooth
			var _nudge = ((abs((_gx * 73856093) ^ (_gy * 19349663)) mod 6) == 0) ? 1 : 0;
			var _level = clamp(_dd + _nudge, 1, MOUNTAIN_MAX_LEVEL);
			var _lift = MOUNTAIN_LIFT_BASE + MOUNTAIN_LIFT_STEP * (_level - 1);
			ds_grid_set(global.mountainLift, _gx, _gy, _lift);
			var _cx = tile_to_world_x(_gx, _gy);
			var _cy = tile_to_world_y(_gx, _gy);

			// Left face (two triangles)
			mountain_vertex(_vb, _cx - _hw, _cy - _lift, 0, 0.5, _level);
			mountain_vertex(_vb, _cx, _cy - _lift + _hh, 0, 0.5, _level);
			mountain_vertex(_vb, _cx, _cy + _hh, 1, 0.5, _level);
			mountain_vertex(_vb, _cx - _hw, _cy - _lift, 0, 0.5, _level);
			mountain_vertex(_vb, _cx, _cy + _hh, 1, 0.5, _level);
			mountain_vertex(_vb, _cx - _hw, _cy, 1, 0.5, _level);
			// Right face
			mountain_vertex(_vb, _cx, _cy - _lift + _hh, 0, 1, _level);
			mountain_vertex(_vb, _cx + _hw, _cy - _lift, 0, 1, _level);
			mountain_vertex(_vb, _cx + _hw, _cy, 1, 1, _level);
			mountain_vertex(_vb, _cx, _cy - _lift + _hh, 0, 1, _level);
			mountain_vertex(_vb, _cx + _hw, _cy, 1, 1, _level);
			mountain_vertex(_vb, _cx, _cy + _hh, 1, 1, _level);
			// Top
			mountain_vertex(_vb, _cx, _cy - _lift - _hh, 0, 0, _level);
			mountain_vertex(_vb, _cx + _hw, _cy - _lift, 0, 0, _level);
			mountain_vertex(_vb, _cx, _cy - _lift + _hh, 0, 0, _level);
			mountain_vertex(_vb, _cx, _cy - _lift - _hh, 0, 0, _level);
			mountain_vertex(_vb, _cx, _cy - _lift + _hh, 0, 0, _level);
			mountain_vertex(_vb, _cx - _hw, _cy - _lift, 0, 0, _level);
		}
	}
	vertex_end(_vb);
	vertex_freeze(_vb);
	ds_grid_destroy(_depth);
	global.mountainWorld = _world;
}

// All mountains in one call
function draw_mountains(_world) {
	if (!variable_global_exists("mountainWorld") || (global.mountainWorld != _world)) {
		ground_build_mountains(_world);
	}
	shader_set(sh_rock);
	vertex_submit(global.mountainVB, pr_trianglelist, -1);
	shader_reset();
}

function get_ground_material(_biome) {
	switch (_biome) {
		case BIOME.DESERT: return 0;
		case BIOME.GRASSLAND: return 2;
		case BIOME.FOREST: return 3;
		case BIOME.SNOW: return 4;
		case BIOME.WATER: return 5;
	}
	// Mountains: dirt around the raised block
	return 1;
}

function ground_ensure_globals() {
	if (variable_global_exists("groundReady")) {
		return;
	}
	global.groundReady = true;
	global.groundSurf = -1;
	global.groundWorld = undefined;
	global.groundPathTotal = -1;
	global.groundDirty = true;
	global.groundMountains = [];
	global.useGroundShader = true;
	global.groundSampler = shader_get_sampler_index(sh_ground, "u_map");
	global.groundUMapSize = shader_get_uniform(sh_ground, "u_mapSize");
	global.groundUHalfTile = shader_get_uniform(sh_ground, "u_halfTile");
	global.groundUTime = shader_get_uniform(sh_ground, "u_time");
	global.groundUMargin = shader_get_uniform(sh_ground, "u_margin");
}

// Called whenever paths change (the path total is also checked, so a missed call only costs a frame)
function ground_mark_dirty() {
	if (variable_global_exists("groundReady")) {
		global.groundDirty = true;
	}
}

// Builds the map texture (and the list of mountain tiles) from the world
function ground_rebuild(_world) {
	var _w = _world.mapW;
	var _h = _world.mapH;
	if (surface_exists(global.groundSurf) && ((surface_get_width(global.groundSurf) != _w) || (surface_get_height(global.groundSurf) != _h))) {
		surface_free(global.groundSurf);
	}
	if (!surface_exists(global.groundSurf)) {
		global.groundSurf = surface_create(_w, _h);
	}

	// Path strength per tile: 255 on a path, 128 on the two tiles that bridge a diagonal link
	var _path = array_create(_w * _h, 0);
	for (var _gy = 0; _gy < _h; _gy++) {
		for (var _gx = 0; _gx < _w; _gx++) {
			if (ds_grid_get(_world.pathGrid, _gx, _gy) != NO_ID) {
				_path[_gy * _w + _gx] = 255;
			}
		}
	}
	for (var _gy2 = 0; _gy2 < _h; _gy2++) {
		for (var _gx2 = 0; _gx2 < _w; _gx2++) {
			if (ds_grid_get(_world.pathGrid, _gx2, _gy2) == NO_ID) {
				continue;
			}
			// Down-right and down-left diagonals, so each link is looked at once
			for (var _d = 0; _d < 2; _d++) {
				var _dx = (_d == 0) ? 1 : -1;
				var _nx = _gx2 + _dx;
				var _ny = _gy2 + 1;
				if (!tile_in_bounds(_world, _nx, _ny) || (ds_grid_get(_world.pathGrid, _nx, _ny) == NO_ID)) {
					continue;
				}
				var _aIndex = _gy2 * _w + _nx;
				var _bIndex = _ny * _w + _gx2;
				if ((_path[_aIndex] == 0) && (_path[_bIndex] == 0)) {
					if (ds_grid_get(_world.biome, _nx, _gy2) != BIOME.WATER) {
						_path[_aIndex] = 128;
					}
					if (ds_grid_get(_world.biome, _gx2, _ny) != BIOME.WATER) {
						_path[_bIndex] = 128;
					}
				}
			}
		}
	}

	var _buf = buffer_create(_w * _h * 4, buffer_fixed, 1);
	global.groundMountains = [];
	for (var _y = 0; _y < _h; _y++) {
		for (var _x = 0; _x < _w; _x++) {
			var _biome = ds_grid_get(_world.biome, _x, _y);
			var _index = (_y * _w + _x) * 4;
			buffer_poke(_buf, _index, buffer_u8, get_ground_material(_biome));
			buffer_poke(_buf, _index + 1, buffer_u8, _path[_y * _w + _x]);
			buffer_poke(_buf, _index + 2, buffer_u8, 0);
			buffer_poke(_buf, _index + 3, buffer_u8, 255);
			if (_biome == BIOME.MOUNTAIN) {
				array_push(global.groundMountains, [_x, _y]);
			}
		}
	}
	buffer_set_surface(_buf, global.groundSurf, 0);
	buffer_delete(_buf);

	global.groundWorld = _world;
	global.groundPathTotal = _world.pathTotal;
	global.groundDirty = false;
}

function ground_check(_world) {
	if ((global.groundWorld != _world) || global.groundDirty || (global.groundPathTotal != _world.pathTotal) || !surface_exists(global.groundSurf)) {
		ground_rebuild(_world);
	}
}

// Draws the ground over the given world rectangle (the camera view) in one call
function draw_ground(_world, _x1, _y1, _x2, _y2) {
	ground_check(_world);
	shader_set(sh_ground);
	shader_set_uniform_f(global.groundUMapSize, _world.mapW, _world.mapH);
	shader_set_uniform_f(global.groundUHalfTile, TILE_W / 2, TILE_H / 2);
	shader_set_uniform_f(global.groundUTime, current_time / 1000);
	shader_set_uniform_f(global.groundUMargin, 8);
	// The map texture must not blur between tiles
	texture_set_stage(global.groundSampler, surface_get_texture(global.groundSurf));
	gpu_set_tex_filter_ext(global.groundSampler, false);
	gpu_set_tex_repeat_ext(global.groundSampler, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
	draw_primitive_begin(pr_trianglestrip);
	draw_vertex(_x1, _y1);
	draw_vertex(_x2, _y1);
	draw_vertex(_x1, _y2);
	draw_vertex(_x2, _y2);
	draw_primitive_end();
	shader_reset();
}