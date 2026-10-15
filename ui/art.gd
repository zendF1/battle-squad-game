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

# ── Icons (96x96, drawn shapes) ─────────────────────────────────────────────

const ICON_SIZE := Vector2i(96, 96)
const ICONS := [
	"gem", "coin", "plus", "weapon", "skill", "battle",
	"characters", "inventory", "history", "shop",
	"swap", "send", "back", "arrow_left", "arrow_right", "check", "close", "end_turn", "unknown",
	"medkit", "teleport", "power_shot", "drill_bomb", "spider_net", "freeze_bomb", "air_strike", "wind_stopper",
]
const UNKNOWN_ICON := "unknown"

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
const FX := {
	"bomb": ROOT + "fx/bomb.png",
	"smoke": ROOT + "fx/smoke.png",
	"debris": ROOT + "fx/debris.png",
	"muzzle": ROOT + "fx/muzzle.png",
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


static func icon_path(icon_name: String) -> String:
	return ROOT + "icons/%s.png" % icon_name


static func explosion_path(i: int) -> String:
	return ROOT + "fx/explosion_%d.png" % i


static func ui_path(box_name: String) -> String:
	return ROOT + "ui/%s.png" % box_name


## Every file this script names (the test checks they all exist).
static func all_paths() -> Array[String]:
	var out: Array[String] = [SHADOW]
	for id in CHARACTERS:
		out.append(frames_path(id))
		out.append(portrait_path(id))
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
	for box_name in UI_BOXES:
		out.append(ui_path(box_name))
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
