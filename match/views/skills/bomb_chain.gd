extends "res://match/views/skills/skill_view.gd"
## Tanko — Bom liên hoàn (server skill heavy_bomb, effect bomb_chain): bombs (projectile kind
## "bomb", each leaving at its launchDelay) on one trajectory dig one shaft; every enemy hit is
## rooted. Visuals: STUB (default replay). To build: the cannon shell ×1.4, bigger explosions.


func skill_id() -> String:
	return "heavy_bomb"


func skill_name() -> String:
	return "Bom liên hoàn"


func describe(rank: int) -> String:
	return "Bắn %d quả bom lớn liên tiếp cùng đường bay (+1 mỗi cấp súng), đào sâu một hố; tổng %d%% sát thương; địch trúng bị cầm chân lượt sau." % [3 + rank, 180 + 15 * rank]
