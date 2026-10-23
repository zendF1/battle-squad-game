extends SceneTree
## Imports a boss's AI-drawn art into the match and the screens: one config per boss,
## art_source/bosses/<id>/import.json, next to its source pictures (one sprite sheet per
## animation: the frames side by side in one row on a flat magenta backdrop, the figure facing
## right; a full-body portrait and a head-and-shoulders bust). Reproducible: everything it does is
## in the config. Runs headless (only Image is used; the editor may stay open):
##
##   $GODOT --headless --path . -s tools/import_boss_frames.gd [-- <boss_id> ...] [--contact=<png>]
##
## No id imports every art_source/bosses/*/import.json. --contact=<png> also writes a contact
## sheet: every cut frame on a checkerboard, a row per animation, the shared pivot (the feet) as
## a red cross, the body's top as a green line (to check the alignment and the scale).
##
## Per sheet (`anims.<name>`: src, frames (how many), fps, loop):
##   1. the generator's "✦" watermarks painted out (`watermark` [[x, y, r], ...] sheet px: the star
##      shape refilled from the px round it, tools/import_titles.gd remove_watermark(): on the
##      backdrop it becomes backdrop, on the art the art carries on);
##   2. the backdrop keyed out (tools/import_frames.gd key_background() with `background`, an anim's
##      own `background` merged over it: the median corner colour, soft edge, the enclosed pockets
##      of backdrop, the crystals' glow un-mixed from the magenta (`glow`)), the magenta fringe
##      despilled (tools/import_hug_guns.gd despill() on the `despill.hueRange` hues), faint px
##      cleared (`alphaCut`);
##   3. cut into its frames: the boundaries at the empty columns between the figures (for each,
##      the widest run of empty columns within `search` × a cell of where equal cells would cut,
##      its middle; none there, an effect touching its neighbour such as the cast's flash or the
##      blizzard's shard rings: the column the fewest px cross, or the equal-width cut with
##      `fallback` "equal"; `cuts` [x, ...] (sheet px) sets them instead). Then by pieces
##      (split_frames(), 8-connected): a piece goes whole to the cell holding `share` of it (a staff
##      tip reaching over a boundary stays with its figure); a piece shared by two figures goes px by
##      px to the figure whose cloak is nearest through the piece (a flood from the cloak px in the
##      middle of each cell), or, with no cloak in it, is cut at the boundary and faded over
##      `edgeFade` px. `compose` {"i": [j, ...]} draws frame i as the parts j... together where the
##      sheet has them, on the first one's feet (the cast's flash where her staff points);
##   4. measured per frame: the body = the cloak's px (`body`: hue range, minimum saturation and
##      value: the indigo / periwinkle cloth, not the cyan crystals, the white frost or the black
##      outline; only its pieces of at least `minPiece` × the largest, not a crystal's facets): its top row (the hood's top), its middle (the median x of the cloak's px in the
##      rows `centreRows` of its height: the skirt, not the staff or a raised arm) and the feet =
##      the lowest opaque row under the cloak within half the cloak's width of that middle (the
##      frost-mist hem's bottom; she hovers). `anchors` [[x, y] | null, ...] (sheet px) overrides a
##      frame's feet point;
##   5. scaled (one scale per sheet) so the body (top to feet, the median of its frames, or the
##      anim's `bodyHeight` in sheet px) is `height` px tall (× the anim's `scale`), once (Lanczos
##      on premultiplied colour: the low-resolution idle sheet is upscaled the same way).
## Then every frame of every animation is placed on one canvas with its feet on the same pivot
## (the union of all of them + `pad` px) and written as <out>/side/<anim>_<i>.png, with
## <out>/side/side.json: {size [w, h], pivot [x, y] (the feet, texture px), height (the body,
## texture px), width (the cloak's median width), facing 1 (drawn facing right), anims {name:
## {frames [stems], fps, loop, peak (optional: the frame of the effect's peak, the burst's flash)}}}.
## Pictures (`pictures.<name>`: src, watermark, size): keyed the same way, trimmed to the content
## (+ `margin` px), centred on a square canvas, scaled to `size` px: <out>/<name>.png (portrait,
## bust). Every frame and picture last gets the `tone` lift (tone(): lighten, desaturateDark).
## Skins (`skins.<name>`, idle and fly: one picture on a skeleton, _import_skin()): the picture (a
## `rect` of a model sheet) keyed and lifted the same way, its orbiting shards cut out as their own
## sprites (cut_shards(): the small pieces near `shards.centres`), measured like a frame and scaled so
## its body is `height` px (the frames' feet and body: the boss body draws both at the same size),
## its mesh (tools/full_mesh.gd: every visible px covered, gaps 0; faint corner px it misses are
## cleared), the `bones` [name, parent, joint, tip joint, strength] on the `joints` (source px; feet =
## the measured hem bottom; crystal = the staff's glow) and their weights, the loop's tracks
## (match/boss/skin_idle.gd or skin_fly.gd by `motion`): <out>/skin/<name>/body.png, shard_<i>.png,
## skin.json (the full.json format of tools/cut_sheet.gd + motion, shards, glow, gaps); a row at
## rest on the contact sheet, <name>_bones.png beside it. A new PNG gets an .import with mipmaps (shown smaller than drawn), an existing .import is
## never touched; until the editor imports them the game reads the PNGs (ui/art.gd).

const ImportFrames := preload("res://tools/import_frames.gd")
const ImportHugGuns := preload("res://tools/import_hug_guns.gd")
const ImportGuns := preload("res://tools/import_guns.gd")
const ImportTitles := preload("res://tools/import_titles.gd")
const FullMesh := preload("res://tools/full_mesh.gd")
const SkinIdle := preload("res://match/boss/skin_idle.gd")
const SkinFly := preload("res://match/boss/skin_fly.gd")
const SRC := "res://art_source/bosses/"

