extends RefCounted
## Equipment widgets shared by the Shop (Trang bị), Túi đồ, the Nhân vật page and Prep: an item
## icon with, from +1, its level's border aura (upgrade_aura.gd), the hexagon frame, the slot filter
## chips, stat lines, and the piece popup (its upgraded stats compared with what the character
## wears in that slot, who wears it, a close X in the top-right corner (a tap outside closes it
## too) and one row of buttons:
## worn → Chuyển cho <nhân vật> (worn by another) / Nâng cấp (opens the upgrade page on the piece) /
## Tháo; not worn → Mặc cho <nhân vật> / Bán (+N xu, never-worn pieces only) / Vứt, the last two
## confirmed first). Actions go through PlayerState (one at a time), which reloads the gear and the
## characters afterwards. Upgraded pieces' names take their level colour.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const Modal := preload("res://ui/modal.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const UpgradeAura := preload("res://screens/home/upgrade_aura.gd")

const GOOD := Color(0.45, 0.9, 0.55)
const LOSS := Color(1.0, 0.45, 0.45)
const WORN := Color(0.35, 0.8, 0.45)
const LEVEL := Color(1.0, 0.8, 0.22)
## The popup buttons' width (all equal, one row of up to three).
const BUTTON_WIDTH := 250

## Opens the Nâng cấp page on a piece (its equipmentId); Home sets it. The popup's Nâng cấp
## button is left out while it is not set.
static var open_upgrade: Callable


## The icon of a catalog item at px; from +1 (`piece`'s upgradeLevel, {} = none) the level's
## aura runs round a rounded square inside the icon's box (kept inside: lists scroll). No "+N":
## the aura and the name colour show the level; the number is in the piece popup.
static func item_icon(item: Dictionary, piece: Dictionary = {}, px: int = 72) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(px, px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var level := int(piece.get("upgradeLevel", 0))
	if UpgradeModel.color_tier(level) > 0:
		box.add_child(UpgradeAura.inside(Vector2(px, px), level, maxf(4.0, px * 0.07), px * 0.2))
	var icon := LobbyUi.icon(Art.equipment_icon(str(item.get("slot", "")), EquipmentModel.tier(item), EquipmentModel.weapon_kind(item)), px)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(icon)
	return box


## A hexagon frame of `size` (tinted in the milestone colour of `level`) with its border aura
## running round it; `content` (an icon, or null) centred in it, `lift` px up.
static func hex_frame(size: Vector2, level: int, content: Control = null, lift: float = 0.0) -> TextureRect:
	var frame := TextureRect.new()
	frame.texture = Art.equipment_frame("hex_filled")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.custom_minimum_size = size
	frame.size = size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.self_modulate = UpgradeModel.frame_tint(level)
	frame.add_child(UpgradeAura.around_frame(size, level))
	if content != null:
		content.position = (size - content.custom_minimum_size) / 2.0 - Vector2(0, lift)
		frame.add_child(content)
	return frame


## A small padlock (a piece ever worn is locked: it cannot be sold), px square, drawn in code.
static func lock_mark(px: int = 22, color: Color = Color(1, 1, 1, 0.6)) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var w := float(px)
		var top := w * 0.44
		c.draw_arc(Vector2(w * 0.5, top), w * 0.24, PI, TAU, 12, color, maxf(2.0, w * 0.11), true)
		c.draw_rect(Rect2(w * 0.14, top, w * 0.72, w * 0.52), color))
	return c


