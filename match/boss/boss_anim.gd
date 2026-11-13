extends RefCounted
## Which frame of a drawn boss (ui/art.gd boss_side(): the Ice Witch's imported frames) shows
## now: a looping base state (idle; fly while it flies, UnitFlew; walk while it walks on the ground,
## Cua Dung Nham's crawl to its pincer and its Cua con; prime while a bomber is about to blow up;
## idle slowed down while stunned or frozen, the body swaying a little: sway()) and over it one
## animation played once (a skill's cast, a summon, a hit), back to the base state when it is over;
## one played with a delay (the crab's pincer: it crawls first) starts later. Pure: step() moves it on.
## play() can put an animation's `peak` frame (the burst's flash, the blizzard's whirl) on a given
## moment: the frames before it are spread over the time until then, the peak holds `hold` s, the
## rest run at the animation's fps.
## action_for(): the animation a boss's ShotResolved plays and when its peak falls (a visual
## mapping by skillId / skill kind, the game data's numbers untouched).

const STUN_SPEED := 0.45 # the idle's speed while stunned / frozen
const SWAY_RAD := 0.045 # the sway's tilt then
const SWAY_HZ := 0.55
const HURT := "hurt"
## The animation of a boss skill by its skillId, else by its kind (GameData.boss_skill()).
## Khổng Lồ Đá: the boulders thrown (giant_boulder; boulder_rain, an older id), pushed (rolling_boulder),
## the stomp (earthquake), the fists on the ground (stone_spikes: its marks and, on its turn start,
## their eruption). Mộc Tinh, Cua Dung Nham: each skill its own animation (named after it; the crab's
## crab_call summon is a summon).
const BY_SKILL := {"ice_spikes": "cast", "frost_beam": "burst", "blizzard": "blizzard",
	"giant_boulder": "throw", "boulder_rain": "throw", "rolling_boulder": "roll", "earthquake": "stomp", "stone_spikes": "spikes",
	"vine_lash": "vine_lash", "poison_thorns": "poison_thorns", "life_drain": "life_drain", "root_drag": "root_drag",
	"fire_bombs": "fire_bombs", "claw_slam": "claw_slam", "pincer": "pincer"}
const BY_KIND := {"beam": "burst", "rain": "cast", "shockwave": "cast", "summon": "summon"}
## An animation a boss does not have → the first of these it has (Khổng Lồ Đá throws for a cast: its
## plain shot; Mộc Tinh shakes its thorns out of the canopy, drains for a beam).
const FALLBACK := {"cast": ["throw", "poison_thorns"], "blizzard": ["throw", "poison_thorns"], "burst": ["throw", "life_drain"]}
## The event its peak lands on (the first of these types in the replay), else the first projectile
## (Mộc Tinh: the vines strike the ground, the root hooks the member it drags; its thorns leave the
## canopy with the projectiles. Cua Dung Nham: the claw hits the ground on the slam's explode, the
## pincer snaps on its pincer event; its lava bombs leave the shell with the projectiles).
const PEAK_ON := {"stomp": ["global"], "spikes": ["mark", "eruption"], "vine_lash": ["ground_strike"], "root_drag": ["pull"],
	"claw_slam": ["explode"], "pincer": ["pincer"]}
## Played only when its PEAK_ON event comes (the crab's pincer: out of reach it only crawls).
const NEEDS_PEAK := ["pincer"]
## At most this long (s) before the peak the animation starts (the crab crawls to its target first,
## on its walk loop, then reaches and snaps); the rest of the wait shows the base state.
const PEAK_LEAD := {"pincer": 0.45}
## Held over the beams (the peak on the first one, held while they fire): the witch's burst, Mộc
## Tinh's drain (its eyes and mushrooms blazing while the life flows in).
const BEAM_HOLD := ["burst", "life_drain"]
## The peak held this share of its event's duration (Mộc Tinh's root at full reach while the member
## is hauled in; yanked back as it arrives).
const PEAK_HOLD := {"root_drag": 0.75}

