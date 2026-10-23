extends Node2D
## The body of a boss or minion in a match (PlayerView's figure in place of the character scene,
## match/views/player_view.gd): BossArt at `height` px over the feet, idling (bob, glow, rotors),
## a white hit flash (hurt()), a step wobble while walking, a death fade (die(): it sinks a little,
## tilts and fades out), and for the boss its shield ball round the figure's centre
## (set_shielded(): pops in, shrinks away; a ShieldBall child: hexes wrapped on a breathing ball). It answers the calls PlayerView makes on a character (face, set_walking, aim, shoot,
## muzzle positions...) with what a body without a gun does: nothing to draw out, the shot leaving
## at once from its muzzle point (BossArt.MUZZLE: the robot's cannon, the witch's crystal).
## Boss mode v2: a flying unit (flying) hovers round its feet point in the air and leans into a
## flight (lean, PlayerView's UnitFlew flight), the witch with her cape and both fliers with a
## trail in the air (BossArt.TRAIL); a bomber (bomber) pulses red while warn (a party player within
## its detonateRange, BomberModel.pulse()); prime() swells and flashes it until its detonation,
## vanish() takes the body away at once (its blast covers it).
## Boss mode v3: a leaper (the snowmen jump next to a party member, then blow up on their next
## turn) glows while leap_warn (it leapt: LeapWarning): a soft warm halo behind the figure and a
## slight red tint, pulsing every LEAP_PULSE_SEC (no prop); its detonation primes it like a bomber.
## Drawn art: a boss with frames (ui/art.gd boss_side(): assets/bosses/<id>/side/, the Ice Witch) is
## drawn from them instead of BossArt, as tall (its body, hood top to the hem, `height` px) on the
## same feet point, mirrored facing left, the same hover bob and lean; a child node draws the frame
## through a shader (the hit flash whitens it, the death's icy tint). BossAnim picks the frame:
## idle looping, fly during a hover move (set_flight()), the idle slowed with a sway while stunned
## or frozen (set_stunned()), a skill's or a summon's animation once (play_action(), the peak on its
## moment), hurt briefly on a hit. Its death (die()) is its own (FRAMES_DEATH_SEC): the first hurt
## frame tinted icy white while cracks spread over her, a held freeze-frame, then she shatters: the
## figure fades and swells away while ice shards (the witch's shard art) burst out and fall, with a
## frost puff and a few sparkles. Without frames everything is as before (BossArt, the death fade).

const BossArt := preload("res://match/boss/boss_art.gd")
const BossAnim := preload("res://match/boss/boss_anim.gd")
const Art := preload("res://ui/art.gd")
const BomberModel := preload("res://match/boss/bomber_model.gd")
const ShieldBall := preload("res://match/views/shield_ball.gd")

const FLASH_SEC := 0.28
const DEATH_SEC := 1.2
const SHIELD_SEC := 0.35
const TRAIL_EVERY_PX := 7.0 # a trail puff each time the figure moved this far
const TRAIL_IDLE_SEC := 0.22 # and this often while it hovers in place
const TRAIL_LIFE := 0.7
const PRIME_SWELL := 0.18 # the body grows this much before it blows up
const LEAP_PULSE_SEC := 0.9 # one pulse of a leapt snowman's warning glow
const LEAP_TINT := 0.45 # its red tint at the pulse's peak (subtle)
const LEAP_GLOW := Color(1.0, 0.42, 0.22)
const SHARDS := 3 # the witch's idle orbiting shards
const SHARDS_CAST := 9 # as many while she casts them
const SHARD_SPIN := 0.9 # rad/s idle, × SHARD_SPIN_CAST at the cast's peak
const SHARD_SPIN_CAST := 7.0
const SHARD_REGROW := 1.0 # s for them to grow back after they flew off
const FRAMES_DEATH_SEC := 1.35 # a drawn boss's death: cracks, freeze, shatter
const CRACK_SEC := 0.35 # the cracks spread (and the icy tint)
const FREEZE_END := 0.55 # s: the held freeze-frame ends, she shatters
const VANISH_SEC := 0.22 # the figure fades away after it
const SHATTER_SHARDS := 30
const SHATTER_GRAVITY := 950.0 # px/s² at a 160 px body
const ICY := Color(0.86, 0.96, 1.0)
const FRAME_SHADER := """shader_type canvas_item;
uniform float flash = 0.0;
uniform float icy = 0.0;
uniform vec4 icy_colour : source_color = vec4(0.86, 0.96, 1.0, 1.0);
void fragment() {
	vec4 c = COLOR; // Godot 4: already the texture × the modulate (sampling it again would square it: darker, more saturated)
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb = mix(c.rgb, icy_colour.rgb * (0.8 + 0.25 * l), icy * smoothstep(0.1, 0.42, l)); // the dark outline stays
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c;
}
"""

