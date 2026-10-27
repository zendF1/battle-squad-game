extends "res://ui/modal.gd"
## The reward of an ended season (one GET /rank/season-rewards row, SeasonRewardModel.parse_one),
## shown on Home under "Mùa giải đã kết thúc": "Phần thưởng Mùa 1: Trung sĩ 2" over the final grade's insignia (dead centre),
## "Hạng #3 · 4.230 điểm", one row per reward (coin, locked gem with its padlock, chests, stones,
## items), the badge note ("Huy hiệu và khung mùa này: <grade>") and "Nhận": POST
## /rank/season-rewards/claim (PlayerState.claim_season_reward: the wallet, chests and stones
## refresh); claimed emits `claimed` and closes, a refusal shows its message under the rows.

signal claimed(season_id: String)

const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const SeasonRewardModel := preload("res://screens/ranked/season_reward_model.gd")
const ChestIcon := preload("res://ui/chest_icon.gd")
const WalletPills := preload("res://ui/wallet_pills.gd")
const ErrorText := preload("res://screens/home/error_text.gd")
const Art := preload("res://ui/art.gd")

const BADGE := 150
const ICON := 48

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
	var lines := SeasonRewardModel.lines(r)
	var columns := Ui.hbox(40)
	columns.name = "Lines"
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(columns)
	var per_column := ceili(lines.size() / 2.0) if lines.size() > 3 else lines.size()
	var column: VBoxContainer = null
	for i in lines.size():
		if i % maxi(1, per_column) == 0:
			column = Ui.vbox(10)
			columns.add_child(column)
		var line: Dictionary = lines[i]
		var row := Ui.hbox(12)
		row.add_child(_icon(line))
		var l := LobbyUi.text(str(line["text"]), 24, Color.WHITE, true)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		column.add_child(row)
	var note := LobbyUi.text("Huy hiệu và khung mùa này: %s" % RankModel.grade_name(str(r["grade"])), 20, Color(0.85, 0.92, 1.0))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.visible = RankModel.grade_name(str(r["grade"])) != ""
	body.add_child(note)
	claim_button = add_button("Nhận", _claim)
	claim_button.name = "Claim"


static func _icon(line: Dictionary) -> Control:
	match str(line["kind"]):
		"coin":
			return LobbyUi.icon("coin", ICON)
		"gem":
			return WalletPills.locked_gem_icon(ICON)
		"chest":
			return ChestIcon.make(str(line["id"]), ICON)
		"stone":
			return LobbyUi.icon(Art.stone_icon(int(line["level"])), ICON)
	return LobbyUi.icon(Art.item_icon(str(line["id"])), ICON)


func _claim() -> void:
	set_busy(true)
	set_message("")
	var res: Dictionary = await PlayerState.claim_season_reward(str(reward["seasonId"]))
	if not is_inside_tree():
		return
	set_busy(false)
	if not res.ok and str(res.get("code", "")) != "SEASON_REWARD_ALREADY_CLAIMED":
		set_message(ErrorText.season_reward(res))
		return
	claimed.emit(str(reward["seasonId"]))
	close()
