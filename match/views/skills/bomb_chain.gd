extends "res://match/views/skills/skill_view.gd"
## Tanko — Bom liên hoàn (server skill heavy_bomb, effect bomb_chain): bombs (projectile kind
## "bomb", each leaving at its launchDelay, at least 0.1 s apart) all fly the shot's own normal
## arc: each later one passes through the earlier craters and explodes where that arc now meets
## the terrain or a player (a lob digs one deep shaft onto the target, a flat shot a trench along
## its arc); every enemy hit is rooted. The server paces the chain so a bomb only explodes once
## every fall so far has landed, so the default replay (paths, explode / damage / fall events)
## already plays in order. On top of it:
## - the bombs are the gun's own tier shell (ShotLook, Blaster wearers the blaster's) drawn
##   BOMB_SCALE × a normal shell;
## - the gun kicks again (recoil, muzzle smoke) as each later bomb leaves;
## - every explosion down in a hole (deeper than GEYSER_DEPTH under the ground beside it) throws
##   a geyser of dirt, dust and embers up out of it and dust rolls out over its rim
##   (bomb_chain_fx.gd), so the digging reads from above;
## - the bombs and the players are drawn over the explosions during the chain (BOMBS_Z,
##   PLAYERS_Z): every bomb is seen flying into the hole and the target stays in sight in it;
## - the hits on a player count up in one running number (merges_damage(), DamageTally);
## - the root: the "Bị cầm chân" number when it lands and the banner on the rooted player's next
##   turn (match_screen; the status overlay on the character is drawn elsewhere).

const ShotLook := preload("res://match/views/shot_look.gd")
const ChainFx := preload("res://match/views/skills/bomb_chain_fx.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")

## A bomb's size against the gun's normal shell (a skill shell is already ShotLook.SKILL_SCALE).
const BOMB_SCALE := 1.4
## The explosions' drawn radius (px; the crater itself is the server's, the gun's own bowl for
## every bomb): the first bomb's big blast on the surface, then the ones down the shaft, kept
## smaller so the hole, the target dropping in and the next bomb stay visible between them.
const FIRST_BLAST_PX := 85.0
const SHAFT_BLAST_PX := 58.0
## An explosion this many px under the ground beside it (rim_y()) is down a hole: a geyser.
const GEYSER_DEPTH := 24.0
## Drawing order during the replay (the explosions are z 0 on the fx layer): the bombs over the
## explosions, so each one is seen flying through the smoke into the hole; the
## players over both, so the target stays in sight while bomb after bomb goes off on it; the
## geyser's dirt over everything (bomb_chain_fx.gd, z 3).
const BOMBS_Z := 1
const PLAYERS_Z := 2

var _fx: Node2D # ChainFx on the fx layer; frees itself once its particles are gone
var _kicked := 1 # bombs whose launch was shown: the first leaves with the shot itself
var _blasts := 0 # explosions so far
var _first_y := NAN # the first explosion's y: the rim when the terrain is unknown
var _z := {} # PlayerView -> its z_index before the replay


func skill_id() -> String:
	return "heavy_bomb"


func skill_name() -> String:
	return "Bom liên hoàn"


func describe(rank: int) -> String:
	# the server's chainCount / chainEach / chainCap (skill_bombchain.go): 2 + rank bombs, each
	# (180 + 15 × rank)% / (3 + rank) of the base damage
	return "Bắn %d quả bom lớn liên tiếp cùng đường bay (+1 mỗi cấp súng), đào sâu một hố; mỗi quả %d%% sát thương, mỗi địch nhận tối đa %d%%; địch trúng bị cầm chân lượt sau." % [2 + rank, roundi((180.0 + 15.0 * rank) / (3 + rank)), 120 + 15 * rank]


## The chain's hits on a player count up in one number (DamageTally).
func merges_damage() -> bool:
	return true


func begin(context: Dictionary) -> void:
	super(context)
	_fx = ChainFx.new()
	_fx.style = ctx.get("style", {})
	var layer = ctx.get("layer")
	if layer is Node:
		layer.add_child(_fx)
	for view in ctx.get("views", {}).values():
		if view is CanvasItem and is_instance_valid(view):
			_z[view] = view.z_index
			view.z_index = PLAYERS_Z


## The size of the bombs: BOMB_SCALE × the normal shell, whatever the skill look adds.
static func bomb_size_k(skill: bool) -> float:
	return BOMB_SCALE / (ShotLook.SKILL_SCALE if skill else 1.0)


func projectile_view(_i: int, _projectile: Dictionary, view: Node2D) -> Node2D:
	if "size_k" in view:
		view.size_k = bomb_size_k(bool(view.get("skill")))
	view.z_index = BOMBS_Z
	return view


func explosion(event: Dictionary, fx: Node2D) -> void:
	_blasts += 1
	var at: Vector2 = fx.position
	fx.radius = blast_px(_blasts - 1, fx.radius)
	var crater := float(event.get("radius", fx.radius))
	if _blasts == 1:
		_first_y = at.y
		return
	fx.skill = false # no skill flash on every later bomb
	var rim := rim_y(at, crater)
	if at.y - rim > GEYSER_DEPTH and _fx != null and is_instance_valid(_fx):
		_fx.geyser(at, rim, crater)


## The drawn radius of explosion i (0 = the first bomb's) whose default would be `radius`.
static func blast_px(i: int, radius: float) -> float:
	return minf(radius, FIRST_BLAST_PX if i == 0 else SHAFT_BLAST_PX)


func process(t: float) -> void:
	var tl = ctx.get("timeline")
	if tl == null:
		return
	while _kicked < tl.projectiles.size() and t >= tl.launch_time(_kicked):
		_kicked += 1
		_kick()


## A later bomb leaves: the gun recoils again and puffs smoke at the muzzle.
func _kick() -> void:
	var view = ctx.get("views", {}).get(ctx.get("shooter", ""))
	if view == null or not is_instance_valid(view):
		return
	if view.gun_state() in ["aiming", "firing"]:
		view.shoot()
	if _fx != null and is_instance_valid(_fx):
		_fx.puff(view.muzzle_position())


func end() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.finish()
	_fx = null
	for view in _z:
		if is_instance_valid(view):
			view.z_index = _z[view]
	_z.clear()


## The ground beside an explosion at `at` whose crater is `crater` (already carved): the higher of
## the surfaces just past both crater edges (rim_reach()); without terrain the first explosion's y.
func rim_y(at: Vector2, crater: float) -> float:
	var mask = ctx.get("terrain")
	if mask == null or not mask.has_method("get_landing_y"):
		return _first_y if not is_nan(_first_y) else at.y
	var edge := rim_reach(crater)
	return minf(mask.get_landing_y(at.x - edge, 0.0), mask.get_landing_y(at.x + edge, 0.0))


## How far from the explosion rim_y() looks: 6 px past the widest the bowl carves (where its
## floor meets its flat top, r·√(1 + BOWL_CEILING / BOWL_DEPTH) ≈ 1.76r). A shaft of stacked
## bowls is that wide, so nearer in it would read the shaft's own wall.
static func rim_reach(crater: float) -> float:
	return crater * sqrt(1.0 + TerrainMask.BOWL_CEILING / TerrainMask.BOWL_DEPTH) + 6.0


## The explosions seen so far (tests).
func blasts() -> int:
	return _blasts
