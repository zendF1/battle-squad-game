extends "res://match/views/skills/skill_view.gd"
## A boss's airburst skill (GET /gamedata bosses skills kind "airburst": Rô-bốt Thép's Bom mù): its
## one projectile (kind "orb") flies as an energy orb (match/boss/orb_view.gd) high up and down to
## the burst point over the target; match_screen draws the burst at the airburst event (AirburstFx,
## a white blink over the screen) and the blind on the members it hits. The camera follows the orb.

const OrbView := preload("res://match/boss/orb_view.gd")
const ORB := "orb"


func projectile_view(_i: int, projectile: Dictionary, view: Node2D) -> Node2D:
	return OrbView.new() if str(projectile.get("kind", "")) == ORB else view
