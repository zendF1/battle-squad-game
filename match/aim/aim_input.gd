extends Node2D
## Slingshot aiming (demo match_screen.dart): drag anywhere, release to fire. Dragging down-right
## shoots up-left. Releasing inside the cancel zone around the shooter cancels. Everything here
## is local; nothing touches the network until fire. The shot starts where the server fires
## from: the body centre (Trajectory.shot_origin()), where the cancel ring is drawn too. A drag
## starts on a press no Control took (_unhandled_input); its moves and its release are then read
## first (_input), so a drag passing over or ending on a HUD button (the move buttons on the
## screen's edges) neither stalls nor presses it.
##
## The aiming aid (match/aim/aim_aid.gd, its constants there), one per entry of preview_offsets
## (degrees added to the aimed angle, e.g. three for a triple shot):
## - the guide arc: the exact flight (the weapon's wind included) over only the first
##   AimAid.arc_fraction(rank_tier) of its time (60 % at bronze or no rank ... 15 % at master), fading out;
## - the landing marker: a short tick with a dot on the ground at AimAid.shown_point() (the
##   exact landing, flown like the server with the weapon's wind_influence / projectile_weight,
##   enemies and a drill's pierce, moved against the wind);
## - "Trúng!": the exact path comes within AimAid.HIT_RADIUS + hit_tolerance() of an enemy body
##   (enemies: their body centres): that enemy gets an animated bullseye over its body, no text
##   (the marker keeps its colour: moved against the wind it may stand by another player);
## - a down arrow on the tick instead of the dot when the apex is above the top of the screen.
## Nothing of it shows below MIN_POWER (the release would not fire).
##
## target_column (air_strike): no slingshot; while pressed, a vertical target line follows the
## pointer and the preview is the drop from the top of the map at that x (the server fires it at
## Items.TARGET_X_ANGLE / TARGET_X_POWER from y 0). Release emits fire_column(x); the cancel zone
## still cancels.
##
## line_mode (the laser skill, SkillView.AIM_LINE): the same slingshot, but the angle is not
## clamped to the upper half (the beam may point down) and the preview is one straight line from
## the shot origin to the map edge (beam_end(), the server's beamEnd), full length; power still
## only decides whether the drag fires (MIN_POWER). The line is drawn thinner in a light electric
## blue over a soft wider glow (LINE_COLOR / LINE_GLOW) so it reads as a beam, not a lob. Every
## enemy the beam crosses (AimAid.laser_hits()) gets the bullseye.

signal aim_changed(angle: float, power: float)
signal aim_cleared # a drag ended without a shot (cancelled, or aiming was turned off)
signal column_changed(x: float) # column mode (air_strike): the drop column under the pointer
signal fire(angle: float, power: float)
signal fire_column(target_x: float)

