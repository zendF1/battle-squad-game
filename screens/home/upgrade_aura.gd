extends ColorRect
## The milestone aura of an upgraded piece: a glowing outline in its milestone colour hugging the
## frame its icon sits in (the hexagon of the Nhân vật slots, the piece popup, the Nâng cấp centre
## and the Prep row; the rounded rectangle of the Túi đồ cards and of the list icons), with bright
## streaks running round the border, sparks drifting off it and a flickering, fire-like outer glow.
## Brighter, faster, with more streaks and sparks per tier (UpgradeModel: +1 green the subtlest, a
## thin outline and one slow streak; +6 sky blue, +10 orange, +14 purple, +16 red the strongest).
## Hidden at +0. The inside of the frame stays readable: the
## glow inward falls off within a few pixels.
##
## One shader for every aura: the signed distance to a rounded pointy-top hexagon or a rounded
## rectangle, a perimeter parameter (the angle around the centre) for the running streaks and the
## sparks, all animated by the shader's TIME. The aura's size in pixels comes from the UV
## derivatives, so one ShaderMaterial per tier × shape × fit serves every size and is shared by all
## those auras: nothing runs or allocates per frame in script, a grid of 30+ cards stays cheap.
##
## Two fits:
## - around_frame(): the aura rect is the frame grown by the glow's room (PAD), the line on the
##   frame's edge, the glow spilling around it (hexagon frames on open ground);
## - inside(): the aura rect is the frame itself, the line inset so the glow stays within it
##   (cards and icons in a scroll area, which would clip a glow sticking out).

const UpgradeModel := preload("res://screens/home/upgrade_model.gd")

enum Shape { RECT, HEX }

## around_frame(): the glow's room around the frame, a fraction of the aura rect's smaller side.
const PAD := 0.12
## The hexagon inside its frame texture (assets/icons/equipment/hex_*.png fill ~97.5% of it).
const HEX_FIT := 0.975

