extends Node2D
## A shell in flight (moved by shot_player.gd), drawn the way the shooter's GUN fires it
## (match/views/shot_look.gd: `kind` = the bullet and its trail, `tier` = how grand), always
## turned to its flight direction (the image flies towards +x; `heading` faces it before it moves,
## then the server path's tangent, set_tangent(), or else its last step; flying left it is flipped
## vertically so its top stays on top, flipped()):
## - bazooka: a rocket with a flickering exhaust flame (assets/fx/common/muzzle.png) at its nozzle,
##   a short fiery line and puffs that start as fire and turn into grey smoke;
## - cannon: a heavy iron ball with a grey smoke trail;
## - shock_rifle: a flickering plasma orb with an electric trail and sparks;
## - seed_launcher: a spinning seed pod with a petal trail;
## - blaster: an energy bolt in the accent colour with a short streak.
## The tier blends its colour into the trail, adds a glow halo (steel up) and its overlay
## particles (assets/fx/tiers/: mithril / silver sparkles, dragon / titan embers, gold coins,
## diamond crystal shards in rainbow colours). The four normal tiers have their own theme
## (ShotLook.THEMES) instead: iron sheds thick grey smoke puffs, steel sparks (short white-hot
## streaks stretched along their speed, falling behind), mithril an icy-blue light ribbon with ice
## glints, dragon a long flickering fire tail (layered flame puffs, hot white-yellow to orange,
## red and dark smoke, wavering) with its embers; and its own shell picture when there is one
## (assets/fx/<kind>/projectile_<tier>.png, Art.tier_projectile()): drawn in its own colours (no
## accent tint, no sheen), fitted into the drawn part of the kind's projectile.png (its alpha
## content box, base_content()) so it flies just as big
## (the halo, skill boost, spin, flicker, exhaust and item marks / tints as for the plain one);
## missing: the kind's projectile.png as before. Images via ui/art.gd (assets/fx/<kind>/, falling
## back to the round bomb, assets/fx/common/bomb.png). A skill shot is drawn larger and brighter;
## an item shot is tinted and marked by the item on top (ITEM_LOOKS; an air strike drops the round
## bomb with its fuse spark instead). Set kind / tier / skill / item / heading before adding it.
## Visuals only: the server path moves it.

const Art := preload("res://ui/art.gd")
const ShotLook := preload("res://match/views/shot_look.gd")

const TRAIL := 10 # positions kept for the line trail
const BOMB_PX := 2.0 # projectile image px per world px
const TURN_RATE := 60.0 # 1/s: how fast the shell turns to the path's tangent (light smoothing)
const CONTENT_ALPHA := 0.1 # a px with more alpha is part of the drawn shell (base_content())
const SPARK := Vector2(-11, -3) # the bomb's fuse tip, world px from its centre (flying +x)
const EXHAUST := Vector2(-13, 0) # the rocket's exhaust flame, world px from its centre (flying +x)
## Overlay trail particles drawn behind the projectile with its halo; coins and shards fly over it.
const GLOWING_FX := ["sparkle", "ember"]
## item id -> tint of the projectile and its trail, a mark drawn over it ("" none) and whether it
## is the round bomb whatever the gun (bomb).
const ITEM_LOOKS := {
	"air_strike": {"tint": Color.WHITE, "mark": "", "bomb": true},
	"freeze_bomb": {"tint": Color(0.62, 0.86, 1.0), "mark": "frost"},
	"spider_net": {"tint": Color(0.95, 0.95, 1.0), "mark": "web"},
	"drill_bomb": {"tint": Color(0.72, 0.72, 0.78), "mark": "spiral"},
	"power_shot": {"tint": Color(1.0, 0.62, 0.42), "mark": ""},
	"teleport": {"tint": Color(0.8, 0.62, 1.0), "mark": ""},
}

static var _contents := {} # Texture2D -> base_content()

