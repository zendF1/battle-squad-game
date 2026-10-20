extends "res://match/views/skills/skill_view.gd"
## Spark — Tia laze (server skill shock_field, effect laser): a straight beam (event beam: from,
## to, duration) through terrain to the map edge, no projectile; damage cause "laser"; every
## enemy hit is stunned. Aimed with a straight line in any direction (AIM_LINE).
## Visuals: STUB (the default replay draws no beam). To build: the glowing beam (core + glow,
## flicker), an impact flash on each enemy hit.


func skill_id() -> String:
	return "shock_field"


func skill_name() -> String:
	return "Tia laze"


func aim_mode() -> String:
	return AIM_LINE


func describe(rank: int) -> String:
	return "Tia thẳng xuyên địa hình tới mép bản đồ, trúng mọi địch trên đường: %d%% sát thương, mỗi địch sau giảm 20%%; địch trúng bị choáng, mất lượt sau." % (150 + 10 * rank)


## The gun points along the beam.
func aim_angle(timeline) -> float:
	for e in timeline.events:
		if str(e.get("type", "")) == "beam" and e.get("from") is Dictionary and e.get("to") is Dictionary:
			var d := Vector2(float(e["to"]["x"]) - float(e["from"]["x"]), float(e["to"]["y"]) - float(e["from"]["y"]))
			if d.length() > 0.01:
				return rad_to_deg(atan2(-d.y, d.x))
	return NAN
