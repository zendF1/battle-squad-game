extends "res://tests/test_case.gd"
## The game data model (autoload/game_data_model.gd) on tests/fixtures/gamedata.json (a real
## GET /gamedata answer): parsing, the typed accessors, the cache file and the ETag, the 304 /
## failure handling, the match version check, unknown ids and the description templates; and
## PlayerState.load_gamedata() against a fake REST client.

const GameData := preload("res://autoload/game_data_model.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")
const FIXTURE := "res://tests/fixtures/gamedata.json"
const CACHE := "user://test_gamedata_cache.json"


static func _raw() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


static func _ok(data: Variant, etag: String = "") -> Dictionary:
	return {"ok": true, "status": 200, "code": "", "message": "", "data": data, "etag": etag}


static func _not_modified() -> Dictionary:
	return {"ok": true, "status": 304, "code": "", "message": "", "data": null, "etag": ""}


static func _fail(status: int) -> Dictionary:
	return {"ok": false, "status": status, "code": "NETWORK_ERROR" if status == 0 else "INTERNAL_SERVER_ERROR", "message": "", "data": null}


static func _edited(version: String) -> Dictionary:
	var d: Dictionary = GameData.parse(_raw()).duplicate(true)
	d["version"] = version
	return d


func _remove_cache() -> void:
	if FileAccess.file_exists(CACHE):
		DirAccess.remove_absolute(CACHE)


# ── Parsing ─────────────────────────────────────────────────────────────────

func test_parse() -> void:
	var raw := _raw()
	var d = GameData.parse(raw)
	check(d is Dictionary, "the envelope")
	eq(d["version"], "4eedfeb2e6a5a751", "its version")
	eq(GameData.parse(raw["data"]), d, "the data itself")
	eq(GameData.parse(null), null, "nothing")
	eq(GameData.parse({"success": true, "data": {"physics": {}}}), null, "no version: not game data")
	eq(GameData.parse({"version": "  "}), null, "a blank version")
	eq(GameData.parse([1, 2]), null, "not an object")


func test_fixture_is_loaded_for_every_test() -> void:
	check(GameData.is_loaded(), "loaded by tests/run_tests.gd")
	eq(GameData.version, "4eedfeb2e6a5a751", "the fixture's version")
	eq(GameData.cache_path, "", "no cache file in tests")


# ── Accessors ───────────────────────────────────────────────────────────────

func test_physics_and_aim() -> void:
	eq([GameData.gravity(), GameData.speed_per_power(), GameData.wind_scale(), GameData.time_step()], [445.0, 9.6, 67.0, 0.02], "flight")
	eq([GameData.max_flight_sec(), GameData.player_hit_radius(), GameData.collision_step_px(), GameData.shot_origin_lift()],
		[4.5, 24.0, 4.0, 20.0], "hits")
	eq(GameData.out_of_bounds(), {"left": 100.0, "right": 100.0, "below": 50.0}, "bounds")
	eq([GameData.power_min(), GameData.power_max(), GameData.angle_min(), GameData.angle_max()], [0.0, 100.0, 0.0, 180.0], "aim ranges")
	eq([GameData.no_aim_angle(), GameData.no_aim_power()], [90.0, 50.0], "no-aim shot")
	eq(GameData.guide_arc_length("gold"), 600.0, "gold guide")
	eq(GameData.guide_arc_length(""), 700.0, "no rank: the default tier's")
	eq(GameData.guide_arc_length("legend"), 700.0, "an unknown tier: the default tier's")
	eq(GameData.hit_tolerance(), {"max": 20.0, "minPart": 0.2, "farPx": 1200.0, "highPx": 700.0}, "hit tolerance")
	eq(GameData.effect_param("laser", "halfWidth"), 10.0, "the laser's half width")
	eq(GameData.effect_param("earthquake", "halfWidth"), 0.0, "no such skill")


