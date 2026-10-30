extends "res://tests/test_case.gd"
## The settings popup with its left menu and the Tài khoản section, and Đăng xuất (spec
## ../battle-squad/docs/specs/2026-10-30-settings-account-link.md, "settings with a left menu"): the
## sections list, the provider rows linked / not linked / coming soon, the confirm's line for a guest
## and a linked account, and core/logout.gd clearing every per-account cache (on stand-ins: the
## real Session file is never touched).

const SettingsPopup := preload("res://screens/home/settings_popup.gd")
const Logout := preload("res://core/logout.gd")
const AccountLink := preload("res://core/account_link.gd")
const SocialGlyphs := preload("res://screens/social/social_glyphs.gd")
const SessionScript := preload("res://autoload/session.gd")
const PlayerStateScript := preload("res://autoload/player_state.gd")
const GuildStateScript := preload("res://autoload/guild_state.gd")
const RouterScript := preload("res://autoload/router.gd")
const PartyScript := preload("res://screens/home/party.gd")
const SocialScript := preload("res://screens/social/social.gd")
const RewardWatch := preload("res://autoload/reward_watch_model.gd")

const SESSION_PATH := "user://test_logout_session.cfg"
const LOADOUT_PATH := "user://test_logout_loadout.cfg"
const PID := "1a2b3c4d-5e6f-4a1b-9c2d-0e1f2a3b4c5d"


class FakeApi:
	extends RefCounted
	var calls: Array = []
	var on_get := Callable() # runs inside get_json (a sign-out while the answer is on its way)
	var answers := {}

	func get_json(path: String) -> Dictionary:
		calls.append({"method": "GET", "path": path})
		if on_get.is_valid():
			on_get.call()
		return answers.get(path, {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "", "data": null})

	func request(method: int, path: String, body: Variant = null, auth: bool = true, retry: bool = true) -> Dictionary:
		calls.append({"method": method, "path": path, "body": body, "auth": auth, "retry": retry})
		return {"ok": true, "status": 200, "code": "", "message": "", "data": null}


class FakeSocket:
	extends RefCounted
	var closed := 0

	func close() -> void:
		closed += 1


static func ok(data: Variant) -> Dictionary:
	return {"ok": true, "status": 200, "code": "", "message": "", "data": data}


func _popup(profile: Dictionary, google_ready: bool = true) -> Array:
	var host := Control.new()
	var p = SettingsPopup.new()
	p.sign_in_ready = func(provider: String) -> bool: return provider == "google" and google_ready
	p.open_for(host)
	p.render(profile)
	return [host, p]


# ── The popup ───────────────────────────────────────────────────────────────

func test_sections_list_and_menu() -> void:
	eq(SettingsPopup.SECTIONS.size(), 1, "only Tài khoản: no empty sound / graphics tabs")
	var s: Dictionary = SettingsPopup.SECTIONS[0]
	eq([s["id"], s["icon"], s["label"]], ["account", "person", "Tài khoản"], "id, glyph, short label")
	check(SocialGlyphs.SOCIAL_KINDS.has("person"), "the account picture exists")
	for entry in SettingsPopup.SECTIONS:
		check(SettingsPopup.new().has_method(entry["build"]), "builder %s exists" % entry["build"])
	var hp := _popup({"playerId": PID, "displayName": "Bé Na"})
	var p = hp[1]
	var b: Button = p.menu.get_node_or_null("Menu_account")
	check(b != null, "a menu button per section")
	if b != null:
		check(b.get_node_or_null("Row/Icon") != null and b.get_node("Row/Label").text == "Tài khoản", "icon + short label")
		check(b.get_meta("selected", false), "the shown section is selected")
	eq(p.current, "account", "the first section shows")
	check(p.section != null and p.section.name == "Account" and p.section.get_parent() == p.content, "the section sits right of the menu")
	var layout: HBoxContainer = p.body.get_node("Layout")
	eq([layout.get_child(0).name, layout.get_child(1).name, layout.get_child(2).name], [&"Menu", &"Divider", &"Content"], "menu | divider | section")
	p.select("nope")
	eq(p.current, "account", "an unknown section is ignored")
	hp[0].free()


