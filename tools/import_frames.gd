extends SceneTree
## Imports hand-made (AI-made) side-view frames of a character into the match art: one JSON
## config per set, art_source/characters/<id>/side_*/import.json, next to its source frames
## (any size, transparent background, facing right). Reproducible: everything it does is in the
## config. Runs headless (only Image is used):
##
##   $GODOT --headless --path . -s tools/import_frames.gd -- <character_id> ...
##   $GODOT --headless --path . -s tools/import_frames.gd -- <config.json> ...
##
## A character id imports its art_source/characters/<id>/side*/import.json (the run frames and
## the ready pose: one config); no argument imports every one (configs_for()). A config whose
## source frames are not there yet is skipped (a drop-in folder waiting for its pictures); a pose
## whose picture is missing is left out with the animations that show it (and `gunDraw`), so the
## run frames alone already make a side view. It writes the config's `out` folder
## (assets/characters/<id>/side/), PNG and JSON only (never a scene: the pose scenes are placed by
## hand): <anim>_<i>.png, hand.png (`hand`: only without a ready pose), side.json and
## gun_anchors.json (formats in assets/README.md, read by ui/art.gd side_view()). A new PNG gets
## an .import without mipmaps; an existing .import is never touched (nor an old file deleted).
## Let the editor import them.
##
## `frames` lists the source files in cycle order, or is a pattern ("frame_*.png": every match,
## natural order: frame_1, frame_2 .. frame_10). An anim's `frames` "all" is every source frame;
## a source index past the last frame is dropped (a template written for more frames).
##
## Per source frame:
##   1. clean: alpha below `alphaCut` is cleared; only the big connected pieces stay (8-connected,
##      at least `keepPieces` × the largest), so the stray pixels near the canvas edges go;
##      defringe: in the `band` px next to the transparency, light grey pixels (the white halo of
##      the removed background round the black outline, chroma ≤ `maxChroma`) get the outline
##      colour and an alpha from how light they are, so the edge is dark and soft.
##   2. measure: the top and the lowest pixel row (the soles: the ground contact), and the
##      column profile of the rows `stabilise.rows` (0 = top, 1 = soles: head, backpack and torso).
## Then:
##   3. stabilise: every frame is shifted so its soles touch the same row as frame 0 and its
##      torso profile best matches frame 0's (least absolute difference, ±`stabilise.search` px):
##      the cycle runs in place, the body does not jitter left / right.
##   4. pivot: the feet point = the median of the frames' hip centres (middle of the rows
##      `hipRows`), on the soles' row; the same pixel in every frame.
##   5. crop: one canvas round all the shifted frames (+`pad` px), the pivot at the same place.
##   6. scale once (Lanczos, premultiplied colour) so the figure is `height` world px tall ×
##      `oversample` texture px per world px; pxPerUnit = worldPxPerUnit × oversample.
## Animations (`anims`): `frames` are source frame indices (written as <anim>_<i>.png) or "idle"
## (reuse idle's PNGs, `count` entries: the code motion makes them move); `fallback`: the frames
## used when none of `frames` is there (a pose whose picture is missing); fps, loop, motion
## (scenes/character/character.gd: breathe, recoil, knockback, fall). Gun anchors: the grip
## follows the near fist (`gun.fists`, source px per frame) by `follow` from a carry point
## (`gun.carry`, source px from the pivot) and, in an anim with `swing`, tilts by up to
## `swingDeg` with the arm (forward = muzzle up); shoot /
## hurt angles and the shoot flash per frame from the anim; `front` false behind the body.
## A frame name may be a pose's (`poses`: a single drawn frame such as the standing idle or the
## ready pose; the anim's `stem` names its PNG), and `frames` may name another anim to reuse its PNG.
## The ready pose is the one the `draw` anim shows; any other pose (the standing idle, `stand`) is
## a body frame like the run frames: counted in the extent, no readyPose. A pose is cleaned at
## `workScale`: its `background` drawn into the pixels removed first (a flat colour, `key`: a solid
## green screen, key_background(); else a light checkerboard, remove_background()), then like a frame
## (its own `alphaCut` / `keepPieces` / `defringe`: the small detached pieces such as an AI sparkle
## go), trimmed to what is left, scaled by `scale` (source px per pose px) with its lowest row on the
## soles' row and `alignX` [pose x, source x] lined up, and resampled once into the shared canvas.
## `canvas` [x, y, w, h] (source px, optional) is always inside that canvas, so a new pose that fits
## leaves the run frames' PNGs as they were. A pose's `armFront` cuts its near arm (the sleeve from
## the shoulder to the fist and both fists) out of the cleaned pose (arm_mask(): flood fill from
## `seeds` inside `polygon`, pose px, the dark outline the barrier, grown over the outline) into its
## own PNG `stem` (default <pose>_arm_front) on the same canvas / pivot / scale, drawn over the hugged
## gun (the body keeps the arm too). side.json gets `readyPose` {anims, scene, armFront (that stem,
## with the cut)} and gun_anchors.json the ready pose's fallback `gun` seat (the draw anchors' grip:
## `gun.grip`, the hug point between the fists); the gun itself is placed by hand in the pose's scene
## (never written here). A pose without `gun.grip` holds the gun at the carry point (`gun.carry`).

const CutSheet := preload("res://tools/cut_sheet.gd")
const SRC := "res://art_source/characters/"

var _written := 0
var _bytes := 0


func _initialize() -> void:
	var found := configs_for(OS.get_cmdline_user_args())
	for id in found["unknown"]:
		push_error("import_frames: no art_source/characters/%s/side*/import.json (an id: rookie, tanko, spark, flora; or a config path)" % id)
	for c in found["configs"]:
		_import(str(c))
	print("import_frames: wrote %d files, %.1f KB" % [_written, _bytes / 1024.0])
	quit(1 if not found["unknown"].is_empty() else 0)


## The configs the command line names: {configs (paths), unknown (ids without one)}. An argument
## ending in .json is a config path; any other is a character id (its side*/import.json); none:
## every character's.
static func configs_for(args: Array) -> Dictionary:
	var configs: Array = []
	var unknown: Array = []
	for a in args:
		var arg := str(a).strip_edges()
		if arg == "":
			continue
		if arg.ends_with(".json"):
			configs.append(arg)
			continue
		var own := find_configs(arg.to_lower())
		if own.is_empty():
			unknown.append(arg)
		configs.append_array(own)
	if args.filter(func(a): return str(a).strip_edges() != "").is_empty():
		for id in DirAccess.get_directories_at(SRC):
			configs.append_array(find_configs(id))
	return {"configs": configs, "unknown": unknown}


## A character's configs: art_source/characters/<id>/side*/import.json.
static func find_configs(id: String) -> Array:
	var out: Array = []
	if id.is_empty() or not id.is_valid_filename() or not DirAccess.dir_exists_absolute(SRC + id):
		return out
	var subs := DirAccess.get_directories_at(SRC + id)
	subs.sort()
	for sub in subs:
		if sub.begins_with("side") and FileAccess.file_exists(SRC + "%s/%s/import.json" % [id, sub]):
			out.append(SRC + "%s/%s/import.json" % [id, sub])
	return out


