extends Node2D
## A unit's status effects drawn on its body (PlayerView makes two: the front one, over the figure
## and under the HP bar, holds the StatusLook; its `back` twin sits under the figure, over the team
## ring). Origin at the feet; `height` px is the figure's height over them, `width` its body's
## width (PlayerView: a player's art, a boss / minion's bodySize × its art's width), so everything
## scales with the body. The looks (StatusLook): the body frozen inside a cluster of faceted
## crystals grown from the ground at its feet (a tall see-through core over it, smaller shards
## fanned round its base behind and in front, each facet shaded with a violet-to-white gradient,
## white lit edges, a light sweeping up them, a cool glow, sparkles, frost; they grow in one after
## another and crack and shatter popping out), flames licking up it with embers, a web wrapped
## over it, earth and stone heaped round the feet (root: a mound rising with stones in it and
## shards jutting up, the ground cracked round it; crumbling into pebbles popping out; the vines
## wound round the feet stay drawn: no effect maps to them, Mộc Tinh's vine lash bursts them, draw_vines()), stars circling the
## head (the far ones behind it) and a soft aura behind the body with a few motes rising. Each
## pops in and out (StatusLook.pop_scale / pop_alpha; the vines and the crystals grow up from the
## ground instead). All computed from the time in _draw(); off (nothing to draw) it neither
## processes nor draws.

const StatusLook := preload("res://match/views/status_look.gd")

const REF_H := 53.0 # a player's figure height: the looks are sized for it × height / REF_H
const FROST := Color(0.95, 0.99, 1.0)
## The freeze's crystals round the core(s), as [x, tilt, length, half width, tip, front, delay]: x
## of the core's half width from the middle of the feet, tilt in radians from upright (+ leans
## right), length and half width of the figure's height, tip: where the point sits across it (-1
## its left edge .. 1 its right), front: in front of the body (else behind it), delay: when it
## starts growing in the pop in (0..1 of it).
const CLUSTER := [
	[-0.72, -0.5, 0.7, 0.15, 0.3, false, 0.0],
	[0.66, 0.4, 0.8, 0.16, -0.25, false, 0.22],
	[-0.9, -0.98, 0.4, 0.1, 0.35, true, 0.34],
	[0.88, 0.92, 0.46, 0.11, -0.3, true, 0.44],
	[0.36, 0.22, 0.28, 0.085, 0.15, true, 0.5],
]
const CORE_LEN := 1.1 # the core's length, of the figure's height (its point just over the head)
const CORE_FACE := 0.46 # the core's facets' alpha: the body shows through it
const SIDE_FACE := 0.82
const TWO_CORES := 1.05 # a body wider than this × its height gets two cores side by side
const GROW_SPAN := 0.5 # of the pop in, each crystal's own growth (from its delay)
const SHEEN_SPEED := 0.3 # sweeps per s (each crystal its own phase)
const SHEEN_EVERY := 1.8 # a sweep runs 1 / SHEEN_EVERY of the cycle, the rest clear
const CRACK_END := 0.32 # of the pop out: the cracks have spread, the crystals burst
const BURST_END := 0.46 # of the pop out: the crystals are gone, only their fragments fall
const FRAG_FALL := 520.0 # px/s² (× the scale) the fragments fall with
## A crystal's colour from its base to its point: soft violet, ice blue by the shoulders (at
## ICE_MID_AT), white-cyan at the point.
const ICE_BASE := Color(0.57, 0.43, 0.93)
const ICE_MID := Color(0.34, 0.64, 1.0)
const ICE_TIP := Color(0.9, 0.99, 1.0)
const ICE_MID_AT := 0.6
const ICE_INK := Color(0.13, 0.16, 0.46)
const ICE_GLOW := Color(0.5, 0.8, 1.0)
## A crystal's facets (corner ids, _shard_verts()) left to right, the tip's last, and their shade
## (lit from the upper left: > 0 lightened, < 0 darkened).
const FACETS := [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [4, 5, 8], [5, 6, 8], [6, 7, 8]]
const FACET_SHADE := [0.26, -0.04, -0.34, 0.58, 0.2, -0.14]
const FACET_ALPHA := [1.0, 0.8, 1.3, 1.15, 0.95, 1.2] # × the crystal's: the far face denser
const FLAME := Color(1.0, 0.42, 0.08)
const FLAME_CORE := Color(1.0, 0.86, 0.32)
const WEB := Color(0.95, 0.95, 1.0)
const VINE := Color(0.34, 0.62, 0.2)
const VINE_BACK := Color(0.2, 0.38, 0.12)
const VINE_OUT := Color(0.08, 0.16, 0.05)
const LEAF := Color(0.48, 0.82, 0.3)
const SOIL := Color(0.36, 0.25, 0.14)
const STAR := Color(1.0, 0.9, 0.3)
const STAR_OUT := Color(0.42, 0.24, 0.04)

var height := 53.0
var width := 30.0
var look := StatusLook.new()
var back: Node2D # the twin under the figure (draws through draw_back())

var _t := 0.0
var _cl: Array = [] # the freeze's crystals for this body size (_ice_cluster())
var _cl_key := Vector2.ZERO
var _v := PackedVector2Array() # a crystal's corners in its own frame (_shard_verts())
var _vf := PackedFloat32Array() # their place along it
static var _halo: GradientTexture2D
static var _facet_tris := PackedInt32Array()
static var _sheen_tris := PackedInt32Array()


func _init() -> void:
	visible = false
	set_process(false)


## The twin under the figure: a plain node that calls back into draw_back().
func make_back() -> Node2D:
	back = Node2D.new()
	back.visible = false
	back.draw.connect(func() -> void: draw_back(back))
	return back


## Takes the unit's statusEffects.
func set_effects(effects: Variant) -> void:
	look.set_effects(effects)
	_wake()


## Every look pops out (death).
func clear() -> void:
	look.clear()
	_wake()


## Everything hidden at once (a bomber blown up).
func vanish() -> void:
	look = StatusLook.new()
	_wake()


## The looks drawn now (tests).
func looks() -> Array:
	return look.looks()


func _wake() -> void:
	var on := not look.is_empty()
	visible = on
	if back != null:
		back.visible = on
	set_process(on)
	queue_redraw()
	if back != null:
		back.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	look.step(delta)
	if look.is_empty():
		_wake()
		return
	queue_redraw()
	if back != null:
		back.queue_redraw()


func _s() -> float:
	return maxf(height / REF_H, 0.3)


