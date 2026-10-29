extends Control
## First login: pick a starter character and a name (GET /player/profile onboarded false; Splash and
## Login open this instead of Home). On the lobby background, three columns mirrored round the
## centre over the name row:
## - left, the character as pictures (InfoPanel, the UI's card frame): its name, its element chain
##   (ui/element_chain.gd: beaten by → element → beats), a row per base stat (glyph, a bar against
##   the strongest starter, the number: Máu heart, Sát thương sword, Phòng thủ shield, Năng lượng di
##   chuyển boot, Bán kính nổ blast, Phá địa hình terrain; CharacterShopModel.stat_rows(), GET
##   /player/characters baseStats), its starting gun's picture;
## - centre, the character standing as on the lobby stage (screens/home/player_figure.gd: the
##   full-body picture, its starting gun resting beside it; the lobby's pedestal under it), as big
##   as the screen allows, big ◀ ▶ mirrored on both sides, a swipe works too, wrapping around;
##   switching slides the figure off the pedestal and the next one on; a dot per starter under it;
## - right, its special skill (SkillPanel, the same size): the skill's picture (a tap: its popup with
##   the description), its name and the "i" (the same popup), and a looping replay of the skill
##   in use (screens/skill_demo.gd), restarted when the character changes;
## - under them, centred: the name field (white, rounded) with the dice inside its right end (a
##   blank as wide on the left, so the text stays centred): a tap tumbles the dice (turns twice and
##   bounces, ROLL_SEC) while the field's letters scramble, then fills GET /player/name-suggestion's
##   name; done once on opening; a hint line, empty unless needed (the name rule, a server refusal);
##   "Bắt đầu": disabled while the name breaks the rule (the field outlined red, the reason in the
##   hint); POST /player/onboarding {characterId, displayName}; the profile it answers is applied,
##   the starter becomes the lobby's character, then Home. Name taken / refused: the field shakes,
##   red, with the hint. ONBOARDING_DONE (another device did it): Home.
## Sizes (_fit()): the figure as big as the height leaves (FIGURE_MIN..FIGURE_MAX of the lobby
## stage's), the panels as wide as the width leaves (PANEL_MIN_W..PANEL_MAX_W; a narrow screen
## shrinks the figure before the panels go under their minimum), so nothing overlaps.
## The starters, names, stats, skills and the suggested names all come from the server.