## The source frame files of a config's `frames` (a list, or a pattern such as "frame_*.png":
## the matching files of dir in natural order).
static func frame_files(frames: Variant, dir: String) -> Array:
	if frames is Array:
		return frames.map(func(f): return str(f))
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.match(str(frames)):
			out.append(f)
	out.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	return out


## cfg.anims for n source frames and the poses that loaded: "all" is every frame, indices past
## the last frame and missing poses are dropped (none left: its `fallback` frames, filtered the
## same way), then an anim with no frame left and one reusing a dropped anim. Same order as cfg.anims.
static func resolve_anims(anims: Dictionary, n: int, poses: Array) -> Dictionary:
	var out := {}
	for anim in anims:
		var spec: Dictionary = anims[anim].duplicate(true)
		var fs = spec.get("frames")
		if str(fs) == "all":
			fs = range(n)
		var there := func(i): return poses.has(i) if i is String else int(i) >= 0 and int(i) < n
		if fs is Array:
			fs = fs.filter(there)
			if fs.is_empty() and spec.get("fallback") is Array:
				fs = spec["fallback"].filter(there)
			spec.erase("fallback")
			if fs.is_empty():
				continue
		elif not out.has(str(fs)) and str(fs) != "idle":
			continue
		spec["frames"] = fs
		out[anim] = spec
	for anim in out.keys(): # "idle" reused before it is listed, or dropped
		if not out[anim]["frames"] is Array and not out.has(str(out[anim]["frames"])):
			out.erase(anim)
	return out


## The ready pose of resolved anims: the pose the `draw` anim shows ("" without one).
static func ready_pose_name(anims: Dictionary) -> String:
	var fs = anims.get("draw", {}).get("frames")
	return str(fs[0]) if fs is Array and not fs.is_empty() and fs[0] is String else ""


