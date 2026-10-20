extends "res://match/views/skills/skill_view.gd"
## Rookie — Mưa tên lửa (server skill triple_shot, effect missile_rain): a flare fired like a
## normal shot; where it lands (event flare) missiles (projectile kind "missile") fall from the
## top of the map around it (event rain: position, radius, count); every enemy hit burns.
## Visuals: STUB (default replay). To build: the flare shell with a red light / smoke trail and a
## red smoke column where it lands, the missiles nose-down, smaller explosions.


func skill_id() -> String:
	return "triple_shot"


func skill_name() -> String:
	return "Mưa tên lửa"


func describe(rank: int) -> String:
	return "Bắn pháo hiệu, %d tên lửa rơi quanh chỗ đáp (+2 mỗi cấp súng), mỗi quả 35%% sát thương; địch trúng bị bỏng: mất 10%% máu tối đa đầu lượt sau." % (6 + 2 * rank)