func test_account_identity() -> void:
	var hp := _popup({"playerId": PID, "displayName": "Bé Na"})
	var p = hp[1]
	eq(p.section.get_node("PlayerName").text, "Bé Na", "the player's name")
	eq(p.section.get_node("PlayerId").text, "ID: 1A2B3C4D", "the short ID")
	eq(SettingsPopup.short_id(""), "", "no id: nothing")
	check(p.section.get_node_or_null("Logout") is Button, "Đăng xuất")
	hp[0].free()


func test_provider_rows_not_linked() -> void:
	var hp := _popup({"playerId": PID, "linkedProviders": []})
	var p = hp[1]
	var rows: Node = p.section.get_node("Providers")
	eq(rows.get_children().map(func(r): return str(r.name)), ["Row_apple", "Row_google"], "one row per provider, the login screen's order")
	var g: Node = rows.get_node("Row_google")
	eq(g.get_meta("state"), AccountLink.LINK, "Google: its link button")
	check(g.find_child("Link", true, false) is Button, "the Liên kết button")
	check(g.find_child("Mark", true, false) != null and g.find_child("Name", true, false).text == "Google", "the mark and the name")
	var a: Node = rows.get_node("Row_apple")
	eq(a.get_meta("state"), AccountLink.SOON, "Apple: not configured")
	check(a.find_child("Soon", true, false) != null and a.find_child("Soon", true, false).text == "Sắp ra mắt", "Sắp ra mắt")
	check(a.find_child("Link", true, false) == null, "no Apple button")
	hp[0].free()
	var hp2 := _popup({"linkedProviders": []}, false)
	eq(hp2[1].section.get_node("Providers/Row_google").get_meta("state"), AccountLink.SOON, "no sign-in sheet here: Google is Sắp ra mắt too")
	hp2[0].free()


func test_provider_rows_linked() -> void:
	var hp := _popup({"playerId": PID, "linkedProviders": ["google"]})
	var p = hp[1]
	var g: Node = p.section.get_node("Providers/Row_google")
	eq(g.get_meta("state"), AccountLink.LINKED, "Google linked")
	check(g.find_child("Tick", true, false) != null, "the green tick")
	check(g.find_child("Linked", true, false) != null, "Đã liên kết")
	check(g.find_child("Link", true, false) == null, "no button once linked")
	eq(p.section.get_node("Providers/Row_apple").get_meta("state"), AccountLink.SOON, "Apple still coming")
	eq(AccountLink.row_state("apple", {"linkedProviders": ["apple"]}, false), AccountLink.LINKED, "linked wins over not configured")
	eq(AccountLink.row_state("google", {}, true), AccountLink.LINK, "an older profile: not linked")
	hp[0].free()


func test_confirm_text_guest_and_linked() -> void:
	eq(Logout.confirm_text({"linkedProviders": []}), "Bấm \"Chơi ngay\" trên máy này để vào lại tài khoản.",
		"a guest is not lost (the device id stays): Chơi ngay gets it back")
	eq(Logout.confirm_text({}), Logout.GUEST_TEXT, "an older profile: a guest")
	eq(Logout.confirm_text({"linkedProviders": ["google"]}), "Đăng nhập lại bằng Google để vào lại tài khoản.", "linked: its provider")
	eq(Logout.confirm_text({"linkedProviders": ["google", "apple"]}), "Đăng nhập lại bằng Apple hoặc Google để vào lại tài khoản.", "both")


func test_logout_button_opens_the_confirm() -> void:
	var hp := _popup({"playerId": PID, "linkedProviders": []})
	var p = hp[1]
	var ran := [0]
	p.logout_action = func() -> void: ran[0] += 1
	(p.section.get_node("Logout") as Button).pressed.emit()
	var m: Node = hp[0].get_node_or_null("ConfirmLogout")
	check(m != null, "a confirm over the popup")
	if m != null:
		eq(m.title.text, "Đăng xuất?", "its title")
		eq(m.body.get_node("Why").text, Logout.GUEST_TEXT, "the guest's line")
		eq(ran[0], 0, "nothing before the confirm")
		check(p.confirm_logout() == m, "one confirm at a time")
		var go: Button = m.find_child("LogoutButton", true, false)
		go.pressed.emit()
		eq(ran[0], 1, "Đăng xuất logs out")
	hp[0].free()


