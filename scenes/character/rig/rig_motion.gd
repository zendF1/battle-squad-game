extends RefCounted
## The bone rig's motions (TEST, pure logic, no nodes): what the character is doing (idle, gun raised
## and aimed, shooting, hurt, walking, dead) turned every frame into a few eased numbers the rig
## (scenes/character/rig/rig_model.gd) solves into bone angles: body offsets and turns, the gun's
## raise and aim, the recoil, the arms' swing, the feet's steps, the fall. Every change blends in
## over time (rates and envelopes below), so switching from any motion to any other never pops.
##
##   raise_gun(true)  arms rise from hanging to the grips over raiseSec, the body leans in; false lowers
##   set_aim(deg)     the aim the gun turns to (up positive, -30 .. 90), followed with aimRate
##   shoot()          recoil: the gun kicks back along its axis, the body rocks back, the head lags
##   hurt()           knocked back, the head snaps back, a wobble that dies out
##   set_walking(on)  the step cycle blends in / out over walkBlendSec
##   die()            knees buckle, then the body falls back and lies on the ground (stays)
##
## Angles in degrees, + clockwise (the body facing right: + leans forward); rig px, y down.

const T := {
	"raiseSec": 0.25,
	"lowerSec": 0.3,
	"aimRate": 9.0, # 1/s: the aim's exponential follow
	"aimMaxDegSec": 260.0, # and its top speed (a big jump of the aim swings, never whips)
	"breathSec": 2.6,
	"breathPx": 1.3, # the chest rises
	"breathDeg": 0.7,
	"headBreathDeg": 1.4,
	"leanDeg": 4.0, # gun raised: leaning in
	"kickPx": 16.0, # the gun's slide back along its axis at the shot
	"recoilPx": 5.0, # the body pushed back
	"recoilDeg": -6.0,
	"hurtPx": 11.0,
	"hurtDeg": -10.0,
	"hurtHeadDeg": -18.0,
	"walkPeriod": 0.6, # s per two steps
	"strideHalf": 12.0, # rig px each foot moves either side of its rest place
	"stepLift": 9.0,
	"walkBob": 2.2,
	"walkCrouch": 3.0,
	"walkLeanDeg": 4.0,
	"armSwingDeg": 18.0,
	"walkBlendSec": 0.18,
	"buckleSec": 0.34,
	"buckleDrop": 20.0,
	"fallStart": 0.26,
	"fallSec": 0.5,
	"fallDeg": -72.0, # the heels and the back of the head both on the ground
	"bounceSec": 0.32,
	"bounceDeg": 7.0,
}

var time := 0.0
var aim := 10.0 # degrees, followed
var aim_target := 10.0
var raised := 0.0 # 0 hanging .. 1 on the grips (linear; sample() eases it)
var raise_target := 0.0
var walk := 0.0 # 0 .. 1 blend
var walk_target := 0.0
var phase := 0.0 # the step cycle 0 .. 1
var shot_age := 99.0
var hurt_age := 99.0
var dead_age := -1.0 # < 0 alive


func raise_gun(on: bool) -> void:
	if dead_age < 0.0:
		raise_target = 1.0 if on else 0.0


func set_aim(deg: float) -> void:
	aim_target = clampf(deg, -30.0, 90.0)


func shoot() -> void:
	if dead_age < 0.0:
		shot_age = 0.0


func hurt() -> void:
	if dead_age < 0.0:
		hurt_age = 0.0


func set_walking(on: bool) -> void:
	walk_target = 1.0 if on and dead_age < 0.0 else 0.0


func die() -> void:
	if dead_age < 0.0:
		dead_age = 0.0
		raise_target = 0.0
		walk_target = 0.0


func is_dead() -> bool:
	return dead_age >= 0.0


## The walk's speed (rig px / s) at full blend: a planted foot moves back this fast under the body.
func walk_speed() -> float:
	return 4.0 * float(T["strideHalf"]) / float(T["walkPeriod"])