func _draw() -> void:
	for l in look.layers():
		match str(l["look"]):
			"vines": _vines(self, l, true)
			"stone": _stone(self, l, true)
			"poison": _poison(self, l, true)
			"flames": _flames(l)
			"web": _web(l)
			"ice": _ice(self, l, true)
			"stars": _stars(self, l, true)
			"aura": _motes(l)


## The far parts: the aura's glow, the vines behind the legs, the ice's glow, ground frost and the
## crystals behind the body, the stars behind the head.
func draw_back(ci: CanvasItem) -> void:
	for l in look.layers():
		match str(l["look"]):
			"aura": _aura(ci, l)
			"vines": _vines(ci, l, false)
			"stone": _stone(ci, l, false)
			"poison": _poison(ci, l, false)
			"ice": _ice(ci, l, false)
			"stars": _stars(ci, l, false)


# ── Ice (freeze) ────────────────────────────────────────────────────────────

## The freeze. Front: the core crystal(s) over the body, the shards in front of it, frost heaped
## at the feet, sparkles drifting up and, popping out, the cracks and the falling fragments.
## Back: the cool glow, the frost on the ground, the shards behind the body. Popping in, each
## crystal grows up from its base after the one before (CLUSTER delays), overshooting a little;
## popping out (StatusLook.pop_out_sec()), cracks spread over the core as the crystals brighten
## (to CRACK_END), they burst (to BURST_END) and their fragments fall and fade.
func _ice(ci: CanvasItem, l: Dictionary, front: bool) -> void:
	var s := _s()
	var k: float = l["k"]
	var out: bool = l["popping_out"]
	var f := 1.0 - k if out else 0.0
	var crack := clampf(f / CRACK_END, 0.0, 1.0) if out else 0.0
	var gone := clampf((f - CRACK_END) / (BURST_END - CRACK_END), 0.0, 1.0) if out else 0.0
	var a := 1.0 - gone if out else minf(1.0, k * 2.5)
	var spread := 1.0 if out else minf(1.0, k * 1.8)
	var w0 := _core_hw()
	if not front:
		var pulse := 0.5 + 0.5 * sin(_t * 1.6)
		var size := Vector2(w0 * 2.0 + 46.0 * s, height * 1.45 + 24.0 * s) * lerpf(0.6, 1.0, spread)
		ci.draw_set_transform(Vector2(0, -height * 0.52), 0.0, size / 64.0)
		ci.draw_texture_rect(_halo_tex(), Rect2(-32, -32, 64, 64), false, Color(ICE_GLOW, (0.3 + 0.08 * pulse + 0.3 * crack) * a))
		var rx := (w0 * 1.45 + 6.0 * s) * spread # the frost on the ground: a thin patch, however wide
		ci.draw_set_transform(Vector2(0, 1.0 * s), 0.0, Vector2(1.0, 6.0 * s / maxf(rx, 1.0)))
		ci.draw_circle(Vector2.ZERO, rx, Color(ICE_MID.lightened(0.35), 0.3 * a))
		ci.draw_circle(Vector2.ZERO, rx * 0.8, Color(FROST, 0.45 * a))
		ci.draw_set_transform(Vector2.ZERO)
	for c in _ice_cluster():
		if bool(c["front"]) != front:
			continue
		var g := 1.0 + 0.04 * crack - 0.1 * gone
		var ca := 1.0 - gone
		if not out:
			var u := clampf((k - float(c["delay"])) / GROW_SPAN, 0.0, 1.0)
			g = _grow(u)
			ca = minf(1.0, u * 3.0)
		if ca <= 0.01 or g <= 0.01:
			continue
		var shine := fmod(_t * SHEEN_SPEED + float(c["seed"]) * 0.23, 1.0) * SHEEN_EVERY
		_shard(ci, c, g, ca, crack * 0.45, shine)
	if not front:
		return
	_frost_drift(ci, w0 * 1.18 * spread, s, a)
	var m := clampi(roundi(w0 * 2.0 / (7.0 * s)), 5, 12)
	for j in m:
		var ph := fmod(_t * 0.16 + _hash(j * 2.3 + 0.7), 1.0)
		var side := -1.0 if j % 2 == 0 else 1.0
		var p := Vector2(side * lerpf(0.3, 1.4, _hash(j * 4.1)) * w0 + sin(_t * 0.9 + j) * 3.0 * s, -height * (0.06 + 1.12 * ph))
		var blink := pow(maxf(0.0, sin(_t * 2.2 + j * 1.9)), 3.0)
		var fade := sin(ph * PI) * a * spread
		if j % 3 == 0:
			_spark(ci, p, (2.2 + 3.6 * blink) * s, Color(1, 1, 1, fade * (0.3 + 0.7 * blink)))
		else:
			ci.draw_circle(p, (0.7 + 0.6 * blink) * s, Color(0.86, 0.95, 1.0, fade * (0.4 + 0.6 * blink)))
	if crack > 0.0 and gone < 1.0:
		for c in _ice_cluster():
			if bool(c["core"]):
				_cracks(ci, c, crack, 1.0 - gone)
	if f > CRACK_END:
		_fragments(ci, (f - CRACK_END) * StatusLook.pop_out_sec("ice"), 1.0 - (f - CRACK_END) / (1.0 - CRACK_END))


## The frost heaped along the crystals' bases, `half` px each side of the feet: a low lumpy
## drift, white on top fading to ice blue at the ground.
func _frost_drift(ci: CanvasItem, half: float, s: float, a: float) -> void:
	if half <= 1.0:
		return
	var n := 28
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var top := Color(FROST, 0.92 * a)
	var waves := half / (7.0 * s) # lumps about 14 px (× the scale) apart
	for i in n + 1:
		var u := i / float(n) * 2.0 - 1.0
		var bump := 0.55 + 0.3 * sin(u * waves * PI + 1.3) + 0.15 * sin(u * waves * 2.3 * PI + 0.4)
		var env := sqrt(maxf(0.0, 1.0 - u * u))
		pts.append(Vector2(u * half, 2.5 * s - (0.6 + 5.0 * bump * env) * s))
		cols.append(top)
	pts.append(Vector2(half * 0.96, 4.2 * s))
	pts.append(Vector2(-half * 0.96, 4.2 * s))
	cols.append(Color(ICE_MID.lightened(0.3), 0.75 * a))
	cols.append(Color(ICE_MID.lightened(0.3), 0.75 * a))
	ci.draw_polygon(pts, cols)


