shader_type canvas_item;

// The bottom of a themed map (match/views/bottom_view.gd), in front of the terrain and behind
// the players, all on the GPU: kind 1 water (waves, a foam line, light streaks, a back wave),
// 2 lava (the same with a bright crust, moving hot blobs and a glow above), 3 abyss (darkness
// rising from the bottom with drifting fog). px are measured from the rect's top; `surface` is
// where the liquid's surface sits (px), rect_size the rect, x_origin the rect's world x (so the
// waves do not move when the rect does).

uniform int kind = 1;
uniform vec4 top_color : source_color = vec4(0.45, 0.9, 0.92, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.5, 0.7, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0);
uniform vec4 fog_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 glow_color : source_color = vec4(0.5, 0.5, 0.8, 1.0);
uniform float surface = 60.0;
uniform vec2 rect_size = vec2(2800.0, 400.0);
uniform float x_origin = -600.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = UV * rect_size;
	float x = px.x + x_origin;
	float t = TIME;
	if (kind == 3) {
		float k = clamp(px.y / surface, 0.0, 1.0);
		float fog = noise(vec2(x * 0.006 + t * 0.05, px.y * 0.02 - t * 0.03)) * 0.6 + noise(vec2(x * 0.017 - t * 0.08, px.y * 0.05)) * 0.4;
		float a = smoothstep(0.0, 1.0, k) * 0.94 + (fog - 0.5) * 0.35 * (1.0 - k) * k * 4.0;
		vec3 col = mix(glow_color.rgb * 0.45 + fog_color.rgb * 0.55, fog_color.rgb, smoothstep(0.1, 0.7, k));
		COLOR = vec4(col, clamp(a, 0.0, 0.97));
	} else {
		float lava = kind == 2 ? 1.0 : 0.0;
		float speed = mix(1.0, 0.35, lava);
		float wave = sin(x * 0.024 + t * 1.6 * speed) * 3.0 + sin(x * 0.061 - t * 2.3 * speed) * 1.5 + sin(x * 0.009 + t * 0.6 * speed) * 2.5;
		float s = surface + wave;
		float back = surface - 9.0 + sin(x * 0.018 - t * 1.1 * speed + 1.3) * 3.0 + sin(x * 0.047 + t * 1.7 * speed) * 1.2;
		float depth = px.y - s;
		if (depth < 0.0) {
			if (px.y >= back) { // the back wave
				COLOR = vec4(mix(top_color.rgb, foam_color.rgb, 0.25), mix(0.5, 0.85, lava));
			} else if (lava > 0.5) { // heat glow over the lava
				COLOR = vec4(glow_color.rgb, 0.45 * exp(-(back - px.y) / 22.0));
			} else {
				discard;
			}
		} else {
			vec3 col = mix(top_color.rgb, deep_color.rgb, clamp(depth / 70.0, 0.0, 1.0));
			if (lava > 0.5) {
				float blob = noise(vec2(x * 0.03 + t * 0.2, depth * 0.06 - t * 0.15));
				col = mix(col, top_color.rgb, smoothstep(0.62, 0.8, blob));
				col = mix(col, deep_color.rgb * 0.45, smoothstep(0.62, 0.75, noise(vec2(x * 0.02 - t * 0.1, depth * 0.08 + 7.0))) * 0.6);
			} else {
				float streak = sin(x * 0.07 + t * 1.3 + depth * 0.35 + sin(x * 0.013) * 3.0);
				if (streak > 0.93 && depth > 6.0 && depth < 40.0) {
					col = mix(col, foam_color.rgb, 0.35);
				}
			}
			float foam_w = 3.0 + noise(vec2(x * 0.05 + t * 0.5, 0.0)) * 2.5;
			if (depth < foam_w) {
				col = foam_color.rgb;
			} else if (depth < foam_w + 6.0 && noise(vec2(x * 0.2 + t, depth * 0.4)) > 0.7 && lava < 0.5) {
				col = mix(col, foam_color.rgb, 0.7); // bubbles under the foam
			}
			float alpha = mix(0.84 + 0.14 * clamp(depth / 40.0, 0.0, 1.0), 1.0, lava);
			COLOR = vec4(col, alpha);
		}
	}
}