func _import(cfg_path: String) -> void:
	var cfg = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	if not cfg is Dictionary:
		push_error("import_frames: %s missing or not a JSON object" % cfg_path)
		return
	var dir := cfg_path.get_base_dir() + "/"
	var out_dir := str(cfg["out"])
	var files := frame_files(cfg.get("frames", []), dir)
	if files.filter(func(f): return FileAccess.file_exists(dir + str(f))).is_empty():
		print("%s: no source frames yet (%s in %s), skipped" % [cfg_path, str(cfg.get("frames", [])), dir])
		return
	print("%s → %s" % [cfg_path, out_dir])
	# 1–2. Clean and measure every source frame.
	var frames: Array = [] # {image, top, bottom, profile, hip}
	for f in files:
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir + str(f)))
		if img == null or img.is_empty():
			push_error("import_frames: cannot read " + dir + str(f))
			return
		img.convert(Image.FORMAT_RGBA8)
		var removed := clean(img, cfg)
		var m := measure(img, cfg)
		if m.is_empty():
			push_error("import_frames: %s is empty after cleaning" % f)
			return
		m["image"] = img
		frames.append(m)
		print("  %s %dx%d: removed %d stray px, figure rows %d..%d" % [f, img.get_width(), img.get_height(), removed, m["top"], m["bottom"]])
	# 3. Stabilise against frame 0: soles on one row, torso profiles matched.
	var search := int(cfg.get("stabilise", {}).get("search", 40))
	var ref: Dictionary = frames[0]
	for fr in frames:
		var oy: int = int(ref["bottom"]) - int(fr["bottom"])
		var ox := best_shift(ref["profile"], fr["profile"], search)
		fr["offset"] = Vector2i(ox, oy)
	# 4. Pivot: the median hip centre (shifted), on the soles' row.
	var hips: Array = []
	for fr in frames:
		hips.append(float(fr["hip"]) + fr["offset"].x)
	hips.sort()
	var pivot := Vector2(hips[hips.size() / 2], float(ref["bottom"]) + 1.0)
	# Poses (single drawn frames, e.g. the ready-to-shoot pose): cleaned at their own size and
	# placed in the frames' source space by their scale and alignment.
	var poses := {} # name -> {image, sp, t, rect (source px of the frames), cfg, center}
	for pname in cfg.get("poses", {}):
		if not FileAccess.file_exists(dir + str(cfg["poses"][pname]["src"])):
			print("  pose %s: no %s yet, left out (and the animations showing it)" % [pname, dir + str(cfg["poses"][pname]["src"])])
			continue
		var pose := _load_pose(dir, cfg, str(pname), cfg["poses"][pname], ref)
		if pose.is_empty():
			return
		poses[str(pname)] = pose
	# 5. One canvas round every shifted frame (and every pose).
	var union := Rect2i()
	for fr in frames:
		var r: Rect2i = fr["rect"]
		r.position += fr["offset"]
		union = r if union.size == Vector2i.ZERO else union.merge(r)
	for pname in poses:
		union = union.merge(poses[pname]["rect"])
	if cfg.get("canvas") is Array and cfg["canvas"].size() >= 4: # pinned: the run frames' PNGs stay
		var pin := Rect2i(int(cfg["canvas"][0]), int(cfg["canvas"][1]), int(cfg["canvas"][2]), int(cfg["canvas"][3]))
		if not pin.encloses(union):
			print("  canvas %s does not hold every frame and pose %s: grown (the run frames' PNGs change)" % [pin, union])
		union = union.merge(pin)
	var fig_h := float(ref["bottom"]) + 1.0 - float(ref["top"])
	var oversample := float(cfg.get("oversample", 2.0))
	var s := float(cfg["height"]) * oversample / fig_h
	var pad_src := int(ceil(float(cfg.get("pad", 2)) / s))
	var origin := union.position - Vector2i(pad_src, pad_src)
	var src_size := union.size + Vector2i(2 * pad_src, 2 * pad_src)
	var out_size := Vector2i(int(ceil(src_size.x * s)), int(ceil(src_size.y * s)))
	src_size = Vector2i(int(round(out_size.x / s)), int(round(out_size.y / s)))
	var k := Vector2(float(out_size.x) / src_size.x, float(out_size.y) / src_size.y) # out px per source px
	var to_out := func(p: Vector2) -> Vector2: return (p - Vector2(origin)) * k
	var pivot_out: Vector2 = to_out.call(pivot)
	print("  stabilised: offsets %s; pivot %s source → %s px; canvas %s (from %s source px round %s, ×%.4f)" % [
		str(frames.map(func(fr): return fr["offset"])), pivot, pivot_out.snapped(Vector2(0.01, 0.01)), out_size, src_size, union, s])
	# 6. Scale each used frame once (a pose: straight from its own size, one resample).
	var outs := {} # source index or pose name -> Image
	var anims := resolve_anims(cfg["anims"], frames.size(), poses.keys())
	if not anims.has("idle"):
		push_error("import_frames: %s has no idle frame" % cfg_path)
		return
	for anim in anims:
		var fs = anims[anim]["frames"]
		if fs is Array:
			for i in fs:
				if i is String:
					if not poses.has(i):
						push_error("import_frames: %s uses the unknown pose %s" % [anim, i])
						return
					if not outs.has(i):
						outs[i] = _scaled_pose(poses[i]["image"], poses[i], origin, src_size, out_size)
				elif not outs.has(int(i)):
					outs[int(i)] = _scaled(frames[int(i)], origin, src_size, out_size)
	# The extent is the run / idle figure's (the ready pose is not counted: the motions use it).
	var ready_name := ready_pose_name(anims)
	var used := Rect2i()
	for i in outs:
		if str(i) == ready_name and i is String:
			continue
		var r: Rect2i = outs[i].get_used_rect()
		used = r if used.size == Vector2i.ZERO else used.merge(r)
	# Gun anchors: the grip follows the near fist from the carry point, tilting with the swing.
	var gun: Dictionary = cfg.get("gun", {})
	var carry := pivot + _v(gun.get("carry", [0, -fig_h * 0.33]))
	var follow := float(gun.get("follow", 0.35))
	var fists: Array = []
	for i in frames.size():
		var fist: Variant = gun.get("fists", [])[i] if i < gun.get("fists", []).size() else null
		fists.append(_v(fist) + Vector2(frames[i]["offset"]) if fist != null else carry)
	var fx_min := INF
	var fx_max := -INF
	for f in fists:
		fx_min = minf(fx_min, f.x)
		fx_max = maxf(fx_max, f.x)
	var fx_mid := (fx_min + fx_max) * 0.5
	var fx_half := maxf(1.0, (fx_max - fx_min) * 0.5)
	var hold := func(i: int, swing: bool) -> Dictionary:
		var f: Vector2 = fists[i]
		var grip: Vector2 = to_out.call(carry + (f - carry) * follow)
		var tilt := -float(gun.get("swingDeg", 0.0)) * (f.x - fx_mid) / fx_half if swing else 0.0
		return {"grip": [snappedf(grip.x, 0.01), snappedf(grip.y, 0.01)], "angle": snappedf(tilt, 0.01), "front": true, "flash": 0.0}
	# Write the frames and the description.
	var side_anims := {}
	var anchors := {}
	var idle_src: Variant = anims["idle"]["frames"][0] # a source index or a pose name
	var pose_hold := func(pname: String) -> Dictionary:
		var seat: Dictionary = poses[pname]["cfg"].get("gun", {})
		var grip: Vector2 = to_out.call(_pose_to_src(poses[pname], _v(seat["grip"])) if seat.has("grip") else carry)
		return {"grip": [snappedf(grip.x, 0.01), snappedf(grip.y, 0.01)], "angle": float(seat.get("angle", 0.0)), "front": true, "flash": 0.0}
	for anim in anims:
		var spec: Dictionary = anims[anim]
		var stems: Array = []
		var holds: Array = []
		if spec["frames"] is Array:
			for j in spec["frames"].size():
				var fi = spec["frames"][j]
				var stem := "%s_%d" % [str(spec.get("stem", anim)), j]
				_save(outs[fi if fi is String else int(fi)], out_dir + stem + ".png")
				stems.append(stem)
				holds.append(pose_hold.call(fi) if fi is String else hold.call(int(fi), bool(spec.get("swing", false))))
		else: # reuse the PNG of idle (or of the named anim)
			var from := str(spec["frames"])
			var reuse: Array = side_anims[from]["frames"] if side_anims.has(from) else ["idle_0"]
			var first = anims.get(from, {}).get("frames", [idle_src])[0] if anims.has(from) else idle_src
			for j in int(spec.get("count", 1)):
				stems.append(reuse[0])
				holds.append(pose_hold.call(first) if first is String else hold.call(int(first), false))
		for j in holds.size():
			var a: Dictionary = holds[j]
			if spec.has("angle"):
				a["angle"] = snappedf(float(a["angle"]) + float(spec["angle"][mini(j, spec["angle"].size() - 1)]), 0.01)
			if spec.has("flash"):
				a["flash"] = float(spec["flash"][mini(j, spec["flash"].size() - 1)])
			a["front"] = bool(spec.get("front", true))
		side_anims[anim] = {"frames": stems, "fps": float(spec.get("fps", 8)), "loop": bool(spec.get("loop", false)), "motion": str(spec.get("motion", ""))}
		anchors[anim] = holds
	var side := {
		"size": [out_size.x, out_size.y],
		"pivot": [snappedf(pivot_out.x, 0.01), snappedf(pivot_out.y, 0.01)],
		"pxPerUnit": snappedf(float(cfg.get("worldPxPerUnit", 0.35)) * oversample, 0.0001),
		"height": snappedf(fig_h * k.y, 0.01),
		"extent": {"back": snappedf(pivot_out.x - used.position.x, 0.01), "front": snappedf(used.end.x - pivot_out.x, 0.01),
			"top": snappedf(pivot_out.y - used.position.y, 0.01)},
		"anims": side_anims,
	}
	# The fist over a held gun's grip; a character with a ready pose holds its gun only there (hugged,
	# its own fists over it: scenes/character/character.gd), so it has none.
	var hand: Dictionary = cfg.get("hand", {})
	if not hand.is_empty() and poses.is_empty():
		_save(_cut_hand(frames[mini(int(hand["frame"]), frames.size() - 1)]["image"], _v(hand["center"]), float(hand["radius"]), float(hand.get("feather", 2.0)), s), out_dir + "hand.png")
		side["hand"] = "hand.png"
	if cfg.has("gunDraw") and (not cfg.has("poses") or not poses.is_empty()): # the ready pose's timings
		side["gunDraw"] = {}
		for key in cfg["gunDraw"]:
			if not str(key).begins_with("_"):
				side["gunDraw"][key] = cfg["gunDraw"][key]
	var anchors_out := {"frameSize": side["size"], "pivot": side["pivot"], "anims": anchors}
	# The ready pose's scene (one GunSocket for the held gun, edited in the editor: ui/art.gd
	# ready_pose()) and its fallback seat (the hug point).
	for pname in poses:
		if pname != ready_name:
			continue
		var pc: Dictionary = poses[pname]["cfg"]
		var pose_anims: Array = []
		for anim in anims:
			var fs = anims[anim]["frames"]
			var first = fs[0] if fs is Array else anims.get(str(fs), {}).get("frames", [null])[0]
			if str(first) == pname and first is String:
				pose_anims.append(anim)
		var info := {"anims": pose_anims}
		if pc.has("scene"):
			info["scene"] = str(pc["scene"])
		if poses[pname].has("arm"): # the near arm over the gun: same canvas, pivot and scale as the pose
			var stem := str(pc["armFront"].get("stem", "%s_arm_front" % pname))
			_save(_scaled_pose(poses[pname]["arm"], poses[pname], origin, src_size, out_size), out_dir + stem + ".png")
			info["armFront"] = stem
		side["readyPose"] = info
		if pc.has("gun"):
			var seat: Dictionary = pose_hold.call(pname)
			seat["anims"] = pose_anims
			anchors_out[pname] = seat
	_write_text(out_dir + "side.json", JSON.stringify(side, "\t", false) + "\n")
	_write_text(out_dir + "gun_anchors.json", JSON.stringify(anchors_out, "\t", false) + "\n")
	_report_feet(anims, outs, pivot_out, oversample)


