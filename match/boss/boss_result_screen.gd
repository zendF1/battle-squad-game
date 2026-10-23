extends Control
## The boss match's end screen (the result screen flow: shown RESULT_DELAY_SEC after MatchEnded,
## the same signals and buttons as match/result_screen.gd): the lobby backdrop; the title of how
## it ended slamming in ("CHIẾN THẮNG" gold with confetti, as any match's win, "Cả đội đã gục" / "Boss đã trốn
## thoát" grey-blue with rain) over "<boss> · Vòng 9/15"; left, "BẢNG SÁT THƯƠNG": the party's
## damage to the boss, most first, each row the player's head, name (mine gold), "Máy" for a bot,
## a bar filling to its share of the top damage and the number counting up, MVP marked; right, the
## boss's figure (fallen and greyed when beaten) with its HP left. Bottom left my rewards card:
## the run's table badge ("Lượt thưởng lớn" gold / "Thưởng thường" grey) with "Còn x lượt thưởng
## lớn hôm nay", +EXP with its bar, +xu, my damage to the boss, and the items won (icons and names
## from the game data); a level up opens the "LÊN CẤP!" popup after the EXP. Bottom right "Chơi
## tiếp" (the same boss's queue again; not for the party's member), "Về sảnh" (the party kept) and
## "Tự động về sảnh sau N giây".
##
## setup(info) before it enters the tree: BossResultModel.info() plus exp ({level, exp} before the
## match, {} unknown), char_name, character_id, again ("" none).

signal home_pressed
signal again_pressed

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const ResultModel := preload("res://match/result_model.gd")
const BossResultModel := preload("res://match/boss/boss_result_model.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")
const LevelUpPopup := preload("res://match/level_up_popup.gd")
const Fmt := preload("res://core/fmt.gd")

const GOLD := Color(1.0, 0.8, 0.22)
const LOSE_TITLE := Color(0.62, 0.72, 0.9)
const BAR_W := 380.0
const ROW_H := 84.0
const BOTTOM_H := 200.0
const RIGHT_W := 330.0
const CONFETTI := [Color(1.0, 0.8, 0.22), Color(0.35, 0.75, 1.0), Color(1.0, 0.42, 0.6), Color(0.45, 0.9, 0.55), Color(0.75, 0.5, 1.0)]

var info := {}

var _title: Label
var _sub: Label
var _rank_panel: PanelContainer
var _rows: Array = [] # [{bar: ProgressBar, value: Label, damage: int, ratio: float, node: Control}]
var _boss_box: Control
var _boss_art: Control
var _bottom: Control
var _card_clip: Control
var _right: VBoxContainer
var _again: Button
var _home: Button
var _countdown: Label
var _exp_value: Label
var _exp_bar: ProgressBar
var _coin_value: Label
var _fx: Control
var _particles: Array = []
var _left_sec := float(ResultModel.AUTO_EXIT_SEC)
var _counting := true
var _popup_open := false


func setup(value: Dictionary) -> void:
	info = value


func _win() -> bool:
	return str(info.get("outcome", "")) == ResultModel.WIN


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	theme = LobbyUi.theme()
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.1, 0.35 if _win() else 0.5)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	_title = LobbyUi.text(str(info.get("title", "")), 84, GOLD if _win() else LOSE_TITLE, true)
	_title.name = "Title"
	_title.add_theme_constant_override("outline_size", 20)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_title.add_theme_constant_override("shadow_offset_y", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_title)
	var boss: Dictionary = info.get("boss", {})
	var sub_parts := PackedStringArray([str(boss.get("name", ""))])
	if str(info.get("round_text", "")) != "":
		sub_parts.append(str(info["round_text"]))
	_sub = LobbyUi.text(" · ".join(sub_parts), 28, Color(0.85, 0.92, 1.0), true)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_sub)
	_rank_panel = _build_ranking()
	add_child(_rank_panel)
	_boss_box = _build_boss(boss)
	add_child(_boss_box)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_fx.mouse_filter = MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_bottom = _build_bottom()
	add_child(_bottom)
	resized.connect(_layout)
	_layout()
	for i in (90 if _win() else 130):
		_particles.append(_particle(true))
	_animate()


