extends Control
## A status effect landing on a unit, as a picture (no words): its badge (status_glyph.gd; the
## lost-turn mark when the effect skips the turn) pops in big over the unit with a flash of its
## colour and a ring of sparks, settles, then rises and fades (LIFE s) and frees itself. Placed
## like a damage number (match_screen _popup): `position` is the point over the unit.

const StatusGlyph := preload("res://match/views/status_glyph.gd")
const RewardGlow := preload("res://ui/reward_glow.gd")

const PX := 76.0
const LIFE := 1.5

var effect := ""
var _t := 0.0
var _glyph: Control
var _color := Color.WHITE


static func make(effect_id: String, lost_turn: bool = false) -> Control:
	var b = load("res://match/views/status_burst.gd").new()
	b.effect = effect_id
	b._glyph = StatusGlyph.make(effect_id, PX, lost_turn)
	return b


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_color = StatusGlyph.color_of(effect)
	size = Vector2(PX, PX)
	pivot_offset = size / 2.0
	position -= size / 2.0
	_glyph.position = Vector2.ZERO
	add_child(_glyph)
	scale = Vector2.ONE * 0.2
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 1.35, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.55)
	t.tween_property(self, "position:y", position.y - 44.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.55)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var k := clampf(_t / 0.45, 0.0, 1.0)
	# the flash of its colour behind it
	var g := PX * (0.8 + 0.5 * k)
	draw_texture_rect(RewardGlow.radial(), Rect2(c - Vector2(g, g), Vector2(g, g) * 2.0), false, Color(_color, 0.75 * (1.0 - k * 0.6)))
	# a ring of sparks running out
	if k < 1.0:
		for i in 8:
			var at := c + Vector2.from_angle(TAU * i / 8.0 + 0.3) * PX * (0.45 + 0.6 * k)
			RewardGlow.star(self, at, 7.0 * (1.0 - k), Color(_color.lerp(Color.WHITE, 0.5), 1.0 - k))
