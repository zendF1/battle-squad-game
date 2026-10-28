extends HBoxContainer
## An element's place in the cycle as pictures instead of "Hệ: Kim — khắc Mộc, bị Hỏa khắc": the
## element that beats it (small) → the element (big) → the element it beats (small), the first
## arrow red (beaten by), the second green (beats); a part the game data does not give is left
## out, nothing at all for no element. The element badge sits in the middle with equal blocks on
## both sides when both parts are known. Names and rules are the game data's (GET /gamedata
## elements); each badge's tooltip names its element.

const GameData := preload("res://autoload/game_data_model.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")

const BEATS := Color(0.45, 0.92, 0.45)
const BEATEN := Color(1.0, 0.42, 0.4)

var _weak
var _weak_arrow
var _main
var _beats_arrow
var _beats


## A chain for `element_id` with the element's badge `px` wide (the others ~0.58 of it).
static func make(element_id: String, px: int = 56):
	var c = new()
	c.build(px)
	c.set_element(element_id)
	return c


func build(px: int) -> void:
	add_theme_constant_override("separation", 4)
	alignment = ALIGNMENT_CENTER
	mouse_filter = MOUSE_FILTER_IGNORE
	var small := int(px * 0.58)
	var arrow := int(px * 0.46)
	_weak = ElementBadge.make("", small)
	_weak.name = "BeatenBy"
	_weak.mouse_filter = MOUSE_FILTER_PASS # its tooltip
	_weak_arrow = GlyphIcon.make("arrow", arrow, BEATEN)
	_main = ElementBadge.make("", px)
	_main.name = "Element"
	_main.mouse_filter = MOUSE_FILTER_PASS
	_beats_arrow = GlyphIcon.make("arrow", arrow, BEATS)
	_beats = ElementBadge.make("", small)
	_beats.name = "Beats"
	_beats.mouse_filter = MOUSE_FILTER_PASS
	for n in [_weak, _weak_arrow, _main, _beats_arrow, _beats]:
		add_child(n)


## Shows `element_id`'s chain (hidden for "").
func set_element(element_id: String) -> void:
	visible = element_id != ""
	var by := GameData.element_beaten_by(element_id)
	var beats := GameData.element_beats(element_id)
	_show_badge(_main, element_id)
	_show_badge(_weak, by)
	_show_badge(_beats, beats)
	_weak.visible = by != ""
	_weak_arrow.visible = by != ""
	_beats.visible = beats != ""
	_beats_arrow.visible = beats != ""


## The ids shown: [beaten by, element, beats] ("" for a part left out); tests.
func shown() -> Array:
	return [_weak.element_id if _weak.visible else "", _main.element_id, _beats.element_id if _beats.visible else ""]


static func _show_badge(badge, id: String) -> void:
	badge.element_id = id
	badge.tooltip_text = GameData.element_name(id) if id != "" else ""
