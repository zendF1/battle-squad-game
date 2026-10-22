extends Control
## The end-of-match screen (every mode; a cancelled match keeps the HUD's small panel): the
## lobby backdrop, "CHIẾN THẮNG" (gold, confetti over the winners) / "THẤT BẠI" (grey-blue, rain)
## / "HOÀ" slamming in at the top; the winning team on the left on a lit pink podium under a
## spotlight (two winners: one step each, the MVP's higher with a gold star; an MVP of the losing
## side: the winner with the most damage stands higher, ResultModel.podium_top()), the other team
## on the right, dimmed, on the ground (a draw: my team left, no podium); each player in full pose
## (ui/character_view.gd, bots too) on their own step under their title plate, the tier badge with
## the name (mine gold) and "Lv.N" / the damage dealt, "MVP" on the best one, "ĐỘI CỦA BẠN" /
## "ĐỐI THỦ" under each team. Bottom left my rewards card (its size never changes: what grew it
## is in the popups): "+N EXP" counting with its bar filling, "+N xu", a small gold chip by
## "PHẦN THƯỞNG" with the new levels after a level up, and for ranked the tier badge with
## "Điểm hạng a → b (+c)". One after another: the EXP, then "LÊN CẤP!" (match/level_up_popup.gd)
## when the player or the character levelled up, the coins, then the rank popup
## (match/rank_popup.gd) when the division or tier changed (the badge then flips to the new rank),
## else the rating line counting. Bottom right, always in place: "Chơi tiếp" (ranked) /
## "Chơi lại" (Quick Play), "Về sảnh" and "Tự động về sảnh sau N giây" (AUTO_EXIT_SEC, then
## home_pressed; paused while a popup is open). The players rise onto their places one by one
## after the title.
##
## setup(info) before it enters the tree: {outcome, left: [ResultModel.entry()], right, mvp,
## reward (ResultModel.reward()), exp: {level, exp} before the match ({} unknown: no bar),
## char_name, again ("" none)}.

