extends RefCounted
## The one place that maps art ids to image files under res://assets/ (see assets/README.md).
## Every texture the game shows comes through here, so an artist can overwrite a PNG with the
## same name (or edit a character's SpriteFrames .tres) and the game changes with no code edit.
## A missing file never crashes: a character falls back to rookie, an icon to the "unknown"
## icon, anything else to a small grey placeholder (with a warning, once per path).
## tools/bake_art.gd draws the placeholder art into these same paths.

const ROOT := "res://assets/"

# ── Characters ──────────────────────────────────────────────────────────────

const CHARACTERS := ["rookie", "tanko", "spark", "flora"]
const DEFAULT_CHARACTER := "rookie"
## Every character frame has this canvas, the feet at FRAME_PIVOT (bottom centre), facing right,
## drawn at PX_PER_UNIT px per art unit (the art is about 150 units tall).
const FRAME_SIZE := Vector2i(512, 400)
const FRAME_PIVOT := Vector2(256, 360)
const PX_PER_UNIT := 1.6
## Animation name -> frame count, frames per second, loops.
const ANIMS := {
	"idle": {"frames": 4, "fps": 2.5, "loop": true},
	"walk": {"frames": 6, "fps": 9.0, "loop": true},
	"shoot": {"frames": 3, "fps": 9.0, "loop": false},
	"hurt": {"frames": 3, "fps": 7.0, "loop": false},
	"die": {"frames": 4, "fps": 8.0, "loop": false},
}
const PORTRAIT_SIZE := Vector2i(128, 128)
## The ground shadow under a character (centred on the feet), drawn at PX_PER_UNIT too.
const SHADOW := ROOT + "characters/shadow.png"
## The hand drawn over the gun's grip (centred on the grip), shared by every character.
const HAND := ROOT + "characters/hand.png"

# ── Guns (assets/weapons/) ──────────────────────────────────────────────────

## The gun a character holds is a separate sprite: assets/weapons/<kind>/<tier>.png, side view,
## facing right; weapons.json gives each sprite's grip pivot and muzzle point (px in the image)
## and the px per art unit it is drawn at. The frames of each character carry, per animation
## frame, where the hand holds it (assets/characters/<id>/gun_anchors.json: grip px in the frame,
## angle in degrees, in front of or behind the body, muzzle flash 0..1).
## Kind = silhouette, tier = look. `basic` is a character's starter gun (no weapon equipped).
const GUN_KINDS := ["bazooka", "cannon", "shock_rifle", "seed_launcher", "blaster"]
const GUN_BASIC := "basic"
const GUN_NORMAL_TIERS := ["iron", "steel", "mithril", "dragon"]
const GUN_CRAFTED_TIERS := ["silver", "gold", "titan", "diamond"]
## The tiers baked per kind: the characters' guns come in the shop tiers, the blaster (generic
## and crafted weapons) in all of them. A tier not listed falls back to the kind's basic.
const GUN_TIERS := {
	"bazooka": [GUN_BASIC, "iron", "steel", "mithril", "dragon"],
	"cannon": [GUN_BASIC, "iron", "steel", "mithril", "dragon"],
	"shock_rifle": [GUN_BASIC, "iron", "steel", "mithril", "dragon"],
	"seed_launcher": [GUN_BASIC, "iron", "steel", "mithril", "dragon"],
	"blaster": [GUN_BASIC, "iron", "steel", "mithril", "dragon", "silver", "gold", "titan", "diamond"],
}
## The gun each character's own weapons are (its basic gun when no weapon is equipped).
const CHARACTER_GUNS := {"rookie": "bazooka", "tanko": "cannon", "spark": "shock_rifle", "flora": "seed_launcher"}
## The last fallback: Rookie's starter bazooka.
const DEFAULT_GUN_KIND := "bazooka"
const GUNS_DATA := ROOT + "weapons/weapons.json"

# ── Icons (96x96, drawn shapes) ─────────────────────────────────────────────

const ICON_SIZE := Vector2i(96, 96)
const ICONS := [
	"gem", "coin", "plus", "weapon", "skill", "battle",
	"characters", "inventory", "history", "shop",
	"swap", "send", "back", "arrow_left", "arrow_right", "check", "close", "end_turn", "unknown",
	"medkit", "teleport", "power_shot", "drill_bomb", "spider_net", "freeze_bomb", "air_strike", "wind_stopper",
]
const UNKNOWN_ICON := "unknown"

# ── Equipment (icons/equipment/) ────────────────────────────────────────────

