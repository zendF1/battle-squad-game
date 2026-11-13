extends Node2D
## The body of a boss or minion in a match (PlayerView's figure in place of the character scene,
## match/views/player_view.gd): BossArt at `height` px over the feet, idling (bob, glow, rotors),
## a white hit flash (hurt()), a step wobble while walking, a death fade (die(): it sinks a little,
## tilts and fades out), and for the boss its shield ball round the figure's centre
## (set_shielded(): pops in, shrinks away; a ShieldBall child: hexes wrapped on a breathing ball). It answers the calls PlayerView makes on a character (face, set_walking, aim, shoot,
## muzzle positions...) with what a body without a gun does: nothing to draw out, the shot leaving
## at once from its muzzle point (BossArt.MUZZLE: the saucer's twin barrels, the witch's crystal),
## following the hover bob and the lean.
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
## frost puff and a few sparkles. Đĩa Bay Thép crashes instead (BossArt.DEATH "crash", CRASH_SEC):
## the first hurt frame shakes harder and harder with sparks and smoke puffs off the hull, then the
## dome pops off (its parts, Art.boss_parts(): the hull with the cockpit open and the dome tumbling
## away) and the hull tumbles down nose first, charring, trailing smoke, and blows up in mid-air: a
## fire burst with a shock ring, smoke and steel debris. A drawn flier leaves its trail
## (BossArt.TRAIL from BossArt.TRAIL_FROM: the saucer's jet puffs under its claws) and leans into a
## flight by BossArt.LEAN round BossArt.LEAN_ABOUT (the saucer banks round its hull's middle). The
## shield ball takes the boss's own accent and follows the bob. Without frames everything is as
## before (BossArt, the death fade).
## A boss with a skinned idle (Art.boss_skin(): her portrait on a skeleton, BossSkinView) shows it
## instead of the idle frames, on the same feet and body height, and floats by its hover
## (SkinIdle.hover()) in every animation, so idle ↔ fly / cast do not jump. One with a skinned glide
## (Art.boss_skin(art, "fly"): her side view, SkinFly) glides on it during a hover move instead of the
## fly frames: the lean and the streaming cape blend in over SkinFly.BLEND_SEC, the cape settles
## with a little overshoot on landing (it shows until settled), the bob blends to the glide's smaller one.
## Boss v4: set_armored() puts the stone plates of its totems' armour on Khổng Lồ Đá (they pop on one
## after another; when the armour breaks they fly off and fade, BossArt.PLATE_BREAK_SEC); heal_glow()
## flashes a green halo behind the figure and lights its heart (a drain or a regen heal); puff()
## squashes a poison mushroom and springs it up as it puffs its spores; a stone totem nods as it
## shoots; a stone totem crumbles into falling stones as it dies.
## Khổng Lồ Đá drawn (its frames and skinned idle, side/points.json: Art.boss_points()): it stands on
## its feet (its skin breathes, SkinIdle.hovers() false: no float); the plates are drawn over the
## frame or the skin (BossArt.FRAME_PLATES, each carried by its points.json joint: they follow every
## pose; on the skin by the bones), popping on and breaking off as before (and off when it dies); its
## heart (the drain's end, the heal glow) is the shown frame's gem (points heart), its muzzle the
## throwing knuckles while a throw shows (hand_r); its stomp's peak frame (BossArt.STOMP) bursts dust
## at the landing foot and opens the game's shockwave ring there (ShockwaveFx). It dies crumbling
## (BossArt.DEATH "crumble", death_phase() crack → crumble → fade → gone): the death frames crack it
## (0 to CRUMBLE_SWAP_FRAME), then it is its parts (Art.boss_parts(), posed as that frame, drawn by
## z): they fall with gravity, pushed out a little from the heart, spinning, bounce and settle on
## the ground, the helmet a beat later and the horns last (HORN_DELAY), tumbling; dust bursts and
## pebbles fly, then everything fades (CRUMBLE_FADE).
## Mộc Tinh drawn (its frames and skinned idle, points.json): it stands on its roots (the skin
## breathes: the canopy, twigs and side roots sway; the mint heart glows on the trunk, the eyes
## flicker); the heart (the drain's end, the heal's mint light) is the shown frame's, its muzzle the
## canopy while its thorns shake out (BossArt.MUZZLE_FOLLOW), root_tip_position() the dragging root's
## tip while root_drag shows it (RootDragFx joins it). Now and then a leaf falls off its canopy
## (BossArt.LEAVES, FallingLeaves). It dies withering (BossArt.DEATH "wither", death_phase() wither →
## drop → fade → gone): its death frames 0..WITHER_SWAP_FRAME brown it, drop its leaves, put its
## glows out and crack it; then it is its parts (posed as that frame; the frame stays over them a
## moment, WITHER_COVER, fading, so their cut edges never show assembled): the canopy clumps and the
## twigs drop off one after another, tumbling slowly, and settle on the ground with a little dust,
## the trunk and the roots sag a little (WITHER_SAG), withered leaves shower down; then it all fades.
## Cua Dung Nham drawn (its frames and skinned idle, points.json): it stands on its legs (the skin
## breathes, the ember glow in its shell, the eyes flicker); walking along the ground (set_walking():
## its crawl to the pincer) it plays its walk loop, back to the idle when it stops; its heart is the
## shown frame's, its muzzle the shell top while fire_bombs shows, where a spout of lava globs shoots
## up at the peak (BossArt.SPOUT); its claw_slam's peak frame throws basalt chips and embers up at the
## claw's impact (BossArt.STOMP, no ring of its own: the game's shockwave opens its slam ring there,
## slam_point()); now and then a lava drop falls off one of its drips and sizzles on the ground
## (BossArt.DRIPS, LavaDrips). It dies cooling (BossArt.DEATH "cool", death_phase() cool → split →
## fade → gone): its death frames cool the lava to stone, crack it and buckle its legs, smoke rising;
## then it is its parts (posed as the last frame, which stays over them a moment, COOL_COVER): the
## shell splits in two and topples apart, the claws and the legs fall off and settle, smoke puffs
## and embers, then it all fades. Its Cua con (art crab, frames from lava_crab/minion/) walks on its
## walk loop, plays prime while warned or primed with the bomber's red tint on its frames (the
## shader's tint), and dies fading (BossArt.DEATH "fade": the hurt frame sinks, tilts and fades).
## Round 2 (Đĩa Bay Thép): a boss with a turret (Art.boss_turret(): its twin cannon, the body frames
## without it) draws it over the body at the mount of the frame shown (turret.json bodyFrames: the
## hurt's tilt moves and turns it), turned to its aim (TurretModel: clamped to its range, a quick
## eased turn, TURN_SEC), at rest (20°, toward the side it faces) otherwise. Its picture follows the
## body's animation (TurretModel.state_for(): the cast charges and recoils on its peak with a flash
## at both muzzles and smoke after, the burst charges and holds hot while its beams fire). A boss
## shot's plan (play_turret(): TurretModel.cues(), on the replay's clock) turns it onto each beam's
## target and each projectile it fires, then back to rest. muzzle_position() is its turned mid tip
## (following the bob, the lean and the hurt's tilt); aim_turret_at() / tip_toward() turn it / say
## where the tip will be. Its crash pops the cannon part off too.

