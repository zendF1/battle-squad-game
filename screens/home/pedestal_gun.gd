extends Control
## The lobby stage's gun: the weapon the stage character wears (its basic gun when none), resting
## on the pedestal beside the character, leaning with the muzzle up-left, floating a little over
## its shadow with a soft glow in its tier's colour (stronger and twinkling for the high tiers,
## match/views/shot_look.gd TIERS), its name and "+N" under it. The lobby calls set_gun() on
## equip / unequip and when the character changes.
## The rect: the gun fitted into the top BOX (its foot on the bottom edge), the name line LABEL_GAP
## px under it, centred (it may be wider than the rect).

const Art := preload("res://ui/art.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const ShotLook := preload("res://match/views/shot_look.gd")

const GUN_SCALE := 0.9 # gun image px → px here (1.44 px per art unit), less when it does not fit BOX
const BOX := Vector2(125, 112) # the leaning gun stays inside this
const TILT := 0.6 # radians, the gun mirrored (muzzle left): lying diagonally, the muzzle up-left
const LABEL_GAP := 12.0
const FLOAT := 3.0 # px up and down
const SPARKLES := 3 # twinkles around a high-tier gun (rank >= 3)

static var _used := {} # texture -> the drawn part of the image (Rect2)

var _gun := {} # Art.gun()
var _glow_color := Color.WHITE
var _glow := 0.0 # 0..1
var _rank := 0
var _name: Label
var _level: Label
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -150
	row.offset_right = 150
	row.offset_top = BOX.y + LABEL_GAP
	add_child(row)
	_name = LobbyUi.text("", 19, Color.WHITE, true)
	row.add_child(_name)
	_level = LobbyUi.text("", 18, LobbyUi.GOLD, true)
	row.add_child(_level)


## Shows the gun kind × tier (ui/art.gd gun(), with its fallbacks), named `title`, "+N" level
## ("" hides it).
func set_gun(kind: String, tier: String, title: String, level: String) -> void:
	_gun = Art.gun(kind, tier)
	var t: Dictionary = ShotLook.TIERS[ShotLook.known_tier(tier)]
	_glow_color = ShotLook.accent(kind, tier)
	_glow = 0.3 + 0.7 * float(t["glow"])
	_rank = int(t["rank"])
	_name.text = title
	_level.text = level
	_level.visible = level != ""
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
		var p: Vector2 = (half * corner * Vector2(-1, 1)).rotated(TILT) + l["centre"]
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
	var xform := Vector2(-1, 1) # mirrored: the muzzle points left
	# The shadow on the pedestal under its foot, smaller while it is up.
	var shadow := Art.texture(Art.SHADOW)
	var sw := bb.x * (0.75 - lift * 0.03)
	draw_texture_rect(shadow, Rect2(Vector2(size.x / 2, BOX.y) - Vector2(sw / 2, 7), Vector2(sw, 14)), false, Color(1, 1, 1, 0.85))
	# The glow behind it, along the gun, breathing.
	var glow := Art.tier_fx("glow")
	if glow == null:
		glow = Art.fx("muzzle")
	var a := _glow * (0.75 + 0.25 * sin(_t * 3.0))
	draw_set_transform(centre, TILT, xform)
	draw_texture_rect(glow, Rect2(-Vector2(w, h * 1.8) * 0.75, Vector2(w, h * 1.8) * 1.5), false, Color(_glow_color, a))
	# The gun, its drawn part centred.
	draw_set_transform(centre, TILT, xform * k)
	draw_texture_rect_region(tex, Rect2(-part.size / 2, part.size), part)
	draw_set_transform(Vector2.ZERO)
	if _rank >= 3:
		var sparkle := Art.tier_fx("sparkle")
		if sparkle != null:
			for i in SPARKLES:
				var ph := _t * 1.3 + i * 2.1
				var tw := maxf(0.0, sin(ph * 2.0))
				var at := centre + Vector2(cos(i * 2.4 + 0.6) * bb.x * 0.4, sin(i * 1.9) * bb.y * 0.4)
				var r := 6.0 + 4.0 * tw
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
