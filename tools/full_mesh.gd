extends RefCounted
## The skinned mesh of a full-body picture (assets/characters/<id>/lobby/full.png, drawn by
## scenes/character/full_body.gd): built by tools/cut_sheet.gd (lineup mode) and stored in
## full.json. Only Image is used (headless).
##
## build(): points along the outline of the visible pixels grown by DILATE px (one every
## EDGE_STEP px) plus a staggered grid inside (INNER_STEP), Delaunay-triangulated; a triangle is
## kept when it lies inside the grown outline (so the gaps between an arm and the body, and the
## holes, stay out of the mesh), then every visible pixel left uncovered becomes a point and the
## mesh is re-triangulated (a few rounds). At rest the mesh maps the picture 1:1 (uv = vertex).
## weights(): per vertex, up to 4 bones by the geodesic distance through the figure's own
## pixels (a raised hand next to the head is far from the head's bone: the path goes round by
## the shoulder), w = strength / (d + SOFT)^3, normalised.

const DILATE := 2.0
const EDGE_STEP := 5.0
const INNER_STEP := 13.0
const VISIBLE := 0.02 # alpha that must be covered
const SOLID := 0.3 # alpha a geodesic path may cross
const SOFT := 6.0
const MAX_BONES := 4
const MIN_WEIGHT := 0.02


