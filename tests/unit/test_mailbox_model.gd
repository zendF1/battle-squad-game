extends "res://tests/test_case.gd"
## MailboxModel: GET /mail parsing (tests/fixtures/mail.json, shaped like the contract), the
## newest-first order, claimed / expired / claimable, the badge count, claim answers.

const MailboxModel := preload("res://screens/home/mailbox_model.gd")
const Fmt := preload("res://core/fmt.gd")
const FIXTURE := "res://tests/fixtures/mail.json"
const NOW := "2026-11-13T12:00:00Z"


func _answer() -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func _mails() -> Array:
	return MailboxModel.parse(_answer())


func _by_id(mails: Array, id: String) -> Dictionary:
	for m in mails:
		if m["mailId"] == id:
			return m
	return {}


func test_parse_and_sort() -> void:
	var mails := _mails()
	eq(mails.map(func(m): return m["mailId"]), ["m_season3", "m_admin", "m_note", "m_season2", "m_old"], "newest first")
	var s3 := _by_id(mails, "m_season3")
	eq(s3["kind"], "season_reward", "kind")
	eq(s3["meta"]["grade"], "thuong_tuong", "meta kept")
	eq(s3["rewards"]["coin"], 100000, "coin")
	eq(s3["rewards"]["items"].map(func(it): return [it["kind"], it["id"], it["qty"]]),
		[["chest", "stone_chest", 18], ["chest", "equip_chest_16", 1]], "items")
	eq(s3["readAt"], "", "null read time")
	eq(MailboxModel.parse({}), [], "nothing")
	eq(MailboxModel.parse(null), [], "no data")
	eq(MailboxModel.parse({"mails": [{"kind": "admin"}, "x"]}), [], "rows without a mailId dropped")


func test_states_and_counts() -> void:
	var mails := _mails()
	var now := Fmt.unix_time(NOW)
	check(MailboxModel.is_claimed(_by_id(mails, "m_season2")), "claimed")
	check(MailboxModel.is_read(_by_id(mails, "m_season2")), "claimed reads as read")
	check(MailboxModel.is_expired(_by_id(mails, "m_old"), now), "expired")
	check(not MailboxModel.is_expired(_by_id(mails, "m_season3"), now), "not yet expired")
	check(not MailboxModel.is_expired(_by_id(mails, "m_admin"), now), "no expiry")
	check(not MailboxModel.has_rewards(_by_id(mails, "m_note")), "a note without rewards")
	eq(MailboxModel.claimable(mails, now).map(func(m): return m["mailId"]), ["m_season3", "m_admin"], "claimable")
	eq(MailboxModel.attention(mails, now), 3, "the badge: two to claim and the unread note")
	check(MailboxModel.is_expired(_by_id(mails, "m_season3"), Fmt.unix_time("2026-12-14T00:00:00Z")), "a month later")


func test_view_texts() -> void:
	var mails := _mails()
	var s3 := _by_id(mails, "m_season3")
	eq(MailboxModel.icon_kind(s3), "grade", "the insignia")
	eq(MailboxModel.grade_of(s3), ["thuong_tuong", 1], "its grade")
	eq(MailboxModel.grade_text(s3), "Thượng tướng", "a general: no division")
	eq(MailboxModel.standing_text(s3), "Hạng #3 · 4.230 điểm", "the final standing")
	eq(MailboxModel.icon_kind(_by_id(mails, "m_admin")), "mail", "an envelope")
	eq(MailboxModel.standing_text(_by_id(mails, "m_admin")), "", "no standing")
	eq(MailboxModel.short_title({"kind": "season_reward", "meta": {"seasonName": "Mùa 4"}}), "Thưởng Mùa 4", "no title: the season")
	eq(MailboxModel.short_title({"kind": "admin"}), "Thư", "no title")
	var tiles := MailboxModel.tiles(s3["rewards"])
	var kinds := tiles.map(func(t): return t["kind"])
	kinds.sort()
	eq(kinds, ["chest", "chest", "coin", "gem"], "tiles")
	var gem: Array = tiles.filter(func(t): return t["kind"] == "gem")
	check(gem.size() == 1 and gem[0].get("locked", false), "the gem is locked gem")


func test_claim_answers() -> void:
	var s3 := _by_id(_mails(), "m_season3")
	var fresh := s3.duplicate(true)
	fresh["claimedAt"] = "2026-11-13T12:00:01Z"
	var done := MailboxModel.claimed(s3, {"mail": fresh, "granted": {"coin": 1}}, NOW)
	eq(done["claimedAt"], "2026-11-13T12:00:01Z", "the answer's mail")
	var local := MailboxModel.claimed(s3, null, NOW)
	check(MailboxModel.is_claimed(local) and MailboxModel.is_read(local), "no answer: claimed now")
	check(not MailboxModel.is_claimed(s3), "the original untouched")
	eq(MailboxModel.claimed_ids({"claimed": ["a", "", 3, "b"]}), ["a", "b"], "claim-all ids")
	eq(MailboxModel.granted({"granted": {"coin": 7, "gem": 2, "items": []}}, {}), {"coin": 7, "gem": 2, "items": []}, "granted")
	eq(MailboxModel.granted({}, s3["rewards"]), s3["rewards"], "fallback: the mail's rewards")
