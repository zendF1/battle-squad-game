extends Control
## "Bang hội" (a Home page, the lobby's crest button; contract guilds.md): two tabs with a
## picture and a short name, Bang hội and Xếp hạng.
## Bang hội, not in a guild: two equal panels mirrored round the centre: on the left "Lập bang
## hội" (the crest, the name field with the game data's name rule, the cost as its currency icon
## and amount from createCost, "Lập bang"; not enough gems / coins opens the Shop), on the right
## the invitations received (the guild's crest and name, ✓ to join, ✕ to decline).
## Bang hội, in one: on the left the guild's card (crest, name, level, the EXP bar inside the level,
## the guild skills from the game data: a heart / shield with "+5%", the ones not reached greyed
## with a lock and their level), the daily shared quest (crossed swords in a laurel, its bar and
## the guild EXP it pays) and today's dungeon (none open: "Mở phó bản" for the leader / deputy, a
## boss picker of the game data's bosses; open: the boss's portrait, its EXP and "Vào đánh", which
## shows the lobby on that boss's mode to play it through the usual boss lobby / matchmaking;
## cleared: the gate with its check). On the right the roster (head, name, level, Lực chiến, the
## leader's crown / the deputy's badge), "Mời" for the leader / deputy (the online players,
## guild_invite_popup.gd) and "Rời bang" (the leader: "Giải tán", with a confirm). A tap on a row
## opens what my role may do to that member (GuildModel.member_actions()).
## Xếp hạng: the top guilds (GET /guilds/rankings): position, crest, name with the leader's name,
## level and members; mine highlighted.
## Data through GuildState (autoload/guild_state.gd), reloaded each time the page shows.

