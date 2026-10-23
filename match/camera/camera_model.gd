extends RefCounted
## The match camera, pure math (match/camera/match_camera.gd applies it to a Camera2D every frame).
## World px; `center` is the camera's centre, `zoom` 1 = one world px per screen px, down to
## min_zoom() (the whole map fits). The view is clamped to the map rect; while it follows a shot
## (`sky`) its top may rise SKY_RISE px above the map top. A map narrower than the view is
## centred and never pans in x; one lower than the view sits on the view's bottom (the extra is
## sky above it, not the void under the map) and never pans in y.
##
## Modes, each entered by its own call (a "take" call) and fed every frame by its update call,
## which does nothing in any other mode, so a manual look is only ended by the next take:
## - TURN (pan_to; retarget follows a walking player): an eased PAN_SEC pan to the point, then
##   follows it smoothly. A pan asked during a hold (hold(): an explosion, a fall) starts when the
##   hold is over;
## - AIM (start_aim; aim_at(anchor, tip)): heads for the tip (the guide arc's far end, the beam's
##   end, a remote aim's look point) kept so the anchor (the shooter) stays KEEP_MARGIN inside the
##   view; release() (the drag released or cancelled) stays where it is (IDLE). column_scroll()
##   (air strike) scrolls the view while the pointer is near a screen side;
## - SHOT (start_shot; track(points)): heads for the middle of the points' box (the live shells,
##   the blasts held HOLD_SEC, falling players), sky allowed; no points: it stays;
## - MANUAL (manual_pan in screen px, look_at: an eased pan to a point): stays where it is put;
## - IDLE: stays (eased back inside the map if it was above it).
## shake(radius) adds a small decaying shake (shake_offset(), screen px), scaled by the blast.
## parallax() is where a far layer (the sky) sits for the current view.
## frame_map() (boss mode v3: a map-wide rain, a beam burst, a shockwave to both edges) eases the
## zoom out over FRAME_SEC until the whole map fits (min_zoom()); unframe() eases it back to the
## zoom before. A manual zoom meanwhile cancels both (that zoom stays).

enum { IDLE, TURN, AIM, SHOT, MANUAL }

const PAN_SEC := 0.6
const HOLD_SEC := 0.4 # an explosion holds the view this long before the next pan
const SKY_RISE := 300.0 # px the view may rise above the map top while following a shot
const KEEP_MARGIN := Vector2(150, 120) # the shooter stays this far inside the view while aiming
const AIM_RATE := 4.5 # 1/s: exponential follow rates
const SHOT_RATE := 6.0
const FOLLOW_RATE := 5.0
const SETTLE_RATE := 4.0
const EDGE_ZONE := 0.6 # column mode: the pointer's |offset| from the screen centre (0..1) where scrolling starts
const EDGE_SPEED := 1100.0 # px/s at the screen's side
const ZOOM_STEP := 1.12 # one wheel notch
const SHAKE_SEC := 0.35
const SHAKE_PER_PX := 0.08 # px of shake per px of blast radius
const SHAKE_MIN := 1.5
const SHAKE_MAX := 7.0
const FRAME_SEC := 0.45 # s the zoom eases out to the whole map (frame_map) or back (unframe)

var map_size := Vector2(1600, 900)
var view_size := Vector2(1600, 900) # screen px
var zoom := 1.0
var center := Vector2(800, 450)
var mode := IDLE
var sky := false # the view may rise SKY_RISE above the map (shot follow)
## A turn's pan follows a flier (boss mode v2: a drone, the witch high in the air): that TURN may
## rise SKY_RISE above the map too. Set before pan_to().
var sky_turn := false

var _target := Vector2(800, 450)
var _anchor := Vector2.ZERO
var _pan_from := Vector2.ZERO
var _pan_t := 1.0 # 0..1 along a pan, 1 = none
var _pan_sec := PAN_SEC
var _pending: Variant = null # a pan waiting for the hold: [point, sec, mode]
var _hold := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _zoom_goal := -1.0 # an eased zoom under way (frame_map / unframe), -1 none
var _zoom_from := 1.0
var _zoom_t := 1.0
var _zoom_sec := FRAME_SEC
var _framed_from := -1.0 # the zoom before frame_map(), -1 not framed


func setup(map: Vector2, view: Vector2) -> void:
	map_size = Vector2(maxf(map.x, 1.0), maxf(map.y, 1.0))
	view_size = Vector2(maxf(view.x, 1.0), maxf(view.y, 1.0))
	zoom = clampf(zoom, min_zoom(), 1.0)
	center = clamp_center(center)
	_target = center


## The smallest zoom: the whole map fits the view (1 when it already does).
func min_zoom() -> float:
	return minf(1.0, minf(view_size.x / map_size.x, view_size.y / map_size.y))


## The view's size in world px.
func world_view() -> Vector2:
	return view_size / zoom


## The world rect on screen now (without the shake).
func view_rect() -> Rect2:
	var wv := world_view()
	return Rect2(center - wv / 2.0, wv)


