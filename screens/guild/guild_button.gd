extends RefCounted
## The lobby's "Bang hội" button (beside Mốc thưởng / Nhiệm vụ): a round button with the guild
## crest drawn on it (my guild's colour once known) and the red dot while invitations wait and I
## am not in a guild (GuildState, refreshed by the lobby each time it shows).

const LobbyUi := preload("res://ui/lobby_ui.gd")
const GuildGlyphs := preload("res://ui/guild_glyphs.gd")
const MilestonePage := preload("res://screens/home/milestone_page.gd")


## The button's column (button + caption), `px` round.
static func make(px: int, on_press: Callable) -> Control:
	var col := LobbyUi.icon_button("unknown", "Bang hội", LobbyUi.ICON_COLORS["purple"], on_press, px)
	col.name = "GuildButton"
	var b: Button = col.get_child(0)
	b.icon = null
	var crest := GuildGlyphs.make("crest", int(px * 0.72))
	crest.name = "Crest"
	crest.position = Vector2(px, px) * 0.14
	b.add_child(crest)
	var dot: Control = MilestonePage.dot(20)
	dot.name = "Dot"
	dot.position = Vector2(px - 18, -2)
	b.add_child(dot)
	var render := func() -> void:
		if not is_instance_valid(crest):
			return
		crest.tint = GuildGlyphs.crest_color(GuildState.guild_id())
		dot.visible = dot_shown(GuildState.in_guild(), GuildState.invites.size())
	GuildState.changed.connect(render)
	GuildState.invites_changed.connect(render)
	col.tree_exiting.connect(func() -> void:
		if GuildState.changed.is_connected(render):
			GuildState.changed.disconnect(render)
		if GuildState.invites_changed.is_connected(render):
			GuildState.invites_changed.disconnect(render))
	render.call()
	return col


## The red dot: invitations wait and I am not in a guild.
static func dot_shown(in_guild: bool, invites: int) -> bool:
	return not in_guild and invites > 0
