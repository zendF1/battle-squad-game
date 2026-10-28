extends RefCounted
## players[id].statusEffects ([{effectId, durationTurn, value, ...}]) as the server keeps them
## (match/status_effect.go): an effect is active while durationTurn > 0; it loses one turn at
## the end of its target's own turn. Snapshots and ItemUsed carry the full list; TurnStarted
## does not, so the client ticks it the same way, and a ShotResolved "status" event applies one.
##
## What each effect does and says is the game data's (GET /gamedata statusEffects, in order:
## name, marker, banner, bad, skipsTurn, blocksMove): every active effect is drawn on the unit's
## body (match/views/status_look.gd, status_fx.gd; no icons beside the HP bar), a status event as
## its picture bursting over the unit (match/views/status_burst.gd), an armed shot item as its
## icon on the use badge, only a marker with no picture as text above the head; a lost turn is a
## countdown ring, a blocked move the effect's picture over the move buttons.

const GameData := preload("res://autoload/game_data_model.gd")
const Items := preload("res://match/items.gd")


static func has(effects: Variant, effect_id: String) -> bool:
	if not effects is Array:
		return false
	for e in effects:
		if e is Dictionary and str(e.get("effectId", "")) == effect_id and int(e.get("durationTurn", 0)) > 0:
			return true
	return false


## The active effect ids of a list, each once, in list order.
static func active(effects: Variant) -> Array:
	var out: Array = []
	if not effects is Array:
		return out
	for e in effects:
		if not e is Dictionary or int(e.get("durationTurn", 0)) <= 0:
			continue
		var id := str(e.get("effectId", ""))
		if id != "" and not out.has(id):
			out.append(id)
	return out


## The text markers of the active effects, in list order, each once: only an effect with no
## picture of its own; an armed shot item ("x1.5", "Khoan") is its icon on the use badge over the
## head (match/views/use_badge.gd) and its aura on the body, never text.
static func marker_text(effects: Variant) -> String:
	var parts: Array[String] = []
	for id in active(effects):
		if Items.order().has(id):
			continue
		var text := GameData.status_marker(id)
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


## The effect skipping the player's turn (the first active skipsTurn effect in the game data's
## order: stun before freeze), "" for none.
static func skip_effect(effects: Variant) -> String:
	var on := active(effects)
	for id in GameData.status_ids():
		if GameData.status_skips_turn(id) and on.has(id):
			return id
	return ""


## An active effect keeps the player from walking and teleporting (blocksMove: root, stun, freeze).
static func blocks_move(effects: Variant) -> bool:
	for id in active(effects):
		if GameData.status_blocks_move(id):
			return true
	return false


## The banner of a lost turn ("Choáng — mất lượt"), "" for none.
static func skip_text(effect_id: String) -> String:
	return GameData.status_banner(effect_id)


## The move controls' notice while an active effect blocks moving without skipping the turn
## ("Bị cầm chân"), "" for none.
static func move_block_text(effects: Variant) -> String:
	for id in active(effects):
		if GameData.status_blocks_move(id) and not GameData.status_skips_turn(id):
			var t := GameData.status_banner(id)
			if t != "":
				return t
	return ""


## The effect blocking moving without skipping the turn (root), "" for none: its picture shows
## over the move controls.
static func move_block_effect(effects: Variant) -> String:
	for id in active(effects):
		if GameData.status_blocks_move(id) and not GameData.status_skips_turn(id):
			return id
	return ""


## The bad effects (the bloom cleanses them) among the active ones.
static func bad(effects: Variant) -> Array:
	return active(effects).filter(func(id): return GameData.status_bad(id))


## The list without the effects in ids (a cleanse event's effectIds).
static func remove(effects: Variant, ids: Variant) -> Array:
	var out: Array = []
	if not effects is Array:
		return out
	for e in effects:
		if e is Dictionary and not (ids is Array and ids.has(str(e.get("effectId", "")))):
			out.append(e.duplicate(true))
	return out
