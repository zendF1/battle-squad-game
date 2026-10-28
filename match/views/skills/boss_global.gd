extends "res://match/views/skills/skill_view.gd"
## A boss's global skill (GET /gamedata bosses skills kind "global": Phù Thuỷ Băng's Bão tuyết,
## Khổng Lồ Đá's Động đất, Mộc Tinh's Mưa gai độc): it hits every party member wherever they stand,
## so the camera frames the whole map (frames_map()) and does not chase the shells. From the global
## event, for its duration, the boss's storm blows over the screen (BossArt.STORM: snow for the
## witch's ice shards, spores for the tree's poison thorns; StormOverlay on the screen layer); the
## shards and thorns are the boss's own projectiles (UnitShell, one per member, the damage at its
## end, where match_screen bursts it on the member). The earthquake has none: match_screen shakes
## the camera for the duration and splits the ground under each member as its damage comes.

const StormOverlay := preload("res://match/boss/storm_overlay.gd")
const BossArt := preload("res://match/boss/boss_art.gd")

var _storm: Node2D = null
var _until := -1.0


func frames_map() -> bool:
	return true


func tracks_shells() -> bool:
	return false


## The storm over the screen (null none; tests).
func storm() -> Node2D:
	return _storm


func on_event(event: Dictionary) -> void:
	if str(event.get("type", "")) != "global":
		return
	_until = float(event.get("t", 0.0)) + maxf(float(event.get("duration", 0.0)), 0.3)
	var shooter: Dictionary = ctx.get("players", {}).get(str(ctx.get("shooter", "")), {})
	var kind := str(BossArt.STORM.get(BossArt.art_of(str(shooter.get("bossId", ""))), ""))
	var screen = ctx.get("screen")
	if kind != "" and kind != StormOverlay.EMBER and screen is Node:
		_storm = StormOverlay.new(kind)
		_storm.wind = -1.0 if float(ctx.get("wind", -1.0)) < 0.0 else 1.0
		screen.add_child(_storm)


func process(t: float) -> void:
	if _until >= 0.0 and t >= _until and _storm != null and is_instance_valid(_storm):
		_storm.release()


func end() -> void:
	if _storm != null and is_instance_valid(_storm):
		_storm.release()
	_storm = null
