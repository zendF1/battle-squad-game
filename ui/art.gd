extends RefCounted
## The one place that maps art ids to image files under res://assets/ (see assets/README.md).
## Every texture the game shows comes through here, so an artist can overwrite a PNG with the
## same name (or edit a character's SpriteFrames .tres) and the game changes with no code edit.
## A missing file never crashes: a character falls back to rookie, an icon to the "unknown"
## icon, anything else to a small grey placeholder (with a warning, once per path).
## tools/bake_art.gd draws the placeholder art into these same paths.

const GameData := preload("res://autoload/game_data_model.gd")

const ROOT := "res://assets/"
const LogicalSizeTexture := preload("res://ui/logical_size_texture.gd")

# ── Characters ──────────────────────────────────────────────────────────────

const CHARACTERS := ["rookie", "tanko", "spark", "flora", "tide"]
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
const HEAD_PART := 0.36 # side_head(): the head's share of the figure's height, from its top
## The ground shadow under a character (centred on the feet), drawn at PX_PER_UNIT too.
const SHADOW := ROOT + "characters/shadow.png"
## The hand drawn over the gun's grip (centred on the grip), shared by every character.
const HAND := ROOT + "characters/hand.png"
## The screens outside the match (lobby stage, Prep, Nhân vật) draw <id>/lobby/full.png (one
## full-body picture, cut from art_source/characters/lineup_v1.png) skinned on the skeleton in
## <id>/lobby/full.json (scenes/character/full_body.gd), animated by FULL_ANIMS merged with the
## full.json's anims; lobby_full() falls back to {} (the frames above) when either file is
## missing or broken. The match keeps the side-view frames.
const LOBBY_VIEW := "lobby"
const FULL_ANIMS := ROOT + "characters/lobby_full_anims.json"
## The match draws a character's side view: <id>/side/ (side.json + its frames, hand.png (none
## with a ready pose: the gun is held only there) and gun_anchors.json, made from hand-drawn frames by tools/import_frames.gd) when it has one,
## else the code-baked frames above (<id>.tres, gun_anchors.json, FRAME_SIZE / FRAME_PIVOT).
## character_look() picks one: side view → baked frames → rookie's side view → rookie's baked
## frames → empty animations. Every character has its side view now; the baked frames stay the
## fallback of a missing / broken one and the art of a new character without drawn frames
## (tools/bake_art.gd draws them for a character without a side view).
const SIDE_VIEW := "side"
## side.json `motion` names scenes/character/character.gd plays on top of the frames.
const SIDE_MOTIONS := ["", "breathe", "recoil", "knockback", "fall"]
## An optional side.json animation: drawn frames of the gun draw (holstered → ready to shoot),
## shown by the draw's progress in the match (scenes/character/gun_draw.gd); its gun anchors (same
## name in gun_anchors.json, optional) place the gun on them. Without it the draw is a code transition.
const DRAW_ANIM := "draw"
## An optional side.json animation: the shot fired from the drawn draw frames (the ready pose with
## the recoil), played instead of `shoot` while the gun is out in the match.
const FIRE_ANIM := "fire"

# ── Guns (assets/weapons/) ──────────────────────────────────────────────────

## The gun a character holds is a separate sprite: assets/weapons/<kind>/<tier>.png, side view,
## facing right; weapons.json gives each sprite's grip pivot and muzzle point (px in the image)
## and the px per art unit it is drawn at. A kind with no held sprites (the bazooka, the cannon, the
## seed launcher, the shock rifle: Rookie, Tanko, Flora and Spark only hug them, in their drawn ready
## poses) is its hug art (hug_<tier>.png, below) wherever a gun is shown; only the blaster (generic
## and crafted weapons, any character) has held sprites. The frames of each character carry, per animation
## frame, where the hand holds it (assets/characters/<id>/gun_anchors.json: grip px in the frame,
## angle in degrees, in front of or behind the body, muzzle flash 0..1).
## Kind = silhouette, tier = look. `basic` is a character's starter gun (no weapon equipped).
const GUN_KINDS := ["bazooka", "cannon", "shock_rifle", "seed_launcher", "water_gun", "blaster"]
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
	"water_gun": [GUN_BASIC, "iron", "steel", "mithril", "dragon"],
	"blaster": [GUN_BASIC, "iron", "steel", "mithril", "dragon", "silver", "gold", "titan", "diamond"],
}
## A character's gun when it has none of its own (no / an unknown gunKind in the game data): the
## gun the fallback character's art (DEFAULT_CHARACTER) hugs.
const DEFAULT_GUN_KIND := "bazooka"
## gun()'s last fallback: the generic blaster's basic sprite.
const FALLBACK_GUN_KIND := "blaster"
const GUNS_DATA := ROOT + "weapons/weapons.json"
## The hug guns: the big guns a drawn ready pose hugs against the chest (hug_gun()):
## assets/weapons/<kind>/hug_<tier>.png, horizontal, muzzle right, no hand grips (made by
## tools/import_hug_guns.gd); hug.json gives each one's size, hold point (where the pose turns it)
## and muzzle (px in the image). A kind with hug art but no held sprites (the bazooka, the cannon, the seed launcher, the shock rifle) is drawn
## from it everywhere (gun(): the pedestal too).
const HUG_DATA := ROOT + "weapons/hug.json"

# ── Icons (96x96, drawn shapes) ─────────────────────────────────────────────

## The icons are drawn on a 96 px canvas (tools/art/icon_painter.gd) and baked at twice that
## (tools/bake_art.gd): a box up to 64 design px, up to 2.4 × that on a big window.
const ICON_PAINT_SIZE := Vector2i(96, 96)
const ICON_SIZE := Vector2i(192, 192)
const ICONS := [
	"gem", "coin", "plus", "weapon", "skill", "battle",
	"characters", "inventory", "history", "shop", "upgrade", "milestone",
	"swap", "send", "back", "arrow_left", "arrow_right", "check", "close", "end_turn", "unknown",
	"medkit", "teleport", "power_shot", "drill_bomb", "spider_net", "freeze_bomb", "air_strike", "wind_stopper",
	"poison_bomb", "double_shot", "triple_shot", "nuke_bomb", "laser_strike",
]
const UNKNOWN_ICON := "unknown"

# ── Equipment (icons/equipment/) ────────────────────────────────────────────

## One icon per slot × tier (128x128), a white silhouette per slot for an empty slot (tinted in
## the UI), the hexagon slot frames (132x152) and the "+N" badge 9-patch.
const EQUIP_SLOTS := ["weapon", "armor", "helmet", "pants", "boots", "gloves"]
const EQUIP_TIERS := ["iron", "steel", "mithril", "dragon", "silver", "gold", "titan", "diamond"]
## Weapons are guns: weapon_<tier>.png is the generic blaster (generic and crafted weapons); each
## character's gun has its own icons in the normal tiers, weapon_<kind>_<tier>.png.
const EQUIP_WEAPON_KINDS := ["bazooka", "cannon", "rifle", "launcher", "water"]
const EQUIP_KIND_TIERS := ["iron", "steel", "mithril", "dragon"]
## The equipment icons (<slot>_<tier>.png: tools/import_equipment.gd; the guns' weapon_<tier>.png,
## weapon_<kind>_<tier>.png: tools/import_guns.gd, import_hug_guns.gd): twice the biggest box one is
## shown in (the Kho đồ card, 112 design px), as a big window shows that box up to 2.4 × bigger.
const EQUIP_ICON_SIZE := Vector2i(256, 256)
const EQUIP_WEAPON_ICON_SIZE := EQUIP_ICON_SIZE
## The code-drawn equipment art's canvas (tools/art/equipment_painter.gd, baked by tools/bake_art.gd
## only for what is not imported, and the slot silhouettes slot_<slot>.png, the Nhân vật page's
## empty slots 70 design px wide), baked at EQUIP_ICON_SIZE.
const EQUIP_PAINT_SIZE := Vector2i(128, 128)
const EQUIP_FRAMES := ["hex_empty", "hex_filled", "hex_selected"]
const EQUIP_FRAME_SIZE := Vector2i(132, 152)
const EQUIP_BADGE := ROOT + "icons/equipment/badge.png"
## badge.png texture margins [left, top, right, bottom].
const EQUIP_BADGE_MARGINS := [15, 15, 15, 15]

# ── Upgrade stones (icons/stones/) ──────────────────────────────────────────

## One icon per stone level 1..12 (128x128, tools/art/stone_painter.gd): a gem whose colour and
## cut escalate with the level (1–3 grey / green, 4–6 blue, 7–9 purple, 10–12 gold / red, glowing).
const STONE_LEVELS := 12
## The stones are drawn on a 128 px canvas (tools/art/stone_painter.gd) and baked at three times
## that: the Ghép đá page shows the merged stone 150 design px wide.
const STONE_PAINT_SIZE := Vector2i(128, 128)
const STONE_ICON_SIZE := Vector2i(384, 384)