const Art := preload("res://ui/art.gd")
const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const PlayerFigure := preload("res://screens/home/player_figure.gd")
const CharacterShopModel := preload("res://screens/home/character_shop_model.gd")
const ElementChain := preload("res://ui/element_chain.gd")
const SkillButton := preload("res://ui/skill_button.gd")
const SkillDemo := preload("res://screens/skill_demo.gd")
const Skills := preload("res://match/skills.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const Model := preload("res://screens/onboarding_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## The figure against the lobby stage's (PlayerFigure ART 375 × 400): as big as the screen's height
## leaves (_fit()), between these.
const FIGURE_MIN := 0.7
const FIGURE_MAX := 1.0
## Space kept above and below the column, and beside the panels.
const MARGIN_Y := 30.0
const MARGIN_X := 28.0
## The side panels' width (both the same).
const PANEL_MIN_W := 300.0
const PANEL_MAX_W := 440.0
const PANEL_MIN_H := 470.0
## Between a panel and its arrow.
const ROW_GAP := 24
## A stat glyph, its bar's height, the number's width.
const STAT_GLYPH := 30
const STAT_BAR := 12
const STAT_VALUE_W := 64
## Each stat's glyph (CharacterShopModel.STAT_ROWS keys).
const STAT_GLYPHS := {"maxHp": "heart", "weaponDamage": "sword", "defense": "shield", "moveEnergy": "boot",
	"explosionRadius": "blast", "craterRadius": "terrain"}
const STAT_FILL := Color(1.0, 0.8, 0.22)
const GUN_SIZE := Vector2(180, 70)
const SKILL_PX := 60
## Room under the feet for the pedestal (lobby stage px, scaled).
const PEDESTAL_ROOM := 58.0
const ARROW := 96
const ARROW_GAP := 18
const SWIPE := 70.0
const SLIDE_PX := 90.0
const SLIDE_SEC := 0.16
const DOT := 14
const FIELD := Vector2(560, 80)
const DICE := 60
const ROLL_SEC := 0.6
const SCRAMBLE_SEC := 0.05
const HINT_H := 34
const START_W := 420
const FIELD_BG := Color(0.98, 0.97, 0.93)
const FIELD_EDGE := Color(0.95, 0.72, 0.2)
const FIELD_TEXT := Color(0.16, 0.12, 0.08)
const BAD := Color(0.9, 0.18, 0.15)
const DOT_ON := Color(1.0, 0.8, 0.22)
const DOT_OFF := Color(1, 1, 1, 0.35)

## The REST client: the Api autoload, or a stand-in (tests, smoke runs).
var api: Object = null
## Where the starter is remembered for the lobby (LoadoutModel's settings file).
var settings_path := LoadoutModel.SETTINGS_PATH

var _ids: Array = []
var _id := ""
var _name_label: Label
var _row: HBoxContainer
var _panels: Array[PanelContainer] = []
var _chain: ElementChain
var _stats: VBoxContainer
var _gun: TextureRect
var _skill: SkillButton
var _skill_name: Label
var _demo: SkillDemo
var _stage: Control
var _figure_box: Control
var _figure: PlayerFigure
var _arrows: Array[Button] = []
var _dots: Control
var _field_panel: PanelContainer
var _field: LineEdit
var _dice: Button
var _dice_glyph: Control
var _hint: Label
var _hint_box: PanelContainer
var _col: VBoxContainer
var _scale := FIGURE_MIN
var _panel_w := PANEL_MIN_W
var _start: Button
var _drag_from := -1.0
var _rolling := false
var _spin_left := 0.0
var _scramble_left := 0.0
var _busy := false
var _server_hint := "" # a refusal's hint, kept until the name changes
var _shake: Tween
var _shake_x := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	build()
	PlayerState.characters_changed.connect(_render_stats)
	PlayerState.need_characters() # the stats (GET /player/characters baseStats)
	roll()


func _exit_tree() -> void:
	if PlayerState.characters_changed.is_connected(_render_stats):
		PlayerState.characters_changed.disconnect(_render_stats)


func _api() -> Object:
	return api if api != null else Api


## Builds the screen on the profile's starter (tests call it without a tree).
func build() -> void:
	theme = LobbyUi.theme()
	_rng.randomize()
	_ids = Model.starters()
	_id = Model.first(_ids, PlayerState.profile)
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.show_image(Art.BG_DEFAULT, false)
	add_child(bg)
	var center := CenterContainer.new()
	center.name = "Column"
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var col := Ui.vbox(0)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(col)
	_col = col

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", ROW_GAP)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(_row)
	_row.add_child(_build_info_panel())
	_row.add_child(_build_stage())
	_row.add_child(_build_skill_panel())
	_dots = Control.new()
	_dots.name = "Dots"
	_dots.mouse_filter = MOUSE_FILTER_IGNORE
	_dots.custom_minimum_size = Vector2(maxi(_ids.size(), 1) * DOT * 2, DOT + 6)
	_dots.size_flags_horizontal = SIZE_SHRINK_CENTER
	_dots.draw.connect(_draw_dots)
	col.add_child(_dots)
	col.add_child(_gap(16))
	col.add_child(_build_field())
	var hint_slot := CenterContainer.new() # the same height with or without a hint: nothing jumps
	hint_slot.custom_minimum_size = Vector2(0, HINT_H + 12)
	hint_slot.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(hint_slot)
	_hint_box = PanelContainer.new()
	_hint_box.mouse_filter = MOUSE_FILTER_IGNORE
	var hb := LobbyUi.box(Color(0.1, 0.03, 0.03, 0.78), HINT_H / 2, 0)
	hb.content_margin_left = 18
	hb.content_margin_right = 18
	_hint_box.add_theme_stylebox_override("panel", hb)
	hint_slot.add_child(_hint_box)
	_hint = LobbyUi.text("", 22, Color(1.0, 0.55, 0.5), true)
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(0, HINT_H)
	_hint_box.add_child(_hint)
	_start = LobbyUi.start_button("Bắt đầu")
	_start.name = "Start"
	_start.custom_minimum_size = Vector2(START_W, 88)
	_start.size_flags_horizontal = SIZE_SHRINK_CENTER
	_start.pressed.connect(confirm)
	col.add_child(_start)
	_render_character()
	_render_name()
	resized.connect(_fit)
	_col.minimum_size_changed.connect(_fit)


## The figure as big as the height leaves for it and the width leaves beside the panels at their
## minimum (FIGURE_MIN..FIGURE_MAX), then the panels as wide as the width leaves.
func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var room := PlayerFigure.ART_FEET + PEDESTAL_ROOM
	var rest := _col.get_combined_minimum_size().y - _row.get_combined_minimum_size().y
	var by_h := (size.y - 2.0 * MARGIN_Y - rest) / room
	var arrows := 2.0 * ARROW + 2.0 * ARROW_GAP
	var by_w := (size.x - 2.0 * MARGIN_X - 2.0 * ROW_GAP - 2.0 * PANEL_MIN_W - arrows) / PlayerFigure.ART.x
	var s := clampf(minf(by_h, by_w), FIGURE_MIN, FIGURE_MAX)
	if not is_equal_approx(s, _scale):
		_set_scale(s)
	var w := clampf((size.x - 2.0 * MARGIN_X - 2.0 * ROW_GAP - arrows - PlayerFigure.ART.x * s) / 2.0, PANEL_MIN_W, PANEL_MAX_W)
	if not is_equal_approx(w, _panel_w):
		_set_panel_width(w)


func _set_panel_width(w: float) -> void:
	_panel_w = w
	for p in _panels:
		p.custom_minimum_size.x = w


## The side panels' width (both the same).
func panel_width() -> float:
	return _panel_w


func _set_scale(s: float) -> void:
	_scale = s
	_figure_box.custom_minimum_size = Vector2(PlayerFigure.ART.x, PlayerFigure.ART_FEET + PEDESTAL_ROOM) * s
	_figure.figure_scale = s
	_figure.foot_margin = PEDESTAL_ROOM * s
	_figure.size = _figure_box.custom_minimum_size
	_figure_box.queue_redraw()


## The figure's scale of the lobby stage's.
func figure_scale() -> float:
	return _scale


## The lobby's pedestal (assets/env/pedestal.png, placed as PlayerFigure does), still while the
## figure slides over it.
func _draw_pedestal() -> void:
	var tex := Art.env("pedestal")
	if tex == null:
		return
	var feet := Vector2(_figure_box.size.x / 2.0, _figure_box.size.y - PEDESTAL_ROOM * _scale)
	var centre := feet + Vector2(0, PlayerFigure.PEDESTAL_DROP * _scale)
	_figure_box.draw_texture_rect(tex, Rect2(centre - Art.PEDESTAL_CENTER * _scale, tex.get_size() * _scale), false)


## A side panel in the UI's card frame (LobbyUi.panel()), PANEL_MIN_H tall at least, filling
## the row's height (both panels the same size).
func _panel(panel_name: String) -> PanelContainer:
	var p := LobbyUi.panel(18, 20)
	p.name = panel_name
	p.custom_minimum_size = Vector2(_panel_w, PANEL_MIN_H)
	p.size_flags_vertical = SIZE_FILL
	_panels.append(p)
	return p


## Left: the name, the element chain, the stat rows, the starting gun.
func _build_info_panel() -> Control:
	var p := _panel("InfoPanel")
	var col := Ui.vbox(14)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(col)
	_name_label = LobbyUi.text("", 40, Color.WHITE, true)
	_name_label.name = "CharacterName"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_name_label)
	_chain = ElementChain.make("", 56)
	_chain.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(_chain)
	_stats = Ui.vbox(8)
	_stats.name = "Stats"
	_stats.mouse_filter = MOUSE_FILTER_IGNORE
	_stats.size_flags_vertical = SIZE_EXPAND_FILL
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_stats)
	_gun = TextureRect.new()
	_gun.name = "Gun"
	_gun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gun.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_gun.custom_minimum_size = GUN_SIZE
	_gun.size_flags_horizontal = SIZE_SHRINK_CENTER
	_gun.mouse_filter = MOUSE_FILTER_PASS
	col.add_child(_gun)
	return p


