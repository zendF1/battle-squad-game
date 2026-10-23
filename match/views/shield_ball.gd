extends Node2D
## A shield bubble: a ball of hexagons. A regular hex grid wrapped on a sphere seen from the front
## (SHADER: each point of the disc is taken back to the sphere's surface, an azimuthal equidistant
## map: q = p / |p| · asin(|p|), and the grid is drawn there), so the hexes are full size and evenly
## spaced in the middle and foreshorten toward the rim, smaller and squeezed, like a globe; its
## outline is a circle. It is most solid in the middle and fades smoothly toward the outside, with no
## ring at the edge; the cells shimmer softly. It breathes (its size swells and shrinks a few
## percent, PULSE_SEC a cycle). One node per bubble, centred on what it covers (radius px):
## a player's shield (PlayerView: Flora's bloom overflow turned into shield) and the boss's
## (BossBody, set_look() driving its own fade). show_ball() pops it in (from POP_FROM with an
## overshoot, fading in), hide_ball() pops it out (swelling as it fades). Its tint is the caster's
## gun tier (tier_colour()). Visual only.

const EquipmentPainter := preload("res://tools/art/equipment_painter.gd")

const PULSE_SEC := 1.8 # one breath
const PULSE_AMP := 0.05 # ± of the radius
const POP_IN_SEC := 0.4
const POP_FROM := 0.6 # the scale it pops in from
const FADE_IN_SEC := 0.22
const POP_OUT_SEC := 0.3
const POP_OUT_TO := 1.25
## The tint of a shield without a known gun tier (a basic gun, a reconnect without the caster).
const DEFAULT_TINT := Color(0.55, 0.9, 1.0)
## Hex cells from the centre to the rim (on the sphere): about one per HEX_PX of the radius, so a
## player's small bubble is not a dense mesh, within HEX_MIN..HEX_MAX.
const HEX_PX := 15.0
const HEX_MIN := 2.2
const HEX_MAX := 3.4

## The ball: the disc (UV -1..1) mapped back onto the sphere, a hex grid there; COLOR (the draw's
## modulate) is the tint and the alpha. Opacity: highest in the middle, smoothly to 0 at the rim.
const SHADER := """
shader_type canvas_item;
uniform float hex_across = 3.2;

vec4 hex_cell(vec2 uv) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 hc = floor(vec4(uv, uv - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 h = vec4(uv - hc.xy * s, uv - (hc.zw + 0.5) * s);
	return dot(h.xy, h.xy) < dot(h.zw, h.zw) ? vec4(h.xy, hc.xy) : vec4(h.zw, hc.zw + 0.5);
}

float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, vec2(0.5, 0.8660254)), p.x);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tint = COLOR;
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r >= 1.0) {
		COLOR = vec4(0.0);
	} else {
		// back onto the sphere: the arc from the front pole (0..pi/2), the grid laid out along it
		vec2 q = r > 0.0001 ? p / r * asin(r) : p;
		vec2 g = (q * hex_across / 1.5707963 * 2.0).yx; // pointy-top cells
		vec4 h = hex_cell(g);
		float edge = 0.5 - hex_dist(h.xy);
		float w = fwidth(edge) * 1.2 + 0.035;
		float line = 1.0 - smoothstep(0.0, w, edge);
		float fill = smoothstep(0.0, 0.25, edge);
		float shimmer = 0.75 + 0.25 * sin(TIME * 2.2 + hash(h.zw) * 6.2831);
		// most solid in the middle, fading smoothly out to nothing at the rim
		float fade = pow(1.0 - r * r, 1.15);
		float z = sqrt(1.0 - r * r);
		float a = fade * (0.3 * fill * shimmer + 0.95 * line);
		vec3 col = mix(tint.rgb, vec3(1.0), 0.25 * line + 0.25 * z * z);
		COLOR = vec4(col, a * tint.a);
	}
}
"""

var radius := 34.0:
	set(v):
		radius = v
		if is_inside_tree():
			material = _material_for(hex_across(radius))
var tint := DEFAULT_TINT
var _t := 0.0
var _on := false
var _anim := 0.0 # s into the pop in / out
var _popping_out := false
var _look := Vector2(-1, -1) # set_look(): (scale, alpha) driven by the owner, else the pop's