func advance(dt: float) -> void:
	time += dt
	shot_age += dt
	hurt_age += dt
	if dead_age >= 0.0:
		dead_age += dt
	var rate := 1.0 / float(T["raiseSec"] if raise_target > raised else T["lowerSec"])
	if dead_age >= 0.0:
		rate *= 1.6
	raised = move_toward(raised, raise_target, rate * dt)
	var step_deg := (aim_target - aim) * (1.0 - exp(-float(T["aimRate"]) * dt))
	var top := float(T["aimMaxDegSec"]) * dt
	aim += clampf(step_deg, -top, top)
	walk = move_toward(walk, walk_target, dt / float(T["walkBlendSec"]))
	if walk > 0.0:
		phase = fmod(phase + dt / float(T["walkPeriod"]), 1.0)


## Ease in-out.
static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## A kick: up to 1 over `rise` s (eased out), then a damped swing back that settles.
static func kick(t: float, rise: float, decay: float, freq: float) -> float:
	if t < 0.0:
		return 0.0
	if t < rise:
		return sin(t / rise * PI * 0.5)
	var u := t - rise
	return exp(-u * decay) * cos(u * freq)


## One foot's place in the step cycle (u 0 .. 1): planted and sliding back for the first half, then
## lifted and swung forward. {x: -1 .. 1 of the stride, lift: 0 .. 1}.
static func step(u: float) -> Dictionary:
	u = fposmod(u, 1.0)
	if u < 0.5:
		return {"x": 1.0 - 4.0 * u, "lift": 0.0}
	var s := (u - 0.5) / 0.5
	return {"x": -1.0 + 2.0 * smooth(s), "lift": sin(PI * s)}


