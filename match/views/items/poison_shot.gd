extends "res://match/views/skills/skill_view.gd"
## Bom độc (item type poison): where its shell bursts, a green poison cloud rolls out over the
## blast (the mushrooms' spore cloud, SporeFx: a hard pop, then a lingering puff); the poison
## status, its badge and its ticks are the usual ones (status events, PlayerDamaged poison).

const SporeFx := preload("res://match/boss/spore_fx.gd")

const CLOUD_K := 1.6 # the cloud's reach × the blast radius
const MIN_REACH := 36.0


func explosion(event: Dictionary, fx: Node2D) -> void:
	var layer = ctx.get("layer")
	if not layer is Node2D or not event.get("position") is Dictionary:
		return
	var p := Vector2(float(event["position"].get("x", 0.0)), float(event["position"].get("y", 0.0)))
	var reach := cloud_reach(float(fx.radius))
	for mode in [SporeFx.BURST, SporeFx.PUFF]:
		var cloud := SporeFx.new(mode, reach)
		cloud.position = p - Vector2(0, 10)
		layer.add_child(cloud)


## How far the cloud rolls out for a blast of this radius (px).
static func cloud_reach(blast_radius: float) -> float:
	return maxf(blast_radius * CLOUD_K, MIN_REACH)
