extends "res://tests/test_case.gd"
## The guild (contract guilds.md) and the gift code (giftcode.md): the game data's guild rules,
## parsing the guild / roster / rankings / invites / activity / match answers, the role
## permissions, the EXP and quest bars, the skill pictures, the name rule, the error texts, the gift
## code's tiles, the result screen's guild EXP tile, the lobby button's dot and the page's views.

const GameData := preload("res://autoload/game_data_model.gd")
const GuildModel := preload("res://screens/guild/guild_model.gd")
const GuildPage := preload("res://screens/guild/guild_page.gd")
const GuildUi := preload("res://screens/guild/guild_ui.gd")
const GuildButton := preload("res://screens/guild/guild_button.gd")
const GuildGlyphs := preload("res://ui/guild_glyphs.gd")
const GuildInvitePopup := preload("res://screens/guild/guild_invite_popup.gd")
const ResultModel := preload("res://match/result_model.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")
const PlayerInfoPopup := preload("res://match/views/player_info_popup.gd")
const GiftCodePopup := preload("res://screens/home/gift_code_popup.gd")


static func _guild() -> Dictionary:
	return {"id": "6f1c2a9e-3b7d-4c51-9a0e-1d2f3a4b5c6d", "name": "Bão Thép", "exp": 4200, "level": 5,
		"hpPercent": 5, "defensePercent": 5, "memberCount": 3, "maxMembers": 50, "leaderName": "SấmSét99",
		"members": [
			{"playerId": "a1", "role": "leader", "displayName": "SấmSét99", "level": 12, "characterId": "rookie", "power": 5321},
			{"playerId": "b2", "role": "deputy", "displayName": "MâyXanh", "level": 7, "characterId": "tide", "power": 3410},
			{"playerId": "c3", "role": "member", "displayName": "Lá", "level": 3, "characterId": "", "power": 900},
			{"role": "member"}, "junk"]}


func test_rules_from_game_data() -> void:
	var r := GameData.guild_rules()
	eq(r["create_currency"], "gem", "currency")
	eq(r["create_amount"], 1000, "cost")
	eq(r["max_members"], 50, "members")
	eq(r["max_deputies"], 2, "deputies")
	eq(r["exp_per_level"], 1000, "exp per level")
	eq(r["skills"].size(), 2, "skills")
	eq(r["skills"][1], {"level": 5, "hp_percent": 0, "defense_percent": 5}, "level 5 skill")
	eq(r["quest_target"], 5, "quest target")
	eq(r["quest_exp"], 100, "quest exp")
	eq(r["dungeon_exp"], 200, "dungeon exp")
	eq([r["name_min"], r["name_max"]], [3, 40], "name rule")


func test_rules_missing_block() -> void:
	var d: Dictionary = GameData.data.duplicate(true)
	d.erase("guild")
	d["version"] = "no-guild"
	GameData.take(d, "", false)
	var r := GameData.guild_rules()
	eq(r["create_amount"], 0, "no cost")
	eq(r["skills"], [], "no skills")


func test_parse_guild_and_roster() -> void:
	var g := GuildModel.parse_guild(_guild())
	eq(g["name"], "Bão Thép", "name")
	eq(g["level"], 5, "level")
	eq(g["member_count"], 3, "count")
	eq(g["leader_name"], "SấmSét99", "leader")
	eq(g["members"].size(), 3, "junk rows dropped")
	eq(g["members"][1], {"player_id": "b2", "role": "deputy", "name": "MâyXanh", "level": 7, "character": "tide", "power": 3410}, "deputy row")
	eq(GuildModel.parse_guild({"name": "x"}), {}, "no id")
	eq(GuildModel.parse_guild(null), {}, "null")
	var old := GuildModel.parse_guild({"id": "g", "members": [{"playerId": "p", "role": "boss"}]})
	eq(old["member_count"], 1, "count from the roster when missing")
	eq(old["members"][0]["role"], "member", "unknown role")
	eq(old["members"][0]["power"], -1, "power unknown")


