extends Control
## The Home lobby (a Gunny-style mobile lobby). Corners: the player (avatar letter, name, EXP
## bar, "Lv.N"; tap opens Hồ sơ) top-left, the wallet pills top-right, the connection state
## top-centre, one round shortcut per page down the right (Nhân vật, Kho đồ, Lịch sử, Shop), the
## selected character's info card (role, skill, stats; its name and level are on the stage) on
## the left, a placeholder chat box bottom-left and the mode card with "BẮT ĐẦU" bottom-right.
## Centre stage: the selected character's name and level over it, drawn big on a pedestal;
## ◀ ▶ or a swipe cycles the four characters. The character is the Loadout's (saved
## in the same settings file, so the Loadout opens with it) and the mode is remembered there
## too. "BẮT ĐẦU" puts the mode's QuickPlay base in Router.quick_play_base and opens the
## Loadout. Character levels and stats come from the PlayerState characters cache, loaded when
## the lobby is shown; until then the card shows name, role and skill only.

signal open_profile(section: int)
signal open_shop(section: int)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const CharacterArt := preload("res://ui/character_art.gd")
const WalletPills := preload("res://ui/wallet_pills.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const Progress := preload("res://screens/home/progress.gd")
const ProfileTab := preload("res://screens/home/profile_tab.gd")
const ShopTab := preload("res://screens/home/shop_tab.gd")
const FakeChat := preload("res://screens/home/fake_chat.gd")

const MARGIN := 18
const STAGE := Vector2(560, 590)
const SWIPE := 70.0 # px of horizontal drag that switches the character
const AVATAR_COLORS := [Color(0.9, 0.4, 0.35), Color(0.3, 0.6, 0.95), Color(0.35, 0.75, 0.45), Color(0.65, 0.45, 0.9), Color(0.95, 0.6, 0.2)]

var wallet: WalletPills
var settings_path := LoadoutModel.SETTINGS_PATH

var _model := LoadoutModel.new() # the character choice (items kept as the Loadout left them)
var _mode := 0

# Player block
var _avatar: PanelContainer
var _avatar_letter: Label
var _name: Label
var _exp_bar: ProgressBar
var _level: Label
var _level_badge: PanelContainer
var _player_status: Label
var _conn: Label

# Stage and info card
var _art: CharacterArt
var _stage_name: Label
var _stage_level: Label
var _info_role: Label
var _info_skill: Label
var _info_stats: GridContainer
var _info_buy: Button
var _drag_from := -1.0

# Mode card
var _mode_name: Label
var _mode_text: Label
var _start: Button


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_model.restore(settings_path)
	_mode = LobbyModel.restore_mode(settings_path)

	_add_stage()
	_pin(_build_player_block(), 0, 0, MARGIN, MARGIN)
	_conn = LobbyUi.text("", 22, Color.WHITE, true)
	_pin(_conn, 0.5, 0, 0, MARGIN + 6)
	wallet = WalletPills.new()
	_pin(wallet, 1, 0, -MARGIN, MARGIN)
	_pin(_build_shortcuts(), 1, 0, -MARGIN - 6, 112)
	_pin(_build_info_card(), 0, 0, MARGIN, 150)
	_pin(_build_chat(), 0, 1, MARGIN, -MARGIN)
	_pin(_build_mode_card(), 1, 1, -MARGIN, -MARGIN)

	PlayerState.changed.connect(_render_player)
	PlayerState.characters_changed.connect(_render_character)
	GameSocket.connected.connect(_render_conn)
	GameSocket.disconnected.connect(_render_conn)
	visibility_changed.connect(_on_visibility_changed)
	_render_player()
	_render_conn()
	_render_mode()
	_render_character()
	_on_visibility_changed()


## Anchors `c` to a point of the screen (ax, ay: 0 left/top, 0.5 centre, 1 right/bottom) at an
## offset; it grows away from that edge as its content needs.
func _pin(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	add_child(c)
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = _grow(ax)
	c.grow_vertical = _grow(ay)


static func _grow(anchor: float) -> GrowDirection:
	if anchor >= 1.0:
		return GROW_DIRECTION_BEGIN
	return GROW_DIRECTION_BOTH if anchor > 0.0 else GROW_DIRECTION_END


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		PlayerState.need_characters()
		_render_character() # back from a page: whatever it loaded or bought


# ── Player ──────────────────────────────────────────────────────────────────

func _build_player_block() -> Control:
	var b := Button.new()
	LobbyUi.style_button(b, Color(0, 0, 0, 0), 20, 6)
	b.add_theme_stylebox_override("hover", LobbyUi.box(Color(1, 1, 1, 0.06), 20, 6))
	b.add_theme_stylebox_override("pressed", LobbyUi.box(Color(1, 1, 1, 0.12), 20, 6))
	b.custom_minimum_size = Vector2(380, 104)
	b.pressed.connect(func(): open_profile.emit(ProfileTab.CHARACTERS))
	var row := Ui.hbox(14)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_top = 6
	row.offset_right = -6
	row.offset_bottom = -6
	b.add_child(row)
	_avatar = PanelContainer.new()
	_avatar.custom_minimum_size = Vector2(92, 92)
	_avatar_letter = LobbyUi.text("?", 48, Color.WHITE, true)
	_avatar_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar.add_child(_avatar_letter)
	row.add_child(_avatar)
	var col := Ui.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(col)
	_name = LobbyUi.text("", 28, Color.WHITE, true)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_name)
	_exp_bar = Ui.bar(0.0, 12)
	_exp_bar.add_theme_stylebox_override("fill", LobbyUi.box(LobbyUi.GOLD, 6, 0))
	_exp_bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.45), 6, 0, Color(1, 1, 1, 0.15), 1))
	col.add_child(_exp_bar)
	var lv_row := Ui.hbox(10)
	col.add_child(lv_row)
	_level_badge = LobbyUi.panel(0, 12, Color(0.12, 0.35, 0.75, 0.9))
	_level = LobbyUi.text("", 20, Color.WHITE, true)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.custom_minimum_size.x = 76
	_level_badge.add_child(_level)
	lv_row.add_child(_level_badge)
	_player_status = LobbyUi.text("", 20, Ui.TEXT_DIM)
	lv_row.add_child(_player_status)
	for c in [row, _avatar, _avatar_letter, col, _name, _exp_bar, lv_row, _level_badge, _level, _player_status]:
		c.mouse_filter = MOUSE_FILTER_IGNORE
	return b


