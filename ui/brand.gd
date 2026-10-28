extends RefCounted
## The game's logo on the first screens (screens/splash.gd, screens/login.gd): one place and size, so
## going from the boot splash to the loading screen to the login screen the logo never moves.
## assets/branding/splash.png (the boot splash, project.godot) has the logo drawn at this same rect on
## a 1920 x 1080 canvas of SPLASH_BG; redraw it there when LOGO_HEIGHT / LOGO_CENTER_Y change.

const Art := preload("res://ui/art.gd")

## The logo's height (design px, the 1600 x 900 base) and its centre's height share of the screen.
const LOGO_HEIGHT := 315.0
const LOGO_CENTER_Y := 0.3
## The boot splash's colour (project.godot application/boot_splash/bg_color, assets/branding/
## splash.png): the loading picture's sky over the logo.
const SPLASH_BG := Color(0.604, 0.851, 0.945)


## The logo, centred across `parent` at LOGO_CENTER_Y, LOGO_HEIGHT tall (anchored: it stays put on any
## aspect ratio); the name as text when the picture is missing.
static func add_logo(parent: Control) -> Control:
	var tex := Art.logo()
	var node: Control
	var w := LOGO_HEIGHT
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		w = LOGO_HEIGHT * tex.get_width() / tex.get_height()
		node = r
	else:
		var l := Label.new()
		l.text = "BATTLE SQUAD"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 64)
		w = 900.0
		node = l
	node.name = "Logo"
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.anchor_left = 0.5
	node.anchor_right = 0.5
	node.anchor_top = LOGO_CENTER_Y
	node.anchor_bottom = LOGO_CENTER_Y
	node.offset_left = -w / 2.0
	node.offset_right = w / 2.0
	node.offset_top = -LOGO_HEIGHT / 2.0
	node.offset_bottom = LOGO_HEIGHT / 2.0
	parent.add_child(node)
	return node


## A control of `size_px` centred across `parent` with its centre at `center_y` (share of the height).
static func place(node: Control, size_px: Vector2, center_y: float) -> void:
	node.anchor_left = 0.5
	node.anchor_right = 0.5
	node.anchor_top = center_y
	node.anchor_bottom = center_y
	node.offset_left = -size_px.x / 2.0
	node.offset_right = size_px.x / 2.0
	node.offset_top = -size_px.y / 2.0
	node.offset_bottom = size_px.y / 2.0
