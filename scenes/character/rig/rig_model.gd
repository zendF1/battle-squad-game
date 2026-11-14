extends RefCounted
## The bone rig's geometry (pure logic, no nodes; drawn by scenes/character/rig/char_rig.gd): a
## character cut into parts on a skeleton (assets/characters/<id>/rig/rig.json, made by art_source/characters/<id>/rig/make_rig.py) and the
## gun it holds, solved every frame from a motion sample (scenes/character/rig/rig_motion.gd) into
## each bone's transform: hips (root) → torso → head; shoulder → elbow → hand each side; hip → knee
## → ankle each side. The arms reach the gun's grips by two-bone IK (blended from their hanging pose
## by the raise), the legs keep the feet on their places on the ground (two-bone IK, knees forward;
## the hips sink when a foot would be out of reach), and a fall turns the whole figure round the
## heels and lifts it so its lowest outline point lies on the ground.
## Rig px: the rig's own units (half the source picture's px), the feet at (0, 0), y down; bones rest
## unturned, so a bone's transform is its turn from rest and its joint's place.

const IK := preload("res://scenes/character/rig/rig_ik.gd")

## The gun's length, of the figure's height: the match's bazooka hug art at 3/4 × 1.3 (57 → 56 px
## on the ~62 px body: about the old ready pose's length), every gun kind the same length.
const GUN_LENGTH := 0.92
## Where the gun sits per aim (degrees up): [deg, pivot dx, pivot dy (rig px from the chest point),
## near grip, far grip (rig px along the tube from the pivot, the gun's hold; + towards the muzzle),
## slide (rig px the tube slides up its axis through the fists: the pivot moves, the grips stay)].
## Between rows: linear. Up to 60° the tube passes in front of the face (the pivot forward, as far as
## the short chibi near arm reaches); aiming higher it moves back beside the head (over the ear: in
## front of the face a vertical tube would hide it) and the far hand slides down to the chin; between
## 60° and 80° it sweeps across (rig_motion.gd leans back and looks up there). From 60° up the long
## tube slides up through the fists (70 px at 80°, 90 at 90°) so its tail clears the ground and its
## tip rises over the cap.
const AIM_PATH := [
	[-30.0, 4.0, 4.0, -10.0, 44.0, 0.0],
	[0.0, 4.0, 0.0, -12.0, 48.0, 0.0],
	[45.0, 10.0, -2.0, -14.0, 40.0, 0.0],
	[60.0, 8.0, -4.0, -14.0, 32.0, 0.0],
	[80.0, -30.0, -4.0, -16.0, 16.0, 70.0],
	[90.0, -42.0, -4.0, -16.0, 10.0, 90.0],
]
## The gun slung on the back while it is down (raise 0: idle, walk, hurt), riding the torso bone:
## anchored at `pos` (rig px from the feet, at rest), its axis at `deg` (at rest; -90 muzzle straight
## up, more negative tilts it back), the anchor `frac` of the gun's length from its tail on its hold
## row. Defaults: the side view's carry (assets/characters/rookie/side/carry.json back.scene, the
## anchor scaled to the rig) tilted BACK_TILT_DEG further back so the tube clears the chibi's big head
## (character.gd sets it from the carry scene, set_back()). Raising, the one gun swings from there
## into the grips (pivot and turn blended by the raise), drawn behind the body until SWAP_FRONT.
const BACK_POS := Vector2(-18.5, -94.6)
const BACK_DEG := -103.0
const BACK_FRAC := 0.127
const BACK_TILT_DEG := -30.0
const SWAP_FRONT := 0.4
## The side the joints bend to (rig_ik.gd middle()): elbows clockwise of the shoulder → grip line (under
## it aiming forward), knees counter-clockwise of the hip → ankle line (forward).
const ELBOW_BEND := 1.0
const KNEE_BEND := -1.0
const REACH := 0.995 # the legs' stretch the hips sink to keep

