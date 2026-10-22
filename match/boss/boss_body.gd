extends Node2D
## The body of a boss or minion in a match (PlayerView's figure in place of the character scene,
## match/views/player_view.gd): BossArt at `height` px over the feet, idling (bob, glow, rotors),
## a white hit flash (hurt()), a step wobble while walking, a death fade (die(): it sinks a little,
## tilts and fades out), and for the boss its shield bubble (set_shielded(): pops in, shrinks
## away). It answers the calls PlayerView makes on a character (face, set_walking, aim, shoot,
## muzzle positions...) with what a body without a gun does: nothing to draw out, the shot leaving
## at once from its muzzle point (BossArt.MUZZLE: the robot's cannon, the witch's crystal).

const BossArt := preload("res://match/boss/boss_art.gd")

const FLASH_SEC := 0.28
const DEATH_SEC := 1.2
const SHIELD_SEC := 0.35
const SHIELD_PAD := 1.05 # the bubble over the figure's extents (BossArt.shield_extents())

var art := BossArt.GENERIC_BOSS
var height := 120.0 # px
var character_id := "" # PlayerView sets it (unused: drawn by art)
var holster := true
var idle_gun := true
var facing := 1
var shielded := false

var _t := 0.0
var _flash := 0.0
var _walking := false
var _dead := false
var _death := 0.0 # 0..1 through the fade
var _shield := 0.0 # 0..1 the bubble shown
var _shield_pop := 0.0 # a short swell when it turns on / off
var _weapon := {"kind": "", "tier": ""}


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
	queue_redraw()


func _draw() -> void:
	var wobble := Vector2.ZERO
	if _walking and not _dead:
		wobble = Vector2(0, -absf(sin(_t * 14.0)) * height * 0.03)
	BossArt.draw(self, art, wobble, height, _t if not _dead else 0.0, facing, _flash)
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