var _written := 0
var _bytes := 0


func _initialize() -> void:
	var ids: Array = []
	var contact := ""
	for a in OS.get_cmdline_user_args():
		var arg := str(a).strip_edges()
		if arg.begins_with("--contact="):
			contact = arg.trim_prefix("--contact=")
		elif arg != "":
			ids.append(arg)
	if ids.is_empty():
		for id in DirAccess.get_directories_at(SRC):
			if FileAccess.file_exists(SRC + id + "/import.json"):
				ids.append(id)
	var failed := false
	for id in ids:
		if not FileAccess.file_exists(SRC + str(id) + "/import.json"):
			push_error("import_boss_frames: no %s%s/import.json" % [SRC, id])
			failed = true
			continue
		if not _import(str(id), contact):
			failed = true
	print("import_boss_frames: wrote %d files, %.1f KB" % [_written, _bytes / 1024.0])
	quit(1 if failed else 0)


func _import(id: String, contact: String) -> bool:
	var dir := SRC + id + "/"
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(dir + "import.json"))
	if not cfg is Dictionary:
		push_error("import_boss_frames: %simport.json is not a JSON object" % dir)
		return false
	var out_dir := str(cfg.get("out", "res://assets/bosses/%s/" % id))
	print("%simport.json → %s" % [dir, out_dir])
	var target := float(cfg.get("height", 240))
	var cut_frames := {} # anim -> [{image (scaled), feet (px in it), width}]
	var order: Array = []
	for anim in cfg.get("anims", {}):
		var spec: Dictionary = cfg["anims"][anim]
		var sheet := _load(dir + str(spec["src"]))
		if sheet == null:
			return false
		var opts := spec_cfg(cfg, spec)
		for wm in spec.get("watermark", []):
			ImportTitles.remove_watermark(sheet, Vector2(float(wm[0]), float(wm[1])), float(wm[2]), float(wm[2]), 2.0,
				ImportFrames.corner_colour(sheet, 8))
		var k := keyed(sheet, opts)
		var n := int(spec["frames"])
		var cut := boundaries(sheet, n, opts, spec.get("cuts"))
		var parts := split_frames(sheet, cut["cuts"], opts)
		var frames: Array = []
		var heights: Array = []
		for i in n:
			var cell: Rect2i = parts[i]["rect"]
			var img: Image = parts[i]["image"]
			var m := measure(img, opts["body"])
			var anchors: Array = spec.get("anchors", [])
			if i < anchors.size() and anchors[i] is Array:
				m["feet"] = Vector2(float(anchors[i][0]) - cell.position.x, float(anchors[i][1]) - cell.position.y)
				if not bool(m["ok"]): # the cloak hidden (an effect over it): the body's height from the others
					m["top"] = NAN
					m["width"] = 0.0
				m["ok"] = true
			if not bool(m["ok"]):
				push_error("import_boss_frames: %s frame %d: no cloak px found (body colours %s)" % [anim, i, opts["body"]])
				return false
			if not is_nan(float(m["top"])):
				heights.append(float(m["feet"].y) - float(m["top"]))
			m["image"] = img
			m["cell"] = cell
			frames.append(m)
		# `compose` {"i": [j, ...]}: frame i drawn as the parts j... together where the sheet has them
		# (the cast's flash where her staff points), on the first one's feet.
		var compose: Dictionary = spec.get("compose", {})
		var composed := {}
		for key in compose:
			var list: Array = compose[key]
			var u := Rect2i()
			for j in list:
				var r: Rect2i = parts[int(j)]["rect"]
				u = r if u.size == Vector2i.ZERO else u.merge(r)
			var img := Image.create(u.size.x, u.size.y, false, Image.FORMAT_RGBA8)
			for j in list:
				var part: Image = parts[int(j)]["image"]
				img.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), parts[int(j)]["rect"].position - u.position)
			var first: Dictionary = frames[int(list[0])]
			var m := first.duplicate()
			m["feet"] = Vector2(first["feet"]) + Vector2(first["cell"].position - u.position)
			m["top"] = float(first["top"]) + first["cell"].position.y - u.position.y
			m["image"] = img
			m["cell"] = u
			composed[int(key)] = m
		for key in composed:
			frames[key] = composed[key]
		var sorted := heights.duplicate()
		sorted.sort()
		var body_h := float(spec.get("bodyHeight", sorted[sorted.size() / 2]))
		for m in frames:
			if is_nan(float(m["top"])):
				m["top"] = float(m["feet"].y) - body_h
		var s := target / body_h * float(spec.get("scale", 1.0))
		var outs: Array = []
		for i in n:
			var m: Dictionary = frames[i]
			var img: Image = m["image"]
			var size := Vector2i(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)))
			var ks := Vector2(float(size.x) / img.get_width(), float(size.y) / img.get_height())
			outs.append({"image": ImportGuns.scaled(img, size), "feet": Vector2(m["feet"]) * ks, "width": float(m["width"]) * s,
				"top": (float(m["feet"].y) - float(m["top"])) * ks.y})
		cut_frames[anim] = outs
		order.append(anim)
		print("  %s %s %dx%d: keyed %d px; cuts %s%s; body %.1f px (frames %s) ×%.4f; feet %s" % [anim, spec["src"],
			sheet.get_width(), sheet.get_height(), k, str(cut["cuts"]), " (touching, cut at the fewest px: %s)" % str(cut["fallback"]) if not cut["fallback"].is_empty() else "",
			body_h, str(heights.map(func(v): return snappedf(v, 0.1))), s,
			str(frames.map(func(m): return (Vector2(m["feet"]) + Vector2(m["cell"].position)).snapped(Vector2(0.1, 0.1))))])
	if order.is_empty():
		push_error("import_boss_frames: %s has no anims" % id)
		return false
	# One canvas: every frame's feet on the pivot.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for anim in order:
		for f in cut_frames[anim]:
			var used: Rect2i = (f["image"] as Image).get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			lo = Vector2(minf(lo.x, used.position.x - f["feet"].x), minf(lo.y, used.position.y - f["feet"].y))
			hi = Vector2(maxf(hi.x, used.end.x - f["feet"].x), maxf(hi.y, used.end.y - f["feet"].y))
	var pad := float(cfg.get("pad", 4))
	var pivot := Vector2(ceil(-lo.x + pad), ceil(-lo.y + pad))
	var canvas := Vector2i(int(ceil(pivot.x + hi.x + pad)), int(ceil(pivot.y + hi.y + pad)))
	var widths: Array = []
	var side_anims := {}
	var written: Dictionary = {} # anim -> [Image] (the contact sheet)
	for anim in order:
		var spec: Dictionary = cfg["anims"][anim]
		var stems: Array = []
		written[anim] = []
		for i in cut_frames[anim].size():
			var f: Dictionary = cut_frames[anim][i]
			var img := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
			var src: Image = f["image"]
			var at := Vector2i((pivot - Vector2(f["feet"])).round())
			img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
			tone(img, cfg.get("tone", {}))
			var stem := "%s_%d" % [anim, i]
			_save(img, out_dir + "side/" + stem + ".png")
			stems.append(stem)
			widths.append(float(f["width"]))
			written[anim].append(img)
		var entry := {"frames": stems, "fps": float(spec.get("fps", 8)), "loop": bool(spec.get("loop", false))}
		if spec.has("peak"):
			entry["peak"] = int(spec["peak"])
		side_anims[anim] = entry
	widths.sort()
	var side := {
		"_doc": "Written by tools/import_boss_frames.gd from art_source/bosses/%s/import.json (do not edit: edit the config and re-run). size / pivot (the feet: the frost-mist hem's bottom centre) / height (the body: the hood's top to the feet) / width (the cloak) in texture px; facing 1: drawn facing right; anims {name: {frames, fps, loop, peak}}." % id,
		"size": [canvas.x, canvas.y],
		"pivot": [pivot.x, pivot.y],
		"height": target,
		"width": snappedf(widths[widths.size() / 2], 0.1),
		"facing": 1,
		"anims": side_anims,
	}
	_write_text(out_dir + "side/side.json", JSON.stringify(side, "\t", false) + "\n")
	print("  canvas %s, pivot %s, body %d px tall" % [canvas, pivot, int(target)])
	for pname in cfg.get("pictures", {}):
		var pc: Dictionary = cfg["pictures"][pname]
		var src_img := _load(dir + str(pc["src"]))
		if src_img == null:
			return false
		for wm in pc.get("watermark", []):
			ImportTitles.remove_watermark(src_img, Vector2(float(wm[0]), float(wm[1])), float(wm[2]), float(wm[2]), 2.0,
				ImportFrames.corner_colour(src_img, 8))
		keyed(src_img, spec_cfg(cfg, pc))
		var pic := picture(src_img, int(pc.get("size", 512)), int(pc.get("margin", 8)))
		tone(pic, cfg.get("tone", {}))
		_save(pic, out_dir + str(pname) + ".png")
	var skins: Dictionary = cfg.get("skins", {}) if cfg.get("skins") is Dictionary else {}
	var skin_rows: Array = []
	for sname in skins:
		var rest := _import_skin(dir, out_dir, cfg, str(sname), contact.get_base_dir() if contact != "" else "")
		if rest.is_empty():
			return false
		# The contact sheet's first rows: the skinned animations at rest, on the frames' canvas and pivot.
		var k := target / float(rest["height"])
		var img: Image = rest["image"]
		var small := ImportGuns.scaled(img, Vector2i(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k))))
		var on := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
		on.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i((pivot - Vector2(rest["pivot"]) * k).round()))
		written["%s (skin)" % sname] = [on]
		skin_rows.append("%s (skin)" % sname)
	order = skin_rows + order
	if contact != "":
		_contact(written, order, canvas, pivot, target, contact)
	return true


