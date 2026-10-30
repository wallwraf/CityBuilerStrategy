// ============================================================
// scr_terrain_cache: the ground is drawn once per chunk of tiles into a surface
// ============================================================

#macro CHUNK_TILES 16
#macro TERRAIN_BAKES_PER_FRAME 3

function terrain_cache_clear() {
	if (variable_global_exists("terrainChunks")) {
		var _names = variable_struct_get_names(global.terrainChunks);
		for (var _i = 0; _i < array_length(_names); _i++) {
			var _chunk = variable_struct_get(global.terrainChunks, _names[_i]);
			if (surface_exists(_chunk.surf)) {
				surface_free(_chunk.surf);
			}
		}
	}
	global.terrainChunks = {};
	global.terrainWorld = undefined;
}

// The original per tile drawing, for any rectangle of tiles (also the dark ocean outside the map)
function draw_terrain_tiles(_world, _gxA, _gxB, _gyA, _gyB) {
	var _hw = TILE_W / 2;
	var _hh = TILE_H / 2;
	var _deepColour = merge_colour(global.biomeColours[BIOME.WATER], c_black, 0.5);
	var _deepColourAlt = merge_colour(_deepColour, c_black, 0.06);
	for (var _gy = _gyA; _gy <= _gyB; _gy++) {
		for (var _gx = _gxA; _gx <= _gxB; _gx++) {
			var _cx = tile_to_world_x(_gx, _gy);
			var _cy = tile_to_world_y(_gx, _gy);
			if (!tile_in_bounds(_world, _gx, _gy)) {
				draw_diamond(_cx, _cy, _hw, _hh, (((_gx + _gy) mod 2) == 0) ? _deepColourAlt : _deepColour, 1);
				continue;
			}
			var _biome = ds_grid_get(_world.biome, _gx, _gy);
			var _lift = (_biome == BIOME.MOUNTAIN) ? ELEVATION_MOUNTAIN : 0;
			var _col = global.biomeColours[_biome];
			if (((_gx + _gy) mod 2) == 0) {
				_col = merge_colour(_col, c_black, 0.06);
			}
			if (_lift > 0) {
				draw_quad_colour(_cx - _hw, _cy - _lift, _cx, _cy + _hh - _lift, _cx, _cy + _hh, _cx - _hw, _cy, merge_colour(_col, c_black, 0.35), 1);
				draw_quad_colour(_cx, _cy + _hh - _lift, _cx + _hw, _cy - _lift, _cx + _hw, _cy, _cx, _cy + _hh, merge_colour(_col, c_black, 0.2), 1);
			}
			draw_diamond(_cx, _cy - _lift, _hw, _hh, _col, 1);
		}
	}
}

function bake_terrain_chunk(_world, _chunk) {
	var _hw = TILE_W / 2;
	var _hh = TILE_H / 2;
	_chunk.x = floor(tile_to_world_x(_chunk.gxA, _chunk.gyB) - _hw) - 1;
	_chunk.y = floor(tile_to_world_y(_chunk.gxA, _chunk.gyA) - _hh - ELEVATION_MOUNTAIN) - 1;
	var _maxX = ceil(tile_to_world_x(_chunk.gxB, _chunk.gyA) + _hw) + 1;
	var _maxY = ceil(tile_to_world_y(_chunk.gxB, _chunk.gyB) + _hh) + 1;
	_chunk.surf = surface_create(_maxX - _chunk.x, _maxY - _chunk.y);
	var _oldMatrix = matrix_get(matrix_world);
	surface_set_target(_chunk.surf);
	draw_clear_alpha(c_black, 0);
	matrix_set(matrix_world, matrix_build(-_chunk.x, -_chunk.y, 0, 0, 0, 0, 1, 1, 1));
	draw_terrain_tiles(_world, _chunk.gxA, _chunk.gxB, _chunk.gyA, _chunk.gyB);
	matrix_set(matrix_world, _oldMatrix);
	surface_reset_target();
}

// Draws every tile of the visible range, from cached chunks where possible
function draw_terrain(_world, _viewMinGx, _viewMaxGx, _viewMinGy, _viewMaxGy) {
	if (!variable_global_exists("terrainWorld") || (global.terrainWorld != _world)) {
		terrain_cache_clear();
		global.terrainWorld = _world;
	}
	var _lo = -DEEP_MARGIN;
	var _hiX = _world.mapW - 1 + DEEP_MARGIN;
	var _hiY = _world.mapH - 1 + DEEP_MARGIN;
	var _cx0 = (max(_viewMinGx, _lo) - _lo) div CHUNK_TILES;
	var _cx1 = (min(_viewMaxGx, _hiX) - _lo) div CHUNK_TILES;
	var _cy0 = (max(_viewMinGy, _lo) - _lo) div CHUNK_TILES;
	var _cy1 = (min(_viewMaxGy, _hiY) - _lo) div CHUNK_TILES;
	var _baked = 0;
	var _filter = gpu_get_tex_filter();
	gpu_set_tex_filter(false);
	for (var _cy = _cy0; _cy <= _cy1; _cy++) {
		for (var _cx = _cx0; _cx <= _cx1; _cx++) {
			var _key = string(_cx) + "_" + string(_cy);
			var _chunk = variable_struct_get(global.terrainChunks, _key);
			if (_chunk == undefined) {
				var _gxA = _lo + _cx * CHUNK_TILES;
				var _gyA = _lo + _cy * CHUNK_TILES;
				_chunk = { surf: -1, x: 0, y: 0, gxA: _gxA, gxB: min(_gxA + CHUNK_TILES - 1, _hiX), gyA: _gyA, gyB: min(_gyA + CHUNK_TILES - 1, _hiY) };
				variable_struct_set(global.terrainChunks, _key, _chunk);
			}
			if (!surface_exists(_chunk.surf)) {
				if (_baked >= TERRAIN_BAKES_PER_FRAME) {
					draw_terrain_tiles(_world, _chunk.gxA, _chunk.gxB, _chunk.gyA, _chunk.gyB);
					continue;
				}
				bake_terrain_chunk(_world, _chunk);
				_baked++;
			}
			draw_surface(_chunk.surf, _chunk.x, _chunk.y);
		}
	}
	gpu_set_tex_filter(_filter);
}