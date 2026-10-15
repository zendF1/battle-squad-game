extends RefCounted
## Equipment widgets shared by the Shop (Trang bị), Túi đồ, the Nhân vật page and Prep: an item
## icon with its "+N" badge, the slot filter chips, stat lines, and the piece popup (stats
## compared with what the character wears in that slot, who wears it, Mặc / Tháo / Chuyển cho
## <nhân vật> / Đóng). Actions go through PlayerState (one at a time), which reloads the gear and
## the characters afterwards.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const Modal := preload("res://ui/modal.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

const GOOD := Color(0.45, 0.9, 0.55)
const LOSS := Color(1.0, 0.45, 0.45)
const WORN := Color(0.35, 0.8, 0.45)
const LEVEL := Color(1.0, 0.8, 0.22)


## The icon of a catalog item at px, with the "+N" badge of `piece` ({} = no badge) over its
## bottom edge.
static func item_icon(item: Dictionary, piece: Dictionary = {}, px: int = 72) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(px, px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := LobbyUi.icon(Art.equipment_icon(str(item.get("slot", "")), EquipmentModel.tier(item)), px)
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


## Stat lines of an item, one Label each ("Máu +30"), added to parent.
static func add_stat_lines(parent: Control, item: Dictionary, font_size: int = 20) -> void:
	for l in EquipmentModel.stat_lines(item):
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


## Delta lines ("Sát thương +17" green, "Máu −20" red) of wearing `item` instead of `worn`,
## in one wrapping row; returns the row (empty when nothing changes).
static func delta_row(item: Dictionary, worn: Dictionary, font_size: int = 19) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 0)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for d in EquipmentModel.compare(item, worn):
		if d["tone"] == "":
			continue
		var l := LobbyUi.text("%s %s" % [d["label"], d["text"]], font_size, GOOD if d["tone"] == "good" else LOSS, true)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_child(l)
	return flow


# ── Popup ───────────────────────────────────────────────────────────────────

## The popup of an owned piece for `character_id` (the character on the Nhân vật stage, or the
## lobby's): icon, name, slot, required level, who wears it, its stats with the change against
## what the character wears in that slot, and the actions.
static func open_piece(overlay: Control, piece: Dictionary, character_id: String) -> Modal:
	var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
	var who := EquipmentModel.wearer(piece)
	var char_name := EquipmentModel.character_name(character_id)
	var worn: Dictionary = EquipmentModel.worn(PlayerState.equipment, character_id).get(str(piece.get("slot", "")), {})
	var worn_other: bool = not worn.is_empty() and str(worn.get("equipmentId", "")) != str(piece.get("equipmentId", ""))
	var worn_item := EquipmentModel.item_of_piece(PlayerState.catalog, worn) if worn_other else {}
	var check := EquipmentModel.can_wear(item, character_id, PlayerState.characters)

	var m := Modal.new()
	m.open(overlay, "%s %s" % [EquipmentModel.display_name(item), EquipmentModel.level_text(piece)], 880)
	var row := Ui.hbox(24)
	m.body.add_child(row)
	var left := Ui.vbox(8)
	row.add_child(left)
	var frame := TextureRect.new()
	frame.texture = Art.equipment_frame("hex_filled")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.custom_minimum_size = Vector2(150, 172)
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
	for d in EquipmentModel.compare(item, worn_item if worn_other else {}):
		deltas[d["key"]] = d
	for l in EquipmentModel.stat_lines(item):
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
			if EquipmentModel.stat_lines(item).any(func(l): return l["key"] == key):
				continue
			stats.add_child(LobbyUi.text(d["label"], 22, Color(0.8, 0.88, 1.0)))
			stats.add_child(LobbyUi.text("—", 22, Ui.TEXT_DIM))
			stats.add_child(_delta_label(d))
		info.add_child(LobbyUi.text("So với %s %s đang mặc" % [EquipmentModel.display_name(worn_item), EquipmentModel.level_text(worn)], 19, Ui.TEXT_DIM))
	if who != character_id and not check["ok"]:
		info.add_child(LobbyUi.text("%s: %s" % [char_name, check["reason"]], 22, LOSS, true))

	var piece_id := str(piece.get("equipmentId", ""))
	var piece_name := EquipmentModel.display_name(item)
	if who == character_id:
		m.add_button("Tháo", _act.bind(m, overlay, "unequip", piece_id, character_id, "Đã tháo %s" % piece_name))
	elif who == "":
		var wear := m.add_button("Mặc cho %s" % char_name, _act.bind(m, overlay, "equip", piece_id, character_id, "%s đã mặc %s" % [char_name, piece_name]))
		if not check["ok"]:
			m.lock_button(wear)
	else:
		var move := m.add_button("Chuyển cho %s" % char_name, _act.bind(m, overlay, "move", piece_id, character_id, "Đã chuyển %s cho %s" % [piece_name, char_name]))
		if not check["ok"]:
			m.lock_button(move)
		m.add_button("Tháo", _act.bind(m, overlay, "unequip", piece_id, who, "Đã tháo %s" % piece_name))
	m.add_button("Đóng", m.close)
	for b in m.buttons():
		(b as Button).custom_minimum_size.x = 250
	return m


static func _delta_label(d: Dictionary) -> Label:
	if d.is_empty() or d["tone"] == "":
		return LobbyUi.text("", 20)
	return LobbyUi.text("(%s)" % d["text"], 20, GOOD if d["tone"] == "good" else LOSS, true)


static func _act(m: Modal, overlay: Control, action: String, piece_id: String, character_id: String, done: String) -> void:
	if PlayerState.equip_busy != "":
		m.set_message("Đang xử lý trang bị khác, hãy đợi")
		return
	m.set_message("")
	m.set_busy(true)
	var res: Dictionary
	match action:
		"equip":
			res = await PlayerState.equip(piece_id, character_id)
		"move":
			res = await PlayerState.move_equipment(piece_id, character_id)
		_:
			res = await PlayerState.unequip(piece_id)
	if res.ok:
		if is_instance_valid(m):
			m.close()
		if is_instance_valid(overlay) and overlay.is_inside_tree():
			Ui.toast(overlay, done)
		return
	if not is_instance_valid(m):
		return
	m.set_message(ErrorText.equip(res) if res.code != "BUSY" else "Đang xử lý trang bị khác, hãy đợi")
	m.set_busy(false)
