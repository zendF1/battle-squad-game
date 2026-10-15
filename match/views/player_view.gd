extends Node2D
## One player, drawn at its feet (server Position is the first solid pixel under the feet).
## Above the name: the markers of its active status effects (match/status_effects.gd).

const Status := preload("res://match/status_effects.gd")

const BODY := Vector2(28, 40) # server PlayerHeight = 40
const TEAM_COLORS := {1: Color(0.25, 0.55, 1.0), 2: Color(1.0, 0.35, 0.3)}
const HP_BAR_WIDTH := 50.0

var player_id := ""
var team_id := 1
var is_me := false
var hp := 0
var max_hp := 1

var _tween: Tween
var _status: Label


func setup(p: Dictionary, me: bool) -> void:
	player_id = str(p.get("playerId", ""))
	team_id = int(p.get("teamId", 1))
	is_me = me
	position = Vector2(float(p["position"]["x"]), float(p["position"]["y"]))
	var name_label := Label.new()
	name_label.text = str(p.get("displayName", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(160, 24)
	name_label.position = Vector2(-80, -BODY.y - 40)
	add_child(name_label)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size = Vector2(200, 24)
	_status.position = Vector2(-100, -BODY.y - 66)
	_status.add_theme_color_override("font_color", Color(0.75, 0.9, 1))
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 4)
	add_child(_status)
	set_status(p.get("statusEffects"))
	set_hp(int(p.get("hp", 0)), int(p.get("maxHp", 1)))
	if not bool(p.get("isAlive", true)):
		set_dead()


func set_hp(value: int, max_value: int = -1) -> void:
	hp = value
	if max_value > 0:
		max_hp = max_value
	queue_redraw()


## effects: the player's statusEffects list (null or [] clears the markers).
func set_status(effects: Variant) -> void:
	_status.text = Status.marker_text(effects)


func status_text() -> String:
	return _status.text


func set_dead() -> void:
	modulate.a = 0.35


## Tweens to target over duration seconds (0 = jump there).
func move_to(target: Vector2, duration: float, trans: Tween.TransitionType = Tween.TRANS_LINEAR, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if _tween:
		_tween.kill()
	if duration <= 0.0:
		position = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(trans).set_ease(ease_type)


func _draw() -> void:
	var body := Rect2(-BODY.x / 2, -BODY.y, BODY.x, BODY.y)
	draw_rect(body, TEAM_COLORS.get(team_id, Color.WHITE))
	if is_me:
		draw_rect(body, Color.WHITE, false, 2.0)
	var bar := Rect2(-HP_BAR_WIDTH / 2, -BODY.y - 12, HP_BAR_WIDTH, 6)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	bar.size.x *= clampf(float(hp) / max_hp, 0.0, 1.0)
	draw_rect(bar, Color(0.3, 0.9, 0.35))
