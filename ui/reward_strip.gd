extends Control
## A row of reward tiles (ResultModel.reward_tiles()): every tile the same TILE frame, its icon
## (coin, stone (its picture tells the level), chest, item) over its count ("×3", "×1.200"), no
## names (a hover / long press shows the name as a tooltip). Centred while the row fits; wider
## than the strip it scrolls horizontally (mouse wheel, mouse or touch drag), never wraps or
## shrinks, the tiles fading as they slide past an edge and a chevron on the side with more. reveal() pops the tiles in one by one.
##
## set_tiles(tiles) builds it; qty_label(kind) is the count of the first tile of that kind (the
## result screens count the coins up on it).

const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const ChestIcon := preload("res://ui/chest_icon.gd")
const ItemIcon := preload("res://ui/item_icon.gd")
const ResultModel := preload("res://match/result_model.gd")

const TILE := Vector2(104, 112)
const GAP := 12.0
const ICON := 64
const WHEEL_STEP := 60.0
const EDGE_ALPHA := 0.3
const FRAME := Color(0.08, 0.12, 0.26, 0.92)
const BORDER := Color(0.55, 0.7, 1.0, 0.35)

var tiles: Array = []
var scroll := 0.0:
	set(v):
		scroll = clampf(v, 0.0, max_scroll())
		_place()

var _row: Control
var _edges: Control # over the tiles: the fades and chevrons
var _nodes: Array = [] # one Control per tile
var _labels: Array = []
var _dragging := false


func _init() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(TILE.x, TILE.y)
	_row = Control.new()
	_row.name = "Row"
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_row)
	_edges = Control.new()
	_edges.name = "Edges"
	_edges.mouse_filter = MOUSE_FILTER_IGNORE
	_edges.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_edges.draw.connect(_draw_edges)
	add_child(_edges)
	resized.connect(func() -> void: scroll = scroll)


func set_tiles(value: Array) -> void:
	tiles = value
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	_labels.clear()
	for i in tiles.size():
		var tile := _tile(tiles[i])
		tile.position = Vector2(i * (TILE.x + GAP), 0)
		_row.add_child(tile)
		_nodes.append(tile)
	_row.size = Vector2(content_width(), TILE.y)
	scroll = 0.0


## The whole row's width (px).
func content_width() -> float:
	return maxf(tiles.size() * TILE.x + maxi(tiles.size() - 1, 0) * GAP, 0.0)


## How far the row scrolls: 0 while it fits.
func max_scroll() -> float:
	return maxf(content_width() - size.x, 0.0)


func fits() -> bool:
	return content_width() <= size.x + 0.5


## The count label of the first tile of `kind` ("coin"), null without one.
func qty_label(kind: String) -> Label:
	for i in tiles.size():
		if str(tiles[i]["kind"]) == kind:
			return _labels[i]
	return null


## Pops the tiles in left to right (scale from small with a bounce), after `delay` s.
func reveal(delay: float = 0.0) -> void:
	for i in _nodes.size():
		var n: Control = _nodes[i]
		n.scale = Vector2.ONE * 0.3
		n.modulate.a = 0.0
		var t := n.create_tween()
		t.tween_interval(delay + i * 0.08)
		t.tween_property(n, "modulate:a", 1.0, 0.12)
		t.parallel().tween_property(n, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _place() -> void:
	if _row == null:
		return
	_row.position = Vector2((size.x - content_width()) / 2.0 if fits() else -scroll, (size.y - TILE.y) / 2.0)
	for n in _nodes:
		(n.get_child(0) as CanvasItem).modulate.a = edge_alpha(_row.position.x + n.position.x)
	_edges.queue_redraw()


## A tile's fade by its left x in the strip: 1 while all of it shows, down to EDGE_ALPHA as it
## slides out past an edge.
func edge_alpha(left_x: float) -> float:
	var shown := clampf((minf(left_x + TILE.x, size.x) - maxf(left_x, 0.0)) / TILE.x, 0.0, 1.0)
	return lerpf(EDGE_ALPHA, 1.0, shown * shown)


## A tile: a holder (placed, popped in by reveal()) around the framed panel (faded at the edges).
func _tile(t: Dictionary) -> Control:
	var holder := Control.new()
	holder.name = "Tile_%s" % str(t["id"])
	holder.size = TILE
	holder.pivot_offset = TILE / 2.0
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	var tile := Panel.new()
	tile.name = "Frame"
	tile.size = TILE
	holder.add_child(tile)
	tile.add_theme_stylebox_override("panel", LobbyUi.box(FRAME, 14, 0, BORDER, 2))
	tile.mouse_filter = MOUSE_FILTER_PASS # the name on hover; a drag still scrolls the strip
	tile.tooltip_text = str(t.get("name", ""))
	var icon := _icon(t)
	icon.position = Vector2((TILE.x - ICON) / 2.0, 8)
	icon.size = Vector2(ICON, ICON)
	tile.add_child(icon)
	var l := LobbyUi.text(ResultModel.tile_qty_text(int(t["qty"])), 24, Color.WHITE, true)
	l.name = "Qty"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(0, TILE.y - 38)
	l.size = Vector2(TILE.x, 32)
	l.clip_text = true
	l.mouse_filter = MOUSE_FILTER_IGNORE
	tile.add_child(l)
	_labels.append(l)
	return holder


static func _icon(t: Dictionary) -> Control:
	var c: Control
	match str(t["kind"]):
		"coin":
			c = LobbyUi.icon("coin", ICON)
		"stone":
			c = LobbyUi.icon(Art.stone_icon(int(t["level"])), ICON)
		"chest":
			c = ChestIcon.make(str(t["id"]), ICON)
		_:
			c = ItemIcon.make(str(t["id"]), ICON)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed and not fits()
		elif mb.pressed and not fits():
			var step := WHEEL_STEP * maxf(mb.factor, 1.0)
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
					scroll += step
					accept_event()
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
					scroll -= step
					accept_event()
	elif event is InputEventMouseMotion and _dragging:
		scroll -= (event as InputEventMouseMotion).relative.x
		accept_event()
	elif event is InputEventScreenDrag and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", true):
		scroll -= (event as InputEventScreenDrag).relative.x
		accept_event()
	elif event is InputEventPanGesture and not fits():
		scroll += (event as InputEventPanGesture).delta.x * 20.0 + (event as InputEventPanGesture).delta.y * 20.0
		accept_event()


## Over the tiles: a chevron on each side that has more.
func _draw_edges() -> void:
	if fits():
		return
	if scroll > 0.5:
		_edge(false)
	if scroll < max_scroll() - 0.5:
		_edge(true)


func _edge(right: bool) -> void:
	var cx := size.x - 16.0 if right else 16.0
	var cy := size.y / 2.0
	var d := 1.0 if right else -1.0
	_edges.draw_circle(Vector2(cx, cy), 16.0, Color(0.04, 0.06, 0.16, 0.85))
	_edges.draw_polyline(PackedVector2Array([Vector2(cx - 4 * d, cy - 9), Vector2(cx + 4 * d, cy), Vector2(cx - 4 * d, cy + 9)]),
		Color(1, 1, 1, 0.95), 4.0, true)
