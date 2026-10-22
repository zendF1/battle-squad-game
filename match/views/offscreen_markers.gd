extends Control
## A player out of the camera's view gets a small marker at the screen's edge pointing at them:
## a round badge with their character's head (the match sprite's: Art.side_head(), turned to face
## them; their initial without one) in a ring of their
## colour (PlayerView.color: ally blue / enemy red, mine gold), a pointer on the ring towards
## them and an HP sliver under it. A tap on a marker emits tapped(player id): match_screen pans
## the camera there. Screen px, on the HUD's CanvasLayer under the HUD's own controls; the rest
## of the screen lets presses through (_has_point is only the markers). Redrawn only when a
## marker changes.
## A player counts as on screen while its feet or its name are. place() is the layout (pure):
## the player's screen point clamped into the screen inset by EDGE / TOP / BOTTOM (the HUD's top
## row stays clear), moved off the rects in `avoid` (Hud.marker_avoid(): the move buttons, the
## energy, the skill slot, the item row, the turn portrait), stacked so markers never overlap.

signal tapped(player_id: String)

const Art := preload("res://ui/art.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")

const RADIUS := 24.0
const RING := 3.0
const POINTER := 11.0 # px the pointer reaches past the ring
const EDGE := 48.0 # a marker's centre stays this far inside the sides
const TOP := 128.0 # under the HUD's top row
const BOTTOM := 64.0 # over the bottom edge (the item row and the skill slot are avoided rects)
const GAP := 8.0 # between stacked markers
const HEAD_UP := 84.0 # a player is on screen while its name or its feet are (px above the feet)
const FEET_UP := 6.0
const SEEN_INSET := 8.0 # px inside the screen's edge a body counts as on screen
const HP_W := 40.0
const HP_H := 5.0
const BACK := Color(0.06, 0.09, 0.22, 0.88)
const OUTLINE := Color(0.02, 0.03, 0.1, 0.85)

var views := {} # playerId -> PlayerView (match_screen's)
var avoid: Array = [] # screen Rect2s a marker keeps off (the move buttons)
var _marks: Array = [] # [{id, at, dir, color, hp, tex, initial}] drawn now
var _circle := PackedVector2Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	for i in 32:
		var a := TAU * i / 32.0
		_circle.append(Vector2(cos(a), sin(a)))


## The markers for players at screen points `points` ({id: Vector2}) on a screen of `screen` px:
## [{id, at (the marker's centre), dir (unit, towards the player)}] for those whose point is off
## screen, top to bottom, each at the nearest spot along its edge off `avoid` and the others.
static func place(points: Dictionary, screen: Vector2, avoid_rects: Array = []) -> Array:
	var seen := Rect2(Vector2.ZERO, screen).grow(-SEEN_INSET)
	var lo := Vector2(EDGE, TOP)
	var hi := Vector2(screen.x - EDGE, screen.y - BOTTOM)
	if hi.y < lo.y:
		lo.y = screen.y / 2.0
		hi.y = screen.y / 2.0
	var wanted: Array = [] # [id, the clamped point], top to bottom
	for id in points:
		var p: Vector2 = points[id]
		if not seen.has_point(p):
			wanted.append([id, p.clamp(lo, hi)])
	wanted.sort_custom(func(a, b): return a[1].y < b[1].y or (a[1].y == b[1].y and str(a[0]) < str(b[0])))
	var out: Array = []
	var step := RADIUS * 2.0 + GAP + HP_H
	for w in wanted:
		var at: Vector2 = w[1]
		# The nearest spot along the edge (up or down, a marker's step at a time) off the HUD's
		# rects and the markers already placed; the clamped point when there is none.
		for k in 24:
			var dy := step * ceilf(k / 2.0) * (1.0 if k % 2 == 1 else -1.0)
			var y := at.y + dy
			if y < lo.y or y > hi.y:
				continue
			var spot := Vector2(at.x, y)
			if not _blocked(spot, out, avoid_rects, step):
				at = spot
				break
		out.append({"id": w[0], "at": at, "dir": Vector2.ZERO})
	for m in out:
		var d: Vector2 = points[m["id"]] - m["at"]
		m["dir"] = d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	return out


static func _blocked(spot: Vector2, placed: Array, avoid_rects: Array, step: float) -> bool:
	for r in avoid_rects:
		if (r as Rect2).grow(RADIUS + 4.0).has_point(spot):
			return true
	for m in placed:
		if spot.distance_to(m["at"]) < step:
			return true
	return false