func _render_player() -> void:
	var display := PlayerState.display_name()
	_name.text = display
	_avatar_letter.text = display.substr(0, 1).to_upper() if display != "" else "?"
	var tint: Color = AVATAR_COLORS[absi(hash(display)) % AVATAR_COLORS.size()]
	_avatar.add_theme_stylebox_override("panel", LobbyUi.box(tint, 20, 0, Color(1, 1, 1, 0.9), 3))
	var loaded := PlayerState.is_loaded()
	_level_badge.visible = loaded
	if loaded:
		_level.text = "Lv.%d" % PlayerState.level()
		var p := Progress.player(PlayerState.level(), PlayerState.player_exp())
		_exp_bar.value = p["ratio"]
		_player_status.text = "EXP %s" % p["text"]
		_player_status.add_theme_color_override("font_color", Ui.TEXT_DIM)
	else:
		_exp_bar.value = 0.0
		_player_status.text = "Đang tải..." if PlayerState.loading else PlayerState.error
		_player_status.add_theme_color_override("font_color", Ui.TEXT_DIM if PlayerState.loading else Ui.TONES["error"])


func _render_conn() -> void:
	if GameSocket.is_open():
		_conn.text = "● Online"
		_conn.add_theme_color_override("font_color", Ui.TONES["good"])
	else:
		_conn.text = "○ Đang kết nối..."
		_conn.add_theme_color_override("font_color", Ui.TONES["draw"])


# ── Shortcuts and chat ──────────────────────────────────────────────────────

func _build_shortcuts() -> Control:
	var col := Ui.vbox(12)
	col.add_child(LobbyUi.icon_button("👤", "Nhân vật", LobbyUi.ICON_COLORS["blue"], func(): open_profile.emit(ProfileTab.CHARACTERS)))
	col.add_child(LobbyUi.icon_button("🎒", "Kho đồ", LobbyUi.ICON_COLORS["green"], func(): open_profile.emit(ProfileTab.INVENTORY)))
	col.add_child(LobbyUi.icon_button("📜", "Lịch sử", LobbyUi.ICON_COLORS["purple"], func(): open_profile.emit(ProfileTab.HISTORY)))
	col.add_child(LobbyUi.icon_button("🛒", "Shop", LobbyUi.ICON_COLORS["orange"], func(): open_shop.emit(ShopTab.ITEMS)))
	return col


