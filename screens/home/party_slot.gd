extends Control
## The teammate slot right of the Home stage (the party modes, screens/home/lobby.gd): the lobby
## stage's presentation at SCALE, in the open scene (no card, no frame). Empty: a "+" on a round
## translucent disc over the plain dais, "Mời" under it (invite_pressed: the invite popup). With a
## teammate (PartyModel.parse_member()): their title's plate (ui/title_plate.gd, nothing without
## one), their character's element badge and name, the level glyph and level, their character
## (CharacterView of their characterId, hands free) standing on their rankBadge's dais
## (screens/ranked/grade_pedestal.gd; assets/env/pedestal.png without a badge) with their gun on it
## (PedestalGun of their gun {kind, tier}); for the host a ready mark under it ("Sẵn sàng" green
## tick / "Chưa sẵn sàng" grey) and a small "×" (kick_pressed), for the member (the host shown,
## always ready) "Rời đội" there instead (leave_pressed). Each player sees the other here: a member
## sees the host. A boss party has three slots (screens/home/party_layout.gd, the slot scaled
## down): a member sees the host ("Rời đội") and the other members (their ready mark); an empty
## slot in a member's view is a dim "+" with "Trống" (only the host invites).

signal invite_pressed
signal kick_pressed
signal leave_pressed

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const CharacterView := preload("res://ui/character_view.gd")
const PedestalGun := preload("res://screens/home/pedestal_gun.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const GradePedestal := preload("res://screens/ranked/grade_pedestal.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const SCALE := 0.7
const SIZE := Vector2(330, 500)
const FEET := Vector2(165, 400) # the teammate's feet (the pedestal's top) in the slot
const ART := Vector2(375, 400) # the lobby stage's character rect, scaled by SCALE here
const ART_FEET := 380.0 # its feet from its top on the stage
const DAIS_K := 0.8 # a badge holder's dais: this much of the stage's (room for the ready mark)
const PEDESTAL_DROP := 6.0 # the pedestal's centre below the feet (lobby: 528 vs 522)
const PLUS := 150.0
const PLUS_DISC := 112.0
const PLUS_DISC_COLOR := Color(0.05, 0.08, 0.2, 0.55)
const READY_COLOR := Color(0.35, 0.85, 0.45)
## The stage's head (lobby.gd: the title's plate, the name, the level) and its gap over the
## character's rect, scaled by SCALE here.
const TITLE_H := 60.0 * SCALE
const NAME_PX := 31 # the stage's 44
const LEVEL_PX := 18 # the stage's 24
const GLYPH_PX := 20 # the stage's 28
const HEAD_GAP := 102.0 # lobby.gd: the art's top (142) below the name (HEAD_Y 40)

var _pedestal: Control
var _plus: Button
var _plus_label: Label
var _art: CharacterView
var _gun: PedestalGun
var _head: VBoxContainer
var _title: TitlePlate
var _name: Label
var _name_row: HBoxContainer # the teammate's character's element badge before the name
var _level: Label
var _ready_mark: PanelContainer
var _ready_text: Label
var _kick: Button
var _leave: Button
var _member := {} # the teammate shown; {} the "+"
var _body: Control # everything


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	_body = Control.new()
	_body.name = "Body"
	_body.size = SIZE
	_body.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_body)
	_pedestal = Control.new()
	_pedestal.name = "Dais"
	_pedestal.mouse_filter = MOUSE_FILTER_IGNORE
	_pedestal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_pedestal.draw.connect(_draw_pedestal)
	_body.add_child(_pedestal)

	_plus = Button.new()
	_plus.name = "InvitePlus"
	_plus.custom_minimum_size = Vector2(PLUS, PLUS)
	_plus.size = Vector2(PLUS, PLUS)
	_plus.position = Vector2(FEET.x - PLUS / 2.0, FEET.y - PLUS - 30.0)
	# the "+" on a round translucent navy disc (PLUS_DISC across), so it reads on a bright
	# background (snow, sky)
	LobbyUi.style_button(_plus, PLUS_DISC_COLOR, int(PLUS_DISC / 2.0), 0)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := _plus.get_theme_stylebox(state) as StyleBoxFlat
		if box != null:
			box.set_expand_margin_all(-(PLUS - PLUS_DISC) / 2.0)
	_plus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	LobbyUi.set_icon(_plus, "plus", 76)
	_plus.pressed.connect(func() -> void: invite_pressed.emit())
	_body.add_child(_plus)
	_plus_label = LobbyUi.text("Mời", 26, Color.WHITE, true)
	_plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	LobbyUi.outline(_plus_label, 8) # reads on a bright ground (snow)
	_plus_label.size = Vector2(SIZE.x, 34)
	_plus_label.position = Vector2(0, FEET.y + 34.0) # under the pedestal
	_body.add_child(_plus_label)

	_art = CharacterView.new()
	_art.size = ART * SCALE
	_art.position = FEET - Vector2(ART.x * SCALE / 2.0, ART_FEET * SCALE)
	_art.idle = true
	_art.hands_free = true # the gun rests on the pedestal
	_art.back_aura = false # the worn weapon's ring is mine (PlayerState), not theirs
	_body.add_child(_art)
	_gun = PedestalGun.new()
	_gun.size = PedestalGun.STAGE_RECT.size
	_gun.scale = Vector2.ONE * SCALE
	_gun.position = FEET + (PedestalGun.STAGE_RECT.position - PedestalGun.FEET) * SCALE
	_body.add_child(_gun)

	_head = Ui.vbox(0)
	_head.name = "Head"
	_head.mouse_filter = MOUSE_FILTER_IGNORE
	_head.custom_minimum_size = Vector2(SIZE.x, 0)
	_head.size = Vector2(SIZE.x, 0)
	_body.add_child(_head)
	_title = TitlePlate.new()
	_title.plate_height = TITLE_H
	_title.max_width = SIZE.x
	_title.size_flags_horizontal = SIZE_SHRINK_CENTER
	_head.add_child(_title)
	_name = LobbyUi.text("", NAME_PX, Color.WHITE, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_row = ElementBadge.name_row(_name, "", NAME_PX, 7)
	_head.add_child(_name_row)
	_level = LobbyUi.text("", LEVEL_PX, LobbyUi.GOLD, true)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.add_child(GlyphIcon.level_row(_level, GLYPH_PX))

	_ready_mark = LobbyUi.panel(0, 16, Color(0, 0, 0, 0.45))
	_ready_mark.mouse_filter = MOUSE_FILTER_IGNORE
	var mark_row := Ui.hbox(6)
	mark_row.mouse_filter = MOUSE_FILTER_IGNORE
	_ready_mark.add_child(mark_row)
	var tick := LobbyUi.icon("check", 24)
	tick.name = "Tick"
	mark_row.add_child(tick)
	_ready_text = LobbyUi.text("", 21, Color.WHITE, true)
	mark_row.add_child(_ready_text)
	_body.add_child(_ready_mark)

	_kick = LobbyUi.round_button("close", 46, LobbyUi.ICON_COLORS["red"], 0.5)
	_kick.name = "Kick"
	_kick.tooltip_text = "Mời ra khỏi đội"
	_kick.position = Vector2(SIZE.x - 58, _art.position.y + 20.0)
	_kick.pressed.connect(func() -> void: kick_pressed.emit())
	_body.add_child(_kick)
	_leave = LobbyUi.pill_button("Rời đội", 22, 48, "back")
	LobbyUi.texture_button(_leave, "button_navy", 14)
	_leave.name = "LeaveParty"
	_leave.pressed.connect(func() -> void: leave_pressed.emit())
	_body.add_child(_leave)
	show_member({}, false)


## Shows the teammate `m` (PartyModel.parse_member()) or, with {}, the "+". host_view: I am the
## host (the "×"); otherwise the member ("Rời đội" on the host's card, is_host_card; another
## member's card shows its ready mark). can_invite false: the "+" is off ("Trống").
func show_member(m: Dictionary, host_view: bool, is_host_card: bool = true, can_invite: bool = true) -> void:
	_member = m
	var empty := m.is_empty()
	_plus.visible = empty
	_plus_label.visible = empty
	_plus.disabled = not can_invite
	_plus.modulate.a = 1.0 if can_invite else 0.4
	_plus_label.text = "Mời" if can_invite else "Trống"
	_plus_label.modulate.a = 1.0 if can_invite else 0.6
	for c in [_art, _gun, _head, _ready_mark]:
		c.visible = not empty
	_kick.visible = not empty and host_view
	_leave.visible = not empty and not host_view and is_host_card
	if empty:
		_pedestal.queue_redraw()
		return
	_art.character_id = str(m.get("characterId", ""))
	var g: Dictionary = m.get("gun", {})
	_gun.set_gun(str(g.get("kind", "")), str(g.get("tier", "")))
	_name.text = str(m.get("displayName", ""))
	var element := GameData.character_element(str(m.get("characterId", "")))
	ElementBadge.set_row_element(_name_row, element)
	ElementBadge.fit_label(_name, SIZE.x - (2 * (NAME_PX + 7) if element != "" else 0))
	var level := int(m.get("level", 0))
	GlyphIcon.show_level(_level, str(level) if level > 0 else "")
	_title.set_title(m.get("title", {}) if m.get("title") is Dictionary else {})
	_head.position = Vector2(0, head_y(_title.has_title()))
	var ready := bool(m.get("ready", false))
	_ready_mark.visible = host_view or not is_host_card # the member sees the host, always ready: "Rời đội" there instead
	_ready_text.text = "Sẵn sàng" if ready else "Chưa sẵn sàng"
	_ready_text.add_theme_color_override("font_color", READY_COLOR if ready else Ui.TEXT_DIM)
	_ready_mark.get_child(0).get_node("Tick").visible = ready
	_place_marks()
	_pedestal.queue_redraw()


## The head's top in the slot: the name HEAD_GAP × SCALE over the character's rect, as on the
## stage; the title's plate (with_title) rises above it, the name stays put.
static func head_y(with_title: bool) -> float:
	var art_top := FEET.y - ART_FEET * SCALE
	return art_top - HEAD_GAP * SCALE - (TITLE_H - 4.0 * SCALE if with_title else 0.0)


## The teammate shown ({} the "+").
func member() -> Dictionary:
	return _member


func _place_marks() -> void:
	var w := _ready_mark.get_combined_minimum_size().x
	_ready_mark.position = Vector2((SIZE.x - w) / 2.0, FEET.y + 40.0)
	var lw := _leave.get_combined_minimum_size().x
	_leave.position = Vector2((SIZE.x - lw) / 2.0, FEET.y + 34.0)


func _draw_pedestal() -> void:
	var centre := FEET + Vector2(0, PEDESTAL_DROP * SCALE)
	if not _member.is_empty() and GradePedestal.draw(_pedestal, centre, GradePedestal.STAGE_RX * SCALE * DAIS_K, str(_member.get("rankBadge", ""))):
		return # a badge holder's dais
	var tex := Art.env("pedestal")
	if tex == null:
		return
	_pedestal.draw_texture_rect(tex, Rect2(centre - Art.PEDESTAL_CENTER * SCALE, tex.get_size() * SCALE), false)