signal home_pressed
signal again_pressed

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const CharacterView := preload("res://ui/character_view.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const TierBadge := preload("res://screens/ranked/tier_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const ResultModel := preload("res://match/result_model.gd")
const LevelUpPopup := preload("res://match/level_up_popup.gd")
const RankPopup := preload("res://match/rank_popup.gd")
const Fmt := preload("res://core/fmt.gd")

const SLOT_W := 250.0
const SLOT_GAP := 24.0
const ART_H := 270.0
const HEAD_H := 136.0 # title plate, name row, level line, damage line over the figure
const PODIUM_H := 64.0
const STEP_LOW_H := 48.0 # two winners: the lower step and the top one
const STEP_TOP_H := 90.0
const RIGHT_W := 330.0 # the buttons' column
const BOTTOM_H := 184.0
const GOLD := Color(1.0, 0.8, 0.22)
const LOSE_TITLE := Color(0.62, 0.72, 0.9)
const DIM := Color(0.6, 0.62, 0.76)
const PINK_TOP := Color(1.0, 0.6, 0.8)
const PINK := Color(0.9, 0.3, 0.6)
const PINK_DARK := Color(0.42, 0.08, 0.32)
const CONFETTI := [Color(1.0, 0.8, 0.22), Color(0.35, 0.75, 1.0), Color(1.0, 0.42, 0.6), Color(0.45, 0.9, 0.55), Color(0.75, 0.5, 1.0)]

var info := {}

var _stage: Control # spotlight + podium (drawn), under the figures
var _fx: Control # confetti / rain, over everything but the bottom bar
var _title: Label
var _slots: Array = [] # [{node, entry, left}]
var _team_labels: Array = []
var _bottom: Control
var _again: Button
var _home: Button
var _countdown: Label
var _left_sec := float(ResultModel.AUTO_EXIT_SEC)
var _counting := true
var _particles: Array = []
var _exp_value: Label
var _exp_bar: ProgressBar
var _coin_value: Label
var _level_chip: PanelContainer
var _level_chip_text: Label
var _card_clip: Control
var _card: Control
var _right: Control
var _rank_badge: TierBadge
var _rank_line: Label
var _popup_open := false
var _top_id := "" # the winner on the podium's top step


func setup(value: Dictionary) -> void:
	info = value


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP # the match under it takes no input any more
	theme = LobbyUi.theme()
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.1, 0.35 if _outcome() != ResultModel.LOSE else 0.5)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(shade)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_stage.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	if _podium():
		_top_id = ResultModel.podium_top(info.get("left", []), str(info.get("mvp", "")))
	for e in info.get("left", []):
		_add_slot(e, true)
	for e in info.get("right", []):
		_add_slot(e, false)
	for side in [true, false]:
		var ids: Array = info.get("left" if side else "right", [])
		var mine := ids.any(func(e): return e["mine"])
		var l := LobbyUi.text("ĐỘI CỦA BẠN" if mine else "ĐỐI THỦ", 24, Color(0.55, 0.78, 1.0) if mine else Color(1.0, 0.6, 0.6), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = MOUSE_FILTER_IGNORE
		l.set_meta("left", side)
		add_child(l)
		_team_labels.append(l)
	_title = LobbyUi.text(ResultModel.title_text(_outcome()), 104, GOLD if _outcome() != ResultModel.LOSE else LOSE_TITLE, true)
	_title.add_theme_constant_override("outline_size", 22)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_title.add_theme_constant_override("shadow_offset_y", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_title)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_fx.mouse_filter = MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_bottom = _build_bottom()
	add_child(_bottom)
	resized.connect(_layout)
	_layout()
	_seed_particles()
	_animate()


func _outcome() -> String:
	return str(info.get("outcome", ResultModel.DRAW))


func _podium() -> bool:
	return _outcome() != ResultModel.DRAW


# ── Layout ──────────────────────────────────────────────────────────────────

func _base_y() -> float:
	return size.y - 270.0 # above the bottom bar


func _floor_y(left: bool) -> float:
	return _base_y() - PODIUM_H if left and _podium() else _base_y()


## Where a player stands: their step's top (two winners: the top step or the lower one).
func _slot_floor(s: Dictionary) -> float:
	if not s["left"] or _top_id == "":
		return _floor_y(s["left"])
	return _base_y() - (STEP_TOP_H if s["entry"]["playerId"] == _top_id else STEP_LOW_H)


func _group_x(left: bool) -> float:
	return size.x * (0.29 if left else 0.71)


func _group_w(n: int) -> float:
	return n * SLOT_W + maxi(n - 1, 0) * SLOT_GAP


func _layout() -> void:
	_title.position = Vector2(0, 18)
	_title.size = Vector2(size.x, 140)
	_title.pivot_offset = _title.size / 2.0
	for side in [true, false]:
		var group: Array = _slots.filter(func(s): return s["left"] == side)
		var w := _group_w(group.size())
		for i in group.size():
			var node: Control = group[i]["node"]
			var x := _group_x(side) - w / 2.0 + i * (SLOT_W + SLOT_GAP)
			node.position = Vector2(x, _slot_floor(group[i]) - ART_H - HEAD_H)
			node.set_meta("home_y", node.position.y)
	for l in _team_labels:
		var left: bool = l.get_meta("left")
		l.size = Vector2(_group_w(maxi(1, _slots.filter(func(s): return s["left"] == left).size())), 36)
		var on_podium := left and _podium() and _top_id == "" # one step: the name on its front
		l.position = Vector2(_group_x(left) - l.size.x / 2.0, (_floor_y(left) + 14.0) if on_podium else _base_y() + 8.0)
	_bottom.position = Vector2(24, size.y - BOTTOM_H - 16)
	_bottom.size = Vector2(size.x - 48, BOTTOM_H)
	_right.position = Vector2(_bottom.size.x - RIGHT_W, 0)
	_right.size = Vector2(RIGHT_W, BOTTOM_H)
	_card_clip.position = Vector2.ZERO
	_card_clip.size = Vector2(_bottom.size.x - RIGHT_W - 24, BOTTOM_H)
	_card.position = Vector2.ZERO
	_card.size = _card_clip.size
	_stage.queue_redraw()


func _add_slot(e: Dictionary, left: bool) -> void:
	var slot := Control.new()
	slot.size = Vector2(SLOT_W, HEAD_H + ART_H)
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	var dim := not left and _outcome() != ResultModel.DRAW
	var head := Ui.vbox(0)
	head.position = Vector2(-20, 0)
	head.size = Vector2(SLOT_W + 40, HEAD_H)
	head.alignment = BoxContainer.ALIGNMENT_END
	head.mouse_filter = MOUSE_FILTER_IGNORE
	slot.add_child(head)
	var plate := TitlePlate.new()
	plate.plate_height = 34
	plate.max_width = SLOT_W + 20
	plate.size_flags_horizontal = SIZE_SHRINK_CENTER
	plate.set_title(e["title"])
	plate.mouse_filter = MOUSE_FILTER_IGNORE
	head.add_child(plate)
	var row := Ui.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	head.add_child(row)
	if str(e["tier"]) != "":
		row.add_child(TierBadge.make(e["tier"], e["division"], 44))
	var name_label := LobbyUi.text(str(e["displayName"]), 28, GOLD.lightened(0.35) if e["mine"] else Color.WHITE, true)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	for t in [[ResultModel.level_text(e), 21, LobbyUi.GOLD], [ResultModel.damage_text(int(e["damage"])), 18, Color(0.82, 0.88, 1.0)]]:
		var sub := LobbyUi.text(t[0], t[1], t[2], true)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.mouse_filter = MOUSE_FILTER_IGNORE
		sub.visible = t[0] != ""
		head.add_child(sub)
	var art := CharacterView.new()
	art.character_id = str(e["characterId"])
	art.idle = true
	art.position = Vector2(0, HEAD_H)
	art.size = Vector2(SLOT_W, ART_H)
	if dim:
		art.modulate = DIM
	slot.add_child(art)
	if info.get("mvp", "") == e["playerId"]:
		var mvp := LobbyUi.text("MVP", 42, GOLD, true)
		mvp.add_theme_constant_override("outline_size", 12)
		mvp.add_theme_color_override("font_outline_color", Color(0.45, 0.12, 0.02))
		mvp.rotation = -0.3
		mvp.position = Vector2(-4, HEAD_H + 10)
		mvp.mouse_filter = MOUSE_FILTER_IGNORE
		slot.add_child(mvp)
	if dim:
		head.modulate = Color(0.85, 0.87, 0.95)
	add_child(slot)
	_slots.append({"node": slot, "entry": e, "left": left})


## The rewards card (left) and the buttons with the countdown (right), each placed by _layout():
## the card is clipped to its place, so nothing in it can push or cover the buttons.
func _build_bottom() -> Control:
	var bar := Control.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	_card_clip = Control.new()
	_card_clip.clip_contents = true
	_card_clip.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(_card_clip)
	var card := LobbyUi.panel(0, 22)
	_card = card
	_card_clip.add_child(card)
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 16 if side in ["top", "bottom"] else 26)
	card.add_child(inner)
	var row := Ui.hbox(36)
	inner.add_child(row)
	var reward: Dictionary = info.get("reward", {})
	var col := Ui.vbox(8)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var head := Ui.hbox(12)
	col.add_child(head)
	head.add_child(LobbyUi.text("PHẦN THƯỞNG", 20, Ui.TEXT_DIM, true))
	_level_chip = PanelContainer.new()
	_level_chip.add_theme_stylebox_override("panel", LobbyUi.box(GOLD, 12, 0, Color(0.45, 0.2, 0.02), 2))
	_level_chip.size_flags_vertical = SIZE_SHRINK_CENTER
	_level_chip.visible = false
	var chip_row := Ui.hbox(4)
	var chip_margin := MarginContainer.new()
	for side in ["left", "right"]:
		chip_margin.add_theme_constant_override("margin_" + side, 10)
	chip_margin.add_child(chip_row)
	_level_chip.add_child(chip_margin)
	chip_row.add_child(LobbyUi.icon("upgrade", 20))
	_level_chip_text = Ui.text("", 18, LobbyUi.TEXT_DARK)
	_level_chip_text.add_theme_font_override("font", LobbyUi.bold())
	_level_chip_text.clip_text = true
	_level_chip_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip_row.add_child(_level_chip_text)
	head.add_child(_level_chip)
	if not reward.get("ok", false):
		col.add_child(LobbyUi.text("Chưa lấy được phần thưởng của trận này", 24, Color.WHITE, true))
	else:
		var exp_row := Ui.hbox(12)
		col.add_child(exp_row)
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", LobbyUi.box(Color(0.22, 0.48, 0.92), 10, 0))
		tag.size_flags_vertical = SIZE_SHRINK_CENTER
		var tag_text := LobbyUi.text("EXP", 18, Color.WHITE, true)
		tag_text.custom_minimum_size = Vector2(56, 28)
		tag_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.add_child(tag_text)
		exp_row.add_child(tag)
		_exp_bar = Ui.bar(0.0, 16)
		_exp_bar.custom_minimum_size = Vector2(240, 16)
		_exp_bar.size_flags_vertical = SIZE_SHRINK_CENTER
		_exp_bar.add_theme_stylebox_override("fill", LobbyUi.box(LobbyUi.GOLD, 8, 0))
		_exp_bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.45), 8, 0, Color(1, 1, 1, 0.15), 1))
		_exp_bar.visible = not info.get("exp", {}).is_empty()
		exp_row.add_child(_exp_bar)
		_exp_value = LobbyUi.text("+0 EXP", 28, Color.WHITE, true)
		_exp_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		exp_row.add_child(_exp_value)
		var coin_row := Ui.hbox(18)
		col.add_child(coin_row)
		_coin_value = LobbyUi.icon_text(coin_row, "coin", "+0 xu", 28, Color.WHITE, true, 36)
	var rank: Dictionary = reward.get("rank", {})
	if not rank.is_empty():
		var sep := ColorRect.new()
		sep.color = Color(1, 1, 1, 0.12)
		sep.custom_minimum_size = Vector2(2, 0)
		row.add_child(sep)
		var rank_row := Ui.hbox(16)
		rank_row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(rank_row)
		_rank_badge = TierBadge.make(rank["old_rank"][0], rank["old_rank"][1], 92)
		_rank_badge.size_flags_vertical = SIZE_SHRINK_CENTER
		rank_row.add_child(_rank_badge)
		var texts := Ui.vbox(2)
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		rank_row.add_child(texts)
		texts.add_child(LobbyUi.text("XẾP HẠNG", 20, Ui.TEXT_DIM, true))
		_rank_line = LobbyUi.text(RankModel.rating_line(rank, rank["old"]), 28, Color.WHITE, true)
		texts.add_child(_rank_line)
	var right := Ui.vbox(8)
	right.alignment = BoxContainer.ALIGNMENT_END
	_right = right
	bar.add_child(right)
	var again_text := str(info.get("again", ""))
	if again_text != "":
		_again = LobbyUi.start_button(again_text)
		_again.custom_minimum_size.y = 78
		_again.pressed.connect(func() -> void:
			_counting = false
			again_pressed.emit())
		right.add_child(_again)
		_home = LobbyUi.pill_button("Về sảnh", 26, 56, "back")
		LobbyUi.texture_button(_home, "button_navy", 18)
	else:
		_home = LobbyUi.start_button("Về sảnh")
		_home.custom_minimum_size.y = 78
	_home.pressed.connect(func() -> void:
		_counting = false
		home_pressed.emit())
	right.add_child(_home)
	_countdown = LobbyUi.text(ResultModel.countdown_text(ResultModel.AUTO_EXIT_SEC), 20, Ui.TEXT_DIM, true)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_countdown)
	return bar