const SHADER_CODE := """
shader_type canvas_item;
// Premultiplied: mostly additive light, but part of what is under it is covered (`cover`), so a
// dark-blue background does not turn red into pink or violet into lavender.
render_mode blend_premul_alpha, unshaded;

uniform vec4 tint : source_color = vec4(0.36, 0.8, 1.0, 1.0); // the line and streaks
uniform vec4 flame_tint : source_color = vec4(0.2, 0.6, 1.0, 1.0); // the outer glow and flame
uniform vec4 core_tint : source_color = vec4(0.85, 0.97, 1.0, 1.0); // the thin hot core of a streak
uniform float cover = 0.5;
uniform float shape = 1.0; // 0 rounded rectangle, 1 pointy-top hexagon
uniform float pad = 0.12; // room for the outer glow, fraction of the smaller side
uniform float radius = 0.08; // corner radius, fraction of the smaller side
uniform float hex_fit = 0.975;
uniform float strength = 0.7;
uniform float line_scale = 1.0; // × the line's width (green: thinner)
uniform float streaks = 1.0;
uniform float sparks = 3.0;
uniform float speed = 0.25; // laps per second of the streaks
uniform float flicker = 0.4;
uniform float tail = 0.08; // a streak's length, fraction of the perimeter
uniform float streak_width = 1.0; // × the line's width
uniform float streak_gain = 1.0;
uniform float flame = 0.0; // the streaks' outer glow (fire spilling off the frame)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// A pointy-top hexagon filling the half extents b, its corners rounded by r.
float sd_hex(vec2 p, vec2 b, float r) {
	b -= r;
	p = abs(p);
	vec2 top = vec2(0.0, b.y);
	vec2 corner = vec2(b.x, b.y * 0.5);
	vec2 n = normalize(vec2(b.y * 0.5, b.x));
	float d1 = p.x - b.x;
	float d2 = dot(p - top, n);
	float d = d1 < 0.0 && d2 < 0.0 ? max(d1, d2) : min(seg(p, top, corner), seg(p, corner, vec2(b.x, 0.0)));
	return d - r;
}

void fragment() {
	vec4 base = COLOR;
	vec2 S = 1.0 / max(fwidth(UV), vec2(1e-5));
	float m = min(S.x, S.y);
	float pd = pad * m;
	vec2 b = S * 0.5 - pd;
	vec2 p = (UV - 0.5) * S;
	float r = radius * m;
	float d = shape > 0.5 ? sd_hex(p, b * hex_fit, r) : sd_box(p, b, r);
	float w = max(1.1, m * 0.014) * line_scale; // the line's half width
	float sw = w * streak_width;
	float reach_in = max(w * 6.0, sw * 2.6);
	if (d < -reach_in) {
		discard;
	}
	float g = max(pd * 0.85, w * 2.5); // the outer glow's reach
	float t = TIME;
	float ang = atan(p.y / max(b.y, 1.0), p.x / max(b.x, 1.0));
	float u = ang / 6.2831853 + 0.5; // 0..1 round the border
	vec2 ring = vec2(cos(ang), sin(ang));
	// Flame-like flicker: a moving noise field sampled round the border (seamless).
	float n1 = noise(ring * 3.2 + vec2(t * 1.9, -t * 1.3));
	float n2 = noise(ring * 7.5 + vec2(-t * 2.7, t * 2.1) + 11.0);
	float fl = mix(1.0, 0.35 + 1.4 * n1 * (0.5 + n2), flicker);
	float line = exp(-(d * d) / (w * w));
	float glow = d > 0.0 ? exp(-d / (g * (0.35 + 0.5 * fl))) * (0.45 + 0.4 * fl) : exp(d / (w * 2.5)) * 0.5;
	// Streaks running round the border: a bright head with a tail fading over `tail` of the
	// perimeter, a thick core and (purple, red) a flame spilling off the frame.
	float st = 0.0; // streak cores
	float sf = 0.0; // streak flames
	float hot = 0.0; // the thin hot centre of the streaks
	for (int i = 0; i < 4; i++) {
		if (float(i) >= streaks) {
			break;
		}
		float head = fract(t * speed + float(i) / streaks);
		float back = fract(head - u);
		float f = back < tail ? pow(1.0 - back / tail, 1.6) : exp(-(1.0 - back) * 120.0);
		float core = exp(-(d * d) / (sw * sw * 2.5));
		float spill = d > 0.0 ? exp(-d / (g * (0.45 + 0.4 * fl))) : exp(d / (sw * 0.7));
		st += f * core;
		sf += f * spill * flame * (0.5 + 0.5 * fl);
		hot += f * exp(-(d * d) / (w * w * 0.6));
	}
	st *= streak_gain;
	sf *= streak_gain;
	// Sparks leaving the border and fading outward.
	float sp = 0.0;
	float perimeter = (shape > 0.5 ? 3.2 : 4.0) * (b.x + b.y);
	for (int j = 0; j < 12; j++) {
		if (float(j) >= sparks) {
			break;
		}
		float fj = float(j);
		float rate = 0.45 + 0.12 * mod(fj, 4.0);
		float phase = t * rate + hash(vec2(fj, 1.7));
		float life = fract(phase);
		float su = fract(hash(vec2(fj, floor(phase))) + life * 0.04);
		float du = (fract(u - su + 0.5) - 0.5) * perimeter;
		float dr = d - life * g * 1.2;
		float sz = w * (1.9 - 1.2 * life);
		sp += exp(-(du * du + dr * dr) / (sz * sz)) * (1.0 - life) * 1.5;
	}
	// Everything fades out before the rect's edge (no visible box round the frame).
	float room = 1.0 - smoothstep(pd * 0.5, pd * 0.97, d);
	float wl = line * 0.6 * strength;
	float wg = glow * strength;
	float ws = st * (0.7 + 0.5 * strength);
	float wf = sf * (0.7 + 0.5 * strength);
	float v = (wl + wg + ws + wf + sp) * room;
	vec3 col = (tint.rgb * (wl + ws) + flame_tint.rgb * (wg + wf) + mix(tint.rgb, core_tint.rgb, 0.6) * sp) / max(wl + wg + ws + wf + sp, 1e-4);
	col = mix(col, core_tint.rgb, clamp(hot * streak_gain * 0.6, 0.0, 0.6));
	vec2 e = min(UV, 1.0 - UV) * S;
	// Fade out before the cut inside too (no visible step).
	float a = clamp(v, 0.0, 1.0) * smoothstep(0.0, 2.0, min(e.x, e.y)) * smoothstep(-reach_in, -reach_in * 0.6, d);
	a *= base.a;
	COLOR = vec4(col * a, a * cover);
}
"""

