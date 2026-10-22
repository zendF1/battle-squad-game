extends Control
## Match HUD, in the lobby look (ui/lobby_ui.gd: translucent navy panels, rounded buttons, gold
## for the armed slot and for my turn), each part pinned to its own corner so it adapts to wide
## phones (stretch aspect "expand"; the viewport is at least 1600 × 900):
## - top left: a small round Thoát (X) in the corner and the chat beside it: only its lines, plain
##   text with an outline and a shadow over the sky (no box, no input: match chat is not there
##   yet), the newest last, the older ones fading (add_chat_line());
## - top centre: the turn timer badge and the wind (strength bar from the middle) side by side;
## - top right: whose turn it is: only that player's lobby full-body figure (ui/character_view.gd,
##   its weapon's +14 / +16 back aura: the match's aura lives here, not on the small sprites), no
##   card, name or title (the title plates are over each sprite's name); it slides and fades in on
##   each turn change (mine, opponents', bots: no aura);
## - the move buttons on the screen's left and right edges, vertically centred (◀ left, ▶
##   right; move_layout()); under the left one the move energy (Thể lực, a short bar as wide as
##   the button) and over it a notice while moving is blocked ("Bị cầm chân", set_move_notice());
##   between the chat (top left) and the skill slot (bottom right), clear of both;
## - bottom centre: the aim readout over the items in hand, a row of slots (icon + count);
## - bottom right: the character's skill as a round slot (its icon, the energy as a ring, off
##   until charged).
## There is no end-turn button (a turn ends with a shot or the clock) and no weapon button (the
## normal shot is the default). A special (the skill or a shot item) once tapped stays armed for
## the turn (match/action_lock.gd: the other shot slots go off). A turn change also shows a short
## centre banner ("Lượt của bạn" / "Lượt của X"); a lost turn (stun / freeze) shows a longer one
## under it ("Choáng — mất lượt", announce_skip()). The small result panel (show_result()) is
## only for a cancelled match and a lost connection: a match that ended shows the full-screen
## result (match/result_screen.gd).

signal move_pressed(dir: int)
signal move_released
signal skill_pressed
signal item_pressed(item_id: String)
signal leave_pressed

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const CharacterView := preload("res://ui/character_view.gd")
const FakeChat := preload("res://screens/home/fake_chat.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const SkillGlyphs := preload("res://match/views/skill_glyphs.gd")

const NAVY := Color(0.06, 0.09, 0.22, 0.78)
const MODE_BG := Color(0.13, 0.2, 0.42, 0.9)
const ENEMY_RED := Color(1.0, 0.42, 0.38)
const RING_CHARGING := Color(0.45, 0.85, 1.0)
const LOW_TIME := 5
const MARGIN := 24
const MAP_TOAST_SEC := 2.6 # the map name's toast at the match start stays this long
const LEAVE_SIZE := 64
const CHAT_WIDTH := 440 # the chat lines' width (a longer line wraps)
const CHAT_LINES := 5 # lines kept, the newest last
const CHAT_FADE := 0.17 # each older line this much more transparent
const CHAT_MIN_ALPHA := 0.35
const PORTRAIT_ART := Vector2(190, 200) # the turn portrait's figure box
const SKILL_SIZE := 132
const ITEM_SIZE := 96
const MOVE_SIZE := 110
const ENERGY_GAP := 10 # between the left move button and the energy under it
const NOTICE_GAP := 8 # between the notice and the left move button over which it sits
const PORTRAIT_SLIDE := 70.0 # px the portrait slides in from the right
## The chat's line until match chat exists.
const CHAT_LINE := {"channel": "Hệ thống", "name": "", "text": "Trận đấu bắt đầu!"}

var _timer: Label
var _timer_panel: PanelContainer
var _wind: Label
var _wind_arrow: TextureRect
var _wind_bar: Control
var _aim: Label
var _aim_panel: PanelContainer
var _energy: ProgressBar
var _move_notice: Label
var _skip_banner: PanelContainer
var _skip_label: Label
var _skip_tween: Tween
var _left: Button
var _right: Button
var _skill: Button
var _skill_ring: Control
var _skill_name: Label
var _skill_box: VBoxContainer
var _items: HBoxContainer
var _item_buttons: Array[Button] = [] # reused; one per item left in hand
var _portrait: Control
var _portrait_art: CharacterView
var _portrait_tween: Tween
var _portrait_key := ""
var _chat: VBoxContainer
var _result: Control
var _result_title: Label
var _result_detail: Label
var _banner: PanelContainer
var _map_toast: PanelContainer
var _map_label: Label
var _banner_label: Label
var _banner_tween: Tween
var _turn_text := ""
var _time_left := 0.0
var _timer_running := true
var _wind_dir := 0
var _wind_power := 0.0
var _my_turn := false
var _low := false
var _skill_energy := 0.0 # 0..1 of the ring
var _skill_ready := false
var _skill_armed := false
var _skill_id := "" # the slot shows its picture (SkillGlyphs) instead of the generic lightning icon


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = LobbyUi.theme()
	_build_top_left()
	_build_top_centre()
	_build_portrait()
	_build_move()
	_build_bottom_centre()
	_build_skill()
	_set_turn_style(false)
	_build_banner()
	_build_result_panel()


func _process(delta: float) -> void:
	if _timer_running:
		_time_left = maxf(0.0, _time_left - delta)
	_timer.text = "%d" % ceili(_time_left)
	var low := _timer_running and ceili(_time_left) <= LOW_TIME
	if low != _low:
		_low = low
		_timer.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if low else Color.WHITE)
	_aim_panel.visible = _aim.text != ""


