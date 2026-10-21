extends "res://match/views/projectile_view.gd"
## A Hoa hồi xuân seed in flight (bloom.gd projectile_view()): the gun's own shell exactly as a
## normal shot draws it (the tier's shell picture, size, spin, flicker, sheen and item marks, so
## the gun tier still reads), but at EVERY tier (basic, the four normal ones, the crafted ones and
## the Blaster alike) a healing trail instead of the tier's flight theme and the kind's trail:
## - a soft green light streak along its recent path (deep green outside, light green inside, a
##   white-green core line), tapering to the tail (instead of the dragon's fire tail, the
##   mithril's ice light, ...);
## - green-white sparkles and soft green motes shed behind it (instead of the tier's embers,
##   smoke, sparks, coins, shards);
## - little leaves falling off it (instead of the kind's petals);
## - a green halo with only a faint touch of the tier's accent (TIER_HINT).
## No line trail. Normal shots keep shot_look.gd's looks (only this view changes them).

const HEAL_DEEP := Color(0.14, 0.6, 0.22)
const HEAL := Color(0.45, 0.95, 0.4)
const HEAL_LIGHT := Color(0.7, 1.0, 0.58)
const HEAL_WHITE := Color(0.93, 1.0, 0.86)
const LEAF_COLOR := Color(0.36, 0.8, 0.3)
const LEAF_VEIN := Color(0.72, 1.0, 0.55)
const TIER_HINT := 0.15 # how much of the tier's accent the halo takes
const HALO_MIN := 0.5 # the halo at least this strong (the tier glow scale), skill boost on top
## The healing light streak (the ribbon), its points kept like the tier themes'.
const RIBBON := {"style": "heal", "points": 28, "every": 8.0, "width": 18.0}
## Green-white sparkles and soft green motes (every other one), drawn behind the shell.
const SPARKLES := {"mode": "puff", "tex": "sparkle", "tex2": "glow", "every": 9.0, "life": 0.6, "size": [9.0, 2.5], "alpha": 1.0,
	"drift": 14.0, "jitter": 10.0, "spin": 4.0, "color": HEAL_WHITE, "color2": HEAL_LIGHT, "glow": true}
## Little leaves falling off (the leaf texture in its own colours: tint 0).
const LEAVES := {"every": 34.0, "life": 0.55, "size": [6.5, 4.0], "alpha": 0.95, "drift": 40.0, "jitter": 13.0, "spin": 6.0, "tint": 0.0}
const LEAF_PX := 32

static var _leaf_cache: ImageTexture


## The settings of the view ShotPlayer made (kind, tier, skill, item, heading, size, trail).
func copy_from(view: Node2D) -> void:
	for p in ["kind", "tier", "skill", "item", "heading", "size_k", "trail_length"]:
		set(p, view.get(p))


func _ready() -> void:
	super()
	_k = _k.duplicate()
	_k["line"] = null # the light streak is its trail
	_kind_trail = _shorter(LEAVES) if trail_length < 1.0 else LEAVES
	_trail_tex = leaf_texture()
	_tier_fx = _shorter(SPARKLES) if trail_length < 1.0 else SPARKLES
	_tier_tex = overlay_texture(str(_tier_fx["tex"]))
	_tier_tex2 = overlay_texture(str(_tier_fx["tex2"]))
	_tier_glows = true
	_tier_on = _tier_tex != null
	_ribbon_spec = RIBBON.duplicate()
	if trail_length < 1.0:
		_ribbon_spec["points"] = maxi(4, int(float(RIBBON["points"]) * trail_length))
	if _ribbon.is_empty():
		_ribbon.append(global_position)


## The halo's colour: green with a faint touch of the tier's accent (its rainbow when prismatic).
func halo_color() -> Color:
	var hint: Color = ShotLook.prism(_t * 2.0) if _tl["prismatic"] else _accent
	return HEAL.lerp(hint, TIER_HINT)


