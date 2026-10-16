extends Node2D
## A shell in flight (moved by shot_player.gd), drawn the way the shooter's GUN fires it
## (match/views/shot_look.gd: `kind` = the bullet and its trail, `tier` = how grand):
## - bazooka: the bomb (fuse spark from assets/fx/common/muzzle.png) with a warm line trail;
## - cannon: a heavy iron ball with a grey smoke trail;
## - shock_rifle: a flickering plasma orb with an electric trail and sparks;
## - seed_launcher: a spinning seed pod with a petal trail;
## - blaster: an energy bolt in the accent colour with a short streak.
## The tier blends its colour into the trail, adds a glow halo (steel up) and its overlay
## particles (assets/fx/tiers/: mithril / silver sparkles, dragon / titan embers, gold coins,
## diamond crystal shards in rainbow colours). Images via ui/art.gd (assets/fx/<kind>/, falling
## back to the bomb). A skill shot is drawn larger and brighter; an item shot is tinted and marked
## by the item on top (ITEM_LOOKS). Set kind / tier / skill / item before adding it. Visuals
## only: the server path moves it.

const Art := preload("res://ui/art.gd")
const ShotLook := preload("res://match/views/shot_look.gd")

const TRAIL := 10 # positions kept for the line trail
const BOMB_PX := 2.0 # projectile image px per world px
const SPARK := Vector2(-11, -3) # the bomb's fuse tip, world px from its centre (flying +x)
## Overlay trail particles drawn behind the projectile with its halo; coins and shards fly over it.
const GLOWING_FX := ["sparkle", "ember"]
## item id -> tint of the projectile and its trail, and a mark drawn over it ("" none).
const ITEM_LOOKS := {
	"freeze_bomb": {"tint": Color(0.62, 0.86, 1.0), "mark": "frost"},
	"spider_net": {"tint": Color(0.95, 0.95, 1.0), "mark": "web"},
	"drill_bomb": {"tint": Color(0.72, 0.72, 0.78), "mark": "spiral"},
	"power_shot": {"tint": Color(1.0, 0.62, 0.42), "mark": ""},
	"teleport": {"tint": Color(0.8, 0.62, 1.0), "mark": ""},
}

var kind := ShotLook.DEFAULT_KIND
var tier := ShotLook.DEFAULT_TIER
var skill := false
var item := ""

var _k: Dictionary # ShotLook.KINDS[kind]
var _tl: Dictionary # ShotLook.TIERS[tier]
var _accent := Color.WHITE
var _accent2 := Color.WHITE
var _trail := PackedVector2Array() # global positions, oldest first
var _particles: Array = [] # the kind's trail: [global position, age, angle, sideways offset]
var _tier_particles: Array = [] # the tier's overlay trail: the same
var _since_particle := 0.0 # world px travelled since the last kind particle
var _since_tier := 0.0
var _dir := Vector2.RIGHT
var _t := 0.0
var _tex: Texture2D
var _trail_tex: Texture2D
var _tier_tex: Texture2D
var _tier_glows := false
var _spark: Texture2D
var _glow: Texture2D
var _tint := Color.WHITE
var _mark := ""
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
	_tex = Art.shot(kind, "projectile", Art.fx("bomb"))
	_spark = Art.fx("muzzle")
	_trail_tex = Art.shot(kind, "trail", Art.fx("smoke"))
	var fx: Dictionary = _tl["trail_fx"]
	if not fx.is_empty():
		_tier_tex = Art.tier_fx(str(fx["tex"]))
		_tier_glows = GLOWING_FX.has(str(fx["tex"]))
	_glow = Art.tier_fx("glow")
	if _glow == null:
		_glow = _spark
	var look: Dictionary = ITEM_LOOKS.get(item, {})
	_tint = look.get("tint", Color.WHITE)
	_mark = look.get("mark", "")
	_rng.randomize()
	_trail.append(global_position)
	_glow_layer = Node2D.new()
	_glow_layer.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_glow_layer.show_behind_parent = true
	_glow_layer.draw.connect(_draw_glow)
	add_child(_glow_layer)


func _process(delta: float) -> void:
	_t += delta
	var p := global_position
	var moved := 0.0
	if _trail.is_empty() or p.distance_squared_to(_trail[-1]) > 0.25:
		var v := p - _trail[-1] if not _trail.is_empty() else Vector2.ZERO
		if v.length_squared() > 0.01:
			_dir = v.normalized()
		moved = v.length()
		_trail.append(p)
		if _trail.size() > TRAIL:
			_trail.remove_at(0)
	_since_particle += moved
	_particles = _emit(_particles, _k["trail"], delta, p, "_since_particle", ShotLook.TRAIL_KIND_CAP)
	if _tier_tex != null:
		_since_tier += moved
		_tier_particles = _emit(_tier_particles, _tl["trail_fx"], delta, p, "_since_tier", ShotLook.TRAIL_TIER_CAP)
	queue_redraw()
	_glow_layer.queue_redraw()