## Right: the skill's picture, name and "i" over its looping replay.
func _build_skill_panel() -> Control:
	var p := _panel("SkillPanel")
	var col := Ui.vbox(12)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(col)
	var head := Ui.hbox(12)
	head.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(head)
	_skill = SkillButton.make(SKILL_PX)
	_skill.name = "Skill"
	_skill.pressed.connect(_show_skill)
	head.add_child(_skill)
	_skill_name = LobbyUi.text("", 30, Color.WHITE, true)
	_skill_name.name = "SkillName"
	_skill_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_name.size_flags_horizontal = SIZE_EXPAND_FILL
	_skill_name.clip_text = true
	_skill_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_skill_name)
	var info := GlyphIcon.info_button(_show_skill, 46)
	info.size_flags_vertical = SIZE_SHRINK_CENTER
	head.add_child(info)
	var frame := PanelContainer.new()
	frame.name = "DemoFrame"
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	var fb := LobbyUi.box(Color(0.02, 0.03, 0.08, 0.6), 14, 3, Color(1, 1, 1, 0.18), 2)
	frame.add_theme_stylebox_override("panel", fb)
	col.add_child(frame)
	_demo = SkillDemo.new()
	_demo.name = "SkillDemo"
	_demo.custom_minimum_size = Vector2(0, 240)
	frame.add_child(_demo)
	return p