# ── Layout ──────────────────────────────────────────────────────────────────

## Adds c pinned at (ax, ay) of the screen (0 left / top, 1 right / bottom, 0.5 centred),
## growing away from that corner, moved by `off` px.
func _pin(c: Control, ax: float, ay: float, off: Vector2) -> Control:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.grow_horizontal = GROW_DIRECTION_END if ax == 0.0 else (GROW_DIRECTION_BEGIN if ax == 1.0 else GROW_DIRECTION_BOTH)
	c.grow_vertical = GROW_DIRECTION_END if ay == 0.0 else (GROW_DIRECTION_BEGIN if ay == 1.0 else GROW_DIRECTION_BOTH)
	c.offset_left = off.x
	c.offset_right = off.x
	c.offset_top = off.y
	c.offset_bottom = off.y
	add_child(c)
	return c


## Top left: the round Thoát in the corner, the chat lines beside it.
func _build_top_left() -> void:
	var row: HBoxContainer = _pin(_ignore(Ui.hbox(14)), 0, 0, Vector2(MARGIN, MARGIN))
	row.name = "TopLeft"
	var leave := LobbyUi.round_button("close", LEAVE_SIZE, NAVY, 0.42)
	leave.name = "Leave"
	leave.tooltip_text = "Thoát"
	leave.size_flags_vertical = SIZE_SHRINK_BEGIN
	leave.pressed.connect(leave_pressed.emit)
	row.add_child(leave)
	_chat = _ignore(Ui.vbox(2))
	_chat.name = "ChatLines"
	_chat.custom_minimum_size.x = CHAT_WIDTH
	_chat.size_flags_vertical = SIZE_SHRINK_BEGIN
	row.add_child(_chat)
	add_chat_line(CHAT_LINE)