## A small coloured tag ("Đang mặc · Tanko", "Cần Lv 7").
static func tag(text_value: String, bg: Color, font_size: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", LobbyUi.box(bg, 10, 0))
	p.get_theme_stylebox("panel").content_margin_left = 10
	p.get_theme_stylebox("panel").content_margin_right = 10
	p.get_theme_stylebox("panel").content_margin_top = 2
	p.get_theme_stylebox("panel").content_margin_bottom = 2
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := LobbyUi.text(text_value, font_size, Color.WHITE, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## "Tất cả" and one chip per slot (EquipmentModel.slots() order); on_select(slot) gets "" for all.
static func slot_chips(on_select: Callable, font_size: int = 22, height: int = 52) -> Array[Button]:
	var order := EquipmentModel.slots()
	var names := ["Tất cả"]
	for s in order:
		names.append(EquipmentModel.slot_name(s))
	var chips := Ui.tab_row(names, font_size, func(i: int): on_select.call("" if i == 0 else order[i - 1]), height)
	for c in chips:
		c.size_flags_horizontal = Control.SIZE_FILL
		c.custom_minimum_size.x = 96
	return chips


## Selects the chip of `slot` ("" = Tất cả).
static func select_chip(chips: Array[Button], slot: String) -> void:
	Ui.select_tab(chips, 0 if slot == "" else EquipmentModel.slots().find(slot) + 1)


## The per-point stat values (GET /player/characters statMultipliers), {} until the characters
## load: item stats are points, shown with what they add in battle once these are known.
static func multipliers() -> Dictionary:
	return BattleStats.multipliers(PlayerState.characters)


## Stat lines of an item, one Label each ("Máu" "+30 điểm (+60)"), added to parent.
static func add_stat_lines(parent: Control, item: Dictionary, font_size: int = 20) -> void:
	for l in EquipmentModel.stat_lines(item, multipliers()):
		var row := Ui.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var k := LobbyUi.text(l["label"], font_size, Color(0.8, 0.88, 1.0))
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(k)
		var v := LobbyUi.text(l["text"], font_size, Color.WHITE, true)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		parent.add_child(row)


## Delta lines ("Sát thương +85 (+17 điểm)" green, "Máu −40 (−20 điểm)" red) of wearing
## `item` instead of `worn`, in one wrapping row; returns the row (empty when nothing changes).
static func delta_row(item: Dictionary, worn: Dictionary, font_size: int = 19) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 0)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for d in EquipmentModel.compare(item, worn, multipliers()):
		if d["tone"] == "":
			continue
		var l := LobbyUi.text("%s %s" % [d["label"], d["text"]], font_size, GOOD if d["tone"] == "good" else LOSS, true)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(l)
	return flow


# ── Popup ───────────────────────────────────────────────────────────────────

## The popup of an owned piece for `character_id` (the character on the Nhân vật stage, or the
## lobby's), the one place that shows the "+N": the name "+N" in the milestone colour; the
## hexagon with the icon and its aura beside slot · category · required level, who wears it,
## "Cấp nâng cấp +N / 16" and its bar; below, its upgraded stats (with "+24% từ nâng cấp" and
## the change against what the character wears in that slot) beside "Mốc nâng cấp" (+6 / +10 /
## +14 / +16 with their bonus, reached ones bright with a check, the others dimmed); an X in the
## top-right corner (or a tap outside the card) closes it; one row of equal buttons
## (piece_actions): worn by another character Chuyển cho <nhân vật> / Nâng cấp / Tháo, worn by this one Nâng cấp / Tháo, not worn
## Mặc cho <nhân vật> / Bán (+ floor(price × sellRate)) / Vứt. A piece ever worn is locked
## (isLocked) and crafted / unknown items cost nothing: Bán stays off with the reason under the row
## (sell_block). The actions stay locked while the owned pieces reload
## (PlayerState.equipment_ready()); Mặc / Chuyển cho also while the can-wear check lacks the
## catalog or the characters, Bán while the catalog loads. Once the data changed and settled the
## popup is rebuilt from the fresh piece (keeping `note`, the last message), so its buttons always
## match.
static func open_piece(overlay: Control, piece: Dictionary, character_id: String, note: String = "") -> Modal:
	var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
	var stats_item := EquipmentModel.piece_item(PlayerState.catalog, piece)
	var who := EquipmentModel.wearer(piece)
	var char_name := EquipmentModel.character_name(character_id)
	var worn: Dictionary = EquipmentModel.worn(PlayerState.equipment, character_id).get(str(piece.get("slot", "")), {})
	var worn_other: bool = not worn.is_empty() and str(worn.get("equipmentId", "")) != str(piece.get("equipmentId", ""))
	var worn_item := EquipmentModel.item_of_piece(PlayerState.catalog, worn) if worn_other else {}
	var worn_stats := EquipmentModel.piece_item(PlayerState.catalog, worn) if worn_other else {}
	var check := EquipmentModel.can_wear(item, character_id, PlayerState.characters)

	var level := int(piece.get("upgradeLevel", 0))
	var m := Modal.new()
	m.open(overlay, "%s %s" % [EquipmentModel.display_name(item), EquipmentModel.level_text(piece)], 880)
	m.title.add_theme_color_override("font_color", UpgradeModel.name_color(piece))
	# Top: the hexagon with the icon and its aura | slot · category · required level, the wearer,
	# "Cấp nâng cấp +N / 16" and its bar.
	var top := Ui.hbox(22)
	m.body.add_child(top)
	top.add_child(hex_frame(Vector2(132, 152), level, item_icon(item, {}, 92), 6))
	var head := Ui.vbox(6)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(head)
	var meta := Ui.hbox(12)
	head.add_child(meta)
	meta.add_child(LobbyUi.text(EquipmentModel.slot_name(str(item.get("slot", ""))), 22, Color(0.8, 0.88, 1.0), true))
	meta.add_child(LobbyUi.text("·", 22, Ui.TEXT_DIM))
	meta.add_child(LobbyUi.text(EquipmentModel.category_name(item), 22,
		Color(0.75, 0.6, 1.0) if str(item.get("category", "")) == "crafted" else Color(0.8, 0.88, 1.0), true))
	meta.add_child(LobbyUi.text("·", 22, Ui.TEXT_DIM))
	meta.add_child(LobbyUi.text("Lv yêu cầu %d" % maxi(int(item.get("requiredLevel", 1)), 1), 22, LEVEL, true))
	head.add_child(LobbyUi.text("Đang mặc: %s" % EquipmentModel.character_name(who) if who != "" else "Chưa mặc", 22,
		WORN if who != "" else Ui.TEXT_DIM, true))
	var level_label := LobbyUi.text(UpgradeModel.level_line(level), 24, UpgradeModel.milestone_color(level) if level >= 1 else LEVEL, true)
	level_label.name = "LevelLine"
	head.add_child(level_label)
	head.add_child(level_bar(level))

	# Below: the stats | the milestones.
	var cols := Ui.hbox(28)
	m.body.add_child(cols)
	var info := Ui.vbox(6)
	info.custom_minimum_size.x = 440
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(info)
	var stats_head := Ui.hbox(12)
	info.add_child(stats_head)
	var sh := LobbyUi.text("Chỉ số", 22, Ui.TEXT_DIM, true)
	sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_head.add_child(sh)
	var share := UpgradeModel.upgrade_share_text(PlayerState.catalog, level)
	if share != "":
		stats_head.add_child(LobbyUi.text(share, 20, GOOD, true))
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 16)
	stats.add_theme_constant_override("v_separation", 2)
	info.add_child(stats)
	var deltas := {}
	var mult := multipliers()
	for d in EquipmentModel.compare(stats_item, worn_stats if worn_other else {}, mult):
		deltas[d["key"]] = d
	var lines := EquipmentModel.stat_lines(stats_item, mult)
	for l in lines:
		var k := LobbyUi.text(l["label"], 21, Color(0.8, 0.88, 1.0))
		k.custom_minimum_size.x = 130
		stats.add_child(k)
		stats.add_child(LobbyUi.text(l["text"], 21, Color.WHITE, true))
		var d: Dictionary = deltas.get(l["key"], {})
		stats.add_child(_delta_label(d if worn_other else {}))
	if worn_other:
		# Stats only the worn piece has are lost.
		for key in deltas:
			var d: Dictionary = deltas[key]
			if lines.any(func(l): return l["key"] == key):
				continue
			stats.add_child(LobbyUi.text(d["label"], 21, Color(0.8, 0.88, 1.0)))
			stats.add_child(LobbyUi.text("—", 21, Ui.TEXT_DIM))
			stats.add_child(_delta_label(d))
		var cmp := LobbyUi.text("So với %s %s đang mặc" % [EquipmentModel.display_name(worn_item), EquipmentModel.level_text(worn)], 19, Ui.TEXT_DIM)
		cmp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(cmp)
	if who != character_id and not check["ok"]:
		info.add_child(LobbyUi.text("%s: %s" % [char_name, check["reason"]], 21, LOSS, true))
	cols.add_child(milestone_list(PlayerState.catalog, level, str(item.get("slot", piece.get("slot", ""))) == "weapon"))

	var piece_id := str(piece.get("equipmentId", ""))
	var piece_name := EquipmentModel.display_name(item)
	var ready := PlayerState.equipment_ready()
	var refund := EquipmentModel.sell_price(item, PlayerState.catalog)
	m.add_close_x()
	# One row of equal buttons: worn → (Chuyển cho) Nâng cấp Tháo; not worn → Mặc cho Bán Vứt.
	var actions: Array = []
	for action in piece_actions(who, character_id, open_upgrade.is_valid()):
		var b: Button
		match action:
			"move":
				b = m.add_button("Chuyển cho %s" % char_name, _act.bind(m, overlay, "move", piece_id, character_id,
					"Đã chuyển %s cho %s" % [piece_name, char_name], EquipmentModel.character_name(who)))
				if not check["ok"] or not PlayerState.can_wear_known():
					m.lock_button(b)
			"equip":
				b = m.add_button("Mặc cho %s" % char_name, _act.bind(m, overlay, "equip", piece_id, character_id, "%s đã mặc %s" % [char_name, piece_name]))
				if not check["ok"] or not PlayerState.can_wear_known():
					m.lock_button(b)
			"unequip":
				b = m.add_button("Tháo", _act.bind(m, overlay, "unequip", piece_id, who, "Đã tháo %s" % piece_name))
			"upgrade":
				b = m.add_button("Nâng cấp", func() -> void:
					m.close()
					open_upgrade.call(piece_id))
				b.add_theme_color_override("font_color", LEVEL)
			"sell":
				var why := sell_block(piece, item, PlayerState.catalog)
				b = m.add_button("Bán  +%s" % EquipmentModel.amount_text(refund) if why == "" and refund["amount"] > 0 else "Bán",
					_confirm_remove.bind(m, overlay, piece, item, true, refund))
				if why != "" or PlayerState.catalog == null:
					m.lock_button(b)
				if why != "":
					# The reason under the row, small: the row keeps its three buttons.
					var reason := m.add_row_label(why, 1, 20)
					reason.name = "SellReason"
			"discard":
				b = m.add_button("Vứt", _confirm_remove.bind(m, overlay, piece, item, false, refund))
				b.add_theme_color_override("font_color", LOSS)
		b.set_meta("action", action)
		if action != "upgrade":
			actions.append(b)
	# Equal widths: the widest label ("Chuyển cho Spark") sets them all.
	var width := float(BUTTON_WIDTH)
	for b in m.buttons():
		width = maxf(width, (b as Button).get_combined_minimum_size().x)
	for b in m.buttons():
		(b as Button).custom_minimum_size.x = width
	if not ready:
		for b in actions:
			m.lock_button(b)
		m.set_message(note if note != "" else "Đang cập nhật trang bị...")
	elif note != "":
		m.set_message(note)

	# Rebuild once the data changed and settled (an action here, a reload, a purchase elsewhere).
	var built := _data_version()
	var rebuild := func() -> void:
		# m "acting": an action (or the Bán / Vứt confirmation) is running; _release() re-checks.
		if not is_instance_valid(m) or m.is_queued_for_deletion() or m.get_meta("acting", false):
			return
		if not PlayerState.equipment_ready() or _data_version() == built:
			return
		var keep := m.message.text if m.message.visible and m.message.text != "Đang cập nhật trang bị..." else ""
		m.close()
		var fresh := EquipmentModel.find_piece(PlayerState.equipment, piece_id)
		if not fresh.is_empty() and is_instance_valid(overlay) and overlay.is_inside_tree():
			open_piece(overlay, fresh, character_id, keep)
	m.set_meta("rebuild", rebuild)
	PlayerState.equipment_changed.connect(rebuild)
	PlayerState.characters_changed.connect(rebuild)
	m.tree_exiting.connect(func() -> void:
		PlayerState.equipment_changed.disconnect(rebuild)
		PlayerState.characters_changed.disconnect(rebuild))
	return m