## The core's half width: the body's half width and a margin.
func _core_hw() -> float:
	return width * 0.5 + 6.0 * _s()


## The frozen cluster for this body (cached per size), drawing order: the shards behind the body,
## the core(s), the shards in front: [{x, tilt, len, hw, tip, front, delay, face, seed, core}].
func _ice_cluster() -> Array:
	var key := Vector2(width, height)
	if key == _cl_key and not _cl.is_empty():
		return _cl
	_cl_key = key
	var w0 := _core_hw()
	var back: Array = []
	var fore: Array = []
	for i in CLUSTER.size():
		var d: Array = CLUSTER[i]
		var c := {"x": float(d[0]) * w0, "tilt": d[1], "len": float(d[2]) * height, "hw": float(d[3]) * height, "tip": d[4],
			"front": d[5], "delay": d[6], "face": SIDE_FACE, "seed": i + 1.0, "core": false}
		(fore if bool(d[5]) else back).append(c)
	var cores: Array = []
	if width > height * TWO_CORES: # a wide body: two crystals side by side, not one squat block
		cores.append({"x": -0.42 * w0, "tilt": -0.08, "len": height * (CORE_LEN - 0.14), "hw": w0 * 0.6, "tip": 0.3})
		cores.append({"x": 0.4 * w0, "tilt": 0.1, "len": height * CORE_LEN, "hw": w0 * 0.64, "tip": -0.2})
	else:
		cores.append({"x": 0.0, "tilt": -0.05, "len": height * CORE_LEN, "hw": w0, "tip": 0.24})
	for i in cores.size():
		cores[i].merge({"front": true, "delay": 0.08 + 0.06 * i, "face": CORE_FACE, "seed": 11.0 + i, "core": true})
	_cl = back + cores + fore
	return _cl


## Where a crystal stands: on the ground at its x, a leaning one raised so its low corner only
## just sinks into the ground.
func _shard_base(c: Dictionary) -> Vector2:
	return Vector2(float(c["x"]), 2.0 * _s() - absf(sin(float(c["tilt"]))) * float(c["hw"]) * 0.7)


## The pop in's growth of a crystal 0..1 through its own part: eased out with an overshoot.
static func _grow(u: float) -> float:
	if u <= 0.0:
		return 0.0
	var c1 := 1.8
	return 1.0 + (c1 + 1.0) * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)


## A crystal's corners in its own frame (x across, y along from the base) into _v: 0-3 the base
## (left edge, ridge, far ridge, right edge), 4 the left shoulder, 5 the ridge's top, 6 the far
## ridge's top, 7 the right shoulder, 8 the point; _vf their place along it (0..1).
func _shard_verts(hw: float, ln: float, tip: float, seed: float) -> void:
	var tsl := (0.6 + 0.12 * _hash(seed * 1.3)) * ln
	var tsr := (0.5 + 0.12 * _hash(seed * 2.1)) * ln
	var tr := maxf(tsl, tsr) + 0.08 * ln
	var ta := tip * hw * 0.6
	var ra := lerpf(-0.16 * hw, ta, 0.3)
	var r2 := lerpf(0.55 * hw, ta, 0.2)
	_v.resize(9)
	_vf.resize(9)
	var corners := [Vector2(-hw, 0), Vector2(-0.16 * hw, 0), Vector2(0.55 * hw, 0), Vector2(hw, 0), Vector2(-hw, tsl),
		Vector2(ra, tr), Vector2(r2, (tsr + tr) * 0.5), Vector2(hw, tsr), Vector2(ta, ln)]
	for i in 9:
		_v[i] = corners[i]
		_vf[i] = corners[i].y / ln


## One crystal: a pointed prism standing on the ground at c.x, leaning c.tilt, grown g (from its
## base), alpha a, its facets shaded from the light on the upper left with the base-to-point
## gradient (ICE_BASE, ICE_MID, ICE_TIP) per vertex, white highlights on the lit edges over a dark
## ink outline, an inner glint, a light sweep up it (shine 0..1; past 1 none), flash: brightened.
func _shard(ci: CanvasItem, c: Dictionary, g: float, a: float, flash: float, shine: float) -> void:
	var s := _s()
	var ln: float = c["len"]
	var hw: float = c["hw"]
	var tilt: float = c["tilt"]
	var up := Vector2(sin(tilt), -cos(tilt))
	var rt := Vector2(-up.y, up.x)
	var base := _shard_base(c)
	var face: float = c["face"]
	_shard_verts(hw, ln, float(c["tip"]), float(c["seed"]))
	var pts := PackedVector2Array()
	pts.resize(9)
	for i in 9:
		pts[i] = base + (rt * _v[i].x + up * _v[i].y) * g
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	for j in FACETS.size():
		for vid in FACETS[j]:
			var fv: float = _vf[vid]
			tp.append(pts[vid])
			tc.append(Color(_ice_col(fv, FACET_SHADE[j], flash), clampf(face * FACET_ALPHA[j] * a * (1.12 - 0.3 * fv), 0.0, 1.0)))
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _facet_idx(), tp, tc)
	if shine < 1.0:
		_sheen(ci, base, up, rt, g, ln, hw, shine, a)
	var lw := maxf(1.0, 1.15 * s) * minf(1.0, g)
	var ink := Color(ICE_INK, 0.55 * a)
	for e in [[0, 4], [4, 8], [8, 7], [7, 3]]:
		ci.draw_line(pts[e[0]], pts[e[1]], ink, lw * 2.0, true)
	ci.draw_line(pts[2], pts[6], Color(ICE_INK, 0.2 * a), lw * 0.8, true)
	ci.draw_line(pts[0], pts[4], Color(1, 1, 1, 0.4 * a), lw, true)
	ci.draw_line(pts[4], pts[8], Color(1, 1, 1, 0.92 * a), lw, true)
	ci.draw_line(pts[5], pts[8], Color(1, 1, 1, 0.75 * a), lw * 0.9, true)
	ci.draw_line(pts[4], pts[5], Color(1, 1, 1, 0.55 * a), lw * 0.8, true)
	ci.draw_line(pts[1], pts[5], Color(1, 1, 1, 0.25 * a), lw * 0.8, true)
	ci.draw_line(pts[6], pts[8], Color(1, 1, 1, 0.3 * a), lw * 0.7, true)
	# two inner facet seams down the faces
	var seam_l := base + (rt * (-hw) + up * (0.28 * _v[4].y)) * g
	var seam_r := base + (rt * lerpf(_v[2].x, hw, 0.5) + up * (0.0)) * g
	ci.draw_line(pts[5], seam_l, Color(1, 1, 1, 0.22 * a), lw * 0.7, true)
	ci.draw_line(pts[6], seam_r, Color(ICE_INK, 0.16 * a), lw * 0.7, true)
	# the inner glint: a short streak on the lit face, and a twinkle on the point now and then
	var tsl: float = _v[4].y
	var g0 := base + (rt * (-0.7 * hw) + up * (0.34 * tsl)) * g
	var g1 := base + (rt * (-0.48 * hw) + up * (0.72 * tsl)) * g
	ci.draw_line(g0, g1, Color(1, 1, 1, 0.5 * a), maxf(1.0, minf(hw * 0.16, 2.2 * s)), true)
	ci.draw_circle(g1 + (g1 - g0) * 0.25, maxf(0.8, 0.9 * s), Color(1, 1, 1, 0.6 * a))
	var blink := pow(maxf(0.0, sin(_t * 1.3 + float(c["seed"]) * 2.7)), 6.0)
	if blink > 0.02:
		var at := base + (rt * lerpf(-hw, _v[8].x, 0.62) + up * lerpf(tsl, ln, 0.62)) * g
		_spark(ci, at, (2.5 + 4.5 * blink) * s * minf(1.0, hw / (8.0 * s)), Color(1, 1, 1, blink * a))


