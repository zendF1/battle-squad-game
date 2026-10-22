extends RefCounted
## How a character's walk is drawn (match/views/player_view.gd): along the terrain surface, at a
## steady speed, a drop off a ledge as a real fall. Drawing only: the positions the game uses (the
## server's, MoveSync's prediction) stay the exact WalkTo pixels; this only decides where the body
## is drawn on the way to them.
##
## The path is the walk's columns, one WalkTo step (one column) apart, built with the terrain mask
## (TerrainMask.walk_to one column at a time takes the same steps as one WalkTo call). Along it:
## - the drawn point trails the path's end and eases into it: its speed is WALK_SPEED × the steps
##   left / LEAD_PX (walk(): WALK_LEAD_PX), capped (follow(): CATCH_UP × WALK_SPEED; walk(): what ends the walk in its
##   time), from a standstill at up to ACCEL. A held walk (MoveSync moving at WALK_SPEED) is drawn
##   at a steady WALK_SPEED about LEAD_PX behind the prediction, so the whole-pixel steps of the
##   prediction never show;
## - the drawn height is the path's height averaged over SMOOTH_PX steps each side (less near the
##   ends of the walk and next to a fall, none there), so the 1 px stairs of a pixel slope become a
##   straight slope and a standing character is exactly on its pixel;
## - a step down taller than FALL_MIN is a fall: the body steps into the column and falls with the
##   game data's gravity, in sqrt(2·drop / gravity) like the shot replay's falls (the server lands
##   a walk drop at once and with no damage), then walks on;
## - a walk that ends below the map (a step into a hole down to its bottom: WalkTo ends there,
##   y = the map height) falls on past the bottom, OUT_DROP px further with the same gravity, so
##   the body leaves the screen (PlayerView fades it); falls_out() / falling_out() tell;
## - a target the path cannot reach by walking (a server correction the prediction did not
##   foresee, a teleport) starts a new path there; the gap eases out over a few frames (SETTLE_SEC)
##   instead of jumping.

const GameData := preload("res://autoload/game_data_model.gd")

const WALK_SPEED := 90.0 # px/s along the ground: MoveSync.SPEED, a held move button
const LEAD_PX := 8.0 # follow(): the drawn point slows down within about this many steps of the path's end
const WALK_LEAD_PX := 4.0 # walk(): the same, a shorter ease-in at the end
const WALK_TAIL_SEC := 0.2 # walk(): about what the start from a standstill and the ease-in add to the time
const ACCEL := 900.0 # px/s² from a standstill (0 → WALK_SPEED in 0.1 s)
const CATCH_UP := 2.5 # follow(): a backlog (after a fall, a correction) is walked off at up to this × WALK_SPEED
const FALL_MIN := 4 # px: a step down taller than this is a fall (WalkTo climbs at most maxClimbPerStep = 3)
const SMOOTH_PX := 4.0 # steps each side the drawn height is averaged over
const SETTLE_SEC := 0.06 # time constant of a correction's ease-out
const END_EPS := 0.02 # steps: closer than this to the end is there
const MIN_WALK_SEC := 0.2 # walk(): the shortest time a walk is given
const MAX_WALK_SPEED := 2.0 * WALK_SPEED # walk(): never faster (a long walk with a fall may run over its time)
## px below the map's bottom a fall out of the map is drawn to (the body, about 60 px tall, is
## out of sight by then), and the span PlayerView fades it over.
const OUT_DROP := 140.0

var terrain # TerrainMask (match/terrain/terrain_mask.gd); null: every target is a correction
var drawn := Vector2.ZERO # where to draw the body this frame

var _pts := PackedVector2Array() # the path: _pts[i] at step i, one column apart
var _s := 0.0 # the drawn point, in steps along _pts
var _speed := 0.0 # steps/s now
var _v_max := WALK_SPEED
var _lead := LEAD_PX
var _fall_t := -1.0 # >= 0 while falling the step after int(_s)
var _resid := Vector2.ZERO # drawn - path point: a correction easing out


## Stands at p: no walk, nothing to ease. A tween (shot fall, knockback, teleport) or a snapshot
## places the body from here.
func reset(p: Vector2) -> void:
	_pts = PackedVector2Array([p])
	_s = 0.0
	_speed = 0.0
	_fall_t = -1.0
	_resid = Vector2.ZERO
	drawn = p


## Keeps the body drawn at p for now while the walk's logical point is the path's: the gap eases
## out (e.g. a tween cut short by a walk).
func ease_from(p: Vector2) -> void:
	_resid = p - _point()
	drawn = p


