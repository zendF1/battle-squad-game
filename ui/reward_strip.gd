extends Control
## Reward tiles (ui/reward_model.gd tiles, or ResultModel.reward_tiles()): every tile the same
## frame, its icon (coin, gem, stone (its picture tells the level), chest, battle item, equipment
## piece with its upgrade aura, character) over its count ("×3", "×1.200"; a piece "+16" in its
## upgrade colour, a character none), no names (a hover / long press shows the name as a
## tooltip). Each tile glows (ui/reward_glow.gd, RewardModel.glow(): stone level, upgrade tier,
## kind; higher = brighter) behind its icon, its border in that colour. Up to max_rows rows
## (each centred; the tiles spread evenly over them) while they fit, then wider than the strip it
## scrolls horizontally (mouse wheel, mouse or touch drag), never shrinks, the tiles fading as
## they slide past an edge and a chevron on the side with more. reveal() pops the tiles in one
## by one.
##
## set_tiles(tiles) builds it; qty_label(kind) is the count of the first tile of that kind (the
## result screens count the coins up on it); tile_node(i) / glow_node(i) for the reward reveal.

const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const ChestIcon := preload("res://ui/chest_icon.gd")
const ItemIcon := preload("res://ui/item_icon.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const RewardGlow := preload("res://ui/reward_glow.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")

const TILE := Vector2(104, 112)
const GAP := 12.0
const ICON := 64
const WHEEL_STEP := 60.0
const EDGE_ALPHA := 0.3
const FRAME := Color(0.05, 0.07, 0.18, 0.6)

## The tile frame and icon size (set before set_tiles()).
var tile_size := TILE
var icon_px := ICON
var gap := GAP
## How many rows the tiles may wrap into before the strip scrolls.
var max_rows := 1
## The glow behind each icon.
var glow := true

var tiles: Array = []
var scroll := 0.0:
	set(v):
		scroll = clampf(v, 0.0, max_scroll())
		_place()

var _row: Control
var _edges: Control # over the tiles: the fades and chevrons
var _nodes: Array = [] # one Control per tile
var _labels: Array = []
var _glows: Array = []
var _counts: Array = [] # tiles per row (layout())
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
	resized.connect(_layout)


func set_tiles(value: Array) -> void:
	tiles = value
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	_labels.clear()
	_glows.clear()
	custom_minimum_size = tile_size
	for i in tiles.size():
		var tile := _tile(tiles[i])
		_row.add_child(tile)
		_nodes.append(tile)
	_layout()


## Tiles per row for `n` tiles of width `tile_w` in `width`: one row while they fit, else up to
## `rows` rows spread evenly (the first rows one more), wider than `width` once even those
## overflow (the strip then scrolls).
static func layout(n: int, width: float, tile_w: float, tile_gap: float, rows: int) -> Array:
	if n <= 0:
		return []
	var fit := maxi(1, int(floor((width + tile_gap + 0.5) / (tile_w + tile_gap))))
	if n <= fit or rows <= 1:
		return [n]
	var r := mini(rows, ceili(float(n) / fit))
	var out: Array = []
	var left := n
	for i in r:
		var take := ceili(float(left) / (r - i))
		out.append(take)
		left -= take
	return out


func _layout() -> void:
	if _row == null:
		return
	_counts = layout(tiles.size(), size.x, tile_size.x, gap, max_rows)
	var wide := content_width()
	var i := 0
	for r in _counts.size():
		var n: int = _counts[r]
		var row_w := n * tile_size.x + maxi(n - 1, 0) * gap
		for c in n:
			if i < _nodes.size():
				(_nodes[i] as Control).position = Vector2((wide - row_w) / 2.0 + c * (tile_size.x + gap), r * (tile_size.y + gap))
			i += 1
	_row.size = Vector2(wide, content_height())
	if max_rows > 1:
		custom_minimum_size.y = content_height()
	scroll = scroll


## The widest row's width (px).
func content_width() -> float:
	var most := 0
	for n in _counts:
		most = maxi(most, int(n))
	return maxf(most * tile_size.x + maxi(most - 1, 0) * gap, 0.0)


func content_height() -> float:
	var rows := maxi(_counts.size(), 1)
	return rows * tile_size.y + (rows - 1) * gap


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


## The i-th tile's holder (placed in the row; the reveal flies it in), its glow (null without).
func tile_node(i: int) -> Control:
	return _nodes[i] if i >= 0 and i < _nodes.size() else null


func glow_node(i: int) -> Control:
	return _glows[i] if i >= 0 and i < _glows.size() else null


## Pops the tiles in left to right (scale from small with a bounce, the glow flashing as each
## lands), after `delay` s.
func reveal(delay: float = 0.0) -> void:
	for i in _nodes.size():
		var n: Control = _nodes[i]
		n.scale = Vector2.ONE * 0.3
		n.modulate.a = 0.0
		var t := n.create_tween()
		t.tween_interval(delay + i * 0.08)
		t.tween_property(n, "modulate:a", 1.0, 0.12)
		t.parallel().tween_property(n, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var g := glow_node(i)
		if g != null:
			t.tween_callback(g.land)


func _place() -> void:
	if _row == null:
		return
	_row.position = Vector2((size.x - content_width()) / 2.0 if fits() else -scroll, maxf((size.y - content_height()) / 2.0, 0.0))
	for n in _nodes:
		(n.get_child(0) as CanvasItem).modulate.a = edge_alpha(_row.position.x + n.position.x)
	_edges.queue_redraw()


## A tile's fade by its left x in the strip: 1 while all of it shows, down to EDGE_ALPHA as it
## slides out past an edge.
func edge_alpha(left_x: float) -> float:
	var shown := clampf((minf(left_x + tile_size.x, size.x) - maxf(left_x, 0.0)) / tile_size.x, 0.0, 1.0)
	return lerpf(EDGE_ALPHA, 1.0, shown * shown)


## A tile: a holder (placed, popped in by reveal()) around the framed panel (faded at the edges):
## the glow, the icon, the count.
func _tile(t: Dictionary) -> Control:
	var holder := Control.new()
	holder.name = "Tile_%s" % str(t["id"])
	holder.size = tile_size
	holder.pivot_offset = tile_size / 2.0
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	var g := RewardModel.glow(t)
	var tile := Panel.new()
	tile.name = "Frame"
	tile.size = tile_size
	holder.add_child(tile)
	var border: Color = Color(g["color"], 0.35 + 0.45 * float(g["power"])) if glow else Color(0.55, 0.7, 1.0, 0.35)
	tile.add_theme_stylebox_override("panel", LobbyUi.box(FRAME, 16, 0, border, 3 if glow else 2))
	tile.mouse_filter = MOUSE_FILTER_PASS # the name on hover; a drag still scrolls the strip
	tile.tooltip_text = str(t.get("name", ""))
	var top := maxf((tile_size.y - icon_px - 30.0) / 2.0, 4.0)
	if glow:
		var gl: Control = RewardGlow.make(g, Vector2(icon_px, icon_px) * 1.2)
		gl.name = "Glow"
		gl.position = Vector2((tile_size.x - gl.size.x) / 2.0, top + (icon_px - gl.size.y) / 2.0)
		tile.add_child(gl)
		_glows.append(gl)
	var icon := tile_icon(t, icon_px)
	icon.name = "Icon"
	icon.position = Vector2((tile_size.x - icon_px) / 2.0, top)
	icon.size = Vector2(icon_px, icon_px)
	tile.add_child(icon)
	var l := LobbyUi.text(count_text(t), 24 if tile_size.x < 130 else 28, count_color(t), true)
	l.name = "Qty"
	LobbyUi.outline(l, 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = Vector2(0, tile_size.y - 36)
	l.size = Vector2(tile_size.x, 32)
	l.clip_text = true
	l.mouse_filter = MOUSE_FILTER_IGNORE
	tile.add_child(l)
	_labels.append(l)
	return holder


## The count under a tile: "×3"; a piece its "+16" (nothing at +0), a character nothing.
static func count_text(t: Dictionary) -> String:
	match str(t.get("kind", "")):
		"equipment":
			var up := int(t.get("upgrade", 0))
			var plus := "+%d" % up if up > 0 else ""
			if int(t.get("qty", 1)) <= 1:
				return plus
			return ("%s %s" % [plus, RewardModel.qty_text(int(t["qty"]))]).strip_edges()
		"character":
			return ""
	return RewardModel.qty_text(int(t.get("qty", 0)))


static func count_color(t: Dictionary) -> Color:
	if str(t.get("kind", "")) == "equipment" and int(t.get("upgrade", 0)) > 0:
		return UpgradeModel.milestone_color(int(t["upgrade"])).lerp(Color.WHITE, 0.25)
	return Color.WHITE


## A tile's picture, `px` square.
static func tile_icon(t: Dictionary, px: int) -> Control:
	var c: Control
	match str(t.get("kind", "")):
		"coin":
			c = LobbyUi.icon("coin", px)
		"gem":
			c = load("res://ui/wallet_pills.gd").locked_gem_icon(px) if t.get("locked", false) else LobbyUi.icon("gem", px)
		"stone":
			c = LobbyUi.icon(Art.stone_icon(int(t["level"])), px)
		"chest":
			c = ChestIcon.make(str(t["id"]), px)
		"equipment":
			var equipment_model = load("res://screens/home/equipment_model.gd")
			var equipment_ui = load("res://screens/home/equipment_ui.gd")
			c = equipment_ui.item_icon(equipment_model.item_of(PlayerState.catalog, str(t["id"])), {"upgradeLevel": int(t.get("upgrade", 0))}, px)
		"character":
			c = LobbyUi.icon(Art.portrait(str(t["id"])), px)
		_:
			c = ItemIcon.make(str(t["id"]), px)
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
