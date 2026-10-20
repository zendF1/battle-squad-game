extends "res://match/views/skills/skill_view.gd"
## Rookie — Mưa tên lửa (server skill triple_shot, effect missile_rain): a flare fired like a
## normal shot; where it lands (event flare) missiles (projectile kind "missile") fall from the
## top of the map around it (event rain: position, radius, count); every enemy hit burns.
## Visuals (all from the server timeline, nothing simulated here):
## - the flare is the gun's own tier shell (ShotLook / ProjectileView) with a flickering red
##   signal light around it and a red smoke trail behind it;
## - where it lands: a red-white flash with sparks, the flare burning on the ground and a red
##   signal smoke column rising from it until the rain is over (then it drifts off and fades);
## - the missiles are the same tier shell, normal size (not the skill's larger one), nose-down
##   along their path with a shorter trail (ProjectileView.trail_length), each impact a smaller
##   burst than a normal shot (MISSILE_BURST, not the skill's bigger one);
## - burn (status) and the hits' numbers are the default replay's; the burn tick at the
##   target's next turn start is a BurnFx flash (match_screen, PlayerDamaged type burn).
## Cheap: one RainFx node draws the light, the smoke and the sparks from fixed pools (no
## per-frame allocation); it outlives the replay only to fade out.

const Art := preload("res://ui/art.gd")

const MISSILE_BURST := 0.8 # a missile's burst radius × this (and drawn like a normal shot)
const MISSILE_TRAIL := 0.4 # a missile keeps this share of its trail
const FLARE_TRAIL := 0.3 # the flare: its red smoke is the trail
const FLARE_RED := Color(1.0, 0.16, 0.12)

var _fx: RainFx = null
var _flare := -1 # the flare's projectile index, -1 none
var _missile_ids := {} # projectileId -> true


func skill_id() -> String:
	return "triple_shot"


func skill_name() -> String:
	return "Mưa tên lửa"


func describe(rank: int) -> String:
	return "Bắn pháo hiệu, %d tên lửa rơi quanh chỗ đáp (+2 mỗi cấp súng), mỗi quả 35%% sát thương; địch trúng bị bỏng: mất 10%% máu tối đa đầu lượt sau." % (6 + 2 * rank)


func begin(context: Dictionary) -> void:
	super.begin(context)
	_flare = -1
	_missile_ids.clear()
	var timeline = ctx.get("timeline")
	if timeline != null:
		for i in timeline.projectiles.size():
			match timeline.kind(i):
				"flare":
					if _flare < 0:
						_flare = i
				"missile":
					_missile_ids[str(timeline.projectiles[i].get("projectileId", ""))] = true
	var layer = ctx.get("layer")
	if layer is Node2D:
		_fx = RainFx.new()
		layer.add_child(_fx) # before the projectile views: the light and smoke stay behind the shells


## The view of projectile i: the flare keeps the gun's styled shell (RainFx adds its light and
## smoke), a missile is drawn at normal size with a short trail.
func projectile_view(_i: int, projectile: Dictionary, view: Node2D) -> Node2D:
	match str(projectile.get("kind", "")):
		"missile":
			view.skill = false
			if "trail_length" in view:
				view.trail_length = MISSILE_TRAIL
		"flare":
			if "trail_length" in view:
				view.trail_length = FLARE_TRAIL
	return view


## A missile's impact: smaller than a normal shot's.
func explosion(event: Dictionary, fx: Node2D) -> void:
	if is_missile(str(event.get("projectileId", ""))):
		fx.skill = false
		fx.radius *= MISSILE_BURST


func is_missile(projectile_id: String) -> bool:
	return _missile_ids.has(projectile_id)


