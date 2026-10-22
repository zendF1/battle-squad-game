extends Node2D
## An impact, drawn the way the shooter's GUN hits (match/views/shot_look.gd; set radius, kind,
## tier and skill before adding it). The kind is the theme: its burst frames
## (assets/fx/<kind>/impact_0..N.png, scaled to the crater radius) with smoke and bits flying out
## - bazooka a fire explosion, cannon a heavy blast with more debris, shock_rifle an electric
## burst with sparks, seed_launcher a petal burst, blaster an energy burst. The tier is the
## intensity, from the shared overlays (assets/fx/tiers/): a bigger burst, a glow flash in its
## colour, shockwave rings (dragon up; titan and diamond two, diamond's in rainbow colours),
## sparkles, embers, gold coins, crystal shards, a lens flare, titan's ground cracks and a screen
## tint for titan and diamond; diamond's sparkles linger. The kind's size (ShotLook.impact_size,
## the cannon 0.75) shrinks the whole impact: everything drawn for the radius (burst, flash,
## rings, smoke, cracks, flare) and how far the debris and particles fly. Particles stay within
## ShotLook.MAX_IMPACT_PARTICLES. The match camera shakes a little for it (match_screen:
## CameraModel.shake(radius)); its screen tint covers the camera's view (the canvas transform).
## Visuals only: the crater and the radius come from the server. It frees itself when
## its last effect is over. `lite` (one of many quick impacts, the missile rain's) keeps it cheap:
## LITE_PARTICLES of the particles, at most one ring, no screen tint, lens flare, cracks or
## lingering sparkles.
## Its colours follow the SHELL (ShotLook.burst_palette(kind, tier)): the burst frames are
## gradient-mapped onto the palette's smoke -> outer -> mid -> core by their luminance, the kind's
## sparks / petals tinted by it, the flash, rings, sparkles and embers, the debris (shrapnel, ice
## chips, lava) and subtly the smoke take it, and a lava palette (dragon) throws half its embers as
## heavy glowing blobs (diamond's flash and screen tint too; its rings, sparkles and shards stay
## rainbow). The shape stays the kind's. One ShaderMaterial per kind × tier, cached
## (draws whose UV is moved by MAP_UV / TINT_UV are recoloured, the rest drawn as usual); basic
## and a tier with no palette keep the kind's own colours (no material).

const Art := preload("res://ui/art.gd")
const ShotLook := preload("res://match/views/shot_look.gd")

