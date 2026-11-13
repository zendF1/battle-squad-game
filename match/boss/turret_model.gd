extends RefCounted
## A boss turret's geometry and timing, pure (Đĩa Bay Thép's twin cannon, round 2: Art.boss_turret()
## from assets/bosses/<id>/turret/turret.json; BossBody draws and turns it). The art frame: texture
## px from the feet, facing right, y down; angles in degrees, 0 straight forward, positive down
## (facing left the whole frame is mirrored, so a world direction is 180° − the angle).
## - clamp_deg(): the turret turns only within its range (10..120: never up through the hull);
##   outside it, the nearest limit (by the shorter way round);
## - aim_deg(): the angle that points the barrels from the pivot at a point, less the body frame's own
##   turn (the hurt's tilt), clamped;
## - tip(): the mid muzzle (the bright dot between the barrels the beams leave from) at an angle;
## - world_deg(): an art angle as a world direction's angle (facing applied);
## - eased(): the quick turn onto a new aim (TURN_SEC, ease out);
## - state_for(): the turret picture a body frame shows (the frame table: the cast charges then
##   recoils on its peak, the burst charges then holds hot while its beams fire);
## - cues(): when the turret turns to what in a boss shot (each beam's target, each projectile that
##   leaves from the turret along its first step), the hot window of its beams and when it rests.
## Visual only: the server's beams and paths start at the pivot (the events' from); the client
## turns the barrels along that line and draws from the tip.

const TURN_SEC := 0.2 # s a turn onto a new aim takes
const REST_AFTER := 0.45 # s after the last shot / beam it turns back to rest
const NEAR_PIVOT := 70.0 # px: a projectile leaving this close to the pivot is fired by the turret
## Projectile kinds that leave from the top of the craft, not the barrels (Bom mù's flash flare
## shoots straight up off the dome: the turret cannot point up).
const SKY_KINDS := ["flash_flare"]


## a (degrees, any) inside [lo, hi], else the nearer limit the shorter way round.
static func clamp_deg(a: float, lo: float, hi: float) -> float:
	var w := wrapf(a, -180.0, 180.0)
	if w >= lo and w <= hi:
		return w
	var d_lo := absf(wrapf(w - lo, -180.0, 180.0))
	var d_hi := absf(wrapf(w - hi, -180.0, 180.0))
	return lo if d_lo <= d_hi else hi


## The turret angle (relative to the body) pointing from `pivot` at `target` (both art frame), the
## body frame's `turn` taken off, clamped to [lo, hi].
static func aim_deg(pivot: Vector2, target: Vector2, turn: float, lo: float, hi: float) -> float:
	var d := target - pivot
	if d.length_squared() < 0.0001:
		return clamp_deg(lo, lo, hi)
	return clamp_deg(rad_to_deg(d.angle()) - turn, lo, hi)


## A muzzle (`offset` from the pivot pointing right: turret.json tips) at `total` degrees (the
## turret angle + the body frame's turn), art frame.
static func tip(pivot: Vector2, total: float, offset: Vector2) -> Vector2:
	return pivot + offset.rotated(deg_to_rad(total))


## An art angle as the world direction's angle (degrees, y down): mirrored facing left.
static func world_deg(total: float, facing: int) -> float:
	return total if facing >= 0 else wrapf(180.0 - total, -180.0, 180.0)


## The angle k (0..1) of the way through a turn from `from` to `to` (ease out: fast, then settles).
static func eased(from: float, to: float, k: float) -> float:
	var u := clampf(k, 0.0, 1.0)
	return lerpf(from, to, 1.0 - pow(1.0 - u, 3.0))


## The turret picture for a body frame: the cast (charge_0 on its first frames, recoil_0 on its
## peak, recoil_1 after), the burst (charge_0, charge_1, then hot from its peak), else idle; hot
## while `hot` (its beams still firing). Falls back to idle when a state has no picture.
static func state_for(anim: String, frame: int, peak: int, hot: bool, have: Dictionary = {}) -> String:
	var s := "idle"
	match anim:
		"cast":
			var p := peak if peak > 0 else 3
			if frame >= p + 1:
				s = "recoil_1"
			elif frame == p:
				s = "recoil_0"
			elif frame >= 1:
				s = "charge_0"
		"burst":
			var p := peak if peak > 0 else 2
			if frame >= p:
				s = "hot"
			elif frame >= 1:
				s = "charge_1"
			else:
				s = "charge_0"
	if hot and s == "idle":
		s = "hot"
	if not have.is_empty() and not have.has(s):
		return "idle"
	return s


## A boss shot's turret plan: {aims: [{t (when the shot leaves), at (world point to point at)}]
## sorted, hot_from / hot_until (the beams' window; -1 none), rest (s: back to rest; -1 none)}.
## events: the timeline's (each beam: from, to, t, duration); shots: [{t, from, dir}] the
## projectiles fired by the turret (their first point and direction).
static func cues(events: Array, shots: Array) -> Dictionary:
	var aims: Array = []
	var hot_from := -1.0
	var hot_until := -1.0
	for e in events:
		if not e is Dictionary or str(e.get("type", "")) != "beam" or not e.get("to") is Dictionary:
			continue
		var t := float(e.get("t", 0.0))
		var to := Vector2(float(e["to"].get("x", 0.0)), float(e["to"].get("y", 0.0)))
		aims.append({"t": t, "at": to})
		hot_from = t if hot_from < 0.0 else minf(hot_from, t)
		hot_until = maxf(hot_until, t + float(e.get("duration", 0.0)))
	for s in shots:
		var dir: Vector2 = s.get("dir", Vector2.ZERO)
		if dir.length_squared() < 0.0001:
			continue
		aims.append({"t": float(s.get("t", 0.0)), "at": Vector2(s.get("from", Vector2.ZERO)) + dir.normalized() * 400.0})
	aims.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	var last := -1.0
	for a in aims:
		last = maxf(last, float(a["t"]))
	var rest := -1.0
	if not aims.is_empty():
		rest = maxf(last, hot_until) + REST_AFTER
	return {"aims": aims, "hot_from": hot_from, "hot_until": hot_until, "rest": rest}
