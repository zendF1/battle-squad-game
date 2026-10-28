extends Control
## The terms of service / privacy policy popup (core/legal_doc.gd), opened from the login screen's
## terms tick (ui/consent_row.gd). A white page over a dim backdrop: the title and its last-updated
## date centred on top between two same-size buttons (left: open the document in the browser at the
## configured URL; right: close), then the sections scrolling (heading, paragraphs, "• " bullet lines
## with a hanging indent). The text comes from GET /legal/{id} (no login needed): the cached copy
## shows at once and is replaced when the server sends a newer one; with no cache and no server, a
## short error with a retry button. Escape / back, the X or a tap outside the page closes it.

const LegalDoc := preload("res://core/legal_doc.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")

## The page's largest width, and its least gap to the screen's edges.
const MAX_WIDTH := 1120.0
const MARGIN := Vector2(40, 32)
const PADDING := 30
const BUTTON_PX := 56
const TITLE_SIZE := 34
const DATE_SIZE := 20
const HEADING_SIZE := 27
const TEXT_SIZE := 23
const BULLET_INDENT := 30
const PAGE := Color(0.985, 0.985, 1.0)
const EDGE := Color(0.09, 0.14, 0.38, 0.35)
const NAVY := Color(0.09, 0.14, 0.38)
const TEXT := Color(0.12, 0.13, 0.2)
const DIM := Color(0.36, 0.39, 0.5)
const RULE := Color(0.09, 0.14, 0.38, 0.14)
const OFFLINE_TEXT := "Không tải được nội dung. Kiểm tra kết nối mạng rồi thử lại."

var doc_id := ""
var url := ""
## The request: func(path: String, etag: String) -> Dictionary (an Api result); Api.get_cached by
## default (a smoke run or a test passes its own).
var fetch := Callable()
## The document shown, {} while loading or failed.
var shown: Dictionary = {}

var page: PanelContainer
var title_label: Label
var date_label: Label
var browser_button: Button
var close_button: Button
var scroll: ScrollContainer
var content: VBoxContainer
var status_box: VBoxContainer
var status_label: Label
var retry_button: Button
var _backdrop_down := false


## Opens the popup of document `id` ("terms" / "privacy") over `host`; `link` is the document's web
## page (the browser button, hidden when ""). Starts loading at once.
static func open(host: Node, id: String, link: String = "", fetcher: Callable = Callable()) -> Control:
	var p = new()
	p.doc_id = id
	p.url = link
	p.fetch = fetcher
	host.add_child(p)
	p.reload()
	return p


func _init() -> void:
	name = "LegalPopup"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Backdrop"
	dim.color = Color(0.01, 0.02, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_backdrop_input)
	add_child(dim)
	page = PanelContainer.new()
	page.name = "Page"
	page.mouse_filter = MOUSE_FILTER_STOP
	var box := LobbyUi.box(PAGE, 22, PADDING, EDGE, 2)
	box.content_margin_top = 22
	box.content_margin_bottom = 18
	box.content_margin_right = 14 # the scroll bar sits in the right padding
	box.shadow_color = Color(0.0, 0.02, 0.1, 0.4)
	box.shadow_size = 14
	box.shadow_offset = Vector2(0, 4)
	page.add_theme_stylebox_override("panel", box)
	add_child(page)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	page.add_child(col)
	col.add_child(_header())
	var rule := ColorRect.new()
	rule.color = RULE
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var body := Control.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(body)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_style_scroll_bar(scroll.get_v_scroll_bar())
	body.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", PADDING - 14 + 4)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	scroll.add_child(pad)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = MOUSE_FILTER_IGNORE
	pad.add_child(content)
	body.add_child(_status())
	resized.connect(_layout)


func _ready() -> void:
	_layout()


## Asks the server for the document again (the cached copy, if any, shows meanwhile).
func reload() -> void:
	var cached := LegalDoc.load_cached(doc_id)
	if not cached.is_empty():
		show_doc(cached["doc"])
	else:
		show_loading()
	var res: Dictionary
	if fetch.is_valid():
		res = await fetch.call(LegalDoc.path(doc_id), str(cached.get("etag", "")))
	else:
		res = await Api.get_cached(LegalDoc.path(doc_id), str(cached.get("etag", "")))
	if is_queued_for_deletion():
		return
	var out := LegalDoc.resolve(res, cached)
	if out.is_empty():
		show_error()
		return
	if out["save"]:
		LegalDoc.save_cached(doc_id, out["doc"], str(res.get("etag", "")))
	if out["doc"] != shown:
		show_doc(out["doc"])


## Fills the page with `doc` (LegalDoc.parse()), scrolled to the top.
func show_doc(doc: Dictionary) -> void:
	shown = doc
	title_label.text = str(doc.get("title", ""))
	date_label.text = LegalDoc.updated_line(doc)
	date_label.visible = date_label.text != ""
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var first := true
	for s in doc.get("sections", []):
		if str(s.get("heading", "")) != "":
			var h := _label(str(s["heading"]), HEADING_SIZE, NAVY, true)
			h.set_meta("kind", "heading")
			if not first:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 10)
				gap.mouse_filter = MOUSE_FILTER_IGNORE
				content.add_child(gap)
			content.add_child(h)
		first = false
		for p in s.get("paragraphs", []):
			content.add_child(_bullet(LegalDoc.bullet_text(p)) if LegalDoc.is_bullet(p) else _paragraph(p))
	scroll.visible = true
	status_box.visible = false
	scroll.scroll_vertical = 0


