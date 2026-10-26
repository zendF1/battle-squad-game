extends Control
## The boss match's end screen (the result screen flow: shown RESULT_DELAY_SEC after MatchEnded,
## the same signals and buttons as match/result_screen.gd): the result background (result.png); the title of how
## it ended slamming in ("CHIẾN THẮNG" gold with confetti, as any match's win, "Cả đội đã gục" /
## "Boss đã trốn thoát" grey-blue with rain) over "<boss> · Vòng 9/15" (a loss adds the boss's HP
## left, BossResultModel.subtitle()); dead centre the PvP result's podium under its spotlight
## (ResultScreen.podium_block()): a step per party player (bots too) ranked by their damage to the
## boss, left to right #3, #1, #2, #4 (BossResultModel.podium(): #1 tallest, #4 lowest), the rank
## on each step's face, each player standing on theirs in full pose (ui/character_view.gd) under
## their name (mine gold) and damage, "MVP" on the best one as in PvP; they rise onto their steps
## from #4 to #1, the damage counting up. Bottom left my rewards card:
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
const CharacterView := preload("res://ui/character_view.gd")
const ResultScreen := preload("res://match/result_screen.gd")
const ResultModel := preload("res://match/result_model.gd")
const BossResultModel := preload("res://match/boss/boss_result_model.gd")
const LevelUpPopup := preload("res://match/level_up_popup.gd")
const Fmt := preload("res://core/fmt.gd")

const GOLD := Color(1.0, 0.8, 0.22)
const LOSE_TITLE := Color(0.62, 0.72, 0.9)
const SLOT_W := 240.0
const SLOT_GAP := 20.0
const ART_H := 250.0
const HEAD_H := 72.0 # the name and the damage over the figure
const PODIUM_MARGIN := 40.0 # px the outer steps reach past their figures
const BOTTOM_H := 200.0
const RIGHT_W := 330.0
const CONFETTI := [Color(1.0, 0.8, 0.22), Color(0.35, 0.75, 1.0), Color(1.0, 0.42, 0.6), Color(0.45, 0.9, 0.55), Color(0.75, 0.5, 1.0)]

var info := {}

var _title: Label
var _sub: Label
var _stage: Control # the spotlight and the podium (drawn), under the figures
var _slots: Array = [] # left to right: [{node: Control, value: Label, damage, rank, step_h}]
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
	var bg := Backdrop.new() # result.png; the shade, the confetti / rain on top
	bg.show_image(Art.BG_RESULT, false)
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
	_sub = LobbyUi.text(BossResultModel.subtitle(info), 28, Color(0.85, 0.92, 1.0), true)
	_sub.name = "Subtitle"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_sub)
	_stage = Control.new()
	_stage.name = "Podium"
	_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	var steps: Array = info.get("podium", BossResultModel.podium(info.get("ranking", [])))
	for st in steps:
		_add_slot(st)
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
	var x0 := (size.x - _group_w()) / 2.0
	for i in _slots.size():
		var node: Control = _slots[i]["node"]
		node.position = Vector2(x0 + i * (SLOT_W + SLOT_GAP), _base_y() - float(_slots[i]["step_h"]) - ART_H - HEAD_H)
		node.set_meta("home_y", node.position.y)
	_bottom.position = Vector2(24, size.y - BOTTOM_H - 16)
	_bottom.size = Vector2(size.x - 48, BOTTOM_H)
	_right.position = Vector2(_bottom.size.x - RIGHT_W, 0)
	_right.size = Vector2(RIGHT_W, BOTTOM_H)
	_card_clip.position = Vector2.ZERO
	_card_clip.size = Vector2(_bottom.size.x - RIGHT_W - 24, BOTTOM_H)
	(_card_clip.get_child(0) as Control).size = _card_clip.size
	_stage.queue_redraw()


## The podium's floor: just above the bottom bar.
func _base_y() -> float:
	return size.y - BOTTOM_H - 34.0


func _group_w() -> float:
	return _slots.size() * SLOT_W + maxi(_slots.size() - 1, 0) * SLOT_GAP


# ── Podium ──────────────────────────────────────────────────────────────────