## The chat placeholder: the fake recent lines and an input-looking row; a tap says chat is
## coming later.
func _build_chat() -> Control:
	var b := Button.new()
	LobbyUi.style_button(b, LobbyUi.PANEL, 18, 0, LobbyUi.PANEL_BORDER, 2)
	b.add_theme_stylebox_override("hover", LobbyUi.box(Color(LobbyUi.PANEL.lightened(0.08), 0.7), 18, 0, LobbyUi.PANEL_BORDER, 2))
	b.custom_minimum_size = Vector2(490, 172)
	b.pressed.connect(func(): Ui.toast(self, FakeChat.COMING_SOON))
	var col := Ui.vbox(2)
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	col.offset_left = 14
	col.offset_top = 10
	col.offset_right = -14
	col.offset_bottom = -10
	b.add_child(col)
	var lines := RichTextLabel.new()
	lines.bbcode_enabled = true
	lines.scroll_active = false
	lines.autowrap_mode = TextServer.AUTOWRAP_OFF
	lines.clip_contents = true
	lines.size_flags_vertical = SIZE_EXPAND_FILL
	lines.add_theme_font_size_override("normal_font_size", 18)
	lines.add_theme_constant_override("line_separation", 0)
	lines.add_theme_constant_override("outline_size", 4)
	lines.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08, 0.85))
	lines.text = "\n".join(FakeChat.LINES.map(FakeChat.bbcode))
	col.add_child(lines)
	var input := LobbyUi.panel(0, 14, Color(0, 0, 0, 0.35))
	input.custom_minimum_size.y = 40
	col.add_child(input)
	var row := Ui.hbox(8)
	input.add_child(row)
	var hint := LobbyUi.text(FakeChat.PLACEHOLDER, 19, Ui.TEXT_DIM)
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_indent(hint, 12))
	var send := LobbyUi.panel(0, 14, LobbyUi.ICON_COLORS["blue"])
	send.custom_minimum_size = Vector2(56, 40)
	var arrow := LobbyUi.text("➤", 20, Color.WHITE, true)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	send.add_child(arrow)
	row.add_child(send)
	for c in [col, lines, input, row, hint, send, arrow]:
		c.mouse_filter = MOUSE_FILTER_IGNORE
	return b


static func _indent(c: Control, left: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.size_flags_horizontal = SIZE_EXPAND_FILL
	m.mouse_filter = MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m


# ── Stage ───────────────────────────────────────────────────────────────────

## The centre: name and level above the character on its pedestal, ◀ ▶ on the sides. Pinned to
## the bottom centre so it stays between the side columns on any width.
func _add_stage() -> void:
	var stage := Control.new()
	stage.custom_minimum_size = STAGE
	stage.mouse_filter = MOUSE_FILTER_STOP
	stage.gui_input.connect(_on_stage_input)
	_pin(stage, 0.5, 1, 0, -110)
	var pedestal := Control.new()
	pedestal.mouse_filter = MOUSE_FILTER_IGNORE
	pedestal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pedestal.draw.connect(_draw_pedestal.bind(pedestal))
	stage.add_child(pedestal)

	var head := Ui.vbox(0)
	head.mouse_filter = MOUSE_FILTER_IGNORE
	head.position = Vector2((STAGE.x - 400) / 2, 40)
	head.custom_minimum_size = Vector2(400, 0)
	stage.add_child(head)
	_stage_name = LobbyUi.text("", 44, Color.WHITE, true)
	_stage_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_stage_name)
	_stage_level = LobbyUi.text("", 24, LobbyUi.GOLD, true)
	_stage_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_stage_level)

	_art = CharacterArt.new()
	_art.position = Vector2((STAGE.x - 375) / 2, 142) # 2.5 px per art unit; feet on the pedestal
	_art.size = Vector2(375, 400)
	_art.idle = true
	stage.add_child(_art)

	for side in [-1, 1]:
		var arrow := LobbyUi.round_button("◀" if side < 0 else "▶", 76, Color(0.05, 0.08, 0.2, 0.7), 32)
		arrow.position = Vector2(0 if side < 0 else STAGE.x - 76, 230) # beside the head, clear of the weapon
		arrow.pressed.connect(_cycle.bind(side))
		stage.add_child(arrow)


## Oval layers, bottom to top: [radii, colour, y offset].
const PEDESTAL := [
	[Vector2(196, 50), Color(0.06, 0.1, 0.24, 0.9), 10.0],
	[Vector2(186, 44), Color(0.28, 0.46, 0.8), 4.0],
	[Vector2(178, 38), Color(0.55, 0.75, 1.0), 0.0],
	[Vector2(150, 28), Color(0.78, 0.9, 1.0, 0.55), 0.0],
]


func _draw_pedestal(c: Control) -> void:
	for layer in PEDESTAL:
		var r: Vector2 = layer[0]
		c.draw_set_transform(Vector2(STAGE.x / 2, 528 + layer[2]), 0.0, Vector2(1.0, r.y / r.x))
		c.draw_circle(Vector2.ZERO, r.x, layer[1])
	c.draw_set_transform(Vector2.ZERO)


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position.x
		elif _drag_from >= 0.0:
			var dx: float = event.position.x - _drag_from
			_drag_from = -1.0
			if absf(dx) >= SWIPE:
				_cycle(-1 if dx > 0 else 1) # drag right shows the previous one


