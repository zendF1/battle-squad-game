extends RefCounted
## Ranked ("Xếp hạng") without UI: tier names and division numerals, a rating's tier and
## division (the server's getTierAndDivision, used only when a field is missing), the Home chip
## and popup texts from GET /rank/me, the ranked line of a match result (MatchEnded.rewards[me])
## with its promotion / demotion, the matchmaking timer and the tips shown while searching.

const Fmt := preload("res://core/fmt.gd")

## Lowest first (the server's compareTiers order).
const TIERS := ["bronze", "silver", "gold", "platinum", "diamond", "master"]
const TIER_NAMES := {"bronze": "Đồng", "silver": "Bạc", "gold": "Vàng", "platinum": "Bạch kim",
	"diamond": "Kim cương", "master": "Cao thủ"}
const NUMERALS := ["", "I", "II", "III"]
## A player with no player_ranks row (the server's elo DefaultRating).
const DEFAULT_RATING := 1000
const RANKED_MODE := "ranked_2v2"

const UP := 1
const SAME := 0
const DOWN := -1

const TIPS := [
	"Gió mạnh đẩy đạn rất xa: nhìn mũi tên gió trước khi bắn.",
	"Bom liên hoàn của Tanko đào hố sâu, địch trúng bị cầm chân lượt sau.",
	"Tia laze của Spark xuyên địa hình và làm choáng mọi địch trên đường bắn.",
	"Hoa hồi xuân của Flora hồi máu cả đội và giải mọi hiệu ứng xấu.",
	"Mưa tên lửa của Rookie làm địch bỏng, mất máu đầu lượt sau.",
	"Bắn vào chân địch: hố sâu làm chúng rơi xuống và mất máu.",
	"Bom băng đóng băng địch một lượt, cả đội tha hồ dồn sát thương.",
	"Dịch chuyển giúp thoát khỏi hố sâu hoặc chiếm chỗ cao.",
	"Bị địch bắn trúng cũng nạp thêm năng lượng kỹ năng.",
	"Thắng trận xếp hạng để lên điểm, thua sẽ bị trừ điểm.",
	"Rời trận giữa chừng tính là thua, kể cả khi đồng đội thắng.",
	"Khiên chịu sát thương trước máu: máu hồi dư của Flora thành khiên.",
]


static func tier_index(tier: String) -> int:
	return TIERS.find(tier)


## "Bạc"; "" for an unknown tier.
static func tier_name(tier: String) -> String:
	return TIER_NAMES.get(tier, "")


## 3 → "III" (the lowest), 1 → "I" (the highest); "" outside 1..3.
static func numeral(division: int) -> String:
	return NUMERALS[division] if division >= 1 and division <= 3 else ""


## "Bạc II"; master has no division ("Cao thủ"); "Chưa xếp hạng" for an unknown tier.
static func label(tier: String, division: int) -> String:
	var n := tier_name(tier)
	if n == "":
		return "Chưa xếp hạng"
	if tier == "master" or numeral(division) == "":
		return n
	return "%s %s" % [n, numeral(division)]


## The tier and division of a rating, as the server computes them: [tier, division].
static func of_rating(rating: int) -> Array:
	if rating < 1000:
		return ["bronze", maxi(1, 3 - maxi(rating, 0) / 333)]
	if rating < 1200:
		return ["silver", maxi(1, 3 - (rating - 1000) / 66)]
	if rating < 1500:
		return ["gold", maxi(1, 3 - (rating - 1200) / 100)]
	if rating < 1800:
		return ["platinum", maxi(1, 3 - (rating - 1500) / 100)]
	if rating < 2200:
		return ["diamond", maxi(1, 3 - (rating - 1800) / 133)]
	return ["master", 1]


## UP when b is a higher rank than a (tier first, then division: 1 is the highest), DOWN when
## lower, SAME otherwise. Ranks are [tier, division].
static func compare(a: Array, b: Array) -> int:
	var ta := tier_index(str(a[0]))
	var tb := tier_index(str(b[0]))
	if ta != tb:
		return UP if tb > ta else DOWN
	if str(a[0]) == "master":
		return SAME
	var da := int(a[1])
	var db := int(b[1])
	if da == db:
		return SAME
	return UP if db < da else DOWN