## The skill's popup (its picture, name and the game data's description).
func _show_skill() -> void:
	SkillButton.show_popup(self, _id)


static func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


# ── Character ───────────────────────────────────────────────────────────────

## ◀, the figure, ▶ in one row: the same arrow and gap each side, so the figure is dead centre.
func _build_stage() -> Control:
	_stage = HBoxContainer.new()
	_stage.name = "Stage"
	_stage.add_theme_constant_override("separation", ARROW_GAP)
	_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.mouse_filter = MOUSE_FILTER_STOP
	_stage.size_flags_vertical = SIZE_SHRINK_CENTER # the figure centred on the panels' height
	_stage.gui_input.connect(_on_stage_input)
	_figure_box = Control.new()
	_figure_box.name = "FigureBox"
	_figure_box.mouse_filter = MOUSE_FILTER_IGNORE
	_figure_box.draw.connect(_draw_pedestal)
	_figure = PlayerFigure.make({}, _scale) # the pedestal is the box's: it stays while the figure slides
	_figure.name = "Figure"
	_figure.custom_minimum_size = Vector2.ONE # sized by _set_scale()
	_figure_box.add_child(_figure)
	_set_scale(_scale)
	for side in [-1, 1]:
		var arrow := LobbyUi.round_button("arrow_left" if side < 0 else "arrow_right", ARROW, Color(0.05, 0.08, 0.2, 0.7), 0.5)
		arrow.name = "ArrowLeft" if side < 0 else "ArrowRight"
		arrow.size_flags_vertical = SIZE_SHRINK_CENTER
		arrow.focus_mode = FOCUS_NONE
		arrow.pressed.connect(cycle.bind(side))
		arrow.visible = _ids.size() > 1
		_arrows.append(arrow)
	_stage.add_child(_arrows[0])
	_stage.add_child(_figure_box)
	_stage.add_child(_arrows[1])
	return _stage


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position.x
		elif _drag_from >= 0.0:
			var dx: float = event.position.x - _drag_from
			_drag_from = -1.0
			if absf(dx) >= SWIPE:
				cycle(-1 if dx > 0 else 1) # drag right shows the previous one


func _unhandled_input(event: InputEvent) -> void:
	if _field != null and _field.has_focus():
		return
	if event.is_action_pressed("ui_left"):
		cycle(-1)
	elif event.is_action_pressed("ui_right"):
		cycle(1)


## Shows the starter `delta` steps away (wrapping around), sliding the figure.
func cycle(delta: int) -> void:
	if _ids.size() < 2 or _busy:
		return
	_id = Model.cycle(_ids, _id, delta)
	if not is_inside_tree():
		_render_character()
		return
	var t := _figure.create_tween()
	t.tween_property(_figure, "position:x", -delta * SLIDE_PX, SLIDE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_figure, "modulate:a", 0.0, SLIDE_SEC)
	t.tween_callback(func() -> void:
		_render_character()
		_figure.position.x = delta * SLIDE_PX)
	t.tween_property(_figure, "position:x", 0.0, SLIDE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_figure, "modulate:a", 1.0, SLIDE_SEC)


## The starter shown.
func character_id() -> String:
	return _id


func _render_character() -> void:
	_name_label.text = GameData.character_name(_id)
	_chain.set_element(GameData.character_element(_id))
	var gun := EquipmentModel.worn_gun(null, null, _id) # the starting gun
	_figure.show_look({"character_id": _id, "gun": gun, "aura_level": 0})
	_gun.texture = Art.ui_gun_texture(Art.hug_gun(str(gun["kind"]), str(gun["tier"])))
	_gun.tooltip_text = EquipmentModel.gun_name(str(gun["kind"]))
	var skill := Skills.for_character(_id)
	_skill.skill_id = str(skill.get("id", ""))
	_skill_name.text = str(skill.get("name", ""))
	if _demo.skill_id() != _skill.skill_id:
		_demo.show_skill(_skill.skill_id) # restarts on the new character's skill
	_dots.queue_redraw()
	_render_stats()