var kind := ShotLook.DEFAULT_KIND
var tier := ShotLook.DEFAULT_TIER
var skill := false
## Extra size on top of the tier / skill scale (a skill's bigger shells: the bomb chain's bombs).
var size_k := 1.0
var item := ""
## The flight direction before the first move (shot_player.gd: the path's start velocity);
## zero: +x.
var heading := Vector2.ZERO
## The share of its trail the shell keeps (0..1: the line, the tier's tail and how long the
## kind's and the tier's trail particles live); set before adding it (the rain's missiles: a
## short one).
var trail_length := 1.0
var _trail_keep := TRAIL
var _kind_trail := {} # _k["trail"], its life scaled by trail_length
var _tangent := Vector2.ZERO # set_tangent()

var _k: Dictionary # ShotLook.KINDS[kind]
var _tl: Dictionary # ShotLook.TIERS[tier]
var _accent := Color.WHITE
var _accent2 := Color.WHITE
var _trail := PackedVector2Array() # global positions, oldest first
var _particles: Array = [] # the kind's trail: [global position, age, angle, sideways offset, velocity]
var _tier_particles: Array = [] # the tier's overlay trail (or its theme's): the same
var _since_particle := 0.0 # world px travelled since the last kind particle
var _since_tier := 0.0
var _dir := Vector2.RIGHT
var _t := 0.0
var _tex: Texture2D
var _tier_body := false # _tex is the tier's own shell picture
var _body_size := Vector2.ONE # the shell's drawn size, world px (before the tier / skill scale)
var _trail_tex: Texture2D
var _tier_fx := {} # ShotLook.trail_fx(tier)
var _tier_on := false # the tier sheds particles
var _tier_tex: Texture2D
var _tier_tex2: Texture2D # every other particle (null: _tier_tex)
var _tier_glows := false
var _ribbon_spec := {} # the theme's tail ({}: none)
var _ribbon := PackedVector2Array() # its points, global, oldest first, one every _ribbon_spec.every px
var _line_pts := PackedVector2Array() # reused drawing buffers for the light ribbon
var _line_cols := PackedColorArray()
var _spark: Texture2D
var _glow: Texture2D
var _tint := Color.WHITE
var _mark := ""
var _fuse := false
var _exhaust := false
var _glow_layer: Node2D # behind the projectile: the halo and the glowing overlay particles
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	kind = ShotLook.known_kind(kind)
	tier = ShotLook.known_tier(tier)
	_k = ShotLook.KINDS[kind]
	_tl = ShotLook.TIERS[tier]
	_accent = ShotLook.accent(kind, tier)
	_accent2 = ShotLook.accent2(kind, tier)
	var look: Dictionary = ITEM_LOOKS.get(item, {})
	var bomb := bool(look.get("bomb", false))
	_tex = Art.fx("bomb") if bomb else Art.shot(kind, "projectile", Art.fx("bomb"))
	_body_size = _tex.get_size() / BOMB_PX
	var own: Texture2D = null if bomb else Art.tier_projectile(kind, tier)
	if own != null:
		_body_size = fit_size(own.get_size(), base_content(_tex) / BOMB_PX) * float(_k.get("tier_body_scale", 1.0))
		_tex = own
		_tier_body = true
	_fuse = bomb or bool(_k["fuse"])
	_exhaust = not bomb and bool(_k["exhaust"])
	if heading.length_squared() > 0.0:
		_dir = heading.normalized()
	_spark = Art.fx("muzzle")
	_trail_tex = Art.shot(kind, "trail", Art.fx("smoke"))
	_tier_fx = ShotLook.trail_fx(tier)
	_kind_trail = _k["trail"]
	if trail_length < 1.0: # shorter-lived particles (copies: the specs are shared)
		_kind_trail = _shorter(_kind_trail)
		if not _tier_fx.is_empty():
			_tier_fx = _shorter(_tier_fx)
	if not _tier_fx.is_empty():
		_tier_tex = overlay_texture(str(_tier_fx.get("tex", "")))
		_tier_tex2 = overlay_texture(str(_tier_fx.get("tex2", "")))
		_tier_glows = bool(_tier_fx.get("glow", GLOWING_FX.has(str(_tier_fx.get("tex", "")))))
		_tier_on = _tier_tex != null or _tier_fx.get("mode", "") == "streak"
	_ribbon_spec = ShotLook.tier_theme(tier).get("ribbon", {})
	if trail_length < 1.0:
		_trail_keep = maxi(3, int(TRAIL * trail_length))
		if not _ribbon_spec.is_empty():
			_ribbon_spec = _ribbon_spec.duplicate()
			_ribbon_spec["points"] = maxi(4, int(float(_ribbon_spec["points"]) * trail_length))
	_glow = Art.tier_fx("glow")
	if _glow == null:
		_glow = _spark
	_tint = look.get("tint", Color.WHITE)
	_mark = look.get("mark", "")
	_rng.randomize()
	_trail.append(global_position)
	if not _ribbon_spec.is_empty():
		_ribbon.append(global_position)
	_glow_layer = Node2D.new()
	_glow_layer.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_glow_layer.show_behind_parent = true
	_glow_layer.draw.connect(_draw_glow)
	add_child(_glow_layer)