var art := BossArt.GENERIC_BOSS
var height := 120.0 # px
var character_id := "" # PlayerView sets it (unused: drawn by art)
var holster := true
var idle_gun := true
var facing := 1
var shielded := false
var flying := false
var bomber := false
var warn := false # a party player within detonateRange: the red pulse
var leaper := false # a leaping minion (behavior "leaper")
var leap_warn := false # it leapt: about to blow up on its next turn (the warning glow)
var lean := 0.0 # rad into a flight (PlayerView sets it)

var _t := 0.0
var _flash := 0.0
var _walking := false
var _dead := false
var _death := 0.0 # 0..1 through the fade
var _shield := 0.0 # 0..1 the bubble shown
var _shield_pop := 0.0 # a short swell when it turns on / off
var _weapon := {"kind": "", "tier": ""}
var _prime := 0.0 # s left before it blows up (prime())
var _prime_sec := 0.0
var _vanished := false
var _trail: Array = [] # [{p: global Vector2, age, r}]
var _trail_from := Vector2.INF
var _trail_idle := 0.0
var _ball: ShieldBall # the shield, over the figure
static var _halo_tex: GradientTexture2D
var _shard_phase := 0.0 # the orbiting shards' angle (integrated: they spin up and down smoothly)
var _cast := 0.0 # s left before the cast shards start flying off (cast_shards())
var _cast_sec := 0.0
var _throw := 0.0 # s left of them flying off, one after another
var _regrow := 1.0 # 0..1 the shards grown back after a cast
var _side := {} # the drawn frames (Art.boss_side()); {} drawn by BossArt
var _anim: BossAnim # which frame shows (drawn frames only)
var _figure: Node2D # draws the frame through _mat
var _over: Node2D # over it: the death's shards, puff and sparkles
var _mat: ShaderMaterial
var _stunned := false
var _dead_t := 0.0 # s into a drawn boss's death
var _cracks: Array = [] # [PackedVector2Array] texture px, spreading over CRACK_SEC
var _bits: Array = [] # the shatter's shards [{p, v, r, rot, spin}] (local px)
var _sparks: Array = [] # [{p, r, delay}]
static var _shader: Shader


func setup(art_id: String, height_px: float) -> void:
	art = art_id
	height = maxf(height_px, 8.0)
	_t = randf() * 3.0
	if _ball == null:
		_ball = ShieldBall.new()
		add_child(_ball)
	_ball.position = Vector2(0, -height * 0.5) # round the figure's centre
	_ball.radius = BossArt.shield_radius(art, height)
	_ball.tint = BossArt.accent("ice_witch")
	_side = Art.boss_side(art)
	if not _side.is_empty() and _figure == null:
		_anim = BossAnim.new(_side["anims"])
		if _shader == null:
			_shader = Shader.new()
			_shader.code = FRAME_SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = _shader
		_figure = Node2D.new()
		_figure.name = "Frames"
		_figure.material = _mat
		_figure.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_figure.draw.connect(_draw_frame)
		add_child(_figure)
		move_child(_figure, 0) # under the shield ball
		_over = Node2D.new()
		_over.name = "DeathFx"
		_over.draw.connect(_draw_shatter)
		add_child(_over)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta / FLASH_SEC)
	_shield_pop = maxf(0.0, _shield_pop - delta * 2.5)
	var want := 1.0 if shielded and not _dead else 0.0
	_shield = move_toward(_shield, want, delta / SHIELD_SEC)
	if _dead and not _side.is_empty():
		_step_death(delta)
	elif _dead and _death < 1.0:
		_death = minf(1.0, _death + delta / DEATH_SEC)
		modulate = Color(0.75, 0.72, 0.8, 1.0 - _death)
		rotation = deg_to_rad(-12.0 * facing) * _death
		position.y = height * 0.08 * _death
	if _anim != null:
		_anim.stunned = _stunned and not _dead
		_anim.step(delta)
	if _prime > 0.0:
		_prime = maxf(0.0, _prime - delta)
		var k := 1.0 - _prime / maxf(_prime_sec, 0.01)
		scale = Vector2.ONE * (1.0 + PRIME_SWELL * k * k + sin(_t * 40.0) * 0.02 * k)
		_flash = maxf(_flash, 0.35 + 0.35 * absf(sin(_t * 18.0)))
	_step_shards(delta)
	_step_trail(delta)
	if _ball != null:
		var alpha := maxf(_shield, _shield_pop * 0.8) if not _vanished else 0.0
		_ball.set_look(1.0 + _shield_pop * 0.12, alpha)
	queue_redraw()
	if _figure != null:
		_figure.queue_redraw()
		_over.queue_redraw()


