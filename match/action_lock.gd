extends RefCounted
## One special shot per turn, chosen for good: the turn starts on the normal shot (WEAPON); tapping
## the skill slot or a shot item (one that arms the next Shoot) arms it, and from then on the turn
## can not go back to the normal shot or switch to another special: tapping it again does nothing,
## the other shot slots are off until the turn ends (match_screen.gd resets to WEAPON on a new
## turn). Instant items (medkit, wind_stopper: UseItem, the turn goes on) are not shots and stay
## usable, as the server allows several per turn. The server has no "un-arm": the special is
## chosen on the client only, so this is where the lock lives.

const WEAPON := "weapon"
const SKILL := "skill"


## The armed mode after tapping `slot` ("skill" or a shot item id): the normal shot arms it,
## anything already armed stays.
static func press(armed: String, slot: String) -> String:
	return slot if armed == WEAPON else armed


## Whether a shot slot can be tapped: `can` (its own rule: my turn, charged, not frozen ...) and
## nothing else armed (the normal shot, or this slot itself, shown armed).
static func slot_enabled(armed: String, slot: String, can: bool) -> bool:
	return can and (armed == WEAPON or armed == slot)


## A special is armed: the normal shot is gone for this turn.
static func locked(armed: String) -> bool:
	return armed != WEAPON