## One player on their step: the name (mine gold) and the damage over the figure, "MVP" as in PvP.
func _add_slot(st: Dictionary) -> void:
	var e: Dictionary = st["entry"]
	var slot := Control.new()
	slot.name = "Rank%d" % int(st["rank"])
	slot.size = Vector2(SLOT_W, HEAD_H + ART_H)
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	var head := Ui.vbox(0)
	head.position = Vector2(-20, 0)
	head.size = Vector2(SLOT_W + 40, HEAD_H)
	head.alignment = BoxContainer.ALIGNMENT_END
	head.mouse_filter = MOUSE_FILTER_IGNORE
	slot.add_child(head)
	var name_label := LobbyUi.text(str(e["displayName"]), 28, GOLD.lightened(0.35) if e["mine"] else Color.WHITE, true)
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	head.add_child(name_label)
	var value := LobbyUi.text("0", 26, Color(1.0, 0.72, 0.55), true)
	value.name = "Damage"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.mouse_filter = MOUSE_FILTER_IGNORE
	head.add_child(value)
	var art := CharacterView.new()
	art.character_id = str(e["characterId"])
	art.idle = true
	art.position = Vector2(0, HEAD_H)
	art.size = Vector2(SLOT_W, ART_H)
	slot.add_child(art)
	if e.get("mvp", false):
		var mvp := LobbyUi.text("MVP", 42, GOLD, true)
		mvp.name = "Mvp"
		mvp.add_theme_constant_override("outline_size", 12)
		mvp.add_theme_color_override("font_outline_color", Color(0.45, 0.12, 0.02))
		mvp.rotation = -0.3
		mvp.position = Vector2(-4, HEAD_H + 10)
		mvp.mouse_filter = MOUSE_FILTER_IGNORE
		slot.add_child(mvp)
	add_child(slot)
	_slots.append({"node": slot, "value": value, "damage": int(e["damage"]), "rank": int(st["rank"]), "step_h": float(st["step_h"])})


## The spotlight from above, the pool of light and the steps (the PvP podium's), the lower ones
## first, each with its rank on its face.
func _draw_stage() -> void:
	if _slots.is_empty():
		return
	var cx := size.x / 2.0
	var w := _group_w() + PODIUM_MARGIN * 2.0
	var base := _base_y()
	var top := base - BossResultModel.step_height(1)
	var light := 1.0 if _win() else 0.55
	var cone := PackedVector2Array([Vector2(cx - 90, -10), Vector2(cx + 90, -10), Vector2(cx + w * 0.55, top + 8), Vector2(cx - w * 0.55, top + 8)])
	_stage.draw_polygon(cone, PackedColorArray([Color(1, 1, 1, 0.2 * light), Color(1, 1, 1, 0.2 * light),
		Color(1, 0.95, 0.9, 0.05 * light), Color(1, 0.95, 0.9, 0.05 * light)]))
	ResultScreen.podium_glow(_stage, Vector2(cx, base - BossResultModel.step_height(_slots.size()) + 4), Vector2(w * 0.56, 34),
		Color(1, 0.9, 0.95, 0.22 * light))
	var x0 := cx - _group_w() / 2.0
	var blocks: Array = []
	for i in _slots.size():
		var sx := x0 + i * (SLOT_W + SLOT_GAP)
		var a := sx - (PODIUM_MARGIN if i == 0 else SLOT_GAP / 2.0)
		var b := sx + SLOT_W + (PODIUM_MARGIN if i == _slots.size() - 1 else SLOT_GAP / 2.0)
		var h: float = _slots[i]["step_h"]
		blocks.append([Rect2(a, base - h, b - a, h), int(_slots[i]["rank"])])
	blocks.sort_custom(func(p, q): return p[1] > q[1]) # #4 first, #1 over everything
	var font := LobbyUi.bold()
	for blk in blocks:
		var r: Rect2 = blk[0]
		ResultScreen.podium_block(_stage, r, false)
		var face_h := r.size.y - 14.0
		var fs := int(clampf(face_h * 0.8, 26.0, 52.0))
		var text := str(blk[1])
		var y := r.position.y + 14.0 + face_h / 2.0 + fs * 0.36
		var col := GOLD if int(blk[1]) == 1 else Color.WHITE
		_stage.draw_string_outline(font, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, 8,
			Color(0.3, 0.04, 0.2, 0.9))
		_stage.draw_string(font, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)


# ── Rewards and buttons ─────────────────────────────────────────────────────

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
	var order := range(_slots.size())
	order.sort_custom(func(a, b): return _slots[a]["rank"] > _slots[b]["rank"]) # #4 first, #1 last
	for k in order.size():
		var sl: Dictionary = _slots[order[k]]
		var node: Control = sl["node"]
		var y: float = node.get_meta("home_y", node.position.y)
		node.position.y = y + 90.0
		node.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.35 + k * 0.16)
		t.tween_property(node, "position:y", y, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(node, "modulate:a", 1.0, 0.25)
		var value: Label = sl["value"]
		t.tween_method(func(v: float) -> void: value.text = Fmt.thousands(roundi(v)), 0.0, float(sl["damage"]), 0.6)
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
