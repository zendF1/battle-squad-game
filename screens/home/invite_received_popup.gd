extends "res://ui/modal.gd"
## A party invite to me (LobbyInvite through Router.party), shown over any Home page: the
## inviter's head, "<name> mời bạn chơi Đấu thường 2vs2" (the game data's name of the mode of the
## invite's queue),
## their level and rank, a bar running down over the invite's expiresInSec, "Đồng ý" / "Từ chối".
## accepted / declined tell Home; the bar running out (or InviteExpired) just closes it.

signal accepted
signal declined

const HeadIcon := preload("res://screens/home/head_icon.gd")
const TierBadge := preload("res://screens/ranked/tier_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")

var party # Router.party (screens/home/party.gd)
var bar: ProgressBar
var _done := false


## Opens over `host` for the invite (PartyModel.parse_invite()); mode_name: its mode's name.
func open_for(host: Node, p, invite: Dictionary, mode_name: String) -> void:
	party = p
	open(host, "Lời mời vào đội", 720)
	var from: Dictionary = invite.get("from", {})
	var who := str(from.get("displayName", ""))
	var row := Ui.hbox(18)
	body.add_child(row)
	row.add_child(HeadIcon.make(str(from.get("characterId", "")), who, 96))
	var col := Ui.vbox(6)
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var line := Ui.label("%s mời bạn chơi %s" % [who, mode_name], 28)
	line.name = "InviteLine"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(line)
	var rank_row := Ui.hbox(8)
	col.add_child(rank_row)
	var level := int(from.get("level", 0))
	if level > 0:
		rank_row.add_child(LobbyUi.text("Lv.%d" % level, 22, LobbyUi.GOLD, true))
	rank_row.add_child(TierBadge.make(str(from.get("tier", "")), int(from.get("division", 3)), 30))
	var rank := LobbyUi.text(RankModel.label(str(from.get("tier", "")), int(from.get("division", 3))), 22, Ui.TEXT_DIM)
	rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_row.add_child(rank)
	bar = Ui.bar(1.0, 14)
	bar.add_theme_stylebox_override("fill", LobbyUi.box(LobbyUi.GOLD, 7, 0))
	body.add_child(bar)
	add_button("Từ chối", _answer.bind(false))
	var yes := add_button("Đồng ý", _answer.bind(true))
	yes.name = "Accept"
	party.invite_closed.connect(_on_closed)
	_update()


func _answer(accept: bool) -> void:
	if _done:
		return
	_done = true
	if accept:
		accepted.emit()
	else:
		declined.emit()
	close()


func _on_closed() -> void:
	if not _done:
		_done = true
		close()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	if party == null or bar == null:
		return
	bar.value = party.model.incoming_ratio(party.now())