## A skinned animation (config `skins.<name>`, see the header): the picture (`rect` [x, y, w, h]: one
## figure of a model sheet) keyed, its shards cut out, the body's mesh, bones and weights
## (tools/full_mesh.gd, as tools/cut_sheet.gd does for the lobby characters), the loop's tracks
## (`motion` "idle": match/boss/skin_idle.gd; "glide": match/boss/skin_fly.gd). Writes
## <out>/skin/<name>/body.png, shard_<i>.png, skin.json (and, with a debug dir, <name>_bones.png:
## the bones on the picture); returns {image (the rest pose: body and shards), pivot, height} or {}.
func _import_skin(dir: String, out_dir: String, cfg: Dictionary, sname: String, debug_dir: String = "") -> Dictionary:
	var sk: Dictionary = cfg["skins"][sname]
	var sub := out_dir + "skin/%s/" % sname
	var img := _load(dir + str(sk["src"]))
	if img == null:
		return {}
	for wm in sk.get("watermark", []):
		ImportTitles.remove_watermark(img, Vector2(float(wm[0]), float(wm[1])), float(wm[2]), float(wm[2]), 2.0, ImportFrames.corner_colour(img, 8))
	var crop := Vector2.ZERO # the joints / shard centres stay sheet px
	if sk.get("rect") is Array and sk["rect"].size() >= 4:
		var r := Rect2i(int(sk["rect"][0]), int(sk["rect"][1]), int(sk["rect"][2]), int(sk["rect"][3]))
		img = img.get_region(r)
		crop = Vector2(r.position)
	keyed(img, spec_cfg(cfg, sk))
	tone(img, cfg.get("tone", {}))
	var shard_cfg: Dictionary = (sk.get("shards", {}) as Dictionary).duplicate(true)
	shard_cfg["centres"] = shard_cfg.get("centres", []).map(func(c): return [float(c[0]) - crop.x, float(c[1]) - crop.y])
	var parts := cut_shards(img, shard_cfg)
	var body: Image = parts["body"]
	var m := measure(body, cfg.get("body", {}))
	if not bool(m["ok"]):
		push_error("import_boss_frames: skin: no cloak found in %s" % sk["src"])
		return {}
	var src_feet: Vector2 = m["feet"]
	var src_h := src_feet.y - float(m["top"])
	var height := float(sk.get("height", 360))
	var s := height / src_h
	var pad := int(sk.get("pad", 6))
	var used := body.get_used_rect().grow(int(ceil(pad / s)))
	used = used.intersection(Rect2i(Vector2i.ZERO, body.get_size()))
	var size := Vector2i(roundi(used.size.x * s), roundi(used.size.y * s))
	var k := Vector2(size) / Vector2(used.size)
	var to_px := func(p: Vector2) -> Vector2: return ((p - Vector2(used.position)) * k).snapped(Vector2(0.1, 0.1))
	var pic := ImportGuns.scaled(body.get_region(used), size)
	ImportFrames.clean(pic, {"alphaCut": 10, "keepPieces": float(sk.get("keepPieces", 0.0004)), "defringe": {"band": 0}}) # no stray specks for the mesh
	var pivot: Vector2 = to_px.call(src_feet)
	# The bones (`joints` source px; `bones` [name, parent, joint, tip joint, strength]).
	var joints := {"feet": src_feet}
	for j in sk.get("joints", {}):
		joints[j] = Vector2(float(sk["joints"][j][0]), float(sk["joints"][j][1])) - crop
	var bones: Array = []
	for b in sk.get("bones", []):
		if not joints.has(str(b[2])) or not joints.has(str(b[3])):
			push_error("import_boss_frames: skin bone %s needs the joints %s and %s" % [b[0], b[2], b[3]])
			return {}
		bones.append({"name": str(b[0]), "parent": str(b[1]), "at": to_px.call(joints[str(b[2])]), "tip": to_px.call(joints[str(b[3])]),
			"strength": float(b[4]) if b.size() > 4 else 1.0})
	var t0 := Time.get_ticks_msec()
	var mesh := FullMesh.build(pic)
	var weights := FullMesh.weights(pic, mesh["vertices"], bones)
	print("  skin %s: body %d px tall (×%.4f), %s; mesh %d vertices, %d triangles, gaps: %d, %.1f s" % [sk["src"], int(height), s, size,
		mesh["vertices"].size(), mesh["triangles"].size() / 3, mesh["gaps"], (Time.get_ticks_msec() - t0) / 1000.0])
	if int(mesh["gaps"]) != 0: # faint corner px the triangles miss (alpha ≤ 64): cleared, invisible
		var cov := FullMesh._coverage(mesh["vertices"], mesh["triangles"], size.x, size.y)
		var data := pic.get_data()
		var cleared := 0
		for i in size.x * size.y:
			if data[i * 4 + 3] > 0 and data[i * 4 + 3] <= 64 and cov[i] == 0:
				data[i * 4 + 3] = 0
				cleared += 1
		pic.set_data(size.x, size.y, false, Image.FORMAT_RGBA8, data)
		mesh["gaps"] = FullMesh.gaps(pic, mesh["vertices"], mesh["triangles"])
		print("    cleared %d faint px outside the mesh; gaps: %d" % [cleared, mesh["gaps"]])
	if int(mesh["gaps"]) != 0:
		push_warning("import_boss_frames: the skin's mesh leaves %d px uncovered" % mesh["gaps"])
	_save(pic, sub + "body.png")
	var rest := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	rest.blit_rect(pic, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
	var shards: Array = []
	for i in parts["shards"].size():
		var sh: Dictionary = parts["shards"][i]
		var r: Rect2i = sh["rect"]
		var ss := Vector2i(maxi(1, roundi(r.size.x * k.x)), maxi(1, roundi(r.size.y * k.y)))
		var simg := ImportGuns.scaled(sh["image"], ss)
		_save(simg, sub + "shard_%d.png" % i)
		var at: Vector2 = to_px.call(Vector2(r.position))
		rest.blend_rect(simg, Rect2i(Vector2i.ZERO, ss), Vector2i(at.round()))
		shards.append({"file": "shard_%d.png" % i, "at": [at.x, at.y], "size": [ss.x, ss.y]})
	var glow: Vector2 = to_px.call(joints.get("crystal", Vector2.ZERO))
	var v: Array = []
	for p in mesh["vertices"]:
		v.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
	var wt: Array = []
	for row in weights:
		var flat: Array = []
		for c in row:
			flat.append(c[0])
			flat.append(snappedf(c[1], 0.001))
		wt.append(flat)
	var bone_rows: Array = []
	for b in bones:
		bone_rows.append({"name": b["name"], "parent": b["parent"], "at": [b["at"].x, b["at"].y], "tip": [b["tip"].x, b["tip"].y],
			"strength": b["strength"]})
	var names: Array = bones.map(func(b): return b["name"])
	var out := {
		"_doc": "Written by tools/import_boss_frames.gd from art_source/bosses/<id>/import.json skin (do not edit: edit the config and re-run). The full.json format of the lobby characters (ui/art.gd parse_full(), scenes/character/full_body.gd): size, pivot (the feet: the frost-mist hem's bottom centre), height (the body, hood top to the feet, px), scale, bones, anims (the idle: match/boss/skin_idle.gd), mesh, weights; plus shards [{file, at (top-left px), size}] and glow (the staff crystal, px).",
		"source": "art_source/bosses/" + dir.trim_suffix("/").get_file() + "/" + str(sk["src"]),
		"size": [size.x, size.y],
		"pivot": [pivot.x, pivot.y],
		"height": height,
		"scale": 1.0,
		"bones": bone_rows,
		"anims": {"idle": SkinFly.tracks(names, height) if str(sk.get("motion", "idle")) == "glide" else SkinIdle.tracks(names, height)},
		"motion": str(sk.get("motion", "idle")),
		"shards": shards,
		"glow": [glow.x, glow.y],
		"gaps": int(mesh["gaps"]),
		"mesh": {"vertices": v, "triangles": Array(mesh["triangles"])},
		"weights": wt,
	}
	_write_text(sub + "skin.json", JSON.stringify(out) + "\n")
	if debug_dir != "":
		var dbg := rest.duplicate()
		for b in bones:
			var a: Vector2 = b["at"]
			var t: Vector2 = b["tip"]
			for q in 40:
				var p: Vector2 = a.lerp(t, q / 39.0)
				if Rect2i(Vector2i.ZERO, size).has_point(Vector2i(p)):
					dbg.set_pixelv(Vector2i(p), Color(1, 0.9, 0.1))
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var q := Vector2i(a) + Vector2i(dx, dy)
					if Rect2i(Vector2i.ZERO, size).has_point(q):
						dbg.set_pixelv(q, Color(0.1, 1, 0.3))
		DirAccess.make_dir_recursive_absolute(debug_dir)
		dbg.save_png(debug_dir.path_join("%s_bones.png" % sname))
	return {"image": rest, "pivot": pivot, "height": height}


## The skin picture's orbiting shards cut out (`shards` {centres [[x, y]] source px, radius}): every
## px of a piece other than the largest (the body) within radius of a centre goes to the nearest
## centre's shard (its orbit arcs with it) and leaves the body. {body (Image), shards [{image, rect}]}.
static func cut_shards(img: Image, cfg: Dictionary) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var centres: Array = []
	for c in cfg.get("centres", []):
		centres.append(Vector2(float(c[0]), float(c[1])))
	var radius := float(cfg.get("radius", 70))
	var label := PackedInt32Array()
	label.resize(w * h)
	var sizes := PackedInt32Array([0])
	var stack := PackedInt32Array()
	stack.resize(w * h)
	for s in w * h:
		if px[s * 4 + 3] == 0 or label[s] != 0:
			continue
		var id := sizes.size()
		var n := 0
		var top := 1
		stack[0] = s
		label[s] = id
		while top > 0:
			top -= 1
			var i: int = stack[top]
			n += 1
			var x := i % w
			var y := i / w
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if xx < 0 or yy < 0 or xx >= w or yy >= h:
						continue
					var j := yy * w + xx
					if label[j] == 0 and px[j * 4 + 3] != 0:
						label[j] = id
						stack[top] = j
						top += 1
		sizes.append(n)
	var largest := 1
	for id in range(1, sizes.size()):
		if sizes[id] > sizes[largest]:
			largest = id
	var datas: Array = []
	var lo: Array = []
	var hi: Array = []
	for c in centres:
		var d := PackedByteArray()
		d.resize(w * h * 4)
		datas.append(d)
		lo.append(Vector2i(w, h))
		hi.append(Vector2i(-1, -1))
	var owner := PackedInt32Array()
	owner.resize(w * h)
	owner.fill(-1)
	for k in w * h:
		if label[k] == 0 or label[k] == largest:
			continue
		var p := Vector2(k % w + 0.5, k / w + 0.5)
		var best := -1
		var best_d := radius
		for ci in centres.size():
			var dd := p.distance_to(centres[ci])
			if dd <= best_d:
				best_d = dd
				best = ci
		owner[k] = best
	for ci in centres.size():
		var d: PackedByteArray = datas[ci]
		var l: Vector2i = lo[ci]
		var u: Vector2i = hi[ci]
		for k in w * h:
			if owner[k] != ci:
				continue
			for c in 4:
				d[k * 4 + c] = px[k * 4 + c]
			px[k * 4 + 3] = 0
			var x := k % w
			var y := k / w
			l = Vector2i(mini(l.x, x), mini(l.y, y))
			u = Vector2i(maxi(u.x, x), maxi(u.y, y))
		datas[ci] = d
		lo[ci] = l
		hi[ci] = u
	var shards: Array = []
	for ci in centres.size():
		if hi[ci].x < 0:
			push_warning("import_boss_frames: no shard px near %s" % centres[ci])
			continue
		var r := Rect2i(lo[ci], hi[ci] - lo[ci] + Vector2i.ONE)
		shards.append({"image": Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, datas[ci]).get_region(r), "rect": r})
	return {"body": Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px), "shards": shards}


