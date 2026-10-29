extends PanelContainer
## The compact character card, pictures only: the element chain (ui/element_chain.gd: beaten by →
## element → beats) beside the skill's picture (ui/skill_button.gd, a tap opens the skill's popup),
## Lực chiến (ui/power_tag.gd, the server's number; hidden while unknown), heart / sword / shield
## with Máu, Sát thương, Phòng thủ (LobbyModel.stat_pairs() order), and "Mua ở Shop" for a character
## not owned (buy_pressed). Shows a LobbyModel.character_info() (show_character()). Used by the
## lobby's left column and the first-login character pick (screens/onboarding.gd: no power, no buy).

signal buy_pressed

const Ui := preload("res://ui/ui.gd")
const Art := preload("res://ui/art.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const ElementChain := preload("res://ui/element_chain.gd")
const SkillButton := preload("res://ui/skill_button.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const PowerTag := preload("res://ui/power_tag.gd")
const Skills := preload("res://match/skills.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## Máu, Sát thương, Phòng thủ (LobbyModel.stat_pairs() order) as pictures.
const STAT_ICONS := ["heart", "sword", "shield"]
const W := 360

## The node the skill popup opens on (null: the current scene).
var popup_host: Node
var chain: ElementChain
var skill: SkillButton
var power: PowerTag
var stats: HBoxContainer
var values: Array[Label] = []
var buy: Button

var _character_id := ""
var _with_power := true
var _with_buy := true


## A card; with_power: the Lực chiến row; with_buy: "Mua ở Shop" under a character not owned.
static func make(with_power: bool = true, with_buy: bool = true):
	var c = load("res://screens/home/character_card.gd").new()
	c._with_power = with_power
	c._with_buy = with_buy
	c._build()
	return c


func _build() -> void:
	name = "InfoCard"
	add_theme_stylebox_override("panel", Art.ui_box("panel", 18)) # LobbyUi.panel()'s look
	custom_minimum_size.x = W
	var col := Ui.vbox(14)
	add_child(col)
	var top := Ui.hbox(10)
	col.add_child(top)
	chain = ElementChain.make("", 58)
	chain.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(chain)
	skill = SkillButton.make(68)
	skill.name = "InfoSkill"
	skill.pressed.connect(_show_skill)
	top.add_child(skill)
	power = PowerTag.make(40, 30)
	power.name = "InfoPower"
	col.add_child(power)
	power.visible = false
	stats = Ui.hbox(0)
	stats.name = "InfoStats"
	col.add_child(stats)
	for i in STAT_ICONS.size():
		var chip := Ui.hbox(6)
		chip.alignment = BoxContainer.ALIGNMENT_CENTER
		chip.size_flags_horizontal = SIZE_EXPAND_FILL
		chip.size_flags_stretch_ratio = 1.0
		chip.add_child(GlyphIcon.make(STAT_ICONS[i], 32))
		var value := LobbyUi.text("", 24, Color.WHITE, true)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(value)
		values.append(value)
		stats.add_child(chip)
	buy = Ui.button("Mua ở Shop", 22)
	buy.name = "InfoBuy"
	LobbyUi.style_button(buy, LobbyUi.ICON_COLORS["orange"], 14, 8)
	buy.add_theme_font_override("font", LobbyUi.bold())
	buy.custom_minimum_size = Vector2(0, 56)
	buy.pressed.connect(func() -> void: buy_pressed.emit())
	buy.visible = false
	col.add_child(buy)


## Shows character `id` from its LobbyModel.character_info() `info`.
func show_character(id: String, info: Dictionary) -> void:
	_character_id = id
	chain.set_element(GameData.character_element(id))
	skill.skill_id = str(Skills.for_character(id).get("id", ""))
	skill.visible = info["skill"] != ""
	skill.tooltip_text = info["skill"]
	stats.visible = not info["stats"].is_empty()
	for i in values.size():
		var pair: Array = info["stats"][i] if i < info["stats"].size() else ["", ""]
		values[i].text = pair[1]
		values[i].get_parent().tooltip_text = pair[0]
	buy.visible = _with_buy and info["owned"] == false
	if _with_power:
		power.set_power(int(info["power"]))
	else:
		power.visible = false


## The character shown.
func character_id() -> String:
	return _character_id


func _show_skill() -> void:
	var host := popup_host
	if host == null and is_inside_tree():
		host = get_tree().current_scene
	if host == null:
		host = get_parent()
	SkillButton.show_popup(host, _character_id)
