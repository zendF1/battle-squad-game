extends Control
## Startup, the loading screen (demo splash_screen.dart): the game data first (GET /gamedata,
## PlayerState.load_gamedata(): every rule and text the screens need; the cached copy when offline),
## then restore the saved session, then Home (the first-login pick, screens/onboarding.gd, while the
## profile is not onboarded) or Login. With no game data at all (a first launch with
## no network) it stays here on a retry screen.
## Pictures only: the loading picture (Art.BG_LOADING, framed so both forts stay on screen), the logo
## where the boot splash drew it (ui/brand.gd), the progress bar (ui/load_bar.gd); a failure shows the
## offline glyph and a round retry button (the reason in their tooltip). The boot splash's plain
## colour fades off the picture first, so boot splash → loading screen does not jump.

const Art := preload("res://ui/art.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const Brand := preload("res://ui/brand.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const LoadBar := preload("res://ui/load_bar.gd")

## The loading picture's part kept on any screen: both forts and the robot (texture UV).
const KEEP := Rect2(0.05, 0.15, 0.9, 0.62)
## The bar (design px) and the failure row: their centres' height share of the screen.
const BAR_SIZE := Vector2(640, 44)
const BAR_Y := 0.8
const FAIL_PX := 96
const FADE_SEC := 0.5
## Where the bar heads during each step (game data, then the session check).
const STEP_GAMEDATA := 0.7
const STEP_PROFILE := 0.95

var _bar: Control
var _fail: HBoxContainer
var _offline: Control
var _retry: Button


func _ready() -> void:
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.top_shade = false
	bg.keep = KEEP
	bg.show_image(Art.BG_LOADING, false)
	add_child(bg)
	var cover := ColorRect.new() # the boot splash's colour, fading off the picture
	cover.color = Brand.SPLASH_BG
	cover.mouse_filter = MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(cover)
	Brand.add_logo(self)
	_bar = LoadBar.new()
	_bar.name = "LoadBar"
	Brand.place(_bar, BAR_SIZE, BAR_Y)
	add_child(_bar)
	_fail = HBoxContainer.new()
	_fail.name = "Failed"
	_fail.alignment = BoxContainer.ALIGNMENT_CENTER
	_fail.add_theme_constant_override("separation", 40)
	Brand.place(_fail, Vector2(FAIL_PX * 3, FAIL_PX), BAR_Y)
	add_child(_fail)
	_offline = GlyphIcon.make("offline", FAIL_PX)
	_offline.mouse_filter = MOUSE_FILTER_PASS
	_fail.add_child(_offline)
	_retry = _retry_button()
	_fail.add_child(_retry)
	_fail.visible = false
	_bar.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(cover, "modulate:a", 0.0, FADE_SEC).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bar, "modulate:a", 1.0, FADE_SEC)
	tw.chain().tween_callback(cover.queue_free)
	_start()


func _retry_button() -> Button:
	var b := Button.new()
	b.name = "Retry"
	b.custom_minimum_size = Vector2(FAIL_PX, FAIL_PX)
	b.focus_mode = FOCUS_NONE
	b.flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var g = GlyphIcon.make("retry", FAIL_PX)
	g.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	b.add_child(g)
	b.button_down.connect(func() -> void: g.modulate = Color(0.8, 0.8, 0.8))
	b.button_up.connect(func() -> void: g.modulate = Color.WHITE)
	b.pressed.connect(_start)
	return b


func _show_failed(reason: String) -> void:
	_bar.visible = false
	_fail.visible = true
	_offline.tooltip_text = reason
	_retry.tooltip_text = reason


func _show_loading(to: float) -> void:
	_fail.visible = false
	_bar.visible = true
	_bar.head_to(to)


func _start() -> void:
	_show_loading(STEP_GAMEDATA)
	if not await PlayerState.load_gamedata():
		_show_failed("Không tải được dữ liệu trò chơi")
		return
	_check_auth()


func _check_auth() -> void:
	_show_loading(STEP_PROFILE)
	if not Session.has_token():
		_bar.finish()
		Router.go(Router.LOGIN)
		return
	var res: Dictionary = await Api.get_json("/player/profile")
	if res.ok and res.data is Dictionary:
		PlayerState.apply(res.data) # also updates Session's playerId / displayName
		GameSocket.open()
		_bar.finish()
		Router.go_signed_in(res.data) # a new account picks its starter and name first
	elif res.status == 401:
		Session.clear_tokens()
		_bar.finish()
		Router.go(Router.LOGIN)
	else:
		_show_failed("Không kết nối được server (%s)" % res.message)
