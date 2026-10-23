extends "res://match/result_popup.gd"
## "LÊN CẤP!" over the result screen (match/result_screen.gd opens it once the EXP bar has
## filled): one card per stage of ResultModel.level_ups(), side by side, the player's level first
## ("CẤP NGƯỜI CHƠI", a big gold medal) then my character's (its name, the character in pose over
## a smaller medal); the second card waits dimmed for its turn. Each card counts its level up from
## the old one, one level per step: the number pops in with sparks, a ring and a glow; the last
## step bursts bigger, turns rays on behind the cards and shows "Lv.3 → Lv.5". setup(stages)
## before it enters the tree.

const CharacterView := preload("res://ui/character_view.gd")

const CARD := Vector2(400, 420)
const CARD_GAP := 60.0
const STEP_MAX := 0.5 # a step's time, shorter for many levels (all of a card's steps: about COUNT_SEC)
const STEP_MIN := 0.16
const COUNT_SEC := 1.6
const SPARKS := [Color(1.0, 0.86, 0.3), Color(1.0, 0.97, 0.75), Color(1.0, 0.6, 0.2), Color(0.55, 0.85, 1.0)]

var stages: Array = []
var _title: Label
const DIGIT_LIFT := 0.15

var _cards: Array = [] # {node, medal, number, line, stage}
var _rays_on: Dictionary = {}


func setup(value: Array) -> void:
	stages = value


func build() -> void:
	_title = label("LÊN CẤP!", 112, GOLD, 24)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_title.add_theme_constant_override("shadow_offset_y", 8)
	stage.add_child(_title)
	for s in stages:
		_cards.append(_card(s))


func _card(s: Dictionary) -> Dictionary:
	var card := Panel.new()
	card.size = CARD
	card.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", LobbyUi.box(Color(0.07, 0.11, 0.3, 0.96), 30, 0, Color(1.0, 0.8, 0.22, 0.9), 5))
	stage.add_child(card)
	var player: bool = s["kind"] == "player"
	var caption := label("CẤP NGƯỜI CHƠI" if player else str(s["name"]).to_upper(), 30, Color(0.75, 0.85, 1.0), 6)
	place(caption, CARD.x / 2.0, 44, CARD.x - 40, 44)
	card.add_child(caption)
	var medal := Medal.new()
	var r := 112.0 if player else 66.0
	medal.size = Vector2(r, r) * 2.0
	medal.position = Vector2(CARD.x / 2.0 - r, (222.0 if player else 284.0) - r)
	card.add_child(medal)
	if not player:
		var art := CharacterView.new()
		art.character_id = str(s["character_id"])
		art.idle = true
		art.size = Vector2(200, 170)
		art.position = Vector2(CARD.x / 2.0 - 100, 62)
		art.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(art)
		card.move_child(art, medal.get_index()) # the medal over the feet
	var fs := 120 if player else 68
	var number := label(str(s["from"]), fs, Color.WHITE, 18 if player else 12)
	number.add_theme_color_override("font_outline_color", Color(0.45, 0.2, 0.02))
	# The medal's only content, dead centre: digits sit low in the line box (its ascent leaves
	# room for Vietnamese marks), so the box is lifted DIGIT_LIFT of the font size.
	place(number, r, r - fs * DIGIT_LIFT, r * 2.0, r * 1.2)
	medal.add_child(number)
	var line := label("Lv.%d → Lv.%d" % [s["from"], s["to"]], 30, Color(0.6, 1.0, 0.65), 6)
	place(line, CARD.x / 2.0, CARD.y - 40, CARD.x - 40, 44)
	line.modulate.a = 0.0
	card.add_child(line)
	return {"node": card, "medal": medal, "number": number, "line": line, "stage": s}


func layout() -> void:
	var c := center()
	var n := _cards.size()
	var total := n * CARD.x + maxi(n - 1, 0) * CARD_GAP
	var top := c.y - CARD.y / 2.0 + 10.0
	place(_title, c.x, top - 92.0, size.x, 140)
	for i in n:
		var card: Control = _cards[i]["node"]
		card.position = Vector2(c.x - total / 2.0 + i * (CARD.x + CARD_GAP), top)
		card.pivot_offset = CARD / 2.0
	if not _rays_on.is_empty():
		_rays_on["at"] = Vector2(c.x, top + CARD.y * 0.45)