## Behind the shell: the light streak, the sparkles and the green halo with a white-green heart.
func _draw_glow() -> void:
	var scale_k := _scale_k()
	_draw_ribbon(_glow_layer, scale_k)
	if _tier_on:
		_draw_tier_particles(_glow_layer, scale_k)
	var glow := maxf(HALO_MIN, float(_tl["glow"])) + (ShotLook.SKILL_GLOW if skill else 0.0)
	var g := (16.0 + 18.0 * glow) * scale_k
	var pulse := 0.8 + 0.2 * sin(_t * 20.0)
	_glow_layer.draw_texture_rect(_glow, Rect2(-Vector2(g, g), Vector2(g, g) * 2), false, Color(halo_color() * _tint, minf(0.8, 0.5 * glow) * pulse))
	var h := g * 0.45
	_glow_layer.draw_texture_rect(_glow, Rect2(-Vector2(h, h), Vector2(h, h) * 2), false, Color(HEAL_WHITE * _tint, 0.4 * pulse))


## The healing light streak: soft glows along the path (deep green, then light green), a
## white-green core line, tapering and fading to the tail, gently shimmering.
func _draw_ribbon(ci: CanvasItem, scale_k: float) -> void:
	var n := _ribbon.size() + 1 # the points, then the shell
	if n < 2:
		return
	var w := float(_ribbon_spec["width"]) * scale_k
	for pass_i in 2:
		var col: Color = [HEAL_DEEP, HEAL_LIGHT][pass_i] * _tint
		var r_k: float = [1.15, 0.6][pass_i]
		var alpha_k: float = [0.5, 0.8][pass_i]
		for i in n:
			var k := float(i) / (n - 1) # 1 at the shell
			var r := w * r_k * (0.3 + 0.7 * k) * (0.92 + 0.08 * sin(_t * 23.0 + i * 1.3))
			var p: Vector2 = _ribbon_at(i) - global_position
			ci.draw_texture_rect(_glow, Rect2(p - Vector2(r, r), Vector2(r, r) * 2), false, Color(col, alpha_k * k))
	_line_pts.resize(n)
	_line_cols.resize(n)
	for i in n:
		var k := float(i) / (n - 1)
		_line_pts[i] = _ribbon_at(i) - global_position
		_line_cols[i] = Color(HEAL_WHITE * _tint, k * (0.85 + 0.15 * sin(_t * 37.0 + i)))
	ci.draw_polyline_colors(_line_pts, _line_cols, maxf(1.5, w * 0.26), true)


## A small leaf (LEAF_PX square, pointing +x) in LEAF_COLOR with a lighter vein, made once.
static func leaf_texture() -> Texture2D:
	if _leaf_cache != null:
		return _leaf_cache
	var img := Image.create(LEAF_PX, LEAF_PX, false, Image.FORMAT_RGBA8)
	var half := LEAF_PX / 2.0
	for y in LEAF_PX:
		for x in LEAF_PX:
			var u := (x + 0.5) / LEAF_PX # 0 stem .. 1 tip
			var v := (y + 0.5 - half) / half # -1 .. 1 across
			var width := 0.78 * sin(PI * u) * (1.0 - 0.3 * u) # the leaf's half width at u
			if width <= 0.0:
				continue
			var d := absf(v) / width # 0 on the vein .. 1 on the edge
			var a := clampf((1.0 - d) * width * half, 0.0, 1.0) # anti-aliased edge
			if a <= 0.0:
				continue
			var c := LEAF_COLOR.lerp(LEAF_VEIN, clampf(1.0 - absf(v) * half / 1.2, 0.0, 1.0) * 0.8)
			c = c.lerp(LEAF_COLOR.darkened(0.25), clampf(d - 0.6, 0.0, 0.4))
			img.set_pixel(x, y, Color(c, a))
	_leaf_cache = ImageTexture.create_from_image(img)
	return _leaf_cache