## Clears the stray pixels and the white fringe in place; returns how many pixels it cleared.
static func clean(img: Image, cfg: Dictionary) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var px := img.get_data()
	var cut := int(cfg.get("alphaCut", 128))
	var removed := 0
	for i in n:
		if px[i * 4 + 3] < cut and px[i * 4 + 3] > 0:
			px[i * 4 + 3] = 0
			removed += 1
	# Connected pieces (8-connected); keep the ones at least keepPieces × the largest.
	var label := PackedInt32Array()
	label.resize(n)
	var sizes := PackedInt32Array([0])
	var stack := PackedInt32Array()
	for s in n:
		if px[s * 4 + 3] == 0 or label[s] != 0:
			continue
		var id := sizes.size()
		var count := 0
		stack.append(s)
		label[s] = id
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
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
					if label[j] == 0 and px[j * 4 + 3] != 0:
						label[j] = id
						stack.append(j)
		sizes.append(count)
	var largest := 0
	for id in range(1, sizes.size()):
		largest = maxi(largest, sizes[id])
	var min_keep := float(cfg.get("keepPieces", 0.02)) * largest
	for i in n:
		if label[i] != 0 and sizes[label[i]] < min_keep:
			px[i * 4 + 3] = 0
			removed += 1
	# Defringe: distance (4-steps) from the transparency, up to `band`.
	var df: Dictionary = cfg.get("defringe", {})
	var band := int(df.get("band", 2))
	if band > 0:
		var dist := PackedByteArray()
		dist.resize(n)
		dist.fill(255)
		var front := PackedInt32Array()
		for i in n:
			if px[i * 4 + 3] == 0:
				continue
			var x := i % w
			var y := i / w
			if (x > 0 and px[(i - 1) * 4 + 3] == 0) or (x < w - 1 and px[(i + 1) * 4 + 3] == 0) \
					or (y > 0 and px[(i - w) * 4 + 3] == 0) or (y < h - 1 and px[(i + w) * 4 + 3] == 0) \
					or x == 0 or y == 0 or x == w - 1 or y == h - 1:
				dist[i] = 1
				front.append(i)
		for d in range(2, band + 1):
			var next := PackedInt32Array()
			for i in front:
				var x := i % w
				for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
					if j >= 0 and j < n and px[j * 4 + 3] != 0 and dist[j] == 255:
						dist[j] = d
						next.append(j)
			front = next
		var oc: Array = df.get("outline", [24, 22, 30])
		var out_l := (float(oc[0]) + float(oc[1]) + float(oc[2])) / 3.0
		var max_chroma := int(df.get("maxChroma", 56))
		for i in n:
			if dist[i] == 255:
				continue
			var o := i * 4
			var r := px[o]
			var g := px[o + 1]
			var b := px[o + 2]
			var l := (r + g + b) / 3.0
			if l <= out_l or maxi(r, maxi(g, b)) - mini(r, mini(g, b)) > max_chroma:
				continue
			var a := clampf((255.0 - l) / (255.0 - out_l), 0.0, 1.0)
			px[o] = int(oc[0])
			px[o + 1] = int(oc[1])
			px[o + 2] = int(oc[2])
			px[o + 3] = int(round(px[o + 3] * a))
	img.set_data(w, h, false, Image.FORMAT_RGBA8, px)
	return removed


## {rect (opaque bbox), top, bottom (lowest opaque row), profile (opaque px per column in the
## stabilise rows), hip (the middle of the hip rows' spans, x)}; {} when empty.
static func measure(img: Image, cfg: Dictionary) -> Dictionary:
	var rect := img.get_used_rect()
	if rect.size == Vector2i.ZERO:
		return {}
	var w := img.get_width()
	var px := img.get_data()
	var top := rect.position.y
	var bottom := rect.end.y - 1
	var hgt := float(bottom - top)
	var rows: Array = cfg.get("stabilise", {}).get("rows", [0.0, 0.62])
	var profile := PackedInt32Array()
	profile.resize(w)
	for y in range(top + int(hgt * float(rows[0])), top + int(hgt * float(rows[1])) + 1):
		for x in range(rect.position.x, rect.end.x):
			if px[(y * w + x) * 4 + 3] > 127:
				profile[x] += 1
	var hr: Array = cfg.get("hipRows", [0.74, 0.8])
	var hip := 0.0
	var count := 0
	for y in range(top + int(hgt * float(hr[0])), top + int(hgt * float(hr[1])) + 1):
		var x0 := -1
		var x1 := -1
		for x in range(rect.position.x, rect.end.x):
			if px[(y * w + x) * 4 + 3] > 127:
				if x0 < 0:
					x0 = x
				x1 = x
		if x0 >= 0:
			hip += (x0 + x1 + 1) * 0.5
			count += 1
	return {"rect": rect, "top": top, "bottom": bottom, "profile": profile, "hip": hip / maxi(1, count)}


## The shift o (px) for which b(x - o) best matches a(x): least sum of absolute differences.
static func best_shift(a: PackedInt32Array, b: PackedInt32Array, search: int) -> int:
	var best := 0
	var best_cost := 1 << 62
	var w := a.size()
	for o in range(-search, search + 1):
		var cost := 0
		for x in w:
			var bx := x - o
			var bv := b[bx] if bx >= 0 and bx < w else 0
			cost += absi(a[x] - bv)
		if cost < best_cost or (cost == best_cost and absi(o) < absi(best)):
			best_cost = cost
			best = o
	return best


## A frame shifted by its offset into the shared canvas, then scaled once (Lanczos on
## premultiplied colour).
static func _scaled(fr: Dictionary, origin: Vector2i, src_size: Vector2i, out_size: Vector2i) -> Image:
	var src: Image = fr["image"]
	var canvas := Image.create(src_size.x, src_size.y, false, Image.FORMAT_RGBA8)
	var from := Rect2i(origin - Vector2i(fr["offset"]), src_size)
	var clip := from.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
	canvas.blit_rect(src, clip, clip.position - from.position)
	canvas.premultiply_alpha()
	canvas.resize(out_size.x, out_size.y, Image.INTERPOLATE_LANCZOS)
	var out := CutSheet._unpremultiply(canvas)
	_clear_faint(out)
	return out


## Lanczos rings: clears the near-invisible alpha it leaves round the figure.
static func _clear_faint(img: Image) -> void:
	var data := img.get_data()
	for o in range(0, data.size(), 4):
		if data[o + 3] < 4:
			data[o] = 0
			data[o + 1] = 0
			data[o + 2] = 0
			data[o + 3] = 0
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)