var height := 330.0
var rest := {} # bone name -> Vector2 (rig px)
var parent := {} # bone name -> parent name ("" the root)
var bone_names: Array = [] # parents first
var parts: Array = [] # {name, png, bone, xf: Transform2D (image px -> rig px at rest)}
var points := {} # name -> Vector2
var gun_under := ""
var gun := {} # {size, hold, muzzle} (texture px), scale (rig px per texture px), length (rig px)
var back := {"pos": BACK_POS, "deg": BACK_DEG + BACK_TILT_DEG, "frac": BACK_FRAC} # the sling (see BACK_POS)


## data: rig.json parsed; gun_meta: the gun art's {size: [w, h], hold: [x, y], muzzle: [x, y]}
## (assets/weapons/hug.json). False when the rig data is unusable.
func setup(data: Dictionary, gun_meta: Dictionary) -> bool:
	if not data.get("bones") is Array or not data.get("parts") is Array:
		return false
	height = float(data.get("height", 330.0))
	for b in data["bones"]:
		var nm := str(b["name"])
		rest[nm] = _vec(b["pos"])
		parent[nm] = str(b.get("parent", ""))
		bone_names.append(nm)
	for p in data["parts"]:
		var x: Array = p["xf"]
		parts.append({"name": str(p["name"]), "png": str(p["png"]), "bone": str(p["bone"]),
				"xf": Transform2D(Vector2(x[0], x[1]), Vector2(x[2], x[3]), Vector2(x[4], x[5]))})
	var pts: Dictionary = data.get("points", {})
	for k in pts:
		points[k] = _vec(pts[k])
	gun_under = str(data.get("gunUnder", ""))
	for need in ["hips", "torso", "head", "n_shoulder", "n_elbow", "n_hand", "f_shoulder", "f_elbow", "f_hand",
			"n_hip", "n_knee", "n_ankle", "f_hip", "f_knee", "f_ankle"]:
		if not rest.has(need):
			return false
	set_gun(gun_meta)
	return true


## The gun held: its art's {size, hold, muzzle} (texture px; arrays or Vector2s), drawn GUN_LENGTH
## long whatever its picture's size (every gun kind the same length, as on the old ready pose).
func set_gun(gun_meta: Dictionary) -> void:
	var size := _vec(gun_meta.get("size", [118, 37]))
	if size.x <= 0.0:
		size = Vector2(118, 37)
	var hold := _vec(gun_meta.get("hold", [size.x * 0.5, size.y * 0.5]))
	var muzzle := _vec(gun_meta.get("muzzle", [size.x, size.y * 0.5]))
	var length := GUN_LENGTH * height
	gun = {"size": size, "hold": hold, "muzzle": muzzle, "scale": length / size.x, "length": length}


## The sling: anchor (rig px from the feet, at rest), axis (degrees, at rest), anchor's fraction of
## the gun's length from its tail.
func set_back(pos: Vector2, deg: float, frac: float) -> void:
	back = {"pos": pos, "deg": deg, "frac": clampf(frac, 0.0, 1.0)}


static func _vec(v) -> Vector2:
	if v is Vector2:
		return v
	return Vector2(float(v[0]), float(v[1])) if v is Array and v.size() >= 2 else Vector2.ZERO


func bone_length(nm: String, child: String) -> float:
	return (rest[child] - rest[nm]).length()


## The aim path's row at `deg`: [pivot offset Vector2, near grip, far grip, slide].
static func aim_row(deg: float) -> Array:
	var rows := AIM_PATH
	if deg <= rows[0][0]:
		return [Vector2(rows[0][1], rows[0][2]), rows[0][3], rows[0][4], rows[0][5]]
	for i in range(1, rows.size()):
		if deg <= rows[i][0]:
			var a: Array = rows[i - 1]
			var b: Array = rows[i]
			var t: float = (deg - float(a[0])) / (float(b[0]) - float(a[0]))
			return [Vector2(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)), lerpf(a[3], b[3], t), lerpf(a[4], b[4], t),
				lerpf(a[5], b[5], t)]
	var z: Array = rows[rows.size() - 1]
	return [Vector2(z[1], z[2]), z[3], z[4], z[5]]