## The options of one sheet / picture: the config's background / despill / alphaCut / body /
## search / edgeFade, its own background merged over the config's.
static func spec_cfg(cfg: Dictionary, spec: Dictionary) -> Dictionary:
	var bg: Dictionary = (cfg.get("background", {}) as Dictionary).duplicate(true)
	if spec.get("background") is Dictionary:
		bg.merge(spec["background"], true)
	var out := {"background": bg, "despill": cfg.get("despill"), "alphaCut": float(spec.get("alphaCut", cfg.get("alphaCut", 20))),
		"body": cfg.get("body", {}), "search": float(spec.get("search", cfg.get("search", 0.35))),
		"edgeFade": int(spec.get("edgeFade", cfg.get("edgeFade", 6))), "fallback": str(spec.get("fallback", cfg.get("fallback", "valley")))}
	return out


## A sheet keyed in place (the backdrop, the magenta fringe, faint px): the backdrop px cleared.
static func keyed(img: Image, opts: Dictionary) -> int:
	img.convert(Image.FORMAT_RGBA8)
	var bg: Dictionary = opts["background"]
	var kc := ImportFrames.corner_colour(img, int(bg.get("corner", 8)))
	var n := ImportFrames.key_background(img, bg)
	var ds = opts.get("despill")
	if ds is Dictionary:
		var chans := ImportFrames.key_channels(kc)
		if not chans.is_empty():
			var hues = ds.get("hueRange")
			ImportHugGuns.despill(img, chans[0], chans[1] if chans.size() > 1 else -1,
				Vector2(float(hues[0]), float(hues[1])) if hues is Array and hues.size() >= 2 else Vector2(-1, -1))
	ImportFrames.clean(img, {"alphaCut": opts["alphaCut"], "keepPieces": 0.0, "defringe": {"band": 0}})
	return n


