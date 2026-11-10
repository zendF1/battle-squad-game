extends RefCounted
## The guild (Bang hội) and the gift code without UI (contracts guilds.md, giftcode.md): the
## server's answers parsed into flat dictionaries, what each role may do to whom, the EXP bar,
## the guild skills from the game data (GameData.guild_rules(): every number is the server's),
## the name rule, the Vietnamese error texts and the gift code's reward tiles. Pure and static:
## autoload/guild_state.gd does the network part, screens/guild/guild_page.gd the drawing.

const GameData := preload("res://autoload/game_data_model.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const Fmt := preload("res://core/fmt.gd")

const LEADER := "leader"
const DEPUTY := "deputy"
const MEMBER := "member"
const ROLES := [LEADER, DEPUTY, MEMBER]
const ROLE_NAMES := {LEADER: "Bang chủ", DEPUTY: "Phó bang", MEMBER: "Thành viên"}

## What a roster row offers (member_actions()), in the order of the member popup's buttons.
const PROMOTE := "promote"
const DEMOTE := "demote"
const TRANSFER := "transfer"
const KICK := "kick"
const ACTION_NAMES := {PROMOTE: "Lên phó bang", DEMOTE: "Xuống thành viên", TRANSFER: "Nhường bang chủ", KICK: "Trục xuất"}

## The gift code: the server's syntax (1–50 of A-Z a-z 0-9 _ -) is checked there; the field caps.
const GIFT_MAX := 50
const GIFT_FAILED := "Mã không hợp lệ hoặc đã dùng"

const ERRORS := {
	"GUILD_CONFLICT": "Tên bang hội đã có người dùng",
	"GUILD_ALREADY_MEMBER": "Bạn đã ở trong một bang hội",
	"GUILD_FULL": "Bang hội đã đủ người",
	"GUILD_DEPUTY_LIMIT": "Đã đủ số phó bang",
	"GUILD_DUNGEON_ALREADY_OPEN": "Hôm nay đã mở phó bản khác",
	"AUTH_FORBIDDEN": "Bạn không có quyền làm việc này",
	"NOT_FOUND": "Bang hội hoặc người chơi không còn",
	"BAD_REQUEST": "Yêu cầu không hợp lệ",
	"BUSY": "Đang xử lý, chờ chút",
}


static func _num(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


# ── Parsing ─────────────────────────────────────────────────────────────────

## A Guild object (POST /guilds, GET /guilds/me, /guilds/{id}, a rankings entry) → {id, name, exp,
## level, hp_percent, defense_percent, member_count, max_members, leader_name, members: [member()]};
## {} when it is not one (no id).
static func parse_guild(d: Variant) -> Dictionary:
	if not d is Dictionary or _str(d.get("id")) == "":
		return {}
	var members: Array = []
	if d.get("members") is Array:
		for m in d["members"]:
			var pm := parse_member(m)
			if not pm.is_empty():
				members.append(pm)
	var count := _num(d.get("memberCount"))
	if count <= 0:
		count = members.size()
	return {"id": _str(d["id"]), "name": _str(d.get("name")), "exp": _num(d.get("exp")), "level": maxi(1, _num(d.get("level"))),
		"hp_percent": _num(d.get("hpPercent")), "defense_percent": _num(d.get("defensePercent")),
		"member_count": count, "max_members": _num(d.get("maxMembers")), "leader_name": _str(d.get("leaderName")),
		"members": members}


## A roster entry → {player_id, role, name, level, character, power}; {} without a player id.
static func parse_member(m: Variant) -> Dictionary:
	if not m is Dictionary or _str(m.get("playerId")) == "":
		return {}
	var role := _str(m.get("role"))
	return {"player_id": _str(m["playerId"]), "role": role if ROLES.has(role) else MEMBER, "name": _str(m.get("displayName")),
		"level": _num(m.get("level")), "character": _str(m.get("characterId")), "power": _num(m.get("power")) if m.has("power") else -1}


## GET /guilds/rankings (an array of Guild summaries, best first) → [parse_guild() + pos].
static func parse_rankings(d: Variant) -> Array:
	var out: Array = []
	if d is Array:
		for e in d:
			var g := parse_guild(e)
			if not g.is_empty():
				g["pos"] = out.size() + 1
				out.append(g)
	return out


## GET /guilds/invites → [{guild_id, name}].
static func parse_invites(d: Variant) -> Array:
	var out: Array = []
	if d is Array:
		for e in d:
			if e is Dictionary and _str(e.get("guildId")) != "":
				out.append({"guild_id": _str(e["guildId"]), "name": _str(e.get("name"))})
	return out


## GET /guilds/{id}/activity → {quest: {progress, target, reward_exp, awarded}, dungeon: dungeon()
## ({} none open today)}.
static func parse_activity(d: Variant) -> Dictionary:
	if not d is Dictionary:
		return {}
	var q: Dictionary = d.get("quest") if d.get("quest") is Dictionary else {}
	return {"quest": {"progress": _num(q.get("progress")), "target": _num(q.get("target")), "reward_exp": _num(q.get("rewardExp")),
		"awarded": q.get("awarded") is bool and q["awarded"]}, "dungeon": parse_dungeon(d.get("dungeon"))}


## A dungeon (activity's, POST /guilds/{id}/dungeon) → {id, boss_id, queue, reward_exp, done}; {} none.
static func parse_dungeon(d: Variant) -> Dictionary:
	if not d is Dictionary or _str(d.get("bossId")) == "":
		return {}
	return {"id": _str(d.get("id")), "boss_id": _str(d["bossId"]), "queue": _str(d.get("queue")),
		"reward_exp": _num(d.get("rewardExp")), "done": _str(d.get("completedMatchId")) != ""}


## MatchEnded rewards[me].guild → {guild_id, exp, quest, dungeon_done}; {} none.
static func parse_progress(d: Variant) -> Dictionary:
	if not d is Dictionary or _str(d.get("guildId")) == "":
		return {}
	return {"guild_id": _str(d["guildId"]), "exp": maxi(0, _num(d.get("expGained"))), "quest": _num(d.get("questProgress")),
		"dungeon_done": d.get("dungeonCompleted") is bool and d["dungeonCompleted"]}


## A match player's guild bonus (BattlePlayerState.guild) → {guild_id, level, hp_percent,
## defense_percent}; {} without one.
static func match_bonus(player: Dictionary) -> Dictionary:
	var g = player.get("guild")
	if not g is Dictionary or _str(g.get("guildId")) == "":
		return {}
	return {"guild_id": _str(g["guildId"]), "level": maxi(1, _num(g.get("level"))), "hp_percent": _num(g.get("hpPercent")),
		"defense_percent": _num(g.get("defensePercent"))}


# ── Roles ───────────────────────────────────────────────────────────────────

## My role in `guild` ("" not a member).
static func role_of(guild: Dictionary, player_id: String) -> String:
	for m in guild.get("members", []):
		if m["player_id"] == player_id:
			return m["role"]
	return ""


## Leader and deputy invite and open the dungeon.
static func can_manage(role: String) -> bool:
	return role == LEADER or role == DEPUTY


## What I (`my_role`) may do to a roster member (`target_role`), the contract's permissions:
## the leader promotes a member, demotes a deputy, transfers to either and kicks either; a
## deputy kicks an ordinary member; nothing on myself or on the leader.
static func member_actions(my_role: String, target_role: String, is_me: bool) -> Array:
	if is_me or target_role == LEADER:
		return []
	match my_role:
		LEADER:
			var out: Array = [PROMOTE] if target_role == MEMBER else [DEMOTE]
			out.append_array([TRANSFER, KICK])
			return out
		DEPUTY:
			return [KICK] if target_role == MEMBER else []
	return []


## The leader leaves only by transfer or disband: the leader's button disbands, everyone else's leaves.
static func leaves_by_disband(my_role: String) -> bool:
	return my_role == LEADER


## The deputies in a roster.
static func deputy_count(guild: Dictionary) -> int:
	return guild.get("members", []).filter(func(m): return m["role"] == DEPUTY).size()


# ── Level, EXP, skills ──────────────────────────────────────────────────────

## The EXP bar inside the guild's level: {ratio 0..1, text "200/1000"} (exp_per_level from the game
## data; the level is the server's).
static func exp_bar(exp: int, level: int, exp_per_level: int) -> Dictionary:
	if exp_per_level <= 0:
		return {"ratio": 0.0, "text": Fmt.thousands(exp)}
	var into := clampi(exp - (maxi(level, 1) - 1) * exp_per_level, 0, exp_per_level)
	return {"ratio": float(into) / exp_per_level, "text": "%s/%s" % [Fmt.thousands(into), Fmt.thousands(exp_per_level)]}


## The guild skills as pictures: one per stat a skill entry adds, in level order: [{stat: "hp" |
## "defense", percent, level, unlocked (guild_level reached it)}].
static func skill_icons(skills: Array, guild_level: int) -> Array:
	var out: Array = []
	for s in skills:
		for stat in ["hp", "defense"]:
			var pct := int(s.get(stat + "_percent", 0))
			if pct > 0:
				out.append({"stat": stat, "percent": pct, "level": int(s["level"]), "unlocked": guild_level >= int(s["level"])})
	return out


## The match bonus as pictures (the server's summed hpPercent / defensePercent): [{stat, percent}].
static func bonus_icons(bonus: Dictionary) -> Array:
	var out: Array = []
	if int(bonus.get("hp_percent", 0)) > 0:
		out.append({"stat": "hp", "percent": int(bonus["hp_percent"])})
	if int(bonus.get("defense_percent", 0)) > 0:
		out.append({"stat": "defense", "percent": int(bonus["defense_percent"])})
	return out


## "+5%".
static func percent_text(pct: int) -> String:
	return "+%d%%" % pct


## The quest bar: {ratio, text "3/5", done}.
static func quest_bar(quest: Dictionary) -> Dictionary:
	var target := int(quest.get("target", 0))
	var progress := mini(int(quest.get("progress", 0)), target) if target > 0 else int(quest.get("progress", 0))
	return {"ratio": float(progress) / target if target > 0 else 0.0, "text": "%d/%d" % [progress, target],
		"done": quest.get("awarded", false) or (target > 0 and progress >= target)}


## "Thành viên" count "12/50" (max from the guild, else the game data).
static func members_text(guild: Dictionary, rules_max: int) -> String:
	var mx := int(guild.get("max_members", 0))
	if mx <= 0:
		mx = rules_max
	return "%d/%d" % [int(guild.get("member_count", 0)), mx] if mx > 0 else str(int(guild.get("member_count", 0)))


# ── Name, errors ────────────────────────────────────────────────────────────

## The problem with a guild name before it is sent (trimmed like the server, the game data's
## length rule), or "".
static func name_problem(raw: String, name_min: int, name_max: int) -> String:
	var name := raw.strip_edges()
	if name == "":
		return "Hãy đặt tên bang hội"
	if name_min > 0 and name.length() < name_min:
		return "Tên bang hội từ %d ký tự" % name_min
	if name_max > 0 and name.length() > name_max:
		return "Tên bang hội tối đa %d ký tự" % name_max
	return ""


## A guild call that failed. action: the call ("create", "accept", "invite", ...: GUILD_CONFLICT
## is the name on create, another guild's membership on accept); currency: the create cost's
## (insufficient funds names it).
static func error_text(res: Dictionary, action: String = "", currency: String = "") -> String:
	var code := str(res.get("code", ""))
	if code == "BUSY":
		return ERRORS[code]
	if int(res.get("status", 0)) == 0:
		return ErrorText.OFFLINE
	if code.ends_with("INSUFFICIENT_BALANCE"):
		return "Không đủ xu" if currency == "coin" else "Không đủ kim cương"
	if code == "GUILD_CONFLICT" and action != "create":
		return "Đã ở trong một bang hội khác"
	if code == "AUTH_FORBIDDEN" and action == "accept":
		return "Lời mời đã hết hạn"
	return ERRORS.get(code, "Thao tác thất bại: %s" % res.get("message", ""))


## Insufficient funds (the create button then opens the shop).
static func is_insufficient(res: Dictionary) -> bool:
	return str(res.get("code", "")).ends_with("INSUFFICIENT_BALANCE")


# ── Gift code ───────────────────────────────────────────────────────────────

## The code as typed, never trimmed nor case-changed (the server checks it exactly); "" when
## there is nothing to send.
static func gift_code(raw: String) -> String:
	return raw.left(GIFT_MAX) if raw.strip_edges() != "" else ""


## POST /giftcode/redeem failure.
static func gift_error(res: Dictionary) -> String:
	if int(res.get("status", 0)) == 0:
		return ErrorText.OFFLINE
	match str(res.get("code", "")):
		"GIFT_CODE_REDEEM_FAILED", "BAD_REQUEST":
			return GIFT_FAILED
	return "Nhận quà thất bại, hãy thử lại"


## POST /giftcode/redeem data → the reward reveal's tiles: the coins, the locked gems (rewardGem
## credits locked gem), the items.
static func gift_tiles(d: Variant) -> Array:
	if not d is Dictionary:
		return []
	var out: Array = [RewardModel.tile("coin", "coin", _num(d.get("rewardCoin"))), RewardModel.tile("gem", "gem", _num(d.get("rewardGem")), 0, 0, true)]
	if d.get("rewardItems") is Array:
		for it in d["rewardItems"]:
			if it is Dictionary and _str(it.get("itemId")) != "":
				out.append(RewardModel.tile("item", _str(it["itemId"]), _num(it.get("quantity"))))
	return RewardModel.merge(out)