## One icon per slot × tier (128x128), a white silhouette per slot for an empty slot (tinted in
## the UI), the hexagon slot frames (132x152) and the "+N" badge 9-patch.
const EQUIP_SLOTS := ["weapon", "armor", "helmet", "pants", "boots", "gloves"]
const EQUIP_TIERS := ["iron", "steel", "mithril", "dragon", "silver", "gold", "titan", "diamond"]
## Weapons are guns: weapon_<tier>.png is the generic blaster (generic and crafted weapons); each
## character's gun has its own icons in the normal tiers, weapon_<kind>_<tier>.png.
const EQUIP_WEAPON_KINDS := ["bazooka", "cannon", "rifle", "launcher"]
const EQUIP_KIND_TIERS := ["iron", "steel", "mithril", "dragon"]
const EQUIP_ICON_SIZE := Vector2i(128, 128)
const EQUIP_FRAMES := ["hex_empty", "hex_filled", "hex_selected"]
const EQUIP_FRAME_SIZE := Vector2i(132, 152)
const EQUIP_BADGE := ROOT + "icons/equipment/badge.png"
## badge.png texture margins [left, top, right, bottom].
const EQUIP_BADGE_MARGINS := [15, 15, 15, 15]

# ── Environment, terrain, effects ───────────────────────────────────────────

const ENV := {
	"sky_match": ROOT + "env/sky_match.png",
	"cloud_0": ROOT + "env/cloud_0.png",
	"cloud_1": ROOT + "env/cloud_1.png",
	"cloud_2": ROOT + "env/cloud_2.png",
	"lobby_bg": ROOT + "env/lobby_bg.png",
	"lobby_ground": ROOT + "env/lobby_ground.png",
	"pedestal": ROOT + "env/pedestal.png",
}
const CLOUDS := ["cloud_0", "cloud_1", "cloud_2"]
## pedestal.png: the centre of the stage's top face (where the feet go), px in the image.
const PEDESTAL_CENTER := Vector2(200, 52)
## lobby_ground.png is the bottom part of the lobby screen from this height (0..1) down.
const LOBBY_GROUND_FROM := 0.6
## sky_match.png covers the map plus this margin (px) on the left and right.
const SKY_MARGIN := 600.0
const TERRAIN := {
	"dirt": ROOT + "terrain/dirt.png",
	"grass_edge": ROOT + "terrain/grass_edge.png",
}
## grass_edge.png: the top GRASS_TUFT_ROWS rows are the tufts above the surface (bottom row
## touches it), the rows under them the grass band from the surface down; transparent = dirt/air.
const GRASS_TUFT_ROWS := 6
const EXPLOSION_FRAMES := 6
## The explosion frames are drawn for a crater of this radius (px in the frame).
const EXPLOSION_RADIUS := 60.0
## Each gun's own shot (assets/fx/<kind>/): projectile.png (64x64, flying +x, 2 px per world px),
## trail.png (32x32 particle) and impact_0..N.png. Rookie's folder holds the bomb
## (rookie/projectile.png) and the explosion (rookie/impact_*), which are also the fallbacks of the
## other kinds; Rookie has no trail particle (its fuse spark and line trail are drawn in code).
## Effects every kind uses (smoke, debris, muzzle flash) are in assets/fx/common/.
const SHOT_KINDS := ["tanko", "spark", "flora"]
const FX := {
	"bomb": ROOT + "fx/rookie/projectile.png",
	"smoke": ROOT + "fx/common/smoke.png",
	"debris": ROOT + "fx/common/debris.png",
	"muzzle": ROOT + "fx/common/muzzle.png",
}

# ── UI 9-patches ────────────────────────────────────────────────────────────

## name -> texture margins [left, top, right, bottom] (the parts that never stretch) and expand
## margins (a glow drawn outside the control's rect).
const UI_BOXES := {
	"button_primary": {"margins": [36, 36, 36, 42], "expand": [12, 12, 12, 12]},
	"button_primary_pressed": {"margins": [36, 36, 36, 42], "expand": [12, 12, 12, 12]},
	"button_navy": {"margins": [18, 18, 18, 18], "expand": [0, 0, 0, 0]},
	"button_orange": {"margins": [26, 26, 26, 30], "expand": [0, 0, 0, 0]},
	"button_disabled": {"margins": [18, 18, 18, 18], "expand": [0, 0, 0, 0]},
	"panel": {"margins": [22, 22, 22, 22], "expand": [0, 0, 0, 0]},
	"panel_selected": {"margins": [20, 20, 20, 20], "expand": [0, 0, 0, 0]},
	"pill": {"margins": [27, 27, 27, 27], "expand": [0, 0, 0, 0]},
	"avatar_frame": {"margins": [24, 24, 24, 24], "expand": [0, 0, 0, 0]},
}

