extends ColorRect
## The blind white-out (063, status blind: the robot's Bom mù): while I am blinded, my own turn
## shows the battlefield behind a strong white glare, a little thinner at the screen's edges, so
## aiming is mostly guesswork; it fades in at my turn's start and out when my shot is answered or
## the turn passes. Purely visual (the server does not change the shot). On the screen layer over
## the world and under the HUD (the controls stay readable). Teammates see the small blindfold on
## my unit instead (StatusLook "blind").
## wanted(): whether it should show now, pure (tests).

const Status := preload("res://match/status_effects.gd")

const EFFECT := "blind"
const FADE_IN := 0.35
const FADE_OUT := 0.3
const CENTRE_ALPHA := 0.94 # the glare in the middle
const EDGE_ALPHA := 0.72 # and at the corners

const SHADER := """
shader_type canvas_item;
uniform float strength = 1.0;
uniform float centre_alpha = 0.94;
uniform float edge_alpha = 0.72;
uniform float time = 0.0;
void fragment() {
	vec2 d = (UV - vec2(0.5)) * vec2(1.0, 0.75) * 2.0;
	float r = length(d);
	float edge = smoothstep(0.55, 1.25, r);
	float shimmer = 0.015 * sin(time * 2.3 + UV.x * 9.0) * sin(time * 1.7 + UV.y * 7.0);
	float a = mix(centre_alpha, edge_alpha, edge) + shimmer;
	vec3 tint = mix(vec3(1.0), vec3(0.93, 0.96, 1.0), edge);
	COLOR = vec4(tint, clamp(a, 0.0, 1.0) * strength);
}
"""

var shown := 0.0 # 0..1 faded in
var _want := false
var _t := 0.0


## The white-out shows: my turn, blind on me, my shot not answered yet.
static func wanted(my_turn: bool, my_effects: Variant, turn_resolved: bool) -> bool:
	return my_turn and not turn_resolved and Status.has(my_effects, EFFECT)


func _init() -> void:
	name = "BlindOverlay"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	color = Color.WHITE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	sm.shader = sh
	sm.set_shader_parameter("centre_alpha", CENTRE_ALPHA)
	sm.set_shader_parameter("edge_alpha", EDGE_ALPHA)
	material = sm
	visible = false
	_apply()


## Turns it on or off (fading).
func set_on(on: bool) -> void:
	_want = on
	if on:
		visible = true


func is_on() -> bool:
	return _want


## Moves the fade on by dt s (called every frame by match_screen, also outside the tree).
func step(dt: float) -> void:
	_t += dt
	if _want:
		shown = minf(1.0, shown + dt / FADE_IN)
	else:
		shown = maxf(0.0, shown - dt / FADE_OUT)
	visible = shown > 0.0
	_apply()


func _apply() -> void:
	var sm := material as ShaderMaterial
	if sm != null:
		sm.set_shader_parameter("strength", shown)
		sm.set_shader_parameter("time", _t)
