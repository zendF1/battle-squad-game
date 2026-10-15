extends SceneTree
## Bakes the code-drawn placeholder art (tools/art/*) into the image files ui/art.gd names, so
## the game only loads files and an artist can replace any of them. Run it windowed (a headless
## run has no renderer):
##
##   $GODOT --path . -s tools/bake_art.gd [-- <group> ...]
##
## Groups: characters, env, terrain, fx, icons, ui (default: all). It overwrites the PNGs (and the
## characters' SpriteFrames .tres), prints every file it wrote and quits. Then import them once
## (editor, or `$GODOT --headless --path . --import`) so the .import files exist. An existing
## .import file is never touched, so import settings changed in the editor survive a re-bake.
##
## Each canvas is drawn in a transparent SubViewport (4x MSAA); a second pass un-premultiplies
## the colours so semi-transparent edges keep their colour in the PNG.

const Art := preload("res://ui/art.gd")
const CharacterPainter := preload("res://tools/art/character_painter.gd")
const EnvPainter := preload("res://tools/art/env_painter.gd")
const FxPainter := preload("res://tools/art/fx_painter.gd")
const TerrainPainter := preload("res://tools/art/terrain_painter.gd")
const IconPainter := preload("res://tools/art/icon_painter.gd")
const UiPainter := preload("res://tools/art/ui_painter.gd")

const GROUPS := ["characters", "env", "terrain", "fx", "icons", "ui"]
## Shown much smaller than drawn (icons on buttons, effects, clouds): mipmapped. The characters
## are not: plain linear filtering keeps the small match bodies sharper.
const MIPMAPPED := ["fx", "icons", "env/cloud"]
const UNPREMULTIPLY := """
shader_type canvas_item;
render_mode blend_disabled, unshaded;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
"""

var _vp: SubViewport
var _out: SubViewport
var _canvas: Node2D
var _view: TextureRect
var _paint: Callable
var _written: Array = [] # [path, bytes]


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.msaa_2d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_canvas = Node2D.new()
	_canvas.draw.connect(func() -> void: _paint.call(_canvas))
	_vp.add_child(_canvas)
	_out = SubViewport.new()
	_out.transparent_bg = true
	_out.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_out)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = UNPREMULTIPLY
	_view.material = mat
	_out.add_child(_view)
	_bake.call_deferred()


func _bake() -> void:
	var wanted: Array = Array(OS.get_cmdline_user_args()).filter(func(a): return GROUPS.has(a))
	if wanted.is_empty():
		wanted = GROUPS
	for group in wanted:
		await call("_bake_" + group)
	var total := 0
	for w in _written:
		total += int(w[1])
	print("bake_art: wrote %d files, %.1f KB" % [_written.size(), total / 1024.0])
	quit()


## Draws `paint(ci)` on a size canvas and returns the straight-alpha image.
func _render(size: Vector2i, paint: Callable) -> Image:
	_paint = paint
	_vp.size = size
	_out.size = size
	_view.size = Vector2(size)
	_canvas.queue_redraw()
	for i in 3:
		await RenderingServer.frame_post_draw
	return _out.get_texture().get_image()


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("bake_art: cannot write %s (%s)" % [path, error_string(err)])
		return
	_write_import(path)
	var bytes := FileAccess.get_file_as_bytes(abs_path).size()
	_written.append([path, bytes])
	print("  %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), bytes / 1024.0])


## A new image gets an .import with mipmaps when it is shown minified; an existing one is kept.
func _write_import(path: String) -> void:
	var import_path := ProjectSettings.globalize_path(path + ".import")
	if FileAccess.file_exists(import_path):
		return
	var mip := MIPMAPPED.any(func(m): return path.contains("/" + m))
	var f := FileAccess.open(import_path, FileAccess.WRITE)
	f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=%s\n' % ("true" if mip else "false"))
	f.close()


# ── Groups ──────────────────────────────────────────────────────────────────

func _bake_characters() -> void:
	var k := Art.PX_PER_UNIT
	for id in Art.CHARACTERS:
		var used := Rect2i()
		for anim in Art.ANIMS:
			var n: int = Art.ANIMS[anim]["frames"]
			for i in n:
				var img: Image = await _render(Art.FRAME_SIZE, func(ci: CanvasItem) -> void:
					CharacterPainter.paint_frame(ci, Art.FRAME_PIVOT, k, id, anim, i, n))
				var r := img.get_used_rect()
				used = r if used.size == Vector2i.ZERO else used.merge(r)
				_save(img, Art.frame_path(id, anim, i))
		print("  %s: art inside %s of %s (pivot %s)" % [id, used, Art.FRAME_SIZE, Art.FRAME_PIVOT])
		# Portrait: head and shoulders, centred on the head.
		var portrait: Image = await _render(Art.PORTRAIT_SIZE, func(ci: CanvasItem) -> void:
			var s := Art.PORTRAIT_SIZE.x / 112.0
			CharacterPainter.paint(ci, Transform2D(0.0, Vector2(s, s), 0.0, Vector2(Art.PORTRAIT_SIZE.x / 2.0 - 4 * s, 158 * s)), id, {"bob": 0.0})
			ci.draw_set_transform(Vector2.ZERO))
		_save(portrait, Art.portrait_path(id))
		_write_frames(id)
	var shadow_size := Vector2i(FxPainter.SHADOW_UNITS * k)
	_save(await _render(shadow_size, func(ci: CanvasItem) -> void: FxPainter.shadow(ci, Vector2(shadow_size))), Art.SHADOW)


## The character's SpriteFrames: one animation per Art.ANIMS entry, its frames in order.
func _write_frames(id: String) -> void:
	var ext := ""
	var anims: Array[String] = []
	var n_ext := 0
	for anim in Art.ANIMS:
		var spec: Dictionary = Art.ANIMS[anim]
		var frames: Array[String] = []
		for i in int(spec["frames"]):
			n_ext += 1
			ext += '[ext_resource type="Texture2D" path="%s" id="%d"]\n' % [Art.frame_path(id, anim, i), n_ext]
			frames.append('{\n"duration": 1.0,\n"texture": ExtResource("%d")\n}' % n_ext)
		anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % [", ".join(frames), "true" if spec["loop"] else "false", anim, str(float(spec["fps"]))])
	var text := '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n[resource]\nanimations = [%s]\n' % [n_ext + 1, ext, ", ".join(anims)]
	var path := Art.frames_path(id)
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	_written.append([path, text.length()])
	print("  %s" % path)