func test_terrain_movement_timings() -> void:
	eq([GameData.player_height(), GameData.max_climb_per_step()], [40, 3], "terrain")
	eq([GameData.bowl_depth(), GameData.bowl_ceiling(), GameData.crater_px_per_terrain_damage()], [0.72, 1.5, 0.6], "bowl")
	eq([GameData.px_per_energy(), GameData.energy_per_px(), GameData.default_move_energy()], [2.0, 0.5, 100], "movement")
	eq([GameData.turn_sec(), GameData.action_interval_sec(), GameData.bot_follow_up_delay_sec(), GameData.skip_turn_delay_sec()],
		[20, 0.15, 1.5, 2.0], "timings")
	eq([GameData.skill_energy_max(), GameData.skill_energy_per_turn(), GameData.skill_energy_on_hit()], [100, 20, 10], "skill energy")


func test_characters_weapons_items() -> void:
	eq(GameData.character_ids(), ["rookie", "tanko", "spark", "flora"], "display order")
	eq(GameData.default_character_id(), "rookie", "default")
	eq([GameData.character_name("tanko"), GameData.character_role_name("tanko"), GameData.character_gun_kind("tanko")],
		["Tanko", "Phá địa hình", "cannon"], "tanko")
	eq([GameData.character_weapon_id("spark"), GameData.character_skill_id("spark")], ["electric_orb", "shock_field"], "spark's gear")
	eq(GameData.weapon_crater_radius("seed_bomb"), 14.399999999999999, "the exact crater")
	eq([GameData.weapon_wind_influence("cannon_ball"), GameData.weapon_projectile_weight("cannon_ball")], [0.5, 1.5], "wind")
	eq(GameData.item_ids().size(), 8, "eight items")
	eq([GameData.item_name("air_strike"), GameData.item_aim_kind("air_strike"), GameData.item_instant("medkit")],
		["Không kích", "targetX", true], "items")
	eq([GameData.max_loadout(), GameData.air_strike_angle(), GameData.air_strike_power()], [3, 270.0, 80.0], "item rules")
	eq(GameData.character_of_gun_kind("seed_launcher"), "flora", "by gun kind")


func test_status_rank_levels_equipment() -> void:
	eq(GameData.status_ids().slice(0, 5), ["burn", "root", "stun", "freeze", "net"], "effects in order")
	eq([GameData.status_banner("stun"), GameData.status_skips_turn("stun"), GameData.status_blocks_move("root")],
		["Choáng — mất lượt", true, true], "stun / root rules")
	eq(GameData.status_marker("power_shot"), "x1.5", "a marker")
	eq(GameData.tier_ids(), ["bronze", "silver", "gold", "platinum", "diamond", "master"], "tiers")
	eq([GameData.tier_name("platinum"), GameData.tier_divisions("master"), GameData.default_rating(), GameData.ranked_mode()],
		["Bạch kim", 1, 1000, "ranked_2v2"], "rank")
	eq(GameData.tier_of_rating(999), ["bronze", 1], "bronze I")
	eq(GameData.tier_of_rating(1066), ["silver", 2], "silver II")
	eq(GameData.tier_of_rating(-5), ["bronze", 3], "below the first tier")
	eq(GameData.tier_of_rating(5000), ["master", 1], "master")
	eq([GameData.character_exp_required(1), GameData.character_exp_required(10), GameData.character_exp_required(80)], [0, 5200, 151325], "levels")
	eq(GameData.character_exp_required(200), 151325, "past the table: the last")
	eq([GameData.character_max_level(), GameData.player_exp_per_level()], [80, 100], "level caps")
	eq(GameData.upgrade_milestones(), [[6, 0.1], [10, 0.2], [14, 0.4], [16, 1.0]], "milestones")
	eq(GameData.equipment_tier_ids("crafted"), ["silver", "gold", "titan", "diamond"], "crafted tiers")
	eq([GameData.equipment_tier_of_suffix("lv30"), GameData.equipment_tier_name("dragon")], ["mithril", "Rồng"], "tier words")
	eq([GameData.skill_rank_of_weapon("rookie_weapon_lv20"), GameData.skill_rank_of_weapon("crafted_weapon_gold"),
		GameData.skill_rank_of_weapon("odd_weapon_x"), GameData.skill_rank_of_weapon("")], [2, 3, 0, 0], "skill ranks by weapon")
	eq([GameData.coins_per_gem(), GameData.match_slots(), GameData.team_size(), GameData.match_start_delay_sec()], [100, 4, 2, 3.0], "economy, matchmaking")
	eq(GameData.tips().size(), 12, "tips")
	eq(GameData.lobby_modes().map(func(m): return m["modeId"]), ["practice", "ranked", "bot"], "lobby modes")
	eq([GameData.match_mode_name("pvp_2v2"), GameData.match_mode_name("koth")], ["Đấu 2v2", "koth"], "match modes; an unknown one raw")
	eq([GameData.default_theme(), GameData.themes().size()], ["grassland", 11], "themes")


