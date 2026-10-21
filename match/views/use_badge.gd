extends Node2D
## What a player is using, over its head (player_view.gd: above the name, the title plate, the
## shot markers and the turn arrow): a small round badge with only the icon, no name: an item's
## own icon (the one in the items row, Art.item_icon()), or for any skill the generic lightning
## "skill" icon (each skill's own picture is on the HUD's skill slot). A normal weapon shot shows
## nothing.
## show_use(): pops in (scaled up from POP_FROM, TRANS_BACK) and stays: for `hold` seconds, or
## (hold < 0) until release() (match_screen: the end of the shot's replay); then fades out over
## FADE. A new show_use() replaces the one shown: one badge per player, so a shot item's ItemUsed
## and its ShotResolved never stack. The node's position is the badge's bottom centre.

const Art := preload("res://ui/art.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Items := preload("res://match/items.gd")
const Skills := preload("res://match/skills.gd")
const SkillGlyphs := preload("res://match/views/skill_glyphs.gd")

const KIND_SKILL := "skill"
const KIND_ITEM := "item"
const HEIGHT := 36.0 # the round badge's diameter
const ICON := 26.0 # the icon's square
const POP_FROM := 0.55
const POP_SEC := 0.22
const FADE := 0.35
const BG := Color(0.05, 0.07, 0.18, 0.9)
const ITEM_RIM := Color(0.85, 0.92, 1.0)
const SKILL_NAME := "Kỹ năng" # an unknown skill's name

var _content := {}
var _width := HEIGHT
var _tex: Texture2D
var _tween: Tween
var _box: StyleBoxFlat


## What a shot or an item use shows: {kind (KIND_SKILL / KIND_ITEM), id, name (not drawn)}, {} for a normal
## weapon shot (or nothing known to show). action_mode: ShotResolved.actionMode (weapon, skill,
## item); an ItemUsed is ("item", "", itemId).
static func content(action_mode: String, skill_id: String, item_id: String) -> Dictionary:
	match action_mode:
		"skill":
			var view = Skills.view_for_skill(skill_id)
			var skill_name: String = view.skill_name()
			return {"kind": KIND_SKILL, "id": skill_id, "name": skill_name if skill_name != "" else SKILL_NAME}
		"item":
			if item_id == "":
				return {}
			return {"kind": KIND_ITEM, "id": item_id, "name": Items.label(item_id)}
	return {}


func _init() -> void:
	visible = false
	z_index = 2 # over the other players' names and bars
	_box = StyleBoxFlat.new()
	_box.bg_color = BG
	_box.set_corner_radius_all(int(HEIGHT / 2))
	_box.set_border_width_all(2)
	_box.anti_aliasing = true
	_box.shadow_color = Color(0, 0, 0, 0.35)
	_box.shadow_size = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Shows c (content()); {} hides the badge. hold: seconds before it fades, < 0 until release().
func show_use(c: Dictionary, hold: float = -1.0) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_content = c
	if c.is_empty():
		visible = false
		return
	var skill := str(c.get("kind", "")) == KIND_SKILL
	# a skill shows the generic lightning "skill" icon (its own picture is on the HUD's skill slot)
	_tex = Art.icon("skill") if skill else Art.item_icon(str(c.get("id", "")))
	_box.border_color = SkillGlyphs.color(str(c["id"])) if skill else ITEM_RIM
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE * POP_FROM
	queue_redraw()
	if not is_inside_tree():
		scale = Vector2.ONE
		return
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold >= 0.0:
		_tween.tween_interval(maxf(0.0, hold - POP_SEC))
		_tween.tween_property(self, "modulate:a", 0.0, FADE)
		_tween.tween_callback(_hide)


## The badge held until now fades out (nothing when none is shown).
func release() -> void:
	if not visible or _content.is_empty():
		return
	if not is_inside_tree():
		_hide()
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, maxf(0.0, POP_SEC * (1.0 - scale.x) / (1.0 - POP_FROM)))
	_tween.tween_property(self, "modulate:a", 0.0, FADE)
	_tween.tween_callback(_hide)


## The content shown ({} when hidden).
func shown() -> Dictionary:
	return _content if visible else {}


## The badge's box (local px, the position at its bottom centre).
func rect() -> Rect2:
	return Rect2(-_width / 2.0, -HEIGHT, _width, HEIGHT)


func _hide() -> void:
	visible = false
	_content = {}


func _draw() -> void:
	if _content.is_empty():
		return
	var r := rect()
	draw_style_box(_box, r)
	if _tex != null:
		draw_texture_rect(_tex, Rect2(r.get_center() - Vector2(ICON, ICON) / 2.0, Vector2(ICON, ICON)), false)