## The stat rows of the shown character (none until GET /player/characters is in).
func _render_stats() -> void:
	if _stats == null:
		return
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	for r in CharacterShopModel.stat_rows(PlayerState.characters, _id):
		_stats.add_child(_stat_row(r))


## glyph, bar, number; its label as the tooltip.
func _stat_row(r: Dictionary) -> Control:
	var row := Ui.hbox(10)
	row.name = "Stat_" + str(r["key"])
	row.tooltip_text = str(r["label"])
	row.mouse_filter = MOUSE_FILTER_PASS
	row.add_child(GlyphIcon.make(str(STAT_GLYPHS.get(r["key"], "info")), STAT_GLYPH))
	var bar := Ui.bar(float(r["ratio"]), STAT_BAR)
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", LobbyUi.box(STAT_FILL, STAT_BAR / 2, 0))
	bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.45), STAT_BAR / 2, 0, Color(1, 1, 1, 0.15), 1))
	row.add_child(bar)
	var v := LobbyUi.text(str(r["text"]), 24, Color.WHITE, true)
	v.custom_minimum_size.x = STAT_VALUE_W
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(v)
	return row


func _draw_dots() -> void:
	var at := _ids.find(_id)
	for i in _ids.size():
		var c := Vector2(DOT + i * DOT * 2, _dots.size.y / 2.0)
		var on := i == at
		_dots.draw_circle(c, DOT / 2.0 + (1.5 if on else 0.0), Color(0.04, 0.05, 0.12, 0.8), true, -1.0, true)
		_dots.draw_circle(c, DOT / 2.0 - (1.0 if on else 2.5), DOT_ON if on else DOT_OFF, true, -1.0, true)


# ── Name ────────────────────────────────────────────────────────────────────

## The white rounded field: a blank, the text centred, the dice (both DICE wide).
func _build_field() -> Control:
	_field_panel = PanelContainer.new()
	_field_panel.name = "NameField"
	_field_panel.custom_minimum_size = FIELD
	_field_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	var row := Ui.hbox(8)
	_field_panel.add_child(row)
	var blank := Control.new()
	blank.custom_minimum_size = Vector2(DICE, DICE)
	blank.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(blank)
	_field = LineEdit.new()
	_field.name = "Name"
	_field.max_length = ErrorText.MAX_NAME
	_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_field.size_flags_horizontal = SIZE_EXPAND_FILL
	_field.size_flags_vertical = SIZE_SHRINK_CENTER
	_field.add_theme_font_size_override("font_size", 34)
	_field.add_theme_font_override("font", LobbyUi.bold())
	_field.add_theme_color_override("font_color", FIELD_TEXT)
	_field.add_theme_color_override("font_uneditable_color", Color(FIELD_TEXT, 0.75))
	_field.add_theme_color_override("caret_color", FIELD_TEXT)
	_field.add_theme_color_override("selection_color", Color(1.0, 0.8, 0.22, 0.5))
	for state in ["normal", "focus", "read_only"]:
		_field.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_field.select_all_on_focus = true
	_field.text_changed.connect(func(_t: String) -> void:
		if not _rolling:
			_server_hint = ""
		_render_name())
	_field.text_submitted.connect(func(_t: String) -> void: confirm())
	row.add_child(_field)
	_dice = Button.new()
	_dice.name = "Dice"
	_dice.custom_minimum_size = Vector2(DICE, DICE)
	_dice.size_flags_vertical = SIZE_SHRINK_CENTER
	_dice.focus_mode = FOCUS_NONE
	_dice.flat = true
	_dice.tooltip_text = "Tên ngẫu nhiên"
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_dice.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_dice_glyph = GlyphIcon.make("dice", DICE)
	_dice_glyph.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_dice_glyph.pivot_offset = Vector2(DICE, DICE) / 2.0
	_dice.add_child(_dice_glyph)
	_dice.pressed.connect(roll)
	row.add_child(_dice)
	return _field_panel