## The piece popup's buttons, in order, for a piece worn by `who` ("" = nobody) opened for
## `character_id`: worn by another character "move" (Chuyển cho), "upgrade", "unequip"; worn by
## this one "upgrade", "unequip" (nothing to move); not worn "equip" (Mặc cho), "sell", "discard".
## Worn pieces cannot be sold or thrown away from here (take them off first). "upgrade" is left
## out without the Nâng cấp page (open_upgrade unset).
static func piece_actions(who: String, character_id: String, can_upgrade: bool = true) -> Array:
	if who == "":
		return ["equip", "sell", "discard"]
	var out: Array = [] if who == character_id else ["move"]
	if can_upgrade:
		out.append("upgrade")
	out.append("unequip")
	return out


## Why a piece cannot be sold ("" when it can, or when the catalog has not loaded yet: Bán waits
## for it): ever worn (isLocked), crafted, or no price.
static func sell_block(piece: Dictionary, item: Dictionary, catalog: Variant) -> String:
	if bool(piece.get("isLocked", false)):
		return "Đã mặc nên không bán được"
	if catalog == null or EquipmentModel.sell_price(item, catalog)["amount"] > 0:
		return ""
	return "Đồ chế tạo không bán được" if str(item.get("category", "")) == "crafted" else "Trang bị này không bán được"