func _cycle(delta: int) -> void:
	_model.select_character(LobbyModel.cycle_character(_model.character_id, delta))
	_model.remember(settings_path)
	_render_character()


## The id of the character on the stage.
func character_id() -> String:
	return _model.character_id


# ── Info card ───────────────────────────────────────────────────────────────

func _build_info_card() -> Control:
	var card := LobbyUi.panel(20, 20)
	card.custom_minimum_size.x = 360
	var col := Ui.vbox(8)
	card.add_child(col)
	_info_role = LobbyUi.text("", 28, Color.WHITE, true)
	col.add_child(_info_role)
	_info_skill = LobbyUi.text("", 22, Color(0.75, 0.9, 1.0))
	col.add_child(_info_skill)
	_info_stats = GridContainer.new()
	_info_stats.columns = 2
	_info_stats.add_theme_constant_override("h_separation", 16)
	_info_stats.add_theme_constant_override("v_separation", 4)
	col.add_child(_info_stats)
	_info_buy = Ui.button("Mua ở Shop", 22)
	LobbyUi.style_button(_info_buy, LobbyUi.ICON_COLORS["orange"], 14, 8)
	_info_buy.add_theme_font_override("font", LobbyUi.bold())
	_info_buy.custom_minimum_size = Vector2(0, 56)
	_info_buy.pressed.connect(func(): open_shop.emit(ShopTab.CHARACTERS))
	col.add_child(_info_buy)
	return card


func _render_character() -> void:
	if _art == null:
		return
	var id := _model.character_id
	var info := LobbyModel.character_info(id, PlayerState.characters)
	var level := LobbyModel.level_text(info)
	_art.character_id = id
	_art.modulate = Color(0.72, 0.72, 0.8) if info["owned"] == false else Color.WHITE
	_stage_name.text = info["name"]
	_stage_level.text = level
	_info_role.text = info["role"]
	_info_skill.text = "⚡ Kỹ năng: %s" % info["skill"] if info["skill"] != "" else ""
	_info_skill.visible = info["skill"] != ""
	Ui.clear(_info_stats)
	_info_stats.visible = not info["stats"].is_empty()
	for pair in info["stats"]:
		var key := LobbyUi.text(pair[0], 22, Ui.TEXT_DIM)
		key.size_flags_horizontal = SIZE_EXPAND_FILL
		_info_stats.add_child(key)
		var value := LobbyUi.text(pair[1], 22, Color.WHITE, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_info_stats.add_child(value)
	_info_buy.visible = info["owned"] == false


# ── Mode and start ──────────────────────────────────────────────────────────

func _build_mode_card() -> Control:
	var col := Ui.vbox(12)
	col.custom_minimum_size.x = 430
	var card := LobbyUi.panel(18, 20)
	col.add_child(card)
	var row := Ui.hbox(12)
	card.add_child(row)
	var texts := Ui.vbox(2)
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(texts)
	_mode_name = LobbyUi.text("", 32, Color.WHITE, true)
	texts.add_child(_mode_name)
	_mode_text = LobbyUi.text("", 22, Color(0.75, 0.9, 1.0))
	texts.add_child(_mode_text)
	var swap := LobbyUi.round_button("⇄", 68, LobbyUi.ICON_COLORS["blue"], 34)
	swap.size_flags_vertical = SIZE_SHRINK_CENTER
	swap.pressed.connect(_next_mode)
	row.add_child(swap)
	_start = LobbyUi.start_button("BẮT ĐẦU")
	_start.pressed.connect(_on_start)
	_start.resized.connect(func(): _start.pivot_offset = _start.size / 2)
	col.add_child(_start)
	var pulse := _start.create_tween().set_loops()
	pulse.tween_property(_start, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_start, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	return col


func _next_mode() -> void:
	_mode = LobbyModel.next_mode(_mode)
	LobbyModel.remember_mode(settings_path, _mode)
	_render_mode()


func _render_mode() -> void:
	var m: Dictionary = LobbyModel.MODES[_mode]
	_mode_name.text = m["name"]
	_mode_text.text = m["description"]


## The QuickPlay base of the chosen mode.
func mode_base() -> Dictionary:
	return LobbyModel.mode_base(_mode)


func _on_start() -> void:
	Router.quick_play_base = mode_base()
	Router.go(Router.LOADOUT)
