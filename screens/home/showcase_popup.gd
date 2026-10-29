extends "res://ui/modal.gd"
## A player's showcase (a tap on a leaderboard podium place or row, mine too): the player's name as
## the title with their grade's insignia and level under it, then three columns mirrored round the
## centre: the gear (six hexagons in the game data's slot order: the piece's icon in its upgrade
## level's tint and aura, the "+N" pill, the socketed gems as coloured gems with their level), the
## character standing on the lobby pedestal (player_figure.gd: their look, weapon, back aura) with
## its Lực chiến under it (and their main set's pips with its 6-piece picture under that; the set
## aura round the figure from a 6-piece set: look.setAura / gear.setAura), and the stats (ShowcaseModel.stat_cells: the final stat as a picture and
## a number, the allocated points under it with the level chevrons); the crit chance centred under
## them when there is one. Under all, the characters they own as heads (the shown one ringed in
## gold): a tap shows that one. GET /players/{id}/showcase through PlayerState.fetch_showcase().
## No sentences: the X (or a tap outside) closes it.

const GlyphIcon := preload("res://ui/glyph_icon.gd")
const PowerTag := preload("res://ui/power_tag.gd")
const Art := preload("res://ui/art.gd")
const LoadStatus := preload("res://ui/load_status.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const PlayerFigure := preload("res://screens/home/player_figure.gd")
const ShowcaseModel := preload("res://screens/home/showcase_model.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const UpgradeAura := preload("res://screens/home/upgrade_aura.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const GearModel := preload("res://screens/home/gear_model.gd")
const GearUi := preload("res://screens/home/gear_ui.gd")

const WIDTH := 1240
const SIDE_W := 330 # the gear and the stats columns (equal: the stage stays centred)
const STAGE := Vector2(400, 430)
const FIGURE_SCALE := 0.8
const HEX := Vector2(100, 115)
const GEM := 30
const HEAD := 72
const GOLD := Color(1.0, 0.8, 0.22)
const POINTS := Color(0.75, 0.85, 1.0)

var player_id := ""
var showcase := {} # ShowcaseModel.parse(), {} until loaded
var _status: LoadStatus
var _header: HBoxContainer
var _content: VBoxContainer
var _gear: GridContainer
var _figure: Control
var _power: Control
var _set_box: CenterContainer # the main set's row under the power
var _stats: VBoxContainer
var _switcher: HBoxContainer
var _request := 0 # the latest fetch: an older answer is dropped


## Opens the showcase of `entry` (a LeaderboardModel row: player_id, name) over `host`: their
## strongest character first (the server's default, which the board draws once their power is known).
static func show_player(host: Node, entry: Dictionary):
	var m = load("res://screens/home/showcase_popup.gd").new()
	m.name = "Showcase"
	m.player_id = str(entry.get("player_id", ""))
	m.open(host, str(entry.get("name", "")), WIDTH)
	m.add_close_x()
	m._build()
	m.load_character("")
	return m


func _build() -> void:
	body.add_theme_constant_override("separation", 10)
	_header = Ui.hbox(14)
	_header.name = "Header"
	_header.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_header)
	_status = LoadStatus.new()
	body.add_child(_status)
	_content = Ui.vbox(12)
	_content.name = "Content"
	body.add_child(_content)
	var cols := Ui.hbox(24)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(cols)
	_gear = GridContainer.new()
	_gear.name = "Gear"
	_gear.columns = 2
	_gear.add_theme_constant_override("h_separation", 26)
	_gear.add_theme_constant_override("v_separation", 14)
	cols.add_child(_side(_gear))
	var stage := Ui.vbox(4)
	stage.name = "Stage"
	stage.custom_minimum_size.x = STAGE.x
	cols.add_child(stage)
	_figure = PlayerFigure.make({}, FIGURE_SCALE, true)
	_figure.name = "Figure"
	_figure.custom_minimum_size = STAGE - Vector2(0, 50)
	_figure.foot_margin = 40.0
	stage.add_child(_figure)
	_power = PowerTag.make(40, 32)
	_power.name = "Power"
	stage.add_child(_power)
	_set_box = CenterContainer.new()
	_set_box.name = "Set"
	_set_box.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(_set_box)
	_stats = Ui.vbox(18)
	_stats.name = "Stats"
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(_side(_stats))
	_switcher = Ui.hbox(18)
	_switcher.name = "Switcher"
	_switcher.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_switcher)
	_content.visible = false