## {vertices: PackedVector2Array (px in the picture), triangles: PackedInt32Array (3 indices
## each), gaps: visible pixels no triangle covers (0 when clean)}.
static func build(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var alpha := _alpha(img)
	var visible := PackedByteArray()
	visible.resize(w * h)
	for i in w * h:
		visible[i] = 1 if alpha[i] > 0.004 else 0
	var d_out := _distance(visible, w, h, true) # px to the nearest visible pixel
	var grown := PackedByteArray()
	grown.resize(w * h)
	var loose := PackedByteArray()
	loose.resize(w * h)
	for i in w * h:
		grown[i] = 1 if d_out[i] <= DILATE else 0
		loose[i] = 1 if d_out[i] <= DILATE + 2.5 else 0
	var depth := _distance(grown, w, h, false) # px inside the grown outline
	var points := PackedVector2Array()
	var hash := {}
	# The outline.
	for y in h:
		for x in w:
			var i := y * w + x
			if grown[i] == 0:
				continue
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1 or grown[i - 1] == 0 or grown[i + 1] == 0 or grown[i - w] == 0 or grown[i + w] == 0
			if edge:
				_add_spaced(points, hash, Vector2(x + 0.5, y + 0.5), EDGE_STEP)
	# The inside.
	var row := 0
	var gy := INNER_STEP * 0.5
	while gy < h:
		var gx := INNER_STEP * (0.5 if row % 2 == 0 else 1.0)
		while gx < w:
			var i := int(gy) * w + int(gx)
			if grown[i] == 1 and depth[i] >= EDGE_STEP * 0.8:
				_add_spaced(points, hash, Vector2(gx, gy), EDGE_STEP)
			gx += INNER_STEP
		gy += INNER_STEP * 0.866
		row += 1
	var tris := PackedInt32Array()
	var gaps := 0
	for round in 5:
		tris = _triangulate(points, loose, w, h)
		var cov := _coverage(points, tris, w, h)
		var missing := PackedVector2Array()
		for i in w * h:
			if alpha[i] > VISIBLE and cov[i] == 0:
				missing.append(Vector2(i % w + 0.5, i / w + 0.5))
		gaps = missing.size()
		if gaps == 0:
			break
		for p in missing:
			_add_spaced(points, hash, p, 1.5)
	return {"vertices": points, "triangles": tris, "gaps": gaps}


## Visible pixels (alpha > VISIBLE) no triangle covers.
static func gaps(img: Image, vertices: PackedVector2Array, triangles: PackedInt32Array) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var alpha := _alpha(img)
	var cov := _coverage(vertices, triangles, w, h)
	var n := 0
	for i in w * h:
		if alpha[i] > VISIBLE and cov[i] == 0:
			n += 1
	return n


## Per vertex the bones moving it: [[bone index, weight], ...] (at most MAX_BONES, summing to
## 1). bones: [{at, tip (Vector2 px), strength}] (strength 0: moves no vertex).
static func weights(img: Image, vertices: PackedVector2Array, bones: Array) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var alpha := _alpha(img)
	var solid := PackedByteArray()
	solid.resize(w * h)
	for i in w * h:
		solid[i] = 1 if alpha[i] > SOLID else 0
	# Each vertex reads the distances at the nearest solid pixel.
	var at_px := PackedInt32Array()
	for v in vertices:
		at_px.append(_nearest_solid(solid, w, h, v))
	var per_bone: Array = []
	for b in bones:
		if float(b.get("strength", 1.0)) <= 0.0:
			per_bone.append(null)
			continue
		per_bone.append(_geodesic(solid, w, h, b["at"], b["tip"]))
	var out: Array = []
	for vi in vertices.size():
		var cand: Array = []
		for bi in bones.size():
			var s := float(bones[bi].get("strength", 1.0))
			if s <= 0.0:
				continue
			var d: float
			var p: int = at_px[vi]
			if p >= 0 and per_bone[bi][p] < INF:
				d = per_bone[bi][p] + vertices[vi].distance_to(Vector2(p % w + 0.5, p / w + 0.5))
			else:
				d = _segment_distance(vertices[vi], bones[bi]["at"], bones[bi]["tip"]) * 2.0
			cand.append([bi, s / pow(d + SOFT, 3.0)])
		cand.sort_custom(func(a, b): return a[1] > b[1])
		cand = cand.slice(0, MAX_BONES)
		var total := 0.0
		for c in cand:
			total += c[1]
		var kept: Array = []
		for c in cand:
			if c[1] / total >= MIN_WEIGHT:
				kept.append(c)
		total = 0.0
		for c in kept:
			total += c[1]
		var row: Array = []
		for c in kept:
			row.append([c[0], c[1] / total])
		out.append(row)
	return out


static func _alpha(img: Image) -> PackedFloat32Array:
	var data := img.get_data() if img.get_format() == Image.FORMAT_RGBA8 else _rgba(img).get_data()
	var n := img.get_width() * img.get_height()
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		a[i] = data[i * 4 + 3] / 255.0
	return a


static func _rgba(img: Image) -> Image:
	var c := img.duplicate()
	c.convert(Image.FORMAT_RGBA8)
	return c


## Chamfer (3-4) distance in px: from the set pixels (to_set: distance to the nearest set pixel)
## or from the unset ones / the border (the depth inside the set).
static func _distance(mask: PackedByteArray, w: int, h: int, to_set: bool) -> PackedFloat32Array:
	var n := w * h
	var d := PackedFloat32Array()
	d.resize(n)
	var big := float(w + h) * 4.0
	for i in n:
		var src := mask[i] == 1 if to_set else mask[i] == 0
		if not to_set and mask[i] == 1:
			var x := i % w
			var y := i / w
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				src = true
		d[i] = 0.0 if src else big
	for y in h:
		for x in w:
			var i := y * w + x
			var v := d[i]
			if x > 0:
				v = minf(v, d[i - 1] + 3.0)
			if y > 0:
				v = minf(v, d[i - w] + 3.0)
				if x > 0:
					v = minf(v, d[i - w - 1] + 4.0)
				if x < w - 1:
					v = minf(v, d[i - w + 1] + 4.0)
			d[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := d[i]
			if x < w - 1:
				v = minf(v, d[i + 1] + 3.0)
			if y < h - 1:
				v = minf(v, d[i + w] + 3.0)
				if x < w - 1:
					v = minf(v, d[i + w + 1] + 4.0)
				if x > 0:
					v = minf(v, d[i + w - 1] + 4.0)
			d[i] = v
	for i in n:
		d[i] /= 3.0
	return d


static func _add_spaced(points: PackedVector2Array, hash: Dictionary, p: Vector2, spacing: float) -> bool:
	var cell := Vector2i(int(p.x / 8.0), int(p.y / 8.0))
	var r := int(ceil(spacing / 8.0))
	for cy in range(cell.y - r, cell.y + r + 1):
		for cx in range(cell.x - r, cell.x + r + 1):
			for q in hash.get(Vector2i(cx, cy), []):
				if (q as Vector2).distance_to(p) < spacing:
					return false
	points.append(p)
	if not hash.has(cell):
		hash[cell] = []
	hash[cell].append(p)
	return true


## Delaunay triangles lying inside `inside` (centroid and every edge, sampled each px).
static func _triangulate(points: PackedVector2Array, inside: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var all := Geometry2D.triangulate_delaunay(points)
	var out := PackedInt32Array()
	for t in range(0, all.size(), 3):
		var a := points[all[t]]
		var b := points[all[t + 1]]
		var c := points[all[t + 2]]
		if absf((b - a).cross(c - a)) < 0.5:
			continue
		if not _in(inside, w, h, (a + b + c) / 3.0):
			continue
		var ok := true
		for e in [[a, b], [b, c], [c, a]]:
			var p: Vector2 = e[0]
			var q: Vector2 = e[1]
			var steps := int(ceil(p.distance_to(q)))
			for s in range(1, steps):
				if not _in(inside, w, h, p.lerp(q, float(s) / steps)):
					ok = false
					break
			if not ok:
				break
		if ok:
			out.append_array([all[t], all[t + 1], all[t + 2]])
	return out


static func _in(mask: PackedByteArray, w: int, h: int, p: Vector2) -> bool:
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	return x >= 0 and y >= 0 and x < w and y < h and mask[y * w + x] == 1


## 1 for every pixel whose centre a triangle covers.
static func _coverage(points: PackedVector2Array, tris: PackedInt32Array, w: int, h: int) -> PackedByteArray:
	var cov := PackedByteArray()
	cov.resize(w * h)
	for t in range(0, tris.size(), 3):
		var a := points[tris[t]]
		var b := points[tris[t + 1]]
		var c := points[tris[t + 2]]
		var area := (b - a).cross(c - a)
		if absf(area) < 1e-6:
			continue
		var x0 := maxi(0, int(floor(minf(a.x, minf(b.x, c.x)))))
		var x1 := mini(w - 1, int(ceil(maxf(a.x, maxf(b.x, c.x)))))
		var y0 := maxi(0, int(floor(minf(a.y, minf(b.y, c.y)))))
		var y1 := mini(h - 1, int(ceil(maxf(a.y, maxf(b.y, c.y)))))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var p := Vector2(x + 0.5, y + 0.5)
				var e0 := (b - a).cross(p - a) / area
				var e1 := (c - b).cross(p - b) / area
				var e2 := (a - c).cross(p - c) / area
				if e0 >= -0.02 and e1 >= -0.02 and e2 >= -0.02:
					cov[y * w + x] = 1
	return cov


static func _nearest_solid(solid: PackedByteArray, w: int, h: int, v: Vector2) -> int:
	var cx := int(v.x)
	var cy := int(v.y)
	var best := -1
	var best_d := INF
	for r in 8:
		for y in range(cy - r, cy + r + 1):
			for x in range(cx - r, cx + r + 1):
				if x < 0 or y < 0 or x >= w or y >= h or solid[y * w + x] == 0:
					continue
				var d := Vector2(x + 0.5, y + 0.5).distance_squared_to(v)
				if d < best_d:
					best_d = d
					best = y * w + x
		if best >= 0:
			return best
	return -1


## Geodesic distance (px, 3-4 chamfer steps through solid pixels) from the segment at → tip.
static func _geodesic(solid: PackedByteArray, w: int, h: int, at: Vector2, tip: Vector2) -> PackedFloat32Array:
	var n := w * h
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(1 << 30)
	var buckets := {}
	var steps := maxi(1, int(ceil(at.distance_to(tip))))
	var seeded := false
	for s in steps + 1:
		var p := at.lerp(tip, float(s) / steps)
		var i := int(p.y) * w + int(p.x)
		if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and solid[i] == 1 and dist[i] != 0:
			dist[i] = 0
			if not buckets.has(0):
				buckets[0] = []
			buckets[0].append(i)
			seeded = true
	if not seeded: # the segment misses the figure: start at its nearest solid pixel
		var i := _nearest_solid(solid, w, h, at)
		if i >= 0:
			dist[i] = 0
			buckets[0] = [i]
	var cost := 0
	var left := buckets.size()
	var max_cost := (w + h) * 8
	while left > 0 and cost <= max_cost:
		if buckets.has(cost):
			var list: Array = buckets[cost]
			buckets.erase(cost)
			left -= 1
			for i: int in list:
				if dist[i] != cost:
					continue
				var x := i % w
				var y := i / w
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var xx := x + dx
						var yy := y + dy
						if xx < 0 or yy < 0 or xx >= w or yy >= h:
							continue
						var j := yy * w + xx
						if solid[j] == 0:
							continue
						var nd := cost + (4 if dx != 0 and dy != 0 else 3)
						if nd < dist[j]:
							dist[j] = nd
							if not buckets.has(nd):
								buckets[nd] = []
								left += 1
							buckets[nd].append(j)
		cost += 1
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = INF if dist[i] >= (1 << 30) else dist[i] / 3.0
	return out


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0 if ab.length_squared() < 1e-6 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