## "Mốc nâng cấp": the +6 / +10 / +14 / +16 rows (UpgradeModel.milestone_rows) for a piece at
## `level`, each a small hexagon with its aura, "+6", "+10% chỉ số" in its colour (a weapon's +14 /
## +16 add "· hào quang tím / đỏ sau lưng", smaller); reached rows bright with a check, the others
## dimmed (UNREACHED_ALPHA).
static func milestone_list(catalog: Variant, level: int, weapon: bool = false) -> VBoxContainer:
	var col := Ui.vbox(4)
	col.name = "Milestones"
	col.custom_minimum_size.x = 330
	col.add_child(LobbyUi.text("Mốc nâng cấp", 22, Ui.TEXT_DIM, true))
	for r in UpgradeModel.milestone_rows(catalog, level, weapon):
		var row := Ui.hbox(12)
		row.custom_minimum_size.y = 42
		row.set_meta("reached", r["reached"])
		row.modulate = Color(1, 1, 1, 1.0 if r["reached"] else UpgradeModel.UNREACHED_ALPHA)
		var hex := hex_frame(Vector2(32, 37), int(r["level"]))
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(40, 42)
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		holder.add_child(hex)
		hex.position = Vector2(4, 2)
		row.add_child(holder)
		var lv := LobbyUi.text("+%d" % int(r["level"]), 22, r["color"], true)
		lv.custom_minimum_size.x = 50
		lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lv)
		var bonus := LobbyUi.text(r["bonus_text"], 22, r["color"], true)
		bonus.size_flags_horizontal = Control.SIZE_EXPAND_FILL if r["back_aura"] == "" else Control.SIZE_FILL
		bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(bonus)
		if r["back_aura"] != "":
			var extra := LobbyUi.text(r["back_aura"], 18, r["color"])
			extra.name = "BackAura"
			extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			extra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(extra)
		row.add_child(check_mark(26, GOOD) if r["reached"] else Control.new())
		col.add_child(row)
	return col