# ── Environment, terrain, effects ───────────────────────────────────────────

const ENV := {
	"sky_match": ROOT + "env/sky_match.png",
	"cloud_0": ROOT + "env/cloud_0.png",
	"cloud_1": ROOT + "env/cloud_1.png",
	"cloud_2": ROOT + "env/cloud_2.png",
	"home_bg": ROOT + "env/home_bg.png",
	"lobby_bg": ROOT + "env/lobby_bg.png",
	"matchmaking_pvp": ROOT + "env/matchmaking_pvp.png",
	"matchmaking_boss_ice_witch": ROOT + "env/matchmaking_boss_ice_witch.png",
	"matchmaking_boss_lava_crab": ROOT + "env/matchmaking_boss_lava_crab.png",
	"matchmaking_boss_steel_robot": ROOT + "env/matchmaking_boss_steel_robot.png",
	"matchmaking_boss_rock_giant": ROOT + "env/matchmaking_boss_rock_giant.png",
	"matchmaking_boss_tree_spirit": ROOT + "env/matchmaking_boss_tree_spirit.png",
	"result": ROOT + "env/result.png",
	"pedestal": ROOT + "env/pedestal.png",
	"login_bg": ROOT + "env/login_bg.png",
	"loading_bg": ROOT + "env/loading_bg.png",
}
const CLOUDS := ["cloud_0", "cloud_1", "cloud_2"]
## pedestal.png: the centre of the stage's top face (where the feet go), px in the image.
const PEDESTAL_CENTER := Vector2(200, 52)
## The screen backgrounds (ui/backdrop.gd). home_bg (BG_HOME, the night sky, 1600x900, stretched
## over the screen): the Home pages and the Loadout. The bright ones (assets/env/<key>.png, opaque,
## about 2.36:1, their own ground, drawn "cover"): lobby_bg (the lobby stage before a mode is
## picked), matchmaking_pvp (a PvP mode), matchmaking_boss_<bossId> (a boss mode; ENV lists the
## bosses with art, a boss without one gets lobby_bg) and result (the result screens). The mode →
## key mapping is LobbyModel.background().
const BG_HOME := "home_bg"
const BG_DEFAULT := "lobby_bg"
const BG_PVP := "matchmaking_pvp"
const BG_BOSS_PREFIX := "matchmaking_boss_"
const BG_RESULT := "result"
## The first screens' pictures (2048 x 1144, opaque, drawn framed: frame_rect()): login_bg (the squad on
## a hill, screens/login.gd), loading_bg (two floating forts over the clouds, screens/splash.gd).
const BG_LOGIN := "login_bg"
const BG_LOADING := "loading_bg"
## The game's logo (assets/branding/logo.png: the helmet emblem over the BATTLE SQUAD wordmark,
## transparent, 628 x 631; ui/brand.gd places it). assets/branding/splash.png (the boot splash: the
## logo on the splash colour) and assets/branding/icon/ (the app icons) are export-time files read by
## project.godot / export_presets.cfg only.
const LOGO := ROOT + "branding/logo.png"
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
## 2 px per world px, centred, drawn turned to the flight; the bazooka's is a rocket),
## trail.png (32x32 trail particle) and impact_0..N.png (the burst). A missing projectile falls
## back to the round bomb (FX "bomb", assets/fx/common/bomb.png, also what an air strike drops),
## a missing impact to bazooka/'s fire explosion, a missing trail to the smoke puff.
## Effects every kind uses (bomb, smoke, debris, muzzle flash) are in assets/fx/common/; the
## shared tier overlays (match/views/shot_look.gd TIERS: glow, sparkles, embers, coins, shards,
## shockwave ring, lens flare, ground cracks) in assets/fx/tiers/, all drawn white-ish and tinted
## in code except the coin and the crack.
const SHOT_KINDS := GUN_KINDS
const SHOT_PARTS := ["projectile", "trail"]
const DEFAULT_SHOT_KIND := "bazooka"
const TIER_FX := ["glow", "sparkle", "ember", "coin", "shard", "ring", "flare", "crack"]
const FX := {
	"bomb": ROOT + "fx/common/bomb.png",
	"smoke": ROOT + "fx/common/smoke.png",
	"debris": ROOT + "fx/common/debris.png",
	"muzzle": ROOT + "fx/common/muzzle.png",
}

# ── Title plates (ui/titles/) ───────────────────────────────────────────────

## One banner per rarity (tools/import_titles.gd, ui/title_plate.gd); an unknown rarity draws
## as blue. titles.json: per rarity the texture size, the x ranges a long name may widen
## ("stretch") and the name's box ("text"), texture px; TITLE_FALLBACK while it is missing.
const TITLE_RARITIES := ["blue", "orange", "purple", "red"]
const TITLES_DATA := ROOT + "ui/titles/titles.json"
const TITLE_FALLBACK := {"size": [506, 107], "stretch": [[147, 357]], "text": [111, 34, 400, 73]}

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
static var _hug_data: Variant = null # parsed hug.json ({} when missing)
static var _looks := {} # character id -> character_look()
static var _sides := {} # side view dir -> parse_side() ({} = none)
static var _heads := {} # character id -> side_head()
static var _ready_poses := {} # character id -> ready_pose()
static var _carry_poses := {} # carry scene path -> carry_pose()
static var _placeholder: Texture2D
static var _empty_frames: SpriteFrames
static var _fulls := {} # character id -> lobby_full() data ({} = none)
static var _lobby_heads := {} # character id -> lobby_head()
static var _titles_data: Variant = null # parsed titles.json ({} when missing)


## The gun kind each character's own weapons are (its basic gun when no weapon is equipped): its
## gunKind in the game data, DEFAULT_GUN_KIND for none or one with no art.
static func character_gun(id: String) -> String:
	var kind := GameData.character_gun_kind(id)
	return kind if GUN_KINDS.has(kind) else DEFAULT_GUN_KIND


## The id, or DEFAULT_CHARACTER for an unknown or missing one (e.g. a bot without one).
static func known_character(id: String) -> String:
	return id if CHARACTERS.has(id) else DEFAULT_CHARACTER


static func frame_path(id: String, anim: String, i: int) -> String:
	return ROOT + "characters/%s/%s_%d.png" % [id, anim, i]


static func frames_path(id: String) -> String:
	return ROOT + "characters/%s/%s.tres" % [id, id]


static func portrait_path(id: String) -> String:
	return ROOT + "characters/%s/portrait.png" % id


static func full_path(id: String) -> String:
	return ROOT + "characters/%s/%s/full.png" % [id, LOBBY_VIEW]


static func full_json_path(id: String) -> String:
	return ROOT + "characters/%s/%s/full.json" % [id, LOBBY_VIEW]


static func gun_path(kind: String, tier: String) -> String:
	return ROOT + "weapons/%s/%s.png" % [kind, tier]


static func hug_gun_path(kind: String, tier: String) -> String:
	return ROOT + "weapons/%s/hug_%s.png" % [kind, tier]


## The screens outside the match show a gun several times bigger than the match draws it (the
## lobby / Nhân vật / Prep pedestal, a party slot, the character info): its high-resolution picture,
## assets/weapons/<kind>/ui_<tier>.png (tools/import_hug_guns.gd / import_guns.gd `uiLength`: the
## same canvas as the match picture, hug_<tier>.png or <tier>.png, only more px), mipmapped.
static func ui_gun_path(kind: String, tier: String) -> String:
	return ROOT + "weapons/%s/ui_%s.png" % [kind, tier]


## The UI picture of the gun a gun() / hug_gun() dictionary names (its kind / tier after the
## fallbacks), else its match texture (no UI picture yet). Same canvas: a region of the match
## texture is the same region of it scaled by ui_size / match_size.
static func ui_gun_texture(g: Dictionary) -> Texture2D:
	var path := ui_gun_path(str(g.get("kind", "")), str(g.get("tier", "")))
	if g.has("kind") and has_png(path):
		var t := _png_texture(path)
		if t != null:
			return t
	return g.get("texture")


static func gun_anchors_path(id: String) -> String:
	return ROOT + "characters/%s/gun_anchors.json" % id


static func side_dir(id: String) -> String:
	return ROOT + "characters/%s/%s/" % [id, SIDE_VIEW]


static func side_json_path(id: String) -> String:
	return side_dir(id) + "side.json"


## The character has a side view (its side.json exists; side_view() checks the rest).
static func has_side_view(id: String) -> bool:
	return FileAccess.file_exists(side_json_path(id))


# ── Bosses (drawn art; without it match/boss/boss_art.gd draws them in code) ──

static var _boss_sides := {} # boss art id -> boss_side() ({} = none)
static var _boss_pictures := {} # path -> Texture2D (null = none)


static func boss_dir(id: String) -> String:
	return ROOT + "bosses/%s/" % id


