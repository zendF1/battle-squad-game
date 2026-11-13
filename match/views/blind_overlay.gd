extends ColorRect
## The blind white-out (status blind: Đĩa Bay Thép's Bom mù, round 2): while I am blinded the whole
## screen is white except a small clear circle round my own unit (CLEAR_BODIES × my figure's height
## on screen, a soft edge), which follows it wherever it goes (the camera moves, it walks, falls);
## nobody else's circle shows (each player sees only their own, on their own screen). It lasts as
## long as the status is on me: from the flash (its status event in the replay) until the end of my
## next own turn (the server ticks it there; turns 1), every turn in between, fading in and out.
## Purely visual (the server does not change the shot). On the screen layer over the world and under
## the HUD (the controls stay readable). Teammates and spectators see the small blindfold on my unit
## instead (StatusLook "blind").
## wanted() and clear_circle() are pure (tests).

const Status := preload("res://match/status_effects.gd")

const EFFECT := "blind"
const FADE_IN := 0.35
const FADE_OUT := 0.3
const GLARE := 0.97 # the white-out's alpha outside the circle
const CLEAR_BODIES := 1.5 # the clear circle's radius: × my figure's height (on screen)
const SOFT := 0.4 # the share of the radius its edge fades over

const SHADER := """
shader_type canvas_item;
uniform float strength = 1.0;
uniform float glare = 0.97;
uniform vec2 rect_size = vec2(1.0);
uniform vec2 centre = vec2(-10000.0);
uniform float radius = 0.0;
uniform float soft = 1.0;
uniform float time = 0.0;
void fragment() {
	vec2 p = UV * rect_size;
	float d = distance(p, centre);
	float out_k = smoothstep(radius - soft, radius, d);
	float shimmer = 0.012 * sin(time * 2.3 + UV.x * 9.0) * sin(time * 1.7 + UV.y * 7.0);
	vec3 tint = mix(vec3(0.93, 0.96, 1.0), vec3(1.0), out_k);
	COLOR = vec4(tint, clamp(glare * out_k + shimmer * out_k, 0.0, 1.0) * strength);
}
"""

var shown := 0.0 # 0..1 faded in
var _want := false
var _t := 0.0
var _centre := Vector2(-10000, -10000) # the clear circle (px on this rect: the screen)
var _radius := 0.0


## The white-out shows: I am alive and blinded.
static func wanted(alive: bool, my_effects: Variant) -> bool:
	return alive and Status.has(my_effects, EFFECT)


## My clear circle on screen from my unit's canvas transform (its feet; get_global_transform_with_canvas())
## and its figure's height (world px): {centre: the figure's middle, radius: CLEAR_BODIES × its height,
## both scaled by the camera's zoom}.
static func clear_circle(canvas_xform: Transform2D, figure_height: float) -> Dictionary:
	var zoom := absf(canvas_xform.get_scale().x)
	return {"centre": canvas_xform * Vector2(0, -figure_height * 0.5), "radius": CLEAR_BODIES * figure_height * zoom}


func _init() -> void:
	name = "BlindOverlay"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	color = Color.WHITE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	sm.shader = sh
	sm.set_shader_parameter("glare", GLARE)
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


## Where my clear circle is now (px on the screen; radius 0: none, all white).
func set_clear(centre: Vector2, radius: float) -> void:
	_centre = centre
	_radius = maxf(radius, 0.0)


## {centre, radius} of the clear circle (tests).
func clear() -> Dictionary:
	return {"centre": _centre, "radius": _radius}


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
		sm.set_shader_parameter("rect_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
		sm.set_shader_parameter("centre", _centre)
		sm.set_shader_parameter("radius", _radius)
		sm.set_shader_parameter("soft", maxf(_radius * SOFT, 1.0))
