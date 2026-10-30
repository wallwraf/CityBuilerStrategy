//
// Simple passthrough fragment shader
//
precision highp float;

varying vec2 v_world;
varying vec4 v_data;   // r unused, g = how far down a cliff face (0 top, 1 foot), b = face (0 top, 0.5 left, 1 right), a = height level / 4

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

void main() {
	vec2 wp = floor(v_world);
	float v = v_data.g;
	float lvl = floor(v_data.a * 4.0 + 0.5);
	bool isTop = (v_data.b < 0.25);
	bool isLeft = (v_data.b >= 0.25) && (v_data.b < 0.75);

	float h = hash(wp);

	// Rock: layered strata down the cliffs, blotches on the top
	float band = vnoise(vec2(wp.x * 0.05, wp.y * 0.45 + fbm(wp * 0.06) * 3.0));
	float blot = fbm(wp * 0.13);
	float t = isTop ? blot : band;
	vec3 c = vec3(0.47, 0.45, 0.43);
	if (t > 0.62) {
		c = vec3(0.57, 0.54, 0.51);
	} else if (t < 0.36) {
		c = vec3(0.36, 0.34, 0.33);
	}

	// Cracks and pebbles
	float crack = fbm(wp * vec2(0.22, 0.8) + vec2(5.0, 9.0));
	if (crack > 0.72) {
		c = c * 0.7;
	}
	if (h > 0.985) {
		c = vec3(0.70, 0.67, 0.62);
	} else if (h < 0.03) {
		c = c * 0.8;
	}
	c = c * vec3(1.0 + 0.04 * (blot - 0.5), 1.0, 1.0 - 0.05 * (blot - 0.5));

	// Light comes from the top right
	float shade = isTop ? 1.0 : (isLeft ? 0.62 : 0.82);
	c = c * shade;
	if (!isTop) {
		c = c * (1.0 - 0.28 * smoothstep(0.65, 1.0, v));
	}

	// Snow on the tall parts
	float cover = (lvl < 1.5) ? 0.0 : ((lvl < 2.5) ? 0.16 : ((lvl < 3.5) ? 0.55 : 0.92));
	float sn = fbm(wp * 0.075 + vec2(3.3, 8.8));
	vec3 snow = (fbm(wp * 0.15) > 0.5) ? vec3(0.95, 0.97, 1.0) : vec3(0.80, 0.86, 0.94);
	snow = snow * (isTop ? 1.0 : (isLeft ? 0.8 : 0.9));
	if (h > 0.992) {
		snow = vec3(1.0);
	}
	if (isTop) {
		if (sn < cover) {
			c = snow;
		}
	} else {
		// Drifts hang down the cliff in ragged columns
		float reach = cover * 0.65 * (0.5 + hash(vec2(floor(wp.x * 0.6), 4.0)));
		if (v < reach) {
			c = snow;
		}
	}

	gl_FragColor = vec4(c, 1.0);
}