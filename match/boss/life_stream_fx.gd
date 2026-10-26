extends Node2D
## Life flowing into a boss (boss v4, Mộc Tinh), on the fx layer: particles leave each source and
## fly along a curve into the boss's heart, emitted for emit_sec, each one travel_sec on its way.
## Looks: DRAIN (Hút sinh lực: glowing green-gold motes and sparkles pulled out of the drained
## member's body into the sap heart, while the beam holds), REGEN (the mushrooms' regen at the boss's
## turn start: leaves and sparkles rising from each mushroom and drifting into the tree). The ends
## are read every frame (the bodies may move): `sources` / `target` are nodes (a PlayerView: its
## body's middle, a boss's view: its heart, heart_position()) or fixed points (Vector2, layer
## coordinates; a PlayerView's points are in the world, as this layer). Visual only; frees itself when the last particle arrived.

const DRAIN := "drain"
const REGEN := "regen"
const GOLD := Color(1.0, 0.86, 0.35)
const LIFE_GREEN := Color(0.62, 1.0, 0.42)
const LEAF := Color(0.42, 0.78, 0.28)
const EVERY := {DRAIN: 0.016, REGEN: 0.035} # s between two particles of a source
const ARC := {DRAIN: 0.1, REGEN: 0.16} # how high the curve bows, of the distance

var look := DRAIN
var sources: Array = [] # Node2D / Vector2
var target = null # Node2D / Vector2
var emit_sec := 0.5
var travel_sec := 0.6
var delay := 0.0 # s before the first particle leaves

var _t := 0.0
var _parts: Array = [] # [{src: index, born, seed}]
var _next_at := 0.0
var _arrived := 0 # particles that reached the heart (tests)


func _init(kind: String = DRAIN) -> void:
	look = kind if EVERY.has(kind) else DRAIN
	z_index = 3


func arrived() -> int:
	return _arrived


func alive() -> int:
	return _parts.size()


## Where an end is now (the views' layer is the world, as this one's); null when its node is gone.
func _point(end) -> Variant:
	if end is Vector2:
		return end
	if end is Node2D and is_instance_valid(end):
		if end.has_method("heart_position"):
			return end.heart_position()
		if end.has_method("body_centre"):
			return end.body_centre()
		return end.position
	return null


func _process(delta: float) -> void:
	_t += delta
	var since := _t - delay
	if since >= 0.0 and since <= emit_sec:
		while _next_at <= since:
			for i in sources.size():
				_parts.append({"src": i, "born": delay + _next_at, "seed": randf()})
			_next_at += float(EVERY[look])
	var kept: Array = []
	for p in _parts:
		if _t - float(p["born"]) >= travel_sec:
			_arrived += 1
		else:
			kept.append(p)
	_parts = kept
	if since > emit_sec and _parts.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var to = _point(target)
	if to == null:
		return
	var since := _t - delay
	if look == DRAIN and since >= 0.0: # the flow: a glowing thread from each source into the heart while it drains
		var k := clampf(since / 0.15, 0.0, 1.0) * clampf((emit_sec + travel_sec * 0.6 - since) / 0.3, 0.0, 1.0)
		for src in sources:
			var from = _point(src)
			if from == null or k <= 0.0:
				continue
			var pts := PackedVector2Array()
			var d: Vector2 = to - from
			for i in 25:
				var u := i / 24.0
				pts.append(from + d * u + Vector2(0, -d.length() * float(ARC[look]) * 0.5 * 4.0 * u * (1.0 - u)) \
					+ Vector2(0, sin(u * 18.0 - _t * 14.0) * 4.0))
			draw_polyline(pts, Color(LIFE_GREEN, 0.18 * k), 16.0, true)
			draw_polyline(pts, Color(GOLD, 0.55 * k), 3.0, true)
	for p in _parts:
		var from = _point(sources[int(p["src"])]) if int(p["src"]) < sources.size() else null
		if from == null:
			continue
		var u := clampf((_t - float(p["born"])) / travel_sec, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u) # eased: slow off the body, fast into the heart
		var sd: float = p["seed"]
		var d: Vector2 = to - from
		var bow := Vector2(0, -d.length() * float(ARC[look]) * 0.5) + Vector2(-d.y, d.x).normalized() * 26.0 * (sd - 0.5) * 2.0
		if look == REGEN:
			bow = Vector2(0, -d.length() * float(ARC[look]) * (0.6 + 0.4 * sd))
		var mid: Vector2 = from + d * 0.5 + bow + Vector2(sin(sd * 40.0), cos(sd * 31.0)) * 12.0
		var at: Vector2 = from.lerp(mid, e).lerp(mid.lerp(to, e), e)
		var fade := minf(1.0, u * 6.0) * minf(1.0, (1.0 - u) * 5.0 + 0.3)
		if look == DRAIN:
			var col := LIFE_GREEN.lerp(GOLD, u)
			var r := (4.0 + 4.0 * sd) * (1.0 - 0.35 * u)
			draw_circle(at, r * 2.4, Color(col, 0.22 * fade))
			draw_circle(at, r, Color(col.lightened(0.3), 0.9 * fade))
			if int(sd * 100.0) % 4 == 0: # a sparkle
				var g := r * 1.8
				draw_line(at - Vector2(g, 0), at + Vector2(g, 0), Color(1, 1, 0.9, 0.8 * fade), 1.4, true)
				draw_line(at - Vector2(0, g), at + Vector2(0, g), Color(1, 1, 0.9, 0.8 * fade), 1.4, true)
		else:
			if int(sd * 100.0) % 3 == 0: # a sparkle
				var g := 6.0 + 3.0 * sd
				draw_circle(at, g * 1.6, Color(LIFE_GREEN, 0.25 * fade))
				draw_line(at - Vector2(g, 0), at + Vector2(g, 0), Color(1, 1, 0.85, 0.9 * fade), 1.4, true)
				draw_line(at - Vector2(0, g), at + Vector2(0, g), Color(1, 1, 0.85, 0.9 * fade), 1.4, true)
			else: # a leaf, turning over
				var rot := _t * 5.0 + sd * TAU
				var r := 7.0 + 3.0 * sd
				var pts := PackedVector2Array()
				for i in 8:
					var ang := TAU * i / 8.0
					pts.append(at + Vector2(cos(ang) * r, sin(ang) * r * 0.42).rotated(rot))
				draw_colored_polygon(pts, Color(LEAF.lerp(LIFE_GREEN, sd), 0.95 * fade))
				draw_line(at - Vector2(r, 0).rotated(rot), at + Vector2(r, 0).rotated(rot), Color(0.12, 0.3, 0.08, 0.7 * fade), 1.0, true)