func test_slots_type_words_gun_kinds() -> void:
	eq(GameData.equipment_slot_ids(), ["helmet", "armor", "gloves", "pants", "boots", "weapon"], "slots in order")
	eq([GameData.equipment_slot_name("gloves"), GameData.equipment_slot_name("ring")], ["Găng tay", "ring"], "slot names; an unknown one raw")
	eq([GameData.type_word_name("shock rifle"), GameData.type_word_gun_kind("shock rifle")], ["Súng điện", "shock_rifle"], "a gun's type word")
	eq([GameData.type_word_name("vest"), GameData.type_word_gun_kind("vest")], ["Áo giáp", ""], "an armour's")
	eq([GameData.type_word_name("laser"), GameData.type_word_gun_kind("laser")], ["", ""], "unknown")
	eq(GameData.gun_kinds().map(func(g): return g["id"]), ["bazooka", "cannon", "shock_rifle", "seed_launcher", "blaster"], "gun kinds in order")
	eq([GameData.gun_kind_name("seed_launcher"), GameData.gun_kind_name("laser")], ["Súng hạt", ""], "gun kind names")


func test_unknown_ids_never_crash() -> void:
	eq([GameData.character_name("ghost"), GameData.item_name("ghost"), GameData.skill_name("ghost"), GameData.status_name("ghost")],
		["ghost", "ghost", "", ""], "names: the id for characters and items, none for a skill / effect")
	eq([GameData.weapon_crater_radius("ghost"), GameData.skill_param("ghost", "x"), GameData.item_value("ghost")], [0.0, 0.0, 0.0], "numbers: 0")
	eq([GameData.skill_aim_kind("ghost"), GameData.item_aim_kind("ghost"), GameData.tier_name("legend")], ["arc", "none", ""], "kinds")
	check(not GameData.status_bad("ghost") and not GameData.item_instant("ghost"), "flags: false")
	eq(GameData.skill_describe("ghost", 2), "", "no description")


func test_empty_data_reads_as_zero() -> void:
	GameData.reset("")
	check(not GameData.is_loaded(), "nothing held")
	eq([GameData.gravity(), GameData.turn_sec(), GameData.character_ids(), GameData.tier_of_rating(1000)], [0.0, 0, [], ["", 0]], "zeros")
	eq(GameData.if_none_match(), "", "no ETag to send")


# ── Templates ───────────────────────────────────────────────────────────────

func test_description_templates() -> void:
	eq(GameData.skill_describe("triple_shot", 0),
		"Bắn pháo hiệu, 12 tên lửa rơi quanh chỗ đáp (+4 mỗi cấp súng), mỗi quả 25% sát thương; địch trúng bị bỏng: mất 10% máu tối đa đầu lượt sau.",
		"the contract's example")
	check(GameData.skill_describe("heavy_bomb", 4).contains("6 quả") and GameData.skill_describe("heavy_bomb", 4).contains("mỗi quả 34%"), "bombs rank 4")
	eq(GameData.skill_describe("shock_field", 9), GameData.skill_describe("shock_field", 4), "a rank past the max: the max")
	eq(GameData.fill_template("{a} + {b} = {c}%, {missing}, {", {"a": 12.0, "b": 0.15, "c": 12.5}), "12 + 0.15 = 12.5%, {missing}, {", "numbers, unknown keys kept")
	eq(GameData.fill_template("{a}{a}", {"a": 3}), "33", "twice")
	eq(GameData.fill_template("no keys", {}), "no keys", "plain text")
	eq([GameData.number_text(2.0), GameData.number_text(-3.0), GameData.number_text(14.399999999999999)], ["2", "-3", "14.4"], "number texts")