func _process(delta: float) -> void:
	_t += delta
	var p := global_position
	var moved := 0.0
	if _tangent.length_squared() > 0.0: # the path's own tangent (shot_player.gd), lightly smoothed
		var a := lerp_angle(_dir.angle(), _tangent.angle(), 1.0 - exp(-TURN_RATE * delta))
		_dir = Vector2.from_angle(a)
	if _trail.is_empty() or p.distance_squared_to(_trail[-1]) > 0.25:
		var v := p - _trail[-1] if not _trail.is_empty() else Vector2.ZERO
		if v.length_squared() > 0.01 and _tangent.length_squared() == 0.0:
			_dir = v.normalized() # no tangent given: the last step
		moved = v.length()
		_trail.append(p)
		if _trail.size() > _trail_keep:
			_trail.remove_at(0)
	_since_particle += moved
	_particles = _emit(_particles, _kind_trail, delta, p - _dir * float(_kind_trail.get("back", 0.0)) * _scale_k(), "_since_particle", ShotLook.TRAIL_KIND_CAP)
	if _tier_on:
		_since_tier += moved
		_tier_particles = _emit(_tier_particles, _tier_fx, delta, p, "_since_tier", ShotLook.TRAIL_TIER_CAP)
	if not _ribbon_spec.is_empty():
		_grow_ribbon(p)
	queue_redraw()
	_glow_layer.queue_redraw()


## A copy of a trail spec whose particles live trail_length as long.
func _shorter(spec: Dictionary) -> Dictionary:
	var out := spec.duplicate()
	if out.has("life"):
		out["life"] = float(out["life"]) * maxf(trail_length, 0.05)
	return out


## An overlay or common effect texture by name ("" or a missing file: null).
static func overlay_texture(tex_name: String) -> Texture2D:
	if tex_name == "":
		return null
	return Art.fx(tex_name) if Art.FX.has(tex_name) else Art.tier_fx(tex_name)


## Adds the ribbon's points along the path towards the shell at p, one every `every` px (the
## shell itself is its head, added when drawn), keeping its `points`.
func _grow_ribbon(p: Vector2) -> void:
	var every := float(_ribbon_spec["every"]) * ShotLook.SHELL_SCALE # the tail is as much shorter
	var keep := int(_ribbon_spec["points"])
	var steps := 0
	while _ribbon[-1].distance_to(p) >= every and steps < keep:
		_ribbon.append(_ribbon[-1].move_toward(p, every))
		steps += 1
	if steps == keep: # a jump longer than the whole tail: start it again here
		_ribbon[-1] = p
	if _ribbon.size() > keep:
		_ribbon = _ribbon.slice(_ribbon.size() - keep)


## Ages a trail's particles, drops the dead ones, adds one every `every` px travelled (the
## distance counter is the property named `counter`; shed [back, side]: thrown off backwards and
## sideways, px/s) and keeps at most `cap` (the oldest go). The particles shed in one frame are
## spread back along the flight to where each `every` px mark was passed (not all at `at`), so a
## fast shell (the rain's missiles) leaves an even trail instead of a clump per frame.
func _emit(list: Array, spec: Dictionary, delta: float, at: Vector2, counter: String, cap: int) -> Array:
	var life: float = spec["life"]
	for q in list:
		q[1] += delta
	list = list.filter(func(q): return q[1] < life)
	var every: float = spec["every"]
	var travelled: float = get(counter)
	var shed: Array = spec.get("shed", [0.0, 0.0])
	while travelled >= every:
		travelled -= every
		var v := Vector2.ZERO
		if float(shed[0]) > 0.0 or float(shed[1]) > 0.0:
			v = -_dir * _rng.randf_range(0.4, 1.0) * float(shed[0]) + Vector2(-_dir.y, _dir.x) * _rng.randf_range(-1.0, 1.0) * float(shed[1])
		# travelled is now how far the shell went since this mark
		list.append([at - _dir * travelled, 0.0, _rng.randf() * TAU, _rng.randf_range(-1.0, 1.0) * float(spec.get("jitter", 0.0)), v])
	set(counter, travelled)
	if list.size() > cap:
		list = list.slice(list.size() - cap)
	return list


