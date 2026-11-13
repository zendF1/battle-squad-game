extends RefCounted
## The look of a badge holder (rankBadge: last season's final grade) drawn in code: the frame
## round their card (grade_frame.gd), the card's background (the face shader FACE_CODE, used by
## player_card.gd and the party slot's frame) and the pedestal under their character
## (grade_pedestal.gd: the cards and the lobby stage). Art only (the grade ids, names and order
## are the game data's): four tiers by the grade's group (grade_badge.gd group_of()), escalating
## by shape, not only colour:
## - 0 enlisted (green): a thin bevelled metal rim, short corner brackets, no glow, a plain
##   medallion; a one-tier round dais;
## - 1 officers (cadet, company; silver): a thicker rim with an inner line, gems at the corners, a
##   light glow, a small laurel; the dais gets a lower tier and gems round its body;
## - 2 field officers (gold): + pointed side wings, a bottom plate with one star, a medium glow,
##   a thicker laurel; a glow under the dais;
## - 3 generals (red-gold): + a second (red) band, stars at the corners, red wings with a star,
##   a red plate with the grade's stars, rays behind the medallion, a full laurel with a red
##   ribbon, a strong glow; a red dais top, red gems, a strong glow.
## Inside a tier each step (GradeBadge.marks_of) adds a little: longer brackets, more laurel
## leaves, glow, rays and plate stars, more sparkles on the background. look() gives every count
## in the approved preview's px (a 166 px wide card), the callers scale them.
## No badge (""): look() is {} and the callers draw the plain card, dais and frame.

const GradeBadge := preload("res://screens/ranked/grade_badge.gd")

## The tier of each group.
const TIERS := {"enlisted": 0, "cadet": 1, "company": 1, "field": 2, "general": 3}
## The step of the preview's grade per tier (Trung sĩ, Đại úy, Đại tá, Thượng tướng): look() gives
## the preview's counts there.
const SAMPLE := [4, 4, 4, 3]
## Per tier: metal hi / mid / lo, the background's top b1 and bottom b2, acc (the spotlight, the
## dais's glow), red (the generals' band, wings, plate, dais).
const PALETTES := [
	{"hi": Color("#c8e6a8"), "mid": Color("#6fa04f"), "lo": Color("#2e4a22"),
		"b1": Color("#4f8a43"), "b2": Color("#1c3a1f"), "acc": Color("#bfe59a"), "red": Color("#c0392b")},
	{"hi": Color("#ffffff"), "mid": Color("#aab6c4"), "lo": Color("#4d5866"),
		"b1": Color("#5b7396"), "b2": Color("#1b263d"), "acc": Color("#e6eef8"), "red": Color("#c0392b")},
	{"hi": Color("#fff1b8"), "mid": Color("#e0a93a"), "lo": Color("#7a4f0e"),
		"b1": Color("#a8772a"), "b2": Color("#33220c"), "acc": Color("#ffe08a"), "red": Color("#c0392b")},
	{"hi": Color("#fff4c2"), "mid": Color("#f0b836"), "lo": Color("#8f2a1c"),
		"b1": Color("#b23a2c"), "b2": Color("#3a0f12"), "acc": Color("#ffd86b"), "red": Color("#c0392b")},
]
## The medallion's well and the dais's top (not a general's).
const WELL := Color("#1b2640")
const DAIS_TOP := Color("#1b2742")
const DAIS_FOOT := Color("#0d1424")
## The background's darker foot (behind the name).
const FOOT := Color("#0b1426")

