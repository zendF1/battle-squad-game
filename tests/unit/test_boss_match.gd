extends "res://tests/test_case.gd"
## The boss side of a match without a scene: the art mapping, body sizes, the boss skill views,
## the 4 + 0 matchmaking slots, and match/boss/boss_body.gd's hit flash, shield and death fade.

const BossFixture := preload("res://tests/boss_fixture.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossBody := preload("res://match/boss/boss_body.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const Skills := preload("res://match/skills.gd")
const MatchmakingModel := preload("res://screens/ranked/matchmaking_model.gd")
const AimAid := preload("res://match/aim/aim_aid.gd")


func test_art_by_id() -> void:
	eq(BossArt.art_of("steel_robot"), "steel_robot", "a boss")
	eq(BossArt.art_of("new_boss"), BossArt.GENERIC_BOSS, "an unknown boss")
	eq(BossArt.art_of("", "snowman"), "snowman", "a minion")
	eq(BossArt.art_of_player({"role": "minion", "minionId": "crab", "characterId": "tanko"}), "crab", "drawn by minionId")
	eq(BossArt.art_of_player({"role": "boss", "bossId": "ice_witch"}), "ice_witch", "the boss")
	eq(BossArt.art_of_player({"characterId": "rookie"}), "", "a player")


func test_body_sizes() -> void:
	BossFixture.take()
	eq(PlayerView.body_size_of({"role": "boss", "bossId": "steel_robot", "bodySize": 3}), 3.0, "the state's")
	eq(PlayerView.body_size_of({"role": "boss", "bossId": "lava_crab"}), 3.2, "else the game data's")
	eq(PlayerView.body_size_of({"role": "minion", "bossId": "ice_witch", "minionId": "snowman"}), 0.85, "a minion's")
	eq(PlayerView.body_size_of({"characterId": "rookie"}), 1.0, "a player")


func test_boss_skill_views() -> void:
	BossFixture.take()
	var rain = Skills.view_for_skill("shell_barrage")
	check(rain.get_script().resource_path.ends_with("boss_rain.gd"), "rain kind: the boss rain")
	eq(rain.skill_name(), "Mưa đạn pháo", "its name")
	check(Skills.view_for_skill("frost_beam").get_script().resource_path.ends_with("boss_beam.gd"), "beam kind")
	check(Skills.view_for_skill("frost_beam").param("sweepSpeed") > 0.0, "the laser's tuning")
	check(Skills.view_for_skill("claw_slam").get_script().resource_path.ends_with("skill_view.gd"), "shockwave: the base view (match_screen draws the wave)")
	eq(Skills.view_for_skill("claw_slam").skill_name(), "Cú kẹp đập", "named")
	check(not Skills.view_for_skill("triple_shot").get_script().resource_path.ends_with("boss_rain.gd"), "a character skill keeps its view")


func test_boss_matchmaking_slots() -> void:
	var teams := {1: [{"playerId": "p2"}, {"playerId": "me"}, {"playerId": "bot_1"}], 2: [{"playerId": "boss_x"}, {"playerId": "minion_a_1"}]}
	var slots := MatchmakingModel.slots(teams, "me", 4, 0)
	eq(slots.map(func(p): return p.get("playerId", "")), ["me", "p2", "bot_1", ""], "the party of four, me first, the boss apart")
	eq(MatchmakingModel.slots(teams, "me").size(), 4, "2v2: two and two")


func test_big_hit_radius() -> void:
	var near := PackedFloat32Array()
	var enemies := PackedVector2Array([Vector2(300, 0)])
	var miss := AimAid.fly(Vector2(0, -60), Vector2(400, 0), 0.0, null, enemies, near)
	var hit := AimAid.fly(Vector2(0, -60), Vector2(400, 0), 0.0, null, enemies, near, 0.0, -10000.0, PackedFloat32Array([72.0]))
	eq(hit["hit"], 0, "a boss's body (72 px) is hit")
	check(miss["hit"] != 0 or float(miss["end"].x) > 300.0, "a player's (24 px) is not there")


func test_body_flash_shield_death() -> void:
	var b := BossBody.new()
	b.setup("steel_robot", 156.0)
	eq(b.art_height(), 156.0, "its height")
	b.hurt()
	check(b.is_flashing(), "a hit flashes")
	b._process(BossBody.FLASH_SEC + 0.01)
	check(not b.is_flashing(), "then fades")
	b.set_shielded(true, false)
	eq(b.shield_shown(), 1.0, "a snapshot's shield at once")
	b.set_shielded(false)
	b._process(BossBody.SHIELD_SEC + 0.01)
	eq(b.shield_shown(), 0.0, "the shield drops")
	b.die()
	b._process(BossBody.DEATH_SEC / 2.0)
	check(b.death_progress() > 0.4 and b.modulate.a < 0.6, "fading out")
	b._process(BossBody.DEATH_SEC)
	eq(b.modulate.a, 0.0, "gone")
	check(b.shoot() == 0.0, "no gun to draw")
	b.free()
