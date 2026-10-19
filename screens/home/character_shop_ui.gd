extends RefCounted
## The Shop's "Nhân vật" widgets (data: character_shop_model.gd): a tall character card (the
## animated lobby full-body figure, ui/character_view.gd, on a glow in the character's colour;
## name, role, skill, "Thông tin" and the buy button) and the "Thông tin" popup (the figure;
## base stats as numbers and bars, weapon with its hug art, skill, "Lối chơi"; Mua / Đóng).

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const Modal := preload("res://ui/modal.gd")
const CharacterView := preload("res://ui/character_view.gd")
const Model := preload("res://screens/home/character_shop_model.gd")

const CARD_BG := Color(0.06, 0.08, 0.19, 0.88)
const HEAD := Color(0.8, 0.88, 1.0)
const INFO_W := 1180


## The glow behind a figure: a soft radial light in the character's colour and a brighter
## ellipse on the floor under its feet (where a CharacterView of the same rect puts them).
class Backdrop extends Control:
	static var _radial: Texture2D

	var tint := Color.WHITE

	func _init(c: Color) -> void:
		tint = c
		mouse_filter = MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	static func radial() -> Texture2D:
		if _radial == null:
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 1))
			g.set_color(1, Color(1, 1, 1, 0))
			g.add_point(0.45, Color(1, 1, 1, 0.45))
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.0, 0.5)
			t.width = 128
			t.height = 128
			_radial = t
		return _radial

	func _draw() -> void:
		var tex := radial()
		var light := Color(tint.lightened(0.25), 0.75)
		draw_texture_rect(tex, Rect2(Vector2(-size.x * 0.15, size.y * 0.02), Vector2(size.x * 1.3, size.y * 1.0)), false, light)
		var k := minf(size.x / CharacterView.UNITS.x, size.y / CharacterView.UNITS.y)
		var feet := Vector2(size.x / 2, size.y - 8 * k)
		var floor_size := Vector2(minf(size.x * 0.9, 280.0), 56.0)
		draw_texture_rect(tex, Rect2(feet - floor_size / 2, floor_size), false, Color(tint.lightened(0.55), 1.0))


## A figure stage: the backdrop and the idling full-body picture fitted into it, feet at the
## bottom centre.
static func stage(id: String) -> Control:
	var s := Control.new()
	s.clip_contents = true
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Backdrop.new(Model.tint(id))
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(back)
	var art := CharacterView.new()
	art.character_id = id
	art.hands_free = true
	art.idle = true
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.add_child(art)
	return s


## A card's parts the Shop updates: {root, buy, other (the other prices row)}.
static func card(id: String, on_info: Callable, on_buy: Callable) -> Dictionary:
	var tint := Model.tint(id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", LobbyUi.box(CARD_BG, 18, 12, Color(tint, 0.7), 2))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := Ui.vbox(4)
	panel.add_child(col)

	var fig := stage(id)
	fig.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fig.mouse_filter = Control.MOUSE_FILTER_STOP
	fig.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			on_info.call())
	col.add_child(fig)

	var title := LobbyUi.text(Model.character_name(id), 32, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var role := LobbyUi.text(Model.role(id), 20, tint.lightened(0.45), true)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(role)
	var skill := Ui.text("Kỹ năng: %s" % Model.info(id)["skill"]["name"], 18, Ui.TEXT_DIM)
	skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(skill)

	# The other prices ("hoặc 300 [gem]"): always reserved, so the buttons line up.
	var other := HBoxContainer.new()
	other.alignment = BoxContainer.ALIGNMENT_CENTER
	other.add_theme_constant_override("separation", 6)
	other.custom_minimum_size.y = 30
	col.add_child(other)

	var buttons := Ui.hbox(8)
	col.add_child(buttons)
	var info := Ui.button("Thông tin", 22)
	info.custom_minimum_size = Vector2(0, 60)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.focus_mode = Control.FOCUS_NONE
	info.pressed.connect(on_info)
	buttons.add_child(info)
	var buy := Ui.button(Model.BUY_TEXT, 22)
	buy.custom_minimum_size = Vector2(0, 60)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.focus_mode = Control.FOCUS_NONE
	buy.pressed.connect(on_buy)
	style_buy(buy)
	buttons.add_child(buy)
	return {"root": panel, "buy": buy, "other": other}


## The buy button's look: orange while it can buy, the plain dark one otherwise.
static func style_buy(b: Button) -> void:
	LobbyUi.style_button(b, Color(0.93, 0.55, 0.12), 14, 8)
	b.add_theme_stylebox_override("disabled", LobbyUi.box(Color(0.12, 0.14, 0.26, 0.9), 14, 8, Color(1, 1, 1, 0.12), 2))
	b.add_theme_font_override("font", LobbyUi.bold())
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))


