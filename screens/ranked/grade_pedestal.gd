extends RefCounted
## The dais (bục) a badge holder's character stands on, drawn in code (grade_look.gd): a round
## metal dais, its top face centred on the feet. Enlisted one tier; officers a lower tier and gems
## round the body; field officers a glow under it; generals a red top, red gems and a strong glow.
## Used by the lobby stage, the party slot and the matchmaking cards; draw() returns false without
## a badge (the caller draws its plain dais or shadow).

const GradeLook := preload("res://screens/ranked/grade_look.gd")

## The preview's top-face half-width (the scale's unit).
const RX := 58.0
## The lobby stage's dais half-width (about assets/env/pedestal.png's 400 px with the lower tier).
const STAGE_RX := 165.0


## Draws the grade's dais on `ci`, the top face's centre at `feet`, `rx` its half-width (the lower
## tier is 1.18 times wider); false (nothing drawn) without a badge.
static func draw(ci: CanvasItem, feet: Vector2, rx: float, g: String) -> bool:
	var l := GradeLook.look(g)
	if l.is_empty():
		return false
	var pal := GradeLook.palette(g)
	var t: int = l["tier"]
	var k := rx / RX
	var ry := 13.0 * k
	var cx := feet.x
	var cy := feet.y
	var red: bool = l["dais_red"]
	if float(l["dais_glow"]) > 0.0:
		GradeLook.fan(ci, feet, GradeLook.ellipse(feet, rx * 1.5, ry * 2.6, 40),
			Color(pal["acc"], 0.8 * float(l["dais_glow"])), Color(pal["acc"], 0.0))
	var h := (10.0 + t * 3.0) * k
	if int(l["dais_tiers"]) >= 2:
		var y2 := cy + h * 0.9
		_body(ci, Vector2(cx, y2), rx * 1.18, ry * 1.18, h * 0.7, pal)
		var top2 := GradeLook.ellipse(Vector2(cx, y2), rx * 1.18, ry * 1.18)
		ci.draw_colored_polygon(top2, pal["lo"])
		top2.append(top2[0])
		GradeLook.stroke_metal(ci, top2, pal, 2.0 * k)
	_body(ci, feet, rx, ry, h, pal)
	GradeLook.stroke_metal(ci, GradeLook.ellipse(Vector2(cx, cy + h), rx, ry, 24, 0.0, PI), pal, 2.5 * k)
	for j: int in (range(-2, 3) if int(l["dais_gems"]) > 0 else []):
		var x: float = cx + j * rx * 0.42
		var y: float = cy + h * 0.55 + ry * sqrt(1.0 - pow(j * 0.42, 2.0))
		GradeLook.diamond(ci, Vector2(x, y), 4.2 * k, pal["red"] if red else pal["mid"], pal["hi"], 0.8 * k)
	var face := GradeLook.ellipse(feet, rx, ry)
	ci.draw_colored_polygon(face, pal["red"] if red else GradeLook.DAIS_TOP)
	face.append(face[0])
	GradeLook.stroke_metal(ci, face, pal, 3.0 * k)
	var ring := GradeLook.ellipse(feet, rx * 0.72, ry * 0.72)
	ring.append(ring[0])
	ci.draw_polyline(ring, Color(pal["hi"], 0.35), 1.2 * k, true)
	return true


## A dais tier's side: from the top face's rim (`top` its centre) down `h`, the front half of the
## ellipse at the bottom, lo at the top to dark at the bottom.
static func _body(ci: CanvasItem, top: Vector2, rx: float, ry: float, h: float, pal: Dictionary) -> void:
	var pts := PackedVector2Array([top + Vector2(-rx, 0)])
	pts.append_array(GradeLook.ellipse(top + Vector2(0, h), rx, ry, 24, PI, 0.0))
	pts.append(top + Vector2(rx, 0))
	var y0 := top.y
	var y1 := top.y + h + ry
	var cols := PackedColorArray()
	for p in pts:
		cols.append((pal["lo"] as Color).lerp(GradeLook.DAIS_FOOT, clampf((p.y - y0) / (y1 - y0), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
