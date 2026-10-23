extends RefCounted
## Which players have a shield up and in what colour (the bubble round them, match/views/
## shield_ball.gd): a shield comes from Flora's bloom (its healing past full HP) and its bubble
## takes the caster's gun tier, remembered for as long as that shield lasts. update() is fed every
## shield value the match learns (ShotResolved shield / damage events, PlayerDamaged, ItemUsed,
## snapshots) and says what changed: GAIN (0 → > 0: the bubble pops in), KEEP (still up), BREAK
## (→ 0: it pops out), NONE (still none). A shield without a known caster (a reconnect's
## snapshot) takes the player's own gun tier, else the default tint. Pure.

const ShieldBall := preload("res://match/views/shield_ball.gd")

const GAIN := "gain"
const KEEP := "keep"
const BREAK := "break"
const NONE := "none"

var _shield := {} # playerId -> shield
var _tier := {} # playerId -> the gun tier its bubble shows ("" the default)


## Takes player id's shield now; caster_tier: the gun tier of who gave it (the shield event's
## shooter), "" unknown; own_tier: the player's own gun tier (the fallback). Returns GAIN / KEEP /
## BREAK / NONE.
func update(id: String, shield: int, caster_tier: String = "", own_tier: String = "") -> String:
	var was := int(_shield.get(id, 0)) > 0
	var now := shield > 0
	_shield[id] = maxi(shield, 0)
	if now and caster_tier != "":
		_tier[id] = caster_tier # a new shield (or a new layer of it) in the caster's colour
	elif now and not _tier.has(id):
		_tier[id] = own_tier
	if not now:
		_tier.erase(id)
	if now:
		return KEEP if was else GAIN
	return BREAK if was else NONE


func has(id: String) -> bool:
	return int(_shield.get(id, 0)) > 0


## The gun tier the bubble of id shows ("" the default).
func tier_of(id: String) -> String:
	return str(_tier.get(id, ""))


## The bubble's tint for id (ShieldBall.tier_colour of tier_of()).
func colour_of(id: String) -> Color:
	return ShieldBall.tier_colour(tier_of(id))


func clear() -> void:
	_shield.clear()
	_tier.clear()
