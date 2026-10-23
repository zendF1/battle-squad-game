extends RefCounted
## The idle of a skinned boss (the Ice Witch's portrait on a skeleton: match/boss/boss_skin_view.gd,
## assets/bosses/<id>/skin/): a gentle, looping pose as a pure function of the time, every motion a
## sine of the PERIOD's frequency (or a whole multiple of it), so t and t + PERIOD give the same pose
## and the loop has no seam. The body floats up and down (hover(): HOVER of the body's height; the
## boss body applies it to every animation of that boss, so idle ↔ fly / cast do not jump); the
## cape wings and the frost mist sway, the mist's bones one after another (a ripple down it); the
## head bobs a hair behind the body, the staff tilts a little; the staff crystal's glow pulses
## (glow()); the orbiting ice shards drift on small ellipses round their rest places, each with its
## own phase, bobbing and turning a little (shard()). Small on purpose: one picture, nothing must
## stretch or tear. tracks() samples the bones' motion into keys of the lobby_full_anims.json format
## (scenes/character/full_body.gd plays them; tools/import_boss_frames.gd writes them into skin.json).

const PERIOD := 2.4 # s, one loop
const HOVER := 0.025 # of the body's height, the float's amplitude (up and down)
const KEYS := 13 # keys per loop in tracks() (cubic between them)
## Per bone: rot (degrees, amplitude), lag (rad behind the body's float), y (of the height), sy
## (breathing scale), harmonic (× the loop's frequency).
const MOTION := {
	"torso": {"rot": 0.4, "lag": 0.3, "sy": 0.006},
	"head": {"rot": 1.1, "lag": 0.7, "y": 0.004},
	"arm_staff": {"rot": 0.7, "lag": 0.5},
	"staff": {"rot": 1.0, "lag": 0.9},
	"arm_free": {"rot": 1.6, "lag": 1.1},
	"cape_l": {"rot": -2.4, "lag": 0.8},
	"cape_r": {"rot": 2.4, "lag": 1.0},
	"mist_1": {"rot": 1.8, "lag": 0.6},
	"mist_2": {"rot": 2.4, "lag": 1.3},
	"mist_3": {"rot": 3.0, "lag": 2.0},
}
const SHARD_RX := 0.022 # of the height: the shards' ellipse
const SHARD_RY := 0.013
const SHARD_BOB := 0.008
const SHARD_TURN := 0.16 # rad
const SHARD_PHASES := [0.0, 2.1, 3.9, 5.2]


static func omega() -> float:
	return TAU / PERIOD


## The body's float now: px up (negative) per px of height.
static func hover(t: float) -> float:
	return -HOVER * sin(omega() * t)


## A bone's offset now: {rot (degrees), y (of the height), sy}; zero for a bone without motion.
static func bone(name: String, t: float) -> Dictionary:
	var m: Dictionary = MOTION.get(name, {})
	var ph := omega() * t * float(m.get("harmonic", 1.0)) - float(m.get("lag", 0.0))
	return {"rot": float(m.get("rot", 0.0)) * sin(ph), "y": -float(m.get("y", 0.0)) * sin(ph), "sy": 1.0 + float(m.get("sy", 0.0)) * sin(ph)}


## Shard i now: {offset (Vector2, of the height, from its rest place), rot (rad), scale}.
static func shard(i: int, t: float) -> Dictionary:
	var ph := omega() * t + float(SHARD_PHASES[i % SHARD_PHASES.size()]) + 0.37 * (i / SHARD_PHASES.size())
	var dir := -1.0 if i % 2 == 1 else 1.0 # neighbours turn the other way round
	return {"offset": Vector2(SHARD_RX * cos(ph) * dir, SHARD_RY * sin(ph) + SHARD_BOB * sin(2.0 * ph)),
		"rot": SHARD_TURN * sin(ph + 0.8), "scale": 1.0 + 0.04 * sin(ph * 2.0 + 1.0)}


## The crystal's glow now (0..1, two pulses per loop).
static func glow(t: float) -> float:
	return 0.5 + 0.5 * sin(2.0 * omega() * t)


## The idle as lobby_full_anims.json tracks for `bones` (names) on a body `height` px tall:
## {length, loop, tracks {bone: {t, rot, y, sy}}}, KEYS keys over one loop (the last = the first).
static func tracks(bones: Array, height: float) -> Dictionary:
	var out := {}
	for b in bones:
		if not MOTION.has(str(b)):
			continue
		var tr := {"t": [], "rot": [], "y": [], "sy": []}
		for k in KEYS:
			var t := PERIOD * k / float(KEYS - 1)
			var p := bone(str(b), t)
			tr["t"].append(snappedf(t, 0.0001))
			tr["rot"].append(snappedf(p["rot"], 0.0001))
			tr["y"].append(snappedf(float(p["y"]) * height, 0.01))
			tr["sy"].append(snappedf(p["sy"], 0.0001))
		out[str(b)] = tr
	return {"length": PERIOD, "loop": true, "tracks": out}
