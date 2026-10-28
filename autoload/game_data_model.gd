extends RefCounted
## The server's game data (GET /gamedata, contract: server docs, internal/api/gamedata): every
## gameplay rule, balance number and Vietnamese display text the client uses (physics, aim, aim
## aid, terrain, movement, timings, skills, characters, weapons, items, status effects, rank tiers,
## levels, equipment rules / slots / item type words, economy, matchmaking, modes, map themes, gun
## kinds, bosses). The client hardcodes none of them: this is the only source, and the only fallback is
## the last copy cached in CACHE_PATH.
## The client keeps only presentation (colours, layout, art per id, animation feel).
##
## Pure and static, like match/theme/map_catalog.gd: PlayerState.load_gamedata() does the network
## part (a conditional GET with If-None-Match: if_none_match(); apply_response() takes the answer:
## 200 replaces the data and the cache, 304 keeps both). Splash loads it before anything needs it;
## with no cache and no network it shows a retry screen. The app refetches when it comes back to
## the foreground if the last check is older than RECHECK_MSEC (check_due()).
##
## Two kinds of copies: the lobby copy (the latest plain GET /gamedata, cached in CACHE_PATH) and
## the match copies (GET /gamedata?version=<v>, cached by version next to it, the newest
## MAX_VERSIONS). A match plays with the game data of its MatchStarted / MatchStateSync
## gamedataVersion from its start to its end, even after an admin save made the plain answer
## newer: use_match(v) pins it (and uses it at once when it is held), needs_refetch() says it must
## be fetched (PlayerState.load_match_gamedata(): a 404 falls back to the plain GET), end_match()
## goes back to the lobby copy. `data` / `version` are the copy in use, which every accessor reads.
##
## Accessors are typed and never crash: a missing section, field or id reads as 0 / "" / false /
## {} / [] (and an unknown id's name as the id itself). Ids are open sets: an admin may add a
## character, skill, item, status effect, tier, mode or theme at any time; callers draw a generic
## look for an id with no art. Tests load tests/fixtures/gamedata.json (tests/run_tests.gd).

const CACHE_PATH := "user://gamedata.json"
## The foreground refetch runs when the last good answer is older than this.
const RECHECK_MSEC := 5 * 60 * 1000
## Match copies (GET /gamedata?version=) kept in memory and in the cache, the newest.
const MAX_VERSIONS := 3

## apply_response() / apply_version_response() outcomes.
const UPDATED := 1 # a new version was taken (and cached)
const SAME := 0 # 304, or a 200 with the version already held
const FAILED := -1 # network / server error or an unusable body: the data held stays
const NOT_FOUND := -2 # ?version= 404 (GAMEDATA_VERSION_NOT_FOUND: never published, or pruned)

static var data := {} # the copy in use ({} none): the match's while a match plays with a held copy, else the lobby's
static var version := "" # data.version ("" none); read it after an accessor (or is_loaded()) ran
static var etag := "" # the lobby copy's ETag, as the server sent it ("" none: one is made from its version)
static var lobby := {} # the latest plain GET /gamedata data ({} none)
static var lobby_version := ""
static var match_version := "" # the gamedataVersion the running match plays with ("" outside a match)
static var cache_path := CACHE_PATH # "" = no cache (tests)
static var checked_msec := -1 # Time.get_ticks_msec() of the last good answer (200 / 304); -1 never
static var _versions := {} # version -> data: the match copies
static var _version_order: Array = [] # their versions, oldest first
static var _cache_read := false
static var _index := {} # section -> {id -> entry}


# ── Loading and cache ───────────────────────────────────────────────────────

## A GET /gamedata body (the envelope {success, data} or the data itself) → the data, or null when
## it is not game data (no version).
static func parse(raw: Variant) -> Variant:
	var d: Variant = raw
	if raw is Dictionary and raw.has("success") and raw.get("data") is Dictionary:
		d = raw["data"]
	if not d is Dictionary:
		return null
	var v = d.get("version")
	if not v is String or str(v).strip_edges() == "":
		return null
	return d


## Takes parsed plain game data (parse()) with its ETag as the lobby copy (in use unless a match
## plays with another held copy). Returns true when the lobby copy changed (another version, or
## the first copy).
static func take(d: Dictionary, new_etag: String = "", save: bool = true) -> bool:
	_ensure_cache()
	var v := str(d.get("version", ""))
	if new_etag != "":
		etag = new_etag
	if v == lobby_version and not lobby.is_empty():
		return false
	lobby = d.duplicate(true)
	lobby_version = v
	etag = new_etag if new_etag != "" else quoted(v)
	_activate()
	if save:
		save_cache()
	return true


## Takes parsed game data of one version (GET /gamedata?version=) as a match copy (in use when it
## is the match's). Returns true when it was not held.
static func take_version(d: Dictionary, save: bool = true) -> bool:
	_ensure_cache()
	var v := str(d.get("version", ""))
	var fresh := not _versions.has(v)
	_keep_version(v, d.duplicate(true))
	_activate()
	if save:
		_save_versions()
	return fresh


## Takes a GET /gamedata answer from Api.get_cached() ({ok, status, data, etag}): 200 with game
## data → take() (UPDATED when it changed), 304 → SAME (the copy held is current), anything else
## → FAILED (the copy held stays). now_msec: when it was answered (checked_msec).
static func apply_response(res: Dictionary, now_msec: int) -> int:
	if not bool(res.get("ok", false)):
		return FAILED
	if int(res.get("status", 0)) == 304:
		if lobby.is_empty():
			return FAILED # a 304 with nothing to keep (the cache was lost): ask again without one
		checked_msec = now_msec
		return SAME
	var d = parse(res.get("data"))
	if not d is Dictionary:
		return FAILED
	checked_msec = now_msec
	return UPDATED if take(d, str(res.get("etag", ""))) else SAME


## Takes a GET /gamedata?version=<v> answer: 200 with the game data of v → take_version()
## (UPDATED, or SAME when held), 404 → NOT_FOUND (fall back to the plain GET), anything else (or
## another version) → FAILED.
static func apply_version_response(res: Dictionary, v: String) -> int:
	if not bool(res.get("ok", false)):
		return NOT_FOUND if int(res.get("status", 0)) == 404 else FAILED
	var d = parse(res.get("data"))
	if not d is Dictionary or str(d["version"]) != v:
		return FAILED
	return UPDATED if take_version(d) else SAME


