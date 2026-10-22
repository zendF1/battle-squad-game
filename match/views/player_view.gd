extends Node2D
## One player, drawn at its feet (server Position is the first solid pixel under the feet): a
## team ring, the character (scenes/character/character.tscn: its art and animations) holding the
## gun of the weapon it brought (weaponItemId → EquipmentModel.gun()), the HP bar, the name,
## above it the small plate of the title it wears (the payload's "title", TitleModel; none for
## bots: nothing drawn, no gap) and above that the markers of its armed shot modifiers
## (match/status_effects.gd); the turn arrow rises over the plate too. Right of the HP bar, small
## round icons for its control / damage effects (burn, root, stun, freeze, net) and its shield
## (match/views/status_icons.gd); the shield also shows on the HP bar as a light-blue segment after
## the HP (the bar then spans HP + shield when they pass the max HP).
## Walking is read from the position changes (prediction or tweens), so callers only move it.
## Idle, the character stands breathing with the gun in its hand in a low carry, 45° down-forward
## (scenes/character/character.gd holster + idle_gun); walking slings it across the back: aim() /
## draw_gun() kneel on the ready pose and turn it up, shoot() fires it (returning the wait while
## it is drawn), clear_aim() and the end of a shot stand it up again in the low carry. aim_sweep() shows a remote player aiming (server PlayerAiming): the gun drawn and
## swung onto the aim over its duration (match/aim/aim_sweep.gd), held there until the shot. The
## gun only ever shows one of 7 directions (scenes/character/aim_snap.gd), so a sweep steps
## between them.
## Skill energy (set_skill_energy(), the value on screen): at 100 (the skill ready) a looping
## aura surrounds the character (energy_aura.gd, behind the body) until it drops (the skill
## fired, a resync) or the player dies. What the player uses (a skill, a shot item, an instant
## item) pops up as a badge over everything above its head (use_badge.gd, show_badge()).