## The trail puffs in the air behind a flier (global positions, so they stay where it passed).
func _step_trail(delta: float) -> void:
	for p in _trail:
		p["age"] = float(p["age"]) + delta
	_trail = _trail.filter(func(p): return float(p["age"]) < TRAIL_LIFE)
	if not flying or _dead or _vanished or not BossArt.TRAIL.has(art) or not is_inside_tree():
		return
	var at := global_position + Vector2(0, -height * 0.35)
	_trail_idle += delta
	if _trail_from == Vector2.INF:
		_trail_from = at
	if at.distance_to(_trail_from) >= TRAIL_EVERY_PX or _trail_idle >= TRAIL_IDLE_SEC:
		_trail_from = at
		_trail_idle = 0.0
		_trail.append({"p": at + Vector2(randf_range(-0.2, 0.2), randf_range(-0.1, 0.25)) * height, "age": 0.0,
			"r": randf_range(0.03, 0.06) * height})


func _draw() -> void:
	if not _trail.is_empty():
		var col: Color = BossArt.TRAIL.get(art, Color.WHITE)
		for p in _trail:
			var k := float(p["age"]) / TRAIL_LIFE
			var at := to_local(p["p"]) + Vector2(0, -k * 10.0)
			draw_circle(at, float(p["r"]) * (1.0 - k * 0.5), Color(col, col.a * 0.55 * (1.0 - k)))
			if art == "ice_witch" and int(float(p["r"]) * 100.0) % 3 == 0: # a frost glint
				var g := float(p["r"]) * 0.9 * (1.0 - k)
				draw_line(at - Vector2(g, 0), at + Vector2(g, 0), Color(1, 1, 1, 0.7 * (1.0 - k)), 1.2, true)
				draw_line(at - Vector2(0, g), at + Vector2(0, g), Color(1, 1, 1, 0.7 * (1.0 - k)), 1.2, true)
	if _vanished:
		return
	var glow := leap_glow()
	if glow > 0.0:
		var r := height * (0.62 + 0.08 * glow)
		draw_texture_rect(halo_texture(), Rect2(Vector2(-r, -height * 0.48 - r), Vector2(r, r) * 2.0), false,
			Color(LEAP_GLOW, 0.3 + 0.45 * glow))
	var tint := BomberModel.pulse(_t, (bomber or leaper) and not _dead and (warn or _prime > 0.0))
	if glow > 0.0:
		tint = maxf(tint, LEAP_TINT * glow)
	if not _side.is_empty(): # the frames' node draws the figure
		return
	var wobble := Vector2.ZERO
	if _walking and not _dead and not flying:
		wobble = Vector2(0, -absf(sin(_t * 14.0)) * height * 0.03)
	BossArt.draw(self, art, wobble, height, _t if not _dead else 0.0, facing, _flash, {"flying": flying, "lean": lean if not _dead else 0.0,
		"tint": tint, "shards": shards()})


## The witch casts her shards (her blizzard): over lead s they spin up and multiply round her,
## for throw s more they whirl fast while the blizzard's shards leave her one after another, then
## they are gone and grow back over SHARD_REGROW s.
func cast_shards(lead: float, throw: float = 0.0) -> void:
	_cast = maxf(lead, 0.05)
	_cast_sec = _cast
	_throw = maxf(throw, 0.0)
	_regrow = 1.0


