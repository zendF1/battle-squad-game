extends RefCounted
## Small guild widgets shared by the guild page and the match's player info popup.

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const GuildGlyphs := preload("res://ui/guild_glyphs.gd")
const GuildModel := preload("res://screens/guild/guild_model.gd")
const Fmt := preload("res://core/fmt.gd")

const DIM := Color(0.75, 0.82, 0.95)
const LOCKED := Color(1, 1, 1, 0.38)


## A guild skill: the stat's picture with "+5%"; one not reached greyed, a lock and "Lv.5".
static func skill_chip(s: Dictionary, px: int = 38) -> Control:
	var chip := PanelContainer.new()
	chip.name = "Skill_%s_%d" % [s["stat"], int(s.get("level", 0))]
	var unlocked: bool = s.get("unlocked", true)
	chip.add_theme_stylebox_override("panel", LobbyUi.box(Color(0.1, 0.16, 0.34, 0.9) if unlocked else Color(0, 0, 0, 0.35), 12, 6,
		Color(1, 0.8, 0.3, 0.6) if unlocked else Color(1, 1, 1, 0.12), 2))
	chip.tooltip_text = ("Máu" if s["stat"] == "hp" else "Phòng thủ") + " " + GuildModel.percent_text(int(s["percent"]))
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := Ui.hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var icon = GlyphIcon.make("heart" if s["stat"] == "hp" else "shield", px)
	row.add_child(icon)
	var pct := LobbyUi.text(GuildModel.percent_text(int(s["percent"])), int(px * 0.6), Color.WHITE, true)
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(pct)
	if not unlocked:
		icon.modulate = LOCKED
		pct.modulate = LOCKED
		row.add_child(GuildGlyphs.make("lock", int(px * 0.7)))
		var lv := LobbyUi.text("Lv.%d" % int(s["level"]), int(px * 0.55), DIM, true)
		lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lv)
	return chip


## The guild EXP a goal pays: the crest with "+100" (done: a check over it).
static func exp_chip(exp: int, guild_id: String, done: bool = false) -> Control:
	var chip := Ui.hbox(4)
	chip.name = "ExpReward"
	chip.tooltip_text = "EXP bang hội"
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var crest := GuildGlyphs.crest(guild_id, 40)
	chip.add_child(crest)
	var l := LobbyUi.text("+%s" % Fmt.thousands(exp), 24, LobbyUi.GOLD, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(l)
	if done:
		chip.add_child(LobbyUi.icon("check", 30))
	return chip
