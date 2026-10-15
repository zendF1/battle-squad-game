extends Control
## Loadout before Quick Play (spec "Client UX"): pick a character and up to three items, then
## "Vào trận" sends QuickPlay {bot?, characterId, items} through the QuickPlay helper. Home puts
## the mode ({} practice target, {"bot": "ai"}) in Router.quick_play_base. Ownership comes from
## the API; a failed request only hides the owned/quantity notes, it never blocks playing.

const Ui := preload("res://ui/ui.gd")
const Items := preload("res://match/items.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const QuickPlay := preload("res://screens/quick_play.gd")
const SETTINGS_PATH := LoadoutModel.SETTINGS_PATH

var _model := LoadoutModel.new()
var _base: Dictionary = {}
var _quick_play: QuickPlay
var _character_buttons := {} # characterId -> Button
var _item_buttons := {} # itemId -> Button
var _count: Label
var _status: Label
var _conn: Label
var _back: Button
var _play: Button


func _ready() -> void:
	_base = Router.quick_play_base.duplicate()
	_model.restore(SETTINGS_PATH)
	_quick_play = QuickPlay.new()
	add_child(_quick_play)
	_quick_play.changed.connect(_refresh)

	var col := Ui.center_column(self)
	col.add_theme_constant_override("separation", 14)
	var mode := "Đấu với máy" if _base.has("bot") else "Luyện tập"
	col.add_child(Ui.label("Chuẩn bị  ·  %s" % mode, 32))

	col.add_child(Ui.label("Nhân vật", 24))
	var chars := HBoxContainer.new()
	chars.add_theme_constant_override("separation", 12)
	col.add_child(chars)
	for c in LoadoutModel.CHARACTERS:
		var b := _toggle("", 22, Vector2(300, 150))
		b.pressed.connect(_on_character.bind(c["id"]))
		chars.add_child(b)
		_character_buttons[c["id"]] = b

	_count = Ui.label("", 24)
	col.add_child(_count)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	for id in Items.ORDER:
		var b := _toggle("", 22, Vector2(300, 96))
		b.pressed.connect(_on_item.bind(id))
		grid.add_child(b)
		_item_buttons[id] = b

	_conn = Ui.label("", 24)
	col.add_child(_conn)
	_status = Ui.label("", 24)
	col.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	_back = Ui.button("Quay lại", 30)
	_back.custom_minimum_size = Vector2(300, 96)
	_back.pressed.connect(_on_back)
	row.add_child(_back)
	_play = Ui.button("Vào trận", 30)
	_play.custom_minimum_size = Vector2(360, 96)
	_play.pressed.connect(_on_play)
	row.add_child(_play)

	_refresh()
	_fetch_characters()
	_fetch_inventory()


func _fetch_characters() -> void:
	var res: Dictionary = await Api.get_json("/player/characters")
	if res.ok:
		_model.owned_characters = LoadoutModel.parse_characters(res.data)
		_refresh()


func _fetch_inventory() -> void:
	var res: Dictionary = await Api.get_json("/player/inventory")
	if res.ok:
		_model.item_counts = LoadoutModel.parse_inventory(res.data)
		_refresh()


func _on_character(id: String) -> void:
	_model.select_character(id)
	_refresh()


## A full loadout disables the other items, so a fourth cannot be picked.
func _on_item(id: String) -> void:
	_model.toggle_item(id)
	_refresh()


func _on_play() -> void:
	_model.remember(SETTINGS_PATH)
	_quick_play.request(_model.payload(_base))


func _on_back() -> void:
	if _quick_play.pending:
		return
	Router.go(Router.HOME)


## The buttons' pressed look always shows the model, whatever a click did to them.
func _refresh() -> void:
	var locked := _quick_play.pending
	for id in _character_buttons:
		var b: Button = _character_buttons[id]
		var text := "%s\n%s" % [_character_name(id), LoadoutModel.character_detail(id)]
		var note := _model.character_note(id)
		b.text = text if note == "" else "%s\n%s" % [text, note]
		b.set_pressed_no_signal(id == _model.character_id)
		b.disabled = locked
	for id in _item_buttons:
		var b: Button = _item_buttons[id]
		var note := _model.item_note(id)
		b.text = Items.label(id) if note == "" else "%s\n%s" % [Items.label(id), note]
		var picked := _model.items.has(id)
		b.set_pressed_no_signal(picked)
		b.disabled = locked or (_model.is_full() and not picked)
	_count.text = "Vật phẩm  %d/%d" % [_model.items.size(), Items.MAX_LOADOUT]
	_conn.text = "● Online" if GameSocket.is_open() else "○ Đang kết nối..."
	_status.text = _quick_play.status
	_play.disabled = not _quick_play.can_request()
	_back.disabled = locked


static func _character_name(id: String) -> String:
	for c in LoadoutModel.CHARACTERS:
		if c["id"] == id:
			return c["name"]
	return id


static func _toggle(text: String, font_size: int, min_size: Vector2) -> Button:
	var b := Ui.button(text, font_size)
	b.custom_minimum_size = min_size
	b.toggle_mode = true
	b.focus_mode = FOCUS_NONE
	return b
