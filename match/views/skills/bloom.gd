extends "res://match/views/skills/skill_view.gd"
## Flora — Hoa hồi xuân (server skill healing_bloom, effect bloom): no aim. The seeds (projectile
## kind "seed", hitPlayerId = the ally; the gun's own per-tier shell, ShotPlayer styles it) rise
## together out of the top of the screen, split up there and fall straight onto every living ally
## (Flora too); heal, shield and cleanse events when they land. Drawn by one BloomFx (bloom_fx.gd)
## on the fx layer: the burst where the seeds leave the screen, a light shaft over each ally while
## its seed falls, the bloom where it lands, the shield bubble when the heal overflows, the
## cleanse sparkle. Each seed carries a soft green glow (SeedGlow). The numbers ("+N" green,
## "+N khiên" light blue) are match_screen's popups.

const BloomFx := preload("res://match/views/skills/bloom_fx.gd")

const SCAN_STEP := 0.02 # s: how finely begin() reads the seeds' paths
const OFF_SCREEN := -30.0 # px: a seed above this y is out of view (the screen starts at y 0)
const FALL_LEAD := 0.25 # s the shaft shows before the seed comes into view
const OLD_FALL := 0.5 # s: the shaft of a seed that never leaves the screen (older server)

var fx: Node2D = null # the BloomFx, null before begin()
var _last_land := 0.0


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


func begin(context: Dictionary) -> void:
	super(context)
	fx = BloomFx.new()
	var layer = ctx.get("layer")
	if layer is Node:
		layer.add_child(fx)
	var tl = ctx.get("timeline")
	var views: Dictionary = ctx.get("views", {})
	if tl == null:
		return
	var exited := false
	for i in tl.projectiles.size():
		if tl.kind(i) != "seed":
			continue
		var land: float = tl.projectile_end(i)
		_last_land = maxf(_last_land, land)
		var plan := seed_plan(tl, i)
		if not exited and plan["exit"] >= 0.0:
			exited = true
			fx.exit(tl.sample(i, plan["exit"]).x, plan["exit"])
		var view = views.get(str(tl.projectiles[i].get("hitPlayerId", "")))
		if view != null:
			fx.shaft(view, plan["shaft"], land)


## When seed i leaves the top of the screen ("exit", -1 when it never does) and when its light
## shaft shows ("shaft": FALL_LEAD before it comes back into view above its ally).
static func seed_plan(tl, i: int) -> Dictionary:
	var land: float = tl.projectile_end(i)
	var t0: float = tl.launch_time(i)
	var exit := -1.0
	var back := -1.0
	var t := t0
	while t < land:
		var off: bool = tl.sample(i, t).y < OFF_SCREEN
		if off and exit < 0.0:
			exit = t
		elif not off and exit >= 0.0:
			back = t
			break
		t += SCAN_STEP
	var shaft := maxf(t0, back - FALL_LEAD) if back >= 0.0 else maxf(t0, land - OLD_FALL)
	return {"exit": exit, "shaft": shaft}


## The seed keeps the gun's shell and gains a soft green glow behind it.
func projectile_view(_i: int, projectile: Dictionary, view: Node2D) -> Node2D:
	if str(projectile.get("kind", "")) == "seed":
		view.add_child(SeedGlow.new())
	return view


func on_event(event: Dictionary) -> void:
	if fx == null or not is_instance_valid(fx):
		return
	var view = ctx.get("views", {}).get(str(event.get("playerId", "")))
	if view == null:
		return
	var at := float(event.get("t", 0.0))
	match str(event.get("type", "")):
		"heal":
			fx.bloom(view, at)
		"shield":
			if int(event.get("amount", 0)) > 0:
				fx.shield(view, at)
		"cleanse":
			fx.cleanse(view, at)


func process(t: float) -> void:
	if fx != null and is_instance_valid(fx):
		fx.sync(t)


## The blooms play on after the replay; a replay dropped before the seeds landed takes them away.
func end() -> void:
	if fx != null and is_instance_valid(fx) and fx.t < _last_land:
		fx.queue_free()
	fx = null


## A soft green glow pulsing behind a flying seed (additive).
class SeedGlow extends Node2D:
	const Art := preload("res://ui/art.gd")
	var _t := 0.0
	var _tex: Texture2D

	func _ready() -> void:
		show_behind_parent = true
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		_tex = Art.tier_fx("glow")

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var size := 64.0 + 8.0 * sin(_t * 14.0)
		var col := Color(0.5, 1.0, 0.45, 0.55)
		if _tex != null:
			draw_texture_rect(_tex, Rect2(-Vector2(size, size) / 2.0, Vector2(size, size)), false, col)
		else:
			draw_circle(Vector2.ZERO, size * 0.3, col)
