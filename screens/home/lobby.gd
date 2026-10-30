extends Control
## The Home lobby (a Gunny-style mobile lobby). Corners: the player (avatar letter, name, EXP
## bar, "Lv.N"; tap opens the Nhân vật page) top-left with the rank chip beside it (grade insignia,
## "Binh nhì 2", the division's points; tap: the rank popup, screens/ranked/rank_chip.gd), the wallet pills top-right, the connection
## state top-centre, the gear right of the wallet (the settings popup, settings_popup.gd), one round shortcut per page down the right (Nhân vật, Kho đồ, Nâng cấp,
## Hồ sơ, Shop, Xếp hạng: the trophy, a code-drawn glyph), the selected character's icon card on the left (character_card.gd; no sentences: its element chain,
## ui/element_chain.gd, beaten by → element → beats; its skill's picture, ui/skill_button.gd, a tap
## opens the skill's popup; Lực chiến (the power glyph and the server's number, ui/power_tag.gd); heart / sword /
## shield with Máu, Sát thương, Phòng thủ; its name and
## level are on the stage), the "Mốc thưởng" button (a red badge with the claimable count, hidden at 0; "Có mốc
## thưởng mới!" once when the count rose since the player last saw it), "Nhiệm vụ" (the daily
## missions; a red dot while a mission, chest or weekly reward is claimable, reloaded each time
## the lobby shows), "Bạn bè" (the friends page; a red count of the requests waiting for me) and
## "Bang hội" (the guild's crest, screens/guild/guild_button.gd; a red dot for invitations while not
## in a guild) above the chat box bottom-left (screens/social/chat_box.gd: the newest Thế giới /
## Bang hội lines; a tap opens the chat popup) and the mode card with "BẮT ĐẦU" bottom-right.
## Centre stage: the worn title's plate (ui/title_plate.gd; nothing without one) over the selected
## character's name and level, the character drawn big on a pedestal with
## its hands free; the gun it wears (its basic gun when none) rests on the pedestal at its left
## (pedestal_gun.gd, no name under it), updated on equip / unequip. ◀ ▶ or a swipe cycles
## the four characters. The character is the Loadout's (saved
## in the same settings file, so the Loadout opens with it; until the player picks one, an owned
## one: _auto_pick()) and the mode is remembered there
## too; the card shows the mode's icon plate and name (a boss mode: a gift box with the big-reward
## runs left today, "×2"; the rank is the chip's, top-left), its swap button (or a tap on the card) opens the Mode Select page
## (open_modes, mode_select.gd), which calls choose_mode(). "BẮT ĐẦU" puts
## the mode's QuickPlay base in Router.quick_play_base and opens the Loadout. Character levels and stats come from the PlayerState characters cache, loaded when
## the lobby is shown; until then the card shows the element and the skill only.
## A party mode (party size 2 or more: Đấu thường, Đấu hạng) adds the party (Router.party,
## screens/home/party.gd), on the mode's queue (CreateLobby {queue}): the teammate slot right of
## the stage (party_slot.gd: "+" → the invite popup, invite_popup.gd; a teammate drawn there, a
## member sees the host), and the start button of PartyModel.start_button(): the host waits for a
## ready teammate ("Chờ đồng đội sẵn sàng", disabled), the member gets "SẴN SÀNG" (the Loadout, which
## readies) / "HUỶ SẴN SÀNG". With a teammate the stage character goes to the lobby (UpdateLoadout)
## so their slot shows it. Choosing another party mode in my lobby moves it there (SetLobbyQueue);
## a solo mode leaves it, asking "Rời đội?" first with a teammate. The member's card shows the
## host's mode (LobbyUpdated queue) and cannot change it ("Chủ phòng chọn chế độ").
## A boss mode (party size 4) has three teammate slots, smaller, two right of the stage and one
## left (screens/home/party_layout.gd); switching a party bigger than a mode holds is refused
## ("Đội đông hơn số người của chế độ này", also the server's PARTY_TOO_LARGE, which puts the
## lobby's mode back).
## The stage's background (background_changed, drawn by Home's ui/backdrop.gd) is lobby_bg until
## the player picks a mode this session (Router.mode_chosen: the mode card / Mode Select, an invite
## accepted, the host's mode followed), then that mode's image (LobbyModel.stage_background()),
## kept for the session; a change cross-fades.

signal open_profile
signal open_shop(section: int)
signal open_bag
signal open_character
signal open_upgrade
signal open_milestones
signal open_daily
signal open_modes
signal open_leaderboard
signal open_guild
signal open_friends
signal background_changed(key: String)