## The flight direction at the path here (velocity, any length; shot_player.gd sets it every
## frame from the server path): the shell turns to it (TURN_RATE smoothing) instead of following
## its last step.
func set_tangent(v: Vector2) -> void:
	if v.length_squared() > 0.0:
		if _tangent.length_squared() == 0.0 and heading.length_squared() == 0.0:
			_dir = v.normalized() # the first one: no turn from +x
		_tangent = v


## The kind's spin (rad/s): none for a tier's own shell picture (the pointed seeds face their
## flight like the rocket; the round basic pod keeps spinning).
func spin_rate() -> float:
	return 0.0 if _tier_body else float(_k["spin"])


## The body's size pulse (scale factor) for the flickering kinds: none for a tier's own shell
## picture (a big detailed shell pulsing at ~7 Hz reads as stutter; its glow still shimmers).
func body_pulse() -> float:
	if _tier_body or not _k["flicker"]:
		return 1.0
	return 1.0 + 0.12 * sin(_t * 45.0)


## The projectile's drawn rotation (rad): its flight direction plus the kind's spin.
func draw_angle() -> float:
	return _dir.angle() + _t * spin_rate()


## Whether the shell is drawn flipped vertically: flying left (a right-facing picture turned by
## ~180° would be upside down: its top, fins, leaf and highlight kept on top); never a spinning one.
func flipped() -> bool:
	return _dir.x < 0.0 and spin_rate() == 0.0


## The shell's colour: the tier's own picture untinted (only an item's tint), the kind's
## projectile.png taking the accent by the kind's body_tint (the blaster's white bolt fully).
func body_color() -> Color:
	if _tier_body:
		return _tint
	return Color.WHITE.lerp(_accent, float(_k["body_tint"])) * _tint


## The shell's drawn size, world px, before the tier / skill scale: the kind's projectile.png's,
## a tier's own picture fitted into it.
func body_size() -> Vector2:
	return _body_size


## The size of the drawn part of a picture (the box of its px with alpha > CONTENT_ALPHA; the
## whole picture when it cannot be read), cached per texture.
static func base_content(tex: Texture2D) -> Vector2:
	if _contents.has(tex):
		return _contents[tex]
	var size := tex.get_size()
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect() if img.detect_alpha() != Image.ALPHA_NONE else Rect2i(Vector2i.ZERO, img.get_size())
		var lo := Vector2i(img.get_width(), img.get_height())
		var hi := Vector2i(-1, -1)
		for y in range(used.position.y, used.end.y):
			for x in range(used.position.x, used.end.x):
				if img.get_pixel(x, y).a > CONTENT_ALPHA:
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		if hi.x >= 0:
			size = Vector2(hi - lo + Vector2i.ONE) * size / Vector2(img.get_size())
	_contents[tex] = size
	return size


## A picture of size `src` fitted into `box` keeping its aspect (as large as fits).
static func fit_size(src: Vector2, box: Vector2) -> Vector2:
	if src.x <= 0.0 or src.y <= 0.0:
		return box
	return src * minf(box.x / src.x, box.y / src.y)


## The shell's drawn scale (its picture, trails, halo, tail): ShotLook.SHELL_SCALE × the tier's
## × the skill's × size_k.
func _scale_k() -> float:
	return ShotLook.SHELL_SCALE * float(_tl["scale"]) * (ShotLook.SKILL_SCALE if skill else 1.0) * size_k