## A boss's drawn side view (assets/bosses/<id>/side/side.json and its frames, written by
## tools/import_boss_frames.gd): {size, pivot (the feet, texture px), height (the body, texture
## px), width, facing (1: drawn facing right), anims {name: {frames [Texture2D], fps, loop, peak}}};
## {} when there is none, it has no idle (frames or a skinned one: boss_skin()) or a frame is
## missing (the code-drawn art then). Frames
## not imported yet are read from the PNG (with mipmaps: drawn smaller than they are).
static func boss_side(id: String) -> Dictionary:
	if _boss_sides.has(id):
		return _boss_sides[id]
	var out := {}
	_boss_sides[id] = out
	var dir := boss_dir(id) + "side/"
	if id == "" or not id.is_valid_filename() or not FileAccess.file_exists(dir + "side.json"):
		return out
	var data := _load_json(dir + "side.json")
	var idle_ok: bool = data.get("anims") is Dictionary and (data["anims"].has("idle") or FileAccess.file_exists(boss_dir(id) + "skin/idle/skin.json"))
	if not idle_ok or not data.get("pivot") is Array or float(data.get("height", 0.0)) <= 0.0:
		push_warning("art: %sside.json is not a boss side view, drawing it in code" % dir)
		return out
	var anims := {}
	for anim in data["anims"]:
		var spec = data["anims"][anim]
		if not spec is Dictionary or not spec.get("frames") is Array or (spec["frames"] as Array).is_empty():
			continue
		var frames: Array = []
		for stem in spec["frames"]:
			var tex := _boss_texture(dir + str(stem) + ".png")
			if tex == null:
				push_warning("art: %s%s.png missing, drawing the boss in code" % [dir, stem])
				return out
			frames.append(tex)
		anims[str(anim)] = {"frames": frames, "fps": maxf(float(spec.get("fps", 8.0)), 0.1), "loop": bool(spec.get("loop", false)),
			"peak": int(spec.get("peak", -1))}
	out.merge({"size": _vec2(data.get("size", [])), "pivot": _vec2(data["pivot"]), "height": float(data["height"]),
		"width": float(data.get("width", float(data["height"]) * 0.6)), "facing": 1 if int(data.get("facing", 1)) >= 0 else -1,
		"anims": anims})
	return out


static var _boss_skins := {} # "<boss art id>/<name>" -> boss_skin() ({} = none)


## A boss's skinned animation `name` (idle: the portrait; fly: the side view gliding;
## assets/bosses/<id>/skin/<name>/: body.png on a skeleton, skin.json in the lobby characters'
## full.json format, written by tools/import_boss_frames.gd; drawn by match/boss/boss_skin_view.gd):
## parse_full()'s {texture, size, pivot, height, scale, bones, vertices, polygons, weights, anims}
## plus motion (idle / glide), shards [{texture, at (top-left px), size}] and glow (the staff
## crystal, px); {} without one (the frames, else the code art).
static func boss_skin(id: String, name: String = "idle") -> Dictionary:
	var key := id + "/" + name
	if _boss_skins.has(key):
		return _boss_skins[key]
	var out := {}
	_boss_skins[key] = out
	if not name.is_valid_filename():
		return out
	var dir := boss_dir(id) + "skin/%s/" % name
	if id == "" or not id.is_valid_filename() or not FileAccess.file_exists(dir + "skin.json"):
		return out
	var data := parse_full(dir + "skin.json", dir + "body.png")
	if data.is_empty():
		return out
	var mipmapped := _boss_texture(dir + "body.png") # drawn smaller than it is
	if mipmapped != null:
		data["texture"] = mipmapped
	var raw := _load_json(dir + "skin.json")
	var shards: Array = []
	for s in raw.get("shards", []):
		if not s is Dictionary:
			continue
		var tex := _boss_texture(dir + str(s.get("file", "")))
		if tex != null:
			shards.append({"texture": tex, "at": _vec2(s.get("at", [])), "size": _vec2(s.get("size", []))})
	data["shards"] = shards
	data["glow"] = _vec2(raw.get("glow", []))
	data["motion"] = str(raw.get("motion", "idle"))
	out.merge(data)
	return out


## A boss's picture (`name`: portrait, the full-body hero pose of its cards; bust, the head and
## shoulders of its HP bar and turn portrait): assets/bosses/<id>/<name>.png, null without one.
static func boss_picture(id: String, name: String) -> Texture2D:
	var path := boss_dir(id) + name + ".png"
	if _boss_pictures.has(path):
		return _boss_pictures[path]
	var t: Texture2D = null
	if id != "" and id.is_valid_filename() and name.is_valid_filename() and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		t = _boss_texture(path)
	_boss_pictures[path] = t
	return t


## A boss texture: the imported one, else the PNG itself with mipmaps (not imported yet).
static func _boss_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path) and _imported(path):
		var t = load(path)
		if t is Texture2D:
			return t
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	return null


static func icon_path(icon_name: String) -> String:
	return ROOT + "icons/%s.png" % icon_name


static func equipment_icon_path(slot: String, tier: String) -> String:
	return ROOT + "icons/equipment/%s_%s.png" % [slot, tier]


static func equipment_weapon_path(kind: String, tier: String) -> String:
	return ROOT + "icons/equipment/weapon_%s_%s.png" % [kind, tier]


static func equipment_slot_path(slot: String) -> String:
	return ROOT + "icons/equipment/slot_%s.png" % slot


static func stone_path(level: int) -> String:
	return ROOT + "icons/stones/stone_%d.png" % level


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


## The rarity, or blue for an unknown one.
static func title_rarity(rarity: String) -> String:
	return rarity if TITLE_RARITIES.has(rarity) else TITLE_RARITIES[0]


static func title_path(rarity: String) -> String:
	return ROOT + "ui/titles/title_%s.png" % title_rarity(rarity)


## The plate of a rarity (blue for an unknown one); the PNG itself while not imported yet.
static func title_texture(rarity: String) -> Texture2D:
	return texture(title_path(rarity))


## A rarity's plate layout {size: Vector2, stretch: [Vector2(x0, x1), ...], text: Rect2}, texture
## px (titles.json; TITLE_FALLBACK scaled to the texture when the file or the entry is missing).
static func title_meta(rarity: String) -> Dictionary:
	if _titles_data == null:
		_titles_data = _load_json(TITLES_DATA)
	var raw = _titles_data.get(title_rarity(rarity))
	if not raw is Dictionary or not raw.get("size") is Array or not raw.get("text") is Array or not raw.get("stretch") is Array:
		raw = TITLE_FALLBACK
	var stretch: Array = []
	for r in raw["stretch"]:
		if r is Array and r.size() >= 2 and float(r[1]) > float(r[0]):
			stretch.append(Vector2(float(r[0]), float(r[1])))
	var t: Array = raw["text"]
	return {"size": _vec2(raw["size"]), "stretch": stretch,
		"text": Rect2(float(t[0]), float(t[1]), float(t[2]) - float(t[0]), float(t[3]) - float(t[1]))}


## Every file this script names (the test checks they all exist).
static func all_paths() -> Array[String]:
	var out: Array[String] = [SHADOW, HAND, GUNS_DATA, HUG_DATA, FULL_ANIMS, LOGO]
	for id in CHARACTERS:
		out.append(portrait_path(id))
		if has_side_view(id):
			out.append_array(side_paths(id))
		else:
			out.append(frames_path(id))
			out.append(gun_anchors_path(id))
			for anim in ANIMS:
				for i in int(ANIMS[anim]["frames"]):
					out.append(frame_path(id, anim, i))
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
	out.append(TITLES_DATA)
	for rarity in TITLE_RARITIES:
		out.append(title_path(rarity))
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
	for level in range(1, STONE_LEVELS + 1):
		out.append(stone_path(level))
	for kind in GUN_KINDS:
		for tier in GUN_TIERS[kind]:
			if not gun_meta(kind, tier).is_empty():
				out.append(gun_path(kind, tier))
			if not hug_meta(kind, tier).is_empty():
				out.append(hug_gun_path(kind, tier))
	return out


## The texture at path (the PNG itself while the editor has not imported it yet), or a small grey
## placeholder when the file is missing. Loaded textures stay cached: a texture only passed to a
## draw call must outlive the frame.
static func texture(path: String) -> Texture2D:
	var t := _png_texture(path)
	return t if t != null else placeholder()


static func placeholder() -> Texture2D:
	if _placeholder == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.6, 0.6, 0.65, 0.6))
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder


## An icon by name (ICONS), or the "unknown" icon. A freshly baked icon the editor has not
## imported yet loads from its PNG.
static func icon(icon_name: String) -> Texture2D:
	var path := icon_path(icon_name)
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return texture(path)
	_warn(path)
	return texture(icon_path(UNKNOWN_ICON))


