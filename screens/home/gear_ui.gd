extends RefCounted
## The gear effects' widgets (GearModel's data drawn with ui/gear_glyphs.gd pictures): a passive as
## its picture and its value, a piece's awaken as its glowing picture (a tap opens a short popup:
## the picture big, when it works, once per match), the set as a row of pips (one per piece of a
## full set, filled by the pieces worn in the set's colour, a bar under each 2 / 4 / 6 group lit
## gold once reached) with the 6-piece effect's picture after it (dim until reached), and a
## character's profile (its passives' pictures and values in one row). Used by the piece popup,
## Kho đồ, the Nhân vật page and the showcase.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const GearIcon := preload("res://ui/gear_icon.gd")
const GearGlyphs := preload("res://ui/gear_glyphs.gd")
const GearModel := preload("res://screens/home/gear_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const VALUE := Color(1.0, 0.92, 0.6)
const PIP_EMPTY := Color(1, 1, 1, 0.16)
const REACHED := Color(1.0, 0.8, 0.22)
const UNREACHED := Color(1, 1, 1, 0.18)
## The awaken popup: how each awaken works (one short line) and which gear number it shows
## (GET /gamedata gear; "" none): presentation text keyed by the awaken kind.
const AWAKEN_LINES := {
	"revive": ["Lần đầu hết máu: sống lại với %s máu", "reviveHpPct"],
	"crit_immune": ["Đòn chí mạng đầu tiên thành đòn thường, thêm khiên %s máu", "critImmuneShieldPct"],
	"sure_proc": ["Phát bắn trúng đầu tiên chắc chắn gây hiệu ứng hệ", ""],
	"no_wind": ["Bấm trong lượt: phát bắn tiếp theo không bị gió", ""],
	"sure_crit": ["Bấm trong lượt: phát bắn tiếp theo luôn chí mạng", ""],
	"double_energy": ["Bấm trong lượt: thể lực lượt này ×%s", "bootsEnergyFactor"],
}


## A passive ({kind, value, glyph}: GearModel.piece_passive() / profile_lines()) as its picture and
## its value ("+48.3%"); an empty box for {}.
static func passive_chip(p: Dictionary, px: int = 40, font_size: int = 22) -> HBoxContainer:
	var row := Ui.hbox(6)
	row.name = "Passive"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if p.is_empty():
		return row
	var icon = GearIcon.make(str(p.get("glyph", p.get("kind", ""))), px)
	row.add_child(icon)
	var l := LobbyUi.text(GearModel.value_text(str(p["kind"]), float(p["value"])), font_size, VALUE, true)
	l.name = "Value"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	return row


## A character's passives (a gear profile) in one row of chips; empty without any.
static func profile_row(gear: Dictionary, px: int = 36, font_size: int = 20) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = "GearProfile"
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in GearModel.profile_lines(gear):
		flow.add_child(passive_chip(l, px, font_size))
	return flow


## The awaken of `slot`'s piece (+16) as its glowing picture; a tap opens its short popup over
## `overlay` (none without one).
static func awaken_button(slot: String, overlay: Control, px: int = 48) -> Button:
	var b := Button.new()
	b.name = "Awaken"
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var icon = GearIcon.make(GearModel.awaken_kind(slot), px)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(icon)
	b.set_meta("slot", slot)
	if overlay != null:
		b.pressed.connect(func() -> void: open_awaken(overlay, slot))
	return b


## The awaken's one line ("Lần đầu hết máu: sống lại với 20% máu"; the number from the game data),
## then "Một lần mỗi trận"; "" for an unknown kind.
static func awaken_text(kind: String) -> String:
	var line: Array = AWAKEN_LINES.get(kind, [])
	if line.is_empty():
		return ""
	var t: String = line[0]
	if line[1] != "":
		var v := GameData.gear_value(line[1])
		var n := ("%d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)
		t = t % (n + ("%" if str(line[1]).ends_with("Pct") else ""))
	return t


## The short awaken popup: "Thức tỉnh" over the picture big and its one line, "Một lần mỗi trận".
static func open_awaken(overlay: Control, slot: String) -> Modal:
	var kind := GearModel.awaken_kind(slot)
	var m := Modal.new()
	m.name = "AwakenPopup"
	m.open(overlay, "Thức tỉnh", 620)
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.title.add_theme_color_override("font_color", REACHED)
	var big = GearIcon.make(kind, 132)
	m.body.add_child(big)
	var t := awaken_text(kind)
	if t != "":
		var l := m.add_text(t, 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var once := m.add_text("Một lần mỗi trận", 22)
	once.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	once.add_theme_color_override("font_color", Ui.TEXT_DIM)
	m.add_close_x()
	return m


## The set pips of a set state (GearModel.set_state()): `size` pips in groups split at the
## thresholds (2 | 2 | 2), the first `pieces` filled in the set's colour; under each group a bar,
## gold when its threshold is reached. An empty control for {}.
static func set_pips(state: Dictionary, pip: int = 16) -> Control:
	var c := Control.new()
	c.name = "SetPips"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state.is_empty() or int(state.get("size", 0)) <= 0:
		return c
	var n := int(state["size"])
	var gap := pip * 0.35
	var group_gap := pip * 0.8
	var bounds: Array = state.get("thresholds", [])
	var groups := 0
	for t in bounds:
		if int(t) < n:
			groups += 1
	var w := n * pip + (n - 1) * gap + groups * (group_gap - gap)
	c.custom_minimum_size = Vector2(w, pip + 8)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var col := GearGlyphs.set_color(int(state.get("index", 0)))
	var pieces := int(state.get("pieces", 0))
	var reached: Array = state.get("reached", [])
	c.set_meta("filled", mini(pieces, n))
	c.draw.connect(func() -> void:
		var x := 0.0
		var group_start := 0.0
		for i in n:
			var centre := Vector2(x + pip / 2.0, pip / 2.0)
			var r := pip / 2.0
			var diamond := PackedVector2Array([centre + Vector2(0, -r), centre + Vector2(r, 0), centre + Vector2(0, r), centre + Vector2(-r, 0)])
			c.draw_colored_polygon(diamond, col if i < pieces else PIP_EMPTY)
			c.draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(0, 0, 0, 0.5), 1.5, true)
			x += pip
			var end_of_group := bounds.has(i + 1) or i == n - 1
			if end_of_group:
				var lit := reached.has(i + 1)
				c.draw_rect(Rect2(group_start, pip + 3, x - group_start, 4), REACHED if lit else UNREACHED)
				x += group_gap
				group_start = x
			else:
				x += gap)
	return c


## The set row: the pips, then the 6-piece effect's picture (dim until the set is complete); an
## empty row without a set.
static func set_row(state: Dictionary, pip: int = 16, icon_px: int = 40) -> HBoxContainer:
	var row := Ui.hbox(10)
	row.name = "SetRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state.is_empty():
		return row
	row.add_child(set_pips(state, pip))
	if str(state.get("glyph", "")) != "":
		var icon = GearIcon.make(str(state["glyph"]), icon_px)
		icon.name = "SetEffect"
		icon.dim = not bool(state.get("complete", false))
		row.add_child(icon)
	return row