## The field's look and the start button for the name typed: red outline and the reason when it
## breaks the rule or the server refused it.
func _render_name() -> void:
	var problem := "" if _rolling else Model.name_problem(_field.text)
	var hint := problem if problem != "" else _server_hint
	_hint.text = hint
	_hint_box.visible = hint != ""
	var bad := hint != ""
	var box := LobbyUi.box(FIELD_BG, int(FIELD.y / 2), 10, BAD if bad else FIELD_EDGE, 4)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 8
	box.shadow_offset = Vector2(0, 4)
	_field_panel.add_theme_stylebox_override("panel", box)
	_start.disabled = _busy or _rolling or problem != ""
	_dice.disabled = _busy or _rolling
	_field.editable = not (_busy or _rolling)
	for a in _arrows:
		a.disabled = _busy


## The name in the field (trimmed).
func name_text() -> String:
	return _field.text.strip_edges()


## The dice: tumbles while the field scrambles, then the server's suggestion (the old text back
## when none came).
func roll() -> void:
	if _rolling or _busy:
		return
	_rolling = true
	_server_hint = ""
	var before := _field.text
	_spin()
	_render_name()
	var res: Dictionary = await _api().get_json("/player/name-suggestion")
	if not is_inside_tree():
		return
	while _spin_left > 0.0:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_rolling = false
	var suggested := Model.suggestion(res)
	_field.text = suggested if suggested != "" else before
	_field.caret_column = _field.text.length()
	if suggested == "" and int(res.get("status", 0)) == 0:
		_server_hint = ErrorText.OFFLINE
	_render_name()


## The dice turns twice and bounces (ROLL_SEC); the field's letters scramble meanwhile.
func _spin() -> void:
	_spin_left = ROLL_SEC
	_scramble_left = 0.0
	if not is_inside_tree():
		_spin_left = 0.0
		return
	_dice_glyph.rotation = 0.0
	var t := _dice_glyph.create_tween()
	t.tween_property(_dice_glyph, "rotation", TAU * 2.0, ROLL_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var b := _dice_glyph.create_tween()
	b.tween_property(_dice_glyph, "scale", Vector2(1.35, 1.35), ROLL_SEC * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	b.tween_property(_dice_glyph, "scale", Vector2.ONE, ROLL_SEC * 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var h := _dice_glyph.create_tween()
	h.tween_property(_dice_glyph, "position:y", -18.0, ROLL_SEC * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	h.tween_property(_dice_glyph, "position:y", 0.0, ROLL_SEC * 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _spin_left > 0.0:
		_spin_left = maxf(0.0, _spin_left - delta)
	if not _rolling:
		return
	_scramble_left -= delta
	if _scramble_left <= 0.0:
		_scramble_left = SCRAMBLE_SEC
		_field.text = Model.scramble(_rng.randi_range(7, 11), _rng)


## The field shakes side to side (a refused name).
func shake() -> void:
	if not is_inside_tree():
		return
	if _shake != null and _shake.is_valid():
		_shake.kill()
	else:
		_shake_x = _field_panel.position.x
	_shake = _field_panel.create_tween()
	for dx in [16.0, -14.0, 10.0, -6.0, 0.0]:
		_shake.tween_property(_field_panel, "position:x", _shake_x + dx, 0.05)


# ── Start ───────────────────────────────────────────────────────────────────

## "Bắt đầu": sends the starter and the name; Home once the server took them.
func confirm() -> void:
	if _busy or _rolling:
		return
	var problem := Model.name_problem(_field.text)
	if problem != "":
		_render_name()
		shake()
		return
	_set_busy(true)
	var res: Dictionary = await _api().post_json("/player/onboarding", {"characterId": _id, "displayName": name_text()})
	if not is_inside_tree():
		return
	if res.get("ok", false) and res.get("data") is Dictionary:
		finish(res["data"])
		return
	_set_busy(false)
	var e := Model.error(res)
	if e["action"] == Model.GO_LOBBY:
		_go_home()
		return
	_server_hint = e["text"]
	_render_name()
	if e["action"] == Model.SHAKE_NAME:
		shake()


## The server took the starter and the name: its profile applied, the starter on the lobby stage.
func finish(profile: Dictionary) -> void:
	PlayerState.apply(profile)
	var current = profile.get("currentCharacterId")
	var choice := LoadoutModel.new()
	choice.restore(settings_path)
	choice.select_character(str(current) if current is String and current != "" else _id)
	choice.remember(settings_path)
	_go_home()


func _go_home() -> void:
	PlayerState.characters_stale = true # the starter was granted
	Router.go(Router.HOME)


func _set_busy(on: bool) -> void:
	_busy = on
	_render_name()
