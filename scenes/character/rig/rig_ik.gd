@tool
extends RefCounted
## Two-bone inverse kinematics in 2D (pure math): the bone rig's arms reach the gun's grips and its
## legs keep the feet on the ground (scenes/character/rig/rig_model.gd).


## The middle joint (elbow / knee) of a chain from `root` with bone lengths l1, l2 reaching for
## `target`, bent to one fixed side of the root → target line: bend +1 clockwise of it (on screen, y
## down), -1 counter-clockwise. A fixed side never flips from one solution to the other as the target
## moves round (a hint direction would, a pop). A target out of reach stretches the chain straight
## towards it; one too close folds it as far as it goes.
static func middle(root: Vector2, l1: float, l2: float, target: Vector2, bend: float) -> Vector2:
	var d := target - root
	var dl := d.length()
	var base := d.angle() if dl > 0.0001 else PI * 0.5
	var dist := clampf(dl, absf(l1 - l2) + 0.0001, l1 + l2 - 0.0001)
	var k := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	return root + Vector2.from_angle(base + signf(bend) * k) * l1


## Where the chain's end lands: the target when it is in reach.
static func end_point(root: Vector2, l1: float, l2: float, target: Vector2, bend: float) -> Vector2:
	var m := middle(root, l1, l2, target, bend)
	var d := target - m
	return m + (d.normalized() * l2 if d.length() > 0.0001 else Vector2.ZERO)