## A status under the buttons ("Đang tạo trận...", an error); busy locks the buttons.
func set_status(text: String, busy: bool) -> void:
	_countdown.text = text
	_countdown.add_theme_color_override("font_color", Color.WHITE if busy else Ui.TONES["error"])
	if _again != null:
		_again.disabled = busy
	_home.disabled = busy


# ── Drawing ─────────────────────────────────────────────────────────────────

func _draw_stage() -> void:
	if not _podium():
		return
	var left: Array = _slots.filter(func(s): return s["left"])
	var n := maxi(1, left.size())
	var cx := _group_x(true)
	var w := _group_w(n) + 90.0
	var base := _base_y()
	var top := base - (STEP_TOP_H if _top_id != "" else PODIUM_H)
	var light := 1.0 if _outcome() == ResultModel.WIN else 0.55
	# the spotlight from above, a pool of light on the podium
	var cone := PackedVector2Array([Vector2(cx - 70, -10), Vector2(cx + 70, -10), Vector2(cx + w * 0.55, top + 8), Vector2(cx - w * 0.55, top + 8)])
	_stage.draw_polygon(cone, PackedColorArray([Color(1, 1, 1, 0.2 * light), Color(1, 1, 1, 0.2 * light), Color(1, 0.95, 0.9, 0.05 * light), Color(1, 0.95, 0.9, 0.05 * light)]))
	if _top_id == "":
		_ellipse(Vector2(cx, top + 4), Vector2(w * 0.56, 30), Color(1, 0.9, 0.95, 0.22 * light))
		_block(Rect2(cx - w / 2.0, top, w, PODIUM_H), false)
		return
	# two winners: a step each, the lower first, the top one over it
	_ellipse(Vector2(cx, base - STEP_LOW_H + 4), Vector2(w * 0.56, 30), Color(1, 0.9, 0.95, 0.22 * light))
	var x0 := cx - _group_w(left.size()) / 2.0
	var blocks: Array = []
	for i in left.size():
		var sx := x0 + i * (SLOT_W + SLOT_GAP)
		var a := sx - (45.0 if i == 0 else SLOT_GAP / 2.0)
		var b := sx + SLOT_W + (45.0 if i == left.size() - 1 else SLOT_GAP / 2.0)
		var top_step: bool = left[i]["entry"]["playerId"] == _top_id
		var h := STEP_TOP_H if top_step else STEP_LOW_H
		blocks.append([Rect2(a, base - h, b - a, h), top_step])
	blocks.sort_custom(func(p, q): return not p[1] and q[1])
	for blk in blocks:
		_block(blk[0], blk[1])


