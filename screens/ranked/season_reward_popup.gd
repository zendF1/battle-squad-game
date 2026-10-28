extends "res://ui/modal.gd"
## The reward of an ended season (one GET /rank/season-rewards row, SeasonRewardModel.parse_one),
## shown on Home under "Mùa giải đã kết thúc": "Phần thưởng Mùa 1: Trung sĩ 2" over the final grade's insignia (dead centre),
## "Hạng #3 · 4.230 điểm", the rewards as glowing tiles (ui/reward_strip.gd: coin, locked gem with
## its padlock, chests, stones, items; icon + ×N) and "Nhận": POST /rank/season-rewards/claim
## (PlayerState.claim_season_reward: the wallet, chests and stones refresh); claimed plays the
## reward reveal over the host (the next season's popup after it), emits `claimed` and closes, a
## refusal shows its message under the tiles.

signal claimed(season_id: String)

const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const SeasonRewardModel := preload("res://screens/ranked/season_reward_model.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const RewardReveal := preload("res://ui/reward_reveal.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

const BADGE := 150

var reward := {}
var claim_button: Button


## Opens over `host` for `r` (SeasonRewardModel.parse_one()).
func open_for(host: Node, r: Dictionary) -> void:
	reward = r
	open(host, "Mùa giải đã kết thúc", 680)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var head := LobbyUi.text(SeasonRewardModel.heading(r), 30, GradeBadge.text_color(str(r["grade"])), true)
	head.name = "Heading"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(head)
	var badge := GradeBadge.make(str(r["grade"]), int(r["division"]), BADGE)
	badge.size_flags_horizontal = SIZE_SHRINK_CENTER
	body.add_child(badge)
	var standing := LobbyUi.text(SeasonRewardModel.standing_text(r), 22, Ui.TEXT_DIM)
	standing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(standing)
	var tiles := RewardStrip.new()
	tiles.name = "Lines"
	tiles.max_rows = 2
	tiles.custom_minimum_size = Vector2(624, RewardStrip.TILE.y)
	body.add_child(tiles)
	tiles.size = Vector2(624, RewardStrip.TILE.y)
	tiles.set_tiles(RewardModel.from_season(r))
	claim_button = add_button("Nhận", _claim)
	claim_button.name = "Claim"


func _claim() -> void:
	set_busy(true)
	set_message("")
	var res: Dictionary = await PlayerState.claim_season_reward(str(reward["seasonId"]))
	if not is_inside_tree():
		return
	set_busy(false)
	if not res.ok and not str(res.get("code", "")) in ["SEASON_REWARD_ALREADY_CLAIMED", "SEASON_REWARD_NOT_FOUND"]:
		set_message(ErrorText.season_reward(res))
		return
	var host := get_parent()
	if res.ok and host is Control: # what it gave bursts out of a gift box; the next season's popup after it
		var reveal: Control = RewardReveal.open(host, RewardModel.from_season(reward))
		if host.has_method("show_season_reward"):
			reveal.collected.connect(func() -> void: host.call("show_season_reward"))
	claimed.emit(str(reward["seasonId"]))
	close()
