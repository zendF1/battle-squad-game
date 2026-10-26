extends Control
## The stage's gun: the weapon the stage character wears (its basic gun when none), resting
## on the pedestal beside the character (the lobby, and the Nhân vật page and Prep while the
## character is its full-body picture, which holds no gun), at its right leaning a little with the muzzle up-right
## (the image as drawn, not mirrored), floating a little over
## its shadow with a soft glow in its tier's colour (stronger and twinkling for the high tiers,
## match/views/shot_look.gd TIERS); no name under it (players know their gun). The lobby calls
## set_gun() on equip / unequip and when the character changes.
## The gun is ui/art.gd gun(): the held sprite, or the hug art for a kind without held sprites
## (Rookie's bazooka, Tanko's cannon, Flora's seed launcher, Spark's shock rifle: hug_<tier>.png), leaned and fitted the same way.
## The rect: the gun fitted into the top BOX (its foot on the bottom edge). Laid out on the match
## picture's px, drawn from its high-resolution UI picture (Art.ui_gun_texture(), mipmapped).

const Art := preload("res://ui/art.gd")
const ShotLook := preload("res://match/views/shot_look.gd")

const GUN_SCALE := 1.5 # gun image px → px here at most (2.4 px per art unit), less when it does not fit BOX (the hug guns)
const BOX := Vector2(262, 180) # the leaning gun stays inside this (twice the old 125-wide fit: every gun ~2x)
const TILT := 0.28 # radians the muzzle end is raised by (the image's muzzle points right): leaning a little
const FLOAT := 5.0 # px up and down
const SPARKLES := 3 # twinkles around a high-tier gun (rank >= 3)
## Its rect on the 560x590 stage of the lobby and the Nhân vật page (character feet at (280,
## 522), the pedestal's centre at y 528): its foot on the pedestal's top face (y 545) right of the
## feet, the butt in front of the near boot, the muzzle out to the stage's right edge, below the
## ▶ arrow and the body. FEET: the character's feet there (to place it on a smaller stage, scaled).
const STAGE_RECT := Rect2(220, 365, 262, 218)
const FEET := Vector2(280, 522)

static var _used := {} # texture -> the drawn part of the image (Rect2)

var _gun := {} # Art.gun()
var _glow_color := Color.WHITE
var _glow := 0.0 # 0..1
var _rank := 0
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Shows the gun kind × tier (ui/art.gd gun(), with its fallbacks).
func set_gun(kind: String, tier: String) -> void:
	_gun = Art.gun(kind, tier)
	var t: Dictionary = ShotLook.TIERS[ShotLook.known_tier(tier)]
	_glow_color = ShotLook.accent(kind, tier)
	_glow = 0.3 + 0.7 * float(t["glow"])
	_rank = int(t["rank"])
	queue_redraw()


## {kind, tier} shown (after the art fallbacks), for tests.
func gun() -> Dictionary:
	return {"kind": str(_gun.get("kind", "")), "tier": str(_gun.get("tier", ""))}


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


## Where the gun is drawn: {part (the image's drawn rect), k (image px → px), bb (the leaning
## gun's bounding box size), centre (local, at rest)}.
func _layout() -> Dictionary:
	var part := _used_rect(_gun["texture"])
	var k := GUN_SCALE * float(_gun["scale"])
	var c := absf(cos(TILT))
	var sn := absf(sin(TILT))
	var bb := Vector2(part.size.x * c + part.size.y * sn, part.size.x * sn + part.size.y * c) * k
	var fit := minf(1.0, minf(BOX.x / bb.x, BOX.y / bb.y))
	return {"part": part, "k": k * fit, "bb": bb * fit, "centre": Vector2(size.x / 2, BOX.y - bb.y * fit / 2)}


## The corners of the drawn gun image in global coordinates, at rest (tests: clear of the body).
func gun_polygon() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _gun.is_empty():
		return out
	var l := _layout()
	var half: Vector2 = l["part"].size / 2 * float(l["k"])
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector2 = (half * corner).rotated(-TILT) + l["centre"]
		out.append(get_global_transform() * p)
	return out


func _draw() -> void:
	if _gun.is_empty():
		return
	var tex: Texture2D = _gun["texture"]
	var l := _layout()
	var part: Rect2 = l["part"]
	var k: float = l["k"]
	var bb: Vector2 = l["bb"]
	var w := part.size.x * k
	var h := part.size.y * k
	var lift := (sin(_t * 2.2) * 0.5 + 0.5) * FLOAT
	var centre: Vector2 = l["centre"] - Vector2(0, lift)
	# The shadow on the pedestal under its foot, smaller while it is up.
	var shadow := Art.texture(Art.SHADOW)
	var sw := bb.x * (0.75 - lift / FLOAT * 0.09)
	var sh := bb.x * 0.11
	draw_texture_rect(shadow, Rect2(Vector2(size.x / 2, BOX.y) - Vector2(sw, sh) / 2, Vector2(sw, sh)), false, Color(1, 1, 1, 0.85))
	# The glow behind it, along the gun, breathing.
	var glow := Art.tier_fx("glow")
	if glow == null:
		glow = Art.fx("muzzle")
	var a := _glow * (0.75 + 0.25 * sin(_t * 3.0))
	draw_set_transform(centre, -TILT)
	draw_texture_rect(glow, Rect2(-Vector2(w, h * 1.8) * 0.75, Vector2(w, h * 1.8) * 1.5), false, Color(_glow_color, a))
	# The gun, its drawn part centred: the same part of its high-resolution UI picture (the same
	# canvas, more px: the match picture would be magnified 2-4 times here).
	var ui := Art.ui_gun_texture(_gun)
	var ui_k := ui.get_size() / tex.get_size()
	draw_set_transform(centre, -TILT, Vector2(k, k))
	draw_texture_rect_region(ui, Rect2(-part.size / 2, part.size), Rect2(part.position * ui_k, part.size * ui_k))
	draw_set_transform(Vector2.ZERO)
	if _rank >= 3:
		var sparkle := Art.tier_fx("sparkle")
		if sparkle != null:
			for i in SPARKLES:
				var ph := _t * 1.3 + i * 2.1
				var tw := maxf(0.0, sin(ph * 2.0))
				var at := centre + Vector2(cos(i * 2.4 + 0.6) * bb.x * 0.4, sin(i * 1.9) * bb.y * 0.4)
				var r := bb.x * (0.05 + 0.03 * tw) # 6..10 px on a 125 px wide gun
				draw_texture_rect(sparkle, Rect2(at - Vector2(r, r), Vector2(r, r) * 2), false, Color(_glow_color.lerp(Color.WHITE, 0.5), tw))


## The part of a gun image with pixels (the whole image when it cannot be read), cached.
static func _used_rect(tex: Texture2D) -> Rect2:
	if _used.has(tex):
		return _used[tex]
	var r := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img != null:
		var u := img.get_used_rect()
		if u.size.x > 0 and u.size.y > 0:
			r = Rect2(u)
	_used[tex] = r
	return r