var anims: Dictionary = {} # name -> {frames (count or Array), fps, loop, peak}
var base := "idle"
var stunned := false
var current := "" # the one played once ("" none)
var flying := false # set_flying(): a hover move under way
var walking := false # set_walking(): moving along the ground
var primed := false # set_primed(): a bomber about to blow up (warned or its detonation's lead-in)
var _pending := {} # play() with a delay: {anim, timing, in (s left)}
var _times := PackedFloat32Array() # its frames' end times
var _t := 0.0 # into it
var _base_t := 0.0 # into the base loop
var _clock := 0.0


func _init(anims_in: Dictionary = {}) -> void:
	anims = anims_in


func has(anim: String) -> bool:
	return anims.has(anim)


## Frames of an animation.
func count(anim: String) -> int:
	var f = anims.get(anim, {}).get("frames", 0)
	return f.size() if f is Array else int(f)


func fps(anim: String) -> float:
	return maxf(float(anims.get(anim, {}).get("fps", 8.0)), 0.1)


## Plays `anim` once over the base state; timing {at (s from now the peak frame starts), peak
## (frame index, default the animation's own), hold (s the peak frame shows, default one frame)}.
## Returns its duration (0: no such animation, nothing changes).
func play(anim: String, timing: Dictionary = {}) -> float:
	anim = resolve(anim)
	var n := count(anim)
	if n <= 0:
		return 0.0
	var delay := float(timing.get("delay", 0.0))
	if delay > 0.0: # it starts later (the base state shows until then)
		var rest := timing.duplicate()
		rest.erase("delay")
		_pending = {"anim": anim, "timing": rest, "in": delay}
		return delay + _length(anim, rest)
	if anim != HURT: # a hit does not cancel the one waiting
		_pending = {}
	_times = _timeline(anim, timing)
	current = anim
	_t = 0.0
	return _times[_times.size() - 1]


## The animation's duration with this timing.
func _length(anim: String, timing: Dictionary) -> float:
	var times := _timeline(anim, timing)
	return times[times.size() - 1] if not times.is_empty() else 0.0


## Its frames' end times with this timing (the frames before the peak spread until `at`, the peak
## held `hold` s, the rest at its fps).
func _timeline(anim: String, timing: Dictionary) -> PackedFloat32Array:
	var n := count(anim)
	var step := 1.0 / fps(anim)
	var peak := int(timing.get("peak", anims[anim].get("peak", -1)))
	var at := float(timing.get("at", -1.0))
	var hold := float(timing.get("hold", step))
	var times := PackedFloat32Array()
	var t := 0.0
	for i in n:
		var d := step
		if peak >= 0 and peak < n and at >= 0.0:
			if i < peak:
				d = at / peak if peak > 0 else 0.0
			elif i == peak:
				d = maxf(hold, step)
		t += d
		times.append(t)
	return times


## The animation played for `anim`: itself, else its FALLBACK when this boss has that one.
func resolve(anim: String) -> String:
	if not has(anim):
		for other in FALLBACK.get(anim, []):
			if has(str(other)):
				return str(other)
	return anim


## The base loop: fly while flying (a hover move under way), else walk while walking, else prime
## while primed, else idle (each only when it has that animation).
func set_flying(on: bool) -> void:
	flying = on
	_rebase()


func set_walking(on: bool) -> void:
	walking = on
	_rebase()


func set_primed(on: bool) -> void:
	primed = on
	_rebase()


func _rebase() -> void:
	var want := "idle"
	if flying and has("fly"):
		want = "fly"
	elif walking and has("walk"):
		want = "walk"
	elif primed and has("prime"):
		want = "prime"
	if want != base:
		base = want
		_base_t = 0.0


## An animation waiting to start (play() with a delay): its name, "" none.
func pending() -> String:
	return str(_pending.get("anim", ""))


func step(delta: float) -> void:
	_clock += delta
	_base_t += delta * (STUN_SPEED if stunned and base == "idle" else 1.0)
	if not _pending.is_empty():
		_pending["in"] = float(_pending["in"]) - delta
		if float(_pending["in"]) <= 0.0:
			var p := _pending
			play(str(p["anim"]), p["timing"])
			_t = -float(p["in"]) - delta # the time past its start (the delta is added below)
	if current != "":
		_t += delta
		if _times.is_empty() or _t >= _times[_times.size() - 1]:
			current = ""


