extends RefCounted
## The server's maps (GET /maps: every active map {mapId, name, theme, width, height, cellSize,
## gridWidth, gridHeight, minRankTier, windRange, version}): the maps are made in the server's DB,
## the client only syncs them. PlayerState.load_maps() fetches the list when Home shows; the last
## list is kept in CACHE_PATH (user://) with its version, so the names and themes are there at
## once on the next start, and an answer with the same version changes nothing.
## Used for map names (history rows, matchmaking "Bản đồ: …", the match start toast) and the
## theme of a map whose MatchStarted carries no mapTheme (MatchStarted's mapTheme / mapName win).
## An unknown map is shown under its raw id, with no theme ("": map_themes.gd draws grassland).

const CACHE_PATH := "user://maps.json"

static var maps := {} # mapId -> {mapId, name, theme, ...the rest of the server's entry}
static var version := "" # the list's version ("" none)
static var cache_path := CACHE_PATH # "" = no cache (tests)
static var _cache_read := false


## {maps: {mapId -> entry}, version} of a GET /maps data: an array of maps, or {version, maps}.
## Entries without a mapId are skipped. With no list version, the version is made of the maps'
## own (mapId:version sorted), so any map's change shows. null when the data is not a list.
static func parse(data: Variant) -> Variant:
	var list: Variant = data
	var ver := ""
	if data is Dictionary:
		list = data.get("maps")
		var v = data.get("version")
		ver = "" if v == null else str(v)
	if not list is Array:
		return null
	var out := {}
	var parts: Array = []
	for e in list:
		if not e is Dictionary:
			continue
		var id := str(e.get("mapId", "")).strip_edges()
		if id == "" or e.get("mapId") == null:
			continue
		var entry: Dictionary = e.duplicate(true)
		entry["mapId"] = id
		entry["name"] = str(e.get("name", "")) if e.get("name") != null else ""
		entry["theme"] = str(e.get("theme", "")) if e.get("theme") != null else ""
		out[id] = entry
		parts.append("%s:%s" % [id, str(e.get("version", ""))])
	if ver == "":
		parts.sort()
		ver = ",".join(parts)
	return {"maps": out, "version": ver}


## Takes a parsed list (parse()). Returns true when it changed the catalog (another version).
static func take(parsed: Dictionary, save: bool = true) -> bool:
	_ensure_cache()
	var ver := str(parsed.get("version", ""))
	if ver == version and (ver != "" or parsed.get("maps", {}) == maps):
		return false
	maps = parsed.get("maps", {})
	version = ver
	if save:
		save_cache()
	return true


static func entry(map_id: String) -> Dictionary:
	_ensure_cache()
	return maps.get(map_id, {})


## The map's name, its raw id when the catalog has none ("" for no id).
static func name_of(map_id: String) -> String:
	var n := str(entry(map_id).get("name", "")).strip_edges()
	return n if n != "" else map_id


## The map's theme id, "" when the catalog does not know the map.
static func theme_of(map_id: String) -> String:
	return str(entry(map_id).get("theme", ""))


static func to_json() -> String:
	return JSON.stringify({"version": version, "maps": maps.values()})


static func save_cache() -> void:
	if cache_path == "":
		return
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(to_json())


## Reads the cache once (the first lookup), unless something was taken already.
static func _ensure_cache() -> void:
	if _cache_read:
		return
	_cache_read = true
	if cache_path == "" or not FileAccess.file_exists(cache_path):
		return
	var parsed = parse(JSON.parse_string(FileAccess.get_file_as_string(cache_path)))
	if parsed is Dictionary:
		maps = parsed["maps"]
		version = parsed["version"]


## Empties the catalog; `path` is the cache to use from now on ("" none: tests).
static func reset(path: String = CACHE_PATH) -> void:
	maps = {}
	version = ""
	cache_path = path
	_cache_read = false
