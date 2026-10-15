shader_type canvas_item;

// TEXTURE is the L8 solid mask: 1 = ground, 0 = air.
uniform vec4 grass_color : source_color = vec4(0.36, 0.62, 0.25, 1.0);
uniform vec4 dirt_top : source_color = vec4(0.55, 0.38, 0.22, 1.0);
uniform vec4 dirt_bottom : source_color = vec4(0.30, 0.20, 0.12, 1.0);
uniform float grass_px = 6.0;

void fragment() {
	if (texture(TEXTURE, UV).r < 0.5) {
		discard;
	}
	float above = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * grass_px)).r;
	COLOR = above < 0.5 ? grass_color : mix(dirt_top, dirt_bottom, UV.y);
}
