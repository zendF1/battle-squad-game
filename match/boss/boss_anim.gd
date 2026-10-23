extends RefCounted
## Which frame of a drawn boss (ui/art.gd boss_side(): the Ice Witch's imported frames) shows
## now: a looping base state (idle; fly while it flies, UnitFlew; idle slowed down while stunned
## or frozen, the body swaying a little: sway()) and over it one animation played once (a skill's
## cast, a summon, a hit), back to the base state when it is over. Pure: step() moves it on.
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
const BY_SKILL := {"ice_spikes": "cast", "frost_beam": "burst", "blizzard": "blizzard"}
const BY_KIND := {"beam": "burst", "rain": "cast", "shockwave": "cast", "summon": "summon"}

var anims: Dictionary = {} # name -> {frames (count or Array), fps, loop, peak}
var base := "idle"
var stunned := false
var current := "" # the one played once ("" none)
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
	var n := count(anim)
	if n <= 0:
		return 0.0
	var step := 1.0 / fps(anim)
	var peak := int(timing.get("peak", anims[anim].get("peak", -1)))
	var at := float(timing.get("at", -1.0))
	var hold := float(timing.get("hold", step))
	_times = PackedFloat32Array()
	var t := 0.0
	for i in n:
		var d := step
		if peak >= 0 and peak < n and at >= 0.0:
			if i < peak:
				d = at / peak if peak > 0 else 0.0
			elif i == peak:
				d = maxf(hold, step)
		t += d
		_times.append(t)
	current = anim
	_t = 0.0
	return t


## The base loop: idle, or fly (flying: a hover move under way).
func set_flying(on: bool) -> void:
	var want := "fly" if on and has("fly") else "idle"
	if want != base:
		base = want
		_base_t = 0.0


func step(delta: float) -> void:
	_clock += delta
	_base_t += delta * (STUN_SPEED if stunned and base == "idle" else 1.0)
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
## none, the animation's own pace), hold (s the peak frame shows; -1: one frame)}. mode: the
## ShotResolved actionMode; skill: its game data entry (GameData.boss_skill(), {} unknown);
## events / launches: the replay's events and its projectiles' launch times. The peak lands on
## the first beam (a burst: held over most of the beams' duration), the first summon (a summon),
## else the first projectile leaving (a cast's rain; the blizzard's whirl held while its shards
## leave one after another).
static func action_for(mode: String, skill_id: String, skill: Dictionary, events: Array, launches: Array) -> Dictionary:
	var anim := ""
	if mode == "summon":
		anim = "summon"
	elif mode == "skill":
		anim = str(BY_SKILL.get(skill_id, ""))
		if anim == "":
			var kind := str(skill.get("kind", ""))
			anim = "blizzard" if kind == "rain" and str(skill.get("launchFrom", "")) == "boss" else str(BY_KIND.get(kind, "cast"))
	else:
		anim = "cast"
	var at := INF
	var hold := -1.0
	for e in events:
		if not e is Dictionary or not (e.get("t") is float or e.get("t") is int):
			continue
		var type := str(e.get("type", ""))
		if (anim == "burst" and type == "beam") or (anim == "summon" and type == "summon"):
			if float(e["t"]) < at:
				at = float(e["t"])
				if anim == "burst" and (e.get("duration") is float or e.get("duration") is int):
					hold = clampf(float(e["duration"]) * 0.6, 0.15, 0.8)
	if at == INF and anim != "summon":
		var last := -INF
		for t in launches:
			at = minf(at, float(t))
			last = maxf(last, float(t))
		if anim == "blizzard" and at < INF:
			hold = clampf(last - at, 0.12, 1.2)
	return {"anim": anim, "at": at if at < INF else -1.0, "hold": hold}
