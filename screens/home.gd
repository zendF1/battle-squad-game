extends Control
## Home: the lobby (screens/home/lobby.gd) and the full-screen pages opened from it: "Nhân vật"
## (gear slots, character, Trang bị / Chỉ số), "Kho đồ" (Trang bị / Vật phẩm / Nguyên liệu),
## "Nâng cấp" (Nâng cấp / Ghép đá; also from the piece popup's Nâng cấp), "Mốc thưởng" (one-time
## progress rewards, milestone_page.gd), "Hồ sơ" (player card,
## Lịch sử), "Xếp hạng" (the leaderboards: Cấp độ / Rank / Lực chiến, leaderboard_page.gd), "Shop" (Vật phẩm / Trang bị / Đá nâng cấp / Nhân vật / Kim cương / Đổi xu) and "Chọn chế
## độ" (the mode card's swap button: one tab per game data category, mode_select.gd; a choice goes
## back to the lobby on that mode, lobby.gd choose_mode()). A page has a
## header with "← Sảnh", its title and the wallet pills; "← Sảnh", Esc (ui_cancel) and the
## Android back button return to the lobby. The pages are built with Home but hidden, and each
## loads its data the first time it is shown (the tabs' own lazy loading). The wallet "+"
## buttons open the Shop on Kim cương (gem) or Đổi xu (coin).
## Each time Home is shown (first entry, back from Loadout or a match) the profile is refreshed in
## the background; the last known values show meanwhile. The cached characters and the owned
## equipment are marked stale too (a match changes their EXP), so whatever shows them reloads
## them once. A message left in Router.home_notice (a ranked queue that ended with an error)
## shows once as a toast. The Nhân vật page, Kho đồ and the Shop's Trang bị (its weapons) act on the lobby's
## character; ◀ ▶ on the Nhân vật page change it in the lobby too.
## A party invite to me (Router.party) shows on its own layer over every page
## (invite_received_popup.gd, "… mời bạn chơi <the mode of the invite's queue>"): Đồng ý answers it
## and shows the lobby on that mode, Từ chối answers no. The party's messages (declined, expired, kicked, the host left, errors) are toasts.
## The reward of an ended season not yet claimed (GET /rank/season-rewards, loaded each time Home
## shows) opens as a popup over the lobby (screens/ranked/season_reward_popup.gd), the oldest
## first, the next one after "Nhận" (and its reward reveal).