func _layout() -> void:
	_title.position = Vector2(0, 14)
	_title.size = Vector2(size.x, 110)
	_title.pivot_offset = _title.size / 2.0
	_sub.position = Vector2(0, 118)
	_sub.size = Vector2(size.x, 40)
	var top := 172.0
	var avail := size.y - BOTTOM_H - 32.0 - top
	_rank_panel.position = Vector2(40, top)
	_rank_panel.size = Vector2(minf(size.x * 0.56, 860.0), 0)
	_boss_box.size = Vector2(minf(size.x * 0.36, 520.0), avail)
	_boss_box.position = Vector2(size.x - _boss_box.size.x - 40, top)
	_bottom.position = Vector2(24, size.y - BOTTOM_H - 16)
	_bottom.size = Vector2(size.x - 48, BOTTOM_H)
	_right.position = Vector2(_bottom.size.x - RIGHT_W, 0)
	_right.size = Vector2(RIGHT_W, BOTTOM_H)
	_card_clip.position = Vector2.ZERO
	_card_clip.size = Vector2(_bottom.size.x - RIGHT_W - 24, BOTTOM_H)
	(_card_clip.get_child(0) as Control).size = _card_clip.size


# ── Ranking ─────────────────────────────────────────────────────────────────

func _build_ranking() -> PanelContainer:
	var panel := LobbyUi.panel(18, 22)
	panel.name = "Ranking"
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var col := Ui.vbox(8)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var head := LobbyUi.text("BẢNG SÁT THƯƠNG", 22, Ui.TEXT_DIM, true)
	head.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(head)
	var n := 0
	for r in info.get("ranking", []):
		n += 1
		col.add_child(_row(r, n))
	return panel


func _row(r: Dictionary, place: int) -> Control:
	var row := Ui.hbox(14)
	row.custom_minimum_size.y = ROW_H
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var num := LobbyUi.text(str(place), 34, GOLD if place == 1 else Color(0.8, 0.86, 1.0), true)
	num.custom_minimum_size.x = 34
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(num)
	var head := HeadIcon.make(str(r["characterId"]), str(r["displayName"]), 64)
	head.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(head)
	var col := Ui.vbox(4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(col)
	var line := Ui.hbox(10)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(line)
	var name_label := LobbyUi.text(str(r["displayName"]), 26, GOLD.lightened(0.3) if r["mine"] else Color.WHITE, true)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 160
	line.add_child(name_label)
	if r["isBot"]:
		line.add_child(_chip("Máy", Color(0.3, 0.34, 0.5), Color.WHITE))
	if r["mine"]:
		line.add_child(_chip("BẠN", Color(0.22, 0.48, 0.92), Color.WHITE))
	if r["mvp"]:
		var mvp := _chip("MVP", GOLD, LobbyUi.TEXT_DARK)
		mvp.name = "Mvp"
		line.add_child(mvp)
	var bar_row := Ui.hbox(12)
	bar_row.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(bar_row)
	var bar := Ui.bar(0.0, 18)
	bar.custom_minimum_size = Vector2(BAR_W, 18)
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	var fill := GOLD if r["mvp"] else (Color(0.4, 0.75, 1.0) if r["mine"] else Color(0.95, 0.45, 0.35))
	bar.add_theme_stylebox_override("fill", LobbyUi.box(fill, 9, 0))
	bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.45), 9, 0, Color(1, 1, 1, 0.15), 1))
	bar_row.add_child(bar)
	var value := LobbyUi.text("0", 24, Color.WHITE, true)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_row.add_child(value)
	_rows.append({"bar": bar, "value": value, "damage": int(r["damage"]), "ratio": float(r["ratio"]), "node": row})
	return row


