extends Control
## A player's character standing as on the lobby stage, at `figure_scale` of it: the same
## CharacterView (the full-body picture, idle, hands free) with the back aura of their weapon's
## upgrade level, their gun resting beside the feet (PedestalGun) and, with `pedestal`, the lobby's
## pedestal under them. Another player's look comes from the server (LeaderboardModel.look():
## {character_id, gun: {kind, tier}, aura_level, set_aura}), never from my own gear. The feet sit at the
## bottom centre of this control, `foot_margin` px above its bottom edge. Used by the leaderboard's
## podium (leaderboard_place.gd, no pedestal: the step is it) and the showcase (showcase_popup.gd).

const Art := preload("res://ui/art.gd")
const CharacterView := preload("res://ui/character_view.gd")
const PedestalGun := preload("res://screens/home/pedestal_gun.gd")

## The lobby stage's character rect and its feet from the rect's top (lobby.gd, party_slot.gd).
const ART := Vector2(375, 400)
const ART_FEET := 380.0
const PEDESTAL_DROP := 6.0 # the pedestal's centre below the feet (lobby: 528 vs 522)

var figure_scale := 1.0
var pedestal := false
## Px between the feet and this control's bottom edge.
var foot_margin := 0.0
## The gun's size against the figure's (1: as on the lobby stage).
var gun_scale := 1.0

var _art: CharacterView
var _gun: PedestalGun
var _look := {}


## A figure at `s` of the lobby stage showing `look` (LeaderboardModel.look()).
static func make(look: Dictionary, s: float, with_pedestal: bool = false):
	var f = load("res://screens/home/player_figure.gd").new()
	f.figure_scale = s
	f.pedestal = with_pedestal
	f._look = look
	return f


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(ART.x, ART_FEET) * figure_scale
	_art = CharacterView.new()
	_art.name = "Art"
	_art.idle = true
	_art.hands_free = true # the gun rests beside the feet, as on the lobby stage
	_art.size = ART * figure_scale
	add_child(_art)
	_gun = PedestalGun.new()
	_gun.name = "Gun"
	_gun.size = PedestalGun.STAGE_RECT.size
	add_child(_gun)
	resized.connect(_layout)
	show_look(_look)


## Shows `look` ({character_id, gun: {kind, tier}, aura_level}); {} shows nothing.
func show_look(look: Dictionary) -> void:
	_look = look
	if _art == null:
		return
	var empty := look.is_empty() or str(look.get("character_id", "")) == ""
	_art.visible = not empty
	_gun.visible = not empty
	if empty:
		queue_redraw()
		return
	_art.character_id = str(look["character_id"])
	var g: Dictionary = look.get("gun", {})
	_art.gun = g
	_art.aura_level = maxi(0, int(look.get("aura_level", 0)))
	_art.set_index = maxi(0, int(look.get("set_aura", 0))) # their 6-piece set aura, never mine
	_art.back_aura = true
	_gun.set_gun(str(g.get("kind", "")), str(g.get("tier", "")))
	_gun.visible = not _art.holds_gun()
	_layout()
	queue_redraw()


## The look shown.
func look() -> Dictionary:
	return _look


## The CharacterView (tests).
func view() -> CharacterView:
	return _art


## The resting gun (tests).
func gun_stand() -> PedestalGun:
	return _gun


## The feet in this control's px.
func feet() -> Vector2:
	return Vector2(size.x / 2.0, size.y - foot_margin)


func _layout() -> void:
	if _art == null:
		return
	var s := figure_scale
	var f := feet()
	_art.size = ART * s
	_art.position = f - Vector2(ART.x * s / 2.0, ART_FEET * s)
	var gs := s * gun_scale
	_gun.scale = Vector2.ONE * gs
	_gun.position = f + (PedestalGun.STAGE_RECT.position - PedestalGun.FEET) * gs
	queue_redraw()


func _draw() -> void:
	if not pedestal or not _art.visible:
		return
	var tex := Art.env("pedestal")
	if tex == null:
		return
	var s := figure_scale
	var centre := feet() + Vector2(0, PEDESTAL_DROP * s)
	draw_texture_rect(tex, Rect2(centre - Art.PEDESTAL_CENTER * s, tex.get_size() * s), false)
