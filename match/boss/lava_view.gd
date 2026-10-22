extends Node2D
## The boss's lava pools on the battlefield (match/boss/lava_zones.gd holds them): one glowing pool
## per zone, as wide as its radius each side of its position (the server burns |dx| ≤ radius),
## lying on the ground there: a dark crust rim, a bubbling orange-yellow surface, a heat glow and
## sparks rising. A new pool swells in (show_zone(): `pop` for a fire bomb's landing), a dried one
## cools to grey and fades (drop()). Visual only.

## A pool is a flat ellipse DEPTH px half high; it swells in over APPEAR_SEC and dries over DRY_SEC
## (Pool's constants).

var _pools := {} # zoneId -> Pool


## Shows the zones of a LavaZones model ({zoneId: zone}): new ones swell in, gone ones dry up.
func sync(zones: Dictionary) -> void:
	for id in zones:
		show_zone(zones[id], false)
	for id in _pools.keys():
		if not zones.has(id):
			drop(id)


func show_zone(z: Dictionary, pop: bool = true) -> void:
	var id := str(z.get("zoneId", ""))
	if id == "" or _pools.has(id):
		return
	var p := Pool.new()
	p.radius = float(z.get("radius", 40.0))
	p.position = z.get("position", Vector2.ZERO)
	p.pop = pop
	add_child(p)
	_pools[id] = p


func drop(id: String) -> void:
	var p = _pools.get(id)
	_pools.erase(id)
	if p != null and is_instance_valid(p):
		p.dry()


## The pools shown (not drying), by id.
func shown() -> Array:
	var out := _pools.keys()
	out.sort()
	return out


class Pool extends Node2D:
	const APPEAR_SEC := 0.45
	const DRY_SEC := 0.9
	const DEPTH := 9.0
	var radius := 40.0
	var pop := true
	var _t := 0.0
	var _grow := 0.0
	var _dry := -1.0 # 0..1 while drying, -1 not

	func _ready() -> void:
		_grow = 0.0 if pop else 0.7
		_t = randf() * 4.0

	func dry() -> void:
		if _dry < 0.0:
			_dry = 0.0

	func _process(delta: float) -> void:
		_t += delta
		_grow = minf(1.0, _grow + delta / APPEAR_SEC)
		if _dry >= 0.0:
			_dry += delta / DRY_SEC
			if _dry >= 1.0:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - pow(1.0 - _grow, 3.0)
		var heat := 1.0 if _dry < 0.0 else 1.0 - _dry
		var alpha := 1.0 if _dry < 0.0 else 1.0 - _dry * _dry
		var rx := radius * k
		var ry := DEPTH * k
		if rx < 1.0:
			return
		for i in 3: # the heat glow
			var g := 1.0 + i * 0.45
			draw_colored_polygon(_ell(Vector2(0, -2), rx * g + 6.0, ry * g * 2.2 + 4.0), Color(1.0, 0.45, 0.1, 0.12 * heat * alpha / g))
		draw_colored_polygon(_ell(Vector2.ZERO, rx + 3.0, ry + 2.5), Color(0.18, 0.1, 0.08, 0.95 * alpha))
		var hot := Color(1.0, 0.42, 0.08).lerp(Color(0.45, 0.42, 0.42), 1.0 - heat)
		draw_colored_polygon(_ell(Vector2.ZERO, rx, ry), Color(hot, alpha))
		var core := Color(1.0, 0.78, 0.25).lerp(Color(0.55, 0.52, 0.5), 1.0 - heat)
		draw_colored_polygon(_ell(Vector2(0, -1), rx * 0.72, ry * 0.55), Color(core, alpha))
		var n := clampi(int(radius / 12.0), 3, 9)
		for i in n: # bubbles
			var ph := fmod(_t * 0.8 + i * 0.37, 1.0)
			var x := (float(i) / maxf(n - 1, 1) * 2.0 - 1.0) * rx * 0.75 + sin(i * 7.3) * 4.0
			var r := (1.5 + 2.5 * sin(ph * PI)) * k
			draw_circle(Vector2(x, -1 + sin(i * 3.1) * ry * 0.3), r, Color(1.0, 0.95, 0.6, 0.8 * heat * alpha))
		for i in 4: # sparks rising
			var ph := fmod(_t * 0.6 + i * 0.25, 1.0)
			var x := sin(i * 5.1 + _t * 0.3) * rx * 0.7
			draw_circle(Vector2(x, -ph * 46.0), 1.8 * (1.0 - ph), Color(1.0, 0.7, 0.2, (1.0 - ph) * heat * alpha))

	static func _ell(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts
