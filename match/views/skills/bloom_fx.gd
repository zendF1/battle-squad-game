extends Node2D
## Hoa hồi xuân's replay drawing (bloom.gd adds one per bloom to the fx layer; layer coordinates).
## Visual only: when and where comes from the server timeline (the seeds' paths, the heal /
## shield / cleanse events); the numbers are match_screen's popups.
## - exit(): where the seeds leave the top of the screen together, a green burst (they split up
##   there, out of view);
## - shaft(): while a seed falls onto its ally, a soft green light shaft from the top of the
##   screen down to the ally and a pulsing ring at its feet (it reads even with the allies at
##   both ends of the map, the camera following the seeds' box; it fades out to nothing at the
##   top, so a camera risen over the map never shows where it starts);
## - bloom(): where a seed lands (the heal event), a flash, a flower of petals opening on the
##   ground around the feet, leaves bursting and drifting down, healing motes and little green
##   crosses rising, a rising glow;
## - shield(): overflow turned into shield, a light-blue bubble popping round the body with a
##   shine sweeping over it and sparkles round the "+N khiên" number;
## - cleanse(): bad effects removed, a ring of little stars bursting off the body and a white
##   puff (the status overlays themselves are the character's, not drawn here).
## Particles move analytically from their age (no per-frame state); the shapes are a few cached
## polygons drawn with transforms. `t` is the replay
## time (bloom.gd syncs it every frame of the replay); after the replay it runs on with the frame
## time, and the node frees itself when the last effect is over.

const Art := preload("res://ui/art.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const SHAFT_IN := 0.25 # s the shaft takes to appear
const SHAFT_OUT := 0.35 # s it fades after the seed lands
const EXIT_LIFE := 0.5
const FLASH_LIFE := 0.4
const FLOWER_LIFE := 1.15
const LEAF_LIFE := 1.3
const MOTE_LIFE := 1.25
const CROSS_LIFE := 1.1
const SHIELD_LIFE := 1.4
const CLEANSE_LIFE := 0.6
const LEAVES := 11
const MOTES := 14
const CROSSES := 4
const PETALS := 8
const CLEANSE_SPARKS := 10
const SHIELD_SPARKS := 8
const POPUP_Y := -146.0 # the "+N khiên" number's centre above the feet (match_screen _popup)

const GREEN := Color(0.45, 0.95, 0.4)
const GREEN_DEEP := Color(0.18, 0.62, 0.22)
const LEAF := [Color(0.3, 0.78, 0.3), Color(0.5, 0.9, 0.35), Color(0.22, 0.66, 0.32)]
const PINK := Color(1.0, 0.62, 0.78)
const PETAL_OUT := Color(0.4, 0.86, 0.36)
const PETAL_RIM := Color(0.12, 0.45, 0.16)
const PETAL_IN := Color(0.93, 1.0, 0.78)
const LIGHT := Color(0.8, 1.0, 0.7)
const CORE := Color(1.0, 0.95, 0.55)
const SHIELD := Color(0.62, 0.9, 1.0)

## Replay time (s since the shot).
var t := 0.0

var _synced := false
var _rng := RandomNumberGenerator.new()
var _exits: Array = [] # {pos, at}
var _shafts: Array = [] # {x, feet (live: view), view, from, land}
var _blooms: Array = [] # {view, feet, at, leaves, motes, crosses, spin}
var _shields: Array = [] # {view, at, sparks}
var _cleanses: Array = [] # {view, feet, at, sparks}
var _end := 0.0 # when the last effect added so far is over
var _glow: Node2D # additive: flashes, motes, the shafts' cores
var _glow_tex: Texture2D
var _sparkle_tex: Texture2D
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _quad_cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])

# Unit shapes, built once: a petal / leaf (from 0 to +x 1, width 1), a plus sign and a four-point
# star (radius 1).
static var _petal := PackedVector2Array()
static var _cross := PackedVector2Array()
static var _star := PackedVector2Array()


func _init() -> void:
	if _petal.is_empty():
		for i in 13:
			var u := float(i) / 12.0
			_petal.append(Vector2(u, 0.5 * sin(PI * u) * (1.0 - 0.35 * u)))
		for i in range(11, 0, -1):
			var u := float(i) / 12.0
			_petal.append(Vector2(u, -0.5 * sin(PI * u) * (1.0 - 0.35 * u)))
		var a := 0.32
		_cross = PackedVector2Array([Vector2(-a, -1), Vector2(a, -1), Vector2(a, -a), Vector2(1, -a), Vector2(1, a), Vector2(a, a),
			Vector2(a, 1), Vector2(-a, 1), Vector2(-a, a), Vector2(-1, a), Vector2(-1, -a), Vector2(-a, -a)])
		for i in 8:
			var r := 1.0 if i % 2 == 0 else 0.28
			_star.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 8.0) * r)
	_rng.randomize()
	_glow_tex = Art.tier_fx("glow")
	_sparkle_tex = Art.tier_fx("sparkle")
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


## Called by bloom.gd every frame of the replay with its time.
func sync(replay_t: float) -> void:
	t = replay_t
	_synced = true


func _process(delta: float) -> void:
	if _synced:
		_synced = false
	else:
		t += delta
		if t > _end:
			queue_free()
			return
	queue_redraw()
	_glow.queue_redraw()


## Whether an effect is still to come or playing at replay time `at`.
func busy(at: float) -> bool:
	return at <= _end


func _reach(at: float) -> void:
	_end = maxf(_end, at)


## The seeds leave the top of the screen at x at replay time at.
func exit(x: float, at: float) -> void:
	_exits.append({"pos": Vector2(x, 0.0), "at": at})
	_reach(at + EXIT_LIFE)


## A seed falls onto the player of `view` from replay time from, landing at land.
func shaft(view: Node2D, from: float, land: float) -> void:
	_shafts.append({"view": view, "from": from, "land": land})
	_reach(land + SHAFT_OUT)


## The seed landed on the player of `view` at replay time at.
func bloom(view: Node2D, at: float) -> void:
	var b := {"view": view, "feet": view.position, "at": at, "spin": _rng.randf_range(-0.6, 0.6) + 0.35,
		"leaves": [], "motes": [], "crosses": []}
	for i in LEAVES:
		var ang := _rng.randf_range(-PI * 0.92, -PI * 0.08)
		var col: Color = PINK if i % 4 == 0 else LEAF[i % LEAF.size()]
		b["leaves"].append({"v": Vector2.from_angle(ang) * _rng.randf_range(130.0, 250.0), "rot": _rng.randf() * TAU,
			"spin": _rng.randf_range(-5.0, 5.0), "size": _rng.randf_range(8.0, 12.0), "sway": _rng.randf() * TAU, "color": col,
			"delay": _rng.randf_range(0.0, 0.08)})
	for i in MOTES:
		b["motes"].append({"x": _rng.randf_range(-30.0, 30.0), "y": _rng.randf_range(-6.0, 4.0), "speed": _rng.randf_range(50.0, 115.0),
			"size": _rng.randf_range(7.0, 13.0), "phase": _rng.randf() * TAU, "delay": _rng.randf_range(0.0, 0.45),
			"color": CORE if i % 3 == 0 else GREEN.lightened(0.3)})
	for i in CROSSES:
		b["crosses"].append({"x": lerpf(-26.0, 26.0, (i + _rng.randf_range(0.2, 0.8)) / CROSSES), "speed": _rng.randf_range(38.0, 64.0),
			"size": _rng.randf_range(6.0, 8.5), "delay": 0.08 + i * 0.1 + _rng.randf_range(0.0, 0.06)})
	_blooms.append(b)
	_reach(at + LEAF_LIFE + 0.5)


## The player of `view` gained shield at replay time at.
func shield(view: Node2D, at: float) -> void:
	var sparks := []
	for i in SHIELD_SPARKS:
		sparks.append({"off": Vector2(_rng.randf_range(-78.0, 78.0), _rng.randf_range(-22.0, 22.0)), "size": _rng.randf_range(5.0, 9.0),
			"delay": _rng.randf_range(0.0, 0.35)})
	_shields.append({"view": view, "at": at, "sparks": sparks})
	_reach(at + SHIELD_LIFE)


