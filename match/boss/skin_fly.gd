extends RefCounted
## The glide of a skinned boss (the Ice Witch's side view on a skeleton: match/boss/boss_skin_view.gd,
## assets/bosses/<id>/skin/fly/), played while it flies (UnitFlew): she skates forward on the air,
## no steps. A Glide state is stepped with whether she flies:
## - blend: 0 → 1 over BLEND_SEC as she takes off, back to 0 as she lands (eased: amount());
## - lean(): the whole body leans LEAN_DEG forward (clockwise in her picture, facing right; mirrored
##   facing left by the owner), eased in and out with the blend;
## - stream: how far the cape and the frost mist stream back, a spring towards the blend's target
##   (critically damped on take-off, under-damped on landing: the cape settles with a little
##   overshoot);
## - bone(): each bone's turn now: its streaming angle × stream plus a ripple, a travelling wave down
##   the cape and the mist (each bone later in phase than the one above it), the hood's tip
##   fluttering back; the staff held angled forward and steady (it only leans with her);
## - hover(): a slight bob, smaller than the idle's (HOVER × the height);
## - shard(): the shards trail behind her shoulders (`trail`, lagging behind the blend, so they fall
##   back as she sets off and catch up when she stops) and drift a little.
## Everything is bounded and continuous in time (sines and first-order lags); tracks() samples the
## steady glide (blend 1) into lobby_full_anims.json keys for skin.json (a preview / fallback; the
## boss body drives the bones itself so it can blend).

const LEAN_DEG := 15.0
const BLEND_SEC := 0.2
const PERIOD := 1.2 # s, one ripple
const HOVER := 0.01 # of the height (the idle's: 0.025)
const STREAM_HZ := 1.6 # the stream's spring
const DAMP_UP := 1.0 # critically damped while she takes off
const DAMP_DOWN := 0.42 # under-damped as she lands: a little overshoot
const TRAIL_SEC := 0.3 # the shards' lag
const TRAIL := 0.07 # of the height, how far back they trail at full speed
const KEYS := 13
## Per bone: stream (degrees at full stream: + = clockwise, the tip of a downward bone back),
## ripple (degrees), lag (rad of the travelling wave), harmonic (× the ripple's frequency).
const MOTION := {
	"torso": {"stream": -2.0, "ripple": 0.5, "lag": 0.0},
	"head": {"stream": -3.0, "ripple": 0.8, "lag": 0.3},
	"hood_tip": {"stream": 8.0, "ripple": 5.0, "lag": 0.6, "harmonic": 2.0},
	"arm_free": {"stream": 6.0, "ripple": 1.5, "lag": 0.5},
	"cape_1": {"stream": 14.0, "ripple": 3.0, "lag": 0.4},
	"cape_2": {"stream": 10.0, "ripple": 5.0, "lag": 1.1},
	"mist_1": {"stream": 10.0, "ripple": 3.0, "lag": 0.8},
	"mist_2": {"stream": 12.0, "ripple": 5.0, "lag": 1.6},
	"mist_3": {"stream": 14.0, "ripple": 7.0, "lag": 2.4},
}


static func omega() -> float:
	return TAU / PERIOD


class Glide:
	var t := 0.0
	var blend := 0.0 # 0..1 linear, eased by amount()
	var stream := 0.0
	var stream_v := 0.0
	var trail := 0.0
	var flying := false

	func step(delta: float, on: bool) -> void:
		flying = on
		t += delta
		var target := 1.0 if on else 0.0
		blend = move_toward(blend, target, delta / BLEND_SEC)
		var w := TAU * STREAM_HZ
		var damp := DAMP_UP if on else DAMP_DOWN
		var steps := maxi(1, int(ceil(delta / 0.008))) # a stable spring at any frame rate
		var h := delta / steps
		for i in steps:
			var acc := w * w * (target - stream) - 2.0 * damp * w * stream_v
			stream_v += acc * h
			stream += stream_v * h
		trail += (target - trail) * (1.0 - exp(-delta / TRAIL_SEC))

	## The blend eased (smoothstep): the lean's and the ripple's share now.
	func amount() -> float:
		return smoothstep(0.0, 1.0, blend)

	## Showing: flying, or still settling after it (the lean, the cape or the shards not back yet).
	func active() -> bool:
		return flying or blend > 0.001 or absf(stream) > 0.01 or absf(stream_v) > 0.05 or trail > 0.12

	## The body's lean now (degrees, clockwise = forward).
	func lean() -> float:
		return LEAN_DEG * amount()

	## A bone's turn now: {rot (degrees), y}.
	func bone(name: String) -> Dictionary:
		var m: Dictionary = MOTION.get(name, {})
		var ph := TAU / PERIOD * t * float(m.get("harmonic", 1.0)) - float(m.get("lag", 0.0))
		return {"rot": float(m.get("stream", 0.0)) * stream + float(m.get("ripple", 0.0)) * sin(ph) * amount(), "y": 0.0}

	## The bob now (of the height, up negative).
	func hover() -> float:
		return -HOVER * sin(TAU / PERIOD * t) * (0.4 + 0.6 * amount())

	## Shard i: {offset (of the height, from its rest place), rot, scale}.
	func shard(i: int) -> Dictionary:
		var ph := TAU / PERIOD * t * 0.5 + 1.7 * i
		return {"offset": Vector2(-TRAIL * trail * (1.0 + 0.25 * i) + 0.008 * cos(ph), -0.012 * trail + 0.008 * sin(ph)),
			"rot": 0.12 * sin(ph + 0.6) - 0.25 * trail, "scale": 1.0}


## The steady glide (stream 1, full ripple) as lobby_full_anims.json tracks for `bones`.
static func tracks(bones: Array, _height: float) -> Dictionary:
	var out := {}
	for b in bones:
		if not MOTION.has(str(b)):
			continue
		var tr := {"t": [], "rot": []}
		for k in KEYS:
			var t := PERIOD * k / float(KEYS - 1)
			tr["t"].append(snappedf(t, 0.0001))
			var m: Dictionary = MOTION[str(b)]
			var ph := omega() * t * float(m.get("harmonic", 1.0)) - float(m.get("lag", 0.0))
			tr["rot"].append(snappedf(float(m.get("stream", 0.0)) + float(m.get("ripple", 0.0)) * sin(ph), 0.0001))
		out[str(b)] = tr
	return {"length": PERIOD, "loop": true, "tracks": out}