func _bake_env() -> void:
	_save(await _render(Vector2i(EnvPainter.LOBBY_SCREEN), func(ci: CanvasItem) -> void: EnvPainter.lobby_sky(ci, EnvPainter.LOBBY_SCREEN)), Art.ENV["lobby_bg"])
	var ground := Vector2i(EnvPainter.LOBBY_SCREEN * Vector2(1.0, 1.0 - EnvPainter.GROUND_FROM))
	_save(await _render(ground, func(ci: CanvasItem) -> void: EnvPainter.lobby_ground(ci, Vector2(ground))), Art.ENV["lobby_ground"])
	_save(await _render(EnvPainter.PEDESTAL_SIZE, func(ci: CanvasItem) -> void: EnvPainter.pedestal(ci, Vector2(EnvPainter.PEDESTAL_SIZE))), Art.ENV["pedestal"])
	var sky := Vector2i(1600, 512)
	_save(await _render(sky, func(ci: CanvasItem) -> void: EnvPainter.match_sky(ci, Vector2(sky))), Art.ENV["sky_match"])
	for i in Art.CLOUDS.size():
		_save(await _render(EnvPainter.CLOUD_SIZE, func(ci: CanvasItem) -> void: EnvPainter.cloud(ci, Vector2(EnvPainter.CLOUD_SIZE), i)), Art.ENV[Art.CLOUDS[i]])


func _bake_terrain() -> void:
	_save(TerrainPainter.dirt(), Art.TERRAIN["dirt"])
	_save(TerrainPainter.grass_edge(), Art.TERRAIN["grass_edge"])


func _bake_fx() -> void:
	_save(await _render(FxPainter.BOMB_SIZE, func(ci: CanvasItem) -> void: FxPainter.bomb(ci, Vector2(FxPainter.BOMB_SIZE))), Art.FX["bomb"])
	for i in Art.EXPLOSION_FRAMES:
		_save(await _render(FxPainter.EXPLOSION_SIZE, func(ci: CanvasItem) -> void: FxPainter.explosion(ci, Vector2(FxPainter.EXPLOSION_SIZE), i)), Art.explosion_path(i))
	_save(await _render(FxPainter.SMOKE_SIZE, func(ci: CanvasItem) -> void: FxPainter.smoke(ci, Vector2(FxPainter.SMOKE_SIZE))), Art.FX["smoke"])
	_save(await _render(FxPainter.DEBRIS_SIZE, func(ci: CanvasItem) -> void: FxPainter.debris(ci, Vector2(FxPainter.DEBRIS_SIZE))), Art.FX["debris"])
	_save(await _render(FxPainter.MUZZLE_SIZE, func(ci: CanvasItem) -> void: FxPainter.muzzle(ci, Vector2(FxPainter.MUZZLE_SIZE))), Art.FX["muzzle"])


func _bake_icons() -> void:
	for icon_name in Art.ICONS:
		_save(await _render(Art.ICON_SIZE, func(ci: CanvasItem) -> void: IconPainter.paint(ci, icon_name)), Art.icon_path(icon_name))


func _bake_ui() -> void:
	for box_name in Art.UI_BOXES:
		var size: Vector2i = UiPainter.BOXES[box_name][0] if UiPainter.BOXES.has(box_name) else Vector2i(96, 96)
		_save(await _render(size, func(ci: CanvasItem) -> void: UiPainter.paint(ci, box_name, Vector2(size))), Art.ui_path(box_name))
