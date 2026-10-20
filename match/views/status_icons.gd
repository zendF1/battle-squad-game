extends RefCounted
## The small status icons drawn beside a player's HP bar (player_view.gd): burn, root, stun,
## freeze, net and shield. Each is a round badge in the effect's colour; the picture inside is
## assets/ui/status/<id>.png when that file exists (drop a PNG there to replace the code-drawn one;
## an image the editor has not imported yet is read directly, ui/art.gd texture()), otherwise it
## is drawn here.

const Art := preload("res://ui/art.gd")

const DIR := "res://assets/ui/status/"
const IDS := ["burn", "root", "stun", "freeze", "net", "shield"]
const COLORS := {
	"burn": Color(1.0, 0.5, 0.15),
	"root": Color(0.45, 0.8, 0.3),
	"stun": Color(1.0, 0.85, 0.2),
	"freeze": Color(0.55, 0.85, 1.0),
	"net": Color(0.78, 0.78, 0.82),
	"shield": Color(0.6, 0.88, 1.0),
}
const BADGE := Color(0.04, 0.06, 0.16, 0.88)


static func path(id: String) -> String:
	return DIR + id + ".png"


## The replacement picture of an icon, null when there is none (the code-drawn one is used).
static func texture(id: String) -> Texture2D:
	if not FileAccess.file_exists(path(id)):
		return null
	var t := Art.texture(path(id))
	return null if t == Art.placeholder() else t


static func color(id: String) -> Color:
	return COLORS.get(id, Color.WHITE)


## Draws icon id as a badge of diameter size centred at c on ci.
static func draw(ci: CanvasItem, id: String, c: Vector2, size: float) -> void:
	var r := size / 2.0
	var col := color(id)
	ci.draw_circle(c, r, BADGE)
	ci.draw_arc(c, r - 1.0, 0.0, TAU, 24, col, 2.0, true)
	var tex := texture(id)
	if tex != null:
		var s := size * 0.78
		ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false)
		return
	var k := r * 0.62 # the picture's half size
	match id:
		"burn": _flame(ci, c, k)
		"root": _root(ci, c, k)
		"stun": _stars(ci, c, k)
		"freeze": _flake(ci, c, k)
		"net": _web(ci, c, k)
		"shield": _shield(ci, c, k)


static func _flame(ci: CanvasItem, c: Vector2, k: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		# A teardrop pointing up: round bottom, pointed top.
		var p := Vector2(sin(a) * 0.72, -cos(a))
		var lift := maxf(0.0, -p.y) * 0.55
		var q := Vector2(p.x * (1.0 - lift), p.y * 1.15 + 0.15)
		outer.append(c + q * k)
		inner.append(c + Vector2(q.x * 0.5, q.y * 0.55 + 0.3) * k)
	ci.draw_colored_polygon(outer, Color(1.0, 0.42, 0.1))
	ci.draw_colored_polygon(inner, Color(1.0, 0.86, 0.3))


static func _root(ci: CanvasItem, c: Vector2, k: float) -> void:
	var brown := Color(0.62, 0.42, 0.22)
	ci.draw_line(c + Vector2(0, -0.2) * k, c + Vector2(0, 0.95) * k, brown, maxf(2.0, k * 0.28), true)
	ci.draw_line(c + Vector2(0, 0.45) * k, c + Vector2(-0.7, 0.95) * k, brown, maxf(1.5, k * 0.18), true)
	ci.draw_line(c + Vector2(0, 0.45) * k, c + Vector2(0.7, 0.95) * k, brown, maxf(1.5, k * 0.18), true)
	var green := Color(0.45, 0.85, 0.3)
	ci.draw_circle(c + Vector2(-0.42, -0.45) * k, k * 0.38, green)
	ci.draw_circle(c + Vector2(0.42, -0.6) * k, k * 0.34, green.lightened(0.15))
	ci.draw_circle(c + Vector2(0.0, -0.15) * k, k * 0.3, green.darkened(0.1))


static func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return pts


static func _stars(ci: CanvasItem, c: Vector2, k: float) -> void:
	ci.draw_arc(c + Vector2(0, 0.1) * k, k * 0.85, PI * 0.1, PI * 1.9, 20, Color(1.0, 0.95, 0.6, 0.7), maxf(1.5, k * 0.14), true)
	ci.draw_colored_polygon(_star(c + Vector2(-0.1, -0.05) * k, k * 0.72), Color(1.0, 0.86, 0.2))
	ci.draw_colored_polygon(_star(c + Vector2(0.62, 0.55) * k, k * 0.32), Color(1.0, 0.95, 0.55))


static func _flake(ci: CanvasItem, c: Vector2, k: float) -> void:
	var col := Color(0.85, 0.97, 1.0)
	var w := maxf(1.5, k * 0.18)
	for i in 3:
		var a := PI / 3.0 * i
		var d := Vector2(cos(a), sin(a)) * k
		ci.draw_line(c - d, c + d, col, w, true)
		for s in [-1.0, 1.0]:
			var tip: Vector2 = c + d * s * 0.6
			var side := d.rotated(PI / 2.0).normalized() * k * 0.25
			ci.draw_line(tip, tip + d * s * 0.25 + side, col, w * 0.7, true)
			ci.draw_line(tip, tip + d * s * 0.25 - side, col, w * 0.7, true)


static func _web(ci: CanvasItem, c: Vector2, k: float) -> void:
	var col := Color(0.9, 0.9, 0.95)
	var w := maxf(1.2, k * 0.12)
	for i in 4:
		var a := PI / 4.0 * i
		var d := Vector2(cos(a), sin(a)) * k
		ci.draw_line(c - d, c + d, col, w, true)
	for rr in [0.45, 0.85]:
		ci.draw_arc(c, k * rr, 0.0, TAU, 8, col, w, true)


static func _shield(ci: CanvasItem, c: Vector2, k: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -1) * k, c + Vector2(0.85, -0.65) * k, c + Vector2(0.75, 0.25) * k,
		c + Vector2(0, 1) * k, c + Vector2(-0.75, 0.25) * k, c + Vector2(-0.85, -0.65) * k])
	ci.draw_colored_polygon(pts, Color(0.55, 0.85, 1.0))
	var shine := PackedVector2Array([c + Vector2(0, -0.78) * k, c + Vector2(0.6, -0.5) * k, c + Vector2(0.52, 0.15) * k,
		c + Vector2(0, 0.75) * k])
	ci.draw_colored_polygon(shine, Color(0.88, 0.97, 1.0))
