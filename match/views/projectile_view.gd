extends Node2D
## A shell in flight (moved by shot_player.gd), drawn the way the shooter's gun fires it
## (STYLES, by `kind`, see style_for()):
## - rookie (bazooka): the bomb (assets/fx/bomb.png, fuse behind) with a flickering spark
##   (assets/fx/muzzle.png) on the fuse and a warm fading line trail;
## - tanko (cannon): a big iron cannonball with a short grey smoke trail;
## - spark (shock rifle): a glowing plasma orb, flickering, with a bright electric trail and sparks;
## - flora (seed launcher): a spinning seed pod with a petal trail.
## Images come from ui/art.gd (assets/fx/<kind>/projectile.png and trail.png, falling back to
## the bomb). A skill shot is drawn larger with a glow; an item shot is tinted and marked by the
## item (ITEM_LOOKS: icy freeze bomb, white net, grey drill spiral...). Set kind / skill / item
## before adding it. Visuals only: the server path moves it.

const Art := preload("res://ui/art.gd")

const TRAIL := 10 # positions kept for the line trail
const BOMB_PX := 2.0 # projectile image px per world px
const SPARK := Vector2(-11, -3) # rookie's fuse tip, world px from the bomb centre (flying +x)
const SKILL_SCALE := 1.3

## kind -> look: line (the line trail colour, or null) and its width, particles (trail particles:
## one every `every` world px, life s, start / end size in world px, alpha, drift down px/s,
## jitter sideways px), spin (rad/s), fuse (rookie's spark), flicker (the projectile pulses).
const STYLES := {
	"rookie": {"line": Color(1.0, 0.85, 0.55), "line_width": 6.0, "particles": false, "spin": 0.0, "fuse": true, "flicker": false},
	"tanko": {"line": Color(0.75, 0.74, 0.76), "line_width": 4.0, "particles": true, "every": 7.0, "life": 0.45,
		"size": [9.0, 20.0], "alpha": 0.7, "drift": -18.0, "spin": 0.0, "fuse": false, "flicker": false},
	"spark": {"line": Color(0.55, 0.95, 1.0), "line_width": 7.0, "particles": true, "every": 6.0, "life": 0.3,
		"size": [9.0, 3.0], "alpha": 1.0, "drift": 0.0, "jitter": 9.0, "spin": 0.0, "fuse": false, "flicker": true},
	"flora": {"line": null, "particles": true, "every": 8.0, "life": 0.6, "size": [8.0, 6.0], "alpha": 0.95,
		"drift": 22.0, "jitter": 6.0, "spin": 9.0, "fuse": false, "flicker": false},
}
## item id -> tint of the projectile and its trail, and a mark drawn over it ("" none).
const ITEM_LOOKS := {
	"freeze_bomb": {"tint": Color(0.62, 0.86, 1.0), "mark": "frost"},
	"spider_net": {"tint": Color(0.95, 0.95, 1.0), "mark": "web"},
	"drill_bomb": {"tint": Color(0.72, 0.72, 0.78), "mark": "spiral"},
	"power_shot": {"tint": Color(1.0, 0.62, 0.42), "mark": ""},
	"teleport": {"tint": Color(0.8, 0.62, 1.0), "mark": ""},
}


## Who fires, how: the projectile kind of the shooter's character (unknown → rookie), whether it
## is a skill shot, and the item (only for an item shot). Air strikes keep the bomb.
static func style_for(character_id: String, action_mode: String, item_id: String) -> Dictionary:
	var k := character_id if STYLES.has(character_id) else "rookie"
	var it := item_id if action_mode == "item" else ""
	if it == "air_strike":
		k = "rookie"
	return {"kind": k, "skill": action_mode == "skill", "item": it}


var kind := "rookie"
var skill := false
var item := ""