const Trajectory := preload("res://match/aim/trajectory_predictor.gd")
const Items := preload("res://match/items.gd")
const AimAid := preload("res://match/aim/aim_aid.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const CANCEL_RADIUS := 60.0
const MIN_POWER := 5.0
const BODY_CENTER := Trajectory.SHOT_ORIGIN # the cancel ring and the shot start (body centre)
const ARC_COLOR := Color(1, 1, 1, 0.55) # the air strike's drop preview
const ARC_WIDTH := 4.0
const GUIDE_COLOR := Color(1, 1, 1, 0.48) # the guide arc, over a soft dark shadow (any sky)
const GUIDE_WIDTH := 3.0
const GUIDE_SHADOW := Color(0.03, 0.04, 0.12, 0.19)
const GUIDE_SHADOW_WIDTH := 6.0
const LINE_COLOR := Color(0.78, 0.97, 1.0, 0.85) # line_mode: the beam preview
const LINE_WIDTH := 3.0
const LINE_GLOW := Color(0.35, 0.85, 1.0, 0.28)
const LINE_GLOW_WIDTH := 12.0
# The landing marker (a tick and a dot on the ground, half transparent) and the hit bullseye.
const MARK_TICK := 9.0 # half the ground tick's width
const MARK_DOT := 4.0 # the dot's radius, MARK_LIFT over the ground
const MARK_LIFT := 8.0
const MARK_COLOR := Color(1, 1, 1, 0.5)
const MARK_RIM := Color(0.03, 0.04, 0.12, 0.42)
const ARROW_SIZE := Vector2(15, 19) # super high: a down arrow stands on the tick for the dot
const HIT_COLOR := Color(1.0, 0.22, 0.16) # the bullseye's red rings and centre
const HIT_LIGHT := Color(1, 1, 1, 0.92) # the white ring between them
const OUTLINE := Color(0.03, 0.04, 0.12, 0.85) # dark rim: reads on bright skies and dark rock
const BULLSEYE_RADIUS := 26.0 # the outer ring round the hit enemy's body centre
const BULLSEYE_PULSE := 0.1 # ± scale of its pulse
const BULLSEYE_HZ := 1.6 # pulses per second; the tick marks turn 1 turn per 4 s

var enabled := false:
	set(value):
		enabled = value
		if not value:
			_reset()
var shooter_pos := Vector2.ZERO
var terrain
var wind_dir := 0
var wind_power := 0.0
## The local player's rank tier (ratingToTier ids; "" unknown = AimAid.DEFAULT_TIER): how much of
## the guide arc shows.
var rank_tier := ""
## My weapon's wind response (server WeaponConfig windInfluence / projectileWeight).
var wind_influence := 1.0
var projectile_weight := 1.0
## Terrain the next shot drills through (px; the drill_bomb's 50), 0 for none.
var pierce := 0.0
## The alive enemies' body centres (feet − (0, 20)): the exact flight stops on them, "Trúng!".
var enemies := PackedVector2Array()
var preview_offsets: Array = [0.0]:
	set(value):
		preview_offsets = value
		_ensure_lines()
		if _dragging:
			_update(_pointer)

var line_mode := false:
	set(value):
		line_mode = value
		if _dragging:
			_update(_pointer)

var target_column := false:
	set(value):
		if value != target_column:
			_reset() # a drag started in the other mode does not carry over
		target_column = value

var _dragging := false
var _start := Vector2.ZERO
var _angle := 0.0
var _power := 0.0
var _in_cancel := false
var _pointer := Vector2.ZERO
var _column_x := 0.0
var _lines: Array[Line2D] = [] # reused; grows to the largest preview_offsets seen
var _shadows: Array[Line2D] = [] # under each line: the guide arc's shadow (arc mode only)
var _ring := PackedVector2Array() # the enemy ring's points round (0, 0), built once
var _marks: Array = [] # per arc shown: {point: the marker on the ground, hit: it hits, high}
var _hit := {} # enemy index -> true: the bullseye on it
var _near := PackedFloat32Array() # AimAid.fly()'s closest distances, reused
var _guide := PackedVector2Array() # the first arc's guide points (aid())
var _fade: Gradient
var _shadow_fade: Gradient
var _anim := 0.0 # s: drives the bullseye's pulse and turn


func _ready() -> void:
	_ensure_lines()


## The guide arc's colour along its length: solid, then fading out (AimAid.ARC_FADE_FROM).
func _arc_gradient() -> Gradient:
	if _fade == null:
		_fade = Gradient.new()
		_fade.offsets = PackedFloat32Array([0.0, AimAid.ARC_FADE_FROM, 1.0])
		_fade.colors = PackedColorArray([GUIDE_COLOR, GUIDE_COLOR, Color(GUIDE_COLOR, 0.0)])
	return _fade


func _shadow_gradient() -> Gradient:
	if _shadow_fade == null:
		_shadow_fade = Gradient.new()
		_shadow_fade.offsets = PackedFloat32Array([0.0, AimAid.ARC_FADE_FROM, 1.0])
		_shadow_fade.colors = PackedColorArray([GUIDE_SHADOW, GUIDE_SHADOW, Color(GUIDE_SHADOW, 0.0)])
	return _shadow_fade


func _ensure_lines() -> void:
	if not is_inside_tree():
		return
	while _lines.size() < preview_offsets.size():
		var shadow := Line2D.new()
		shadow.width = GUIDE_SHADOW_WIDTH
		shadow.gradient = _shadow_gradient()
		shadow.joint_mode = Line2D.LINE_JOINT_ROUND
		shadow.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(shadow)
		_shadows.append(shadow)
		var line := Line2D.new()
		line.width = ARC_WIDTH
		line.default_color = ARC_COLOR
		add_child(line)
		_lines.append(line)


func _process(delta: float) -> void:
	if _dragging and not _hit.is_empty():
		_anim += delta
		queue_redraw()


## A press no Control took starts a drag.
func _unhandled_input(event: InputEvent) -> void:
	if _press_starts_drag(event):
		get_viewport().set_input_as_handled()


## A running drag reads its moves and release before the GUI, so a button under the pointer
## cannot swallow them (nor be pressed or hovered by them).
func _input(event: InputEvent) -> void:
	if _drag_event(event):
		get_viewport().set_input_as_handled()


## A left press while enabled and not dragging starts a drag there; true when it did.
func _press_starts_drag(event: InputEvent) -> bool:
	if not enabled or _dragging:
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		_start = _pointer_of(event)
		_update(_start)
		return true
	return false


## A running drag's move (aims) or left release (fires or cancels); true when it took the event.
func _drag_event(event: InputEvent) -> bool:
	if not enabled or not _dragging:
		return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release()
		return true
	if event is InputEventMouseMotion:
		_update(_pointer_of(event))
		return true
	return false


## The pointer in world coordinates (the event's position outside the tree: the tests).
func _pointer_of(event: InputEventMouse) -> Vector2:
	return get_global_mouse_position() if is_inside_tree() else event.position


## Whether a drag is running.
func is_dragging() -> bool:
	return _dragging


func _update(pointer: Vector2) -> void:
	_pointer = pointer
	_in_cancel = pointer.distance_to(shooter_pos + BODY_CENTER) <= CANCEL_RADIUS
	if target_column:
		_update_column(pointer)
		return
	var d := pointer - _start
	_power = clampf(d.length() / 2.0, 0.0, 100.0)
	for line in _lines:
		line.default_color = LINE_COLOR if line_mode else GUIDE_COLOR
		line.width = LINE_WIDTH if line_mode else GUIDE_WIDTH
		line.gradient = null if line_mode else _arc_gradient()
	for shadow in _shadows:
		if not shadow.points.is_empty():
			shadow.points = PackedVector2Array()
	_marks.clear()
	_hit.clear()
	_guide = PackedVector2Array()
	var origin: Vector2 = Trajectory.shot_origin(shooter_pos, terrain)
	if line_mode:
		_angle = rad_to_deg(atan2(d.y, -d.x)) # -180..180: any direction
		var end := beam_end(origin, _angle, terrain)
		for i in _lines.size():
			_lines[i].points = PackedVector2Array([origin, end]) if i == 0 and _power > 0.0 else PackedVector2Array()
		if _power >= MIN_POWER:
			for k in AimAid.laser_hits(origin, end, enemies):
				_hit[k] = true
		queue_redraw()
		aim_changed.emit(_angle, _power)
		return
	_angle = clampf(rad_to_deg(atan2(d.y, -d.x)), 0.0, 180.0)
	var accel := AimAid.wind_accel(wind_dir, wind_power, wind_influence, projectile_weight)
	var part := AimAid.arc_fraction(rank_tier)
	for i in range(preview_offsets.size(), _lines.size()):
		if not _lines[i].points.is_empty():
			_lines[i].points = PackedVector2Array()
	for i in preview_offsets.size():
		var a := _angle + float(preview_offsets[i])
		var v := AimAid.launch_velocity(a, _power)
		var flight: Dictionary = AimAid.fly(origin, v, accel, terrain, enemies, _near, pierce)
		var t: float = flight["time"]
		# the guide: the first part of the exact flight (the weapon's wind included; points every
		# TIME_STEP), so it bends like the shell will
		var n := maxi(2, roundi(part * t / Trajectory.TIME_STEP) + 1)
		var guide := Trajectory.simulate(origin.x, origin.y, v.x, v.y, accel, terrain, n)
		if i < _lines.size():
			_lines[i].points = guide
			_shadows[i].points = guide
		if i == 0:
			_guide = guide
		if _power < MIN_POWER:
			continue
		var end: Vector2 = flight["end"]
		var r := AimAid.hit_tolerance(end.x - origin.x, AimAid.apex_height(a, _power))
		var hit := false
		for k in enemies.size():
			if AimAid.is_hit(_near, k, r):
				hit = true
				_hit[k] = true
		_marks.append({"point": AimAid.shown_point(end, accel, t, terrain), "hit": hit,
			"high": AimAid.is_super_high(origin.y, a, _power)})
	queue_redraw()
	aim_changed.emit(_angle, _power)


## The aid shown now: {marks: [{point, hit, high}] (one per arc), hits: the enemy indices with
## "Trúng!", sorted, guide: the first arc's guide points}.
func aid() -> Dictionary:
	var hits := _hit.keys()
	hits.sort()
	return {"marks": _marks.duplicate(true), "hits": hits, "guide": _guide}


func _update_column(pointer: Vector2) -> void:
	_column_x = pointer.x
	if terrain != null:
		_column_x = clampf(_column_x, 0.0, float(terrain.width)) # the server clamps it the same way
	_marks.clear()
	_hit.clear()
	for shadow in _shadows:
		shadow.points = PackedVector2Array()
	for i in _lines.size():
		_lines[i].gradient = null
		_lines[i].default_color = ARC_COLOR
		_lines[i].width = ARC_WIDTH
		_lines[i].points = Trajectory.predict(Vector2(_column_x, 0.0), Items.TARGET_X_ANGLE, Items.TARGET_X_POWER,
			wind_dir, wind_power, terrain) if i == 0 else PackedVector2Array()
	queue_redraw()
	column_changed.emit(_column_x)


func _release() -> void:
	if target_column:
		var x := _column_x
		var cancel := _in_cancel
		_reset()
		if not cancel:
			fire_column.emit(x)
		return
	var shoot := _power >= MIN_POWER and not _in_cancel
	var angle := _angle
	var power := _power
	_reset(not shoot)
	if shoot:
		fire.emit(angle, power)


## Where a straight beam from origin at angle (degrees, Shoot convention) leaves the map
## rectangle (server beamEnd); 2000 px away without terrain.
static func beam_end(origin: Vector2, angle: float, terrain = null) -> Vector2:
	var dir := Vector2(cos(deg_to_rad(angle)), -sin(deg_to_rad(angle)))
	if terrain == null:
		return origin + dir * 2000.0
	var w := float(terrain.width)
	var h := float(terrain.height)
	var s := INF
	if dir.x > 1e-9:
		s = minf(s, (w - origin.x) / dir.x)
	elif dir.x < -1e-9:
		s = minf(s, -origin.x / dir.x)
	if dir.y > 1e-9:
		s = minf(s, (h - origin.y) / dir.y)
	elif dir.y < -1e-9:
		s = minf(s, -origin.y / dir.y)
	return origin + dir * maxf(s, 0.0)


## cleared: emit aim_cleared when a slingshot drag was running.
func _reset(cleared: bool = true) -> void:
	if _dragging and cleared and not target_column:
		aim_cleared.emit()
	_dragging = false
	_in_cancel = false
	_marks.clear()
	_hit.clear()
	for line in _lines:
		line.points = PackedVector2Array()
	for shadow in _shadows:
		shadow.points = PackedVector2Array()
	queue_redraw()


func _draw() -> void:
	if not _dragging:
		return
	var c := shooter_pos + BODY_CENTER
	var color := Color(1, 0.3, 0.3, 0.9) if _in_cancel else Color(1, 1, 1, 0.5)
	draw_arc(c, CANCEL_RADIUS, 0.0, TAU, 48, color, 3.0)
	draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), color, 3.0)
	draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), color, 3.0)
	if line_mode and not target_column and not _lines.is_empty() and _lines[0].points.size() == 2:
		draw_line(_lines[0].points[0], _lines[0].points[1], LINE_GLOW, LINE_GLOW_WIDTH, true) # under the line (children draw on top)
	if target_column and not _in_cancel:
		var bottom := float(terrain.height) if terrain != null else 2000.0
		draw_line(Vector2(_column_x, 0.0), Vector2(_column_x, bottom), Color(1, 0.85, 0.2, 0.8), 3.0)
	for k in _hit:
		if k < enemies.size():
			_draw_enemy_hit(enemies[k])
	for m in _marks:
		_draw_mark(m["point"], bool(m["high"]))


