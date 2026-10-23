extends Node2D
## The body of a boss or minion in a match (PlayerView's figure in place of the character scene,
## match/views/player_view.gd): BossArt at `height` px over the feet, idling (bob, glow, rotors),
## a white hit flash (hurt()), a step wobble while walking, a death fade (die(): it sinks a little,
## tilts and fades out), and for the boss its shield bubble (set_shielded(): pops in, shrinks
## away). It answers the calls PlayerView makes on a character (face, set_walking, aim, shoot,
## muzzle positions...) with what a body without a gun does: nothing to draw out, the shot leaving
## at once from its muzzle point (BossArt.MUZZLE: the robot's cannon, the witch's crystal).
## Boss mode v2: a flying unit (flying) hovers round its feet point in the air and leans into a
## flight (lean, PlayerView's UnitFlew flight), the witch with her cape and both fliers with a
## trail in the air (BossArt.TRAIL); a bomber (bomber) pulses red while warn (a party player within
## its detonateRange, BomberModel.pulse()); prime() swells and flashes it until its detonation,
## vanish() takes the body away at once (its blast covers it).

const BossArt := preload("res://match/boss/boss_art.gd")
const BomberModel := preload("res://match/boss/bomber_model.gd")

const FLASH_SEC := 0.28
const DEATH_SEC := 1.2
const SHIELD_SEC := 0.35
const SHIELD_PAD := 1.05 # the bubble over the figure's extents (BossArt.shield_extents())
const TRAIL_EVERY_PX := 7.0 # a trail puff each time the figure moved this far
const TRAIL_IDLE_SEC := 0.22 # and this often while it hovers in place
const TRAIL_LIFE := 0.7
const PRIME_SWELL := 0.18 # the body grows this much before it blows up

var art := BossArt.GENERIC_BOSS
var height := 120.0 # px
var character_id := "" # PlayerView sets it (unused: drawn by art)
var holster := true
var idle_gun := true
var facing := 1
var shielded := false
var flying := false
var bomber := false
var warn := false # a party player within detonateRange: the red pulse
var lean := 0.0 # rad into a flight (PlayerView sets it)

var _t := 0.0
var _flash := 0.0
var _walking := false
var _dead := false
var _death := 0.0 # 0..1 through the fade
var _shield := 0.0 # 0..1 the bubble shown
var _shield_pop := 0.0 # a short swell when it turns on / off
var _weapon := {"kind": "", "tier": ""}
var _prime := 0.0 # s left before it blows up (prime())
var _prime_sec := 0.0
var _vanished := false
var _trail: Array = [] # [{p: global Vector2, age, r}]
var _trail_from := Vector2.INF
var _trail_idle := 0.0


func setup(art_id: String, height_px: float) -> void:
	art = art_id
	height = maxf(height_px, 8.0)
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta / FLASH_SEC)
	_shield_pop = maxf(0.0, _shield_pop - delta * 2.5)
	var want := 1.0 if shielded and not _dead else 0.0
	_shield = move_toward(_shield, want, delta / SHIELD_SEC)
	if _dead and _death < 1.0:
		_death = minf(1.0, _death + delta / DEATH_SEC)
		modulate = Color(0.75, 0.72, 0.8, 1.0 - _death)
		rotation = deg_to_rad(-12.0 * facing) * _death
		position.y = height * 0.08 * _death
	if _prime > 0.0:
		_prime = maxf(0.0, _prime - delta)
		var k := 1.0 - _prime / maxf(_prime_sec, 0.01)
		scale = Vector2.ONE * (1.0 + PRIME_SWELL * k * k + sin(_t * 40.0) * 0.02 * k)
		_flash = maxf(_flash, 0.35 + 0.35 * absf(sin(_t * 18.0)))
	_step_trail(delta)
	queue_redraw()