## Per colour tier (1..5): colours (UpgradeModel.TIER_COLORS for the line and streaks, a
## saturated flame for the glow, a thin hot core: never pure white, so red reads fire-red, not
## pink), how much of the background it covers, glow strength, streaks (count, length as a fraction of the
## perimeter, width, brightness, flame spilling off the frame), sparks, speed (laps / s), flicker.
## Green the subtlest (thin, dim, one slow streak, one spark); sky blue and orange stay subtle;
## purple and red get big, thick, fiery streaks.
const LOOKS := [
	{},
	{"flame_tint": Color(0.22, 0.95, 0.3), "core_tint": Color(0.8, 1.0, 0.82), "cover": 0.32,
		"strength": 0.5, "line_scale": 0.85, "streaks": 1.0, "tail": 0.07, "streak_width": 1.0, "streak_gain": 0.75,
		"flame": 0.0, "sparks": 1.0, "speed": 0.14, "flicker": 0.2},
	{"flame_tint": Color(0.18, 0.62, 1.0), "core_tint": Color(0.82, 0.96, 1.0), "cover": 0.35,
		"strength": 0.6, "streaks": 1.0, "tail": 0.08, "streak_width": 1.1, "streak_gain": 0.9, "flame": 0.0,
		"sparks": 2.0, "speed": 0.22, "flicker": 0.3},
	{"flame_tint": Color(1.0, 0.42, 0.04), "core_tint": Color(1.0, 0.88, 0.6), "cover": 0.45,
		"strength": 0.8, "streaks": 2.0, "tail": 0.1, "streak_width": 1.3, "streak_gain": 1.0, "flame": 0.25,
		"sparks": 4.0, "speed": 0.26, "flicker": 0.55},
	{"flame_tint": Color(0.5, 0.12, 1.0), "core_tint": Color(0.86, 0.72, 1.0), "cover": 0.6,
		"strength": 0.95, "streaks": 3.0, "tail": 0.2, "streak_width": 2.2, "streak_gain": 1.5, "flame": 0.9,
		"sparks": 6.0, "speed": 0.3, "flicker": 0.65},
	{"flame_tint": Color(1.0, 0.16, 0.0), "core_tint": Color(1.0, 0.88, 0.63), "cover": 0.7,
		"strength": 1.15, "streaks": 4.0, "tail": 0.17, "streak_width": 2.7, "streak_gain": 1.9, "flame": 1.2,
		"sparks": 10.0, "speed": 0.34, "flicker": 0.85},
]

static var _shader: Shader
static var _materials := {} # "tier|shape|pad|radius" -> ShaderMaterial

var level := 0:
	set = set_level
var shape := Shape.HEX
var pad := PAD
var radius := 0.08


func _init() -> void:
	color = Color.WHITE
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


## An aura on the edge of a frame of `frame_size` placed at (0, 0) in the same parent, its glow
## spilling around it. corner: the corner radius as a fraction of the frame's smaller side.
static func around_frame(frame_size: Vector2, at_level: int, frame_shape: Shape = Shape.HEX, corner: float = 0.08) -> Control:
	var a = new()
	a.fit_frame(Rect2(Vector2.ZERO, frame_size), frame_shape, corner)
	a.level = at_level
	return a


## An aura filling `rect_size` at (0, 0) in its parent, its line inset by `inset_px` so the glow
## stays inside (cards and icons in a scroll area). corner_px: the line's corner radius.
static func inside(rect_size: Vector2, at_level: int, inset_px: float = 8.0, corner_px: float = 12.0, frame_shape: Shape = Shape.RECT) -> Control:
	var a = new()
	var m := maxf(minf(rect_size.x, rect_size.y), 1.0)
	a.shape = frame_shape
	a.pad = snappedf(inset_px / m, 0.005)
	a.radius = snappedf(corner_px / m, 0.005)
	a.position = Vector2.ZERO
	a.size = rect_size
	a.level = at_level
	return a


## Places the aura around a frame rect (in the aura's parent): the rect grown by the glow's room,
## so the line lies on the frame's edge.
func fit_frame(frame: Rect2, frame_shape: Shape = Shape.HEX, corner: float = 0.08) -> void:
	shape = frame_shape
	pad = PAD
	var small := minf(frame.size.x, frame.size.y)
	var grow := PAD * small / (1.0 - 2.0 * PAD)
	radius = snappedf(corner * small / (small + 2.0 * grow), 0.005)
	position = frame.position - Vector2(grow, grow)
	size = frame.size + Vector2(grow, grow) * 2.0
	_apply()


func set_level(v: int) -> void:
	level = v
	_apply()


func _apply() -> void:
	var tier := UpgradeModel.color_tier(level)
	visible = tier > 0
	if tier > 0:
		material = material_for(tier, shape, pad, radius)


## The shared material of a colour tier (1..5), a shape and a fit.
static func material_for(tier: int, frame_shape: Shape = Shape.HEX, at_pad: float = PAD, corner: float = 0.08) -> ShaderMaterial:
	tier = clampi(tier, 1, LOOKS.size() - 1)
	var key := "%d|%d|%.3f|%.3f" % [tier, frame_shape, at_pad, corner]
	var m: ShaderMaterial = _materials.get(key)
	if m != null:
		return m
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	m = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", UpgradeModel.TIER_COLORS[tier])
	m.set_shader_parameter("shape", 1.0 if frame_shape == Shape.HEX else 0.0)
	m.set_shader_parameter("pad", at_pad)
	m.set_shader_parameter("radius", corner)
	m.set_shader_parameter("hex_fit", HEX_FIT)
	var look: Dictionary = LOOKS[tier]
	for k in look:
		m.set_shader_parameter(k, look[k])
	_materials[key] = m
	return m
