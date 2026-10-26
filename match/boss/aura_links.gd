extends Node2D
## The minion auras drawn between the units (boss v4), under the players: a glowing amber rune link
## from each armour minion (MatchState.boss armorMinions: Khổng Lồ Đá's stone totems) to the boss's
## chest, energy pulses running along it to the boss and rune marks along it shimmering; a faint
## green vine thread from each regen minion (regenMinions: Mộc Tinh's mushrooms) to the boss, leaf
## motes drifting along it, brighter while it heals the boss (pulse_regen()). A new link grows out
## from the minion; a link whose minion is gone snaps: its pieces fall and fade (BREAK_SEC). The
## ends are read from the views every frame (`views`: match_screen's playerId -> PlayerView, a
## boss view's heart_position(), a minion's body_centre()). Visual only.

const ARMOR := "armor"
const REGEN := "regen"
const GROW_SEC := 0.45
const BREAK_SEC := 0.7
const PIECES := 9
const GRAVITY := 900.0
const AMBER := Color(1.0, 0.72, 0.22)
const AMBER_HOT := Color(1.0, 0.95, 0.7)
const VINE := Color(0.5, 0.86, 0.3)
const INK := Color(0.12, 0.07, 0.03)
const VINE_SAG := 0.07

var views := {} # playerId -> PlayerView
var boss_id := "" # the boss's playerId

var _links := {} # kind -> {minion id: k (0..1 grown)}
var _breaks: Array = [] # [{a, b, age, kind, seed}]
var _t := 0.0
var _regen_pulse := 0.0


func _init() -> void:
	_links = {ARMOR: {}, REGEN: {}}


## The aura lists now (BossHudModel armor_minions / regen_minions): new links grow (at once without
## animate), gone ones snap (animate) or vanish.
func set_links(armor: Array, regen: Array, animate: bool = true) -> void:
	_set_kind(ARMOR, armor, animate)
	_set_kind(REGEN, regen, animate)
	queue_redraw()


func _set_kind(kind: String, ids: Array, animate: bool) -> void:
	var held: Dictionary = _links[kind]
	for id in ids:
		if not held.has(id):
			held[id] = 0.0 if animate else 1.0
	for id in held.keys():
		if not ids.has(id):
			if animate:
				var ends := _ends(str(id))
				if not ends.is_empty():
					_breaks.append({"a": ends[0], "b": ends[1], "age": 0.0, "kind": kind, "seed": randf() * 10.0, "k": float(held[id])})
			held.erase(id)


## The links' minions (tests): kind ARMOR / REGEN.
func ids(kind: String) -> Array:
	var out: Array = _links.get(kind, {}).keys()
	out.sort()
	return out


## Links snapping now (tests).
func breaking() -> int:
	return _breaks.size()


## The regen heals the boss: the vine threads flare.
func pulse_regen() -> void:
	_regen_pulse = 1.0


## A link's ends now: [the minion's body middle, the boss's heart]; [] when a view is missing.
func _ends(id: String) -> Array:
	var m = views.get(id)
	var b = views.get(boss_id)
	if m == null or b == null or not is_instance_valid(m) or not is_instance_valid(b):
		return []
	var from: Vector2 = m.body_centre() if m.has_method("body_centre") else m.position
	var to: Vector2 = b.heart_position() if b.has_method("heart_position") else b.position
	return [from, to]


func _process(delta: float) -> void:
	_t += delta
	_regen_pulse = maxf(0.0, _regen_pulse - delta / 1.2)
	for kind in _links:
		var held: Dictionary = _links[kind]
		for id in held:
			held[id] = minf(1.0, float(held[id]) + delta / GROW_SEC)
	for b in _breaks:
		b["age"] = float(b["age"]) + delta
	_breaks = _breaks.filter(func(b): return float(b["age"]) < BREAK_SEC)
	queue_redraw()


func _draw() -> void:
	for id in _links[ARMOR]:
		var ends := _ends(str(id))
		if not ends.is_empty():
			_rune_link(ends[0], ends[1], float(_links[ARMOR][id]), float(hash(id) % 100) / 10.0)
	for id in _links[REGEN]:
		var ends := _ends(str(id))
		if not ends.is_empty():
			_vine_link(ends[0], ends[1], float(_links[REGEN][id]), float(hash(id) % 100) / 10.0)
	for b in _breaks:
		_snapped(b)


## The point at u (0 the minion .. 1 the boss) of a link from a to b: a shallow arc up.
static func link_point(a: Vector2, b: Vector2, u: float, sag: float = 0.12) -> Vector2:
	var p := a.lerp(b, u)
	return p + Vector2(0, -a.distance_to(b) * sag * 4.0 * u * (1.0 - u))