func _draw() -> void:
	var scale_k := _scale_k()
	var line = _k["line"]
	var n := _trail.size()
	if line != null:
		var c: Color = Color(line).lerp(_accent, float(_tl["mix"])) * _tint
		var w: float = float(_k["line_width"]) * float(_tl["line"])
		var bright := 0.45 + 0.25 * minf(1.0, float(_tl["rank"]) / 4.0)
		for i in range(1, n):
			var k := float(i) / n
			var a := _trail[i - 1] - global_position
			var b := _trail[i] - global_position
			var col: Color = ShotLook.prism(_t * 1.5 - k * 0.6) * _tint if _tl["prismatic"] else c
			draw_line(a, b, Color(col, bright * k), (2.0 + w * k) * scale_k, true)
	# The kind's trail particles take the accent by the tier's mix (the blaster's always).
	var kt: Dictionary = _kind_trail
	var amount := float(kt.get("tint", 0.0)) * (1.0 if float(_k["body_tint"]) > 0.0 else float(_tl["mix"]))
	_draw_particles(self, _particles, kt, _trail_tex, Color.WHITE.lerp(_accent, amount) * _tint, scale_k, false)
	if _tier_on and not _tier_glows:
		_draw_tier_particles(self, scale_k)
	# The projectile.
	var rot := draw_angle()
	var pulse := body_pulse()
	draw_set_transform(Vector2.ZERO, rot, Vector2(1.0, -1.0 if flipped() else 1.0) * scale_k * pulse)
	var size := _body_size
	var body := body_color()
	if _exhaust: # behind the rocket: a flame stretched along the flight, flickering in length
		var flicker := 0.8 + 0.12 * sin(_t * 47.0) + 0.08 * sin(_t * 113.0)
		var flame := Vector2(20.0 * flicker, 11.0)
		draw_texture_rect(_spark, Rect2(EXHAUST - Vector2(flame.x * 0.65, flame.y / 2), flame), false, Color(1, 1, 1, 0.9) * _tint)
	draw_texture_rect(_tex, Rect2(-size / 2, size), false, body)
	if not _tier_body and float(_k["body_tint"]) == 0.0 and float(_tl["glow"]) > 0.0: # a sheen in the tier's colour on a solid shell
		var sheen: Color = ShotLook.prism(_t * 2.0) if _tl["prismatic"] else _accent
		draw_texture_rect(_glow, Rect2(-size * 0.4, size * 0.8), false, Color(sheen, 0.35 * float(_tl["glow"])))
	if _fuse:
		var flicker := 0.75 + 0.25 * sin(_t * 40.0)
		var spark := Vector2(14, 14) * flicker
		draw_texture_rect(_spark, Rect2(SPARK - spark / 2, spark), false)
	_draw_mark(minf(size.x, size.y) * 0.3)
	draw_set_transform(Vector2.ZERO)


## The overlay particles' colour: coins keep their own gold, the rest take the tier's colour.
func _tier_color() -> Color:
	return (Color.WHITE if str(_tier_fx.get("tex", "")) == "coin" else _accent2) * _tint


## The tier's (or its theme's) flight particles on ci: streaks, or puffs in its texture(s), in the
## theme's alternating colours (else the tier's).
func _draw_tier_particles(ci: CanvasItem, scale_k: float) -> void:
	if _tier_fx.get("mode", "") == "streak":
		_draw_streaks(ci, _tier_particles, _tier_fx, scale_k)
		return
	if _tier_fx.has("color"):
		_draw_particles(ci, _tier_particles, _tier_fx, _tier_tex, Color(_tier_fx["color"]) * _tint, scale_k, false,
			_tier_tex2 if _tier_tex2 != null else _tier_tex, Color(_tier_fx["color2"]) * _tint)
		return
	_draw_particles(ci, _tier_particles, _tier_fx, _tier_tex, _tier_color(), scale_k, _tl["prismatic"])