static var _warned := {}
static var _textures := {} # path -> Texture2D
static var _guns_data: Variant = null # parsed weapons.json ({} when missing)
static var _anchors := {} # character id -> {anim: [anchor...]}
static var _placeholder: Texture2D
static var _empty_frames: SpriteFrames


## The id, or DEFAULT_CHARACTER for an unknown or missing one (e.g. a bot without one).
static func known_character(id: String) -> String:
	return id if CHARACTERS.has(id) else DEFAULT_CHARACTER


static func frame_path(id: String, anim: String, i: int) -> String:
	return ROOT + "characters/%s/%s_%d.png" % [id, anim, i]


static func frames_path(id: String) -> String:
	return ROOT + "characters/%s/%s.tres" % [id, id]


static func portrait_path(id: String) -> String:
	return ROOT + "characters/%s/portrait.png" % id


static func gun_path(kind: String, tier: String) -> String:
	return ROOT + "weapons/%s/%s.png" % [kind, tier]


static func gun_anchors_path(id: String) -> String:
	return ROOT + "characters/%s/gun_anchors.json" % id


static func icon_path(icon_name: String) -> String:
	return ROOT + "icons/%s.png" % icon_name


static func equipment_icon_path(slot: String, tier: String) -> String:
	return ROOT + "icons/equipment/%s_%s.png" % [slot, tier]


static func equipment_weapon_path(kind: String, tier: String) -> String:
	return ROOT + "icons/equipment/weapon_%s_%s.png" % [kind, tier]


static func equipment_slot_path(slot: String) -> String:
	return ROOT + "icons/equipment/slot_%s.png" % slot


static func equipment_frame_path(frame: String) -> String:
	return ROOT + "icons/equipment/%s.png" % frame


static func shot_path(kind: String, part: String) -> String:
	return ROOT + "fx/%s/%s.png" % [kind, part]


static func explosion_path(i: int) -> String:
	return ROOT + "fx/rookie/impact_%d.png" % i


static func ui_path(box_name: String) -> String:
	return ROOT + "ui/%s.png" % box_name


## Every file this script names (the test checks they all exist).
static func all_paths() -> Array[String]:
	var out: Array[String] = [SHADOW, HAND, GUNS_DATA]
	for id in CHARACTERS:
		out.append(frames_path(id))
		out.append(portrait_path(id))
		out.append(gun_anchors_path(id))
		for anim in ANIMS:
			for i in int(ANIMS[anim]["frames"]):
				out.append(frame_path(id, anim, i))
	for icon_name in ICONS:
		out.append(icon_path(icon_name))
	for d in [ENV, TERRAIN, FX]:
		for k in d:
			out.append(d[k])
	for i in EXPLOSION_FRAMES:
		out.append(explosion_path(i))
	for kind in SHOT_KINDS:
		out.append(shot_path(kind, "projectile"))
		out.append(shot_path(kind, "trail"))
		for i in EXPLOSION_FRAMES:
			out.append(shot_path(kind, "impact_%d" % i))
	for box_name in UI_BOXES:
		out.append(ui_path(box_name))
	for slot in EQUIP_SLOTS:
		out.append(equipment_slot_path(slot))
		for tier in EQUIP_TIERS:
			out.append(equipment_icon_path(slot, tier))
	for kind in EQUIP_WEAPON_KINDS:
		for tier in EQUIP_KIND_TIERS:
			out.append(equipment_weapon_path(kind, tier))
	for frame in EQUIP_FRAMES:
		out.append(equipment_frame_path(frame))
	out.append(EQUIP_BADGE)
	for kind in GUN_KINDS:
		for tier in GUN_TIERS[kind]:
			out.append(gun_path(kind, tier))
	return out


## The texture at path, or a small grey placeholder when the file is missing. Loaded textures
## stay cached: a texture only passed to a draw call must outlive the frame.
static func texture(path: String) -> Texture2D:
	var cached: Texture2D = _textures.get(path)
	if cached != null:
		return cached
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			_textures[path] = t
			return t
	_warn(path)
	return placeholder()


static func placeholder() -> Texture2D:
	if _placeholder == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.6, 0.6, 0.65, 0.6))
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder


## An icon by name (ICONS), or the "unknown" icon.
static func icon(icon_name: String) -> Texture2D:
	var path := icon_path(icon_name)
	if ResourceLoader.exists(path):
		return texture(path)
	_warn(path)
	return texture(icon_path(UNKNOWN_ICON))


## The icon of an item id (the icon has the item's name), or the "unknown" icon.
static func item_icon(item_id: String) -> Texture2D:
	return icon(item_id if ICONS.has(item_id) else UNKNOWN_ICON)


## The icon of an equipment item by slot and tier (EquipmentModel.tier()); an unknown tier draws
## as iron, an unknown slot as the "unknown" icon. A weapon with a gun kind
## (EquipmentModel.weapon_kind()) in a normal tier gets that gun's icon, the blaster otherwise
## (also while the gun's file is missing or not imported yet).
static func equipment_icon(slot: String, tier: String, kind: String = "") -> Texture2D:
	if not EQUIP_SLOTS.has(slot):
		return icon(UNKNOWN_ICON)
	tier = tier if EQUIP_TIERS.has(tier) else EQUIP_TIERS[0]
	if slot == "weapon" and EQUIP_WEAPON_KINDS.has(kind) and EQUIP_KIND_TIERS.has(tier):
		var path := equipment_weapon_path(kind, tier)
		if ResourceLoader.exists(path):
			var t := texture(path)
			if t != placeholder():
				return t
	return texture(equipment_icon_path(slot, tier))


## The white silhouette of an empty slot (tint it).
static func equipment_slot_icon(slot: String) -> Texture2D:
	return texture(equipment_slot_path(slot)) if EQUIP_SLOTS.has(slot) else icon(UNKNOWN_ICON)


## A hexagon slot frame: "hex_empty", "hex_filled" or "hex_selected".
static func equipment_frame(frame: String) -> Texture2D:
	return texture(equipment_frame_path(frame if EQUIP_FRAMES.has(frame) else EQUIP_FRAMES[0]))


## The "+N" badge background as a StyleBoxTexture (content_margin: padding around the text).
static func equipment_badge_box(content_margin: int = 6) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(EQUIP_BADGE)
	for side in 4:
		box.set_texture_margin(side, EQUIP_BADGE_MARGINS[side])
		box.set_content_margin(side, content_margin)
	box.content_margin_left = content_margin + 4
	box.content_margin_right = content_margin + 4
	return box


static func portrait(id: String) -> Texture2D:
	var path := portrait_path(known_character(id))
	return texture(path if ResourceLoader.exists(path) else portrait_path(DEFAULT_CHARACTER))


static func env(key: String) -> Texture2D:
	return texture(ENV.get(key, ""))


static func terrain(key: String) -> Texture2D:
	return texture(TERRAIN.get(key, ""))


static func fx(key: String) -> Texture2D:
	return texture(FX.get(key, ""))


static func explosion(i: int) -> Texture2D:
	return texture(explosion_path(clampi(i, 0, EXPLOSION_FRAMES - 1)))


## A part of a gun kind's shot ("projectile", "trail", "impact_<i>"), or `fallback` (a texture)
## for Rookie / an unknown kind / a file missing or not imported yet.
static func shot(kind: String, part: String, fallback: Texture2D) -> Texture2D:
	if not SHOT_KINDS.has(kind):
		return fallback
	var path := shot_path(kind, part)
	var t: Texture2D = _textures.get(path)
	if t == null and ResourceLoader.exists(path):
		t = texture(path)
	return t if t != null and t != placeholder() else fallback


## The SpriteFrames of a character (idle/walk/shoot/hurt/die), falling back to rookie's, then to
## empty animations (nothing drawn, nothing breaks).
static func character_frames(id: String) -> SpriteFrames:
	for cid in [known_character(id), DEFAULT_CHARACTER]:
		var path := frames_path(cid)
		if ResourceLoader.exists(path):
			var f = load(path)
			if f is SpriteFrames:
				return f
		_warn(path)
	if _empty_frames == null:
		_empty_frames = SpriteFrames.new()
		for anim in ANIMS:
			if not _empty_frames.has_animation(anim):
				_empty_frames.add_animation(anim)
			_empty_frames.add_frame(anim, placeholder())
	return _empty_frames


# ── Guns ────────────────────────────────────────────────────────────────────