## The orbiting shards now: {phase, n, size, reach} (BossArt opts shards).
func shards() -> Dictionary:
	if _cast > 0.0:
		var k := 1.0 - _cast / maxf(_cast_sec, 0.01) # 0 → 1 over the spin-up
		return {"phase": _shard_phase, "n": SHARDS + int(round((SHARDS_CAST - SHARDS) * minf(k * 1.6, 1.0))), "size": 1.0 + 0.25 * k,
			"reach": 1.0 + 0.35 * k}
	if _throw > 0.0: # throwing: they whirl, flickering in and out as each one leaves
		return {"phase": _shard_phase, "n": SHARDS_CAST, "size": 0.85 + 0.35 * absf(sin(_t * 23.0)), "reach": 1.35}
	return {"phase": _shard_phase, "n": SHARDS, "size": _regrow, "reach": 0.6 + 0.4 * _regrow}


func casting_shards() -> bool:
	return _cast > 0.0 or _throw > 0.0


func _step_shards(delta: float) -> void:
	var spin := SHARD_SPIN
	if _cast > 0.0:
		var k := 1.0 - _cast / maxf(_cast_sec, 0.01)
		spin *= 1.0 + (SHARD_SPIN_CAST - 1.0) * k
		_cast = maxf(0.0, _cast - delta)
		if _cast <= 0.0 and _throw <= 0.0:
			_regrow = 0.0 # off they fly
	elif _throw > 0.0:
		spin *= SHARD_SPIN_CAST
		_throw = maxf(0.0, _throw - delta)
		if _throw <= 0.0:
			_regrow = 0.0 # the last one left
	elif _regrow < 1.0:
		_regrow = minf(1.0, _regrow + delta / SHARD_REGROW)
	_shard_phase += spin * delta


## A leapt snowman's warning glow now (0..1, pulsing every LEAP_PULSE_SEC; 0 without the warning,
## dead or blowing up).
func leap_glow() -> float:
	if not leap_warn or _dead or _vanished or _prime > 0.0:
		return 0.0
	return 0.5 - 0.5 * cos(TAU * _t / LEAP_PULSE_SEC)


## A soft round halo (white in the middle, clear at the rim), tinted when drawn.
static func halo_texture() -> GradientTexture2D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(1.0, 0.5)
		_halo_tex.width = 64
		_halo_tex.height = 64
	return _halo_tex


## The figure's height (px, the unit PlayerView reads art_height() × scale in).
func art_height() -> float:
	return height


## Turns the shield on or off; animate: with the pop.
func set_shielded(on: bool, animate: bool = true) -> void:
	if on == shielded:
		return
	shielded = on
	if animate:
		_shield_pop = 1.0
	else:
		_shield = 1.0 if on else 0.0


func shield_shown() -> float:
	return _shield


## The shield ball (tests, previews).
func shield_ball() -> ShieldBall:
	return _ball


func set_weapon(kind: String, tier: String) -> void:
	_weapon = {"kind": kind, "tier": tier}


func weapon() -> Dictionary:
	return _weapon


func face(dir: float) -> void:
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1


func set_walking(on: bool) -> void:
	_walking = on


func hurt() -> void:
	_flash = 1.0
	if _anim != null and not _dead and (_anim.playing() == "" or _anim.playing() == BossAnim.HURT):
		_anim.play(BossAnim.HURT)


func is_flashing() -> bool:
	return _flash > 0.0


func die() -> void:
	if _dead:
		return
	_dead = true
	if not _side.is_empty():
		_dead_t = 0.0
		_cracks = _make_cracks()


## About to blow up in sec (a detonation's lead-in): the body swells, flashing red.
func prime(sec: float) -> void:
	if _dead or sec <= 0.0:
		return
	_prime = sec
	_prime_sec = sec


func priming() -> bool:
	return _prime > 0.0


## Gone at once (it blew up: its blast covers the spot).
func vanish() -> void:
	_dead = true
	_vanished = true
	_prime = 0.0
	scale = Vector2.ONE


func vanished() -> bool:
	return _vanished


func death_progress() -> float:
	return _death


# ── Drawn frames ────────────────────────────────────────────────────────────

## Drawn from frames (Art.boss_side()), not by BossArt.
func has_frames() -> bool:
	return not _side.is_empty()


## The frame animation (null without frames: tests).
func anim() -> BossAnim:
	return _anim


## A hover move (UnitFlew) starts / ends: the fly loop while it lasts.
func set_flight(on: bool) -> void:
	if _anim != null:
		_anim.set_flying(on)


## Stunned or frozen (a status that skips the turn): the idle slows down and sways.
func set_stunned(on: bool) -> void:
	_stunned = on


