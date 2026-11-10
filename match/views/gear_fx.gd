extends Node2D
## A gear effect happening on a unit in a match, drawn in code: the effect's picture
## (ui/gear_glyphs.gd) pops up over the body inside a burst of rings and motes in its colour,
## rises a little and fades; then the node frees itself. One per event:
## - "resist" (armor passive: a burn / freeze / poison / root ignored): a teal shield puff;
## - "revive" (armor awaken Hồi sinh): a big gold burst, rings climbing the body, the heart;
## - "crit_immune" (helmet awaken: the crit counted as a normal hit, a shield given): the crossed
##   burst in a light-blue bubble;
## - "proc" (gloves / pants chance, or the pants awaken: the element effect applied): the spark;
## - "set_shield" / "set_heal" / "set_cleanse" / "set_fire" (the 6-piece effects): their pictures,
##   small;
## - an awaken kind ("no_wind"...: a piece's awaken used, over its user): its picture.
## Place it at the unit's body centre; `scale_k` scales it to the body (a boss's is bigger).

const GearGlyphs := preload("res://ui/gear_glyphs.gd")

## kind -> {glyph, color, px (picture), rings, sec, big (the bigger burst)}
const LOOKS := {
	"resist": {"glyph": "resist", "color": Color(0.35, 0.95, 0.85), "px": 46.0, "rings": 1, "sec": 0.9},
	"revive": {"glyph": "revive", "color": Color(1.0, 0.82, 0.3), "px": 64.0, "rings": 3, "sec": 1.5, "big": true},
	"crit_immune": {"glyph": "crit_immune", "color": Color(0.62, 0.9, 1.0), "px": 54.0, "rings": 2, "sec": 1.1},
	"proc": {"glyph": "proc_chance", "color": Color(0.82, 0.5, 1.0), "px": 40.0, "rings": 1, "sec": 0.8},
	"set_shield": {"glyph": "set_shield", "color": Color(0.62, 0.9, 1.0), "px": 44.0, "rings": 1, "sec": 1.0},
	"set_heal": {"glyph": "set_lifesteal", "color": Color(0.45, 0.95, 0.5), "px": 38.0, "rings": 1, "sec": 0.9},
	"set_cleanse": {"glyph": "set_cleanse", "color": Color(0.55, 0.9, 1.0), "px": 42.0, "rings": 2, "sec": 1.0},
	"set_fire": {"glyph": "set_fire", "color": Color(1.0, 0.5, 0.15), "px": 38.0, "rings": 1, "sec": 0.8},
}
const RISE := 26.0
const MOTES := 10

var kind := "resist"
var scale_k := 1.0
var _look := {}
var _t := 0.0


static func look_of(fx_kind: String) -> Dictionary:
	if LOOKS.has(fx_kind):
		return LOOKS[fx_kind]
	if GearGlyphs.AWAKENS.has(fx_kind):
		return {"glyph": fx_kind, "color": GearGlyphs.AWAKEN_GLOW, "px": 52.0, "rings": 2, "sec": 1.1}
	return {}


static func make(fx_kind: String, k: float = 1.0):
	var fx = new()
	fx.kind = fx_kind
	fx.scale_k = k
	return fx


func _ready() -> void:
	_look = look_of(kind)
	z_index = 3
	if _look.is_empty():
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _t >= float(_look.get("sec", 1.0)):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _look.is_empty():
		return
	var sec := float(_look["sec"])
	var p := clampf(_t / sec, 0.0, 1.0)
	var col: Color = _look["color"]
	var big := bool(_look.get("big", false))
	var k := scale_k
	# rings bursting out, one after another
	for i in int(_look["rings"]):
		var q := clampf(p * 1.6 - i * 0.22, 0.0, 1.0)
		if q <= 0.0 or q >= 1.0:
			continue
		var r := lerpf(12.0, (70.0 if big else 44.0), ease(q, 0.4)) * k
		draw_arc(Vector2(0, -i * 8.0 * k if big else 0.0), r, 0, TAU, 40, Color(col, 0.8 * (1.0 - q)), maxf(2.0, 5.0 * (1.0 - q)) * k, true)
	# motes flying out and up
	for i in MOTES:
		var a := TAU * i / MOTES + 0.3
		var d := ease(p, 0.5) * (60.0 if big else 34.0) * k
		var m := Vector2.from_angle(a) * d + Vector2(0, -p * 30.0 * k)
		draw_circle(m, (3.0 if big else 2.2) * k, Color(col.lightened(0.4), 1.0 - p))
	# the picture: pops in, rises, fades in its last third
	var pop := minf(1.0, _t / 0.18)
	var s := float(_look["px"]) * k * (0.6 + 0.4 * ease(pop, -2.0))
	var alpha := 1.0 if p < 0.66 else 1.0 - (p - 0.66) / 0.34
	modulate.a = alpha
	GearGlyphs.draw(self, str(_look["glyph"]), Vector2(0, -RISE * k * p - s * 0.2), s)
