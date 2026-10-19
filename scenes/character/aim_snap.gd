extends RefCounted
## The held gun points one of 7 world directions, never anywhere in between (visual only: the shot,
## the aim line, the power and every network angle keep the real angle). Angles are degrees in the
## Shoot / PlayerAiming convention: 0 right, 90 up, 180 left.
##
##   right side: -45, 0, 45     up: 90     left side: 135, 180, 225 (= -135)
##
## Nothing points below -45 on either side (no straight down). An angle turns the gun to the nearest
## direction on its side (boundaries halfway: 22.5, 67.5, 112.5, 157.5, -22.5 / 202.5; an exact
## boundary goes to the upper one); anything below -45 on the right is -45, below 225 on the left
## 225. The side is the raw angle's: under 90 faces right, over 90 left; straight up (90) and
## straight down (-90 / 270) keep the current facing. Used by scenes/character/character.gd (every
## aim(): the local drag, a remote player's PlayerAiming sweep, a shot replay) and
## match/views/player_view.gd face_angle().

const STEP := 45.0
const LOWEST := -45.0 # elevation: degrees above level towards the facing side
const HIGHEST := 90.0
## The 7 directions as world angles, right to left.
const DIRECTIONS := [-45.0, 0.0, 45.0, 90.0, 135.0, 180.0, 225.0]


## angle normalised to -90 <= a < 270 (straight down is -90).
static func normalize(angle: float) -> float:
	return wrapf(angle, -90.0, 270.0)


## The side an aim angle faces: 1 right (under 90), -1 left (over 90), `current` straight up or
## straight down.
static func side(angle: float, current: int) -> int:
	var a := normalize(angle)
	if is_equal_approx(a, 90.0) or is_equal_approx(a, -90.0):
		return current
	return 1 if a < 90.0 else -1


## The gun's snapped elevation for an aim angle on a character facing facing_dir (1 right, -1
## left): one of -45, 0, 45, 90 degrees above level towards the facing side. An angle behind the
## character (facing the wrong side) is held at the nearest end (90 up or -45 down).
static func elevation(angle: float, facing_dir: int) -> float:
	var up := wrapf(angle if facing_dir > 0 else 180.0 - angle, -180.0, 180.0)
	if up < -90.0:
		up = LOWEST # behind and below: forward down
	return clampf(floorf(up / STEP + 0.5) * STEP, LOWEST, HIGHEST)


## The world direction (one of DIRECTIONS) the gun shows for an aim angle; facing_dir (1 right, -1
## left, 0 right) picks the side for straight up / straight down only.
static func snap(angle: float, facing_dir: int = 0) -> float:
	var f := side(angle, 1 if facing_dir >= 0 else -1)
	var e := elevation(angle, f)
	return e if f > 0 else 180.0 - e