## The upgrade level as a bar out of +16 with ticks at the milestones, filled in the level's
## level colour (green +1..+5, then the milestone colours).
static func level_bar(level: int, width: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 14)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := UpgradeModel.milestone_color(level) if level >= 1 else LEVEL
	var k := clampf(float(level) / UpgradeModel.max_level(), 0.0, 1.0)
	c.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		c.draw_style_box(LobbyUi.box(Color(1, 1, 1, 0.1), 7, 0), r)
		if k > 0.0:
			c.draw_style_box(LobbyUi.box(fill, 7, 0), Rect2(r.position, Vector2(maxf(r.size.x * k, 14.0), r.size.y)))
		for t in range(1, UpgradeModel.milestone_from().size() - 1):
			var x := r.size.x * float(UpgradeModel.milestone_from()[t]) / UpgradeModel.max_level()
			c.draw_line(Vector2(x, 1), Vector2(x, r.size.y - 1), Color(0, 0, 0, 0.45), 2.0))
	return c


## The "worn" mark of a piece card: a green disc with a dark rim and a white check, px square,
## drawn in code (reads on every tier's tinted card, green included: the rim and the check).
static func worn_badge(px: int = 30) -> Control:
	var c := Control.new()
	c.name = "WornBadge"
	c.custom_minimum_size = Vector2(px, px)
	c.size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var w := float(px)
		var mid := Vector2(w, w) / 2.0
		c.draw_circle(mid, w * 0.5, Color(0.03, 0.06, 0.1, 0.95))
		c.draw_circle(mid, w * 0.5 - maxf(2.0, w * 0.09), WORN.darkened(0.15))
		c.draw_polyline(PackedVector2Array([Vector2(w * 0.27, w * 0.52), Vector2(w * 0.44, w * 0.69), Vector2(w * 0.74, w * 0.33)]),
			Color.WHITE, maxf(2.5, w * 0.12), true))
	return c


