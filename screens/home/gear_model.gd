extends RefCounted
## The gear effects (server contract docs/contracts/gear-effects.md) as the screens and the match
## show them, without UI: a piece's passive {kind, value} and awaken, a character's gear profile
## (GET /player/characters characters[].gear, the showcase's character.gear, the match's
## BattlePlayerState.gear: the summed passives, the main set, the 6-piece aura, the +16 awakens)
## and the match's awaken buttons. Every number is the server's (the APIs send the values already
## computed; GET /gamedata gear the kinds, the milestone levels and the set thresholds): nothing
## is computed here but what to draw. Pictures by kind: ui/gear_glyphs.gd.

const GameData := preload("res://autoload/game_data_model.gd")
const GearGlyphs := preload("res://ui/gear_glyphs.gd")
const BattleStats := preload("res://screens/home/battle_stats.gd")

const MINUS := "−"
## The profile's passive fields by passive kind, in the order the screens list them.
const PROFILE_FIELDS := [["crit_damage", "critDamage"], ["crit_taken", "critTaken"], ["proc_chance", "procChance"],
	["resist", "resist"], ["move_cost", "moveCost"]]
## Passives that lower something (crit taken, the walk's energy cost): shown "−X%".
const LOWERING := ["crit_taken", "move_cost"]


static func _num(v: Variant) -> float:
	return float(v) if v is int or v is float else 0.0


# ── One piece ───────────────────────────────────────────────────────────────

## A piece's (or catalog item's) tier index, 0 none.
static func tier_index(piece: Dictionary, item: Dictionary = {}) -> int:
	var v = piece.get("tierIndex", item.get("tierIndex"))
	return int(v) if v is int or v is float else 0


## A piece's passive at its level ({kind, value, slot, glyph}; the catalog item's at +0 when the
## piece has none), {} without one (no tier index, an older server).
static func piece_passive(piece: Dictionary, item: Dictionary = {}) -> Dictionary:
	var p = piece.get("passive")
	if not p is Dictionary:
		p = item.get("passive")
	if not p is Dictionary or str(p.get("kind", "")) == "":
		return {}
	var slot := str(piece.get("slot", item.get("slot", "")))
	var kind := str(p["kind"])
	return {"kind": kind, "value": _num(p.get("value")), "slot": slot, "glyph": GearGlyphs.passive_kind(kind, slot)}


## Whether a piece has reached its awaken (+16, hasAwaken).
static func has_awaken(piece: Dictionary) -> bool:
	return bool(piece.get("hasAwaken", false))


## The awaken kind of a slot ("revive"...), "" unknown.
static func awaken_kind(slot: String) -> String:
	return GameData.gear_awaken_kind(slot)


## Whether a slot's awaken is a button in the match (weapon, gloves, boots) rather than automatic.
static func awaken_is_button(slot: String) -> bool:
	return GameData.gear_awaken_button(slot)


## "+48.3%", "−30%" (a passive that lowers something), "" for 0.
static func value_text(kind: String, value: float) -> String:
	if value == 0.0:
		return ""
	return ("%s" % MINUS if LOWERING.has(kind) else "+") + BattleStats.format_chance(absf(value))


# ── A profile (a character's, a showcase's, a match player's) ──────────────

## The gear profile of a GET /player/characters entry, a showcase character or a match player
## (their "gear"), {} when it has none (an older server, a boss).
static func profile_of(holder: Variant) -> Dictionary:
	if holder is Dictionary and holder.get("gear") is Dictionary:
		return holder["gear"]
	return {}


## The passive lines of a profile, zeros left out, in PROFILE_FIELDS order: [{kind, glyph, value,
## text}]. proc_chance draws the gloves' picture.
static func profile_lines(gear: Dictionary) -> Array:
	var out: Array = []
	for f in PROFILE_FIELDS:
		var v := _num(gear.get(f[1]))
		if v != 0.0:
			out.append({"kind": f[0], "glyph": GearGlyphs.passive_kind(f[0]), "value": v, "text": value_text(f[0], v)})
	return out


## The main set of a profile: {index, pieces, crafted, reached ([2, 4, 6] met), size (the pips: the
## game data's setEffectPieces), thresholds ([2, 4, 6]), effect (the 6-piece effect id of the
## index), glyph ("set_<effect>", "" none), complete (the 6-piece effect on)}; {} without a set.
static func set_state(gear: Dictionary) -> Dictionary:
	var s = gear.get("set")
	if not s is Dictionary or int(_num(s.get("index"))) <= 0:
		return {}
	var index := int(_num(s.get("index")))
	var reached: Array = []
	if s.get("reached") is Array:
		for r in s["reached"]:
			if r is int or r is float:
				reached.append(int(r))
	var effect := GameData.gear_set_effect(index)
	var size := GameData.gear_set_size()
	return {"index": index, "pieces": int(_num(s.get("pieces"))), "crafted": int(_num(s.get("crafted"))), "reached": reached,
		"size": size, "thresholds": GameData.gear_set_thresholds(), "effect": effect,
		"glyph": "set_" + effect if effect != "" else "", "complete": size > 0 and reached.has(size)}