## The local player's walk: target is MoveSync's prediction, moving at WALK_SPEED while a move
## button is held. The drawn point trails it and catches up after a fall or a correction.
func follow(target: Vector2) -> void:
	if _retarget(target):
		_v_max = WALK_SPEED * CATCH_UP
		_lead = LEAD_PX


## Another player's walk to target (a PlayerMoved), drawn in at most max_sec (falls included):
## at WALK_SPEED or faster, up to MAX_WALK_SPEED.
func walk(target: Vector2, max_sec: float) -> void:
	if _retarget(target):
		_v_max = clampf(_left() / maxf(max_sec - _falls_sec() - WALK_TAIL_SEC, MIN_WALK_SEC), WALK_SPEED, MAX_WALK_SPEED)
		_lead = WALK_LEAD_PX


## Ends the walk within about sec (the player acts: its shot leaves from the server's position).
func hurry(sec: float) -> void:
	_v_max = maxf(_v_max, _left() / maxf(sec, 0.01))
	_speed = maxf(_speed, minf(_v_max, WALK_SPEED))


## Where the walk is going (its last point).
func target() -> Vector2:
	return _pts[_pts.size() - 1]


## True while the drawn point is still on its way or easing out a correction.
func active() -> bool:
	return _s < _pts.size() - 1 or _fall_t >= 0.0 or _resid.length_squared() > 0.0


## True when the walk ends below the map (y >= the terrain's height): a fall out of the map.
func falls_out() -> bool:
	return _is_out(_pts.size() - 1)


## True while a fall out of the map is still being drawn.
func falling_out() -> bool:
	return falls_out() and active()


## Advances dt seconds; returns the new drawn point.
func step(dt: float) -> Vector2:
	var end := float(_pts.size() - 1)
	var left := dt
	while left > 0.0:
		if _fall_t >= 0.0:
			var i := int(_s)
			var j := _fall_end(i)
			var land := _fall_time(_drop(i, j))
			_fall_t += left
			if _fall_t < land:
				break
			left = _fall_t - land
			_fall_t = -1.0
			_s = float(j)
			_speed = 0.0 # lands, then walks on from a standstill
			continue
		if _s >= end - END_EPS:
			_s = end
			_speed = 0.0
			break
		if _s == floorf(_s) and _is_fall(int(_s)):
			_fall_t = 0.0
			continue
		var want := minf(WALK_SPEED * (end - _s) / _lead, _v_max)
		_speed = minf(want, _speed + ACCEL * left)
		var to := minf(end, floorf(_s) + 1.0) # the next column
		var d := _speed * left
		if _s + d < to:
			_s += d
			break
		left -= (to - _s) / maxf(_speed, 1e-6)
		_s = to
	_trim()
	if _resid != Vector2.ZERO:
		_resid *= exp(-dt / SETTLE_SEC)
		if _resid.length_squared() < 1e-4:
			_resid = Vector2.ZERO
	drawn = _draw_point() + _resid
	return drawn


# ── Path ────────────────────────────────────────────────────────────────────

## The path now runs from the column the drawn point is on its way to, to target. Returns false
## when target is already the path's end.
func _retarget(target: Vector2) -> bool:
	if target == _pts[_pts.size() - 1]:
		return false
	var keep := int(ceil(_s - 1e-9)) # the column being walked to (falling: the landing)
	if _fall_t >= 0.0:
		keep = _fall_end(int(_s))
	keep = mini(keep, _pts.size() - 1)
	var walked := _walk_columns(_pts[keep], target)
	if walked.is_empty():
		_correct(target)
		return true
	_pts = _pts.slice(0, keep + 1)
	_pts.append_array(walked)
	return true