signal open_shop(section: int)
## "Vào đánh" on today's dungeon: the boss queue to play (Home shows the lobby on its mode).
signal play_queue(queue: String)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const GuildGlyphs := preload("res://ui/guild_glyphs.gd")
const PowerTag := preload("res://ui/power_tag.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const GuildModel := preload("res://screens/guild/guild_model.gd")
const GuildInvitePopup := preload("res://screens/guild/guild_invite_popup.gd")
const GuildUi := preload("res://screens/guild/guild_ui.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")
const ShopTab := preload("res://screens/home/shop_tab.gd")
const Fmt := preload("res://core/fmt.gd")

const TAB_GUILD := 0
const TAB_RANKING := 1
const TABS := [{"name": "Bang hội", "glyph": "crest"}, {"name": "Xếp hạng", "glyph": "trophy"}]
const LEFT_W := 600
const ROW_H := 76
const ME := Color(0.4, 0.85, 1.0)
const ROW_BG := Color(0.06, 0.09, 0.22, 0.8)
const ME_BG := Color(0.1, 0.24, 0.42, 0.95)
const DIM := Color(0.75, 0.82, 0.95)
const LOCKED := Color(1, 1, 1, 0.38)

## Where dialogs and toasts go (Home); defaults to this page.
var overlay: Control

var _tab := TAB_GUILD
var _armed := false
var _tabs: Array[Button] = []
var _guild_view: Control # the Bang hội tab's body (rebuilt on each render)
var _ranking_view: Control
var _ranking_status: LoadStatus
var _ranking_rows: VBoxContainer
var _name_input: LineEdit
var _create_message: Label


func _ready() -> void:
	if overlay == null:
		overlay = self
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := Ui.vbox(14)
	margin.add_child(col)
	var tab_row := Ui.hbox(8)
	col.add_child(tab_row)
	_tabs = Ui.tab_row(TABS.map(func(_t): return ""), 26, show_tab, 64)
	for i in _tabs.size():
		_dress_tab(_tabs[i], TABS[i])
		tab_row.add_child(_tabs[i])
	_guild_view = Control.new()
	_guild_view.name = "GuildView"
	_guild_view.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(_guild_view)
	_ranking_view = _build_ranking()
	_ranking_view.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(_ranking_view)
	GuildState.changed.connect(_on_state)
	GuildState.activity_changed.connect(_on_state)
	GuildState.invites_changed.connect(_on_state)
	GuildState.rankings_changed.connect(_render_ranking)
	visibility_changed.connect(_ensure_loaded)
	show_tab(_tab)
	_arm.call_deferred()


## Deferred from _ready(): Home hides the pages it does not show right after adding them.
func _arm() -> void:
	_armed = true
	_ensure_loaded()


func _ensure_loaded() -> void:
	if not (_armed and is_visible_in_tree()):
		return
	GuildState.load_me()
	GuildState.load_invites()
	GuildState.load_activity()
	if _tab == TAB_RANKING:
		GuildState.load_rankings()


## Shows tab `index` (TAB_GUILD, TAB_RANKING).
func show_tab(index: int) -> void:
	_tab = clampi(index, 0, TABS.size() - 1)
	Ui.select_tab(_tabs, _tab)
	_guild_view.visible = _tab == TAB_GUILD
	_ranking_view.visible = _tab == TAB_RANKING
	_ensure_loaded()
	_render_guild()
	_render_ranking()


func tab() -> int:
	return _tab


func _dress_tab(b: Button, t: Dictionary) -> void:
	b.name = "Tab_" + str(t["glyph"])
	b.tooltip_text = t["name"]
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(center)
	var row := Ui.hbox(10)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(row)
	var glyph: Control = GuildGlyphs.make("crest", 42) if t["glyph"] == "crest" else GlyphIcon.make(str(t["glyph"]), 42)
	row.add_child(glyph)
	var l := LobbyUi.text(str(t["name"]), 26, Color.WHITE, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(l)


func _on_state() -> void:
	if is_inside_tree():
		_render_guild.call_deferred()
		if GuildState.in_guild() and GuildState.activity.is_empty() and GuildState.activity_error == "" and is_visible_in_tree():
			GuildState.load_activity()


# ── Bang hội ────────────────────────────────────────────────────────────────

## Rebuilds the Bang hội tab from GuildState (the name typed is kept).
func _render_guild() -> void:
	if _guild_view == null:
		return
	var typed := _name_input.text if is_instance_valid(_name_input) else ""
	var typing := is_instance_valid(_name_input) and _name_input.has_focus()
	Ui.clear(_guild_view)
	_name_input = null
	var body: Control
	if not GuildState.known:
		var status := LoadStatus.new()
		if GuildState.error != "":
			status.show_error(GuildState.error, GuildState.load_me)
		else:
			status.show_loading()
		body = CenterContainer.new()
		body.add_child(status)
	elif GuildState.in_guild():
		body = _build_member_view()
	else:
		body = _build_join_view(typed)
	body.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_guild_view.add_child(body)
	if typing and _name_input != null:
		_name_input.grab_focus.call_deferred() # a reload while typing keeps the field
		_name_input.caret_column = typed.length()


## Not in a guild: Lập bang hội | Lời mời, two equal panels.
func _build_join_view(typed: String) -> Control:
	var row := Ui.hbox(16)
	row.name = "JoinView"
	var create := _build_create(typed)
	var invites := _build_invites()
	for p in [create, invites]:
		p.size_flags_horizontal = SIZE_EXPAND_FILL
		p.size_flags_stretch_ratio = 1.0
		row.add_child(p)
	return row


func _panel_title(glyph: Control, text: String) -> HBoxContainer:
	var head := Ui.hbox(12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(glyph)
	var l := LobbyUi.text(text, 30, Color.WHITE, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(l)
	return head


func _build_create(typed: String) -> Control:
	var rules := GameData.guild_rules()
	var panel := LobbyUi.panel(24, 20)
	panel.name = "CreatePanel"
	var outer := Ui.vbox(14)
	panel.add_child(outer)
	outer.add_child(_panel_title(GuildGlyphs.make("crest", 48, GuildGlyphs.CREST_COLORS[0]), "Lập bang hội"))
	var col := Ui.vbox(18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_vertical = SIZE_EXPAND_FILL
	outer.add_child(col)
	var big := GuildGlyphs.make("crest", 150, GuildGlyphs.CREST_COLORS[0])
	col.add_child(big)
	_name_input = LineEdit.new()
	_name_input.name = "NameInput"
	_name_input.text = typed
	if int(rules["name_max"]) > 0:
		_name_input.max_length = int(rules["name_max"])
	_name_input.placeholder_text = "Tên bang hội"
	_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_input.add_theme_font_size_override("font_size", 28)
	_name_input.custom_minimum_size = Vector2(420, 72)
	_name_input.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(_name_input)
	var cost := Ui.hbox(8)
	cost.name = "Cost"
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	var currency := str(rules["create_currency"])
	var amount := int(rules["create_amount"])
	if amount > 0:
		LobbyUi.icon_text(cost, "coin" if currency == "coin" else "gem", Fmt.thousands(amount), 30, LobbyUi.GOLD, true, 40)
	cost.tooltip_text = "Phí lập bang"
	cost.mouse_filter = MOUSE_FILTER_PASS
	col.add_child(cost)
	_create_message = LobbyUi.text("", 22, Ui.TONES["error"], true)
	_create_message.name = "CreateMessage"
	_create_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_create_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_create_message.visible = false
	col.add_child(_create_message)
	var go := LobbyUi.start_button("Lập bang")
	go.name = "CreateButton"
	go.custom_minimum_size = Vector2(320, 84)
	go.add_theme_font_size_override("font_size", 34)
	go.size_flags_horizontal = SIZE_SHRINK_CENTER
	go.disabled = GuildState.busy != ""
	go.pressed.connect(_create)
	_name_input.text_submitted.connect(func(_t: String) -> void: _create())
	col.add_child(go)
	return panel


func _create() -> void:
	if _name_input == null or GuildState.busy != "":
		return
	var rules := GameData.guild_rules()
	var problem := GuildModel.name_problem(_name_input.text, int(rules["name_min"]), int(rules["name_max"]))
	if problem != "":
		_show_create_message(problem)
		return
	var res: Dictionary = await GuildState.create(_name_input.text)
	if res.ok:
		Ui.toast(overlay, "Đã lập bang hội")
		return
	if GuildModel.is_insufficient(res):
		Ui.toast(overlay, GuildModel.error_text(res, "create", str(rules["create_currency"])))
		open_shop.emit(ShopTab.EXCHANGE if str(rules["create_currency"]) == "coin" else ShopTab.GEMS)
		return
	_show_create_message(GuildModel.error_text(res, "create", str(rules["create_currency"])))


func _show_create_message(text: String) -> void:
	if is_instance_valid(_create_message):
		_create_message.text = text
		_create_message.visible = text != ""


func _build_invites() -> Control:
	var panel := LobbyUi.panel(24, 20)
	panel.name = "InvitesPanel"
	var col := Ui.vbox(14)
	panel.add_child(col)
	col.add_child(_panel_title(GuildGlyphs.make("invite", 48), "Lời mời"))
	var list := Ui.vbox(10)
	list.name = "Invites"
	col.add_child(Ui.scroll(list))
	if GuildState.invites.is_empty():
		var empty := Ui.vbox(10)
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.size_flags_vertical = SIZE_EXPAND_FILL
		var ghost := GuildGlyphs.make("invite", 120)
		ghost.modulate = LOCKED
		empty.add_child(ghost)
		var l := LobbyUi.text("Đang tải..." if not GuildState.invites_loaded else "Chưa có lời mời", 24, Ui.TEXT_DIM, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(l)
		list.size_flags_vertical = SIZE_EXPAND_FILL
		list.add_child(empty)
		var spacer := Control.new() # keeps the ghost in the panel's middle
		spacer.custom_minimum_size.y = 120
		list.add_child(spacer)
	for inv in GuildState.invites:
		list.add_child(_invite_row(inv))
	return panel


func _invite_row(inv: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.name = "Invite_" + str(inv["guild_id"])
	row.add_theme_stylebox_override("panel", LobbyUi.box(ROW_BG, 14, 10, Color(1, 1, 1, 0.08), 1))
	var h := Ui.hbox(14)
	row.add_child(h)
	h.add_child(GuildGlyphs.crest(str(inv["guild_id"]), 56))
	var n := LobbyUi.text(str(inv["name"]), 26, Color.WHITE, true)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(n)
	var info: Dictionary = GuildState.invite_guilds.get(str(inv["guild_id"]), {})
	if not info.is_empty(): # the inviting guild's level and members (GET /guilds/{id})
		var members := Ui.hbox(6)
		members.name = "Members"
		members.add_child(LobbyUi.icon("characters", 30))
		var mc := LobbyUi.text(GuildModel.members_text(info, int(GameData.guild_rules()["max_members"])), 22, Color.WHITE, true)
		mc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		members.add_child(mc)
		h.add_child(members)
		var lv := Ui.hbox(4)
		lv.name = "Level"
		lv.add_child(GlyphIcon.make("level", 30))
		var lt := LobbyUi.text(str(int(info["level"])), 24, LobbyUi.GOLD, true)
		lt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lv.add_child(lt)
		h.add_child(lv)
	var yes := LobbyUi.round_button("check", 58, LobbyUi.ICON_COLORS["green"])
	yes.name = "Accept"
	yes.tooltip_text = "Vào bang"
	yes.pressed.connect(func() -> void: _answer(inv, true))
	h.add_child(yes)
	var no := LobbyUi.round_button("close", 58, LobbyUi.ICON_COLORS["red"])
	no.name = "Decline"
	no.tooltip_text = "Từ chối"
	no.pressed.connect(func() -> void: _answer(inv, false))
	h.add_child(no)
	return row


func _answer(inv: Dictionary, yes: bool) -> void:
	var res: Dictionary
	if yes:
		res = await GuildState.accept(str(inv["guild_id"]))
	else:
		res = await GuildState.decline(str(inv["guild_id"]))
	if not res.ok:
		Ui.toast(overlay, GuildModel.error_text(res, "accept" if yes else "decline"))
	elif yes:
		Ui.toast(overlay, "Đã vào bang %s" % inv["name"])


## In a guild: the card, the quest and the dungeon on the left, the roster on the right.
func _build_member_view() -> Control:
	var row := Ui.hbox(16)
	row.name = "MemberView"
	var left := Ui.vbox(14)
	left.custom_minimum_size.x = LEFT_W
	row.add_child(left)
	left.add_child(_build_header())
	left.add_child(_build_quest())
	var dungeon := _build_dungeon()
	dungeon.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(dungeon)
	var roster := _build_roster()
	roster.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(roster)
	return row


func _build_header() -> Control:
	var g: Dictionary = GuildState.guild
	var rules := GameData.guild_rules()
	var panel := LobbyUi.panel(20, 20)
	panel.name = "GuildCard"
	var h := Ui.hbox(18)
	panel.add_child(h)
	h.add_child(GuildGlyphs.crest(str(g["id"]), 120))
	var col := Ui.vbox(8)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(col)
	var n := LobbyUi.text(str(g["name"]), 32, Color.WHITE, true)
	n.name = "GuildName"
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(n)
	var lv_row := Ui.hbox(10)
	col.add_child(lv_row)
	var lv: Control = GlyphIcon.make("level", 34)
	lv.tooltip_text = "Cấp bang"
	lv.mouse_filter = MOUSE_FILTER_PASS
	lv_row.add_child(lv)
	var lvl := LobbyUi.text(str(int(g["level"])), 28, LobbyUi.GOLD, true)
	lvl.name = "GuildLevel"
	lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_row.add_child(lvl)
	var bar_info := GuildModel.exp_bar(int(g["exp"]), int(g["level"]), int(rules["exp_per_level"]))
	var bar := Ui.bar(bar_info["ratio"], 18)
	bar.name = "ExpBar"
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", LobbyUi.box(LobbyUi.GOLD, 9, 0))
	lv_row.add_child(bar)
	var exp_text := LobbyUi.text(bar_info["text"], 20, DIM, true)
	exp_text.name = "ExpText"
	exp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_row.add_child(exp_text)
	var skills := Ui.hbox(14)
	skills.name = "Skills"
	col.add_child(skills)
	for s in GuildModel.skill_icons(rules["skills"], int(g["level"])):
		skills.add_child(GuildUi.skill_chip(s))
	return panel


func _build_quest() -> Control:
	var q: Dictionary = GuildState.activity.get("quest", {})
	var panel := LobbyUi.panel(18, 20)
	panel.name = "QuestCard"
	panel.tooltip_text = "Nhiệm vụ ngày: thắng trận cùng bang"
	var h := Ui.hbox(16)
	panel.add_child(h)
	h.add_child(GuildGlyphs.make("quest", 72))
	var col := Ui.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(col)
	var title := LobbyUi.text("Nhiệm vụ bang", 24, Color.WHITE, true)
	col.add_child(title)
	var bar_row := Ui.hbox(10)
	col.add_child(bar_row)
	var info := GuildModel.quest_bar(q)
	var bar := Ui.bar(info["ratio"], 18)
	bar.name = "QuestBar"
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	if info["done"]:
		bar.add_theme_stylebox_override("fill", LobbyUi.box(LobbyUi.ICON_COLORS["green"], 9, 0))
	bar_row.add_child(bar)
	var t := LobbyUi.text(info["text"] if not q.is_empty() else "…", 22, Color.WHITE, true)
	t.name = "QuestText"
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_row.add_child(t)
	var reward := int(q.get("reward_exp", 0))
	if reward <= 0:
		reward = int(GameData.guild_rules()["quest_exp"])
	h.add_child(GuildUi.exp_chip(reward, str(GuildState.guild_id()), info["done"]))
	return panel


func _build_dungeon() -> Control:
	var d: Dictionary = GuildState.activity.get("dungeon", {})
	var panel := LobbyUi.panel(18, 20)
	panel.name = "DungeonCard"
	var h := Ui.hbox(16)
	panel.add_child(h)
	var manage := GuildModel.can_manage(GuildState.my_role())
	if d.is_empty():
		h.add_child(GuildGlyphs.make("dungeon", 140))
		var col := Ui.vbox(12)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		h.add_child(col)
		col.add_child(LobbyUi.text("Phó bản bang", 26, Color.WHITE, true))
		if manage:
			var open := LobbyUi.start_button("Mở phó bản")
			open.name = "OpenDungeon"
			open.custom_minimum_size = Vector2(0, 72)
			open.add_theme_font_size_override("font_size", 30)
			open.disabled = GuildState.activity.is_empty() or GuildState.busy != ""
			open.pressed.connect(open_boss_picker)
			col.add_child(open)
		else:
			var wait := Ui.hbox(8)
			wait.add_child(GuildGlyphs.make("lock", 32))
			var l := LobbyUi.text("Chờ bang chủ mở", 22, DIM, true)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			wait.add_child(l)
			col.add_child(wait)
		var exp := int(GameData.guild_rules()["dungeon_exp"])
		if exp > 0:
			h.add_child(GuildUi.exp_chip(exp, GuildState.guild_id()))
		return panel
	var stage := _boss_stage(str(d["boss_id"]), Vector2(170, 170))
	h.add_child(stage)
	var col := Ui.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(col)
	var name_row := Ui.hbox(10)
	name_row.add_child(GuildGlyphs.make("dungeon_done" if d["done"] else "dungeon", 40))
	var n := LobbyUi.text(GameData.boss_name(str(d["boss_id"])), 26, Color.WHITE, true)
	n.name = "BossName"
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(n)
	col.add_child(name_row)
	col.add_child(GuildUi.exp_chip(int(d["reward_exp"]), GuildState.guild_id(), d["done"]))
	var play := LobbyUi.start_button("Vào đánh")
	play.name = "PlayDungeon"
	play.custom_minimum_size = Vector2(0, 72)
	play.add_theme_font_size_override("font_size", 30)
	play.pressed.connect(func() -> void: play_queue.emit(str(d["queue"])))
	col.add_child(play)
	return panel


## A boss's portrait (the Mode Select card's figure) in a box of `box` px.
static func _boss_stage(boss_id: String, box: Vector2) -> Control:
	var stage := Control.new()
	stage.name = "BossStage"
	stage.custom_minimum_size = box
	stage.size_flags_vertical = SIZE_SHRINK_CENTER
	stage.size_flags_horizontal = SIZE_SHRINK_CENTER
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	var art := BossArt.art_of(boss_id)
	var tint := BossArt.accent(art)
	stage.draw.connect(func() -> void:
		for i in 5:
			stage.draw_circle(stage.size / 2.0, stage.size.y * (0.5 - i * 0.08), Color(tint, 0.06 + i * 0.03)))
	var figure := BossArtView.make(art, box, -1, "portrait")
	figure.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(figure)
	return stage


## "Mở phó bản": the game data's bosses as cards; a tap opens today's dungeon on that boss.
func open_boss_picker() -> Modal:
	var m := Modal.new()
	m.open(overlay, "Chọn boss", 900)
	m.add_close_x()
	var grid := GridContainer.new()
	grid.name = "Bosses"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	var center := CenterContainer.new()
	center.add_child(grid)
	m.body.add_child(center)
	for b in GameData.bosses():
		var id := str(b.get("bossId", ""))
		if id == "":
			continue
		var card := Button.new()
		card.name = "Boss_" + id
		card.focus_mode = FOCUS_NONE
		card.custom_minimum_size = Vector2(190, 210)
		LobbyUi.style_button(card, Color(0.08, 0.12, 0.28, 0.95), 16, 8, Color(1, 1, 1, 0.12), 2)
		var col := Ui.vbox(4)
		col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		col.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(col)
		var stage := _boss_stage(id, Vector2(170, 160))
		stage.size_flags_horizontal = SIZE_SHRINK_CENTER
		col.add_child(stage)
		var l := LobbyUi.text(GameData.boss_name(id), 22, Color.WHITE, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = MOUSE_FILTER_IGNORE
		col.add_child(l)
		card.pressed.connect(func() -> void: _open_dungeon(m, id))
		grid.add_child(card)
	return m


func _open_dungeon(m: Modal, boss_id: String) -> void:
	m.set_busy(true)
	var res: Dictionary = await GuildState.open_dungeon(boss_id)
	if not is_instance_valid(m):
		return
	if res.ok:
		m.close()
		Ui.toast(overlay, "Đã mở phó bản")
	else:
		m.set_busy(false)
		m.set_message(GuildModel.error_text(res, "dungeon"))


# ── Roster ──────────────────────────────────────────────────────────────────

func _build_roster() -> Control:
	var g: Dictionary = GuildState.guild
	var role := GuildState.my_role()
	var panel := LobbyUi.panel(18, 20)
	panel.name = "Roster"
	var col := Ui.vbox(12)
	panel.add_child(col)
	var head := Ui.hbox(12)
	col.add_child(head)
	var count := Ui.hbox(8)
	count.tooltip_text = "Thành viên"
	count.mouse_filter = MOUSE_FILTER_PASS
	count.size_flags_horizontal = SIZE_EXPAND_FILL
	count.add_child(LobbyUi.icon("characters", 40))
	var c := LobbyUi.text(GuildModel.members_text(g, int(GameData.guild_rules()["max_members"])), 28, Color.WHITE, true)
	c.name = "MemberCount"
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_child(c)
	head.add_child(count)
	if GuildModel.can_manage(role):
		var invite := _action_button("Mời", "invite", LobbyUi.ICON_COLORS["green"])
		invite.name = "InviteButton"
		invite.pressed.connect(open_invite)
		head.add_child(invite)
	var leave := _action_button("Giải tán" if GuildModel.leaves_by_disband(role) else "Rời bang", "leave", LobbyUi.ICON_COLORS["red"])
	leave.name = "LeaveButton"
	leave.pressed.connect(_confirm_leave)
	head.add_child(leave)
	var list := Ui.vbox(8)
	list.name = "Members"
	var scroll := Ui.scroll(list)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(scroll)
	for m in g.get("members", []):
		list.add_child(_member_row(m, role))
	return panel


## A small button with a guild picture and a short word.
func _action_button(text: String, glyph: String, bg: Color) -> Button:
	var b := Button.new()
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 60)
	LobbyUi.style_button(b, bg, 30, 10, Color(1, 1, 1, 0.6), 2)
	var row := Ui.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.add_child(GuildGlyphs.make(glyph, 40))
	var l := LobbyUi.text(text, 24, Color.WHITE, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(l)
	b.custom_minimum_size.x = maxf(170.0, row.get_combined_minimum_size().x + 36.0)
	return b


func _member_row(m: Dictionary, my_role: String) -> Control:
	var me: bool = m["player_id"] == Session.player_id
	var actions := GuildModel.member_actions(my_role, m["role"], me)
	var row := Button.new()
	row.name = "Member_" + str(m["player_id"])
	row.focus_mode = FOCUS_NONE
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = MOUSE_FILTER_PASS # a drag still scrolls the list
	row.disabled = actions.is_empty()
	var bg := LobbyUi.box(ME_BG if me else ROW_BG, 14, 8, ME if me else Color(1, 1, 1, 0.08), 3 if me else 1)
	for st in ["normal", "disabled"]:
		row.add_theme_stylebox_override(st, bg)
	row.add_theme_stylebox_override("hover", LobbyUi.box((ME_BG if me else ROW_BG).lightened(0.08), 14, 8, ME if me else Color(1, 1, 1, 0.2), 3 if me else 1))
	row.add_theme_stylebox_override("pressed", bg)
	row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not actions.is_empty():
		row.pressed.connect(func() -> void: open_member(m))
	var h := Ui.hbox(12)
	h.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -18
	h.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(h)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(44, 44)
	badge.size_flags_vertical = SIZE_SHRINK_CENTER
	badge.mouse_filter = MOUSE_FILTER_IGNORE
	if m["role"] != GuildModel.MEMBER:
		var g := GuildGlyphs.make("crown" if m["role"] == GuildModel.LEADER else "deputy", 44)
		g.name = "RoleBadge"
		badge.add_child(g)
	badge.tooltip_text = GuildModel.ROLE_NAMES.get(m["role"], "")
	h.add_child(badge)
	var head = HeadIcon.make(str(m["character"]), str(m["name"]), 60)
	head.lobby = true
	head.ring = LobbyUi.GOLD if m["role"] == GuildModel.LEADER else Color(0.85, 0.88, 0.95)
	head.size_flags_vertical = SIZE_SHRINK_CENTER
	h.add_child(head)
	var n := LobbyUi.text(str(m["name"]), 24, ME if me else Color.WHITE, true)
	n.name = "Name"
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(n)
	var lv := LobbyUi.text("Lv.%d" % int(m["level"]) if int(m["level"]) > 0 else "", 22, LobbyUi.GOLD, true)
	lv.custom_minimum_size.x = 80
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(lv)
	var power = PowerTag.make(30, 22)
	power.keep_unknown = true
	power.set_power(int(m["power"]))
	power.custom_minimum_size.x = 150
	power.alignment = BoxContainer.ALIGNMENT_END
	power.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(power)
	return row


## What my role may do to member `m`: its card (head, name, level, power) and one button per action.
func open_member(m: Dictionary) -> Modal:
	var dialog := Modal.new()
	dialog.open(overlay, str(m["name"]), 680)
	dialog.add_close_x()
	var info := Ui.hbox(16)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var head = HeadIcon.make(str(m["character"]), str(m["name"]), 84)
	head.lobby = true
	info.add_child(head)
	var lv := LobbyUi.text("Lv.%d" % int(m["level"]), 26, LobbyUi.GOLD, true)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.add_child(lv)
	var power = PowerTag.make(34, 26)
	power.set_power(int(m["power"]))
	info.add_child(power)
	dialog.body.add_child(info)
	var actions := GuildModel.member_actions(GuildState.my_role(), m["role"], false)
	for i in actions.size():
		var action: String = actions[i]
		var b := dialog.add_button(GuildModel.ACTION_NAMES[action], func() -> void: _member_action(dialog, action, m), i / 2)
		b.name = "Action_" + action
		if action == GuildModel.PROMOTE and GuildModel.deputy_count(GuildState.guild) >= int(GameData.guild_rules()["max_deputies"]) \
				and int(GameData.guild_rules()["max_deputies"]) > 0:
			dialog.lock_button(b) # the deputies are full
	return dialog


func _member_action(dialog: Modal, action: String, m: Dictionary) -> void:
	if action in [GuildModel.TRANSFER, GuildModel.KICK] and not dialog.has_meta("confirmed_" + action):
		dialog.set_meta("confirmed_" + action, true)
		dialog.set_message("%s %s? Bấm lần nữa để xác nhận" % [GuildModel.ACTION_NAMES[action], m["name"]])
		dialog.message.add_theme_color_override("font_color", LobbyUi.GOLD)
		return
	dialog.set_busy(true)
	var res: Dictionary = await GuildState.act(action, str(m["player_id"]))
	if not is_instance_valid(dialog):
		return
	if res.ok:
		dialog.close()
		Ui.toast(overlay, "Đã xong")
	else:
		dialog.set_busy(false)
		dialog.message.add_theme_color_override("font_color", Ui.TONES["error"])
		dialog.set_message(GuildModel.error_text(res, action))


## "Rời bang" / "Giải tán": a confirm first.
func _confirm_leave() -> Modal:
	var disband := GuildModel.leaves_by_disband(GuildState.my_role())
	var m := Modal.new()
	m.open(overlay, "Giải tán bang hội?" if disband else "Rời bang hội?", 640)
	m.add_text("Bang hội và mọi thành viên sẽ bị giải tán, không hoàn phí." if disband else "Bạn sẽ rời bang và mất kỹ năng bang.")
	m.add_button("Ở lại", m.close)
	var go := m.add_button("Giải tán" if disband else "Rời bang", func() -> void:
		m.set_busy(true)
		var res: Dictionary
		if disband:
			res = await GuildState.disband()
		else:
			res = await GuildState.leave()
		if not is_instance_valid(m):
			return
		if res.ok:
			m.close()
		else:
			m.set_busy(false)
			m.set_message(GuildModel.error_text(res, "disband" if disband else "leave")))
	go.name = "ConfirmLeave"
	return m


## "Mời": the online players with a "Mời" each (guild_invite_popup.gd).
func open_invite() -> Control:
	var popup := GuildInvitePopup.new()
	popup.open_for(overlay, Router.party)
	return popup


# ── Xếp hạng ────────────────────────────────────────────────────────────────

func _build_ranking() -> Control:
	var panel := LobbyUi.panel(18, 20)
	panel.name = "Ranking"
	var col := Ui.vbox(10)
	panel.add_child(col)
	_ranking_status = LoadStatus.new()
	col.add_child(_ranking_status)
	_ranking_rows = Ui.vbox(8)
	_ranking_rows.name = "Rows"
	var scroll := Ui.scroll(_ranking_rows)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(scroll)
	return panel


func _render_ranking() -> void:
	if _ranking_rows == null:
		return
	if GuildState.rankings_error != "" and not GuildState.rankings_loaded:
		_ranking_status.show_error(GuildState.rankings_error, GuildState.load_rankings)
	elif not GuildState.rankings_loaded:
		_ranking_status.show_loading()
	else:
		_ranking_status.clear()
	Ui.clear(_ranking_rows)
	for g in GuildState.rankings:
		_ranking_rows.add_child(_ranking_row(g, g["id"] == GuildState.guild_id()))
	if GuildState.rankings_loaded and GuildState.rankings.is_empty():
		var l := LobbyUi.text("Chưa có bang hội nào", 24, Ui.TEXT_DIM, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ranking_rows.add_child(l)


func _ranking_row(g: Dictionary, me: bool) -> Control:
	var row := PanelContainer.new()
	row.name = "Row%d" % int(g["pos"])
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = MOUSE_FILTER_PASS
	var bg := LobbyUi.box(ME_BG if me else ROW_BG, 14, 8, ME if me else Color(1, 1, 1, 0.08), 3 if me else 1)
	bg.content_margin_right = 22
	row.add_theme_stylebox_override("panel", bg)
	var h := Ui.hbox(14)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(h)
	var pos := LobbyUi.text(str(int(g["pos"])), 28, ME if me else (LobbyUi.GOLD if int(g["pos"]) <= 3 else Color.WHITE), true)
	pos.custom_minimum_size.x = 70
	pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pos)
	h.add_child(GuildGlyphs.crest(str(g["id"]), 58))
	var names := Ui.vbox(0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = SIZE_EXPAND_FILL
	names.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(names)
	var n := LobbyUi.text(str(g["name"]), 26, ME if me else Color.WHITE, true)
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(n)
	if str(g["leader_name"]) != "":
		var leader := Ui.hbox(6)
		leader.mouse_filter = MOUSE_FILTER_IGNORE
		leader.add_child(GuildGlyphs.make("crown", 24))
		var ln := LobbyUi.text(str(g["leader_name"]), 20, DIM)
		ln.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ln.clip_text = true
		ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		ln.size_flags_horizontal = SIZE_EXPAND_FILL
		leader.add_child(ln)
		names.add_child(leader)
	var members := Ui.hbox(6)
	members.custom_minimum_size.x = 140
	members.alignment = BoxContainer.ALIGNMENT_END
	members.mouse_filter = MOUSE_FILTER_IGNORE
	members.add_child(LobbyUi.icon("characters", 32))
	var mc := LobbyUi.text(GuildModel.members_text(g, int(GameData.guild_rules()["max_members"])), 22, Color.WHITE, true)
	mc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	members.add_child(mc)
	h.add_child(members)
	var lv_box := Ui.hbox(6)
	lv_box.custom_minimum_size.x = 110
	lv_box.alignment = BoxContainer.ALIGNMENT_END
	lv_box.mouse_filter = MOUSE_FILTER_IGNORE
	lv_box.add_child(GlyphIcon.make("level", 34))
	var lv := LobbyUi.text(str(int(g["level"])), 28, LobbyUi.GOLD, true)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_box.add_child(lv)
	h.add_child(lv_box)
	return row