# ── Answers, cache and ETag ─────────────────────────────────────────────────

func test_take_and_answers() -> void:
	GameData.reset("")
	eq(GameData.apply_response(_ok(_raw(), "\"4eedfeb2e6a5a751\""), 1000), GameData.UPDATED, "a 200: taken")
	eq(GameData.if_none_match(), "\"4eedfeb2e6a5a751\"", "the server's ETag is sent back")
	eq(GameData.checked_msec, 1000, "checked")
	eq(GameData.apply_response(_ok(_raw()), 2000), GameData.SAME, "the same version: nothing changes")
	eq(GameData.apply_response(_not_modified(), 3000), GameData.SAME, "304: kept")
	eq(GameData.checked_msec, 3000, "a 304 is a good answer")
	eq(GameData.apply_response(_fail(0), 4000), GameData.FAILED, "offline")
	eq(GameData.apply_response(_fail(500), 4000), GameData.FAILED, "a server error")
	eq(GameData.apply_response(_ok({"version": ""}), 4000), GameData.FAILED, "not game data")
	eq(GameData.checked_msec, 3000, "failures are not checks")
	eq(GameData.version, "4eedfeb2e6a5a751", "the data held stays")
	eq(GameData.apply_response(_ok({"success": true, "data": _edited("v2")}), 5000), GameData.UPDATED, "a new version")
	eq([GameData.version, GameData.if_none_match()], ["v2", "\"v2\""], "no ETag header: made from the version")
	GameData.reset("")
	eq(GameData.apply_response(_not_modified(), 1), GameData.FAILED, "a 304 with nothing held")


