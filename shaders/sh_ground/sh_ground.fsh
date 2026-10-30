//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

precision highp float;

varying vec2 v_world;

uniform sampler2D u_map;   // R = material id, G = path strength
uniform vec2 u_mapSize;    // map size in tiles
uniform vec2 u_halfTile;   // TILE_W / 2, TILE_H / 2
uniform float u_time;      // seconds
uniform float u_margin;    // how far the deep ocean fades in (tiles)

#define WATER 5.0

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.65 + vnoise(p * 2.1 + vec2(7.3, 3.1)) * 0.35;
}

// Material of one tile. Outside the map is open water.
float matAt(vec2 c) {
	vec2 cc = clamp(c, vec2(0.0), u_mapSize - vec2(1.0));
	vec4 t = texture2D(u_map, (cc + vec2(0.5)) / u_mapSize);
	bool outside = (c.x < 0.0) || (c.y < 0.0) || (c.x > u_mapSize.x - 1.0) || (c.y > u_mapSize.y - 1.0);
	return outside ? WATER : floor(t.r * 255.0 + 0.5);
}

float pathAt(vec2 c) {
	vec2 cc = clamp(c, vec2(0.0), u_mapSize - vec2(1.0));
	vec4 t = texture2D(u_map, (cc + vec2(0.5)) / u_mapSize);
	bool outside = (c.x < 0.0) || (c.y < 0.0) || (c.x > u_mapSize.x - 1.0) || (c.y > u_mapSize.y - 1.0);
	return outside ? 0.0 : t.g;
}

// The look of each material. 0 sand, 1 dirt, 2 grass, 3 forest, 4 snow, 5 water
vec3 surf(float m, vec2 wp) {
	float h = hash(wp);
	if (m < 0.5) {
		vec3 c = vec3(0.84, 0.74, 0.50);
		float n = fbm(wp * 0.07);
		c = mix(c, vec3(0.78, 0.67, 0.43), smoothstep(0.45, 0.65, n) * 0.6);
		if (h > 0.975) {
			c = vec3(0.62, 0.52, 0.34);
		} else if (h > 0.955) {
			c = vec3(0.92, 0.84, 0.62);
		}
		return c;
	}
	if (m < 1.5) {
		vec3 c = vec3(0.37, 0.26, 0.17);
		float n = fbm(wp * 0.11);
		if (n > 0.58) {
			c = vec3(0.30, 0.21, 0.13);
		} else if (n < 0.38) {
			c = vec3(0.44, 0.31, 0.20);
		}
		if (h > 0.985) {
			c = vec3(0.55, 0.48, 0.42);
		} else if (h > 0.96) {
			c = c * 0.82;
		}
		return c;
	}
	if (m < 3.5) {
		vec3 dark = vec3(0.17, 0.35, 0.12);
		vec3 mid = vec3(0.25, 0.47, 0.16);
		vec3 light = vec3(0.36, 0.60, 0.20);
		if (m > 2.5) {
			dark = vec3(0.11, 0.27, 0.13);
			mid = vec3(0.17, 0.38, 0.17);
			light = vec3(0.24, 0.50, 0.21);
		}
		float n = fbm(wp * 0.09);
		float bl = vnoise(vec2(wp.x * 0.8, wp.y * 0.45));
		float v = n * 0.5 + bl * 0.7;
		vec3 c = mid;
		if (v < 0.5) {
			c = dark;
		} else if (v > 0.95) {
			c = light;
		}
		if (h > 0.93) {
			c = light;
		} else if (h < 0.05) {
			c = dark;
		}
		// Tiny flowers on grassland
		if (m < 2.5 && hash(wp + vec2(17.0, 3.0)) > 0.9985) {
			c = (hash(wp * 1.7) > 0.5) ? vec3(0.95, 0.85, 0.30) : vec3(0.95, 0.95, 0.90);
		}
		return c;
	}
	if (m < 4.5) {
		vec3 c = vec3(0.93, 0.95, 0.98);
		float n = fbm(wp * 0.06);
		if (n < 0.42) {
			c = vec3(0.80, 0.86, 0.94);
		} else if (n < 0.5) {
			c = vec3(0.87, 0.91, 0.96);
		}
		if (h > 0.992) {
			c = vec3(1.0);
		}
		return c;
	}
	vec3 c = vec3(0.14, 0.49, 0.66);
	float n = fbm(wp * 0.035 + vec2(u_time * 0.015, 0.0));
	if (n > 0.6) {
		c = vec3(0.18, 0.57, 0.74);
	} else if (n < 0.4) {
		c = vec3(0.11, 0.42, 0.58);
	}
	return c;
}

