extends RefCounted
## How a remote player's gun swings onto its aim (server PlayerAiming: the bots for now), pure
## math so it can be tested: from level (the gun just drawn) to the aim over the aim's duration,
## like a hand finding it. The angles are elevations: degrees above level towards the facing side
## (scenes/character/character.gd aim_elevation()).
##
##   hold ─▶ swing (ease-out cubic, a little past the aim) ─▶ correct back (a hair short) ─▶ settle on it ─▶ rest
##
## It is on the aim SETTLE_SEC before the duration ends (the shot follows), and stays within
## lo..hi (default -90..90, level to straight up or down): an aim past it is clamped, and an
## overshoot that would leave it comes from the short side instead. The curve is the real angle;
## the gun shows it snapped to its 7 directions (scenes/character/aim_snap.gd, applied by
## character.gd aim()), so it steps between them and ends on the aim's direction.

const SETTLE_SEC := 0.2 # the gun rests on the aim this long before the shot
const MIN_SWEEP_PART := 0.6 # a short aim still sweeps over at least this part of it
const HOLD_END := 0.12 # parts of the sweep time: the gun comes up at level (the draw)
const SWING_END := 0.62 # the main swing ends a little past the aim
const FIX_END := 0.82 # the first correction ends a hair short, the second settles on it
const OVERSHOOT_PART := 0.15 # the overshoot: this part of the swing,
const OVERSHOOT_MIN := 2.0 # within these degrees (scaled by wobble 0..1 to 60..100 %)
const OVERSHOOT_MAX := 7.0
const UNDERSHOOT_PART := 0.35 # the second correction starts this part of the overshoot short


## Seconds from the start until the gun is on the aim, for an aim lasting duration seconds.
static func sweep_time(duration: float) -> float:
	if duration <= 0.0:
		return 0.0
	return maxf(duration - SETTLE_SEC, duration * MIN_SWEEP_PART)


## The elevation t seconds into an aim of duration seconds from `from` to `to`, within lo..hi.
## wobble (0..1) varies the overshoot so no two aims look the same.
static func elevation(t: float, duration: float, from: float, to: float, wobble: float = 0.5,
		lo: float = -90.0, hi: float = 90.0) -> float:
	to = clampf(to, lo, hi)
	from = clampf(from, lo, hi)
	var sweep := sweep_time(duration)
	if sweep <= 0.0 or t >= sweep:
		return to
	var u := clampf(t / sweep, 0.0, 1.0)
	var delta := to - from
	var dir := 1.0 if delta >= 0.0 else -1.0
	var over := dir * clampf(absf(delta) * OVERSHOOT_PART, OVERSHOOT_MIN, OVERSHOOT_MAX) * lerpf(0.6, 1.0, clampf(wobble, 0.0, 1.0))
	if to + over > hi or to + over < lo:
		over = -over # at the reach's edge: stop short, then push onto it
	var peak := to + over
	var dip := to - over * UNDERSHOOT_PART
	var e: float
	if u < HOLD_END:
		e = from
	elif u < SWING_END:
		var k := (u - HOLD_END) / (SWING_END - HOLD_END)
		e = lerpf(from, peak, 1.0 - pow(1.0 - k, 3.0))
	elif u < FIX_END:
		e = lerpf(peak, dip, smoothstep(0.0, 1.0, (u - SWING_END) / (FIX_END - SWING_END)))
	else:
		e = lerpf(dip, to, smoothstep(0.0, 1.0, (u - FIX_END) / (1.0 - FIX_END)))
	return clampf(e, lo, hi)


## The aim angle (0 right, 90 up, 180 left: the Shoot / PlayerAiming convention) t seconds into an
## aim at `angle` lasting duration seconds, for a character facing facing_dir (1 right, -1 left),
## swinging up from level within lo..hi elevation.
static func angle_at(t: float, duration: float, angle: float, facing_dir: int, wobble: float = 0.5,
		lo: float = -90.0, hi: float = 90.0) -> float:
	var up := angle if facing_dir > 0 else 180.0 - angle
	var e := elevation(t, duration, 0.0, wrapf(up, -180.0, 180.0), wobble, lo, hi)
	return e if facing_dir > 0 else 180.0 - e