static var _materials := {} # hex cells across (snapped) -> ShaderMaterial
static var _shader: Shader
static var _white: Texture2D


## The bubble's tint for a gun tier: the tier's main colour of the equipment palettes
## (EquipmentPainter.TIERS: dragon red, mithril teal, gold yellow...), lightened a little to glow;
## DEFAULT_TINT for the basic gun or an unknown tier.
static func tier_colour(tier: String) -> Color:
	var t = EquipmentPainter.TIERS.get(tier)
	if not t is Array:
		return DEFAULT_TINT
	return (t[0] as Color).lerp(t[1], 0.35)


## The breathing scale at time t (s): 1 ± PULSE_AMP on a slow sine.
static func pulse(t: float) -> float:
	return 1.0 + PULSE_AMP * sin(TAU * t / PULSE_SEC)


## The hex cells from the centre to the rim for a ball of radius px.
static func hex_across(radius_px: float) -> float:
	return snappedf(clampf(radius_px / HEX_PX, HEX_MIN, HEX_MAX), 0.2)


## The ball's material for that many cells (shared by the balls of about the same size).
static func _material_for(across: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	if not _materials.has(across):
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("hex_across", across)
		_materials[across] = m
	return _materials[across]


static func _white_tex() -> Texture2D:
	if _white == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


func _ready() -> void:
	material = _material_for(hex_across(radius))
	_t = randf() * PULSE_SEC


## Shows the bubble; animate: it pops in (else it is there at once, a snapshot's shield).
func show_ball(animate: bool = true) -> void:
	if _on and not _popping_out:
		return
	_on = true
	_popping_out = false
	_anim = 0.0 if animate else POP_IN_SEC
	queue_redraw()


## Takes it away; animate: it pops out (else gone at once).
func hide_ball(animate: bool = true) -> void:
	if not _on or _popping_out:
		return
	if animate:
		_popping_out = true
		_anim = 0.0
	else:
		_on = false
	queue_redraw()


## The owner drives it (the boss's shield fade): scale on top of the breath, alpha 0..1; alpha 0
## hides it.
func set_look(scale_k: float, alpha: float) -> void:
	_look = Vector2(scale_k, alpha)
	_on = alpha > 0.0
	_popping_out = false
	queue_redraw()


## Shown (or popping out).
func is_on() -> bool:
	return _on


func popping_out() -> bool:
	return _popping_out


## (scale, alpha) of the pop now: the pop-in's overshoot from POP_FROM and its fade, the
## pop-out's swell and fade, else (1, 1); the owner's set_look() when it drives it.
func pop_state() -> Vector2:
	if _look.y >= 0.0:
		return _look
	if _popping_out:
		var k := clampf(_anim / POP_OUT_SEC, 0.0, 1.0)
		return Vector2(lerpf(1.0, POP_OUT_TO, k), 1.0 - k * k)
	if _anim < POP_IN_SEC:
		var k := clampf(_anim / POP_IN_SEC, 0.0, 1.0)
		var s := 1.70158 # back-out: overshoots then settles on 1
		var back := 1.0 + (s + 1.0) * pow(k - 1.0, 3.0) + s * pow(k - 1.0, 2.0)
		return Vector2(lerpf(POP_FROM, 1.0, back), clampf(_anim / FADE_IN_SEC, 0.0, 1.0))
	return Vector2.ONE


## The radius drawn now (px): the breath and the pop on radius.
func drawn_radius() -> float:
	return radius * pulse(_t) * pop_state().x


## Sets the breath's clock (s; previews, tests).
func set_time(t: float) -> void:
	_t = t
	queue_redraw()


func _process(delta: float) -> void:
	if not _on:
		return
	_t += delta
	_anim += delta
	if _popping_out and _anim >= POP_OUT_SEC:
		_on = false
		_popping_out = false
	queue_redraw()


func _draw() -> void:
	if not _on:
		return
	var p := pop_state()
	if p.y <= 0.0:
		return
	var r := drawn_radius()
	draw_texture_rect(_white_tex(), Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(tint, p.y))
