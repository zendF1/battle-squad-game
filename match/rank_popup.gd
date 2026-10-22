extends "res://match/result_popup.gd"
## The rank change over the result screen (match/result_screen.gd opens it after the level up,
## when RankModel.popup_of() has one): it opens on the old rank (the tier badge, "Vàng II", the
## rating) and counts the rating to the new one, then walks the popup's steps, one rank each:
## - a division inside a tier: the old badge slides out left, the next slides in with a pop, a
##   ring and sparks in the tier's colours, the rank's name ticks over;
## - into a higher tier: the badge charges up shaking, shatters (shards, a white flash), light,
##   rays, sparks and two shockwaves in the new tier's colours, the new badge slams in big and
##   settles (the screen shakes), "THĂNG HẠNG!" slams over it with the new rank's name; the top
##   tier (crown) adds a gold flash and confetti over everything;
## - down (a demotion): the badge sinks and greys, the lower one rises dimmed; no fireworks.
## The tier colours are the badge's (screens/ranked/tier_badge.gd). setup(popup) before it
## enters the tree.

const TierBadge := preload("res://screens/ranked/tier_badge.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const Fmt := preload("res://core/fmt.gd")

const BADGE := 250.0
const BADGE_TIER := 290.0 # the badge of a new tier
const UP_GREEN := Color(0.55, 1.0, 0.6)
const DOWN_RED := Color(1.0, 0.5, 0.45)
const DOWN_TITLE := Color(0.62, 0.72, 0.9)

var popup := {}
var _title: Label
var _caption: Label
var _badge: Control
var _name: Label
var _rating: Label
var _change: Label
var _crown_line: Label
var _rays_on: Dictionary = {}
var _badge_px := BADGE


func setup(value: Dictionary) -> void:
	popup = value


func _up() -> bool:
	return int(popup["move"]) == RankModel.UP


func _tier_up() -> bool:
	return popup["kind"] == "tier"


func _colors(tier: String) -> Array:
	return TierBadge.COLORS.get(tier, TierBadge.COLORS[""])


func build() -> void:
	var grand := _tier_up()
	_title = label(str(popup["title"]), 120 if grand else (92 if _up() else 80), GOLD if _up() else DOWN_TITLE, 24 if grand else 18)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_title.add_theme_constant_override("shadow_offset_y", 8)
	_title.modulate.a = 0.0
	stage.add_child(_title)
	_caption = label("XẾP HẠNG", 30, Color(0.75, 0.85, 1.0), 6)
	stage.add_child(_caption)
	var old: Array = popup["old_rank"]
	_badge = TierBadge.make(str(old[0]), int(old[1]), BADGE)
	stage.add_child(_badge)
	_name = label(RankModel.label(str(old[0]), int(old[1])), 54, _colors(str(old[0]))[0], 12)
	stage.add_child(_name)
	_rating = label(RankModel.points_text(int(popup["old"])), 34, Color.WHITE, 8)
	stage.add_child(_rating)
	_change = label(RankModel.change_text(int(popup["change"])), 34, UP_GREEN if int(popup["change"]) >= 0 else DOWN_RED, 8)
	_change.modulate.a = 0.0
	stage.add_child(_change)
	_crown_line = label("Bạn đã chạm tới đỉnh cao danh vọng!", 32, TierBadge.CROWN[0], 8)
	_crown_line.modulate.a = 0.0
	stage.add_child(_crown_line)


func _badge_centre() -> Vector2:
	return center() + Vector2(0, -30)


func layout() -> void:
	var c := center()
	place(_title, c.x, c.y - 290, size.x, 150)
	place(_caption, c.x, c.y - 232, 600, 44)
	_place_badge(_badge, _badge_px)
	place(_name, c.x, c.y + 150, 800, 70)
	place(_rating, c.x - 50, c.y + 205, 300, 46)
	place(_change, c.x + 110, c.y + 205, 160, 46)
	place(_crown_line, c.x, c.y + 252, 900, 46)
	if not _rays_on.is_empty():
		_rays_on["at"] = _badge_centre()


func _place_badge(b: Control, px: float, dx: float = 0.0) -> void:
	b.custom_minimum_size = Vector2(px, px)
	b.size = Vector2(px, px)
	b.position = _badge_centre() - b.size / 2.0 + Vector2(dx, 0)
	b.pivot_offset = b.size / 2.0


func play() -> void:
	var c := _badge_centre()
	pop(_badge, 0.3, 0.36)
	glow(c, _colors(str(popup["old_rank"][0]))[1], BADGE, 0.7)
	seq.tween_interval(0.45)
	seq.tween_method(func(v: float) -> void: _rating.text = RankModel.points_text(roundi(v)),
		float(popup["old"]), float(popup["new"]), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	seq.tween_callback(func() -> void:
		_change.modulate.a = 1.0
		pop(_change, 0.4, 0.3))
	seq.tween_interval(0.35)
	var prev: Array = popup["old_rank"]
	for step in popup["steps"]:
		if not _up():
			_down(step)
		elif str(step[0]) != str(prev[0]):
			_tier(step, prev)
		else:
			_division(step)
		prev = step
	seq.tween_callback(_ending)
	seq.tween_interval(0.5)
	seq.tween_callback(done_playing)


## The next division of the same tier: out left, in from the right with a pop.
func _division(step: Array) -> void:
	seq.tween_callback(func() -> void:
		var old := _badge
		var t := old.create_tween()
		t.tween_property(old, "position:x", old.position.x - 260.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(old, "modulate:a", 0.0, 0.24)
		t.tween_callback(old.queue_free)
		_badge = TierBadge.make(str(step[0]), int(step[1]), _badge_px)
		stage.add_child(_badge)
		_place_badge(_badge, _badge_px, 260.0)
		_badge.modulate.a = 0.0
		var n := _badge.create_tween()
		n.tween_property(_badge, "position:x", _badge.position.x - 260.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		n.parallel().tween_property(_badge, "modulate:a", 1.0, 0.16)
		n.tween_callback(func() -> void:
			var cs := _colors(str(step[0]))
			pop(_badge, 1.25, 0.24)
			ring(_badge_centre(), cs[0], _badge_px * 0.45, _badge_px * 0.95, 0.5, 7.0)
			burst(_badge_centre(), cs + [Color.WHITE], 18, 380.0, 10.0)
			_set_name(step, true)))
	seq.tween_interval(0.75)


## Into a higher tier: charge, shatter, light and rays, the new badge slams in.
func _tier(step: Array, prev: Array) -> void:
	var old_c := _colors(str(prev[0]))
	var cs := _colors(str(step[0]))
	var c := _badge_centre()
	_on_badge(0.36, func(b: Control) -> void: # the charge: shaking, swelling
		glow(c, old_c[0], BADGE * 1.3, 0.7)
		var t := b.create_tween()
		for i in 6:
			t.tween_property(b, "rotation", 0.08 if i % 2 == 0 else -0.08, 0.06)
			t.parallel().tween_property(b, "scale", Vector2.ONE * (1.0 + 0.03 * (i + 1)), 0.06))
	seq.tween_callback(func() -> void:
		_badge.visible = false
		shards(c, old_c + [Color.WHITE], _badge_px, 18)
		flash(Color(1, 1, 1, 0.85), 0.4)
		glow(c, cs[0], BADGE * 2.2, 0.9)
		burst(c, cs + [Color.WHITE, GOLD], 60, 760.0, 13.0)
		ring(c, cs[0], 40.0, maxf(size.x, size.y) * 0.6, 0.7, 14.0)
		ring(c, Color.WHITE, 30.0, maxf(size.x, size.y) * 0.4, 0.55, 8.0)
		_rays_on = rays(c, [cs[0], cs[1]], size.y * 0.95, 0.34, 22)
		var old := _badge
		_badge_px = BADGE_TIER
		_badge = TierBadge.make(str(step[0]), int(step[1]), _badge_px)
		stage.add_child(_badge)
		_place_badge(_badge, _badge_px)
		old.queue_free()
		_badge.scale = Vector2.ONE * 2.8
		_badge.modulate.a = 0.0)
	seq.tween_interval(0.28)
	_on_badge(0.2, func(b: Control) -> void:
		b.modulate.a = 1.0
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE * 0.88, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN))
	seq.tween_callback(func() -> void: # the slam
		shake(0.35)
		ring(c, cs[0].lightened(0.3), BADGE_TIER * 0.4, BADGE_TIER * 1.4, 0.5, 12.0)
		burst(c, cs + [Color.WHITE], 30, 520.0, 11.0)
		_set_name(step, true)
		_show_title(2.4)
		if popup["crown"] and str(step[0]) == str(popup["new_rank"][0]):
			_crown())
	_on_badge(0.8, func(b: Control) -> void:
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE * 1.08, 0.12).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE))


## Runs `make(badge)` (it starts its own tween on it) on the badge shown at that moment (steps
## replace it), then waits `sec`.
func _on_badge(sec: float, make: Callable) -> void:
	seq.tween_callback(func() -> void: make.call(_badge))
	seq.tween_interval(sec)


## The top tier: a gold flash, gold rays and confetti over everything.
func _crown() -> void:
	flash(Color(1.0, 0.85, 0.3, 0.7), 0.5)
	var gold := rays(_badge_centre(), [TierBadge.CROWN[0], TierBadge.CROWN[1]], size.y * 0.95, 0.26, 12)
	gold["spin"] = -0.18
	shower(_colors(str(popup["new_rank"][0])) + [TierBadge.CROWN[0], TierBadge.CROWN[1], Color.WHITE], 110)
	burst(_badge_centre() + Vector2(0, -_badge_px * 0.42), [TierBadge.CROWN[0], Color.WHITE], 28, 460.0, 12.0)
	_crown_line.modulate.a = 1.0
	pop(_crown_line, 0.4, 0.3)


## Down one rank: the badge sinks and greys, the lower one rises dimmed.
func _down(step: Array) -> void:
	_on_badge(0.5, func(b: Control) -> void:
		var t := b.create_tween()
		t.tween_property(b, "position:y", b.position.y + 50.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(b, "modulate", Color(0.45, 0.47, 0.55, 0.0), 0.5))
	seq.tween_callback(func() -> void:
		var old := _badge
		_badge = TierBadge.make(str(step[0]), int(step[1]), _badge_px)
		stage.add_child(_badge)
		_place_badge(_badge, _badge_px)
		old.queue_free()
		_badge.position.y += 30.0
		_badge.modulate = Color(0.6, 0.62, 0.7, 0.0)
		var t := _badge.create_tween()
		t.tween_property(_badge, "position:y", _badge.position.y - 30.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_badge, "modulate", Color(0.72, 0.74, 0.82, 1.0), 0.5)
		_set_name(step, false))
	seq.tween_interval(0.6)


func _set_name(rank: Array, lit: bool) -> void:
	_name.text = RankModel.label(str(rank[0]), int(rank[1]))
	_name.add_theme_color_override("font_color", _colors(str(rank[0]))[0] if lit else Color(0.75, 0.78, 0.86))
	if lit:
		pop(_name, 1.5, 0.3)


## After the last step: the title (when no tier slam showed it) and faint rays for a division up.
func _ending() -> void:
	if _title.modulate.a < 1.0:
		_show_title(1.8 if _up() else 0.7)
	if _up() and _rays_on.is_empty():
		_rays_on = rays(_badge_centre(), [_colors(str(popup["new_rank"][0]))[0], Color.WHITE], size.y * 0.8, 0.18, 18)


## The title pops in over the badge, "XẾP HẠNG" gives it its place.
func _show_title(from: float) -> void:
	_title.modulate.a = 1.0
	pop(_title, from, 0.42 if from > 2.0 else 0.36)
	create_tween().tween_property(_caption, "modulate:a", 0.0, 0.15)


func show_end() -> void:
	var nr: Array = popup["new_rank"]
	var keep := _badge
	_badge_px = BADGE_TIER if _tier_up() else BADGE
	_badge = TierBadge.make(str(nr[0]), int(nr[1]), _badge_px)
	stage.add_child(_badge)
	_place_badge(_badge, _badge_px)
	if not _up():
		_badge.modulate = Color(0.72, 0.74, 0.82, 1.0)
	for c in stage.get_children(): # the badges still sliding
		if c is TierBadge and c != _badge:
			c.queue_free()
	if is_instance_valid(keep) and keep != _badge:
		keep.queue_free()
	_set_name(nr, _up())
	_name.scale = Vector2.ONE
	_rating.text = RankModel.points_text(int(popup["new"]))
	_change.modulate.a = 1.0
	_change.scale = Vector2.ONE
	_title.modulate.a = 1.0
	_title.scale = Vector2.ONE
	_caption.modulate.a = 0.0
	if popup["crown"]:
		_crown_line.modulate.a = 1.0
		_crown_line.scale = Vector2.ONE
	if _up() and _rays_on.is_empty():
		var cs := _colors(str(nr[0]))
		_rays_on = rays(_badge_centre(), [cs[0], cs[1]] if _tier_up() else [cs[0], Color.WHITE], size.y * (0.95 if _tier_up() else 0.8),
			0.34 if _tier_up() else 0.18, 22 if _tier_up() else 18)
