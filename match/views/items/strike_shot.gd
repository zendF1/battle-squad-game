extends "res://match/views/skills/skill_view.gd"
## Bom huỷ diệt / Laze (item types nuke / laser; ShotResolved: a projectile kind "signal", the
## strike event {kind, position, radius, beams, duration}, a nuke's projectile kind "nuke", then the
## explode): the signal flies as a red flare canister (SignalShell); where it lands StrikeFx burns
## the flare on the ground and marks the target (a turning red ring of the strike's radius, a
## crosshair; for the nuke a red guide line from the sky, the danger pulsing faster as it nears);
## - nuke: the bomb falls along its server path (NukeShell); its explode is the blast's reach,
##   with NukeBlast over it (a white flash, a fireball, a ground shockwave, the mushroom cloud
##   rising) and a white screen flash;
## - laser: `beams` laser beams swing in from the sky and converge on the point while charging,
##   then fire (StrikeFx.hit() on the explode without projectileId, whose burst is the strike's
##   radius).
## Every time is the server's (the events); this only draws them.

const SignalShell := preload("res://match/views/items/signal_shell.gd")
const NukeShell := preload("res://match/views/items/nuke_shell.gd")
const StrikeFx := preload("res://match/views/items/strike_fx.gd")
const NukeBlast := preload("res://match/views/items/nuke_blast.gd")

const SIGNAL := "signal"
const NUKE := "nuke"
const LASER := "laser"
const SCREEN_FLASH_SEC := 0.45

var _fx: Node2D = null # StrikeFx of the strike event
var _kind := "" # the strike's kind: NUKE / LASER ("" before it)
var _radius := 0.0


func begin(context: Dictionary) -> void:
	super.begin(context)
	_fx = null
	_kind = ""
	_radius = 0.0
	var timeline = ctx.get("timeline")
	if timeline != null: # known from the start: the signal's colour
		for e in timeline.events_of("strike"):
			_kind = strike_kind(e, str(timeline.item_id))
			break


## A strike event's kind: its "kind", else its item's type in the game data, else NUKE.
static func strike_kind(event: Dictionary, item_id: String = "") -> String:
	var k := str(event.get("kind", ""))
	if k == NUKE or k == LASER:
		return k
	var t := GameData.item_type(str(event.get("itemId", item_id)))
	return LASER if t == LASER else NUKE


func projectile_view(_i: int, projectile: Dictionary, view: Node2D) -> Node2D:
	match str(projectile.get("kind", "")):
		SIGNAL:
			var s := SignalShell.new()
			s.laser = _kind == LASER
			s.heading = view.get("heading") if view.get("heading") is Vector2 else Vector2.ZERO
			return s
		NUKE:
			var n := NukeShell.new()
			n.heading = Vector2.DOWN
			return n
	return view


func on_event(event: Dictionary) -> void:
	if str(event.get("type", "")) != "strike" or not event.get("position") is Dictionary:
		return
	var layer = ctx.get("layer")
	if not layer is Node2D:
		return
	_kind = strike_kind(event, str(ctx.get("timeline").item_id) if ctx.get("timeline") != null else "")
	_radius = float(event.get("radius", 40.0))
	if _fx != null and is_instance_valid(_fx):
		_fx.release()
	_fx = StrikeFx.new()
	_fx.kind = _kind
	_fx.radius = _radius
	_fx.beams = int(event.get("beams", 5))
	_fx.duration = float(event.get("duration", 0.8))
	_fx.position = Vector2(float(event["position"].get("x", 0.0)), float(event["position"].get("y", 0.0)))
	layer.add_child(_fx)


func explosion(event: Dictionary, fx: Node2D) -> void:
	var p := Vector2(float(event["position"].get("x", 0.0)), float(event["position"].get("y", 0.0))) \
		if event.get("position") is Dictionary else Vector2.ZERO
	var timeline = ctx.get("timeline")
	var pid := str(event.get("projectileId", ""))
	var layer = ctx.get("layer")
	if pid != "" and timeline != null and timeline.kind_of(pid) == NUKE:
		fx.radius = maxf(fx.radius, _radius)
		if layer is Node2D:
			var blast := NukeBlast.new()
			blast.radius = fx.radius
			blast.position = p
			layer.add_child(blast)
		_screen_flash()
		if _fx != null and is_instance_valid(_fx):
			_fx.hit()
	elif pid == "" and _kind == LASER:
		fx.radius = maxf(fx.radius, _radius)
		if _fx != null and is_instance_valid(_fx):
			_fx.hit()


## A white flash over the whole screen (the nuke's), fading.
func _screen_flash() -> void:
	var screen = ctx.get("screen")
	if not screen is Node:
		return
	var flash := ColorRect.new()
	flash.color = Color(1, 0.98, 0.9, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(flash)
	var t := flash.create_tween()
	t.tween_property(flash, "color:a", 0.0, SCREEN_FLASH_SEC).set_ease(Tween.EASE_OUT)
	t.tween_callback(flash.queue_free)


func end() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.release()
	_fx = null


## What the replay draws now, for tests: {kind, radius, fx (StrikeFx.state() or {})}.
func state() -> Dictionary:
	return {"kind": _kind, "radius": _radius, "fx": _fx.state() if _fx != null and is_instance_valid(_fx) else {}}