## A check mark (✓) px square, drawn in code.
static func check_mark(px: int = 24, color: Color = GOOD) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var w := float(px)
		c.draw_polyline(PackedVector2Array([Vector2(w * 0.12, w * 0.52), Vector2(w * 0.4, w * 0.8), Vector2(w * 0.9, w * 0.2)]),
			color, maxf(2.5, w * 0.14), true))
	return c


## What the popup's buttons depend on: the owned pieces, the characters, the catalog, a running
## action.
static func _data_version() -> Array:
	return [PlayerState.equipment_version, PlayerState.characters_version, PlayerState.catalog != null,
		PlayerState.equipment_ready()]


static func _delta_label(d: Dictionary) -> Label:
	if d.is_empty() or d["tone"] == "":
		return LobbyUi.text("", 20)
	return LobbyUi.text(d["text"], 20, GOOD if d["tone"] == "good" else LOSS, true)


## from_name: who wore the piece before a move (for the half-done message).
static func _act(m: Modal, overlay: Control, action: String, piece_id: String, character_id: String, done: String, from_name: String = "") -> void:
	if not PlayerState.equipment_ready():
		m.set_message("Đang cập nhật trang bị, hãy đợi")
		return
	m.set_message("")
	m.set_busy(true)
	m.set_meta("acting", true)
	var res: Dictionary
	match action:
		"equip":
			res = await PlayerState.equip(piece_id, character_id)
		"move":
			res = await PlayerState.move_equipment(piece_id, character_id)
		_:
			res = await PlayerState.unequip(piece_id)
	var toast_ok := is_instance_valid(overlay) and overlay.is_inside_tree()
	if res.ok:
		if is_instance_valid(m):
			m.close()
		if toast_ok:
			Ui.toast(overlay, done)
		return
	if res.get("unequipped", false):
		# Taken off the first character, not put on the second: the popup's buttons are stale.
		if is_instance_valid(m):
			m.close()
		if toast_ok:
			Ui.toast(overlay, "Đã tháo khỏi %s nhưng chưa mặc được cho %s: %s" % [from_name, EquipmentModel.character_name(character_id), ErrorText.equip(res)], 4.0)
		return
	if not is_instance_valid(m):
		return
	m.set_meta("acting", false)
	m.set_message(ErrorText.equip(res) if res.code != "BUSY" else "Đang xử lý trang bị khác, hãy đợi")
	m.set_busy(false)
	# The reload PlayerState started rebuilds the popup (with this message) when it lands.
	for b in m.buttons():
		if not PlayerState.equipment_ready():
			(b as Button).disabled = true


