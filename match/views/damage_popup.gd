extends Label
## Floating number above a player; set text and font color (or a damage's style(): set_style())
## before adding it, frees itself. Bold with a dark outline; it pops in, rises and fades.
## A damage event's elementEffect (the server's element rules, GET /gamedata elementRules) styles
## its number (style()): "strong" bigger in a warm gold-orange with a small "Khắc hệ!" tag above it,
## popping harder; "weak" smaller and greyish blue; none the usual red (gold for a critical hit).
## Boss v4: a hit on an armoured boss (its stone totems standing) reads as reduced (armored_style():
## a stone-grey, smaller number, the first one of an armour with a small "Giáp đá" tag); a poison
## tick's number is green (POISON).

const LobbyUi := preload("res://ui/lobby_ui.gd")
const Fmt := preload("res://core/fmt.gd")


## A hit: 1250 → "-1.250".
static func damage_text(amount: int) -> String:
	return "-" + Fmt.thousands(absi(amount))


## Numbers that come quickly on one player (a missile rain, a bomb chain) step aside so they
## stay readable: the n-th in a row (0 the first) is drawn this far off the usual spot.
const STACK_MS := 450 # a popup within this of the previous one on the player is "in a row"
const STAGGER_X := [0.0, 36.0, -36.0, 18.0, -18.0]


static func stagger(n: int) -> Vector2:
	var i := absi(n) % STAGGER_X.size()
	return Vector2(STAGGER_X[i], -30.0 * i)


## A heal: 450 → "+450", 1250 → "+1.250".
static func heal_text(amount: int) -> String:
	return "+" + Fmt.thousands(absi(amount))


const RED := Color(1, 0.3, 0.3)
const CRIT := Color(1, 0.85, 0.2)
const STRONG := Color(1.0, 0.6, 0.12) # khắc hệ: warm gold-orange
const STRONG_TAG := Color(1.0, 0.9, 0.42)
const WEAK := Color(0.62, 0.7, 0.84) # bị khắc: greyish blue
const STRONG_TEXT := "Khắc hệ!"
const FONT := 34
const STRONG_FONT := 46
const WEAK_FONT := 27
const ARMORED := Color(0.8, 0.74, 0.64) # stone grey: the armour took most of the hit
const ARMOR_TAG := "Giáp đá"
const ARMOR_TAG_COLOR := Color(1.0, 0.8, 0.36)
const POISON := Color(0.62, 0.95, 0.3)
const HEAL := Color(0.4, 1, 0.5)


## How a damage number looks: {color, font_size, tag ("" none: the "Khắc hệ!" over it), tag_color,
## pop (the scale it overshoots to), from (the scale it pops in from)}.
static func style(effect: String, critical: bool = false) -> Dictionary:
	match effect:
		"strong":
			return {"color": STRONG, "font_size": STRONG_FONT, "tag": STRONG_TEXT, "tag_color": STRONG_TAG, "pop": 1.45, "from": 0.35}
		"weak":
			return {"color": WEAK, "font_size": WEAK_FONT, "tag": "", "tag_color": WEAK, "pop": 1.08, "from": 0.6}
	return {"color": CRIT if critical else RED, "font_size": FONT, "tag": "", "tag_color": RED, "pop": 1.2, "from": 0.5}


## A hit on an armoured boss: style() turned stone grey and smaller; tag: the "Giáp đá" tag over it
## (in place of "Khắc hệ!").
static func armored_style(effect: String, critical: bool = false, tag: bool = false) -> Dictionary:
	var st := style(effect, critical)
	st["color"] = Color(st["color"]).lerp(ARMORED, 0.75)
	st["font_size"] = int(round(float(st["font_size"]) * 0.88))
	st["pop"] = minf(float(st["pop"]), 1.15)
	st["armored"] = true
	if tag:
		st["tag"] = ARMOR_TAG
		st["tag_color"] = ARMOR_TAG_COLOR
	return st


## A damage event's elementEffect ("strong" / "weak"; "" for none or anything else).
static func effect_of(e: Dictionary) -> String:
	var v = e.get("elementEffect")
	return str(v) if v is String and str(v) in ["strong", "weak"] else ""


var _style := style("")
var _tag: Label


## Takes a style() (before adding the popup): its colour, size, tag and pop.
func set_style(st: Dictionary) -> void:
	_style = st
	add_theme_color_override("font_color", st["color"])


## The "Khắc hệ!" tag over the number (null without one; tests).
func tag() -> Label:
	return _tag


func _ready() -> void:
	var fs := int(_style["font_size"])
	add_theme_font_size_override("font_size", fs)
	add_theme_font_override("font", LobbyUi.bold())
	add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08, 0.95))
	add_theme_constant_override("outline_size", 9)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(240, fs + 10)
	position -= Vector2(120, fs + 10 - 44)
	pivot_offset = size / 2
	if str(_style["tag"]) != "":
		_tag = Label.new()
		_tag.text = str(_style["tag"])
		_tag.add_theme_font_size_override("font_size", 20)
		_tag.add_theme_font_override("font", LobbyUi.bold())
		_tag.add_theme_color_override("font_color", _style["tag_color"])
		_tag.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.0, 0.95))
		_tag.add_theme_constant_override("outline_size", 7)
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tag.size = Vector2(size.x, 26)
		_tag.position = Vector2(0, -20)
		add_child(_tag)
	var from := float(_style["from"])
	scale = Vector2(from, from)
	var pop := float(_style["pop"])
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(pop, pop), 0.12 if pop < 1.3 else 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.1)
	t.parallel().tween_property(self, "position:y", position.y - 60.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.7 if _tag != null else 0.45)
	t.tween_callback(queue_free)