func _process(_delta: float) -> void:
	var xf := get_viewport().get_canvas_transform() if is_inside_tree() else Transform2D()
	var points := {}
	var seen := Rect2(Vector2.ZERO, size).grow(-SEEN_INSET)
	for id in views:
		var v = views[id]
		if v == null or not is_instance_valid(v) or v.is_dead():
			continue
		var head: Vector2 = xf * (v.position + Vector2(0, -HEAD_UP))
		var feet: Vector2 = xf * (v.position + Vector2(0, -FEET_UP))
		if not seen.has_point(head) and not seen.has_point(feet):
			points[id] = (head + feet) / 2.0
	var now := place(points, size, avoid)
	for m in now:
		var v = views[m["id"]]
		m["color"] = LobbyUi.GOLD if v.is_me else v.color
		m["hp"] = clampf(float(v.hp) / maxf(1.0, float(v.max_hp)), 0.0, 1.0)
		m["char"] = v.character_id()
		m["at"] = (m["at"] as Vector2).round()
	if now == _marks:
		return
	_marks = now
	queue_redraw()


## The markers shown now ([{id, at, dir, ...}]).
func shown() -> Array:
	return _marks


func _has_point(point: Vector2) -> bool:
	return _mark_at(point) != ""


func _mark_at(point: Vector2) -> String:
	for m in _marks:
		if point.distance_to(m["at"]) <= RADIUS + POINTER:
			return str(m["id"])
	return ""


func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not press:
		return
	var id := _mark_at(event.position)
	if id != "":
		tapped.emit(id)
		accept_event()


func _draw() -> void:
	for m in _marks:
		_draw_mark(m)


func _draw_mark(m: Dictionary) -> void:
	var c: Vector2 = m["at"]
	var col: Color = m["color"]
	var d: Vector2 = m["dir"]
	var n := Vector2(-d.y, d.x)
	# The pointer: a wedge from the ring towards the player.
	var tip := c + d * (RADIUS + POINTER)
	var wedge := PackedVector2Array([tip, c + d * (RADIUS - 2.0) + n * 10.0, c + d * (RADIUS - 2.0) - n * 10.0])
	var rim := PackedVector2Array([c + d * (RADIUS + POINTER + 2.5), c + d * (RADIUS - 3.0) + n * 12.5, c + d * (RADIUS - 3.0) - n * 12.5])
	draw_colored_polygon(rim, OUTLINE)
	draw_colored_polygon(wedge, col)
	draw_circle(c, RADIUS + RING + 1.5, OUTLINE)
	draw_circle(c, RADIUS + RING, col)
	draw_circle(c, RADIUS, BACK)
	var head := Art.side_head(str(m.get("char", ""))) if str(m.get("char", "")) != "" else {}
	if not head.is_empty():
		draw_colored_polygon(_disc(c), Color.WHITE, head_uvs(head, d.x < 0.0), head["texture"])
	else:
		var font := get_theme_default_font()
		var v = views.get(m["id"])
		var initial: String = str(v.display_name() if v != null else m["id"]).left(1).to_upper()
		draw_string(font, c + Vector2(-RADIUS, 9), initial, HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 26, Color.WHITE)
	# The HP sliver under the badge.
	var bar := Rect2(c + Vector2(-HP_W / 2.0, RADIUS + RING + 4.0), Vector2(HP_W, HP_H))
	draw_rect(bar.grow(1.5), OUTLINE)
	var hp: float = m["hp"]
	var fill := Color(1.0, 0.3, 0.25).lerp(Color(1.0, 0.85, 0.2), clampf(hp * 2.0, 0.0, 1.0))
	fill = fill.lerp(Color(0.3, 0.9, 0.35), clampf(hp * 2.0 - 1.0, 0.0, 1.0))
	if hp > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp, bar.size.y)), fill)


func _disc(c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in _circle:
		pts.append(c + p * (RADIUS - 1.0))
	return pts


## The UVs of the head crop (Art.side_head()) over the badge's disc; mirrored: facing left (the
## frames face right), towards a player on the left.
func head_uvs(head: Dictionary, mirrored: bool) -> PackedVector2Array:
	var r: Rect2 = head["rect"]
	var size: Vector2 = (head["texture"] as Texture2D).get_size()
	var out := PackedVector2Array()
	for p in _circle:
		var u := 0.5 + 0.5 * (-p.x if mirrored else p.x)
		out.append((r.position + Vector2(u, 0.5 + 0.5 * p.y) * r.size) / size)
	return out