## The columns of a WalkTo from `from` to target, excluding from; empty when that walk does not
## end exactly on target.
func _walk_columns(from: Vector2, target: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if terrain == null:
		return out
	var end_x := roundf(target.x)
	var pos := from
	while roundf(pos.x) != end_x:
		var dir := 1.0 if end_x > roundf(pos.x) else -1.0
		var next: Vector2 = terrain.walk_to(pos.x, pos.y, roundf(pos.x) + dir)
		if next.x == roundf(pos.x):
			break # blocked
		pos = next
		out.append(pos)
	if pos != target:
		return PackedVector2Array()
	return out


## A target no walk reaches: a new path there; the drawn body eases over from where it is.
func _correct(target: Vector2) -> void:
	var was := drawn
	reset(target)
	_resid = was - target
	drawn = was


func _is_fall(i: int) -> bool:
	return i + 1 < _pts.size() and (_pts[i + 1].y - _pts[i].y > FALL_MIN or _is_out(i + 1))


## Step i is the path's end and below the map: the fall into it goes on OUT_DROP px past it.
func _is_out(i: int) -> bool:
	return terrain != null and i == _pts.size() - 1 and i > 0 and _pts[i].y >= float(terrain.height)


## The height the fall from step i to step j drops (past the bottom when j is out of the map).
func _drop(i: int, j: int) -> float:
	return _pts[j].y - _pts[i].y + (OUT_DROP if _is_out(j) else 0.0)


## The end of the fall that starts at step i: the steps after it go on down as long as each is a
## fall (a slope too steep to walk down is one fall along it).
func _fall_end(i: int) -> int:
	var j := i + 1
	while _is_fall(j):
		j += 1
	return j


## sqrt(2·drop / gravity): the shot replay's fall time (server shotTimeline.fallTime).
static func _fall_time(drop: float) -> float:
	var g := GameData.gravity()
	return sqrt(2.0 * drop / g) if g > 0.0 and drop > 0.0 else 0.0


## Steps (columns) left to walk.
func _left() -> float:
	return float(_pts.size() - 1) - _s


## The falls still ahead, in seconds.
func _falls_sec() -> float:
	var t := 0.0
	var i := int(_s)
	while i < _pts.size() - 1:
		if _is_fall(i):
			var j := _fall_end(i)
			t += _fall_time(_drop(i, j))
			i = j
		else:
			i += 1
	return t


## Drops the columns far enough behind that the height average no longer reads them.
func _trim() -> void:
	var drop := int(_s - SMOOTH_PX) - 2
	if drop > 16:
		_pts = _pts.slice(drop)
		_s -= drop


# ── Drawing ─────────────────────────────────────────────────────────────────

## The path point at the drawn step (no smoothing).
func _point() -> Vector2:
	var i := int(_s)
	if i >= _pts.size() - 1:
		return _pts[_pts.size() - 1]
	return _pts[i].lerp(_pts[i + 1], _s - i)


func _draw_point() -> Vector2:
	var i := int(_s)
	if _fall_t >= 0.0:
		# y = y0 + g·t²/2; x where the path is at that height, so the body goes over the edge and
		# down a steep slope above it, and lands on the column's pixel.
		var y := _pts[i].y + 0.5 * GameData.gravity() * _fall_t * _fall_t
		var j := _fall_end(i)
		var k := i
		while k < j and _pts[k + 1].y < y:
			k += 1
		if k >= j:
			return Vector2(_pts[j].x, minf(y, _pts[j].y + OUT_DROP)) if _is_out(j) else _pts[j]
		var f := clampf((y - _pts[k].y) / maxf(_pts[k + 1].y - _pts[k].y, 1e-6), 0.0, 1.0)
		return Vector2(lerpf(_pts[k].x, _pts[k + 1].x, f), y)
	var p := _point()
	if _s >= float(_pts.size() - 1) and _is_out(_pts.size() - 1):
		return p + Vector2(0, OUT_DROP) # fallen out: below the bottom, out of sight
	var w := minf(SMOOTH_PX, minf(_s - _run_start(), _run_end() - _s))
	if w <= 0.0:
		return p
	return Vector2(p.x, _mean_y(_s - w, _s + w))


## The first step of the stretch the drawn point walks on: after the last fall behind it, else 0.
func _run_start() -> float:
	var i := int(_s)
	while i > 0:
		if _is_fall(i - 1):
			return float(i)
		i -= 1
	return 0.0


## The last step of the stretch: before the next fall ahead, else the path's end.
func _run_end() -> float:
	var i := int(ceil(_s - 1e-9))
	while i < _pts.size() - 1:
		if _is_fall(i):
			return float(i)
		i += 1
	return float(_pts.size() - 1)


## The path's height averaged over steps a..b (piecewise linear between the columns).
func _mean_y(a: float, b: float) -> float:
	const N := 16
	var sum := 0.0
	for k in N:
		var s := a + (b - a) * (k + 0.5) / N
		var i := clampi(int(s), 0, _pts.size() - 1)
		var y := _pts[i].y if i >= _pts.size() - 1 else lerpf(_pts[i].y, _pts[i + 1].y, s - i)
		sum += y
	return sum / N
