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
## The lobby stage's pose without a gun: the idle animation (same frame count, speed and canvas)
## with the front arm hanging relaxed, <id>/idle_free_0..3.png. Not in the .tres: free_frames()
## builds its SpriteFrames from the files (no anchors: no gun is drawn).
const FREE_POSE := "idle_free"
const PORTRAIT_SIZE := Vector2i(128, 128)
## The ground shadow under a character (centred on the feet), drawn at PX_PER_UNIT too.
const SHADOW := ROOT + "characters/shadow.png"
## The hand drawn over the gun's grip (centred on the grip), shared by every character.
const HAND := ROOT + "characters/hand.png"
## The screens outside the match (lobby stage, Prep, Nhân vật) draw a character with
## <id>/lobby/rig.json as its front-view cutout rig (scenes/character/rig.gd): part pictures in
## <id>/lobby/parts/<part>.png on bones, animated by the shared LOBBY_ANIMS (a rig.json may add
## or override one). rig() falls back to {} (the frames above) when the rig or a part is missing.
## The match keeps the side-view frames.
const RIG_VIEW := "lobby"
const LOBBY_ANIMS := ROOT + "characters/lobby_anims.json"
## The screens outside the match prefer <id>/lobby/full.png (one full-body picture, cut from
## art_source/characters/lineup_v1.png) skinned on the skeleton in <id>/lobby/full.json
## (scenes/character/full_body.gd), animated by FULL_ANIMS merged with the full.json's anims;
## lobby_full() falls back to {} (then the rig, then the frames) when either file is missing or
## broken.
const FULL_ANIMS := ROOT + "characters/lobby_full_anims.json"
## The animations a lobby rig needs (idle: holding the gun; idle_free: hands free).
const RIG_ANIM_NAMES := ["idle", "idle_free"]

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
## Each gun kind's own shot (assets/fx/<kind>/, kind = GUN_KINDS): projectile.png (flying +x,
## 2 px per world px), trail.png (32x32 trail particle) and impact_0..N.png (the burst).
## bazooka/ (the bomb and the fire explosion) is also the fallback of a missing file of another
## kind. Effects every kind uses (smoke, debris, muzzle flash) are in assets/fx/common/; the
## shared tier overlays (match/views/shot_look.gd TIERS: glow, sparkles, embers, coins, shards,
## shockwave ring, lens flare, ground cracks) in assets/fx/tiers/, all drawn white-ish and tinted
## in code except the coin and the crack.
const SHOT_KINDS := GUN_KINDS
const SHOT_PARTS := ["projectile", "trail"]
const DEFAULT_SHOT_KIND := "bazooka"
const TIER_FX := ["glow", "sparkle", "ember", "coin", "shard", "ring", "flare", "crack"]
const FX := {
	"bomb": ROOT + "fx/bazooka/projectile.png",
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
static var _free_frames := {} # character id -> SpriteFrames
static var _rigs := {} # character id -> rig() data ({} = no rig)
static var _fulls := {} # character id -> lobby_full() data ({} = none)


## The id, or DEFAULT_CHARACTER for an unknown or missing one (e.g. a bot without one).
static func known_character(id: String) -> String:
	return id if CHARACTERS.has(id) else DEFAULT_CHARACTER


static func frame_path(id: String, anim: String, i: int) -> String:
	return ROOT + "characters/%s/%s_%d.png" % [id, anim, i]


static func frames_path(id: String) -> String:
	return ROOT + "characters/%s/%s.tres" % [id, id]


static func portrait_path(id: String) -> String:
	return ROOT + "characters/%s/portrait.png" % id


static func rig_path(id: String) -> String:
	return ROOT + "characters/%s/%s/rig.json" % [id, RIG_VIEW]


static func rig_part_path(id: String, part: String) -> String:
	return ROOT + "characters/%s/%s/parts/%s.png" % [id, RIG_VIEW, part]


static func full_path(id: String) -> String:
	return ROOT + "characters/%s/%s/full.png" % [id, RIG_VIEW]


static func full_json_path(id: String) -> String:
	return ROOT + "characters/%s/%s/full.json" % [id, RIG_VIEW]


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
	return shot_path(DEFAULT_SHOT_KIND, "impact_%d" % i)


static func tier_fx_path(fx_name: String) -> String:
	return ROOT + "fx/tiers/%s.png" % fx_name


static func ui_path(box_name: String) -> String:
	return ROOT + "ui/%s.png" % box_name


## Every file this script names (the test checks they all exist).
static func all_paths() -> Array[String]:
	var out: Array[String] = [SHADOW, HAND, GUNS_DATA, LOBBY_ANIMS, FULL_ANIMS]
	for id in CHARACTERS:
		out.append(frames_path(id))
		out.append(portrait_path(id))
		out.append(gun_anchors_path(id))
		for anim in ANIMS:
			for i in int(ANIMS[anim]["frames"]):
				out.append(frame_path(id, anim, i))
		for i in int(ANIMS["idle"]["frames"]):
			out.append(frame_path(id, FREE_POSE, i))
		out.append_array(rig_paths(id))
		out.append(full_path(id))
		out.append(full_json_path(id))
	for icon_name in ICONS:
		out.append(icon_path(icon_name))
	for d in [ENV, TERRAIN, FX]:
		for k in d:
			out.append(d[k])
	for kind in SHOT_KINDS:
		for part in SHOT_PARTS:
			out.append(shot_path(kind, part))
		for i in EXPLOSION_FRAMES:
			out.append(shot_path(kind, "impact_%d" % i))
	for fx_name in TIER_FX:
		out.append(tier_fx_path(fx_name))
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
## for an unknown kind / a file missing or not imported yet.
static func shot(kind: String, part: String, fallback: Texture2D) -> Texture2D:
	if not SHOT_KINDS.has(kind):
		return fallback
	var t := _cached(shot_path(kind, part))
	return t if t != null else fallback


## A shared tier overlay (TIER_FX), or null when its file is missing or not imported yet (the
## effect is then left out).
static func tier_fx(fx_name: String) -> Texture2D:
	return _cached(tier_fx_path(fx_name)) if TIER_FX.has(fx_name) else null


## The texture at path when it loads (cached), null otherwise; warns once.
static func _cached(path: String) -> Texture2D:
	var t: Texture2D = _textures.get(path)
	if t == null and ResourceLoader.exists(path):
		t = texture(path)
	if t == null:
		_warn(path)
	return t if t != null and t != placeholder() else null


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


## The no-gun pose of a character as SpriteFrames with one looping "idle" animation, or null when
## one of its frames is missing or not imported yet (the caller keeps the normal frames).
static func free_frames(id: String) -> SpriteFrames:
	id = known_character(id)
	if _free_frames.has(id):
		return _free_frames[id]
	var spec: Dictionary = ANIMS["idle"]
	var f := SpriteFrames.new()
	f.set_animation_loop("default", true)
	f.rename_animation("default", "idle")
	f.set_animation_speed("idle", float(spec["fps"]))
	f.set_animation_loop("idle", true)
	for i in int(spec["frames"]):
		var t := _cached(frame_path(id, FREE_POSE, i))
		if t == null:
			f = null
			break
		f.add_frame("idle", t)
	if f != null:
		_free_frames[id] = f # a missing frame is looked up again next time (imported meanwhile)
	return f


# ── Cutout rigs ─────────────────────────────────────────────────────────────

## rig.json and every part picture it names ([] without a rig.json).
static func rig_paths(id: String) -> Array[String]:
	var out: Array[String] = []
	var path := rig_path(id)
	if not FileAccess.file_exists(path):
		return out
	out.append(path)
	var data := _load_json(path)
	var parts := {}
	for b in data.get("bones", []):
		if b is Dictionary and b.has("part"):
			parts[str(b["part"])] = true
	for part in parts:
		out.append(rig_part_path(id, part))
	return out


## A character's lobby rig: {scale (part px → character px), bones: [{name, parent, part, at, pivot
## (Vector2 part px), rot, z, flip, shade, set}], gun: {bone, at, angle, z}, textures: {part:
## Texture2D}, anims: {name: spec}}, or {} when it has no rig.json, the file is broken or a part
## picture is missing (the character then uses its frames). A part not imported yet is read
## straight from its PNG.
static func rig(id: String) -> Dictionary:
	id = known_character(id)
	if _rigs.has(id):
		return _rigs[id]
	var out := _parse_rig(id)
	_rigs[id] = out
	return out


static func _parse_rig(id: String) -> Dictionary:
	var path := rig_path(id)
	if not FileAccess.file_exists(path):
		return {}
	var data := _load_json(path)
	if not data.get("bones") is Array or not data.get("gun") is Dictionary or float(data.get("scale", 0.0)) <= 0.0:
		push_warning("art: %s is not a rig, using the frames" % path)
		return {}
	var names := {}
	for b in data["bones"]:
		if b is Dictionary and b.has("name"):
			names[str(b["name"])] = true
	var bones: Array = []
	var textures := {}
	for b in data["bones"]:
		if not b is Dictionary or not b.has("name") or (b.has("parent") and not names.has(str(b["parent"]))):
			push_warning("art: %s has a bad bone %s, using the frames" % [path, str(b)])
			return {}
		var e := {"name": str(b["name"]), "parent": str(b.get("parent", "")), "at": _vec2(b.get("at", [])),
			"pivot": _vec2(b.get("pivot", [])), "rot": float(b.get("rot", 0.0)), "z": int(b.get("z", 0)),
			"flip": bool(b.get("flip", false)), "shade": float(b.get("shade", 1.0)), "set": str(b.get("set", ""))}
		if b.has("part"):
			var part := str(b["part"])
			if not textures.has(part):
				var t := _rig_texture(rig_part_path(id, part))
				if t == null:
					return {}
				textures[part] = t
			e["part"] = part
		bones.append(e)
	var g: Dictionary = data["gun"]
	if not names.has(str(g.get("bone", ""))):
		push_warning("art: %s gun bone missing, using the frames" % path)
		return {}
	var anims: Dictionary = _load_json(LOBBY_ANIMS).duplicate()
	anims.erase("_doc")
	if data.get("anims") is Dictionary:
		anims.merge(data["anims"], true)
	for anim in RIG_ANIM_NAMES:
		if not anims.get(anim) is Dictionary:
			push_warning("art: rig animation %s missing, using the frames" % anim)
			return {}
	return {"scale": float(data["scale"]), "bones": bones, "textures": textures, "anims": anims,
		"gun": {"bone": str(g["bone"]), "at": _vec2(g.get("at", [])), "angle": float(g.get("angle", 0.0)), "z": int(g.get("z", 0))}}


# ── Full-body pictures ──────────────────────────────────────────────────────

## A character's skinned full-body picture: {texture, size, pivot (the feet, px in the picture),
## height (px), scale (picture px → character px), bones: [{name, parent, at, tip (Vector2 px)}]
## (parents first), vertices (PackedVector2Array, px = uv), polygons (Array of PackedInt32Array
## triangles), weights (per bone a PackedFloat32Array, one per vertex), anims: {name: spec}}, or
## {} when it has none (the rig, then the frames, draw it). Not imported yet: read from the PNG.
static func lobby_full(id: String) -> Dictionary:
	id = known_character(id)
	if _fulls.has(id):
		return _fulls[id]
	var out := parse_full(full_json_path(id), full_path(id))
	_fulls[id] = out
	return out


static func parse_full(json_path: String, png_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path) or not FileAccess.file_exists(png_path):
		return {}
	var data := _load_json(json_path)
	var mesh = data.get("mesh")
	if float(data.get("scale", 0.0)) <= 0.0 or not data.get("pivot") is Array or not data.get("bones") is Array \
			or not mesh is Dictionary or not mesh.get("vertices") is Array or not mesh.get("triangles") is Array \
			or not data.get("weights") is Array or (data["weights"] as Array).size() != (mesh["vertices"] as Array).size():
		push_warning("art: %s is not a full-body picture, using the rig" % json_path)
		return {}
	var bones: Array = []
	var index := {}
	for b in data["bones"]:
		if not b is Dictionary or not b.has("name") or (str(b.get("parent", "")) != "" and not index.has(str(b["parent"]))):
			push_warning("art: %s has a bad bone %s, using the rig" % [json_path, str(b)])
			return {}
		index[str(b["name"])] = bones.size()
		bones.append({"name": str(b["name"]), "parent": str(b.get("parent", "")), "at": _vec2(b.get("at", [])), "tip": _vec2(b.get("tip", []))})
	var vertices := PackedVector2Array()
	for v in mesh["vertices"]:
		vertices.append(_vec2(v))
	var n := vertices.size()
	var polygons: Array = []
	var tris: Array = mesh["triangles"]
	for t in range(0, tris.size() - 2, 3):
		var tri := PackedInt32Array([int(tris[t]), int(tris[t + 1]), int(tris[t + 2])])
		for i in tri:
			if i < 0 or i >= n:
				push_warning("art: %s triangle index %d out of range, using the rig" % [json_path, i])
				return {}
		polygons.append(tri)
	var weights: Array = []
	for b in bones:
		var w := PackedFloat32Array()
		w.resize(n)
		weights.append(w)
	for vi in n:
		var row: Array = data["weights"][vi]
		for k in range(0, row.size() - 1, 2):
			var bi := int(row[k])
			if bi >= 0 and bi < bones.size():
				weights[bi][vi] = float(row[k + 1])
	var anims: Dictionary = _load_json(FULL_ANIMS).duplicate(true)
	anims.erase("_doc")
	var own = data.get("anims")
	if own is Dictionary:
		for anim in own:
			if not own[anim] is Dictionary:
				continue
			if anims.get(anim) is Dictionary:
				var merged: Dictionary = anims[anim]
				for key in own[anim]:
					if key == "tracks" and own[anim]["tracks"] is Dictionary:
						merged["tracks"].merge(own[anim]["tracks"], true)
					else:
						merged[key] = own[anim][key]
			else:
				anims[anim] = own[anim]
	if not anims.get("idle") is Dictionary or polygons.is_empty() or bones.is_empty():
		push_warning("art: %s has no idle, mesh or bones, using the rig" % json_path)
		return {}
	var tex := _rig_texture(png_path)
	if tex == null:
		return {}
	return {"texture": tex, "size": _vec2(data.get("size", [])), "pivot": _vec2(data["pivot"]), "height": float(data.get("height", 0.0)),
		"scale": float(data["scale"]), "bones": bones, "vertices": vertices, "polygons": polygons, "weights": weights, "anims": anims}


## A part picture: the imported texture, else the PNG itself, else null.
static func _rig_texture(path: String) -> Texture2D:
	var cached: Texture2D = _textures.get(path)
	if cached != null:
		return cached
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			_textures[path] = t
			return t
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			var t := ImageTexture.create_from_image(img)
			_textures[path] = t
			return t
	_warn(path)
	return null


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