## A shot's animation (BossAnim.action_for(): {anim, at, hold}) played once; its duration (0: none).
func play_action(action: Dictionary) -> float:
	if _anim == null or _dead:
		return 0.0
	return _anim.play(str(action.get("anim", "")), {"at": float(action.get("at", -1.0)), "hold": float(action.get("hold", -1.0))})


## The frame shown: [anim, index] (the death shows the first hurt frame).
func shown_frame() -> Array:
	if _anim == null:
		return []
	if _dead:
		return [BossAnim.HURT if _anim.has(BossAnim.HURT) else "idle", 0]
	return _anim.frame()


## The death's phase now: "crack", "freeze", "shatter" or "gone" ("" alive or no frames).
func death_phase() -> String:
	if not _dead or _side.is_empty():
		return ""
	if _dead_t < CRACK_SEC:
		return "crack"
	if _dead_t < FREEZE_END:
		return "freeze"
	return "shatter" if _dead_t < FRAMES_DEATH_SEC else "gone"


func shatter_count() -> int:
	return _bits.size()


func _step_death(delta: float) -> void:
	var was := _dead_t
	_dead_t += delta
	_death = minf(1.0, _dead_t / FRAMES_DEATH_SEC)
	if was < FREEZE_END and _dead_t >= FREEZE_END:
		_shatter()
	var g := SHATTER_GRAVITY * height / 160.0
	for b in _bits:
		b["v"] = Vector2(b["v"]) + Vector2(0, g * delta)
		b["p"] = Vector2(b["p"]) + Vector2(b["v"]) * delta
		b["rot"] = float(b["rot"]) + float(b["spin"]) * delta


## The body's centre now (local px; the hover bob of the frame).
func _centre() -> Vector2:
	return Vector2(0, BossArt.bob(art, _t, flying) * height / BossArt.UNIT - height * 0.5)


## The cracks: a few jagged lines from near the body's middle outward (texture px).
func _make_cracks() -> Array:
	var out: Array = []
	var h := float(_side["height"])
	var c: Vector2 = _side["pivot"] - Vector2(0, h * 0.55)
	for i in 7:
		var a := TAU * i / 7.0 + randf_range(-0.3, 0.3)
		var p := c + Vector2(randf_range(-0.08, 0.08), randf_range(-0.12, 0.12)) * h
		var line := PackedVector2Array([p])
		var segs := randi_range(3, 5)
		for k in segs:
			a += randf_range(-0.7, 0.7)
			p += Vector2.from_angle(a) * h * randf_range(0.05, 0.09)
			line.append(p)
		out.append(line)
	return out


## She breaks: the shards burst out of her body, the sparkles placed.
func _shatter() -> void:
	_bits.clear()
	var c := _centre()
	for i in SHATTER_SHARDS:
		var p := c + Vector2(randf_range(-0.28, 0.28), randf_range(-0.42, 0.42)) * height
		var dir := (p - c).normalized() if p != c else Vector2.UP
		_bits.append({"p": p, "v": dir * randf_range(1.0, 2.6) * height + Vector2(0, -0.8 * height),
			"r": height * randf_range(0.03, 0.07), "rot": randf() * TAU, "spin": randf_range(-9.0, 9.0)})
	_sparks.clear()
	for i in 6:
		_sparks.append({"p": c + Vector2(randf_range(-0.55, 0.55), randf_range(-0.6, 0.5)) * height, "r": height * randf_range(0.05, 0.09),
			"delay": randf_range(0.0, 0.35)})


## The frame now: {tex, xform (Transform2D: texture px → local), alpha, flash, icy}; {} none.
func _frame_look() -> Dictionary:
	var f := shown_frame()
	if f.is_empty() or _vanished:
		return {}
	var spec: Dictionary = _side["anims"].get(f[0], _side["anims"]["idle"])
	var frames: Array = spec["frames"]
	var tex: Texture2D = frames[clampi(int(f[1]), 0, frames.size() - 1)]
	var k := height / float(_side["height"])
	var mirror := float(facing * int(_side["facing"]))
	var alpha := 1.0
	var swell := 1.0
	var icy := 0.0
	var flash := _flash * 0.85
	if _dead:
		icy = 0.5 * clampf(_dead_t / CRACK_SEC, 0.0, 1.0)
		if _dead_t >= CRACK_SEC and _dead_t < FREEZE_END: # the freeze: a white pulse building to the break
			flash = maxf(flash, 0.45 * smoothstep(CRACK_SEC, FREEZE_END, _dead_t))
		if _dead_t >= FREEZE_END:
			var v := clampf((_dead_t - FREEZE_END) / VANISH_SEC, 0.0, 1.0)
			alpha = 1.0 - v
			swell = 1.0 + 0.14 * v
			flash = maxf(flash, 0.6 * (1.0 - v))
	var bob := BossArt.bob(art, _t if not _dead else 0.0, flying) * height / BossArt.UNIT
	var rot := (lean + _anim.sway()) if not _dead else 0.0
	var centre := Vector2(0, -height * 0.5) # a swell grows round the body's centre
	var xform := Transform2D(rot, Vector2(mirror * k, k) * swell, 0.0, Vector2(0, bob) + centre * (1.0 - swell))
	return {"tex": tex, "xform": xform * Transform2D(0.0, -Vector2(_side["pivot"])), "alpha": alpha, "flash": flash, "icy": icy}