## A pose (cfg.poses[name]): its source image cleaned (the background first when it is drawn into
## the pixels, then like a frame) and placed in the frames' source space: sp source px per pose
## px, the pose's lowest row on the frames' sole row (both stand on the same ground) and its
## `alignX` [pose x, source x] column on that source column (e.g. the belt buckle on the idle
## frame's: the body does not jump on a switch). {} on an error.
func _load_pose(dir: String, cfg: Dictionary, pname: String, pc: Dictionary, ref: Dictionary) -> Dictionary:
	var path := dir + str(pc["src"])
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		push_error("import_frames: cannot read " + path)
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var ws := float(pc.get("workScale", 1.0)) # cleaned at this size (pose px stay the source's)
	if ws != 1.0:
		img.resize(int(round(img.get_width() * ws)), int(round(img.get_height() * ws)), Image.INTERPOLATE_LANCZOS)
	var bg := 0
	if pc.get("background") is Dictionary:
		bg = key_background(img, pc["background"]) if pc["background"].has("key") else remove_background(img, pc["background"])
	var pcfg := cfg.duplicate(true)
	for key in ["alphaCut", "keepPieces", "defringe"]:
		if pc.has(key):
			pcfg[key] = pc[key]
	var removed := clean(img, pcfg)
	var wrect := img.get_used_rect() # trimmed: what is left of the figure
	if wrect.size == Vector2i.ZERO:
		push_error("import_frames: pose %s is empty after cleaning" % pname)
		return {}
	# The near arm drawn over the gun: cut from the cleaned pose (the same keying and cleanup).
	var arm: Image = null
	if pc.get("armFront") is Dictionary:
		var am := arm_mask(img, pc["armFront"], ws)
		var count := 0
		for v in am:
			if v > 0.0:
				count += 1
		if count == 0:
			push_warning("import_frames: pose %s armFront cut nothing (check its seeds / polygon), no arm layer" % pname)
		else:
			arm = apply_mask(img, am)
			print("  pose %s armFront: %d px" % [pname, count])
	var rect := Rect2(Vector2(wrect.position) / ws, Vector2(wrect.size) / ws)
	var sp := float(pc["scale"])
	var ax: Array = pc.get("alignX", [rect.get_center().x, ref["hip"]])
	var t := Vector2(float(ax[1]) - float(ax[0]) * sp, float(ref["bottom"]) + 1.0 - float(rect.end.y) * sp)
	var pose := {"image": img, "sp": sp, "t": t, "cfg": pc, "ws": ws, "center": rect.get_center()}
	if arm != null:
		pose["arm"] = arm
	var a := _pose_to_src(pose, Vector2(rect.position))
	var b := _pose_to_src(pose, Vector2(rect.end))
	pose["rect"] = Rect2i(Vector2i(floori(a.x), floori(a.y)), Vector2i(ceili(b.x) - floori(a.x), ceili(b.y) - floori(a.y)))
	print("  pose %s %dx%d (×%.2f): background %d px, removed %d stray px, figure %s pose px → source %s (×%.4f)" % [
		pname, img.get_width(), img.get_height(), ws, bg, removed, rect, pose["rect"], sp])
	return pose


static func _pose_to_src(pose: Dictionary, p: Vector2) -> Vector2:
	return pose["t"] + p * float(pose["sp"])


## A pose image cut to the frames' canvas (the source rect origin..origin+src_size, mapped back to
## pose px) and scaled once to out_size.
static func _scaled_pose(img: Image, pose: Dictionary, origin: Vector2i, src_size: Vector2i, out_size: Vector2i) -> Image:
	var sp := float(pose["sp"]) / float(pose.get("ws", 1.0)) # source px per work px
	var p0: Vector2 = (Vector2(origin) - pose["t"]) / float(pose["sp"]) * float(pose.get("ws", 1.0))
	var size := Vector2i(int(round(src_size.x / sp)), int(round(src_size.y / sp)))
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var from := Rect2i(Vector2i(int(round(p0.x)), int(round(p0.y))), size)
	var clip := from.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	canvas.blit_rect(img, clip, clip.position - from.position)
	canvas.premultiply_alpha()
	canvas.resize(out_size.x, out_size.y, Image.INTERPOLATE_LANCZOS)
	var out := CutSheet._unpremultiply(canvas)
	_clear_faint(out)
	return out


## A part of a drawn figure with thick dark outlines (a pose's near arm) as a mask (0..1 per pixel
## of img): the pixels 4-connected to `seeds` [[x, y], ...] through non-dark opaque pixels inside
## `polygon` [[x, y], ...] (the region it may take: where an outline is open, its edge is the cut),
## dark = max(r, g, b) ≤ `darkMax` (the outline is the barrier); grown `grow` px (4-steps) over the
## dark opaque pixels inside the polygon (it keeps its own outline), then the holes it encloses
## filled (the creases, a detail drawn in another colour); the edge feathered inward over `feather`
## px (the kept share of a (2f+1)² box, nothing outside the cut). Coordinates in the config's px, img
## at ws × them. A seed on a dark, clear or outside pixel is skipped with a warning. Pure.
static func arm_mask(img: Image, ac: Dictionary, ws: float = 1.0) -> PackedFloat32Array:
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var px := img.get_data()
	var mask := PackedFloat32Array()
	mask.resize(n)
	var poly := PackedVector2Array()
	for p in ac.get("polygon", []):
		poly.append(_v(p) * ws)
	if poly.size() < 3:
		push_warning("import_frames: armFront needs a polygon of 3 points or more")
		return mask
	var lo := poly[0]
	var hi := poly[0]
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	# The work box: the polygon's bounds and a 1 px clear border (outside the polygon).
	var x0 := clampi(floori(lo.x) - 1, 0, w)
	var y0 := clampi(floori(lo.y) - 1, 0, h)
	var x1 := clampi(ceili(hi.x) + 2, 0, w)
	var y1 := clampi(ceili(hi.y) + 2, 0, h)
	var bw := x1 - x0
	var bh := y1 - y0
	if bw <= 0 or bh <= 0:
		return mask
	var dark_max := int(ac.get("darkMax", 80))
	var cls := PackedByteArray() # 0 outside the polygon or clear, 1 dark, 2 open
	cls.resize(bw * bh)
	for y in bh:
		for x in bw:
			var gx := x0 + x
			var gy := y0 + y
			if not Geometry2D.is_point_in_polygon(Vector2(gx + 0.5, gy + 0.5), poly):
				continue
			var o := (gy * w + gx) * 4
			if px[o + 3] == 0:
				continue
			cls[y * bw + x] = 1 if maxi(px[o], maxi(px[o + 1], px[o + 2])) <= dark_max else 2
	var m := PackedByteArray()
	m.resize(bw * bh)
	var stack := PackedInt32Array()
	for sd in ac.get("seeds", []):
		var sp := (_v(sd) * ws).floor()
		var sx := int(sp.x) - x0
		var sy := int(sp.y) - y0
		if sx < 0 or sy < 0 or sx >= bw or sy >= bh or cls[sy * bw + sx] != 2:
			push_warning("import_frames: armFront seed %s is not on an open pixel inside the polygon, skipped" % str(sd))
			continue
		if m[sy * bw + sx] == 1:
			continue
		m[sy * bw + sx] = 1
		stack.append(sy * bw + sx)
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x := i % bw
			for j in [i - 1 if x > 0 else -1, i + 1 if x < bw - 1 else -1, i - bw, i + bw]:
				if j >= 0 and j < bw * bh and m[j] == 0 and cls[j] == 2:
					m[j] = 1
					stack.append(j)
	# Grow over the outline (dark, inside the polygon).
	var front := PackedInt32Array()
	for i in bw * bh:
		if m[i] == 1:
			front.append(i)
	for d in int(round(float(ac.get("grow", 6)) * ws)):
		var next := PackedInt32Array()
		for i in front:
			var x := i % bw
			for j in [i - 1 if x > 0 else -1, i + 1 if x < bw - 1 else -1, i - bw, i + bw]:
				if j >= 0 and j < bw * bh and m[j] == 0 and cls[j] == 1:
					m[j] = 1
					next.append(j)
		front = next
	# Holes: what the box border cannot reach without crossing the cut.
	var out := PackedByteArray()
	out.resize(bw * bh)
	for y in bh:
		for x in bw:
			if (x == 0 or y == 0 or x == bw - 1 or y == bh - 1) and m[y * bw + x] == 0:
				out[y * bw + x] = 1
				stack.append(y * bw + x)
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % bw
		for j in [i - 1 if x > 0 else -1, i + 1 if x < bw - 1 else -1, i - bw, i + bw]:
			if j >= 0 and j < bw * bh and out[j] == 0 and m[j] == 0:
				out[j] = 1
				stack.append(j)
	var f := maxi(0, int(round(float(ac.get("feather", 1)) * ws)))
	for y in bh:
		for x in bw:
			if out[y * bw + x] == 1:
				continue
			var k := 1.0
			if f > 0:
				var sum := 0.0
				var cnt := 0.0
				for dy in range(-f, f + 1):
					for dx in range(-f, f + 1):
						var xx := x + dx
						var yy := y + dy
						cnt += 1.0
						if xx >= 0 and yy >= 0 and xx < bw and yy < bh and out[yy * bw + xx] == 0:
							sum += 1.0
				k = sum / cnt
			mask[(y0 + y) * w + x0 + x] = k
	return mask