## A keyed sheet's n − 1 frame boundaries: {cuts [x], fallback [the boundaries (1..n − 1) with no
## empty column near them: cut where the fewest px cross, or equal-width with `fallback` "equal"]}.
## `given` (the config's cuts) sets them instead. See the header (3.).
static func boundaries(img: Image, n: int, opts: Dictionary, given: Variant = null) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var cols := PackedInt32Array()
	cols.resize(w)
	for y in h:
		for x in w:
			if px[(y * w + x) * 4 + 3] > 0:
				cols[x] += 1
	var cell := float(w) / n
	var cuts: Array = []
	var fallback: Array = []
	for k in range(1, n):
		if given is Array and given.size() >= n - 1:
			cuts.append(int(given[k - 1]))
			continue
		var e := cell * k
		var lo := maxi(1, int(e - cell * float(opts.get("search", 0.35))))
		var hi := mini(w - 2, int(e + cell * float(opts.get("search", 0.35))))
		var best := Vector2i(-1, -1) # the widest run of empty columns: [start, end]
		var x := lo
		while x <= hi:
			if cols[x] != 0:
				x += 1
				continue
			var s := x
			while x <= hi and cols[x] == 0:
				x += 1
			var run := Vector2i(s, x - 1)
			var wider := run.y - run.x > best.y - best.x
			var as_wide := run.y - run.x == best.y - best.x and absf((run.x + run.y) * 0.5 - e) < absf((best.x + best.y) * 0.5 - e)
			if best.x < 0 or wider or as_wide:
				best = run
		if best.x >= 0:
			cuts.append((best.x + best.y + 1) / 2)
		elif str(opts.get("fallback", "valley")) == "equal":
			cuts.append(int(round(e)))
			fallback.append(k)
		else: # the column the fewest px cross (summed over ±2 columns), the nearest to e
			var low := -1
			var low_n := 1 << 30
			for xx in range(lo, hi + 1):
				var sum := 0
				for d in range(-2, 3):
					sum += cols[clampi(xx + d, 0, w - 1)]
				if sum < low_n or (sum == low_n and absf(xx - e) < absf(low - e)):
					low_n = sum
					low = xx
			cuts.append(low)
			fallback.append(k)
	return {"cuts": cuts, "fallback": fallback}


