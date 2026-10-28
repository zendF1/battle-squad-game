extends "res://ui/modal.gd"
## The "Mua" dialog of a unit-priced item offer (ShopModel.sells_quantity()), one centred column:
## the item's big icon, what the bag holds of it (the bag icon and the count; red when full), the
## count with ▼ / ▲ round it (hold to repeat), the presets x3 / x5 / x10 (toggles: the chosen one
## lit, tapping it again = x1), the total as the item's small icon × total, the price with the
## currency icon (red when the balance is short; no total while the bag is full), and one Mua button. ▲ and the presets that would
## take the bag past its cap are off (BuyQuantity). The name is the title (one line); the X and a
## tap outside close it. Mua calls on_buy(total offers).

const BuyQuantity := preload("res://screens/home/buy_quantity.gd")
const ShopModel := preload("res://screens/home/shop_model.gd")
const Art := preload("res://ui/art.gd")
const Fmt := preload("res://core/fmt.gd")

const ICON_PX := 132
const STEP_SIZE := Vector2(92, 84) # the ▼ / ▲ buttons
const COUNT_W := 150 # the count between them
const PRESET_SIZE := Vector2(116, 64)
const HOLD_DELAY := 0.35 # s held before ▲ / ▼ repeat
const HOLD_EVERY := 0.07 # s between repeats
const SHORT := Color(1.0, 0.42, 0.38) # the price the balance cannot pay, the full bag

var model: BuyQuantity
var offer := {}
var owned := -1 # -1 unknown
var on_buy := Callable()

var up_button: Button
var down_button: Button
var count_label: Label
var total_label: Label
var price_label: Label
var owned_label: Label
var buy_button: Button
var sum_row: HBoxContainer # the total and its price (hidden while nothing fits)
var preset_buttons: Array[Button] = []
var _hold := 0 # +1 ▲ held, -1 ▼ held
var _hold_timer: Timer


## A triangle pointing up or down, drawn in the button's middle.
class Arrow extends Control:
	var up := true

	func _draw() -> void:
		var c := size / 2.0
		var w := minf(size.x, size.y) * 0.26
		var h := w * 0.9
		var pts := PackedVector2Array([c + Vector2(-w, h * 0.5), c + Vector2(w, h * 0.5), c + Vector2(0, -h)]) if up \
			else PackedVector2Array([c + Vector2(-w, -h * 0.5), c + Vector2(w, -h * 0.5), c + Vector2(0, h)])
		draw_colored_polygon(pts, Color.WHITE)


## Builds the dialog over `host` for `the_offer`: `owned_count` the bag's count of its item (-1
## unknown), `balance` the player's balance in its currency (-1 unknown), `buy(total)` on Mua.
func open_for(host: Node, the_offer: Dictionary, owned_count: int, balance: int, buy: Callable) -> void:
	offer = the_offer
	owned = owned_count
	on_buy = buy
	model = BuyQuantity.new(ShopModel.room(offer, owned), int(offer.get("priceAmount", 0)), balance)
	open(host, ShopModel.offer_name(offer), 640)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_close_x()
	title.autowrap_mode = TextServer.AUTOWRAP_OFF # one line (add_close_x() wraps it)
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.timeout.connect(_on_hold_tick)
	add_child(_hold_timer)
	var id := str(offer.get("itemId", ""))

	var icon := LobbyUi.icon(Art.item_icon(id), ICON_PX)
	icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	body.add_child(icon)
	var bag := _row(body)
	bag.add_child(LobbyUi.icon("inventory", 34))
	owned_label = LobbyUi.text(Fmt.thousands(owned) if owned >= 0 else "—", 26, Color.WHITE)
	owned_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bag.add_child(owned_label)

	var steps := _row(body, 16)
	down_button = _step_button(false)
	steps.add_child(down_button)
	count_label = LobbyUi.text("", 44, Color.WHITE, true)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size = Vector2(COUNT_W, STEP_SIZE.y)
	steps.add_child(count_label)
	up_button = _step_button(true)
	steps.add_child(up_button)

	var presets := _row(body, 14)
	for p in BuyQuantity.PRESETS:
		var b := Ui.button("x%d" % p, 26)
		b.toggle_mode = true
		b.focus_mode = FOCUS_NONE
		b.custom_minimum_size = PRESET_SIZE
		Ui.toggle_style(b, Ui.TAB_BG, Ui.ACCENT, 12)
		b.pressed.connect(_on_preset.bind(p))
		presets.add_child(b)
		preset_buttons.append(b)

	var sum := _row(body, 10)
	sum_row = sum
	sum.add_child(LobbyUi.icon(Art.item_icon(id), 40))
	total_label = LobbyUi.text("", 30, Color.WHITE, true)
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sum.add_child(total_label)
	var gap := Control.new()
	gap.custom_minimum_size.x = 36
	sum.add_child(gap)
	sum.add_child(LobbyUi.icon(ShopModel.currency_icon(str(offer.get("priceCurrency", ""))), 40))
	price_label = LobbyUi.text("", 30, Color.WHITE, true)
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sum.add_child(price_label)

	buy_button = add_button("Mua", _on_buy)
	refresh()


