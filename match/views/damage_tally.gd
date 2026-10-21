extends Label
## One running damage number per player for a multi-hit skill shot (a missile rain, a bomb
## chain; SkillView.merges_damage()): instead of a pile of "-160 -14 -100" popups the player
## gets a single "-160" that counts up as the hits land (-160 → -320 → -734), with a small bump
## per hit, and rises and fades HOLD_SEC after the last one. It follows the player's view (the
## target may fall into a hole meanwhile). Looks like DamagePopup; frees itself.
## Set `follow` (the PlayerView) before adding it, then add() every hit.

const LobbyUi := preload("res://ui/lobby_ui.gd")
const DamagePopup := preload("res://match/views/damage_popup.gd")

const OFFSET := Vector2(0, -160) # over the player, clear of its name and HP bar
const HOLD_SEC := 0.75 # after the last hit
const FADE_SEC := 0.5
const RISE_PX := 50.0 # while fading
const BUMP := 1.25 # the scale a hit kicks it to
const BUMP_SEC := 0.14
const RED := Color(1, 0.3, 0.3)
const CRIT := Color(1, 0.85, 0.2)
const Z := 10 # over the explosions that keep coming (and the chain's raised players / geysers)

var follow: Node2D = null
var total := 0
var hits := 0
var _since := 0.0 # s since the last hit
var _bump := 1.0 # 0..1 into the current bump (1: done)
var _from := Vector2.ZERO # the last place over the player (kept when it is gone)


func _ready() -> void:
	z_index = Z
	add_theme_font_size_override("font_size", 34)
	add_theme_font_override("font", LobbyUi.bold())
	add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08, 0.95))
	add_theme_constant_override("outline_size", 9)
	add_theme_color_override("font_color", RED)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(240, 44)
	pivot_offset = size / 2
	_place()


## A hit of `amount` on the player: the total counts up and the number bumps.
func add(amount: int, critical: bool = false) -> void:
	total += absi(amount)
	hits += 1
	text = DamagePopup.damage_text(total)
	add_theme_color_override("font_color", CRIT if critical else RED)
	_since = 0.0
	_bump = 0.0
	modulate.a = 1.0


## True once it started fading: a later hit on the player gets a new tally.
func is_fading() -> bool:
	return _since >= HOLD_SEC


func _place() -> void:
	if follow != null and is_instance_valid(follow):
		_from = follow.position + OFFSET
	var rise := RISE_PX * clampf((_since - HOLD_SEC) / FADE_SEC, 0.0, 1.0)
	position = _from - Vector2(size.x / 2, rise)


func _process(delta: float) -> void:
	_since += delta
	if _bump < 1.0:
		_bump = minf(1.0, _bump + delta / BUMP_SEC)
	# up fast, back down: 1 → BUMP → 1
	var k := sin(PI * _bump)
	scale = Vector2.ONE * lerpf(1.0, BUMP, k)
	_place()
	if _since > HOLD_SEC:
		modulate.a = clampf(1.0 - (_since - HOLD_SEC) / FADE_SEC, 0.0, 1.0)
		if _since >= HOLD_SEC + FADE_SEC:
			queue_free()
