extends RefCounted
## A bomber minion's warning (behavior "bomber": the drones, the crablings blow up when their move
## ends within detonateRange of a party player): while a party player is within that range its
## body pulses with a red glow (pulse(), BossArt's tint), no prop. Pure.

const PULSE_SEC := 0.5 # one red pulse
const PULSE_MAX := 0.85 # the tint at the pulse's peak


## The distance (px) from pos to the nearest of targets; INF when none.
static func nearest(pos: Vector2, targets: Array) -> float:
	var best := INF
	for p in targets:
		if p is Vector2:
			best = minf(best, pos.distance_to(p))
	return best


## A party player is within range (px) of pos. No range (0, the game data does not say): never.
static func warning(pos: Vector2, targets: Array, range_px: float) -> bool:
	return range_px > 0.0 and nearest(pos, targets) <= range_px


## The red glow (0..PULSE_MAX) at time t (s): pulsing while warn, 0 otherwise.
static func pulse(t: float, warn: bool) -> float:
	if not warn:
		return 0.0
	return PULSE_MAX * (0.5 - 0.5 * cos(TAU * maxf(t, 0.0) / PULSE_SEC))
