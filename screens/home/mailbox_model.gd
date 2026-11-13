extends RefCounted
## The mailbox ("Hòm thư") without UI. GET /mail → {mails: [{mailId, kind: "season_reward" |
## "admin", title, body, meta, rewards: {coin, gem, items: [RewardItem]}, createdAt, expiresAt,
## readAt, claimedAt}], unclaimedCount}; a season_reward mail's meta = {seasonId, seasonName,
## grade, division, rankPos, rankPoints}. parse() keeps the mails newest first; a mail is
## claimable while it has rewards, is not claimed and has not expired. The gem of a mail is locked
## gem (kim cương khoá), like a season reward's. POST /mail/claim → {mail, granted, wallet},
## POST /mail/claim-all → {claimed: [ids], granted, wallet} (wallet: SeasonRewardModel.wallet_of).

const SeasonRewardModel := preload("res://screens/ranked/season_reward_model.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const Fmt := preload("res://core/fmt.gd")

const SEASON := "season_reward"
const ADMIN := "admin"


static func _num(v: Variant) -> int:
	return int(v) if v is int or v is float else 0


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


## {coin, gem, items: [{kind, id, level, qty, name}]} from a rewards / granted object.
static func parse_rewards(r: Variant) -> Dictionary:
	if not r is Dictionary:
		return {"coin": 0, "gem": 0, "items": []}
	return {"coin": maxi(_num(r.get("coin")), 0), "gem": maxi(_num(r.get("gem")), 0),
		"items": SeasonRewardModel.parse_items(r.get("items"))}


## One mail object → its fields (rewards parsed, meta a Dictionary, timestamps "" when null);
## {} without a mailId.
static func parse_one(m: Variant) -> Dictionary:
	if not m is Dictionary or _str(m.get("mailId")) == "":
		return {}
	var meta: Dictionary = m["meta"] if m.get("meta") is Dictionary else {}
	return {"mailId": _str(m["mailId"]), "kind": _str(m.get("kind")), "title": _str(m.get("title")),
		"body": _str(m.get("body")), "meta": meta, "rewards": parse_rewards(m.get("rewards")),
		"createdAt": _str(m.get("createdAt")), "expiresAt": _str(m.get("expiresAt")),
		"readAt": _str(m.get("readAt")), "claimedAt": _str(m.get("claimedAt"))}


## GET /mail data → the mails (parse_one()), newest first; [] for anything else.
static func parse(data: Variant) -> Array:
	var out: Array = []
	if data is Dictionary and data.get("mails") is Array:
		for m in data["mails"]:
			var one := parse_one(m)
			if not one.is_empty():
				out.append(one)
	return sort_newest(out)


## The mails newest first (createdAt; an unreadable time last), the server's order among equals.
static func sort_newest(mails: Array) -> Array:
	var keyed: Array = []
	for i in mails.size():
		keyed.append([Fmt.unix_time(str(mails[i].get("createdAt", ""))), i, mails[i]])
	keyed.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	return keyed.map(func(k): return k[2])


static func has_rewards(m: Dictionary) -> bool:
	var r: Dictionary = m.get("rewards", {})
	return int(r.get("coin", 0)) > 0 or int(r.get("gem", 0)) > 0 or not (r.get("items", []) as Array).is_empty()


static func is_claimed(m: Dictionary) -> bool:
	return str(m.get("claimedAt", "")) != ""


static func is_read(m: Dictionary) -> bool:
	return str(m.get("readAt", "")) != "" or is_claimed(m)


## expiresAt has passed at `now` (unix seconds); a mail without one never expires.
static func is_expired(m: Dictionary, now: int) -> bool:
	var at := Fmt.unix_time(str(m.get("expiresAt", "")))
	return at >= 0 and now >= at


static func is_claimable(m: Dictionary, now: int) -> bool:
	return has_rewards(m) and not is_claimed(m) and not is_expired(m, now)


## The mails still to claim at `now`.
static func claimable(mails: Array, now: int) -> Array:
	return mails.filter(func(m): return is_claimable(m, now))


## How many mails want a look (the lobby badge): the ones to claim plus the unread ones without
## rewards (an expired mail never counts).
static func attention(mails: Array, now: int) -> int:
	var n := 0
	for m in mails:
		if is_claimable(m, now) or (not has_rewards(m) and not is_read(m) and not is_expired(m, now)):
			n += 1
	return n


## The mail after a claim answer: the answer's mail when it has one, else `m` claimed at `at`.
static func claimed(m: Dictionary, answer: Variant, at: String) -> Dictionary:
	if answer is Dictionary:
		var fresh := parse_one(answer.get("mail"))
		if not fresh.is_empty():
			if fresh["claimedAt"] == "":
				fresh["claimedAt"] = at
			return fresh
	var out := m.duplicate(true)
	out["claimedAt"] = at
	if out["readAt"] == "":
		out["readAt"] = at
	return out


## The mailIds a claim-all answer claimed.
static func claimed_ids(data: Variant) -> Array:
	var out: Array = []
	if data is Dictionary and data.get("claimed") is Array:
		for id in data["claimed"]:
			if id is String and id != "":
				out.append(id)
	return out


## What a claim answer granted (its `granted`), else `fallback` (the mail's rewards).
static func granted(data: Variant, fallback: Dictionary) -> Dictionary:
	if data is Dictionary and data.get("granted") is Dictionary:
		return parse_rewards(data["granted"])
	return fallback


## RewardModel tiles of a rewards object (coin, locked gem, stones, chests, items).
static func tiles(rewards: Dictionary) -> Array:
	return RewardModel.from_season(rewards)


## The row's picture: "grade" (a season reward with a grade: its insignia) or "mail" (an envelope).
static func icon_kind(m: Dictionary) -> String:
	if str(m.get("kind", "")) == SEASON and str((m.get("meta", {}) as Dictionary).get("grade", "")) != "":
		return "grade"
	return "mail"


## A season reward's grade and division (meta), for its insignia.
static func grade_of(m: Dictionary) -> Array:
	var meta: Dictionary = m.get("meta", {})
	return [_str(meta.get("grade")), _num(meta.get("division"))]


## The row's short title: the mail's own, else "Thưởng Mùa 1" / "Thư".
static func short_title(m: Dictionary) -> String:
	if str(m.get("title", "")) != "":
		return str(m["title"])
	if str(m.get("kind", "")) == SEASON:
		var season := _str((m.get("meta", {}) as Dictionary).get("seasonName"))
		return "Thưởng %s" % season if season != "" else "Thưởng mùa"
	return "Thư"


## A season reward's final standing "Hạng #3 · 4.230 điểm" (meta); "" for another mail.
static func standing_text(m: Dictionary) -> String:
	if str(m.get("kind", "")) != SEASON:
		return ""
	var meta: Dictionary = m.get("meta", {})
	return SeasonRewardModel.standing_text({"rankPos": _num(meta.get("rankPos")), "rankPoints": maxi(_num(meta.get("rankPoints")), 0)})


## A season reward's grade name ("Thượng tướng", "Trung sĩ 2"); "" otherwise.
static func grade_text(m: Dictionary) -> String:
	if icon_kind(m) != "grade":
		return ""
	var g := grade_of(m)
	return RankModel.label(g[0], g[1])
