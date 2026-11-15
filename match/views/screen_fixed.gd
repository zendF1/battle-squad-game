extends Node2D
## What is drawn in the match world for the player to read keeps one screen size at every camera
## zoom (min_zoom() to CameraModel.MAX_ZOOM): only the gameplay is magnified (characters, bosses
## and the effects on their bodies, terrain, guns, shells, blasts and skill effects, gameplay areas
## on the ground); numbers, names, HP bars, badges, the turn arrow, the aim guide and its cancel
## ring, markers and icons are not.
##
## A ScreenFixed node scales what is under it by 1 / the camera's zoom round `pivot` (its parent's
## px), every frame: its children keep their parent-space coordinates, sit exactly where they did
## at zoom 1 when on the pivot, and their size and offset from the pivot are screen px. `follow`
## (+ `follow_offset`) moves the pivot with a node (a running damage number over a falling player);
## free_when_empty: it goes once its children have (a popup freed itself). hold() wraps a node.
## per_px() / per_px_of(): world px per screen px (1 / the zoom), for drawing that cannot sit under
## one (the aim guide's Line2D widths, the bullseye, the cancel ring).

signal rescaled # the scale changed (a parent drawing in the same space redraws)

var pivot := Vector2.ZERO
var follow: Node2D
var follow_offset := Vector2.ZERO
var free_when_empty := false
var factor := 1.0 # the scale now (1 / the zoom)
var canvas := Transform2D() # the camera's transform when out of the tree (tests)


## World px per screen px under the canvas transform xf (its zoom).
static func per_px_of(xf: Transform2D) -> float:
	var z := absf(xf.get_scale().x)
	return 1.0 / z if z > 1e-6 else 1.0


## World px per screen px where item is drawn (1 outside the tree).
static func per_px(item: CanvasItem) -> float:
	return per_px_of(item.get_canvas_transform()) if item != null and item.is_inside_tree() else 1.0


## child added under a new ScreenFixed in parent, pivoted at `at` (parent px; or following
## follow_node + offset); it frees itself with the child. Returns the holder.
static func hold(parent: Node, child: Node, at: Vector2, follow_node: Node2D = null, offset: Vector2 = Vector2.ZERO) -> Node2D:
	var h: Node2D = load("res://match/views/screen_fixed.gd").new()
	h.pivot = at
	h.follow = follow_node
	h.follow_offset = offset
	h.free_when_empty = true
	h.add_child(child)
	parent.add_child(h)
	return h


func _init() -> void:
	process_priority = 100 # after the camera moved this frame


func _enter_tree() -> void:
	fit()


func _process(_delta: float) -> void:
	if free_when_empty and get_child_count() == 0:
		queue_free()
		return
	fit()


## Applies the camera's zoom now.
func fit() -> void:
	if follow != null and is_instance_valid(follow):
		pivot = follow.position + follow_offset
	var s := per_px(self) if is_inside_tree() else per_px_of(canvas)
	position = pivot * (1.0 - s)
	if not is_equal_approx(s, factor):
		factor = s
		scale = Vector2(s, s)
		rescaled.emit()