# ── core/logout.gd ──────────────────────────────────────────────────────────

func _filled_player_state():
	var s = PlayerStateScript.new()
	s.profile = {"playerId": PID, "displayName": "Bé Na", "coin": 50}
	s.characters = {"characters": [{"characterId": "rookie"}]}
	s.characters_stale = false
	s._characters_player = PID
	s.equipment = [{"equipmentId": "e1"}]
	s.equipment_stale = false
	s._equipment_player = PID
	s.stones = {5: 2}
	s.milestones = {"items": []}
	s.milestone_count = 3
	s.milestone_seen = 2
	s.titles = {"titles": []}
	s.daily = {"missions": []}
	s.rank = {"tier": "gold"}
	s._rank_player = PID
	s.boss_runs = {"bosses": []}
	s._boss_runs_player = PID
	s.chests = [{"chestId": "stone_chest", "quantity": 2}]
	s.season_rewards = [{"seasonId": "s1"}]
	s.leaderboards = {"level": {"rows": []}}
	s._leaderboard_player = PID
	s.busy_id = "offer"
	s._known_ids = {"x": true}
	s._reward_watch.start(s.profile, PID)
	s.pending_reward_landed = true
	return s


func _filled_router():
	var r = RouterScript.new()
	r.party = PartyScript.new()
	r.party.model.lobby = {"lobbyId": "l1", "members": []}
	r.party.model.incoming = {"lobbyId": "l2"}
	r.party.model.players = [{"playerId": "p2"}]
	r.social = SocialScript.new()
	r.social._player = PID
	r.social.friends = {"friends": [{"playerId": "p2"}]}
	r.social.friends_loaded = true
	r.social.guild_id = "g1"
	r.social.guild_known = true
	r.social._feeds["world"] = {"messages": [{"id": 1, "text": "hi"}], "error": ""}
	r.social._next_ok["world"] = 99999999
	r.queue = "ranked_2v2"
	r.ranked_member = true
	r.mode_chosen = true
	r.last_quick_play = {"bot": "ai"}
	r.match_roster = {"p2": {}}
	r.home_notice = "x"
	return r


func _filled_guild_state():
	var g = GuildStateScript.new()
	g._player = PID
	g.guild = {"id": "g1", "name": "Rồng Lửa"}
	g.known = true
	g.activity = {"quest": {}}
	g.invites = [{"guild_id": "g2"}]
	g.invites_loaded = true
	g.invite_guilds = {"g2": {}}
	g.busy = "leave"
	return g