const BossArt := preload("res://match/boss/boss_art.gd")
const BossAnim := preload("res://match/boss/boss_anim.gd")
const BossSkinView := preload("res://match/boss/boss_skin_view.gd")
const SkinIdle := preload("res://match/boss/skin_idle.gd")
const Art := preload("res://ui/art.gd")
const BomberModel := preload("res://match/boss/bomber_model.gd")
const TurretModel := preload("res://match/boss/turret_model.gd")
const ShieldBall := preload("res://match/views/shield_ball.gd")
const ShockwaveFx := preload("res://match/boss/shockwave_fx.gd")
const FallingLeaves := preload("res://match/boss/falling_leaves.gd")
const LavaDrips := preload("res://match/boss/lava_drips.gd")

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
const CRASH_WOBBLE := 0.55 # s: the crash's shaking hurt frame (sparks, smoke)
const CRASH_FALL := 0.7 # s: the dome popped off, the hull tumbles down
const CRASH_BOOM := 0.9 # s: the explosion dies down
const CRASH_SEC := CRASH_WOBBLE + CRASH_FALL + CRASH_BOOM
const CRASH_DROP := 0.6 # of the body's height the hull falls before it blows up
const CRASH_DRIFT := 0.12 # of the height it slides toward its nose as it dives
const CRASH_TUMBLE := 0.62 # rad nose down when it blows up
const HURT_TILT := -0.157 # rad: the first hurt frame's nose-up tilt (make_frames.py: 9°), the hull starts there
const HURT_SHIFT := Vector2(-4.9, -2.1) # texture px: its knock back
const CRASH_DEBRIS := 14
const ZAP_SEC := 0.22 # one spark's life
const SOOT := Color(0.3, 0.27, 0.26) # the crash's charring (the shader's tint)
const SMOKE := Color(0.15, 0.14, 0.16)
const FIRE := [Color(1.0, 0.95, 0.72), Color(1.0, 0.6, 0.16), Color(0.86, 0.26, 0.1)]
const FRAME_SHADER := """shader_type canvas_item;
uniform float flash = 0.0;
uniform float icy = 0.0;
uniform vec4 icy_colour : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform float tint = 0.0; // a bomber's red warning pulse (BomberModel.pulse(), as BossArt's code art: half way to WARN_RED)
uniform vec4 tint_colour : source_color = vec4(1.0, 0.22, 0.16, 1.0);
void fragment() {
	vec4 c = COLOR; // Godot 4: already the texture × the modulate (sampling it again would square it: darker, more saturated)
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb = mix(c.rgb, icy_colour.rgb * (0.8 + 0.25 * l), icy * smoothstep(0.1, 0.42, l)); // the dark outline stays
	c.rgb = mix(c.rgb, tint_colour.rgb, tint * 0.5);
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
var _parts := {} # the loose parts (Art.boss_parts(): the saucer's hull and dome)
var _smoke: Array = [] # the crash's smoke [{p, v, r, grow, age, life}] (body px: texture px from the feet, facing right)
var _zaps: Array = [] # its sparks [{p, r, rot, age}] (body px)
var _debris: Array = [] # its steel bits [{p, v, r, rot, spin, col}] (body px)
var _dome := {} # the popped dome {p (its centre), v, rot, spin} (body px)
var _boom_at := Vector2.ZERO # where it blew up (body px)
var _emit := 0.0 # s to the next spark / puff
static var _shader: Shader
var _skin := {} # the skinned idle (Art.boss_skin()); {} the idle frames
var _skin_view: BossSkinView
var _fly_view: BossSkinView # the skinned glide (Art.boss_skin(art, "fly")); null: the fly frames
var _flying_now := false # a hover move under way (set_flight())
var armored := false # boss v4: the totems' stone plates are on (set_armored())
var _plates := 0.0 # 0..1 the plates shown (popping on)
var _plate_break := -1.0 # s since they broke off (-1 none)
var _heal := 0.0 # 0..1 the heal glow (heal_glow())
var _puff := -1.0 # s into a spore puff (puff(); -1 none)
var _nod := 0.0 # 0..1 a totem's shot nod
const HEAL_SEC := 1.1
const TIP_FLASH_SEC := 0.14 # the muzzle flash at the turret's tips when it recoils
const TIP_SMOKE_LIFE := 0.7
const TIP_SMOKE_EVERY := 0.05 # s between two puffs at each tip while it cools (recoil_1)
var _turret := {} # Art.boss_turret(): {} none
var _aim := 0.0 # the turret's angle now (degrees, relative to the body, art frame)
var _aim_from := 0.0
var _aim_to := 0.0
var _aim_k := 1.0 # 0..1 through the turn onto _aim_to
var _aim_sec := TurretModel.TURN_SEC
var _plan := {} # play_turret(): TurretModel.cues() on the replay's clock
var _plan_t := -1.0 # s into it (-1 none)
var _tstate := "idle" # the turret picture shown
var _tip_flash := 0.0 # s left of the muzzle flash
var _tip_smoke: Array = [] # [{p (global), v, r, age, life}]
var _tip_emit := 0.0
var _turret_fires := true # the shot playing fires from the turret (play_turret() with aims): its cast recoils
var _cannon := {} # the crash's popped cannon {p (its hub), v, rot, spin} (body px)
const PLATES_IN_SEC := 0.5
const NOD_SEC := 0.45
const PUFF_SEC := 0.7
const HEAL_GLOW := Color(0.6, 1.0, 0.4)
const CRUMBLE := [Color(0.69, 0.48, 0.27), Color(0.43, 0.29, 0.18), Color(0.85, 0.65, 0.4)]
## Khổng Lồ Đá's crumble (BossArt.DEATH "crumble").
const CRUMBLE_SWAP_FRAME := 2 # the death frame the parts take over on (they are posed as it)
const CRUMBLE_FALL := 1.6 # s from the swap: the parts fall, bounce and settle
const CRUMBLE_FADE := 0.6 # s: then they fade away
const HELMET_DELAY := 0.15 # s after the swap the helmet drops
const HORN_DELAY := 0.4 # s after the swap the horns drop, tumbling
const RUBBLE_GRAVITY := 5.9 # body heights / s²
const RUBBLE_PUSH := Vector2(0.12, 0.3) # body heights / s: the push out from the heart (lo, hi)
const RUBBLE_BOUNCE := 0.3 # of the fall speed back up
const RUBBLE_PEBBLES := 16
const STONE := [Color(0.42, 0.33, 0.27), Color(0.3, 0.24, 0.2), Color(0.56, 0.53, 0.49)]
const DUST := Color(0.62, 0.52, 0.43)
const STOMP_PUFFS := 10
const STOMP_PEBBLES := 8
## The skinned idle's bone carrying each points.json joint (the plates on the skin).
const SKIN_BONE := {"chest": "torso", "pauldron_l": "arm_l", "pauldron_r": "arm_r", "pelvis": "root", "head": "head"}
var _points := {} # Art.boss_points(): the frames' points ({} none)
var _plate_view: Node2D # draws the plates (and the heart's heal light) over the frames / the skin
var _rubble: Array = [] # the crumble's parts [{tex, size, z, c, v, rot, spin, delay, ground}] (body px)
var _crumbled := false # the parts took over
var _dust: Array = [] # [{p, v, r, grow, age, life}] (local px)
var _pebbles: Array = [] # [{p, v, r, rot, spin, age, life, col, ground}] (local px)
var _last_frame: Array = []
const WITHER_SWAP_FRAME := 3 # Mộc Tinh's death frame its parts are posed as (the last)
const WITHER_HOLD := 0.25 # s that frame shows before they take over
const WITHER_COVER := 0.22 # s the frame stays over the parts, fading, as they start to separate
const WITHER_FALL := 1.5 # s from the swap: the clumps and twigs drop and settle
const WITHER_FADE := 0.7 # s: then it all fades
const WITHER_SAG := 0.06 # the trunk and roots squash this much toward the ground
const WITHER_GRAVITY := 0.7 # × RUBBLE_GRAVITY: leafy clumps fall softer
const WITHER_BOUNCE := 0.12
## The parts that drop off (s after the swap; the rest stay on the trunk and sag with it).
const WITHER_DROP := {"canopy_ml": 0.0, "canopy_mr": 0.1, "canopy_l": 0.18, "canopy_r": 0.26, "branch_l": 0.34, "branch_r": 0.4}
const WITHER_LEAVES := 26 # the shower at the swap
const WITHER_LEAF_EVERY := 0.05 # s between two while the death frames wither it
var _leaves := FallingLeaves.new() # the falling leaves (BossArt.LEAVES)
var _leaf_in := 1.5 # s to the next idle leaf
var _leaf_emit := 0.0
## Cua Dung Nham's cooling death (BossArt.DEATH "cool").
const COOL_SWAP_FRAME := 4 # its last death frame: the parts are posed as it
const COOL_HOLD := 0.3 # s that frame shows before they take over
const COOL_COVER := 0.22 # s the frame stays over the parts, fading
const COOL_FALL := 1.5 # s from the swap: the shell splits, claws and legs fall and settle
const COOL_FADE := 0.7 # s: then it all fades
const COOL_BOUNCE := 0.22
const COOL_SMOKE_EVERY := 0.09 # s between two smoke puffs off the cooling shell
const COOL_SMOKE := Color(0.32, 0.3, 0.3)
const EMBERS := [Color(1.0, 0.62, 0.18), Color(1.0, 0.82, 0.34), Color(0.95, 0.4, 0.1)]
## The shell's halves topple apart (rad they end turned, outward; they slide COOL_SLIDE body heights
## out over COOL_TOPPLE_SEC, their bottoms kept on the ground).
const COOL_TOPPLE := {"shell_l": -0.5, "shell_r": 0.55}
const COOL_TOPPLE_SEC := 0.75
const COOL_SLIDE := 0.1
const COOL_SINK := 0.03 # body heights they settle down as they tip
## The other parts' start (body heights / s, facing right: x out, y up negative; spin rad / s; delay
## s): the claws drop off tumbling, the legs slump outward.
const COOL_PARTS := {"shell_l": {"v": Vector2.ZERO, "spin": 0.0, "delay": 0.0}, "shell_r": {"v": Vector2.ZERO, "spin": 0.0, "delay": 0.04},
	"arm_l": {"v": Vector2(-0.12, -0.05), "spin": -1.8, "delay": 0.12}, "claw_l": {"v": Vector2(-0.3, -0.22), "spin": -3.2, "delay": 0.16},
	"finger_l": {"v": Vector2(-0.36, -0.3), "spin": -4.5, "delay": 0.2},
	"arm_r": {"v": Vector2(0.14, -0.06), "spin": 1.6, "delay": 0.14}, "palm_r": {"v": Vector2(0.24, -0.14), "spin": 2.4, "delay": 0.18},
	"finger_r": {"v": Vector2(0.34, -0.24), "spin": 4.0, "delay": 0.24}}
const COOL_LEG := {"v": Vector2(0.07, -0.03), "spin": 0.7, "delay": 0.06} # every leg_* (x and spin outward from the heart)
var _drips := LavaDrips.new() # the lava drops (BossArt.DRIPS, the spout)
var _drip_in := 0.8 # s to the next drip
var _smoke_emit := 0.0


func setup(art_id: String, height_px: float) -> void:
	art = art_id
	height = maxf(height_px, 8.0)
	_t = randf() * 3.0
	if _ball == null:
		_ball = ShieldBall.new()
		add_child(_ball)
	_ball.position = Vector2(0, -height * 0.5) # round the figure's centre
	_ball.radius = BossArt.shield_radius(art, height)
	_ball.tint = BossArt.accent(art)
	_side = Art.boss_side(art)
	if not _side.is_empty() and _figure == null:
		_anim = BossAnim.new(_side["anims"])
		if _shader == null:
			_shader = Shader.new()
			_shader.code = FRAME_SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = _shader
		if _crashes():
			_mat.set_shader_parameter("icy_colour", SOOT) # the crash chars it instead of icing it
			_parts = Art.boss_parts(art)
		_turret = Art.boss_turret(art)
		if not _turret.is_empty():
			_aim = float(_turret["rest"])
			_aim_to = _aim
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
		_skin = Art.boss_skin(art)
		if not _skin.is_empty():
			_skin_view = BossSkinView.new()
			_skin_view.name = "Skin"
			_skin_view.setup(_skin)
			_skin_view.set_shader_material(_mat)
			add_child(_skin_view)
			move_child(_skin_view, 1) # over the frames' node, under the shield ball
		var fly := Art.boss_skin(art, "fly")
		if not fly.is_empty():
			_fly_view = BossSkinView.new()
			_fly_view.name = "Glide"
			_fly_view.setup(fly)
			_fly_view.set_shader_material(_mat)
			add_child(_fly_view)
			move_child(_fly_view, 1)
		_points = Art.boss_points(art)
		_plate_view = Node2D.new()
		_plate_view.name = "Plates"
		_plate_view.draw.connect(_draw_plates)
		add_child(_plate_view)
		move_child(_plate_view, _ball.get_index()) # over the frames and the skin, under the shield ball
		if _skin_view != null:
			_place_skin()


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta / FLASH_SEC)
	_shield_pop = maxf(0.0, _shield_pop - delta * 2.5)
	var want := 1.0 if shielded and not _dead else 0.0
	_shield = move_toward(_shield, want, delta / SHIELD_SEC)
	if _dead and not _side.is_empty() and not _fades():
		_step_death(delta)
	elif _dead and _death < 1.0:
		_death = minf(1.0, _death + delta / DEATH_SEC)
		modulate = Color(0.75, 0.72, 0.8, 1.0 - _death)
		rotation = deg_to_rad(-12.0 * facing) * _death
		position.y = height * 0.08 * _death
	if _anim != null:
		_anim.stunned = _stunned and not _dead
		_anim.set_primed((bomber or leaper) and not _dead and (warn or _prime > 0.0))
		_anim.step(delta)
		_check_stomp()
	if _mat != null:
		_mat.set_shader_parameter("tint", _tint_now())
	_step_dust(delta)
	_step_leaves(delta)
	_step_drips(delta)
	if _fly_view != null:
		_fly_view.glide(delta, _flying_now and not _dead)
	if _skin_view != null:
		_skin_view.advance(delta * (BossAnim.STUN_SPEED if _stunned and not _dead else 1.0))
	if _skin_view != null or _fly_view != null:
		_place_skin()
	if _prime > 0.0:
		_prime = maxf(0.0, _prime - delta)
		var k := 1.0 - _prime / maxf(_prime_sec, 0.01)
		scale = Vector2.ONE * (1.0 + PRIME_SWELL * k * k + sin(_t * 40.0) * 0.02 * k)
		_flash = maxf(_flash, 0.35 + 0.35 * absf(sin(_t * 18.0)))
	_step_shards(delta)
	_step_trail(delta)
	_step_turret(delta)
	_heal = maxf(0.0, _heal - delta / HEAL_SEC)
	_nod = maxf(0.0, _nod - delta / NOD_SEC)
	if _puff >= 0.0:
		_puff += delta
		if _puff >= PUFF_SEC:
			_puff = -1.0
	if armored and not _dead:
		_plates = minf(1.0, _plates + delta / PLATES_IN_SEC)
	if _plate_break >= 0.0:
		_plate_break += delta
		if _plate_break >= BossArt.PLATE_BREAK_SEC:
			_plate_break = -1.0
	if _ball != null:
		if not _dead:
			_ball.position = _centre() # round the figure, bobbing with it
		var alpha := maxf(_shield, _shield_pop * 0.8) if not _vanished else 0.0
		_ball.set_look(1.0 + _shield_pop * 0.12, alpha)
	queue_redraw()
	if _figure != null:
		_figure.queue_redraw()
		_over.queue_redraw()
		_plate_view.queue_redraw()


## The trail puffs in the air behind a flier (global positions, so they stay where it passed).
func _step_trail(delta: float) -> void:
	for p in _trail:
		p["age"] = float(p["age"]) + delta
	_trail = _trail.filter(func(p): return float(p["age"]) < TRAIL_LIFE)
	if not flying or _dead or _vanished or not BossArt.TRAIL.has(art) or not is_inside_tree():
		return
	var at := to_global(Vector2(0, _bob_px() - height * BossArt.trail_from(art)))
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
	if _heal > 0.0 and not _dead: # a heal: a green halo behind the figure (round its heart when drawn)
		var hr := height * (0.6 + 0.12 * (1.0 - _heal))
		var hc := _heart_local() if not _points.is_empty() else Vector2(0, -height * 0.5)
		hc.y = minf(hc.y, _bob_px() - height * 0.45) # round the body, not sunk into the ground (the tree's low heart)
		draw_texture_rect(halo_texture(), Rect2(hc - Vector2(hr, hr), Vector2(hr, hr) * 2.0), false,
			Color(HEAL_GLOW, 0.55 * _heal))
	var glow := leap_glow()
	if glow > 0.0:
		var r := height * (0.62 + 0.08 * glow)
		draw_texture_rect(halo_texture(), Rect2(Vector2(-r, -height * 0.48 - r), Vector2(r, r) * 2.0), false,
			Color(LEAP_GLOW, 0.3 + 0.45 * glow))
	var tint := _tint_now()
	if not _side.is_empty(): # the frames' node draws the figure (the tint through its shader)
		return
	var wobble := Vector2.ZERO
	if _walking and not _dead and not flying:
		wobble = Vector2(0, -absf(sin(_t * 14.0)) * height * 0.03)
	BossArt.draw(self, art, wobble, height, _t if not _dead else 0.0, facing, _flash, {"flying": flying, "lean": lean if not _dead else 0.0,
		"tint": tint, "shards": shards(), "plates": _plates if armored else 0.0, "plates_break": _plate_break, "heal": _heal,
		"puff": _puff, "nod": _nod})
	if _dead and art == "stone_totem" and _death < 1.0: # it crumbles: stones fall off it
		for i in 9:
			var u := _death * 1.6 - i * 0.05
			if u <= 0.0 or u >= 1.0:
				continue
			var x := (fmod(i * 0.618, 1.0) - 0.5) * height * 0.6
			var y0 := -height * (0.2 + 0.7 * fmod(i * 0.37, 1.0))
			var p := Vector2(x * (1.0 + u), minf(y0 + 0.5 * 1400.0 * u * u * 0.5, 2.0))
			draw_circle(p, height * 0.05 * (1.0 - 0.4 * u), Color(CRUMBLE[i % 3], 1.0 - u))


## The red warning tint now (0..1): a bomber warned or primed pulses (BomberModel.pulse()), a leapt
## snowman glows a little.
func _tint_now() -> float:
	var tint := BomberModel.pulse(_t, (bomber or leaper) and not _dead and (warn or _prime > 0.0))
	var glow := leap_glow()
	if glow > 0.0:
		tint = maxf(tint, LEAP_TINT * glow)
	return tint


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
	return height * BossArt.top(art)


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


## Walking along the ground (PlayerView: its x changing): the code art wobbles; drawn frames play
## their walk loop (BossAnim base walk; the crab's crawl, its Cua con), back to the idle when it stops.
func set_walking(on: bool) -> void:
	_walking = on
	if _anim != null:
		_anim.set_walking(on and not _dead)


func walking() -> bool:
	return _walking


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
	if armored and _plates > 0.0: # the plates break off as it dies
		_plate_break = 0.0
		_plates = 0.0
	if not _side.is_empty():
		_dead_t = 0.0
		if _crashes():
			_emit = 0.0
		elif _breaks_apart():
			_rubble.clear()
			_crumbled = false
			_leaf_emit = 0.0
		else:
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
	_flying_now = on
	if _anim != null:
		_anim.set_flying(on)


## Stunned or frozen (a status that skips the turn): the idle slows down and sways.
func set_stunned(on: bool) -> void:
	_stunned = on


## A shot's animation (BossAnim.action_for(): {anim, at, hold}) played once; its duration (0: none).
func play_action(action: Dictionary) -> float:
	if _anim == null or _dead:
		return 0.0
	_turret_fires = true
	return _anim.play(str(action.get("anim", "")), {"at": float(action.get("at", -1.0)), "hold": float(action.get("hold", -1.0)),
		"delay": float(action.get("delay", 0.0))})


## The frame shown: [anim, index] (the death shows the first hurt frame).
func shown_frame() -> Array:
	if _anim == null:
		return []
	if _dead:
		if _breaks_apart() and _anim.has("death"):
			return ["death", mini(int(floor(_dead_t * _anim.fps("death"))), _anim.count("death") - 1)]
		return [BossAnim.HURT if _anim.has(BossAnim.HURT) else "idle", 0]
	return _anim.frame()


## The death's phase now: "crack", "freeze", "shatter" or "gone"; a crash: "wobble", "fall", "boom"
## or "gone"; a crumble: "crack", "crumble", "fade", "gone"; a wither: "wither", "drop", "fade", "gone"
## a cool: "cool", "split", "fade", "gone"; a fade (a drawn minion): "fade", "gone" ("" alive or no frames).
func death_phase() -> String:
	if not _dead or _side.is_empty():
		return ""
	if _fades():
		return "fade" if _death < 1.0 else "gone"
	if _cools():
		var swap := crumble_swap_sec()
		if _dead_t < swap:
			return "cool"
		if _dead_t < swap + COOL_FALL:
			return "split"
		return "fade" if _dead_t < swap + COOL_FALL + COOL_FADE else "gone"
	if _crashes():
		if _dead_t < CRASH_WOBBLE:
			return "wobble"
		if _dead_t < CRASH_WOBBLE + CRASH_FALL:
			return "fall"
		return "boom" if _dead_t < CRASH_SEC else "gone"
	if _withers():
		var swap := crumble_swap_sec()
		if _dead_t < swap:
			return "wither"
		if _dead_t < swap + WITHER_FALL:
			return "drop"
		return "fade" if _dead_t < swap + WITHER_FALL + WITHER_FADE else "gone"
	if _crumbles():
		var swap := crumble_swap_sec()
		if _dead_t < swap:
			return "crack"
		if _dead_t < swap + CRUMBLE_FALL:
			return "crumble"
		return "fade" if _dead_t < swap + CRUMBLE_FALL + CRUMBLE_FADE else "gone"
	if _dead_t < CRACK_SEC:
		return "crack"
	if _dead_t < FREEZE_END:
		return "freeze"
	return "shatter" if _dead_t < FRAMES_DEATH_SEC else "gone"


func shatter_count() -> int:
	return _bits.size()


func _step_death(delta: float) -> void:
	if _crashes():
		_step_crash(delta)
		return
	if _crumbles():
		_step_crumble(delta)
		return
	if _withers():
		_step_wither(delta)
		return
	if _cools():
		_step_cool(delta)
		return
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
	return Vector2(0, _bob_px() - height * 0.5)


## The hover now (px, up negative): a boss with a skinned idle floats by its idle's hover in every
## animation (idle ↔ fly / cast do not jump), the others by BossArt.bob(); still once dead.
func _bob_px() -> float:
	var t := _t if not _dead else 0.0
	if not _skin.is_empty() and not SkinIdle.hovers(_skin): # it stands on its feet (its skin breathes)
		return 0.0
	if not _skin.is_empty():
		var a := _fly_view.glide_state.amount() if _fly_view != null and not _dead else 0.0
		var glide := _fly_view.glide_state.hover() if _fly_view != null and not _dead else 0.0
		return (SkinIdle.hover(t) * (1.0 - a) + glide * a) * height # the glide's smaller bob, blended
	return BossArt.bob(art, t, flying) * height / BossArt.UNIT


## The skinned idle shows now (instead of a frame): the base idle, nothing played over it, alive.
func showing_skin() -> bool:
	return _skin_view != null and not _dead and not _vanished and _anim != null and _anim.playing() == "" and _anim.frame()[0] == "idle" \
		and not showing_glide()


## The skinned glide shows now (instead of the fly frames): flying, or settling after a landing,
## nothing played over it, alive.
func showing_glide() -> bool:
	return _fly_view != null and not _dead and not _vanished and _anim != null and _anim.playing() == "" and _fly_view.glide_state.active()


## The skinned glide's view (null without one).
func glide_view() -> BossSkinView:
	return _fly_view


## The skinned idle on the feet: as tall as the frames' body (`height`), mirrored facing left, the
## hover, the lean and the stun's sway; the shader's flash while it shows.
func _place_skin() -> void:
	var glide_on := showing_glide()
	var idle_on := showing_skin()
	if _fly_view != null:
		_fly_view.visible = glide_on
	if _skin_view != null:
		_skin_view.visible = idle_on
	var v: BossSkinView = _fly_view if glide_on else (_skin_view if idle_on else null)
	if v == null:
		return
	var k := height / v.height()
	v.position = Vector2(0, _bob_px())
	v.rotation = (lean + _anim.sway()) if v == _skin_view else 0.0 # the glide leans by itself
	v.scale = Vector2(k * float(facing), k)
	_mat.set_shader_parameter("flash", _flash * 0.85)
	_mat.set_shader_parameter("icy", 0.0)


## The skinned idle's view (null without one: tests, previews).
func skin_view() -> BossSkinView:
	return _skin_view


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
	if showing_skin() or showing_glide():
		return {}
	var spec: Dictionary = _side["anims"].get(f[0], _side["anims"].values()[0]) # no idle frames: a skinned idle
	var frames: Array = spec["frames"]
	var tex: Texture2D = frames[clampi(int(f[1]), 0, frames.size() - 1)]
	var k := height / float(_side["height"])
	var mirror := float(facing * int(_side["facing"]))
	var alpha := 1.0
	var swell := 1.0
	var icy := 0.0
	var flash := _flash * 0.85
	if _dead and not _breaks_apart() and not _fades():
		icy = 0.5 * clampf(_dead_t / CRACK_SEC, 0.0, 1.0)
		if _dead_t >= CRACK_SEC and _dead_t < FREEZE_END: # the freeze: a white pulse building to the break
			flash = maxf(flash, 0.45 * smoothstep(CRACK_SEC, FREEZE_END, _dead_t))
		if _dead_t >= FREEZE_END:
			var v := clampf((_dead_t - FREEZE_END) / VANISH_SEC, 0.0, 1.0)
			alpha = 1.0 - v
			swell = 1.0 + 0.14 * v
			flash = maxf(flash, 0.6 * (1.0 - v))
	var bob := _bob_px()
	var centre := Vector2(0, -height * 0.5) # a swell grows round the body's centre
	var xform := _turn() * Transform2D(0.0, Vector2(mirror * k, k) * swell, 0.0, Vector2(0, bob) + centre * (1.0 - swell))
	return {"tex": tex, "xform": xform * Transform2D(0.0, -Vector2(_side["pivot"])), "alpha": alpha, "flash": flash, "icy": icy}


## The lean (× BossArt.LEAN) and the stun's sway now, turning round BossArt.LEAN_ABOUT over the
## bobbing feet (local px); none once dead.
func _turn() -> Transform2D:
	if _dead:
		return Transform2D.IDENTITY
	var rot := lean * (BossArt.lean_scale(art) if not _side.is_empty() else 1.0) + (_anim.sway() if _anim != null else 0.0)
	var c := Vector2(0, _bob_px() - height * (BossArt.lean_about(art) if not _side.is_empty() else 0.0))
	return Transform2D(rot, c) * Transform2D(0.0, -c)


## The frame: its texture scaled to `height`, on the feet (plus the bob, the lean or the stun's
## sway), mirrored facing left, through the shader (the hit flash, the death's icy tint).
func _draw_frame() -> void:
	if showing_skin() or showing_glide(): # a skinned view draws her (and owns the shader's flash)
		return
	if _dead and _crashes():
		_draw_crash_body()
		return
	if _dead and _crumbled:
		_draw_rubble()
		return
	var look := _frame_look()
	if look.is_empty() or float(look["alpha"]) <= 0.0:
		_mat.set_shader_parameter("flash", 0.0)
		return
	_mat.set_shader_parameter("flash", look["flash"])
	_mat.set_shader_parameter("icy", look["icy"])
	_figure.draw_set_transform_matrix(look["xform"])
	_figure.draw_texture(look["tex"], Vector2.ZERO, Color(1, 1, 1, look["alpha"]))
	if has_turret() and not _dead:
		var m := _frame_mount()
		var tex: Texture2D = _turret["frames"].get(_tstate, _turret["frames"]["idle"])
		_figure.draw_set_transform_matrix(_art_xform() * Transform2D(deg_to_rad(_aim + m.z), Vector2(m.x, m.y)) \
			* Transform2D(0.0, -Vector2(_turret["pivot"])))
		_figure.draw_texture(tex, Vector2.ZERO, Color(1, 1, 1, look["alpha"]))
	_figure.draw_set_transform(Vector2.ZERO)


## The shatter over the figure: the frost puff, the shards falling, the sparkles.
func _draw_shatter() -> void:
	_draw_turret_fx()
	_draw_dust()
	_leaves.draw(_over)
	_drips.draw(_over)
	if not _dead or _side.is_empty():
		return
	if _crashes():
		_draw_crash_fx()
		return
	if _breaks_apart() or _fades():
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


# ── The crash (Đĩa Bay Thép's death) ────────────────────────────────────────

## Dies by crashing (BossArt.DEATH "crash", drawn from frames).
func _crashes() -> bool:
	return not _side.is_empty() and BossArt.death_of(art) == "crash"


## Body px (texture px from the feet, facing right: the frames' own units) → local px: scaled to
## `height`, mirrored facing left, on the (still) hover bob.
func _crash_local() -> Transform2D:
	var k := height / float(_side["height"])
	return Transform2D(0.0, Vector2(float(facing * int(_side["facing"])) * k, k), 0.0, Vector2(0, _bob_px()))


## The falling body's pose at s into the death (body px → body px): the hurt frame (hull false)
## shakes round the hull's middle, harder and harder; then the hull (hull true: it starts at the
## hurt frame's tilt and knock back) dives nose down, falling and sliding toward its nose.
func _crash_pose(s: float, hull: bool) -> Transform2D:
	var h := float(_side["height"])
	var c := Vector2(0, -h * BossArt.lean_about(art))
	var ang := 0.0
	var off := Vector2.ZERO
	if s < CRASH_WOBBLE:
		var w := s / CRASH_WOBBLE
		ang = sin(s * 26.0) * 0.09 * (0.4 + 0.6 * w)
		off = Vector2(sin(s * 61.0) * 2.5, cos(s * 47.0) * 1.8) * h / 240.0
	else:
		var u := clampf((s - CRASH_WOBBLE) / CRASH_FALL, 0.0, 1.0)
		ang = (HURT_TILT if hull else 0.0) + (CRASH_TUMBLE - HURT_TILT) * u * u + sin(s * 19.0) * 0.05 * (1.0 - u)
		off = (HURT_SHIFT if hull else Vector2.ZERO) + Vector2(CRASH_DRIFT, CRASH_DROP) * h * u * u
	return Transform2D(ang, off + c) * Transform2D(0.0, -c)


## A point of the hull (body px, before the pose), at random: its rim and its middle.
func _hull_point() -> Vector2:
	var h := float(_side["height"])
	return Vector2(randf_range(-0.55, 0.55), -BossArt.lean_about(art) + randf_range(-0.1, 0.12)) * h


## A smoke puff at p (body px); big: the explosion's, rolling out after a short delay.
func _add_smoke(p: Vector2, big: bool, out: Vector2 = Vector2.ZERO) -> void:
	var h := float(_side["height"])
	_smoke.append({"p": p, "v": (Vector2(randf_range(-0.06, 0.06), randf_range(-0.22, -0.12)) + out) * h,
		"r": h * (randf_range(0.15, 0.22) if big else randf_range(0.09, 0.14)), "grow": 1.5 if big else 1.8,
		"age": -randf_range(0.08, 0.22) if big else 0.0, "life": randf_range(0.9, 1.1) if big else randf_range(0.6, 0.9)})


func _add_zap(p: Vector2) -> void:
	_zaps.append({"p": p, "r": float(_side["height"]) * randf_range(0.07, 0.11), "rot": randf() * TAU, "age": 0.0})


func _step_crash(delta: float) -> void:
	var was := _dead_t
	_dead_t += delta
	var s := _dead_t
	_death = minf(1.0, s / CRASH_SEC)
	var h := float(_side["height"])
	var fall_end := CRASH_WOBBLE + CRASH_FALL
	if was < CRASH_WOBBLE and s >= CRASH_WOBBLE: # the dome pops off
		var dome: Dictionary = _parts.get("parts", {}).get("dome", {})
		if not dome.is_empty():
			_dome = {"p": _crash_pose(CRASH_WOBBLE, true) * (Vector2(dome["at"]) + Vector2(dome["size"]) * 0.5),
				"v": Vector2(randf_range(-0.5, -0.25), -1.55) * h, "rot": HURT_TILT, "spin": randf_range(-6.5, -4.0)}
		for i in 5:
			_add_zap(_crash_pose(CRASH_WOBBLE, true) * (Vector2(randf_range(-0.2, 0.2), -0.62) * h))
		var cannon: Dictionary = _parts.get("parts", {}).get("cannon", {})
		if not cannon.is_empty() and has_turret(): # the turret pops off its socket, nose first
			var m := _hurt_mount()
			_cannon = {"p": _crash_pose(CRASH_WOBBLE, false) * Vector2(m.x, m.y), "v": Vector2(randf_range(0.45, 0.7), -1.2) * h,
				"rot": deg_to_rad(_aim + m.z), "spin": randf_range(5.0, 8.0)}
			_add_zap(Vector2(_cannon["p"]))
	if was < fall_end and s >= fall_end:
		_boom()
	_emit -= delta
	if s < fall_end and _emit <= 0.0:
		var pose := _crash_pose(s, s >= CRASH_WOBBLE)
		if s < CRASH_WOBBLE:
			_emit = 0.06
			_add_zap(pose * _hull_point())
			_add_smoke(pose * Vector2(randf_range(-0.45, 0.45) * h, -h * (BossArt.lean_about(art) + 0.06)), false, Vector2(0, -0.15))
		else: # smoke pours out of the open cockpit as it falls, sparks off the rim
			_emit = 0.04
			_add_smoke(pose * Vector2(randf_range(-0.12, 0.12) * h, -h * (BossArt.lean_about(art) + 0.12)), false)
			if randf() < 0.45:
				_add_zap(pose * _hull_point())
	for p in _smoke:
		p["age"] = float(p["age"]) + delta
		p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * delta
	_smoke = _smoke.filter(func(p): return float(p["age"]) < float(p["life"]))
	for z in _zaps:
		z["age"] = float(z["age"]) + delta
	_zaps = _zaps.filter(func(z): return float(z["age"]) < ZAP_SEC)
	var g := 3.2 * h
	for b in _debris:
		b["v"] = Vector2(b["v"]) + Vector2(0, g * delta)
		b["p"] = Vector2(b["p"]) + Vector2(b["v"]) * delta
		b["rot"] = float(b["rot"]) + float(b["spin"]) * delta
	if not _cannon.is_empty():
		_cannon["v"] = Vector2(_cannon["v"]) + Vector2(0, g * delta)
		_cannon["p"] = Vector2(_cannon["p"]) + Vector2(_cannon["v"]) * delta
		_cannon["rot"] = float(_cannon["rot"]) + float(_cannon["spin"]) * delta
	if not _dome.is_empty():
		_dome["v"] = Vector2(_dome["v"]) + Vector2(0, g * delta)
		_dome["p"] = Vector2(_dome["p"]) + Vector2(_dome["v"]) * delta
		_dome["rot"] = float(_dome["rot"]) + float(_dome["spin"]) * delta


## It blows up: steel bits fly out, big smoke rolls, a few last sparks.
func _boom() -> void:
	var h := float(_side["height"])
	_boom_at = _crash_pose(CRASH_WOBBLE + CRASH_FALL, true) * Vector2(0, -h * BossArt.lean_about(art))
	_debris.clear()
	var cols := [BossArt.STEEL, BossArt.STEEL_DARK, BossArt.STEEL_LIGHT, BossArt.HAZARD]
	for i in CRASH_DEBRIS:
		var dir := Vector2.from_angle(randf_range(-PI * 0.95, -PI * 0.05) if i % 3 != 0 else randf_range(0.0, TAU))
		_debris.append({"p": _boom_at + dir * h * 0.08, "v": dir * randf_range(0.9, 2.3) * h, "r": h * randf_range(0.04, 0.08),
			"rot": randf() * TAU, "spin": randf_range(-12.0, 12.0), "col": cols[i % cols.size()]})
	for i in 9:
		var d := Vector2.from_angle(TAU * i / 9.0)
		_add_smoke(_boom_at + d * h * 0.18, true, d * 0.35)
	for i in 6:
		_add_zap(_boom_at + Vector2(randf_range(-0.4, 0.4), randf_range(-0.35, 0.25)) * h)


## The crash's body through the shader: the shaking hurt frame, then the hull (dome off) diving;
## the popped dome tumbling away; charring as it goes, a white pop when the dome flies.
func _draw_crash_body() -> void:
	var s := _dead_t
	var fall_end := CRASH_WOBBLE + CRASH_FALL
	var flash := _flash * 0.85
	if s < CRASH_WOBBLE:
		flash = maxf(flash, 0.3 * maxf(0.0, sin(s * 38.0)) * s / CRASH_WOBBLE)
	else:
		flash = maxf(flash, 0.8 * clampf(1.0 - (s - CRASH_WOBBLE) / 0.15, 0.0, 1.0))
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("icy", 0.6 * clampf(s / fall_end, 0.0, 1.0))
	var l := _crash_local()
	var hull: Dictionary = _parts.get("parts", {}).get("hull", {})
	if s < fall_end:
		if s < CRASH_WOBBLE or hull.is_empty() or _dome.is_empty():
			var hurt: Array = _side["anims"].get(BossAnim.HURT, _side["anims"].values()[0])["frames"]
			_figure.draw_set_transform_matrix(l * _crash_pose(s, false) * Transform2D(0.0, -Vector2(_side["pivot"])))
			_figure.draw_texture(hurt[0], Vector2.ZERO)
			if has_turret() and s < CRASH_WOBBLE: # still on its socket while it shakes
				var m := _hurt_mount()
				_figure.draw_set_transform_matrix(l * _crash_pose(s, false) * Transform2D(deg_to_rad(_aim + m.z), Vector2(m.x, m.y)) \
					* Transform2D(0.0, -Vector2(_turret["pivot"])))
				_figure.draw_texture(_turret["frames"]["idle"], Vector2.ZERO)
		else:
			_figure.draw_set_transform_matrix(l * _crash_pose(s, true) * Transform2D(0.0, Vector2(hull["at"])))
			_figure.draw_texture(hull["texture"], Vector2.ZERO)
	if not _cannon.is_empty():
		var cannon: Dictionary = _parts["parts"]["cannon"]
		var ca := clampf((CRASH_SEC - s) / 0.45, 0.0, 1.0)
		if ca > 0.0:
			_figure.draw_set_transform_matrix(l * Transform2D(float(_cannon["rot"]), Vector2(_cannon["p"])) \
				* Transform2D(0.0, -Vector2(cannon.get("pivot", Vector2(cannon["size"]) * 0.5))))
			_figure.draw_texture(cannon["texture"], Vector2.ZERO, Color(1, 1, 1, ca))
	if not _dome.is_empty():
		var dome: Dictionary = _parts["parts"]["dome"]
		var a := clampf((CRASH_SEC - s) / 0.45, 0.0, 1.0)
		if a > 0.0:
			_figure.draw_set_transform_matrix(l * Transform2D(float(_dome["rot"]), Vector2(_dome["p"])) \
				* Transform2D(0.0, -Vector2(dome["size"]) * 0.5))
			_figure.draw_texture(dome["texture"], Vector2.ZERO, Color(1, 1, 1, a))
	_figure.draw_set_transform(Vector2.ZERO)


## The crash's smoke (over the figure, under the fire; body px): soft dark puffs growing and rising.
func _draw_smoke() -> void:
	for p in _smoke:
		if float(p["age"]) <= 0.0:
			continue
		var k := float(p["age"]) / float(p["life"])
		var r := float(p["r"]) * (1.0 + float(p["grow"]) * k)
		var a := 0.75 * (1.0 - k) * minf(1.0, float(p["age"]) / 0.08)
		_over.draw_texture_rect(halo_texture(), Rect2(Vector2(p["p"]) - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(SMOKE.lerp(Color(0.36, 0.35, 0.38), k), a))


## Over the figure: the explosion (fire, fireballs, the shock ring), the steel debris and the sparks.
func _draw_crash_fx() -> void:
	var h := float(_side["height"])
	var hs := h / 240.0
	var s := _dead_t
	_over.draw_set_transform_matrix(_crash_local())
	var b := s - CRASH_WOBBLE - CRASH_FALL
	if b >= 0.0: # the fire under the smoke it makes
		var kb := clampf(b / 0.55, 0.0, 1.0)
		var out := 1.0 - (1.0 - kb) * (1.0 - kb)
		var c := _boom_at
		for layer in [[FIRE[2], 0.6, 0.8], [FIRE[1], 0.5, 0.65], [FIRE[0], 0.34, 0.3]]:
			var r: float = h * (float(layer[1]) + float(layer[2]) * out)
			var a := (1.0 - kb) * (1.0 - kb if layer[0] == FIRE[0] else 1.0)
			for _n in 2: # twice: a dense fireball, not a faint glow
				_over.draw_texture_rect(halo_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(layer[0], a))
		for i in 8:
			var at := c + Vector2.from_angle(TAU * i / 8.0 + 0.4) * h * (0.3 + 0.12 * (i % 2)) * out
			var r := h * (0.2 if i % 2 == 0 else 0.15) * (1.0 - 0.45 * kb)
			_over.draw_texture_rect(halo_texture(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false,
				Color(FIRE[1 + i % 2], (1.0 - kb)))
	_draw_smoke()
	if b >= 0.0:
		var c := _boom_at
		var kr := clampf(b / 0.32, 0.0, 1.0)
		if kr < 1.0:
			_over.draw_arc(c, h * (0.2 + 0.9 * kr), 0.0, TAU, 48, Color(1.0, 0.86, 0.6, 0.85 * (1.0 - kr)), (10.0 * (1.0 - kr) + 1.0) * hs, true)
		var fade := clampf((CRASH_SEC - s) / 0.35, 0.0, 1.0)
		for d in _debris:
			var r := float(d["r"])
			var pts := PackedVector2Array()
			for q in [Vector2(-1.0, -0.6), Vector2(1.0, -0.4), Vector2(0.7, 0.65), Vector2(-0.8, 0.5)]:
				pts.append(Vector2(d["p"]) + (q * r).rotated(float(d["rot"])))
			_over.draw_colored_polygon(pts, Color(d["col"], fade))
			pts.append(pts[0])
			_over.draw_polyline(pts, Color(BossArt.OUT, fade), 2.0 * hs, true)
	for z in _zaps:
		var k := float(z["age"]) / ZAP_SEC
		var r := float(z["r"]) * (0.5 + 0.8 * k)
		var col := Color(1.0, 0.9, 0.5, 1.0 - k)
		for i in 5:
			var d := Vector2.from_angle(float(z["rot"]) + TAU * i / 5.0)
			_over.draw_line(Vector2(z["p"]) + d * r * 0.3, Vector2(z["p"]) + d * r, col, 4.5 * hs, true)
		_over.draw_circle(Vector2(z["p"]), r * 0.3 * (1.0 - k), Color(1, 1, 1, 1.0 - k))
	_over.draw_set_transform(Vector2.ZERO)


## A turret points along an aim angle (degrees, the Shoot convention: 0 right, 90 up); others: nothing.
func aim(angle: float) -> void:
	if has_turret() and not is_nan(angle):
		var a := deg_to_rad(angle)
		aim_turret_at(turret_pivot() + Vector2(cos(a), -sin(a)) * 300.0)


func draw_gun() -> void:
	pass


func clear_aim() -> void:
	if has_turret():
		rest_turret()


func gun_state() -> String:
	return "holstered"


## The shot leaves at once (no gun to draw): a small flash (a totem nods), no wait.
func shoot(_with_gun: bool = true) -> float:
	_flash = maxf(_flash, 0.35)
	if art == "stone_totem":
		_nod = 1.0
	return 0.0


## Boss v4: the stone plates of its totems' armour go on (pop on one after another) or break off
## (animate: they fly off and fade; else gone at once).
func set_armored(on: bool, animate: bool = true) -> void:
	if on == armored:
		return
	armored = on
	if on:
		_plate_break = -1.0
		_plates = 0.0 if animate else 1.0
	else:
		_plate_break = 0.0 if animate and _plates > 0.0 else -1.0
		_plates = 0.0


## The plates shown now (0..1; tests).
func plates_shown() -> float:
	return _plates if armored else 0.0


## The plates are flying off (tests).
func plates_breaking() -> bool:
	return _plate_break >= 0.0


## A heal (a drain, a regen): the green glow behind the figure, its heart lit.
func heal_glow() -> void:
	_heal = 1.0


func heal_shown() -> float:
	return _heal


## A poison mushroom's spore puff: squashed, then sprung up.
func puff() -> void:
	_puff = 0.0


func puffing() -> bool:
	return _puff >= 0.0


## The heart point (global): where drained life flows in (BossArt.HEART; drawn with points: the
## shown frame's heart).
func heart_position() -> Vector2:
	return to_global(_heart_local())


func _heart_local() -> Vector2:
	var fp := _frame_points()
	if fp.get("heart") is Vector2:
		return _unit_xform() * Vector2(fp["heart"])
	return BossArt.heart(art, height, facing) + Vector2(0, _bob_px())


func muzzle_position() -> Vector2:
	if has_turret():
		return to_global(_art_xform() * _tip_art("mid", _aim))
	var f := shown_frame()
	var fp := _frame_points()
	var follow: Dictionary = BossArt.MUZZLE_FOLLOW.get(art, {})
	if not f.is_empty() and not follow.is_empty() and str(f[0]) == str(follow["anim"]) and fp.get(str(follow["point"])) is Vector2:
		return to_global(_unit_xform() * Vector2(fp[str(follow["point"])])) # the giant's throwing knuckles, the tree's canopy
	var m := BossArt.muzzle(art, height, facing) + Vector2(0, _bob_px())
	return to_global(_turn() * m)


func fire_muzzle_position() -> Vector2:
	return muzzle_position()


# ── The turret (round 2: Đĩa Bay Thép's twin cannon) ─────────────────────────

## Drawn with a turret of its own (Art.boss_turret(), on drawn frames).
func has_turret() -> bool:
	return not _turret.is_empty() and not _side.is_empty()


## The art frame (texture px from the feet, facing right, y down) → local px: scaled to `height`,
## mirrored facing left, on the hover bob, turned by the lean / sway (the frame's own transform).
func _art_xform() -> Transform2D:
	var k := height / float(_side["height"])
	return _turn() * Transform2D(0.0, Vector2(float(facing * int(_side["facing"])) * k, k), 0.0, Vector2(0, _bob_px()))


## The turret's mount on the body frame shown: Vector3(x, y, turn degrees) (art frame).
func _frame_mount() -> Vector3:
	var f := shown_frame()
	if not f.is_empty():
		var list = _turret["body_frames"].get(str(f[0]))
		if list is Array and int(f[1]) >= 0 and int(f[1]) < list.size():
			return list[int(f[1])]
	var m: Vector2 = _turret["mount"]
	return Vector3(m.x, m.y, 0.0)


## The mount on the first hurt frame (the crash shakes that frame).
func _hurt_mount() -> Vector3:
	var list = _turret["body_frames"].get(BossAnim.HURT)
	if list is Array and not list.is_empty():
		return list[0]
	var m: Vector2 = _turret["mount"]
	return Vector3(m.x, m.y, 0.0)


## A muzzle (turret.json tips: mid, upper, lower) at turret angle `a` (art frame).
func _tip_art(key: String, a: float) -> Vector2:
	var m := _frame_mount()
	return TurretModel.tip(Vector2(m.x, m.y), a + m.z, _turret["tips"].get(key, Vector2.ZERO))


## The top of the figure (global): its dome's top (a flare shot up leaves from there).
func top_position() -> Vector2:
	if _side.is_empty():
		return to_global(_turn() * Vector2(0, _bob_px() - height))
	return to_global(_art_xform() * Vector2(0, -float(_side["height"]) * 0.97))


## The turret angle now (degrees, relative to the body; tests).
func turret_angle() -> float:
	return _aim


## The angle it is turning to.
func turret_goal() -> float:
	return _aim_to


## The turret picture shown (idle, charge_0, charge_1, hot, recoil_0, recoil_1).
func turret_state() -> String:
	return _tstate


## The pivot (global).
func turret_pivot() -> Vector2:
	var m := _frame_mount()
	return to_global(_art_xform() * Vector2(m.x, m.y))


## The turret angle that points it at `p` (global), clamped.
func _aim_for(p: Vector2) -> float:
	var m := _frame_mount()
	var r: Vector2 = _turret["range"]
	return TurretModel.aim_deg(Vector2(m.x, m.y), _art_xform().affine_inverse() * to_local(p), m.z, r.x, r.y)


## Turns the turret onto `p` (global) over `sec` s (0: at once).
func aim_turret_at(p: Vector2, sec: float = TurretModel.TURN_SEC) -> void:
	if not has_turret() or _dead:
		return
	_turn_to(_aim_for(p), sec)


## Where its mid tip will be once aimed at `p` (global; the bob as now).
func tip_toward(p: Vector2) -> Vector2:
	if not has_turret():
		return muzzle_position()
	return to_global(_art_xform() * _tip_art("mid", _aim_for(p)))


## Back to the rest angle (toward the side it faces).
func rest_turret(sec: float = TurretModel.TURN_SEC * 1.5) -> void:
	if has_turret():
		_turn_to(float(_turret["rest"]), sec)


func _turn_to(a: float, sec: float) -> void:
	_aim_from = _aim
	_aim_to = a
	_aim_sec = sec
	_aim_k = 0.0 if sec > 0.0 else 1.0
	if sec <= 0.0:
		_aim = a


## A boss shot's turret plan (TurretModel.cues(), times from now = the replay's start): it turns
## TURN_SEC before each aim's moment, holds hot over the beams, rests after.
func play_turret(plan: Dictionary) -> void:
	if not has_turret():
		return
	_plan = plan.duplicate(true)
	_plan_t = 0.0
	_turret_fires = not (plan.get("aims", []) as Array).is_empty() # Bom mù's flare leaves from the dome: no recoil


## The plan's hot window is on (tests).
func turret_hot() -> bool:
	return _plan_t >= 0.0 and float(_plan.get("hot_from", -1.0)) >= 0.0 and _plan_t >= float(_plan["hot_from"]) - 0.1 \
		and _plan_t < float(_plan.get("hot_until", -1.0))


func _step_turret(delta: float) -> void:
	for p in _tip_smoke:
		p["age"] = float(p["age"]) + delta
		p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * delta
	_tip_smoke = _tip_smoke.filter(func(p): return float(p["age"]) < float(p["life"]))
	_tip_flash = maxf(0.0, _tip_flash - delta)
	if not has_turret() or _dead:
		return
	var hot := turret_hot()
	if _plan_t >= 0.0:
		_plan_t += delta
		var aims: Array = _plan.get("aims", [])
		while not aims.is_empty() and _plan_t >= float(aims[0]["t"]) - TurretModel.TURN_SEC:
			var a: Dictionary = aims.pop_front()
			aim_turret_at(a["at"], clampf(float(a["t"]) - _plan_t + delta, 0.05, TurretModel.TURN_SEC))
		var rest := float(_plan.get("rest", -1.0))
		if aims.is_empty() and (rest < 0.0 or _plan_t >= rest):
			if rest >= 0.0:
				rest_turret()
			_plan_t = -1.0
	if _aim_k < 1.0:
		_aim_k = minf(1.0, _aim_k + delta / maxf(_aim_sec, 0.001))
		_aim = TurretModel.eased(_aim_from, _aim_to, _aim_k)
	var f := shown_frame()
	var state := "idle"
	if not f.is_empty():
		var peak := int(_side["anims"].get(str(f[0]), {}).get("peak", -1))
		state = TurretModel.state_for(str(f[0]), int(f[1]), peak, hot, _turret["frames"]) if _turret_fires or hot else "idle"
	if state == "recoil_0" and _tstate != "recoil_0": # the shot leaves: a flash at both muzzles
		_tip_flash = TIP_FLASH_SEC
		for key in ["upper", "lower"]:
			for i in 3:
				_add_tip_smoke(key, 1.0)
	if state == "recoil_1":
		_tip_emit -= delta
		if _tip_emit <= 0.0:
			_tip_emit = TIP_SMOKE_EVERY
			_add_tip_smoke("upper" if randf() < 0.5 else "lower", 0.6)
	_tstate = state


## A smoke puff off a muzzle (global, drifting out along the barrel and up).
func _add_tip_smoke(key: String, strength: float) -> void:
	var at := to_global(_art_xform() * _tip_art(key, _aim))
	var dir := (at - turret_pivot()).normalized()
	var k := height / 240.0
	_tip_smoke.append({"p": at, "v": dir * randf_range(30.0, 80.0) * strength * k + Vector2(randf_range(-10, 10), -randf_range(25.0, 45.0)) * k,
		"r": randf_range(7.0, 12.0) * k * (0.6 + 0.4 * strength), "age": 0.0, "life": TIP_SMOKE_LIFE * randf_range(0.7, 1.1)})


## The muzzle flash at both tips (where the recoiled barrels' mouths are) and the smoke off them.
func _draw_turret_fx() -> void:
	for p in _tip_smoke:
		var k := float(p["age"]) / float(p["life"])
		var r := float(p["r"]) * (1.0 + 1.6 * k)
		var at := _over.to_local(p["p"])
		_over.draw_texture_rect(halo_texture(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(Color(0.42, 0.4, 0.42).lerp(Color(0.72, 0.72, 0.74), k), 0.6 * (1.0 - k)))
	if _tip_flash <= 0.0 or not has_turret() or _dead:
		return
	var u := _tip_flash / TIP_FLASH_SEC # 1 → 0
	var back := float(_turret["recoil"].get("recoil_0", 0.0))
	var hk := height / float(_side["height"])
	for key in ["upper", "lower"]:
		var at := _over.to_local(to_global(_art_xform() * _tip_art(key, _aim)))
		var dir := (at - _over.to_local(turret_pivot())).normalized()
		at -= dir * back * hk
		var r := height * 0.16 * (0.6 + 0.4 * u)
		_over.draw_texture_rect(halo_texture(), Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.62, 0.2, 0.9 * u))
		var c := r * 0.45
		_over.draw_texture_rect(halo_texture(), Rect2(at - Vector2(c, c), Vector2(c, c) * 2.0), false, Color(1.0, 0.97, 0.85, u))
		var side := Vector2(-dir.y, dir.x)
		var tip := at + dir * r * 1.5
		_over.draw_colored_polygon(PackedVector2Array([at + side * r * 0.22, tip, at - side * r * 0.22]), Color(1.0, 0.9, 0.55, u))


# ── Khổng Lồ Đá's drawn art: points, plates, stomp, crumble ─────────────────

## The unit frame (BossArt: the body 100 tall, the feet at the origin, facing right) → local px: as
## the frames are drawn (scaled to `height`, mirrored facing left, the bob, the lean / sway).
func _unit_xform() -> Transform2D:
	var k := height / BossArt.UNIT
	var mirror := float(facing * (int(_side["facing"]) if not _side.is_empty() else 1))
	return _turn() * Transform2D(0.0, Vector2(mirror * k, k), 0.0, Vector2(0, _bob_px()))


## The shown frame's points (Art.boss_points(), the unit frame): {name: Vector2 / Vector3}; {} none.
func _frame_points() -> Dictionary:
	if _points.is_empty():
		return {}
	var f := shown_frame()
	if f.is_empty():
		return {}
	var list = _points["frames"].get(str(f[0]))
	if list is Array and not list.is_empty():
		return list[clampi(int(f[1]), 0, list.size() - 1)]
	return {}


## Each FRAME_PLATES' pose now (unit frame): by its joint in the shown frame, or on the skinned idle
## by the bone carrying that joint (SKIN_BONE).
func plate_poses() -> Array:
	var out: Array = []
	var on_skin := showing_skin()
	var fp := _frame_points()
	var rest: Dictionary = _points.get("rest", {})
	for pl in BossArt.FRAME_PLATES:
		var j := str(pl["joint"])
		if on_skin:
			var k := _skin_view.height() / BossArt.UNIT # unit → skin px
			var m := _skin_view.bone_motion(str(SKIN_BONE.get(j, "torso")))
			out.append(Transform2D(0.0, Vector2.ONE / k, 0.0, Vector2.ZERO) * m * Transform2D(0.0, Vector2.ONE * k, 0.0, Vector2.ZERO))
		else:
			out.append(BossArt.frame_plate_pose(fp.get(j), rest.get(j)))
	return out


## The plates over the frame / the skin (popping on, breaking off), the heart lit by a heal.
func _draw_plates() -> void:
	if _vanished or _points.is_empty():
		return
	var on := armored and _plates > 0.0 and not _dead
	if on or _plate_break >= 0.0:
		BossArt.draw_frame_plates(_plate_view, _unit_xform(), height, _t, plate_poses(), _plates if on else 0.0, _plate_break, _flash)
	if _heal > 0.0 and not _dead:
		var r := height * 0.09 * (0.8 + 0.4 * _heal)
		var c := _heart_local()
		_plate_view.draw_texture_rect(halo_texture(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(BossArt.heart_light(art), 0.85 * _heal))


## The stomp's peak frame just showed (BossArt.STOMP): the dust and the shockwave at the foot; a
## spout's (BossArt.SPOUT): the lava globs out of its point.
func _check_stomp() -> void:
	var f := _anim.frame()
	if f != _last_frame and not _dead:
		if _at_peak(f, BossArt.STOMP.get(art, {})):
			stomp_fx()
		if _at_peak(f, BossArt.SPOUT.get(art, {})):
			spout_fx()
	_last_frame = f


## The frame f is the peak of the animation `cfg` names, played now.
func _at_peak(f: Array, cfg: Dictionary) -> bool:
	return not cfg.is_empty() and _anim.playing() == str(cfg["anim"]) and str(f[0]) == str(cfg["anim"]) \
		and int(f[1]) == int(_side["anims"].get(str(cfg["anim"]), {}).get("peak", -1))


## Where the stomp / slam hits the ground (global; Vector2.INF: no such point): BossArt.STOMP's
## foot on the feet, facing applied (Cua Dung Nham's claw_slam: the game's shockwave opens its slam
## ring there).
func slam_point() -> Vector2:
	var st: Dictionary = BossArt.STOMP.get(art, {})
	if st.is_empty() or _side.is_empty():
		return Vector2.INF
	return to_global(_unit_xform() * Vector2(st.get("foot", Vector2.ZERO)))


## The stomp lands: a dust burst at the foot, pebbles thrown up (embers with them: the crab's lava),
## the ground's shockwave ring (unless ring false: the game's own slam ring opens there).
func stomp_fx() -> void:
	var st: Dictionary = BossArt.STOMP.get(art, {})
	var foot := _unit_xform() * Vector2(st.get("foot", Vector2.ZERO))
	if bool(st.get("ring", true)):
		var ring := ShockwaveFx.new()
		ring.name = "StompRing"
		ring.setup({"origin": foot, "t0": 0.0, "left": [], "right": []}, null, BossArt.accent(art))
		ring.release()
		add_child(ring)
		move_child(ring, 0) # on the ground, behind the figure
	var stones: Array = st.get("pebbles", STONE)
	if bool(st.get("embers", false)):
		for i in STOMP_PEBBLES:
			var a := -PI * 0.5 + (randf() - 0.5) * 2.0
			_pebbles.append({"p": foot + Vector2(0, -0.02 * height), "v": Vector2.from_angle(a) * height * randf_range(1.0, 2.0),
				"r": height * randf_range(0.008, 0.014), "rot": 0.0, "spin": 0.0, "age": 0.0, "life": randf_range(0.5, 0.8),
				"col": EMBERS[i % EMBERS.size()], "ground": foot.y, "ember": true})
	for i in STOMP_PUFFS:
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread := 0.3 + 0.7 * float(i) / STOMP_PUFFS
		_dust.append({"p": foot + Vector2(side * spread * 0.1 * height, -0.02 * height), "v": Vector2(side * spread * 1.1, -0.18 - 0.2 * spread) * height,
			"r": height * (0.07 + 0.04 * spread), "grow": 1.6, "age": 0.0, "life": 0.75 + 0.2 * spread})
	for i in STOMP_PEBBLES:
		var a := -PI * 0.5 + (float(i) / (STOMP_PEBBLES - 1) - 0.5) * 1.8
		_pebbles.append({"p": foot + Vector2(0, -0.01 * height), "v": Vector2.from_angle(a) * height * randf_range(1.4, 2.2), "r": height * randf_range(0.012, 0.022),
			"rot": randf() * TAU, "spin": randf_range(-10.0, 10.0), "age": 0.0, "life": 0.9, "col": stones[i % stones.size()], "ground": foot.y})


## The spout's peak (BossArt.SPOUT): lava globs shoot up out of the frame's point (the crab's shell
## top: its bombs leave there, falling from the sky after), a hot flash puff over it.
func spout_fx() -> void:
	var sp: Dictionary = BossArt.SPOUT.get(art, {})
	var fp := _frame_points()
	if sp.is_empty() or not fp.get(str(sp["point"])) is Vector2:
		return
	var at := _unit_xform() * Vector2(fp[str(sp["point"])])
	for i in int(sp.get("globs", 8)):
		var v := Vector2(randf_range(-0.45, 0.45), -randf_range(2.2, 3.4)) * height
		_drips.add(at + Vector2(randf_range(-0.03, 0.03) * height, 0), height * randf_range(0.022, 0.034), INF, v, randf_range(0.7, 1.0))
	_dust.append({"p": at, "v": Vector2(0, -0.3) * height, "r": height * 0.08, "grow": 1.6, "age": 0.0, "life": 0.45,
		"col": LavaDrips.LAVA})


## The lava drops now and then off the drips' tips (BossArt.DRIPS: alive, not hidden), all moving on.
func _step_drips(delta: float) -> void:
	_drips.step(delta, height)
	var cfg: Dictionary = BossArt.DRIPS.get(art, {})
	if cfg.is_empty() or _side.is_empty() or _dead or _vanished:
		return
	_drip_in -= delta
	if _drip_in > 0.0:
		return
	var every: Vector2 = cfg["every"]
	_drip_in = randf_range(every.x, every.y)
	var fp := _frame_points()
	var tips: Array = (cfg["tips"] as Array).filter(func(k): return fp.get(str(k)) is Vector2)
	if tips.is_empty():
		return
	var tip: Vector2 = fp[str(tips[randi() % tips.size()])]
	var r := float(cfg.get("r", 1.0)) * height / BossArt.UNIT * randf_range(0.85, 1.2)
	_drips.add(_unit_xform() * tip + Vector2(0, r * 0.6), r, randf_range(0.0, 0.025) * height)


## The lava drops (tests): their count.
func drip_count() -> int:
	return _drips.count()


## The lava drops (tests).
func drips() -> LavaDrips:
	return _drips


## The dust puffs and the pebbles (local px): puffs drift and slow down, grow and fade; pebbles fall,
## bounce once off their ground, fade.
func _step_dust(delta: float) -> void:
	if _dust.is_empty() and _pebbles.is_empty():
		return
	for d in _dust:
		d["age"] = float(d["age"]) + delta
		d["v"] = Vector2(d["v"]) * exp(-float(d.get("drag", 3.0)) * delta)
		d["p"] = Vector2(d["p"]) + Vector2(d["v"]) * delta
	_dust = _dust.filter(func(d): return float(d["age"]) < float(d["life"]))
	var g := RUBBLE_GRAVITY * height
	for p in _pebbles:
		p["age"] = float(p["age"]) + delta
		p["v"] = Vector2(p["v"]) + Vector2(0, g * delta)
		p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * delta
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		if Vector2(p["p"]).y > float(p["ground"]) and Vector2(p["v"]).y > 0.0:
			p["p"] = Vector2(Vector2(p["p"]).x, float(p["ground"]))
			p["v"] = Vector2(Vector2(p["v"]).x * 0.5, -Vector2(p["v"]).y * 0.3)
			p["spin"] = float(p["spin"]) * 0.5
	_pebbles = _pebbles.filter(func(p): return float(p["age"]) < float(p["life"]))


func _draw_dust() -> void:
	for d in _dust:
		var k := float(d["age"]) / float(d["life"])
		var r := float(d["r"]) * (1.0 + float(d["grow"]) * k)
		_over.draw_texture_rect(halo_texture(), Rect2(Vector2(d["p"]) - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(d.get("col", DUST), 0.85 * (1.0 - k) * minf(1.0, float(d["age"]) / 0.1 + 0.3)))
	for p in _pebbles:
		var k := float(p["age"]) / float(p["life"])
		var r := float(p["r"])
		var col: Color = p["col"]
		if bool(p.get("ember", false)): # a lava spark: a hot dot with a glow
			var a := clampf((1.0 - k) * 2.0, 0.0, 1.0)
			_over.draw_set_transform(Vector2.ZERO)
			_over.draw_circle(p["p"], r * 2.4, Color(col, 0.25 * a))
			_over.draw_circle(p["p"], r, Color(col.lightened(0.3), a))
			continue
		_over.draw_set_transform(p["p"], float(p["rot"]), Vector2.ONE)
		_over.draw_colored_polygon(PackedVector2Array([Vector2(-r, -r * 0.6), Vector2(r * 0.4, -r), Vector2(r, r * 0.2), Vector2(-r * 0.2, r)]),
			Color(col, clampf((1.0 - k) * 3.0, 0.0, 1.0)))
	if not _pebbles.is_empty():
		_over.draw_set_transform(Vector2.ZERO)


## Dies crumbling (BossArt.DEATH "crumble", drawn from frames).
func _crumbles() -> bool:
	return not _side.is_empty() and BossArt.death_of(art) == "crumble"


## s into the death the parts take over (CRUMBLE_SWAP_FRAME of the death animation; a wither:
## WITHER_SWAP_FRAME, WITHER_HOLD later).
func crumble_swap_sec() -> float:
	if _anim == null or not _anim.has("death"):
		return 0.0
	if _withers(): # Mộc Tinh: after its last death frame showed a moment
		return float(mini(WITHER_SWAP_FRAME, _anim.count("death") - 1)) / _anim.fps("death") + WITHER_HOLD
	if _cools(): # Cua Dung Nham: the same after its last death frame
		return float(mini(COOL_SWAP_FRAME, _anim.count("death") - 1)) / _anim.fps("death") + COOL_HOLD
	return float(mini(CRUMBLE_SWAP_FRAME, _anim.count("death") - 1)) / _anim.fps("death")


## The crumble's parts (tests): their count.
func rubble_count() -> int:
	return _rubble.size()


## The parts (tests): [{c (body px centre), v, rot, delay, ground, size, z}].
func rubble() -> Array:
	return _rubble


func _step_crumble(delta: float) -> void:
	_dead_t += delta
	var swap := crumble_swap_sec()
	_death = minf(1.0, _dead_t / (swap + CRUMBLE_FALL + CRUMBLE_FADE))
	if not _crumbled and _dead_t >= swap:
		_crumble()
	if not _crumbled:
		return
	_fall_parts(delta, _dead_t - swap, 1.0, RUBBLE_BOUNCE)


## The loose parts fall (gravity × g_scale), spin, bounce (bounce of their speed back up) and slide
## to a stop on their ground, a dust puff under a heavy landing; anchored ones stay (a wither's trunk).
func _fall_parts(delta: float, since: float, g_scale: float, bounce: float) -> void:
	var h := float(_side["height"])
	var g := RUBBLE_GRAVITY * h * g_scale
	var to_local := _crash_local()
	for r in _rubble:
		if since < float(r["delay"]) or bool(r.get("anchored", false)):
			continue
		var v: Vector2 = r["v"]
		v.y += g * delta
		var c: Vector2 = Vector2(r["c"]) + v * delta
		var rot := float(r["rot"]) + float(r["spin"]) * delta
		var sz: Vector2 = r["size"]
		var hh := 0.5 * (absf(sz.x * sin(rot)) + absf(sz.y * cos(rot))) * 0.8 # its half height turned (the corners are clear)
		var ground := float(r["ground"])
		if c.y + hh >= ground:
			c.y = ground - hh
			if v.y > 0.0:
				if v.y > h * 0.9: # a heavy landing: a dust puff
					var at := to_local * Vector2(c.x, ground)
					_dust.append({"p": at, "v": Vector2(randf_range(-0.2, 0.2), -0.12) * height, "r": height * clampf(sz.x / h, 0.08, 0.2) * 0.6,
						"grow": 1.2, "age": 0.0, "life": 0.7})
				v.y = -v.y * bounce if v.y > h * 0.5 else 0.0
				v.x *= 0.5
				r["spin"] = float(r["spin"]) * 0.45
			v.x *= exp(-5.0 * delta) # it slides to a stop
			r["spin"] = float(r["spin"]) * exp(-4.0 * delta)
		r["v"] = v
		r["c"] = c
		r["rot"] = rot


## The parts take over from the death frame: placed as it, pushed out from the heart, a dust burst
## and pebbles.
func _crumble() -> void:
	_crumbled = true
	_rubble.clear()
	var parts := Art.boss_parts(art)
	var h := float(_side["height"])
	if parts.is_empty():
		return
	var ph := h / float(parts["height"])
	var fp := _frame_points()
	var heart: Vector2 = (Vector2(fp["heart"]) if fp.get("heart") is Vector2 else Vector2(BossArt.HEART.get(art, Vector2(0, -50)))) * h / BossArt.UNIT
	var top_z := 1
	for name in parts["parts"]:
		top_z = maxi(top_z, int(parts["parts"][name].get("z", 0)))
	for name in parts["parts"]:
		var pt: Dictionary = parts["parts"][name]
		var sz: Vector2 = Vector2(pt["size"]) * ph
		var c: Vector2 = Vector2(pt["at"]) * ph + sz / 2.0
		var dir := (c - heart).normalized() if c.distance_to(heart) > 1.0 else Vector2.UP
		var push := randf_range(RUBBLE_PUSH.x, RUBBLE_PUSH.y) * h
		var v := Vector2(dir.x * push, -absf(dir.y) * push * 0.3 - 0.15 * h)
		var spin := randf_range(-2.5, 2.5)
		var delay := 0.0
		var n := str(name)
		if n.begins_with("horn"):
			delay = HORN_DELAY
			v = Vector2(signf(c.x - heart.x) * 0.32 * h, -0.45 * h) # tumbling off
			spin = signf(c.x - heart.x) * randf_range(6.0, 8.0)
		elif n == "helmet":
			delay = HELMET_DELAY
		var z := int(pt.get("z", 0))
		_rubble.append({"name": n, "tex": pt["texture"], "size": sz, "z": z, "c": c, "v": v, "rot": 0.0, "spin": spin, "delay": delay,
			"ground": h * (0.005 + 0.035 * float(z) / float(top_z))})
	_rubble.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))
	var to_local := _crash_local()
	for i in 8: # the dust burst round the lower body
		var at := to_local * Vector2(randf_range(-0.3, 0.3) * h, -randf_range(0.02, 0.4) * h)
		_dust.append({"p": at, "v": Vector2(randf_range(-0.4, 0.4), -randf_range(0.05, 0.2)) * height, "r": height * randf_range(0.08, 0.14),
			"grow": 1.4, "age": 0.0, "life": randf_range(0.9, 1.3)})
	for i in RUBBLE_PEBBLES:
		var from := Vector2(randf_range(-0.3, 0.3), -randf_range(0.2, 0.7)) * height
		var dir := (from - _unit_xform() * (heart * BossArt.UNIT / h)).normalized()
		_pebbles.append({"p": from, "v": (dir * randf_range(0.5, 1.2) + Vector2(0, -0.6)) * height, "r": height * randf_range(0.01, 0.025),
			"rot": randf() * TAU, "spin": randf_range(-10.0, 10.0), "age": 0.0, "life": randf_range(1.0, 1.6), "col": STONE[i % STONE.size()],
			"ground": randf_range(0.0, 0.03) * height})


## The parts on the ground and falling (in z order), fading at the end.
func _draw_rubble() -> void:
	var fall := WITHER_FALL if _withers() else (COOL_FALL if _cools() else CRUMBLE_FALL)
	var fade_sec := WITHER_FADE if _withers() else (COOL_FADE if _cools() else CRUMBLE_FADE)
	var since := _dead_t - crumble_swap_sec()
	var fade := clampf(1.0 - (since - fall) / fade_sec, 0.0, 1.0)
	_mat.set_shader_parameter("flash", 0.0)
	_mat.set_shader_parameter("icy", 0.0)
	if fade <= 0.0:
		return
	var to_local := _crash_local()
	for r in _rubble:
		var sz: Vector2 = r["size"]
		_figure.draw_set_transform_matrix(to_local * Transform2D(float(r["rot"]), Vector2(1.0, float(r.get("sy", 1.0))), 0.0, Vector2(r["c"])))
		_figure.draw_texture_rect(r["tex"], Rect2(-sz / 2.0, sz), false, Color(1, 1, 1, fade))
	var cover := wither_cover()
	if cover > 0.0: # the whole frame over the parts a moment: their cut edges never show assembled
		var look := _frame_look()
		if not look.is_empty():
			_figure.draw_set_transform_matrix(look["xform"])
			_figure.draw_texture(look["tex"], Vector2.ZERO, Color(1, 1, 1, cover))
	_figure.draw_set_transform(Vector2.ZERO)


# ── Mộc Tinh's drawn art: leaves, the dragging root, the wither ─────────────

## Dies withering (BossArt.DEATH "wither", drawn from frames).
func _withers() -> bool:
	return not _side.is_empty() and BossArt.death_of(art) == "wither"


## Falls apart into its parts (a crumble, a wither or a cool).
func _breaks_apart() -> bool:
	return _crumbles() or _withers() or _cools()


## The falling leaves (tests): their count.
func leaf_count() -> int:
	return _leaves.count()


## The dragging root's tip now (global; Vector2.INF while no frame shows it): points.json rootTip.
func root_tip_position() -> Vector2:
	if _dead or _vanished:
		return Vector2.INF
	var fp := _frame_points()
	if fp.get("rootTip") is Vector2:
		return to_global(_unit_xform() * Vector2(fp["rootTip"]))
	return Vector2.INF


## 0..1: the last death frame over the parts as they start to separate (a wither, WITHER_COVER; a
## cool, COOL_COVER).
func wither_cover() -> float:
	if not (_withers() or _cools()) or not _crumbled:
		return 0.0
	return clampf(1.0 - (_dead_t - crumble_swap_sec()) / (COOL_COVER if _cools() else WITHER_COVER), 0.0, 1.0)


## A leaf off the canopy (local px): round the shown frame's canopy point, spread over the crown.
func _canopy_leaf_at(spread: float) -> Vector2:
	var fp := _frame_points()
	var c: Vector2 = fp["canopy"] if fp.get("canopy") is Vector2 else Vector2(0, -80)
	return _unit_xform() * (c + Vector2(randf_range(-spread, spread), randf_range(-4.0, 14.0)))


## The idle's leaves now and then (BossArt.LEAVES), the death's shower while it withers; all fall.
func _step_leaves(delta: float) -> void:
	_leaves.step(delta, height)
	var look: Dictionary = BossArt.LEAVES.get(art, {})
	if look.is_empty() or _side.is_empty() or _vanished:
		return
	if _dead:
		if _withers() and _dead_t < crumble_swap_sec() + 0.6:
			_leaf_emit -= delta
			while _leaf_emit <= 0.0:
				_leaf_emit += WITHER_LEAF_EVERY
				var cols: Array = look["wither"]
				_leaves.add(_canopy_leaf_at(42.0), height * randf_range(0.02, 0.03), cols[randi() % cols.size()],
					height * randf_range(0.0, 0.03), Vector2(randf_range(-0.25, 0.25), randf_range(-0.05, 0.05)) * height, 3.0, 1.7)
		if _withers(): # they fade with it
			_leaves.fade = clampf(1.0 - (_dead_t - crumble_swap_sec() - WITHER_FALL) / WITHER_FADE, 0.0, 1.0)
		return
	_leaf_in -= delta
	if _leaf_in <= 0.0:
		var every: Vector2 = look["every"]
		_leaf_in = randf_range(every.x, every.y)
		var cols: Array = look["colours"]
		var side := -1.0 if randf() < 0.5 else 1.0 # off the crown's sides, clear of the trunk
		_leaves.add(_canopy_leaf_at(0.0) + _unit_xform().basis_xform(Vector2(side * randf_range(28.0, 62.0), 6.0)),
			height * randf_range(0.026, 0.032), cols[randi() % cols.size()], height * randf_range(0.0, 0.025),
			Vector2(side * randf_range(0.02, 0.08), 0.0) * height, 6.0)


func _step_wither(delta: float) -> void:
	_dead_t += delta
	var swap := crumble_swap_sec()
	_death = minf(1.0, _dead_t / (swap + WITHER_FALL + WITHER_FADE))
	if not _crumbled and _dead_t >= swap:
		_wither()
	if not _crumbled:
		return
	var since := _dead_t - swap
	_fall_parts(delta, since, WITHER_GRAVITY, WITHER_BOUNCE)
	var sag := WITHER_SAG * smoothstep(WITHER_COVER, WITHER_FALL * 0.8, since) # squashing toward the feet
	for r in _rubble:
		if bool(r.get("anchored", false)):
			var c0: Vector2 = r["c0"]
			r["c"] = Vector2(c0.x, c0.y * (1.0 - sag))
			r["sy"] = 1.0 - sag


## The parts take over from the last death frame: the clumps and twigs to drop, the trunk and roots
## anchored; a shower of withered leaves and a little dust at the foot.
func _wither() -> void:
	_crumbled = true
	_rubble.clear()
	var parts := Art.boss_parts(art)
	if parts.is_empty():
		return
	var h := float(_side["height"])
	var ph := h / float(parts["height"])
	var top_z := 1
	for name in parts["parts"]:
		top_z = maxi(top_z, int(parts["parts"][name].get("z", 0)))
	for name in parts["parts"]:
		var n := str(name)
		var pt: Dictionary = parts["parts"][name]
		var sz: Vector2 = Vector2(pt["size"]) * ph
		var c: Vector2 = Vector2(pt["at"]) * ph + sz / 2.0
		var z := int(pt.get("z", 0))
		var drops := WITHER_DROP.has(n)
		var out := signf(c.x) if absf(c.x) > 1.0 else (1.0 if z % 2 == 0 else -1.0)
		var spin := out * (randf_range(0.3, 0.8) if n.begins_with("canopy") else randf_range(2.0, 3.5))
		_rubble.append({"name": n, "tex": pt["texture"], "size": sz, "z": z, "c": c, "c0": c, "sy": 1.0, "anchored": not drops,
			"v": Vector2(out * randf_range(0.22, 0.4), -0.08) * h if drops else Vector2.ZERO, "rot": 0.0, "spin": spin if drops else 0.0,
			"delay": float(WITHER_DROP.get(n, 0.0)), "ground": h * (0.005 + 0.03 * float(z) / float(top_z))})
	_rubble.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))
	var cols: Array = BossArt.LEAVES.get(art, {}).get("wither", [Color(0.55, 0.33, 0.14)])
	for i in WITHER_LEAVES:
		_leaves.add(_canopy_leaf_at(48.0), height * randf_range(0.02, 0.032), cols[i % cols.size()], height * randf_range(0.0, 0.035),
			Vector2(randf_range(-0.45, 0.45), randf_range(-0.25, 0.05)) * height, 3.2, 1.7)
	for i in 4: # a little dust at the foot
		var side := -1.0 if i % 2 == 0 else 1.0
		_dust.append({"p": Vector2(side * randf_range(0.05, 0.3) * height, -0.02 * height), "v": Vector2(side * 0.15, -0.06) * height,
			"r": height * randf_range(0.05, 0.08), "grow": 1.2, "age": 0.0, "life": randf_range(0.8, 1.1)})


# ── Cua Dung Nham's drawn art: the cooling death, its Cua con's fade ─────────

## Dies cooling (BossArt.DEATH "cool", drawn from frames).
func _cools() -> bool:
	return not _side.is_empty() and BossArt.death_of(art) == "cool"


## Dies fading like the code art (BossArt.DEATH "fade": a minion drawn from frames).
func _fades() -> bool:
	return not _side.is_empty() and BossArt.death_of(art) == "fade"


## A smoke puff rising off the shell (local px), round the shown frame's heart.
func _add_cool_smoke(spread: float, big: bool = false) -> void:
	var c := _heart_local() + Vector2(randf_range(-spread, spread), -randf_range(0.05, 0.2)) * height
	_dust.append({"p": c, "v": Vector2(randf_range(-0.06, 0.06), -randf_range(0.25, 0.4)) * height, "drag": 0.8,
		"r": height * (randf_range(0.09, 0.13) if big else randf_range(0.055, 0.08)), "grow": 1.8, "age": 0.0,
		"life": randf_range(0.9, 1.3), "col": COOL_SMOKE})


func _step_cool(delta: float) -> void:
	_dead_t += delta
	var swap := crumble_swap_sec()
	_death = minf(1.0, _dead_t / (swap + COOL_FALL + COOL_FADE))
	if _dead_t < swap + COOL_FALL * 0.6 and _dead_t > 1.0 / maxf(_anim.fps("death"), 0.1): # smoke off the cooling shell
		_smoke_emit -= delta
		while _smoke_emit <= 0.0:
			_smoke_emit += COOL_SMOKE_EVERY
			_add_cool_smoke(0.3)
	if not _crumbled and _dead_t >= swap:
		_split()
	if not _crumbled:
		return
	var since := _dead_t - swap
	_fall_parts(delta, since, 1.0, COOL_BOUNCE)
	var h := float(_side["height"])
	for r in _rubble:
		if not r.has("topple"):
			continue
		var u := clampf((since - float(r["delay"])) / COOL_TOPPLE_SEC, 0.0, 1.0)
		u = 1.0 - pow(1.0 - u, 3.0) + 0.06 * sin(PI * u) * (1.0 - u) # eased out, a little rock at the end
		var rot := float(r["topple"]) * u
		var c0: Vector2 = r["c0"]
		r["rot"] = rot
		r["c"] = c0 + Vector2(signf(float(r["topple"])) * COOL_SLIDE * h, COOL_SINK * h) * u # tipping over, settling a little


## The parts take over from the last death frame: the shell's halves split apart, the claws and the
## legs fall off (COOL_PARTS, COOL_LEG), a smoke burst and embers out of the crack.
func _split() -> void:
	_crumbled = true
	_rubble.clear()
	var parts := Art.boss_parts(art)
	if parts.is_empty():
		return
	var h := float(_side["height"])
	var ph := h / float(parts["height"])
	var fp := _frame_points()
	var heart: Vector2 = (Vector2(fp["heart"]) if fp.get("heart") is Vector2 else Vector2(BossArt.HEART.get(art, Vector2(0, -50)))) * h / BossArt.UNIT
	var top_z := 1
	for name in parts["parts"]:
		top_z = maxi(top_z, int(parts["parts"][name].get("z", 0)))
	for name in parts["parts"]:
		var n := str(name)
		var pt: Dictionary = parts["parts"][name]
		var sz: Vector2 = Vector2(pt["size"]) * ph
		var c: Vector2 = Vector2(pt["at"]) * ph + sz / 2.0
		var z := int(pt.get("z", 0))
		var cfg: Dictionary = COOL_PARTS.get(n, COOL_LEG)
		var v: Vector2 = cfg["v"]
		var spin := float(cfg["spin"])
		if not COOL_PARTS.has(n): # a leg: outward from the heart
			var out := signf(c.x - heart.x) if absf(c.x - heart.x) > 1.0 else 1.0
			v = Vector2(out * absf(v.x), v.y)
			spin = out * absf(spin) * randf_range(0.6, 1.2)
		var part := {"name": n, "tex": pt["texture"], "size": sz, "z": z, "c": c, "v": v * h * randf_range(0.85, 1.15), "rot": 0.0,
			"spin": spin, "delay": float(cfg["delay"]), "ground": h * (0.005 + 0.03 * float(z) / float(top_z))}
		if COOL_TOPPLE.has(n): # a shell half: toppled by hand (_step_cool), not falling
			part.merge({"anchored": true, "topple": float(COOL_TOPPLE[n]), "c0": c})
		_rubble.append(part)
	_rubble.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))
	for i in 7: # the smoke burst out of the crack
		_add_cool_smoke(0.25, true)
	var crack := _unit_xform() * (heart * BossArt.UNIT / h)
	for i in RUBBLE_PEBBLES:
		var a := -PI * 0.5 + (randf() - 0.5) * 1.6
		_pebbles.append({"p": crack + Vector2(randf_range(-0.08, 0.08), randf_range(-0.05, 0.05)) * height,
			"v": Vector2.from_angle(a) * height * randf_range(0.7, 1.5), "r": height * randf_range(0.007, 0.013), "rot": 0.0, "spin": 0.0,
			"age": 0.0, "life": randf_range(0.5, 0.9), "col": EMBERS[i % EMBERS.size()], "ground": 0.0, "ember": true})