## Adds a chat line (FakeChat line: {channel, name, text}) under the others: plain text, outlined
## and shadowed over the sky; past CHAT_LINES the oldest goes, the older ones fade.
func add_chat_line(line: Dictionary) -> void:
	var l: RichTextLabel = _ignore(RichTextLabel.new())
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = CHAT_WIDTH
	l.add_theme_font_size_override("normal_font_size", 20)
	l.add_theme_color_override("default_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.1, 0.9))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 7)
	l.text = FakeChat.bbcode(line)
	_chat.add_child(l)
	while _chat.get_child_count() > CHAT_LINES:
		var old := _chat.get_child(0)
		_chat.remove_child(old)
		old.free()
	var n := _chat.get_child_count()
	for i in n:
		(_chat.get_child(i) as CanvasItem).modulate.a = maxf(CHAT_MIN_ALPHA, 1.0 - CHAT_FADE * (n - 1 - i))


## The chat lines shown, oldest first: [{text (no BBCode), alpha}].
func chat_lines() -> Array:
	var out: Array = []
	for l in _chat.get_children():
		out.append({"text": (l as RichTextLabel).get_parsed_text(), "alpha": (l as CanvasItem).modulate.a})
	return out


## Top centre: the timer badge and the wind side by side.
func _build_top_centre() -> void:
	var row: HBoxContainer = _pin(_ignore(Ui.hbox(12)), 0.5, 0, Vector2(0, MARGIN))
	row.name = "TopCentre"
	_timer_panel = _ignore(PanelContainer.new())
	_timer_panel.custom_minimum_size = Vector2(84, 84)
	row.add_child(_timer_panel)
	_timer = LobbyUi.text("", 40, Color.WHITE, true)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_panel.add_child(_timer)
	var wind_panel: PanelContainer = _ignore(LobbyUi.panel(12, 18, NAVY))
	wind_panel.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(wind_panel)
	var wind_col := Ui.vbox(4)
	wind_col.mouse_filter = MOUSE_FILTER_IGNORE
	wind_panel.add_child(wind_col)
	var wind_row := Ui.hbox(8)
	wind_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wind_row.mouse_filter = MOUSE_FILTER_IGNORE
	wind_col.add_child(wind_row)
	wind_row.add_child(LobbyUi.text("Gió", 24, Color.WHITE, true))
	_wind_arrow = LobbyUi.icon("arrow_right", 26)
	wind_row.add_child(_wind_arrow)
	_wind = LobbyUi.text("", 24, Color.WHITE, true)
	wind_row.add_child(_wind)
	_wind_bar = _ignore(Control.new())
	_wind_bar.custom_minimum_size = Vector2(200, 14)
	_wind_bar.draw.connect(_draw_wind_bar)
	wind_col.add_child(_wind_bar)


## Top right: the turn portrait, only the figure (and its back aura): no card, no name.
func _build_portrait() -> void:
	_portrait = _pin(_ignore(Control.new()), 1, 0, Vector2(-MARGIN, MARGIN))
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = PORTRAIT_ART
	_portrait_art = CharacterView.new()
	_portrait_art.name = "Figure"
	_portrait_art.size = PORTRAIT_ART
	_portrait_art.idle = true
	_portrait_art.hands_free = true
	_portrait_art.back_aura = true
	_portrait_art.aura_level = 0
	_portrait.add_child(_portrait_art)
	_portrait.visible = false


## The move buttons on the left and right edges, vertically centred; the energy under the left
## one, the notice over it.
func _build_move() -> void:
	var col: VBoxContainer = _pin(_ignore(Ui.vbox(ENERGY_GAP)), 0, 0.5, Vector2(MARGIN, -MOVE_SIZE / 2.0))
	col.name = "MoveLeft"
	col.grow_vertical = GROW_DIRECTION_END # the button's centre on the screen's middle
	col.offset_bottom = col.offset_top
	_left = _hold_button("arrow_left", -1)
	_left.name = "MoveLeftButton"
	_left.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(_left)
	var energy_panel: PanelContainer = _ignore(LobbyUi.panel(8, 10, NAVY))
	energy_panel.name = "Energy"
	energy_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(energy_panel)
	var energy_col := Ui.vbox(4)
	energy_col.mouse_filter = MOUSE_FILTER_IGNORE
	energy_panel.add_child(energy_col)
	var label := LobbyUi.text("Thể lực", 18, Color(1, 1, 1, 0.85), true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_col.add_child(label)
	_energy = ProgressBar.new()
	_energy.max_value = 100
	_energy.show_percentage = false
	_energy.custom_minimum_size = Vector2(MOVE_SIZE, 16)
	_energy.mouse_filter = MOUSE_FILTER_IGNORE
	_energy.add_theme_stylebox_override("background", LobbyUi.box(Color(0.02, 0.03, 0.1, 0.85), 8, 0, Color(1, 1, 1, 0.15), 2))
	_energy.add_theme_stylebox_override("fill", LobbyUi.box(Color(0.35, 0.85, 0.45), 8, 0))
	energy_col.add_child(_energy)
	_move_notice = _pin(LobbyUi.text("", 24, Color(0.75, 1.0, 0.55), true), 0, 0.5, Vector2(MARGIN, -MOVE_SIZE / 2.0 - NOTICE_GAP))
	_move_notice.name = "MoveNotice"
	_move_notice.grow_vertical = GROW_DIRECTION_BEGIN # sits on the button
	_move_notice.offset_top = _move_notice.offset_bottom
	_move_notice.mouse_filter = MOUSE_FILTER_IGNORE
	_move_notice.visible = false
	_right = _hold_button("arrow_right", 1)
	_right.name = "MoveRightButton"
	_pin(_right, 1, 0.5, Vector2(-MARGIN, 0))


## Where the move parts are, in screen px (after a layout pass): {left, right, energy, notice}
## as Rect2s.
func move_layout() -> Dictionary:
	return {"left": _left.get_global_rect(), "right": _right.get_global_rect(),
		"energy": _energy.get_parent().get_parent().get_global_rect(), "notice": _move_notice.get_global_rect()}


## The screen rects the off-screen markers keep off (match/views/offscreen_markers.gd): the move
## buttons and the energy, the skill slot, the item row and the turn portrait (those shown).
func marker_avoid() -> Array:
	var out: Array = [_left.get_global_rect(), _right.get_global_rect(), _energy.get_parent().get_parent().get_global_rect()]
	for c in [_skill_box, _items, _portrait]:
		if c.is_visible_in_tree() and c.size.x > 0.0:
			out.append(c.get_global_rect())
	return out


## Bottom centre: the aim readout over the item slots.
func _build_bottom_centre() -> void:
	var col: VBoxContainer = _pin(_ignore(Ui.vbox(10)), 0.5, 1, Vector2(0, -MARGIN))
	col.name = "BottomCentre"
	col.alignment = BoxContainer.ALIGNMENT_END
	_aim_panel = _ignore(LobbyUi.panel(10, 18, NAVY))
	_aim_panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(_aim_panel)
	_aim = LobbyUi.text("", 26, Color.WHITE, true)
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_panel.add_child(_aim)
	_items = _ignore(Ui.hbox(14))
	_items.name = "Items"
	_items.alignment = BoxContainer.ALIGNMENT_CENTER
	_items.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(_items)


## Bottom right: the round skill slot with its energy ring, its name under it.
func _build_skill() -> void:
	_skill_box = _pin(_ignore(Ui.vbox(4)), 1, 1, Vector2(-MARGIN, -MARGIN))
	_skill_box.name = "Skill"
	_skill_box.visible = false
	_skill = Button.new()
	_skill.name = "SkillSlot"
	_skill.custom_minimum_size = Vector2(SKILL_SIZE, SKILL_SIZE)
	_skill.size_flags_horizontal = SIZE_SHRINK_CENTER
	_skill.toggle_mode = true
	_skill.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	LobbyUi.set_icon(_skill, "skill", int(SKILL_SIZE * 0.46))
	_slot_style(_skill, SKILL_SIZE / 2)
	_skill.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.4))
	_skill.pressed.connect(skill_pressed.emit)
	_skill_box.add_child(_skill)
	_skill_ring = _ignore(Control.new())
	_skill_ring.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_skill_ring.draw.connect(_draw_skill_ring)
	_skill.add_child(_skill_ring)
	_skill_name = LobbyUi.text("", 20, Color.WHITE, true)
	_skill_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_box.add_child(_skill_name)


