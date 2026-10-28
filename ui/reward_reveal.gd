extends Control
## The one reward effect (every reward the player opens or is granted shows with it):
## RewardReveal.open(host, tiles, {chest_id, count, extra}) covers `host` with a dimmed, blurred
## backdrop and plays, all in pictures:
## 1. the container (ui/reward_box.gd: the chest of `chest_id`, else a gift box; "×N" under it
##    when `count` > 1 chests open at once) drops in dead centre, then rocks harder and harder,
##    hopping, with the light of the best reward leaking through its seams (SHAKE s);
## 2. it bursts open: a white flash, the lid thrown off, light pouring out, god rays turning
##    behind, confetti and sparkles, the screen shaking;
## 3. the rewards (ui/reward_model.gd tiles, merged, weakest first) fly out of it one by one on an
##    arc, trailing sparkles, and land in their slots (ui/reward_strip.gd: icon + "×N" over its
##    glow, up to three rows centred, then scrolling) with a bounce and a flash; the best ones
##    land with a shake. `extra` (a Control, e.g. a new title's plate) shows under them;
## 4. "Nhận" (or a tap anywhere) sends every tile flying to the wallet (coins / gems: the
##    "CoinPill" / "GemPill" on screen) or the bag ("BagButton", else the top-right corner), then
##    the overlay fades, emits `collected` and frees itself.
## A tap skips ahead: during 1 to the burst, during 3 lands every tile at once. Esc collects.

signal collected