## The frame: its texture scaled to `height`, on the feet (plus the bob, the lean or the stun's
## sway), mirrored facing left, through the shader (the hit flash, the death's icy tint).
func _draw_frame() -> void:
	var look := _frame_look()
	if look.is_empty() or float(look["alpha"]) <= 0.0:
		_mat.set_shader_parameter("flash", 0.0)
		return
	_mat.set_shader_parameter("flash", look["flash"])
	_mat.set_shader_parameter("icy", look["icy"])
	_figure.draw_set_transform_matrix(look["xform"])
	_figure.draw_texture(look["tex"], Vector2.ZERO, Color(1, 1, 1, look["alpha"]))
	_figure.draw_set_transform(Vector2.ZERO)


## The shatter over the figure: the frost puff, the shards falling, the sparkles.
func _draw_shatter() -> void:
	if not _dead or _side.is_empty():
		return
	var look := _frame_look()
	if not look.is_empty() and float(look["alpha"]) > 0.0 and not _cracks.is_empty(): # the cracks over her
		var grow := clampf(_dead_t / CRACK_SEC, 0.0, 1.0)
		var a := float(look["alpha"])
		_over.draw_set_transform_matrix(look["xform"])
		for line in _cracks:
			var pts := PackedVector2Array()
			for i in mini(maxi(2, int(ceil(line.size() * grow))), line.size()):
				pts.append(line[i])
			_over.draw_polyline(pts, Color(0.1, 0.18, 0.42, 0.9 * a), 7.0, true)
			_over.draw_polyline(pts, Color(1, 1, 1, a), 3.0, true)
		_over.draw_set_transform(Vector2.ZERO)
	if _dead_t < FREEZE_END:
		return
	var s := _dead_t - FREEZE_END
	var life := FRAMES_DEATH_SEC - FREEZE_END
	var c := _centre()
	var puff := clampf(s / 0.55, 0.0, 1.0)
	if puff < 1.0:
		for i in 4:
			var r := height * (0.3 + 0.12 * i) * (0.6 + 0.6 * puff)
			var at := c + Vector2(cos(i * 1.9), sin(i * 2.3)) * height * 0.08 * puff
			_over.draw_texture_rect(halo_texture(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(ICY, 0.55 * (1.0 - puff)))
	var fade := clampf((life - s) / (life * 0.4), 0.0, 1.0)
	for b in _bits:
		BossArt.shard(_over, b["p"], float(b["r"]), float(b["rot"]), fade)
	for sp in _sparks:
		var u := (s - float(sp["delay"])) / 0.45
		if u <= 0.0 or u >= 1.0:
			continue
		var r := float(sp["r"]) * sin(PI * u)
		var p: Vector2 = sp["p"]
		var col := Color(1, 1, 1, 0.9)
		_over.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.22, -r * 0.22), p + Vector2(r, 0),
			p + Vector2(r * 0.22, r * 0.22), p + Vector2(0, r), p + Vector2(-r * 0.22, r * 0.22), p + Vector2(-r, 0),
			p + Vector2(-r * 0.22, -r * 0.22)]), col)


func aim(_angle: float) -> void:
	pass


func draw_gun() -> void:
	pass


func clear_aim() -> void:
	pass


func gun_state() -> String:
	return "holstered"


## The shot leaves at once (no gun to draw): a small flash, no wait.
func shoot(_with_gun: bool = true) -> float:
	_flash = maxf(_flash, 0.35)
	return 0.0


func muzzle_position() -> Vector2:
	return to_global(BossArt.muzzle(art, height, facing))


func fire_muzzle_position() -> Vector2:
	return muzzle_position()
