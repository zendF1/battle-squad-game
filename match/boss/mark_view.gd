extends Node2D
## The boss's eruption marks on the ground (boss v4, Khổng Lồ Đá's Gai đá trồi; BossMarks holds
## them), under the players: each a glowing cracked circle of earth round where a party member
## stood at the cast, drawn flat on the ground (an ellipse radius wide), so it reads as "get out of
## here": a scorched floor with amber cracks running out from the middle, a pulsing rim with a
## warning ripple running out to it, a faint column of light over it and pebbles hopping in it as
## the ground rumbles. It stays across turns until its eruption: charge() (the turn start's replay
## before it) makes it rumble harder and brighter until then, erupt() flashes it out (the stone
## spikes are BombChainFx.erupt()'s), a vanished mark (the boss died, a sync without it) fades.
## sync() takes the model's marks (a snapshot, a TurnStarted). Visual only.

const POP_IN := 0.35 # s: a new mark opens from its middle
const FADE := 0.4 # s: a mark taken away fades
const FLASH := 0.3 # s: the eruption's flash
const PULSE_SEC := 1.1 # one pulse of the rim and the glow
const RIPPLE_SEC := 1.4 # a warning ripple running out to the rim
const FLAT := 0.27 # the ellipse's height for its width (seen along the ground)
const CRACKS := 8
const PEBBLES := 6
const AMBER := Color(1.0, 0.66, 0.2)
const HOT := Color(1.0, 0.93, 0.62)
const SCORCH := Color(0.22, 0.1, 0.04)
const INK := Color(0.1, 0.05, 0.02)

## markId -> {pos: Vector2, radius, k: 0..1 opened, charge: s left of its charge (-1 none),
## charge_sec, flash: s since it erupted (-1 none), fade: s since it was taken away (-1 none), seed}
var _marks := {}
var _t := 0.0
static var _column: GradientTexture2D
static var _glow: GradientTexture2D


func _ready() -> void:
	set_process(not _marks.is_empty())


## The marks drawn (not erupting or fading).
func ids() -> Array:
	var out: Array = []
	for id in _marks:
		if float(_marks[id]["flash"]) < 0.0 and float(_marks[id]["fade"]) < 0.0:
			out.append(id)
	out.sort()
	return out


func has(mark_id: String) -> bool:
	return ids().has(mark_id)


## Drawn at all (also erupting / fading).
func drawn() -> int:
	return _marks.size()


## A new mark (BossMarks.parse() shape); animate: it opens from its middle.
func show_mark(m: Dictionary, animate: bool = true) -> void:
	var id := str(m.get("markId", ""))
	if id == "":
		return
	if _marks.has(id) and float(_marks[id]["flash"]) < 0.0 and float(_marks[id]["fade"]) < 0.0:
		return
	_marks[id] = {"pos": m.get("position", Vector2.ZERO), "radius": maxf(float(m.get("radius", 60.0)), 10.0), "k": 0.0 if animate else 1.0,
		"charge": -1.0, "charge_sec": 0.0, "flash": -1.0, "fade": -1.0, "seed": float(hash(id) % 1000) / 37.0}
	_wake()


## The model's marks now (BossMarks.marks): the missing ones open (animate) or are there at once,
## the gone ones fade.
func sync(marks: Dictionary, animate: bool = false) -> void:
	for id in marks:
		show_mark(marks[id], animate)
	for id in _marks:
		if not marks.has(id) and float(_marks[id]["flash"]) < 0.0 and float(_marks[id]["fade"]) < 0.0:
			_marks[id]["fade"] = 0.0
	_wake()


## The mark erupts in sec (its turn start's replay): it rumbles harder and brighter until then.
func charge(mark_id: String, sec: float) -> void:
	if _marks.has(mark_id):
		_marks[mark_id]["charge"] = maxf(sec, 0.01)
		_marks[mark_id]["charge_sec"] = maxf(sec, 0.01)
		_wake()