## A copy of img with its alpha × mask (one value per pixel, 0..1).
static func apply_mask(img: Image, mask: PackedFloat32Array) -> Image:
	var out: Image = img.duplicate()
	out.convert(Image.FORMAT_RGBA8)
	var px := out.get_data()
	for i in mini(mask.size(), px.size() / 4):
		var k := mask[i]
		if k < 1.0:
			px[i * 4 + 3] = int(round(px[i * 4 + 3] * clampf(k, 0.0, 1.0)))
	out.set_data(out.get_width(), out.get_height(), false, Image.FORMAT_RGBA8, px)
	return out


## The background colour of an image on a flat backdrop (a solid green screen): per channel the
## median of the pixels in the four `corner` px squares (the picture's corners are backdrop).
static func corner_colour(img: Image, corner: int = 8) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var c := clampi(corner, 1, mini(w, h))
	var ch: Array = [[], [], []]
	for o in [Vector2i(0, 0), Vector2i(w - c, 0), Vector2i(0, h - c), Vector2i(w - c, h - c)]:
		for y in range(o.y, o.y + c):
			for x in range(o.x, o.x + c):
				var col := img.get_pixel(x, y)
				ch[0].append(col.r)
				ch[1].append(col.g)
				ch[2].append(col.b)
	for a in ch:
		a.sort()
	return Color(ch[0][ch[0].size() / 2], ch[1][ch[1].size() / 2], ch[2][ch[2].size() / 2])


