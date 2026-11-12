extends "res://tests/test_case.gd"
## screens/home/invite_popup.gd's tabs and empty state, and the status marks of its rows
## (screens/home/presence_glyphs.gd).

const InvitePopup := preload("res://screens/home/invite_popup.gd")
const PresenceGlyphs := preload("res://screens/home/presence_glyphs.gd")
const PartyModel := preload("res://screens/home/party_model.gd")


func test_tabs_suggestions_first() -> void:
	eq(InvitePopup.TABS.map(func(t): return t["tab"]), [PartyModel.TAB_SUGGEST, PartyModel.TAB_FRIENDS], "Gợi ý, Bạn bè")
	eq(InvitePopup._tab_index(PartyModel.TAB_FRIENDS), 1, "the friends tab")
	eq(InvitePopup._tab_index("?"), 0, "anything else: the suggestions")
	eq(PartyModel.new().invite_tab, PartyModel.TAB_SUGGEST, "a session opens on the suggestions")


func test_empty_state() -> void:
	eq(InvitePopup.empty_state(true, false, ""), {"glyph": "", "text": InvitePopup.LOADING}, "loading: no picture")
	eq(InvitePopup.empty_state(true, true, ""), {"glyph": "friends", "text": "Chưa có bạn bè"}, "no friends")
	eq(InvitePopup.empty_state(false, true, ""), {"glyph": "suggest", "text": InvitePopup.EMPTY}, "no one online")
	eq(InvitePopup.empty_state(true, true, " an ")["text"], InvitePopup.NOT_FOUND, "nothing found")


func test_status_marks() -> void:
	for status in PartyModel.STATUSES:
		var g = PresenceGlyphs.status_mark(status, 26)
		eq(g.kind, status, status + " has its mark")
		g.free()
	var other = PresenceGlyphs.status_mark("away", 26)
	eq(other.kind, PartyModel.IDLE, "an unknown status: online")
	other.free()
	for kind in ["suggest", "friends"]:
		var tab = PresenceGlyphs.make_glyph(kind, 48)
		check(kind in PresenceGlyphs.PRESENCE_KINDS or kind in PresenceGlyphs.SOCIAL_KINDS, kind + " is drawn")
		tab.free()