## An icon for a Button (assets/icons/<name>.png, Art.icon()): the baked picture with all its px,
## standing in at the paint size (ui/logical_size_texture.gd: a Button's minimum size counts its
## icon's px, so the buttons keep the layout they had with the 96 px icons). Cached.
static func button_icon(icon_name: String) -> Texture2D:
	var key := "button:" + icon_name
	if not _textures.has(key):
		_textures[key] = LogicalSizeTexture.of(icon(icon_name), ICON_PAINT_SIZE)
	return _textures[key]


## An item's icon for a Button (Art.item_icon() as button_icon()).
static func item_button_icon(item_id: String) -> Texture2D:
	return button_icon(item_id if ICONS.has(item_id) else UNKNOWN_ICON)


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


## The icon of an upgrade stone level (clamped to 1..STONE_LEVELS); the PNG itself while the
## editor has not imported it yet, the placeholder when it is missing.
static func stone_icon(level: int) -> Texture2D:
	return texture(stone_path(clampi(level, 1, STONE_LEVELS)))


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


## The file of a screen background key (BG_*; a boss's BG_BOSS_PREFIX + bossId).
static func background_path(key: String) -> String:
	return ROOT + "env/%s.png" % key


## The background key of a boss (matchmaking_boss_<bossId>).
static func boss_background(boss_id: String) -> String:
	return BG_BOSS_PREFIX + boss_id


## The key a screen draws for `key`: itself when its image is in the project, else BG_DEFAULT (a
## new boss without art, "" none).
static func background_key(key: String) -> String:
	if key == "" or key.contains("/") or key.contains(".") or not has_png(background_path(key)):
		return BG_DEFAULT
	return key


## A screen background (background_key(): lobby_bg when `key` has no image).
static func background(key: String) -> Texture2D:
	return texture(background_path(background_key(key)))


## The part of a `tex_size` texture that fills a `rect_size` rect "cover": the texture's aspect
## kept, the rect filled, the overflow cut off evenly on both sides (texture px).
static func cover_source(tex_size: Vector2, rect_size: Vector2) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return Rect2(Vector2.ZERO, tex_size.max(Vector2.ZERO))
	var k := maxf(rect_size.x / tex_size.x, rect_size.y / tex_size.y) # texture px → rect px
	var part := rect_size / k
	return Rect2((tex_size - part) / 2.0, part)


## Where a `tex_size` picture goes in a `rect_size` rect, drawn "framed" (the whole texture's rect,
## rect px): cover (the aspect kept, the rect filled), the overflow cut by `align` (0 keeps the top /
## left, 1 the bottom / right, 0.5 even); but never cutting into `keep` (texture UV 0..1, the part of
## the picture that must stay on screen: the squad on the login picture). Where cover would, the
## picture is drawn just small enough to show all of `keep` and placed by `align`, leaving a band of
## the rect uncovered (ui/backdrop.gd fills it from the picture's edges). `keep` with no area: cover.
static func frame_rect(tex_size: Vector2, rect_size: Vector2, keep: Rect2 = Rect2(), align: Vector2 = Vector2(0.5, 0.5)) -> Rect2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return Rect2(Vector2.ZERO, rect_size.max(Vector2.ZERO))
	var k := maxf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var has_keep := keep.size.x > 0.0 and keep.size.y > 0.0
	if has_keep:
		var ks := keep.size * tex_size
		k = minf(k, minf(rect_size.x / ks.x, rect_size.y / ks.y))
	var drawn := tex_size * k
	var pos := (rect_size - drawn) * align
	if has_keep:
		var k0 := keep.position * drawn
		var k1 := keep.end * drawn
		pos.x = clampf(pos.x, -k0.x, rect_size.x - k1.x)
		pos.y = clampf(pos.y, -k0.y, rect_size.y - k1.y)
	return Rect2(pos, drawn)


## Sides of a picture (edge_strip()).
enum { SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM, SIDE_LEFT }
## edge_strip(): the averaged edge is this share of the picture deep, in EDGE_STRIP_PX buckets.
const EDGE_DEPTH := 0.02
const EDGE_STRIP_PX := 8
static var _edges := {} # "key/side" → ImageTexture

## A background's colours along one side (SIDE_*), averaged EDGE_DEPTH deep into EDGE_STRIP_PX buckets
## along the side: an EDGE_STRIP_PX x 1 texture (top, bottom) or 1 x EDGE_STRIP_PX (left, right) that
## ui/backdrop.gd stretches over a band frame_rect() leaves uncovered, so the sky or the grass goes on.
## Made once per key and side; a 1 x 1 grey when the pixels cannot be read.
static func edge_strip(key: String, side: int) -> Texture2D:
	key = background_key(key)
	var id := "%s/%d" % [key, side]
	if _edges.has(id):
		return _edges[id]
	var img: Image = background(key).get_image()
	var out: Image
	if img == null or img.is_empty():
		out = Image.create(1, 1, false, Image.FORMAT_RGB8)
		out.fill(Color(0.5, 0.6, 0.7))
	else:
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGB8)
		var w := img.get_width()
		var h := img.get_height()
		var across := side == SIDE_TOP or side == SIDE_BOTTOM
		var length := w if across else h
		var depth := maxi(1, roundi((h if across else w) * EDGE_DEPTH))
		out = Image.create(EDGE_STRIP_PX if across else 1, 1 if across else EDGE_STRIP_PX, false, Image.FORMAT_RGB8)
		for b in EDGE_STRIP_PX:
			var sum := Color(0, 0, 0)
			var n := 0
			for along in range(floori(float(b * length) / EDGE_STRIP_PX), floori(float((b + 1) * length) / EDGE_STRIP_PX)):
				for d in depth:
					var p: Vector2i
					match side:
						SIDE_TOP: p = Vector2i(along, d)
						SIDE_BOTTOM: p = Vector2i(along, h - 1 - d)
						SIDE_LEFT: p = Vector2i(d, along)
						_: p = Vector2i(w - 1 - d, along)
					var c := img.get_pixelv(p)
					sum.r += c.r
					sum.g += c.g
					sum.b += c.b
					n += 1
			var avg := Color(sum.r / n, sum.g / n, sum.b / n)
			out.set_pixel(b if across else 0, 0 if across else b, avg)
	var t := ImageTexture.create_from_image(out)
	_edges[id] = t
	return t


## The mean of a background's top and bottom edge colours (edge_strip()), made once per key.
static func edge_mean(key: String) -> Color:
	key = background_key(key)
	var id := key + "/mean"
	if not _edges.has(id):
		var sum := Color(0, 0, 0)
		var n := 0
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			var img: Image = edge_strip(key, side).get_image()
			for x in img.get_width():
				var c := img.get_pixel(x, 0)
				sum.r += c.r
				sum.g += c.g
				sum.b += c.b
				n += 1
		_edges[id] = Color(sum.r / n, sum.g / n, sum.b / n)
	return _edges[id]


static var _blurred := {} # background key → its blurred ImageTexture

## A lightly blurred copy of a screen background (the Matchmaking screen's: barely soft, the
## picture still reads): the image shrunk to BLUR_WIDTH px wide (Lanczos; about a third of the
## 1024 px backgrounds, so detail under ~3 px goes soft), a Gaussian of BLUR_SIGMA px over it when
## above 0, then grown to BLUR_KEEP px (cubic) for the GPU to stretch, made once per key. The
## sharp one when its pixels cannot be read.
const BLUR_WIDTH := 340
const BLUR_SIGMA := 0.0
const BLUR_KEEP := 1024
static func blurred_background(key: String) -> Texture2D:
	key = background_key(key)
	if _blurred.has(key):
		return _blurred[key]
	var sharp := background(key)
	var img: Image = sharp.get_image() if sharp != placeholder() else null
	if img == null or img.is_empty():
		return sharp
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	var aspect := float(img.get_height()) / img.get_width()
	img.resize(BLUR_WIDTH, maxi(roundi(BLUR_WIDTH * aspect), 1), Image.INTERPOLATE_LANCZOS)
	if BLUR_SIGMA > 0.0:
		img = gaussian_blur(img, BLUR_SIGMA)
	img.resize(BLUR_KEEP, maxi(roundi(BLUR_KEEP * aspect), 1), Image.INTERPOLATE_CUBIC)
	var t := ImageTexture.create_from_image(img)
	_blurred[key] = t
	return t


## A separable Gaussian blur (sigma px, edges clamped) of an RGB8 image.
static func gaussian_blur(img: Image, sigma: float) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var r := maxi(ceili(sigma * 3.0), 1)
	var k := PackedFloat32Array()
	var sum := 0.0
	for i in range(-r, r + 1):
		k.append(exp(-float(i * i) / (2.0 * sigma * sigma)))
		sum += k[k.size() - 1]
	for i in k.size():
		k[i] /= sum
	var src := img.get_data()
	var tmp := PackedFloat32Array()
	tmp.resize(w * h * 3)
	for y in h:
		for x in w:
			var c := Vector3.ZERO
			for i in range(-r, r + 1):
				var o := (y * w + clampi(x + i, 0, w - 1)) * 3
				c += Vector3(src[o], src[o + 1], src[o + 2]) * k[i + r]
			var d := (y * w + x) * 3
			tmp[d] = c.x
			tmp[d + 1] = c.y
			tmp[d + 2] = c.z
	var out := PackedByteArray()
	out.resize(w * h * 3)
	for y in h:
		for x in w:
			var c := Vector3.ZERO
			for i in range(-r, r + 1):
				var o := (clampi(y + i, 0, h - 1) * w + x) * 3
				c += Vector3(tmp[o], tmp[o + 1], tmp[o + 2]) * k[i + r]
			var d := (y * w + x) * 3
			out[d] = clampi(roundi(c.x), 0, 255)
			out[d + 1] = clampi(roundi(c.y), 0, 255)
			out[d + 2] = clampi(roundi(c.z), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, out)


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


