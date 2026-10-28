extends "res://match/views/skills/skill_view.gd"
## A boss's roll skill (GET /gamedata bosses skills kind "roll": Khổng Lồ Đá's Đá lăn): the thrown
## boulder (projectile kind "rolling_boulder") flies as the same boulder (RollingBoulderView at the
## skill's radius, tumbling) that match_screen then rolls along the roll event's ground path from
## where it lands (BossMoves), crushing whoever it rolls over. The camera follows the throw.

const RollingBoulderView := preload("res://match/boss/rolling_boulder_view.gd")
const KIND := "rolling_boulder"


func projectile_view(_i: int, projectile: Dictionary, view: Node2D) -> Node2D:
	if str(projectile.get("kind", "")) != KIND:
		return view
	return RollingBoulderView.new(radius_of(projectile))


## The boulder's radius: the projectile's explosionRadius (the roll's radius), else the skill's.
func radius_of(projectile: Dictionary) -> float:
	var r = projectile.get("explosionRadius")
	if (r is int or r is float) and float(r) > 0.0:
		return float(r)
	var sk := GameData.boss_skill("", skill_id())
	var sr = sk.get("radius")
	return float(sr) if (sr is int or sr is float) and float(sr) > 0.0 else 60.0