## The Bán / Vứt confirmation over the piece popup `m`: the piece, what selling gives (`refund`)
## or that it is lost, who wears it (Vứt only: taken off first), where its gems and stones go. The popup
## holds its rebuild while it is open.
static func _confirm_remove(m: Modal, overlay: Control, piece: Dictionary, item: Dictionary, sell: bool, refund: Dictionary) -> void:
	if not PlayerState.equipment_ready():
		m.set_message("Đang cập nhật trang bị, hãy đợi")
		return
	# The confirmation (part of the popup) names the level; the toasts after it do not.
	var piece_name := EquipmentModel.display_name(item)
	var who := EquipmentModel.wearer(piece)
	m.set_meta("acting", true)
	var c := Modal.new()
	c.open(overlay, ("Bán %s %s?" if sell else "Vứt %s %s?") % [piece_name, EquipmentModel.level_text(piece)], 760)
	if sell:
		c.add_text("Nhận %s" % EquipmentModel.amount_text(refund), 28).add_theme_color_override("font_color", LEVEL)
	else:
		c.add_text("Mất trang bị này", 28).add_theme_color_override("font_color", LOSS)
	if who != "":
		c.add_text("Đang mặc trên %s — sẽ tháo ra trước" % EquipmentModel.character_name(who), 24).add_theme_color_override("font_color", WORN)
	if piece.get("gemSlot1") != null or piece.get("gemSlot2") != null:
		c.add_text("Ngọc đã khảm được trả về túi", 24)
	if int(piece.get("upgradeLevel", 0)) > 0:
		c.add_text("Hoàn lại một phần đá cường hoá đã dùng", 24)
	c.add_text("Không thể hoàn tác.", 22).add_theme_color_override("font_color", Ui.TEXT_DIM)
	var ok := c.add_button("Bán" if sell else "Vứt", _remove.bind(c, m, overlay, str(piece.get("equipmentId", "")), piece_name, sell, refund))
	if not sell:
		ok.add_theme_color_override("font_color", LOSS)
	var cancel := func() -> void:
		c.close()
		_release(m)
	c.add_button("Huỷ", cancel)
	# A tap outside the confirmation is Huỷ: it closes only the confirmation, not the popup.
	c.close_on_backdrop(cancel)


## Runs the confirmed sell / discard: success closes both with a toast; taken off but not sold /
## thrown away closes both with what happened; any other failure shows why on the popup.
static func _remove(c: Modal, m: Modal, overlay: Control, piece_id: String, piece_name: String, sell: bool, refund: Dictionary) -> void:
	if not PlayerState.equipment_ready():
		c.set_message("Đang cập nhật trang bị, hãy đợi")
		return
	var fresh := EquipmentModel.find_piece(PlayerState.equipment, piece_id)
	if fresh.is_empty():
		c.set_message(ErrorText.EQUIP_REMOVE["EQUIP_NOT_OWNED"])
		return
	var who := EquipmentModel.wearer(fresh)
	if sell and (who != "" or bool(fresh.get("isLocked", false))):
		c.set_message(ErrorText.EQUIP_REMOVE["EQUIP_LOCKED"])
		return
	c.set_message("")
	c.set_busy(true)
	var res: Dictionary
	if sell:
		res = await PlayerState.sell_equipment(piece_id)
	else:
		res = await PlayerState.discard_equipment(piece_id, who != "")
	var toast_ok := is_instance_valid(overlay) and overlay.is_inside_tree()
	if res.ok or res.get("unequipped", false):
		for d in [m, c]:
			if is_instance_valid(d):
				d.close()
		if not toast_ok:
			return
		if res.ok:
			var data: Dictionary = res.data if res.data is Dictionary else {}
			var got := refund
			if data.get("amount") is int or data.get("amount") is float:
				got = {"currency": str(data.get("currency", refund["currency"])), "amount": int(data["amount"])}
			Ui.toast(overlay, "Đã bán %s, +%s" % [piece_name, EquipmentModel.amount_text(got)] if sell else "Đã vứt %s" % piece_name)
		else:
			Ui.toast(overlay, "Đã tháo khỏi %s nhưng chưa %s được: %s" % [EquipmentModel.character_name(who), "bán" if sell else "vứt",
				ErrorText.equipment_remove(res, sell)], 4.0)
		return
	if is_instance_valid(c):
		c.close()
	if not is_instance_valid(m):
		return
	m.set_message(ErrorText.equipment_remove(res, sell) if res.code != "BUSY" else "Đang xử lý trang bị khác, hãy đợi")
	for b in m.buttons():
		if not PlayerState.equipment_ready():
			(b as Button).disabled = true
	_release(m)


## The confirmation closed without removing the piece: the popup rebuilds again (now, when the
## data changed meanwhile and settled; otherwise when it does).
static func _release(m: Modal) -> void:
	if not is_instance_valid(m) or m.is_queued_for_deletion():
		return
	m.set_meta("acting", false)
	var rebuild = m.get_meta("rebuild", null)
	if rebuild is Callable:
		rebuild.call()
