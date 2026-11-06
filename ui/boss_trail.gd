extends HBoxContainer
## A boss's bonus runs of the day as pictures (ui/boss_trail_model.gd): one pip per win the gold
## chest needs (a green check for a win, a red cross for a loss, an empty ring for a run still to
## play), a small arrow, then the gold chest the wins lead to: bright while it can be earned, grey
## once it is lost for today, glowing with a check on its corner when earned. No numbers, no words.
## The boss card, the lobby's mode card and the boss result draw it; make() fills it and pop() lets
## the result screen bring in this run's pip and the chest.

const LobbyUi := preload("res://ui/lobby_ui.gd")
const ChestIcon := preload("res://ui/chest_icon.gd")
const RewardGlow := preload("res://ui/reward_glow.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const TrailModel := preload("res://ui/boss_trail_model.gd")

const WIN_COLOR := Color(0.2, 0.74, 0.38)
const LOSS_COLOR := Color(0.82, 0.24, 0.26)
const OPEN_FILL := Color(0.04, 0.06, 0.16, 0.7)
const OPEN_RING := Color(1, 1, 1, 0.42)
const GREY_SHADER := """
shader_type canvas_item;
void fragment() {
	float v = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(vec3(mix(v, 0.5, 0.35)), COLOR.a * 0.8);
}
"""

## The pips left to right, then the chest's holder.
var pips: Array[Control] = []
var chest: Control


static func make(trail: Dictionary, pip_px: int = 28, chest_px: int = 40) -> HBoxContainer:
	var t = load("res://ui/boss_trail.gd").new()
	t.name = "Trail"
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.mouse_filter = MOUSE_FILTER_IGNORE
	t.add_theme_constant_override("separation", maxi(pip_px / 5, 3))
	for i in trail.get("pips", []).size():
		var p := _pip(str(trail["pips"][i]), pip_px)
		p.name = "Pip%d" % i
		t.add_child(p)
		t.pips.append(p)
	var arrow := LobbyUi.icon("arrow_right", maxi(pip_px * 2 / 3, 14))
	arrow.name = "Arrow"
	arrow.size_flags_vertical = SIZE_SHRINK_CENTER
	arrow.modulate = Color(1, 1, 1, 0.7)
	arrow.mouse_filter = MOUSE_FILTER_IGNORE
	t.add_child(arrow)
	t.chest = _gold(trail, chest_px)
	t.add_child(t.chest)
	return t


## Brings the pip at `index` (this run's) and, with `gold`, the chest in with a bounce after `delay` s.
func pop(index: int, gold: bool, delay: float = 0.0) -> void:
	if index >= 0 and index < pips.size():
		_bounce(pips[index], delay)
	if gold:
		_bounce(chest, delay + 0.25)


func _bounce(c: Control, delay: float) -> void:
	c.pivot_offset = c.custom_minimum_size / 2.0
	c.scale = Vector2.ONE * 0.2
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _pip(state: String, px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.size_flags_vertical = SIZE_SHRINK_CENTER
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.set_meta("state", state)
	c.draw.connect(func() -> void: _draw_pip(c, state))
	return c


static func _draw_pip(c: Control, state: String) -> void:
	var r := minf(c.size.x, c.size.y) / 2.0
	var o := c.size / 2.0
	var w := maxf(r * 0.28, 2.0)
	match state:
		TrailModel.WIN:
			c.draw_circle(o, r, WIN_COLOR, true, -1.0, true)
			c.draw_arc(o, r - 1.0, 0.0, TAU, 32, Color(1, 1, 1, 0.75), 2.0, true)
			c.draw_polyline(PackedVector2Array([o + Vector2(-0.48, 0.03) * r, o + Vector2(-0.12, 0.38) * r, o + Vector2(0.5, -0.36) * r]),
				Color.WHITE, w, true)
		TrailModel.LOSS:
			c.draw_circle(o, r, LOSS_COLOR, true, -1.0, true)
			c.draw_arc(o, r - 1.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 2.0, true)
			for d in [Vector2(0.38, 0.38), Vector2(0.38, -0.38)]:
				c.draw_line(o - d * r, o + d * r, Color.WHITE, w, true)
		_:
			c.draw_circle(o, r, OPEN_FILL, true, -1.0, true)
			c.draw_arc(o, r - 1.0, 0.0, TAU, 32, OPEN_RING, 2.0, true)


## The gold chest: over its glow while it can be earned or was, grey once lost.
static func _gold(trail: Dictionary, px: int) -> Control:
	var state := str(trail.get("gold", TrailModel.LOST))
	var id := str(trail.get("gold_chest", TrailModel.GOLD_CHEST))
	var holder := Control.new()
	holder.name = "Gold"
	holder.custom_minimum_size = Vector2(px, px)
	holder.size_flags_vertical = SIZE_SHRINK_CENTER
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	holder.set_meta("state", state)
	if state != TrailModel.LOST:
		var g: Control = RewardGlow.make(RewardModel.glow({"kind": "chest", "id": id}), Vector2(px, px) * 1.3)
		g.name = "Glow"
		g.position = -Vector2(px, px) * 0.15
		g.reach = 1.0
		holder.add_child(g)
	var icon := ChestIcon.make(id, px)
	icon.name = "Chest"
	if state == TrailModel.LOST:
		var sh := Shader.new()
		sh.code = GREY_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		icon.material = m
	holder.add_child(icon)
	if state == TrailModel.WON:
		var check := _pip(TrailModel.WIN, maxi(px * 9 / 20, 14))
		check.name = "Earned"
		check.position = Vector2(px, px) - check.custom_minimum_size + Vector2(px, px) * 0.08
		check.size = check.custom_minimum_size
		holder.add_child(check)
	return holder