func show_loading() -> void:
	_show_status("Đang tải...", false)


func show_error() -> void:
	_show_status(OFFLINE_TEXT, true)


func close() -> void:
	queue_free()


func _show_status(text: String, failed: bool) -> void:
	shown = {}
	if title_label.text == "":
		title_label.text = "Điều khoản dịch vụ" if doc_id == "terms" else "Chính sách bảo mật"
	date_label.visible = false
	scroll.visible = false
	status_box.visible = true
	status_label.text = text
	status_box.get_node("Offline").visible = failed
	retry_button.visible = failed


func _header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 16)
	browser_button = _round_button("Mở trong trình duyệt")
	browser_button.name = "Browser"
	var g = GlyphIcon.make("browser", BUTTON_PX)
	g.custom_minimum_size = Vector2.ZERO # inset in the button below
	g.set_anchors_preset(PRESET_FULL_RECT)
	var inset := BUTTON_PX * 0.2
	g.offset_left = inset
	g.offset_top = inset
	g.offset_right = -inset
	g.offset_bottom = -inset
	browser_button.add_child(g)
	browser_button.pressed.connect(_open_browser)
	row.add_child(browser_button)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 2)
	titles.mouse_filter = MOUSE_FILTER_IGNORE
	title_label = _label("", TITLE_SIZE, NAVY, true)
	title_label.name = "Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(title_label)
	date_label = _label("", DATE_SIZE, DIM, false)
	date_label.name = "Updated"
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titles.add_child(date_label)
	row.add_child(titles)
	close_button = _round_button("Đóng")
	close_button.name = "Close"
	LobbyUi.set_icon(close_button, "close", int(BUTTON_PX * 0.5))
	close_button.expand_icon = true
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	close_button.pressed.connect(close)
	row.add_child(close_button)
	return row


## The browser button keeps its place without a URL (hidden but laid out), so the title stays centred.
func _round_button(tip: String) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.focus_mode = FOCUS_NONE
	LobbyUi.texture_button(b, "button_navy", 0)
	b.custom_minimum_size = Vector2(BUTTON_PX, BUTTON_PX)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	return b


func _status() -> VBoxContainer:
	status_box = VBoxContainer.new()
	status_box.name = "Status"
	status_box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	status_box.add_theme_constant_override("separation", 18)
	status_box.visible = false
	var g = GlyphIcon.make("offline", 96)
	g.name = "Offline"
	status_box.add_child(g)
	status_label = _label("", TEXT_SIZE, DIM, true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_box.add_child(status_label)
	retry_button = Button.new()
	retry_button.name = "Retry"
	retry_button.tooltip_text = "Thử lại"
	retry_button.focus_mode = FOCUS_NONE
	retry_button.flat = true
	retry_button.custom_minimum_size = Vector2(84, 84)
	retry_button.size_flags_horizontal = SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		retry_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var r = GlyphIcon.make("retry", 84)
	r.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	retry_button.add_child(r)
	retry_button.button_down.connect(func() -> void: r.modulate = Color(0.8, 0.8, 0.8))
	retry_button.button_up.connect(func() -> void: r.modulate = Color.WHITE)
	retry_button.pressed.connect(reload)
	status_box.add_child(retry_button)
	return status_box


func _label(text: String, font_size: int, color: Color, heavy: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 1 # wraps to the width it gets instead of asking for its text's width
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if heavy:
		l.add_theme_font_override("font", LobbyUi.bold())
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l


func _paragraph(text: String) -> Label:
	var l := _label(text, TEXT_SIZE, TEXT, false)
	l.set_meta("kind", "paragraph")
	l.add_theme_constant_override("line_spacing", 4)
	return l


## A bullet line: the dot, then the text wrapping under itself (a hanging indent).
func _bullet(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta("kind", "bullet")
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	var dot := _label("•", TEXT_SIZE, NAVY, true)
	dot.size_flags_horizontal = SIZE_FILL
	dot.custom_minimum_size.x = BULLET_INDENT
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.autowrap_mode = TextServer.AUTOWRAP_OFF
	dot.size_flags_vertical = SIZE_SHRINK_BEGIN # on the first line of a long bullet
	row.add_child(dot)
	row.add_child(_paragraph(text))
	return row


func _layout() -> void:
	var w := minf(MAX_WIDTH, size.x - MARGIN.x * 2.0)
	var h := size.y - MARGIN.y * 2.0
	page.size = Vector2(w, h)
	page.position = (size - page.size) / 2.0


func _style_scroll_bar(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(NAVY, 0.08)
	track.set_corner_radius_all(5)
	track.content_margin_left = 5
	track.content_margin_right = 5
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var g := StyleBoxFlat.new()
		g.bg_color = Color(NAVY, 0.45 if state == "grabber" else 0.65)
		g.set_corner_radius_all(5)
		bar.add_theme_stylebox_override(state, g)


func _open_browser() -> void:
	if url != "":
		OS.shell_open(url)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		browser_button.modulate.a = 1.0 if url != "" else 0.0
		browser_button.disabled = url == ""
		browser_button.mouse_filter = MOUSE_FILTER_STOP if url != "" else MOUSE_FILTER_IGNORE
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Only a press that starts on the backdrop and is released there closes (the tap that opened the
## popup never does).
func _on_backdrop_input(event: InputEvent) -> void:
	var pressed: bool
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	else:
		return
	if pressed:
		_backdrop_down = true
	elif _backdrop_down:
		_backdrop_down = false
		close()