## A flat background colour keyed out in place (bg.key: "corners", the corner_colour() of the image,
## or [r, g, b] 0..255). d = a pixel's RGB distance (0..441) to the key. The backdrop is every pixel
## with d < `tolerance` + `soft` connected to the border (4-connected), plus the enclosed pieces of
## at least `holeMin` px that are mostly (≥ `holePure`, default half) the key itself (d < tolerance:
## between an arm and the body; 0 takes a shaded pocket of backdrop too); the art's own greens are farther from the key or enclosed and small. On the backdrop
## alpha = (d - tolerance) / soft (0..1): the soft edge; a partly keyed pixel's colour is un-blended
## from the key (p = a·c + (1 - a)·key). Spill: within `spill` px (4-steps) of the cleared pixels the
## key's strongest channel is capped at the larger of the other two (no green rim on the dark
## outline); `spillFrom` "keyed" measures that band from every backdrop pixel, the partly keyed
## ones too (a thin wedge of backdrop between hair strands, a small pocket whose middle only
## alphaCut clears: their green rim is farther than `spill` from a fully cleared pixel). The key
## may be any flat colour: a green screen's spill is its green (capped at the larger of red / blue),
## a magenta (or other two-channel) backdrop's is the part of its two channels above the third
## (key_channels(): both lowered by it, so a pink rim turns grey, a red keeps its red). `glow`
## {colour [r, g, b], fit (RGB distance, default 40), alpha (× the glow's alpha, default 1; 0 keys
## it away), max (default 0.95)}: a soft glow the art painted into the backdrop (a glowing crystal)
## is un-mixed from it: a pixel on the line from the key to that colour (no farther than `fit`, less
## than `max` of the way), reached from the backdrop through such pixels, is that colour at the
## alpha of how far along it is (faded in over the soft edge), so no key tint is left in it; the
## spill band is measured from it too. Returns
## how many pixels it cleared (alpha 0). Pure: only img changes.
static func key_background(img: Image, bg: Dictionary) -> int:
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var px := img.get_data()
	var key := corner_colour(img, int(bg.get("corner", 8)))
	if bg.get("key") is Array and bg["key"].size() >= 3:
		key = Color8(int(bg["key"][0]), int(bg["key"][1]), int(bg["key"][2]))
	var kr := key.r * 255.0
	var kg := key.g * 255.0
	var kb := key.b * 255.0
	var tol := float(bg.get("tolerance", 45.0))
	var soft := maxf(0.001, float(bg.get("soft", 45.0)))
	var dist := PackedFloat32Array()
	dist.resize(n)
	var near := PackedByteArray()
	near.resize(n)
	for i in n:
		var o := i * 4
		var dr := px[o] - kr
		var dg := px[o + 1] - kg
		var db := px[o + 2] - kb
		var d := sqrt(dr * dr + dg * dg + db * db)
		dist[i] = d
		near[i] = 1 if d < tol + soft else 0
	# The backdrop: the near-key pieces touching the border, and the big enclosed ones of pure key.
	var label := PackedInt32Array()
	label.resize(n)
	var stack := PackedInt32Array()
	stack.resize(n)
	var hole_min := int(bg.get("holeMin", 200))
	var hole_pure := float(bg.get("holePure", 0.5))
	var backdrop := PackedByteArray([0])
	for s in n:
		if near[s] == 0 or label[s] != 0:
			continue
		var id := backdrop.size()
		var size := 0
		var pure := 0
		var border := false
		var top := 1
		stack[0] = s
		label[s] = id
		while top > 0:
			top -= 1
			var i: int = stack[top]
			size += 1
			if dist[i] < tol:
				pure += 1
			var x := i % w
			var y := i / w
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				border = true
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
				if j >= 0 and near[j] == 1 and label[j] == 0:
					label[j] = id
					stack[top] = j
					top += 1
		backdrop.append(1 if border or (size >= hole_min and pure >= size * hole_pure) else 0)
	var glow_a := _glow(px, w, h, dist, label, backdrop, key, tol, bg.get("glow"))
	var cleared := 0
	var gone := PackedByteArray()
	gone.resize(n)
	var from_keyed := str(bg.get("spillFrom", "cleared")) == "keyed"
	var chans := key_channels(key)
	var kc: int = chans[0] # the key's strongest channel
	var kc2: int = chans[1] if chans.size() > 1 else -1 # a magenta key's other one
	for i in n:
		var glowing := not glow_a.is_empty() and glow_a[i] >= 0.0
		if (label[i] == 0 or backdrop[label[i]] == 0) and not glowing:
			continue
		if from_keyed:
			gone[i] = 1
		var o := i * 4
		var a := clampf((dist[i] - tol) / soft, 0.0, 1.0)
		if glowing: # the glow's colour at its own alpha (faded in over the soft edge)
			var mix := glow_a[i]
			var keep := a * mix * float(bg["glow"].get("alpha", 1.0)) if dist[i] < tol + soft else mix * float(bg["glow"].get("alpha", 1.0))
			if keep <= 0.0 or mix <= 0.0:
				px[o] = 0
				px[o + 1] = 0
				px[o + 2] = 0
				px[o + 3] = 0
				gone[i] = 1
				cleared += 1
				continue
			px[o] = clampi(roundi((px[o] - (1.0 - mix) * kr) / mix), 0, 255)
			px[o + 1] = clampi(roundi((px[o + 1] - (1.0 - mix) * kg) / mix), 0, 255)
			px[o + 2] = clampi(roundi((px[o + 2] - (1.0 - mix) * kb) / mix), 0, 255)
			px[o + 3] = roundi(px[o + 3] * clampf(keep, 0.0, 1.0))
			gone[i] = 1 # the spill band starts at the glow too (the outline's tinted rim next to it)
			continue
		if a <= 0.0:
			px[o] = 0
			px[o + 1] = 0
			px[o + 2] = 0
			px[o + 3] = 0
			gone[i] = 1
			cleared += 1
			continue
		px[o] = clampi(roundi((px[o] - (1.0 - a) * kr) / a), 0, 255)
		px[o + 1] = clampi(roundi((px[o + 1] - (1.0 - a) * kg) / a), 0, 255)
		px[o + 2] = clampi(roundi((px[o + 2] - (1.0 - a) * kb) / a), 0, 255)
		px[o + 3] = roundi(px[o + 3] * a)
		if from_keyed and kc2 >= 0: # a partly keyed pixel is despilled too (it starts the band)
			var excess := mini(px[o + kc], px[o + kc2]) - px[o + 3 - kc - kc2]
			if excess > 0:
				px[o + kc] -= excess
				px[o + kc2] -= excess
		elif from_keyed:
			px[o + kc] = mini(px[o + kc], maxi(px[o + (kc + 1) % 3], px[o + (kc + 2) % 3]))
	# Despill the band next to the cleared (or keyed) pixels: the key's channel no stronger than the others.
	var band := int(bg.get("spill", 3))
	if band > 0:
		var front := PackedInt32Array()
		var seen := gone.duplicate()
		for i in n:
			if gone[i] == 1:
				front.append(i)
		for d in band:
			var next := PackedInt32Array()
			for i in front:
				var x := i % w
				for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
					if j < 0 or j >= n or seen[j] == 1:
						continue
					seen[j] = 1
					next.append(j)
					var o: int = j * 4
					if kc2 >= 0: # magenta: the part of both key channels above the third
						var excess := mini(px[o + kc], px[o + kc2]) - px[o + 3 - kc - kc2]
						if excess > 0:
							px[o + kc] -= excess
							px[o + kc2] -= excess
						continue
					var cap := maxi(px[o + (kc + 1) % 3], px[o + (kc + 2) % 3])
					if px[o + kc] > cap:
						px[o + kc] = cap
			front = next
	img.set_data(w, h, false, Image.FORMAT_RGBA8, px)
	return cleared


## The channels (0 r, 1 g, 2 b) a key colour's spill shows in: [its strongest] (a green screen:
## [1]), or [strongest, second] when the second is at least half the strongest and the third is
## not (a magenta backdrop: [0, 2]).
static func key_channels(key: Color) -> Array:
	var c := [key.r, key.g, key.b]
	var k := 0 if c[0] >= c[1] and c[0] >= c[2] else (1 if c[1] >= c[2] else 2)
	var a := (k + 1) % 3
	var b := (k + 2) % 3
	var second := a if c[a] >= c[b] else b
	var third := 3 - k - second
	if c[second] >= 0.5 * c[k] and c[third] < 0.5 * c[k]:
		return [k, second]
	return [k]


## key_background() `glow`: per pixel how far along the line from the key to the glow colour it is
## (0..1; -1: not glow), for the pixels on that line (within `fit`, below `max`) reached from the
## backdrop pieces through such pixels (4-connected) and the backdrop pixels themselves that are on
## it beyond the pure key (d ≥ tolerance); empty without a glow colour.
static func _glow(px: PackedByteArray, w: int, h: int, dist: PackedFloat32Array, label: PackedInt32Array, backdrop: PackedByteArray, key: Color, tol: float, cfg: Variant) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not cfg is Dictionary or not cfg.get("colour") is Array or cfg["colour"].size() < 3:
		return out
	var k := Vector3(key.r, key.g, key.b) * 255.0
	var line := Vector3(float(cfg["colour"][0]), float(cfg["colour"][1]), float(cfg["colour"][2])) - k
	var len2 := maxf(1.0, line.length_squared())
	var fit := float(cfg.get("fit", 40.0))
	var top := float(cfg.get("max", 0.95))
	var n := w * h
	out.resize(n)
	out.fill(-1.0)
	var on := PackedFloat32Array()
	on.resize(n)
	for i in n:
		var o := i * 4
		var d := Vector3(px[o], px[o + 1], px[o + 2]) - k
		var t := clampf(d.dot(line) / len2, 0.0, 1.0)
		on[i] = t if t < top and (d - line * t).length() <= fit else -1.0
	var stack := PackedInt32Array()
	for i in n:
		if label[i] != 0 and backdrop[label[i]] == 1:
			if on[i] >= 0.0 and dist[i] >= tol:
				out[i] = on[i]
			stack.append(i)
	var seen := PackedByteArray()
	seen.resize(n)
	for i in stack:
		seen[i] = 1
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x := i % w
		var y := i / w
		for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1]:
			if j >= 0 and seen[j] == 0 and on[j] >= 0.0:
				seen[j] = 1
				out[j] = on[j]
				stack.append(j)
	return out


