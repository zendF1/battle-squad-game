extends Control
## Matchmaking (opened by the Loadout's "TÌM TRẬN" on a queue mode: Đấu hạng 2vs2, Đấu thường
## 2vs2, ...): the queue Router.queue (screens/ranked/ranked_flow.gd) with the Loadout's character
## and items (Router.ranked_loadout) and the screen around it. Left, my team's two cards (mine filled:
## character, name, Lv, tier badge; my teammate a silhouette "Đang ghép..." with a light sweep),
## right the two enemy silhouettes, in the middle the VS emblem under the mode's name in capitals
## and its description (the game data's, "ĐẤU HẠNG 2VS2") and over
## "Đang ghép... 0:31" with a spinner ("Đang vào hàng chờ..." until the server says the queue
## started). Bottom: a tip changing every TIP_SEC and "Hủy ghép" (also Esc / Android back), which
## cancels the queue and goes back to Home. MatchFound: "Hủy ghép" goes, the VS emblem flashes,
## "Tìm thấy trận!" pops and the silhouettes flip one by one into the real players (bots too,
## MatchmakingModel order); the match opens once MatchStarted came and the reveal had
## MatchmakingModel.reveal_sec() (the socket is held from MatchStarted, so the first turn's events
## wait for the Match scene). A server sending MatchFound without teams: the cards flip from
## MatchStarted's players. An error, a dropped queue or a lost connection goes back to Home with
## its message (Router.home_notice). In a party (Router.party with a teammate) the teammate's card
## shows from the start and the queue never leaves the lobby (RankedFlow.keep_lobby): a cancel or an
## error goes back Home still in the party. Opened for the party's member (Router.ranked_member:
## the host started the queue) it searches at once; the member's "Hủy ghép" leaves the lobby (the
## server cancels the queue for both). Every LeaveLobby goes through Router.party.leave().
## A boss queue (boss:<bossId>): the title is the boss's name; left, the party's four compact
## cards in a 2x2 grid (my teammates from the start), right one big card of the same size with
## the boss's figure and name, which stays: only the party's cards flip at MatchFound (bot
## teammates included).
## The background is the queued mode's image (the one the lobby shows for it,
## LobbyModel.background_of_queue()), blurred and dimmed under the cards.
## offline_preview (the preview harness, set before it enters
## the tree): no socket; the harness feeds on_event().

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const RankedFlow := preload("res://screens/ranked/ranked_flow.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const MatchmakingModel := preload("res://screens/ranked/matchmaking_model.gd")
const PlayerCard := preload("res://screens/ranked/player_card.gd")
const VsEmblem := preload("res://screens/ranked/vs_emblem.gd")
const TitleModel := preload("res://screens/home/title_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const ElementBackdrop := preload("res://ui/element_backdrop.gd")

const BOSS_CARD_SCALE := 0.74 # the party's compact cards in a boss queue
const BOSS_GAP := 16 # between the boss queue's cards

const MARGIN := 18
const DIM := Color(0.01, 0.03, 0.1, 0.42) # over the blurred background: the cards and texts lead
const TIP_SEC := 6.0
const CENTRE_W := 330
const BLUE := Color(0.5, 0.74, 1.0)
const RED := Color(1.0, 0.55, 0.55)

var offline_preview := false
var flow := RankedFlow.new()

var _cards: Array = [] # PlayerCard ×4, left to right
var _vs: VsEmblem
var _status_row: Control
var _status: Label
var _spinner: Control
var _found_label: Label
var _map_line: Label # "Bản đồ: …" once the match is found
var _tip: Label
var _cancel: Button
var _me := ""
var _searching := false
var _elapsed := 0.0
var _spin := 0.0
var _tip_index := 0
var _tip_left := TIP_SEC
var _found_for := -1.0 # seconds since MatchFound, -1 before
var _revealed := false
var _snapshot: Variant = null # MatchStarted data
var _leaving := false
var _queue := "" # Router.queue, else the game data's ranked mode
var _boss := {} # the boss of a boss queue (GET /gamedata bosses), {} otherwise


func _ready() -> void:
	theme = LobbyUi.theme()
	get_tree().quit_on_go_back = false # Android back cancels the queue
	_me = Session.player_id
	_tip_index = randi() % maxi(RankModel.tips().size(), 1)
	var as_member := Router.ranked_member # taken once, whatever happens next
	Router.ranked_member = false
	_queue = Router.queue if Router.queue != "" else GameData.ranked_mode()
	_boss = GameData.boss_of_queue(_queue)
	_build()
	_cards[0].show_player(_my_player())
	var mates := _teammates()
	for i in mini(mates.size(), _cards.size() - 1):
		_cards[i + 1].show_player(mates[i])
	PlayerState.rank_changed.connect(_on_rank_changed)
	PlayerState.need_titles() # the other players' titles (MatchFound gives their ids)
	if not offline_preview:
		GameSocket.event_received.connect(on_event)
		GameSocket.disconnected.connect(_on_disconnected)
		if not GameSocket.is_open():
			_run([["failed", RankedFlow.DISCONNECTED]])
			return
	if as_member:
		_run(flow.start_member())
		return
	flow.keep_lobby = _in_party()
	_run(flow.start(Router.ranked_loadout, _queue))


func _in_party() -> bool:
	return Router.party != null and Router.party.model.in_party()


## The party's teammates as card players (MatchmakingModel.parse_player); [] alone.
func _teammates() -> Array:
	if not _in_party():
		return []
	return Router.party.model.teammates().map(func(m): return MatchmakingModel.parse_player(m))


## A boss queue: the party's cards (4) on the left, the boss on the right.
func _is_boss() -> bool:
	return not _boss.is_empty() or GameData.is_boss_queue(_queue)


## The cards on my side: the boss party's size, else the team size.
func _left_size() -> int:
	return maxi(int(LobbyModel.mode(LobbyModel.index_of_queue(_queue))["party_size"]), 1) if _is_boss() \
		else MatchmakingModel.team_size()


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true


func _my_player() -> Dictionary:
	var character := str(Router.ranked_loadout.get("characterId", GameData.default_character_id()))
	return MatchmakingModel.my_player(_me, PlayerState.display_name(), character, PlayerState.level(), PlayerState.my_rank())


func _on_rank_changed() -> void:
	if _found_for < 0.0:
		_cards[0].show_player(_my_player())


# ── Layout ──────────────────────────────────────────────────────────────────

func _build() -> void:
	var bg := Backdrop.new() # the queued mode's image, blurred (LobbyModel.background_of_queue())
	bg.blurred = true
	bg.top_shade = false # the dim covers it
	bg.show_image(LobbyModel.background_of_queue(_queue), false)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	centre.offset_bottom = -112 # above the bottom bar
	centre.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(centre)
	var row := Ui.hbox(26)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	centre.add_child(row)
	row.add_child(_team("ĐỘI CỦA BẠN", BLUE, false))
	row.add_child(_build_middle())
	row.add_child(_boss_side() if _is_boss() else _team("ĐỐI THỦ", RED, true))

	var bar := Ui.hbox(18)
	bar.anchor_left = 0
	bar.anchor_right = 1
	bar.anchor_top = 1
	bar.anchor_bottom = 1
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = -MARGIN - 84
	bar.offset_bottom = -MARGIN
	add_child(bar)
	bar.add_child(_build_tip())
	_cancel = LobbyUi.pill_button("Hủy ghép", 30, 84)
	LobbyUi.texture_button(_cancel, "button_orange", 24)
	_cancel.custom_minimum_size.x = 300
	_cancel.pressed.connect(cancel)
	bar.add_child(_cancel)


## A team's label over its two cards; a boss queue's party: a 2x2 grid of compact cards.
func _team(caption: String, color: Color, enemy: bool) -> Control:
	var col := Ui.vbox(10)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	var boss := _is_boss() and not enemy
	if not _is_boss(): # a boss queue: no headers, the frames' colours tell the sides
		var label := LobbyUi.text(caption, 26, color, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(label)
	var cards: Container
	if boss:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", BOSS_GAP)
		grid.add_theme_constant_override("v_separation", BOSS_GAP)
		cards = grid
	else:
		cards = Ui.hbox(18)
	cards.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(cards)
	for i in (_left_size() if boss else MatchmakingModel.team_size()):
		var card := PlayerCard.new()
		card.enemy = enemy
		card.mine = not enemy and i == 0
		if boss: # compact and scaled: four fit in the grid
			card.compact = true
			var holder := Control.new()
			holder.custom_minimum_size = _boss_cell()
			holder.mouse_filter = MOUSE_FILTER_IGNORE
			var inner := Control.new()
			inner.scale = Vector2.ONE * BOSS_CARD_SCALE
			inner.mouse_filter = MOUSE_FILTER_IGNORE
			holder.add_child(inner)
			inner.add_child(card)
			cards.add_child(holder)
		else:
			cards.add_child(card)
		_cards.append(card)
	return col


## One party card of a boss queue on screen.
func _boss_cell() -> Vector2:
	return PlayerCard.COMPACT_SIZE * BOSS_CARD_SCALE


## The party grid's size: the boss side takes the same box, so the screen mirrors around the VS.
func _boss_block() -> Vector2:
	var cell := _boss_cell()
	return Vector2(cell.x * 2 + BOSS_GAP, cell.y * 2 + BOSS_GAP)


## The boss's side, the party grid's mirror: "BOSS" over one big card of the same size as the
## grid, the boss's figure filling it over its name.
func _boss_side() -> Control:
	var col := Ui.vbox(10)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	var card := _boss_card(BossArt.art_of(str(_boss.get("bossId", ""))), _boss_block(),
		str(_boss.get("name", LobbyModel.queue_name(_queue))), str(_boss.get("bossId", "")))
	card.name = "BossCard"
	col.add_child(card)
	return col


## The boss card of size `at`, the enemy's red frame over its element's backdrop (ElementBackdrop:
## the boss's element, drawn behind the figure): the figure as big as the card allows, its name
## under it with its element's badge, both centred.
func _boss_card(art: String, at: Vector2, name_text: String, boss_id: String = "") -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = at
	card.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", LobbyUi.box(Color(0.06, 0.03, 0.08, 0.95), 22, 0))
	var back := ElementBackdrop.new() # under everything, inside the frame
	back.element_id = GameData.boss_element(boss_id)
	back.radius = 22.0
	back.name = "ElementBackdrop"
	card.add_child(back)
	var pad := MarginContainer.new()
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	card.add_child(pad)
	var inner := Ui.vbox(8)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_child(inner)
	var name_label := LobbyUi.text(name_text, 34, Color.WHITE, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	inner.add_child(BossArtView.make(art, Vector2(at.x - 40, at.y - 40 - 34 * 1.45 - 8), -1, "portrait"))
	inner.add_child(ElementBadge.name_row(name_label, GameData.boss_element(boss_id), 38, 10))
	var frame := Control.new() # the enemy's red frame over it all
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		frame.draw_style_box(LobbyUi.box(Color(0, 0, 0, 0), 22, 0, Color(PlayerCard.RED, 0.95), 4), Rect2(Vector2.ZERO, frame.size)))
	card.add_child(frame)
	return card


func _build_middle() -> Control:
	var col := Ui.vbox(6)
	col.custom_minimum_size.x = CENTRE_W
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = MOUSE_FILTER_IGNORE
	var mode: Dictionary = LobbyModel.mode(LobbyModel.index_of_queue(_queue)) if LobbyModel.index_of_queue(_queue) >= 0 else {}
	var title_text := str(_boss.get("name", "")) if str(_boss.get("name", "")) != "" else LobbyModel.queue_name(_queue)
	var title := LobbyUi.text(title_text.to_upper(), 40, LobbyUi.GOLD, true)
	title.name = "ModeTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = CENTRE_W
	title.visible = not _is_boss() # a boss queue: the medal, "Tìm thấy trận!" and the map only
	col.add_child(title)
	var sub := LobbyUi.text("" if _is_boss() else str(mode.get("description", "")), 21, Color(0.75, 0.9, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.visible = sub.text != ""
	col.add_child(sub)
	_vs = VsEmblem.new()
	_vs.custom_minimum_size = Vector2(CENTRE_W, 300)
	col.add_child(_vs)
	var stack := Control.new() # the status row and "Tìm thấy trận!" in the same place
	stack.custom_minimum_size = Vector2(CENTRE_W, 64)
	stack.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(stack)
	var status_row := Ui.hbox(12)
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	status_row.mouse_filter = MOUSE_FILTER_IGNORE
	stack.add_child(status_row)
	_status_row = status_row
	_spinner = Control.new()
	_spinner.custom_minimum_size = Vector2(34, 34)
	_spinner.size_flags_vertical = SIZE_SHRINK_CENTER
	_spinner.mouse_filter = MOUSE_FILTER_IGNORE
	_spinner.draw.connect(_draw_spinner)
	status_row.add_child(_spinner)
	_status = LobbyUi.text("Đang vào hàng chờ...", 30, Color.WHITE, true)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_row.add_child(_status)
	_found_label = LobbyUi.text("Tìm thấy trận!", 44, LobbyUi.GOLD, true)
	_found_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_found_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_found_label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_found_label.visible = false
	_found_label.resized.connect(func() -> void: _found_label.pivot_offset = _found_label.size / 2.0)
	stack.add_child(_found_label)
	_map_line = LobbyUi.text("", 26, Color(0.85, 0.93, 1.0), true)
	_map_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_line.modulate.a = 0.0
	col.add_child(_map_line)
	var pulse := _vs.create_tween().set_loops()
	pulse.tween_property(_vs, "scale", Vector2.ONE * 1.05, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_vs, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	_vs.set_meta("pulse", pulse)
	return col


func _build_tip() -> Control:
	var panel := LobbyUi.panel(0, 22)
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 22)
	inner.add_theme_constant_override("margin_right", 22)
	panel.add_child(inner)
	var row := Ui.hbox(14)
	inner.add_child(row)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", LobbyUi.box(LobbyUi.GOLD, 12, 0))
	tag.size_flags_vertical = SIZE_SHRINK_CENTER
	var tag_text := LobbyUi.text("MẸO", 20, LobbyUi.TEXT_DARK, true)
	tag_text.add_theme_constant_override("outline_size", 0)
	tag_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_text.custom_minimum_size = Vector2(70, 32)
	tag_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(tag_text)
	row.add_child(tag)
	_tip = LobbyUi.text(RankModel.tip(_tip_index), 24, Color(0.88, 0.94, 1.0))
	_tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip.size_flags_horizontal = SIZE_EXPAND_FILL
	_tip.clip_text = true
	_tip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_tip)
	return panel


func _draw_spinner() -> void:
	var c := _spinner.size / 2.0
	var r := minf(c.x, c.y) - 4.0
	_spinner.draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.18), 5.0, true)
	_spinner.draw_arc(c, r, _spin, _spin + PI * 1.25, 24, LobbyUi.GOLD, 5.0, true)


# ── Flow ────────────────────────────────────────────────────────────────────

func on_event(event: String, data: Variant) -> void:
	if not flow.member:
		flow.keep_lobby = _in_party() # Router.party has applied this event already
	_run(flow.on_event(event, data))


func _on_disconnected() -> void:
	_run(flow.on_disconnected())


## "Hủy ghép": nothing once the match is found.
func cancel() -> void:
	if flow.found():
		return
	_cancel.disabled = true
	_status.text = "Đang hủy ghép..."
	_run(flow.cancel())


func _run(actions: Array) -> void:
	for a in actions:
		match a[0]:
			"send":
				if offline_preview:
					pass
				elif a[1] == "LeaveLobby":
					Router.party.leave()
				else:
					GameSocket.send(a[1], a[2])
			"searching":
				_searching = true
				_elapsed = 0.0
				_render_status()
			"found":
				_on_found(a[1])
			"started":
				if not offline_preview:
					GameSocket.hold() # TurnStarted follows at once; Match releases it
				_snapshot = a[1]
				if not _revealed:
					_reveal(MatchmakingModel.teams_of_started(a[1]))
				_maybe_go()
			"failed":
				_leave(str(a[1]))
			"cancelled":
				_leave("")


func _leave(notice: String) -> void:
	if _leaving or offline_preview:
		return
	_leaving = true
	Router.home_notice = notice
	Router.go(Router.HOME)


func _process(delta: float) -> void:
	_run(flow.tick(delta))
	_spin = fmod(_spin + delta * 6.0, TAU)
	_spinner.queue_redraw()
	if _searching and _found_for < 0.0:
		var before := int(_elapsed)
		_elapsed += delta
		if int(_elapsed) != before:
			_render_status()
	_tip_left -= delta
	if _tip_left <= 0.0:
		_next_tip()
	if _found_for >= 0.0:
		_found_for += delta
		_maybe_go()


func _render_status() -> void:
	if flow.phase == RankedFlow.Phase.CANCELLING:
		return
	_status.text = "Đang ghép... %s" % RankModel.timer_text(int(_elapsed)) if _searching else "Đang vào hàng chờ..."


func _next_tip() -> void:
	_tip_left = TIP_SEC
	_tip_index += 1
	var t := _tip.create_tween()
	t.tween_property(_tip, "modulate:a", 0.0, 0.25)
	t.tween_callback(func() -> void: _tip.text = RankModel.tip(_tip_index))
	t.tween_property(_tip, "modulate:a", 1.0, 0.25)


func _on_found(data: Variant) -> void:
	_found_for = 0.0
	_cancel.disabled = true
	var fade := _cancel.create_tween()
	fade.tween_property(_cancel, "modulate:a", 0.0, 0.25)
	_status_row.visible = false
	_found_label.visible = true
	_found_label.scale = Vector2.ONE * 0.4
	var pop := _found_label.create_tween()
	pop.tween_property(_found_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_vs.found = true
	var pulse: Tween = _vs.get_meta("pulse")
	pulse.kill()
	var flash := _vs.create_tween()
	flash.tween_property(_vs, "flash", 1.0, 0.08)
	flash.parallel().tween_property(_vs, "scale", Vector2.ONE * 1.18, 0.12).set_trans(Tween.TRANS_SINE)
	flash.tween_property(_vs, "flash", 0.0, 0.5)
	flash.parallel().tween_property(_vs, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	_map_line.text = MatchmakingModel.map_text(data)
	_map_line.create_tween().tween_property(_map_line, "modulate:a", 1.0, 0.4).set_delay(0.3)
	var teams := MatchmakingModel.teams_of_found(data)
	if not teams.is_empty():
		_reveal(teams)


## Fills the cards from the match's teams: mine at once, the others flipping one by one.
func _reveal(teams: Dictionary) -> void:
	if teams.is_empty():
		return
	_revealed = true
	var slots := MatchmakingModel.slots(teams, _me, _left_size(), 0) if _is_boss() else MatchmakingModel.slots(teams, _me)
	var order := MatchmakingModel.reveal_order(slots, _me)
	for i in slots.size():
		var p: Dictionary = slots[i]
		var card: PlayerCard = _cards[i]
		card.title = _title_of(p)
		if not order.has(i):
			if not p.is_empty():
				card.show_player(p)
	for k in order.size():
		var i: int = order[k]
		get_tree().create_timer(MatchmakingModel.FLIP_GAP * (k + 1)).timeout.connect(_cards[i].flip_to.bind(slots[i]))


func _title_of(p: Dictionary) -> Dictionary:
	if p.is_empty():
		return {}
	if p["playerId"] == _me:
		return PlayerState.equipped_title()
	if str(p["titleId"]) == "":
		return {}
	return TitleModel.find(PlayerState.titles, str(p["titleId"]))


func _maybe_go() -> void:
	if _snapshot == null or _found_for < MatchmakingModel.reveal_sec() or _leaving or offline_preview:
		return
	_leaving = true
	Router.match_snapshot = _snapshot
	Router.match_roster = {}
	for card in _cards:
		var p: Dictionary = card.player()
		if not p.is_empty():
			Router.match_roster[p["playerId"]] = p
	Router.go(Router.MATCH)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		cancel()