## The centre c kept so the view stays inside the map (its top up to SKY_RISE above it when
## sky_ok); a map narrower than the view is centred, a lower one sits on the view's bottom.
func clamp_center(c: Vector2, sky_ok: bool = false) -> Vector2:
	var half := world_view() / 2.0
	var out := c
	if map_size.x <= half.x * 2.0:
		out.x = map_size.x / 2.0
	else:
		out.x = clampf(c.x, half.x, map_size.x - half.x)
	if map_size.y <= half.y * 2.0:
		out.y = map_size.y - half.y # the map's bottom on the view's: the extra is sky above it
	else:
		out.y = clampf(c.y, half.y - (SKY_RISE if sky_ok else 0.0), map_size.y - half.y)
	return out


## Where the camera heads to show tip while anchor stays KEEP_MARGIN inside the view.
func keep_in_view(tip: Vector2, anchor: Vector2) -> Vector2:
	var reach := (world_view() / 2.0 - KEEP_MARGIN).max(Vector2.ZERO)
	return Vector2(clampf(tip.x, anchor.x - reach.x, anchor.x + reach.x), clampf(tip.y, anchor.y - reach.y, anchor.y + reach.y))


func is_visible(p: Vector2, margin: float = 0.0) -> bool:
	return view_rect().grow(-margin).has_point(p)


# ── Takes ───────────────────────────────────────────────────────────────────

## Turn start: an eased pan to point, then following it (retarget). Waits for a hold.
func pan_to(point: Vector2, sec: float = PAN_SEC) -> void:
	if _hold > 0.0:
		_pending = [point, sec, TURN]
		return
	_start_pan(point, sec, TURN)


## Jumps to point and stays there.
func snap(point: Vector2) -> void:
	_pending = null
	mode = IDLE
	sky = false
	_pan_t = 1.0
	center = clamp_center(point)
	_target = center


## A tap on an off-screen marker: an eased pan there, then it stays (manual).
func look_at(point: Vector2, sec: float = PAN_SEC) -> void:
	_pending = null
	_start_pan(point, sec, MANUAL)


func start_aim(anchor: Vector2, tip: Vector2) -> void:
	_pending = null
	_hold = 0.0
	mode = AIM
	sky = false
	_pan_t = 1.0
	_anchor = anchor
	_target = keep_in_view(tip, anchor)


func start_shot() -> void:
	_pending = null
	mode = SHOT
	sky = true
	_pan_t = 1.0
	_target = center


## A drag by screen px (the view moves the other way: the world follows the finger).
func manual_pan(screen_delta: Vector2) -> void:
	_pending = null
	mode = MANUAL
	_pan_t = 1.0
	center = clamp_center(center - screen_delta / zoom, sky)
	_target = center


## Zooms to z (clamped to min_zoom()..1) keeping the world point under the screen point anchor
## where it is.
func zoom_at(z: float, anchor: Vector2) -> void:
	_zoom_goal = -1.0 # a manual zoom ends a framing
	_framed_from = -1.0
	z = clampf(z, min_zoom(), 1.0)
	if is_equal_approx(z, zoom):
		return
	var off := anchor - view_size / 2.0
	var world := center + off / zoom
	zoom = z
	center = clamp_center(world - off / zoom, sky)
	if mode == IDLE or mode == MANUAL:
		_target = center
	_pan_from = center


## The whole map in view: the zoom eases out to min_zoom() over sec (the zoom before is kept for
## unframe()).
func frame_map(sec: float = FRAME_SEC) -> void:
	if _framed_from < 0.0:
		_framed_from = zoom
	_ease_zoom(min_zoom(), sec)


## A wide area in view (Tide's snow nova: its whole radius): the zoom eases out until `size`
## (world px, plus a margin) fits the view, never closer than now nor past min_zoom(); unframe()
## brings the zoom before back.
func frame_size(size: Vector2, sec: float = FRAME_SEC) -> void:
	var fit := minf(view_size.x / maxf(size.x * 1.15, 1.0), view_size.y / maxf(size.y * 1.25, 1.0))
	if fit >= zoom:
		return
	if _framed_from < 0.0:
		_framed_from = zoom
	_ease_zoom(fit, sec)


## Back from frame_map() / frame_size(): the zoom eases back to the one before; nothing when not framed.
func unframe(sec: float = FRAME_SEC) -> void:
	if _framed_from < 0.0:
		return
	var z := _framed_from
	_framed_from = -1.0
	_ease_zoom(z, sec)


## frame_map() is on (until unframe() or a manual zoom).
func framed() -> bool:
	return _framed_from >= 0.0


## An eased zoom is under way.
func zooming() -> bool:
	return _zoom_goal >= 0.0


func _ease_zoom(z: float, sec: float) -> void:
	_zoom_from = zoom
	_zoom_goal = clampf(z, min_zoom(), 1.0)
	_zoom_sec = maxf(sec, 1e-3)
	_zoom_t = 0.0


## An explosion or a fall: the next pan waits sec (the longest hold wins).
func hold(sec: float) -> void:
	_hold = maxf(_hold, sec)


func holding() -> bool:
	return _hold > 0.0


