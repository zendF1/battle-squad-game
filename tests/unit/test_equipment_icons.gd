extends "res://tests/test_case.gd"
## The equipment icons imported from the AI-drawn sheets (tools/import_equipment.gd).

const Art := preload("res://ui/art.gd")
const ImportEquipment := preload("res://tools/import_equipment.gd")

const ITEMS := ["helmet", "armor", "gloves", "pants", "boots"]
const MAGENTA := Color8(250, 5, 245)


func test_config_and_sources() -> void:
	var cfg := ImportEquipment.load_config()
	eq(ImportEquipment.items_of(cfg), ITEMS, "equipment.json items: left → right on a sheet")
	eq(ImportEquipment.imported_slots(), ITEMS, "bake_art.gd skips these slots' icons")
	for tier in Art.EQUIP_TIERS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(ImportEquipment.SRC + tier + ".png"))
		check(img != null and not img.is_empty(), "sheet %s.png" % tier)
	eq(ImportEquipment.items_of({"items": ["helmet", "weapon"]}), [], "the weapon is not a sheet item")
	eq(ImportEquipment.items_of({"items": ["helmet", "ring"]}), [], "an unknown slot")
	eq(ImportEquipment.items_of({}), [], "no items")


func test_every_slot_and_tier_has_an_icon() -> void:
	var cfg := ImportEquipment.load_config()
	var margin := int(cfg.get("margin", 6))
	var box := Art.EQUIP_ICON_SIZE.x - 2 * margin
	var sparkly: Dictionary = cfg.get("sparkles", {})
	for slot in ITEMS:
		var ref := Rect2i()
		var all := Rect2i()
		for tier in Art.EQUIP_TIERS:
			var path := Art.equipment_icon_path(slot, tier)
			check(FileAccess.file_exists(path + ".import"), "%s has an .import" % path)
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img == null or img.is_empty():
				failures.append("%s missing" % path)
				continue
			img.convert(Image.FORMAT_RGBA8)
			eq(img.get_size(), Art.EQUIP_ICON_SIZE, "%s size" % path)
			var used := _opaque_rect(img)
			all = used if all.size == Vector2i.ZERO else all.merge(used)
			check(mini(used.size.x, used.size.y) >= box / 2, "%s: the item, not a speck (%s)" % [path, used])
			if not sparkly.has(tier): # a sparkle may reach into the margin
				check(used.position.x >= margin - 1 and used.position.y >= margin - 1 and used.end.x <= Art.EQUIP_ICON_SIZE.x - margin + 1
					and used.end.y <= Art.EQUIP_ICON_SIZE.y - margin + 1, "%s inside the margin (%s)" % [path, used])
			eq(_magenta(img), 0, "%s: no backdrop left" % path)
			eq(img.get_pixel(0, 0).a, 0.0, "%s: transparent, no backing" % path)
			if tier == "iron":
				ref = used
			elif tier == "steel": # the same outline on the sheet: the same size and place in the icon
				check(absi(used.position.x - ref.position.x) <= 2 and absi(used.position.y - ref.position.y) <= 2
					and absi(used.size.x - ref.size.x) <= 2 and absi(used.size.y - ref.size.y) <= 2, "%s: as big and where iron is (%s vs %s)" % [slot, used, ref])
		check(maxi(all.size.x, all.size.y) >= box - 3, "%s: the tiers together fill the icon (%s)" % [slot, all])
	check(Art.equipment_icon("boots", "diamond") != null, "boots_diamond loads")


func test_old_sparkle_tiers_keep_their_sparkles() -> void:
	var sp: Dictionary = ImportEquipment.load_config()["sparkles"]
	for tier in ["silver", "gold", "diamond", "dragon"]:
		check(sp.get(tier) is Dictionary and not sp[tier]["stars"].is_empty(), "%s sparkles" % tier)
	for tier in ["iron", "steel", "mithril", "titan"]:
		check(not sp.has(tier), "%s has none (as before)" % tier)
	check(not sp["dragon"]["slots"].has("helmet"), "no sparkle on the dragon helmet (as before)")


