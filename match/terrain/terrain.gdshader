shader_type canvas_item;

// One tile of the terrain (terrain_view.gd). TEXTURE (and solid_tex) is the tile's L8 solid
// mask (1 = ground, 0 = air), edge_tex its L8 edge bytes (TerrainMask.edge): on air 1 =
// carved by an explosion, 0 = the map's own air; on ground the scorch, 1 near-black within 3 px
// of a carved pixel, fading to 0 over 2.5 px more. dest_tex is the L8 destructible mask: on
// ground 1 = soft (destructible), 0 = hard (indestructible); it never changes, so it is uploaded
// once. All cover the tile's rect grown by the aprons the neighbour reads below need, from world
// pixel tex_origin; everything works in world pixels, so the tiles join seamlessly. All the rest
// is derived from the masks per pixel, so a crater only re-uploads the tiles it touched and its
// new edges get their colours for free.
// Each ground pixel is drawn with its material, soft or hard (match/theme/material_painter.gd,
// set by terrain_view.gd from the map theme):
// - *_fill: tileable fill, sampled by world position (one mask px = one world px), darker with
//   depth (*_bottom_tint at the map's bottom), with a rim (*_rim, mixed *_rim_mix) on walls and
//   undersides; a hard material also outlines itself against soft ground;
// - *_edge: a horizontally tileable strip. Its top *_cap rows are drawn in the air just above a
//   surface (the bottom one touches it: tufts, snow puffs), the rows under them the band from
//   the surface down (grass, snow, a metal rim); a transparent texel there shows the fill (or
//   air for a cap texel);
// - *_hang: a strip drawn in the air under an underside (row 0 touches it: icicles, roots);
//   *_hang_rows 0 = none.
// A carved face grows nothing (no band under carved air, no cap or hang in it) and the ground
// along it is scorched; the map's own surface keeps its band. Grassland's soft material is
// dirt.png + grass_edge.png with the colours this shader always had.

uniform sampler2D soft_fill : source_color, repeat_enable, filter_nearest;
uniform sampler2D soft_edge : source_color, filter_nearest;
uniform sampler2D soft_hang : source_color, filter_nearest;
uniform int soft_cap = 6;
uniform int soft_hang_rows = 0;
uniform vec4 soft_bottom_tint : source_color = vec4(0.53, 0.51, 0.56, 1.0);
uniform vec4 soft_rim : source_color = vec4(0.25, 0.16, 0.1, 1.0);
uniform float soft_rim_mix = 0.7;
uniform sampler2D hard_fill : source_color, repeat_enable, filter_nearest;
uniform sampler2D hard_edge : source_color, filter_nearest;
uniform sampler2D hard_hang : source_color, filter_nearest;
uniform int hard_cap = 0;
uniform int hard_hang_rows = 0;
uniform vec4 hard_bottom_tint : source_color = vec4(0.7, 0.7, 0.74, 1.0);
uniform vec4 hard_rim : source_color = vec4(0.16, 0.17, 0.2, 1.0);
uniform float hard_rim_mix = 0.85;
uniform sampler2D solid_tex : filter_nearest; // = TEXTURE (a built-in cannot be passed to a function)
uniform sampler2D edge_tex : filter_nearest;
uniform sampler2D dest_tex : filter_nearest;
uniform ivec2 tex_origin;
uniform ivec2 map_size = ivec2(1, 1);
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

// 1 = soft ground (or below the map), 0 = hard. Only meaningful where solid_at is 1.
float soft_at(ivec2 p) {
	if (p.x < 0 || p.x >= map_size.x || p.y < 0 || p.y >= map_size.y) {
		return 1.0;
	}
	return texelFetch(dest_tex, p - tex_origin, 0).r;
}

vec4 edge_texel(bool soft, int row, int x) {
	if (soft) {
		return texelFetch(soft_edge, ivec2(x % textureSize(soft_edge, 0).x, row), 0);
	}
	return texelFetch(hard_edge, ivec2(x % textureSize(hard_edge, 0).x, row), 0);
}