## A keyed sheet split into its frames by the pieces (8-connected px over alpha 0) and the cuts
## (x of the n − 1 boundaries): a piece goes whole to the cell holding at least `share` of it (a
## staff tip or a sparkle reaching over the cut stays with its own figure; a piece under
## `smallPiece` px goes to the cell with most of it); a piece shared by two figures (an effect
## touching its neighbour) is cut at the boundaries, its px faded out over `edgeFade` px next to
## each cut. [{image (the frame's px cropped to rect), rect (sheet px)}] per frame, left → right.
static func split_frames(img: Image, cuts: Array, opts: Dictionary) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var n := cuts.size() + 1
	var px := img.get_data()
	var edges: Array = [0] + cuts + [w]
	var cell_of := PackedInt32Array()
	cell_of.resize(w)
	for i in n:
		for x in range(int(edges[i]), int(edges[i + 1])):
			cell_of[x] = i
	var label := PackedInt32Array()
	label.resize(w * h)
	var counts := PackedInt32Array([]) # piece id × n: its px per cell (id 0 unused)
	counts.resize(n)
	var stack := PackedInt32Array()
	stack.resize(w * h)
	var next_id := 1
	for s in w * h:
		if px[s * 4 + 3] == 0 or label[s] != 0:
			continue
		var id := next_id
		next_id += 1
		counts.resize((id + 1) * n)
		var top := 1
		stack[0] = s
		label[s] = id
		while top > 0:
			top -= 1
			var i: int = stack[top]
			var x := i % w
			var y := i / w
			counts[id * n + cell_of[x]] += 1
			for dy in range(-1, 2):
				var yy := y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-1, 2):
					var xx := x + dx
					if xx < 0 or xx >= w:
						continue
					var j := yy * w + xx
					if label[j] == 0 and px[j * 4 + 3] != 0:
						label[j] = id
						stack[top] = j
						top += 1
	var share := float(opts.get("share", 0.8))
	var small := int(opts.get("smallPiece", 400))
	var owner := PackedInt32Array() # piece id -> its frame, -1: shared (cut)
	owner.resize(next_id)
	var shared := 0
	for id in range(1, next_id):
		var total := 0
		var best := 0
		for c in n:
			total += counts[id * n + c]
			if counts[id * n + c] > counts[id * n + best]:
				best = c
		owner[id] = best if total < small or counts[id * n + best] >= total * share else -1
		if owner[id] < 0:
			shared += 1
	# A shared piece's px go to the figure whose cloak is nearest through the piece (a multi-source
	# flood from the cloak px in the middle of each cell, away from the cuts by `seedMargin` × the
	# cell): the fronts meet between two figures, not at a straight cut.
	var body: Dictionary = opts.get("body", {})
	var margin := float(opts.get("seedMargin", 0.2))
	var geo := PackedInt32Array()
	geo.resize(w * h)
	geo.fill(-1)
	var queue := PackedInt32Array()
	for k in w * h:
		var id := label[k]
		if id == 0 or owner[id] >= 0:
			continue
		var x := k % w
		var c := cell_of[x]
		var cw := float(int(edges[c + 1]) - int(edges[c]))
		if x < int(edges[c]) + cw * margin or x >= int(edges[c + 1]) - cw * margin:
			continue
		if is_cloak(px, k, body):
			geo[k] = c
			queue.append(k)
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x := i % w
		var y := i / w
		for dy in range(-1, 2):
			var yy := y + dy
			if yy < 0 or yy >= h:
				continue
			for dx in range(-1, 2):
				var xx := x + dx
				if xx < 0 or xx >= w:
					continue
				var j := yy * w + xx
				if geo[j] < 0 and label[j] == label[i]:
					geo[j] = geo[i]
					queue.append(j)
	var fade := int(opts.get("edgeFade", 6))
	var frame_of := PackedInt32Array() # px -> its frame (-1: none)
	frame_of.resize(w * h)
	frame_of.fill(-1)
	var alpha := PackedByteArray()
	alpha.resize(w * h)
	for k in w * h:
		var id := label[k]
		if id == 0:
			continue
		var x := k % w
		var f := owner[id]
		var a := px[k * 4 + 3]
		if f < 0 and geo[k] >= 0:
			f = geo[k]
		elif f < 0: # no cloak in the piece: the straight cut
			f = cell_of[x]
			var dist := 1 << 20
			if f > 0:
				dist = mini(dist, x - int(edges[f]))
			if f < n - 1:
				dist = mini(dist, int(edges[f + 1]) - 1 - x)
			if fade > 0 and dist < fade:
				a = int(a * float(dist) / fade)
			if a == 0:
				continue
		frame_of[k] = f
		alpha[k] = a
	var out: Array = []
	for i in n:
		var d := PackedByteArray()
		d.resize(w * h * 4)
		var lo := Vector2i(w, h)
		var hi := Vector2i(-1, -1)
		for k in w * h:
			if frame_of[k] != i:
				continue
			d[k * 4] = px[k * 4]
			d[k * 4 + 1] = px[k * 4 + 1]
			d[k * 4 + 2] = px[k * 4 + 2]
			d[k * 4 + 3] = alpha[k]
			var x := k % w
			var y := k / w
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		var full := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, d)
		var r := Rect2i(lo, hi - lo + Vector2i.ONE) if hi.x >= 0 else Rect2i(int(edges[i]), 0, 1, 1)
		out.append({"image": full.get_region(r), "rect": r})
	if shared > 0:
		print("    %d piece(s) shared by two frames: cut at the boundaries" % shared)
	return out


