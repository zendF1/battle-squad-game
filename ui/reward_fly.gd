extends Control
## What a purchase gives arrives at once (a purchase is not a reward: no gift box, no "Nhận"):
## RewardFly.play(host, tiles, from) pops each bought thing's icon over its glow with "×N"
## (ui/reward_strip.gd mini_tile, RewardModel tiles) where the buy happened (`from`, a canvas
## position; dead centre without it), holds it a moment, then flies it to where it lands — the
## coin / gem pill for coins and gems, the bag button for the rest (target_for(), also the reward
## reveal's collect) — and fades. It never takes input and never blocks the screen; the wallet and
## the bag are already updated when it starts.

const RewardStrip := preload("res://ui/reward_strip.gd")
const RewardModel := preload("res://ui/reward_model.gd")

const ICON_PX := 72
const FONT := 30
const POP_SEC := 0.22
const HOLD_SEC := 0.45
const FLY_SEC := 0.55
const STAGGER := 0.08 # s between two tiles of one purchase
const SPREAD := 26.0 # px between two tiles' start points


## Plays the arrival of `tiles` (RewardModel tiles, merged here) over `host`, starting at the canvas
## position `from` (null: the host's centre). Returns the layer (it frees itself when done).
static func play(host: Control, tiles: Array, from: Variant = null) -> Control:
	var layer = load("res://ui/reward_fly.gd").new()
	layer.name = "RewardFly"
	layer.mouse_filter = MOUSE_FILTER_IGNORE
	host.add_child(layer)
	layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layer._start(RewardModel.merge(tiles), from)
	return layer


func _start(tiles: Array, from: Variant) -> void:
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var start: Vector2 = to_local * (from as Vector2) if from is Vector2 else size / 2.0
	if size == Vector2.ZERO and not from is Vector2:
		start = get_parent().size / 2.0 if get_parent() is Control else Vector2.ZERO
	var last := 0.0
	for i in tiles.size():
		var t: Dictionary = tiles[i]
		var node := RewardStrip.mini_tile(t, ICON_PX, FONT)
		node.name = "Tile%d" % i
		node.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(node)
		node.reset_size()
		var half := node.get_combined_minimum_size() / 2.0
		var at := start + Vector2((i - (tiles.size() - 1) / 2.0) * (half.x * 2.0 + SPREAD), 0)
		node.position = at - half
		node.pivot_offset = half
		node.scale = Vector2.ONE * 0.3
		node.modulate.a = 0.0
		var target: Vector2 = to_local * target_for(self, t) - half
		var d := i * STAGGER
		var tw := node.create_tween()
		tw.tween_interval(d)
		tw.tween_property(node, "modulate:a", 1.0, POP_SEC * 0.6)
		tw.parallel().tween_property(node, "scale", Vector2.ONE * 1.15, POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", Vector2.ONE, 0.12)
		tw.tween_interval(HOLD_SEC)
		tw.tween_property(node, "position", target, FLY_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(node, "scale", Vector2.ONE * 0.35, FLY_SEC)
		tw.parallel().tween_property(node, "modulate:a", 0.0, 0.2).set_delay(FLY_SEC - 0.2)
		last = maxf(last, d + POP_SEC + 0.12 + HOLD_SEC + FLY_SEC)
	var end := create_tween()
	end.tween_interval(last + 0.05)
	end.tween_callback(queue_free)


## How long play() runs for `count` tiles (s).
static func duration(count: int) -> float:
	return maxi(count - 1, 0) * STAGGER + POP_SEC + 0.12 + HOLD_SEC + FLY_SEC


## Where a reward or a bought thing lands (canvas position): the "CoinPill" / "GemPill" on screen
## for coins and gems, the "BagButton" for the rest, else the top-right corner of `from_node`.
static func target_for(from_node: Control, t: Dictionary) -> Vector2:
	var kind := str(t.get("kind", ""))
	var names := ["CoinPill"] if kind == "coin" else (["GemPill"] if kind == "gem" else ["BagButton"])
	var root: Node = from_node.get_parent()
	while root != null and root.get_parent() != null and root.get_parent() is Control:
		root = root.get_parent()
	for n in names:
		var found := visible_named(root, n)
		if found != null:
			return found.get_global_transform_with_canvas() * (found.size / 2.0)
	return from_node.get_global_transform_with_canvas() * Vector2(from_node.size.x - 90.0, 60.0)


static func visible_named(root: Node, node_name: String) -> Control:
	if root == null:
		return null
	for n in root.find_children(node_name, "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() if c.is_inside_tree() else c.visible:
			return c
	return null