func test_logout_clears_every_cache() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	var session = SessionScript.new(SESSION_PATH)
	var device: String = session.ensure_device_id()
	session.set_tokens("access-1", "refresh-1", PID, "Bé Na")
	var f := FileAccess.open(LOADOUT_PATH, FileAccess.WRITE)
	f.store_string("[loadout]\ncharacter=\"rookie\"\n")
	f.close()
	var api := FakeApi.new()
	var socket := FakeSocket.new()
	var ps = _filled_player_state()
	var gs = _filled_guild_state()
	var router = _filled_router()
	var gen: int = ps.account_gen
	var lo = Logout.new()
	lo.session = session
	lo.api = api
	lo.player_state = ps
	lo.guild_state = gs
	lo.socket = socket
	lo.router = router
	lo.files = [LOADOUT_PATH] as Array[String]
	lo.run()
	# the server
	eq(api.calls.size(), 1, "one request")
	if api.calls.size() == 1:
		eq([api.calls[0]["method"], api.calls[0]["path"], api.calls[0]["body"], api.calls[0]["auth"], api.calls[0]["retry"]],
			[HTTPClient.METHOD_POST, "/auth/logout", {"refreshToken": "refresh-1"}, false, false], "POST /auth/logout with the refresh token")
	# the socket and the session
	eq(socket.closed, 1, "the game socket closed")
	eq([session.access_token, session.refresh_token, session.player_id, session.display_name], ["", "", "", ""], "tokens and identity gone")
	eq(session.device_install_id, device, "the device id stays (a guest's Chơi ngay gets the account back)")
	var again = SessionScript.new(SESSION_PATH)
	check(not again.has_token() and again.device_install_id == device, "saved that way")
	again.free()
	check(not FileAccess.file_exists(LOADOUT_PATH), "the last loadout / mode picked removed")
	# PlayerState
	eq(ps.profile, {}, "profile")
	check(ps.account_gen > gen, "answers on their way are dropped")
	eq([ps.characters, ps.equipment, ps.stones, ps.milestones, ps.titles, ps.daily, ps.chests], [null, null, null, null, null, null, null],
		"characters, bag, stones, milestones, titles, missions, chests")
	check(ps.characters_stale and ps.equipment_stale and ps.stones_stale and ps.chests_stale, "stale: the next account loads its own")
	eq([ps.rank, ps.boss_runs, ps.leaderboards, ps.season_rewards], [{}, {}, {}, []], "rank, boss runs, leaderboards, season rewards")
	eq([ps.my_rank(), ps.my_boss_runs()], [{}, {}], "nothing to read back")
	eq([ps.milestone_count, ps.milestone_seen], [-1, -1], "the milestone badge unknown")
	eq([ps.busy_id, ps._known_ids], ["", {}], "no purchase running, no ids seen")
	check(not ps.reward_watching() and not ps.pending_reward_landed, "the rewards watch stopped")
	# GuildState
	eq([gs.guild, gs.known, gs.activity, gs.invites, gs.invites_loaded, gs.invite_guilds, gs.busy, gs._player],
		[{}, false, {}, [], false, {}, "", ""], "the guild forgotten")
	# Router: chat / friends, the party, the match payloads
	var so = router.social
	eq([so.friends, so.friends_loaded, so.guild_id, so.guild_known, so._feeds, so._next_ok], [{}, false, "", false, {}, {}], "chat lines and friends gone")
	var pm = router.party.model
	check(not pm.in_lobby() and pm.incoming.is_empty() and pm.players.is_empty(), "the party forgotten")
	eq([router.queue, router.ranked_member, router.mode_chosen, router.last_quick_play, router.match_roster, router.home_notice],
		["", false, false, {}, {}, ""], "the queue, the mode picked, the last match payloads")
	ps.free()
	gs.free()
	router.party.free()
	router.social.free()
	router.free()
	session.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))


func test_logout_without_a_session_sends_nothing() -> void:
	var session = SessionScript.new("user://test_logout_none.cfg")
	session.access_token = ""
	session.refresh_token = ""
	var api := FakeApi.new()
	var lo = Logout.new()
	lo.session = session
	lo.api = api
	lo.player_state = PlayerStateScript.new()
	lo.guild_state = GuildStateScript.new()
	lo.socket = FakeSocket.new()
	lo.router = RouterScript.new()
	lo.files = [] as Array[String]
	lo.run()
	eq(api.calls.size(), 0, "no refresh token: no POST /auth/logout")
	lo.player_state.free()
	lo.guild_state.free()
	lo.router.free()
	session.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_logout_none.cfg"))


func test_answers_from_before_logout_are_dropped() -> void:
	var ps = PlayerStateScript.new()
	var api := FakeApi.new()
	api.answers["/player/profile"] = ok({"playerId": "old", "displayName": "Cũ"})
	api.answers["/milestones/summary"] = ok({"claimableCount": 4})
	api.on_get = func() -> void: ps.reset_account() # signed out while the answer travels
	ps.api = api
	ps.refresh()
	eq(ps.profile, {}, "the old account's profile is not applied")
	ps.load_milestone_summary()
	eq(ps.milestone_count, -1, "nor its milestone badge")
	ps.free()


func test_socket_close_drops_held_events() -> void:
	var s = load("res://autoload/game_socket.gd").new()
	s.hold()
	s._held_events.append(["TurnStarted", {}])
	s.close()
	var seen := []
	s.event_received.connect(func(e, _d): seen.append(e))
	s.release()
	eq(seen, [], "nothing of the closed link replays")
	s.free()