func test_rankings_invites_activity() -> void:
	var r := GuildModel.parse_rankings([{"id": "g1", "name": "A", "level": 3, "memberCount": 9, "maxMembers": 50, "leaderName": "X"}, {"name": "bad"}, {"id": "g2", "name": "B"}])
	eq(r.size(), 2, "two guilds")
	eq([r[0]["pos"], r[1]["pos"]], [1, 2], "positions")
	eq(GuildModel.members_text(r[0], 0), "9/50", "members text")
	eq(GuildModel.members_text({"member_count": 4, "max_members": 0}, 30), "4/30", "max from the rules")
	eq(GuildModel.parse_invites([{"guildId": "g1", "name": "A", "expiresAt": "2026-11-06T00:00:00Z"}, {"name": "x"}]), [{"guild_id": "g1", "name": "A"}], "invites")
	var a := GuildModel.parse_activity({"quest": {"id": "daily_counted_wins", "progress": 3, "target": 5, "rewardExp": 100, "awarded": false}, "dungeon": null})
	eq(a["quest"], {"progress": 3, "target": 5, "reward_exp": 100, "awarded": false}, "quest")
	eq(a["dungeon"], {}, "no dungeon")
	var d := GuildModel.parse_dungeon({"id": "d", "day": "2026-10-30", "bossId": "steel_robot", "queue": "boss:steel_robot", "rewardExp": 200, "completedMatchId": null})
	eq(d, {"id": "d", "boss_id": "steel_robot", "queue": "boss:steel_robot", "reward_exp": 200, "done": false}, "dungeon")
	eq(GuildModel.parse_dungeon({"bossId": "x", "completedMatchId": "m1"})["done"], true, "cleared")


func test_roles() -> void:
	var g := GuildModel.parse_guild(_guild())
	eq(GuildModel.role_of(g, "a1"), "leader", "leader")
	eq(GuildModel.role_of(g, "zz"), "", "outsider")
	check(GuildModel.can_manage("leader") and GuildModel.can_manage("deputy") and not GuildModel.can_manage("member"), "manage")
	eq(GuildModel.member_actions("leader", "member", false), ["promote", "transfer", "kick"], "leader on a member")
	eq(GuildModel.member_actions("leader", "deputy", false), ["demote", "transfer", "kick"], "leader on a deputy")
	eq(GuildModel.member_actions("deputy", "member", false), ["kick"], "deputy on a member")
	eq(GuildModel.member_actions("deputy", "deputy", false), [], "deputy on a peer")
	eq(GuildModel.member_actions("deputy", "leader", false), [], "nobody on the leader")
	eq(GuildModel.member_actions("member", "member", false), [], "member")
	eq(GuildModel.member_actions("leader", "member", true), [], "not on myself")
	check(GuildModel.leaves_by_disband("leader") and not GuildModel.leaves_by_disband("deputy"), "leader disbands")
	eq(GuildModel.deputy_count(g), 1, "deputies")


func test_bars_and_skills() -> void:
	eq(GuildModel.exp_bar(4200, 5, 1000), {"ratio": 0.2, "text": "200/1.000"}, "exp inside the level")
	eq(GuildModel.exp_bar(0, 1, 1000)["text"], "0/1.000", "fresh")
	eq(GuildModel.exp_bar(50, 1, 0)["ratio"], 0.0, "no rule")
	var icons := GuildModel.skill_icons(GameData.guild_rules()["skills"], 2)
	eq(icons, [{"stat": "hp", "percent": 5, "level": 1, "unlocked": true}, {"stat": "defense", "percent": 5, "level": 5, "unlocked": false}], "skills at level 2")
	eq(GuildModel.skill_icons(GameData.guild_rules()["skills"], 5)[1]["unlocked"], true, "level 5 unlocks defense")
	eq(GuildModel.quest_bar({"progress": 7, "target": 5, "awarded": true}), {"ratio": 1.0, "text": "5/5", "done": true}, "quest capped")
	eq(GuildModel.quest_bar({"progress": 2, "target": 5})["done"], false, "quest running")
	eq(GuildModel.percent_text(5), "+5%", "percent")


func test_name_rule_and_errors() -> void:
	eq(GuildModel.name_problem("  ", 3, 40), "Hãy đặt tên bang hội", "empty")
	eq(GuildModel.name_problem(" ab ", 3, 40), "Tên bang hội từ 3 ký tự", "short")
	eq(GuildModel.name_problem("a".repeat(41), 3, 40), "Tên bang hội tối đa 40 ký tự", "long")
	eq(GuildModel.name_problem("Bão Thép", 3, 40), "", "ok")
	eq(GuildModel.error_text({"ok": false, "status": 409, "code": "GUILD_CONFLICT"}, "create"), "Tên bang hội đã có người dùng", "name taken")
	eq(GuildModel.error_text({"ok": false, "status": 409, "code": "GUILD_CONFLICT"}, "accept"), "Đã ở trong một bang hội khác", "accept conflict")
	eq(GuildModel.error_text({"ok": false, "status": 409, "code": "GUILD_FULL"}), "Bang hội đã đủ người", "full")
	eq(GuildModel.error_text({"ok": false, "status": 409, "code": "GUILD_DEPUTY_LIMIT"}), "Đã đủ số phó bang", "deputies")
	eq(GuildModel.error_text({"ok": false, "status": 409, "code": "GUILD_DUNGEON_ALREADY_OPEN"}), "Hôm nay đã mở phó bản khác", "dungeon")
	eq(GuildModel.error_text({"ok": false, "status": 409, "code": "GUILD_ALREADY_MEMBER"}, "create"), "Bạn đã ở trong một bang hội", "already")
	eq(GuildModel.error_text({"ok": false, "status": 400, "code": "SHOP_INSUFFICIENT_BALANCE"}, "create", "gem"), "Không đủ kim cương", "gems")
	check(GuildModel.is_insufficient({"code": "SHOP_INSUFFICIENT_BALANCE"}), "insufficient")
	eq(GuildModel.error_text({"ok": false, "status": 0, "code": ""}), "Không kết nối được server, hãy thử lại", "offline")
	eq(GuildModel.error_text({"ok": false, "status": -1, "code": "BUSY"}), "Đang xử lý, chờ chút", "busy")


