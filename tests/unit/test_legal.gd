extends "res://tests/test_case.gd"
## The terms / privacy documents (core/legal_doc.gd: GET /legal/{id} parsed, cached per version,
## shown offline from the cache) and their popup (ui/legal_popup.gd), from a real server answer
## (tests/fixtures/legal_terms.json).

const LegalDoc := preload("res://core/legal_doc.gd")
const LegalPopup := preload("res://ui/legal_popup.gd")
const ConsentRow := preload("res://ui/consent_row.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const ApiResponse := preload("res://core/api_response.gd")

const FIXTURE := "res://tests/fixtures/legal_terms.json"
const TEST_DIR := "user://test_legal"
const OFFLINE := {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "network error (2)", "data": null, "etag": ""}


static func _answer(etag: String = "\"terms-vi-1.0\"") -> Dictionary:
	var body := FileAccess.get_file_as_string(FIXTURE).to_utf8_buffer()
	var res := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 200, body)
	res["etag"] = etag
	return res


static func _doc() -> Dictionary:
	return LegalDoc.parse(_answer().data)


func _clean_cache() -> void:
	for id in LegalDoc.IDS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR + "/%s.json" % id))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))


func test_parses_the_server_answer() -> void:
	var doc := _doc()
	eq(doc.id, "terms", "id")
	eq(doc.title, "Điều khoản dịch vụ", "title")
	eq(doc.version, "1.0", "version")
	eq(doc.updatedAt, "2026-10-28", "date")
	eq(doc.sections.size(), 9, "every section")
	eq(doc.sections[0].heading, "", "an untitled lead section kept")
	eq(doc.sections[0].paragraphs.size(), 1, "its paragraph")
	eq(doc.sections[1].heading, "1. Chấp nhận điều khoản", "headings in order")
	check(LegalDoc.is_bullet(doc.sections[1].paragraphs[1]), "a bullet line")
	check(not LegalDoc.is_bullet(doc.sections[1].paragraphs[0]), "a plain paragraph")
	check(not LegalDoc.bullet_text(doc.sections[1].paragraphs[1]).begins_with("•"), "the dot dropped from the text")
	eq(LegalDoc.path("privacy"), "/legal/privacy?lang=vi", "request path")


func test_rejects_what_is_not_a_document() -> void:
	eq(LegalDoc.parse(null), {}, "no data")
	eq(LegalDoc.parse([]), {}, "not an object")
	eq(LegalDoc.parse({"title": "X", "sections": []}), {}, "no section")
	eq(LegalDoc.parse({"title": "", "sections": [{"heading": "A", "paragraphs": ["b"]}]}), {}, "no title")
	var doc := LegalDoc.parse({"title": "X", "sections": [{"heading": " ", "paragraphs": ["", "  "]}, {"heading": "A", "paragraphs": ["b", 3]}]})
	eq(doc.sections.size(), 1, "empty sections dropped")
	eq(doc.sections[0].paragraphs, ["b", "3"] as Array[String], "paragraphs as text")


func test_date_line() -> void:
	eq(LegalDoc.date_text("2026-10-28"), "28/10/2026", "day/month/year")
	eq(LegalDoc.date_text("2026-10-28T00:00:00Z"), "28/10/2026", "a timestamp's date")
	eq(LegalDoc.date_text("soon"), "soon", "other text as it is")
	eq(LegalDoc.updated_line(_doc()), "Cập nhật: 28/10/2026", "under the title")
	eq(LegalDoc.updated_line({}), "", "no date, no line")


func test_cache_per_version() -> void:
	LegalDoc.cache_dir = TEST_DIR
	_clean_cache()
	var doc := _doc()
	eq(LegalDoc.load_cached("terms"), {}, "no cache at first")
	var first := LegalDoc.resolve(_answer(), {})
	eq(first.doc, doc, "the answer shown")
	check(first.save, "a first answer is cached")
	LegalDoc.save_cached("terms", first.doc, "\"terms-vi-1.0\"")
	var cached := LegalDoc.load_cached("terms")
	eq(cached.doc, doc, "the cached copy reads back")
	eq(cached.etag, "\"terms-vi-1.0\"", "with its ETag")
	eq(LegalDoc.load_cached("privacy"), {}, "one file per document")
	check(not LegalDoc.resolve(_answer(), cached).save, "the same version is not written again")
	var not_modified := LegalDoc.resolve({"ok": true, "status": 304, "data": null, "etag": "\"terms-vi-1.0\""}, cached)
	eq(not_modified.doc, doc, "304: the cached copy")
	check(not not_modified.save, "304: nothing to write")
	eq(LegalDoc.resolve({"ok": true, "status": 304, "data": null}, {}), {}, "304 with no cache: nothing to show")
	var newer := _answer("\"terms-vi-1.1\"")
	newer.data["version"] = "1.1"
	newer.data["sections"][1]["paragraphs"].append("• Một dòng mới.")
	var updated := LegalDoc.resolve(newer, cached)
	eq(updated.doc.version, "1.1", "a new version replaces the cache")
	check(updated.save, "and is written")
	_clean_cache()
	LegalDoc.cache_dir = LegalDoc.CACHE_DIR