## The mark is charging (tests).
func charging(mark_id: String) -> bool:
	return _marks.has(mark_id) and float(_marks[mark_id]["charge"]) > 0.0


## Its eruption: a flash, then it is gone.
func erupt(mark_id: String) -> void:
	if _marks.has(mark_id):
		_marks[mark_id]["flash"] = 0.0
		_marks[mark_id]["charge"] = -1.0
		_wake()


## Every mark fades (the boss died).
func clear() -> void:
	for id in _marks:
		if float(_marks[id]["flash"]) < 0.0:
			_marks[id]["fade"] = maxf(float(_marks[id]["fade"]), 0.0)
	_wake()


func _wake() -> void:
	set_process(not _marks.is_empty())
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for id in _marks.keys():
		var m: Dictionary = _marks[id]
		m["k"] = minf(1.0, float(m["k"]) + delta / POP_IN)
		if float(m["charge"]) > 0.0:
			m["charge"] = maxf(0.0, float(m["charge"]) - delta)
		if float(m["flash"]) >= 0.0:
			m["flash"] = float(m["flash"]) + delta
			if float(m["flash"]) >= FLASH:
				_marks.erase(id)
				continue
		if float(m["fade"]) >= 0.0:
			m["fade"] = float(m["fade"]) + delta
			if float(m["fade"]) >= FADE:
				_marks.erase(id)
	if _marks.is_empty():
		set_process(false)
	queue_redraw()


## How hard a mark rumbles now (0 idle .. 1 just before it erupts).
static func charge_k(charge: float, charge_sec: float) -> float:
	if charge < 0.0 or charge_sec <= 0.0:
		return 0.0
	return clampf(1.0 - charge / charge_sec, 0.0, 1.0)


func _draw() -> void:
	for id in _marks:
		_draw_mark(_marks[id])