## A small sheet: three items left → right on magenta (a block; a pair of pieces overlapping in x;
## a frame with a pocket of backdrop inside and a strap end beside it), a sparkle far off.
func test_split_a_synthetic_sheet() -> void:
	var img := Image.create(240, 90, false, Image.FORMAT_RGBA8)
	img.fill(MAGENTA)
	var dark := Color(0.1, 0.1, 0.12)
	var grey := Color(0.55, 0.57, 0.6)
	img.fill_rect(Rect2i(10, 20, 40, 40), dark)
	img.fill_rect(Rect2i(13, 23, 34, 34), grey)
	img.fill_rect(Rect2i(70, 15, 22, 30), dark) # the pair: one item
	img.fill_rect(Rect2i(86, 48, 22, 30), dark)
	img.fill_rect(Rect2i(130, 20, 50, 50), dark) # a frame with a pocket of backdrop
	img.fill_rect(Rect2i(142, 32, 26, 26), MAGENTA)
	img.fill_rect(Rect2i(184, 40, 3, 3), dark) # a strap end 4 px off the frame
	img.fill_rect(Rect2i(222, 76, 4, 4), Color(1, 0.75, 1)) # the sparkle
	var cfg := ImportEquipment.load_config()
	var k := ImportEquipment.keyed(img, cfg)
	check(k["keyed"] > 0, "backdrop keyed")
	var got := ImportEquipment.split(img, 3, cfg["split"])
	eq(got["items"].size(), 3, "three items")
	if got["items"].size() != 3:
		return
	eq(got["items"][0]["rect"], Rect2i(10, 20, 40, 40), "the block")
	eq(got["items"][1]["rect"], Rect2i(70, 15, 38, 63), "the pair is one item")
	eq(got["items"][2]["rect"], Rect2i(130, 20, 57, 50), "the frame with its strap end")
	eq(got["droppedPieces"], 1, "the sparkle dropped")
	var frame: Image = got["items"][2]["image"]
	eq(frame.get_pixel(25, 25).a, 0.0, "the enclosed pocket keyed out")
	eq(frame.get_pixel(55, 21).a, 1.0, "the strap end kept")
	eq(frame.get_pixel(5, 5).a, 1.0, "the frame kept")
	var pair: Image = got["items"][1]["image"]
	eq(pair.get_pixel(0, 0).a, 1.0, "the first of the pair")
	eq(pair.get_pixel(37, 62).a, 1.0, "the second of the pair")
	eq(pair.get_pixel(37, 0).a, 0.0, "backdrop between them")
	# With cuts: the same split by the boundaries' x.
	var by_cut := ImportEquipment.split(img, 3, {"anchor": 0.05, "join": 8, "cuts": [60, 120]})
	eq(by_cut["items"].map(func(i): return i["rect"]), got["items"].map(func(i): return i["rect"]), "split by cuts")
	eq(ImportEquipment.split(img, 4, cfg["split"])["items"].size(), 3, "a sheet with fewer items reports them")


## fit(): one scale for every tier, each at its own sheet place, centred.
func test_fit_keeps_one_scale_and_place() -> void:
	var a := Image.create(10, 20, false, Image.FORMAT_RGBA8)
	a.fill(Color(1, 0, 0))
	var b := Image.create(10, 20, false, Image.FORMAT_RGBA8)
	b.fill(Color(0, 0, 1))
	var f := ImportEquipment.fit({"steel": {"image": b, "rect": Rect2i(105, 50, 10, 20)}, "iron": {"image": a, "rect": Rect2i(100, 50, 10, 20)}}, 128, 6)
	eq(f["tiers"], ["iron", "steel"], "tier order")
	eq(f["union"], Rect2i(100, 50, 15, 20), "the union of the tiers")
	near(f["scale"], 116.0 / 20.0, 0.0001, "the union fits the box")
	var ra := _opaque_rect(f["icons"]["iron"])
	var rb := _opaque_rect(f["icons"]["steel"])
	eq(ra.size, rb.size, "the same size")
	near(rb.position.x - ra.position.x, 5 * 116.0 / 20.0, 1.5, "steel 5 sheet px right of iron")
	eq(ra.position.y, 6, "the margin")
	near((ra.position.x + rb.end.x) / 2.0, 64.0, 1.0, "centred")


func test_sparkles() -> void:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var cfg := {"sparkles": {"gold": {"stars": [[100, 30, 12]]}, "dragon": {"stars": [[100, 30, 9]], "colour": [255, 217, 102, 242], "slots": ["armor"]}}}
	ImportEquipment.add_sparkles(img, "helmet", "dragon", cfg)
	eq(img.get_used_rect().size, Vector2i.ZERO, "not on a slot it skips")
	ImportEquipment.add_sparkles(img, "helmet", "iron", cfg)
	eq(img.get_used_rect().size, Vector2i.ZERO, "not on a tier without")
	ImportEquipment.add_sparkles(img, "helmet", "gold", cfg)
	var c := img.get_pixel(100, 30)
	check(c.a > 0.9 and c.r > 0.95 and c.b > 0.95, "a white star at its centre (%s)" % c)
	check(img.get_pixel(100, 19).a > 0.0 and img.get_pixel(111, 30).a > 0.0, "its tips")
	eq(img.get_pixel(108, 22).a, 0.0, "nothing between the tips")
	# Nudged off the art: the spot within reach with the least art under it.
	var art := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	art.fill_rect(Rect2i(0, 0, 104, 128), Color(0.3, 0.3, 0.3))
	var p := ImportEquipment.free_spot(art, Vector2(100, 30), 9, 14)
	check(p.x >= 108 and p.x <= 119, "moved right of the art (%s)" % p)
	eq(ImportEquipment.free_spot(art, Vector2(100, 30), 9, 0), Vector2(100, 30), "no nudge: where it is")


static func _opaque_rect(img: Image) -> Rect2i:
	var r := Rect2i()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				r = Rect2i(x, y, 1, 1) if r.size == Vector2i.ZERO else r.merge(Rect2i(x, y, 1, 1))
	return r


## Opaque px of the backdrop's colour (red and blue both well above green).
static func _magenta(img: Image) -> int:
	var n := 0
	var px := img.get_data()
	for o in range(0, px.size(), 4):
		if px[o + 3] > 128 and px[o] - px[o + 1] > 60 and px[o + 2] - px[o + 1] > 60:
			n += 1
	return n