## The card's face: a rounded rect (nothing shows past the corners). Without a badge (ranked 0) the
## dark face with the team's glow from the top; a badge holder's (ranked 1) the tier's colours top
## to bottom with a spotlight behind the character and a vignette, darker from foot_y down. The
## sweeping light band of a searching card over both.
const FACE_CODE := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(268.0, 520.0);
uniform float radius = 22.0;
uniform vec4 bg : source_color = vec4(0.05, 0.08, 0.2, 0.9);
uniform vec4 rim : source_color = vec4(0.36, 0.62, 1.0, 1.0);
uniform float glow = 0.38;
uniform float shine_x = -1000.0;
uniform float ranked = 0.0;
uniform vec4 b1 : source_color = vec4(0.3, 0.5, 0.3, 1.0);
uniform vec4 b2 : source_color = vec4(0.1, 0.2, 0.1, 1.0);
uniform vec4 acc : source_color = vec4(0.75, 0.9, 0.6, 1.0);
uniform vec4 foot : source_color = vec4(0.043, 0.078, 0.149, 1.0);
uniform float foot_y = 100000.0;
varying vec2 local;
void vertex() {
	local = VERTEX;
}
float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	float d = sd_round(local - rect_size * 0.5, rect_size * 0.5, radius);
	float inside = 1.0 - smoothstep(-1.0, 0.5, d);
	vec3 c = mix(bg.rgb, rim.rgb, glow * (1.0 - smoothstep(0.0, rect_size.y * 0.55, local.y)));
	float a = bg.a;
	if (ranked > 0.5) {
		vec2 uv = local / rect_size;
		c = mix(b1.rgb, b2.rgb, uv.y);
		c = mix(c, acc.rgb, 0.55 * (1.0 - clamp(length((uv - vec2(0.5, 0.42)) / 0.55), 0.0, 1.0)));
		c = mix(c, vec3(0.0), 0.45 * clamp((length(uv - vec2(0.5)) / 0.75 - 0.6) / 0.4, 0.0, 1.0));
		c = mix(c, foot.rgb, 0.35 * step(foot_y, local.y));
		a = 1.0;
	}
	float x = local.x + (local.y - rect_size.y * 0.5) * 0.3;
	float band = 1.0 - smoothstep(0.0, 70.0, abs(x - shine_x));
	c += vec3(band * band * 0.14);
	COLOR = vec4(c, a * inside);
}
"""

static var _face_shader: Shader


## The tier of a grade (0..3), -1 without a badge.
static func tier_of(g: String) -> int:
	if g == "":
		return -1
	return int(TIERS.get(GradeBadge.group_of(g), -1))


## The tier's colours ({} without a badge).
static func palette(g: String) -> Dictionary:
	var t := tier_of(g)
	return PALETTES[t] if t >= 0 else {}


## Every ornament's count and size for a grade, in the preview's px; {} without a badge.
static func look(g: String) -> Dictionary:
	var t := tier_of(g)
	if t < 0:
		return {}
	var step := clampi(GradeBadge.marks_of(g), 1, 5) # an admin-added grade: the tier's first step
	var d: int = step - SAMPLE[t] # steps above (+) / below (-) the preview's grade
	return {
		"tier": t,
		"rim": [4.0, 6.0, 7.0, 8.0][t],
		"glow": maxf(0.0, [0.0, 5.0, 10.0, 18.0][t] * (1.0 + 0.1 * d)),
		"inner_line": [0.0, 0.3, 0.55, 0.55][t],
		"red_band": t >= 3,
		"bracket_len": [16.0, 22.0, 28.0, 34.0][t] + 1.5 * d,
		"bracket_w": [3.0, 4.0, 5.0, 6.0][t],
		"gems": t >= 1,
		"corner_stars": 2 if t >= 3 else 0,
		"wing": [0.0, 0.0, 13.0, 20.0][t],
		"wing_star": t >= 3,
		"plate": [0.0, 0.0, 44.0, 70.0][t],
		"plate_stars": [0, 0, 1, clampi(step, 1, 4)][t],
		"leaves": [0, 1 + int(step >= 3), 3 + int(step >= 3), 5][t],
		"ribbon": t >= 3,
		"rays": 6 + 2 * step if t >= 3 else 0,
		"sparkles": maxi(0, [0, 4, 8, 14][t] + (d if t >= 1 else 0)),
		"dais_tiers": 2 if t >= 1 else 1,
		"dais_gems": 5 if t >= 1 else 0,
		"dais_glow": [0.0, 0.0, 0.55, 0.9][t],
		"dais_red": t >= 3,
	}


## The metal gradient (hi, mid, lo, mid, hi) at t 0..1.
static func metal(pal: Dictionary, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var stops := [[0.0, pal["hi"]], [0.35, pal["mid"]], [0.6, pal["lo"]], [0.85, pal["mid"]], [1.0, pal["hi"]]]
	for i in range(1, stops.size()):
		if t <= stops[i][0]:
			var a: Array = stops[i - 1]
			var b: Array = stops[i]
			return (a[1] as Color).lerp(b[1], (t - a[0]) / (b[0] - a[0]))
	return pal["hi"]


## The metal gradient over `box` (top-left to bottom-right, as SVG's objectBoundingBox) at each point.
static func metal_colors(pal: Dictionary, pts: PackedVector2Array, box: Rect2) -> PackedColorArray:
	var out := PackedColorArray()
	var s := Vector2(maxf(box.size.x, 0.001), maxf(box.size.y, 0.001))
	for p in pts:
		var u := (p - box.position) / s
		out.append(metal(pal, (u.x + u.y) / 2.0))
	return out


## Points round an ellipse from angle a0 to a1 (n segments; a full turn is not closed).
static func ellipse(c: Vector2, rx: float, ry: float, n: int = 48, a0: float = 0.0, a1: float = TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var full := is_equal_approx(a1 - a0, TAU)
	for i in (n if full else n + 1):
		var a := a0 + (a1 - a0) * i / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A closed rounded rect path (the first point repeated at the end), starting at the top edge's
## middle (a straight joint there), straight edges cut every `step` px so a gradient along it is
## smooth.
static func round_rect(r: Rect2, rad: float, step: float = 16.0) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) / 2.0)
	var pts := PackedVector2Array()
	var corners := [[Vector2(r.end.x - rad, r.position.y + rad), -PI / 2], [r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI / 2], [r.position + Vector2(rad, rad), PI]]
	var start := Vector2(r.get_center().x, r.position.y)
	var prev := start
	for c in corners:
		var a0: float = c[1]
		var first: Vector2 = c[0] + Vector2(cos(a0), sin(a0)) * rad
		_line_to(pts, prev, first, step)
		for i in 9:
			var a: float = a0 + PI / 2 * i / 8.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
		prev = pts[pts.size() - 1]
	_line_to(pts, prev, start, step)
	pts.append(start)
	return pts


static func _line_to(pts: PackedVector2Array, from: Vector2, to: Vector2, step: float) -> void:
	var n := maxi(1, ceili(from.distance_to(to) / step))
	for i in n:
		pts.append(from.lerp(to, i / float(n)))


## A filled fan: `centre` in c_in, the ring's points in c_out (a soft glow).
static func fan(ci: CanvasItem, centre: Vector2, ring: PackedVector2Array, c_in: Color, c_out: Color) -> void:
	var pts := PackedVector2Array([centre])
	pts.append_array(ring)
	var cols := PackedColorArray([c_in])
	var idx := PackedInt32Array()
	for i in ring.size():
		cols.append(c_out)
		idx.append_array([0, 1 + i, 1 + (i + 1) % ring.size()])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)


## A metal stroke along `pts`, the gradient over the points' own box.
static func stroke_metal(ci: CanvasItem, pts: PackedVector2Array, pal: Dictionary, width: float) -> void:
	ci.draw_polyline_colors(pts, metal_colors(pal, pts, bounds(pts)), width, true)


static func bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## A filled polygon with a metal outline.
static func plate(ci: CanvasItem, pts: PackedVector2Array, fill: Color, pal: Dictionary, width: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	stroke_metal(ci, closed, pal, width)


static func star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(GradeBadge.star_points(c, r, r * 0.45)), color)


## A diamond (half-diagonal `half`) with an outline.
static func diamond(ci: CanvasItem, c: Vector2, half: float, fill: Color, edge: Color, width: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -half), c + Vector2(half, 0), c + Vector2(0, half), c + Vector2(-half, 0)])
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, edge, width, true)


## The card face's shader (FACE_CODE), made once.
static func face_shader() -> Shader:
	if _face_shader == null:
		_face_shader = Shader.new()
		_face_shader.code = FACE_CODE
	return _face_shader


## Sets a face material to the grade's background (the plain face without a badge).
static func set_face(mat: ShaderMaterial, g: String) -> void:
	var pal := palette(g)
	mat.set_shader_parameter("ranked", 0.0 if pal.is_empty() else 1.0)
	if not pal.is_empty():
		mat.set_shader_parameter("b1", pal["b1"])
		mat.set_shader_parameter("b2", pal["b2"])
		mat.set_shader_parameter("acc", pal["acc"])


## The background's sparkles in `card` (white stars, more with the tier and the step), the
## preview's spread scaled to the card.
static func draw_sparkles(ci: CanvasItem, card: Rect2, g: String) -> void:
	var l := look(g)
	if l.is_empty():
		return
	var k := card.size.x / 166.0
	var ky := card.size.y / 276.0
	for i in int(l["sparkles"]):
		var p := card.position + Vector2((12 + (i * 53) % 142) * k, (16 + (i * 37) % 150) * ky)
		star(ci, p, (2 + i % 3) * k, Color(1, 1, 1, 0.7))
