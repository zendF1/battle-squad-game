extends Control
## The base of the result screen's popups (match/level_up_popup.gd, match/rank_popup.gd): the
## screen dimmed under it, a full-rect `stage` the popup lays its nodes on (by hand: they move),
## its drawn effects (bursts of sparks, shockwave rings, soft glows, turning rays, shards, a
## screen flash; under or over the stage) and "Tiếp tục" at the bottom. build() makes the nodes,
## layout() places them (on every resize), play() runs the sequence on `seq` and calls done_playing()
## at its end. A tap before the end jumps to it (finish(): kills `seq`, show_end()); a tap after
## it, or "Tiếp tục", closes the popup (closed, then it frees itself). Presentation only: the
## timings here are the client's.

signal closed

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")

const DIM := Color(0.01, 0.02, 0.07, 0.8)
const GOLD := Color(1.0, 0.8, 0.22)

var stage: Control
var seq: Tween
var done := false
var _back: Control # effects under the stage
var _front: Control # effects over it
var _continue: Button
var _fx: Array = [] # {kind, age, dur, ...}
var _rays: Array = [] # {at, colors, radius, count, alpha, spin, a}
var _closing := false
var _shake := 0.0


# ── For the popups ──────────────────────────────────────────────────────────

func build() -> void:
	pass


func layout() -> void:
	pass


func play() -> void:
	seq.tween_callback(done_playing)


## The end state, everything shown (a tap during the sequence).
func show_end() -> void:
	pass


func done_playing() -> void:
	done = true


func center() -> Vector2:
	return size / 2.0


## A centred outlined label (the popups' titles and lines).
static func label(value: String, font_size: int, color: Color, outline: int = 0) -> Label:
	var l := LobbyUi.text(value, font_size, color, true)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l


## Places a label of `h` px centred on (cx, cy), `w` wide, its pivot at its centre.
static func place(l: Control, cx: float, cy: float, w: float, h: float) -> void:
	l.size = Vector2(w, h)
	l.position = Vector2(cx - w / 2.0, cy - h / 2.0)
	l.pivot_offset = l.size / 2.0


## Scales a control from `from` to 1 with an overshoot (a pop).
func pop(c: Control, from: float = 1.6, sec: float = 0.32) -> Tween:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * from
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Where a control's centre is in this popup.
func centre_of(c: Control) -> Vector2:
	return c.global_position - global_position + c.size * c.scale / 2.0


# ── Effects ─────────────────────────────────────────────────────────────────

## Sparks and stars flying out of `at`.
func burst(at: Vector2, colors: Array, n: int = 24, speed: float = 420.0, px: float = 10.0) -> void:
	for i in n:
		var a := TAU * i / n + randf_range(-0.2, 0.2)
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.45, 1.0)
		_fx.append({"kind": "spark", "age": 0.0, "dur": randf_range(0.55, 0.95), "p": at, "v": v,
			"c": colors[i % colors.size()], "s": px * randf_range(0.6, 1.3), "star": i % 3 == 0, "spin": randf_range(-6, 6)})


## Confetti falling over the whole popup (the crown).
func shower(colors: Array, n: int = 80) -> void:
	for i in n:
		_fx.append({"kind": "spark", "age": -randf() * 0.8, "dur": randf_range(1.6, 2.4),
			"p": Vector2(randf() * size.x, -20.0 - randf() * 120.0), "v": Vector2(randf_range(-40, 40), randf_range(260, 420)),
			"c": colors[i % colors.size()], "s": randf_range(8, 14), "star": i % 2 == 0, "spin": randf_range(-6, 6), "fall": true})


## A shockwave ring growing from r0 to r1 and fading.
func ring(at: Vector2, color: Color, r0: float, r1: float, sec: float = 0.5, width: float = 8.0) -> void:
	_fx.append({"kind": "ring", "age": 0.0, "dur": sec, "p": at, "r0": r0, "r1": r1, "c": color, "w": width})


## A soft light swelling and fading, under the stage.
func glow(at: Vector2, color: Color, radius: float, sec: float = 0.6) -> void:
	_fx.append({"kind": "glow", "age": 0.0, "dur": sec, "p": at, "r": radius, "c": color})


## The whole popup flashes `color`.
func flash(color: Color, sec: float = 0.35) -> void:
	_fx.append({"kind": "flash", "age": 0.0, "dur": sec, "c": color})


## Pieces of a broken badge flying apart.
func shards(at: Vector2, colors: Array, radius: float, n: int = 14) -> void:
	for i in n:
		var a := TAU * i / n + randf_range(-0.25, 0.25)
		var r := radius * randf_range(0.35, 0.6)
		var pts := PackedVector2Array([Vector2.ZERO, Vector2(cos(a - 0.3), sin(a - 0.3)) * r, Vector2(cos(a + 0.3), sin(a + 0.3)) * r])
		_fx.append({"kind": "shard", "age": 0.0, "dur": randf_range(0.6, 0.9), "p": at, "pts": pts,
			"v": Vector2(cos(a), sin(a)) * randf_range(380, 720) + Vector2(0, -120), "c": colors[i % colors.size()],
			"spin": randf_range(-9, 9), "a": 0.0})