func test_gift_code() -> void:
	eq(GuildModel.gift_code(" Launch_2026 "), " Launch_2026 ", "never trimmed: the server checks it")
	eq(GuildModel.gift_code("   "), "", "nothing to send")
	eq(GuildModel.gift_code("x".repeat(60)).length(), 50, "capped")
	eq(GuildModel.gift_error({"ok": false, "status": 400, "code": "GIFT_CODE_REDEEM_FAILED"}), "Mã không hợp lệ hoặc đã dùng", "failed")
	eq(GuildModel.gift_error({"ok": false, "status": 400, "code": "BAD_REQUEST"}), "Mã không hợp lệ hoặc đã dùng", "bad code")
	var tiles := GuildModel.gift_tiles({"code": "Launch_2026", "rewardCoin": 75, "rewardGem": 4, "rewardItems": [{"itemId": "medkit", "quantity": 2}]})
	eq(tiles.size(), 3, "three tiles")
	var by := {}
	for t in tiles:
		by[t["kind"]] = t
	eq(by["coin"]["qty"], 75, "coins")
	eq([by["gem"]["qty"], by["gem"]["locked"]], [4, true], "locked gems")
	eq([by["item"]["id"], by["item"]["qty"]], ["medkit", 2], "item")
	eq(GuildModel.gift_tiles({"rewardCoin": 0, "rewardGem": 0, "rewardItems": []}), [], "nothing")


func test_match_progress_and_result_tile() -> void:
	eq(GuildModel.parse_progress({"guildId": "g", "expGained": 100, "questProgress": 5, "dungeonCompleted": true}),
		{"guild_id": "g", "exp": 100, "quest": 5, "dungeon_done": true}, "progress")
	eq(GuildModel.parse_progress(null), {}, "none")
	var r := ResultModel.reward({"expGained": 30, "coinGained": 10, "guild": {"guildId": "g", "expGained": 200, "questProgress": 2, "dungeonCompleted": true}}, "boss:steel_robot")
	eq(r["guild"]["exp"], 200, "reward guild")
	var tile := ResultModel.guild_tile(r)
	eq([tile["kind"], tile["id"], tile["qty"], tile["done"]], ["guild", "g", 200, true], "guild tile")
	eq(ResultModel.reward_tiles(r).back()["kind"], "guild", "last tile")
	eq(ResultModel.guild_tile(ResultModel.reward({"expGained": 30, "guild": {"guildId": "g", "expGained": 0, "questProgress": 1}}, "")), {}, "no exp, no dungeon: no tile")
	eq(ResultModel.guild_tile(ResultModel.reward({"expGained": 30}, "")), {}, "no guild")
	eq(RewardStrip.count_text(tile), "+200", "count")
	var icon := RewardStrip.tile_icon(tile, 64)
	check(icon.get_node_or_null("DungeonDone") != null, "dungeon cleared mark")
	eq(RewardModel.name_of(tile), "EXP bang hội", "tooltip")
	icon.free()
	var empty := ResultModel.reward({"guild": {"guildId": "g", "expGained": 100}}, "")
	eq(empty["empty"], false, "a guild EXP alone is a reward")


func test_match_bonus_popup() -> void:
	var p := {"playerId": "p", "displayName": "Sấm", "characterId": "rookie", "guild": {"guildId": "g", "level": 5, "hpPercent": 5, "defensePercent": 5}}
	eq(GuildModel.match_bonus(p), {"guild_id": "g", "level": 5, "hp_percent": 5, "defense_percent": 5}, "bonus")
	eq(GuildModel.bonus_icons(GuildModel.match_bonus(p)), [{"stat": "hp", "percent": 5}, {"stat": "defense", "percent": 5}], "icons")
	eq(GuildModel.match_bonus({"playerId": "bot"}), {}, "bot")
	var host := Control.new()
	var popup = PlayerInfoPopup.new()
	popup.open_for(host, p)
	var skills: Node = popup.find_child("GuildSkills", true, false)
	check(skills != null and skills.get_child_count() == 2, "two skill chips")
	var plain = PlayerInfoPopup.new()
	plain.open_for(host, {"playerId": "bot", "displayName": "Bot"})
	check(plain.find_child("Guild", true, false) == null, "no guild block")
	host.free()


