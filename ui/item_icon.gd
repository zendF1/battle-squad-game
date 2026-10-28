extends RefCounted
## A battle item's icon as a Control: its picture (Art.ICONS, assets/icons/<id>.png) when there
## is one, else the "unknown" icon.

const LobbyUi := preload("res://ui/lobby_ui.gd")
const Art := preload("res://ui/art.gd")


static func make(item_id: String, px: int) -> Control:
	return LobbyUi.icon(Art.item_icon(item_id), px)
