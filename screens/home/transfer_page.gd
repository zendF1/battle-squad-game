extends Control
## The Nâng cấp page's "Chuyển hoá" tab (TransferModel; server contract
## ../battle-squad/docs/contracts/equip-transfer.md): carry an upgrade level to another piece of the
## same slot, paid in kim cương khoá. Mirrored round the centre:
## - left, "Món nguồn": the pieces at +1 and up (EquipmentUi.piece_row(): icon with its aura, name,
##   "+N", the cap mark); right, "Món nhận" (the same width): the other pieces of the source's slot
##   below its level, the ones whose cap holds the level first, the others faded with their cap
##   mark (they cannot take it);
## - centre: the source's hexagon left, the arrow dead centre, the target's right (an empty hexagon
##   until one is picked), each with its name over it and "+10 → +0" / "+0 → +10" under it (the
##   levels in their colours), each piece's cap mark under those; then CHUYỂN HOÁ with the locked kim cương
##   (the gem with its padlock) and the price, off with the reason under it ("Thiếu kim cương khoá"
##   in red when the locked balance is short: the unlocked kim cương never pays).
## CHUYỂN HOÁ confirms once (the two pieces, the price), then PlayerState.transfer_equipment(). The
## result is not a reward (no gift box): the source's aura flows as sparks along an arc into the
## target, the target bursts in its new colour and the new levels show; the toast says what was
## paid. The source then becomes the piece that took the level.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const Modal := preload("res://ui/modal.gd")
const Fmt := preload("res://core/fmt.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const TransferModel := preload("res://screens/home/transfer_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const WalletPills := preload("res://ui/wallet_pills.gd")

const SIDE_W := 430 # both side panels: the layout is mirrored
const FRAME := Vector2(136, 157)
const BIG_ICON := 96
const COL_W := 230
const DIM := Color(0.8, 0.88, 1.0)
const BAD := Color(1.0, 0.45, 0.45)
const FX_SEC := 1.6

## Where dialogs and toasts go (Home); the Nâng cấp page sets it.
var overlay: Control

var _source_id := ""
var _target_id := ""
var _acting := false
var _hold := {} # {source, target}: the pieces drawn while the result plays (before, then after)

var _sources: VBoxContainer
var _targets: VBoxContainer
var _grid: GridContainer
var _go: Button
var _go_text: HBoxContainer
var _go_price: Label
var _reason: Label
var _fx: Control
var _fx_t := 0.0
var _fx_from := Vector2.ZERO
var _fx_to := Vector2.ZERO
var _fx_from_color := Color.WHITE
var _fx_to_color := Color.WHITE
var _fx_parts: Array = []
var _fx_text := ""


func _init() -> void:
	var row := Ui.hbox(16)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(row)
	_sources = _side(row, "Món nguồn")
	var center := LobbyUi.panel(18, 18)
	center.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(center)
	var col := Ui.vbox(16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	_grid = GridContainer.new()
	_grid.name = "Pair"
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = SIZE_SHRINK_CENTER
	col.add_child(_grid)
	_go = LobbyUi.start_button("")
	_go.name = "TransferGo"
	_go.custom_minimum_size = Vector2(420, 84)
	_go.size_flags_horizontal = SIZE_SHRINK_CENTER
	_go.pressed.connect(_on_go)
	col.add_child(_go)
	_go_text = Ui.hbox(10)
	_go_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_go_text.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_go_text.offset_bottom = -6 # over the lip, like the button's own text
	_go_text.mouse_filter = MOUSE_FILTER_IGNORE
	var word := Ui.text("CHUYỂN HOÁ", 30, LobbyUi.TEXT_DARK)
	word.add_theme_font_override("font", LobbyUi.bold())
	word.mouse_filter = MOUSE_FILTER_IGNORE
	_go_text.add_child(word)
	var gem := WalletPills.locked_gem_icon(34)
	gem.name = "LockedGem"
	gem.mouse_filter = MOUSE_FILTER_IGNORE
	_go_text.add_child(gem)
	_go_price = Ui.text("", 27, LobbyUi.TEXT_DARK)
	_go_price.name = "Price"
	_go_price.add_theme_font_override("font", LobbyUi.bold())
	_go_price.mouse_filter = MOUSE_FILTER_IGNORE
	_go_text.add_child(_go_price)
	_go.add_child(_go_text)
	_reason = LobbyUi.text("", 20, Ui.TEXT_DIM, true)
	_reason.name = "Reason"
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.custom_minimum_size.y = 28
	col.add_child(_reason)
	_targets = _side(row, "Món nhận")
	_fx = Control.new()
	_fx.name = "TransferFx"
	_fx.mouse_filter = MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


## A side panel: its title over a scrolling list; returns the list.
func _side(row: Control, title: String) -> VBoxContainer:
	var panel := LobbyUi.panel(14, 18)
	panel.custom_minimum_size.x = SIDE_W
	row.add_child(panel)
	var col := Ui.vbox(10)
	panel.add_child(col)
	var head := LobbyUi.text(title, 26, Color.WHITE, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var list := Ui.vbox(8)
	col.add_child(Ui.scroll(list))
	return list


## Shows the tab with `equipment_id` as the source ("" keeps the choice).
func select_source(equipment_id: String) -> void:
	if equipment_id != "" and equipment_id != _source_id:
		_source_id = equipment_id
		_target_id = ""
	render()


func _source() -> Dictionary:
	if _hold.has("source"):
		return _hold["source"]
	return EquipmentModel.find_piece(PlayerState.equipment, _source_id)


func _target() -> Dictionary:
	if _hold.has("target"):
		return _hold["target"]
	return EquipmentModel.find_piece(PlayerState.equipment, _target_id)


## kim cương khoá held, -1 before the profile loads (the server checks then).
static func _locked() -> int:
	return PlayerState.gem_locked() if not PlayerState.profile.is_empty() else -1


func render() -> void:
	if _grid == null:
		return
	var catalog = PlayerState.catalog
	var all := TransferModel.sources(PlayerState.equipment, catalog)
	if not _acting:
		if _source().is_empty() or int(_source().get("upgradeLevel", 0)) < 1:
			_source_id = str(all[0].get("equipmentId", "")) if not all.is_empty() else ""
			_target_id = ""
		var rows := TransferModel.targets(PlayerState.equipment, catalog, _source())
		if rows.filter(func(r): return r["ok"] and str(r["piece"].get("equipmentId", "")) == _target_id).is_empty():
			_target_id = ""
	_render_sources(all)
	_render_targets()
	_render_pair()
	_render_go()


func _render_sources(all: Array) -> void:
	Ui.clear(_sources)
	if PlayerState.equipment == null:
		return
	if all.is_empty():
		_sources.add_child(_empty("Chưa có trang bị đã nâng cấp"))
	for p in all:
		var id := str(p.get("equipmentId", ""))
		_sources.add_child(EquipmentUi.piece_row(p, id == _source_id, _on_source.bind(id)))


func _render_targets() -> void:
	Ui.clear(_targets)
	var source := _source()
	if PlayerState.equipment == null or source.is_empty():
		return
	var rows := TransferModel.targets(PlayerState.equipment, PlayerState.catalog, source)
	if rows.is_empty():
		_targets.add_child(_empty("Chưa có %s nào khác thấp hơn" % EquipmentModel.slot_name(UpgradeModel.piece_slot(PlayerState.catalog, source)).to_lower()))
	for r in rows:
		var id := str(r["piece"].get("equipmentId", ""))
		var b := EquipmentUi.piece_row(r["piece"], id == _target_id, _on_target.bind(id), not r["ok"])
		if not r["ok"]:
			b.tooltip_text = "Chỉ lên được +%d" % int(r["cap"])
		_targets.add_child(b)


static func _empty(text_value: String) -> Label:
	var l := LobbyUi.text(text_value, 21, Ui.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## The centre: names, hexagons (the arrow between), "+a → +b" and the cap marks, as two mirrored
## columns round the arrow.
func _render_pair() -> void:
	Ui.clear(_grid)
	var catalog = PlayerState.catalog
	var source := _source()
	var target := _target()
	var levels := TransferModel.after(source, target) if not target.is_empty() else {}
	var cols := [source, target]
	# Names
	for i in 2:
		if i == 1:
			_grid.add_child(Control.new())
		var p: Dictionary = cols[i]
		var name_label := LobbyUi.text(EquipmentModel.display_name(EquipmentModel.item_of_piece(catalog, p)) if not p.is_empty() else "", 24,
			UpgradeModel.name_color(p), true)
		name_label.custom_minimum_size = Vector2(COL_W, 32)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_grid.add_child(name_label)
	# Hexagons, the arrow dead centre
	for i in 2:
		if i == 1:
			var arrow := CenterContainer.new()
			arrow.name = "Arrow"
			arrow.add_child(LobbyUi.icon("arrow_right", 56))
			_grid.add_child(arrow)
		var holder := CenterContainer.new()
		holder.name = "SourceHex" if i == 0 else "TargetHex"
		holder.custom_minimum_size = Vector2(COL_W, FRAME.y)
		_grid.add_child(holder)
		var p: Dictionary = cols[i]
		if p.is_empty():
			var empty := EquipmentUi.hex_frame(FRAME, 0)
			empty.modulate.a = 0.3
			holder.add_child(empty)
		else:
			var item := EquipmentModel.item_of_piece(catalog, p)
			holder.add_child(EquipmentUi.hex_frame(FRAME, int(p.get("upgradeLevel", 0)), EquipmentUi.item_icon(item, {}, BIG_ICON), 4))
	# "+10 → +0" | "+0 → +10"
	for i in 2:
		if i == 1:
			_grid.add_child(Control.new())
		var p: Dictionary = cols[i]
		var change := Ui.hbox(8)
		change.name = "SourceLevels" if i == 0 else "TargetLevels"
		change.alignment = BoxContainer.ALIGNMENT_CENTER
		change.custom_minimum_size = Vector2(COL_W, 50)
		_grid.add_child(change)
		if p.is_empty():
			continue
		var now := int(p.get("upgradeLevel", 0))
		change.add_child(_level_label(now, 38))
		if not levels.is_empty():
			change.add_child(LobbyUi.icon("arrow_right", 26))
			change.add_child(_level_label(int(levels["source" if i == 0 else "target"]), 38))
	# The caps
	for i in 2:
		if i == 1:
			_grid.add_child(Control.new())
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(COL_W, 26)
		_grid.add_child(holder)
		var p: Dictionary = cols[i]
		# Both columns show their cap (+16 too): the target's is what lets it take the level.
		var cap := UpgradeModel.cap(catalog, p) if not p.is_empty() and UpgradeModel.cap_known(catalog, p) else -1
		if cap >= 0:
			var after: int = int(levels["source" if i == 0 else "target"]) if not levels.is_empty() else int(p.get("upgradeLevel", 0))
			holder.add_child(EquipmentUi.cap_mark(cap, after >= cap, 19))


static func _level_label(level: int, font_size: int) -> Label:
	var l := LobbyUi.text("+%d" % level, font_size, UpgradeModel.milestone_color(level), true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _reason_text() -> String:
	if _acting:
		return "Đang chuyển hoá..."
	if PlayerState.catalog == null or PlayerState.equipment == null:
		return "Đang tải..."
	var why := TransferModel.blocked_reason(PlayerState.catalog, _source(), _target(), _locked())
	if why != "":
		return why
	if not PlayerState.equipment_ready():
		return "Đang cập nhật trang bị..."
	return ""


func _render_go() -> void:
	var reason := _reason_text()
	var price := TransferModel.cost(PlayerState.catalog, int(_source().get("upgradeLevel", 0)))
	_go.disabled = reason != ""
	_go_price.text = Fmt.thousands(price)
	_go_price.visible = price > 0
	_go_text.get_node("LockedGem").visible = price > 0
	_go_text.modulate = Color(1, 1, 1, 0.5 if _go.disabled else 1.0)
	var short := reason == TransferModel.SHORT
	_go_price.add_theme_color_override("font_color", Color(0.7, 0.08, 0.08) if short else LobbyUi.TEXT_DARK)
	_reason.text = reason
	_reason.add_theme_color_override("font_color", BAD if short else Ui.TEXT_DIM)


func _on_source(id: String) -> void:
	if _acting or id == _source_id:
		return
	_source_id = id
	_target_id = ""
	render.call_deferred()


func _on_target(id: String) -> void:
	if _acting:
		return
	var row := TransferModel.targets(PlayerState.equipment, PlayerState.catalog, _source()).filter(
		func(r): return str(r["piece"].get("equipmentId", "")) == id)
	if row.is_empty():
		return
	if not row[0]["ok"]: # it cannot take the level: say why, keep the choice
		Ui.toast(overlay if overlay != null else self, "Món này chỉ lên được +%d" % int(row[0]["cap"]), 2.0)
		return
	_target_id = id
	render.call_deferred()


## One confirmation with the two pieces and the price, then the transfer.
func _on_go() -> void:
	if _reason_text() != "":
		return
	var source := _source()
	var target := _target()
	var price := TransferModel.cost(PlayerState.catalog, int(source.get("upgradeLevel", 0)))
	var m := Modal.new()
	m.open(overlay if overlay != null else self, "Chuyển hoá", 620)
	var row := Ui.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.body.add_child(row)
	var levels := TransferModel.after(source, target)
	for i in 2:
		if i == 1:
			row.add_child(LobbyUi.icon("arrow_right", 40))
		var p: Dictionary = [source, target][i]
		var col := Ui.vbox(2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		var icon := EquipmentUi.item_icon(EquipmentModel.item_of_piece(PlayerState.catalog, p), p, 84)
		icon.size_flags_horizontal = SIZE_SHRINK_CENTER
		col.add_child(icon)
		var change := Ui.hbox(4)
		change.alignment = BoxContainer.ALIGNMENT_CENTER
		change.add_child(_level_label(int(p.get("upgradeLevel", 0)), 26))
		change.add_child(LobbyUi.icon("arrow_right", 20))
		change.add_child(_level_label(int(levels["source" if i == 0 else "target"]), 26))
		col.add_child(change)
	var cost := Ui.hbox(8)
	cost.alignment = BoxContainer.ALIGNMENT_CENTER
	cost.add_child(WalletPills.locked_gem_icon(36))
	cost.add_child(LobbyUi.text(Fmt.thousands(price), 30, Color.WHITE, true))
	m.body.add_child(cost)
	m.add_button("Huỷ", m.close)
	m.add_button("Chuyển hoá", func():
		m.close()
		if _reason_text() == "":
			_run())


func _run() -> void:
	var source := _source().duplicate(true)
	var target := _target().duplicate(true)
	var src_id := str(source.get("equipmentId", ""))
	var tgt_id := str(target.get("equipmentId", ""))
	var src_level := int(source.get("upgradeLevel", 0))
	var tgt_level := int(target.get("upgradeLevel", 0))
	var item_name := EquipmentModel.display_name(EquipmentModel.item_of_piece(PlayerState.catalog, target))
	_acting = true
	_hold = {"source": source, "target": target}
	render()
	var res: Dictionary = await PlayerState.transfer_equipment(src_id, tgt_id, src_level, tgt_level)
	if not is_inside_tree():
		return
	if not res.ok:
		_acting = false
		_hold = {}
		var host := overlay if overlay != null else self
		Ui.toast(host, ErrorText.transfer(res) if res.code != "BUSY" else "Đang xử lý việc khác, hãy đợi", 3.0)
		render()
		return
	var result := TransferModel.parse_result(res.data)
	var after_source: Dictionary = result["source"] if not result["source"].is_empty() else source.merged({"upgradeLevel": tgt_level}, true)
	var after_target: Dictionary = result["target"] if not result["target"].is_empty() else target.merged({"upgradeLevel": src_level}, true)
	await play_flow(src_level, int(after_target.get("upgradeLevel", src_level)), func():
		_hold = {"source": after_source, "target": after_target}
		_render_pair())
	if not is_inside_tree():
		return
	var paid := int(result["gem_spent"])
	var host := overlay if overlay != null else self
	if bool(result["replay"]):
		Ui.toast(host, "Giao dịch trước đã hoàn tất", 2.5)
	else:
		Ui.toast(host, "Chuyển hoá thành công! %s +%d%s" % [item_name, int(after_target.get("upgradeLevel", src_level)),
			" (−%s kim cương khoá)" % Fmt.thousands(paid) if paid > 0 else ""], 3.0)
	_acting = false
	_hold = {}
	_source_id = tgt_id # the piece that took the level
	_target_id = ""
	render()


## The result: the source's level flows as sparks along an arc into the target, which bursts in its
## new colour; `land` runs when it lands (the new levels show). Awaitable.
func play_flow(from_level: int, to_level: int, land: Callable = Callable()) -> void:
	var from := _grid.find_child("SourceHex", true, false) as Control
	var to := _grid.find_child("TargetHex", true, false) as Control
	if from == null or to == null:
		if land.is_valid():
			land.call()
		return
	var inv := _fx.get_global_transform_with_canvas().affine_inverse()
	_fx_from = inv * (from.get_global_rect().get_center())
	_fx_to = inv * (to.get_global_rect().get_center())
	_fx_from_color = UpgradeModel.milestone_color(maxi(from_level, 1))
	_fx_to_color = UpgradeModel.milestone_color(maxi(to_level, 1))
	_fx_text = "+%d" % to_level
	_fx_parts.clear()
	var rng := RandomNumberGenerator.new()
	for i in 26:
		_fx_parts.append([rng.randf_range(0.0, 0.3), rng.randf_range(-26.0, 26.0), rng.randf_range(3.0, 7.0), rng.randf() * TAU])
	var landed := [false]
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		_fx_t = t
		if t >= 0.62 and not landed[0]:
			landed[0] = true
			if land.is_valid():
				land.call()
		_fx.queue_redraw(), 0.0, 1.0, FX_SEC)
	await tw.finished
	_fx_t = 0.0
	_fx_text = ""
	_fx_parts.clear()
	if not landed[0] and land.is_valid():
		land.call()
	_fx.queue_redraw()


func _draw_fx() -> void:
	if _fx_parts.is_empty():
		return
	var t := _fx_t
	var c := _fx
	var span := _fx_to - _fx_from
	var lift := Vector2(0, -maxf(90.0, span.length() * 0.35))
	var r := FRAME.y * 0.5
	# The source flares, then dims as its level leaves it.
	var flare := clampf(1.0 - t * 3.0, 0.0, 1.0)
	if flare > 0.0:
		c.draw_circle(_fx_from, r * (0.6 + 0.5 * (1.0 - flare)), Color(_fx_from_color, 0.45 * flare), true, -1.0, true)
	# The level as an orb and sparks along an arc (a quadratic curve over the arrow).
	var travel := clampf((t - 0.08) / 0.56, 0.0, 1.0)
	for p in _fx_parts:
		var k := clampf(travel - float(p[0]) * 0.5, 0.0, 1.0) / maxf(1.0 - float(p[0]) * 0.5, 0.01)
		if k <= 0.0 or k >= 1.0:
			continue
		var pos := _arc(k, lift) + Vector2(0, float(p[1])) * sin(k * PI)
		var col := _fx_from_color.lerp(_fx_to_color, k).lightened(0.35)
		_spark(c, pos, float(p[2]) * (1.0 - 0.4 * k), Color(col, 0.9))
	if travel > 0.0 and travel < 1.0:
		var orb := _arc(travel, lift)
		var col := _fx_from_color.lerp(_fx_to_color, travel)
		for k in 4: # a short glowing tail
			var back := _arc(maxf(travel - k * 0.05, 0.0), lift)
			c.draw_circle(back, 24.0 - k * 4.5, Color(col, 0.5 - k * 0.1), true, -1.0, true)
		c.draw_circle(orb, 30.0, Color(col, 0.35), true, -1.0, true)
		c.draw_circle(orb, 22.0, Color(col.lightened(0.2), 0.9), true, -1.0, true)
		c.draw_circle(orb, 10.0, Color(1, 1, 1, 0.95), true, -1.0, true)
	# The target bursts in its new colour.
	var hit := clampf((t - 0.6) / 0.4, 0.0, 1.0)
	if hit > 0.0:
		var fade := 1.0 - hit
		c.draw_circle(_fx_to, r * (0.5 + 0.6 * hit), Color(1, 1, 1, 0.55 * maxf(0.0, 1.0 - hit * 3.0)), true, -1.0, true)
		for k in 3:
			var tk := clampf(hit * 1.25 - k * 0.15, 0.0, 1.0)
			if tk > 0.0:
				c.draw_arc(_fx_to, r * (0.35 + tk), 0, TAU, 48, Color(_fx_to_color, (1.0 - tk) * 0.9), 9.0 * (1.0 - tk) + 1.5, true)
		for p in _fx_parts:
			var pos: Vector2 = _fx_to + Vector2.from_angle(float(p[3])) * r * (0.25 + 1.1 * hit)
			_spark(c, pos, float(p[2]) * 1.3 * fade, Color(_fx_to_color.lightened(0.45), fade))
		var font := LobbyUi.bold()
		var fs := 46
		var w := font.get_string_size(_fx_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var alpha := clampf(fade * 2.5, 0.0, 1.0) * minf(hit * 6.0, 1.0)
		var at := _fx_to + Vector2(-w / 2.0, 14.0 - 44.0 * hit)
		c.draw_string_outline(font, at, _fx_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.05, 0.03, 0.1, alpha))
		c.draw_string(font, at, _fx_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color.WHITE.lerp(_fx_to_color, 0.35), alpha))


func _arc(k: float, lift: Vector2) -> Vector2:
	var mid := (_fx_from + _fx_to) / 2.0 + lift
	return _fx_from.lerp(mid, k).lerp(mid.lerp(_fx_to, k), k)


static func _spark(c: Control, at: Vector2, s: float, color: Color) -> void:
	if s < 0.6 or color.a <= 0.01: # too small to see (and a degenerate polygon)
		return
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 2), at + Vector2(s * 0.45, 0), at + Vector2(0, s * 2), at + Vector2(-s * 0.45, 0)]), color)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 2, 0), at + Vector2(0, s * 0.45), at + Vector2(s * 2, 0), at + Vector2(0, -s * 0.45)]), color)
