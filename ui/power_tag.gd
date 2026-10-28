extends HBoxContainer
## Lực chiến as a picture and a number: the power glyph (ui/glyph_icon.gd "power") then the
## server's number in gold ("12.345", LeaderboardModel.power_text). Hidden while the power is
## unknown (-1) unless keep_unknown ("—"). The tooltip names it.

const GlyphIcon := preload("res://ui/glyph_icon.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const LeaderboardModel := preload("res://screens/home/leaderboard_model.gd")

const COLOR := Color(1.0, 0.84, 0.3)

var keep_unknown := false
var value := -1
var label: Label


## A tag with a `px` glyph and `font_size` text.
static func make(px: int, font_size: int, color: Color = COLOR):
	var t = load("res://ui/power_tag.gd").new()
	t.name = "PowerTag"
	t.add_theme_constant_override("separation", maxi(4, px / 6))
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.mouse_filter = MOUSE_FILTER_PASS
	t.tooltip_text = "Lực chiến"
	t.add_child(GlyphIcon.make("power", px))
	t.label = LobbyUi.text("", font_size, color, true)
	t.label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.label.mouse_filter = MOUSE_FILTER_IGNORE
	t.add_child(t.label)
	t.set_power(-1)
	return t


func set_power(power: int) -> void:
	value = power
	label.text = LeaderboardModel.power_text(power)
	visible = power >= 0 or keep_unknown