## The 6-piece set aura's index (setAura), 0 none.
static func set_aura(gear: Dictionary) -> int:
	return int(_num(gear.get("setAura")))


## The slots whose worn piece is +16 (awaken), in the server's order.
static func awaken_slots(gear: Dictionary) -> Array:
	var out: Array = []
	if gear.get("awaken") is Array:
		for s in gear["awaken"]:
			if s is String and s != "":
				out.append(s)
	return out


# ── Upgrade milestones ──────────────────────────────────────────────────────

## What reaching +`level` unlocks on a piece of `slot` besides its stats, as pictures: the weapon's
## bullet glow at the game data's glowLevel ("bullet_glow"), its skill a rank up at skillRankLevel
## ("rank_up"), the slot's awaken kind at awakenLevel; [] for the other levels.
static func milestone_unlocks(level: int, slot: String) -> Array:
	var out: Array = []
	if slot == "weapon" and level == GameData.gear_glow_level() and level > 0:
		out.append("bullet_glow")
	if slot == "weapon" and level == GameData.gear_skill_rank_level() and level > 0:
		out.append("rank_up")
	if level == GameData.gear_awaken_level() and level > 0 and awaken_kind(slot) != "":
		out.append(awaken_kind(slot))
	return out


# ── The match ───────────────────────────────────────────────────────────────

## The awakens a match player used (awakenUsed) or pressed this turn (armed).
static func used_awakens(gear: Dictionary) -> Array:
	var out: Array = []
	for key in ["awakenUsed", "armed"]:
		if gear.get(key) is Array:
			for s in gear[key]:
				if s is String and not out.has(s):
					out.append(s)
	return out


## Marks `slot` used on a match player's gear (AwakenUsed): a copy with it in awakenUsed.
static func mark_used(gear: Dictionary, slot: String) -> Dictionary:
	var out := gear.duplicate(true)
	var used: Array = out.get("awakenUsed") if out.get("awakenUsed") is Array else []
	if not used.has(slot):
		used.append(slot)
	out["awakenUsed"] = used
	return out


## Whether a match player's `slot` awaken is armed for this turn's shot (gear.armed).
static func armed(gear: Dictionary, slot: String) -> bool:
	return gear.get("armed") is Array and (gear["armed"] as Array).has(slot)


## A copy of a match player's gear with `slot` armed for the turn's shot.
static func mark_armed(gear: Dictionary, slot: String) -> Dictionary:
	var out := gear.duplicate(true)
	var a: Array = out.get("armed") if out.get("armed") is Array else []
	if not a.has(slot):
		a.append(slot)
	out["armed"] = a
	return out


## The wind a turn's shot flies with ({direction, power}): power 0 while the turn player's
## weapon awaken is armed (`gear`: their match gear) or `none` (my Awaken on its way, the awakened
## shot replaying); the server zeroes the wind for that shot (contract gear-effects).
static func turn_wind(wind: Dictionary, gear: Dictionary, none: bool = false) -> Dictionary:
	var out := {"direction": int(_num(wind.get("direction"))), "power": _num(wind.get("power"))}
	if none or armed(gear, "weapon"):
		out["power"] = 0.0
	return out


## A copy of a match player's gear with nothing armed (the shot used them, the turn passed).
static func clear_armed(gear: Dictionary) -> Dictionary:
	if not gear.get("armed") is Array or (gear["armed"] as Array).is_empty():
		return gear
	var out := gear.duplicate(true)
	out["armed"] = []
	return out


## The boots' passive on the walk: the share of the normal energy per px paid, 1 − moveCost / 100
## (1 without it; the server's profile is capped by its gear caps, so it stays above 0).
static func move_cost_factor(gear: Dictionary) -> float:
	var cost := _num(gear.get("moveCost"))
	return 1.0 if cost <= 0.0 else maxf(1.0 - cost / 100.0, 0.01)


## My awaken buttons: [{slot, used, enabled}] for my +16 pieces whose awaken is a button (the game
## data's), in the server's order. state: {my_turn, can_shoot (before my shot, my turn not lost),
## can_act (alive, my turn, not lost), rooted}. A used one stays (greyed); the weapon / gloves
## only before the shot; the boots any time in my turn but not rooted.
static func awaken_buttons(gear: Dictionary, state: Dictionary) -> Array:
	var used := used_awakens(gear)
	var out: Array = []
	for slot in awaken_slots(gear):
		if not awaken_is_button(slot):
			continue
		var was_used := used.has(slot)
		var ok := bool(state.get("can_act", false))
		if slot == "boots":
			ok = ok and not bool(state.get("rooted", false))
		else:
			ok = ok and bool(state.get("can_shoot", false))
		out.append({"slot": slot, "used": was_used, "enabled": ok and not was_used})
	return out


## The weapon level from which every shell of a weapon glows (the game data's glowLevel, +10).
static func glow_level() -> int:
	return GameData.gear_glow_level()