## The light sweeping up a crystal: a soft slanted band (bright in the middle, clear at its
## edges) clipped to its outline, at shine 0..1 of the way from below the base to past the point.
func _sheen(ci: CanvasItem, base: Vector2, up: Vector2, rt: Vector2, g: float, ln: float, hw: float, shine: float, a: float) -> void:
	var mid := lerpf(-0.15, 1.1, shine) * ln
	var bh := 0.1 * ln
	var slant := 0.3 * hw
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var bright := Color(1, 1, 1, 0.3 * a)
	var clear := Color(1, 1, 1, 0.0)
	for side in [-1.0, 1.0]:
		for lev in [-1.0, 0.0, 1.0]:
			var t := clampf(mid + bh * lev - side * slant, 0.0, ln)
			tp.append(base + (rt * _edge_at(t, side, hw, ln) + up * t) * g)
			tc.append(bright if lev == 0.0 else clear)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _sheen_idx(), tp, tc)


## Across a crystal at t along it, on its left (side -1) or right (1) edge (from _v).
func _edge_at(t: float, side: float, hw: float, ln: float) -> float:
	var sh: float = _v[4].y if side < 0.0 else _v[7].y
	if t <= sh:
		return side * hw
	return lerpf(side * hw, _v[8].x, (t - sh) / maxf(ln - sh, 0.001))


## The pop out's cracks spreading over a core crystal from a point on its upper middle: white
## zig-zags with a dark seam, reaching further as crack goes 0..1.
func _cracks(ci: CanvasItem, c: Dictionary, crack: float, a: float) -> void:
	var s := _s()
	var ln: float = c["len"]
	var hw: float = c["hw"]
	var tilt: float = c["tilt"]
	var up := Vector2(sin(tilt), -cos(tilt))
	var rt := Vector2(-up.y, up.x)
	var base := _shard_base(c)
	var seed: float = c["seed"]
	var o := Vector2(0.12 * hw, 0.5 * ln)
	var reach := crack * 3.0 # segments drawn per branch
	var lw := maxf(1.0, 1.1 * s)
	for b in 6:
		var ang := TAU * b / 6.0 + (_hash(seed * 3.0 + b) - 0.5) * 0.8
		var p := o
		for j in 3:
			if reach <= j:
				break
			var part := minf(1.0, reach - j)
			var turn := ang + (_hash(seed * 5.0 + b * 3.0 + j) - 0.5) * 1.1
			var step := Vector2(cos(turn) * hw * 0.3, sin(turn) * ln * 0.12) * (1.0 - 0.2 * j) * part
			var q := Vector2(clampf(p.x + step.x, -hw * 0.92, hw * 0.92), clampf(p.y + step.y, 0.06 * ln, 0.93 * ln))
			var w0 := base + rt * p.x + up * p.y
			var w1 := base + rt * q.x + up * q.y
			ci.draw_line(w0 + Vector2(0.6, 0.8) * s, w1 + Vector2(0.6, 0.8) * s, Color(ICE_INK, 0.5 * a), lw, true)
			ci.draw_line(w0, w1, Color(1, 1, 1, 0.95 * a), lw * (1.0 - 0.25 * j), true)
			p = q


## The fragments the crystals shed when they burst, tau s after: small facets thrown out from
## where they were on each crystal, spinning and falling, fading (a 1..0).
func _fragments(ci: CanvasItem, tau: float, a: float) -> void:
	var s := _s()
	var centre := Vector2(0, -height * 0.45)
	var tp := PackedVector2Array()
	var tc := PackedColorArray()
	var idx := PackedInt32Array()
	var fade := pow(clampf(a, 0.0, 1.0), 0.7)
	for c in _ice_cluster():
		var ln: float = c["len"]
		var hw: float = c["hw"]
		var tilt: float = c["tilt"]
		var up := Vector2(sin(tilt), -cos(tilt))
		var rt := Vector2(-up.y, up.x)
		var base := _shard_base(c)
		var seed: float = c["seed"]
		var count := 5 if bool(c["core"]) else 2
		for j in count:
			var h := seed * 7.3 + j * 1.9
			var along := lerpf(0.12, 0.92, _hash(h + 0.2))
			var p0 := base + rt * lerpf(-0.75, 0.75, _hash(h + 0.1)) * hw + up * along * ln
			var v0 := (p0 - centre).normalized() * lerpf(35.0, 85.0, _hash(h + 0.3)) * s + Vector2(0, -lerpf(30.0, 80.0, _hash(h + 0.4)) * s)
			var p := p0 + v0 * tau + Vector2(0, 0.5 * FRAG_FALL * s * tau * tau)
			var r := lerpf(0.55, 1.0, _hash(h + 0.5)) * clampf(hw * 0.42, 2.6 * s, 7.0 * s)
			var rot := _hash(h + 0.6) * TAU + tau * (_hash(h + 0.7) - 0.5) * 16.0
			var col := _ice_col(along, 0.25, 0.0)
			var o := tp.size()
			tp.append(p + Vector2.from_angle(rot) * r)
			tp.append(p + Vector2.from_angle(rot + 2.3) * r * 0.75)
			tp.append(p + Vector2.from_angle(rot + 4.1) * r * 0.6)
			tc.append(Color(col.lightened(0.7), fade))
			tc.append(Color(col, fade * 0.9))
			tc.append(Color(col.darkened(0.2), fade * 0.9))
			idx.append_array([o, o + 1, o + 2])
	if not idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, tp, tc)