## The bad effects of the player of `view` were cleansed at replay time at.
func cleanse(view: Node2D, at: float) -> void:
	var sparks := []
	for j in CLEANSE_SPARKS:
		sparks.append({"dir": Vector2.from_angle(TAU * (j + _rng.randf_range(-0.3, 0.3)) / CLEANSE_SPARKS),
			"dist": _rng.randf_range(34.0, 52.0), "size": _rng.randf_range(4.0, 7.0)})
	_cleanses.append({"view": view, "feet": view.position, "at": at + 0.05, "sparks": sparks})
	_reach(at + 0.05 + CLEANSE_LIFE)


static func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


static func _back_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + k * k * (2.7 * k + 1.7)


## A 0..1 envelope: up over fade_in from 0, down over fade_out before life.
static func _env(a: float, life: float, fade_in: float, fade_out: float) -> float:
	if a < 0.0 or a > life:
		return 0.0
	return minf(1.0, a / maxf(fade_in, 1e-4)) * minf(1.0, (life - a) / maxf(fade_out, 1e-4))


func _feet(entry: Dictionary) -> Vector2:
	var view = entry["view"]
	return view.position if is_instance_valid(view) else entry.get("feet", Vector2.ZERO)


func _shape(shape: PackedVector2Array, at: Vector2, rot: float, size: Vector2, color: Color) -> void:
	draw_set_transform(at, rot, size)
	draw_colored_polygon(shape, color)


func _draw() -> void:
	for s in _shafts:
		_draw_shaft(s)
	for b in _blooms:
		_draw_bloom(b)
	for s in _shields:
		_draw_shield(s)
	for c in _cleanses:
		_draw_cleanse(c)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_glow() -> void:
	for e in _exits:
		var a := t - float(e["at"])
		var k := _env(a, EXIT_LIFE, 0.05, 0.4)
		if k > 0.0:
			_glow_at(_glow, e["pos"], 70.0 + 120.0 * a, Color(GREEN, 0.9 * k))
	for s in _shafts:
		var a := t - float(s["from"])
		var k := _shaft_alpha(s)
		if k <= 0.0:
			continue
		var feet := _feet(s)
		_vertical(_glow, feet.x, 0.0, feet.y - GameData.shot_origin_lift(), 7.0, Color(GREEN, 0.0), Color(GREEN, 0.45 * k))
		_glow_at(_glow, feet + Vector2(0, -6), 46.0 + 6.0 * sin(a * 12.0), Color(GREEN, 0.35 * k))
	for b in _blooms:
		var a := t - float(b["at"])
		var feet := _feet(b)
		var body := feet + Vector2(0, -GameData.shot_origin_lift())
		var k := _env(a, FLASH_LIFE, 0.03, FLASH_LIFE - 0.05)
		if k > 0.0:
			_glow_at(_glow, body, 60.0 + 110.0 * _ease_out(a / FLASH_LIFE), Color(0.35, 0.8, 0.3, 0.6 * k))
		# The healing glow rising from the feet
		k = _env(a, 1.0, 0.1, 0.6)
		if k > 0.0:
			var top := feet.y - 40.0 - 110.0 * _ease_out(a)
			_vertical(_glow, feet.x, top, feet.y, 30.0, Color(GREEN, 0.0), Color(GREEN, 0.4 * k))
		for m in b["motes"]:
			var ma := a - float(m["delay"])
			var mk := _env(ma, MOTE_LIFE, 0.1, 0.6)
			if mk <= 0.0:
				continue
			var p: Vector2 = feet + Vector2(m["x"] + 5.0 * sin(ma * 5.0 + m["phase"]), m["y"] - m["speed"] * ma)
			var size: float = m["size"] * (0.7 + 0.3 * sin(ma * 14.0 + m["phase"]))
			if _sparkle_tex != null:
				_glow.draw_texture_rect(_sparkle_tex, Rect2(p - Vector2(size, size) / 2.0, Vector2(size, size)), false, Color(m["color"], mk))
			else:
				_glow.draw_circle(p, size * 0.3, Color(m["color"], mk))
	for s in _shields:
		var a := t - float(s["at"])
		var k := _env(a, 0.5, 0.04, 0.4)
		if k > 0.0:
			_glow_at(_glow, _feet(s) + Vector2(0, -30), 130.0, Color(SHIELD, 0.22 * k))
	_glow.draw_set_transform_matrix(Transform2D.IDENTITY)


