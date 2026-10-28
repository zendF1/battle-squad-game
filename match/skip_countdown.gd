extends RefCounted
## A lost turn's countdown (063: a frozen / stunned unit's TurnStarted says skipped "freeze" /
## "stun" and skipAfter s: the server ends that turn skipAfter s after it sent it). No text: a
## ring that empties clockwise and the whole seconds left (5, 4, … 1), in the effect's colour,
## over the unit and, for my own lost turn, dead centre on the screen. A TurnStarted held back by
## a replay counts from when it arrived (`elapsed`). No skipAfter (an older server): no countdown.
## Pure: the views read number() / fraction() every frame.

var effect := "" # the effect skipping the turn ("freeze", "stun"), "" none
var player_id := "" # whose turn is lost
var total := 0.0 # skipAfter (s)
var _left := 0.0 # s left now


## Starts the countdown of a TurnStarted {currentPlayerId, skipped, skipAfter}: skip is the
## effect id (TurnStarted.skipped, else the unit's effects), elapsed the s since it arrived.
## Returns whether it runs (skipped with a positive skipAfter).
func start(turn_started: Dictionary, skip: String, elapsed: float = 0.0) -> bool:
	var after = turn_started.get("skipAfter")
	if skip == "" or not (after is int or after is float) or float(after) <= 0.0:
		stop()
		return false
	effect = skip
	player_id = str(turn_started.get("currentPlayerId", ""))
	total = float(after)
	_left = maxf(total - maxf(elapsed, 0.0), 0.0)
	return _left > 0.0


func stop() -> void:
	effect = ""
	player_id = ""
	total = 0.0
	_left = 0.0


## Moves it on by dt s.
func step(dt: float) -> void:
	if total > 0.0:
		_left = maxf(_left - dt, 0.0)


## Shown: started, not run out.
func active() -> bool:
	return effect != "" and _left > 0.0


func left() -> float:
	return _left


## The whole seconds left, as shown: 5 for the first second … 1 for the last; 0 when over.
func number() -> int:
	return maxi(1, ceili(_left - 1e-6)) if active() else 0


## The ring's share still filled (1 → 0).
func fraction() -> float:
	return clampf(_left / total, 0.0, 1.0) if total > 0.0 and active() else 0.0
