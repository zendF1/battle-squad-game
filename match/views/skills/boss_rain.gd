extends "res://match/views/skills/rain.gd"
## A boss's rain skill (GET /gamedata bosses skills kind "rain": Mưa đạn pháo, Bom dung nham,
## Càng nghiền, Gai băng, Bão tuyết): no flare is fired; at the rain event (position: the target,
## radius: the spread) a red danger ring opens on the ground there with the signal smoke of the
## rain, then the shells (projectile kind "missile", in the boss's shot look) fall from the top of
## the map like Rookie's missiles, their hits counting up in one number per player. The name is
## the boss skill's (SkillView.skill_name()); damage, shells and lava come from the server timeline.
## The camera stays on the target's ground while they fall (tracks_shells()).

var _ring: Node2D = null


## The camera looks at the target's ground, not at the shells high above it.
func tracks_shells() -> bool:
	return false


func on_event(event: Dictionary) -> void:
	super.on_event(event)
	if str(event.get("type", "")) != "rain":
		return
	var p = event.get("position")
	if not p is Dictionary:
		return
	var at := Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0)))
	if _fx != null and is_instance_valid(_fx):
		_fx.land(at)
	var layer = ctx.get("layer")
	if layer is Node2D:
		_ring = DangerRing.new()
		_ring.position = at
		_ring.radius = maxf(float(event.get("radius", 60.0)), 30.0)
		layer.add_child(_ring)


## The ground ring under a boss's rain: it opens, pulses red while the shells fall, then fades.
class DangerRing extends Node2D:
	const LIFE := 2.2
	var radius := 80.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var open := minf(_t / 0.25, 1.0)
		var fade := 1.0 - clampf((_t - (LIFE - 0.5)) / 0.5, 0.0, 1.0)
		var pulse := 0.6 + 0.4 * sin(_t * 12.0)
		var r := radius * open
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.15, 0.1, 0.16 * fade))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.25, 0.15, 0.9 * fade * pulse), 5.0, true)
		draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 40, Color(1.0, 0.5, 0.3, 0.6 * fade), 3.0, true)
		draw_set_transform(Vector2.ZERO)
		var s := 10.0 * open
		draw_line(Vector2(-s, 0), Vector2(s, 0), Color(1, 0.9, 0.8, 0.9 * fade), 3.0, true)
		draw_line(Vector2(0, -s * 0.6), Vector2(0, s * 0.6), Color(1, 0.9, 0.8, 0.9 * fade), 3.0, true)