## The landing marker on the ground at `foot`: a short tick with a dot over it, or (super high:
## the apex above the screen) a down arrow standing on it; white with a dark rim.
func _draw_mark(foot: Vector2, high: bool) -> void:
	var fill := MARK_COLOR
	var rim := MARK_RIM
	var tick := Vector2(MARK_TICK, 0)
	draw_line(foot - tick, foot + tick, rim, 5.0, true)
	draw_line(foot - tick, foot + tick, fill, 2.5, true)
	if high:
		_draw_down_arrow(foot - Vector2(0, 3), fill, rim)
		return
	var dot := foot - Vector2(0, MARK_LIFT)
	draw_circle(dot, MARK_DOT + 1.5, rim)
	draw_circle(dot, MARK_DOT, fill)


## A down arrow with its tip at `tip`.
func _draw_down_arrow(tip: Vector2, fill: Color, rim: Color) -> void:
	var w := ARROW_SIZE.x / 2.0
	var h := ARROW_SIZE.y
	var shaft := w * 0.38
	var tri := PackedVector2Array([tip, tip + Vector2(w, -h * 0.5), tip + Vector2(shaft, -h * 0.5),
		tip + Vector2(shaft, -h), tip + Vector2(-shaft, -h), tip + Vector2(-shaft, -h * 0.5), tip + Vector2(-w, -h * 0.5)])
	var loop := tri.duplicate()
	loop.append(tip)
	draw_polyline(loop, rim, 3.0, true)
	draw_colored_polygon(tri, fill)