## The crystal colour at f along it (0 base .. 1 point), lightened (shade > 0) or darkened
## (< 0) for its facet, and brightened by flash.
static func _ice_col(f: float, shade: float, flash: float) -> Color:
	var c := ICE_BASE.lerp(ICE_MID, f / ICE_MID_AT) if f < ICE_MID_AT else ICE_MID.lerp(ICE_TIP, (f - ICE_MID_AT) / (1.0 - ICE_MID_AT))
	c = c.lightened(shade) if shade > 0.0 else c.darkened(-shade)
	return c.lightened(flash) if flash > 0.0 else c


## The facets as triangles over their own vertices (each facet its own shade).
static func _facet_idx() -> PackedInt32Array:
	if _facet_tris.is_empty():
		var o := 0
		for fc in FACETS:
			_facet_tris.append_array([o, o + 1, o + 2])
			if fc.size() == 4:
				_facet_tris.append_array([o, o + 2, o + 3])
			o += fc.size()
	return _facet_tris


## The sheen's two bands: left edge 0-2, right edge 3-5, bottom to top.
static func _sheen_idx() -> PackedInt32Array:
	if _sheen_tris.is_empty():
		_sheen_tris.append_array([0, 1, 4, 0, 4, 3, 1, 2, 5, 1, 5, 4])
	return _sheen_tris


