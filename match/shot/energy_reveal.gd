extends RefCounted
## When a shot's new skill energies show. ShotResolved carries every player's energy after the
## shot (skillEnergies, the shooter's also as skillEnergy) the moment the server resolves it,
## before the shell has even left; showing them then would put a victim's +10 on screen while
## the shell is still in the air. The match keeps players[id].skillEnergy as the value on screen
## and this holds the rest until the replay reaches it:
## - fired(): the skill's shooter, at the fire moment (the lead-in over): its spent energy (0);
## - on_event(): a player's first damage event (amount > 0) in the replay, after its HP drop:
##   its new energy (the server's +10 when an enemy hit it);
## - finish(): when the replay ends, every value not shown yet (an energy that changed without a
##   hit on screen).
## Each returns {playerId: energy} to show now ({} for nothing). A resync drops it (clear()):
## the snapshot's values are shown as they are. The end-of-turn +20 comes in TurnStarted, which
## waits for the replay's end, so it never runs ahead either.

const SKILL := "skill"
const DAMAGE := "damage"

var _pending := {} # playerId -> energy still to show
var _skill_shooter := "" # the skill's shooter until fired()


## timeline: the ShotTimeline; players: {playerId: match player dict}, their skillEnergy the
## values on screen. Only the energies that differ from them wait.
func begin(timeline, players: Dictionary) -> void:
	clear()
	var energies: Dictionary = timeline.skill_energies.duplicate()
	if timeline.shooter_energy >= 0 and not energies.has(timeline.shooter_id):
		energies[timeline.shooter_id] = timeline.shooter_energy # an older server: the shooter's only
	for id in energies:
		var value = energies[id]
		if not players.has(id) or not (value is int or value is float):
			continue
		if int(value) != int(players[id].get("skillEnergy", 0)):
			_pending[id] = int(value)
	if timeline.action_mode == SKILL and _pending.has(timeline.shooter_id):
		_skill_shooter = timeline.shooter_id


## The fire moment: the skill's shooter spends its energy.
func fired() -> Dictionary:
	if _skill_shooter == "" or not _pending.has(_skill_shooter):
		return {}
	var out := {_skill_shooter: _pending[_skill_shooter]}
	_pending.erase(_skill_shooter)
	_skill_shooter = ""
	return out


## A replayed timeline event: a damage event on a player whose energy waits shows it.
func on_event(e: Dictionary) -> Dictionary:
	if str(e.get("type", "")) != DAMAGE or int(e.get("amount", 0)) <= 0:
		return {}
	var id := str(e.get("playerId", ""))
	if not _pending.has(id) or id == _skill_shooter:
		return {}
	var out := {id: _pending[id]}
	_pending.erase(id)
	return out


## The replay ended: everything not shown yet.
func finish() -> Dictionary:
	var out := _pending
	_pending = {}
	_skill_shooter = ""
	return out


func clear() -> void:
	_pending = {}
	_skill_shooter = ""


## The energies still waiting, {playerId: energy}.
func pending() -> Dictionary:
	return _pending.duplicate()
