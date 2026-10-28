extends HBoxContainer
## The wallet from PlayerState as two dark pills: the gems [gem+lock] 300 · [gem] 50 [+] (kim
## cương khoá, then kim cương: top-ups) and the coins [coin] 1.250 [+] (icons from assets/icons/,
## the lock drawn in code, the pill assets/ui/pill.png), and the "Thử lại" button of a failed
## profile refresh (only while not loading). "—" until the profile is loaded; stale values stay on
## screen while a refresh runs. The "+" buttons emit gem_plus / coin_plus (Home opens the Shop on
## the matching section).

signal gem_plus
signal coin_plus

const LobbyUi := preload("res://ui/lobby_ui.gd")
const Fmt := preload("res://core/fmt.gd")
const Art := preload("res://ui/art.gd")

const ICON := 36
const VALUE_W := 52.0 # a gem value's room (left-aligned next to its icon)

var _gem_locked: Label
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
	var gems := _pill(Color(0.55, 0.36, 0.88), gem_plus)
	gems.name = "GemPill"
	_gem_locked = _value(gems, locked_gem_icon(ICON), "Kim cương khoá")
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.22)
	sep.custom_minimum_size = Vector2(2, 28)
	sep.size_flags_vertical = SIZE_SHRINK_CENTER
	gems.add_child(sep)
	_gem = _value(gems, LobbyUi.icon("gem", ICON), "Kim cương")
	_order_plus(gems)
	var coins := _pill(Color(0.95, 0.65, 0.15), coin_plus)
	coins.name = "CoinPill"
	_coin = _value(coins, LobbyUi.icon("coin", ICON), "Xu")
	_coin.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin.custom_minimum_size.x = 92
	_order_plus(coins)
	PlayerState.changed.connect(_render)
	_render()


## A pill (its row returned): a pad, then the values added by _value(), the "+" last.
func _pill(plus_color: Color, on_plus: Signal) -> HBoxContainer:
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
	var plus := LobbyUi.round_button("plus", 46, plus_color, 0.56)
	plus.name = "Plus"
	plus.pressed.connect(on_plus.emit)
	row.add_child(plus)
	return row


## Keeps the pill's "+" last.
static func _order_plus(row: HBoxContainer) -> void:
	var plus := row.get_node("Plus")
	row.move_child(plus, row.get_child_count() - 1)


func _value(row: HBoxContainer, icon: Control, tip: String) -> Label:
	icon.tooltip_text = tip
	row.add_child(icon)
	var value := LobbyUi.text("—", 26, Color.WHITE, true)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.custom_minimum_size.x = VALUE_W
	value.tooltip_text = tip
	value.mouse_filter = MOUSE_FILTER_PASS
	row.add_child(value)
	return value


## The gem icon with a small padlock drawn on its lower right (kim cương khoá).
static func locked_gem_icon(px: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(px, px)
	box.size_flags_vertical = SIZE_SHRINK_CENTER
	box.mouse_filter = MOUSE_FILTER_PASS
	var gem := LobbyUi.icon("gem", px)
	gem.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(gem)
	var lock := Control.new()
	lock.name = "Lock"
	lock.mouse_filter = MOUSE_FILTER_IGNORE
	lock.size = Vector2(px, px)
	lock.draw.connect(func() -> void: draw_lock(lock, Vector2(px * 0.74, px * 0.74), px * 0.42))
	box.add_child(lock)
	return box


## A padlock `h` tall centred on `at`: a dark outline, a gold body with a keyhole, a steel shackle.
static func draw_lock(ci: CanvasItem, at: Vector2, h: float) -> void:
	var w := h * 0.86
	var body := Rect2(at.x - w / 2.0, at.y - h * 0.08, w, h * 0.58)
	var out := Color(0.07, 0.06, 0.12)
	ci.draw_arc(at + Vector2(0, -h * 0.1), w * 0.32, PI, TAU, 12, out, h * 0.26, true)
	ci.draw_arc(at + Vector2(0, -h * 0.1), w * 0.32, PI, TAU, 12, Color(0.85, 0.88, 0.95), h * 0.12, true)
	ci.draw_rect(body.grow(h * 0.09), out)
	ci.draw_rect(body, Color(1.0, 0.8, 0.25))
	ci.draw_rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.35)), Color(1.0, 0.92, 0.55))
	ci.draw_circle(body.get_center() + Vector2(0, -h * 0.03), h * 0.08, out)


func _render() -> void:
	if PlayerState.is_loaded():
		_gem_locked.text = Fmt.thousands(PlayerState.gem_locked())
		_gem.text = Fmt.thousands(PlayerState.gem_unlocked())
		_coin.text = Fmt.thousands(PlayerState.coin())
	else:
		_gem_locked.text = "—"
		_gem.text = "—"
		_coin.text = "—"
	_retry.visible = PlayerState.error != "" and not PlayerState.loading