func _glow_at(ci: CanvasItem, c: Vector2, size: float, color: Color) -> void:
	if _glow_tex != null:
		ci.draw_texture_rect(_glow_tex, Rect2(c - Vector2(size, size) / 2.0, Vector2(size, size)), false, color)
	else:
		ci.draw_circle(c, size * 0.3, color)


## A vertical band at x from top to bottom, half width w, colour top_col fading to bottom_col.
func _vertical(ci: CanvasItem, x: float, top: float, bottom: float, w: float, top_col: Color, bottom_col: Color) -> void:
	_quad[0] = Vector2(x - w, top)
	_quad[1] = Vector2(x + w, top)
	_quad[2] = Vector2(x + w * 0.7, bottom)
	_quad[3] = Vector2(x - w * 0.7, bottom)
	_quad_cols[0] = top_col
	_quad_cols[1] = top_col
	_quad_cols[2] = bottom_col
	_quad_cols[3] = bottom_col
	ci.draw_polygon(_quad, _quad_cols)


func _shaft_alpha(s: Dictionary) -> float:
	var a := t - float(s["from"])
	var land := float(s["land"]) - float(s["from"])
	if a < 0.0 or a > land + SHAFT_OUT:
		return 0.0
	return minf(1.0, a / SHAFT_IN) * (1.0 if a <= land else 1.0 - (a - land) / SHAFT_OUT)


func _draw_shaft(s: Dictionary) -> void:
	var k := _shaft_alpha(s)
	if k <= 0.0:
		return
	var a := t - float(s["from"])
	var feet := _feet(s)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_vertical(self, feet.x, 0.0, feet.y - GameData.shot_origin_lift(), 34.0, Color(LIGHT, 0.0), Color(LIGHT, 0.22 * k))
	_vertical(self, feet.x, 0.0, feet.y - GameData.shot_origin_lift(), 16.0, Color(PETAL_IN, 0.0), Color(PETAL_IN, 0.28 * k))
	# The target ring at the feet, pulsing in
	var r := 30.0 - 8.0 * fposmod(a * 1.6, 1.0)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.36))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(GREEN, 0.9 * k), 3.0, true)
	draw_arc(Vector2.ZERO, r + 9.0, 0.0, TAU, 32, Color(PETAL_IN, 0.4 * k), 2.0, true)


