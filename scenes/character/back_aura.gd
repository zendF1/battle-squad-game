extends Node2D
## The weapon milestone back aura: a glowing ring slowly turning behind a character's back, the
## reward for a weapon upgraded to +14 (purple, ~1 turn / 12 s) or +16 (red, ~1 turn / 8 s, with a
## second smaller, fainter copy turning the other way for density). Both gently pulse (scale and
## alpha). The rings are AI-drawn pictures (assets/fx/back_aura_<colour>.png, keyed from
## art_source/fx/ by tools/import_back_aura.gd), drawn with normal blending, centred on this
## node's origin: the owner puts it behind the figure, centred on the torso, and sets `diameter`
## (px of the ring picture's full width) and `strength` (alpha). Set `level` (the worn weapon's
## upgradeLevel): below +14 it is hidden and does not process. Two sprites, no per-frame
## allocation. Used by ui/character_view.gd (lobby stage, Prep, Nhân vật); not on the small
## match sprites.

const Art := preload("res://ui/art.gd")

const PURPLE_FROM := 14
const RED_FROM := 16
const PATHS := {
	"purple": Art.ROOT + "fx/back_aura_purple.png",
	"red": Art.ROOT + "fx/back_aura_red.png",
}
## Seconds per turn of the main ring.
const PERIOD := {"purple": 12.0, "red": 8.0}
## The red second ring: its size and alpha against the main one, seconds per (reverse) turn.
const INNER_SCALE := 0.74
const INNER_ALPHA := 0.42
const INNER_PERIOD := 11.0
## The pulse: ± scale and ± alpha share, its period in seconds.
const PULSE_SCALE := 0.025
const PULSE_ALPHA := 0.12
const PULSE_SEC := 2.6

## The worn weapon's upgrade level (0 = none).
var level := 0:
	set(value):
		level = value
		_apply()
## The ring picture's on-screen width in this node's px.
var diameter := 300.0:
	set(value):
		diameter = value
		_apply()
## Alpha of the main ring at the pulse's middle.
var strength := 1.0

var _main: Sprite2D
var _inner: Sprite2D
var _aura := ""
var _base := 1.0 # the main ring's scale for `diameter`
var _t := 0.0


## "red" from +16, "purple" from +14, "" below.
static func aura_for(upgrade_level: int) -> String:
	if upgrade_level >= RED_FROM:
		return "red"
	if upgrade_level >= PURPLE_FROM:
		return "purple"
	return ""


func _init() -> void:
	name = "BackAura"
	_main = _sprite("Ring")
	_inner = _sprite("Inner")
	_apply()


func _sprite(node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.visible = false
	add_child(s)
	return s


## The aura shown ("red", "purple" or "").
func aura() -> String:
	return _aura


func _apply() -> void:
	if _main == null:
		return
	var a := aura_for(level)
	if a != _aura:
		_aura = a
		_main.texture = Art.texture(PATHS[a]) if a != "" else null
		_inner.texture = _main.texture
		_main.rotation = randf() * TAU if a != "" else 0.0 # several on screen do not turn in step
		_inner.rotation = randf() * TAU if a != "" else 0.0
	var w := float(_main.texture.get_width()) if _main.texture != null else 1.0
	_base = diameter / maxf(1.0, w)
	_main.visible = _aura != ""
	_inner.visible = _aura == "red"
	set_process(_aura != "")
	_pose()


func _process(delta: float) -> void:
	if is_inside_tree() and not is_visible_in_tree():
		return # hidden screen: no work
	_t += delta
	_main.rotation = wrapf(_main.rotation + TAU / float(PERIOD[_aura]) * delta, 0.0, TAU)
	if _inner.visible:
		_inner.rotation = wrapf(_inner.rotation - TAU / INNER_PERIOD * delta, 0.0, TAU)
	_pose()


## The pulse: scale and alpha of both rings at _t.
func _pose() -> void:
	var p := sin(_t * TAU / PULSE_SEC)
	_main.scale = Vector2.ONE * (_base * (1.0 + PULSE_SCALE * p))
	_main.modulate.a = strength * (1.0 - PULSE_ALPHA * (0.5 - 0.5 * p))
	var q := sin(_t * TAU / PULSE_SEC + PI) # the inner ring breathes opposite
	_inner.scale = Vector2.ONE * (_base * INNER_SCALE * (1.0 + PULSE_SCALE * q))
	_inner.modulate.a = strength * INNER_ALPHA * (1.0 - PULSE_ALPHA * (0.5 - 0.5 * q))
