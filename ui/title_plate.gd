extends Control
## A title ("Danh hiệu") plate: the rarity's banner (assets/ui/titles/, ui/art.gd title_meta)
## with the title's name centred in its inner panel, bold white with a dark outline and shadow.
## `plate_height` sets the size (the banner keeps its proportions); a name too long for the
## panel widens the plate in the banner's plain border runs (titles.json "stretch": the ends and
## the red's crown never stretch), up to `max_width` (0 = no limit), then the font shrinks (down
## to MIN_FONT). Purple and red plates get a slow shine sweep (a canvas shader on the banner
## only, TIME-driven: no per-frame script). The control's minimum size is the plate's size;
## it draws centred in a larger rect. set_title({}) or a title with no name draws nothing.

const Art := preload("res://ui/art.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")

const SHINE_RARITIES := ["purple", "red"]
const MIN_FONT := 8
## font size = the name box's drawn height × FONT_FACTOR (font_size 0)
const FONT_FACTOR := 1.0
## px kept free on each side of the name inside its box, × the font size
const PAD_FACTOR := 0.35
const SHINE_PERIOD := 3.6 # s between two sweeps

const SHINE_CODE := """
shader_type canvas_item;
uniform float plate_width = 300.0;
uniform float plate_height = 60.0;
uniform float phase = 0.0;
uniform float period = 3.6;
varying vec2 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float band = plate_height * 0.55;
	float t = fract(TIME / period + phase) * 2.2; // the sweep crosses during the first 1/2.2
	float centre = -band + t * (plate_width + band * 2.0);
	float x = local.x - (local.y - plate_height * 0.5) * 0.6;
	float k = 1.0 - smoothstep(0.0, band, abs(x - centre));
	c.rgb += vec3(1.0, 0.95, 0.85) * k * k * 0.42 * c.a;
	COLOR = c;
}
"""

static var _shine_shader: Shader

var title := {} # {id, name, rarity}; {} = none
var plate_height := 48.0:
	set(v):
		plate_height = maxf(4.0, v)
		_relayout()
var max_width := 0.0:
	set(v):
		max_width = maxf(0.0, v)
		_relayout()
var font_size := 0: # 0: from the name box's height
	set(v):
		font_size = maxi(0, v)
		_relayout()
var shine := true: # purple / red sweep
	set(v):
		shine = v
		_relayout()