## Spark streaks: each a short line from where it is back along its speed (length s of it),
## falling with the spec's gravity, thinning and fading over its life; a soft white core.
func _draw_streaks(ci: CanvasItem, list: Array, spec: Dictionary, scale_k: float) -> void:
	var sizes: Array = spec["size"]
	var life: float = spec["life"]
	var g := float(spec.get("gravity", 0.0))
	var length := float(spec.get("length", 0.04))
	for q in list:
		var age: float = q[1]
		var f: float = age / life
		var v: Vector2 = q[4] + Vector2(0, g * age)
		var at: Vector2 = q[0] - global_position + Vector2(-_dir.y, _dir.x) * float(q[3]) + q[4] * age + Vector2(0, 0.5 * g * age * age)
		var w: float = lerpf(sizes[0], sizes[1], f) * scale_k
		var c: Color = Color(spec["color"] if q[2] < PI else spec["color2"]) * _tint
		var tail := at - v * length * (1.0 - 0.5 * f)
		ci.draw_line(tail, at, Color(c, (1.0 - f) * float(spec.get("alpha", 1.0))), w, true)
		ci.draw_line(tail.lerp(at, 0.5), at, Color(1, 1, 1, 0.8 * (1.0 - f)), maxf(1.0, w * 0.45), true)


## The theme's tail along the ribbon points (ci: the glow layer, behind the shell).
## light: a glowing streak, soft deep blue glows outside, ice ones inside, a white-cyan core
##   line, tapering and fading to the tail; fire: flame puffs from a hot white-yellow head through orange and red
##   to dark smoke at the tail, wavering sideways and flickering in size.
func _draw_ribbon(ci: CanvasItem, scale_k: float) -> void:
	var n := _ribbon.size() + 1 # the points, then the shell
	if n < 2:
		return
	var w := float(_ribbon_spec["width"]) * scale_k
	var style := str(_ribbon_spec["style"])
	if style == "light": # soft glows along the path (deep blue, then ice), a white-cyan core line
		for pass_i in 2:
			var col: Color = [ShotLook.ICE_DEEP, ShotLook.ICE][pass_i] * _tint
			var size_k: float = [1.15, 0.6][pass_i]
			var alpha_k: float = [0.45, 0.75][pass_i]
			for i in n:
				var k := float(i) / (n - 1) # 1 at the shell
				var r := w * size_k * (0.3 + 0.7 * k) * (0.94 + 0.06 * sin(_t * 31.0 + i * 1.7))
				var p: Vector2 = _ribbon_at(i) - global_position
				ci.draw_texture_rect(_glow, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, Color(col, alpha_k * k))
		_line_pts.resize(n)
		_line_cols.resize(n)
		for i in n:
			var k := float(i) / (n - 1)
			_line_pts[i] = _ribbon_at(i) - global_position
			_line_cols[i] = Color(ShotLook.ICE_WHITE * _tint, k * (0.9 + 0.1 * sin(_t * 41.0 + i)))
		ci.draw_polyline_colors(_line_pts, _line_cols, maxf(1.5, w * 0.28), true)
		return
	# fire: tail first, so the hot head is drawn over it.
	var side := Vector2(-_dir.y, _dir.x)
	for i in n:
		var k := float(i) / (n - 1) # 1 at the shell
		var p: Vector2 = _ribbon_at(i) - global_position
		var sway := side * sin(_t * 17.0 + i * 0.8) * w * 0.35 * (1.0 - k)
		var flick := 0.85 + 0.15 * sin(_t * 43.0 + i * 2.3) + 0.08 * sin(_t * 97.0 + i)
		var heat := k * k * (0.92 + 0.08 * sin(_t * 29.0 + i))
		var r := w * (0.55 + 0.75 * (1.0 - k)) * flick
		var c: Color = ShotLook.fire(heat) * _tint
		var tex := _glow if heat > 0.25 else _trail_smoke()
		var alpha := (0.25 + 0.7 * k) if heat > 0.25 else 0.45 * k + 0.08
		ci.draw_texture_rect(tex, Rect2(p + sway - Vector2(r, r), Vector2(r, r) * 2), false, Color(c, alpha))
	for i in range(int(n * 0.55), n): # the hot inner core near the shell
		var k := float(i) / (n - 1)
		var p: Vector2 = _ribbon_at(i) - global_position
		var r := w * 0.42 * (0.6 + 0.4 * k) * (0.9 + 0.1 * sin(_t * 61.0 + i))
		ci.draw_texture_rect(_glow, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, Color(ShotLook.fire(1.0) * _tint, 0.75 * k))


## Ribbon point i, local to the shell's parent space (global); past the points: the shell.
func _ribbon_at(i: int) -> Vector2:
	return _ribbon[i] if i < _ribbon.size() else global_position