func _row(parent: Control, separation: int = 8) -> HBoxContainer:
	var r := Ui.hbox(separation)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _step_button(up: bool) -> Button:
	var b := Ui.button("", 24)
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size = STEP_SIZE
	Ui.toggle_style(b, Ui.TAB_BG.lightened(0.12), Ui.ACCENT, 14)
	var arrow := Arrow.new()
	arrow.up = up
	arrow.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	arrow.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(arrow)
	b.button_down.connect(_on_step_down.bind(1 if up else -1))
	b.button_up.connect(_on_step_up)
	return b


## Shows the model: the count, the total, the price (red when short), what is on or off.
func refresh() -> void:
	count_label.text = str(model.count)
	total_label.text = "×%d" % (model.total() * maxi(int(offer.get("quantity", 1)), 1))
	price_label.text = Fmt.thousands(model.price())
	price_label.add_theme_color_override("font_color", Color.WHITE if model.affordable() else SHORT)
	owned_label.add_theme_color_override("font_color", SHORT if model.room <= 0 else Color.WHITE)
	up_button.disabled = not model.can_up()
	down_button.disabled = not model.can_down()
	for b in [up_button, down_button]:
		b.get_child(0).modulate.a = 0.3 if b.disabled else 1.0
	for i in preset_buttons.size():
		var p: int = BuyQuantity.PRESETS[i]
		preset_buttons[i].set_pressed_no_signal(model.preset == p)
		preset_buttons[i].disabled = not model.preset_allowed(p)
		preset_buttons[i].modulate.a = 0.4 if preset_buttons[i].disabled else 1.0
	sum_row.visible = model.room > 0 # a full bag: nothing to total
	if buy_button != null:
		buy_button.disabled = not model.can_buy()
		if not model.can_buy():
			lock_button(buy_button)
		else:
			buy_button.set_meta("locked", false)


func _on_preset(p: int) -> void:
	model.toggle(p)
	refresh()


func _on_step_down(dir: int) -> void:
	_hold = dir
	_step(dir)
	_arm_hold(HOLD_DELAY)


func _on_step_up() -> void:
	_hold = 0
	_hold_timer.stop()


func _on_hold_tick() -> void:
	if _hold == 0:
		return
	if not _step(_hold):
		_hold = 0
		return
	_arm_hold(HOLD_EVERY)


## The next repeat in sec s (only on screen: the tests tick it by hand).
func _arm_hold(sec: float) -> void:
	if _hold_timer.is_inside_tree():
		_hold_timer.start(sec)


## One step of ▲ (+1) or ▼ (-1); whether it moved.
func _step(dir: int) -> bool:
	var moved := model.up() if dir > 0 else model.down()
	refresh()
	return moved


func _on_buy() -> void:
	if not model.can_buy():
		return
	var total := model.total()
	close()
	if on_buy.is_valid():
		on_buy.call(total)
