shader_type canvas_item;

// The map theme's floating particles over the background (match/views/sky_view.gd), all on the
// GPU: three layers of jittered grid cells, at most one particle per cell, moving with TIME.
// mode (map_themes.gd FX_*): 1 snow falling and drifting with the wind, 2 embers rising and
// flickering, 3 dust motes drifting, 4 wisps (big soft glows wandering), 5 twinkling stars in
// the upper half. density 0..1 = share of cells with a particle. rect_size is the rect in px.

uniform int mode = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float density = 0.5;
uniform float wind = 0.0; // signed wind power
uniform vec2 rect_size = vec2(1600.0, 900.0);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void fragment() {
	vec2 px = UV * rect_size;
	float a = 0.0;
	vec3 col = tint.rgb;
	for (int layer = 0; layer < 3; layer++) {
		float fl = float(layer);
		float cell = mode == 4 ? 220.0 + fl * 60.0 : (mode == 5 ? 46.0 + fl * 20.0 : 70.0 + fl * 34.0);
		vec2 q = px;
		float t = TIME;
		if (mode == 1) {
			q.y -= t * (26.0 + fl * 18.0);
			q.x -= t * wind * (8.0 + fl * 6.0) + sin(t * 0.8 + fl) * 10.0;
		} else if (mode == 2) {
			q.y += t * (22.0 + fl * 14.0);
			q.x += sin(t * 0.6 + px.y * 0.01 + fl) * 14.0;
		} else if (mode == 3) {
			q.x -= t * (6.0 + fl * 4.0) * (1.0 + abs(wind) * 0.4) * (wind < 0.0 ? -1.0 : 1.0);
			q.y -= sin(t * 0.3 + fl * 2.0) * 12.0;
		} else if (mode == 4) {
			q += vec2(sin(t * 0.21 + fl * 1.7), cos(t * 0.17 + fl)) * 40.0;
		}
		vec2 id = floor(q / cell);
		vec2 h = hash2(id + fl * 17.0);
		if (h.x > density) {
			continue;
		}
		vec2 centre = (id + 0.15 + 0.7 * hash2(id + 3.1 + fl)) * cell;
		float d = length(q - centre);
		float r = mode == 4 ? 7.0 + fl * 3.0 : (mode == 5 ? 1.3 : (mode == 1 ? 1.6 + fl * 0.9 : 1.2 + fl * 0.5));
		float k = 0.0;
		if (mode == 4) {
			k = exp(-d * d / (r * r * 2.0)) * (0.6 + 0.4 * sin(t * 1.3 + h.y * 30.0));
			k += smoothstep(r * 0.4, 0.0, d) * 0.6;
		} else {
			k = smoothstep(r + 1.0, r - 0.5, d);
		}
		if (mode == 2) {
			k *= 0.55 + 0.45 * sin(t * 6.0 + h.y * 40.0);
			col = mix(tint.rgb, vec3(1.0, 0.95, 0.6), h.y * 0.6);
		} else if (mode == 5) {
			k *= pow(max(0.0, sin(t * (1.0 + h.y * 2.0) + h.y * 50.0)), 4.0);
			k *= smoothstep(0.55, 0.2, UV.y);
		}
		a = max(a, k * (0.55 + 0.45 * fl / 2.0));
	}
	COLOR = vec4(col, a * tint.a);
}