func shake(radius: float) -> void:
	_shake = maxf(_shake, clampf(radius * SHAKE_PER_PX, SHAKE_MIN, SHAKE_MAX))
	_shake_t = 0.0


# ── Updates (only in their own mode) ──────────────────────────────────────────

## TURN: the player walked.
func retarget(point: Vector2) -> void:
	if mode == TURN:
		_target = point


func aim_at(anchor: Vector2, tip: Vector2) -> void:
	if mode == AIM:
		_anchor = anchor
		_target = keep_in_view(tip, anchor)


## The drag was released or cancelled: stay until the shot plays.
func release() -> void:
	if mode == AIM:
		mode = IDLE
		_target = center


## SHOT: heads for the middle of the points' box; none: stays.
func track(points: PackedVector2Array) -> void:
	if mode != SHOT or points.is_empty():
		return
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	_target = box.get_center()


## AIM, column mode (air strike): pointer_x (screen px) near a side scrolls the view that way.
func column_scroll(pointer_x: float, delta: float) -> void:
	if mode != AIM:
		return
	var u := (pointer_x / view_size.x) * 2.0 - 1.0
	var k := clampf((absf(u) - EDGE_ZONE) / (0.95 - EDGE_ZONE), 0.0, 1.0)
	if k <= 0.0:
		_target = center
		return
	center = clamp_center(center + Vector2(signf(u) * EDGE_SPEED * k * k * delta / zoom, 0.0))
	_target = center


# ── Step ────────────────────────────────────────────────────────────────────

## Advances delta seconds; returns the new centre.
func step(delta: float) -> Vector2:
	if _zoom_goal >= 0.0:
		_zoom_t = minf(1.0, _zoom_t + delta / _zoom_sec)
		zoom = lerpf(_zoom_from, _zoom_goal, ease_in_out(_zoom_t))
		if _zoom_t >= 1.0:
			zoom = _zoom_goal
			_zoom_goal = -1.0
		center = clamp_center(center, sky)
		_pan_from = clamp_center(_pan_from, sky)
	if _hold > 0.0:
		_hold = maxf(0.0, _hold - delta)
		if _hold <= 0.0 and _pending != null:
			var p: Array = _pending
			_pending = null
			_start_pan(p[0], p[1], p[2])
	if _shake > 0.0:
		_shake_t += delta
		if _shake_t >= SHAKE_SEC:
			_shake = 0.0
	var goal := clamp_center(_target, sky)
	if _pan_t < 1.0:
		_pan_t = minf(1.0, _pan_t + delta / maxf(_pan_sec, 1e-3))
		center = _pan_from.lerp(goal, ease_in_out(_pan_t))
		return center
	var rate := FOLLOW_RATE
	match mode:
		AIM:
			rate = AIM_RATE
		SHOT:
			rate = SHOT_RATE
		IDLE, MANUAL:
			rate = SETTLE_RATE
			goal = clamp_center(center, sky)
	center = center.lerp(goal, 1.0 - exp(-rate * delta))
	return center


## The shake now (screen px): a few fast wobbles, fading out.
func shake_offset() -> Vector2:
	if _shake <= 0.0:
		return Vector2.ZERO
	var k := 1.0 - _shake_t / SHAKE_SEC
	var t := _shake_t
	return Vector2(sin(t * 71.0) + 0.5 * sin(t * 133.0 + 1.3), cos(t * 59.0) + 0.5 * sin(t * 117.0 + 0.4)) * (_shake * k * k / 1.5)


## The pan in progress: 0..1, 1 when none.
func pan_progress() -> float:
	return _pan_t


func target() -> Vector2:
	return clamp_center(_target, sky)


## A far layer's travel for the view range: factor × (how far the centre can move), screen px.
func parallax_travel(factor: float) -> Vector2:
	var r := _range()
	return Vector2(r.size.x, r.size.y) * zoom * factor


## The far layer's offset (screen px, ≤ 0) now: from 0 at the left / top of the centre's range to
## -parallax_travel() at its right / bottom, so a layer view_size + parallax_travel() large always
## covers the screen.
func parallax(factor: float) -> Vector2:
	var r := _range()
	var u := 0.5 if r.size.x <= 0.0 else clampf((center.x - r.position.x) / r.size.x, 0.0, 1.0)
	var v := 1.0 if r.size.y <= 0.0 else clampf((center.y - r.position.y) / r.size.y, 0.0, 1.0)
	return -Vector2(u, v) * parallax_travel(factor)


## Where the centre can be (sky included), as a rect of centres.
func _range() -> Rect2:
	var lo := clamp_center(Vector2(-INF, -INF), true)
	var hi := clamp_center(Vector2(INF, INF), true)
	return Rect2(lo, hi - lo)


func _start_pan(point: Vector2, sec: float, new_mode: int) -> void:
	mode = new_mode
	sky = sky_turn and new_mode == TURN
	_target = point
	_pan_from = center
	_pan_sec = sec
	_pan_t = 0.0 if sec > 0.0 else 1.0
	if sec <= 0.0:
		center = clamp_center(point)


static func ease_in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t) if t < 1.0 else 1.0
