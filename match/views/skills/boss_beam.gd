extends "res://match/views/skills/laser.gd"
## A boss's beam skill (GET /gamedata bosses skills kind "beam": Tia laze nghiền, Tia băng giá):
## the laser's visuals (laser_fx.gd: the charge at the boss's muzzle point, the beam sweeping
## through the terrain to the map edge in the boss's shot look, a burst on every player hit), its
## timing from the beam event (t, duration). Boss skills have no game data tuning of their own: the
## laser effect's (the first laser skill's params) is used.


func param(key: String) -> float:
	return GameData.effect_param("laser", key)
