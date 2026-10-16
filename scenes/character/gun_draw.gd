extends RefCounted
## The match's gun draw (pure logic, no nodes; scenes/character/character.gd shows it): the gun is
## holstered by default (idle and walk show the character's own drawn arms), drawn while the
## player aims and put away after the shot.
##
##   holstered ─draw()─▶ drawing ─(progress 1)─▶ aiming ─fire()─▶ firing ─(fireHoldSec)─▶ holstering ─(progress 0)─▶ holstered
##
## - progress (0 holstered .. 1 out) rises over drawSec while drawing and falls over holsterSec
##   while holstering, so a draw() during holstering (or a holster() during drawing) reverses
##   from where it is, no snapping. shown() is the eased progress the view poses from.
## - fire() with the gun out fires at once (returns 0); otherwise it draws at fastDrawSec and
##   fires when the gun is out (update() returns "fire"), returning the seconds until then, so
##   the shot can be drawn leaving from the muzzle (remote and bot shots never aimed here).
## - holster() cancels a pending fire.
##
## TIMINGS is the one table of the draw's timings and pose; a side view may override any of them
## in its side.json "gunDraw" object (ui/art.gd parse_side()).

enum { HOLSTERED, DRAWING, AIMING, FIRING, HOLSTERING }
const STATE_NAMES := ["holstered", "drawing", "aiming", "firing", "holstering"]

const TIMINGS := {
	"drawSec": 0.22, # drag start → the gun is out
	"fastDrawSec": 0.12, # a shot that leaves before the gun is out (remote / bot shots)
	"holsterSec": 0.2, # put away
	"fireHoldSec": 0.4, # firing (the recoil, 0.33 s) → holstering starts
	"carryAngle": 75.0, # degrees the barrel points down in the low carry the draw starts from
	"carryScale": 0.55, # the gun's size in the low carry
	"carryOffset": [-0.05, 0.08], # the low carry from the grip, x back / y down, of the figure height
	"fadeIn": 0.35, # part of the draw the gun fades in over (out over the same part of a holster)
	"leanDeg": 3.0, # the ready stance leans forward this much round the feet
	"crouch": 0.015, # and squats this much (scale y)
	"squash": 0.03, # a squash-and-stretch bump through the middle of the draw
}

var state := HOLSTERED
## 0 holstered .. 1 the gun out.
var progress := 0.0
var timings := TIMINGS.duplicate(true)

var _speed := 0.0 # progress per s while drawing
var _fire_pending := false
var _fire_left := 0.0


## overrides: any TIMINGS keys (side.json "gunDraw").
func _init(overrides: Dictionary = {}) -> void:
	for key in overrides:
		if not timings.has(key):
			continue
		if timings[key] is Array:
			var v = overrides[key]
			if v is Array and v.size() >= 2:
				timings[key] = [float(v[0]), float(v[1])]
		else:
			timings[key] = maxf(0.0, float(overrides[key]))


func state_name() -> String:
	return STATE_NAMES[state]


## The gun is shown (any state but holstered).
func armed() -> bool:
	return state != HOLSTERED


## The gun is all the way out.
func is_out() -> bool:
	return state == AIMING or state == FIRING


func fire_pending() -> bool:
	return _fire_pending


## The eased progress the view poses from: ease-out cubic (quick out, settling at the aim).
func shown() -> float:
	return 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 3.0)


## The gun's opacity: fades in over the first fadeIn of the draw.
func alpha() -> float:
	var f: float = timings["fadeIn"]
	return 1.0 if f <= 0.0 else clampf(progress / f, 0.0, 1.0)


## Starts drawing (from holstered, or reversing a holster from its progress). fast: at
## fastDrawSec. A draw while firing keeps the gun out (aiming again).
func draw(fast: bool = false) -> void:
	match state:
		HOLSTERED, HOLSTERING:
			state = DRAWING
			_speed = _rate(fast)
		DRAWING:
			if fast:
				_speed = maxf(_speed, _rate(true))
		FIRING:
			state = AIMING
	if state == DRAWING and (progress >= 1.0 or _speed >= 1e9):
		progress = 1.0
		state = AIMING


## Puts the gun away (from drawing, aiming or firing); cancels a pending fire.
func holster() -> void:
	_fire_pending = false
	if state == DRAWING or state == AIMING or state == FIRING:
		state = HOLSTERING
		if timings["holsterSec"] <= 0.0:
			progress = 0.0
			state = HOLSTERED


## Fires: at once with the gun out (returns 0, the caller plays the recoil); otherwise draws fast
## and fires when out (update() returns "fire"), returning the seconds until then.
func fire() -> float:
	if is_out():
		state = FIRING
		_fire_left = timings["fireHoldSec"]
		_fire_pending = false
		return 0.0
	_fire_pending = true
	draw(true)
	if state == AIMING: # was already out (a zero-length draw)
		return fire()
	return (1.0 - progress) / maxf(_speed, 0.0001)


## Back to holstered at once (death, a rebuilt match).
func reset() -> void:
	state = HOLSTERED
	progress = 0.0
	_fire_pending = false
	_fire_left = 0.0


## Advances by delta seconds. Returns what happened: "drawn" (aiming), "fire" (a pending fire
## leaves: play the recoil), "holstering" (the fire hold is over), "holstered", or "".
func update(delta: float) -> String:
	match state:
		DRAWING:
			progress += delta * _speed
			if progress >= 1.0:
				progress = 1.0
				if _fire_pending:
					_fire_pending = false
					state = FIRING
					_fire_left = timings["fireHoldSec"]
					return "fire"
				state = AIMING
				return "drawn"
		FIRING:
			_fire_left -= delta
			if _fire_left <= 0.0:
				holster()
				return "holstered" if state == HOLSTERED else "holstering"
		HOLSTERING:
			var sec: float = timings["holsterSec"]
			progress -= delta / sec if sec > 0.0 else 1.0
			if progress <= 0.0:
				progress = 0.0
				state = HOLSTERED
				return "holstered"
	return ""


func _rate(fast: bool) -> float:
	var sec: float = timings["fastDrawSec"] if fast else timings["drawSec"]
	return 1.0 / sec if sec > 0.0 else 1e9
