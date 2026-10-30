extends "res://ui/modal.gd"
## "Nhập mã quà" (Hồ sơ's gift box button; contract giftcode.md): the gift box over a code field
## (as typed: never trimmed nor case-changed, capped at GuildModel.GIFT_MAX) and "Nhận". POST
## /giftcode/redeem {code}; a success closes it and opens the one reward reveal (ui/reward_reveal.gd:
## the gift box bursts, the coins / locked gems / items fly out as icon + "×N") on `host`, then the
## wallet and the bag refresh (PlayerState.assets_changed()); GIFT_CODE_REDEEM_FAILED (and a bad
## code) shows "Mã không hợp lệ hoặc đã dùng" under the field.

const GuildModel := preload("res://screens/guild/guild_model.gd")
const RewardReveal := preload("res://ui/reward_reveal.gd")

var input: LineEdit
var redeem: Button
var _host: Node


func open_for(host: Node) -> void:
	_host = host
	open(host, "Nhập mã quà", 640)
	add_close_x()
	var box := LobbyUi.icon("milestone", 120)
	box.size_flags_horizontal = SIZE_SHRINK_CENTER
	body.add_child(box)
	input = LineEdit.new()
	input.name = "Code"
	input.max_length = GuildModel.GIFT_MAX
	input.placeholder_text = "Mã quà tặng"
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", 30)
	input.custom_minimum_size.y = 76
	body.add_child(input)
	redeem = add_button("Nhận", _redeem)
	redeem.name = "Redeem"
	input.text_submitted.connect(func(_t: String) -> void: _redeem())
	input.grab_focus.call_deferred()


func _redeem() -> void:
	var code := GuildModel.gift_code(input.text)
	if code == "" or _busy:
		return
	set_message("")
	set_busy(true)
	input.editable = false
	var res: Dictionary = await Api.post_json("/giftcode/redeem", {"code": code})
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	if res.ok:
		PlayerState.assets_changed()
		var tiles := GuildModel.gift_tiles(res.data)
		close()
		if not tiles.is_empty() and is_instance_valid(_host):
			RewardReveal.open(_host, tiles)
		return
	set_busy(false)
	input.editable = true
	set_message(GuildModel.gift_error(res))