const LIFE := 1.1
const GRAVITY := 900.0
const BURST_SEC := 0.5 # the frames play over this time
const FLASH_SEC := 0.35
const RING_SEC := 0.55
const SCREEN_SEC := 0.3
const CRACK_FADE := 0.8 # s the ground cracks take to fade at the end
const LITE_PARTICLES := 0.35 # a lite impact's share of the particles
## A draw whose source rect is moved by this many texture sizes is gradient-mapped onto the
## palette (the frames), by TINT_UV brightened to grey and tinted (the kind's sparks / petals).
const MAP_UV := 2.0
const TINT_UV := 4.0
## Where the ramp's stops sit along the frames' normalised luminance: smoke 0, outer, mid, core 1.
const RAMP_OUTER := 0.4
const RAMP_MID := 0.75
const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 smoke_c;
uniform vec4 outer_c;
uniform vec4 mid_c;
uniform vec4 core_c;
uniform vec2 lum = vec2(0.0, 1.0);
uniform vec2 ramp = vec2(0.4, 0.75);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	if (UV.x > 1.5) {
		bool map = UV.x < 3.5;
		vec4 c = texture(TEXTURE, UV - vec2(map ? 2.0 : 4.0));
		float l = clamp((dot(c.rgb, vec3(0.299, 0.587, 0.114)) - lum.x) / max(lum.y - lum.x, 0.001), 0.0, 1.0);
		vec3 g = vec3(0.75 + 0.25 * l);
		if (map) {
			if (l < ramp.x) {
				g = mix(smoke_c.rgb, outer_c.rgb, l / ramp.x);
			} else if (l < ramp.y) {
				g = mix(outer_c.rgb, mid_c.rgb, (l - ramp.x) / (ramp.y - ramp.x));
			} else {
				g = mix(mid_c.rgb, core_c.rgb, (l - ramp.y) / (1.0 - ramp.y));
			}
		}
		COLOR = vec4(g, c.a) * tint;
	}
}
"""

static var _shader: Shader
static var _materials := {} # "kind/tier" -> ShaderMaterial (burst_material())

var radius := 30.0
var kind := ShotLook.DEFAULT_KIND
var tier := ShotLook.DEFAULT_TIER
var skill := false
var lite := false

var _k: Dictionary # ShotLook.KINDS[kind]["impact"]
var _ti: Dictionary # ShotLook.TIERS[tier]["impact"]
var _prismatic := false
var _accent := Color.WHITE
var _accent2 := Color.WHITE
var _pal := {} # ShotLook.burst_palette(kind, tier); {} the kind's own colours
var _spark := Color.WHITE # sparkles (two of three) and embers
var _spark2 := Color.WHITE
var _smoke_color := Color.WHITE
var _scale := 1.0 # burst scale (ShotLook.impact_scale)
var _size := 1.0 # the kind's whole-impact size (ShotLook.impact_size): the drawn radius and the spread
var _r := 30.0 # the drawn radius: radius × _size
var _life := LIFE
var _t := 0.0
var _smoke: Array = [] # [offset, size, drift, spin]
var _debris: Array = [] # [velocity, size, color, spin]
## Overlay particles: [velocity, size, color, spin, life, gravity factor, twinkle phase]
var _sparkles: Array = []
var _embers: Array = []
var _coins: Array = []
var _shards: Array = []
var _frames: Array[Texture2D] = []
var _frame_tint := Color.WHITE
var _smoke_tex: Texture2D
var _debris_tex: Texture2D
var _fx := {} # TIER_FX name -> Texture2D (null: missing, left out)
var _glow_layer: Node2D # over the burst: flash, rings, sparkles, embers, flare, screen tint
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	kind = ShotLook.known_kind(kind)
	tier = ShotLook.known_tier(tier)
	var kd: Dictionary = ShotLook.KINDS[kind]
	_k = kd["impact"]
	_ti = ShotLook.TIERS[tier]["impact"]
	_prismatic = bool(ShotLook.TIERS[tier]["prismatic"])
	_accent = ShotLook.accent(kind, tier)
	_accent2 = ShotLook.accent2(kind, tier)
	_spark = _accent2
	_spark2 = _accent
	_smoke_color = _k["smoke_color"]
	_pal = ShotLook.burst_palette(kind, tier)
	if not _pal.is_empty():
		_accent = _pal["flash"]
		_accent2 = _pal["spark2"]
		_spark = _pal["spark"]
		_spark2 = _pal["spark2"]
		_smoke_color = _pal["smoke_color"]
		material = burst_material(kind, tier)
	_scale = ShotLook.impact_scale(kind, tier, skill)
	_size = ShotLook.impact_size(kind)
	_r = radius * _size
	_life = LIFE if lite else ShotLook.impact_life(tier, LIFE)
	for i in Art.EXPLOSION_FRAMES:
		_frames.append(Art.shot(kind, "impact_%d" % i, Art.explosion(i)))
	var mix := float(ShotLook.TIERS[tier]["mix"])
	_frame_tint = Color.WHITE.lerp(_accent, maxf(float(_k.get("frame_tint", 0.0)), 0.25 * mix))
	_smoke_tex = Art.fx("smoke")
	_debris_tex = Art.fx("debris") if _k["bit_image"] == "debris" else Art.shot(kind, "trail", Art.fx("debris"))
	for fx_name in Art.TIER_FX:
		_fx[fx_name] = Art.tier_fx(fx_name)
	if _fx["glow"] == null:
		_fx["glow"] = Art.fx("muzzle")
	_rng.randomize()
	var counts := ShotLook.impact_counts(kind, tier, skill)
	if lite:
		for g in counts:
			counts[g] = int(floor(counts[g] * LITE_PARTICLES))
	for i in int(counts["smoke"]):
		var off := Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.6, 0.1)) * _r
		_smoke.append([off, _rng.randf_range(0.4, 0.7), Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-70, -35)), _rng.randf_range(-1.0, 1.0)])
	var colors: Array = _k["colors"]
	if not _pal.is_empty():
		colors = _bit_colors()
	var speed: Array = _k["speed"]
	var bit: Array = _k["bit_size"]
	var bit_tint := _accent if float(kd["body_tint"]) > 0.0 and _pal.is_empty() else Color.WHITE
	for i in int(counts["bits"]):
		var a := _rng.randf_range(-PI * 0.95, -PI * 0.05) # mostly upward
		_debris.append([Vector2.from_angle(a) * _rng.randf_range(speed[0], speed[1]) * sqrt(_scale), _rng.randf_range(bit[0], bit[1]),
			Color(colors[i % colors.size()]) * bit_tint, _rng.randf_range(-12.0, 12.0)])
	var linger := 0.0 if lite else float(_ti["linger"])
	for i in int(counts["sparkles"]):
		var slow := linger > 0.0 and i % 2 == 0 # half of diamond's sparkles hang in the air
		var life := (0.7 + linger) * _rng.randf_range(0.8, 1.0) if slow else _rng.randf_range(0.55, 0.85)
		_sparkles.append(_particle(-PI, PI, [40.0, 120.0] if slow else [140.0, 380.0], [3.0, 7.0], _spark if i % 3 else _spark2, life, 0.05 if slow else 0.2))
	var lava := bool(_pal.get("lava", false))
	for i in int(counts["embers"]):
		if lava and i % 2 == 0: # a heavy glowing lava blob: thrown up, falling back
			var c: Color = Color(_pal["mid"]).lerp(_pal["core"], _rng.randf_range(0.0, 0.6))
			_embers.append(_particle(-PI * 0.85, -PI * 0.15, [200.0, 420.0], [7.5, 12.0], c, _rng.randf_range(0.85, 1.1), 1.0))
		else:
			_embers.append(_particle(-PI * 0.95, -PI * 0.05, [150.0, 420.0], [3.0, 6.0], _spark2 if i % 2 else _spark, _rng.randf_range(0.7, 1.05), 0.35))
	for i in int(counts["coins"]):
		_coins.append(_particle(-PI * 0.9, -PI * 0.1, [220.0, 460.0], [4.5, 6.5], Color.WHITE, LIFE, 1.0))
	for i in int(counts["shards"]):
		_shards.append(_particle(-PI, 0.1, [220.0, 520.0], [5.0, 9.0], Color.WHITE, LIFE, 0.6))
	_glow_layer = Node2D.new()
	_glow_layer.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_glow_layer.draw.connect(_draw_glow)
	add_child(_glow_layer)


## The cached ShaderMaterial of kind × tier's burst palette (null: no palette).
static func burst_material(kind: String, tier: String) -> ShaderMaterial:
	kind = ShotLook.known_kind(kind)
	tier = ShotLook.known_tier(tier)
	var key := kind + "/" + tier
	if _materials.has(key):
		return _materials[key]
	var pal := ShotLook.burst_palette(kind, tier)
	var m: ShaderMaterial = null
	if not pal.is_empty():
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER_CODE
		m = ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("smoke_c", pal["smoke"])
		m.set_shader_parameter("outer_c", pal["outer"])
		m.set_shader_parameter("mid_c", pal["mid"])
		m.set_shader_parameter("core_c", pal["core"])
		var lum: Array = ShotLook.KINDS[kind]["impact"].get("lum", [0.0, 1.0])
		m.set_shader_parameter("lum", Vector2(lum[0], lum[1]))
		m.set_shader_parameter("ramp", Vector2(RAMP_OUTER, RAMP_MID))
	_materials[key] = m
	return m


## The debris colours under a palette: the kind's dirt with the palette's bits between (shrapnel,
## ice chips, lava), or for sparks / petals (the kind's trail image) the palette's sparks.
func _bit_colors() -> Array:
	if _k["bit_image"] != "debris":
		return [_pal["spark"], _pal["spark2"], _pal["mid"]]
	var bits: Array = _pal["bits"]
	if bits.is_empty():
		return _k["colors"]
	var out: Array = []
	for i in 6:
		out.append(bits[(i >> 1) % bits.size()] if i % 2 else _k["colors"][(i >> 1) % _k["colors"].size()])
	return out


## An overlay particle thrown at an angle in [a0, a1] (radians, -PI/2 = up), speed and size
## ranges, colour, life (s) and gravity factor.
func _particle(a0: float, a1: float, speed: Array, size: Array, color: Color, life: float, gravity: float) -> Array:
	var v := Vector2.from_angle(_rng.randf_range(a0, a1)) * _rng.randf_range(speed[0], speed[1]) * sqrt(_scale)
	return [v, _rng.randf_range(size[0], size[1]) * sqrt(_scale), color, _rng.randf_range(-10.0, 10.0), life, gravity, _rng.randf() * TAU]


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	queue_redraw()
	_glow_layer.queue_redraw()


func _draw() -> void:
	var t := _t
	if _ti["crack"] and not lite: # ground cracks: under everything, fading at the end
		var tex: Texture2D = _fx["crack"]
		if tex != null:
			var a := clampf(t / 0.08, 0.0, 1.0) * clampf((_life - t) / CRACK_FADE, 0.0, 1.0)
			var r := _r * 1.9 * _scale
			draw_texture_rect(tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(1, 1, 1, 0.85 * a))
	# Smoke (behind the fire), from 0.08 s: grows, drifts up, fades.
	if t > 0.08 and t < LIFE:
		var s := (t - 0.08) / (LIFE - 0.08)
		var sc := _smoke_color
		for p in _smoke:
			var at: Vector2 = p[0] + p[2] * (t - 0.08) * _size
			var r: float = _r * p[1] * (0.8 + s * 0.9) * 1.25 * sqrt(_scale)
			draw_set_transform(at, p[3] * s, Vector2.ONE)
			draw_texture_rect(_smoke_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(sc, sc.a * (1.0 - s)))
		draw_set_transform(Vector2.ZERO)
	# The burst frames.
	if t < BURST_SEC and not _frames.is_empty():
		var i := mini(int(t / BURST_SEC * _frames.size()), _frames.size() - 1)
		var tex := _frames[i]
		var k := _r / Art.EXPLOSION_RADIUS * _scale
		var sz := tex.get_size() * k
		if _pal.is_empty():
			draw_texture_rect(tex, Rect2(-sz / 2, sz), false, _frame_tint)
		else:
			draw_texture_rect_region(tex, Rect2(-sz / 2, sz), Rect2(tex.get_size() * MAP_UV, tex.get_size()), Color.WHITE, false, false)
	# Debris / sparks / petals.
	if t < LIFE:
		var g := GRAVITY * float(_k["gravity"])
		var a := clampf(1.0 - t / LIFE, 0.0, 1.0)
		var tinted: bool = not _pal.is_empty() and _k["bit_image"] != "debris" # sparks / petals in the palette
		var src := Rect2(_debris_tex.get_size() * TINT_UV, _debris_tex.get_size())
		for d in _debris:
			var at: Vector2 = (d[0] * t + Vector2(0, 0.5 * g * t * t)) * _size
			var r: float = d[1] * 1.4
			draw_set_transform(at, d[3] * t, Vector2.ONE)
			if tinted:
				draw_texture_rect_region(_debris_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), src, Color(d[2], a), false, false)
			else:
				draw_texture_rect(_debris_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(d[2], a))
		draw_set_transform(Vector2.ZERO)
	_draw_particles(self, _coins, _fx["coin"], t, false)
	_draw_particles(self, _shards, _fx["shard"], t, _prismatic)


## The glowing parts over the burst (normal blending, so they keep their colour on the bright
## sky): the screen tint, the flash, the shockwave rings, sparkles, embers and the lens flare.
func _draw_glow() -> void:
	var t := _t
	var ci := _glow_layer
	var screen := 0.0 if lite else float(_ti["screen"]) * (1.25 if skill else 1.0)
	if screen > 0.0 and t < SCREEN_SEC:
		var view := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
		var c: Color = ShotLook.prism(t * 2.0) if _prismatic and _pal.is_empty() else _accent
		ci.draw_rect(view, Color(c, screen * (1.0 - t / SCREEN_SEC)))
	var flash := float(_ti["flash"]) + (0.3 if skill else 0.0)
	var glow: Texture2D = _fx["glow"]
	if flash > 0.0 and t < FLASH_SEC:
		var k := t / FLASH_SEC
		var r := _r * (1.6 + 1.2 * ease(k, 0.3)) * _scale
		var c: Color = ShotLook.prism(t) if _prismatic and _pal.is_empty() else _accent
		ci.draw_texture_rect(glow, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(c, 0.6 * minf(1.0, flash) * (1.0 - k)))
		if t < 0.12:
			var h := _r * 0.9 * _scale
			ci.draw_texture_rect(glow, Rect2(-Vector2(h, h), Vector2(h, h) * 2), false, Color(1, 1, 1, 0.8 * minf(1.0, flash) * (1.0 - t / 0.12)))
	var ring: Texture2D = _fx["ring"]
	if ring != null:
		for j in mini(int(_ti["rings"]), 1) if lite else int(_ti["rings"]):
			var rt := t - j * 0.09
			if rt < 0.0 or rt > RING_SEC:
				continue
			var k := rt / RING_SEC
			var r := _r * (0.5 + (1.6 + 0.35 * j) * ease(k, 0.4)) * _scale
			var c: Color = ShotLook.prism(k + j * 0.33) if _prismatic else (_accent if j == 0 else _accent2)
			ci.draw_texture_rect(ring, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(c, 0.9 * (1.0 - k)))
	_draw_particles(ci, _sparkles, _fx["sparkle"], t, _prismatic, true)
	_draw_particles(ci, _embers, _fx["ember"], t, false)
	var flare_k := 0.0 if lite else float(_ti["flare"])
	var flare: Texture2D = _fx["flare"]
	if flare_k > 0.0 and flare != null and t < 0.45:
		var pop := sin(PI * t / 0.45)
		var w := _r * 3.2 * flare_k * _scale * (0.6 + 0.4 * pop)
		var c: Color = Color.WHITE.lerp(_accent2, 0.35)
		ci.draw_texture_rect(flare, Rect2(-Vector2(w, w), Vector2(w, w) * 2), false, Color(c, 0.9 * pop))


## Draws overlay particles (_particle()) with tex on ci at time t: thrown out, pulled by gravity
## times their factor, turning, fading over their life; twinkle: the alpha flickers (sparkles).
func _draw_particles(ci: CanvasItem, list: Array, tex: Texture2D, t: float, prismatic: bool, twinkle: bool = false) -> void:
	if tex == null or list.is_empty():
		return
	for q in list:
		var life: float = q[4]
		if t >= life:
			continue
		var g := GRAVITY * float(q[5])
		var slow := 1.0 / (1.0 + t * 1.5) # air drag: they slow down
		var at: Vector2 = (q[0] * t * slow + Vector2(0, 0.5 * g * t * t)) * _size
		var f := t / life
		var a := 1.0 - f * f
		if twinkle:
			a *= 0.55 + 0.45 * sin(q[6] + t * 22.0)
		var c: Color = ShotLook.prism(q[6] / TAU + t * 0.8) if prismatic else q[2]
		var r: float = q[1]
		ci.draw_set_transform(at, q[3] * t, Vector2.ONE)
		ci.draw_texture_rect(tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(c, a))
	ci.draw_set_transform(Vector2.ZERO)