## The animation showing and its frame: [name, index].
func frame() -> Array:
	if current != "":
		for i in _times.size():
			if _t < _times[i]:
				return [current, i]
		return [current, _times.size() - 1]
	var anim := base if has(base) else "idle"
	var n := maxi(count(anim), 1)
	var i := int(floor(_base_t * fps(anim)))
	if bool(anims.get(anim, {}).get("loop", true)):
		i = i % n
	else:
		i = mini(i, n - 1)
	return [anim, i]


## The body's tilt (rad): a slow sway while stunned / frozen on the idle, 0 otherwise.
func sway() -> float:
	if not stunned or current != "":
		return 0.0
	return SWAY_RAD * sin(TAU * SWAY_HZ * _clock)


func playing() -> String:
	return current


## The animation a boss's shot plays and when its peak falls: {anim, at (s into the replay; -1:
## none, the animation's own pace), hold (s the peak frame shows; -1: one frame), delay (optional,
## PEAK_LEAD: s before it starts; at then counts from its start)}. mode: the
## ShotResolved actionMode (turn_start: a mapped skill going off then, the spikes erupting); skill: its
## game data entry (GameData.boss_skill(), {} unknown);
## events / launches: the replay's events and its projectiles' launch times. The peak lands on
## the first beam (a burst: held over most of the beams' duration), the first summon (a summon), the
## global skill starting (the stomp), the first mark / eruption (the spikes),
## else the first projectile leaving (a cast's rain; the blizzard's whirl held while its shards
## leave one after another; beams one after another, the saucer's turret laser: held until the last
## one ends).
static func action_for(mode: String, skill_id: String, skill: Dictionary, events: Array, launches: Array) -> Dictionary:
	var anim := ""
	if mode == "summon":
		anim = "summon"
	elif mode == "turn_start" and BY_SKILL.has(skill_id):
		anim = str(BY_SKILL[skill_id]) # a skill going off on the boss's turn start (the spikes' eruption)
	elif mode == "skill":
		anim = str(BY_SKILL.get(skill_id, ""))
		if anim == "":
			var kind := str(skill.get("kind", ""))
			anim = "blizzard" if kind == "rain" and str(skill.get("launchFrom", "")) == "boss" else str(BY_KIND.get(kind, "cast"))
	else:
		anim = "cast"
	var at := INF
	var hold := -1.0
	var beams_end := -INF # the last beam's end (round 2: the saucer's beams one after another)
	var beam_ts := {}
	for e in events:
		if not e is Dictionary or not (e.get("t") is float or e.get("t") is int):
			continue
		var type := str(e.get("type", ""))
		if anim in BEAM_HOLD and type == "beam":
			beams_end = maxf(beams_end, float(e["t"]) + (float(e["duration"]) if e.get("duration") is float or e.get("duration") is int else 0.0))
			beam_ts[snappedf(float(e["t"]), 0.001)] = true
		if (anim in BEAM_HOLD and type == "beam") or (anim == "summon" and type == "summon") or type in PEAK_ON.get(anim, []):
			if float(e["t"]) < at:
				at = float(e["t"])
				var dur := float(e["duration"]) if e.get("duration") is float or e.get("duration") is int else -1.0
				if anim in BEAM_HOLD and dur >= 0.0:
					hold = clampf(dur * 0.6, 0.15, 0.8)
				elif PEAK_HOLD.has(anim) and dur > 0.0:
					hold = clampf(dur * float(PEAK_HOLD[anim]), 0.15, 2.0)
	if anim in BEAM_HOLD and at < INF and beam_ts.size() > 1: # beams one after another: hot over all of them
		hold = clampf(beams_end - at, 0.15, 4.0)
	if at == INF and anim in NEEDS_PEAK:
		return {"anim": "", "at": -1.0, "hold": -1.0} # out of reach: it only crawls (its walk loop)
	if at < INF and PEAK_LEAD.has(anim) and at > float(PEAK_LEAD[anim]):
		var lead := float(PEAK_LEAD[anim])
		return {"anim": anim, "at": lead, "hold": hold, "delay": at - lead}
	if at == INF and anim != "summon":
		var last := -INF
		for t in launches:
			at = minf(at, float(t))
			last = maxf(last, float(t))
		if anim == "blizzard" and at < INF:
			hold = clampf(last - at, 0.12, 1.2)
	return {"anim": anim, "at": at if at < INF else -1.0, "hold": hold}
