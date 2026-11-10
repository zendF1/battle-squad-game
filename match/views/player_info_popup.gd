extends "res://ui/modal.gd"
## A match player's info popup (a tap on the HUD's turn portrait, match/hud.gd portrait_pressed):
## the player's head and name, and when they play with a guild bonus (BattlePlayerState.guild,
## read once by the server at the match's start) the guild's crest with its level and the guild
## skills it brings, as pictures: a heart / shield with "+5%" (GuildModel.bonus_icons(); the server's
## summed percentages, never the client's). Bots, bosses and players without a guild show only the
## head and name. A tap outside or the X closes it; it never touches the match.

const GuildModel := preload("res://screens/guild/guild_model.gd")
const GuildGlyphs := preload("res://ui/guild_glyphs.gd")
const GuildUi := preload("res://screens/guild/guild_ui.gd")
const HeadIcon := preload("res://screens/home/head_icon.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")


## Opens over `host` for match player `player` (a BattlePlayerState dict).
func open_for(host: Node, player: Dictionary) -> void:
	var player_name := str(player.get("displayName", ""))
	open(host, player_name, 560)
	add_close_x()
	var head = HeadIcon.make(str(player.get("characterId", "")), player_name, 110)
	head.name = "Head"
	head.size_flags_horizontal = SIZE_SHRINK_CENTER
	body.add_child(head)
	var bonus := GuildModel.match_bonus(player)
	if bonus.is_empty():
		return
	var guild := LobbyUi.panel(16, 18, Color(0.06, 0.09, 0.22, 0.85))
	guild.name = "Guild"
	body.add_child(guild)
	var row := Ui.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	guild.add_child(row)
	var crest := GuildGlyphs.crest(str(bonus["guild_id"]), 64)
	crest.tooltip_text = "Bang hội"
	crest.mouse_filter = MOUSE_FILTER_PASS
	row.add_child(crest)
	var lv := Ui.hbox(4)
	lv.add_child(GlyphIcon.make("level", 30))
	var l := LobbyUi.text(str(int(bonus["level"])), 26, LobbyUi.GOLD, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.add_child(l)
	row.add_child(lv)
	var skills := Ui.hbox(10)
	skills.name = "GuildSkills"
	for s in GuildModel.bonus_icons(bonus):
		skills.add_child(GuildUi.skill_chip(s, 36))
	row.add_child(skills)