void fragment() {
	ivec2 p = ivec2(UV * vec2(textureSize(TEXTURE, 0))) + tex_origin;
	float here = solid_at(p);
	if (here < 0.5) {
		if (edge_at(p) > 0.5) {
			discard; // inside a crater: bare
		}
		// The map's own air: a cap texel if a surface is just below...
		vec4 deco = vec4(0.0);
		float burnt = 0.0;
		int max_cap = max(soft_cap, hard_cap);
		for (int d = 1; d <= 8; d++) {
			if (d > max_cap) {
				break;
			}
			ivec2 below = p + ivec2(0, d);
			if (solid_at(below) > 0.5) {
				bool soft = soft_at(below) > 0.5;
				int cap = soft ? soft_cap : hard_cap;
				if (d <= cap) {
					deco = edge_texel(soft, cap - d, p.x);
					burnt = edge_at(below); // scorched ground: scorched tufts
				}
				break;
			}
		}
		// ...else a hang texel if an underside is just above.
		int max_hang = max(soft_hang_rows, hard_hang_rows);
		if (deco.a < 0.5 && max_hang > 0) {
			for (int d = 1; d <= 12; d++) {
				if (d > max_hang) {
					break;
				}
				ivec2 above = p - ivec2(0, d);
				if (solid_at(above) > 0.5) {
					bool soft = soft_at(above) > 0.5;
					int rows = soft ? soft_hang_rows : hard_hang_rows;
					if (d <= rows && edge_at(above) < 0.5) { // a scorched underside drips nothing
						deco = soft ? texelFetch(soft_hang, ivec2(p.x % textureSize(soft_hang, 0).x, d - 1), 0)
							: texelFetch(hard_hang, ivec2(p.x % textureSize(hard_hang, 0).x, d - 1), 0);
					}
					break;
				}
			}
		}
		if (deco.a < 0.5) {
			discard;
		}
		COLOR = vec4(mix(deco.rgb, scorch_color.rgb, burnt), 1.0);
	} else {
		bool soft = soft_at(p) > 0.5;
		int cap = soft ? soft_cap : hard_cap;
		int band_rows = (soft ? textureSize(soft_edge, 0).y : textureSize(hard_edge, 0).y) - cap;
		// Band: px down from the first air above (0 = none within the band, or that air is
		// carved: a crater floor grows no band).
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
		vec4 band = top_gap > 0 ? edge_texel(soft, cap + top_gap - 1, p.x) : vec4(0.0);
		vec3 col;
		if (band.a > 0.5) {
			col = band.rgb;
		} else if (soft) {
			// Fill: lighter near an open face above, darker deeper.
			float open = 0.0;
			open += solid_at(p - ivec2(0, 14)) < 0.5 ? 1.0 : 0.0;
			open += solid_at(p - ivec2(0, 30)) < 0.5 ? 1.0 : 0.0;
			open += solid_at(p - ivec2(0, 60)) < 0.5 ? 1.0 : 0.0;
			float depth = clamp((float(p.y) + 0.5) / float(map_size.y) * 1.2 - open * 0.18, 0.0, 1.0);
			vec4 fill = texture(soft_fill, vec2(p) / vec2(textureSize(soft_fill, 0)));
			fill.rgb *= mix(vec3(1.0), soft_bottom_tint.rgb, depth);
			// Rim on walls and undersides: air close by on the sides or below.
			float near_air = 0.0;
			near_air += 1.0 - solid_at(p + ivec2(2, 0));
			near_air += 1.0 - solid_at(p - ivec2(2, 0));
			near_air += 1.0 - solid_at(p + ivec2(0, 2));
			if (near_air > 0.5) {
				fill = mix(fill, soft_rim, soft_rim_mix);
			}
			col = fill.rgb;
		} else {
			// Hard: its own fill, a little darker deeper, outlined against air beside or below
			// and against soft ground on any side (the air above is the band's job).
			float depth = clamp((float(p.y) + 0.5) / float(map_size.y), 0.0, 1.0);
			vec4 fill = texture(hard_fill, vec2(p) / vec2(textureSize(hard_fill, 0)));
			fill.rgb *= mix(vec3(1.0), hard_bottom_tint.rgb, depth);
			bool outline = false;
			for (int i = 0; i < 4; i++) {
				ivec2 q = p + (i == 0 ? ivec2(2, 0) : i == 1 ? ivec2(-2, 0) : i == 2 ? ivec2(0, 2) : ivec2(0, -2));
				float s = solid_at(q);
				if ((s < 0.5 && i < 3) || (s > 0.5 && q.y < map_size.y && soft_at(q) > 0.5)) {
					outline = true;
				}
			}
			if (outline) {
				fill = mix(fill, hard_rim, hard_rim_mix);
			}
			col = fill.rgb;
		}
		// Scorch along a carved edge
		COLOR = vec4(mix(col, scorch_color.rgb, edge_at(p)), 1.0);
	}
}