## The trail puffs in the air behind a flier (global positions, so they stay where it passed).
func _step_trail(delta: float) -> void:
	for p in _trail:
		p["age"] = float(p["age"]) + delta
	_trail = _trail.filter(func(p): return float(p["age"]) < TRAIL_LIFE)
	if not flying or _dead or _vanished or not BossArt.TRAIL.has(art) or not is_inside_tree():
		return
	var at := global_position + Vector2(0, -height * 0.35)
	_trail_idle += delta
	if _trail_from == Vector2.INF:
		_trail_from = at
	if at.distance_to(_trail_from) >= TRAIL_EVERY_PX or _trail_idle >= TRAIL_IDLE_SEC:
		_trail_from = at
		_trail_idle = 0.0
		_trail.append({"p": at + Vector2(randf_range(-0.2, 0.2), randf_range(-0.1, 0.25)) * height, "age": 0.0,
			"r": randf_range(0.03, 0.06) * height})


func _draw() -> void:
	if not _trail.is_empty():
		var col: Color = BossArt.TRAIL.get(art, Color.WHITE)
		for p in _trail:
			var k := float(p["age"]) / TRAIL_LIFE
			var at := to_local(p["p"]) + Vector2(0, -k * 10.0)
			draw_circle(at, float(p["r"]) * (1.0 - k * 0.5), Color(col, col.a * 0.55 * (1.0 - k)))
			if art == "ice_witch" and int(float(p["r"]) * 100.0) % 3 == 0: # a frost glint
				var g := float(p["r"]) * 0.9 * (1.0 - k)
				draw_line(at - Vector2(g, 0), at + Vector2(g, 0), Color(1, 1, 1, 0.7 * (1.0 - k)), 1.2, true)
				draw_line(at - Vector2(0, g), at + Vector2(0, g), Color(1, 1, 1, 0.7 * (1.0 - k)), 1.2, true)
	if _vanished:
		return
	var wobble := Vector2.ZERO
	if _walking and not _dead and not flying:
		wobble = Vector2(0, -absf(sin(_t * 14.0)) * height * 0.03)
	BossArt.draw(self, art, wobble, height, _t if not _dead else 0.0, facing, _flash, {"flying": flying, "lean": lean if not _dead else 0.0,
		"tint": BomberModel.pulse(_t, bomber and not _dead and (warn or _prime > 0.0))})
	if _shield > 0.0 or _shield_pop > 0.0:
		var ext := BossArt.shield_extents(art, height) * SHIELD_PAD * (1.0 + _shield_pop * 0.12)
		BossArt.draw_shield(self, Vector2(0, -height * 0.5), ext.y, _t, maxf(_shield, _shield_pop * 0.8), BossArt.accent("ice_witch"),
			Vector2(ext.x / ext.y, 1.0))


## The figure's height (px, the unit PlayerView reads art_height() × scale in).
func art_height() -> float:
	return height


## Turns the shield on or off; animate: with the pop.
func set_shielded(on: bool, animate: bool = true) -> void:
	if on == shielded:
		return
	shielded = on
	if animate:
		_shield_pop = 1.0
	else:
		_shield = 1.0 if on else 0.0


func shield_shown() -> float:
	return _shield


func set_weapon(kind: String, tier: String) -> void:
	_weapon = {"kind": kind, "tier": tier}


func weapon() -> Dictionary:
	return _weapon


func face(dir: float) -> void:
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1


func set_walking(on: bool) -> void:
	_walking = on


func hurt() -> void:
	_flash = 1.0


func is_flashing() -> bool:
	return _flash > 0.0


func die() -> void:
	_dead = true


## About to blow up in sec (a detonation's lead-in): the body swells, flashing red.
func prime(sec: float) -> void:
	if _dead or sec <= 0.0:
		return
	_prime = sec
	_prime_sec = sec


func priming() -> bool:
	return _prime > 0.0


## Gone at once (it blew up: its blast covers the spot).
func vanish() -> void:
	_dead = true
	_vanished = true
	_prime = 0.0
	scale = Vector2.ONE


func vanished() -> bool:
	return _vanished


func death_progress() -> float:
	return _death


func aim(_angle: float) -> void:
	pass


func draw_gun() -> void:
	pass


func clear_aim() -> void:
	pass


func gun_state() -> String:
	return "holstered"


## The shot leaves at once (no gun to draw): a small flash, no wait.
func shoot(_with_gun: bool = true) -> float:
	_flash = maxf(_flash, 0.35)
	return 0.0


func muzzle_position() -> Vector2:
	return to_global(BossArt.muzzle(art, height, facing))


func fire_muzzle_position() -> Vector2:
	return muzzle_position()
