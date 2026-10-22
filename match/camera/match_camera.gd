extends Camera2D
## The match's camera: applies a CameraModel (match/camera/camera_model.gd) every frame (position,
## zoom, the shake as the offset), keeps the far sky layer (SkyView on its own CanvasLayer) in
## parallax with it, and reads the manual look gestures:
## - a left drag pans the view when aiming is off (not my turn, the shot replaying, input
##   locked); on my turn a left drag aims, as before (AimInput takes the press first);
## - a right or middle drag pans at any time; on a touch screen two fingers pan and pinch-zoom (a
##   second finger cancels an aim drag in progress);
## - the mouse wheel / a trackpad pinch zooms around the pointer, a trackpad two-finger scroll pans;
##   zoom from 1 down to the whole map fitting the view (CameraModel.min_zoom()).
## A drag's moves and release are read first (_input), like AimInput's, so a HUD button under the
## pointer does not swallow them. What the camera looks at is match_screen's (the model's takes and
## updates); a manual look stays until the next take there.

const CameraModel := preload("res://match/camera/camera_model.gd")
const SkyView := preload("res://match/views/sky_view.gd")

const PAN_SLOP := 6.0 # px a left press moves before it counts as a pan (a tap stays a tap)

var model := CameraModel.new()
var sky: SkyView # the far layer (SkyView), or null
var aim # AimInput: a left press it takes is an aim, not a pan; a second finger cancels its drag

var _drag := -1 # the mouse button panning, -1 none
var _drag_at := Vector2.ZERO
var _drag_moved := false
var _touches := {} # finger index -> screen position
var _pinch_mid := Vector2.ZERO
var _pinch_len := 0.0


func _ready() -> void:
	position_smoothing_enabled = false
	ignore_rotation = true
	anchor_mode = ANCHOR_MODE_DRAG_CENTER
	make_current()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()


## The map is w × h world px (the terrain's size; any size).
func set_map(map_size: Vector2) -> void:
	model.setup(map_size, _view())
	_fit_sky()
	_apply()


## Jumps to point (no pan).
func snap_to(point: Vector2) -> void:
	model.snap(point)
	_apply()


func _view() -> Vector2:
	return get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)


func _on_resized() -> void:
	model.setup(model.map_size, _view())
	_fit_sky()
	_apply()


func _fit_sky() -> void:
	if sky == null:
		return
	var z := model.zoom
	model.zoom = 1.0 # the most travel there is (at zoom 1)
	var travel := model.parallax_travel(SkyView.PARALLAX)
	model.zoom = z
	sky.fit(_view(), travel)


func _process(delta: float) -> void:
	model.step(delta)
	_apply()


func _apply() -> void:
	position = model.center
	zoom = Vector2(model.zoom, model.zoom)
	# The shake never shows past the map's edges (the void under it): kept inside the same clamp.
	var c := model.center
	offset = model.clamp_center(c + model.shake_offset() / model.zoom, model.sky) - model.clamp_center(c, model.sky)
	if sky != null:
		var back := model.parallax(SkyView.PARALLAX)
		sky.scroll(back, model.parallax(SkyView.CLOUD_PARALLAX).x - back.x)


## world → screen px (the view now, shake included).
func to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world if is_inside_tree() else world


# ── Gestures ─────────────────────────────────────────────────────────────────

func _aim_takes_left() -> bool:
	return aim != null and (aim.enabled or aim.is_dragging())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var k: float = CameraModel.ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / CameraModel.ZOOM_STEP
				model.zoom_at(model.zoom * pow(k, event.factor if event.factor > 0.0 else 1.0), event.position)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_start_drag(event.button_index, event.position)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_LEFT:
				if _touches.size() < 2 and not _aim_takes_left():
					_start_drag(MOUSE_BUTTON_LEFT, event.position)
					get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		model.zoom_at(model.zoom * event.factor, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		model.manual_pan(-event.delta * 12.0)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
		return
	if event is InputEventScreenDrag:
		if _touches.has(event.index):
			_touches[event.index] = event.position
			if _touches.size() >= 2:
				_pinch_step()
				get_viewport().set_input_as_handled()
		return
	if _drag < 0:
		return
	if event is InputEventMouseMotion:
		var d: Vector2 = event.position - _drag_at
		if not _drag_moved and d.length() < PAN_SLOP:
			return
		_drag_moved = true
		_drag_at = event.position
		model.manual_pan(d)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == _drag and not event.pressed:
		_drag = -1
		get_viewport().set_input_as_handled()


func _start_drag(button: int, at: Vector2) -> void:
	_drag = button
	_drag_at = at
	_drag_moved = false


## Two fingers: pan with their middle, zoom with their spread. The second finger ends a one-finger
## pan or aim drag.
func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
	else:
		_touches.erase(e.index)
	if _touches.size() >= 2:
		_drag = -1
		if aim != null and aim.is_dragging():
			aim.cancel()
		_pinch_begin()
		get_viewport().set_input_as_handled()


func _pinch_points() -> Array:
	var keys := _touches.keys()
	keys.sort()
	return [_touches[keys[0]], _touches[keys[1]]]


func _pinch_begin() -> void:
	var p := _pinch_points()
	_pinch_mid = (p[0] + p[1]) / 2.0
	_pinch_len = maxf((p[0] as Vector2).distance_to(p[1]), 1.0)


func _pinch_step() -> void:
	var p := _pinch_points()
	var mid: Vector2 = (p[0] + p[1]) / 2.0
	var length := maxf((p[0] as Vector2).distance_to(p[1]), 1.0)
	model.manual_pan(mid - _pinch_mid)
	model.zoom_at(model.zoom * length / _pinch_len, mid)
	_pinch_mid = mid
	_pinch_len = length