static func _num(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback


static func _str(v: Variant) -> String:
	return str(v) if v is String else ""


## A rank from a GET /rank/me data: {rating, tier, division, wins, losses, draws, rankPos,
## season: {name, endsAt}}; the server's defaults (silver III at 1000) for missing parts.
static func from_me(data: Variant) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	var rating := _num(d.get("rating"), DEFAULT_RATING)
	var fallback := of_rating(rating)
	var tier := _str(d.get("tier"))
	if tier_index(tier) < 0:
		tier = fallback[0]
	var division := _num(d.get("division"), 0)
	if division < 1 or division > 3:
		division = fallback[1] if tier == fallback[0] else 3
	var season: Dictionary = d["season"] if d.get("season") is Dictionary else {}
	return {"rating": rating, "tier": tier, "division": division, "wins": _num(d.get("wins"), 0),
		"losses": _num(d.get("losses"), 0), "draws": _num(d.get("draws"), 0), "rankPos": _num(d.get("rankPos"), 0),
		"season": {"name": _str(season.get("name")), "endsAt": _str(season.get("endsAt"))}}


## "1.050 điểm".
static func points_text(rating: int) -> String:
	return "%s điểm" % Fmt.thousands(rating)


## The mode card's line: "Bạc II · 1.050 điểm".
static func mode_line(rank: Dictionary) -> String:
	return "%s · %s" % [label(rank["tier"], rank["division"]), points_text(rank["rating"])]


## "Hạng #12" in the season's leaderboard, "Chưa có thứ hạng" without a position.
static func position_text(pos: int) -> String:
	return "Hạng #%s" % Fmt.thousands(pos) if pos > 0 else "Chưa có thứ hạng"


## "Thắng 12 · Thua 8" (" · Hoà 1" when there are draws).
static func record_text(rank: Dictionary) -> String:
	var out := "Thắng %d · Thua %d" % [rank["wins"], rank["losses"]]
	if int(rank["draws"]) > 0:
		out += " · Hoà %d" % rank["draws"]
	return out


## "Mùa 1 · Kết thúc 30/11" (the date in the zone bias_minutes east of UTC); the name alone
## without an end date, "Mùa giải hiện tại" without a name.
static func season_text(rank: Dictionary, bias_minutes: int) -> String:
	var season: Dictionary = rank["season"]
	var season_name: String = season["name"] if season["name"] != "" else "Mùa giải hiện tại"
	var date := Fmt.short_date(season["endsAt"], bias_minutes)
	if date == "":
		return season_name
	return "%s · Kết thúc %s" % [season_name, date.substr(0, 5)]


## The ranked part of a match result for a reward (MatchEnded.rewards[me]) of a match in `mode`;
## {} when the match is not ranked or the reward carries no rating. Else {old, new, change,
## old_rank: [tier, division], new_rank, move: UP / SAME / DOWN}; missing old fields come from
## newRating - ratingChange, missing tiers from the ratings.
static func result_of(mode: String, reward: Variant) -> Dictionary:
	if mode != RANKED_MODE or not reward is Dictionary:
		return {}
	var new_rating = reward.get("newRating")
	if not (new_rating is int or new_rating is float):
		return {}
	var nr := int(new_rating)
	var change := _num(reward.get("ratingChange"), 0)
	var old := _num(reward.get("oldRating"), nr - change)
	if reward.has("ratingChange") == false:
		change = nr - old
	var new_rank := _rank_of(reward, "newTier", "newDivision", nr)
	var old_rank := _rank_of(reward, "oldTier", "oldDivision", old)
	return {"old": old, "new": nr, "change": change, "old_rank": old_rank, "new_rank": new_rank,
		"move": compare(old_rank, new_rank)}


static func _rank_of(d: Dictionary, tier_key: String, div_key: String, rating: int) -> Array:
	var tier := _str(d.get(tier_key))
	var fallback := of_rating(rating)
	if tier_index(tier) < 0:
		return fallback
	var div := _num(d.get(div_key), 0)
	if div < 1 or div > 3:
		div = fallback[1] if tier == fallback[0] else 3
	return [tier, div]


## "Điểm hạng 1.050 → 1.068 (+18)"; at `shown` (the count-up's current value) instead of the
## new rating while it counts.
static func rating_line(result: Dictionary, shown: int = -1) -> String:
	var value: int = result["new"] if shown < 0 else shown
	return "Điểm hạng %s → %s (%s)" % [Fmt.thousands(result["old"]), Fmt.thousands(value), change_text(result["change"])]


## +18 → "+18", -12 → "-12", 0 → "±0".
static func change_text(change: int) -> String:
	return "±0" if change == 0 else Fmt.signed(change)


## "Thăng hạng!" / "Rớt hạng" / "" for the result's move.
static func move_text(move: int) -> String:
	match move:
		UP: return "Thăng hạng!"
		DOWN: return "Rớt hạng"
	return ""


## Matchmaking elapsed time: 31 → "0:31", 65 → "1:05", 600 → "10:00".
static func timer_text(seconds: int) -> String:
	var s := maxi(seconds, 0)
	return "%d:%02d" % [s / 60, s % 60]


## The tip at `index`, wrapping around.
static func tip(index: int) -> String:
	return TIPS[posmod(index, TIPS.size())]