## Sets a buy button from Model.buy_button() (busy: a purchase runs).
static func set_buy(b: Button, look: Dictionary, busy: bool) -> void:
	b.text = look["text"]
	if look["icon"] != "":
		LobbyUi.set_icon(b, look["icon"], 30)
	else:
		b.icon = null
	b.disabled = not look["enabled"] or busy


## Fills the other prices row of a card.
static func set_other_prices(row: HBoxContainer, prices: Array) -> void:
	Ui.clear(row)
	for i in prices.size():
		row.add_child(Ui.text("hoặc", 18, Ui.TEXT_DIM))
		LobbyUi.icon_text(row, prices[i]["icon"], prices[i]["text"], 20, Color.WHITE, true, 24)


# ── Info popup ──────────────────────────────────────────────────────────────

## The "Thông tin" popup of a character: data is the GET /player/characters data (base
## stats), c its Model.card(); on_buy runs after the popup closed. Returns the Modal.
static func open_info(overlay: Control, id: String, data: Variant, c: Dictionary, busy: bool, on_buy: Callable) -> Modal:
	var info := Model.info(id)
	var tint: Color = info["tint"]
	var m := Modal.new()
	m.open(overlay, info["name"], INFO_W)
	var row := Ui.hbox(28)
	m.body.add_child(row)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", LobbyUi.box(CARD_BG, 18, 0, Color(tint, 0.7), 2))
	left.custom_minimum_size = Vector2(290, 400)
	row.add_child(left)
	left.add_child(stage(id))

	var right := Ui.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(LobbyUi.text(info["role"], 24, tint.lightened(0.45), true))

	var cols := Ui.hbox(28)
	right.add_child(cols)
	var stats := Ui.vbox(6)
	stats.custom_minimum_size.x = 430
	cols.add_child(stats)
	stats.add_child(LobbyUi.text("Chỉ số cơ bản", 22, HEAD, true))
	var rows := Model.stat_rows(data, id)
	if rows.is_empty():
		stats.add_child(Ui.text("Chưa tải được chỉ số", 20, Ui.TEXT_DIM))
	for r in rows:
		stats.add_child(_stat_row(r, tint))

	var gear := Ui.vbox(6)
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(gear)
	gear.add_child(LobbyUi.text("Vũ khí", 22, HEAD, true))
	var weapon := Ui.hbox(12)
	gear.add_child(weapon)
	var gun := TextureRect.new()
	gun.texture = Art.hug_gun(info["weapon"]["kind"], info["weapon"]["tier"])["texture"]
	gun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gun.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gun.custom_minimum_size = Vector2(120, 52)
	weapon.add_child(gun)
	var wnames := Ui.vbox(0)
	wnames.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon.add_child(wnames)
	wnames.add_child(LobbyUi.text(info["weapon"]["name"], 22, Color.WHITE, true))
	wnames.add_child(Ui.text(info["weapon"]["wind"], 18, Ui.TEXT_DIM))
	gear.add_child(LobbyUi.text("Kỹ năng: %s" % info["skill"]["name"], 22, HEAD, true))
	var skill := Ui.text(info["skill"]["text"], 19)
	skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gear.add_child(skill)
	gear.add_child(Ui.text(info["skill"]["energy"], 18, LobbyUi.GOLD))

	right.add_child(LobbyUi.text("Lối chơi", 22, HEAD, true))
	var play := Ui.text(info["playstyle"], 20)
	play.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(play)

	var buy := m.add_button(Model.BUY_TEXT, func() -> void:
		m.close()
		on_buy.call())
	style_buy(buy)
	var look := Model.buy_button(c)
	if c["state"] == Model.BUY:
		look["text"] = "Mua %s" % look["text"]
	set_buy(buy, look, busy)
	m.add_button("Đóng", m.close)
	return m


static func _stat_row(r: Dictionary, tint: Color) -> Control:
	var row := Ui.hbox(12)
	var k := Ui.text(r["label"], 20, HEAD)
	k.custom_minimum_size.x = 214
	row.add_child(k)
	var bar := Ui.bar(r["ratio"], 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", LobbyUi.box(tint.lightened(0.3), 7, 0))
	row.add_child(bar)
	var v := LobbyUi.text(r["text"], 20, Color.WHITE, true)
	v.custom_minimum_size.x = 64
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return row