# ── State ───────────────────────────────────────────────────────────────────

## Whose turn: the banner when it changes, and the top-right portrait of `player` (a match player
## dict: playerId, characterId, isBot, weaponUpgradeLevel) sliding in when the player changes.
## _ally: my team (no longer shown: the portrait has no name).
func set_turn(mine: bool, player_name: String, player: Dictionary = {}, _ally: bool = true) -> void:
	var text := "Lượt của bạn" if mine else "Lượt của %s" % player_name
	var changed := text != _turn_text
	_turn_text = text
	_my_turn = mine
	_set_turn_style(mine)
	if changed:
		_announce(text, mine)
	_set_portrait(player, player_name)


## The turn text ("Lượt của bạn" / "Lượt của X") the banner shows.
func turn_text() -> String:
	return _turn_text


## The weapon upgrade level a match player's portrait shows the aura of: weaponUpgradeLevel (0
## for a bot, for none and from an older server).
static func portrait_level(player: Dictionary) -> int:
	return 0 if bool(player.get("isBot", false)) else EquipmentModel.player_weapon_level(player)


func _set_portrait(player: Dictionary, player_name: String) -> void:
	if player.is_empty():
		_portrait.visible = false
		_portrait_key = ""
		return
	var id := Art.known_character(str(player.get("characterId", "")))
	var key := "%s|%s" % [player.get("playerId", player_name), id]
	_portrait_art.character_id = id
	_portrait_art.aura_level = portrait_level(player)
	_portrait.visible = true
	if key == _portrait_key:
		return
	_portrait_key = key
	# Slides in from the right and fades in (the anchors keep it in the corner).
	if _portrait_tween:
		_portrait_tween.kill()
	_portrait.modulate.a = 0.0
	var right := -float(MARGIN)
	_portrait.offset_left = right + PORTRAIT_SLIDE
	_portrait.offset_right = right + PORTRAIT_SLIDE
	if not is_inside_tree():
		_portrait.modulate.a = 1.0
		_portrait.offset_left = right
		_portrait.offset_right = right
		return
	_portrait_tween = create_tween().set_parallel()
	_portrait_tween.tween_property(_portrait, "modulate:a", 1.0, 0.25)
	_portrait_tween.tween_property(_portrait, "offset_left", right, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_portrait_tween.tween_property(_portrait, "offset_right", right, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The turn portrait: {visible, character, aura ("red" / "purple" / ""), node (the portrait
## Control: only the figure in it)}.
func portrait() -> Dictionary:
	return {"visible": _portrait.visible, "character": _portrait_art.character_id, "aura": _portrait_art.aura().aura(),
		"node": _portrait}


## Sets the turn clock from a server value and resumes the local countdown.
func set_time(seconds: int) -> void:
	_time_left = seconds
	_timer_running = true


## Freezes the countdown. The server stops TurnTimerTick while a shot resolves, and the next
## set_time() (TurnTimerTick or TurnStarted) resumes it.
func pause_timer() -> void:
	_timer_running = false


## No wind (power 0, e.g. while a wind_stopper lasts) reads "Gió: tắt".
func set_wind(direction: int, power: float) -> void:
	_wind_dir = direction
	_wind_power = power
	_wind_bar.queue_redraw()
	_wind_arrow.visible = power > 0.0 and direction != 0
	if power <= 0.0:
		_wind.text = "tắt"
		return
	_wind_arrow.texture = Art.icon("arrow_right" if direction > 0 else "arrow_left")
	_wind.text = "%.1f" % power


## value of max_value (the player's maxMoveEnergy: it differs per character); max_value <= 0
## keeps the current maximum.
func set_energy(value: int, max_value: int = 0) -> void:
	if max_value > 0:
		_energy.max_value = max_value
	_energy.value = value


func set_aim(angle: float, power: float) -> void:
	_aim.text = "%d°  lực %d" % [roundi(angle), roundi(power)]


func set_column(x: float) -> void:
	_aim.text = "Không kích x=%d" % roundi(x)


## The notice over the move buttons ("" hides it), e.g. "Bị cầm chân" while rooted.
func set_move_notice(text: String) -> void:
	_move_notice.text = text
	_move_notice.visible = text != ""


func move_notice() -> String:
	return _move_notice.text if _move_notice.visible else ""


## A lost turn: a red banner under the turn banner, held for `hold` s ("" hides it).
func announce_skip(text: String, hold: float = 1.8) -> void:
	_skip_label.text = text
	if _skip_tween:
		_skip_tween.kill()
	if text == "":
		_skip_banner.modulate.a = 0.0
		return
	_skip_banner.modulate.a = 1.0
	if not is_inside_tree():
		return
	_skip_tween = create_tween()
	_skip_tween.tween_interval(hold)
	_skip_tween.tween_property(_skip_banner, "modulate:a", 0.0, 0.4)


func skip_text() -> String:
	return _skip_label.text if _skip_banner.modulate.a > 0.0 else ""


func set_controls_enabled(enabled: bool) -> void:
	_left.disabled = not enabled
	_right.disabled = not enabled
	if not enabled:
		_aim.text = ""


## The skill slot and the item slots. skill: Skills.for_character() ({} hides the slot: an
## unknown character); energy 0..100 fills its ring; skill_enabled: it can be tapped. armed:
## "weapon", "skill" or the armed item id (shown gold). items: [{"id", "count", "enabled",
## "name"}], the items left.
func set_actions(skill: Dictionary, energy: int, skill_enabled: bool, armed: String, items: Array = []) -> void:
	_skill_box.visible = not skill.is_empty()
	_skill_name.text = str(skill.get("name", ""))
	_skill.tooltip_text = _skill_name.text
	var id := str(skill.get("id", ""))
	if id != _skill_id:
		_skill_id = id
		if SkillGlyphs.has(id):
			_skill.icon = null
		else:
			LobbyUi.set_icon(_skill, "skill", int(SKILL_SIZE * 0.46))
	_skill_energy = clampf(energy / 100.0, 0.0, 1.0)
	_skill_ready = energy >= 100
	_skill_armed = armed == "skill"
	_skill.disabled = not skill_enabled
	_skill.set_pressed_no_signal(_skill_armed)
	_skill_name.add_theme_color_override("font_color", LobbyUi.GOLD if _skill_ready else Color(1, 1, 1, 0.6))
	_skill_ring.queue_redraw()
	while _item_buttons.size() < items.size():
		_item_buttons.append(_item_slot())
	for i in _item_buttons.size():
		var b := _item_buttons[i]
		b.visible = i < items.size()
		if not b.visible:
			continue
		var it: Dictionary = items[i]
		if b.get_meta("item_id", "") != it["id"]:
			b.icon = Art.item_icon(str(it["id"]))
		b.tooltip_text = str(it.get("name", it["id"]))
		b.set_meta("item_id", it["id"])
		(b.get_node("Count") as Label).text = "x%d" % int(it.get("count", 1))
		b.disabled = not bool(it["enabled"])
		b.set_pressed_no_signal(armed == it["id"])


## The slots shown: {skill: {visible, disabled, armed, ring (0..1), name}, items: [{id, count,
## disabled, armed}]}.
func slots() -> Dictionary:
	var items: Array = []
	for b in _item_buttons:
		if b.visible:
			items.append({"id": str(b.get_meta("item_id", "")), "count": (b.get_node("Count") as Label).text,
				"disabled": b.disabled, "armed": b.button_pressed})
	return {"skill": {"visible": _skill_box.visible, "disabled": _skill.disabled, "armed": _skill.button_pressed,
		"ring": _skill_energy, "name": _skill_name.text, "picture": _skill_id if SkillGlyphs.has(_skill_id) else ""}, "items": items}


func show_result(title: String, detail: String) -> void:
	_result_title.text = title
	_result_detail.text = detail
	_result.visible = true


# ── Widgets ─────────────────────────────────────────────────────────────────

func _hold_button(icon_name: String, dir: int) -> Button:
	var b := LobbyUi.round_button(icon_name, MOVE_SIZE, Color(0.2, 0.34, 0.66, 0.9), 0.42)
	b.add_theme_stylebox_override("disabled", LobbyUi.box(Color(0.12, 0.15, 0.3, 0.55), MOVE_SIZE / 2, 0, Color(1, 1, 1, 0.25), 3))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.button_down.connect(move_pressed.emit.bind(dir))
	b.button_up.connect(move_released.emit)
	return b


## A slot's looks: navy normally, gold while armed, dim when off.
func _slot_style(b: Button, radius: int) -> void:
	LobbyUi.style_button(b, MODE_BG, radius, 6, Color(1, 1, 1, 0.3), 3)
	var gold := LobbyUi.box(LobbyUi.GOLD, radius, 6, LobbyUi.GOLD_DARK, 4)
	b.add_theme_stylebox_override("pressed", gold)
	var gold_hover: StyleBoxFlat = gold.duplicate()
	gold_hover.bg_color = LobbyUi.GOLD.lightened(0.12)
	b.add_theme_stylebox_override("hover_pressed", gold_hover)
	b.add_theme_stylebox_override("disabled", LobbyUi.box(Color(0.1, 0.13, 0.26, 0.6), radius, 6, Color(1, 1, 1, 0.1), 3))


## An item slot: its icon, the count in the corner; toggled to show the armed one.
func _item_slot() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(ITEM_SIZE, ITEM_SIZE)
	b.toggle_mode = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(ITEM_SIZE * 0.62))
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_slot_style(b, 20)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))
	var count := LobbyUi.text("", 20, Color.WHITE, true)
	count.name = "Count"
	count.mouse_filter = MOUSE_FILTER_IGNORE
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	count.offset_right = -8
	count.offset_bottom = -4
	b.add_child(count)
	b.pressed.connect(func() -> void: item_pressed.emit(str(b.get_meta("item_id", ""))))
	_items.add_child(b)
	return b


## The skill's energy as a ring round the slot: the track, the charge clockwise from the top
## (light blue while charging, gold when full, white while armed).
func _draw_skill_ring() -> void:
	var c := _skill_ring.size / 2.0
	var r := minf(c.x, c.y) - 6.0
	_skill_ring.draw_arc(c, r, 0.0, TAU, 64, Color(0.02, 0.03, 0.1, 0.8), 8.0, true)
	if SkillGlyphs.has(_skill_id): # the skill's own picture in the slot, dimmed while it can't be used
		_skill_ring.modulate = Color(1, 1, 1, 0.45) if _skill.disabled and not _skill_ready else Color.WHITE
		SkillGlyphs.draw(_skill_ring, _skill_id, c, SKILL_SIZE * 0.5)
	if _skill_energy <= 0.0:
		return
	var col := Color.WHITE if _skill_armed else (LobbyUi.GOLD if _skill_ready else RING_CHARGING)
	var from := -PI / 2.0
	_skill_ring.draw_arc(c, r, from, from + TAU * _skill_energy, maxi(8, int(64 * _skill_energy)), col, 7.0, true)


func _set_turn_style(mine: bool) -> void:
	var badge := LobbyUi.box(NAVY, 42, 0, LobbyUi.GOLD if mine else Color(1, 1, 1, 0.3), 4)
	_timer_panel.add_theme_stylebox_override("panel", badge)


## Wind strength (power up to about 5) as a bar growing from the centre the way it blows.
func _draw_wind_bar() -> void:
	var s := _wind_bar.size
	var back := Rect2(Vector2.ZERO, s)
	_wind_bar.draw_style_box(LobbyUi.box(Color(0.02, 0.03, 0.1, 0.8), 7, 0), back)
	var mid := s.x / 2
	_wind_bar.draw_rect(Rect2(mid - 1, 1, 2, s.y - 2), Color(1, 1, 1, 0.5))
	if _wind_power <= 0.0 or _wind_dir == 0:
		return
	var bar_len := clampf(_wind_power / 5.0, 0.05, 1.0) * (mid - 3)
	var x := mid if _wind_dir > 0 else mid - bar_len
	_wind_bar.draw_rect(Rect2(x, 3, bar_len, s.y - 6), Color(0.45, 0.85, 1.0))


func _build_banner() -> void:
	var center := CenterContainer.new() # upper half: the players stand lower
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.anchor_bottom = 0.55
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	_banner = _ignore(PanelContainer.new())
	_banner.modulate.a = 0.0
	center.add_child(_banner)
	_banner_label = LobbyUi.text("", 56, Color.WHITE, true)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)
	var skip_center := CenterContainer.new() # under the turn banner
	skip_center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	skip_center.anchor_top = 0.3
	skip_center.anchor_bottom = 0.72
	skip_center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(skip_center)
	_skip_banner = _ignore(PanelContainer.new())
	_skip_banner.name = "SkipBanner"
	_skip_banner.modulate.a = 0.0
	var box := LobbyUi.box(Color(0.32, 0.05, 0.08, 0.9), 26, 14, Color(1.0, 0.5, 0.4, 0.9), 3)
	box.content_margin_left = 44
	box.content_margin_right = 44
	_skip_banner.add_theme_stylebox_override("panel", box)
	skip_center.add_child(_skip_banner)
	_skip_label = LobbyUi.text("", 40, Color(1.0, 0.92, 0.85), true)
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_banner.add_child(_skip_label)