func test_cache_file() -> void:
	_remove_cache()
	GameData.reset(CACHE)
	check(not GameData.is_loaded(), "no cache yet")
	GameData.apply_response(_ok(_raw(), "\"4eedfeb2e6a5a751\""), 10)
	check(FileAccess.file_exists(CACHE), "cached")
	GameData.reset(CACHE) # a new launch
	check(GameData.is_loaded(), "read back from the cache")
	eq([GameData.version, GameData.if_none_match()], ["4eedfeb2e6a5a751", "\"4eedfeb2e6a5a751\""], "with its version and ETag")
	eq(GameData.turn_sec(), 20, "and its numbers")
	eq(GameData.checked_msec, -1, "not checked yet this launch")
	eq(GameData.apply_response(_fail(0), 20), GameData.FAILED, "offline on the next launch")
	eq(GameData.character_name("flora"), "Flora", "the cache is used")
	GameData.apply_response(_ok(_edited("v3"), "\"v3\""), 30)
	GameData.reset(CACHE)
	check(GameData.is_loaded(), "read back")
	eq(GameData.version, "v3", "a new version replaces the cache")
	var f := FileAccess.open(CACHE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	GameData.reset(CACHE)
	check(not GameData.is_loaded(), "a broken cache is no game data")
	_remove_cache()


func test_match_version_and_recheck() -> void:
	check(not GameData.needs_refetch("4eedfeb2e6a5a751"), "the same version")
	check(GameData.needs_refetch("0123456789abcdef"), "another version")
	check(not GameData.needs_refetch(null), "an older server sends none")
	check(not GameData.needs_refetch(""), "empty")
	GameData.checked_msec = -1
	check(GameData.check_due(0), "never checked")
	GameData.checked_msec = 1000
	check(not GameData.check_due(1000 + GameData.RECHECK_MSEC - 1), "checked a moment ago")
	check(GameData.check_due(1000 + GameData.RECHECK_MSEC), "old enough")


# ── The match's version ─────────────────────────────────────────────────────

const VERSIONS_CACHE := "user://test_gamedata_cache_versions.json"


func _remove_caches() -> void:
	_remove_cache()
	if FileAccess.file_exists(VERSIONS_CACHE):
		DirAccess.remove_absolute(VERSIONS_CACHE)


static func _turn(version: String, turn_sec: int) -> Dictionary:
	var d := _edited(version)
	d["timings"]["turnSec"] = turn_sec
	return d


func test_match_plays_with_its_version() -> void:
	var lobby_version := GameData.version
	check(GameData.use_match(lobby_version), "the lobby copy's version: in use at once")
	check(not GameData.needs_refetch(lobby_version), "no fetch")
	GameData.take(_turn("newer", 30), "", false) # an admin saved mid-match: a plain GET is newer
	eq([GameData.lobby_version, GameData.version, GameData.turn_sec()], ["newer", lobby_version, 20], "the match keeps its own")
	GameData.end_match()
	eq([GameData.version, GameData.turn_sec()], ["newer", 30], "after the match: the newest")
	check(not GameData.use_match("m1"), "a version not held")
	eq(GameData.version, "newer", "the lobby copy meanwhile")
	check(GameData.needs_refetch("m1"), "it must be fetched")
	eq(GameData.apply_version_response(_ok({"success": true, "data": _turn("m1", 15)}), "m1"), GameData.UPDATED, "taken")
	eq([GameData.version, GameData.turn_sec(), GameData.lobby_version], ["m1", 15, "newer"], "in use; the lobby copy stays")
	eq(GameData.if_none_match(), "\"newer\"", "a plain GET still asks with the lobby copy's ETag")
	GameData.take(_turn("newest", 40), "", false)
	eq(GameData.version, "m1", "a plain answer does not change the match's")
	GameData.end_match()
	eq(GameData.version, "newest", "back to the lobby")
	check(GameData.use_match("m1") and GameData.turn_sec() == 15, "the next match on m1 uses the copy held")
	GameData.end_match()
	check(GameData.use_match(null) and GameData.version == "newest", "an older server sends none: the lobby copy")


func test_version_answers() -> void:
	GameData.use_match("m2")
	eq(GameData.apply_version_response({"ok": false, "status": 404, "code": "GAMEDATA_VERSION_NOT_FOUND", "message": "", "data": null}, "m2"),
		GameData.NOT_FOUND, "404: fall back to the plain GET")
	eq(GameData.apply_version_response(_fail(0), "m2"), GameData.FAILED, "offline")
	eq(GameData.apply_version_response(_ok(_edited("other")), "m2"), GameData.FAILED, "another version")
	eq(GameData.version, "4eedfeb2e6a5a751", "the copy in use stays")
	eq(GameData.apply_version_response(_ok(_edited("m2")), "m2"), GameData.UPDATED, "the match's")
	eq(GameData.apply_version_response(_ok(_edited("m2")), "m2"), GameData.SAME, "again: held")


func test_match_copies_cached_by_version() -> void:
	_remove_caches()
	GameData.reset(CACHE)
	eq(GameData.versions_path(), VERSIONS_CACHE, "next to the lobby cache")
	GameData.apply_response(_ok(_raw()), 1)
	for v in ["a", "b", "c", "d"]:
		GameData.use_match(v)
		GameData.apply_version_response(_ok(_turn(v, 11)), v)
	GameData.end_match()
	GameData.reset(CACHE) # a new launch
	check(GameData.is_loaded(), "read back")
	eq(GameData.version, "4eedfeb2e6a5a751", "the lobby copy in use")
	check(not GameData.has_version("a"), "the oldest pruned")
	check(GameData.has_version("b") and GameData.has_version("d"), "the newest %d kept" % GameData.MAX_VERSIONS)
	check(GameData.use_match("c") and GameData.turn_sec() == 11, "a reconnect plays with the cached copy")
	_remove_caches()


func test_player_state_fetches_the_match_version() -> void:
	var api := FakeApi.new()
	api.answers = [_ok(_turn("m3", 25), "\"m3\"")]
	var s = _state(api)
	var ok: bool = await s.load_match_gamedata(GameData.version)
	check(ok and api.calls.is_empty(), "held: no fetch")
	ok = await s.load_match_gamedata("m3")
	check(ok, "the match's version")
	eq(api.calls, [["/gamedata?version=m3", ""]], "GET /gamedata?version=")
	eq([GameData.version, GameData.turn_sec()], ["m3", 25], "in use")
	GameData.end_match()
	s.free()


func test_player_state_falls_back_on_404() -> void:
	var api := FakeApi.new()
	api.answers = [{"ok": false, "status": 404, "code": "GAMEDATA_VERSION_NOT_FOUND", "message": "", "data": null},
		_ok(_turn("plain", 35), "\"plain\"")]
	var s = _state(api)
	var ok: bool = await s.load_match_gamedata("pruned")
	check(not ok, "not the match's own version")
	eq(api.calls, [["/gamedata?version=pruned", ""], ["/gamedata", "\"4eedfeb2e6a5a751\""]], "then the plain GET")
	eq([GameData.version, GameData.match_version, GameData.turn_sec()], ["plain", "plain", 35], "the match plays with the newest")
	GameData.take(_turn("later", 45), "", false)
	eq(GameData.version, "plain", "and keeps it")
	GameData.end_match()
	s.free()


# ── PlayerState.load_gamedata() ─────────────────────────────────────────────

class FakeApi:
	extends RefCounted
	var calls: Array = [] # [path, etag]
	var answers: Array = [] # answered in order; the last one repeats

	func get_cached(path: String, etag: String) -> Dictionary:
		calls.append([path, etag])
		return answers[mini(calls.size() - 1, answers.size() - 1)]


func _state(api: FakeApi):
	var s = PlayerStateScript.new()
	s.api = api
	return s


func test_player_state_loads_and_keeps_on_304() -> void:
	GameData.reset("")
	var api := FakeApi.new()
	api.answers = [_ok(_raw(), "\"4eedfeb2e6a5a751\"")]
	var s = _state(api)
	var changed := [0]
	s.gamedata_changed.connect(func(): changed[0] += 1)
	var ok: bool = await s.load_gamedata()
	check(ok, "usable")
	eq(api.calls, [["/gamedata", ""]], "the first launch sends no ETag")
	eq(changed[0], 1, "changed once")
	api.answers = [_not_modified()]
	ok = await s.load_gamedata()
	check(ok, "still usable")
	eq(api.calls[1], ["/gamedata", "\"4eedfeb2e6a5a751\""], "If-None-Match with the ETag")
	eq(changed[0], 1, "a 304 changes nothing")
	api.answers = [_fail(0)]
	ok = await s.load_gamedata()
	check(ok, "offline with a copy held: usable")
	eq(GameData.version, "4eedfeb2e6a5a751", "kept")
	s.free()


func test_player_state_first_launch_offline() -> void:
	GameData.reset("")
	var api := FakeApi.new()
	api.answers = [_fail(0)]
	var s = _state(api)
	var ok: bool = await s.load_gamedata()
	check(not ok, "no game data: Splash shows its retry screen")
	api.answers = [_ok(_raw())]
	ok = await s.load_gamedata()
	check(ok, "the retry loads it")
	s.free()


func test_player_state_304_without_a_copy_asks_again() -> void:
	GameData.reset("")
	var api := FakeApi.new()
	api.answers = [_not_modified(), _ok(_raw())]
	var s = _state(api)
	var ok: bool = await s.load_gamedata()
	check(ok, "loaded")
	eq(api.calls, [["/gamedata", ""], ["/gamedata", ""]], "asked again for the body")
	s.free()
