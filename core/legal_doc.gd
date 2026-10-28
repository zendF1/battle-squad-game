extends RefCounted
## The terms of service ("terms") and the privacy policy ("privacy") as the server sends them
## (GET /legal/{id}: {id, title, version, updatedAt "YYYY-MM-DD", sections: [{heading, paragraphs}]},
## a paragraph starting with "• " is a bullet line). The text is the server's: the client only
## shows it (ui/legal_popup.gd). Each document is cached in user://legal/<id>.json with its version
## and ETag, replaced when the server sends another version, and shown when the server cannot be
## reached.

const IDS := ["terms", "privacy"]
const CACHE_DIR := "user://legal"
const BULLET := "• "

static var cache_dir := CACHE_DIR


## The request path of a document.
static func path(id: String) -> String:
	return "/legal/%s?lang=vi" % id


## A server answer's data as a document, {} when it is not one (no title or no section with text).
static func parse(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var sections: Array = []
	var raw = data.get("sections")
	if raw is Array:
		for s in raw:
			if not s is Dictionary:
				continue
			var paragraphs: Array[String] = []
			var ps = s.get("paragraphs")
			if ps is Array:
				for p in ps:
					var t := str(p).strip_edges()
					if t != "":
						paragraphs.append(t)
			var heading := str(s.get("heading", "")).strip_edges()
			if heading != "" or not paragraphs.is_empty():
				sections.append({"heading": heading, "paragraphs": paragraphs})
	var title := str(data.get("title", "")).strip_edges()
	if title == "" or sections.is_empty():
		return {}
	return {
		"id": str(data.get("id", "")),
		"title": title,
		"version": str(data.get("version", "")),
		"updatedAt": str(data.get("updatedAt", "")),
		"sections": sections,
	}


## "2026-10-28" → "28/10/2026"; any other text as it is.
static func date_text(updated_at: String) -> String:
	var parts := updated_at.substr(0, 10).split("-")
	if parts.size() == 3 and parts[0].length() == 4 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int():
		return "%s/%s/%s" % [parts[2], parts[1], parts[0]]
	return updated_at


## The line under the title: "Cập nhật: 28/10/2026", "" without a date.
static func updated_line(doc: Dictionary) -> String:
	var d := date_text(str(doc.get("updatedAt", "")))
	return "" if d == "" else "Cập nhật: %s" % d


static func is_bullet(paragraph: String) -> bool:
	return paragraph.begins_with(BULLET) or paragraph.begins_with("•")


## A bullet line's text without its "• ".
static func bullet_text(paragraph: String) -> String:
	return paragraph.trim_prefix("•").strip_edges()


static func cache_path(id: String) -> String:
	return "%s/%s.json" % [cache_dir, id]


## The cached copy of a document: {doc, etag}, {} when there is none (or cache_dir is "").
static func load_cached(id: String) -> Dictionary:
	if cache_dir == "" or not FileAccess.file_exists(cache_path(id)):
		return {}
	var saved = JSON.parse_string(FileAccess.get_file_as_string(cache_path(id)))
	if not saved is Dictionary:
		return {}
	var doc := parse(saved.get("doc"))
	if doc.is_empty():
		return {}
	return {"doc": doc, "etag": str(saved.get("etag", ""))}


static func save_cached(id: String, doc: Dictionary, etag: String) -> void:
	if cache_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var f := FileAccess.open(cache_path(id), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"doc": doc, "etag": etag}))


## What to show after a request (an Api result: {ok, status, data, etag}) given the cached copy
## (load_cached()): {doc, save} (save: write the answer to the cache) or {} when there is nothing to
## show (offline with no cache, or a broken answer with no cache). A 304 keeps the cache; a new
## version replaces it; a failure falls back to it.
static func resolve(res: Dictionary, cached: Dictionary) -> Dictionary:
	var old: Dictionary = cached.get("doc", {})
	if res.get("ok", false):
		if int(res.get("status", 200)) == 304:
			return {"doc": old, "save": false} if not old.is_empty() else {}
		var doc := parse(res.get("data"))
		if not doc.is_empty():
			var changed: bool = old.is_empty() or str(old.get("version", "")) != doc.version \
				or str(cached.get("etag", "")) != str(res.get("etag", "")) or old != doc
			return {"doc": doc, "save": changed}
	return {"doc": old, "save": false} if not old.is_empty() else {}