const AimSweep := preload("res://match/aim/aim_sweep.gd")
const AimSnap := preload("res://scenes/character/aim_snap.gd")
const Status := preload("res://match/status_effects.gd")
const StatusIcons := preload("res://match/views/status_icons.gd")
const CharacterScene := preload("res://scenes/character/character.tscn")
const Art := preload("res://ui/art.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const TitleModel := preload("res://screens/home/title_model.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const EnergyAura := preload("res://match/views/energy_aura.gd")
const UseBadge := preload("res://match/views/use_badge.gd")
const Skills := preload("res://match/skills.gd")

const BODY := Vector2(28, 40) # server PlayerHeight = 40
## px per art unit: the baked art (about 150 units) stands about 52 px tall over the 28x40
## body; a side view (Rookie) is drawn at its own pxPerUnit, about 60 px tall.
const ART_SCALE := 0.35
const TEAM_COLORS := {1: Color(0.25, 0.55, 1.0), 2: Color(1.0, 0.35, 0.3)}
const ALLY := Color(0.3, 0.6, 1.0)
const ENEMY := Color(1.0, 0.35, 0.3)
const HP_BAR_WIDTH := 50.0
const ICON_SIZE := 22.0 # the status icons right of the HP bar
const ICON_GAP := 2.0
const SHIELD_COLOR := Color(0.62, 0.9, 1.0)
const ART_TOP := 56.0 # px above the feet the art reaches (at least; a taller side view raises it)
const WALK_HOLD := 0.12 # s a walk animation lasts after the last x change
const TITLE_H := 34.0 # the title plate over the name
const TITLE_FONT := 14
const TITLE_MAX_W := 220.0
const BADGE_GAP := 4.0 # px between the badge and what is under it
const BADGE_LIFT := 26.0 # px the badge rises over the shot markers / the turn arrow when shown

var player_id := ""
var team_id := 1
var is_me := false
var hp := 0
var max_hp := 1
var shield := 0
var skill_energy := 0
var _icons: Array = [] # Status.icons() of the effects
var color := ALLY

var _tween: Tween
var _status: Label
var _name: Label
var _title: TitlePlate
var _title_rise := 0.0 # px the status markers and the turn arrow sit higher for the plate
var _sprite: Node2D # scenes/character/character.gd
var _ring: Node2D
var _aura: EnergyAura
var _badge: UseBadge
var _hp_known := false
var _active := false
var _dead := false
var _last_x := 0.0
var _walk_left := 0.0
var _t := 0.0
var _art_top := ART_TOP
var _sweep := {} # aim_sweep(): {t, duration, angle, wobble}; {} when none


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
	_aura = EnergyAura.new() # a child of the ring: over it, under the body (drawn before it)
	_ring.add_child(_aura)
	_sprite = CharacterScene.instantiate()
	_sprite.scale = Vector2.ONE * (ART_SCALE / Art.PX_PER_UNIT)
	_sprite.show_behind_parent = true
	_sprite.holster = true # drawn (kneeling) to shoot
	_sprite.idle_gun = true # idle: standing, the gun in hand 45° down-forward; walking: on the back
	_sprite.character_id = str(p.get("characterId", ""))
	var gun := EquipmentModel.player_gun(p, PlayerState.catalog)
	_sprite.set_weapon(gun["kind"], gun["tier"])
	add_child(_sprite)
	_art_top = maxf(ART_TOP, _sprite.art_height() * _sprite.scale.y + 3.0)
	_aura.height = _art_top

	_name = LobbyUi.text(str(p.get("displayName", "")), 20, color.lightened(0.55) if not me else LobbyUi.GOLD, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.size = Vector2(200, 26)
	_name.position = Vector2(-100, -_art_top - 40)
	add_child(_name)
	_title = TitlePlate.new()
	_title.plate_height = TITLE_H
	_title.font_size = TITLE_FONT
	_title.max_width = TITLE_MAX_W
	_title.size = Vector2(TITLE_MAX_W + 20, TITLE_H)
	_title.position = Vector2(-(TITLE_MAX_W + 20) / 2, -_art_top - 40 - TITLE_H + 3)
	_title.set_title(TitleModel.from_player(p))
	add_child(_title)
	_title_rise = TITLE_H - 3 if _title.has_title() else 0.0
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size = Vector2(200, 24)
	_status.position = Vector2(-100, -_art_top - 64 - _title_rise)
	_status.add_theme_color_override("font_color", Color(0.75, 0.9, 1))
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 4)
	add_child(_status)
	_badge = UseBadge.new()
	add_child(_badge)
	set_status(p.get("statusEffects"))
	set_hp(int(p.get("hp", 0)), int(p.get("maxHp", 1)))
	set_shield(int(p.get("shield", 0)) if (p.get("shield") is int or p.get("shield") is float) else 0)
	set_skill_energy(int(p.get("skillEnergy", 0)) if (p.get("skillEnergy") is int or p.get("skillEnergy") is float) else 0)
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
	if not _sweep.is_empty():
		_sweep["t"] = float(_sweep["t"]) + delta
		_apply_sweep()
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


## The skill energy on screen (0..100): the aura is on while the skill is ready and alive.
func set_skill_energy(value: int) -> void:
	skill_energy = value
	_aura.set_on(Skills.is_ready(value) and not _dead)


func aura_on() -> bool:
	return _aura.is_on()


## What the player uses (UseBadge.content(); {} hides it): hold seconds before it fades, < 0
## until release_badge(). The content already held stays as it is, where it is (no second pop).
func show_badge(content: Dictionary, hold: float = -1.0) -> void:
	if _dead and not content.is_empty():
		return
	if hold < 0.0 and _badge.is_held(content):
		return
	_place_badge(true)
	_badge.show_use(content, hold)


## The held badge `content` ends (UseBadge.release_held()): anything else shown stays.
func release_held_badge(content: Dictionary) -> void:
	_badge.release_held(content)


## The badge sits on top of the name (and the title plate), over the shot markers and the
## turn arrow while they show: never on the HP bar. A badge already up stays where it is (the
## turn passing on while it fades does not drop it onto the name) unless `force`.
func _place_badge(force: bool = false) -> void:
	if _badge.visible and not force:
		return
	var lift := BADGE_LIFT if _active or _status.text != "" else 0.0
	_badge.position = Vector2(0, -_art_top - 40 - _title_rise - lift - BADGE_GAP)


func release_badge() -> void:
	_badge.release()


## The badge shown ({} none): {kind, id, name}.
func badge() -> Dictionary:
	return _badge.shown()


## The badge node (its position and box, for layout checks).
func badge_node() -> Node2D:
	return _badge


## effects: the player's statusEffects list (null or [] clears the markers and icons).
func set_status(effects: Variant) -> void:
	_status.text = Status.marker_text(effects)
	_icons = Status.icons(effects)
	_place_badge()
	queue_redraw()


## The shield (absorbs damage before HP), drawn on the HP bar and as an icon.
func set_shield(value: int) -> void:
	shield = maxi(0, value)
	queue_redraw()


## The icons drawn right of the HP bar: the bad effect ids (Status.icons(), game data order), then "shield".
func status_icons() -> Array:
	var out := _icons.duplicate()
	if shield > 0:
		out.append("shield")
	return out


## The HP bar's fills as fractions of its width: {hp, shield} (the shield segment follows the HP;
## when HP + shield pass the max HP the bar spans HP + shield).
func bar_fractions() -> Dictionary:
	var total := float(maxi(max_hp, hp + shield))
	if total <= 0.0:
		return {"hp": 0.0, "shield": 0.0}
	return {"hp": clampf(hp / total, 0.0, 1.0), "shield": clampf(shield / total, 0.0, 1.0)}


## The worn title shown over the name ({} = none).
func title() -> Dictionary:
	return _title.title if _title.has_title() else {}


func status_text() -> String:
	return _status.text


func set_dead() -> void:
	if _dead:
		return
	_dead = true
	_active = false
	_sweep = {}
	_sprite.die()
	_aura.set_on(false)
	_badge.show_use({})
	_name.modulate.a = 0.5
	_title.modulate.a = 0.5
	_status.modulate.a = 0.5
	_ring.queue_redraw()
	queue_redraw()


## dir > 0 faces right, < 0 left.
func face(dir: float) -> void:
	_sprite.face(dir)


## Aim angle in degrees (0 right, 90 up, 180 left): face the side it shoots to (AimSnap.side():
## straight up / down keeps the facing).
func face_angle(angle: float) -> void:
	_sprite.face(AimSnap.side(angle, _sprite.facing))


func facing() -> int:
	return _sprite.facing


## Points the gun at an aim angle (degrees, 0 right, 90 up), snapped to the nearest of its 7
## directions (visual only); draws it.
## Ends an aim_sweep().
func aim(angle: float) -> void:
	_sweep = {}
	_sprite.aim(angle)


## A remote player aims at angle (degrees, the Shoot convention) for duration seconds before its
## shot: faces that side, draws the gun at level and swings it onto the aim (the swing's angle
## snapped: the gun steps between its directions and ends on the aim's), then holds it there
## until aim(), shoot(), clear_aim() or death. While still walking
## (a move just before) it faces and draws once the walk is over.
func aim_sweep(angle: float, duration: float) -> void:
	if _dead:
		return
	_sweep = {"t": 0.0, "duration": maxf(0.0, duration), "angle": angle, "wobble": randf()}
	_apply_sweep()


func is_sweeping() -> bool:
	return not _sweep.is_empty()


## The angle a remote aim (aim_sweep()) shows now (degrees, the Shoot convention), NAN when none
## (the camera looks along it).
func sweep_angle() -> float:
	if _sweep.is_empty():
		return NAN
	return AimSweep.angle_at(float(_sweep["t"]), float(_sweep["duration"]), float(_sweep["angle"]), _sprite.facing,
		float(_sweep["wobble"]))


func is_dead() -> bool:
	return _dead


func display_name() -> String:
	return _name.text if _name != null else player_id


func _apply_sweep() -> void:
	if _walk_left > 0.0:
		return # the walk faces the body; the gun comes out once it stops
	var angle := float(_sweep["angle"])
	face_angle(angle)
	# The curve runs on the real angle; the character snaps what it shows (AimSnap).
	_sprite.aim(AimSweep.angle_at(float(_sweep["t"]), float(_sweep["duration"]), angle, _sprite.facing,
		float(_sweep["wobble"])))


## Draws the gun at level (a drag started, no angle yet).
func draw_gun() -> void:
	_sprite.draw_gun()


## Puts the gun away (and ends an aim_sweep()).
func clear_aim() -> void:
	_sweep = {}
	_sprite.clear_aim()


## The gun draw state: holstered, drawing, aiming, firing, holstering.
func gun_state() -> String:
	return _sprite.gun_state()


## The gun's muzzle, global coordinates (visual only: the server's shot origin is unchanged).
func muzzle_position() -> Vector2:
	return _sprite.muzzle_position()


## Where the muzzle is when the shot leaves (the gun out at the aim), global; call after shoot().
func fire_muzzle_position() -> Vector2:
	return _sprite.fire_muzzle_position()


## {kind, tier} of the gun held.
func weapon() -> Dictionary:
	return _sprite.weapon()


## Recoil and muzzle flash (a shot leaves): at once with the gun out, else once it is drawn
## (fast); returns the seconds until then. with_gun false: a shot not from the gun (air strike).
func shoot(with_gun: bool = true) -> float:
	_sweep = {}
	return _sprite.shoot(with_gun)


## The current player gets a bobbing arrow above the name.
func set_active(on: bool) -> void:
	_active = on and not _dead
	_place_badge()
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
	var bar := Rect2(-HP_BAR_WIDTH / 2, -_art_top - 12, HP_BAR_WIDTH, 8)
	draw_rect(bar.grow(2), Color(0.02, 0.03, 0.1, 0.85))
	var health := clampf(float(hp) / max_hp, 0.0, 1.0) # the colour follows the HP share of the max
	var fill := Color(1.0, 0.3, 0.25).lerp(Color(1.0, 0.85, 0.2), clampf(health * 2.0, 0.0, 1.0))
	fill = fill.lerp(Color(0.3, 0.9, 0.35), clampf(health * 2.0 - 1.0, 0.0, 1.0))
	var fr := bar_fractions()
	var frac: float = fr["hp"]
	if frac > 0.0:
		var f := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
		draw_rect(f, fill)
		draw_rect(Rect2(f.position, Vector2(f.size.x, 2)), fill.lightened(0.4))
	if float(fr["shield"]) > 0.0:
		var sh := Rect2(bar.position + Vector2(bar.size.x * frac, 0), Vector2(bar.size.x * float(fr["shield"]), bar.size.y))
		draw_rect(sh, SHIELD_COLOR)
		draw_rect(Rect2(sh.position, Vector2(sh.size.x, 3)), Color(1, 1, 1, 0.95))
		draw_line(sh.position, sh.position + Vector2(0, sh.size.y), Color(1, 1, 1, 0.9), 1.5)
	var icons := status_icons()
	for i in icons.size():
		var c := Vector2(bar.end.x + 4.0 + ICON_SIZE / 2.0 + i * (ICON_SIZE + ICON_GAP), bar.get_center().y)
		StatusIcons.draw(self, str(icons[i]), c, ICON_SIZE)
	if _active:
		var y := -_art_top - 48 - _title_rise - absf(sin(_t * 4.0)) * 6.0
		var arrow := PackedVector2Array([Vector2(-10, y - 12), Vector2(10, y - 12), Vector2(0, y)])
		draw_colored_polygon(arrow, LobbyUi.GOLD)
		arrow.append(arrow[0])
		draw_polyline(arrow, Color(0.25, 0.13, 0.02), 2.0, true)