## A side column SIDE_W wide with `c` centred in it.
func _side(c: Control) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size.x = SIDE_W
	box.add_child(c)
	return box


## Loads and shows character `character_id` of the player ("" their power character).
func load_character(character_id: String) -> void:
	_request += 1
	var ticket := _request
	_status.show_loading()
	var res: Dictionary = await PlayerState.fetch_showcase(player_id, character_id)
	if ticket != _request or not is_inside_tree():
		return
	if res.has("error"):
		_status.show_error(str(res["error"]), load_character.bind(character_id))
		return
	_status.clear()
	show_showcase(res["showcase"])


## Shows a parsed showcase (ShowcaseModel.parse()).
func show_showcase(s: Dictionary) -> void:
	showcase = s
	_content.visible = not s.is_empty()
	if s.is_empty():
		return
	title.text = str(s["name"])
	_render_header(s)
	var c: Dictionary = s["character"]
	_figure.show_look(ShowcaseModel.look(c, PlayerState.catalog))
	_power.set_power(int(c["power"]))
	Ui.clear(_set_box)
	_set_box.add_child(GearUi.set_row(GearModel.set_state(c.get("gear", {})), 16, 38))
	_render_gear(c)
	_render_stats(c)
	_render_switcher(s)


func _render_header(s: Dictionary) -> void:
	Ui.clear(_header)
	var ins := GradeBadge.make(str(s["grade"]), int(s["division"]), 54)
	ins.name = "Insignia"
	ins.tooltip_text = RankModel.label(str(s["grade"]), int(s["division"]))
	_header.add_child(ins)
	var lv := LobbyUi.text("Lv.%d" % int(s["level"]), 28, GOLD, true)
	lv.name = "Level"
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(lv)


# ── Gear ────────────────────────────────────────────────────────────────────

func _render_gear(c: Dictionary) -> void:
	Ui.clear(_gear)
	var worn: Dictionary = c["equipment"]
	for slot in EquipmentModel.slots():
		_gear.add_child(_slot(str(slot), worn.get(slot, {})))