## A background drawn into the pixels (a fake transparency checkerboard, a watermark on it)
## cleared in place: the light, grey pixels (lum ≥ `minLum`, chroma ≤ `maxChroma`) connected to
## the image border (4-connected) and, enclosed by the figure (between an arm and the body, the
## legs), every other such piece of at least `holeMin` px that is the checkerboard: at least
## `holeTones` of it in each of its two `tones` [[lo, hi], [lo, hi]] (lum) and nearly all of it in
## one of them, so eye whites and highlights stay. Returns how many pixels it cleared.
static func remove_background(img: Image, bg: Dictionary) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h
	var px := img.get_data()
	var min_lum := float(bg.get("minLum", 200))
	var max_chroma := int(bg.get("maxChroma", 24))
	var like := PackedByteArray()
	like.resize(n)
	var lum := PackedByteArray()
	lum.resize(n)
	for i in n:
		var o := i * 4
		var r := px[o]
		var g := px[o + 1]
		var b := px[o + 2]
		var l := (r + g + b) / 3.0
		lum[i] = int(l)
		if l >= min_lum and maxi(r, maxi(g, b)) - mini(r, mini(g, b)) <= max_chroma:
			like[i] = 1
	# Label the background-like pieces; the ones touching the border are the background.
	var label := PackedInt32Array()
	label.resize(n)
	var stack := PackedInt32Array()
	stack.resize(n)
	var tones: Array = bg.get("tones", [[230, 244], [248, 255]])
	var t0a := int(tones[0][0])
	var t0b := int(tones[0][1])
	var t1a := int(tones[1][0])
	var t1b := int(tones[1][1])
	var hole_min := int(bg.get("holeMin", 400))
	var hole_tones := float(bg.get("holeTones", 0.15))
	var clear := PackedByteArray([0])
	var next_id := 1
	for s in n:
		if like[s] == 0 or label[s] != 0:
			continue
		var id := next_id
		next_id += 1
		var size := 0
		var c0 := 0
		var c1 := 0
		var border := false
		var top := 0
		stack[0] = s
		top = 1
		label[s] = id
		while top > 0:
			top -= 1
			var i: int = stack[top]
			size += 1
			var l := lum[i]
			if l >= t0a and l <= t0b:
				c0 += 1
			elif l >= t1a and l <= t1b:
				c1 += 1
			var x := i % w
			var y := i / w
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				border = true
			if x > 0 and like[i - 1] == 1 and label[i - 1] == 0:
				label[i - 1] = id
				stack[top] = i - 1
				top += 1
			if x < w - 1 and like[i + 1] == 1 and label[i + 1] == 0:
				label[i + 1] = id
				stack[top] = i + 1
				top += 1
			if y > 0 and like[i - w] == 1 and label[i - w] == 0:
				label[i - w] = id
				stack[top] = i - w
				top += 1
			if y < h - 1 and like[i + w] == 1 and label[i + w] == 0:
				label[i + w] = id
				stack[top] = i + w
				top += 1
		var sz := float(size)
		var hole := sz >= hole_min and c0 / sz >= hole_tones and c1 / sz >= hole_tones and (c0 + c1) / sz >= 0.9
		clear.append(1 if border or hole else 0)
		if hole and not border:
			print("    enclosed checkerboard piece: %d px" % size)
	var cleared := 0
	for i in n:
		if label[i] != 0 and clear[label[i]] == 1:
			px[i * 4 + 3] = 0
			cleared += 1
	img.set_data(w, h, false, Image.FORMAT_RGBA8, px)
	return cleared


## A round cut (radius px, soft edge) of the cleaned frame centred on `center`, scaled by s.
static func _cut_hand(src: Image, center: Vector2, radius: float, feather: float, s: float) -> Image:
	var r := int(ceil(radius + feather))
	var size := 2 * r + 1
	var cut := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2i(int(round(center.x)), int(round(center.y)))
	var from := Rect2i(c - Vector2i(r, r), Vector2i(size, size))
	var clip := from.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
	cut.blit_rect(src, clip, clip.position - from.position)
	for y in size:
		for x in size:
			var col := cut.get_pixel(x, y)
			var d := Vector2(x - r, y - r).length()
			col.a *= clampf((radius - d) / feather + 0.5, 0.0, 1.0)
			cut.set_pixel(x, y, col)
	cut.premultiply_alpha()
	var o := maxi(1, int(round(size * s)))
	cut.resize(o, o, Image.INTERPOLATE_LANCZOS)
	var out := CutSheet._unpremultiply(cut)
	_clear_faint(out)
	return out


## Prints where the soles touch the ground per walk frame (px from the pivot, world px) to tune
## the walk fps against the walk speed: a planted foot should move back by speed / fps per frame.
func _report_feet(anims: Dictionary, outs: Dictionary, pivot: Vector2, oversample: float) -> void:
	if not anims.has("walk") or not anims["walk"]["frames"] is Array:
		return
	var line := "  walk soles (world px from the pivot, the 3 rows over the pivot):"
	for si in anims["walk"]["frames"]:
		var img: Image = outs[int(si)]
		var y1 := int(round(pivot.y))
		var x0 := INF
		var x1 := -INF
		for y in range(y1 - 3, y1):
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.25:
					x0 = minf(x0, x)
					x1 = maxf(x1, x)
		line += " [%.1f, %.1f]" % [(x0 - pivot.x) / oversample, (x1 + 1 - pivot.x) / oversample]
	print(line)


static func _v(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() >= 2 else Vector2.ZERO


func _save(img: Image, path: String) -> void:
	if not path.ends_with(".png"):
		push_error("import_frames: refusing to write " + path)
		return
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if not FileAccess.file_exists(abs_path + ".import"):
		var f := FileAccess.open(abs_path + ".import", FileAccess.WRITE)
		f.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\n')
		f.close()
	var err := img.save_png(abs_path)
	if err != OK:
		push_error("import_frames: cannot write %s (%s)" % [path, error_string(err)])
		return
	var bytes := FileAccess.get_file_as_bytes(abs_path).size()
	_written += 1
	_bytes += bytes
	print("  %s  %dx%d  %.1f KB" % [path, img.get_width(), img.get_height(), bytes / 1024.0])


func _write_text(path: String, text: String) -> void:
	if not path.ends_with(".json"): # PNG and JSON only: never a (hand-placed) scene
		push_error("import_frames: refusing to write " + path)
		return
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	_written += 1
	_bytes += text.length()
	print("  %s  %.1f KB" % [path, text.length() / 1024.0])
