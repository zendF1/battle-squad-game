extends ColorRect
## The milestone aura behind an equipment icon: a soft pulsing glow, a coloured ring with a faint
## disc inside it, slowly turning rays (from +10) and sparkles circling the item, all in the
## piece's milestone colour (UpgradeModel: +6 sky blue, +10 orange, +14 purple, +16 red, the
## strongest with the most rays and sparkles). Hidden below +6.
##
## One shader for every aura; one ShaderMaterial per milestone tier shared by all auras of that
## tier, animated by the shader's TIME: nothing runs or allocates per frame in script, so a grid of
## 30+ cards stays cheap. Place it behind the icon, centred on it and about 1.5× its size (it
## draws to the rect's edge): `UpgradeAura.around(icon_px, level)`.

const UpgradeModel := preload("res://screens/home/upgrade_model.gd")

## How much bigger than the icon the aura is drawn.
const SPREAD := 1.55

const SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 tint : source_color = vec4(0.36, 0.8, 1.0, 1.0);
uniform float strength = 0.6;
uniform float rays = 0.0;
uniform float sparkles = 3.0;
uniform float speed = 1.0;
uniform float ring = 1.0;
uniform float pulse_amount = 0.2;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = TIME * speed;
	float pulse = 1.0 - pulse_amount + pulse_amount * sin(t * 2.2);
	float glow = exp(-r * r * 3.0) * strength * pulse;
	float disc = (1.0 - smoothstep(0.5, 0.6, r)) * 0.2 * ring;
	float d_ring = (r - 0.6) / 0.035;
	float edge = exp(-d_ring * d_ring) * 0.85 * ring * pulse;
	float ray = 0.0;
	if (rays > 0.5) {
		float a = atan(p.y, p.x);
		ray = pow(abs(sin(a * rays * 0.5 + t * 0.35)), 10.0) * smoothstep(1.0, 0.45, r) * smoothstep(0.25, 0.5, r) * 0.6 * strength;
	}
	float sp = 0.0;
	for (int i = 0; i < 12; i++) {
		float fi = float(i);
		if (fi >= sparkles) {
			break;
		}
		float ang = fi * 6.2831853 / sparkles + t * (0.35 + 0.08 * mod(fi, 3.0));
		float rad = 0.72 + 0.12 * sin(t * 1.3 + fi * 1.7);
		vec2 q = p - vec2(cos(ang), sin(ang)) * rad;
		float tw = 0.55 + 0.45 * sin(t * 3.1 + fi * 2.3);
		float dot_ = smoothstep(0.06, 0.0, length(q));
		vec2 aq = abs(q);
		float cross_ = smoothstep(0.014, 0.0, min(aq.x, aq.y)) * smoothstep(0.13, 0.0, max(aq.x, aq.y));
		sp += (dot_ + cross_ * 0.8) * tw;
	}
	float v = glow + disc + edge + ray + sp;
	vec3 col = mix(tint.rgb, vec3(1.0), clamp(sp * 0.7 + edge * 0.15, 0.0, 1.0));
	COLOR = vec4(col, clamp(v, 0.0, 1.0));
}
"""

## Per milestone tier (1..4): glow strength, rays, sparkles, speed, ring, pulse.
const LOOKS := [
	{},
	{"strength": 0.5, "rays": 0.0, "sparkles": 3.0, "speed": 0.8, "ring": 0.8, "pulse_amount": 0.15},
	{"strength": 0.65, "rays": 6.0, "sparkles": 4.0, "speed": 1.0, "ring": 1.0, "pulse_amount": 0.18},
	{"strength": 0.8, "rays": 8.0, "sparkles": 6.0, "speed": 1.2, "ring": 1.0, "pulse_amount": 0.2},
	{"strength": 1.0, "rays": 12.0, "sparkles": 10.0, "speed": 1.5, "ring": 1.15, "pulse_amount": 0.25},
]

static var _shader: Shader
static var _materials := {} # tier -> ShaderMaterial

var level := 0:
	set = set_level


func _init() -> void:
	color = Color.WHITE
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


## An aura for an icon of icon_px at `level`, sized and offset to sit centred on an icon placed at
## (0, 0) in the same parent.
static func around(icon_px: float, at_level: int) -> Control:
	var a = new()
	var s := icon_px * SPREAD
	a.size = Vector2(s, s)
	a.custom_minimum_size = Vector2.ZERO
	a.position = Vector2(-(s - icon_px) / 2.0, -(s - icon_px) / 2.0)
	a.level = at_level
	return a


## Centres the aura on a rect (the icon's, in the aura's parent).
func center_on(rect: Rect2) -> void:
	var s := maxf(rect.size.x, rect.size.y) * SPREAD
	size = Vector2(s, s)
	position = rect.get_center() - size / 2.0


func set_level(v: int) -> void:
	level = v
	var tier := UpgradeModel.milestone_tier(v)
	visible = tier > 0
	if tier > 0:
		material = material_for(tier)


## The shared material of a milestone tier (1..4).
static func material_for(tier: int) -> ShaderMaterial:
	tier = clampi(tier, 1, LOOKS.size() - 1)
	var m: ShaderMaterial = _materials.get(tier)
	if m != null:
		return m
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	m = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", UpgradeModel.MILESTONE_COLORS[tier])
	var look: Dictionary = LOOKS[tier]
	for k in look:
		m.set_shader_parameter(k, look[k])
	_materials[tier] = m
	return m