var _style: Dictionary
var _trail := PackedVector2Array() # global positions, oldest first
var _particles: Array = [] # [global position, age, angle, sideways offset]
var _since_particle := 0.0 # world px travelled since the last particle
var _dir := Vector2.RIGHT
var _t := 0.0
var _tex: Texture2D
var _trail_tex: Texture2D
var _spark: Texture2D
var _tint := Color.WHITE
var _mark := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not STYLES.has(kind):
		kind = "rookie"
	_style = STYLES[kind]
	_tex = Art.shot(kind, "projectile", Art.fx("bomb"))
	_spark = Art.fx("muzzle")
	_trail_tex = Art.shot(kind, "trail", Art.fx("smoke"))
	var look: Dictionary = ITEM_LOOKS.get(item, {})
	_tint = look.get("tint", Color.WHITE)
	_mark = look.get("mark", "")
	_rng.randomize()
	_trail.append(global_position)


func _process(delta: float) -> void:
	_t += delta
	var p := global_position
	if _trail.is_empty() or p.distance_squared_to(_trail[-1]) > 0.25:
		var v := p - _trail[-1] if not _trail.is_empty() else Vector2.ZERO
		if v.length_squared() > 0.01:
			_dir = v.normalized()
		_since_particle += v.length()
		_trail.append(p)
		if _trail.size() > TRAIL:
			_trail.remove_at(0)
	if _style["particles"]:
		for q in _particles:
			q[1] += delta
		var life: float = _style["life"]
		_particles = _particles.filter(func(q): return q[1] < life)
		var every: float = _style["every"]
		while _since_particle >= every:
			_since_particle -= every
			_particles.append([p, 0.0, _rng.randf() * TAU, _rng.randf_range(-1.0, 1.0) * float(_style.get("jitter", 0.0))])
	queue_redraw()


func _draw() -> void:
	var scale_k := SKILL_SCALE if skill else 1.0
	var line = _style["line"]
	var n := _trail.size()
	if line != null:
		var w: float = _style["line_width"]
		for i in range(1, n):
			var k := float(i) / n
			var a := _trail[i - 1] - global_position
			var b := _trail[i] - global_position
			draw_line(a, b, Color(Color(line) * _tint, 0.45 * k), 2.0 + w * k * scale_k, true)
	if _style["particles"]:
		var sizes: Array = _style["size"]
		var life: float = _style["life"]
		for q in _particles:
			var f: float = q[1] / life
			var r: float = lerpf(sizes[0], sizes[1], f) * scale_k
			var side := Vector2(-_dir.y, _dir.x) * float(q[3])
			var at: Vector2 = q[0] - global_position + side + Vector2(0, float(_style["drift"]) * q[1])
			draw_set_transform(at, q[2] + q[1] * float(_style["spin"]), Vector2.ONE)
			draw_texture_rect(_trail_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, Color(_tint, float(_style["alpha"]) * (1.0 - f)))
		draw_set_transform(Vector2.ZERO)
	if skill: # a glow behind a skill shot
		var g := 30.0 * scale_k
		draw_texture_rect(_spark, Rect2(-Vector2(g, g), Vector2(g, g) * 2), false, Color(1, 1, 1, 0.45 + 0.15 * sin(_t * 20.0)))
	var rot := _dir.angle() + _t * float(_style["spin"])
	var pulse := 1.0 + (0.12 * sin(_t * 45.0) if _style["flicker"] else 0.0)
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE * scale_k * pulse)
	var size := _tex.get_size() / BOMB_PX
	draw_texture_rect(_tex, Rect2(-size / 2, size), false, _tint)
	if _style["fuse"]:
		var flicker := 0.75 + 0.25 * sin(_t * 40.0)
		var spark := Vector2(14, 14) * flicker
		draw_texture_rect(_spark, Rect2(SPARK - spark / 2, spark), false)
	_draw_mark(minf(size.x, size.y) * 0.3)
	draw_set_transform(Vector2.ZERO)


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