func _rune_link(a: Vector2, b: Vector2, grow: float, seed: float) -> void:
	var n := 28
	var pts := PackedVector2Array()
	var end := maxi(2, int(ceil(n * grow)) + 1)
	for i in mini(end, n + 1):
		var u := float(i) / n
		pts.append(link_point(a, b, u) + Vector2(0, sin(u * 22.0 + _t * 6.0 + seed) * 1.6))
	var flick := 0.8 + 0.2 * sin(_t * 13.0 + seed)
	draw_polyline(pts, Color(AMBER, 0.16 * flick), 14.0, true)
	draw_polyline(pts, Color(INK, 0.45), 5.0, true)
	draw_polyline(pts, Color(AMBER, 0.85 * flick), 2.6, true)
	draw_polyline(pts, Color(AMBER_HOT, 0.6 * flick), 1.0, true)
	var length := a.distance_to(b)
	var marks := clampi(int(length / 90.0), 2, 14)
	for i in marks: # rune marks along it, shimmering
		var u := (i + 0.5) / marks
		if u > grow:
			break
		var p := link_point(a, b, u)
		var s := 4.5 + 1.5 * sin(_t * 4.0 + i * 1.3 + seed)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.7, 0), p + Vector2(0, s), p + Vector2(-s * 0.7, 0)]),
			Color(AMBER.lerp(AMBER_HOT, 0.4), 0.9))
		draw_polyline(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.7, 0), p + Vector2(0, s), p + Vector2(-s * 0.7, 0),
			p + Vector2(0, -s)]), INK, 1.4, true)
	if grow >= 1.0:
		for k in 3: # energy pulses running to the boss
			var u := fmod(_t * 0.55 + k / 3.0 + seed * 0.1, 1.0)
			var p := link_point(a, b, u)
			draw_circle(p, 7.0, Color(AMBER, 0.25))
			draw_circle(p, 3.2, Color(AMBER_HOT, 0.95))
		draw_circle(b, 9.0 + 2.0 * sin(_t * 5.0), Color(AMBER, 0.22))
	draw_circle(a, 6.0, Color(AMBER, 0.35 * flick))


func _vine_link(a: Vector2, b: Vector2, grow: float, seed: float) -> void:
	var k := _regen_pulse # the thread itself only shows while it heals the boss
	if k > 0.02:
		var n := 36
		var pts := PackedVector2Array()
		var end := maxi(2, int(ceil(n * grow)) + 1)
		for i in mini(end, n + 1):
			var u := float(i) / n
			pts.append(link_point(a, b, u, VINE_SAG) + Vector2(0, sin(u * 30.0 + seed) * 5.0))
		draw_polyline(pts, Color(VINE, 0.22 * k), 9.0, true)
		draw_polyline(pts, Color(VINE.darkened(0.3), 0.7 * k), 2.2, true)
	if grow >= 1.0: # leaf motes drifting along it to the boss, faint between heals
		var motes := 5 + int(7.0 * k)
		for i in motes:
			var u := fmod(_t * (0.12 + 0.4 * k) + i / float(motes) + seed * 0.07, 1.0)
			var p := link_point(a, b, u, VINE_SAG) + Vector2(0, sin(u * 30.0 + seed) * 5.0)
			draw_circle(p, 2.2 + 1.8 * k, Color(VINE.lightened(0.3), (0.28 + 0.6 * k) * sin(u * PI)))


## A snapped link: its pieces fall and fade, a flash at the boss's end.
func _snapped(br: Dictionary) -> void:
	var age := float(br["age"])
	var f := age / BREAK_SEC
	var a: Vector2 = br["a"]
	var b: Vector2 = br["b"]
	var col := AMBER if str(br["kind"]) == ARMOR else VINE
	for i in PIECES:
		var u0 := float(i) / PIECES
		var u1 := (i + 0.8) / PIECES
		if u0 > float(br["k"]):
			break
		var drop := Vector2((sin(i * 3.7 + float(br["seed"])) * 60.0) * age, 0.5 * GRAVITY * age * age * (0.6 + 0.4 * sin(i * 1.9)))
		var p0 := link_point(a, b, u0) + drop
		var p1 := link_point(a, b, u1) + drop
		draw_line(p0, p1, Color(INK, 0.5 * (1.0 - f)), 5.0, true)
		draw_line(p0, p1, Color(col, (1.0 - f)), 2.4, true)
	if f < 0.4:
		draw_circle(b, 14.0 * (1.0 + f * 2.0), Color(AMBER_HOT if str(br["kind"]) == ARMOR else VINE, 0.5 * (1.0 - f / 0.4)))