const LobbyUi := preload("res://ui/lobby_ui.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const RewardBox := preload("res://ui/reward_box.gd")
const RewardGlow := preload("res://ui/reward_glow.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")

## Phases, in order.
const DROP := "drop"
const SHAKE := "shake"
const BURST := "burst"
const FLY := "fly"
const SHOW := "show"
const COLLECT := "collect"
const DONE := "done"

const DROP_SEC := 0.5
const SHAKE_SEC := 1.3
const BURST_SEC := 0.35 # from the burst to the first tile leaving the box
const FLIGHT_SEC := 0.5
const BUTTON_AFTER := 0.3
const BOX_PX := 300.0
const TILE := Vector2(136, 152)
const TILE_ICON := 88
const MAX_ROWS := 3
const GRAVITY := 980.0
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 3.0 * amount).rgb;
	float v = 1.0 - 0.55 * length(SCREEN_UV - vec2(0.5)) * amount;
	COLOR = vec4(c * mix(1.0, 0.38, amount) * v, 1.0);
}
"""

var tiles: Array = []
var chest_id := ""
var count := 1
var phase := DROP
## The best reward's glow (the leaking light, the god rays).
var best := {}

var backdrop: ColorRect
var stage: Control # everything that shakes
var box: Control # ui/reward_box.gd
var strip: Control # ui/reward_strip.gd
var collect_button: Button
var _flash: ColorRect
var _fx_back: Control # god rays (behind the box and tiles)
var _fx_front: Control # particles (over them)
var _count_label: Label
var _extra: Control
var _time := 0.0 # in the current phase
var _clock := 0.0 # since open
var _rays := 0.0 # 0..1 the god rays
var _shake := 0.0 # px, decaying
var _particles: Array = [] # {pos, vel, rot, spin, color, size, life, max, star, gravity}
var _flying: Array = [] # {node, until}: trailing sparkles
var _landed := 0
var _blur: ShaderMaterial


## Opens the reveal over `host` for `reward_tiles` (RewardModel tiles; merged and ordered here).
## opts: chest_id (the chest opened; "" a gift box), count (chests opened at once), extra (a
## Control shown under the tiles once they landed).
static func open(host: Node, reward_tiles: Array, opts: Dictionary = {}) -> Control:
	var r = load("res://ui/reward_reveal.gd").new()
	r.tiles = RewardModel.merge(reward_tiles)
	r.chest_id = str(opts.get("chest_id", ""))
	r.count = maxi(int(opts.get("count", 1)), 1)
	r._extra = opts.get("extra") as Control
	host.add_child(r)
	return r


func _ready() -> void:
	name = "RewardReveal"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	best = RewardModel.best_glow(tiles)
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BLUR_SHADER
	_blur = ShaderMaterial.new()
	_blur.shader = sh
	_blur.set_shader_parameter("amount", 0.0)
	backdrop.material = _blur
	add_child(backdrop)
	stage = Control.new()
	stage.name = "Stage"
	stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage.mouse_filter = MOUSE_FILTER_PASS # a tap anywhere, tiles too, reaches _gui_input
	add_child(stage)
	_fx_back = _layer("Rays", _draw_rays)
	box = RewardBox.make(chest_id, BOX_PX)
	box.name = "Box"
	box.light = best["color"]
	box.pivot_offset = Vector2(BOX_PX / 2.0, BOX_PX * 0.9)
	stage.add_child(box)
	_count_label = LobbyUi.text(RewardModel.qty_text(count), 44, LobbyUi.GOLD, true)
	_count_label.name = "Count"
	LobbyUi.outline(_count_label, 10)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.visible = count > 1
	stage.add_child(_count_label)
	strip = RewardStrip.new()
	strip.name = "Tiles"
	strip.tile_size = TILE
	strip.icon_px = TILE_ICON
	strip.gap = 22.0
	strip.max_rows = MAX_ROWS
	strip.mouse_filter = MOUSE_FILTER_PASS
	stage.add_child(strip)
	strip.set_tiles(tiles)
	strip.visible = false
	if _extra != null:
		_extra.modulate.a = 0.0
		stage.add_child(_extra)
	_fx_front = _layer("Particles", _draw_particles)
	collect_button = LobbyUi.start_button("Nhận")
	collect_button.name = "Collect"
	collect_button.custom_minimum_size = Vector2(300, 96)
	collect_button.pressed.connect(collect)
	collect_button.visible = false
	add_child(collect_button)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_flash)
	resized.connect(_layout)
	_layout()
	_start_drop()


func _layer(layer_name: String, painter: Callable) -> Control:
	var c := Control.new()
	c.name = layer_name
	c.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(painter.bind(c))
	stage.add_child(c)
	return c


## The box dead centre, its count under it; the tiles centred (a little higher with an extra
## under them), the button at the bottom.
func _layout() -> void:
	var c := size / 2.0
	if phase in [DROP, SHAKE, BURST, FLY] and box != null:
		box.position = c - box.size / 2.0
	if _count_label != null:
		_count_label.size = Vector2(240, 60)
		_count_label.position = Vector2(c.x - 120, c.y + BOX_PX / 2.0 - 6)
	if strip == null:
		return
	var w := minf(size.x - 120.0, 1400.0)
	strip.size = Vector2(w, strip.size.y)
	var counts := RewardStrip.layout(tiles.size(), w, TILE.x, strip.gap, MAX_ROWS)
	var h: float = counts.size() * TILE.y + maxi(counts.size() - 1, 0) * float(strip.gap)
	var extra_h := (_extra.get_combined_minimum_size().y + 24.0) if _extra != null else 0.0
	strip.size = Vector2(w, h)
	strip.position = Vector2((size.x - w) / 2.0, c.y - (h + extra_h) / 2.0 - 30.0)
	if _extra != null:
		_extra.size = Vector2(minf(size.x - 80.0, 900.0), _extra.get_combined_minimum_size().y)
		_extra.position = Vector2((size.x - _extra.size.x) / 2.0, strip.position.y + h + 24.0)
	if collect_button != null:
		collect_button.size = collect_button.custom_minimum_size
		collect_button.position = Vector2((size.x - collect_button.size.x) / 2.0, size.y - collect_button.size.y - 48.0)


# ── Phases ──────────────────────────────────────────────────────────────────

func _set_phase(p: String) -> void:
	phase = p
	_time = 0.0


func _start_drop() -> void:
	_set_phase(DROP)
	var c := size / 2.0
	box.position = Vector2(c.x - BOX_PX / 2.0, -BOX_PX * 1.4)
	box.scale = Vector2(0.85, 1.15)
	var t := create_tween()
	t.tween_property(box, "position:y", c.y - BOX_PX / 2.0, DROP_SEC * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(func(v: float) -> void: _blur.set_shader_parameter("amount", v), 0.0, 1.0, 0.3)
	# the landing: squash, a dust puff, a thump
	t.tween_callback(func() -> void:
		_shake = 6.0
		_puff(box.position + Vector2(BOX_PX / 2.0, BOX_PX * 0.92)))
	t.tween_property(box, "scale", Vector2(1.18, 0.82), 0.06)
	t.tween_property(box, "scale", Vector2.ONE, DROP_SEC * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Skips ahead: to the burst (before it), every tile landed (while they fly), collecting (once
## shown).
func skip() -> void:
	match phase:
		DROP, SHAKE:
			_burst()
		BURST, FLY:
			_land_all()
		SHOW:
			collect()


func _process(delta: float) -> void:
	_time += delta
	_clock += delta
	match phase:
		DROP:
			if _time >= DROP_SEC:
				_set_phase(SHAKE)
		SHAKE:
			_wobble()
			if _time >= SHAKE_SEC:
				_burst()
		BURST:
			if _time >= BURST_SEC:
				_fly()
	_rays = move_toward(_rays, 1.0 if phase in [BURST, FLY, SHOW] else 0.0, delta * (3.0 if phase != COLLECT else 4.0))
	_step_particles(delta)
	_shake = move_toward(_shake, 0.0, delta * 30.0)
	stage.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake if _shake > 0.05 else Vector2.ZERO
	_fx_back.queue_redraw()
	_fx_front.queue_redraw()


## The rocking before the burst: harder and faster, little hops, light leaking more and more.
func _wobble() -> void:
	var k := clampf(_time / SHAKE_SEC, 0.0, 1.0)
	var amp := deg_to_rad(lerpf(2.5, 11.0, pow(k, 1.4)))
	var freq := lerpf(12.0, 30.0, k)
	box.rotation = sin(_time * freq) * amp
	var hop := absf(sin(_time * 7.5)) * 16.0 * k * k
	box.position = size / 2.0 - box.size / 2.0 - Vector2(0, hop)
	var squash := 0.035 * k * sin(_time * freq * 2.0)
	box.scale = Vector2(1.0 + squash, 1.0 - squash) * (1.0 + 0.06 * k)
	box.leak = pow(k, 1.2)
	if k > 0.55:
		_shake = maxf(_shake, 2.5 * k)
	if randf() < 0.35 + k * 0.6: # sparks out of the seam
		var seam := box.position + Vector2(BOX_PX * randf_range(0.18, 0.82), BOX_PX * 84.0 / 160.0)
		_spark(seam, Vector2(randf_range(-120, 120), randf_range(-260, -120)), best["accent"], 0.45, randf_range(3, 6))


## Opens: flash, the lid thrown off, light pouring out, god rays, confetti, the screen shaking.
func _burst() -> void:
	if phase in [BURST, FLY, SHOW, COLLECT, DONE]:
		return
	_set_phase(BURST)
	_blur.set_shader_parameter("amount", 1.0)
	box.position = size / 2.0 - box.size / 2.0
	box.rotation = 0.0
	box.leak = 1.0
	_flash.color.a = 0.95
	var f := create_tween()
	f.tween_property(_flash, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var lid := create_tween()
	lid.tween_property(box, "lid_offset", Vector2(46, -330), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lid.parallel().tween_property(box, "lid_turn", 1.1, 0.7)
	lid.parallel().tween_property(box, "lid_alpha", 0.0, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	lid.parallel().tween_property(box, "open_glow", 1.0, 0.18)
	box.scale = Vector2(1.22, 0.86)
	var s := create_tween()
	s.tween_property(box, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_shake = 16.0
	_count_label.visible = false
	var at := box.position + Vector2(BOX_PX / 2.0, BOX_PX * 0.5)
	var colors := [best["color"], best["accent"], Color(1, 1, 1), LobbyUi.GOLD, Color(0.45, 0.85, 1.0), Color(1.0, 0.45, 0.6)]
	for i in 90: # confetti
		var ang := randf_range(-PI * 0.95, -PI * 0.05)
		var sp := randf_range(380, 1050)
		_particles.append({"pos": at, "vel": Vector2.from_angle(ang) * sp, "rot": randf() * TAU, "spin": randf_range(-12, 12),
			"color": colors[i % colors.size()], "size": randf_range(7, 13), "life": 0.0, "max": randf_range(1.4, 2.2),
			"star": false, "gravity": GRAVITY})
	for i in 36: # sparkles
		var ang := randf() * TAU
		_spark(at, Vector2.from_angle(ang) * randf_range(200, 620), best["accent"] if i % 2 == 0 else Color.WHITE, randf_range(0.6, 1.1),
			randf_range(8, 16))


## The tiles fly out of the box one by one to their slots.
func _fly() -> void:
	_set_phase(FLY)
	strip.visible = true
	strip.clip_contents = false
	var from := box.position + Vector2(BOX_PX / 2.0, BOX_PX * 0.45)
	var step := RewardModel.stagger(tiles.size())
	var fade := create_tween()
	fade.tween_interval(0.25 + step * tiles.size() * 0.6)
	fade.tween_property(box, "modulate:a", 0.0, 0.45)
	fade.parallel().tween_property(box, "scale", Vector2(0.7, 0.7), 0.45)
	if tiles.is_empty():
		_after_landing()
		return
	for i in tiles.size():
		var n: Control = strip.tile_node(i)
		var end := n.position
		# the box's centre in the row's space
		var start: Vector2 = (n.get_parent() as Control).get_global_transform_with_canvas().affine_inverse() * (get_global_transform_with_canvas() * from) - n.size / 2.0
		var lift := Vector2(0, -minf(220.0, 120.0 + absf(end.x - start.x) * 0.25))
		var ctrl := (start + end) / 2.0 + lift
		n.position = start
		n.scale = Vector2.ONE * 0.15
		n.modulate.a = 0.0
		var g: Control = strip.glow_node(i)
		if g != null:
			g.intro = 0.25
		var t := n.create_tween()
		t.tween_interval(i * step)
		t.tween_callback(func() -> void: _flying.append({"node": n, "color": RewardModel.glow(tiles[i])["accent"], "until": _clock + FLIGHT_SEC}))
		t.tween_property(n, "modulate:a", 1.0, 0.1)
		t.parallel().tween_method(func(k: float) -> void: n.position = _bezier(start, ctrl, end, k), 0.0, 1.0, FLIGHT_SEC) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(n, "scale", Vector2.ONE * 1.28, FLIGHT_SEC * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_callback(_land.bind(i))
		t.tween_property(n, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		n.set_meta("reveal_tween", t)


static func _bezier(a: Vector2, c: Vector2, b: Vector2, k: float) -> Vector2:
	return a.lerp(c, k).lerp(c.lerp(b, k), k)


## A tile in its slot: its glow comes on with a flash, sparkles burst; the best ones shake.
func _land(i: int) -> void:
	var g: Control = strip.glow_node(i)
	var glow := RewardModel.glow(tiles[i])
	if g != null:
		g.intro = 1.0
		g.land()
	var n: Control = strip.tile_node(i)
	var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * (n.get_global_transform_with_canvas() * (n.size / 2.0))
	var power := float(glow["power"])
	for k in int(6 + power * 14):
		_spark(at, Vector2.from_angle(randf() * TAU) * randf_range(120, 300 + power * 200), glow["accent"] if k % 2 == 0 else Color.WHITE,
			randf_range(0.35, 0.7), randf_range(4, 8 + power * 6))
	if power >= 0.85:
		_shake = maxf(_shake, 7.0 * power)
		_flash.color.a = maxf(_flash.color.a, 0.25)
		create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
	_landed += 1
	if _landed >= tiles.size():
		_after_landing()


func _after_landing() -> void:
	if phase != FLY:
		return
	_set_phase(SHOW)
	if box.modulate.a > 0.0: # skipped ahead: the empty box goes too
		var b := create_tween()
		b.tween_property(box, "modulate:a", 0.0, 0.25)
	if strip.fits():
		strip.clip_contents = false
	else:
		strip.clip_contents = true
	var t := create_tween()
	t.tween_interval(BUTTON_AFTER)
	t.tween_callback(func() -> void:
		collect_button.visible = true
		collect_button.modulate.a = 0.0
		collect_button.scale = Vector2(0.7, 0.7)
		collect_button.pivot_offset = collect_button.size / 2.0)
	t.tween_property(collect_button, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(collect_button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _extra != null:
		t.parallel().tween_property(_extra, "modulate:a", 1.0, 0.3)


## Lands every tile at once (a tap while they fly).
func _land_all() -> void:
	if phase in [DROP, SHAKE]:
		_burst()
	if phase == BURST:
		_fly()
	if phase != FLY:
		return
	for i in tiles.size():
		var n: Control = strip.tile_node(i)
		var t = n.get_meta("reveal_tween") if n.has_meta("reveal_tween") else null
		if t is Tween and t.is_valid():
			t.kill()
	_flying.clear()
	_landed = 0
	strip._layout()
	for i in tiles.size():
		var n: Control = strip.tile_node(i)
		n.scale = Vector2.ONE
		n.modulate.a = 1.0
		_land(i)


## Sends the tiles to the wallet / bag, fades out, emits `collected`, frees itself.
func collect() -> void:
	if phase in [COLLECT, DONE]:
		return
	if phase != SHOW:
		_land_all()
	_set_phase(COLLECT)
	collect_button.disabled = true
	strip.clip_contents = false
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(collect_button, "modulate:a", 0.0, 0.15)
	if _extra != null:
		t.tween_property(_extra, "modulate:a", 0.0, 0.15)
	for i in tiles.size():
		var n: Control = strip.tile_node(i)
		var target := target_of(tiles[i])
		var to: Vector2 = (n.get_parent() as Control).get_global_transform_with_canvas().affine_inverse() * target - n.size / 2.0
		var d := 0.04 * i
		t.tween_property(n, "position", to, 0.5).set_delay(d).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(n, "scale", Vector2.ONE * 0.3, 0.5).set_delay(d)
		t.tween_property(n, "modulate:a", 0.0, 0.18).set_delay(d + 0.38)
	var end := 0.62 + 0.04 * tiles.size()
	t.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(end)
	t.chain().tween_callback(_finish)


func _finish() -> void:
	if phase == DONE:
		return
	_set_phase(DONE)
	collected.emit()
	queue_free()


## Where a collected tile flies (canvas position): the coin / gem pill on screen for coins and
## gems, the bag button for the rest, else the top-right corner.
func target_of(t: Dictionary) -> Vector2:
	var kind := str(t.get("kind", ""))
	var names := ["CoinPill"] if kind == "coin" else (["GemPill"] if kind == "gem" else ["BagButton"])
	var root := get_parent()
	while root != null and root.get_parent() != null and root.get_parent() is Control:
		root = root.get_parent()
	for n in names:
		var found := _visible_named(root, n)
		if found != null:
			return found.get_global_transform_with_canvas() * (found.size / 2.0)
	return get_global_transform_with_canvas() * Vector2(size.x - 90.0, 60.0)


static func _visible_named(root: Node, node_name: String) -> Control:
	if root == null:
		return null
	for n in root.find_children(node_name, "Control", true, false):
		if (n as Control).is_visible_in_tree():
			return n
	return null


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		skip()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and phase != DONE:
		collect()
		get_viewport().set_input_as_handled()


# ── Particles and rays ──────────────────────────────────────────────────────

func _spark(at: Vector2, vel: Vector2, color: Color, life: float, px: float) -> void:
	_particles.append({"pos": at, "vel": vel, "rot": 0.0, "spin": 0.0, "color": color, "size": px, "life": 0.0, "max": life,
		"star": true, "gravity": 120.0})


## A dust puff where the box lands.
func _puff(at: Vector2) -> void:
	for i in 14:
		var dir := -1.0 if i % 2 == 0 else 1.0
		_particles.append({"pos": at + Vector2(dir * randf_range(20, 120), 0), "vel": Vector2(dir * randf_range(80, 260), randf_range(-90, -20)),
			"rot": 0.0, "spin": 0.0, "color": Color(0.85, 0.8, 0.75, 0.6), "size": randf_range(14, 26), "life": 0.0,
			"max": randf_range(0.4, 0.7), "star": false, "gravity": 0.0, "puff": true})


func _step_particles(delta: float) -> void:
	for f in _flying:
		var n: Control = f["node"]
		if is_instance_valid(n) and _clock < float(f["until"]):
			var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * (n.get_global_transform_with_canvas() * (n.size / 2.0))
			_spark(at + Vector2(randf_range(-14, 14), randf_range(-14, 14)), Vector2(randf_range(-40, 40), randf_range(-40, 40)), f["color"],
				0.4, randf_range(4, 8))
	_flying = _flying.filter(func(f): return _clock < float(f["until"]))
	if phase == SHOW and randf() < delta * 14.0: # motes rising behind the rewards
		_spark(Vector2(randf() * size.x, size.y + 10), Vector2(randf_range(-20, 20), randf_range(-160, -70)), best["accent"], randf_range(2.5, 4.0),
			randf_range(3, 6))
	for p in _particles:
		p["life"] += delta
		p["vel"].y += float(p["gravity"]) * delta
		p["vel"] *= 1.0 - minf(delta * (1.6 if not p["star"] else 2.2), 0.5)
		p["pos"] += p["vel"] * delta
		p["rot"] += float(p["spin"]) * delta
	_particles = _particles.filter(func(p): return float(p["life"]) < float(p["max"]))


func _draw_particles(c: Control) -> void:
	for p in _particles:
		var k := float(p["life"]) / float(p["max"])
		var col: Color = p["color"]
		var a := col.a * (1.0 - k * k)
		var px := float(p["size"])
		if p.get("puff", false):
			c.draw_texture_rect(RewardGlow.radial(), Rect2(p["pos"] - Vector2(px, px) * (1.0 + k), Vector2(px, px) * 2.0 * (1.0 + k)), false,
				Color(col, a * 0.8))
		elif p["star"]:
			RewardGlow.star(c, p["pos"], px * (1.0 - 0.5 * k), Color(col, a))
		else:
			var flip := absf(cos(float(p["rot"]) * 1.7)) # confetti turning over
			c.draw_set_transform(p["pos"], float(p["rot"]), Vector2(1.0, maxf(flip, 0.15)))
			c.draw_rect(Rect2(-px / 2.0, -px * 0.3, px, px * 0.6), Color(col, a))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## God rays behind everything, turning slowly, in the best reward's colours; a soft glow under
## the box while it leaks.
func _draw_rays(c: Control) -> void:
	var centre := size / 2.0 + Vector2(0, -20)
	var col: Color = best.get("color", Color.WHITE)
	var acc: Color = best.get("accent", col)
	if phase == SHAKE or (phase == DROP and _time > DROP_SEC * 0.8):
		var k: float = box.leak
		var g: float = BOX_PX * (0.7 + 0.9 * k)
		c.draw_texture_rect(RewardGlow.radial(), Rect2(centre - Vector2(g, g), Vector2(g, g) * 2.0), false, Color(col, 0.6 * k))
	if _rays <= 0.0:
		return
	# two fans: wide soft rays turning one way, thin bright ones the other
	var reach := size.length() * 0.5 * (0.45 + 0.55 * _rays)
	for layer in 2:
		var n := 12 if layer == 0 else 18
		var spin := _clock * (0.18 if layer == 0 else -0.11) + layer * 0.3
		var width := 0.5 if layer == 0 else 0.22
		var alpha := 0.26 if layer == 0 else 0.3
		for i in n:
			var ang := spin + TAU * i / n
			var w := PI / n * width
			var tint := col if i % 2 == 0 else acc
			var r := reach * ((1.0 if i % 2 == 0 else 0.72) if layer == 0 else 0.62 + 0.25 * sin(i * 2.3))
			c.draw_polygon(PackedVector2Array([centre, centre + Vector2.from_angle(ang - w) * r, centre + Vector2.from_angle(ang + w) * r]),
				PackedColorArray([Color(tint.lerp(Color.WHITE, 0.25 * layer), alpha * _rays), Color(tint, 0.0), Color(tint, 0.0)]))
	var g2 := 420.0 * (0.6 + 0.4 * _rays)
	c.draw_texture_rect(RewardGlow.radial(), Rect2(centre - Vector2(g2, g2), Vector2(g2, g2) * 2.0), false, Color(col, 0.45 * _rays))
	var g3 := 170.0 * (0.6 + 0.4 * _rays)
	c.draw_texture_rect(RewardGlow.radial(), Rect2(centre - Vector2(g3, g3), Vector2(g3, g3) * 2.0), false, Color(acc.lerp(Color.WHITE, 0.5), 0.35 * _rays))