## One podium step: its top, the front with light bars, the glowing edge; the top step a gold
## star on its front.
func _block(r: Rect2, star: bool) -> void:
	var w := r.size.x
	var top := r.position.y
	var face := PackedVector2Array([r.position + Vector2(0, 14), r.position + Vector2(w, 14), r.end, Vector2(r.position.x, r.end.y)])
	_stage.draw_polygon(face, PackedColorArray([PINK, PINK, PINK_DARK, PINK_DARK]))
	for x in [r.position.x + 22.0, r.end.x - 30.0]: # light bars at the ends
		_stage.draw_rect(Rect2(x, top + 20, 8, r.size.y - 26), Color(0.6, 0.95, 1.0, 0.5))
	var top_face := PackedVector2Array([r.position + Vector2(10, -6), r.position + Vector2(w - 10, -6), r.position + Vector2(w, 14), r.position + Vector2(0, 14)])
	_stage.draw_colored_polygon(top_face, PINK_TOP)
	_stage.draw_line(r.position + Vector2(0, 14), r.position + Vector2(w, 14), Color(1, 1, 1, 0.75), 3.0, true)
	_stage.draw_polyline(PackedVector2Array([r.position + Vector2(0, 14), Vector2(r.position.x, r.end.y), r.end, r.position + Vector2(w, 14)]),
		Color(0.12, 0.02, 0.1, 0.8), 3.0, true)
	if star:
		var c := Vector2(r.get_center().x, top + 14 + (r.size.y - 14) / 2.0)
		var pts := PackedVector2Array()
		for i in 10:
			var rad := 26.0 if i % 2 == 0 else 11.0
			var a := TAU * i / 10.0 - PI / 2.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		_stage.draw_colored_polygon(pts, GOLD)
		_stage.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.45, 0.12, 0.02), 3.0, true)