func play() -> void:
	_title.scale = Vector2.ONE * 2.2
	_title.modulate.a = 0.0
	seq.tween_property(_title, "modulate:a", 1.0, 0.12)
	seq.parallel().tween_property(_title, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _cards.size():
		var card: Control = _cards[i]["node"]
		card.scale = Vector2.ONE * 0.6
		card.modulate.a = 0.0
		seq.parallel().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08 * i)
		seq.parallel().tween_property(card, "modulate", Color(1, 1, 1, 1) if i == 0 else Color(0.55, 0.58, 0.7, 1), 0.2).set_delay(0.08 * i)
	for i in _cards.size():
		var k: Dictionary = _cards[i]
		seq.tween_interval(0.3)
		if i > 0:
			seq.tween_property(k["node"], "modulate", Color.WHITE, 0.2)
		var steps: Array = k["stage"]["steps"]
		var step := clampf(COUNT_SEC / maxf(steps.size(), 1.0), STEP_MIN, STEP_MAX)
		for j in steps.size():
			seq.tween_callback(_tick.bind(k, int(steps[j]), j == steps.size() - 1))
			seq.tween_interval(step if j < steps.size() - 1 else 0.45)
	seq.tween_callback(done_playing)


## One level up on a card: the number pops, with sparks, a ring and a glow; bigger on the last.
func _tick(k: Dictionary, level: int, last: bool) -> void:
	var number: Label = k["number"]
	var medal: Control = k["medal"]
	number.text = str(level)
	pop(number, 1.9 if last else 1.6, 0.34)
	var at := centre_of(medal)
	var r: float = medal.size.x / 2.0
	burst(at, SPARKS, 34 if last else 16, 520.0 if last else 340.0, 12.0 if last else 9.0)
	ring(at, Color(1.0, 0.9, 0.45), r, r * (2.4 if last else 1.8), 0.55, 10.0 if last else 6.0)
	glow(at, Color(1.0, 0.85, 0.4), r * 2.2, 0.6)
	medal.set("shine", 1.0)
	if last:
		var line: Label = k["line"]
		line.modulate.a = 1.0
		pop(line, 0.4, 0.3)
		_light_rays()


func _light_rays() -> void:
	if _rays_on.is_empty():
		_rays_on = rays(Vector2.ZERO, [Color(1.0, 0.85, 0.35), Color(1.0, 0.97, 0.8)], maxf(size.x, size.y), 0.15, 20)
		layout()


func show_end() -> void:
	_title.scale = Vector2.ONE
	_title.modulate.a = 1.0
	for k in _cards:
		var card: Control = k["node"]
		card.scale = Vector2.ONE
		card.modulate = Color.WHITE
		k["number"].text = str(k["stage"]["to"])
		k["number"].scale = Vector2.ONE
		k["line"].modulate.a = 1.0
		k["line"].scale = Vector2.ONE
	_light_rays()


## The round gold medal: a dark outline, a gold rim with a light bevel, a navy face; `shine`
## (1 on a step, fading) lights the rim.
class Medal extends Control:
	var shine := 0.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if shine > 0.0:
			shine = maxf(shine - delta * 2.0, 0.0)
			queue_redraw()

	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		draw_circle(c + Vector2(0, r * 0.06), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, Color(0.07, 0.07, 0.14))
		draw_circle(c, r * 0.94, Color(0.85, 0.45, 0.08).lerp(Color(1, 0.95, 0.7), shine * 0.6))
		draw_circle(c + Vector2(0, -r * 0.03), r * 0.86, Color(1.0, 0.8, 0.22).lerp(Color.WHITE, shine * 0.5))
		draw_circle(c, r * 0.76, Color(0.07, 0.07, 0.14))
		draw_circle(c, r * 0.72, Color(0.13, 0.2, 0.5))
		draw_circle(c + Vector2(0, r * 0.12), r * 0.6, Color(0.1, 0.15, 0.4))
		draw_arc(c, r * 0.9, PI * 1.1, PI * 1.6, 24, Color(1, 1, 1, 0.55), r * 0.05, true)