## A motion sample (rig_motion.gd sample()) solved: {bones: name -> Transform2D (skeleton px, before
## the figure's transform), figure: Transform2D (the fall), gun: Transform2D (texture px -> skeleton
## px; the one gun, from the back sling to the hands), gun_front (drawn in the hands' layer: raise
## SWAP_FRONT and up; else behind the body), gun_alpha (1; fading out with a fall), muzzle (figure px),
## dir (the gun's axis), grips: [near, far] and hands: [near, far] (skeleton px), flash}.
func solve(s: Dictionary) -> Dictionary:
	var g := {}
	var r := float(s.get("raise", 0.0))
	# hips (sunk when a foot would be out of reach)
	var hips_rot := deg_to_rad(float(s.get("hips_deg", 0.0)))
	var hips_pos: Vector2 = rest["hips"] + s.get("hips", Vector2.ZERO)
	var feet := {"n": rest["n_ankle"] + s.get("foot_n", Vector2.ZERO), "f": rest["f_ankle"] + s.get("foot_f", Vector2.ZERO)}
	var drop := 0.0
	for side in ["n", "f"]:
		var hip: Vector2 = hips_pos + (rest[side + "_hip"] - rest["hips"]).rotated(hips_rot)
		var reach := (bone_length(side + "_hip", side + "_knee") + bone_length(side + "_knee", side + "_ankle")) * REACH
		var dx: float = feet[side].x - hip.x
		if absf(dx) < reach:
			drop = maxf(drop, feet[side].y - sqrt(reach * reach - dx * dx) - hip.y)
	hips_pos.y += drop
	g["hips"] = Transform2D(hips_rot, hips_pos)
	var torso_rot := hips_rot + deg_to_rad(float(s.get("torso_deg", 0.0)))
	g["torso"] = Transform2D(torso_rot, _at(g, "hips", "torso") + s.get("torso", Vector2.ZERO))
	g["head"] = Transform2D(torso_rot + deg_to_rad(float(s.get("head_deg", 0.0))), _at(g, "torso", "head"))
	# the gun: from the sling on the back (riding the torso) to the aim at the chest
	var aim := float(s.get("aim", 0.0))
	var row := aim_row(aim)
	var aim_rot := -deg_to_rad(aim)
	var chest: Vector2 = g["torso"] * (points.get("chest", rest["torso"]) - rest["torso"])
	var p_aim: Vector2 = chest + row[0] + Vector2.from_angle(aim_rot) * (float(row[3]) - float(s.get("kick", 0.0)))
	var sc := float(gun["scale"])
	var hold: Vector2 = gun["hold"]
	var back_rot := torso_rot + deg_to_rad(float(back["deg"]))
	var anchor := Vector2(float(back["frac"]) * float(gun["size"].x), hold.y)
	var back_xf := Transform2D(back_rot, Vector2(sc, sc), 0.0, g["torso"] * (back["pos"] - rest["torso"])) \
		* Transform2D(0.0, -anchor)
	var gun_rot := lerp_angle(back_rot, aim_rot, r)
	var pivot: Vector2 = (back_xf * hold).lerp(p_aim, r)
	var dir := Vector2.from_angle(gun_rot)
	var slide := float(row[3]) * r # the grips stay where they were before the slide
	var grips := [pivot + dir * (float(row[1]) - slide), pivot + dir * (float(row[2]) - slide)]
	# the arms: hanging (swing / bend) → on the grips (IK), blended by the raise
	var hands := []
	var i := 0
	for side in ["n", "f"]:
		var sh: String = side + "_shoulder"
		var el: String = side + "_elbow"
		var hd: String = side + "_hand"
		var d1: Vector2 = rest[el] - rest[sh]
		var d2: Vector2 = rest[hd] - rest[el]
		var sp := _at(g, "torso", sh)
		var fk_upper := torso_rot + deg_to_rad(float(s.get("swing_" + side, 0.0)))
		var fk_fore := fk_upper - deg_to_rad(float(s.get("bend_" + side, 0.0)))
		var upper := fk_upper
		var fore := fk_fore
		if r > 0.0:
			# the hand's target slides from where it hangs to its grip (no IK flip on the way: the gun
			# swings in from the back sling)
			var hang: Vector2 = sp + d1.rotated(fk_upper) + d2.rotated(fk_fore)
			var target: Vector2 = hang.lerp(grips[i], r)
			var e := IK.middle(sp, d1.length(), d2.length(), target, ELBOW_BEND)
			var ik_upper := (e - sp).angle() - d1.angle()
			var ik_fore := (target - e).angle() - d2.angle()
			# IK on the sliding target, eased in from the hanging angles over the first part of the
			# raise (both agree there: the target starts on the hanging hand)
			var w := clampf(r / 0.15, 0.0, 1.0)
			upper = lerp_angle(fk_upper, ik_upper, w)
			fore = lerp_angle(fk_fore, ik_fore, w)
		var ep := sp + d1.rotated(upper)
		var hp := ep + d2.rotated(fore)
		g[sh] = Transform2D(upper, sp)
		g[el] = Transform2D(fore, ep)
		g[hd] = Transform2D(fore, hp)
		hands.append(hp)
		i += 1
	# the legs: feet on their places
	for side in ["n", "f"]:
		var hb: String = side + "_hip"
		var kn: String = side + "_knee"
		var an: String = side + "_ankle"
		var d1: Vector2 = rest[kn] - rest[hb]
		var d2: Vector2 = rest[an] - rest[kn]
		var hp := _at(g, "hips", hb)
		var k := IK.middle(hp, d1.length(), d2.length(), feet[side], KNEE_BEND)
		var a := IK.end_point(hp, d1.length(), d2.length(), feet[side], KNEE_BEND)
		var thigh := (k - hp).angle() - d1.angle()
		var shin := (a - k).angle() - d2.angle()
		g[hb] = Transform2D(thigh, hp)
		g[kn] = Transform2D(shin, k)
		g[an] = Transform2D(shin, a)
	# the fall: round the near heel, lifted so the lowest outline point lies on the ground
	var fall := deg_to_rad(float(s.get("fall_deg", 0.0)))
	var heel := Vector2(points.get("n_sole", Vector2.ZERO).x - 8.0, 0.0)
	var fig := Transform2D(0.0, heel) * Transform2D(fall, Vector2.ZERO) * Transform2D(0.0, -heel)
	if fall != 0.0:
		var low := 0.0
		for pair in [["head", "head_back"], ["head", "cap_back"], ["head", "cap_top"], ["torso", "back"]]:
			if points.has(pair[1]):
				var q: Vector2 = fig * (g[pair[0]] * (points[pair[1]] - rest[pair[0]]))
				low = maxf(low, q.y)
		fig = Transform2D(0.0, Vector2(0.0, -low)) * fig
	var gun_xf := Transform2D(gun_rot, Vector2(sc, sc), 0.0, pivot) * Transform2D(0.0, -hold)
	var muzzle: Vector2 = gun_xf * gun["muzzle"]
	# dead: the sling fades out as the body falls (never pressed into the ground)
	var alpha := 1.0 - clampf(float(s.get("dead", 0.0)) * 1.5, 0.0, 1.0) if bool(s.get("dying", false)) else 1.0
	return {
		"bones": g, "figure": fig, "gun": gun_xf, "gun_front": r >= SWAP_FRONT, "gun_alpha": alpha,
		"muzzle": fig * muzzle, "dir": dir, "grips": grips, "hands": hands,
		"flash": float(s.get("flash", 0.0)) * r,
	}


## Where bone `child`'s joint is under its parent `par`'s transform in g.
func _at(g: Dictionary, par: String, child: String) -> Vector2:
	return g[par] * (rest[child] - rest[par])


## A part's transform (image px -> skeleton px) for the bones in g.
func part_transform(g: Dictionary, part: Dictionary) -> Transform2D:
	var b := str(part["bone"])
	return g[b] * Transform2D(0.0, -rest[b]) * part["xf"]
