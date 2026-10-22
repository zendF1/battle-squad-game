extends Control
## The teammate slot right of the Home stage (the ranked mode only, screens/home/lobby.gd), at
## about SCALE of the stage. Empty: a rounded-square "+" on a small pedestal, "Mời" under it
## (invite_pressed: the invite popup). With a teammate (PartyModel.parse_member()): their name,
## "Lv.N" and tier badge above their character (CharacterView of their characterId, hands free)
## with their gun on the pedestal (PedestalGun of their gun {kind, tier}); for the host a ready
## mark under it ("Sẵn sàng" green tick / "Chưa sẵn sàng" grey) and a small "×" (kick_pressed), for
## the member (the host shown, always ready) "Rời đội" there instead (leave_pressed). Each player sees the other here: a
## member sees the host.

signal invite_pressed
signal kick_pressed
signal leave_pressed

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")
const CharacterView := preload("res://ui/character_view.gd")
const PedestalGun := preload("res://screens/home/pedestal_gun.gd")
const TierBadge := preload("res://screens/ranked/tier_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")

const SCALE := 0.7
const SIZE := Vector2(330, 500)
const FEET := Vector2(165, 400) # the teammate's feet (the pedestal's top) in the slot
const ART := Vector2(375, 400) # the lobby stage's character rect, scaled by SCALE here
const ART_FEET := 380.0 # its feet from its top on the stage
const PEDESTAL_DROP := 6.0 # the pedestal's centre below the feet (lobby: 528 vs 522)
const PLUS := 150.0
const READY_COLOR := Color(0.35, 0.85, 0.45)

var _pedestal: Control
var _plus: Button
var _plus_label: Label
var _art: CharacterView
var _gun: PedestalGun
var _head: VBoxContainer
var _name: Label
var _level: Label
var _badge: TierBadge
var _ready_mark: PanelContainer
var _ready_text: Label
var _kick: Button
var _leave: Button
var _member := {} # the teammate shown; {} the "+"


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = MOUSE_FILTER_IGNORE
	_pedestal = Control.new()
	_pedestal.mouse_filter = MOUSE_FILTER_IGNORE
	_pedestal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_pedestal.draw.connect(_draw_pedestal)
	add_child(_pedestal)

	_plus = Button.new()
	_plus.name = "InvitePlus"
	_plus.custom_minimum_size = Vector2(PLUS, PLUS)
	_plus.size = Vector2(PLUS, PLUS)
	_plus.position = Vector2(FEET.x - PLUS / 2.0, FEET.y - PLUS - 30.0)
	LobbyUi.style_button(_plus, Color(1, 1, 1, 0), 28, 0) # just the "+", no box
	_plus.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	LobbyUi.set_icon(_plus, "plus", 76)
	_plus.pressed.connect(func() -> void: invite_pressed.emit())
	add_child(_plus)
	_plus_label = LobbyUi.text("Mời", 26, Color.WHITE, true)
	_plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_label.size = Vector2(SIZE.x, 34)
	_plus_label.position = Vector2(0, FEET.y + 34.0) # under the pedestal
	add_child(_plus_label)

	_art = CharacterView.new()
	_art.size = ART * SCALE
	_art.position = FEET - Vector2(ART.x * SCALE / 2.0, ART_FEET * SCALE)
	_art.idle = true
	_art.hands_free = true # the gun rests on the pedestal
	_art.back_aura = false # the worn weapon's ring is mine (PlayerState), not theirs
	add_child(_art)
	_gun = PedestalGun.new()
	_gun.size = PedestalGun.STAGE_RECT.size
	_gun.scale = Vector2.ONE * SCALE
	_gun.position = FEET + (PedestalGun.STAGE_RECT.position - PedestalGun.FEET) * SCALE
	add_child(_gun)

	_head = Ui.vbox(2)
	_head.mouse_filter = MOUSE_FILTER_IGNORE
	_head.size = Vector2(SIZE.x, 0)
	_head.position = Vector2(0, _art.position.y - 58.0) # over the figure's head
	add_child(_head)
	_name = LobbyUi.text("", 28, Color.WHITE, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.custom_minimum_size.x = SIZE.x
	_head.add_child(_name)
	var row := Ui.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_head.add_child(row)
	_badge = TierBadge.make("", 3, 30)
	row.add_child(_badge)
	_level = LobbyUi.text("", 22, LobbyUi.GOLD, true)
	_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_level)

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
	add_child(_ready_mark)

	_kick = LobbyUi.round_button("close", 46, LobbyUi.ICON_COLORS["red"], 0.5)
	_kick.name = "Kick"
	_kick.tooltip_text = "Mời ra khỏi đội"
	_kick.position = Vector2(SIZE.x - 58, _art.position.y + 20.0)
	_kick.pressed.connect(func() -> void: kick_pressed.emit())
	add_child(_kick)
	_leave = LobbyUi.pill_button("Rời đội", 22, 48, "back")
	LobbyUi.texture_button(_leave, "button_navy", 14)
	_leave.name = "LeaveParty"
	_leave.pressed.connect(func() -> void: leave_pressed.emit())
	add_child(_leave)
	show_member({}, false)


## Shows the teammate `m` (PartyModel.parse_member()) or, with {}, the "+". host_view: I am the
## host (the "×"); otherwise the member (the "Rời đội").
func show_member(m: Dictionary, host_view: bool) -> void:
	_member = m
	var empty := m.is_empty()
	_plus.visible = empty
	_plus_label.visible = empty
	for c in [_art, _gun, _head, _ready_mark]:
		c.visible = not empty
	_kick.visible = not empty and host_view
	_leave.visible = not empty and not host_view
	if empty:
		_pedestal.queue_redraw()
		return
	_art.character_id = str(m.get("characterId", ""))
	var g: Dictionary = m.get("gun", {})
	_gun.set_gun(str(g.get("kind", "")), str(g.get("tier", "")))
	_name.text = str(m.get("displayName", ""))
	var level := int(m.get("level", 0))
	_level.text = "Lv.%d" % level if level > 0 else ""
	_badge.tier = str(m.get("tier", ""))
	_badge.division = int(m.get("division", 3))
	_badge.visible = _badge.tier != ""
	var ready := bool(m.get("ready", false))
	_ready_mark.visible = host_view # the member sees the host, always ready: "Rời đội" there instead
	_ready_text.text = "Sẵn sàng" if ready else "Chưa sẵn sàng"
	_ready_text.add_theme_color_override("font_color", READY_COLOR if ready else Ui.TEXT_DIM)
	_ready_mark.get_child(0).get_node("Tick").visible = ready
	_place_marks()
	_pedestal.queue_redraw()


## The teammate shown ({} the "+").
func member() -> Dictionary:
	return _member


func _place_marks() -> void:
	var w := _ready_mark.get_combined_minimum_size().x
	_ready_mark.position = Vector2((SIZE.x - w) / 2.0, FEET.y + 40.0)
	var lw := _leave.get_combined_minimum_size().x
	_leave.position = Vector2((SIZE.x - lw) / 2.0, FEET.y + 34.0)


func _draw_pedestal() -> void:
	var tex := Art.env("pedestal")
	if tex == null:
		return
	var centre := FEET + Vector2(0, PEDESTAL_DROP * SCALE)
	_pedestal.draw_texture_rect(tex, Rect2(centre - Art.PEDESTAL_CENTER * SCALE, tex.get_size() * SCALE), false)