## The sprite of a gun: {kind, tier, texture, grip, muzzle (px in the texture), scale (texture
## px → character frame px)}. Falls back to the kind's basic, then to Rookie's basic bazooka
## (a missing file, one not imported yet or no weapons.json entry), then to the placeholder.
static func gun(kind: String, tier: String) -> Dictionary:
	for kt in [[kind, tier], [kind, GUN_BASIC], [DEFAULT_GUN_KIND, GUN_BASIC]]:
		var meta := gun_meta(kt[0], kt[1])
		var path := gun_path(kt[0], kt[1])
		if meta.is_empty() or not ResourceLoader.exists(path):
			continue
		var t := texture(path)
		if t == placeholder():
			continue
		var data := guns_data()
		var ppu := float(data.get("pxPerUnit", PX_PER_UNIT))
		return {"kind": kt[0], "tier": kt[1], "texture": t, "grip": meta["grip"], "muzzle": meta["muzzle"],
			"scale": PX_PER_UNIT / ppu if ppu > 0.0 else 1.0}
	_warn(gun_path(kind, tier))
	return {"kind": DEFAULT_GUN_KIND, "tier": GUN_BASIC, "texture": placeholder(), "grip": Vector2(4, 8),
		"muzzle": Vector2(16, 8), "scale": 1.0}


## weapons.json's entry of a sprite: {grip, muzzle} (Vector2 px), {} when it has none.
static func gun_meta(kind: String, tier: String) -> Dictionary:
	var guns = guns_data().get("guns")
	var e = guns.get(kind, {}).get(tier) if guns is Dictionary and guns.get(kind) is Dictionary else null
	if not e is Dictionary or not e.get("grip") is Array or not e.get("muzzle") is Array:
		return {}
	return {"grip": _vec2(e["grip"]), "muzzle": _vec2(e["muzzle"])}


## weapons.json parsed ({} when missing or invalid).
static func guns_data() -> Dictionary:
	if _guns_data == null:
		_guns_data = _load_json(GUNS_DATA)
	return _guns_data


## Where a character holds its gun in each frame: anim -> [{grip (Vector2, px in the frame),
## angle (degrees, 0 = level, + turns the muzzle down), front (drawn over the body), flash
## (0..1 muzzle flash)}], one per frame. Falls back to Rookie's, then to a fixed hold.
static func gun_anchors(id: String) -> Dictionary:
	id = known_character(id)
	if _anchors.has(id):
		return _anchors[id]
	var out := {}
	for cid in [id, DEFAULT_CHARACTER]:
		var data := _load_json(gun_anchors_path(cid))
		if data.get("anims") is Dictionary:
			for anim in data["anims"]:
				var frames: Array = []
				for a in data["anims"][anim]:
					if a is Dictionary and a.get("grip") is Array:
						frames.append({"grip": _vec2(a["grip"]), "angle": float(a.get("angle", 0.0)),
							"front": bool(a.get("front", true)), "flash": float(a.get("flash", 0.0))})
				out[anim] = frames
			break
	_anchors[id] = out
	return out


## The anchor of frame i of anim (the last frame's when i is past the end; a fixed hold in
## front of the chest when the character has no anchors).
static func gun_anchor(id: String, anim: String, i: int) -> Dictionary:
	var frames: Array = gun_anchors(id).get(anim, [])
	if frames.is_empty():
		frames = gun_anchors(id).get("idle", [])
	if frames.is_empty():
		return {"grip": FRAME_PIVOT + Vector2(32, -50) * PX_PER_UNIT, "angle": 0.0, "front": true, "flash": 0.0}
	return frames[clampi(i, 0, frames.size() - 1)]


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_warn(path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("art: %s is not a JSON object" % path)
		return {}
	return parsed


static func _vec2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a.size() >= 2 else Vector2.ZERO


## A StyleBoxTexture from assets/ui/<box_name>.png with its texture margins; modulate tints it
## (e.g. lighter for hover). content_margin -1 keeps the texture margins as padding.
static func ui_box(box_name: String, content_margin: int = -1, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var spec: Dictionary = UI_BOXES.get(box_name, UI_BOXES["panel"])
	var box := StyleBoxTexture.new()
	box.texture = texture(ui_path(box_name))
	var m: Array = spec["margins"]
	var e: Array = spec["expand"]
	for side in 4:
		box.set_texture_margin(side, m[side])
		box.set_expand_margin(side, e[side])
		if content_margin >= 0:
			box.set_content_margin(side, content_margin)
	box.modulate_color = modulate
	return box


static func _warn(path: String) -> void:
	if not _warned.has(path):
		_warned[path] = true
		push_warning("art: missing %s, using a fallback" % path)