func _draw_bloom(b: Dictionary) -> void:
	var a := t - float(b["at"])
	if a < 0.0:
		return
	var feet := _feet(b)
	var body := feet + Vector2(0, -GameData.shot_origin_lift())
	# The ring rolling out on the ground
	var rk := _env(a, 0.65, 0.02, 0.5)
	if rk > 0.0:
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.36))
		draw_arc(Vector2.ZERO, 14.0 + 80.0 * _ease_out(a / 0.65), 0.0, TAU, 40, Color(LIGHT, 0.85 * rk), 4.0, true)
	# The flower opening on the ground round the feet: outer petals, inner white petals, a core
	var fk := _env(a, FLOWER_LIFE, 0.02, 0.45)
	if fk > 0.0:
		var open := _back_out(a / 0.32)
		var spin := float(b["spin"]) * a
		var ground := Transform2D(0.0, Vector2(1.0, 0.42), 0.0, feet + Vector2(0, -2))
		for i in PETALS:
			var ang := TAU * i / PETALS + spin
			draw_set_transform_matrix(ground * Transform2D(ang, Vector2(50.0, 26.0) * open, 0.0, Vector2.ZERO))
			draw_colored_polygon(_petal, Color(PETAL_RIM, 0.9 * fk))
			draw_set_transform_matrix(ground * Transform2D(ang, Vector2(46.0, 21.0) * open, 0.0, Vector2(2.0, 0.0)))
			draw_colored_polygon(_petal, Color(PETAL_OUT, fk))
		for i in PETALS:
			var ang := TAU * (i + 0.5) / PETALS - spin * 0.6
			draw_set_transform_matrix(ground * Transform2D(ang, Vector2(31.0, 15.0) * open, 0.0, Vector2.ZERO))
			draw_colored_polygon(_petal, Color(PETAL_IN, fk))
		draw_set_transform_matrix(ground)
		draw_circle(Vector2.ZERO, 9.0 * open, Color(CORE, fk))
	# Leaves bursting out of the body and drifting down, swaying
	for l in b["leaves"]:
		var la := a - float(l["delay"])
		var lk := _env(la, LEAF_LIFE, 0.04, 0.5)
		if lk <= 0.0:
			continue
		var drag := (1.0 - exp(-3.2 * la)) / 3.2
		var v: Vector2 = l["v"]
		var p := body + v * drag + Vector2(9.0 * sin(la * 4.0 + l["sway"]) * minf(la * 2.0, 1.0), 34.0 * la * la)
		var size: float = l["size"]
		var rot := float(l["rot"]) + float(l["spin"]) * la
		_shape(_petal, p - Vector2.from_angle(rot) * 1.0, rot, Vector2(size * 1.9 + 2.0, size + 2.0), Color(PETAL_RIM, 0.8 * lk))
		_shape(_petal, p, rot, Vector2(size * 1.9, size), Color(l["color"], lk))
	# Little green crosses rising over the head
	for c in b["crosses"]:
		var ca := a - float(c["delay"])
		var ck := _env(ca, CROSS_LIFE, 0.12, 0.5)
		if ck <= 0.0:
			continue
		var p := feet + Vector2(c["x"], -44.0 - float(c["speed"]) * ca)
		var size: float = c["size"] * (0.6 + 0.4 * _back_out(ca / 0.2))
		_shape(_cross, p, 0.0, Vector2(size + 2.0, size + 2.0), Color(GREEN_DEEP, 0.9 * ck))
		_shape(_cross, p, 0.0, Vector2(size, size), Color(0.62, 1.0, 0.55, ck))


func _draw_shield(s: Dictionary) -> void:
	var a := t - float(s["at"])
	if a < 0.0 or a > SHIELD_LIFE:
		return
	var feet := _feet(s)
	# (the bubble itself is the player's: PlayerView's shield ball pops in with the shield)
	# Sparkles round the "+N khiên" number as it rises
	var up := POPUP_Y - 60.0 * _ease_out(minf(a / 0.9, 1.0))
	for sp in s["sparks"]:
		var sa := a - float(sp["delay"])
		var sk := _env(sa, 0.6, 0.08, 0.35)
		if sk <= 0.0:
			continue
		var size: float = sp["size"] * (0.75 + 0.25 * sin(sa * 20.0))
		_shape(_star, feet + Vector2(0, up) + sp["off"], sa * 2.0, Vector2(size, size), Color(1, 1, 1, sk))


func _draw_cleanse(c: Dictionary) -> void:
	var a := t - float(c["at"])
	if a < 0.0 or a > CLEANSE_LIFE:
		return
	var k := a / CLEANSE_LIFE
	var at := _feet(c) + Vector2(0, -30)
	draw_set_transform(at, 0.0, Vector2.ONE)
	draw_arc(Vector2.ZERO, 20.0 + 34.0 * _ease_out(k), 0.0, TAU, 32, Color(1, 1, 1, 0.75 * (1.0 - k)), 3.0, true)
	for sp in c["sparks"]:
		var d: Vector2 = sp["dir"] * float(sp["dist"]) * _ease_out(k * 1.25)
		var size: float = sp["size"] * (1.0 - k * 0.5)
		_shape(_star, at + d, k * 3.0, Vector2(size, size), Color(1.0, 1.0, 0.82, 1.0 - k * k))
