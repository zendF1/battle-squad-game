extends "res://ui/modal.gd"
## The mailbox ("Hòm thư", PlayerState.my_mail(), MailboxModel), opened from the lobby's Hòm thư
## button. The list, newest first: one row per mail with its picture (a season reward: the
## insignia of its final grade, screens/ranked/grade_badge.gd; another mail: an envelope), its
## short title, its rewards as icons × N, a red dot while it wants a look (rewards to claim, or
## unread without rewards) and a check once claimed (claimed and expired rows dimmed); "Nhận tất
## cả" while one or more can be claimed. A tap on a row opens its detail (and marks it read): the
## picture, the final standing of a season reward, the text, the rewards as tiles
## (ui/reward_strip.gd), "Quay lại" and "Nhận". A claim is instant (fixed contents, already shown:
## no reward reveal): the icons fly to the wallet / bag (ui/reward_fly.gd) and the list shows again.

const MailboxModel := preload("res://screens/home/mailbox_model.gd")
const GradeBadge := preload("res://screens/ranked/grade_badge.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const RewardStrip := preload("res://ui/reward_strip.gd")
const RewardModel := preload("res://ui/reward_model.gd")
const RewardFly := preload("res://ui/reward_fly.gd")
const MilestonePage := preload("res://screens/home/milestone_page.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

const WIDTH := 880
const LIST_H := 452
const ROW_H := 96
const ROW_ICON := 72
const MINI_ICON := 40
const MINI_MAX := 3 # reward icons on a row; more show as "+N"
const DETAIL_ICON := 132
const TITLE := "Hòm thư"

var detail_id := "" # the mail whose detail shows; "" the list
var list: VBoxContainer # the rows (the list view)
var scroll: ScrollContainer
var claim_all_button: Button
var claim_button: Button
var back_button: Button
var _scroll_y := 0


static func open_on(host: Node):
	var p = load("res://screens/home/mailbox_popup.gd").new()
	p.name = "MailboxPopup"
	p.open_for(host)
	return p


func open_for(host: Node) -> void:
	open(host, TITLE, WIDTH)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_close_x()
	PlayerState.mail_changed.connect(render)
	PlayerState.load_mail()
	render()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _mail(id: String) -> Dictionary:
	for m in PlayerState.my_mail():
		if m["mailId"] == id:
			return m
	return {}


## Shows the list, or the detail of detail_id (the list when that mail is gone).
func render() -> void:
	if scroll != null and is_instance_valid(scroll):
		_scroll_y = scroll.scroll_vertical
	Ui.clear(body)
	Ui.clear(row(0))
	scroll = null
	list = null
	claim_all_button = null
	claim_button = null
	back_button = null
	var m := _mail(detail_id) if detail_id != "" else {}
	if m.is_empty():
		detail_id = ""
		_render_list()
	else:
		_render_detail(m)
	set_busy(PlayerState.mail_busy != "")


# ── List ────────────────────────────────────────────────────────────────────

func _render_list() -> void:
	title.text = TITLE
	var mails := PlayerState.my_mail()
	if mails.is_empty():
		_rows.visible = false
		var empty := Ui.vbox(10)
		empty.name = "Empty"
		empty.custom_minimum_size.y = 240
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		var art = GlyphIcon.make("mail", 120)
		art.modulate.a = 0.5
		empty.add_child(art)
		var l := LobbyUi.text("Chưa có thư", 24, Ui.TEXT_DIM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(l)
		body.add_child(empty)
		return
	list = Ui.vbox(10)
	list.name = "List"
	for mail in mails:
		list.add_child(_row(mail))
	scroll = Ui.scroll(list)
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(WIDTH - 2 * PADDING, mini(LIST_H, mails.size() * (ROW_H + 10) - 10))
	body.add_child(scroll)
	var y := _scroll_y
	(func() -> void: if is_instance_valid(scroll): scroll.scroll_vertical = y).call_deferred()
	var claimable := PlayerState.mail_unclaimed()
	_rows.visible = claimable > 0
	if claimable > 0:
		claim_all_button = add_button("Nhận tất cả", claim_all)
		claim_all_button.name = "ClaimAll"
		claim_all_button.custom_minimum_size.x = 300


## A mail's picture, `px` square: its grade's insignia or an envelope.
static func picture(m: Dictionary, px: int) -> Control:
	if MailboxModel.icon_kind(m) == "grade":
		var g := MailboxModel.grade_of(m)
		var badge := GradeBadge.make(g[0], g[1], px)
		badge.tooltip_text = MailboxModel.grade_text(m)
		badge.mouse_filter = MOUSE_FILTER_PASS
		badge.size_flags_horizontal = SIZE_SHRINK_CENTER
		badge.size_flags_vertical = SIZE_SHRINK_CENTER
		return badge
	return GlyphIcon.make("mail", px)


func _row(m: Dictionary) -> Button:
	var now := _now()
	var b := Button.new()
	b.name = "Mail_" + str(m["mailId"])
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	var attention := MailboxModel.is_claimable(m, now) or (not MailboxModel.has_rewards(m) and not MailboxModel.is_read(m))
	LobbyUi.style_button(b, Ui.CARD_SELECTED if attention else Ui.CARD_BG, 16, 0)
	b.pressed.connect(open_detail.bind(str(m["mailId"])))
	var h := Ui.hbox(16)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -18
	b.add_child(h)
	var pic := picture(m, ROW_ICON)
	pic.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(pic)
	var t := LobbyUi.text(MailboxModel.short_title(m), 24, Color.WHITE, true)
	t.name = "Title"
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	t.custom_minimum_size.x = 260 # "Thưởng Mùa 12" whole beside three rewards
	h.add_child(t)
	var tiles := MailboxModel.tiles(m["rewards"])
	var rewards := Ui.hbox(12)
	rewards.name = "Rewards"
	rewards.mouse_filter = MOUSE_FILTER_IGNORE
	for i in mini(tiles.size(), MINI_MAX):
		var one := Ui.hbox(2)
		one.mouse_filter = MOUSE_FILTER_IGNORE
		var icon := RewardStrip.tile_icon(tiles[i], MINI_ICON)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		one.add_child(icon)
		var n := LobbyUi.text(RewardStrip.count_text(tiles[i]), 18, Color.WHITE, true)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		one.add_child(n)
		rewards.add_child(one)
	if tiles.size() > MINI_MAX:
		var more := LobbyUi.text("+%d" % (tiles.size() - MINI_MAX), 18, Ui.TEXT_DIM, true)
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rewards.add_child(more)
	h.add_child(rewards)
	var mark := Control.new() # the dot / the check, one fixed slot so the rewards line up
	mark.name = "Mark"
	mark.custom_minimum_size = Vector2(36, 36)
	mark.size_flags_vertical = SIZE_SHRINK_CENTER
	mark.mouse_filter = MOUSE_FILTER_IGNORE
	if MailboxModel.is_claimed(m):
		var check = GlyphIcon.make("check", 36)
		check.name = "Check"
		mark.add_child(check)
	elif attention:
		var dot := MilestonePage.dot(18)
		dot.name = "Dot"
		dot.position = Vector2(9, 9)
		mark.add_child(dot)
	h.add_child(mark)
	if MailboxModel.is_claimed(m) or MailboxModel.is_expired(m, now):
		b.modulate = Color(1, 1, 1, 0.55)
	return b


## Opens the detail of `id` and marks it read.
func open_detail(id: String) -> void:
	detail_id = id
	set_message("")
	PlayerState.mark_mail_read(id) # its mail_changed renders the detail
	render()


func back_to_list() -> void:
	detail_id = ""
	set_message("")
	render()


# ── Detail ──────────────────────────────────────────────────────────────────

func _render_detail(m: Dictionary) -> void:
	title.text = MailboxModel.short_title(m)
	var now := _now()
	var pic := picture(m, DETAIL_ICON)
	pic.name = "Picture"
	pic.size_flags_horizontal = SIZE_SHRINK_CENTER
	body.add_child(pic)
	var standing := MailboxModel.standing_text(m)
	if standing != "":
		var s := LobbyUi.text(standing, 22, Ui.TEXT_DIM)
		s.name = "Standing"
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(s)
	if str(m["body"]) != "":
		var text := LobbyUi.text(str(m["body"]), 22)
		text.name = "Body"
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = WIDTH - 2 * PADDING
		body.add_child(text)
	if MailboxModel.has_rewards(m):
		var tiles := RewardStrip.new()
		tiles.name = "Tiles"
		tiles.max_rows = 2
		var w := WIDTH - 2 * PADDING
		tiles.custom_minimum_size = Vector2(w, RewardStrip.TILE.y)
		body.add_child(tiles)
		tiles.size = Vector2(w, RewardStrip.TILE.y)
		tiles.set_tiles(MailboxModel.tiles(m["rewards"]))
		if MailboxModel.is_claimed(m) or MailboxModel.is_expired(m, now):
			tiles.modulate = Color(1, 1, 1, 0.55)
	_rows.visible = true
	back_button = add_button("Quay lại", back_to_list)
	back_button.name = "Back"
	if MailboxModel.is_claimable(m, now):
		claim_button = add_button("Nhận", claim)
		claim_button.name = "Claim"
	elif MailboxModel.has_rewards(m):
		claim_button = add_button("Đã nhận" if MailboxModel.is_claimed(m) else "Hết hạn", func() -> void: pass)
		claim_button.name = "Claim"
		lock_button(claim_button)


func _centre(c: Control) -> Variant:
	return c.get_global_transform_with_canvas() * (c.size / 2.0) if is_instance_valid(c) and c.is_inside_tree() else null


## POST /mail/claim for the detail's mail: what it gave flies to the wallet / bag (no reveal) and
## the list shows again; a refusal shows its message.
func claim() -> Control:
	var m := _mail(detail_id)
	if m.is_empty() or PlayerState.mail_busy != "":
		return null
	var from: Variant = _centre(claim_button)
	set_message("")
	var res: Dictionary = await PlayerState.claim_mail(str(m["mailId"]))
	if is_queued_for_deletion(): # closed meanwhile
		return null
	if not res.ok:
		if str(res.get("code", "")) != "MAIL_ALREADY_CLAIMED":
			set_message(ErrorText.mail(res))
		return null
	detail_id = ""
	render()
	return _fly(MailboxModel.tiles(MailboxModel.granted(res.data, m["rewards"])), from)


## POST /mail/claim-all: everything it gave flies to the wallet / bag at once (no reveal).
func claim_all() -> Control:
	if PlayerState.mail_busy != "":
		return null
	var now := _now()
	var expected := {"coin": 0, "gem": 0, "items": []}
	for m in MailboxModel.claimable(PlayerState.my_mail(), now):
		expected["coin"] += int(m["rewards"]["coin"])
		expected["gem"] += int(m["rewards"]["gem"])
		expected["items"].append_array(m["rewards"]["items"])
	var from: Variant = _centre(claim_all_button)
	set_message("")
	var res: Dictionary = await PlayerState.claim_all_mail()
	if is_queued_for_deletion(): # closed meanwhile
		return null
	if not res.ok:
		set_message(ErrorText.mail(res))
		return null
	return _fly(MailboxModel.tiles(MailboxModel.granted(res.data, expected)), from)


func _fly(tiles: Array, from: Variant) -> Control:
	var host := get_parent()
	if tiles.is_empty() or not host is Control:
		return null
	return RewardFly.play(host, tiles, from)