## One keyed frame's body: {ok, top (the cloak's top row), feet (Vector2: the hem's bottom centre),
## width (the cloak's width in its skirt rows)}. See the header (4.).
static func measure(img: Image, body: Dictionary) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	var rows: Array = body.get("centreRows", [0.4, 0.8])
	var cloak := PackedByteArray()
	cloak.resize(w * h)
	var row_n := PackedInt32Array()
	row_n.resize(h)
	for y in h:
		for x in w:
			var o := (y * w + x) * 4
			if px[o + 3] < 160:
				continue
			if is_cloak(px, y * w + x, body):
				cloak[y * w + x] = 1
	# Only the cloth's big pieces: a crystal's periwinkle facets above the hood are not her top.
	_keep_big(cloak, w, h, float(body.get("minPiece", 0.08)))
	for y in h:
		for x in w:
			if cloak[y * w + x] == 1:
				row_n[y] += 1
	var min_row := maxi(2, int(w * 0.004))
	var top := -1
	var bottom := -1
	for y in h:
		if row_n[y] >= min_row:
			if top < 0:
				top = y
			bottom = y
	if top < 0 or bottom - top < 8:
		return {"ok": false}
	var span := float(bottom - top)
	var xs: Array = []
	for y in range(int(top + span * float(rows[0])), int(top + span * float(rows[1])) + 1):
		for x in w:
			if cloak[y * w + x] == 1:
				xs.append(x)
	if xs.size() < 10:
		return {"ok": false}
	xs.sort()
	var cx := float(xs[xs.size() / 2])
	var width := float(xs[int(xs.size() * 0.95)] - xs[int(xs.size() * 0.05)])
	# The feet: the lowest opaque row under the cloak within half its width of the middle.
	var x0 := maxi(0, int(cx - width * 0.5))
	var x1 := mini(w - 1, int(cx + width * 0.5))
	var feet_y := bottom
	for y in range(bottom, h):
		var n := 0
		for x in range(x0, x1 + 1):
			if px[(y * w + x) * 4 + 3] >= 128:
				n += 1
		if n >= 2:
			feet_y = y
	return {"ok": true, "top": float(top), "feet": Vector2(cx, feet_y + 1.0), "width": width}


