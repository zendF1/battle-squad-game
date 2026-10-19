extends RefCounted
## Equipment widgets shared by the Shop (Trang bị), Túi đồ, the Nhân vật page and Prep: an item
## icon with its "+N" badge and, from +6, its milestone aura (upgrade_aura.gd), the slot filter
## chips, stat lines, and the piece popup (its upgraded stats compared with what the character
## wears in that slot, who wears it, Mặc / Tháo / Chuyển cho <nhân vật> / Đóng, and below them
## Nâng cấp (opens the upgrade page on the piece), Bán (+N xu, never-worn pieces only) / Vứt, each
## confirmed first). Actions go through PlayerState (one at a time), which reloads the gear and the
## characters afterwards. Upgraded pieces' names take their milestone colour.

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

## Opens the Nâng cấp page on a piece (its equipmentId); Home sets it. The popup's Nâng cấp
## button is left out while it is not set.
static var open_upgrade: Callable


## The icon of a catalog item at px, with the "+N" badge of `piece` ({} = no badge) over its
## bottom edge and, from +6, the milestone aura behind it (spilling a little outside the box).
static func item_icon(item: Dictionary, piece: Dictionary = {}, px: int = 72) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(px, px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not piece.is_empty() and UpgradeModel.milestone_tier(int(piece.get("upgradeLevel", 0))) > 0:
		box.add_child(UpgradeAura.around(px, int(piece.get("upgradeLevel", 0))))
	var icon := LobbyUi.icon(Art.equipment_icon(str(item.get("slot", "")), EquipmentModel.tier(item), EquipmentModel.weapon_kind(item)), px)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(icon)
	if not piece.is_empty():
		var b := badge(EquipmentModel.level_text(piece), maxi(14, px / 5))
		b.anchor_left = 0.5
		b.anchor_right = 0.5
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
		b.grow_horizontal = Control.GROW_DIRECTION_BOTH
		b.grow_vertical = Control.GROW_DIRECTION_BEGIN
		b.offset_top = 4
		b.offset_bottom = 4
		box.add_child(b)
	return box


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


## The "+N" pill (assets/icons/equipment/badge.png).
static func badge(text_value: String, font_size: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Art.equipment_badge_box(1))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := LobbyUi.text(text_value, font_size, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


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


## "Tất cả" and one chip per slot (EquipmentModel.SLOTS order); on_select(slot) gets "" for all.
static func slot_chips(on_select: Callable, font_size: int = 22, height: int = 52) -> Array[Button]:
	var names := ["Tất cả"]
	for s in EquipmentModel.SLOTS:
		names.append(EquipmentModel.slot_name(s))
	var chips := Ui.tab_row(names, font_size, func(i: int): on_select.call("" if i == 0 else EquipmentModel.SLOTS[i - 1]), height)
	for c in chips:
		c.size_flags_horizontal = Control.SIZE_FILL
		c.custom_minimum_size.x = 96
	return chips


## Selects the chip of `slot` ("" = Tất cả).
static func select_chip(chips: Array[Button], slot: String) -> void:
	Ui.select_tab(chips, 0 if slot == "" else EquipmentModel.SLOTS.find(slot) + 1)


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
## lobby's): icon, name, slot, required level, who wears it, its stats with the change against
## what the character wears in that slot, and the actions: Mặc / Chuyển cho / Tháo / Đóng, then a
## second row with Bán (+ floor(price × sellRate)) and Vứt. A piece ever worn is locked
## (isLocked) and crafted / unknown items cost nothing: no Bán, the reason instead. The actions stay locked while the owned pieces reload
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

	var m := Modal.new()
	m.open(overlay, "%s %s" % [EquipmentModel.display_name(item), EquipmentModel.level_text(piece)], 880)
	if UpgradeModel.milestone_tier(int(piece.get("upgradeLevel", 0))) > 0:
		m.title.add_theme_color_override("font_color", UpgradeModel.name_color(piece))
	var row := Ui.hbox(24)
	m.body.add_child(row)
	var left := Ui.vbox(8)
	row.add_child(left)
	var frame := TextureRect.new()
	frame.texture = Art.equipment_frame("hex_filled")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.custom_minimum_size = Vector2(150, 172)
	frame.self_modulate = UpgradeModel.frame_tint(int(piece.get("upgradeLevel", 0)))
	left.add_child(frame)
	var icon := item_icon(item, piece, 104)
	icon.position = Vector2((150 - 104) / 2.0, (172 - 104) / 2.0 - 8)
	frame.add_child(icon)

	var info := Ui.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var meta := Ui.hbox(12)
	info.add_child(meta)
	meta.add_child(LobbyUi.text(EquipmentModel.slot_name(str(item.get("slot", ""))), 22, Color(0.8, 0.88, 1.0), true))
	meta.add_child(LobbyUi.text("Lv yêu cầu %d" % maxi(int(item.get("requiredLevel", 1)), 1), 22, LEVEL, true))
	if str(item.get("category", "")) == "crafted":
		meta.add_child(LobbyUi.text("Chế tạo", 22, Color(0.75, 0.6, 1.0), true))
	info.add_child(LobbyUi.text("Đang mặc: %s" % EquipmentModel.character_name(who) if who != "" else "Chưa mặc", 22,
		WORN if who != "" else Ui.TEXT_DIM, true))
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 18)
	stats.add_theme_constant_override("v_separation", 2)
	info.add_child(stats)
	var deltas := {}
	var mult := multipliers()
	for d in EquipmentModel.compare(stats_item, worn_stats if worn_other else {}, mult):
		deltas[d["key"]] = d
	var lines := EquipmentModel.stat_lines(stats_item, mult)
	for l in lines:
		var k := LobbyUi.text(l["label"], 22, Color(0.8, 0.88, 1.0))
		k.custom_minimum_size.x = 150
		stats.add_child(k)
		stats.add_child(LobbyUi.text(l["text"], 22, Color.WHITE, true))
		var d: Dictionary = deltas.get(l["key"], {})
		stats.add_child(_delta_label(d if worn_other else {}))
	if worn_other:
		# Stats only the worn piece has are lost.
		for key in deltas:
			var d: Dictionary = deltas[key]
			if lines.any(func(l): return l["key"] == key):
				continue
			stats.add_child(LobbyUi.text(d["label"], 22, Color(0.8, 0.88, 1.0)))
			stats.add_child(LobbyUi.text("—", 22, Ui.TEXT_DIM))
			stats.add_child(_delta_label(d))
		info.add_child(LobbyUi.text("So với %s %s đang mặc" % [EquipmentModel.display_name(worn_item), EquipmentModel.level_text(worn)], 19, Ui.TEXT_DIM))
	if who != character_id and not check["ok"]:
		info.add_child(LobbyUi.text("%s: %s" % [char_name, check["reason"]], 22, LOSS, true))

	var piece_id := str(piece.get("equipmentId", ""))
	var piece_name := EquipmentModel.display_name(item)
	var ready := PlayerState.equipment_ready()
	var actions: Array = []
	if who == character_id:
		actions.append(m.add_button("Tháo", _act.bind(m, overlay, "unequip", piece_id, character_id, "Đã tháo %s" % piece_name)))
	elif who == "":
		var wear := m.add_button("Mặc cho %s" % char_name, _act.bind(m, overlay, "equip", piece_id, character_id, "%s đã mặc %s" % [char_name, piece_name]))
		actions.append(wear)
		if not check["ok"] or not PlayerState.can_wear_known():
			m.lock_button(wear)
	else:
		var move := m.add_button("Chuyển cho %s" % char_name, _act.bind(m, overlay, "move", piece_id, character_id,
			"Đã chuyển %s cho %s" % [piece_name, char_name], EquipmentModel.character_name(who)))
		actions.append(move)
		if not check["ok"] or not PlayerState.can_wear_known():
			m.lock_button(move)
		actions.append(m.add_button("Tháo", _act.bind(m, overlay, "unequip", piece_id, who, "Đã tháo %s" % piece_name)))
	m.add_button("Đóng", m.close)
	for b in m.buttons():
		(b as Button).custom_minimum_size.x = 250
	# Second row, smaller: upgrading, then selling and throwing away (irreversible, each asks first).
	if open_upgrade.is_valid():
		var up := _small(m.add_button("Nâng cấp", func() -> void:
			m.close()
			open_upgrade.call(piece_id), 1))
		up.custom_minimum_size.x = 200
		up.add_theme_color_override("font_color", LEVEL)
	var refund := EquipmentModel.sell_price(item, PlayerState.catalog)
	var locked := bool(piece.get("isLocked", false))
	if locked:
		m.add_row_label("Đã mặc nên không bán được", 1)
	elif PlayerState.catalog == null or refund["amount"] > 0:
		var sell := _small(m.add_button("Bán  +%s" % EquipmentModel.amount_text(refund) if refund["amount"] > 0 else "Bán",
			_confirm_remove.bind(m, overlay, piece, item, true, refund), 1))
		actions.append(sell)
		if PlayerState.catalog == null:
			m.lock_button(sell)
	else:
		m.add_row_label("Đồ chế tạo không bán được" if str(item.get("category", "")) == "crafted" else "Trang bị này không bán được", 1)
	var discard := _small(m.add_button("Vứt", _confirm_remove.bind(m, overlay, piece, item, false, refund), 1))
	discard.add_theme_color_override("font_color", LOSS)
	actions.append(discard)
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
		if b.text != "Đóng" and not PlayerState.equipment_ready():
			(b as Button).disabled = true


## A second-row button: shorter, smaller text.
static func _small(b: Button) -> Button:
	b.custom_minimum_size = Vector2(250, 64)
	b.add_theme_font_size_override("font_size", 24)
	return b


## The Bán / Vứt confirmation over the piece popup `m`: the piece, what selling gives (`refund`)
## or that it is lost, who wears it (Vứt only: taken off first), where its gems and stones go. The popup
## holds its rebuild while it is open.
static func _confirm_remove(m: Modal, overlay: Control, piece: Dictionary, item: Dictionary, sell: bool, refund: Dictionary) -> void:
	if not PlayerState.equipment_ready():
		m.set_message("Đang cập nhật trang bị, hãy đợi")
		return
	var piece_name := "%s %s" % [EquipmentModel.display_name(item), EquipmentModel.level_text(piece)]
	var who := EquipmentModel.wearer(piece)
	m.set_meta("acting", true)
	var c := Modal.new()
	c.open(overlay, ("Bán %s?" if sell else "Vứt %s?") % piece_name, 760)
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
	c.add_button("Huỷ", func() -> void:
		c.close()
		_release(m))


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
		if b.text != "Đóng" and not PlayerState.equipment_ready():
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