## True once game data is held (fetched or read from the cache).
static func is_loaded() -> bool:
	_ensure_cache()
	return not data.is_empty()


## The If-None-Match value for the next plain GET /gamedata: the lobby copy's ETag, "" with none.
static func if_none_match() -> String:
	_ensure_cache()
	if lobby.is_empty():
		return ""
	return etag if etag != "" else quoted(lobby_version)


## True when the game data of version v is held (the lobby copy or a match copy).
static func has_version(v: String) -> bool:
	_ensure_cache()
	return v != "" and ((v == lobby_version and not lobby.is_empty()) or _versions.has(v))


## A match plays with the game data of its gamedataVersion (MatchStarted / MatchStateSync; "" or
## absent from an older server: the lobby copy) until end_match(). Uses it at once when it is
## held; returns true when the match's game data is in use (false: needs_refetch()). A match on
## the lobby copy keeps it even when a plain GET brings a newer one meanwhile.
static func use_match(match_v: Variant) -> bool:
	_ensure_cache()
	match_version = str(match_v) if match_v is String else ""
	if match_version != "" and match_version == lobby_version and not _versions.has(match_version) and not lobby.is_empty():
		_keep_version(match_version, lobby) # pinned: a newer lobby copy does not replace it mid-match
	_activate()
	return match_version == "" or version == match_version


## The match is over: the lobby copy is in use again.
static func end_match() -> void:
	match_version = ""
	_activate()


## A MatchStarted / MatchStateSync gamedataVersion asks for a refetch: it is set and is not the
## version in use ("" or absent from an older server: no).
static func needs_refetch(match_v: Variant) -> bool:
	if not match_v is String or str(match_v) == "":
		return false
	_ensure_cache()
	return str(match_v) != version


## The foreground check is due: no good answer yet, or the last one is older than max_age.
static func check_due(now_msec: int, max_age_msec: int = RECHECK_MSEC) -> bool:
	return checked_msec < 0 or now_msec - checked_msec >= max_age_msec


static func quoted(v: String) -> String:
	return "\"%s\"" % v if v != "" else ""


## Saves the lobby copy (CACHE_PATH).
static func save_cache() -> void:
	if cache_path == "" or lobby.is_empty():
		return
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": lobby_version, "etag": etag, "data": lobby}))


## The match copies' cache file: user://gamedata_versions.json next to CACHE_PATH ("" none).
static func versions_path() -> String:
	return "" if cache_path == "" else cache_path.get_basename() + "_versions.json"


static func _save_versions() -> void:
	var path := versions_path()
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"copies": _version_order.map(func(v): return _versions[v])}))


## Holds a match copy as the newest; the oldest past MAX_VERSIONS go (never the match's own).
static func _keep_version(v: String, d: Dictionary) -> void:
	_versions[v] = d
	_version_order.erase(v)
	_version_order.append(v)
	var i := 0
	while _version_order.size() > MAX_VERSIONS and i < _version_order.size():
		var old: String = _version_order[i]
		if old == match_version or old == v:
			i += 1
			continue
		_version_order.remove_at(i)
		_versions.erase(old)


## Puts the copy the moment wants in use: the match's when it is held, else the lobby's.
static func _activate() -> void:
	var v := lobby_version
	var d := lobby
	if match_version != "" and _versions.has(match_version):
		v = match_version
		d = _versions[v]
	if v == version and is_same(d, data):
		return
	data = d
	version = v if not d.is_empty() else ""
	_build_index()


## Reads the caches once (the first lookup), unless something was taken already.
static func _ensure_cache() -> void:
	if _cache_read:
		return
	_cache_read = true
	var raw = _read_json(cache_path)
	if raw is Dictionary:
		var d = parse(raw.get("data"))
		if d is Dictionary:
			lobby = d
			lobby_version = str(d["version"])
			etag = str(raw.get("etag", "")) if raw.get("etag") is String else ""
	var saved = _read_json(versions_path())
	if saved is Dictionary and saved.get("copies") is Array:
		for c in saved["copies"]:
			var d = parse(c)
			if d is Dictionary:
				_keep_version(str(d["version"]), d)
	_activate()


## A JSON file's value, null when it is missing or broken.
static func _read_json(path: String) -> Variant:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null # a broken cache is no game data
	return json.data


## Empties the held data; `path` is the cache to use from now on ("" none: tests).
static func reset(path: String = CACHE_PATH) -> void:
	data = {}
	version = ""
	etag = ""
	lobby = {}
	lobby_version = ""
	match_version = ""
	cache_path = path
	checked_msec = -1
	_versions = {}
	_version_order = []
	_cache_read = false
	_index = {}


static func _build_index() -> void:
	_index = {}
	for spec in [["weapons", "weaponId"], ["skills", "skillId"], ["characters", "characterId"], ["items", "itemId"],
			["statusEffects", "effectId"]]:
		_index[spec[0]] = _by(list(spec[0]), spec[1])
	_index["rankTiers"] = _by(_list_in(section("rank"), "tiers"), "tier")
	_index["equipmentTiers"] = _by(_list_in(section("equipment"), "tiers"), "tier")
	_index["matchModes"] = _by(_list_in(section("modes"), "match"), "modeId")
	_index["lobbyModes"] = _by(_list_in(section("modes"), "lobby"), "modeId")
	_index["equipmentSlots"] = _by(_list_in(section("equipment"), "slots"), "id")
	_index["typeWords"] = _by(_list_in(section("equipment"), "typeWords"), "word")
	_index["gunKinds"] = _by(list("gunKinds"), "id")
	_index["bosses"] = _by(list("bosses"), "bossId")
	_index["elements"] = _by(list("elements"), "elementId")
	_index["grades"] = _by(_list_in(section("grades"), "list"), "grade")
	_index["seasonRewards"] = _by(list("seasonRewards"), "grade")
	_index["chests"] = _by(list("chests"), "chestId")


