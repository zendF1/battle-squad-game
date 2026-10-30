extends RefCounted
## PlayerState's watch over a match reward still on its way (MatchEnded rewardSettlementStatus
## "pending", docs/contracts/security-settlement.md): the server keeps granting it (on its start,
## then every 30 s) and sends no event when it lands, so the profile is fetched again a few times
## (next_delay(): FIRST_SEC, then every EVERY_SEC, MAX_CHECKS times in all, about three minutes)
## until its coin, exp or level move from what they were when the watch started (LANDED), the
## checks run out (GAVE_UP) or another account signs in (GAVE_UP). The cadence is the client's,
## not game data.

const FIRST_SEC := 10.0
const EVERY_SEC := 30.0
const MAX_CHECKS := 7

const WAIT := "wait"
const LANDED := "landed"
const GAVE_UP := "gave_up"

var active := false
var checks := 0
var baseline := {} # snapshot() of the profile when the watch started; {} unknown (the first check takes it)
var player := ""


## Starts (or starts over) from the cached profile of `player_id`.
func start(profile: Dictionary, player_id: String) -> void:
	active = true
	checks = 0
	player = player_id
	baseline = snapshot(profile, player_id)


func stop() -> void:
	active = false


## Seconds before the next check.
func next_delay() -> float:
	return FIRST_SEC if checks == 0 else EVERY_SEC


## A profile fetched for the check: WAIT (check again after next_delay()), LANDED or GAVE_UP (the
## watch stopped).
func on_profile(profile: Dictionary, player_id: String) -> String:
	if not active:
		return GAVE_UP
	if player_id != player:
		stop()
		return GAVE_UP
	checks += 1
	var now := snapshot(profile, player_id)
	if baseline.is_empty():
		baseline = now
	elif not now.is_empty() and now != baseline:
		stop()
		return LANDED
	if checks >= MAX_CHECKS:
		stop()
		return GAVE_UP
	return WAIT


## What a match reward moves in the profile: {coin, exp, level}; {} when `profile` is not
## `player_id`'s (or not loaded).
static func snapshot(profile: Dictionary, player_id: String) -> Dictionary:
	if profile.is_empty() or str(profile.get("playerId", "")) != player_id:
		return {}
	return {"coin": _num(profile.get("coin")), "exp": _num(profile.get("exp")), "level": _num(profile.get("level"))}


static func _num(v: Variant) -> int:
	return int(v) if v is int or v is float else 0
