extends RefCounted
## Leaves falling off a drawn tree (BossBody: Mộc Tinh's canopy, BossArt.LEAVES): now and then one in
## its idle, a shower of withered ones as it dies. Each leaf flutters down (a slow fall with a side
## sway, turning with it), lands on its ground and lies there fading out. Positions in the body's
## local px; drawn by the caller's canvas item (draw()). Visual only.

const FALL := 0.32 # body heights / s it drifts down at
const SWAY := 0.05 # body heights: the side sway's reach
const SWAY_HZ := 1.3
const SETTLE := 0.6 # s it lies on the ground fading

var leaves: Array = [] # [{p, v0, r, col, rot, phase, age, life, ground, landed, speed}]
var fade := 1.0 # all of them × this (the dying tree fading out)


## A leaf at p (local px) r px long, falling at FALL × height (+ drift: a push, local px / s, easing
## out; speed × the fall), lying on `ground` (local y) once it lands; gone after `life` s at the latest.
func add(p: Vector2, r: float, col: Color, ground: float, drift: Vector2 = Vector2.ZERO, life: float = 4.0, speed: float = 1.0) -> void:
	leaves.append({"p": p, "v0": drift, "r": r, "col": col, "rot": randf() * TAU, "phase": randf() * TAU, "age": 0.0,
		"life": life, "ground": ground, "landed": -1.0, "speed": speed})


func count() -> int:
	return leaves.size()


## Moves them on (height: the body's px tall, their speed's scale).
func step(delta: float, height: float) -> void:
	if leaves.is_empty():
		return
	for l in leaves:
		var age := float(l["age"]) + delta
		l["age"] = age
		if float(l["landed"]) >= 0.0:
			l["landed"] = float(l["landed"]) + delta
			continue
		var push: Vector2 = Vector2(l["v0"]) * exp(-2.5 * age)
		var sway := cos(age * SWAY_HZ * TAU + float(l["phase"])) * SWAY * height * SWAY_HZ * TAU * 0.35
		var p: Vector2 = Vector2(l["p"]) + (push + Vector2(sway, FALL * float(l.get("speed", 1.0)) * height * clampf(age * 3.0, 0.2, 1.0))) * delta
		l["rot"] = float(l["rot"]) + sway / maxf(height, 1.0) * 6.0 * delta
		if p.y >= float(l["ground"]):
			p.y = float(l["ground"])
			l["landed"] = 0.0
		l["p"] = p
	leaves = leaves.filter(func(l): return float(l["age"]) < float(l["life"]) and float(l["landed"]) < SETTLE)


## How opaque a leaf is now (fading as it lies on the ground, or near the end of its life).
static func alpha(l: Dictionary) -> float:
	var a := 1.0
	if float(l["landed"]) >= 0.0:
		a = 1.0 - float(l["landed"]) / SETTLE
	a = minf(a, clampf((float(l["life"]) - float(l["age"])) / 0.4, 0.0, 1.0))
	return clampf(minf(a, float(l["age"]) / 0.12), 0.0, 1.0)


## A pointed leaf with its midrib (local px of ci).
func draw(ci: CanvasItem) -> void:
	for l in leaves:
		var a := alpha(l) * fade
		if a <= 0.0:
			continue
		var r := float(l["r"])
		var col: Color = l["col"]
		ci.draw_set_transform(l["p"], float(l["rot"]), Vector2.ONE)
		var pts := PackedVector2Array([Vector2(-r, 0), Vector2(-r * 0.4, -r * 0.42), Vector2(r * 0.45, -r * 0.36), Vector2(r, 0),
			Vector2(r * 0.45, r * 0.36), Vector2(-r * 0.4, r * 0.42)])
		ci.draw_colored_polygon(pts, Color(col, a))
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(col.darkened(0.6), a * 0.9), maxf(r * 0.12, 1.0), true)
		ci.draw_line(Vector2(-r * 0.85, 0), Vector2(r * 0.7, 0), Color(col.darkened(0.45), a * 0.8), maxf(r * 0.08, 0.8), true)
	if not leaves.is_empty():
		ci.draw_set_transform(Vector2.ZERO)
