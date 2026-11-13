extends "res://tests/test_case.gd"
## The mailbox popup (screens/home/mailbox_popup.gd) over a fake REST client: the list (newest
## first, pictures and icons × N, no reward words), a row's detail (the insignia, the tiles, Nhận;
## marks it read) and the claim: instant, the icons fly (ui/reward_fly.gd), never the reveal.

const MailboxPopup := preload("res://screens/home/mailbox_popup.gd")
const RewardFly := preload("res://ui/reward_fly.gd")
const RewardReveal := preload("res://ui/reward_reveal.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const FIXTURE := "res://tests/fixtures/mail.json"


class FakeApi:
	extends RefCounted
	var calls: Array = []
	var answers := {}

	func get_json(path: String) -> Dictionary:
		calls.append(["GET", path, null])
		return answers.get(path, {"ok": false, "status": 500, "code": "INTERNAL", "message": "", "data": null})

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append(["POST", path, body])
		return answers.get(path, {"ok": true, "status": 200, "code": "", "message": "", "data": {"ok": true}})


func _open(api: FakeApi) -> Array:
	api.answers["/mail"] = {"ok": true, "status": 200, "code": "", "message": "",
		"data": JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))}
	PlayerState.api = api
	var host := Control.new()
	host.size = Vector2(1600, 900)
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return [host, MailboxPopup.open_on(host)]


func _done(host: Control) -> void:
	host.free()
	PlayerState.api = null
	PlayerState.mails = []
	PlayerState._mail_player = ""
	PlayerState.mail_busy = ""


static func _texts(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text).filter(func(t): return t != "")


func test_list() -> void:
	var api := FakeApi.new()
	var opened := _open(api)
	var p = opened[1]
	check(p.list != null, "the list")
	if p.list != null:
		eq(p.list.get_children().map(func(r): return str(r.name)), ["Mail_m_season3", "Mail_m_admin", "Mail_m_note", "Mail_m_season2", "Mail_m_old"], "newest first")
		var first: Control = p.list.get_child(0)
		check(first.find_children("*", "", true, false).any(func(c): return c.get_script() == GradeBadge), "a season reward shows its insignia")
		check(first.find_child("Dot", true, false) != null, "unclaimed: the red dot")
		var claimed: Control = p.list.get_child(3)
		check(claimed.find_child("Check", true, false) != null and claimed.modulate.a < 1.0, "claimed: dimmed with a check")
		check(p.list.get_child(4).modulate.a < 1.0, "expired: dimmed")
		var texts := _texts(p.list)
		check(not texts.any(func(t): return " xu" in t or "Rương" in t or "kim cương" in t), "no reward words: %s" % str(texts))
	check(p.claim_all_button != null, "Nhận tất cả")
	_done(opened[0])


func test_detail_and_claim_fly() -> void:
	var api := FakeApi.new()
	var opened := _open(api)
	var host: Control = opened[0]
	var p = opened[1]
	api.answers["/mail/claim"] = {"ok": true, "status": 200, "code": "", "message": "",
		"data": {"granted": {"coin": 100000, "gem": 1000, "items": [{"kind": "chest", "id": "stone_chest", "qty": 18}]},
			"wallet": {"coin": 200000}}}
	p.open_detail("m_season3")
	check(api.calls.has(["POST", "/mail/read", {"mailId": "m_season3"}]), "opening marks it read")
	check(p.find_child("Picture", true, false) != null, "the picture")
	var tiles: Control = p.find_child("Tiles", true, false)
	check(tiles != null and tiles.get_script() == RewardStrip, "the rewards as tiles")
	check(p.claim_button != null and not p.claim_button.disabled, "Nhận")
	var layer = await p.claim()
	check(layer != null and layer.get_script() == RewardFly, "the rewards fly to the wallet / bag")
	check(not host.get_children().any(func(c): return c.get_script() == RewardReveal), "no reward reveal")
	eq(p.detail_id, "", "back to the list")
	_done(host)


func test_no_reward_reveal_in_claim_paths() -> void:
	var src := (MailboxPopup as GDScript).source_code
	check(not src.contains("RewardReveal") and not src.contains("show_rewards("), "no gift box for a mail")
	check(src.contains("RewardFly.play("), "the rewards fly")
	var home := (load("res://screens/home.gd") as GDScript).source_code
	check(not home.contains("season_reward_popup"), "no season popup on Home")
