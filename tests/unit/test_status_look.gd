extends "res://tests/test_case.gd"
## Status effects drawn on the body (StatusLook, StatusFx, PlayerView): every effect of the game
## data maps to a look, they stack back to front, pop in and out, a buff's aura takes its colour,
## an unknown bad effect a violet one; the fx scales with the body; no icons by the HP bars.

const StatusLook := preload("res://match/views/status_look.gd")
const StatusFx := preload("res://match/views/status_fx.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const GameData := preload("res://autoload/game_data_model.gd")


static func _fx(ids: Array, turns: int = 2) -> Array:
	return ids.map(func(id): return {"effectId": id, "durationTurn": turns})


func test_every_game_data_effect_has_a_look() -> void:
	var want := {"freeze": "ice", "burn": "flames", "net": "web", "root": "stone", "stun": "stars"}
	for id in GameData.status_ids():
		var look := StatusLook.look_of(id)
		check(StatusLook.ORDER.has(look), "%s has a look (%s)" % [id, look])
		if want.has(id):
			eq(look, want[id], "%s's look" % id)
		elif not GameData.status_bad(id):
			eq(look, "aura", "%s, a good effect: an aura" % id)


func test_stone_root() -> void:
	eq(StatusLook.look_of("root"), "stone", "root is earth and stone at the feet")
	check(StatusLook.ORDER.has("vines"), "the vines look is kept (a future wood boss)")
	check(StatusLook.pop_out_sec("stone") > StatusLook.POP_OUT, "it takes its time crumbling")
	eq(StatusFx.stone_rise(0.0, false), 0.0, "rises from the ground")
	eq(StatusFx.stone_rise(1.0, false), 1.0, "risen")
	check(StatusFx.stone_rise(0.5, false) > 0.5, "eased out")
	eq(StatusFx.stone_rise(0.1, true), 0.0, "crumbled down at the end of its pop out")


func test_looks_stack_back_to_front() -> void:
	var looks := StatusLook.looks_of(_fx(["stun", "freeze", "root", "power_shot", "net", "burn"]))
	eq(looks.keys(), ["aura", "stone", "flames", "web", "ice", "stars"], "ORDER, each once")
	eq(StatusLook.looks_of(_fx(["burn", "burn"])).keys(), ["flames"], "the same effect twice: one look")
	eq(StatusLook.looks_of([{"effectId": "stun", "durationTurn": 0}]), {}, "an expired effect: nothing")
	eq(StatusLook.looks_of(null), {}, "null")


func test_aura_colours() -> void:
	var a: Color = StatusLook.looks_of(_fx(["power_shot"]))["aura"]
	eq(a, StatusLook.AURA_COLORS["power_shot"], "power shot's warm orange")
	var mixed: Color = StatusLook.looks_of(_fx(["power_shot", "freeze_bomb"]))["aura"]
	var avg: Color = (StatusLook.AURA_COLORS["power_shot"] + StatusLook.AURA_COLORS["freeze_bomb"]) / 2.0
	check(mixed.is_equal_approx(avg), "two buffs: their colours mixed (%s)" % mixed)
	var d: Dictionary = GameData.data.duplicate(true)
	d["version"] = "edited"
	d["statusEffects"].append({"effectId": "curse", "name": "Nguyền", "marker": "", "banner": "", "bad": true,
		"skipsTurn": false, "blocksMove": false})
	d["statusEffects"].append({"effectId": "haste", "name": "Nhanh", "marker": "", "banner": "", "bad": false,
		"skipsTurn": false, "blocksMove": false})
	GameData.take(d, "", false)
	eq(StatusLook.looks_of(_fx(["curse"]))["aura"], StatusLook.CURSE, "a new bad effect: the violet aura")
	eq(StatusLook.looks_of(_fx(["haste"]))["aura"], StatusLook.DEFAULT_AURA, "a new good one: the default gold")


func test_pop_in_and_out() -> void:
	var l := StatusLook.new()
	check(l.is_empty() and not l.animating(), "nothing")
	l.set_effects(_fx(["freeze"]))
	check(l.has("ice") and not l.shown("ice") and l.animating(), "popping in")
	var first: Dictionary = l.layers()[0]
	near(first["k"], 0.0, 1e-6, "from nothing")
	l.step(StatusLook.POP_IN * 0.5)
	var mid: Dictionary = l.layers()[0]
	check(mid["scale"] > 0.4 and mid["alpha"] > 0.9, "half way: growing, already opaque (%s)" % mid)
	l.step(StatusLook.POP_IN)
	check(l.shown("ice") and not l.animating(), "shown")
	near(l.layers()[0]["scale"], 1.0, 1e-6, "at full size")
	l.set_effects(_fx(["freeze", "burn"]))
	eq(l.looks(), ["flames", "ice"], "a second effect stacks under the ice")
	check(l.shown("ice") and not l.shown("flames"), "the ice stays, the flames pop in")
	l.step(1.0)
	l.set_effects(_fx(["burn"]))
	check(l.has("ice") and l.layers()[1]["popping_out"], "the freeze ended: the ice pops out")
	l.step(StatusLook.pop_out_sec("ice") * 0.5)
	var out: Dictionary = l.layers()[1]
	check(out["scale"] > 1.0 and out["alpha"] < 1.0, "swelling as it fades (%s)" % out)
	check(l.has("ice"), "the ice still cracking and shedding (%s s)" % StatusLook.pop_out_sec("ice"))
	l.step(StatusLook.pop_out_sec("ice") * 0.6)
	eq(l.looks(), ["flames"], "gone")
	l.set_effects(_fx(["burn"]))
	l.step(0.01)
	check(l.shown("flames"), "the same effects again: nothing pops")
	l.clear()
	l.step(StatusLook.POP_OUT * 1.1)
	check(l.is_empty(), "cleared (death): all popped out")


func test_back_in_while_popping_out() -> void:
	var l := StatusLook.new()
	l.set_effects(_fx(["stun"]))
	l.step(1.0)
	l.set_effects([])
	l.step(StatusLook.POP_OUT * 0.5)
	l.set_effects(_fx(["stun"])) # stunned again before the stars were gone
	check(l.has("stars") and not l.layers()[0]["popping_out"], "back in from where it was")
	check(float(l.layers()[0]["k"]) > 0.3, "not from nothing")


func test_pop_curves() -> void:
	near(StatusLook.pop_scale(0.0, false), 0.4, 1e-6, "starts small")
	near(StatusLook.pop_scale(1.0, false), 1.0, 1e-6, "ends at full size")
	var peak := 0.0
	for i in 21:
		peak = maxf(peak, StatusLook.pop_scale(i / 20.0, false))
	check(peak > 1.02 and peak < 1.2, "overshoots a little (%f)" % peak)
	near(StatusLook.pop_scale(0.0, true), 1.18, 1e-6, "out: swells")
	near(StatusLook.pop_alpha(0.0, true), 0.0, 1e-6, "out: faded")


func _view(p: Dictionary) -> Node2D:
	var holder := Node2D.new()
	var v: Node2D = PlayerView.new()
	holder.add_child(v)
	var base := {"playerId": "p", "teamId": 1, "characterId": "rookie", "hp": 1000, "maxHp": 1500, "isAlive": true,
		"position": {"x": 0.0, "y": 0.0}}
	base.merge(p, true)
	v.setup(base, false, 1)
	if v.figure().has_method("_ready"):
		v.figure()._ready() # the character, not in the tree
	return v


func test_player_view_draws_on_the_body() -> void:
	var v := _view({"statusEffects": _fx(["root", "stun"]), "shield": 200})
	eq(v.status_looks(), ["stone", "stars"], "the effects on the body")
	check(not v.has_method("status_icons"), "no icons by the HP bar")
	var fx: StatusFx = v.status_fx()
	check(fx.visible and fx.back != null and fx.back.visible, "drawn, front and back")
	check(fx.show_behind_parent, "under the HP bar")
	check(fx.height > 45.0 and fx.height < 75.0, "a player's figure height (%f)" % fx.height)
	v.set_status(_fx(["root"]))
	for i in 10:
		fx.look.step(0.05)
	eq(v.status_looks(), ["stone"], "the stun ended: its stars gone")
	v.set_dead()
	for i in 12:
		fx.look.step(0.05) # the earth crumbles away over StatusLook.pop_out_sec("stone")
	eq(v.status_looks(), [], "dead: nothing on the body")
	v.set_status(_fx(["burn"]))
	eq(v.status_looks(), [], "nothing comes back on a dead body")
	v.get_parent().free()


func test_scales_with_the_body() -> void:
	var player := _view({"statusEffects": _fx(["freeze"])})
	var boss := _view({"playerId": "b", "teamId": 2, "role": "boss", "bossId": "lava_crab", "bodySize": 3.0,
		"statusEffects": _fx(["freeze"])})
	var minion := _view({"playerId": "m", "teamId": 2, "role": "minion", "bossId": "lava_crab", "minionId": "crab",
		"bodySize": 1.4, "statusEffects": _fx(["net"])})
	var pf: StatusFx = player.status_fx()
	var bf: StatusFx = boss.status_fx()
	var mf: StatusFx = minion.status_fx()
	check(bf.height > pf.height * 2.5, "the boss's looks are its size (%f vs %f)" % [bf.height, pf.height])
	check(bf.width > bf.height, "as wide as the crab's body (%f × %f)" % [bf.width, bf.height])
	check(mf.height > pf.height and mf.height < bf.height, "a minion's in between")
	eq(boss.status_looks(), ["ice"], "the boss frozen")
	eq(minion.status_looks(), ["web"], "a minion netted")
	for v in [player, boss, minion]:
		v.get_parent().free()


func test_ice_crystal_cluster() -> void:
	var fx: StatusFx = StatusFx.new()
	fx.height = 53.0
	fx.width = 32.0
	var cl: Array = fx._ice_cluster()
	var cores := cl.filter(func(c): return c["core"])
	var back := cl.filter(func(c): return not c["front"])
	var fore := cl.filter(func(c): return c["front"] and not c["core"])
	eq(cores.size(), 1, "a player: one core crystal over the body")
	check(back.size() >= 2 and fore.size() >= 2 and back.size() + fore.size() <= 6, "4-6 smaller ones, behind and in front (%d / %d)" % [back.size(), fore.size()])
	check(float(cores[0]["face"]) >= 0.35 and float(cores[0]["face"]) <= 0.5, "the core see-through (%f)" % cores[0]["face"])
	check(float(cores[0]["hw"]) * 2.0 > fx.width, "the core covers the body")
	eq(cl.find(cores[0]), back.size(), "drawn after the back ones, before the front ones")
	fx.height = 174.0 # the lava crab: wide and low
	fx.width = 250.0
	cl = fx._ice_cluster()
	cores = cl.filter(func(c): return c["core"])
	eq(cores.size(), 2, "a wide boss: two cores side by side, not one squat block")
	for c in cl:
		check(float(c["len"]) <= fx.height * 1.2, "every crystal within the body's height (%f)" % c["len"])
	near(StatusFx._grow(0.0), 0.0, 1e-6, "grows from nothing")
	near(StatusFx._grow(1.0), 1.0, 1e-6, "to its size")
	var peak := 0.0
	for i in 21:
		peak = maxf(peak, StatusFx._grow(i / 20.0))
	check(peak > 1.03 and peak < 1.2, "a slight overshoot (%f)" % peak)
	check(StatusLook.pop_out_sec("ice") > StatusLook.POP_OUT, "the ice takes longer to leave: it cracks and sheds")
	near(StatusLook.pop_out_sec("stars"), StatusLook.POP_OUT, 1e-6, "the others as before")
	fx.free()