func on_event(event: Dictionary) -> void:
	if _fx == null:
		return
	match str(event.get("type", "")):
		"flare":
			var p = event.get("position")
			if p is Dictionary:
				_fx.land(Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
		"rain":
			_fx.rain()


func process(t: float) -> void:
	if _fx == null or not is_instance_valid(_fx):
		return
	var timeline = ctx.get("timeline")
	if _flare >= 0 and timeline != null and t >= timeline.launch_time(_flare) and t < timeline.projectile_end(_flare):
		_fx.follow(timeline.sample(_flare, t))
	else:
		_fx.follow_none()


func end() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.fade_out()
	_fx = null


## What a rain replay is drawing now, for tests: {flying, landed, column, puffs, fading}.
func fx_state() -> Dictionary:
	return _fx.state() if _fx != null and is_instance_valid(_fx) else {}


## The flare's light and smoke trail, the landing flash and sparks, the signal smoke column.
## Particles live in fixed pools (ring buffers): the oldest is reused when one is full.
class RainFx extends Node2D:
	const POOL := 120 # smoke puffs (trail + column)
	const SPARKS := 14
	const TRAIL_EVERY := 6.0 # px of flight between two trail puffs
	const TRAIL_LIFE := 1.1
	const COLUMN_RATE := 26.0 # puffs / s
	const COLUMN_LIFE := 2.4
	const FLASH_SEC := 0.4
	const FADE_SEC := 1.6 # after the replay: the column stops, the rest fades
	const SPARK_LIFE := 0.6
	const GRAVITY := 520.0

	var _smoke_tex: Texture2D
	var _glow_tex: Texture2D
	var _rng := RandomNumberGenerator.new()
	var _t := 0.0
	# the flare in flight
	var _flying := false
	var _at := Vector2.ZERO
	var _last := Vector2.ZERO
	var _has_last := false
	var _since := 0.0
	# landed
	var _landed := false
	var _land := Vector2.ZERO
	var _land_t := 0.0
	var _column_acc := 0.0
	var _rain_t := -1.0
	var _fading := false
	var _fade_t := 0.0
	# smoke pool: position, velocity, age, life, size from / to, column (1) or trail (0)
	var _pos := PackedVector2Array()
	var _vel := PackedVector2Array()
	var _age := PackedFloat32Array()
	var _life := PackedFloat32Array()
	var _s0 := PackedFloat32Array()
	var _s1 := PackedFloat32Array()
	var _spin := PackedFloat32Array()
	var _column := PackedByteArray()
	var _next := 0
	# sparks
	var _sp_pos := PackedVector2Array()
	var _sp_vel := PackedVector2Array()
	var _sp_age := PackedFloat32Array()

	func _init() -> void: # the pools are ready before the node enters the tree
		texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_smoke_tex = Art.fx("smoke")
		_glow_tex = Art.tier_fx("glow")
		if _glow_tex == null:
			_glow_tex = Art.fx("muzzle")
		_rng.randomize()
		_pos.resize(POOL)
		_vel.resize(POOL)
		_age.resize(POOL)
		_life.resize(POOL)
		_s0.resize(POOL)
		_s1.resize(POOL)
		_spin.resize(POOL)
		_column.resize(POOL)
		_age.fill(1e6) # all dead
		_life.fill(1.0)
		_sp_pos.resize(SPARKS)
		_sp_vel.resize(SPARKS)
		_sp_age.resize(SPARKS)
		_sp_age.fill(1e6)

	## The flare is at p (layer coordinates) this frame.
	func follow(p: Vector2) -> void:
		_flying = true
		_at = p
		if not _has_last:
			_last = p
			_has_last = true

	func follow_none() -> void:
		_flying = false
		_has_last = false

	## The flare landed at p: flash, sparks, the column starts.
	func land(p: Vector2) -> void:
		_flying = false
		_has_last = false
		_landed = true
		_land = p
		_land_t = _t
		for i in SPARKS:
			var a := _rng.randf_range(-PI * 0.92, -PI * 0.08)
			_sp_pos[i] = p
			_sp_vel[i] = Vector2.from_angle(a) * _rng.randf_range(140.0, 320.0)
			_sp_age[i] = 0.0
		for i in 5: # a first burst of thick smoke at the spot
			_puff(p + Vector2(_rng.randf_range(-10, 10), -4), Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-50, -20)),
				COLUMN_LIFE * 0.8, 12.0, 34.0, true)

	## The missiles start falling.
	func rain() -> void:
		_rain_t = _t

	## The replay is over: stop the column, let everything fade, then free.
	func fade_out() -> void:
		if _fading:
			return
		_fading = true
		_fade_t = 0.0
		_flying = false

	func state() -> Dictionary:
		var alive := 0
		for i in POOL:
			if _age[i] < _life[i]:
				alive += 1
		return {"flying": _flying, "landed": _landed, "column": _landed and not _fading, "puffs": alive, "fading": _fading,
			"raining": _rain_t >= 0.0}

	func _puff(p: Vector2, v: Vector2, life: float, s0: float, s1: float, column: bool) -> void:
		var i := _next
		_next = (_next + 1) % POOL
		_pos[i] = p
		_vel[i] = v
		_age[i] = 0.0
		_life[i] = life
		_s0[i] = s0
		_s1[i] = s1
		_spin[i] = _rng.randf() * TAU
		_column[i] = 1 if column else 0

	func _process(delta: float) -> void:
		_t += delta
		if _fading:
			_fade_t += delta
			if _fade_t >= FADE_SEC + COLUMN_LIFE * 0.5:
				queue_free()
				return
		# the flare's trail: a puff every TRAIL_EVERY px it flew
		if _flying and _has_last:
			_since += _last.distance_to(_at)
			var steps := 0
			while _since >= TRAIL_EVERY and steps < 8:
				_since -= TRAIL_EVERY
				steps += 1
				var k := clampf(_since / maxf(_last.distance_to(_at), 0.001), 0.0, 1.0)
				_puff(_at.lerp(_last, k), Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-14, -4)), TRAIL_LIFE, 6.0, 19.0, false)
			_last = _at
		# the column: puffs rising from the landing point while the rain lasts
		if _landed and not _fading:
			_column_acc += delta * COLUMN_RATE
			while _column_acc >= 1.0:
				_column_acc -= 1.0
				_puff(_land + Vector2(_rng.randf_range(-5, 5), -6), Vector2(_rng.randf_range(-10, 10), -_rng.randf_range(170.0, 220.0)),
					COLUMN_LIFE * _rng.randf_range(0.85, 1.1), 11.0, 38.0, true)
		for i in POOL:
			if _age[i] < _life[i]:
				_age[i] += delta
				_pos[i] += _vel[i] * delta
				if _column[i] == 1: # the column sways and slows as it rises
					var v := _vel[i]
					v.x += sin(_t * 1.7 + _spin[i]) * 14.0 * delta
					v.y *= 1.0 - 0.75 * delta
					_vel[i] = v
		for i in SPARKS:
			if _sp_age[i] < SPARK_LIFE:
				_sp_age[i] += delta
				var v := _sp_vel[i] + Vector2(0, GRAVITY * delta)
				_sp_vel[i] = v
				_sp_pos[i] += v * delta
		queue_redraw()

	## 1 while playing, down to 0 over FADE_SEC after the replay.
	func _fade() -> float:
		return clampf(1.0 - _fade_t / FADE_SEC, 0.0, 1.0) if _fading else 1.0

	func _draw() -> void:
		var flicker := 0.82 + 0.1 * sin(_t * 37.0) + 0.08 * sin(_t * 91.0)
		# smoke, oldest look: red near the source, turning dusty pink and fading
		for i in POOL:
			var age: float = _age[i]
			var life: float = _life[i]
			if age >= life:
				continue
			var f := age / life
			var r := lerpf(_s0[i], _s1[i], sqrt(f))
			var col: Color
			if _column[i] == 1:
				col = Color(0.95, 0.12, 0.1).lerp(Color(0.88, 0.5, 0.5), f)
				col.a = 0.75 * (1.0 - f * f) * minf(1.0, age / 0.1) * _fade()
			else:
				col = Color(0.98, 0.15, 0.12).lerp(Color(0.85, 0.55, 0.55), f)
				col.a = 0.8 * (1.0 - f)
			draw_set_transform(_pos[i], _spin[i] + age * 0.6, Vector2.ONE)
			draw_texture_rect(_smoke_tex, Rect2(-Vector2(r, r), Vector2(r, r) * 2), false, col)
		draw_set_transform(Vector2.ZERO)
		# the flare's red light in flight
		if _flying:
			var g := 48.0 * flicker
			draw_texture_rect(_glow_tex, Rect2(_at - Vector2(g, g), Vector2(g, g) * 2), false, Color(FLARE_RED, 0.85))
			var m := 24.0 * flicker
			draw_texture_rect(_glow_tex, Rect2(_at - Vector2(m, m), Vector2(m, m) * 2), false, Color(1.0, 0.35, 0.3, 0.8))
			var h := 12.0 * flicker
			draw_texture_rect(_glow_tex, Rect2(_at - Vector2(h, h), Vector2(h, h) * 2), false, Color(1, 0.9, 0.85, 0.9))
		if not _landed:
			return
		var fade := _fade()
		# the landing flash
		var ft := _t - _land_t
		if ft < FLASH_SEC:
			var k := ft / FLASH_SEC
			var r := lerpf(22.0, 82.0, ease(k, 0.35))
			draw_texture_rect(_glow_tex, Rect2(_land - Vector2(r, r), Vector2(r, r) * 2), false, Color(1.0, 0.25, 0.18, 0.85 * (1.0 - k)))
			var c := 30.0 * (1.0 - k)
			draw_texture_rect(_glow_tex, Rect2(_land - Vector2(c, c), Vector2(c, c) * 2), false, Color(1, 0.95, 0.9, 1.0 - k))
		# the flare burning on the ground (brighter when the rain starts)
		var boost := 0.0
		if _rain_t >= 0.0:
			boost = clampf(1.0 - (_t - _rain_t) / 0.5, 0.0, 1.0)
		var gr := (24.0 + 14.0 * boost) * flicker
		draw_texture_rect(_glow_tex, Rect2(_land - Vector2(gr, gr), Vector2(gr, gr) * 2), false, Color(FLARE_RED, 0.7 * fade))
		var core := 7.0 * flicker
		draw_texture_rect(_glow_tex, Rect2(_land - Vector2(core, core), Vector2(core, core) * 2), false, Color(1, 0.92, 0.85, 0.95 * fade))
		for i in SPARKS:
			var a: float = _sp_age[i]
			if a >= SPARK_LIFE:
				continue
			var f := a / SPARK_LIFE
			var tail: Vector2 = _sp_pos[i] - _sp_vel[i] * 0.03
			draw_line(tail, _sp_pos[i], Color(1.0, lerpf(0.85, 0.3, f), lerpf(0.6, 0.2, f), 1.0 - f), 2.5 * (1.0 - f) + 0.8, true)