func _draw_mark(m: Dictionary) -> void:
	var pos: Vector2 = m["pos"]
	var r: float = float(m["radius"])
	var open := 1.0 - pow(1.0 - float(m["k"]), 3.0)
	var ck := charge_k(float(m["charge"]), float(m["charge_sec"]))
	var flash := float(m["flash"])
	var fade := float(m["fade"])
	var a := 1.0
	if fade >= 0.0:
		a = 1.0 - fade / FADE
	var speed := 1.0 + ck * 3.5
	var pulse := 0.5 + 0.5 * sin(_t * TAU / PULSE_SEC * speed + float(m["seed"]))
	var bright := (0.55 + 0.45 * pulse) * (1.0 + ck * 0.8)
	var shake := Vector2(sin(_t * 61.0) * 1.6, cos(_t * 47.0) * 0.8) * ck
	var c := pos + shake
	var rr := r * open
	if flash >= 0.0: # the eruption: a hot flash spreading over the circle, then gone
		var f := flash / FLASH
		_ellipse(c, rr * (1.0 + 0.25 * f), Color(HOT, 0.85 * (1.0 - f)))
		_glow_at(c + Vector2(0, -rr * 0.2), rr * (1.3 + f), Color(AMBER, 0.7 * (1.0 - f)))
		return
	# the light column over it (behind everything in it)
	_column_at(c, rr, Color(AMBER, (0.3 + 0.14 * pulse + 0.25 * ck) * a))
	# the scorched floor, the glow in it
	_ellipse(c, rr, Color(SCORCH, 0.5 * a))
	_glow_at(c, rr * 1.05, Color(AMBER, minf(1.0, (0.7 + 0.3 * ck) * bright) * a))
	# cracks running out from the middle, glowing
	for i in CRACKS:
		var ang := TAU * i / CRACKS + float(m["seed"]) * 0.7 + sin(i * 2.3) * 0.25
		var pts := PackedVector2Array([c])
		var reach := rr * (0.72 + 0.22 * sin(i * 1.7 + float(m["seed"])))
		var p := Vector2.ZERO
		for j in 4:
			var u := (j + 1) / 4.0
			var jag := sin(i * 3.1 + j * 2.2 + float(m["seed"])) * 0.32
			p = Vector2(cos(ang + jag * (1.0 - u)), sin(ang + jag * (1.0 - u)) * FLAT) * reach * u
			pts.append(c + p)
		draw_polyline(pts, Color(INK, 0.75 * a), 5.0, true)
		draw_polyline(pts, Color(AMBER.lerp(HOT, 0.45 * pulse + 0.5 * ck), minf(1.0, bright) * a), 2.6, true)
	# the hot middle
	_glow_at(c, rr * 0.28, Color(HOT, (0.45 + 0.35 * pulse + 0.3 * ck) * a))
	# the rim: a pulsing ring, a warning ripple running out to it
	_ring(c, rr, Color(INK, 0.7 * a), 6.5)
	_ring(c, rr, Color(AMBER.lerp(HOT, 0.4 * pulse), (0.8 + 0.2 * pulse) * a), 3.0 + 2.0 * pulse + 2.0 * ck)
	var rip := fmod(_t / (RIPPLE_SEC / speed) + float(m["seed"]), 1.0)
	_ring(c, rr * (0.25 + 0.75 * rip), Color(HOT, 0.55 * (1.0 - rip) * a), 2.0)
	# pebbles hopping in it as the ground rumbles
	for i in PEBBLES:
		var ph := fmod(_t * (1.1 + 0.25 * i) * speed + i * 0.37 + float(m["seed"]), 1.0)
		var x := (fmod(float(i) * 0.618 + float(m["seed"]) * 0.1, 1.0) * 2.0 - 1.0) * rr * 0.8
		var hop := sin(ph * PI) * (5.0 + 7.0 * ck + 3.0 * (i % 3))
		var at := c + Vector2(x, -hop + (fmod(i * 0.41, 1.0) - 0.5) * rr * FLAT)
		draw_circle(at, 2.2 + (i % 2), Color(0.42, 0.32, 0.22, a))
		draw_circle(at + Vector2(-0.6, -0.6), 1.0, Color(0.7, 0.58, 0.42, a))


func _ellipse(c: Vector2, rx: float, col: Color) -> void:
	if rx <= 0.5:
		return
	draw_set_transform(c, 0.0, Vector2(1.0, FLAT))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO)


func _ring(c: Vector2, rx: float, col: Color, width: float) -> void:
	if rx <= 0.5:
		return
	var pts := PackedVector2Array()
	for i in 49:
		var ang := TAU * i / 48.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * rx * FLAT))
	draw_polyline(pts, col, width, true)


func _glow_at(c: Vector2, rx: float, col: Color) -> void:
	if rx <= 0.5:
		return
	draw_set_transform(c, 0.0, Vector2(1.0, FLAT))
	draw_texture_rect(glow_texture(), Rect2(-Vector2(rx, rx), Vector2(rx, rx) * 2.0), false, col)
	draw_set_transform(Vector2.ZERO)


## A faint column of light rising from the circle, fading upward.
func _column_at(c: Vector2, rx: float, col: Color) -> void:
	if rx <= 0.5:
		return
	var h := rx * 1.25
	draw_texture_rect(column_texture(), Rect2(c + Vector2(-rx * 0.92, -h), Vector2(rx * 1.84, h)), false, col)


## Soft round glow (white middle, clear rim), tinted when drawn.
static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 64
		_glow.height = 64
	return _glow


## The light column: clear at the top, strongest at the ground, soft at both sides.
static func column_texture() -> GradientTexture2D:
	if _column == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 1)])
		_column = GradientTexture2D.new()
		_column.gradient = g
		_column.fill_from = Vector2(0.5, 0.0)
		_column.fill_to = Vector2(0.5, 1.0)
		_column.width = 8
		_column.height = 64
	return _column
