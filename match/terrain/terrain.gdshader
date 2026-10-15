shader_type canvas_item;

// TEXTURE is the L8 solid mask: 1 = ground, 0 = air. The mask stays the only source of truth:
// everything here is derived from it per pixel, so a crater only re-uploads the mask
// (terrain_view.gd refresh) and its new edges get grass/rim colours for free.
// The look comes from two images (assets/terrain, set by terrain_view.gd):
// - dirt_tex: tileable dirt, sampled by world position (one mask px = one world px), darker
//   with depth, with a dark burnt rim on crater walls and undersides;
// - grass_tex: a horizontally tileable strip. Its top tuft_rows rows are the tufts drawn in the
//   air just above a surface (the bottom one touches it), the rows under them the grass band
//   from the surface down; a transparent texel there shows dirt (or air for a tuft).

uniform sampler2D dirt_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D grass_tex : source_color, filter_nearest;
uniform int tuft_rows = 6;
uniform vec4 dirt_bottom_tint : source_color = vec4(0.53, 0.51, 0.56, 1.0); // dirt at depth 1, x dirt_tex
uniform vec4 rim_color : source_color = vec4(0.25, 0.16, 0.1, 1.0);

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
	ivec2 gsize = textureSize(grass_tex, 0);
	int band_rows = gsize.y - tuft_rows;
	int gx = p.x % gsize.x;
	float here = solid_at(TEXTURE, p, size);
	if (here < 0.5) {
		// Air: a tuft texel if the surface is just below.
		vec4 tuft = vec4(0.0);
		for (int d = 1; d <= 8; d++) {
			if (d > tuft_rows) {
				break;
			}
			if (solid_at(TEXTURE, p + ivec2(0, d), size) > 0.5) {
				tuft = texelFetch(grass_tex, ivec2(gx, tuft_rows - d), 0);
				break;
			}
		}
		if (tuft.a < 0.5) {
			discard;
		}
		COLOR = vec4(tuft.rgb, 1.0);
	} else {
		// Grass band: px down from the first air above (0 = none within the band).
		int top_gap = 0;
		for (int d = 1; d <= 24; d++) {
			if (d > band_rows) {
				break;
			}
			if (solid_at(TEXTURE, p - ivec2(0, d), size) < 0.5) {
				top_gap = d;
				break;
			}
		}
		vec4 grass = top_gap > 0 ? texelFetch(grass_tex, ivec2(gx, tuft_rows + top_gap - 1), 0) : vec4(0.0);
		if (grass.a > 0.5) {
			COLOR = vec4(grass.rgb, 1.0);
		} else {
			// Dirt: lighter near an open face above, darker deeper.
			float open = 0.0;
			open += solid_at(TEXTURE, p - ivec2(0, 14), size) < 0.5 ? 1.0 : 0.0;
			open += solid_at(TEXTURE, p - ivec2(0, 30), size) < 0.5 ? 1.0 : 0.0;
			open += solid_at(TEXTURE, p - ivec2(0, 60), size) < 0.5 ? 1.0 : 0.0;
			float depth = clamp(UV.y * 1.2 - open * 0.18, 0.0, 1.0);
			vec4 dirt = texture(dirt_tex, vec2(p) / vec2(textureSize(dirt_tex, 0)));
			dirt.rgb *= mix(vec3(1.0), dirt_bottom_tint.rgb, depth);
			// Burnt rim on walls and undersides: air close by on the sides or below.
			float near_air = 0.0;
			near_air += 1.0 - solid_at(TEXTURE, p + ivec2(2, 0), size);
			near_air += 1.0 - solid_at(TEXTURE, p - ivec2(2, 0), size);
			near_air += 1.0 - solid_at(TEXTURE, p + ivec2(0, 2), size);
			if (near_air > 0.5) {
				dirt = mix(dirt, rim_color, 0.7);
			}
			COLOR = vec4(dirt.rgb, 1.0);
		}
	}
}
