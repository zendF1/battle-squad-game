extends RefCounted
## players[id].statusEffects ([{effectId, durationTurn, value, ...}]) as the server keeps them
## (match/status_effect.go): an effect is active while durationTurn > 0; it loses one turn at
## the end of its target's own turn. Snapshots and ItemUsed carry the full list; TurnStarted
## does not, so the client ticks it the same way, and a ShotResolved "status" event applies one.

## Short label above the player's head; effects not listed (heal) show nothing.
const MARKERS := {
	"net": "Lưới",
	"freeze": "Băng",
	"power_shot": "x1.5",
	"drill_bomb": "Khoan",
	"spider_net": "Đạn lưới",
	"freeze_bomb": "Đạn băng",
	"air_strike": "Không kích",
}


static func has(effects: Variant, effect_id: String) -> bool:
	if not effects is Array:
		return false
	for e in effects:
		if e is Dictionary and str(e.get("effectId", "")) == effect_id and int(e.get("durationTurn", 0)) > 0:
			return true
	return false


## "Lưới · x1.5": the markers of the active effects, in list order, each once.
static func marker_text(effects: Variant) -> String:
	var parts: Array[String] = []
	if not effects is Array:
		return ""
	for e in effects:
		if not e is Dictionary or int(e.get("durationTurn", 0)) <= 0:
			continue
		var text := str(MARKERS.get(str(e.get("effectId", "")), ""))
		if text != "" and not parts.has(text):
			parts.append(text)
	return " · ".join(parts)


## ApplyStatusEffect: an effect already in the list gets the new duration, otherwise it is added.
static func apply(effects: Variant, effect_id: String, turns: int) -> Array:
	var out: Array = effects.duplicate(true) if effects is Array else []
	for e in out:
		if e is Dictionary and str(e.get("effectId", "")) == effect_id:
			e["durationTurn"] = turns
			return out
	out.append({"effectId": effect_id, "durationTurn": turns})
	return out


## tickEffects: every effect loses one turn; expired ones are dropped.
static func tick(effects: Variant) -> Array:
	var out: Array = []
	if not effects is Array:
		return out
	for e in effects:
		if not e is Dictionary:
			continue
		var next: Dictionary = e.duplicate(true)
		next["durationTurn"] = int(e.get("durationTurn", 0)) - 1
		if next["durationTurn"] > 0:
			out.append(next)
	return out