## One slot: the hexagon with the piece's icon (the slot's silhouette when empty), the "+N" pill
## over its foot and its gems down its right side.
func _slot(slot: String, piece: Dictionary) -> Control:
	var cell := Control.new()
	cell.name = "Slot_" + slot
	cell.custom_minimum_size = Vector2(HEX.x + GEM + 4, HEX.y + 10)
	cell.mouse_filter = MOUSE_FILTER_IGNORE
	var level := int(piece.get("upgradeLevel", 0))
	var icon: TextureRect
	if piece.is_empty():
		icon = LobbyUi.icon(Art.equipment_slot_icon(slot), 52)
		icon.modulate = Color(0.75, 0.85, 1.0, 0.3)
		icon.custom_minimum_size = Vector2(52, 52)
	else:
		var item := EquipmentModel.item_of_piece(PlayerState.catalog, piece)
		icon = LobbyUi.icon(Art.equipment_icon(slot, EquipmentModel.tier(item), EquipmentModel.weapon_kind(item)), 78)
		icon.custom_minimum_size = Vector2(78, 78)
		icon.tooltip_text = str(piece.get("name", ""))
		icon.mouse_filter = MOUSE_FILTER_PASS
	icon.size = icon.custom_minimum_size
	var frame := EquipmentUi.hex_frame(HEX, level, icon, 4.0)
	frame.texture = Art.equipment_frame("hex_filled" if not piece.is_empty() else "hex_empty")
	if piece.is_empty():
		frame.self_modulate = Color.WHITE
	cell.add_child(frame)
	var plus := ShowcaseModel.upgrade_text(piece)
	if plus != "":
		var pill := PanelContainer.new()
		pill.name = "Plus"
		pill.mouse_filter = MOUSE_FILTER_IGNORE
		pill.add_theme_stylebox_override("panel", Art.equipment_badge_box(4))
		var l := LobbyUi.text(plus, 19, UpgradeModel.name_color(piece), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.add_child(l)
		cell.add_child(pill)
		var w := pill.get_combined_minimum_size().x
		pill.position = Vector2((HEX.x - w) / 2.0, HEX.y - 22)
	var gems := ShowcaseModel.gems(piece)
	for i in gems.size():
		var g: Dictionary = gems[i]
		var gem := _gem(g)
		gem.name = "Gem%d" % (i + 1)
		gem.position = Vector2(HEX.x + 2, 14 + i * (GEM + 18))
		cell.add_child(gem)
	return cell


## A gem: its colour's cut gem and its level under it.
func _gem(g: Dictionary) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(GEM, GEM + 16)
	box.size = box.custom_minimum_size
	box.mouse_filter = MOUSE_FILTER_IGNORE
	var icon = GlyphIcon.make("gem", GEM, g["color"])
	box.add_child(icon)
	var l := LobbyUi.text(str(g["level"]), 15, Color.WHITE, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(-6, GEM - 6)
	l.size = Vector2(GEM + 12, 20)
	box.add_child(l)
	return box


# ── Stats ───────────────────────────────────────────────────────────────────

func _render_stats(c: Dictionary) -> void:
	Ui.clear(_stats)
	var cells := ShowcaseModel.stat_cells(c)
	var grid := GridContainer.new()
	grid.name = "StatGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 18)
	_stats.add_child(grid)
	# two columns: the first three down the left, the other three down the right
	for row in 3:
		for col in 2:
			var i: int = col * 3 + row
			if i < cells.size():
				grid.add_child(_stat(cells[i]))
	var crit := ShowcaseModel.crit_text(c)
	if crit != "":
		var r := Ui.hbox(8)
		r.name = "Crit"
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_child(GlyphIcon.make("crit", 38))
		var l := LobbyUi.text(crit, 26, Color.WHITE, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(l)
		_stats.add_child(r)


## A stat: its picture, the final number and, under it, the allocated points (level chevrons).
func _stat(cell: Dictionary) -> Control:
	var h := Ui.hbox(8)
	h.name = "Stat_" + str(cell["key"])
	h.custom_minimum_size.x = 150
	h.add_child(GlyphIcon.make(str(cell["glyph"]), 44))
	var col := Ui.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(col)
	var v := LobbyUi.text(str(cell["value"]), 26, Color.WHITE, true)
	v.name = "Value"
	col.add_child(v)
	var pts := Ui.hbox(4)
	pts.name = "Points"
	pts.add_child(GlyphIcon.make("level", 20))
	var n := LobbyUi.text(str(cell["points"]), 18, POINTS, true)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pts.add_child(n)
	col.add_child(pts)
	return h


# ── Characters ──────────────────────────────────────────────────────────────

func _render_switcher(s: Dictionary) -> void:
	Ui.clear(_switcher)
	var owned: Array = s["characters"]
	_switcher.visible = owned.size() > 1
	var shown := str(s["character"]["id"])
	for o in owned:
		var id := str(o["id"])
		var b := Button.new()
		b.name = "Pick_" + id
		b.flat = true
		b.focus_mode = FOCUS_NONE
		b.custom_minimum_size = Vector2(HEAD, HEAD)
		b.tooltip_text = GameData.character_name(id)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var head = HeadIcon.make(id, id, HEAD)
		head.lobby = true
		head.ring_width = 5.0 if id == shown else 3.0
		head.ring = GOLD if id == shown else Color(1, 1, 1, 0.35)
		head.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		b.add_child(head)
		if id != shown:
			b.modulate = Color(1, 1, 1, 0.75)
			b.pressed.connect(load_character.bind(id))
		_switcher.add_child(b)