const Backdrop := preload("res://ui/backdrop.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Ui := preload("res://ui/ui.gd")
const Modal := preload("res://ui/modal.gd")
const RewardReveal := preload("res://ui/reward_reveal.gd")
const WalletPills := preload("res://ui/wallet_pills.gd")
const Lobby := preload("res://screens/home/lobby.gd")
const ProfileTab := preload("res://screens/home/profile_tab.gd")
const ShopTab := preload("res://screens/home/shop_tab.gd")
const BagPage := preload("res://screens/home/bag_page.gd")
const CharacterPage := preload("res://screens/home/character_page.gd")
const UpgradePage := preload("res://screens/home/upgrade_page.gd")
const MilestonePage := preload("res://screens/home/milestone_page.gd")
const DailyPage := preload("res://screens/home/daily_page.gd")
const DailyModel := preload("res://screens/home/daily_model.gd")
const EquipmentUi := preload("res://screens/home/equipment_ui.gd")
const InviteReceivedPopup := preload("res://screens/home/invite_received_popup.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const ModeSelect := preload("res://screens/home/mode_select.gd")
const LeaderboardPage := preload("res://screens/home/leaderboard_page.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const SeasonRewardPopup := preload("res://screens/ranked/season_reward_popup.gd")
const OnboardingModel := preload("res://screens/onboarding_model.gd")

const LOBBY := 0
const PROFILE := 1
const SHOP := 2
const BAG := 3
const CHARACTER := 4
const UPGRADE := 5
const MILESTONE := 6
const DAILY := 7
const MODES := 8
const LEADERBOARD := 9

var _lobby: Lobby
var _profile: ProfileTab
var _shop: ShopTab
var _bag: BagPage
var _character: CharacterPage
var _upgrade: UpgradePage
var _milestone: MilestonePage
var _daily: DailyPage
var _modes: ModeSelect
var _leaderboard: LeaderboardPage
var _pages := {} # PROFILE / SHOP / BAG / CHARACTER -> the page (header + content)
var _shown := LOBBY
var _invite_layer: Control # over every page: the invite to me
var _invite_popup: InviteReceivedPopup
var _season_popup: SeasonRewardPopup


func _ready() -> void:
	theme = LobbyUi.theme()
	var bg := Backdrop.new() # the lobby stage's: lobby_bg, the picked mode's image (lobby.gd)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	PlayerState.characters_stale = true
	PlayerState.equipment_stale = true
	_lobby = Lobby.new()
	_lobby.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_lobby)
	bg.show_image(_lobby.background(), false)
	_lobby.background_changed.connect(bg.show_image)
	_lobby.open_profile.connect(open_profile)
	_lobby.open_shop.connect(open_shop)
	_lobby.open_bag.connect(open_bag)
	_lobby.open_character.connect(open_character)
	_lobby.open_upgrade.connect(open_upgrade)
	_lobby.open_milestones.connect(open_milestones)
	_lobby.open_daily.connect(open_daily)
	_lobby.open_modes.connect(open_modes)
	_lobby.open_leaderboard.connect(open_leaderboard)
	_connect_wallet(_lobby.wallet)
	_lobby.rank_chip.host = self

	_profile = ProfileTab.new()
	_profile.overlay = self
	_shop = ShopTab.new()
	_shop.overlay = self
	_shop.lobby_character = _lobby.character_id
	_bag = BagPage.new()
	_bag.overlay = self
	_bag.lobby_character = _lobby.character_id
	_bag.open_shop.connect(open_shop)
	_bag.open_upgrade.connect(open_upgrade)
	_character = CharacterPage.new()
	_character.overlay = self
	_character.selected.connect(_lobby.select_character)
	_character.open_shop.connect(open_shop)
	_upgrade = UpgradePage.new()
	_upgrade.overlay = self
	_upgrade.open_shop.connect(open_shop)
	EquipmentUi.open_upgrade = open_upgrade
	_milestone = MilestonePage.new()
	_milestone.overlay = self
	_daily = DailyPage.new()
	_daily.overlay = self
	_daily.go.connect(_on_daily_go)
	_pages[CHARACTER] = _build_page("Nhân vật", _character)
	_pages[UPGRADE] = _build_page("Nâng cấp", _upgrade)
	_pages[BAG] = _build_page("Kho đồ", _bag)
	_pages[MILESTONE] = _build_page("Mốc thưởng", _milestone)
	_pages[DAILY] = _build_page("Nhiệm Vụ Ngày", _daily, _daily.header_extra())
	_modes = ModeSelect.new()
	_modes.chosen.connect(func(index: int) -> void:
		_show(LOBBY)
		_lobby.choose_mode(index))
	_pages[MODES] = _build_page("Chọn chế độ", _modes)
	_pages[PROFILE] = _build_page("Hồ sơ", _profile)
	_leaderboard = LeaderboardPage.new()
	_leaderboard.lobby_character = _lobby.character_id
	_leaderboard.overlay = self
	_pages[LEADERBOARD] = _build_page("Xếp hạng", _leaderboard)
	_pages[SHOP] = _build_page("Shop", _shop)
	_show(LOBBY)
	PlayerState.changed.connect(_check_onboarded)
	PlayerState.refresh()
	PlayerState.load_rank() # the rank chip, the ranked mode card; the match's aiming aid reads the tier
	PlayerState.load_maps() # map names (history, matchmaking, the match toast) and themes from the server
	PlayerState.season_rewards_changed.connect(show_season_reward)
	PlayerState.load_season_rewards() # an ended season's reward to claim: its popup
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_invite_layer = Control.new()
	_invite_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_invite_layer.mouse_filter = MOUSE_FILTER_IGNORE
	_invite_layer.theme = theme
	layer.add_child(_invite_layer)
	Router.party.invite_received.connect(show_invite)
	Router.party.notice.connect(func(text: String) -> void: Ui.toast(self, text, 2.5))
	if Router.home_notice != "": # a ranked queue that ended with an error
		Ui.toast(self, Router.home_notice, 3.5)
		Router.home_notice = ""


## A profile still to onboard (signed in while the profile could not load): the starter pick.
func _check_onboarded() -> void:
	if OnboardingModel.needs_onboarding(PlayerState.profile) and is_inside_tree():
		PlayerState.changed.disconnect(_check_onboarded)
		Router.go(Router.ONBOARDING)


func _exit_tree() -> void:
	if PlayerState.changed.is_connected(_check_onboarded):
		PlayerState.changed.disconnect(_check_onboarded)
	get_tree().quit_on_go_back = true
	for sig in [Router.party.invite_received, Router.party.notice]:
		for c in sig.get_connections():
			if c["callable"].get_object() == self:
				sig.disconnect(c["callable"])
	if EquipmentUi.open_upgrade == open_upgrade:
		EquipmentUi.open_upgrade = Callable()


## A full-screen page: the night backdrop (Art.BG_HOME), the header row (`extra` after the title,
## taking the room the title leaves), then `content`.
func _build_page(title: String, content: Control, extra: Control = null) -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page.visible = false
	add_child(page)
	var bg := Backdrop.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page.add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	page.add_child(col)
	var header := MarginContainer.new()
	for side in ["left", "right", "top"]:
		header.add_theme_constant_override("margin_" + side, 16)
	col.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	header.add_child(row)
	var back := LobbyUi.pill_button("Sảnh", 26, 64, "back")
	LobbyUi.texture_button(back, "pill", 22, true)
	back.pressed.connect(_show.bind(LOBBY))
	row.add_child(back)
	var t := LobbyUi.text(title, 36, Color.WHITE, true)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(t)
	if extra != null:
		t.size_flags_horizontal = SIZE_FILL
		extra.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(extra)
	var wallet := WalletPills.new()
	row.add_child(wallet)
	_connect_wallet(wallet)
	content.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(content)
	return page


func _connect_wallet(wallet: WalletPills) -> void:
	wallet.gem_plus.connect(open_shop.bind(ShopTab.GEMS))
	wallet.coin_plus.connect(open_shop.bind(ShopTab.EXCHANGE))


## An invite to me (PartyModel.parse_invite()): its popup over whatever page shows.
## The oldest unclaimed season reward's popup (none open yet, PlayerState.my_season_rewards());
## null when there is none.
func show_season_reward() -> SeasonRewardPopup:
	if is_instance_valid(_season_popup) and not _season_popup.is_queued_for_deletion():
		return _season_popup
	var list := PlayerState.my_season_rewards()
	if list.is_empty() or PlayerState.season_busy != "" or _reveal_open():
		return null # a reward reveal shows the next popup when it is collected
	_season_popup = SeasonRewardPopup.new()
	_season_popup.open_for(self, list[0])
	return _season_popup


func show_invite(invite: Dictionary) -> InviteReceivedPopup:
	if is_instance_valid(_invite_popup) and not _invite_popup.is_queued_for_deletion():
		_invite_popup.close() # a newer invite replaces it
	_invite_popup = InviteReceivedPopup.new()
	var queue := str(invite.get("mode", ""))
	if queue == "":
		queue = GameData.ranked_mode() # an older server: the ranked queue
	_invite_popup.open_for(_invite_layer, Router.party, invite, LobbyModel.queue_name(queue))
	_invite_popup.accepted.connect(func() -> void:
		Router.party.respond(true)
		_show(LOBBY)
		_lobby.show_queue_mode(queue))
	_invite_popup.declined.connect(func() -> void: Router.party.respond(false))
	return _invite_popup


## The Mode Select page on the lobby's mode (its tab, the card highlighted).
func open_modes() -> void:
	_modes.show_for(_lobby.current_mode())
	_show(MODES)


func open_profile() -> void:
	_show(PROFILE)


## The Xếp hạng page (tab: LeaderboardModel.TABS index; -1 keeps the last one).
func open_leaderboard(tab: int = -1) -> void:
	if tab >= 0:
		_leaderboard.show_tab(tab)
	_show(LEADERBOARD)


## The Nhân vật page on the lobby's character (section: CharacterPage.GEAR or STATS).
func open_character(section: int = CharacterPage.GEAR) -> void:
	_character.show_character(_lobby.character_id())
	_character.show_section(section)
	_show(CHARACTER)


func open_bag(section: int = BagPage.EQUIPMENT) -> void:
	_bag.show_section(section) # before showing: only that sub-tab loads
	_show(BAG)


## The Nâng cấp page, on the piece `equipment_id` ("" keeps its choice); section: UpgradePage.UPGRADE
## or MERGE (Ghép đá).
func open_upgrade(equipment_id: String = "", section: int = UpgradePage.UPGRADE) -> void:
	if section == UpgradePage.MERGE:
		_upgrade.show_section(section)
	else:
		_upgrade.select_piece(equipment_id)
	_show(UPGRADE)


## The Mốc thưởng page, on tab `tab` (MilestoneModel.TABS index; -1 keeps the last one).
func open_milestones(tab: int = -1) -> void:
	if tab >= 0:
		_milestone.show_tab(tab)
	_show(MILESTONE)


func open_daily() -> void:
	_show(DAILY)


## "Đi ngay" on a daily mission: play → the lobby's BẮT ĐẦU (its mode, the Loadout), shop → the
## Shop's Vật phẩm, equipment → Nâng cấp.
func _on_daily_go(target: String) -> void:
	match target:
		DailyModel.GOTO_PLAY:
			_show(LOBBY)
			_lobby.start()
		DailyModel.GOTO_SHOP:
			open_shop(ShopTab.ITEMS)
		DailyModel.GOTO_EQUIPMENT:
			open_upgrade()


func open_shop(section: int) -> void:
	_shop.show_section(section)
	_show(SHOP)


## Which screen shows: LOBBY or a page (PROFILE, SHOP, BAG, CHARACTER, UPGRADE, MILESTONE, DAILY, MODES, LEADERBOARD). Android back quits only from the lobby.
func _show(which: int) -> void:
	_shown = which
	for key in _pages:
		_pages[key].visible = key == which
	_lobby.visible = which == LOBBY
	get_tree().quit_on_go_back = which == LOBBY


func shown() -> int:
	return _shown


func _unhandled_input(event: InputEvent) -> void:
	if _shown != LOBBY and event.is_action_pressed("ui_cancel") and not _modal_open():
		get_viewport().set_input_as_handled()
		_show(LOBBY)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _shown != LOBBY and not _modal_open():
		_show(LOBBY)


func _modal_open() -> bool:
	for c in get_children():
		if c.get_script() == Modal and not c.is_queued_for_deletion():
			return true
	return _reveal_open()


## A reward reveal (ui/reward_reveal.gd) plays over Home.
func _reveal_open() -> bool:
	for c in get_children():
		if c.get_script() == RewardReveal and not c.is_queued_for_deletion():
			return true
	return false