static func _chip(text: String, bg: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", LobbyUi.box(bg, 10, 0))
	p.size_flags_vertical = SIZE_SHRINK_CENTER
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var l := LobbyUi.text(text, 18, fg, true)
	if fg == LobbyUi.TEXT_DARK:
		l.add_theme_constant_override("outline_size", 0)
	l.custom_minimum_size = Vector2(0, 28)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.mouse_filter = MOUSE_FILTER_IGNORE
	m.add_child(l)
	p.add_child(m)
	return p


# ── Boss ────────────────────────────────────────────────────────────────────

func _build_boss(boss: Dictionary) -> Control:
	var box := Control.new()
	box.name = "Boss"
	box.mouse_filter = MOUSE_FILTER_IGNORE
	_boss_art = BossArtView.make(str(boss.get("art", BossArt.GENERIC_BOSS)), Vector2(420, 330), -1)
	box.add_child(_boss_art)
	if str(info.get("result", "")) == BossResultModel.DEFEATED:
		_boss_art.modulate = Color(0.55, 0.55, 0.62, 0.85)
		_boss_art.idle = false
	var col := Ui.vbox(6)
	col.name = "BossHp"
	col.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(col)
	var cap := LobbyUi.text("Máu boss còn lại", 20, Ui.TEXT_DIM, true)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var bar := Ui.bar(float(boss.get("ratio", 0.0)), 22)
	bar.custom_minimum_size = Vector2(380, 22)
	bar.size_flags_horizontal = SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", LobbyUi.box(Color(0.92, 0.25, 0.2), 11, 0))
	bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.5), 11, 0, Color(1, 1, 1, 0.2), 1))
	col.add_child(bar)
	var hp := LobbyUi.text(str(boss.get("hp_text", "")), 24, Color.WHITE, true)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hp)
	box.resized.connect(func() -> void:
		var art_h := maxf(box.size.y - 96.0, 120.0)
		_boss_art.size = Vector2(box.size.x, art_h)
		_boss_art.position = Vector2.ZERO
		if str(info.get("result", "")) == BossResultModel.DEFEATED:
			_boss_art.pivot_offset = Vector2(box.size.x / 2.0, art_h)
			_boss_art.rotation = deg_to_rad(10.0)
		col.position = Vector2(0, art_h + 6.0)
		col.size = Vector2(box.size.x, 90))
	return box


# ── Rewards and buttons ─────────────────────────────────────────────────────