## Rays turning behind the stage around `at`, fading in to `alpha`; returns them (change "alpha").
func rays(at: Vector2, colors: Array, radius: float, alpha: float = 0.3, count: int = 18) -> Dictionary:
	var r := {"at": at, "colors": colors, "radius": radius, "count": count, "alpha": alpha, "shown": 0.0, "a": 0.0, "spin": 0.25}
	_rays.append(r)
	return r


## Shakes the stage for `sec` (a slam).
func shake(sec: float = 0.3) -> void:
	_shake = sec


# ── Base ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)
	_back = _layer(_draw_back)
	stage = Control.new()
	stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage)
	_front = _layer(_draw_front)
	_continue = LobbyUi.start_button("Tiếp tục")
	_continue.custom_minimum_size = Vector2(320, 84)
	_continue.size = _continue.custom_minimum_size
	_continue.pressed.connect(close)
	add_child(_continue)
	build()
	resized.connect(_on_resized)
	_on_resized()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	seq = create_tween()
	play()


func _layer(on_draw: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(on_draw)
	add_child(c)
	return c


func _on_resized() -> void:
	_continue.position = Vector2((size.x - _continue.size.x) / 2.0, size.y - _continue.size.y - 44.0)
	layout()


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	accept_event()
	if done:
		close()
	else:
		finish()


## Jumps to the end of the sequence.
func finish() -> void:
	if done:
		return
	if seq != null:
		seq.kill()
	show_end()
	done_playing()


func close() -> void:
	if _closing:
		return
	_closing = true
	if seq != null:
		seq.kill()
	mouse_filter = MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.18)
	t.tween_callback(func() -> void:
		closed.emit()
		queue_free())


func _process(delta: float) -> void:
	for q in _fx:
		q["age"] += delta
		if q["age"] < 0.0:
			continue
		match q["kind"]:
			"spark":
				q["p"] += q["v"] * delta
				if not q.get("fall", false):
					q["v"] *= pow(0.12, delta)
					q["v"].y += 260.0 * delta
	_fx = _fx.filter(func(q): return q["age"] < q["dur"])
	for r in _rays:
		r["a"] += r["spin"] * delta
		r["shown"] = move_toward(r["shown"], r["alpha"], delta * 0.8)
	if _shake > 0.0:
		_shake -= delta
		stage.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * maxf(_shake / 0.3, 0.0)
		if _shake <= 0.0:
			stage.position = Vector2.ZERO
	_back.queue_redraw()
	_front.queue_redraw()


func _draw_back() -> void:
	for r in _rays:
		if r["shown"] <= 0.01:
			continue
		var n: int = r["count"]
		for i in n:
			var a: float = r["a"] + TAU * i / n
			var half := PI / n * 0.55
			var c: Color = r["colors"][i % r["colors"].size()]
			var pts := PackedVector2Array([r["at"], r["at"] + Vector2(cos(a - half), sin(a - half)) * r["radius"],
				r["at"] + Vector2(cos(a + half), sin(a + half)) * r["radius"]])
			_back.draw_polygon(pts, PackedColorArray([Color(c, r["shown"]), Color(c, 0.0), Color(c, 0.0)]))
	for q in _fx:
		if q["kind"] == "glow" and q["age"] >= 0.0:
			var k: float = q["age"] / q["dur"]
			_soft_circle(_back, q["p"], q["r"] * (0.6 + 0.4 * k), Color(q["c"], (1.0 - k) * 0.9))


func _draw_front() -> void:
	for q in _fx:
		if q["age"] < 0.0:
			continue
		var k: float = q["age"] / q["dur"]
		match q["kind"]:
			"spark":
				var c := Color(q["c"], 1.0 - k * k)
				var s: float = q["s"] * (1.0 - 0.4 * k)
				_front.draw_set_transform(q["p"], q["spin"] * q["age"], Vector2.ONE)
				if q["star"]:
					_front.draw_colored_polygon(_star(s), c)
				else:
					_front.draw_rect(Rect2(-s / 2.0, -s / 4.0, s, s / 2.0), c)
				_front.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"ring":
				var e := 1.0 - pow(1.0 - k, 3.0)
				_front.draw_arc(q["p"], lerpf(q["r0"], q["r1"], e), 0.0, TAU, 72, Color(q["c"], 1.0 - k), q["w"] * (1.0 - 0.6 * k), true)
			"shard":
				_front.draw_set_transform(q["p"] + q["v"] * q["age"] + Vector2(0, 500.0 * q["age"] * q["age"]),
					q["spin"] * q["age"], Vector2.ONE)
				_front.draw_colored_polygon(q["pts"], Color(q["c"], 1.0 - k))
				_front.draw_polyline(q["pts"] + PackedVector2Array([q["pts"][0]]), Color(0.07, 0.07, 0.14, 1.0 - k), 2.5, true)
				_front.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"flash":
				_front.draw_rect(Rect2(Vector2.ZERO, size), Color(q["c"], (1.0 - k) * q["c"].a))


static func _star(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var r := s if i % 2 == 0 else s * 0.32
		var a := TAU * i / 8.0 - PI / 2.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func _soft_circle(on: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	for i in 10:
		var f := 1.0 - i / 10.0
		on.draw_circle(at, radius * f, Color(color, color.a * 0.14))
