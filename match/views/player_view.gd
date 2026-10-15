extends Node2D
## One player, drawn at its feet (server Position is the first solid pixel under the feet): a
## team ring, the character (character_sprite.gd: its art and animations), the HP bar, the name
## and above it the markers of its active status effects (match/status_effects.gd).
## Walking is read from the position changes (prediction or tweens), so callers only move it.

const Status := preload("res://match/status_effects.gd")
const CharacterSprite := preload("res://match/views/character_sprite.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")

const BODY := Vector2(28, 40) # server PlayerHeight = 40
const TEAM_COLORS := {1: Color(0.25, 0.55, 1.0), 2: Color(1.0, 0.35, 0.3)}
const ALLY := Color(0.3, 0.6, 1.0)
const ENEMY := Color(1.0, 0.35, 0.3)
const HP_BAR_WIDTH := 50.0
const ART_TOP := 56.0 # px above the feet the art reaches
const WALK_HOLD := 0.12 # s a walk animation lasts after the last x change

var player_id := ""
var team_id := 1
var is_me := false
var hp := 0
var max_hp := 1
var color := ALLY

var _tween: Tween
var _status: Label
var _name: Label
var _sprite: CharacterSprite
var _ring: Node2D
var _hp_known := false
var _active := false
var _dead := false
var _last_x := 0.0
var _walk_left := 0.0
var _t := 0.0


## my_team: the local player's team; allies are blue, enemies red. -1 colours by team id.
func setup(p: Dictionary, me: bool, my_team: int = -1) -> void:
	player_id = str(p.get("playerId", ""))
	team_id = int(p.get("teamId", 1))
	is_me = me
	if my_team >= 0:
		color = ALLY if team_id == my_team else ENEMY
	else:
		color = TEAM_COLORS.get(team_id, Color.WHITE)
	position = Vector2(float(p["position"]["x"]), float(p["position"]["y"]))
	_last_x = position.x

	_ring = Node2D.new()
	_ring.show_behind_parent = true
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_sprite = CharacterSprite.new()
	_sprite.show_behind_parent = true
	_sprite.character_id = str(p.get("characterId", ""))
	add_child(_sprite)

	_name = LobbyUi.text(str(p.get("displayName", "")), 20, color.lightened(0.55) if not me else LobbyUi.GOLD, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.size = Vector2(200, 26)
	_name.position = Vector2(-100, -ART_TOP - 40)
	add_child(_name)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size = Vector2(200, 24)
	_status.position = Vector2(-100, -ART_TOP - 64)
	_status.add_theme_color_override("font_color", Color(0.75, 0.9, 1))
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 4)
	add_child(_status)
	set_status(p.get("statusEffects"))
	set_hp(int(p.get("hp", 0)), int(p.get("maxHp", 1)))
	if not bool(p.get("isAlive", true)):
		set_dead()


func _process(delta: float) -> void:
	_t += delta
	var dx := position.x - _last_x
	_last_x = position.x
	if absf(dx) > 0.01:
		_walk_left = WALK_HOLD
		_sprite.face(dx)
	else:
		_walk_left = maxf(0.0, _walk_left - delta)
	_sprite.set_walking(_walk_left > 0.0 and not _dead)
	if _active:
		queue_redraw() # the turn arrow bobs


func set_hp(value: int, max_value: int = -1) -> void:
	if _hp_known and value < hp:
		_sprite.hurt()
	_hp_known = true
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
	if _dead:
		return
	_dead = true
	_active = false
	_sprite.die()
	_name.modulate.a = 0.5
	_status.modulate.a = 0.5
	_ring.queue_redraw()
	queue_redraw()


## dir > 0 faces right, < 0 left.
func face(dir: float) -> void:
	_sprite.face(dir)


## Aim angle in degrees (0 right, 90 up, 180 left): face the side it shoots to.
func face_angle(angle: float) -> void:
	if absf(angle - 90.0) > 1.0:
		_sprite.face(1.0 if angle < 90.0 else -1.0)


func facing() -> int:
	return _sprite.facing


## Recoil and muzzle flash (a shot leaves).
func shoot() -> void:
	_sprite.shoot()


## The current player gets a bobbing arrow above the name.
func set_active(on: bool) -> void:
	_active = on and not _dead
	queue_redraw()


func character_id() -> String:
	return _sprite.character_id


## Tweens to target over duration seconds (0 = jump there).
func move_to(target: Vector2, duration: float, trans: Tween.TransitionType = Tween.TRANS_LINEAR, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if _tween:
		_tween.kill()
	if duration <= 0.0:
		position = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(trans).set_ease(ease_type)


func _draw_ring() -> void:
	var c := color if not _dead else Color(0.5, 0.5, 0.55)
	_ring.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	_ring.draw_circle(Vector2.ZERO, 20.0, Color(c, 0.25))
	_ring.draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color(c, 0.9), 3.0, true)
	_ring.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	if _dead:
		return
	# HP bar: dark rounded back, a fill green → yellow → red, a light top line.
	var bar := Rect2(-HP_BAR_WIDTH / 2, -ART_TOP - 12, HP_BAR_WIDTH, 8)
	draw_rect(bar.grow(2), Color(0.02, 0.03, 0.1, 0.85))
	var frac := clampf(float(hp) / max_hp, 0.0, 1.0)
	var fill := Color(1.0, 0.3, 0.25).lerp(Color(1.0, 0.85, 0.2), clampf(frac * 2.0, 0.0, 1.0))
	fill = fill.lerp(Color(0.3, 0.9, 0.35), clampf(frac * 2.0 - 1.0, 0.0, 1.0))
	if frac > 0.0:
		var f := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
		draw_rect(f, fill)
		draw_rect(Rect2(f.position, Vector2(f.size.x, 2)), fill.lightened(0.4))
	if _active:
		var y := -ART_TOP - 48 - absf(sin(_t * 4.0)) * 6.0
		var arrow := PackedVector2Array([Vector2(-10, y - 12), Vector2(10, y - 12), Vector2(0, y)])
		draw_colored_polygon(arrow, LobbyUi.GOLD)
		arrow.append(arrow[0])
		draw_polyline(arrow, Color(0.25, 0.13, 0.02), 2.0, true)