## The mask's 8-connected pieces under `share` × the largest cleared, in place.
static func _keep_big(mask: PackedByteArray, w: int, h: int, share: float) -> void:
	var label := PackedInt32Array()
	label.resize(w * h)
	var sizes := PackedInt32Array([0])
	var stack := PackedInt32Array()
	for s in w * h:
		if mask[s] == 0 or label[s] != 0:
			continue
		var id := sizes.size()
		var n := 0
		stack.append(s)
		label[s] = id
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			n += 1
			var x := i % w
			var y := i / w
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and mask[yy * w + xx] == 1 and label[yy * w + xx] == 0:
						label[yy * w + xx] = id
						stack.append(yy * w + xx)
		sizes.append(n)
	var largest := 0
	for n in sizes:
		largest = maxi(largest, n)
	for i in w * h:
		if label[i] != 0 and sizes[label[i]] < largest * share:
			mask[i] = 0


## Pixel k (of an RGBA8 px array) is the cloak's cloth: opaque, of the `body` hues, saturation
## and value (see the header, 4.).
static func is_cloak(px: PackedByteArray, k: int, body: Dictionary) -> bool:
	var o := k * 4
	if px[o + 3] < 160:
		return false
	var c := Color8(px[o], px[o + 1], px[o + 2])
	var hues: Array = body.get("hue", [222, 266])
	var hue := c.h * 360.0
	return hue >= float(hues[0]) and hue <= float(hues[1]) and c.s >= float(body.get("minSat", 0.35)) \
		and c.v >= float(body.get("minVal", 0.22)) and c.v <= float(body.get("maxVal", 0.96))


## The tone lift (config `tone`): every visible px a little lighter, `lighten` of the way to white
## in OKHSL lightness (the dark cloak gains most, the light glow and the cyan highlights hardly
## change), and the darkest tones `desaturateDark` less saturated (fading out by mid lightness);
## the black outline (lightness under ~0.1) is left as it is, so the figure stays crisp. In place.
static func tone(img: Image, cfg: Variant) -> void:
	if not cfg is Dictionary:
		return
	var lift := float(cfg.get("lighten", 0.0))
	var desat := float(cfg.get("desaturateDark", 0.0))
	if lift <= 0.0 and desat <= 0.0:
		return
	var w := img.get_width()
	var h := img.get_height()
	var px := img.get_data()
	for o in range(0, px.size(), 4):
		if px[o + 3] == 0:
			continue
		var c := Color8(px[o], px[o + 1], px[o + 2])
		var l := c.ok_hsl_l
		var keep := smoothstep(0.06, 0.2, l) # the outline stays dark
		if keep <= 0.0:
			continue
		var l2 := l + (1.0 - l) * lift * keep
		var s2 := c.ok_hsl_s * (1.0 - desat * keep * clampf((0.55 - l) / 0.4, 0.0, 1.0))
		var t := Color.from_ok_hsl(c.ok_hsl_h, s2, l2)
		px[o] = clampi(roundi(t.r * 255.0), 0, 255)
		px[o + 1] = clampi(roundi(t.g * 255.0), 0, 255)
		px[o + 2] = clampi(roundi(t.b * 255.0), 0, 255)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, px)


## A picture trimmed to its content (+ margin px), centred on a square, scaled to size × size.
static func picture(img: Image, size: int, margin: int) -> Image:
	var used := img.get_used_rect()
	var side := maxi(used.size.x, used.size.y) + 2 * margin
	var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
	sq.blit_rect(img, used, (Vector2i(side, side) - used.size) / 2)
	return ImportGuns.scaled(sq, Vector2i(size, size)) if side != size else sq


static func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		push_error("import_boss_frames: cannot read " + path)
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## The contact sheet: every frame (half size) on a checkerboard, a row per anim; the pivot's
## cross in red, the body's top (pivot − height) in green.
func _contact(written: Dictionary, order: Array, canvas: Vector2i, pivot: Vector2, height: float, path: String) -> void:
	var k := 0.5
	var cw := int(canvas.x * k)
	var ch := int(canvas.y * k)
	var cols := 0
	for anim in order:
		cols = maxi(cols, written[anim].size())
	var sheet := Image.create(cw * cols, ch * order.size(), false, Image.FORMAT_RGBA8)
	for y in sheet.get_height():
		for x in sheet.get_width():
			var light := ((x / 12) + (y / 12)) % 2 == 0
			sheet.set_pixel(x, y, Color(0.82, 0.82, 0.86) if light else Color(0.62, 0.62, 0.68))
	for r in order.size():
		var anim: String = order[r]
		for i in written[anim].size():
			var fr: Image = (written[anim][i] as Image).duplicate()
			fr.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
			var at := Vector2i(i * cw, r * ch)
			sheet.blend_rect(fr, Rect2i(Vector2i.ZERO, fr.get_size()), at)
			var p := Vector2i(at.x + int(pivot.x * k), at.y + int(pivot.y * k))
			for x in range(at.x, at.x + cw):
				sheet.set_pixel(x, p.y, Color(1, 0.1, 0.1))
				sheet.set_pixel(x, clampi(p.y - int(height * k), at.y, at.y + ch - 1), Color(0.1, 0.85, 0.2))
			for y in range(at.y, at.y + ch):
				sheet.set_pixel(p.x, y, Color(1, 0.1, 0.1))
			for x in range(at.x, at.x + cw): # the cell's frame
				sheet.set_pixel(x, at.y, Color(0.2, 0.2, 0.25))
			for y in range(at.y, at.y + ch):
				sheet.set_pixel(at.x, y, Color(0.2, 0.2, 0.25))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	sheet.save_png(path)
	print("  contact sheet %s (%dx%d)" % [path, sheet.get_width(), sheet.get_height()])


func _save(img: Image, path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_boss_frames: cannot write %s (%s)" % [path, error_string(err)])
		return
	var bytes := FileAccess.get_file_as_bytes(abs_path).size()
	_written += 1
	_bytes += bytes
	print("    %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), bytes / 1024.0])


func _write_text(path: String, text: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	_written += 1
	_bytes += text.length()
	print("    %s  %.1f KB" % [path, text.length() / 1024.0])