## A four-point twinkle.
func _spark(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r < 0.6 or col.a <= 0.01:
		return
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(c + Vector2.from_angle(TAU * i / 8.0 - PI / 2.0) * (r if i % 2 == 0 else r * 0.2))
	ci.draw_colored_polygon(pts, col)


# ── Flames (burn) ───────────────────────────────────────────────────────────

func _flames(l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	# a warm glow over the body
	draw_set_transform(Vector2(0, -height * 0.45), 0.0, Vector2(width * 0.62, height * 0.55) * k / 32.0)
	draw_texture_rect(_halo_tex(), Rect2(-32, -32, 64, 64), false, Color(1.0, 0.45, 0.1, 0.32 * a))
	draw_set_transform(Vector2.ZERO)
	var n := clampi(roundi(width / (5.0 * s)), 5, 22)
	for i in n:
		var up := pow(_hash(i * 3.1), 1.6) # most of them low on the body
		var x := (lerpf(-0.5, 0.5, (i + 0.5) / n) + (_hash(i * 7.7) - 0.5) * 0.12) * width
		var y := -height * 0.62 * up
		var fh := (10.0 + 7.0 * _hash(i * 0.9)) * s * (1.0 - 0.4 * up) * (0.82 + 0.25 * sin(_t * 11.0 + i * 1.7))
		var sway := sin(_t * 7.0 + i * 2.3) * fh * 0.2
		_flame(Vector2(x, y) * k, fh * k, sway * k, a)
	var m := n + 4
	for j in m:
		var ph := fmod(_t * 0.85 + j * 0.287, 1.0)
		var x := lerpf(-0.5, 0.5, _hash(j * 1.31)) * width + sin(_t * 3.0 + j) * 4.0 * s
		var y := -height * (0.2 + ph * 0.95)
		var r := (1.8 + 1.1 * _hash(j * 2.7)) * s * (1.0 - ph * 0.5)
		draw_circle(Vector2(x, y) * k, r, Color(1.0, 0.5 + 0.4 * (1.0 - ph), 0.15, (1.0 - ph) * a))


## A flame tongue standing at `base` (its round bottom), `h` px tall, its tip swayed by `sway`:
## a deep red rim, the orange flame, a yellow core.
func _flame(base: Vector2, h: float, sway: float, a: float) -> void:
	var cols := [Color(0.85, 0.16, 0.04, 0.85 * a), Color(FLAME, 0.95 * a), Color(FLAME_CORE, a)]
	var sizes := [1.0, 0.78, 0.45]
	for layer in 3:
		var hh: float = h * sizes[layer]
		var r := hh / 3.2
		var c := base + Vector2(0, -r * 0.15 * layer)
		var pts := PackedVector2Array()
		for i in 14:
			var ang := TAU * i / 14.0
			var v := Vector2(sin(ang), -cos(ang))
			if v.y < 0.0:
				var up := -v.y
				v.x *= 1.0 - up * 0.85
				v.y *= 2.2
				v.x += sway / maxf(r, 0.01) * up * (1.0 - 0.2 * layer)
			pts.append(c + v * r)
		draw_colored_polygon(pts, cols[layer])


# ── Web (net) ───────────────────────────────────────────────────────────────

func _web(l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	var c := Vector2(0, -height * 0.52)
	var rx := (width * 0.5 + 6.0 * s) * k
	var ry := (height * 0.5 + 5.0 * s) * k
	var spokes := 9
	var dirs: Array[Vector2] = []
	for i in spokes:
		var ang := TAU * i / spokes + 0.25 + (_hash(i * 5.3) - 0.5) * 0.25
		dirs.append(Vector2(cos(ang) * rx, sin(ang) * ry))
	var lw := maxf(1.0, 1.3 * s)
	var shade := Color(0, 0, 0, 0.22 * a)
	var col := Color(WEB, 0.82 * a)
	var lines := PackedVector2Array()
	for d in dirs:
		lines.append(c)
		lines.append(c + d)
	for ring in [0.3, 0.58, 0.86]:
		for i in spokes:
			var p0: Vector2 = c + dirs[i] * ring
			var p1: Vector2 = c + dirs[(i + 1) % spokes] * ring
			var mid: Vector2 = (p0 + p1) * 0.5
			mid = mid.lerp(c, 0.12) # each thread sags in toward the middle
			lines.append(p0)
			lines.append(mid)
			lines.append(mid)
			lines.append(p1)
	# two threads anchored on the ground
	for side in [-1.0, 1.0]:
		lines.append(c + Vector2(side * rx * 0.62, ry * 0.75))
		lines.append(Vector2(side * rx * 0.9, 0))
	var offset := PackedVector2Array()
	for p in lines:
		offset.append(p + Vector2(0.8, 1.2) * s)
	draw_multiline(offset, shade, lw + 1.0)
	draw_multiline(lines, col, lw)
	draw_circle(c, 2.4 * s * k, Color(WEB, 0.9 * a))


# ── Stone (root) ────────────────────────────────────────────────────────────

const EARTH := Color(0.46, 0.32, 0.19)
const EARTH_LIT := Color(0.6, 0.44, 0.27)
const EARTH_DARK := Color(0.3, 0.2, 0.12)
const ROCK := Color(0.6, 0.56, 0.5)
const ROCK_LIT := Color(0.8, 0.76, 0.68)
const ROCK_DARK := Color(0.4, 0.36, 0.32)
const ROCK_INK := Color(0.13, 0.09, 0.06)
const MOUND_H := 0.34 # the mound's height over the feet, of the figure's height
## Stones set in the mound: [x of its half width (-1..1), y of the mound's height (0 the ground ..
## 1 its top), radius of the figure's height, seed].
const STONES := [[-0.62, 0.38, 0.085, 0.3], [0.1, 0.62, 0.1, 1.7], [0.7, 0.32, 0.075, 2.9], [-0.18, 0.2, 0.065, 4.1], [0.42, 0.78, 0.06, 5.3]]
## Shards jutting up out of the mound: [x of its half width, height of the figure's, lean].
const STONE_SHARDS := [[-0.88, 0.2, -0.35], [0.9, 0.24, 0.3], [-0.38, 0.12, -0.15]]
const PEBBLES := 12
const PEBBLE_FALL := 700.0 # px/s² (× the scale)


## How far the mound has risen (0..1): growing up from the ground popping in (eased out), sinking
## while it crumbles popping out.
static func stone_rise(k: float, popping_out: bool) -> float:
	if popping_out:
		return clampf(k * 1.2 - 0.2, 0.0, 1.0)
	var g := clampf(k * 1.15, 0.0, 1.0)
	return 1.0 - pow(1.0 - g, 3.0)


## The root's earth. Back: the cracked ground round the feet and the mound's back slope behind the
## legs. Front: the mound in front of the legs with stones set in it and stone shards jutting up;
## popping out the mound sinks as pebbles burst off it and fall.
func _stone(ci: CanvasItem, l: Dictionary, front: bool) -> void:
	var s := _s()
	var a: float = l["alpha"] if not l["popping_out"] else 1.0
	var leaving: bool = l["popping_out"]
	var rise := stone_rise(float(l["k"]), leaving)
	var half := width * 0.62 + 4.0 * s
	var mh := height * MOUND_H * rise
	if not front:
		# cracks across the ground round the mound, radiating out (squashed onto the ground plane)
		var crack_a := a * (1.0 if not leaving else clampf(float(l["k"]) * 1.5, 0.0, 1.0))
		for i in 7:
			var ang := lerpf(PI * 1.06, PI * 1.94, i / 6.0) + _hash(i * 3.1) * 0.2
			var dir := Vector2(cos(ang), sin(ang) * -0.3)
			var p0 := dir * half * 0.8
			var pts := PackedVector2Array([p0])
			var reach := half * (0.35 + 0.4 * _hash(i * 1.7)) * clampf(rise * 1.3, 0.0, 1.0)
			for j in 3:
				var f := (j + 1) / 3.0
				pts.append(p0 + dir * reach * f + dir.orthogonal() * (_hash(i + j * 2.3) - 0.5) * 3.0 * s)
			ci.draw_polyline(pts, Color(ROCK_INK, 0.5 * crack_a), 1.2 * s, true)
		if mh > 0.5:
			ci.draw_colored_polygon(_mound(half * 0.92, mh * 1.08, 1.3), Color(EARTH_DARK, a))
		return
	if mh > 0.5:
		var mound := _mound(half, mh, 0.0)
		ci.draw_colored_polygon(mound, Color(EARTH, a))
		ci.draw_colored_polygon(_mound(half * 0.7, mh * 0.82, 2.1, Vector2(-half * 0.16, 0)), Color(EARTH_LIT, 0.55 * a))
		var ring := mound.duplicate()
		ring.append(mound[0])
		ci.draw_polyline(ring, Color(ROCK_INK, 0.9 * a), 2.0 * s, true)
		for st in STONE_SHARDS:
			var base := Vector2(float(st[0]) * half, -mh * 0.5)
			var h := height * float(st[1]) * rise
			if h > 1.0:
				_rock_shard(ci, base, h, 4.0 * s, float(st[2]), a)
		for st in STONES:
			var c := Vector2(float(st[0]) * half * 0.85, -mh * float(st[1]))
			_rock(ci, c, height * float(st[2]) * (0.5 + 0.5 * rise), float(st[3]), a)
	if leaving: # crumbling: pebbles burst off the mound and fall
		var u := (1.0 - float(l["k"])) * StatusLook.pop_out_sec("stone") # s since it started
		for i in PEBBLES:
			var x0 := lerpf(-0.9, 0.9, _hash(i * 1.37)) * half
			var y0 := -height * MOUND_H * (0.2 + 0.7 * _hash(i * 2.11))
			var v := Vector2(x0 * 3.0 + (_hash(i * 0.7) - 0.5) * 60.0 * s, -(70.0 + 90.0 * _hash(i * 4.3)) * s)
			var p := Vector2(x0, y0) + v * u + Vector2(0, 0.5 * PEBBLE_FALL * s * u * u)
			if p.y > 2.0 * s:
				p.y = 2.0 * s # they land on the ground
			var fade := clampf(1.0 - u / StatusLook.pop_out_sec("stone"), 0.0, 1.0)
			_rock(ci, p, (2.2 + 2.0 * _hash(i * 5.9)) * s, float(i), fade)


## A lumpy mound of earth `half` wide each side and `h` tall over the feet (its seed shifts the
## bumps), its foot a little under the ground line.
func _mound(half: float, h: float, seed: float, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var t := i / float(n)
		var x := lerpf(-half, half, t)
		var bump := 1.0 + 0.16 * sin(t * 17.0 + seed) + 0.1 * sin(t * 31.0 + seed * 2.0)
		var y := -h * pow(sin(t * PI), 0.6) * bump
		pts.append(off + Vector2(x, y))
	pts.append(off + Vector2(half * 0.8, 3.0 * _s()))
	pts.append(off + Vector2(-half * 0.8, 3.0 * _s()))
	return pts


## A rounded stone at c (radius r): shaded from the upper left, an ink outline.
func _rock(ci: CanvasItem, c: Vector2, r: float, seed: float, a: float) -> void:
	if r < 0.5 or a <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 8:
		var ang := TAU * i / 8.0
		pts.append(c + Vector2(cos(ang), sin(ang) * 0.78) * r * (0.85 + 0.25 * _hash(seed * 3.0 + i)))
	ci.draw_colored_polygon(pts, Color(ROCK_DARK, a))
	var lit := PackedVector2Array()
	for p in pts:
		lit.append(c + (p - c) * 0.78 + Vector2(-0.15, -0.18) * r)
	ci.draw_colored_polygon(lit, Color(ROCK, a))
	ci.draw_circle(c + Vector2(-0.35, -0.35) * r, r * 0.22, Color(ROCK_LIT, a))
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, Color(ROCK_INK, a), maxf(1.0, r * 0.22), true)


## A stone shard jutting up from base, h tall, w half wide at its foot, leaning `lean`.
func _rock_shard(ci: CanvasItem, base: Vector2, h: float, w: float, lean: float, a: float) -> void:
	var tip := base + Vector2(lean * h, -h)
	var left := base + Vector2(-w, 0)
	var right := base + Vector2(w, 0)
	var mid := base + Vector2(w * 0.1, 0)
	ci.draw_colored_polygon(PackedVector2Array([left, tip, mid]), Color(ROCK_LIT, a))
	ci.draw_colored_polygon(PackedVector2Array([mid, tip, right]), Color(ROCK_DARK, a))
	ci.draw_polyline(PackedVector2Array([left, tip, right]), Color(ROCK_INK, a), 1.6 * _s(), true)


# ── Vines (no effect maps to them; Mộc Tinh's Roi dây leo bursts them: vine_strike_fx.gd) ──

## front: the parts of the vines in front of the legs (and the soil), else those behind.
func _vines(ci: CanvasItem, l: Dictionary, front: bool) -> void:
	var grow := clampf(float(l["k"]) * 1.15, 0.0, 1.0) if not l["popping_out"] else 1.0
	draw_vines(ci, height, width, 1.0 - pow(1.0 - grow, 2.0), float(l["alpha"]), front)


## The vines wound up round a body `h` tall and `w` wide from its feet (the origin), grown `grow`
## (0..1) of their height, alpha a; front: the parts in front of the body (and the soil, the root
## claws), else those behind. thorny: brown thorns along them (Roi dây leo's); lash: their tops
## whip sideways by this share of the width (0 still); seed shifts their twists.
static func draw_vines(ci: CanvasItem, h: float, w: float, grow: float, a: float, front: bool, thorny: bool = false,
		lash: float = 0.0, seed: float = 0.0) -> void:
	var s := maxf(h / REF_H, 0.3)
	var n := clampi(roundi(w / (13.0 * s)) + 1, 2, 8)
	var reach := w * 0.24
	for i in n:
		var x0 := lerpf(-0.5, 0.5, i / float(n - 1)) * w
		var vh := h * (0.3 + 0.12 * _hash(i * 2.9 + seed)) * grow
		var phase := i * 1.9 + 0.4 + seed
		var steps := 12
		var prev := Vector2(x0, 0)
		var whip := lash * w * (1.0 if i % 2 == 0 else -0.7)
		for j in range(1, steps + 1):
			var f := j / float(steps)
			var q := phase + f * 5.2
			var p := Vector2(x0 + sin(q) * reach * (1.0 - f * 0.35) + whip * f * f, -vh * f)
			var near := cos(q) > 0.0
			if near == front:
				var lw := lerpf(3.6, 1.4, f) * s
				ci.draw_line(prev, p, Color(VINE_OUT, a), lw + 2.0 * s, true)
				ci.draw_line(prev, p, Color(VINE if front else VINE_BACK, a), lw, true)
				if front and (j == 5 or j == 9):
					_leaf_at(ci, p, (4.0 + _hash(i + j) * 2.0) * s * grow, sin(q) * 0.9 + (0.6 if j == 9 else -0.4), a)
				if thorny and j % 2 == 0 and j < steps:
					var d := (p - prev).normalized()
					var side := d.orthogonal() * (1.0 if j % 4 == 0 else -1.0)
					var tl := (3.2 - 1.4 * f) * s
					ci.draw_colored_polygon(PackedVector2Array([p - d * tl * 0.6, p + side * tl * 1.4 + d * tl * 0.3, p + d * tl * 0.4]),
						Color(0.36, 0.22, 0.1, a))
			prev = p
	if front: # churned soil and root claws at the feet
		ci.draw_set_transform(Vector2(0, 1.0 * s), 0.0, Vector2(1.0, 0.32))
		ci.draw_circle(Vector2.ZERO, (w * 0.5 + 3.0 * s) * grow, Color(SOIL, 0.7 * a))
		ci.draw_set_transform(Vector2.ZERO)
		for side in [-1.0, 1.0]:
			var r0 := Vector2(side * w * 0.55, 1.0 * s)
			var r1 := r0 + Vector2(side * 6.0, -9.0 * grow) * s
			var r2 := r1 + Vector2(-side * 5.0, -4.0 * grow) * s
			ci.draw_polyline(PackedVector2Array([r0, r1, r2]), Color(0.45, 0.3, 0.16, a), 2.6 * s, true)


static func _leaf_at(ci: CanvasItem, at: Vector2, r: float, rot: float, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := TAU * i / 10.0
		pts.append(at + Vector2(cos(ang) * r, sin(ang) * r * 0.45).rotated(rot) + Vector2(r, 0).rotated(rot))
	ci.draw_colored_polygon(pts, Color(LEAF, a))
	ci.draw_line(at, at + Vector2(r * 1.8, 0).rotated(rot), Color(VINE_OUT, 0.6 * a), maxf(1.0, r * 0.18), true)


# ── Poison (boss v4) ────────────────────────────────────────────────────────

const POISON := Color(0.62, 0.95, 0.26)
const POISON_DARK := Color(0.22, 0.42, 0.06)
const POISON_GLOW := Color(0.55, 0.95, 0.2)


## The poison. Back: a sickly green glow behind the body. Front: green bubbles rising off it and
## popping at the top, two drips running down its sides and falling, a small green drop bobbing by
## the head (the status's icon).
func _poison(ci: CanvasItem, l: Dictionary, front: bool) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	if not front:
		var size := Vector2(width + 24.0 * s, height + 20.0 * s) * k * (1.0 + 0.04 * pulse)
		ci.draw_set_transform(Vector2(0, -height * 0.5), 0.0, size / 64.0)
		ci.draw_texture_rect(_halo_tex(), Rect2(-32, -32, 64, 64), false, Color(POISON_GLOW, (0.34 + 0.14 * pulse) * a))
		ci.draw_set_transform(Vector2.ZERO)
		return
	var n := clampi(roundi(width / (6.0 * s)), 5, 14)
	for j in n:
		var ph := fmod(_t * 0.65 + j / float(n) + _hash(j * 1.3) * 0.5, 1.0)
		var x := lerpf(-0.5, 0.5, _hash(j * 2.17)) * width + sin(_t * 2.6 + j) * 2.5 * s
		var p := Vector2(x, -height * (0.12 + ph * 0.92))
		var r := (1.7 + 2.3 * _hash(j * 3.7)) * s * (0.6 + 0.6 * ph) * k
		if ph > 0.88: # it pops
			var u := (ph - 0.88) / 0.12
			ci.draw_arc(p, r * (1.0 + u), 0.0, TAU, 12, Color(POISON, (1.0 - u) * 0.8 * a), 1.2 * s, true)
			continue
		ci.draw_circle(p, r, Color(POISON, 0.6 * a))
		ci.draw_arc(p, r, 0.0, TAU, 12, Color(POISON_DARK, 0.85 * a), maxf(1.0, 0.9 * s), true)
		ci.draw_circle(p + Vector2(-0.35, -0.35) * r, r * 0.3, Color(1, 1, 0.9, 0.85 * a))
	for side in [-1.0, 1.0]: # drips down the sides, then falling off
		var ph := fmod(_t * 0.55 + (0.5 if side > 0.0 else 0.0), 1.0)
		var top := Vector2(side * width * 0.36, -height * 0.62)
		var p := top + Vector2(0, height * 0.5 * smoothstep(0.0, 0.7, ph) + height * 0.6 * maxf(0.0, ph - 0.7) / 0.3)
		var r := 2.4 * s * k
		var fade := 1.0 - maxf(0.0, ph - 0.75) / 0.25
		if ph < 0.7:
			ci.draw_line(top, p, Color(POISON, 0.45 * a), 1.6 * s, true)
		_drop(ci, p, r, Color(POISON, fade * a))
	# the icon: a green drop bobbing by the head
	var ic := Vector2(width * 0.42 + 6.0 * s, -height * 0.94 + sin(_t * 3.0) * 1.5 * s)
	_drop(ci, ic, 5.2 * s * k, Color(POISON, a), true)


## A drop of poison at c (radius r, its point up); outlined: an ink outline and a highlight.
static func _drop(ci: CanvasItem, c: Vector2, r: float, col: Color, outlined: bool = false) -> void:
	if r < 0.4 or col.a <= 0.0:
		return
	var pts := PackedVector2Array([c + Vector2(0, -r * 1.9)])
	for i in 11:
		var ang := -PI * 0.15 + PI * 1.3 * i / 10.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	ci.draw_colored_polygon(pts, col)
	if outlined:
		var ring := pts.duplicate()
		ring.append(pts[0])
		ci.draw_polyline(ring, Color(POISON_DARK.darkened(0.4), col.a), maxf(1.0, r * 0.28), true)
		ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.25), r * 0.28, Color(1, 1, 0.9, 0.85 * col.a))


# ── Stars (stun) ────────────────────────────────────────────────────────────

## front: the stars on the near half of their circle, else the far ones (behind the head).
func _stars(ci: CanvasItem, l: Dictionary, front: bool) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	var head := Vector2(0, -height * 0.96)
	var rx := maxf(width * 0.42, 17.0 * s) * k
	var ry := rx * 0.3
	var n := 4 if width < 80.0 * s else 5
	for i in n:
		var ang := _t * 4.0 + TAU * i / n
		var depth := sin(ang)
		if (depth >= 0.0) != front:
			continue
		var p := head + Vector2(cos(ang) * rx, depth * ry)
		var r := 6.5 * s * k * (0.82 + 0.18 * depth)
		var col := Color(STAR, a * (0.75 + 0.25 * depth))
		_star(ci, p, r, ang * 0.6, col)


func _star(ci: CanvasItem, c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(rot + TAU * i / 10.0 - PI / 2.0) * rr)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(STAR_OUT, col.a), maxf(1.0, r * 0.18), true)


# ── Aura (buffs) ────────────────────────────────────────────────────────────

func _aura(ci: CanvasItem, l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var k: float = l["scale"]
	var col: Color = l["color"]
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	var size := Vector2(width + 30.0 * s, height + 26.0 * s) * k * (1.0 + 0.04 * pulse)
	ci.draw_set_transform(Vector2(0, -height * 0.5), 0.0, size / 64.0)
	ci.draw_texture_rect(_halo_tex(), Rect2(-32, -32, 64, 64), false, Color(col, (0.42 + 0.14 * pulse) * a))
	ci.draw_set_transform(Vector2.ZERO)


## A few motes in the aura's colour rising past the body.
func _motes(l: Dictionary) -> void:
	var s := _s()
	var a: float = l["alpha"]
	var col: Color = l["color"]
	var n := clampi(roundi(width / (8.0 * s)), 4, 12)
	for j in n:
		var ph := fmod(_t * 0.5 + j / float(n), 1.0)
		var x := lerpf(-0.55, 0.55, _hash(j * 1.73)) * width + sin(_t * 2.0 + j * 1.3) * 3.0 * s
		var y := -height * (0.05 + ph * 0.95)
		var fade := sin(ph * PI)
		draw_circle(Vector2(x, y), 1.6 * s, Color(col.lightened(0.45), 0.7 * fade * a))


# ── Helpers ─────────────────────────────────────────────────────────────────

static func _hash(x: float) -> float:
	var v := sin(x * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


static func _halo_tex() -> GradientTexture2D:
	if _halo == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0)])
		_halo = GradientTexture2D.new()
		_halo.gradient = g
		_halo.fill = GradientTexture2D.FILL_RADIAL
		_halo.fill_from = Vector2(0.5, 0.5)
		_halo.fill_to = Vector2(1.0, 0.5)
		_halo.width = 64
		_halo.height = 64
	return _halo
