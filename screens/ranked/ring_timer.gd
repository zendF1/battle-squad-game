extends RefCounted
## The matchmaking screen's timer ring round the VS emblem, without UI: while searching it fills
## clockwise with the time waited, one lap every LAP_SEC, and starts again from empty after each
## lap; when the match is found it runs from where it was to full in FILL_SEC, then the burst
## (flash, sparks, scale pop) plays for BURST_SEC. The screen ticks it and draws fill() and burst().

const LAP_SEC := 30.0
const FILL_SEC := 0.25
const BURST_SEC := 0.7

## Seconds searched (the small timer under the emblem).
var elapsed := 0.0
## Seconds since the match was found; -1 before.
var found_for := -1.0
var _fill_at_found := 0.0


## The share of a lap filled after `t` seconds: 0 at the start of every lap, just under 1 at its end.
static func lap_fill(t: float) -> float:
	return fposmod(maxf(t, 0.0), LAP_SEC) / LAP_SEC


## Advances the ring: the search time while searching, the found animation once found.
func tick(delta: float, searching: bool = true) -> void:
	if found_for >= 0.0:
		found_for += delta
	elif searching:
		elapsed += delta


## The match was found: the ring runs to full from where it is (once).
func find() -> void:
	if found_for >= 0.0:
		return
	_fill_at_found = lap_fill(elapsed)
	found_for = 0.0


func is_found() -> bool:
	return found_for >= 0.0


## The share of the ring drawn, 0..1.
func fill() -> float:
	if found_for < 0.0:
		return lap_fill(elapsed)
	var k := clampf(found_for / FILL_SEC, 0.0, 1.0)
	return lerpf(_fill_at_found, 1.0, 1.0 - (1.0 - k) * (1.0 - k)) # eases out into full


## The burst's progress, 0..1: 0 until the ring is full after a find, 1 once it is over.
func burst() -> float:
	if found_for < FILL_SEC:
		return 0.0
	return clampf((found_for - FILL_SEC) / BURST_SEC, 0.0, 1.0)


## The burst is playing (drawn).
func bursting() -> bool:
	return found_for >= FILL_SEC and burst() < 1.0


## Whole seconds searched.
func seconds() -> int:
	return int(elapsed)