const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const CharacterView := preload("res://ui/character_view.gd")
const PedestalGun := preload("res://screens/home/pedestal_gun.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const Art := preload("res://ui/art.gd")
const WalletPills := preload("res://ui/wallet_pills.gd")
const LoadoutModel := preload("res://screens/loadout_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const Progress := preload("res://screens/home/progress.gd")
const ShopTab := preload("res://screens/home/shop_tab.gd")
const ChatBox := preload("res://screens/social/chat_box.gd")
const ChatPopup := preload("res://screens/social/chat_popup.gd")
const SocialGlyphs := preload("res://screens/social/social_glyphs.gd")
const FriendsModel := preload("res://screens/social/friends_model.gd")
const MilestonePage := preload("res://screens/home/milestone_page.gd")
const MilestoneModel := preload("res://screens/home/milestone_model.gd")
const TitlePlate := preload("res://ui/title_plate.gd")
const MissionArt := preload("res://screens/home/mission_art.gd")
const RankChip := preload("res://screens/ranked/rank_chip.gd")
const PartySlot := preload("res://screens/home/party_slot.gd")
const GradeFrame := preload("res://screens/ranked/grade_frame.gd")
const InvitePopup := preload("res://screens/home/invite_popup.gd")
const Modal := preload("res://ui/modal.gd")
const ModeSelectModel := preload("res://screens/home/mode_select_model.gd")
const PartyLayout := preload("res://screens/home/party_layout.gd")
const BossCardModel := preload("res://screens/home/boss_card_model.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const CharacterCard := preload("res://screens/home/character_card.gd")
const ModeSelect := preload("res://screens/home/mode_select.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const GuildButton := preload("res://screens/guild/guild_button.gd")
const SettingsPopup := preload("res://screens/home/settings_popup.gd")

const MARGIN := 18
const STAGE := Vector2(560, 590)
const SWIPE := 70.0 # px of horizontal drag that switches the character
const AVATAR_COLORS := [Color(0.9, 0.4, 0.35), Color(0.3, 0.6, 0.95), Color(0.35, 0.75, 0.45), Color(0.65, 0.45, 0.9), Color(0.95, 0.6, 0.2)]

var wallet: WalletPills
var settings_path := LoadoutModel.SETTINGS_PATH

var _model := LoadoutModel.new() # the character choice (items kept as the Loadout left them)
var _picked := false # the player picked a character here (◀ ▶, the Nhân vật page): no automatic pick after
var _mode := 0
var _background := "" # the stage's background key (background())

# Player block
var _avatar: PanelContainer
var _avatar_letter: Label
var _name: Label
var _exp_bar: ProgressBar
var _level: Label
var _level_badge: PanelContainer
var _player_status: Label
var _conn: Label

# Stage and info card
var _art: CharacterView
var _gun_stand: PedestalGun
var _stage_head: VBoxContainer
var _stage_title: TitlePlate
var _stage_name: Label
var _stage_name_row: HBoxContainer # the element badge before the name
var _stage_level: Label
var _info: CharacterCard
var _drag_from := -1.0

var _milestone_badge: PanelContainer
var _daily_dot: Control
var _friends_badge: PanelContainer

var rank_chip: RankChip

# Mode card
var _mode_plate: Control # the mode's icon on its round plate (Mode Select's look)
var _mode_name: Label
var _mode_lock: Label # the member's "Chủ phòng chọn chế độ"
var _mode_runs: HBoxContainer # a boss mode's gift box and the big-reward runs left, "×2"
var _mode_runs_text: Label
var _mode_swap: Button
var _start: Button
var _slots: Array[PartySlot] = [] # a party mode's teammate slots (PartyLayout: 1 for 2v2, 3 for a boss)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_model.restore(settings_path)
	PlayerState.need_characters() # drops another account's cached characters before the pick
	_auto_pick()
	_mode = LobbyModel.restore_mode(settings_path)

	_add_stage()
	for i in PartyLayout.THREE.size():
		var slot := PartySlot.new()
		slot.name = "PartySlot%d" % i
		_pin(slot, 0.5, 1, SLOT_X, SLOT_Y)
		slot.invite_pressed.connect(open_invite)
		slot.kick_pressed.connect(func() -> void: _kick(slot))
		slot.leave_pressed.connect(_confirm_leave.bind(Callable()))
		_slots.append(slot)
	_pin(_build_player_block(), 0, 0, MARGIN, MARGIN)
	rank_chip = RankChip.new()
	_pin(rank_chip, 0, 0, MARGIN + PLAYER_W + 14, MARGIN + 14)
	_conn = LobbyUi.text("", 22, Color.WHITE, true)
	_pin(_conn, 0.5, 0, 0, MARGIN + 6)
	var gear := _build_settings_button()
	_pin(gear, 1, 0, -MARGIN, MARGIN)
	wallet = WalletPills.new()
	_pin(wallet, 1, 0, -MARGIN - SETTINGS - SETTINGS_GAP, MARGIN)
	wallet.resized.connect(func() -> void: gear.position.y = wallet.position.y + (wallet.size.y - gear.size.y) / 2.0)
	_pin(_build_shortcuts(), 1, 0, -MARGIN - 6, 112)
	_pin(_build_info_card(), 0, 0, MARGIN, 150)
	_pin(_build_chat(), 0, 1, MARGIN, -MARGIN)
	var rewards := Ui.hbox(20)
	rewards.add_child(_build_milestone_button())
	rewards.add_child(_build_daily_button())
	rewards.add_child(_build_friends_button())
	rewards.add_child(GuildButton.make(REWARD_BUTTON, func(): open_guild.emit()))
	_pin(rewards, 0, 1, MARGIN + 6, -MARGIN - CHAT_H - 12)
	_pin(_build_mode_card(), 1, 1, -MARGIN, -MARGIN)

	PlayerState.changed.connect(_render_player)
	PlayerState.changed.connect(_auto_pick) # the profile's currentCharacterId
	PlayerState.characters_changed.connect(_auto_pick)
	PlayerState.characters_changed.connect(_render_character)
	PlayerState.equipment_changed.connect(_render_gun)
	PlayerState.milestones_changed.connect(_render_milestones)
	PlayerState.daily_changed.connect(_render_daily)
	PlayerState.rank_changed.connect(_render_mode)
	PlayerState.boss_runs_changed.connect(_render_mode)
	Router.party.changed.connect(_render_mode) # a member follows the host's mode
	Router.party.queue_refused.connect(_on_queue_refused)
	Router.party.select_queue(_party_queue())
	GameSocket.connected.connect(_render_conn)
	GameSocket.disconnected.connect(_render_conn)
	visibility_changed.connect(_on_visibility_changed)
	_render_player()
	_render_conn()
	_render_mode()
	_render_character()
	_on_visibility_changed()


## Anchors `c` to a point of the screen (ax, ay: 0 left/top, 0.5 centre, 1 right/bottom) at an
## offset; it grows away from that edge as its content needs.
func _pin(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	add_child(c)
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = _grow(ax)
	c.grow_vertical = _grow(ay)


static func _grow(anchor: float) -> GrowDirection:
	if anchor >= 1.0:
		return GROW_DIRECTION_BEGIN
	return GROW_DIRECTION_BOTH if anchor > 0.0 else GROW_DIRECTION_END


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		PlayerState.need_characters()
		PlayerState.need_equipment() # the stage character holds the weapon it wears
		PlayerState.load_milestone_summary() # back from a match or a page: the badge count
		PlayerState.load_daily() # the daily missions' red dot (a match or a purchase moves them)
		GuildState.load_me() # my guild (the guild button, chat's Bang hội tab)
		GuildState.load_invites() # the guild button's red dot
		Router.social.load_friends() # the friends button's count of requests waiting
		_render_character() # back from a page: whatever it loaded or bought
		_render_milestones()
		_render_daily()


# ── Player ──────────────────────────────────────────────────────────────────

const PLAYER_W := 380


func _build_player_block() -> Control:
	var b := Button.new()
	LobbyUi.style_button(b, Color(0, 0, 0, 0), 20, 6)
	b.add_theme_stylebox_override("hover", LobbyUi.box(Color(1, 1, 1, 0.06), 20, 6))
	b.add_theme_stylebox_override("pressed", LobbyUi.box(Color(1, 1, 1, 0.12), 20, 6))
	b.custom_minimum_size = Vector2(PLAYER_W, 104)
	b.pressed.connect(func(): open_character.emit())
	var row := Ui.hbox(14)
	row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_top = 6
	row.offset_right = -6
	row.offset_bottom = -6
	b.add_child(row)
	_avatar = PanelContainer.new()
	_avatar.custom_minimum_size = Vector2(92, 92)
	_avatar_letter = LobbyUi.text("?", 48, Color.WHITE, true)
	_avatar_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar.add_child(_avatar_letter)
	var frame := NinePatchRect.new()
	frame.texture = Art.texture(Art.ui_path("avatar_frame"))
	var m: Array = Art.UI_BOXES["avatar_frame"]["margins"]
	frame.patch_margin_left = m[0]
	frame.patch_margin_top = m[1]
	frame.patch_margin_right = m[2]
	frame.patch_margin_bottom = m[3]
	frame.mouse_filter = MOUSE_FILTER_IGNORE
	_avatar.add_child(frame)
	row.add_child(_avatar)
	var col := Ui.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(col)
	_name = LobbyUi.text("", 28, Color.WHITE, true)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_name)
	_exp_bar = Ui.bar(0.0, 12)
	_exp_bar.add_theme_stylebox_override("fill", LobbyUi.box(LobbyUi.GOLD, 6, 0))
	_exp_bar.add_theme_stylebox_override("background", LobbyUi.box(Color(0, 0, 0, 0.45), 6, 0, Color(1, 1, 1, 0.15), 1))
	col.add_child(_exp_bar)
	var lv_row := Ui.hbox(10)
	col.add_child(lv_row)
	_level_badge = LobbyUi.panel(0, 12, Color(0.12, 0.35, 0.75, 0.9))
	_level = LobbyUi.text("", 20, Color.WHITE, true)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.custom_minimum_size.x = 76
	_level_badge.add_child(_level)
	lv_row.add_child(_level_badge)
	_player_status = LobbyUi.text("", 20, Ui.TEXT_DIM)
	lv_row.add_child(_player_status)
	for c in [row, _avatar, _avatar_letter, col, _name, _exp_bar, lv_row, _level_badge, _level, _player_status]:
		c.mouse_filter = MOUSE_FILTER_IGNORE
	return b


func _render_player() -> void:
	if _stage_title != null:
		_stage_title.set_title(PlayerState.equipped_title())
		_stage_head.position.y = HEAD_Y - (TITLE_H - 4.0 if _stage_title.has_title() else 0.0) # the name stays put
	var display := PlayerState.display_name()
	_name.text = display
	_avatar_letter.text = display.substr(0, 1).to_upper() if display != "" else "?"
	var tint: Color = AVATAR_COLORS[absi(hash(display)) % AVATAR_COLORS.size()]
	_avatar.add_theme_stylebox_override("panel", LobbyUi.box(tint, 20, 0)) # the avatar_frame image draws the rim
	var loaded := PlayerState.is_loaded()
	_level_badge.visible = loaded
	if loaded:
		_level.text = "Lv.%d" % PlayerState.level()
		var p := Progress.player(PlayerState.level(), PlayerState.player_exp())
		_exp_bar.value = p["ratio"]
		_player_status.text = "EXP %s" % p["text"]
		_player_status.add_theme_color_override("font_color", Ui.TEXT_DIM)
	else:
		_exp_bar.value = 0.0
		_player_status.text = "Đang tải..." if PlayerState.loading else PlayerState.error
		_player_status.add_theme_color_override("font_color", Ui.TEXT_DIM if PlayerState.loading else Ui.TONES["error"])


func _render_conn() -> void:
	if GameSocket.is_open():
		_conn.text = "● Online"
		_conn.add_theme_color_override("font_color", Ui.TONES["good"])
	else:
		_conn.text = "○ Đang kết nối..."
		_conn.add_theme_color_override("font_color", Ui.TONES["draw"])


# ── Settings ────────────────────────────────────────────────────────────────

const SETTINGS := 56 # px, the gear in the top-right corner
const SETTINGS_GAP := 12 # between the gear and the wallet


## The gear (a code-drawn cog on a dark disc, like the wallet pills) in the top-right corner, right
## of the wallet and level with its middle: the settings popup (settings_popup.gd).
func _build_settings_button() -> Button:
	var b := Button.new()
	b.name = "SettingsButton"
	b.tooltip_text = "Cài đặt"
	b.custom_minimum_size = Vector2(SETTINGS, SETTINGS)
	LobbyUi.style_button(b, Color(0.05, 0.08, 0.2, 0.82), SETTINGS / 2, 0, Color(1, 1, 1, 0.85), 3)
	b.add_theme_stylebox_override("hover", LobbyUi.box(Color(0.12, 0.16, 0.32, 0.9), SETTINGS / 2, 0, Color(1, 1, 1, 0.85), 3))
	b.add_theme_stylebox_override("pressed", LobbyUi.box(Color(0.02, 0.04, 0.12, 0.9), SETTINGS / 2, 0, Color(1, 1, 1, 0.85), 3))
	var g = GlyphIcon.make("gear", 0)
	g.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var inset := roundf(SETTINGS * 0.14)
	g.offset_left = inset
	g.offset_top = inset
	g.offset_right = -inset
	g.offset_bottom = -inset
	b.add_child(g)
	b.pressed.connect(open_settings)
	return b


func open_settings():
	var showing := _host().get_node_or_null("SettingsPopup")
	if showing != null and not showing.is_queued_for_deletion():
		return showing
	return SettingsPopup.open_on(_host())


# ── Shortcuts and chat ──────────────────────────────────────────────────────

const SHORTCUT := 62 # px, six round buttons fit above the mode card
const REWARD_BUTTON := 70 # px, Mốc thưởng / Nhiệm vụ above the chat


func _build_shortcuts() -> Control:
	var col := Ui.vbox(2)
	col.add_child(LobbyUi.icon_button("characters", "Nhân vật", LobbyUi.ICON_COLORS["blue"], func(): open_character.emit(), SHORTCUT))
	var bag := LobbyUi.icon_button("inventory", "Kho đồ", LobbyUi.ICON_COLORS["green"], func(): open_bag.emit(), SHORTCUT)
	bag.name = "BagButton" # collected rewards fly here (ui/reward_reveal.gd)
	col.add_child(bag)
	col.add_child(LobbyUi.icon_button("upgrade", "Nâng cấp", LobbyUi.ICON_COLORS["red"], func(): open_upgrade.emit(), SHORTCUT))
	col.add_child(LobbyUi.icon_button("history", "Hồ sơ", LobbyUi.ICON_COLORS["purple"], func(): open_profile.emit(), SHORTCUT))
	col.add_child(LobbyUi.icon_button("shop", "Shop", LobbyUi.ICON_COLORS["orange"], func(): open_shop.emit(ShopTab.ITEMS), SHORTCUT))
	col.add_child(_glyph_shortcut("trophy", "Xếp hạng", LobbyUi.ICON_COLORS["gold"], func(): open_leaderboard.emit()))
	return col


## A shortcut like LobbyUi.icon_button() whose picture is a code-drawn glyph (ui/glyph_icon.gd).
func _glyph_shortcut(kind: String, caption: String, bg: Color, on_press: Callable) -> Control:
	var col := LobbyUi.icon_button("unknown", caption, bg, on_press, SHORTCUT)
	col.name = "Shortcut_" + kind
	var b: Button = col.get_child(0)
	b.icon = null
	var g = GlyphIcon.make(kind, 0)
	g.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var inset := roundf(SHORTCUT * 0.17)
	g.offset_left = inset
	g.offset_top = inset
	g.offset_right = -inset
	g.offset_bottom = -inset
	b.add_child(g)
	return col


const CHAT_H := 172


## "Mốc thưởng": a round gift button with its caption and the red claimable badge on its corner.
func _build_milestone_button() -> Control:
	var col := LobbyUi.icon_button("milestone", "Mốc thưởng", LobbyUi.ICON_COLORS["red"], func(): open_milestones.emit(), REWARD_BUTTON)
	var b: Button = col.get_child(0)
	_milestone_badge = MilestonePage.badge()
	_milestone_badge.position = Vector2(REWARD_BUTTON - 22, -6)
	b.add_child(_milestone_badge)
	return col


func _render_milestones() -> void:
	if _milestone_badge == null:
		return
	var text := MilestoneModel.badge_text(PlayerState.milestone_count)
	_milestone_badge.visible = text != ""
	(_milestone_badge.get_child(0) as Label).text = text
	if is_visible_in_tree() and PlayerState.take_new_milestones():
		Ui.toast(self, "Có mốc thưởng mới!")


## "Nhiệm vụ": a round button with a clipboard and the red dot (anything claimable today).
func _build_daily_button() -> Control:
	var col := LobbyUi.icon_button("check", "Nhiệm vụ", LobbyUi.ICON_COLORS["green"], func(): open_daily.emit(), REWARD_BUTTON)
	var b: Button = col.get_child(0)
	b.icon = null # the clipboard is drawn (mission_art.gd)
	var art := MissionArt.make(MissionArt.Kind.BOARD, Vector2(REWARD_BUTTON, REWARD_BUTTON) * 0.7)
	art.position = Vector2(REWARD_BUTTON, REWARD_BUTTON) * 0.15
	b.add_child(art)
	_daily_dot = MilestonePage.dot(20)
	_daily_dot.position = Vector2(REWARD_BUTTON - 18, -2)
	b.add_child(_daily_dot)
	return col


func _render_daily() -> void:
	if _daily_dot != null:
		_daily_dot.visible = PlayerState.daily_claimable() > 0


## The chat box (screens/social/chat_box.gd): the newest Thế giới / Bang hội lines, polled while
## the lobby shows; a tap opens the chat popup.
func _build_chat() -> Control:
	var b := ChatBox.make(490, CHAT_H)
	b.pressed.connect(open_chat)
	return b


## The chat popup (screens/social/chat_popup.gd) over Home.
func open_chat():
	return ChatPopup.open_on(_host())


## "Bạn bè": a round button with two people (the friends page) and the red count of the friend
## requests waiting for me.
func _build_friends_button() -> Control:
	var col := LobbyUi.icon_button("unknown", "Bạn bè", LobbyUi.ICON_COLORS["blue"], func(): open_friends.emit(), REWARD_BUTTON)
	col.name = "FriendsButton"
	var b: Button = col.get_child(0)
	b.icon = null # the two people are drawn (social_glyphs.gd)
	var art := SocialGlyphs.glyph("friends", int(REWARD_BUTTON * 0.66))
	art.position = Vector2(REWARD_BUTTON, REWARD_BUTTON) * 0.17
	b.add_child(art)
	_friends_badge = MilestonePage.badge()
	_friends_badge.position = Vector2(REWARD_BUTTON - 22, -6)
	b.add_child(_friends_badge)
	Router.social.friends_changed.connect(_render_friends)
	_render_friends()
	return col


func _render_friends() -> void:
	var n := FriendsModel.pending_count(Router.social.friends)
	_friends_badge.visible = n > 0
	(_friends_badge.get_child(0) as Label).text = str(n)


# ── Stage ───────────────────────────────────────────────────────────────────

## The centre: name and level above the character on its pedestal, ◀ ▶ on the sides. Pinned to
## the bottom centre so it stays between the side columns on any width.
func _add_stage() -> void:
	var stage := Control.new()
	stage.custom_minimum_size = STAGE
	stage.mouse_filter = MOUSE_FILTER_STOP
	stage.gui_input.connect(_on_stage_input)
	_pin(stage, 0.5, 1, 0, -110)
	var pedestal := Control.new()
	pedestal.mouse_filter = MOUSE_FILTER_IGNORE
	pedestal.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pedestal.draw.connect(_draw_pedestal.bind(pedestal))
	stage.add_child(pedestal)

	var head := Ui.vbox(0)
	head.mouse_filter = MOUSE_FILTER_IGNORE
	head.position = Vector2((STAGE.x - 400) / 2, HEAD_Y)
	_stage_head = head
	head.custom_minimum_size = Vector2(400, 0)
	stage.add_child(head)
	_stage_title = TitlePlate.new()
	_stage_title.plate_height = TITLE_H
	_stage_title.max_width = 400
	_stage_title.size_flags_horizontal = SIZE_SHRINK_CENTER
	head.add_child(_stage_title)
	_stage_name = LobbyUi.text("", 44, Color.WHITE, true)
	_stage_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_name_row = ElementBadge.name_row(_stage_name, "", 44, 10)
	head.add_child(_stage_name_row)
	_stage_level = LobbyUi.text("", 24, LobbyUi.GOLD, true)
	_stage_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(GlyphIcon.level_row(_stage_level, 28))

	_art = CharacterView.new()
	_art.position = Vector2((STAGE.x - 375) / 2, 142) # 2.5 px per art unit; feet on the pedestal
	_art.size = Vector2(375, 400)
	_art.idle = true
	_art.hands_free = true
	_art.back_aura = true # the worn weapon's +14 / +16 ring, behind the body and the pedestal gun
	stage.add_child(_art)

	_gun_stand = PedestalGun.new()
	_gun_stand.size = PedestalGun.STAGE_RECT.size
	_gun_stand.position = PedestalGun.STAGE_RECT.position
	stage.add_child(_gun_stand)

	for side in [-1, 1]:
		var arrow := LobbyUi.round_button("arrow_left" if side < 0 else "arrow_right", 76, Color(0.05, 0.08, 0.2, 0.7), 0.5)
		arrow.position = Vector2(0 if side < 0 else STAGE.x - 76, 230) # beside the head, clear of the weapon
		arrow.pressed.connect(_cycle.bind(side))
		stage.add_child(arrow)


const TITLE_H := 60.0 # the worn title's plate over the stage name
const HEAD_Y := 40.0 # stage y of the name (the plate rises above it)


const PEDESTAL_AT := 528.0 # stage y of the pedestal centre (the character's feet)


func _draw_pedestal(c: Control) -> void:
	var tex := Art.env("pedestal")
	c.draw_texture(tex, Vector2(STAGE.x / 2, PEDESTAL_AT) - Art.PEDESTAL_CENTER) # assets/env/pedestal.png


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position.x
		elif _drag_from >= 0.0:
			var dx: float = event.position.x - _drag_from
			_drag_from = -1.0
			if absf(dx) >= SWIPE:
				_cycle(-1 if dx > 0 else 1) # drag right shows the previous one


func _cycle(delta: int) -> void:
	_picked = true
	_model.select_character(LobbyModel.cycle_character(_model.character_id, delta))
	_model.remember(settings_path)
	_render_character()
	_send_character()


## The id of the character on the stage.
func character_id() -> String:
	return _model.character_id


## Puts `id` on the stage and remembers it (the Nhân vật page's ◀ ▶).
func select_character(id: String) -> void:
	_picked = true
	_model.select_character(id)
	_model.remember(settings_path)
	_render_character()
	_send_character()


## Until the player picks one here, the stage shows LoadoutModel.start_character(): the device's
## choice, else the profile's currentCharacterId, else the first owned one, never one the
## characters cache says is not owned (no character is free: a Spark-only player never lands on
## Rookie). Saved, so the Loadout opens with it. Run again when the profile or the characters load.
func _auto_pick() -> void:
	if _picked:
		return
	var start := LoadoutModel.start_character(settings_path, PlayerState.profile, PlayerState.characters)
	if start == "":
		return
	var changed := start != _model.character_id
	_model.select_character(start)
	if LoadoutModel.saved_character(settings_path) != start:
		_model.remember(settings_path)
	if changed and _art != null:
		_render_character()
		_send_character()


## With a teammate in the lobby: the stage character (one I own) goes to it, their slot shows it.
func _send_character() -> void:
	if LobbyModel.character_info(_model.character_id, PlayerState.characters)["owned"] == true:
		Router.party.set_character(_model.character_id)


# ── Info card ───────────────────────────────────────────────────────────────

## The selected character's compact card (character_card.gd): element chain, skill, Lực chiến,
## heart / sword / shield, "Mua ở Shop" when not owned.
func _build_info_card() -> Control:
	_info = CharacterCard.make()
	_info.buy_pressed.connect(func(): open_shop.emit(ShopTab.CHARACTERS))
	return _info


func _render_character() -> void:
	if _art == null:
		return
	var id := _model.character_id
	var info := LobbyModel.character_info(id, PlayerState.characters)
	var level := LobbyModel.level_text(info)
	_art.character_id = id
	_art.modulate = Color(0.72, 0.72, 0.8) if info["owned"] == false else Color.WHITE
	_gun_stand.modulate = _art.modulate
	_render_gun()
	_stage_name.text = info["name"]
	ElementBadge.set_row_element(_stage_name_row, GameData.character_element(id))
	GlyphIcon.show_level(_stage_level, level)
	_info.popup_host = _host()
	_info.show_character(id, info)


## The stage character's gun under the pedestal (worn weapon or its basic gun).
func _render_gun() -> void:
	if _gun_stand == null:
		return
	var id := _model.character_id
	var g := EquipmentModel.worn_gun(PlayerState.equipment, PlayerState.catalog, id)
	_gun_stand.set_gun(g["kind"], g["tier"])


# ── Mode and start ──────────────────────────────────────────────────────────

func _build_mode_card() -> Control:
	var col := Ui.vbox(12)
	col.custom_minimum_size.x = 430
	var card := LobbyUi.panel(18, 20)
	card.name = "ModeCard"
	card.mouse_filter = MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_open_modes())
	col.add_child(card)
	var row := Ui.hbox(14)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(row)
	_mode_plate = Control.new() # the plate is swapped per mode (_render_mode)
	_mode_plate.custom_minimum_size = Vector2(MODE_PLATE, MODE_PLATE)
	_mode_plate.size_flags_vertical = SIZE_SHRINK_CENTER
	_mode_plate.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(_mode_plate)
	var texts := Ui.vbox(2)
	texts.mouse_filter = MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(texts)
	_mode_name = LobbyUi.text("", 32, Color.WHITE, true)
	_mode_name.name = "ModeName"
	_mode_name.clip_text = true
	_mode_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_mode_name)
	_mode_runs = Ui.hbox(6)
	_mode_runs.name = "ModeRuns"
	_mode_runs.mouse_filter = MOUSE_FILTER_IGNORE
	_mode_runs.visible = false
	var gift := LobbyUi.icon("milestone", 34)
	gift.mouse_filter = MOUSE_FILTER_IGNORE
	_mode_runs.add_child(gift)
	_mode_runs_text = LobbyUi.text("", 26, LobbyUi.GOLD, true)
	_mode_runs_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_runs.add_child(_mode_runs_text)
	texts.add_child(_mode_runs)
	_mode_lock = LobbyUi.text(ModeSelectModel.LOCKED_TEXT, 20, Ui.TEXT_DIM)
	_mode_lock.name = "ModeLock"
	_mode_lock.visible = false
	texts.add_child(_mode_lock)
	_mode_swap = LobbyUi.round_button("swap", 68, LobbyUi.ICON_COLORS["blue"], 0.6)
	_mode_swap.name = "ModeSwap"
	_mode_swap.size_flags_vertical = SIZE_SHRINK_CENTER
	_mode_swap.pressed.connect(_open_modes)
	row.add_child(_mode_swap)
	_start = LobbyUi.start_button("BẮT ĐẦU")
	_start.pressed.connect(_on_start)
	_start.resized.connect(func(): _start.pivot_offset = _start.size / 2)
	col.add_child(_start)
	var pulse := _start.create_tween().set_loops()
	pulse.tween_property(_start, "scale", Vector2(1.035, 1.035), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_start, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	return col


const MODE_PLATE := 68 # the mode card's icon plate
const MODE_NAME_W := 430 - 18 * 2 - MODE_PLATE - 68 - 14 * 2 # the card less its padding, plate, swap and gaps


## The swap button or a tap on the card: the Mode Select page; the party's member cannot (the host
## chooses).
func _open_modes() -> void:
	if Router.party.model.is_member():
		Ui.toast(self, ModeSelectModel.LOCKED_TEXT)
		return
	open_modes.emit()


## The chosen mode's index (Mode Select highlights it).
func current_mode() -> int:
	return _mode


## Mode Select's choice (ModeSelectModel.switch_action()): another party mode in my lobby moves it
## (SetLobbyQueue), a solo mode leaves it ("Rời đội?" first with a teammate).
func choose_mode(index: int) -> void:
	var party = Router.party.model
	match ModeSelectModel.switch_action(_mode, index, party.in_lobby(), party.is_member(), party.in_party(), party.member_count()):
		ModeSelectModel.SWITCH, ModeSelectModel.SET_QUEUE:
			_switch_mode(index)
		ModeSelectModel.LEAVE:
			Router.party.leave() # the lobby made for an invite, alone: no party to keep
			_switch_mode(index)
		ModeSelectModel.CONFIRM_LEAVE:
			_confirm_leave(_switch_mode.bind(index)) # "Rời đội?" first
		ModeSelectModel.LOCKED:
			Ui.toast(self, ModeSelectModel.LOCKED_TEXT)
		ModeSelectModel.NOTHING:
			if index == _mode and not party.is_member(): # the restored mode picked again: picked now
				Router.mode_chosen = true
				_render_background()
		ModeSelectModel.TOO_LARGE:
			Ui.toast(self, ModeSelectModel.TOO_LARGE_TEXT)


## The server refused SetLobbyQueue (PARTY_TOO_LARGE): Home shows the lobby's mode again.
func _on_queue_refused() -> void:
	show_queue_mode(Router.party.model.lobby_queue())


func _switch_mode(index: int) -> void:
	Router.mode_chosen = true
	_mode = clampi(index, 0, maxi(LobbyModel.modes().size() - 1, 0))
	LobbyModel.remember_mode(settings_path, _mode)
	Router.party.select_queue(_party_queue()) # my lobby follows a party mode's queue
	_render_mode()


## The queue the party plays: the chosen mode's when it is a party mode, else "".
func _party_queue() -> String:
	return str(mode_base().get("queue", "")) if LobbyModel.is_party(_mode) else ""


## Shows the mode of `queue` and remembers it (an invite accepted from any mode: the lobby's queue).
func show_queue_mode(queue: String) -> void:
	var i := LobbyModel.index_of_queue(queue)
	if i < 0:
		return
	Router.mode_chosen = true
	if i == _mode:
		_render_background()
		return
	_mode = i
	LobbyModel.remember_mode(settings_path, _mode)
	_render_mode()


## "Rời đội?": Rời đội sends LeaveLobby, then `then` (the mode switch) when given.
func _confirm_leave(then: Callable) -> void:
	var m := Modal.new()
	m.open(_host(), "Rời đội?", 640)
	m.add_text("Bạn sẽ rời đội hiện tại và không chơi cùng đồng đội này nữa.")
	m.add_button("Ở lại", m.close)
	var leave := m.add_button("Rời đội", func() -> void:
		m.close()
		Router.party.leave()
		if then.is_valid():
			then.call())
	leave.name = "ConfirmLeave"


## The invite popup ("Mời đồng đội").
func open_invite() -> InvitePopup:
	var popup := InvitePopup.new()
	popup.open_for(_host(), Router.party)
	return popup


## Where dialogs go: Home (the screen root) when the lobby is in it.
func _host() -> Node:
	var p := get_parent()
	return p if p is Control else self


func _render_mode() -> void:
	if _mode_name == null:
		return
	var party = Router.party.model
	var member: bool = party.is_member()
	if member: # the host's mode
		var i := LobbyModel.index_of_queue(party.lobby_queue())
		if i >= 0:
			Router.mode_chosen = true # the host's pick
		if i >= 0 and i != _mode:
			_mode = i
			LobbyModel.remember_mode(settings_path, _mode)
	_mode_lock.visible = member
	_mode_swap.disabled = member
	var m: Dictionary = LobbyModel.mode(_mode)
	_mode_name.text = m["name"]
	_mode_name.add_theme_font_size_override("font_size", 32)
	ElementBadge.shrink_to_fit(_mode_name, MODE_NAME_W, 22) # a long boss name stays whole
	Ui.clear(_mode_plate)
	var plate := ModeSelect.plate(ModeSelectModel.icon_of(m["icon"]), MODE_PLATE, ModeSelect.plate_color(ModeSelectModel.order_in_section(_mode)))
	_mode_plate.add_child(plate)
	var boss: bool = m["category"] == BossCardModel.CATEGORY
	if boss and is_visible_in_tree():
		PlayerState.load_boss_runs() # (an answer at once re-renders: read the runs after it)
	var c := BossCardModel.card(_mode, m, _mode, PlayerState.my_boss_runs(), 0) if boss else {}
	_mode_runs.visible = boss and not member and str(c.get("runs_text", "")) != ""
	if boss: # the big-reward runs left today
		_mode_runs_text.text = str(c["runs_text"])
		_mode_runs.modulate = Color(1, 1, 1, 0.45) if int(c["runs_left"]) == 0 else Color.WHITE
	_render_party()
	_render_background()


## The stage's background key: lobby_bg until a mode is picked this session, then the mode's.
func background() -> String:
	return LobbyModel.stage_background(_mode, Router.mode_chosen)


func _render_background() -> void:
	var key := background()
	if key != _background:
		_background = key
		background_changed.emit(key)


const SLOT_X := STAGE.x / 2.0 + 175.0 # the teammate slot's centre right of the stage's centre
const SLOT_Y := -240.0 # its bottom above the screen's bottom: the pedestal clear of the mode card


## The host's × on a slot: KickMember for the member shown there.
func _kick(slot: PartySlot) -> void:
	var id := str(slot.member().get("playerId", ""))
	if id != "":
		Router.party.kick(id)


## The slots shown for the mode (PartyLayout); tests and the preview harness.
func party_slots() -> Array:
	return _slots.filter(func(s): return s.visible)


## A party mode's teammate slots (PartyLayout.slots() of its party size, the lobby's other members
## in them) and the start button (PartyModel.start_button()).
func _render_party() -> void:
	if _slots.is_empty() or _start == null:
		return
	var party = Router.party.model
	var with_party := LobbyModel.is_party(_mode)
	var capacity := int(LobbyModel.mode(_mode)["party_size"]) if with_party else 1
	var layout := PartyLayout.slots(capacity)
	var shown := PartyLayout.fill(party.teammates(), capacity)
	var host_view: bool = not party.is_member()
	# real frame art on any teammate: every slot shrinks the same way, the art inside its rect
	var fit := GradeFrame.any_art(shown.map(func(m): return str(m.get("rankBadge", "")) if m is Dictionary else ""))
	for i in _slots.size():
		var slot := _slots[i]
		slot.visible = i < layout.size()
		if not slot.visible:
			continue
		var at: Dictionary = layout[i]
		var k: float = float(at["scale"])
		slot.scale = Vector2.ONE * k
		slot.pivot_offset = Vector2(PartySlot.SIZE.x / 2.0, PartySlot.SIZE.y)
		slot.offset_left = float(at["x"])
		slot.offset_right = float(at["x"])
		slot.offset_top = float(at["y"])
		slot.offset_bottom = float(at["y"])
		var m: Dictionary = shown[i]
		slot.fit_art = fit
		slot.show_member(m, host_view, str(m.get("playerId", "")) == str(party.lobby.get("hostPlayerId", "")), host_view)
	var state: Dictionary = party.start_button() if with_party else {"text": "BẮT ĐẦU", "disabled": false, "action": "start"}
	_start.text = state["text"]
	_start.disabled = state["disabled"]
	_start.set_meta("action", state["action"])
	_start.add_theme_font_size_override("font_size", 40 if str(state["text"]).length() <= 14 else 30)


## The QuickPlay base of the chosen mode.
func mode_base() -> Dictionary:
	return LobbyModel.mode_base(_mode)


func _on_start() -> void:
	if LobbyModel.is_party(_mode) and str(_start.get_meta("action", "start")) == "unready":
		Router.party.set_ready(false) # HUỶ SẴN SÀNG
		return
	start() # the member's SẴN SÀNG: the Loadout readies


## What BẮT ĐẦU does (also a daily mission's "Đi ngay"): the mode's QuickPlay base, then the
## Loadout.
func start() -> void:
	Router.quick_play_base = mode_base()
	Router.go(Router.LOADOUT)