## A gun tier's own shell picture (match/views/projectile_view.gd): assets/fx/<kind>/
## projectile_<tier>.png, for the normal tiers (PROJECTILE_TIERS) only, imported by
## tools/import_projectiles.gd (art_source/fx/projectiles/<kind>_<tier>.png).
const PROJECTILE_TIERS := GUN_NORMAL_TIERS


static func tier_projectile_path(kind: String, tier: String) -> String:
	return shot_path(kind, "projectile_%s" % tier)


## The tier's own shell picture (the PNG itself while not imported yet), or null: an unknown kind,
## basic or a crafted tier, or no file yet (the kind's projectile.png is drawn instead).
static func tier_projectile(kind: String, tier: String) -> Texture2D:
	if not SHOT_KINDS.has(kind) or not PROJECTILE_TIERS.has(tier):
		return null
	var path := tier_projectile_path(kind, tier)
	if not _textures.has(path) and not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return null
	return _png_texture(path)


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


## The SpriteFrames of a character (idle/walk/shoot/hurt/die): character_look()'s.
static func character_frames(id: String) -> SpriteFrames:
	return character_look(id)["frames"]


## How the match draws a character: {side (true: its side view), frames (SpriteFrames with
## idle/walk/shoot/hurt/die), size (Vector2 texture px), pivot (the feet, texture px), scale
## (character px per texture px: the character node is PX_PER_UNIT px per art unit), height (the
## figure, texture px), extent {back, front, top} (texture px from the pivot), motions {anim:
## SIDE_MOTIONS name}, anchors {anim: [gun anchor...]} (texture px), hand (Texture2D drawn over
## the gun's grip, null: HAND), hand_scale, draw_frames (frames has DRAW_ANIM), fire_frames (and
## FIRE_ANIM), ready (side.json "readyPose": {anims, scene, arm_front (Texture2D: the near arm
## drawn over the hugged gun, same size / pivot / scale as the frames; null without)}; {} without:
## see ready_pose()),
## gun_draw (side.json "gunDraw": gun_draw.gd TIMINGS overrides), carry (parse_carry(): how the
## match slings the gun on the back standing and walking; {} for the baked frames)}.
## Order: side view → baked frames → rookie's → empty.
static func character_look(id: String) -> Dictionary:
	id = known_character(id)
	if _looks.has(id):
		return _looks[id]
	var look := {}
	for cid in [id, DEFAULT_CHARACTER]:
		look = side_view(cid)
		if look.is_empty():
			look = _baked_look(cid)
		if not look.is_empty():
			break
	if look.is_empty():
		if _empty_frames == null:
			_empty_frames = SpriteFrames.new()
			for anim in ANIMS:
				if not _empty_frames.has_animation(anim):
					_empty_frames.add_animation(anim)
				_empty_frames.add_frame(anim, placeholder())
		look = _baked(_empty_frames, {})
	_looks[id] = look
	return look


## The code-baked frames (<id>.tres + gun_anchors.json), {} when the .tres is missing.
static func _baked_look(id: String) -> Dictionary:
	var path := frames_path(id)
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is SpriteFrames:
			return _baked(f, _parse_anchors(gun_anchors_path(id)))
	_warn(path)
	return {}


static func _baked(frames: SpriteFrames, anchors: Dictionary) -> Dictionary:
	var h := 150.0 * PX_PER_UNIT
	return {"side": false, "frames": frames, "size": Vector2(FRAME_SIZE), "pivot": FRAME_PIVOT, "scale": 1.0, "height": h,
		"extent": {"back": 40.0 * PX_PER_UNIT, "front": 40.0 * PX_PER_UNIT, "top": h}, "motions": {}, "anchors": anchors,
		"hand": null, "hand_scale": 1.0, "draw_frames": false, "fire_frames": false, "ready": {}, "gun_draw": {}, "carry": {}}


## A character's side view (see character_look()), {} when it has none or it is broken.
static func side_view(id: String) -> Dictionary:
	return parse_side(side_dir(known_character(id)))


## The side view in dir (side.json, its frames, gun_anchors.json, hand.png); {} when side.json is
## missing, lacks an animation of ANIMS or a frame file. Frames not imported yet are read from
## the PNG.
static func parse_side(dir: String) -> Dictionary:
	if _sides.has(dir):
		return _sides[dir]
	var out := {}
	_sides[dir] = out
	if not FileAccess.file_exists(dir + "side.json"):
		return out
	var data := _load_json(dir + "side.json")
	var ppu := float(data.get("pxPerUnit", 0.0))
	if ppu <= 0.0 or not data.get("pivot") is Array or not data.get("anims") is Dictionary:
		push_warning("art: %sside.json is not a side view, using the baked frames" % dir)
		return out
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var motions := {}
	for anim in ANIMS:
		var spec = data["anims"].get(anim)
		if not spec is Dictionary or not spec.get("frames") is Array or (spec["frames"] as Array).is_empty():
			push_warning("art: %sside.json has no %s, using the baked frames" % [dir, anim])
			return out
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(spec.get("fps", 8.0)))
		frames.set_animation_loop(anim, bool(spec.get("loop", false)))
		for stem in spec["frames"]:
			var tex := _png_texture(dir + str(stem) + ".png")
			if tex == null:
				return out
			frames.add_frame(anim, tex)
		var motion := str(spec.get("motion", ""))
		motions[anim] = motion if SIDE_MOTIONS.has(motion) else ""
	# Optional drawn "draw" frames (holstered → ready to shoot), played by the draw's progress
	# instead of the code transition (scenes/character/gun_draw.gd), and the "fire" frames (the
	# shot from them); a broken set is skipped (fire only with draw frames).
	for anim in [DRAW_ANIM, FIRE_ANIM]:
		var spec = data["anims"].get(anim)
		if anim == FIRE_ANIM and not frames.has_animation(DRAW_ANIM):
			break
		if not spec is Dictionary or not spec.get("frames") is Array or (spec["frames"] as Array).is_empty():
			continue
		var texs: Array[Texture2D] = []
		for stem in spec["frames"]:
			var tex := _png_texture(dir + str(stem) + ".png")
			if tex == null:
				texs.clear()
				break
			texs.append(tex)
		if not texs.is_empty():
			frames.add_animation(anim)
			frames.set_animation_loop(anim, false)
			frames.set_animation_speed(anim, float(spec.get("fps", 8.0)))
			for tex in texs:
				frames.add_frame(anim, tex)
			var motion := str(spec.get("motion", ""))
			motions[anim] = motion if SIDE_MOTIONS.has(motion) else ""
	# "readyPose": the drawn ready pose's anims, the scene its hug gun is placed in by hand
	# (ready_pose()) and its near arm drawn over that gun (armFront: a PNG stem; a missing PNG: none).
	var ready := {}
	var rp = data.get("readyPose")
	if rp is Dictionary and frames.has_animation(DRAW_ANIM):
		var ra: Array = []
		for anim in rp.get("anims", []):
			if frames.has_animation(str(anim)):
				ra.append(str(anim))
		var arm: Texture2D = null
		if str(rp.get("armFront", "")) != "":
			arm = _png_texture(dir + str(rp["armFront"]) + ".png")
		ready = {"anims": ra, "scene": str(rp.get("scene", "")), "arm_front": arm}
	var scale := PX_PER_UNIT / ppu
	var ext = data.get("extent", {})
	var height := float(data.get("height", 0.0))
	var hand: Texture2D = null
	if str(data.get("hand", "")) != "":
		hand = _png_texture(dir + str(data["hand"]))
	var carry := parse_carry(dir + "carry.json")
	out.merge({"side": true, "frames": frames, "size": _vec2(data.get("size", [])), "pivot": _vec2(data["pivot"]), "scale": scale,
		"height": height, "extent": {"back": float(ext.get("back", height * 0.3)), "front": float(ext.get("front", height * 0.3)),
		"top": float(ext.get("top", height))}, "motions": motions, "anchors": _parse_anchors(dir + "gun_anchors.json"),
		"hand": hand, "hand_scale": scale if hand != null else 1.0, "draw_frames": frames.has_animation(DRAW_ANIM),
		"fire_frames": frames.has_animation(FIRE_ANIM), "ready": ready, "carry": carry,
		"gun_draw": data.get("gunDraw", {}) if data.get("gunDraw") is Dictionary else {}})
	return out


