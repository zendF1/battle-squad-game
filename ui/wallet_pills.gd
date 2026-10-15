extends HBoxContainer
## The wallet from PlayerState as two dark pills, [gem] 300 [+] and [coin] 1.250 [+] (icons from
## assets/icons/, the pill assets/ui/pill.png), and the
## "Thử lại" button of a failed profile refresh (only while not loading). "—" until the profile
## is loaded; stale values stay on screen while a refresh runs. The "+" buttons emit
## gem_plus / coin_plus (Home opens the Shop on the matching section).

signal gem_plus
signal coin_plus

const LobbyUi := preload("res://ui/lobby_ui.gd")
const Fmt := preload("res://core/fmt.gd")
const Art := preload("res://ui/art.gd")

var _gem: Label
var _coin: Label
var _retry: Button


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	alignment = BoxContainer.ALIGNMENT_END
	_retry = LobbyUi.pill_button("Thử lại", 22, 56)
	LobbyUi.style_button(_retry, Color(0.75, 0.25, 0.25, 0.85), 28, 18)
	_retry.size_flags_vertical = SIZE_SHRINK_CENTER
	_retry.pressed.connect(PlayerState.refresh)
	add_child(_retry)
	_gem = _pill("gem", Color(0.55, 0.36, 0.88), gem_plus)
	_coin = _pill("coin", Color(0.95, 0.65, 0.15), coin_plus)
	PlayerState.changed.connect(_render)
	_render()


func _pill(icon_name: String, plus_color: Color, on_plus: Signal) -> Label:
	var pill := PanelContainer.new()
	var style := Art.ui_box("pill", 4)
	style.content_margin_left = 0
	pill.add_theme_stylebox_override("panel", style)
	pill.size_flags_vertical = SIZE_SHRINK_CENTER
	add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)
	var pad := Control.new()
	pad.custom_minimum_size.x = 6
	row.add_child(pad)
	row.add_child(LobbyUi.icon(icon_name, 36))
	var value := LobbyUi.text("—", 26, Color.WHITE, true)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 92
	row.add_child(value)
	var plus := LobbyUi.round_button("plus", 46, plus_color, 0.56)
	plus.pressed.connect(on_plus.emit)
	row.add_child(plus)
	return value


func _render() -> void:
	if PlayerState.is_loaded():
		_gem.text = Fmt.thousands(PlayerState.gem())
		_coin.text = Fmt.thousands(PlayerState.coin())
	else:
		_gem.text = "—"
		_coin.text = "—"
	_retry.visible = PlayerState.error != "" and not PlayerState.loading