## The centre banner: pops in, holds, fades out.
func _announce(text: String, mine: bool) -> void:
	if _banner == null:
		return
	_banner_label.text = text
	var box := LobbyUi.box(LobbyUi.GOLD if mine else Color(0.05, 0.07, 0.18, 0.85), 30, 22,
		LobbyUi.GOLD_DARK if mine else Color(ENEMY_RED, 0.8), 4)
	box.content_margin_left = 60
	box.content_margin_right = 60
	if mine:
		box.border_width_bottom = 8
	_banner.add_theme_stylebox_override("panel", box)
	_banner_label.add_theme_color_override("font_color", LobbyUi.TEXT_DARK if mine else Color.WHITE)
	_banner_label.add_theme_constant_override("outline_size", 0 if mine else 9)
	if _banner_tween:
		_banner_tween.kill()
	if not is_inside_tree():
		return
	_banner.pivot_offset = _banner.size / 2
	_banner.scale = Vector2(0.7, 0.7)
	_banner.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(0.9)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.35)


## The map's name at the match start, under the timer: "BẢN ĐỒ" over the name, sliding in,
## held MAP_TOAST_SEC, fading out.
func announce_map(map_name: String) -> void:
	if _map_toast != null:
		_map_toast.queue_free()
	_map_toast = _ignore(PanelContainer.new())
	_map_toast.name = "MapToast"
	var box := LobbyUi.box(Color(0.05, 0.07, 0.18, 0.82), 20, 6, Color(LobbyUi.GOLD, 0.85), 3)
	box.content_margin_left = 34
	box.content_margin_right = 34
	_map_toast.add_theme_stylebox_override("panel", box)
	var col := Ui.vbox(0)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	_map_toast.add_child(col)
	var cap := LobbyUi.text("BẢN ĐỒ", 15, Color(0.75, 0.88, 1.0), true)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	_map_label = LobbyUi.text(map_name, 30, LobbyUi.GOLD, true)
	_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_map_label)
	_pin(_map_toast, 0.5, 0, Vector2(0, MARGIN + 96))
	if not is_inside_tree():
		return
	_map_toast.modulate.a = 0.0
	var t := _map_toast.create_tween()
	t.tween_property(_map_toast, "modulate:a", 1.0, 0.3)
	t.tween_interval(MAP_TOAST_SEC)
	t.tween_property(_map_toast, "modulate:a", 0.0, 0.5)
	t.tween_callback(_map_toast.queue_free)


## The map toast's text ("" none shown).
func map_toast() -> String:
	return _map_label.text if _map_toast != null and is_instance_valid(_map_toast) and is_instance_valid(_map_label) else ""


func _build_result_panel() -> void:
	_result = _ignore(Control.new())
	_result.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_result.visible = false
	add_child(_result)
	var dim: ColorRect = _ignore(ColorRect.new())
	dim.color = Color(0.02, 0.03, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_result.add_child(dim)
	var center: CenterContainer = _ignore(CenterContainer.new())
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_result.add_child(center)
	var panel := LobbyUi.panel(40, 28, Color(0.06, 0.09, 0.22, 0.92))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	panel.add_child(col)
	_result_title = LobbyUi.text("", 60, LobbyUi.GOLD, true)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_title)
	_result_detail = LobbyUi.text("", 28)
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_detail)
	var back := LobbyUi.start_button("Về sảnh")
	back.custom_minimum_size = Vector2(360, 90)
	back.pressed.connect(leave_pressed.emit)
	col.add_child(back)


static func _ignore(c):
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c