func test_offline() -> void:
	var cached := {"doc": _doc(), "etag": "\"terms-vi-1.0\""}
	eq(LegalDoc.resolve(OFFLINE, cached).doc, cached.doc, "offline: the cached copy")
	eq(LegalDoc.resolve(OFFLINE, {}), {}, "offline with no cache: the error")
	eq(LegalDoc.resolve({"ok": true, "status": 200, "data": {"title": "X"}, "etag": ""}, {}), {}, "a broken answer: the error")
	var not_found := {"ok": false, "status": 404, "code": "NOT_FOUND", "message": "", "data": null}
	eq(LegalDoc.resolve(not_found, cached).doc, cached.doc, "a server error: the cached copy")


func test_popup_shows_the_document() -> void:
	var p = LegalPopup.new()
	p.show_doc(_doc())
	eq(p.title_label.text, "Điều khoản dịch vụ", "title")
	eq(p.date_label.text, "Cập nhật: 28/10/2026", "date")
	var headings := 0
	var bullets := 0
	var paragraphs := 0
	for c in p.content.get_children():
		match c.get_meta("kind", ""):
			"heading": headings += 1
			"bullet": bullets += 1
			"paragraph": paragraphs += 1
	eq(headings, 8, "a heading per titled section (the lead has none)")
	eq(bullets, 11, "every bullet line")
	eq(paragraphs, 11, "every plain paragraph")
	check(p.scroll.visible and not p.status_box.visible, "the text shown")
	p.show_error()
	check(not p.scroll.visible and p.status_box.visible and p.retry_button.visible, "the error with its retry")
	eq(p.status_label.text, LegalPopup.OFFLINE_TEXT, "a short reason")
	p.show_loading()
	check(not p.retry_button.visible, "no retry while loading")
	p.free()


func test_popup_loads_caches_and_falls_back() -> void:
	LegalDoc.cache_dir = TEST_DIR
	_clean_cache()
	var calls: Array = []
	var p = LegalPopup.new()
	p.doc_id = "terms"
	p.fetch = func(path: String, etag: String) -> Dictionary:
		calls.append([path, etag])
		return OFFLINE
	p.reload()
	check(p.status_box.visible and p.retry_button.visible, "offline with no cache: the error")
	eq(p.title_label.text, "Điều khoản dịch vụ", "the document's name over the error")
	p.fetch = func(path: String, etag: String) -> Dictionary:
		calls.append([path, etag])
		return _answer()
	p.reload()
	check(p.scroll.visible, "retry: the text")
	eq(LegalDoc.load_cached("terms").doc, _doc(), "cached")
	p.fetch = func(path: String, etag: String) -> Dictionary:
		calls.append([path, etag])
		return OFFLINE
	p.reload()
	check(p.scroll.visible and not p.status_box.visible, "offline again: the cached copy")
	eq(calls[0], ["/legal/terms?lang=vi", ""], "no ETag without a cache")
	eq(calls[2], ["/legal/terms?lang=vi", "\"terms-vi-1.0\""], "the cached ETag sent")
	p.free()
	_clean_cache()
	LegalDoc.cache_dir = LegalDoc.CACHE_DIR


func test_popup_title_stays_centred() -> void:
	var p = LegalPopup.new()
	eq(p.browser_button.custom_minimum_size, p.close_button.custom_minimum_size, "same-size buttons on both sides")
	var header: HBoxContainer = p.browser_button.get_parent()
	eq(header.get_child(0), p.browser_button, "browser left")
	eq(header.get_child(2), p.close_button, "close right")
	p.free()
	check(GlyphIcon.KINDS.has("browser"), "the browser glyph")


func test_consent_links_open_the_documents() -> void:
	var row := ConsentRow.new(400.0, false, "https://t", "https://p")
	var seen: Array = []
	row.link_pressed.connect(func(id: String) -> void: seen.append(id))
	row._on_link("terms")
	row._on_link("privacy")
	eq(seen, ["terms", "privacy"], "the document ids, not the browser")
	for id in seen:
		check(LegalDoc.IDS.has(id), "%s is a document" % id)
	row.free()