func _trail_smoke() -> Texture2D:
	return Art.fx("smoke")


## The glowing parts behind the projectile (normal blending, so they read on the bright sky too):
## the halo (tier glow, brighter for a skill shot) and the sparkle / ember trail.
func _draw_glow() -> void:
	var scale_k := _scale_k()
	if not _ribbon_spec.is_empty():
		_draw_ribbon(_glow_layer, scale_k)
	if _tier_on and _tier_glows:
		_draw_tier_particles(_glow_layer, scale_k)
	var glow := float(_tl["glow"]) + (ShotLook.SKILL_GLOW if skill else 0.0)
	if glow <= 0.0:
		return
	var g := (16.0 + 18.0 * glow) * scale_k
	var c: Color = ShotLook.prism(_t * 2.0) if _tl["prismatic"] else _accent
	var pulse := 0.8 + 0.2 * sin(_t * 20.0)
	_glow_layer.draw_texture_rect(_glow, Rect2(-Vector2(g, g), Vector2(g, g) * 2), false, Color(c * _tint, minf(0.8, 0.5 * glow) * pulse))
	if int(_tl["rank"]) >= 6 or skill: # a hot white core for the grandest guns
		var h := g * 0.45
		_glow_layer.draw_texture_rect(_glow, Rect2(-Vector2(h, h), Vector2(h, h) * 2), false, Color(1, 1, 1, 0.35 * pulse))


## Draws trail particles (spec: life, size, alpha, drift, spin, optional hot / cool / cool_at)
## with tex in color (prismatic: each its own rainbow colour), times its hot-to-cool colour, on ci;
## with tex2: every other one (by its random angle) in tex2 and color2.
func _draw_particles(ci: CanvasItem, list: Array, spec: Dictionary, tex: Texture2D, color: Color, scale_k: float, prismatic: bool,
		tex2: Texture2D = null, color2: Color = Color.WHITE) -> void:
	if list.is_empty() or tex == null:
		return
	var sizes: Array = spec["size"]
	var life: float = spec["life"]
	var alpha := float(spec.get("alpha", 1.0))
	var hot = spec.get("hot")
	var cool_at := maxf(0.001, float(spec.get("cool_at", 1.0)))
	for q in list:
		var f: float = q[1] / life
		var r: float = lerpf(sizes[0], sizes[1], f) * scale_k
		var side := Vector2(-_dir.y, _dir.x) * float(q[3])
		var at: Vector2 = q[0] - global_position + side + Vector2(0, float(spec.get("drift", 0.0)) * q[1]) + q[4] * q[1]
		var second: bool = tex2 != null and q[2] >= PI
		var c: Color = ShotLook.prism(q[2] / TAU + _t) if prismatic else (color2 if second else color)
		if hot != null:
			c *= Color(hot).lerp(spec["cool"], minf(1.0, f / cool_at))
		ci.draw_set_transform(at, q[2] + q[1] * float(spec.get("spin", 0.0)), Vector2.ONE)
		ci.draw_texture_rect(tex2 if second else tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(c, alpha * (1.0 - f)))
	ci.draw_set_transform(Vector2.ZERO)


## The item's mark over the projectile (in its rotated frame); r about the projectile radius.
func _draw_mark(r: float) -> void:
	match _mark:
		"web":
			var c := Color(1, 1, 1, 0.9)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, c, 1.5, true)
			draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 12, c, 1.2, true)
			for i in 4:
				var d := Vector2.from_angle(PI * i / 4.0) * r * 1.15
				draw_line(-d, d, c, 1.2, true)
		"spiral":
			var pts := PackedVector2Array()
			for i in 18:
				var a := i * 0.7 + _t * 18.0
				pts.append(Vector2.from_angle(a) * r * (0.15 + 0.85 * i / 17.0))
			draw_polyline(pts, Color(0.3, 0.3, 0.35, 0.95), 2.0, true)
		"frost":
			draw_arc(Vector2.ZERO, r * 1.3, 0.0, TAU, 20, Color(0.8, 0.95, 1.0, 0.7), 2.5, true)
			for i in 3:
				var d := Vector2.from_angle(PI * i / 3.0) * r * 0.9
				draw_line(-d, d, Color(1, 1, 1, 0.85), 1.5, true)