var _layout := {}
var _texture: Texture2D
var _banner: Control
var _text: Control
var _shine_material: ShaderMaterial


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_banner = Control.new()
	_banner.mouse_filter = MOUSE_FILTER_IGNORE
	_banner.draw.connect(_draw_banner)
	_banner.texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS # small in the match
	add_child(_banner)
	_text = Control.new()
	_text.mouse_filter = MOUSE_FILTER_IGNORE
	_text.draw.connect(_draw_name)
	add_child(_text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
		_place()


## Shows a title ({id, name, rarity}; TitleModel.parse_title), {} for none.
func set_title(t: Dictionary) -> void:
	title = t.duplicate()
	_relayout()


func has_title() -> bool:
	return str(title.get("name", "")) != ""


func rarity() -> String:
	return Art.title_rarity(str(title.get("rarity", "")))


## The plate's drawn size (Vector2.ZERO without a title).
func plate_size() -> Vector2:
	return _layout.get("size", Vector2.ZERO)


## The font size the name is drawn at (0 without a title).
func name_font_size() -> int:
	return int(_layout.get("font_size", 0))


## The plate layout for a name: {size, scale, extra, font_size, text_rect, pieces}. meta is
## Art.title_meta(); pieces are [source Rect2 (texture px), drawn Rect2] left to right, the
## stretch ranges widened by `extra` px in total (shared equally). Pure: the tests call it.
static func layout(meta: Dictionary, name_text: String, height: float, max_w: float, font_px: int, font: Font) -> Dictionary:
	var tex_size: Vector2 = meta["size"]
	var s := height / maxf(1.0, tex_size.y)
	var base_w := tex_size.x * s
	var box: Rect2 = meta["text"]
	var box_w := box.size.x * s
	var fs := font_px if font_px > 0 else maxi(MIN_FONT, int(round(box.size.y * s * FONT_FACTOR)))
	var stretch: Array = meta["stretch"]
	var room_max := INF if max_w <= 0.0 else maxf(0.0, max_w - base_w)
	if stretch.is_empty():
		room_max = 0.0
	var extra := 0.0
	while true:
		var need := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0 * PAD_FACTOR * fs
		extra = maxf(0.0, need - box_w)
		if extra <= room_max or fs <= MIN_FONT:
			extra = minf(extra, room_max)
			break
		fs -= 1
	var pieces: Array = []
	var x_src := 0.0
	var x_out := 0.0
	var share := extra / maxf(1.0, float(stretch.size()))
	for r in stretch:
		var r0: float = r.x
		var r1: float = r.y
		if r0 > x_src:
			pieces.append([Rect2(x_src, 0, r0 - x_src, tex_size.y), Rect2(x_out, 0, (r0 - x_src) * s, height)])
			x_out += (r0 - x_src) * s
		pieces.append([Rect2(r0, 0, r1 - r0, tex_size.y), Rect2(x_out, 0, (r1 - r0) * s + share, height)])
		x_out += (r1 - r0) * s + share
		x_src = r1
	if x_src < tex_size.x:
		pieces.append([Rect2(x_src, 0, tex_size.x - x_src, tex_size.y), Rect2(x_out, 0, (tex_size.x - x_src) * s, height)])
		x_out += (tex_size.x - x_src) * s
	var text_rect := Rect2(box.position * s, Vector2(box_w + extra, box.size.y * s))
	return {"size": Vector2(x_out, height), "scale": s, "extra": extra, "font_size": fs, "text_rect": text_rect, "pieces": pieces}


static func font() -> Font:
	return LobbyUi.bold()


func _relayout() -> void:
	if not has_title():
		_layout = {}
		_texture = null
		custom_minimum_size = Vector2.ZERO
		visible = false
		return
	visible = true
	var r := rarity()
	_texture = Art.title_texture(r)
	_layout = layout(Art.title_meta(r), str(title["name"]), plate_height, max_width, font_size, font())
	custom_minimum_size = _layout["size"]
	if shine and SHINE_RARITIES.has(r):
		if _shine_shader == null:
			_shine_shader = Shader.new()
			_shine_shader.code = SHINE_CODE
		if _shine_material == null:
			_shine_material = ShaderMaterial.new()
			_shine_material.shader = _shine_shader
			_shine_material.set_shader_parameter("phase", randf())
			_shine_material.set_shader_parameter("period", SHINE_PERIOD)
		_shine_material.set_shader_parameter("plate_width", _layout["size"].x)
		_shine_material.set_shader_parameter("plate_height", _layout["size"].y)
		_banner.material = _shine_material
	else:
		_banner.material = null
	_place()


## Centres the plate in the control's rect.
func _place() -> void:
	if _layout.is_empty():
		return
	var plate: Vector2 = _layout["size"]
	var at: Vector2 = ((size - plate) / 2.0).floor()
	for c in [_banner, _text]:
		c.position = at
		c.size = _layout["size"]
		c.queue_redraw()


func _draw_banner() -> void:
	if _layout.is_empty() or _texture == null:
		return
	var tex_scale := Vector2(_texture.get_width(), _texture.get_height()) / Vector2(maxf(1.0, _layout_meta_size().x), maxf(1.0, _layout_meta_size().y))
	for p in _layout["pieces"]:
		var src: Rect2 = p[0]
		_banner.draw_texture_rect_region(_texture, p[1], Rect2(src.position * tex_scale, src.size * tex_scale))


## titles.json's texture size (the PNG may differ when replaced by hand: drawn scaled).
func _layout_meta_size() -> Vector2:
	return Art.title_meta(rarity())["size"]


func _draw_name() -> void:
	if _layout.is_empty():
		return
	var f := font()
	var fs: int = _layout["font_size"]
	var name_text := str(title["name"])
	var r: Rect2 = _layout["text_rect"]
	var w := f.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ascent := f.get_ascent(fs)
	var descent := f.get_descent(fs)
	var pos := Vector2(r.position.x + (r.size.x - w) / 2.0, r.position.y + (r.size.y - (ascent + descent)) / 2.0 + ascent)
	var outline := maxi(2, int(round(fs * 0.22)))
	var dark := Color(0.04, 0.02, 0.08, 0.92)
	_text.draw_string_outline(f, pos + Vector2(0, maxf(1.0, fs * 0.08)), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline + 1, Color(0, 0, 0, 0.45))
	_text.draw_string_outline(f, pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, dark)
	_text.draw_string(f, pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