## This frame's motion as numbers (rig_model.gd solve()):
##   hips (Vector2 offset), hips_deg, torso (Vector2), torso_deg, head_deg,
##   raise (0 .. 1 eased), aim (deg), kick (gun slide, rig px), flash (0 .. 1),
##   swing_n / swing_f (hanging arms' turn at the shoulder, deg), bend_n / bend_f (elbows, deg),
##   foot_n / foot_f (Vector2 offsets of the feet from their rest places), fall_deg, dead (0 .. 1: the
##   fall's progress), dying (bool).
func sample() -> Dictionary:
	var out := {}
	var b := sin(TAU * time / float(T["breathSec"]))
	var b_lag := sin(TAU * (time - 0.35) / float(T["breathSec"]))
	var r := smooth(raised)
	var hips := Vector2.ZERO
	var hips_deg := 0.0
	var torso := Vector2(0.0, -float(T["breathPx"]) * (0.5 + 0.5 * b))
	var torso_deg := float(T["breathDeg"]) * b * 0.4 + float(T["leanDeg"]) * r
	var head_deg := float(T["headBreathDeg"]) * b_lag + 1.6 * sin(time * 0.53) * sin(time * 0.29 + 1.0) - float(T["leanDeg"]) * 0.6 * r
	var swing_n := 0.0
	var swing_f := 0.0
	var bend_n := 0.0
	var bend_f := 0.0
	# aiming low: the chin drops a little; 45° .. 85° (the tube sweeping from in front of the face to
	# beside the head, rig_model.gd AIM_PATH): leaning back, looking up
	var up := clampf(aim / 90.0, -0.4, 1.0)
	var steep := sin(PI * clampf((aim - 45.0) / 40.0, 0.0, 1.0))
	head_deg += (5.0 * minf(up, 0.0) - 14.0 * steep) * r
	torso_deg += -3.0 * steep * r
	# recoil
	var k := kick(shot_age, 0.045, 9.0, 13.0)
	var kb := kick(shot_age - 0.02, 0.06, 7.0, 10.0)
	var kh := kick(shot_age - 0.06, 0.07, 6.5, 11.0)
	hips.x -= float(T["recoilPx"]) * kb
	torso_deg += float(T["recoilDeg"]) * kb
	head_deg += -5.0 * kh
	out["kick"] = float(T["kickPx"]) * k
	out["flash"] = clampf(1.0 - shot_age / 0.08, 0.0, 1.0) if shot_age >= 0.0 else 0.0
	# hurt
	var h := kick(hurt_age, 0.07, 4.5, 9.0)
	var hh := kick(hurt_age - 0.02, 0.06, 4.0, 12.0)
	hips.x -= float(T["hurtPx"]) * h
	hips.y += 3.0 * absf(h)
	torso_deg += float(T["hurtDeg"]) * h
	head_deg += float(T["hurtHeadDeg"]) * hh
	swing_n += 26.0 * h
	swing_f += 20.0 * h
	bend_n += 20.0 * absf(h)
	bend_f += 20.0 * absf(h)
	# walk
	var w := smooth(walk)
	var sn := step(phase)
	var sf := step(phase + 0.5)
	var stride := float(T["strideHalf"])
	var foot_n := Vector2(sn["x"] * stride, -sn["lift"] * float(T["stepLift"])) * w
	var foot_f := Vector2(sf["x"] * stride, -sf["lift"] * float(T["stepLift"])) * w
	hips.y += w * (float(T["walkCrouch"]) + float(T["walkBob"]) * 0.5 * (1.0 - cos(TAU * 2.0 * (phase - 0.25))))
	torso_deg += w * float(T["walkLeanDeg"])
	head_deg += -w * float(T["walkLeanDeg"]) * 0.5 + w * 1.2 * sin(TAU * 2.0 * (phase - 0.1))
	var hang := w * (1.0 - r)
	swing_n += -float(T["armSwingDeg"]) * float(sf["x"]) * hang
	swing_f += -float(T["armSwingDeg"]) * float(sn["x"]) * hang
	bend_n += 14.0 * maxf(0.0, float(sf["x"])) * hang
	bend_f += 14.0 * maxf(0.0, float(sn["x"])) * hang
	# death: buckle, fall back, bounce, lie still
	var fall_deg := 0.0
	var dead := 0.0
	if dead_age >= 0.0:
		var d := dead_age
		var buckle := smooth(d / float(T["buckleSec"]))
		var s := clampf((d - float(T["fallStart"])) / float(T["fallSec"]), 0.0, 1.0)
		var f := s * s
		var land := float(T["fallStart"]) + float(T["fallSec"])
		var bounce := 0.0
		if d > land:
			var u := (d - land) / float(T["bounceSec"])
			bounce = sin(PI * clampf(u, 0.0, 1.0)) * (1.0 - clampf(u, 0.0, 1.0) * 0.3) if u < 1.0 else 0.0
		fall_deg = float(T["fallDeg"]) * f + float(T["bounceDeg"]) * bounce
		dead = s
		hips.y += float(T["buckleDrop"]) * buckle * (1.0 - 0.75 * smooth(s))
		torso_deg += 9.0 * buckle * (1.0 - s) - 6.0 * s
		head_deg += 12.0 * buckle * (1.0 - s) + 16.0 * s
		swing_n += -45.0 * sin(PI * s) + 12.0 * s - 10.0 * bounce
		swing_f += -38.0 * sin(PI * s) + 8.0 * s - 8.0 * bounce
		bend_n += 30.0 * buckle * (1.0 - 0.6 * s)
		bend_f += 30.0 * buckle * (1.0 - 0.6 * s)
	out["hips"] = hips
	out["hips_deg"] = hips_deg
	out["torso"] = torso
	out["torso_deg"] = torso_deg
	out["head_deg"] = head_deg
	out["raise"] = r
	out["aim"] = aim
	out["swing_n"] = swing_n
	out["swing_f"] = swing_f
	out["bend_n"] = bend_n
	out["bend_f"] = bend_f
	out["foot_n"] = foot_n
	out["foot_f"] = foot_f
	out["fall_deg"] = fall_deg
	out["dead"] = dead
	out["dying"] = dead_age >= 0.0
	return out
