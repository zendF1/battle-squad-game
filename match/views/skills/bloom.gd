extends "res://match/views/skills/skill_view.gd"
## Flora — Hoa hồi xuân (server skill healing_bloom, effect bloom): no aim; seeds (projectile kind
## "seed", hitPlayerId = the ally) rise together, split and land on every living ally; heal,
## shield and cleanse events when they land. Visuals: STUB (default replay: the seeds fly as
## shells). To build: a green heal burst and a shield shimmer where they land.


func skill_id() -> String:
	return "healing_bloom"


func skill_name() -> String:
	return "Hoa hồi xuân"


func aim_mode() -> String:
	return AIM_NONE


func preview_offsets() -> Array:
	return []


func describe(rank: int) -> String:
	return "Hồi máu cả đội: Flora %d%%, đồng đội %d%% máu tối đa (+5%% mỗi cấp súng); máu dư thành khiên (tối đa 50%% máu); giải mọi hiệu ứng xấu." % [40 + 5 * rank, 30 + 5 * rank]
