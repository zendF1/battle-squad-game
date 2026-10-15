shader_type canvas_item;

// TEXTURE is the L8 solid mask: 1 = ground, 0 = air. The mask stays the only source of truth:
// everything here is derived from it per pixel, so a crater only re-uploads the mask
// (terrain_view.gd refresh) and its new edges get grass/rim colours for free.
// Placeholder art: a grass band along every surface that has air above it (wavy thickness, a
// light top line, a darker underside), grass tufts just above it, dirt that is lighter near any
// open face and darker with depth, with speckle noise, and a dark burnt rim on crater walls.

uniform vec4 grass_light : source_color = vec4(0.55, 0.82, 0.32, 1.0);
uniform vec4 grass_color : source_color = vec4(0.36, 0.66, 0.24, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.22, 0.45, 0.17, 1.0);
uniform vec4 dirt_top : source_color = vec4(0.62, 0.43, 0.25, 1.0);
uniform vec4 dirt_bottom : source_color = vec4(0.33, 0.22, 0.14, 1.0);
uniform vec4 rim_color : source_color = vec4(0.25, 0.16, 0.1, 1.0);
uniform float grass_px = 7.0;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float solid_at(sampler2D tex, ivec2 p, ivec2 size) {
	if (p.x < 0 || p.x >= size.x || p.y < 0) {
		return 0.0;
	}
	if (p.y >= size.y) {
		return 1.0; // below the map is solid floor
	}
	return texelFetch(tex, p, 0).r;
}

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	ivec2 p = ivec2(UV * vec2(size));
	float here = solid_at(TEXTURE, p, size);
	float col_h = hash(vec2(float(p.x), 7.0));
	if (here < 0.5) {
		// Air: a grass tuft if the surface is just below (blade height varies per column).
		float blade = floor(col_h * col_h * 5.0);
		bool tuft = false;
		for (int d = 1; d <= 4; d++) {
			if (float(d) <= blade && solid_at(TEXTURE, p + ivec2(0, d), size) > 0.5) {
				tuft = true;
				break;
			}
		}
		if (!tuft) {
			discard;
		}
		COLOR = mix(grass_color, grass_light, 0.5);
	} else {
		// Grass band: air within a wavy thickness above.
		float thick = grass_px + 2.0 * sin(float(p.x) * 0.09) + 1.5 * sin(float(p.x) * 0.23);
		int top_gap = 0; // px down from the surface (0 = none found)
		for (int d = 1; d <= 10; d++) {
			if (float(d) > thick) {
				break;
			}
			if (solid_at(TEXTURE, p - ivec2(0, d), size) < 0.5) {
				top_gap = d;
				break;
			}
		}
		if (top_gap > 0) {
			COLOR = top_gap <= 2 ? grass_light : grass_color;
			if (float(top_gap) > thick - 2.0) {
				COLOR = grass_dark;
			}
		} else {
			// Dirt: lighter near an open face above, darker deeper; strata and speckles.
			float open = 0.0;
			open += solid_at(TEXTURE, p - ivec2(0, 14), size) < 0.5 ? 1.0 : 0.0;
			open += solid_at(TEXTURE, p - ivec2(0, 30), size) < 0.5 ? 1.0 : 0.0;
			open += solid_at(TEXTURE, p - ivec2(0, 60), size) < 0.5 ? 1.0 : 0.0;
			float depth = clamp(UV.y * 1.2 - open * 0.18, 0.0, 1.0);
			vec4 dirt = mix(dirt_top, dirt_bottom, depth);
			float strata = sin(float(p.y) * 0.11 + sin(float(p.x) * 0.013) * 3.0);
			dirt.rgb *= 1.0 + strata * 0.04;
			float n = hash(floor(vec2(p) / 3.0));
			if (n > 0.93) {
				dirt.rgb *= 0.78; // dark pebble
			} else if (n < 0.05) {
				dirt.rgb *= 1.15; // light grit
			}
			// Burnt rim on walls and undersides: air close by on the sides or below.
			float near_air = 0.0;
			near_air += 1.0 - solid_at(TEXTURE, p + ivec2(2, 0), size);
			near_air += 1.0 - solid_at(TEXTURE, p - ivec2(2, 0), size);
			near_air += 1.0 - solid_at(TEXTURE, p + ivec2(0, 2), size);
			if (near_air > 0.5) {
				dirt = mix(dirt, rim_color, 0.7);
			}
			COLOR = dirt;
		}
	}
}