func _build_bottom() -> Control:
	var bar := Control.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	_card_clip = Control.new()
	_card_clip.clip_contents = true
	_card_clip.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(_card_clip)
	var card := LobbyUi.panel(0, 22)
	card.name = "Rewards"
	_card_clip.add_child(card)
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 14 if side in ["top", "bottom"] else 24)
	card.add_child(inner)
	var col := Ui.vbox(8)
	inner.add_child(col)
	var reward: Dictionary = info.get("reward", {})
	var head := Ui.hbox(12)
	col.add_child(head)
	head.add_child(LobbyUi.text("PHẦN THƯỞNG", 20, Ui.TEXT_DIM, true))
	if reward.get("ok", false):
		var bonus: bool = reward.get("bonus_run", false)
		var badge := _chip(str(reward.get("badge", "")), GOLD if bonus else Color(0.36, 0.4, 0.55), LobbyUi.TEXT_DARK if bonus else Color.WHITE)
		badge.name = "RunBadge"
		head.add_child(badge)
		var left := str(reward.get("left_text", ""))
		if left != "":
			head.add_child(LobbyUi.text(left, 20, Color(0.85, 0.92, 1.0), true))
	if not reward.get("ok", false):
		col.add_child(LobbyUi.text("Chưa lấy được phần thưởng của trận này", 24, Color.WHITE, true))
		return _finish_bottom(bar)
	var row := Ui.hbox(26)
	col.add_child(row)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", LobbyUi.box(Color(0.22, 0.48, 0.92), 10, 0))
	tag.size_flags_vertical = SIZE_SHRINK_CENTER
	var tag_text := LobbyUi.text("EXP", 18, Color.WHITE, true)
	tag_text.custom_minimum_size = Vector2(56, 28)
	tag_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.add_child(tag_text)
	var exp_row := Ui.hbox(10)
	exp_row.add_child(tag)
	_exp_bar = Ui.bar(0.0, 16)
	_exp_bar.custom_minimum_size = Vector2(180, 16)
	_exp_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	_exp_bar.add_theme_stylebox_override("fill", LobbyUi.box(LobbyUi.GOLD, 8, 0))
	_exp_bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.45), 8, 0, Color(1, 1, 1, 0.15), 1))
	_exp_bar.visible = not info.get("exp", {}).is_empty()
	exp_row.add_child(_exp_bar)
	_exp_value = LobbyUi.text("+0 EXP", 28, Color.WHITE, true)
	exp_row.add_child(_exp_value)
	row.add_child(exp_row)
	var coin_row := Ui.hbox(8)
	row.add_child(coin_row)
	_coin_value = LobbyUi.icon_text(coin_row, "coin", "+0 xu", 28, Color.WHITE, true, 36)
	var dmg := LobbyUi.text(str(reward.get("damage_text", "")), 24, Color(1.0, 0.7, 0.55), true)
	dmg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(dmg)
	var items := Ui.hbox(18)
	items.name = "Items"
	col.add_child(items)
	var list: Array = reward.get("items", [])
	if list.is_empty():
		items.add_child(LobbyUi.text("Không rơi vật phẩm", 20, Ui.TEXT_DIM))
	for it in list:
		var one := Ui.hbox(6)
		var icon := LobbyUi.icon(Art.item_icon(str(it["itemId"])), 44)
		one.add_child(icon)
		var l := LobbyUi.text("%s ×%d" % [it["name"], int(it["qty"])], 22, Color.WHITE, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		one.add_child(l)
		items.add_child(one)
	return _finish_bottom(bar)


func _finish_bottom(bar: Control) -> Control:
	_right = Ui.vbox(8)
	_right.alignment = BoxContainer.ALIGNMENT_END
	bar.add_child(_right)
	var again_text := str(info.get("again", ""))
	if again_text != "":
		_again = LobbyUi.start_button(again_text)
		_again.name = "Again"
		_again.custom_minimum_size.y = 78
		_again.pressed.connect(func() -> void:
			_counting = false
			again_pressed.emit())
		_right.add_child(_again)
		_home = LobbyUi.pill_button("Về sảnh", 26, 56, "back")
		LobbyUi.texture_button(_home, "button_navy", 18)
	else:
		_home = LobbyUi.start_button("Về sảnh")
		_home.custom_minimum_size.y = 78
	_home.name = "Home"
	_home.pressed.connect(func() -> void:
		_counting = false
		home_pressed.emit())
	_right.add_child(_home)
	_countdown = LobbyUi.text(ResultModel.countdown_text(ResultModel.AUTO_EXIT_SEC), 20, Ui.TEXT_DIM, true)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right.add_child(_countdown)
	return bar


## A status under the buttons ("Đang tạo trận...", an error); busy locks the buttons.
func set_status(text: String, busy: bool) -> void:
	_countdown.text = text
	_countdown.add_theme_color_override("font_color", Color.WHITE if busy else Ui.TONES["error"])
	if _again != null:
		_again.disabled = busy
	_home.disabled = busy


# ── Animation ───────────────────────────────────────────────────────────────

func _animate() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_title.scale = Vector2.ONE * 2.2
	_title.modulate.a = 0.0
	var slam := create_tween()
	slam.tween_interval(0.15)
	slam.tween_property(_title, "modulate:a", 1.0, 0.12)
	slam.parallel().tween_property(_title, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var node: Control = r["node"]
		node.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.4 + i * 0.15)
		t.tween_property(node, "modulate:a", 1.0, 0.2)
		t.tween_property(r["bar"], "value", float(r["ratio"]), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var value: Label = r["value"]
		t.parallel().tween_method(func(v: float) -> void: value.text = Fmt.thousands(roundi(v)), 0.0, float(r["damage"]), 0.6)
	_bottom.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_interval(0.7)
	reveal.tween_property(_bottom, "modulate:a", 1.0, 0.25)
	var reward: Dictionary = info.get("reward", {})
	if not reward.get("ok", false):
		return
	var steps := {}
	var before: Dictionary = info.get("exp", {})
	if not before.is_empty():
		steps = ResultModel.exp_steps(int(before["level"]), int(before["exp"]), int(reward["exp"]))
		_exp_bar.value = steps["from"]
	reveal.tween_method(func(v: float) -> void: _exp_value.text = "+%s EXP" % Fmt.thousands(roundi(v)), 0.0, float(reward["exp"]), 0.7)
	if not steps.is_empty():
		reveal.parallel().tween_property(_exp_bar, "value", steps["to"] if steps["levels"] == 0 else 1.0, 0.7)
	reveal.tween_method(func(v: float) -> void: _coin_value.text = "+%s xu" % Fmt.thousands(roundi(v)), 0.0, float(reward["coin"]), 0.5)
	reveal.tween_callback(_level_up)


func _level_up() -> void:
	var stages := ResultModel.level_ups(info.get("reward", {}), info.get("exp", {}), str(info.get("character_id", "")),
		str(info.get("char_name", "")))
	if stages.is_empty():
		return
	var popup = LevelUpPopup.new()
	popup.setup(stages)
	_popup_open = true
	popup.closed.connect(func() -> void: _popup_open = false)
	add_child(popup)


func _particle(anywhere: bool) -> Dictionary:
	var w := maxf(size.x, 1600.0)
	var h := maxf(size.y, 900.0)
	if _win():
		return {"p": Vector2(randf() * w, (randf() * h if anywhere else -20.0) - h * 0.3), "v": Vector2(randf_range(-30, 30), randf_range(70, 150)),
			"a": randf() * TAU, "spin": randf_range(-6, 6), "c": CONFETTI[randi() % CONFETTI.size()], "s": randf_range(8, 15)}
	return {"p": Vector2(randf() * (w + 200) - 100, randf() * h if anywhere else -30.0), "v": Vector2(-90, randf_range(650, 900)),
		"a": 0.0, "spin": 0.0, "c": Color(0.7, 0.8, 1.0, randf_range(0.18, 0.38)), "s": randf_range(18, 34)}


func _draw_fx() -> void:
	for q in _particles:
		if _win():
			_fx.draw_set_transform(q["p"], q["a"], Vector2.ONE)
			_fx.draw_rect(Rect2(-q["s"] / 2.0, -q["s"] / 4.0, q["s"], q["s"] / 2.0), q["c"])
		else:
			_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_fx.draw_line(q["p"], q["p"] + q["v"].normalized() * q["s"], q["c"], 2.0, true)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _process(delta: float) -> void:
	for i in _particles.size():
		var q: Dictionary = _particles[i]
		q["p"] += q["v"] * delta
		q["a"] += q["spin"] * delta
		if q["p"].y > size.y + 40:
			_particles[i] = _particle(false)
	_fx.queue_redraw()
	if _counting and not _popup_open:
		var before := ceili(_left_sec)
		_left_sec -= delta
		if ceili(_left_sec) != before:
			_countdown.text = ResultModel.countdown_text(ceili(_left_sec))
		if _left_sec <= 0.0:
			_counting = false
			home_pressed.emit()
