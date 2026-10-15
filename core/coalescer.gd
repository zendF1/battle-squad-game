extends RefCounted
## Coalesces refresh requests for one resource: one fetch at a time, and an answer is applied
## only when no newer refresh was asked while it was in flight (that answer may predate the
## change the newer refresh was asked for); the caller then fetches again.
##
##     if not gate.ask(): return          # one is running; it will fetch again
##     while true:
##         var t := gate.ticket()
##         var res = await fetch()
##         if gate.finish(t): apply(res); break

var running := false
var _asked := 0


## A refresh was asked. True when the caller should start fetching (none in flight).
func ask() -> bool:
	_asked += 1
	if running:
		return false
	running = true
	return true


## The ticket for the fetch about to start.
func ticket() -> int:
	return _asked


## The fetch for `t` answered. True when it is the latest (apply it; the gate is idle again),
## false when a newer refresh was asked meanwhile (drop the answer and fetch again).
func finish(t: int) -> bool:
	if t != _asked:
		return false
	running = false
	return true
