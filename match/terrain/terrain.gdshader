shader_type canvas_item;

// One tile of the terrain (terrain_view.gd). TEXTURE (and solid_tex) is the tile's L8 solid
// mask (1 = ground, 0 = air) and edge_tex its L8 edge bytes (TerrainMask.edge): on air 1 =
// carved by an explosion, 0 = the map's own air; on ground the scorch, 1 near-black within 3 px
// of a carved pixel, fading to 0 over 2.5 px more. Both cover the tile's rect grown by the aprons the neighbour
// reads below need, from world pixel tex_origin; everything works in world pixels, so the tiles
// join seamlessly. All the rest is derived from the masks per pixel, so a crater only
// re-uploads the tiles it touched and its new edges get their colours for free.
// The look comes from two images (assets/terrain, set by terrain_view.gd):
// - dirt_tex: tileable dirt, sampled by world position (one mask px = one world px), darker
//   with depth, with a dark burnt rim on walls and undersides;
// - grass_tex: a horizontally tileable strip. Its top tuft_rows rows are the tufts drawn in the
//   air just above a surface (the bottom one touches it), the rows under them the grass band
//   from the surface down; a transparent texel there shows dirt (or air for a tuft).
// A carved face grows no grass (no band under carved air, no tufts in it) and the ground along
// it is scorched; the map's own surface keeps its grass.

uniform sampler2D dirt_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D grass_tex : source_color, filter_nearest;
uniform sampler2D solid_tex : filter_nearest; // = TEXTURE (a built-in cannot be passed to a function)
uniform sampler2D edge_tex : filter_nearest;
uniform ivec2 tex_origin;
uniform ivec2 map_size = ivec2(1, 1);
uniform int tuft_rows = 6;
uniform vec4 dirt_bottom_tint : source_color = vec4(0.53, 0.51, 0.56, 1.0); // dirt at depth 1, x dirt_tex
uniform vec4 rim_color : source_color = vec4(0.25, 0.16, 0.1, 1.0);
uniform vec4 scorch_color : source_color = vec4(0.055, 0.045, 0.04, 1.0);

float solid_at(ivec2 p) {
	if (p.x < 0 || p.x >= map_size.x || p.y < 0) {
		return 0.0;
	}
	if (p.y >= map_size.y) {
		return 1.0; // below the map is solid floor
	}
	return texelFetch(solid_tex, p - tex_origin, 0).r;
}

float edge_at(ivec2 p) {
	if (p.x < 0 || p.x >= map_size.x || p.y < 0 || p.y >= map_size.y) {
		return 0.0;
	}
	return texelFetch(edge_tex, p - tex_origin, 0).r;
}

void fragment() {
	ivec2 p = ivec2(UV * vec2(textureSize(TEXTURE, 0))) + tex_origin;
	ivec2 gsize = textureSize(grass_tex, 0);
	int band_rows = gsize.y - tuft_rows;
	int gx = p.x % gsize.x;
	float here = solid_at(p);
	if (here < 0.5) {
		if (edge_at(p) > 0.5) {
			discard; // inside a crater: bare
		}
		// The map's own air: a tuft texel if the surface is just below.
		vec4 tuft = vec4(0.0);
		float burnt = 0.0;
		for (int d = 1; d <= 8; d++) {
			if (d > tuft_rows) {
				break;
			}
			ivec2 below = p + ivec2(0, d);
			if (solid_at(below) > 0.5) {
				tuft = texelFetch(grass_tex, ivec2(gx, tuft_rows - d), 0);
				burnt = edge_at(below); // scorched ground: scorched tufts
				break;
			}
		}
		if (tuft.a < 0.5) {
			discard;
		}
		COLOR = vec4(mix(tuft.rgb, scorch_color.rgb, burnt), 1.0);
	} else {
		// Grass band: px down from the first air above (0 = none within the band, or that air
		// is carved: a crater floor grows no grass).
		int top_gap = 0;
		for (int d = 1; d <= 24; d++) {
			if (d > band_rows) {
				break;
			}
			ivec2 above = p - ivec2(0, d);
			if (solid_at(above) < 0.5) {
				top_gap = edge_at(above) > 0.5 ? 0 : d;
				break;
			}
		}
		vec4 grass = top_gap > 0 ? texelFetch(grass_tex, ivec2(gx, tuft_rows + top_gap - 1), 0) : vec4(0.0);
		vec3 col;
		if (grass.a > 0.5) {
			col = grass.rgb;
		} else {
			// Dirt: lighter near an open face above, darker deeper.
			float open = 0.0;
			open += solid_at(p - ivec2(0, 14)) < 0.5 ? 1.0 : 0.0;
			open += solid_at(p - ivec2(0, 30)) < 0.5 ? 1.0 : 0.0;
			open += solid_at(p - ivec2(0, 60)) < 0.5 ? 1.0 : 0.0;
			float depth = clamp((float(p.y) + 0.5) / float(map_size.y) * 1.2 - open * 0.18, 0.0, 1.0);
			vec4 dirt = texture(dirt_tex, vec2(p) / vec2(textureSize(dirt_tex, 0)));
			dirt.rgb *= mix(vec3(1.0), dirt_bottom_tint.rgb, depth);
			// Burnt rim on walls and undersides: air close by on the sides or below.
			float near_air = 0.0;
			near_air += 1.0 - solid_at(p + ivec2(2, 0));
			near_air += 1.0 - solid_at(p - ivec2(2, 0));
			near_air += 1.0 - solid_at(p + ivec2(0, 2));
			if (near_air > 0.5) {
				dirt = mix(dirt, rim_color, 0.7);
			}
			col = dirt.rgb;
		}
		// Scorch along a carved edge
		COLOR = vec4(mix(col, scorch_color.rgb, edge_at(p)), 1.0);
	}
}