## The hit enemy (its body centre): an animated bullseye over the body: red outer ring, white
## ring, red centre dot, four tick marks slowly turning, the whole pulsing gently (no text).
func _draw_enemy_hit(centre: Vector2) -> void:
	if _ring.is_empty():
		for i in 41:
			var a := TAU * i / 40.0
			_ring.append(Vector2(cos(a), sin(a)))
	var k := 1.0 + BULLSEYE_PULSE * sin(_anim * TAU * BULLSEYE_HZ)
	var r := BULLSEYE_RADIUS * k
	draw_set_transform(centre, 0.0, Vector2(r, r))
	draw_polyline(_ring, OUTLINE, 6.0 / r, true)
	draw_polyline(_ring, HIT_COLOR, 3.5 / r, true)
	draw_set_transform(centre, 0.0, Vector2(r, r) * 0.62)
	draw_polyline(_ring, HIT_LIGHT, 2.5 / (r * 0.62), true)
	draw_set_transform(Vector2.ZERO)
	draw_circle(centre, 5.5 * k, OUTLINE)
	draw_circle(centre, 4.0 * k, HIT_COLOR)
	var turn := _anim * TAU / 4.0
	for q in 4:
		var d := Vector2.from_angle(turn + q * TAU / 4.0)
		draw_line(centre + d * (r - 5.0), centre + d * (r + 7.0), OUTLINE, 5.0, true)
		draw_line(centre + d * (r - 4.0), centre + d * (r + 6.0), HIT_COLOR, 2.5, true)