static func _by(entries: Array, key: String) -> Dictionary:
	var out := {}
	for e in entries:
		var id := str(e.get(key, ""))
		if id != "" and not out.has(id):
			out[id] = e
	return out


# ── Raw lookups (only this file digs into the dictionaries) ────────────────

static func section(sec: String) -> Dictionary:
	_ensure_cache()
	var s = data.get(sec)
	return s if s is Dictionary else {}


## The entries of a top-level array (weapons, skills, characters, items, statusEffects), only the
## dictionaries, in the server's (display) order.
static func list(sec: String) -> Array:
	_ensure_cache()
	return _dicts(data.get(sec))


static func _list_in(d: Dictionary, key: String) -> Array:
	return _dicts(d.get(key))


static func _dicts(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for e in v:
			if e is Dictionary:
				out.append(e)
	return out


static func _entry(index: String, id: String) -> Dictionary:
	_ensure_cache()
	var by: Dictionary = _index.get(index, {})
	return by.get(id, {})


static func _f(d: Dictionary, key: String) -> float:
	var v = d.get(key)
	return float(v) if v is int or v is float else 0.0


static func _i(d: Dictionary, key: String) -> int:
	var v = d.get(key)
	return int(v) if v is int or v is float else 0


static func _s(d: Dictionary, key: String) -> String:
	var v = d.get(key)
	return str(v) if v is String else ""


static func _b(d: Dictionary, key: String) -> bool:
	var v = d.get(key)
	return v if v is bool else false


static func _sub(d: Dictionary, key: String) -> Dictionary:
	var v = d.get(key)
	return v if v is Dictionary else {}


static func _strings(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for s in v:
			if s is String:
				out.append(s)
	return out


# ── physics: the shell flight (server SimulateProjectile) ──────────────────

static func gravity() -> float:
	return _f(section("physics"), "gravity")


static func speed_per_power() -> float:
	return _f(section("physics"), "speedPerPower")


static func wind_scale() -> float:
	return _f(section("physics"), "windScale")


static func time_step() -> float:
	return _f(section("physics"), "timeStep")


static func max_flight_sec() -> float:
	return _f(section("physics"), "maxFlightSec")


static func player_hit_radius() -> float:
	return _f(section("physics"), "playerHitRadius")


static func collision_step_px() -> float:
	return _f(section("physics"), "collisionStepPx")


## The shot origin (and the body centre) above the feet, px.
static func shot_origin_lift() -> float:
	return _f(section("physics"), "shotOriginLift")


## {left, right, below} px: the flight ends at x < −left, x > width + right, y > height + below.
static func out_of_bounds() -> Dictionary:
	var o := _sub(section("physics"), "outOfBounds")
	return {"left": _f(o, "left"), "right": _f(o, "right"), "below": _f(o, "below")}


# ── aim ─────────────────────────────────────────────────────────────────────

static func power_min() -> float:
	return _f(section("aim"), "powerMin")


static func power_max() -> float:
	return _f(section("aim"), "powerMax")


static func angle_min() -> float:
	return _f(section("aim"), "angleMin")


static func angle_max() -> float:
	return _f(section("aim"), "angleMax")


static func no_aim_angle() -> float:
	return _f(section("aim"), "noAimAngle")


static func no_aim_power() -> float:
	return _f(section("aim"), "noAimPower")


# ── aimAid: the aiming guide ────────────────────────────────────────────────

## The guide arc's length (px) for the local player's rank tier; an unknown / "" tier reads as
## aimAid.defaultTier.
static func guide_arc_length(tier: String) -> float:
	var aid := section("aimAid")
	var by := _sub(aid, "guideArcLength")
	var v = by.get(tier)
	if not (v is int or v is float):
		v = by.get(_s(aid, "defaultTier"))
	return float(v) if v is int or v is float else 0.0


## {max, minPart, farPx, highPx} of the "Trúng!" tolerance.
static func hit_tolerance() -> Dictionary:
	var t := _sub(section("aimAid"), "hitTolerance")
	return {"max": _f(t, "max"), "minPart": _f(t, "minPart"), "farPx": _f(t, "farPx"), "highPx": _f(t, "highPx")}


# ── combat ──────────────────────────────────────────────────────────────────

static func power_shot_factor() -> float:
	return _f(section("combat"), "powerShotFactor")


# ── terrain ─────────────────────────────────────────────────────────────────

static func player_height() -> int:
	return _i(section("terrain"), "playerHeight")


static func max_climb_per_step() -> int:
	return _i(section("terrain"), "maxClimbPerStep")


static func crater_px_per_terrain_damage() -> float:
	return _f(section("terrain"), "craterPxPerTerrainDamage")


static func bowl_depth() -> float:
	return _f(section("terrain"), "bowlDepth")


static func bowl_ceiling() -> float:
	return _f(section("terrain"), "bowlCeiling")


# ── movement ────────────────────────────────────────────────────────────────

static func px_per_energy() -> float:
	return _f(section("movement"), "pxPerEnergy")


static func energy_per_px() -> float:
	return _f(section("movement"), "energyPerPx")


static func default_move_energy() -> int:
	return _i(section("movement"), "defaultMoveEnergy")


# ── timings ─────────────────────────────────────────────────────────────────

static func turn_sec() -> int:
	return _i(section("timings"), "turnSec")


static func action_interval_sec() -> float:
	return _f(section("timings"), "actionIntervalSec")


static func bot_follow_up_delay_sec() -> float:
	return _f(section("timings"), "botFollowUpDelaySec")


static func skip_turn_delay_sec() -> float:
	return _f(section("timings"), "skipTurnDelaySec")


# ── skill energy and ranks ──────────────────────────────────────────────────

static func skill_energy_max() -> int:
	return _i(section("skillEnergy"), "max")


static func skill_energy_per_turn() -> int:
	return _i(section("skillEnergy"), "perTurn")


static func skill_energy_on_hit() -> int:
	return _i(section("skillEnergy"), "onHit")


static func skill_rank_max() -> int:
	return _i(section("skillRanks"), "max")


static func skill_rank_default() -> int:
	return _i(section("skillRanks"), "default")


## A skill rank clamped to 0..skillRanks.max.
static func clamp_skill_rank(rank: int) -> int:
	return clampi(rank, 0, maxi(skill_rank_max(), 0))


## The skill rank a tier word gives (skillRanks.byTierWord: "lv20", "gold", ...); the default for
## a word not in the map.
static func skill_rank_of_word(word: String) -> int:
	var by := _sub(section("skillRanks"), "byTierWord")
	var v = by.get(word)
	return clamp_skill_rank(int(v) if v is int or v is float else skill_rank_default())


## The skill rank of an equipped weapon item id: the word after its last "_" (rookie_weapon_lv20 →
## lv20); the default for none.
static func skill_rank_of_weapon(item_id: String) -> int:
	if item_id == "":
		return clamp_skill_rank(skill_rank_default())
	var parts := item_id.split("_")
	return skill_rank_of_word(parts[parts.size() - 1])


# ── weapons ─────────────────────────────────────────────────────────────────

static func weapon(weapon_id: String) -> Dictionary:
	return _entry("weapons", weapon_id)


## The starter weapon of a character ({} unknown).
static func weapon_of_character(character_id: String) -> Dictionary:
	return weapon(character_weapon_id(character_id))


static func weapon_explosion_radius(weapon_id: String) -> float:
	return _f(weapon(weapon_id), "explosionRadius")


static func weapon_crater_radius(weapon_id: String) -> float:
	return _f(weapon(weapon_id), "craterRadius")


## The wind response of a weapon: windInfluence / projectileWeight ({influence, weight}; 0 for an
## unknown weapon).
static func weapon_wind_influence(weapon_id: String) -> float:
	return _f(weapon(weapon_id), "windInfluence")


static func weapon_projectile_weight(weapon_id: String) -> float:
	return _f(weapon(weapon_id), "projectileWeight")


# ── skills ──────────────────────────────────────────────────────────────────

static func skills() -> Array:
	return list("skills")


static func skill(skill_id: String) -> Dictionary:
	return _entry("skills", skill_id)


static func has_skill(skill_id: String) -> bool:
	return not skill(skill_id).is_empty()


## The skill's Vietnamese button name ("" for a skill the game data does not know: the caller
## shows its generic label).
static func skill_name(skill_id: String) -> String:
	return _s(skill(skill_id), "name")


static func skill_effect_type(skill_id: String) -> String:
	return _s(skill(skill_id), "effectType")


## "arc" / "line" / "none"; "arc" for an unknown skill or kind.
static func skill_aim_kind(skill_id: String) -> String:
	var k := _s(skill(skill_id), "aimKind")
	return k if k in ["arc", "line", "none"] else "arc"


static func skill_status_effect(skill_id: String) -> String:
	return _s(skill(skill_id), "statusEffectId")


## A tuning number of the skill's effect type (params), 0 when absent.
static func skill_param(skill_id: String, key: String) -> float:
	return _f(_sub(skill(skill_id), "params"), key)


## The first param `key` of a skill with this effect type (laser halfWidth for the aim aid), 0
## when no skill has it.
static func effect_param(effect_type: String, key: String) -> float:
	for s in skills():
		if _s(s, "effectType") == effect_type:
			var p := _sub(s, "params")
			if p.has(key):
				return _f(p, key)
	return 0.0


## The values of the skill at rank r (ranks[] entry with that rank, else the nearest below) as
## {name: number}; {} when the skill has no ranks.
static func skill_values(skill_id: String, rank: int) -> Dictionary:
	var best := {}
	var best_rank := -1
	for e in _list_in(skill(skill_id), "ranks"):
		var r := _i(e, "rank")
		if r <= rank and r > best_rank:
			best_rank = r
			best = _sub(e, "values")
	return best


## The skill's description at rank r: its template with every {key} filled from the rank's values
## (fill_template()); "" for an unknown skill.
static func skill_describe(skill_id: String, rank: int) -> String:
	return fill_template(_s(skill(skill_id), "description"), skill_values(skill_id, clamp_skill_rank(rank)))


## Replaces every {key} of a template with values[key] (whole numbers without a decimal, others
## in their shortest form); a {key} with no number stays as it is.
static func fill_template(template: String, values: Dictionary) -> String:
	var out := ""
	var i := 0
	while i < template.length():
		var open := template.find("{", i)
		if open < 0:
			out += template.substr(i)
			break
		var close := template.find("}", open + 1)
		if close < 0:
			out += template.substr(i)
			break
		out += template.substr(i, open - i)
		var key := template.substr(open + 1, close - open - 1)
		var v = values.get(key)
		if v is int or v is float:
			out += number_text(float(v))
		else:
			out += template.substr(open, close - open + 1)
		i = close + 1
	return out


## 12 → "12", 12.5 → "12.5", 0.15 → "0.15".
static func number_text(v: float) -> String:
	if is_equal_approx(v, roundf(v)) and absf(v) < 1e15:
		return str(int(roundf(v)))
	return String.num(v)


# ── characters ──────────────────────────────────────────────────────────────

static func characters() -> Array:
	return list("characters")


static func character_ids() -> Array:
	return characters().map(func(c): return str(c.get("characterId", ""))).filter(func(id): return id != "")


static func character(character_id: String) -> Dictionary:
	return _entry("characters", character_id)


static func is_character(character_id: String) -> bool:
	return not character(character_id).is_empty()


static func default_character_id() -> String:
	_ensure_cache()
	var v = data.get("defaultCharacterId")
	return str(v) if v is String else ""


## The display name; the id itself when unknown.
static func character_name(character_id: String) -> String:
	var n := _s(character(character_id), "name")
	return n if n != "" else character_id


static func character_role(character_id: String) -> String:
	return _s(character(character_id), "role")


## The Vietnamese role label ("Phá địa hình"), "" when unknown.
static func character_role_name(character_id: String) -> String:
	return _s(character(character_id), "roleName")


static func character_playstyle(character_id: String) -> String:
	return _s(character(character_id), "playstyle")


static func character_weapon_id(character_id: String) -> String:
	return _s(character(character_id), "weaponId")


static func character_skill_id(character_id: String) -> String:
	return _s(character(character_id), "skillId")


## The gun art kind ("" lets the client draw its generic gun).
static func character_gun_kind(character_id: String) -> String:
	return _s(character(character_id), "gunKind")


## The character whose gun kind is `gun_kind` ("" none).
static func character_of_gun_kind(gun_kind: String) -> String:
	for c in characters():
		if _s(c, "gunKind") == gun_kind and gun_kind != "":
			return _s(c, "characterId")
	return ""


# ── items ───────────────────────────────────────────────────────────────────

static func items() -> Array:
	return list("items")


static func item_ids() -> Array:
	return items().map(func(it): return str(it.get("itemId", ""))).filter(func(id): return id != "")


static func item(item_id: String) -> Dictionary:
	return _entry("items", item_id)


static func is_item(item_id: String) -> bool:
	return not item(item_id).is_empty()


## The Vietnamese name; the id itself when unknown.
static func item_name(item_id: String) -> String:
	var n := _s(item(item_id), "name")
	return n if n != "" else item_id


static func item_type(item_id: String) -> String:
	return _s(item(item_id), "type")


static func item_value(item_id: String) -> float:
	return _f(item(item_id), "value")


## An item's Vietnamese description ("" none; an older server sends none).
static func item_description(item_id: String) -> String:
	return _s(item(item_id), "description")


## A number of an item's params (poison_bomb turns, triple_shot spreadDeg, nuke_bomb blastFactor;
## `fallback` when absent).
static func item_param(item_id: String, key: String, fallback: float = 0.0) -> float:
	var v = _sub(item(item_id), "params").get(key)
	return float(v) if v is int or v is float else fallback


## True: UseItem acts at once (the turn goes on); false: it arms the next shot.
static func item_instant(item_id: String) -> bool:
	return _b(item(item_id), "instant")


## "none" / "arc" / "targetX" ("none" for an unknown item).
static func item_aim_kind(item_id: String) -> String:
	var k := _s(item(item_id), "aimKind")
	return k if k != "" else "none"


static func max_loadout() -> int:
	return _i(section("itemRules"), "maxLoadout")


static func air_strike_angle() -> float:
	return _f(_sub(section("itemRules"), "airStrike"), "angle")


static func air_strike_power() -> float:
	return _f(_sub(section("itemRules"), "airStrike"), "power")


## The freeze bomb's shot damage × this of a normal shot (itemRules.freezeBombDamageFactor, 063);
## 1 from a server that does not send it (full damage, as before).
static func freeze_bomb_damage_factor() -> float:
	var v = section("itemRules").get("freezeBombDamageFactor")
	return float(v) if v is int or v is float else 1.0


# ── status effects ──────────────────────────────────────────────────────────

static func status_effects() -> Array:
	return list("statusEffects")


static func status_ids() -> Array:
	return status_effects().map(func(e): return str(e.get("effectId", ""))).filter(func(id): return id != "")


static func status(effect_id: String) -> Dictionary:
	return _entry("statusEffects", effect_id)


static func is_status(effect_id: String) -> bool:
	return not status(effect_id).is_empty()


## The Vietnamese label when it lands ("" for an effect with no row).
static func status_name(effect_id: String) -> String:
	return _s(status(effect_id), "name")


static func status_marker(effect_id: String) -> String:
	return _s(status(effect_id), "marker")


static func status_banner(effect_id: String) -> String:
	return _s(status(effect_id), "banner")


static func status_bad(effect_id: String) -> bool:
	return _b(status(effect_id), "bad")


static func status_skips_turn(effect_id: String) -> bool:
	return _b(status(effect_id), "skipsTurn")


static func status_blocks_move(effect_id: String) -> bool:
	return _b(status(effect_id), "blocksMove")


# ── rank ────────────────────────────────────────────────────────────────────

## [{tier, name, minRating, divisions, divisionSize}], lowest first.
static func rank_tiers() -> Array:
	return _list_in(section("rank"), "tiers")


static func tier_ids() -> Array:
	return rank_tiers().map(func(t): return str(t.get("tier", ""))).filter(func(id): return id != "")


static func rank_tier(tier: String) -> Dictionary:
	return _entry("rankTiers", tier)


## "Bạc"; "" for an unknown tier.
static func tier_name(tier: String) -> String:
	return _s(rank_tier(tier), "name")


## The tier's number of divisions (1: no division shown), 0 for an unknown tier.
static func tier_divisions(tier: String) -> int:
	return _i(rank_tier(tier), "divisions")


static func default_rating() -> int:
	return _i(section("rank"), "defaultRating")


## The ranked mode / queue id ("ranked_2v2").
static func ranked_mode() -> String:
	return _s(section("rank"), "rankedMode")


## [tier, division] of a rating: the last tier whose minRating ≤ rating (the first below every
## one), division clamp(divisions − floor((rating − minRating) / divisionSize), 1, divisions), 1
## when divisionSize is 0. ["", 0] with no tiers.
static func tier_of_rating(rating: int) -> Array:
	var tiers := rank_tiers()
	if tiers.is_empty():
		return ["", 0]
	var t: Dictionary = tiers[0]
	for e in tiers:
		if _i(e, "minRating") <= rating:
			t = e
	var divisions := maxi(_i(t, "divisions"), 1)
	var size := _i(t, "divisionSize")
	var division := 1
	if size > 0:
		division = clampi(divisions - floori(float(rating - _i(t, "minRating")) / size), 1, divisions)
	return [_s(t, "tier"), division]


# ── grades (cấp bậc, the visible rank from rank points), season and match rewards, chests ──

## grades: {divisionPoints, ladderTop, list: [{grade, name, divisions, minPoints, winPoints,
## lossPoints, general}], generals: [{grade, fromPos, toPos}]}.
static func grades() -> Dictionary:
	return section("grades")


## The grades, lowest first (the generals last).
static func grade_list() -> Array:
	return _list_in(grades(), "list")


static func grade_ids() -> Array:
	return grade_list().map(func(g): return _s(g, "grade")).filter(func(id): return id != "")


static func grade(grade_id: String) -> Dictionary:
	return _entry("grades", grade_id)


## "Binh nhì"; "" for an unknown grade.
static func grade_name(grade_id: String) -> String:
	return _s(grade(grade_id), "name")


## The grade's number of divisions (1: none shown), 0 for an unknown grade.
static func grade_divisions(grade_id: String) -> int:
	return _i(grade(grade_id), "divisions")


static func grade_min_points(grade_id: String) -> int:
	return _i(grade(grade_id), "minPoints")


## A general grade (set at season end for the top of the leaderboard, never reached by playing).
static func grade_general(grade_id: String) -> bool:
	return _b(grade(grade_id), "general")


## The points of one division (100).
static func division_points() -> int:
	return _i(grades(), "divisionPoints")


## The highest grade reached by playing ("dai_ta").
static func ladder_top() -> String:
	return _s(grades(), "ladderTop")


## [{grade, fromPos, toPos}]: the general grades by season leaderboard position.
static func grade_generals() -> Array:
	return _list_in(grades(), "generals")


## seasonRewards: [{grade, coin, gem, items: [{kind, id, qty}]}] in grade order.
static func season_rewards() -> Array:
	return list("seasonRewards")


## The season reward of a final grade, {} none.
static func season_reward(grade_id: String) -> Dictionary:
	return _entry("seasonRewards", grade_id)


## rankedRewards: {winCoin, lossCoin, winStoneRolls, lossStoneRolls, stoneWeights: [{level, weight}]}.
static func ranked_rewards() -> Dictionary:
	return section("rankedRewards")


## chests: [{chestId, name, kind, stones: [{level, weight}], upgradeLevel}].
static func chests() -> Array:
	return list("chests")


static func chest(chest_id: String) -> Dictionary:
	return _entry("chests", chest_id)


## "Rương đá"; the id itself for an unknown chest.
static func chest_name(chest_id: String) -> String:
	var n := _s(chest(chest_id), "name")
	return n if n != "" else chest_id


## "stone" / "equipment"; "" for an unknown chest.
static func chest_kind(chest_id: String) -> String:
	return _s(chest(chest_id), "kind")


## A stone chest's rolls [{level, weight}] (only positive weights), in the server's order.
static func chest_stones(chest_id: String) -> Array:
	return _list_in(chest(chest_id), "stones").filter(func(s): return _i(s, "level") > 0 and _f(s, "weight") > 0.0)


## An equipment chest's upgrade level (+14), 0 none.
static func chest_upgrade_level(chest_id: String) -> int:
	return _i(chest(chest_id), "upgradeLevel")


# ── levels ──────────────────────────────────────────────────────────────────

## [{level, expRequired}] in level order (the total EXP to reach each level).
static func character_levels() -> Array:
	return _list_in(_sub(section("levels"), "character"), "levels")


static func character_max_level() -> int:
	return _i(_sub(section("levels"), "character"), "maxLevel")


## The total EXP to reach a character level (0 at level 1 or below, the last entry's past it).
static func character_exp_required(level: int) -> int:
	var out := 0
	for e in character_levels():
		if _i(e, "level") <= level:
			out = _i(e, "expRequired")
	return out


static func player_exp_per_level() -> int:
	return _i(_sub(section("levels"), "player"), "expPerLevel")


# ── equipment ───────────────────────────────────────────────────────────────

static func upgrade_step_per_level() -> float:
	return _f(section("equipment"), "upgradeStepPerLevel")


static func max_upgrade_level() -> int:
	return _i(section("equipment"), "maxUpgradeLevel")


## [[level, bonus], ...] ascending.
static func upgrade_milestones() -> Array:
	var out: Array = []
	for m in _list_in(section("equipment"), "milestones"):
		out.append([_i(m, "level"), _f(m, "bonus")])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


static func max_stone_level() -> int:
	return _i(section("equipment"), "maxStoneLevel")


static func merge_min_count() -> int:
	return _i(section("equipment"), "mergeMinCount")


static func merge_max_count() -> int:
	return _i(section("equipment"), "mergeMaxCount")


static func merge_rate_per_item() -> float:
	return _f(section("equipment"), "mergeRatePerItem")


static func sell_rate() -> float:
	return _f(section("equipment"), "sellRate")


static func weapon_upgrade_cost_multiplier() -> float:
	return _f(section("equipment"), "weaponUpgradeCostMultiplier")


## [{tier, name, kind, idSuffix, skillRank}] in order.
static func equipment_tiers() -> Array:
	return _list_in(section("equipment"), "tiers")


static func equipment_tier(tier: String) -> Dictionary:
	return _entry("equipmentTiers", tier)


## The tier ids of one kind ("normal" / "crafted"), in order.
static func equipment_tier_ids(kind: String) -> Array:
	return equipment_tiers().filter(func(t): return _s(t, "kind") == kind).map(func(t): return _s(t, "tier"))


## "Sắt"; "" for an unknown tier.
static func equipment_tier_name(tier: String) -> String:
	return _s(equipment_tier(tier), "name")


## The normal tier whose ids end in `suffix` ("lv20" → "steel"), "" none.
static func equipment_tier_of_suffix(suffix: String) -> String:
	for t in equipment_tiers():
		if _s(t, "idSuffix") == suffix and suffix != "":
			return _s(t, "tier")
	return ""


## {suffix: tier} of the normal tiers.
static func equipment_suffixes() -> Dictionary:
	var out := {}
	for t in equipment_tiers():
		if _s(t, "idSuffix") != "":
			out[_s(t, "idSuffix")] = _s(t, "tier")
	return out


## [{id, name}], the equipment slots in display order.
static func equipment_slots() -> Array:
	return _list_in(section("equipment"), "slots")


## The slot ids in display order (the Nhân vật page's slots, filters, sorting).
static func equipment_slot_ids() -> Array:
	return equipment_slots().map(func(e): return _s(e, "id")).filter(func(id): return id != "")


## "Găng tay"; the id itself for an unknown slot.
static func equipment_slot_name(slot: String) -> String:
	var n := _s(_entry("equipmentSlots", slot), "name")
	return n if n != "" else slot


## The Vietnamese word of a catalog item name's type part (lower case, "shock rifle" → "Súng
## điện"); "" for an unknown type.
static func type_word_name(word: String) -> String:
	return _s(_entry("typeWords", word), "name")


## The gun kind of a weapon type word ("shock rifle" → "shock_rifle"); "" for armour or unknown.
static func type_word_gun_kind(word: String) -> String:
	return _s(_entry("typeWords", word), "gunKind")


# ── economy, matchmaking, modes, themes, gun kinds ──────────────────────────

static func coins_per_gem() -> int:
	return _i(section("economy"), "coinsPerGem")


static func match_slots() -> int:
	return _i(section("matchmaking"), "slots")


static func team_size() -> int:
	return _i(section("matchmaking"), "teamSize")


static func match_start_delay_sec() -> float:
	return _f(section("matchmaking"), "matchStartDelaySec")


## How long a party invite waits for its answer (matchmaking.inviteTimeoutSec); 0 unknown.
static func invite_timeout_sec() -> int:
	return _i(section("matchmaking"), "inviteTimeoutSec")


static func tips() -> Array:
	return _strings(section("matchmaking").get("tips"))


## [{modeId, name, description, queue, bot, category, icon, partySize, ranked}], the Home mode
## choices in order (the server leaves disabled modes out; one marked enabled: false is dropped
## here too).
static func lobby_modes() -> Array:
	return _list_in(section("modes"), "lobby").filter(func(m): return m.get("enabled") != false)


## [{categoryId, name}], the Mode Select tabs in order (modes.categories); [] from a server without
## them.
static func mode_categories() -> Array:
	return _list_in(section("modes"), "categories").filter(func(c): return _s(c, "categoryId") != "")


## The lobby mode that joins `queue` ({} none, also for "").
static func lobby_mode_of_queue(queue: String) -> Dictionary:
	if queue == "":
		return {}
	for m in lobby_modes():
		if _s(m, "queue") == queue:
			return m
	return {}


## A queue (or a match of it: MatchStarted mode = the queue) that changes rating: its lobby mode's
## ranked flag; without that flag (an older server) the queue is rank.rankedMode.
static func is_ranked_queue(queue: String) -> bool:
	if queue == "":
		return false
	var m := lobby_mode_of_queue(queue)
	if m.get("ranked") is bool:
		return m["ranked"]
	return queue == ranked_mode()


## A queue some lobby mode joins (or rank.rankedMode): a match of it came from Matchmaking.
static func is_lobby_queue(queue: String) -> bool:
	return queue != "" and (not lobby_mode_of_queue(queue).is_empty() or queue == ranked_mode())


## A match mode's Vietnamese name (MatchStarted mode, match history); the id itself when unknown.
static func match_mode_name(mode_id: String) -> String:
	var n := _s(_entry("matchModes", mode_id), "name")
	return n if n != "" else mode_id


static func default_theme() -> String:
	return _s(section("mapThemes"), "default")


static func themes() -> Array:
	return _strings(section("mapThemes").get("themes"))


## [{id, name}], every gun art kind in display order.
static func gun_kinds() -> Array:
	return list("gunKinds")


## A gun kind's Vietnamese name ("cannon" → "Đại pháo"); "" for an unknown kind.
static func gun_kind_name(kind: String) -> String:
	return _s(_entry("gunKinds", kind), "name")


# ── bosses ──────────────────────────────────────────────────────────────────

## The queue prefix of a boss mode (boss:<bossId>).
const BOSS_QUEUE_PREFIX := "boss:"


## [{bossId, name, description, recommendedLevel, modeId, queue, mapId, hp, bodySize, turnLimit,
## shieldedDamageFactor, flying, hover {minX, maxX, minY, maxY}, minions: [{minionId, name, hp,
## bodySize, behavior, movement, explodeOnDeath, explodeRadius, explodeDamagePct, explodeDamageOf,
## detonateRange, shotDamageFactor, flyRange, walkRange}], skills: [{skillId, name, description, kind}],
## dailyBonusRuns}], the enabled bosses in display order; [] from a server
## without them.
static func bosses() -> Array:
	return list("bosses")


## A boss by id ({} unknown).
static func boss(boss_id: String) -> Dictionary:
	return _entry("bosses", boss_id)


## The boss a queue (or a boss match's mode: the same id) fights: the bosses entry with that queue,
## else the id after "boss:"; {} for any other queue.
static func boss_of_queue(queue: String) -> Dictionary:
	if queue == "":
		return {}
	for b in bosses():
		if _s(b, "queue") == queue:
			return b
	return boss(queue.trim_prefix(BOSS_QUEUE_PREFIX)) if queue.begins_with(BOSS_QUEUE_PREFIX) else {}


## A boss queue or match mode (boss:<bossId>).
static func is_boss_queue(queue: String) -> bool:
	return queue.begins_with(BOSS_QUEUE_PREFIX) or not boss_of_queue(queue).is_empty()


## The boss a lobby mode (modes.lobby modeId) fights ({} none).
static func boss_of_mode(mode_id: String) -> Dictionary:
	if mode_id == "":
		return {}
	for b in bosses():
		if _s(b, "modeId") == mode_id:
			return b
	var m := _entry("lobbyModes", mode_id)
	return boss_of_queue(_s(m, "queue")) if not m.is_empty() else {}


## The boss's name; the id itself when unknown.
static func boss_name(boss_id: String) -> String:
	var n := _s(boss(boss_id), "name")
	return n if n != "" else boss_id


## A minion type ({minionId, name, hp, bodySize}) of the boss boss_id, or of any boss when boss_id
## is "" or does not have it; {} unknown.
static func boss_minion(boss_id: String, minion_id: String) -> Dictionary:
	for b in ([boss(boss_id)] if boss_id != "" else []) + bosses():
		for m in _list_in(b, "minions"):
			if _s(m, "minionId") == minion_id:
				return m
	return {}


## A leaper of this minion type blows up at the end of its turn after a leap
## (minions[].leapDetonateNextTurn; the snowman no longer does since 063: it leaps once, then
## shoots): true when the game data does not say (the old behaviour).
static func minion_leap_detonates(boss_id: String, minion_id: String) -> bool:
	var v = boss_minion(boss_id, minion_id).get("leapDetonateNextTurn")
	return v if v is bool else true


## A boss skill ({skillId, name, description, kind}) of the boss boss_id, or of any boss when
## boss_id is "" or does not have it; {} unknown.
static func boss_skill(boss_id: String, skill_id: String) -> Dictionary:
	if skill_id == "":
		return {}
	for b in ([boss(boss_id)] if boss_id != "" else []) + bosses():
		for s in _list_in(b, "skills"):
			if _s(s, "skillId") == skill_id:
				return s
	return {}


## A body size of the game data (a boss's or a minion's bodySize): 1 when not positive.
static func body_size_of(entry: Dictionary) -> float:
	var v := _f(entry, "bodySize")
	return v if v > 0.0 else 1.0


## The game data entry of a match's boss or minion player (role boss / minion, bossId, minionId):
## its bosses entry or minion type; {} for a player or an unknown id.
static func boss_unit(p: Dictionary) -> Dictionary:
	match _s(p, "role"):
		"boss":
			return boss(_s(p, "bossId"))
		"minion":
			return boss_minion(_s(p, "bossId"), _s(p, "minionId"))
	return {}


## A boss or minion flies (no gravity, no fall: it hovers in the air): the state's flying, else
## the game data's (a boss's flying, a minion's movement "fly"); false for a player.
static func unit_flying(p: Dictionary) -> bool:
	if p.get("flying") is bool:
		return p["flying"]
	var u := boss_unit(p)
	if _s(p, "role") == "boss":
		return _b(u, "flying")
	return unit_movement(p) == "fly"


## A minion's behavior ("shooter" / "bomber"): the state's, else its game data type's; "" none.
static func unit_behavior(p: Dictionary) -> String:
	var v := _s(p, "behavior")
	return v if v != "" else _s(boss_unit(p), "behavior")


## A minion's movement ("none" / "walk" / "fly"): the state's, else its game data type's; "" none.
static func unit_movement(p: Dictionary) -> String:
	var v := _s(p, "movement")
	return v if v != "" else _s(boss_unit(p), "movement")


## How close (px) a bomber minion detonates to a party player (its type's detonateRange); 0
## when the game data does not say.
static func unit_detonate_range(p: Dictionary) -> float:
	var v = p.get("detonateRange")
	if (v is int or v is float) and v > 0:
		return float(v)
	return maxf(_f(boss_unit(p), "detonateRange"), 0.0)


## A minion blasts where it dies (its type's explodeOnDeath; the state's when it carries one).
static func unit_explodes_on_death(p: Dictionary) -> bool:
	if p.get("explodeOnDeath") is bool:
		return p["explodeOnDeath"]
	return _b(boss_unit(p), "explodeOnDeath")


## The blast radius (px) of a minion's detonation / death blast (its type's explodeRadius); 0
## unknown.
static func unit_explode_radius(p: Dictionary) -> float:
	var v = p.get("explodeRadius")
	if (v is int or v is float) and v > 0:
		return float(v)
	return maxf(_f(boss_unit(p), "explodeRadius"), 0.0)


## A flying boss's hover band {minX, maxX, minY, maxY} ({} none).
static func boss_hover(boss_id: String) -> Dictionary:
	return _sub(boss(boss_id), "hover")


# ── elements (ngũ hành) ─────────────────────────────────────────────────────
# elements: [{elementId, name, beats, sortOrder}] (the "beats" cycle: metal → wood → earth →
# water → fire → metal), elementRules {pvpStrongPct, pvpWeakPct, bossStrongPct, bossTakenPct},
# characters[].element, bosses[].element (minions carry their boss's). The server applies the
# multipliers; the client only shows them (badges, the detail line, the counter hint, the damage
# numbers' elementEffect). [] / "" / 0 from a server without them.

## [{elementId, name, beats, sortOrder}] by sortOrder (the server's order for equal ones).
static func elements() -> Array:
	var out := list("elements").filter(func(e): return _s(e, "elementId") != "")
	var order := {}
	for i in out.size():
		order[out[i]] = i
	out.sort_custom(func(a, b):
		var sa := _f(a, "sortOrder")
		var sb := _f(b, "sortOrder")
		return sa < sb if sa != sb else int(order[a]) < int(order[b]))
	return out


static func element_ids() -> Array:
	return elements().map(func(e): return _s(e, "elementId"))


static func element(element_id: String) -> Dictionary:
	return _entry("elements", element_id)


static func is_element(element_id: String) -> bool:
	return element_id != "" and not element(element_id).is_empty()


## "Thủy"; the id itself for an element the game data does not know ("" for "").
static func element_name(element_id: String) -> String:
	var n := _s(element(element_id), "name")
	return n if n != "" else element_id


## The element `element_id` beats (khắc), "" none / unknown.
static func element_beats(element_id: String) -> String:
	return _s(element(element_id), "beats")


## The element that beats `element_id` (bị ... khắc), "" none.
static func element_beaten_by(element_id: String) -> String:
	if element_id == "":
		return ""
	for e in elements():
		if _s(e, "beats") == element_id:
			return _s(e, "elementId")
	return ""


## "strong" when `attacker` beats `target`, "weak" when `target` beats `attacker`, "" otherwise
## (also when either is unknown): the same rule the server's elementEffect follows.
static func element_effect(attacker: String, target: String) -> String:
	if attacker == "" or target == "" or attacker == target:
		return ""
	if element_beats(attacker) == target:
		return "strong"
	if element_beats(target) == attacker:
		return "weak"
	return ""


## {pvpStrongPct, pvpWeakPct, bossStrongPct, bossTakenPct} (0 for a missing one).
static func element_rules() -> Dictionary:
	var r := section("elementRules")
	var out := {}
	for k in ["pvpStrongPct", "pvpWeakPct", "bossStrongPct", "bossTakenPct"]:
		out[k] = _f(r, k)
	return out


## A character's element ("" none).
static func character_element(character_id: String) -> String:
	return _s(character(character_id), "element")


## A boss's element ("" none).
static func boss_element(boss_id: String) -> String:
	return _s(boss(boss_id), "element")


## A match unit's element: the state's element (BattlePlayerState / the summon event), else its
## game data's (a boss or minion: its boss's; a player: its character's); "" none.
static func unit_element(p: Dictionary) -> String:
	var v := _s(p, "element")
	if v != "":
		return v
	if _s(p, "role") in ["boss", "minion"]:
		return boss_element(_s(p, "bossId"))
	return character_element(_s(p, "characterId"))

