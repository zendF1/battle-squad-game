extends "res://match/views/skills/skill_view.gd"
## A boss's global skill (GET /gamedata bosses skills kind "global": Phù Thuỷ Băng's Bão tuyết,
## Khổng Lồ Đá's Động đất, Mộc Tinh's Mưa gai độc): it hits every party member wherever they stand,
## so the camera frames the whole map (frames_map()) and does not chase the shells. From the global
## event, for its duration, the boss's storm blows over the screen (BossArt.STORM: snow for the
## witch's ice shards, spores for the tree's poison thorns; StormOverlay on the screen layer); the
## shards and thorns are the boss's own projectiles (UnitShell, one per member, the damage at its
## end, where match_screen bursts it on the member). The earthquake has none: match_screen shakes
## the camera for the duration and splits the ground under each member as its damage comes.
## Round 2 (Đĩa Bay Thép's Bom mù: signalKind flash_flare, flash): its flash flare (UnitShell
## flash_flare) shoots up off the top of the map from the top of the craft (its dome: drawn there at
## launch and easing onto the server's path from the turret pivot, UnitShell.lead; the turret cannot
## point up); at the global event with `flash` the whole screen flashes white for everyone
## (FlashFx on the screen layer: FLASH_HOLD s full, then fading over the event's duration). The
## blind that follows is match_screen's (its status events; my white-out, BlindOverlay).
## Mộc Tinh's thorns (poison_thorn) leave its canopy (the boss's muzzle_position(): points.json canopy
## while poison_thorns shows, else BossArt.MUZZLE), easing onto the server's paths (UnitShell.lead).

const StormOverlay := preload("res://match/boss/storm_overlay.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const UnitShell := preload("res://match/views/unit_shell.gd")
const FLASH_HOLD := 0.12

var _storm: Node2D = null
var _until := -1.0
var _flash: Control = null


## The flash over the screen (null none; tests).
func flash() -> Control:
	return _flash


## The flash flare leaves from the top of the craft (the boss's dome), the tree's thorns from its
## canopy, easing onto their paths.
func projectile_view(_i: int, projectile: Dictionary, view: Node2D) -> Node2D:
	var kind := str(projectile.get("kind", ""))
	if not kind in [UnitShell.FLASH_FLARE, UnitShell.POISON_THORN] or not "lead" in view:
		return view
	var shooter = ctx.get("views", {}).get(str(ctx.get("shooter", "")))
	var path = projectile.get("path")
	if shooter == null or not is_instance_valid(shooter) or not shooter.has_method("figure") or not path is Array or path.is_empty():
		return view
	var fig = shooter.figure()
	var from := "top_position" if kind == UnitShell.FLASH_FLARE else "muzzle_position"
	if fig == null or not fig.has_method(from):
		return view
	var first = path[0].get("position") if path[0] is Dictionary else null
	if not first is Dictionary:
		return view
	var start := Vector2(float(first.get("x", 0.0)), float(first.get("y", 0.0)))
	view.lead = Vector2(fig.call(from)) - start # the fx layer is the world (no transform of its own)
	return view


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
	if bool(event.get("flash", false)) and ctx.get("screen") is Node:
		_flash = FlashFx.new(maxf(float(event.get("duration", 0.0)), 0.4))
		ctx["screen"].add_child(_flash)
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


## The map-wide white flash: the whole screen white for FLASH_HOLD s, then fading out over the rest
## of `sec` (ease out); frees itself. Taps go through.
class FlashFx extends ColorRect:
	var sec := 1.2
	var _t := 0.0

	func _init(seconds: float = 1.2) -> void:
		sec = seconds
		name = "MapFlash"
		mouse_filter = MOUSE_FILTER_IGNORE
		set_anchors_preset(PRESET_FULL_RECT)
		color = Color(1, 1, 1, 1)

	func step(delta: float) -> void:
		_t += delta
		var k := clampf((_t - FLASH_HOLD) / maxf(sec - FLASH_HOLD, 0.01), 0.0, 1.0)
		color.a = 1.0 - k * k * (3.0 - 2.0 * k)

	func done() -> bool:
		return _t >= sec

	func _process(delta: float) -> void:
		step(delta)
		if done():
			queue_free()
