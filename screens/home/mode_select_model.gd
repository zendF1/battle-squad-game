extends RefCounted
## The Mode Select screen ("Chọn chế độ") without UI: its sections, one per game data category
## (modes.categories, in order: PvP, Boss, ...) with the lobby modes of that category in their
## order (LobbyModel.modes()), a mode's card (icon, name; the description and the party size for
## its "i" popup; ranked, selected), the placeholder of a category without modes ("Sắp ra mắt"), and what choosing a mode
## does to the party (switch_action()). Modes and categories are the game data's: a new one an admin
## adds shows by itself. The client keeps only the presentation per id: the icon key → icon table,
## the categories drawn as a grid of small cards (boss) and the placeholder line per category.

const LobbyModel := preload("res://screens/home/lobby_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## How a section draws its modes: one big card per mode in a row, or a grid of small cards.
const CARDS := "cards"
const GRID := "grid"
const GRID_CATEGORIES := ["boss"]

## A category without modes yet shows one disabled card.
const SOON := "Sắp ra mắt"
const SOON_TEXT := {"boss": "Phòng 4 người cùng đánh boss"}
const SOON_DEFAULT := "Chế độ mới sẽ sớm có ở đây"

## The game data's icon key → an icon of assets/icons; any other key (or "") → FALLBACK_ICON.
const ICONS := {
	"casual": "battle", "swords": "battle", "battle": "battle", "pvp": "battle",
	"ranked": "upgrade", "trophy": "upgrade", "rank": "upgrade",
	"bot": "weapon", "robot": "weapon", "ai": "weapon",
	"practice": "power_shot", "target": "power_shot",
	"boss": "air_strike", "skull": "air_strike",
}
const FALLBACK_ICON := "battle"

## Choosing a mode (switch_action()):
const NOTHING := "none" # the mode already shown
const LOCKED := "locked" # the party's member: the host chooses
const SWITCH := "switch" # not in a lobby: just switch
const SET_QUEUE := "set_queue" # in my lobby, to another party mode: SetLobbyQueue {queue}, then switch
const LEAVE := "leave" # alone in my lobby, to a solo mode: LeaveLobby, then switch
const CONFIRM_LEAVE := "confirm_leave" # with a teammate, to a solo mode: "Rời đội?" first
const TOO_LARGE := "too_large" # in my lobby, to a party mode smaller than the party: refused (TOO_LARGE_TEXT)

const LOCKED_TEXT := "Chủ phòng chọn chế độ"
const TOO_LARGE_TEXT := "Đội đông hơn số người của chế độ này" # = the server's PARTY_TOO_LARGE


## The icon (assets/icons name) of an icon key.
static func icon_of(key: String) -> String:
	return str(ICONS.get(key, FALLBACK_ICON))


## The sections in order: [{categoryId, name, layout, modes: [card()]}]. The game data's categories
## first (an empty one too: it shows the placeholder), then any category a mode names that the list
## lacks (its id as its name), in the order its first mode comes.
static func sections(current: int) -> Array:
	var out: Array = []
	var by_id := {}
	for c in GameData.mode_categories():
		var id := str(c["categoryId"])
		if by_id.has(id):
			continue
		by_id[id] = out.size()
		out.append(_section(id, str(c.get("name", id)) if c.get("name") is String else id))
	var all := LobbyModel.modes()
	for i in all.size():
		var cat: String = all[i]["category"]
		if not by_id.has(cat):
			by_id[cat] = out.size()
			out.append(_section(cat, cat))
		out[by_id[cat]]["modes"].append(card(i, current))
	return out


static func _section(id: String, title: String) -> Dictionary:
	return {"categoryId": id, "name": title, "layout": GRID if GRID_CATEGORIES.has(id) else CARDS, "modes": []}


## The mode at `index`'s place among its category's modes (0 for the first): the icon plate's
## colour on Mode Select and the lobby's mode card.
static func order_in_section(index: int) -> int:
	var all := LobbyModel.modes()
	if index < 0 or index >= all.size():
		return 0
	var n := 0
	for i in index:
		if all[i]["category"] == all[index]["category"]:
			n += 1
	return n


## The section index of the mode at `index` (the tab Mode Select opens on); 0 when none.
static func section_of(index: int) -> int:
	var all := sections(index)
	for s in all.size():
		for c in all[s]["modes"]:
			if c["index"] == index:
				return s
	return 0


## A mode's card: {index, id, name, description, icon, party_size, badge ("2 người"; "" solo: the
## info popup's party line), ranked, selected}.
static func card(index: int, current: int) -> Dictionary:
	var m: Dictionary = LobbyModel.mode(index)
	var size: int = m["party_size"]
	return {"index": index, "id": m["id"], "name": m["name"], "description": m["description"], "icon": icon_of(m["icon"]),
		"party_size": size, "badge": "%d người" % size if size >= 2 else "", "ranked": m["ranked"], "selected": index == current}


## A category without modes: {title, text} of its disabled card.
static func placeholder(category_id: String) -> Dictionary:
	return {"title": SOON, "text": str(SOON_TEXT.get(category_id, SOON_DEFAULT))}


## What choosing the mode `to` (from `from`) does, given the party: NOTHING, LOCKED, SWITCH,
## SET_QUEUE, LEAVE, CONFIRM_LEAVE or TOO_LARGE. In my lobby, a party mode (a queue for two or more)
## keeps it (SetLobbyQueue) unless the party (`members`, me too) is bigger than that mode holds
## (TOO_LARGE: a boss party of 3 to a 2v2); a solo mode leaves it, asking "Rời đội?" first with a
## teammate.
static func switch_action(from: int, to: int, in_lobby: bool, is_member: bool, in_party: bool, members: int = 1) -> String:
	if to < 0 or to >= LobbyModel.modes().size() or to == from:
		return NOTHING
	if is_member:
		return LOCKED
	if not in_lobby:
		return SWITCH
	if LobbyModel.is_party(to) and LobbyModel.is_queue(LobbyModel.mode_base(to)):
		return TOO_LARGE if members > int(LobbyModel.mode(to)["party_size"]) else SET_QUEUE
	return CONFIRM_LEAVE if in_party else LEAVE