## Ages a trail's particles, drops the dead ones, adds one every `every` px travelled (the
## distance counter is the property named `counter`) and keeps at most `cap` (the oldest go).
func _emit(list: Array, spec: Dictionary, delta: float, at: Vector2, counter: String, cap: int) -> Array:
	var life: float = spec["life"]
	for q in list:
		q[1] += delta
	list = list.filter(func(q): return q[1] < life)
	var every: float = spec["every"]
	var travelled: float = get(counter)
	while travelled >= every:
		travelled -= every
		list.append([at, 0.0, _rng.randf() * TAU, _rng.randf_range(-1.0, 1.0) * float(spec.get("jitter", 0.0))])
	set(counter, travelled)
	if list.size() > cap:
		list = list.slice(list.size() - cap)
	return list


func _scale_k() -> float:
	return float(_tl["scale"]) * (ShotLook.SKILL_SCALE if skill else 1.0)


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
			draw_line(a, b, Color(col, bright * k), 2.0 + w * k * scale_k, true)
	# The kind's trail particles take the accent by the tier's mix (the blaster's always).
	var kt: Dictionary = _k["trail"]
	var amount := float(kt.get("tint", 0.0)) * (1.0 if float(_k["body_tint"]) > 0.0 else float(_tl["mix"]))
	_draw_particles(self, _particles, kt, _trail_tex, Color.WHITE.lerp(_accent, amount) * _tint, scale_k, false)
	if _tier_tex != null and not _tier_glows:
		_draw_particles(self, _tier_particles, _tl["trail_fx"], _tier_tex, _tier_color(), scale_k, _tl["prismatic"])
	# The projectile.
	var rot := _dir.angle() + _t * float(_k["spin"])
	var pulse := 1.0 + (0.12 * sin(_t * 45.0) if _k["flicker"] else 0.0)
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE * scale_k * pulse)
	var size := _tex.get_size() / BOMB_PX
	var body := Color.WHITE.lerp(_accent, float(_k["body_tint"])) * _tint
	draw_texture_rect(_tex, Rect2(-size / 2, size), false, body)
	if float(_k["body_tint"]) == 0.0 and float(_tl["glow"]) > 0.0: # a sheen in the tier's colour on a solid shell
		var sheen: Color = ShotLook.prism(_t * 2.0) if _tl["prismatic"] else _accent
		draw_texture_rect(_glow, Rect2(-size * 0.4, size * 0.8), false, Color(sheen, 0.35 * float(_tl["glow"])))
	if _k["fuse"]:
		var flicker := 0.75 + 0.25 * sin(_t * 40.0)
		var spark := Vector2(14, 14) * flicker
		draw_texture_rect(_spark, Rect2(SPARK - spark / 2, spark), false)
	_draw_mark(minf(size.x, size.y) * 0.3)
	draw_set_transform(Vector2.ZERO)


## The overlay particles' colour: coins keep their own gold, the rest take the tier's colour.
func _tier_color() -> Color:
	return (Color.WHITE if str(_tl["trail_fx"]["tex"]) == "coin" else _accent2) * _tint


## The glowing parts behind the projectile (normal blending, so they read on the bright sky too):
## the halo (tier glow, brighter for a skill shot) and the sparkle / ember trail.
func _draw_glow() -> void:
	var scale_k := _scale_k()
	if _tier_tex != null and _tier_glows:
		_draw_particles(_glow_layer, _tier_particles, _tl["trail_fx"], _tier_tex, _tier_color(), scale_k, _tl["prismatic"])
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


## Draws trail particles (spec: life, size, alpha, drift, spin) with tex in color (prismatic:
## each its own rainbow colour) on ci.
func _draw_particles(ci: CanvasItem, list: Array, spec: Dictionary, tex: Texture2D, color: Color, scale_k: float, prismatic: bool) -> void:
	if list.is_empty() or tex == null:
		return
	var sizes: Array = spec["size"]
	var life: float = spec["life"]
	var alpha := float(spec.get("alpha", 1.0))
	for q in list:
		var f: float = q[1] / life
		var r: float = lerpf(sizes[0], sizes[1], f) * scale_k
		var side := Vector2(-_dir.y, _dir.x) * float(q[3])
		var at: Vector2 = q[0] - global_position + side + Vector2(0, float(spec.get("drift", 0.0)) * q[1])
		var c: Color = ShotLook.prism(q[2] / TAU + _t) if prismatic else color
		ci.draw_set_transform(at, q[2] + q[1] * float(spec.get("spin", 0.0)), Vector2.ONE)
		ci.draw_texture_rect(tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(c, alpha * (1.0 - f)))
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