## The head of a character's match sprite: its side view's first idle frame (facing right) and the
## square rect (frame px) round the head, found from the frame's opaque pixels (the figure's top
## HEAD_PART, centred on them, nudged towards the face); {} without a side view. Cached per
## character. The off-screen markers draw it (portrait.png is the old cartoon art).
static func side_head(id: String) -> Dictionary:
	id = known_character(id)
	if _heads.has(id):
		return _heads[id]
	var out := {}
	_heads[id] = out
	var side := side_view(id)
	if side.is_empty():
		return out
	var tex: Texture2D = (side["frames"] as SpriteFrames).get_frame_texture("idle", 0)
	var img := tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return out
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var top := -1
	var bottom := -1
	for y in h:
		var n := 0
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				n += 1
		if n >= 2:
			if top < 0:
				top = y
			bottom = y
	if top < 0:
		return out
	var band := int((bottom - top) * HEAD_PART)
	var sum := 0.0
	var count := 0
	for y in range(top, top + band):
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				sum += x
				count += 1
	var size := band * 1.2
	var cx := sum / maxi(count, 1) + band * 0.06
	out.merge({"texture": tex, "rect": Rect2(cx - size / 2.0, top + band * 0.04, size, size)})
	return out


## The head crop of a character's lobby picture (the full-body picture the lobby stage shows),
## for avatars (the leaderboard, the profile): {texture, rect} with the square rect (picture px)
## computed from its head bone (neck `at` → crown `tip`, full.json): LOBBY_HEAD_SIDE × the bone's
## length, centred LOBBY_HEAD_CENTRE of the way up it, so the face sits in the middle with the
## chin and the hair inside. {} without a lobby picture (side_head() then).
const LOBBY_HEAD_SIDE := 1.25
const LOBBY_HEAD_CENTRE := 0.5
static func lobby_head(id: String) -> Dictionary:
	id = known_character(id)
	if _lobby_heads.has(id):
		return _lobby_heads[id]
	var out := lobby_head_of(lobby_full(id))
	_lobby_heads[id] = out
	return out


## lobby_head() of a lobby_full() data.
static func lobby_head_of(full: Dictionary) -> Dictionary:
	if full.is_empty() or full.get("texture") == null:
		return {}
	for b in full.get("bones", []):
		if b["name"] != "head":
			continue
		var at: Vector2 = b["at"]
		var tip: Vector2 = b["tip"]
		var side := at.distance_to(tip) * LOBBY_HEAD_SIDE
		if side <= 0.0:
			return {}
		var c := at.lerp(tip, LOBBY_HEAD_CENTRE)
		var r := Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side))
		var pic := Rect2(Vector2.ZERO, Vector2((full["texture"] as Texture2D).get_size()))
		r.position = r.position.clamp(pic.position, pic.end - r.size) # never past the picture's edge
		return {"texture": full["texture"], "rect": r}
	return {}


## Every file of a character's side view (side.json, gun_anchors.json, the frames, hand.png, the
## ready pose's front arm).
static func side_paths(id: String) -> Array[String]:
	var dir := side_dir(id)
	var out: Array[String] = [dir + "side.json", dir + "gun_anchors.json"]
	var data := _load_json(dir + "side.json")
	var anims = data.get("anims")
	if anims is Dictionary:
		for anim in anims:
			for stem in anims[anim].get("frames", []):
				if not out.has(dir + str(stem) + ".png"):
					out.append(dir + str(stem) + ".png")
	if str(data.get("hand", "")) != "":
		out.append(dir + str(data["hand"]))
	var rp = data.get("readyPose")
	if rp is Dictionary and str(rp.get("armFront", "")) != "":
		out.append(dir + str(rp["armFront"]) + ".png")
	if FileAccess.file_exists(dir + "carry.json"):
		out.append(dir + "carry.json")
	return out