void main() {
	// Snap to whole world pixels so the ground stays crisp
	vec2 wp = floor(v_world);

	// Tile coordinates of this pixel (tile centres sit on whole numbers)
	vec2 gRaw = vec2(wp.x / u_halfTile.x + wp.y / u_halfTile.y, wp.y / u_halfTile.y - wp.x / u_halfTile.x) * 0.5;

	// Noise wobble, so coasts and borders wander
	vec2 warp = vec2(fbm(wp * 0.05), fbm(wp * 0.05 + vec2(31.7, 17.3))) - vec2(0.5);
	vec2 fine = vec2(vnoise(wp * 0.2), vnoise(wp * 0.2 + vec2(9.1, 4.4))) - vec2(0.5);
	vec2 g = gRaw + warp * 0.55 + fine * 0.18;

	// The four tiles around this pixel and their bilinear weights
	vec2 b = floor(g);
	vec2 f = g - b;
	float w00 = (1.0 - f.x) * (1.0 - f.y);
	float w10 = f.x * (1.0 - f.y);
	float w01 = (1.0 - f.x) * f.y;
	float w11 = f.x * f.y;
	float m00 = matAt(b);
	float m10 = matAt(b + vec2(1.0, 0.0));
	float m01 = matAt(b + vec2(0.0, 1.0));
	float m11 = matAt(b + vec2(1.0, 1.0));

	// Total weight held by each tile's material
	float t00 = w00 + ((m10 == m00) ? w10 : 0.0) + ((m01 == m00) ? w01 : 0.0) + ((m11 == m00) ? w11 : 0.0);
	float t10 = w10 + ((m00 == m10) ? w00 : 0.0) + ((m01 == m10) ? w01 : 0.0) + ((m11 == m10) ? w11 : 0.0);
	float t01 = w01 + ((m00 == m01) ? w00 : 0.0) + ((m10 == m01) ? w10 : 0.0) + ((m11 == m01) ? w11 : 0.0);
	float t11 = w11 + ((m00 == m11) ? w00 : 0.0) + ((m10 == m11) ? w10 : 0.0) + ((m01 == m11) ? w01 : 0.0);

	// Winner: the material holding the most weight (ties go to the higher layer)
	float bestW = t00;
	float bestM = m00;
	if ((t10 > bestW + 0.0001) || ((abs(t10 - bestW) <= 0.0001) && (m10 > bestM))) {
		bestW = t10;
		bestM = m10;
	}
	if ((t01 > bestW + 0.0001) || ((abs(t01 - bestW) <= 0.0001) && (m01 > bestM))) {
		bestW = t01;
		bestM = m01;
	}
	if ((t11 > bestW + 0.0001) || ((abs(t11 - bestW) <= 0.0001) && (m11 > bestM))) {
		bestW = t11;
		bestM = m11;
	}

	// Runner up: the best different material (what lies under the edge)
	float secW = 0.0;
	float secM = bestM;
	if ((m00 != bestM) && ((t00 > secW + 0.0001) || ((abs(t00 - secW) <= 0.0001) && (m00 > secM)))) {
		secW = t00;
		secM = m00;
	}
	if ((m10 != bestM) && ((t10 > secW + 0.0001) || ((abs(t10 - secW) <= 0.0001) && (m10 > secM)))) {
		secW = t10;
		secM = m10;
	}
	if ((m01 != bestM) && ((t01 > secW + 0.0001) || ((abs(t01 - secW) <= 0.0001) && (m01 > secM)))) {
		secW = t01;
		secM = m01;
	}
	if ((m11 != bestM) && ((t11 > secW + 0.0001) || ((abs(t11 - secW) <= 0.0001) && (m11 > secM)))) {
		secW = t11;
		secM = m11;
	}

	// How far inside its own area this pixel is (about 1 per tile, 0 right on an edge)
	float e = bestW - 0.5;
	vec3 col = surf(bestM, wp);

	if (bestM == WATER) {
		if (secM != WATER) {
			// Shallow water near the shore, and foam washing in and out
			col = mix(col, vec3(0.30, 0.68, 0.80), 0.35 * clamp(1.0 - e / 0.30, 0.0, 1.0));
			float wob = 0.5 + 0.5 * sin(u_time * 1.4 + fbm(wp * 0.04) * 6.2832);
			float foamW = 0.05 + 0.13 * wob;
			float brk = vnoise(wp * 0.35 + vec2(u_time * 0.4, 0.0));
			if ((e < foamW * 0.55) || ((e < foamW) && (brk > 0.45))) {
				col = vec3(0.92, 0.97, 0.98);
			}
		}
	} else {
		if (secM == WATER) {
			// Wet shoreline
			if (e < 0.14) {
				col = col * 0.82;
			}
		} else if (secM < bestM) {
			// Higher layers hang over lower ones, one blade at a time
			float blade = hash(vec2(floor(wp.x * 0.7), floor(wp.y * 0.35)));
			float jag = 0.02 + 0.10 * blade;
			if (e < jag) {
				col = surf(secM, wp);
			}
		} else if ((secM > bestM) && (e < 0.09)) {
			// Contact shadow under an overhang
			col = col * 0.78;
		}
	}

	// Paths: dirt rim around a cobblestone core
	float pw = pathAt(b) * w00 + pathAt(b + vec2(1.0, 0.0)) * w10 + pathAt(b + vec2(0.0, 1.0)) * w01 + pathAt(b + vec2(1.0, 1.0)) * w11;
	if (pw > 0.48) {
		col = vec3(0.33, 0.24, 0.15) * (0.9 + 0.2 * hash(wp));
		if (pw > 0.60) {
			vec2 cp = wp / vec2(5.0, 3.0);
			cp.x += floor(cp.y) * 0.5;
			vec2 cf = fract(cp);
			float sh = hash(floor(cp));
			vec3 stone = mix(vec3(0.46, 0.43, 0.40), vec3(0.66, 0.62, 0.56), sh);
			if ((cf.x < 0.14) || (cf.y < 0.2)) {
				stone = vec3(0.27, 0.24, 0.20);
			}
			col = stone;
		}
	}

	// Far outside the map the ocean gets deeper
	float outDist = max(max(-gRaw.x, gRaw.x - (u_mapSize.x - 1.0)), max(-gRaw.y, gRaw.y - (u_mapSize.y - 1.0)));
	if (outDist > 0.0) {
		col = col * (1.0 - 0.5 * clamp(outDist / u_margin, 0.0, 1.0));
	}

	gl_FragColor = vec4(col, 1.0);
}
