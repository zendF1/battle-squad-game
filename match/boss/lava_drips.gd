extends RefCounted
## Lava drops off a drawn boss (BossBody: Cua Dung Nham, BossArt.DRIPS / BossArt.SPOUT): now and then a
## drop falls off one of its drips' tips and sizzles on the ground (a flat glow spreading and cooling,
## a wisp of steam); at fire_bombs' peak a spout of globs shoots up out of its shell. Each drop falls
## with gravity, stretched along its speed; a drop that lands sizzles SIZZLE s, one whose life ends
## in the air fades. Positions in the body's local px; drawn by the caller's canvas item (draw()).
## Visual only.

const GRAVITY := 3.4 # body heights / s²
const GROW := 0.12 # s a drop takes to swell off its tip
const SIZZLE := 0.6 # s it sizzles on the ground
const HOT := Color(1.0, 0.86, 0.36)
const LAVA := Color(1.0, 0.5, 0.12)
const RIM := Color(0.55, 0.16, 0.05)
const STEAM := Color(0.62, 0.6, 0.6)

var drops: Array = [] # [{p, v, r, age, life, ground, landed}]


## A drop at p (local px), r px round, landing on `ground` (local y; INF: never), starting at v
## (local px / s), gone after `life` s at the latest.
func add(p: Vector2, r: float, ground: float, v: Vector2 = Vector2.ZERO, life: float = 3.0) -> void:
	drops.append({"p": p, "v": v, "r": r, "age": 0.0, "life": life, "ground": ground, "landed": -1.0})


func count() -> int:
	return drops.size()


## The ones lying on the ground sizzling (tests).
func sizzling() -> int:
	return drops.filter(func(d): return float(d["landed"]) >= 0.0).size()


## Moves them on (height: the body's px tall, the gravity's scale).
func step(delta: float, height: float) -> void:
	if drops.is_empty():
		return
	for d in drops:
		d["age"] = float(d["age"]) + delta
		if float(d["landed"]) >= 0.0:
			d["landed"] = float(d["landed"]) + delta
			continue
		if float(d["age"]) < GROW and Vector2(d["v"]) == Vector2.ZERO:
			continue # still swelling off its tip
		var v: Vector2 = Vector2(d["v"]) + Vector2(0, GRAVITY * height * delta)
		var p: Vector2 = Vector2(d["p"]) + v * delta
		if p.y >= float(d["ground"]) and v.y > 0.0:
			p.y = float(d["ground"])
			d["landed"] = 0.0
			v = Vector2.ZERO
		d["v"] = v
		d["p"] = p
	drops = drops.filter(func(d): return float(d["age"]) < float(d["life"]) and float(d["landed"]) < SIZZLE)


## A drop, its glow and its tail (stretched along its speed); a landed one: its sizzle.
func draw(ci: CanvasItem) -> void:
	for d in drops:
		var p: Vector2 = d["p"]
		var r := float(d["r"])
		var landed := float(d["landed"])
		if landed >= 0.0:
			var k := landed / SIZZLE
			ci.draw_set_transform(p, 0.0, Vector2(1.0, 0.32))
			ci.draw_circle(Vector2.ZERO, r * (1.6 + 2.2 * k), Color(LAVA, 0.35 * (1.0 - k)))
			ci.draw_circle(Vector2.ZERO, r * (1.1 + 0.9 * k), Color(LAVA.lerp(RIM, k), 0.9 * (1.0 - k)))
			ci.draw_circle(Vector2.ZERO, r * 0.6 * (1.0 - k), Color(HOT, 1.0 - k))
			ci.draw_set_transform(Vector2.ZERO)
			for i in 2: # a wisp of steam
				var u := clampf(k * 1.4 - i * 0.25, 0.0, 1.0)
				if u > 0.0 and u < 1.0:
					var at := p + Vector2((i - 0.5) * r * 2.0 + sin(u * 6.0 + i) * r, -r * (1.0 + 7.0 * u))
					ci.draw_circle(at, r * (0.8 + 1.4 * u), Color(STEAM, 0.45 * sin(PI * u)))
			continue
		var a := clampf((float(d["life"]) - float(d["age"])) / 0.25, 0.0, 1.0)
		var grow := clampf(float(d["age"]) / GROW, 0.35, 1.0) if Vector2(d["v"]) == Vector2.ZERO else 1.0
		var rr := r * grow
		var v: Vector2 = d["v"]
		var tail := -v.normalized() * minf(v.length() * 0.035, rr * 4.0) if v.length() > 1.0 else Vector2.ZERO
		ci.draw_circle(p, rr * 2.2, Color(LAVA, 0.22 * a))
		if tail != Vector2.ZERO:
			ci.draw_line(p, p + tail, Color(LAVA, 0.85 * a), rr * 1.3, true)
		ci.draw_circle(p, rr * 1.15, Color(RIM, a))
		ci.draw_circle(p, rr, Color(LAVA, a))
		ci.draw_circle(p + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.5, Color(HOT, a))