## How the match slings a side view's gun on the back outside the ready pose (scenes/character/
## character.gd idle_gun: standing and walking), from its carry.json (not made by
## tools/import_frames.gd): back {scene (the carry scene the sling is placed in by hand:
## scenes/character/poses/<id>_carry.tscn, carry_pose()), bob [[dx, dy]...] (per walk frame, the
## upper body's offset from the idle frame, px of the frame textures: tools/carry_bob.gd)}.
## Without a scene the placement can be written in the file (px of the frame textures): at [x, y]
## (the hold point on the idle frame's lower back), angle (degrees of the gun's axis from the facing
## direction, + turns the muzzle down: -122 = muzzle up and back over the shoulder), hold (0..1
## along the gun from its back end to the muzzle; missing: the gun's own hold point), scale (× its
## ready-pose size, 1), flip (drawn upside down).
## Returns {back: {scene ("" none), bob (Array of Vector2), and only when the file has `at`: at,
## angle, hold (-1: the gun's), scale, flip}}; {} when there is no file or no back part (neither
## scene nor at).
static func parse_carry(json_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		return {}
	var data := _load_json(json_path)
	var out := {}
	var b = data.get("back")
	if b is Dictionary and (b.get("at") is Array or str(b.get("scene", "")) != ""):
		var bob: Array = []
		for d in b.get("bob", []):
			bob.append(_vec2(d) if d is Array else Vector2.ZERO)
		var back := {"scene": str(b.get("scene", "")), "bob": bob}
		if b.get("at") is Array:
			back.merge({"at": _vec2(b["at"]), "angle": float(b.get("angle", -120.0)), "hold": float(b.get("hold", -1.0)),
				"scale": float(b.get("scale", 1.0)), "flip": bool(b.get("flip", false))})
		out["back"] = back
	return out


## How a character's gun is slung on its back (its carry.json back.scene), in the character's Flip
## coordinates (the feet at 0, facing right; scenes/character/character.gd): {socket (Transform2D:
## the CarrySocket, its origin the hold point on the back, its turn the gun's angle, its scale the
## size), preview (Transform2D: the Preview's texture px → socket space, its offset included), hold
## (the Preview gun's texture px under the socket's origin), muzzle_y (that gun's muzzle row, px),
## length (its length, px), texture (the Preview's picture, null: not imported yet)}; {} when the
## character has no carry scene or it is broken (the code then uses carry.json's own placement or a
## default sling). WYSIWYG: carry_gun_transform() draws any gun exactly as the Preview shows its
## own. Placed by hand in scenes/character/poses/<id>_carry.tscn (assets/README.md): root → CarrySocket
## (Node2D) → Preview (Sprite2D: the hug gun, horizontal, muzzle right, at its match size), Body (the
## idle frame, over the gun: the gun is behind the body), WalkPreview (editor only:
## poses/carry_walk.gd). A Preview with no picture stands for the character's iron hug gun at the
## hug scale, held 0.18 along it on its muzzle row.
static func carry_pose(id: String) -> Dictionary:
	var back: Dictionary = character_look(id).get("carry", {}).get("back", {})
	var path := str(back.get("scene", ""))
	if path == "":
		return {}
	if _carry_poses.has(path):
		return _carry_poses[path]
	var out := {}
	_carry_poses[path] = out
	if not ResourceLoader.exists(path):
		_warn(path)
		return out
	var ps = load(path)
	var root: Node = ps.instantiate() if ps is PackedScene else null
	var sock: Node2D = root.get_node_or_null("CarrySocket") as Node2D if root != null else null
	var pv: Sprite2D = sock.get_node_or_null("Preview") as Sprite2D if sock != null else null
	if pv == null:
		push_warning("art: %s has no CarrySocket/Preview, the carry uses its defaults" % path)
	else:
		var tex := pv.texture
		var meta := {}
		if tex != null:
			meta = pose_gun_meta(tex.resource_path)
			if meta.is_empty(): # some other picture: its muzzle row through the middle
				meta = {"muzzle": Vector2(tex.get_width(), tex.get_height() * 0.5), "size": tex.get_size()}
		var preview: Transform2D
		if tex != null:
			var corner := -tex.get_size() * 0.5 if pv.centered else Vector2.ZERO
			preview = pv.transform * Transform2D(0.0, pv.offset + corner)
		else: # not imported yet: the character's iron hug gun at the hug scale
			var own := hug_gun(character_gun(known_character(id)), "iron")
			meta = {"muzzle": own["muzzle"], "size": own["size"]}
			var hs := hug_scale()
			preview = Transform2D(0.0, Vector2(hs, hs), 0.0, Vector2.ZERO) * Transform2D(0.0, -Vector2(0.18 * float(own["size"].x), float(own["muzzle"].y)))
		out.merge({"socket": sock.transform, "preview": preview, "hold": preview.affine_inverse() * Vector2.ZERO,
			"muzzle_y": float(meta["muzzle"].y), "length": maxf(1.0, float(meta["size"].x)), "texture": tex})
	if root != null:
		root.free()
	return out


## The carry pose's (carry_pose()) gun g ({size, muzzle}: hug_gun() or a held gun) in socket space:
## texture px → socket px. The Preview's own gun is drawn exactly as the Preview shows it; any other
## is scaled to the same length and hung at the same place along it, the same height off its
## muzzle row, on the socket's origin.
static func carry_gun_transform(pose: Dictionary, g: Dictionary) -> Transform2D:
	var r := float(pose["length"]) / maxf(1.0, float(g["size"].x))
	var hold: Vector2 = pose["hold"]
	var own := Vector2(hold.x / r, float(g["muzzle"].y) + (hold.y - float(pose["muzzle_y"])) / r)
	return pose["preview"] * Transform2D(0.0, Vector2(r, r), 0.0, hold) * Transform2D(0.0, -own)


## The back carry's sway over a walk cycle, degrees.
const CARRY_SWAY_DEG := 2.0


## The sling `socket` (Flip coordinates) on walk frame i of a walk with `bob` (carry.json back.bob:
## texture px per frame) at k character px per texture px: moved by the frame's bob and swayed
## round its origin (CARRY_SWAY_DEG over the cycle). No bob: the socket as it is.
static func carry_walk_transform(socket: Transform2D, bob: Array, i: int, k: float) -> Transform2D:
	if bob.is_empty():
		return socket
	i = posmod(i, bob.size())
	var xf := Transform2D(deg_to_rad(CARRY_SWAY_DEG * sin(TAU * float(i) / float(bob.size()))), Vector2.ZERO) \
		* Transform2D(socket.x, socket.y, Vector2.ZERO)
	xf.origin = socket.origin + Vector2(bob[i]) * k
	return xf


# ── Full-body pictures ──────────────────────────────────────────────────────

## A character's skinned full-body picture: {texture, size, pivot (the feet, px in the picture),
## height (px), scale (picture px → character px), bones: [{name, parent, at, tip (Vector2 px)}]
## (parents first), vertices (PackedVector2Array, px = uv), polygons (Array of PackedInt32Array
## triangles), weights (per bone a PackedFloat32Array, one per vertex), anims: {name: spec}}, or
## {} when it has none (the frames draw it). Not imported yet: read from the PNG.
static func lobby_full(id: String) -> Dictionary:
	id = known_character(id)
	if _fulls.has(id):
		return _fulls[id]
	var out := parse_full(full_json_path(id), full_path(id))
	_fulls[id] = out
	return out


static func parse_full(json_path: String, png_path: String) -> Dictionary:
	if not FileAccess.file_exists(json_path) or not has_png(png_path):
		return {}
	var data := _load_json(json_path)
	var mesh = data.get("mesh")
	if float(data.get("scale", 0.0)) <= 0.0 or not data.get("pivot") is Array or not data.get("bones") is Array \
			or not mesh is Dictionary or not mesh.get("vertices") is Array or not mesh.get("triangles") is Array \
			or not data.get("weights") is Array or (data["weights"] as Array).size() != (mesh["vertices"] as Array).size():
		push_warning("art: %s is not a full-body picture, using the frames" % json_path)
		return {}
	var bones: Array = []
	var index := {}
	for b in data["bones"]:
		if not b is Dictionary or not b.has("name") or (str(b.get("parent", "")) != "" and not index.has(str(b["parent"]))):
			push_warning("art: %s has a bad bone %s, using the frames" % [json_path, str(b)])
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
				push_warning("art: %s triangle index %d out of range, using the frames" % [json_path, i])
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
		push_warning("art: %s has no idle, mesh or bones, using the frames" % json_path)
		return {}
	var tex := _png_texture(png_path)
	if tex == null:
		return {}
	return {"texture": tex, "size": _vec2(data.get("size", [])), "pivot": _vec2(data["pivot"]), "height": float(data.get("height", 0.0)),
		"scale": float(data["scale"]), "motionScale": float(data.get("motionScale", 1.0)), "bones": bones, "vertices": vertices,
		"polygons": polygons, "weights": weights, "anims": anims}


## A picture: the imported texture, else the PNG itself (not imported yet), else null.
static func _png_texture(path: String) -> Texture2D:
	var cached: Texture2D = _textures.get(path)
	if cached != null:
		return cached
	if ResourceLoader.exists(path) and _imported(path):
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


## The editor has imported the file (its .import names the imported copy); a fresh .import
## written by a tool has not been yet, and loading it would only print an error.
static func _imported(path: String) -> bool:
	return not FileAccess.file_exists(path + ".import") or FileAccess.get_file_as_string(path + ".import").contains("\npath")


## The project has this PNG: the file itself (the editor, imported or not yet), or its imported
## copy (an export keeps only the .import remap, never the PNG, so FileAccess alone misses it).
## The game's logo (LOGO), null without the file (the first screens then show the name as text).
static func logo() -> Texture2D:
	return _png_texture(LOGO) if has_png(LOGO) else null


static func has_png(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)


# ── Rank art (grades) ───────────────────────────────────────────────────────

## A grade's card frame (assets/ranks/frame_<grade>.png: a 512 × 640 portrait, transparent
## centre, the card's window inset RANK_FRAME_INSET each side) and badge (badge_<grade>.png, 256 ×
## 256). Optional: null when the file is not there (yet), and the caller draws its placeholder in
## code (screens/ranked/grade_frame.gd, grade_badge.gd).
const RANK_FRAME_INSET := 0.12


static func rank_frame_path(grade: String) -> String:
	return ROOT + "ranks/frame_%s.png" % grade


static func rank_badge_path(grade: String) -> String:
	return ROOT + "ranks/badge_%s.png" % grade


static func rank_frame(grade: String) -> Texture2D:
	return _optional_png(rank_frame_path(grade)) if grade != "" else null


static func rank_badge(grade: String) -> Texture2D:
	return _optional_png(rank_badge_path(grade)) if grade != "" else null


## A texture that may not exist: null (no warning) when the file is missing.
static func _optional_png(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	if not has_png(path):
		_textures[path] = null # looked once per run
		return null
	return _png_texture(path)


# ── Guns ────────────────────────────────────────────────────────────────────

## The sprite of a gun: {kind, tier, texture, grip, muzzle (px in the texture), scale (texture
## px → character frame px), hug (true: hug art)}. Per kind / tier: its held sprite (weapons.json),
## else its hug art (hug.json: a kind with no held sprites, the bazooka, the cannon, the seed launcher and the shock rifle; grip = the hold, the
## middle of the tube); falls back to the kind's basic, then to the blaster's basic
## (FALLBACK_GUN_KIND; a missing file, one not imported yet or no entry), then to the placeholder.
static func gun(kind: String, tier: String) -> Dictionary:
	for kt in [[kind, tier], [kind, GUN_BASIC], [FALLBACK_GUN_KIND, GUN_BASIC]]:
		var meta := gun_meta(kt[0], kt[1])
		var path := gun_path(kt[0], kt[1])
		if not meta.is_empty() and ResourceLoader.exists(path):
			var t := texture(path)
			if t != placeholder():
				return {"kind": kt[0], "tier": kt[1], "texture": t, "grip": meta["grip"], "muzzle": meta["muzzle"],
					"scale": gun_scale(), "hug": false}
		var hm := hug_meta(kt[0], kt[1])
		if not hm.is_empty() and has_png(hug_gun_path(kt[0], kt[1])):
			var ht := _png_texture(hug_gun_path(kt[0], kt[1]))
			if ht != null:
				return {"kind": kt[0], "tier": kt[1], "texture": ht, "grip": hm["pivot"], "muzzle": hm["muzzle"],
					"scale": hug_scale(), "hug": true}
	_warn(gun_path(kind, tier))
	return {"kind": FALLBACK_GUN_KIND, "tier": GUN_BASIC, "texture": placeholder(), "grip": Vector2(4, 8),
		"muzzle": Vector2(16, 8), "scale": 1.0, "hug": false}


## A held gun sprite's texture px → character frame px (weapons.json pxPerUnit).
static func gun_scale() -> float:
	var ppu := float(guns_data().get("pxPerUnit", PX_PER_UNIT))
	return PX_PER_UNIT / ppu if ppu > 0.0 else 1.0


## A hug gun's texture px → character frame px (hug.json pxPerUnit; the held guns' without it).
static func hug_scale() -> float:
	var ppu := float(hug_data().get("pxPerUnit", 0.0))
	return PX_PER_UNIT / ppu if ppu > 0.0 else gun_scale()


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


## Where a character holds its gun in each frame of its look (character_look(): the side view's
## or the baked frames' gun_anchors.json): anim -> [{grip (Vector2, px in the frame texture),
## angle (degrees, 0 = level, + turns the muzzle down), front (drawn over the body), flash
## (0..1 muzzle flash)}], one per frame.
static func gun_anchors(id: String) -> Dictionary:
	return character_look(id)["anchors"]


static func _parse_anchors(path: String) -> Dictionary:
	var out := {}
	var data := _load_json(path)
	if data.get("anims") is Dictionary:
		for anim in data["anims"]:
			var frames: Array = []
			for a in data["anims"][anim]:
				if a is Dictionary and a.get("grip") is Array:
					frames.append({"grip": _vec2(a["grip"]), "angle": float(a.get("angle", 0.0)),
						"front": bool(a.get("front", true)), "flash": float(a.get("flash", 0.0))})
			out[anim] = frames
	return out


## The gun a drawn ready pose hugs (character.gd, the pose scenes): {kind, tier, texture, path,
## pivot (where the pose turns it: a hug gun's hold point, an old gun sprite's centre), muzzle,
## size (px in the texture), hug (true: hug art)}. Order: the kind's hug art in that tier → in its
## other tiers (iron first, then GUN_TIERS order) → the held gun sprite of gun(kind, tier)
## pivoted at its own centre (not the grip). Hug art not imported yet is read from the PNG.
static func hug_gun(kind: String, tier: String) -> Dictionary:
	var tiers: Array = [tier, "iron"]
	for t in GUN_TIERS.get(kind, []):
		if not tiers.has(t):
			tiers.append(t)
	for t in tiers:
		var meta := hug_meta(kind, str(t))
		if meta.is_empty() or not has_png(hug_gun_path(kind, str(t))):
			continue
		var tex := _png_texture(hug_gun_path(kind, str(t)))
		if tex == null:
			continue
		meta.merge({"kind": kind, "tier": str(t), "texture": tex, "path": hug_gun_path(kind, str(t)), "hug": true}, true)
		return meta
	var g := gun(kind, tier)
	var size: Vector2 = g["texture"].get_size()
	return {"kind": g["kind"], "tier": g["tier"], "texture": g["texture"],
		"path": hug_gun_path(g["kind"], g["tier"]) if g["hug"] else gun_path(g["kind"], g["tier"]),
		"pivot": size * 0.5, "muzzle": g["muzzle"], "size": size, "hug": bool(g["hug"])}


## hug.json's entry of a hug gun: {pivot (its hold), muzzle, size} (Vector2 px), {} when it has none.
static func hug_meta(kind: String, tier: String) -> Dictionary:
	var guns = hug_data().get("guns")
	var e = guns.get(kind, {}).get(tier) if guns is Dictionary and guns.get(kind) is Dictionary else null
	if not e is Dictionary or not e.get("hold") is Array or not e.get("muzzle") is Array or not e.get("size") is Array:
		return {}
	return {"pivot": _vec2(e["hold"]), "muzzle": _vec2(e["muzzle"]), "size": _vec2(e["size"])}


## hug.json parsed ({} when missing or invalid).
static func hug_data() -> Dictionary:
	if _hug_data == null:
		_hug_data = _load_json(HUG_DATA) if FileAccess.file_exists(HUG_DATA) else {}
	return _hug_data


## The pose gun a texture path is (a hug gun hug_<tier>.png or a held gun <tier>.png under
## weapons/<kind>/): hug_gun()'s {pivot, muzzle, size}; {} for any other path.
static func pose_gun_meta(path: String) -> Dictionary:
	var rel := path.trim_prefix(ROOT + "weapons/")
	if rel == path or rel.get_slice_count("/") != 2 or rel.get_extension() != "png":
		return {}
	var kind := rel.get_slice("/", 0)
	var stem := rel.get_slice("/", 1).get_basename()
	if stem.begins_with("hug_"):
		return hug_meta(kind, stem.trim_prefix("hug_"))
	var g := gun_meta(kind, stem)
	if g.is_empty() or not guns_data().get("guns", {}).get(kind, {}).get(stem, {}).get("size") is Array:
		return {}
	var size := _vec2(guns_data()["guns"][kind][stem]["size"])
	return {"pivot": size * 0.5, "muzzle": g["muzzle"], "size": size}


## How a character's drawn ready pose holds its gun (look["ready"], side.json "readyPose"), in the
## character's Flip coordinates (the feet at 0, facing right; scenes/character/character.gd):
## {anims (the ready pose's animations), socket (Transform2D: the GunSocket, its origin the hug
## point the gun turns round, its turn / size), preview (Transform2D: the Preview's texture px →
## socket space, its offset included), pivot (the point of the Preview's gun that the pose turns
## round, texture px), length (that gun's length, px)}; {} when the character has no ready pose.
## WYSIWYG: gun_transform() draws any gun exactly as the Preview shows its own. Placed by hand in
## the character's pose scene (side.json readyPose.scene: scenes/character/poses/<id>_ready.tscn;
## assets/README.md): root → Body (the ready frame) → GunSocket (Node2D) → Preview (Sprite2D, the
## hug gun at 0°, horizontal, facing right); a Preview with no picture yet (pose_gun.gd: the hug
## art not imported yet) stands for its kind / tier's hug_gun(). Without the scene (or a node): the
## gun anchors' hug point, the character's iron hug gun at the weapons' scale, level. Every
## character has its scene and a side view with a readyPose (tools/import_frames.gd -- <id>); a
## character without one (the code-baked frames, no readyPose) has no ready pose: the code draw,
## its scene's Body showing the baked idle frame (scenes/character/poses/pose_body.gd).
static func ready_pose(id: String) -> Dictionary:
	id = known_character(id)
	if _ready_poses.has(id):
		return _ready_poses[id]
	var look := character_look(id)
	var rp: Dictionary = look.get("ready", {})
	var out := {}
	_ready_poses[id] = out
	if rp.is_empty():
		return out
	var k := float(look["scale"])
	var pivot: Vector2 = look["pivot"]
	var anims: Array = rp["anims"]
	var grip: Vector2 = gun_anchor(id, str(anims[0]) if not anims.is_empty() else DRAW_ANIM, 0)["grip"]
	var kind := character_gun(id)
	var own := hug_gun(kind, "iron")
	var gs := hug_scale() if own["hug"] else gun_scale()
	var socket := Transform2D(0.0, (grip - pivot) * k)
	var preview := Transform2D(0.0, Vector2(gs, gs), 0.0, Vector2.ZERO) * Transform2D(0.0, -own["pivot"])
	var gun_pivot: Vector2 = own["pivot"]
	var length := float(own["size"].x)
	var path := str(rp.get("scene", ""))
	if path != "" and ResourceLoader.exists(path):
		var ps = load(path)
		var root: Node = ps.instantiate() if ps is PackedScene else null
		if root is Node2D:
			var sock := root.get_node_or_null("GunSocket") as Node2D
			if sock != null:
				socket = sock.transform
				var pv := sock.get_node_or_null("Preview") as Sprite2D
				if pv != null:
					var meta := {}
					if pv.texture != null:
						meta = pose_gun_meta(pv.texture.resource_path)
						if meta.is_empty(): # some other picture: turned round its offset point
							meta = {"pivot": -pv.offset, "size": pv.texture.get_size()}
					else: # not imported yet (pose_gun.gd): its kind / tier's hug gun
						var stand := hug_gun(str(pv.get("kind")) if pv.get("kind") != null else kind, str(pv.get("tier")) if pv.get("tier") != null else "iron")
						meta = {"pivot": stand["pivot"], "size": stand["size"]}
					var corner := Vector2.ZERO
					if pv.centered and pv.texture != null:
						corner = -pv.texture.get_size() * 0.5
					preview = pv.transform * Transform2D(0.0, pv.offset + corner)
					gun_pivot = meta["pivot"]
					length = float(meta["size"].x)
		elif root == null:
			push_warning("art: %s is not a scene, the ready pose uses its defaults" % path)
		if root != null:
			root.free()
	out.merge({"anims": anims, "socket": socket, "preview": preview, "pivot": gun_pivot, "length": maxf(1.0, length)})
	return out


## The ready pose's (ready_pose()) gun g (hug_gun()) in socket space: texture px → socket px. The
## Preview's own gun is drawn exactly as the Preview shows it; any other is scaled to the same
## length with its pivot on the Preview gun's pivot.
static func gun_transform(pose: Dictionary, g: Dictionary) -> Transform2D:
	var r := float(pose["length"]) / maxf(1.0, float(g["size"].x))
	return pose["preview"] * Transform2D(0.0, Vector2(r, r), 0.0, pose["pivot"]) * Transform2D(0.0, -g["pivot"])


## The anchor of frame i of anim (the last frame's when i is past the end; a fixed hold in
## front of the chest when the character has no anchors).
static func gun_anchor(id: String, anim: String, i: int) -> Dictionary:
	var frames: Array = gun_anchors(id).get(anim, [])
	if frames.is_empty():
		frames = gun_anchors(id).get("idle", [])
	if frames.is_empty():
		var look := character_look(id)
		return {"grip": look["pivot"] + Vector2(32, -50) * PX_PER_UNIT / float(look["scale"]), "angle": 0.0, "front": true, "flash": 0.0}
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