func test_skill_chip_locked() -> void:
	var chip := GuildUi.skill_chip({"stat": "defense", "percent": 5, "level": 5, "unlocked": false})
	var texts: Array = []
	for c in chip.find_children("*", "Label", true, false):
		texts.append(c.text)
	check(texts.has("+5%") and texts.has("Lv.5"), "percent and level: %s" % [texts])
	chip.free()


func test_glyphs() -> void:
	for k in GuildGlyphs.KINDS:
		var g := GuildGlyphs.make(k, 48)
		eq(g.custom_minimum_size, Vector2(48, 48), k)
		g.free()
	eq(GuildGlyphs.crest_color("abc"), GuildGlyphs.crest_color("abc"), "stable colour")
	eq(GuildGlyphs.crest_color(""), GuildGlyphs.CREST_COLORS[1], "default colour")


func test_button_dot() -> void:
	check(GuildButton.dot_shown(false, 2), "invites, no guild")
	check(not GuildButton.dot_shown(true, 2), "in a guild")
	check(not GuildButton.dot_shown(false, 0), "no invites")


func test_invite_rows_skip_members() -> void:
	var g := GuildModel.parse_guild(_guild())
	var rows := GuildInvitePopup.rows([{"playerId": "a1"}, {"playerId": "x9"}, {"playerId": "c3"}], g)
	eq(rows, [{"playerId": "x9"}], "only outsiders")


## The page's views from GuildState: loading, not in a guild (create | invites), in one.
func test_page_views() -> void:
	var saved_guild: Dictionary = GuildState.guild
	var saved_known: bool = GuildState.known
	var saved_invites: Array = GuildState.invites
	var saved_player: String = GuildState._player
	var saved_activity: Dictionary = GuildState.activity
	GuildState._player = Session.player_id
	GuildState.known = false
	var page = GuildPage.new()
	page._ready()
	page._render_guild()
	check(page.find_child("JoinView", true, false) == null and page.find_child("MemberView", true, false) == null, "loading")
	GuildState.known = true
	GuildState.guild = {}
	GuildState.invites = [{"guild_id": "g1", "name": "Rồng Lửa"}]
	page._render_guild()
	check(page.find_child("CreatePanel", true, false) != null, "create panel")
	check(page.find_child("Invite_g1", true, false) != null, "invite row")
	var cost: Node = page.find_child("Cost", true, false)
	var cost_texts: Array = cost.find_children("*", "Label", true, false).map(func(l): return l.text)
	eq(cost_texts, ["1.000"], "the cost from the game data")
	var raw := _guild()
	raw["members"][0]["playerId"] = Session.player_id
	GuildState.guild = GuildModel.parse_guild(raw)
	GuildState.activity = GuildModel.parse_activity({"quest": {"progress": 2, "target": 5, "rewardExp": 100}, "dungeon": null})
	page._render_guild()
	check(page.find_child("MemberView", true, false) != null, "member view")
	check(page.find_child("InviteButton", true, false) != null, "leader invites")
	check(page.find_child("OpenDungeon", true, false) != null, "leader opens the dungeon")
	eq(page.find_child("LeaveButton", true, false).find_children("*", "Label", true, false)[0].text, "Giải tán", "leader disbands")
	check(page.find_child("Skill_hp_1", true, false) != null and page.find_child("Skill_defense_5", true, false) != null, "skills")
	raw["members"][0]["role"] = "member"
	raw["members"][1]["role"] = "leader"
	GuildState.guild = GuildModel.parse_guild(raw)
	GuildState.activity = GuildModel.parse_activity({"quest": {"progress": 5, "target": 5, "rewardExp": 100, "awarded": true},
		"dungeon": {"id": "d", "bossId": "steel_robot", "queue": "boss:steel_robot", "rewardExp": 200, "completedMatchId": null}})
	page._render_guild()
	check(page.find_child("InviteButton", true, false) == null, "a member does not invite")
	check(page.find_child("PlayDungeon", true, false) != null, "anyone plays the open dungeon")
	var queues: Array = []
	page.play_queue.connect(func(q: String) -> void: queues.append(q))
	page.find_child("PlayDungeon", true, false).pressed.emit()
	eq(queues, ["boss:steel_robot"], "the returned queue")
	page.free()
	GuildState.guild = saved_guild
	GuildState.known = saved_known
	GuildState.invites = saved_invites
	GuildState._player = saved_player
	GuildState.activity = saved_activity


func test_gift_popup_builds() -> void:
	var host := Control.new()
	var popup = GiftCodePopup.new()
	popup.open_for(host)
	eq(popup.input.max_length, GuildModel.GIFT_MAX, "capped field")
	eq(popup.redeem.text, "Nhận", "button")
	host.free()