func _ellipse(c: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		pts.append(c + Vector2(cos(TAU * i / 40.0) * radii.x, sin(TAU * i / 40.0) * radii.y))
	_stage.draw_colored_polygon(pts, color)


## Confetti over the winners' side (a win), rain over everything (a loss), nothing on a draw.
func _seed_particles() -> void:
	_particles.clear()
	var n := 90 if _outcome() == ResultModel.WIN else (140 if _outcome() == ResultModel.LOSE else 0)
	for i in n:
		_particles.append(_particle(true))


func _particle(anywhere: bool) -> Dictionary:
	var w := maxf(size.x, 1600.0)
	var h := maxf(size.y, 900.0)
	if _outcome() == ResultModel.WIN:
		return {"p": Vector2(randf() * w * 0.62, (randf() * h if anywhere else -20.0) - h * 0.3),
			"v": Vector2(randf_range(-30, 30), randf_range(70, 150)), "a": randf() * TAU, "spin": randf_range(-6, 6),
			"c": CONFETTI[randi() % CONFETTI.size()], "s": randf_range(8, 15)}
	return {"p": Vector2(randf() * (w + 200) - 100, randf() * h if anywhere else -30.0),
		"v": Vector2(-90, randf_range(650, 900)), "a": 0.0, "spin": 0.0, "c": Color(0.7, 0.8, 1.0, randf_range(0.18, 0.38)),
		"s": randf_range(18, 34)}


func _draw_fx() -> void:
	for q in _particles:
		if _outcome() == ResultModel.WIN:
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
		if _outcome() == ResultModel.WIN:
			q["p"].x += sin(q["a"] * 0.5) * 20.0 * delta
		if q["p"].y > size.y + 40:
			_particles[i] = _particle(false)
	if not _particles.is_empty():
		_fx.queue_redraw()
	if _counting and not _popup_open:
		var before := ceili(_left_sec)
		_left_sec -= delta
		if ceili(_left_sec) != before:
			_countdown.text = ResultModel.countdown_text(ceili(_left_sec))
		if _left_sec <= 0.0:
			_counting = false
			home_pressed.emit()


# ── Animations ──────────────────────────────────────────────────────────────

func _animate() -> void:
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	_title.scale = Vector2.ONE * 2.4
	_title.modulate.a = 0.0
	var slam := create_tween()
	slam.tween_interval(0.15)
	slam.tween_property(_title, "modulate:a", 1.0, 0.12)
	slam.parallel().tween_property(_title, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in _slots.size():
		var node: Control = _slots[i]["node"]
		var y: float = node.get_meta("home_y")
		node.position.y = y + 90.0
		node.modulate.a = 0.0
		var rise := create_tween()
		rise.tween_interval(0.35 + i * 0.14)
		rise.tween_property(node, "position:y", y, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.parallel().tween_property(node, "modulate:a", 1.0, 0.25)
	_bottom.modulate.a = 0.0
	var reveal := create_tween()
	reveal.tween_interval(0.7)
	reveal.tween_property(_bottom, "modulate:a", 1.0, 0.25)
	_count_rewards(reveal)


## The EXP and its bar, then the level-up popup (when there is one), the coins and the rank.
func _count_rewards(t: Tween) -> void:
	var reward: Dictionary = info.get("reward", {})
	if reward.get("ok", false):
		var steps := {}
		var before: Dictionary = info.get("exp", {})
		if not before.is_empty():
			steps = ResultModel.exp_steps(int(before["level"]), int(before["exp"]), int(reward["exp"]))
			_exp_bar.value = steps["from"]
		t.tween_method(func(v: float) -> void: _exp_value.text = "+%s EXP" % Fmt.thousands(roundi(v)), 0.0, float(reward["exp"]), 0.7)
		if not steps.is_empty():
			if reward["level_up"] or steps["levels"] > 0:
				t.parallel().tween_property(_exp_bar, "value", 1.0, 0.5)
				t.tween_callback(func() -> void: _exp_bar.value = 0.0)
				t.tween_property(_exp_bar, "value", steps["to"], 0.35)
			else:
				t.parallel().tween_property(_exp_bar, "value", steps["to"], 0.7)
	t.tween_callback(_after_exp)


## My character's id (my entry's).
func _my_character() -> String:
	for e in info.get("left", []) + info.get("right", []):
		if e["mine"]:
			return str(e["characterId"])
	return ""


func _after_exp() -> void:
	var stages := ResultModel.level_ups(info.get("reward", {}), info.get("exp", {}), _my_character(),
		str(info.get("char_name", "")))
	if stages.is_empty():
		_count_rest()
		return
	var parts: Array = []
	for s in stages:
		parts.append("Lv.%d" % s["to"] if s["kind"] == "player" else "%s Lv.%d" % [s["name"], s["to"]])
	_level_chip_text.text = " · ".join(parts)
	var font: Font = _level_chip_text.get_theme_font("font")
	_level_chip_text.custom_minimum_size.x = minf(font.get_string_size(_level_chip_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 2.0, 240.0)
	_level_chip.visible = true
	_pop(_level_chip)
	var popup = LevelUpPopup.new()
	popup.setup(stages)
	_open_popup(popup, _count_rest)


## A popup over everything; the auto return waits while it is open, `then` runs once it closed.
func _open_popup(popup: Control, then: Callable) -> void:
	_popup_open = true
	popup.closed.connect(func() -> void:
		_popup_open = false
		then.call())
	add_child(popup)


## The coins, then the rank: its popup when the division or tier changed, else the rating line.
func _count_rest() -> void:
	var t := create_tween()
	t.tween_interval(0.1)
	var reward: Dictionary = info.get("reward", {})
	if reward.get("ok", false):
		t.tween_method(func(v: float) -> void: _coin_value.text = "+%s xu" % Fmt.thousands(roundi(v)), 0.0, float(reward["coin"]), 0.5)
	var rank: Dictionary = reward.get("rank", {})
	if rank.is_empty():
		return
	var popup_data := RankModel.popup_of(rank)
	if popup_data.is_empty():
		t.tween_interval(0.15)
		t.tween_method(func(v: float) -> void: _rank_line.text = RankModel.rating_line(rank, roundi(v)),
			float(rank["old"]), float(rank["new"]), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return
	t.tween_interval(0.25)
	t.tween_callback(func() -> void:
		var popup = RankPopup.new()
		popup.setup(popup_data)
		_open_popup(popup, _rank_settled.bind(rank)))


## After the rank popup: the card's badge flips to the new rank, its line shows the new rating.
func _rank_settled(rank: Dictionary) -> void:
	_rank_line.text = RankModel.rating_line(rank)
	_rank_badge.pivot_offset = _rank_badge.size / 2.0
	var t := create_tween()
	t.tween_property(_rank_badge, "scale", Vector2.ONE * 0.2, 0.14).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void:
		_rank_badge.tier = rank["new_rank"][0]
		_rank_badge.division = rank["new_rank"][1])
	t.tween_property(_rank_badge, "scale", Vector2.ONE * 1.3, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_rank_badge, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE)


func _pop(l: Control) -> void:
	l.pivot_offset = Vector2(0, l.size.y / 2.0)
	l.modulate.a = 1.0
	l.scale = Vector2.ONE * 0.5
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
