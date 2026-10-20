extends RefCounted
## Titles ("Danh hiệu") without UI: GET /player/titles parsed, a title as the plates draw it
## ({id, name, rarity}) from the profile's equippedTitle, a match player's title or a milestone
## reward, and the texts of the Hồ sơ picker. Malformed parts fall back to no title, never an
## error.

const RARITIES := ["blue", "orange", "purple", "red"]


## {id, name, rarity} from a server title object; {} when there is none or it has no name. A
## missing or unknown rarity draws as blue.
static func parse_title(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var id := str(v.get("id", "")) if v.get("id") != null else ""
	var title_name := str(v.get("name", "")) if v.get("name") != null else ""
	if title_name.strip_edges() == "":
		return {}
	var rarity := str(v.get("rarity", ""))
	return {"id": id, "name": title_name, "rarity": rarity if RARITIES.has(rarity) else RARITIES[0]}


## The title a match player wears (its "title" field; none for bots and old servers).
static func from_player(p: Variant) -> Dictionary:
	return parse_title(p.get("title")) if p is Dictionary else {}


## The title the profile says is worn (GET /player/profile equippedTitle).
static func from_profile(profile: Variant) -> Dictionary:
	return parse_title(profile.get("equippedTitle")) if profile is Dictionary else {}


## GET /player/titles data → {"titles": [{id, name, rarity, description, owned, obtainedAt}],
## "equipped": title or {}}; null when malformed. Titles keep the server's order.
static func parse(data: Variant) -> Variant:
	if not data is Dictionary or not data.get("titles") is Array:
		return null
	var out: Array = []
	for t in data["titles"]:
		var base := parse_title(t)
		if base.is_empty() or base["id"] == "":
			continue
		base["description"] = str(t.get("description", "")) if t.get("description") != null else ""
		base["owned"] = t.get("owned") is bool and t["owned"]
		base["obtainedAt"] = str(t.get("obtainedAt", "")) if t.get("obtainedAt") != null else ""
		out.append(base)
	return {"titles": out, "equipped": parse_title(data.get("equipped"))}


static func owned(parsed: Variant) -> Array:
	if not parsed is Dictionary:
		return []
	return parsed["titles"].filter(func(t): return t["owned"])


static func locked(parsed: Variant) -> Array:
	if not parsed is Dictionary:
		return []
	return parsed["titles"].filter(func(t): return not t["owned"])


## The id of the worn title, "" when none.
static func equipped_id(parsed: Variant) -> String:
	if not parsed is Dictionary:
		return ""
	return str(parsed["equipped"].get("id", ""))


## How a locked title is won: "Đạt: Thắng 100 trận" ("Chưa mở" without a description).
static func locked_text(t: Dictionary) -> String:
	var d := str(t.get("description", "")).strip_edges()
	return "Đạt: %s" % d if d != "" else "Chưa mở"


## The title of an id in the parsed list, {} when not listed.
static func find(parsed: Variant, id: String) -> Dictionary:
	if not parsed is Dictionary:
		return {}
	for t in parsed["titles"]:
		if t["id"] == id:
			return t
	return {}
