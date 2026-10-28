extends Node2D
## Match against the server. The server is authoritative: this screen renders its snapshot,
## replays ShotResolved, and predicts only the local player's walk (MoveSync). Every match
## event that arrives during a replay waits until the replay ends, and the turn clock is paused
## from the shot until the next timer event, so the HUD never runs ahead of the animation.
## PlayerAiming (another player, the bots for now, aims before its shot) swings that player's gun
## onto the aim (PlayerView.aim_sweep); its ShotResolved fires it, a turn change puts it away.
## Items: instant ones (medkit, wind_stopper) go out as UseItem through the same commit path as
## a shot but leave the turn open; shot items arm the next Shoot (actionMode "item"). A drill-armed
## shot's shells are drill bits (projectiles[].drill); its "drill" event opens the tunnel in the
## terrain behind the bit as it bores (TunnelDig, one version step) with dirt and dust (DrillFx),
## before the shell's explode.
## Skills: each character's skill has a SkillView (match/views/skills/): its aim mode (an arc, a
## straight line, or none: fired on tap) and, for a skill ShotResolved, the replay visuals on top
## of the default handling here. Status effects: stun and freeze lose the whole turn (controls off,
## a countdown; the server ends it), root keeps the move controls off ("Bị cầm chân"); burn ticks at
## turn start (PlayerDamaged type burn); the shield shows on the HP bar and absorbs damage first.
## Skill energy: players[id].skillEnergy is the value on screen (the HUD's skill slot, the
## full-energy aura over each player). A ShotResolved's new energies wait for the replay
## (match/shot/energy_reveal.gd): the skill's shooter spends at the fire moment, a hit player gains
## at its first damage event, the rest at the replay's end; TurnStarted (the end-of-turn +20,
## held back by the replay), ItemUsed and snapshots set them as they come.
## What a player uses shows as a badge over it (PlayerView.show_badge(), match/views/use_badge.gd):
## a skill or a shot item from the moment it is armed to the replay's end, an instant item
## (ItemUsed) for ITEM_BADGE_SEC; a normal weapon shot shows none. Arming: my armed mode goes to
## the server as SelectAction whenever it changes in my turn (the skill, a shot item, back to the
## weapon; never an instant item), and my badge shows at once; ActionSelected shows (or, for
## "weapon", hides) another player's, MatchStateSync's selectedAction restores it. A held badge
## goes on into the shot's (no second pop) and is hidden when the turn passes without a shot. A
## server without SelectAction ignores it: the others' badges then come with the shot.
## Camera (match/camera/): the battle world is under one Camera2D (MatchCamera, its CameraModel
## _cam fed here every frame by _track_camera()); the sky is a far layer behind it in parallax, the
## HUD, the top-edge arrows and the off-screen markers stay on their CanvasLayers. The map's size
## is the terrain's (MatchStarted / MatchStateSync terrain width × height, any size). Match start:
## on me, then a pan to the current player; each turn start pans to its player (after an
## explosion's hold); my aim drag, a remote PlayerAiming sweep, the replayed shot's shells /
## blasts / falls / teleports / laser beam each take it; an explosion shakes it a little. A
## marker tap (OffscreenMarkers) pans to that player; MatchCamera reads the manual pan / zoom.
## Boss mode (MatchStarted mode boss:<bossId>, a boss block in the state): the boss and its
## minions are players of team 2 drawn by BossBody (PlayerView); the HUD's boss bar follows
## BossHudModel (HP, the shield: bossShielded / BossShieldChanged, the round: TurnStarted round),
## the boss's ActionSelected names its skill under the bar; its rain / beam skills replay with the
## boss skill views (match/views/skills/boss_rain.gd, boss_beam.gd), a summon event adds the
## minion where it lands (a pop, the camera on it), a lava event leaves a pool (LavaZones /
## LavaView, replaced by every lavaZones list), the boss's death takes its minions (die cause
## boss_defeated). The camera frames a big body by its height (_look_lift()). MatchEnded shows the
## boss result screen (match/boss/boss_result_screen.gd).
## Boss mode v2: UnitFlew {playerId, from, to, duration} flies a drone or the witch through the air
## (PlayerView.fly(), the camera on it; the events after it wait until it lands, like a fall out of
## the map); walking crablings come as PlayerMoved. A bomber pulses red while a party player is
## within its detonateRange (_update_bombers()). A minion's own blast (BlastEvents: its
## detonation, ShotResolved actionMode self_destruct, and the death blast after a die) is drawn as
## that minion blowing up: it swells until then (prime()), then the body is gone at once
## under a big burst in its look (BossArt.BLAST_LOOK, the snowman's icy) with a shockwave as wide
## as the blast (BlastFx) and a hard shake; an explode with a crater number carves that radius.
## A summon event carries the whole new unit (displayName, hp, maxHp, teamId, bodySize, flying,
## behavior, movement); the game data's minion type only fills what it leaves out.
## Boss mode v3: the boss summons for free at the start of its turn (ShotResolved actionMode
## "summon", "Triệu hồi" under the boss bar; the turn is not resolved by it: its attack's
## ActionSelected and ShotResolved follow). Many beams at once (the witch's radial burst, the
## robot's parallel sweep) and a map-wide rain (with the boss's storm over the screen) frame the
## whole map (SkillView.frames_map(): the camera zooms out, then back after the replay); a ground
## shockwave (Shockwave: the slam's explode, then explodes stepping out to both edges) is a ripple
## along the ground with a dust burst at each step (ShockwaveFx), the map framed too. UnitJumped
## {playerId, from, to, duration, height} is a leaping snowman's arc jump (PlayerView.jump(): squash
## and stretch, the camera on it, the events after it wait until it lands); from it until its next
## turn ends it glows as a warning (LeapWarning; the state's leapt), then blows up as a minion.
## Tide's water orb: its bounce (ShotTimeline "bounce" events from projectiles[].bounces) splashes
## on the ground (WaterSplash), its explosion bursts into water over the gun's impact.
## Elements: a damage event's elementEffect ("strong" / "weak", the server's element rules) styles
## its number (DamagePopup.style(): bigger gold-orange with "Khắc hệ!" / smaller greyish blue), the
## running tally of a multi-hit skill too; every name carries its element's badge (PlayerView).
## Boss mode v4 (Khổng Lồ Đá, Mộc Tinh; the server's earth / wood contract): an eruption skill's mark
## events leave glowing cracked circles under the party (BossMarks, MarkView), kept through turns
## and restored from MatchStateSync / TurnStarted marks; the boss's turn starts with a ShotResolved
## actionMode "turn_start" (it does not end the turn: the summon and the attack follow) in which the
## marks rumble until their eruption events, then stone spikes burst up across each one
## (BombChainFx.erupt()) and the members hit hop a little (cosmetic: the server moves nobody); the
## boss's death clears them. A ground_strike event bursts thorny vines up under a member
## (VineStrikeFx). A heal event on the boss (cause drain: life flowing from the drained member into
## its heart, LifeStreamFx, while the green-gold beam holds; cause regen: leaves and sparkles rising
## from each mushroom into it) glows on it, a green number, the HUD's bar rising. The poison status
## is drawn on the body (StatusFx), its turn-start PlayerDamaged type poison a green number and a
## puff of spores. The minion auras (BossHudModel armorMinions / regenMinions, BossShieldChanged, a
## minion's death or summon): rune links from each stone totem to the giant and stone plates on it
## (AuraLinks, BossBody.set_armored(); they snap and fly off when the last totem falls, "Phá giáp!"),
## vine threads from the mushrooms; a hit on the armoured boss shows a stone-grey number ("Giáp đá"
## over the first). A mushroom's turn (ShotResolved actionMode "spore") puffs a spore cloud out to
## its radius (SporeFx), its death blast bursts into spores. The camera frames the marks, the
## eruptions and the strikes of a shot (_frame_ground()).
## Lost turns and blind (063): a stunned / frozen unit's TurnStarted (skipped + skipAfter) shows a
## countdown, no text: a ring emptying with the seconds left over the unit (CountdownRing on its
## PlayerView) and, for my own, dead centre on the HUD under the turn banner (SkipCountdown; a
## TurnStarted held back by a replay counts from its arrival). While I am blinded my own turn is
## whited out (BlindOverlay on the screen layer, until my shot is answered); others see the
## blindfold on my unit (StatusLook "blind"). The snowman (leapDetonateNextTurn false) leaps
## without the fuse warning. The summon is named as the boss's kit names it (summon.name).
## Boss mode v5 (063): the new ShotResolved events play on the replay's clock: airburst (Bom mù:
## the orb is OrbView via the boss_airburst skill view; AirburstFx and a white blink at the
## burst), move (a unit walks its ground path: BossMoves drives the view, its state is `to`),
## pincer (PincerFx snaps on the target), global (boss_global: the map framed, the boss's storm;
## the earthquake shakes the camera for its duration and splits the ground under every member hit,
## GroundCrackFx; a shard / thorn bursts on the member it hits), roll (the thrown boulder is a
## RollingBoulderView via boss_roll, then rolls along the path from where it lands) and pull (the
## member dragged along the path, RootDragFx along the ground, its state `to`).
## See docs/superpowers/specs/2026-10-15-godot-client-roadmap-design.md.

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const BurnFx := preload("res://match/views/skills/burn_fx.gd")
const ShotLook := preload("res://match/views/shot_look.gd")
const DamagePopup := preload("res://match/views/damage_popup.gd")
const DamageTally := preload("res://match/views/damage_tally.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const BottomView := preload("res://match/views/bottom_view.gd")
const MapThemes := preload("res://match/theme/map_themes.gd")
const Art := preload("res://ui/art.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const EnergyReveal := preload("res://match/shot/energy_reveal.gd")
const UseBadge := preload("res://match/views/use_badge.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const Trajectory := preload("res://match/aim/trajectory_predictor.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const MoveSync := preload("res://match/move/move_sync.gd")
const WalkPath := preload("res://match/move/walk_path.gd")
const Hud := preload("res://match/hud.gd")
const Skills := preload("res://match/skills.gd")
const ItemViews := preload("res://match/views/items/item_views.gd")
const Items := preload("res://match/items.gd")
const Status := preload("res://match/status_effects.gd")
const ActionLock := preload("res://match/action_lock.gd")
const SkillView := preload("res://match/views/skills/skill_view.gd")
const HighShellMarker := preload("res://match/views/high_shell_marker.gd")
const RankModel := preload("res://screens/ranked/rank_model.gd")
const ResultModel := preload("res://match/result_model.gd")
const ResultScreen := preload("res://match/result_screen.gd")
const QuickPlay := preload("res://screens/quick_play.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const CameraModel := preload("res://match/camera/camera_model.gd")
const MatchCamera := preload("res://match/camera/match_camera.gd")
const OffscreenMarkers := preload("res://match/views/offscreen_markers.gd")
const BossHudModel := preload("res://match/boss/boss_hud_model.gd")
const LavaZones := preload("res://match/boss/lava_zones.gd")
const LavaView := preload("res://match/boss/lava_view.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossAnim := preload("res://match/boss/boss_anim.gd")
const BossResultModel := preload("res://match/boss/boss_result_model.gd")
const BossResultScreen := preload("res://match/boss/boss_result_screen.gd")
const PopFx := preload("res://match/boss/pop_fx.gd")
const BlastEvents := preload("res://match/boss/blast_events.gd")
const BlastFx := preload("res://match/boss/blast_fx.gd")
const FlightModel := preload("res://match/boss/flight_model.gd")
const BomberModel := preload("res://match/boss/bomber_model.gd")
const ShieldState := preload("res://match/views/shield_state.gd")
const Shockwave := preload("res://match/boss/shockwave.gd")
const ShockwaveFx := preload("res://match/boss/shockwave_fx.gd")
const JumpModel := preload("res://match/boss/jump_model.gd")
const LeapWarning := preload("res://match/boss/leap_warning.gd")
const UnitShell := preload("res://match/views/unit_shell.gd")
const UnitImpact := preload("res://match/views/unit_impact.gd")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const WaterSplash := preload("res://match/views/water_splash.gd")
const BossMarks := preload("res://match/boss/boss_marks.gd")
const MarkView := preload("res://match/boss/mark_view.gd")
const AuraLinks := preload("res://match/boss/aura_links.gd")
const VineStrikeFx := preload("res://match/boss/vine_strike_fx.gd")
const SporeFx := preload("res://match/boss/spore_fx.gd")
const LifeStreamFx := preload("res://match/boss/life_stream_fx.gd")
const BombChainFx := preload("res://match/views/skills/bomb_chain_fx.gd")
const SkipCountdown := preload("res://match/skip_countdown.gd")
const CountdownRing := preload("res://match/views/countdown_ring.gd")
const BlindOverlay := preload("res://match/views/blind_overlay.gd")
const BossMoves := preload("res://match/boss/boss_moves.gd")
const AirburstFx := preload("res://match/boss/airburst_fx.gd")
const PincerFx := preload("res://match/boss/pincer_fx.gd")
const GroundCrackFx := preload("res://match/boss/ground_crack_fx.gd")
const RollingBoulderView := preload("res://match/boss/rolling_boulder_view.gd")
const RootDragFx := preload("res://match/boss/root_drag_fx.gd")
const TunnelDig := preload("res://match/terrain/tunnel_dig.gd")
const DrillFx := preload("res://match/views/drill_fx.gd")
const QUAKE_SHAKE := 70.0 # the earthquake's shake (as an explosion of this radius), renewed every QUAKE_EVERY s
const QUAKE_EVERY := 0.12
const WATER_GUN := "water_gun" # a shot of this gun kind bursts into water (visual only)

## Actions go out at least the server's timings.actionIntervalSec apart (it drops closer ones)
## plus this margin for the network's jitter.
const ACTION_MARGIN := 0.1
const MOVE_ACK_GAP := 0.16 # Shoot/EndTurn/UseItem wait this long after the last answer to a Move
# Both waits are measured with Time.get_ticks_usec() from the moment they start, not by summing
# frame deltas: a long frame right before an answer is read would count time from before it.
## Another player's walk (PlayerMoved) is drawn along the surface (PlayerView.walk_to) and ends
## this long before a bot's next action (timings.botFollowUpDelaySec after its Move) at the latest.
const OTHER_WALK_LEAD := 0.1
const SNAP_WALK_SEC := 0.12 # a shooter's walk still under way ends within this when its shot resolves
const SHOT_ACK_TIMEOUT := 3.0
const ITEM_ACK_TIMEOUT := 1.5 # input waits this long for ItemUsed after a UseItem
const TELEPORT_SEC := 0.3
const WEAPON := "weapon"
const SKILL := "skill"
const ITEM := "item"
const RESYNC_RETRY := 3.0 # re-ask for MatchStateSync if none arrived
## Before the player may aim or act in a match whose gamedataVersion is not the cached one, the
## game data is fetched again; "Đang cập nhật dữ liệu..." shows if that takes longer than this.
const DATA_NOTICE_SEC := 0.3
const DATA_NOTICE := "Đang cập nhật dữ liệu..."
const UNIT_RING_RADIUS := 26.0 # a lost turn's countdown ring over the unit
const MIN_AIM_SEC := 0.15 # a PlayerAiming with less left (held back by a replay) is not shown
const ITEM_BADGE_SEC := 1.5 # an instant item's badge stays this long, then fades
const LOOK_LIFT := Vector2(0, -60) # the camera centres a player this far above its feet
const REMOTE_LOOK := 520.0 # px along a remote player's aim the camera looks
const START_HOLD := 0.5 # s on me at the match start before the pan to the current player
const FALL_TAIL := 0.25 # s the camera stays on a fall's end
const DRILL_SHAKE := 10.0 # the drill biting into the ground (as an explosion of this radius)
## The result screen shows this long after MatchEnded is applied (after the last shot's replay):
## the match's end stays on screen meanwhile, input locked. A "Trận bị huỷ" shows at once.
const RESULT_DELAY_SEC := 2.0
const OUT_OF_MAP := "out_of_map" # PlayerDamaged type / ShotResolved cause: fell out of the bottom of the map

var _me := ""
var _mode := "" # MatchStarted's mode (a queue: a solo lobby left going Home, "Chơi tiếp"; ranked: the rating row)
var _lobby_left := false # LeaveLobby sent (once)
var _roster := {} # Router.match_roster: the ranked players' level and rank (MatchFound)
var _damage_by := {} # playerId -> damage dealt to the other team, counted from the replays (the MVP without stats)
var _replay: QuickPlay # the result screen's "Chơi lại"
var _players := {} # playerId -> server BattlePlayerState
var _views := {} # playerId -> PlayerView
var _current := ""
var _wind := {"direction": 0, "power": 0.0}
var _ended := false
var _deferred: Array = []
## A walk's fall out of the map is still drawn: its PlayerDamaged out_of_map and every event after
## it wait in _deferred until the body has dropped out of sight (then the death plays).
var _fall_hold := false
## A UnitFlew flight is still drawn: the events after it wait in _deferred until it lands.
var _flight_hold := false
var _awaiting_ack := 0.0 # seconds left for the server to answer a sent Shoot/EndTurn/UseItem
var _awaiting_item := "" # the instant item a sent UseItem waits for ("" for Shoot/EndTurn)
var _committing := false # an action requested: input locked until it is answered
var _commit_sent := false # a Shoot/EndTurn sent: no more Moves this turn
var _cmd_sent := false # the pending commit (Shoot/EndTurn/UseItem) has actually been sent
var _resync_in := 0.0 # seconds before asking for MatchStateSync again
var _resync_after_shot := false # the terrain drifted during a replay: Reconnect once it is over
var _digs: Array = [] # TunnelDig: drill tunnels opening behind the bit (_step_digs())
var _turn_resolved := false # this turn's shot was answered: the server takes no more actions
var _move_ack_at := -10_000_000 # Time.get_ticks_usec() when the last PlayerMoved for my Moves was handled
var _disconnected := false
var _armed := WEAPON # what my next Shoot fires: WEAPON, SKILL or a shot item id
var _sent_select := WEAPON # the armed mode the server has from me this turn (my last SelectAction)
var _held_badges := {} # playerId -> the badge its armed skill / shot item holds (UseBadge.content()) until its shot fires
var send_hook := Callable() # tests: takes (event, data) instead of GameSocket for SelectAction
var _turn_index := -1
var _data_wait := false # the game data is being fetched again (gamedataVersion changed): no aiming or actions

var _mask := TerrainMask.new()
var _moves := MoveSync.new()
var _sky: SkyView
var _terrain_view: TerrainView
var _bottom: BottomView # the map theme's water / lava / abyss, over the terrain's bottom
var _theme := "" # the map theme the views show ("" none yet)
var _players_layer: Node2D
var _fx_layer: Node2D
var _aim: AimInput
var _high_marker: HighShellMarker
var _shot_player: ShotPlayer
var _shot_timeline: ShotTimeline = null # the shot being replayed (its projectiles' blast radii)
var _skill_view = null # the SkillView of the skill shot being replayed, or null
var _energy_reveal := EnergyReveal.new() # the replayed shot's skill energies not shown yet
var _shot_badge := {} # the replayed shot's badge: {shooter, content (UseBadge.content())}
var _popup_row := {} # playerId -> [msec of its last popup, how many came in a row] (DamagePopup.stagger)
var _tallies := {} # playerId -> its running DamageTally in a multi-hit skill shot (SkillView.merges_damage())
var _skip := "" # the current player loses this turn: "stun" / "freeze" (TurnStarted.skipped), "" none
var _countdown := SkipCountdown.new() # the lost turn's countdown (TurnStarted skipAfter)
var _unit_ring: Node2D = null # its ring over the unit (a CountdownRing on its PlayerView)
var _blind: BlindOverlay = null # my blind white-out (on the screen layer, under the HUD)
var _moves_fx := BossMoves.new() # boss v5: the walks, drags and rolls along a ShotResolved path
var _quake_until := -1.0 # boss v5: the earthquake shakes the camera until this _clock s
var _quake_next := 0.0
var _hud: Hud
var _cam := CameraModel.new() # what the camera does (MatchCamera applies it)
var _camera: MatchCamera
var _markers: OffscreenMarkers
var _focus: Array = [] # the replay's held camera points: [{pos: Vector2 | view: Node2D, until: _clock s}]
var _clock := 0.0 # s since the screen started (the focus expiry)
var _aim_dragging := false # my aim drag was running last frame

var _boss := BossHudModel.new() # the boss fight's state (inactive outside the boss mode)
var _lava := LavaZones.new()
var _shields := ShieldState.new() # who has a shield bubble up, in whose gun tier colour
var _lava_view: LavaView
var _screen_fx: CanvasLayer # screen overlays over the world, under the HUD (a boss's storm)
var _wave_fx: Node2D = null # the replayed shot's ground shockwave (ShockwaveFx), null none
var _leaps := LeapWarning.new() # the leapt snowmen about to blow up
var _marks := BossMarks.new() # boss v4: the eruption marks on the ground
var _mark_view := MarkView.new()
var _links := AuraLinks.new() # boss v4: the totems' rune links, the mushrooms' vine threads
var _armor_tagged := false # the "Giáp đá" tag was shown on this armour's first hit
var _drain := {} # the replayed shot drains: {until: s the life flows until}

var _hold_dir := 0
var _action_at := -10_000_000 # Time.get_ticks_usec() when my last Move/Shoot/EndTurn/UseItem was sent


func _ready() -> void:
	_me = Session.player_id
	var far := CanvasLayer.new() # the sky: a far layer behind the world, in parallax with the camera
	far.layer = -1
	add_child(far)
	_sky = SkyView.new()
	far.add_child(_sky)
	_terrain_view = TerrainView.new()
	add_child(_terrain_view)
	_bottom = BottomView.new()
	add_child(_bottom)
	_lava_view = LavaView.new() # on the ground, under the players
	add_child(_lava_view)
	_links.views = _views # under the players
	add_child(_links)
	add_child(_mark_view) # on the ground, under the players
	_players_layer = Node2D.new()
	add_child(_players_layer)
	_fx_layer = Node2D.new()
	add_child(_fx_layer)
	_aim = AimInput.new()
	add_child(_aim)
	_shot_player = ShotPlayer.new()
	_shot_player.layer = _fx_layer
	add_child(_shot_player)
	_camera = MatchCamera.new()
	_camera.model = _cam
	_camera.sky = _sky
	_camera.aim = _aim
	add_child(_camera)
	_screen_fx = CanvasLayer.new() # same layer as the HUD's, before it: under the HUD
	add_child(_screen_fx)
	_blind = BlindOverlay.new()
	_screen_fx.add_child(_blind)
	var ui := CanvasLayer.new()
	add_child(ui)
	_markers = OffscreenMarkers.new() # under the HUD's controls
	_markers.views = _views
	_markers.tapped.connect(_on_marker_tapped)
	ui.add_child(_markers)
	_hud = Hud.new()
	ui.add_child(_hud)
	var over_hud := CanvasLayer.new() # the high shells' arrows on the top edge, over the HUD
	over_hud.layer = ui.layer + 1
	add_child(over_hud)
	_high_marker = HighShellMarker.new()
	_high_marker.shot_player = _shot_player
	_high_marker.aim = _aim
	over_hud.add_child(_high_marker)

	_moves.terrain = _mask
	_aim.fire.connect(_on_fire)
	_aim.aim_changed.connect(_hud.set_aim)
	_aim.aim_changed.connect(_face_aim)
	_aim.aim_cleared.connect(_clear_my_aim)
	_aim.column_changed.connect(_hud.set_column)
	_shot_player.event_due.connect(_on_shot_event)
	_shot_player.fired.connect(_on_shot_fired)
	_shot_player.finished.connect(_on_shot_finished)
	_hud.move_pressed.connect(func(dir: int) -> void: _hold_dir = dir)
	_hud.move_released.connect(func() -> void: _hold_dir = 0)
	_hud.skill_pressed.connect(_on_skill_pressed)
	_hud.item_pressed.connect(_on_item_pressed)
	_aim.fire_column.connect(_on_fire_column)
	_hud.leave_pressed.connect(_on_leave)

	var snap: Dictionary = Router.match_snapshot
	Router.match_snapshot = {} # consumed: a later Match scene must not start from it
	_mode = str(snap.get("mode", ""))
	_roster = Router.match_roster
	Router.match_roster = {}
	GameData.use_match(snap.get("gamedataVersion")) # its game data when held, before anything reads it
	_load_snapshot(snap, false)
	_check_gamedata(snap)
	var map_name := MapThemes.name_of(snap)
	if map_name != "":
		_hud.announce_map(map_name)
	GameSocket.event_received.connect(_on_event)
	GameSocket.disconnected.connect(_on_disconnected)
	GameSocket.release()


## Leaving the match: the lobby's game data is in use again.
func _exit_tree() -> void:
	GameData.end_match()


## The ground views made before _ready() (tests build the screen without it) go with the screen.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for n in [_mark_view, _links]:
			if is_instance_valid(n) and n.get_parent() == null:
				n.free()


func _process(delta: float) -> void:
	_track_camera(delta)
	_step_countdown(delta)
	_refresh_blind(delta)
	if _shot_player != null and _shot_player.is_playing():
		_moves_fx.sync(_shot_player.time())
	_step_digs()
	if _clock < _quake_until and _clock >= _quake_next:
		_quake_next = _clock + QUAKE_EVERY
		_cam.shake(QUAKE_SHAKE)
	_release_fall_hold()
	_release_flight_hold()
	_update_bombers()
	if _wave_fx != null and is_instance_valid(_wave_fx) and _shot_player.is_playing():
		_wave_fx.sync(_shot_player.time())
	if _awaiting_ack > 0.0:
		_awaiting_ack -= delta
		if _awaiting_ack <= 0.0:
			# The server ignored the Shoot/EndTurn/UseItem: give control back.
			_clear_my_aim() # a gun still out for an unanswered Shoot goes away
			_committing = false
			_commit_sent = false
			_cmd_sent = false
			_awaiting_item = ""
			_refresh_controls()
			if _armed == WEAPON:
				_hold_badge(_me, {}) # a no-aim skill's badge shown at the tap: never answered
	# Once the shot is answered the server takes no Moves until TurnStarted: sending one (e.g.
	# a walk after SHOT_ACK_TIMEOUT gave control back, then a late ShotResolved) would only
	# lose it and send Reconnect in the middle of the replay.
	if not _is_my_turn() or _commit_sent or _turn_resolved:
		return
	if _hold_dir != 0 and _can_act() and not _is_rooted():
		_moves.hold(_hold_dir, delta)
	# Runs while a Shoot/EndTurn waits too, so the rest of the walk (and a re-send of an
	# unanswered Move) still goes out before it; _commit_action waits for them.
	var cmd := _moves.update(Time.get_ticks_msec() / 1000.0, _since(_action_at) >= _action_interval())
	if not cmd.is_empty():
		GameSocket.send("Move", cmd)
		_mark_action()
	if _moves.needs_resync():
		_request_resync(delta)
	if not _shot_player.is_playing():
		var changes := _moves.take_changes()
		if changes.has("position"):
			_views[_me].follow_walk(changes["position"]) # drawn along the surface (WalkPath)
			_aim.shooter_pos = changes["position"]
			if _fell_out():
				_refresh_controls() # walked into a hole to the bottom: no more input
		if changes.has("energy"): # may change alone, e.g. when dropped Moves were not charged
			_hud.set_energy(changes["energy"])


# ── Snapshot and turn state ──────────────────────────────────────────────────

## The map theme (MatchStarted / MatchStateSync mapTheme, else the map catalog's, else
## grassland) on the sky, the terrain's materials and the bottom; nothing when unchanged.
func _apply_theme(theme: String) -> void:
	if theme == _theme:
		return
	_theme = theme
	_sky.show_theme(theme)
	_terrain_view.show_theme(theme)
	if _bottom != null:
		_bottom.setup(theme, Vector2(_mask.width, _mask.height), Art.SKY_MARGIN)


## Rebuilds the match from a snapshot: MatchStarted (is_sync false) or a MatchStateSync. A
## MatchStateSync for the current player continues the turn: during mine MoveSync replays the
## Moves the snapshot does not show yet on top of it, and a resolved shot keeps input locked
## and the clock paused.
func _load_snapshot(snap: Dictionary, is_sync: bool) -> void:
	var current := str(snap.get("currentPlayerId", ""))
	var continuing := is_sync and current == _current
	_shot_player.stop()
	_digs.clear() # the snapshot's terrain has the tunnels
	_moves_fx = BossMoves.new()
	_quake_until = -1.0
	_deferred.clear()
	_fall_hold = false
	_flight_hold = false
	_energy_reveal.clear() # the snapshot's energies are shown as they are
	_shot_badge = {}
	_held_badges.clear() # the views are rebuilt: selectedAction brings the current one back
	var terrain: Dictionary = snap.get("terrain", {})
	if not terrain.is_empty() and _mask.load_snapshot(terrain):
		# A sync without mapTheme (an older server) keeps the theme MatchStarted gave.
		_apply_theme(MapThemes.theme_of(snap) if _theme == "" or not is_sync or snap.has("mapTheme") else _theme)
		_terrain_view.show_mask(_mask)
		_set_map_size(Vector2(_mask.width, _mask.height))
	for view in _views.values():
		view.queue_free()
	_views.clear()
	_players = snap.get("players", {}).duplicate(true)
	_fill_badges()
	var my_team := int(_players.get(_me, {}).get("teamId", -1))
	for id in _players:
		var view := PlayerView.new()
		view.walk.terrain = _mask
		_players_layer.add_child(view)
		view.setup(_players[id], id == _me, my_team)
		view.face(1.0 if view.position.x < _mask.width / 2.0 else -1.0) # towards the middle
		_views[id] = view
		# a shield's bubble keeps the colour of its caster when known, else the player's own gun's
		var sh = _players[id].get("shield")
		_shields.update(id, int(sh) if sh is int or sh is float else 0, "", _gun_tier(id))
		view.set_shield_tint(_shields.colour_of(id))
		_leaps.on_state(id, _players[id], int(snap.get("turnIndex", _turn_index)), current)
		view.set_leapt(_leaps.warning(id))
	_load_boss(snap)
	_wind = snap.get("wind", _wind)
	_turn_index = int(snap.get("turnIndex", _turn_index))
	var energy := int(_players.get(_me, {}).get("moveEnergy", 0))
	if is_sync and _players.has(_me) and _players[_me].has("position"):
		# Every MatchStateSync goes through MoveSync. lastMoveSeq (absent on an older server: -1)
		# says which of my Moves the snapshot already shows.
		var last_seq = snap.get("lastMoveSeq")
		_moves.apply_snapshot(_pos(_me), energy, int(last_seq) if (last_seq is int or last_seq is float) else -1)
	_hud.set_time(int(snap.get("turnTimeLeft", GameData.turn_sec())))
	_skip = Status.skip_effect(_players.get(current, {}).get("statusEffects")) # a lost turn goes on
	_start_countdown({}) # a snapshot has no skipAfter: the views are new, no countdown
	if continuing and _turn_resolved:
		_hud.pause_timer() # this turn's shot is resolving: the server clock waits for TurnStarted
	_focus.clear()
	if not is_sync and _players.has(_me) and _players[_me].has("position"):
		_cam.snap(_pos(_me) + _look_lift(_me)) # the match starts on me, then pans to whoever plays first
		_cam.hold(START_HOLD)
	_set_current(current, energy, continuing)
	_restore_selection(snap.get("selectedAction"), current)


## continuing: the same turn goes on (a MatchStateSync for the current player), so MoveSync, a
## sent Shoot/EndTurn and a resolved shot are kept; otherwise a new turn starts.
func _set_current(player_id: String, move_energy: int, continuing: bool = false) -> void:
	_current = player_id
	_hold_dir = 0
	_resync_in = 0.0
	if not continuing:
		_armed = WEAPON # every turn starts with the weapon
		_sent_select = WEAPON # and so does the server's selection
		for id in _held_badges.keys(): # the turn passed without that shot
			_hold_badge(id, {})
		_awaiting_ack = 0.0
		_awaiting_item = ""
		_committing = false
		_commit_sent = false
		_cmd_sent = false
		_turn_resolved = false
		if _is_my_turn():
			_moves.reset(_pos(_me), move_energy)
		if _players.get(player_id, {}).has("position"):
			var flier = _views.get(player_id)
			_cam.sky_turn = flier != null and "flying" in flier and flier.flying # a flier high up: the view may rise into the sky
			_cam.pan_to(_pos(player_id) + _look_lift(player_id)) # waits for an explosion's hold
	if _views.has(_me) and _players[_me].has("position"):
		# Leaving my turn with Moves unanswered or unsent (or with my last PlayerMoved in the
		# same frame) leaves the view on the prediction: walk it to the server's position. My
		# turn starts there (a walk already heading there goes on).
		var view = _views[_me]
		var to := _pos(_me)
		if not _is_my_turn():
			view.walk_to(to, _other_walk_max())
		elif not view.walk.active() or view.walk.target() != to:
			view.move_to(to, 0.0)
	var turn_player: Dictionary = _players.get(player_id, {})
	var my_team := int(_players.get(_me, {}).get("teamId", -1))
	_hud.set_turn(_is_my_turn(), str(turn_player.get("displayName", "")), turn_player,
		my_team < 0 or int(turn_player.get("teamId", -2)) == my_team)
	_hud.set_wind(int(_wind.get("direction", 0)), float(_wind.get("power", 0.0)))
	_show_wind()
	for id in _views:
		_views[id].set_active(id == player_id and not _ended)
	_hud.set_energy(move_energy if _is_my_turn() else 0, _max_energy())
	_refresh_controls()


## My full move energy (BattlePlayerState.maxMoveEnergy: the character's base + bonuses), the
## energy bar's maximum; the game data's movement.defaultMoveEnergy from a server that does not
## send it.
func _max_energy() -> int:
	var v = _players.get(_me, {}).get("maxMoveEnergy")
	return int(v) if (v is int or v is float) and v > 0 else GameData.default_move_energy()


func _is_my_turn() -> bool:
	return not _ended and _current == _me and bool(_players.get(_me, {}).get("isAlive", false))


func _can_act() -> bool:
	return _is_my_turn() and not _shot_player.is_playing() and not _committing and not _turn_resolved \
		and not _moves.needs_resync() and _skip == "" and not _data_wait and not _fell_out()


## My walk (the prediction) ended below the map: I am falling out, the server takes nothing more.
func _fell_out() -> bool:
	return _mask.height > 0 and _moves.position.y >= _mask.height


## A blocksMove effect (root, stun, freeze) keeps me from walking and teleporting this turn.
func _is_rooted() -> bool:
	return Status.blocks_move(_players.get(_me, {}).get("statusEffects"))


## A skipsTurn effect (stun, freeze) is on me: no shot this turn.
func _is_frozen() -> bool:
	return Status.skip_effect(_players.get(_me, {}).get("statusEffects")) != ""


## Also drops the armed mode back to the weapon when it can no longer be fired: not my turn, the
## turn resolved, I am frozen, the skill is not charged, or the armed item is no longer in
## players[me].items. A temporary input lock (pending UseItem ack, commit wait, shot animation,
## resync) keeps the armed mode: the buttons are disabled meanwhile but the choice survives.
## A special once armed (the skill or a shot item) is kept for the turn: the other shot slots
## are off (ActionLock); instant items stay usable.
func _refresh_controls() -> void:
	var can := _can_act()
	var me: Dictionary = _players.get(_me, {})
	# Stunned / frozen: the whole turn is lost (_can_act is false); rooted: no walking or teleport.
	var frozen := _skip != "" and _is_my_turn()
	var rooted := _is_my_turn() and _is_rooted()
	var can_shoot := can and not frozen
	var may_shoot := _is_my_turn() and not _turn_resolved and not frozen # armed mode may stay
	_hud.set_controls_enabled(can and not rooted)
	_hud.set_move_notice(Status.move_block_text(me.get("statusEffects")) if rooted and _skip == "" else "")
	var skill := _my_skill()
	var energy := int(me.get("skillEnergy", 0))
	var armed_ok := _armed == WEAPON or (_armed == SKILL and may_shoot and not skill.is_empty() and Skills.is_ready(energy))
	for it in Items.hand(me.get("items")):
		if it["id"] == _armed and may_shoot and not Items.is_instant(it["id"]):
			armed_ok = true
	if not armed_ok:
		_armed = WEAPON
	var skill_usable := ActionLock.slot_enabled(_armed, SKILL, can_shoot and not skill.is_empty() and Skills.is_ready(energy))
	var buttons: Array = []
	for it in Items.hand(me.get("items")):
		var usable := can if Items.is_instant(it["id"]) else ActionLock.slot_enabled(_armed, it["id"], can_shoot)
		if Items.moves_user(it["id"]) and rooted:
			usable = false
		buttons.append({"id": it["id"], "count": it["count"], "name": Items.label(it["id"]), "enabled": usable})
	_hud.set_actions(skill, energy, skill_usable, _armed, buttons)
	_sync_selection()
	var aim_mode := str(skill.get("aim", SkillView.AIM_ARC)) if _armed == SKILL else SkillView.AIM_ARC
	var offsets: Array = skill["offsets"] if _armed == SKILL and aim_mode == SkillView.AIM_ARC else [0.0]
	if _aim.preview_offsets != offsets:
		_aim.preview_offsets = offsets
	if _aim.line_mode != (aim_mode == SkillView.AIM_LINE):
		_aim.line_mode = aim_mode == SkillView.AIM_LINE
	_aim.target_column = Items.needs_target_x(_armed)
	_aim.enabled = can_shoot
	if can:
		_aim.shooter_pos = _views[_me].position
		_aim.terrain = _mask
		_aim.wind_dir = int(_wind.get("direction", 0))
		_aim.wind_power = float(_wind.get("power", 0.0))
		_set_aim_aid(me)
	else:
		_hold_dir = 0


## What the aiming aid needs for my next shot: my rank tier (the guide arc's length), my
## character's weapon's wind response (the game data's weapons: windInfluence / projectileWeight;
## 1 / 1 for a weapon it does not know), a drill's pierce (Items.pierce()), and the alive enemies'
## body centres (the exact flight stops on them; "Trúng!").
func _set_aim_aid(me: Dictionary) -> void:
	_aim.rank_tier = PlayerState.rank_tier()
	var weapon_id := GameData.character_weapon_id(str(me.get("characterId", "")))
	var influence := GameData.weapon_wind_influence(weapon_id)
	var weight := GameData.weapon_projectile_weight(weapon_id)
	_aim.wind_influence = influence if GameData.weapon(weapon_id).has("windInfluence") else 1.0
	_aim.projectile_weight = weight if weight > 0.0 else 1.0
	_aim.pierce = Items.pierce(_armed)
	var my_team := int(me.get("teamId", -1))
	var centres := PackedVector2Array()
	var radii := PackedFloat32Array()
	for id in _players:
		var p: Dictionary = _players[id]
		if id == _me or not bool(p.get("isAlive", false)) or int(p.get("teamId", -2)) == my_team or not p.has("position"):
			continue
		var body := PlayerView.body_size_of(p)
		centres.append(_pos(id) + Trajectory.shot_offset() * body)
		radii.append(GameData.player_hit_radius() * body)
	_aim.enemies = centres
	_aim.enemy_radii = radii


## The least time between two of my actions: the server's actionIntervalSec plus ACTION_MARGIN.
func _action_interval() -> float:
	return GameData.action_interval_sec() + ACTION_MARGIN


## The longest another player's walk is drawn: it ends before a bot's next action.
func _other_walk_max() -> float:
	return maxf(GameData.bot_follow_up_delay_sec() - OTHER_WALK_LEAD, 0.0)


## A MatchStarted / MatchStateSync whose gamedataVersion is not held: fetch that version
## (PlayerState.load_match_gamedata(): GET /gamedata?version=, the plain GET on a 404) before I
## may aim or act (_data_wait keeps _can_act() false), "Đang cập nhật dữ liệu..." after
## DATA_NOTICE_SEC. A failed fetch keeps the copy in use and lets the match go on. The match
## keeps its version to the end (_exit_tree(): GameData.end_match()).
func _check_gamedata(snap: Variant) -> void:
	if _data_wait or not snap is Dictionary or not GameData.needs_refetch(snap.get("gamedataVersion")):
		return
	_data_wait = true
	_refresh_controls()
	get_tree().create_timer(DATA_NOTICE_SEC).timeout.connect(func() -> void:
		if _data_wait and is_instance_valid(_hud):
			_hud.set_data_notice(DATA_NOTICE))
	await PlayerState.load_match_gamedata(str(snap["gamedataVersion"]))
	_data_wait = false
	if is_instance_valid(_hud):
		_hud.set_data_notice("")
		_refresh_controls()


# ── Server events ────────────────────────────────────────────────────────────

func _on_event(event: String, data: Variant) -> void:
	if event == "MatchStateSync":
		if data is Dictionary:
			GameData.use_match(data.get("gamedataVersion"))
		_load_snapshot(data, true)
		_check_gamedata(data)
		return
	if event in ["PlayerAiming", "TurnStarted"] and data is Dictionary:
		data = data.duplicate()
		data["receivedAt"] = Time.get_ticks_usec() # a replay may hold it back: show only what is left
	if _shot_player.is_playing() or _fall_hold or _flight_hold:
		_deferred.append([event, data])
		return
	if _waits_for_fall(event, data):
		_fall_hold = true
		_deferred.append([event, data])
		return
	_apply(event, data)


## A PlayerDamaged out_of_map for a player whose walk still falls out of the map on screen
## (PlayerMoved outOfMap came first): its death waits for the fall.
func _waits_for_fall(event: String, data: Variant) -> bool:
	if event != "PlayerDamaged" or not data is Array:
		return false
	for e in data:
		if e is Dictionary and str(e.get("type", "")) == OUT_OF_MAP:
			var view = _views.get(str(e.get("playerId", "")))
			if view != null and view.falling_out():
				return true
	return false


## Applies the events held back by a replay or a fall, in order, until another one holds them.
func _flush_deferred() -> void:
	while not _deferred.is_empty() and not _shot_player.is_playing() and not _fall_hold and not _flight_hold:
		var item: Array = _deferred[0]
		if _waits_for_fall(item[0], item[1]):
			_fall_hold = true
			break
		_deferred.pop_front()
		_apply(item[0], item[1])


func _apply(event: String, data: Variant) -> void:
	match event:
		"TurnStarted":
			_wind = data.get("wind", _wind)
			var index := int(data.get("turnIndex", _turn_index + 1))
			if index > _turn_index and _players.has(_current):
				_tick_status(_current) # the server ticks the effects at the end of their target's turn
				_end_leap(_current, _turn_index)
			_turn_index = maxi(index, _turn_index)
			var energies = data.get("skillEnergy") # every player's (the end-of-turn +20 in it)
			if energies is Dictionary:
				_show_energies(energies)
			var left = data.get("turnTimeLeft")
			_hud.set_time(int(left) if left is int or left is float else GameData.turn_sec())
			for view in _views.values():
				view.clear_aim() # guns put away
			var current := str(data.get("currentPlayerId", ""))
			if _players.has(current) and data.has("maxMoveEnergy"):
				_players[current]["maxMoveEnergy"] = data["maxMoveEnergy"]
			# A lost turn (stun / freeze): the server sends skipped; an older one does not, then
			# the effects tell.
			var skipped = data.get("skipped")
			_skip = str(skipped) if skipped is String else Status.skip_effect(_players.get(current, {}).get("statusEffects"))
			if _boss.active:
				_boss.on_turn_started(data)
				if data.has("lavaZones"):
					_lava.set_all(data["lavaZones"])
					_lava_view.sync(_lava.zones)
				if data.get("marks") is Array:
					_marks.set_all(data["marks"])
					_mark_view.sync(_marks.marks, true)
				_hud.set_boss(_boss.state())
			_set_current(current, int(data.get("moveEnergy", 0)))
			_start_countdown(data)
		"TurnTimerTick":
			_hud.set_time(int(data.get("timeLeft", 0)))
		"PlayerMoved":
			_on_player_moved(data)
		"PlayerAiming":
			_on_player_aiming(data)
		"ActionSelected":
			_on_action_selected(data)
		"ShotResolved":
			_awaiting_ack = 0.0
			var shooter := str(data.get("shooterId", ""))
			_count_damage(shooter, data.get("events"))
			var timeline := ShotTimeline.new(data)
			# A boss's free summon (v3) and its turn start (v4) do not end its turn: its attack follows.
			if timeline.action_mode != SUMMON and timeline.action_mode != TURN_START:
				_turn_resolved = true # the server takes no more actions until TurnStarted
			elif timeline.action_mode == SUMMON and _boss.active and shooter == _boss.player_id:
				_hud.announce_boss_skill(_summon_name())
			_hud.pause_timer() # resumed by the next TurnTimerTick / TurnStarted
			_snap_to_server(shooter)
			_shot_timeline = timeline
			if _boss.active or timeline.action_mode == BlastEvents.SELF_DESTRUCT:
				_tag_blasts(timeline, shooter)
			# The energies after the shot (0 for a skill's shooter, +10 for each enemy hit) wait
			# for their moment in the replay.
			_energy_reveal.begin(timeline, _players)
			_shot_badge = {"shooter": shooter, "content": UseBadge.content(timeline.action_mode, timeline.skill_id, timeline.item_id)}
			# The shot looks like the shooter's gun (visuals only): the kind and tier of the weapon
			# it brought (weaponItemId), its character's basic gun when none (bots).
			_shot_player.style = ShotLook.style_for(_players.get(shooter, {}), str(data.get("actionMode", "")),
				str(data.get("itemId", "")), PlayerState.catalog)
			var boss_look: Dictionary = BossArt.SHOT_LOOK.get(str(_players.get(shooter, {}).get("bossId", "")), {})
			if str(_players.get(shooter, {}).get("role", "")) == "boss" and not boss_look.is_empty():
				_shot_player.style["kind"] = boss_look["kind"]
				_shot_player.style["tier"] = boss_look["tier"]
			_skill_view = null
			_tallies.clear() # the last shot's tallies finish on their own
			if timeline.action_mode == SKILL:
				_skill_view = Skills.view_for_skill(timeline.skill_id)
			elif timeline.action_mode == ITEM:
				_skill_view = ItemViews.view_for(timeline) # a shot item's visuals (poison cloud, nuke, laser), null none
			if _skill_view != null:
				_skill_view.begin({"layer": _fx_layer, "timeline": timeline, "style": _shot_player.style,
					"views": _views, "players": _players, "shooter": shooter, "terrain": _mask, "screen": _screen_fx,
					"wind": int(_wind.get("direction", 0))})
				_shot_player.skill_view = _skill_view
			var framed: bool = _skill_view != null and _skill_view.frames_map()
			if _boss.active and shooter == _boss.player_id and _start_shockwave(timeline):
				framed = true
			var wide_summon := timeline.action_mode == SUMMON and _summons_spread(timeline.events)
			var lead_in := _show_shooting(shooter, timeline)
			_cast_shards(shooter, timeline)
			_play_boss_action(shooter, timeline)
			_focus.clear()
			_cam.start_shot()
			var area: Vector2 = _skill_view.frame_size() if _skill_view != null else Vector2.ZERO
			if area != Vector2.ZERO and not framed: # a wide skill (Tide's nova): its whole area in view
				_cam.frame_size(area)
				if _skill_view.has_method("centre"):
					_hold_focus({"pos": _skill_view.centre()}, timeline.duration + 0.4)
			if framed:
				_cam.frame_map()
				_hud.fade_boss_skill() # the map's top (the boss in the air) comes under it
			elif wide_summon:
				_cam.frame_map() # a wave over the whole map: all of it in view (Triệu hồi stays)
			elif _boss.active:
				_frame_ground(timeline.events, timeline.duration + 0.5)
			if _boss.active:
				_begin_v4(timeline, shooter)
			_shot_player.play(timeline, lead_in)
			_refresh_controls()
		"PlayerDamaged": # lava / burn at turn start, out_of_map after a walk's fall (shot damage comes in ShotResolved)
			for e in data:
				var id := str(e.get("playerId", ""))
				_set_hp(id, int(e.get("hp", 0)))
				if e.get("shield") is int or e.get("shield") is float:
					_set_shield(id, int(e["shield"]))
				var amount := int(e.get("damage", 0))
				if amount > 0 and str(e.get("type", "")) == POISON: # the poison tick: a green number, a puff of spores
					_popup(id, DamagePopup.damage_text(amount), DamagePopup.POISON)
					if _views.has(id):
						var puff := SporeFx.new(SporeFx.TICK, 34.0 * maxf(_views[id].body_size, 1.0))
						puff.position = _views[id].body_centre()
						_fx_layer.add_child(puff)
				elif amount > 0 and str(e.get("type", "")) != OUT_OF_MAP: # fallen out: no number, the body is gone below
					var burn := str(e.get("type", "")) in ["burn", "lava"]
					_popup(id, DamagePopup.damage_text(amount), Color(1.0, 0.55, 0.15) if burn else Color(1, 0.3, 0.3))
					if burn and _views.has(id): # the burn tick: a fire flash over the body
						var flash := BurnFx.new()
						flash.position = _views[id].position
						_fx_layer.add_child(flash)
				if not bool(e.get("isAlive", true)):
					_kill(id)
		"ItemUsed":
			_on_item_used(data)
		"BossShieldChanged":
			_on_boss_shield(data)
		"UnitFlew":
			_on_unit_flew(data)
		"UnitJumped":
			_on_unit_jumped(data)
		"MatchEnded":
			_on_match_ended(data)


## The fall out of the map is drawn (the body out of sight): its death and what came after it.
func _release_fall_hold() -> void:
	if _fall_hold and not _any_falling_out():
		_fall_hold = false
		_flush_deferred()
		_refresh_controls()


func _any_falling_out() -> bool:
	for view in _views.values():
		if view.falling_out():
			return true
	return false


## Another player aims (the server sends it for bots): its gun swings onto the angle the shot will
## be fired with over durationMs, less the time a replay held the event back. Only for the
## current, living player before its shot; mine is aimed by my own drag.
func _on_player_aiming(d: Variant) -> void:
	if not d is Dictionary:
		return
	var id := str(d.get("playerId", ""))
	if id == _me or id != _current or _ended or _turn_resolved or not _views.has(id) \
			or not bool(_players.get(id, {}).get("isAlive", false)):
		return
	var left := float(d.get("durationMs", 0)) / 1000.0
	if d.has("receivedAt"):
		left -= _since(int(d["receivedAt"]))
	if left < MIN_AIM_SEC:
		return # ShotResolved draws the gun fast, as without PlayerAiming
	_views[id].aim_sweep(float(d.get("angle", 90.0)), left)
	var from: Vector2 = _views[id].position + Trajectory.shot_offset()
	_cam.start_aim(from, from + _aim_dir(float(d.get("angle", 90.0))) * REMOTE_LOOK)


## Another player armed its skill or a shot item (or went back to the weapon): its badge shows and
## is held until its shot fires, "weapon" or the turn passing. Mine follows my own arming.
func _on_action_selected(d: Variant) -> void:
	if not d is Dictionary:
		return
	var id := str(d.get("playerId", ""))
	if id == _me or id != _current or _ended or _turn_resolved or not _views.has(id) \
			or not bool(_players.get(id, {}).get("isAlive", false)):
		return
	if _boss.active and id == _boss.player_id and str(d.get("actionMode", "")) == SKILL:
		_hud.announce_boss_skill(str(GameData.boss_skill(_boss.boss_id, str(d.get("skillId", ""))).get("name", "")))
	elif _boss.active and id == _boss.player_id and str(d.get("actionMode", "")) == SUMMON:
		_hud.announce_boss_skill(_summon_name())
		return
	_hold_badge(id, UseBadge.content(str(d.get("actionMode", "")), str(d.get("skillId", "")), str(d.get("itemId", ""))))


## The badge of what my armed mode fires ({} for the weapon).
func _armed_content() -> Dictionary:
	if _armed == SKILL:
		return UseBadge.content(SKILL, str(_my_skill().get("id", "")), "")
	if _armed == WEAPON:
		return {}
	return UseBadge.content("item", "", _armed)


## Shows `content` over player id and holds it (its shot's badge goes on from it); {} ends the
## held one (an instant item's badge shown meanwhile stays).
func _hold_badge(id: String, content: Dictionary) -> void:
	var view = _views.get(id)
	var old: Dictionary = _held_badges.get(id, {})
	if content == old and (content.is_empty() or (view != null and view.badge() == content)):
		return
	_held_badges.erase(id)
	if view == null:
		return
	if not old.is_empty() and old != content:
		view.release_held_badge(old)
	if not content.is_empty():
		_held_badges[id] = content
		view.show_badge(content)


## My armed mode changed in my turn (before my shot): tell the server (SelectAction, everyone sees
## the badge) and show my badge at once. Not after the Shoot went out: the shot carries it.
func _sync_selection() -> void:
	if not _is_my_turn() or _turn_resolved or _commit_sent or _armed == _sent_select:
		return
	_sent_select = _armed
	var data := {"actionMode": WEAPON}
	if _armed == SKILL:
		data["actionMode"] = SKILL
	elif _armed != WEAPON:
		data = {"actionMode": "item", "itemId": _armed}
	_send("SelectAction", data)
	_hold_badge(_me, _armed_content())


## MatchStateSync's selectedAction (the current player's armed skill / shot item; absent: the
## weapon, or a server without it): another player's badge comes back; for me it is what the
## server has, and my own armed mode (kept through a resync of my turn) shows and is sent again
## when they differ.
func _restore_selection(sel: Variant, current: String) -> void:
	var has: bool = sel is Dictionary and str(sel.get("playerId", "")) == current
	if current == _me:
		_sent_select = WEAPON
		if has:
			var mode := str(sel.get("actionMode", ""))
			_sent_select = SKILL if mode == SKILL else (str(sel.get("itemId", "")) if mode == "item" else WEAPON)
		if _is_my_turn() and not _turn_resolved:
			_hold_badge(_me, _armed_content())
		_refresh_controls()
	elif has and not _turn_resolved:
		_on_action_selected(sel)


func _send(event: String, data: Dictionary) -> void:
	if send_hook.is_valid():
		send_hook.call(event, data)
	else:
		GameSocket.send(event, data)


## ItemUsed carries every player's state (hp, items, statusEffects...) and the wind. For a shot
## item it comes before ShotResolved and the Shoot stays pending; for my UseItem it is the answer.
func _on_item_used(d: Dictionary) -> void:
	_wind = d.get("wind", _wind)
	var players = d.get("players")
	if players is Dictionary:
		for id in players:
			if not _players.has(id) or not players[id] is Dictionary:
				continue
			var p: Dictionary = players[id].duplicate(true)
			_players[id] = p
			_views[id].set_hp(int(p.get("hp", 0)), int(p.get("maxHp", -1)))
			_views[id].set_status(p.get("statusEffects"))
			if p.get("skillEnergy") is int or p.get("skillEnergy") is float:
				_views[id].set_skill_energy(int(p["skillEnergy"]))
			if p.get("shield") is int or p.get("shield") is float:
				_set_shield(id, int(p["shield"]))
			if not bool(p.get("isAlive", true)):
				_views[id].set_dead()
			_leaps.on_state(id, p, _turn_index, _current)
			_views[id].set_leapt(_leaps.warning(id))
	_hud.set_wind(int(_wind.get("direction", 0)), float(_wind.get("power", 0.0)))
	_show_wind()
	# An instant item shows its badge now; a shot item's comes with its shot (one badge, not two).
	var used := str(d.get("itemId", ""))
	var user := str(d.get("playerId", ""))
	if Items.is_instant(used) and _views.has(user):
		_views[user].show_badge(UseBadge.content("item", "", used), ITEM_BADGE_SEC)
	if str(d.get("playerId", "")) == _me and _awaiting_item != "" and str(d.get("itemId", "")) == _awaiting_item:
		_awaiting_item = ""
		_awaiting_ack = 0.0
		_cmd_sent = false
		_committing = false
	_refresh_controls()


func _on_player_moved(d: Dictionary) -> void:
	var id := str(d.get("playerId", ""))
	if not _players.has(id):
		return
	var pos := Vector2(float(d["position"]["x"]), float(d["position"]["y"]))
	var energy := int(d.get("moveEnergy", 0))
	_players[id]["position"] = {"x": pos.x, "y": pos.y}
	_players[id]["moveEnergy"] = energy
	if id == _me and _is_my_turn():
		# Rebase: server state plus our unacknowledged commands. _process shows the result;
		# when the prediction was right (the normal case) nothing visibly changes.
		var was_lost := _moves.needs_resync()
		_moves.on_server_moved(pos, energy, int(d.get("seq", 0)))
		_move_ack_at = Time.get_ticks_usec()
		if was_lost and not _moves.needs_resync():
			_resync_in = 0.0
			_refresh_controls() # the newest Move's late answer unlocks input
		if bool(d.get("outOfMap", false)):
			# The walk ended in a hole down to the bottom (nothing walks on from there): drawn
			# now, so the PlayerDamaged right behind it waits for the fall.
			_views[id].follow_walk(_moves.position)
			_drop_out_of_sight(id, pos)
		return
	_views[id].walk_to(pos, _other_walk_max()) # along the surface, a drop as a fall
	if bool(d.get("outOfMap", false)):
		_drop_out_of_sight(id, pos)


## A walk out of the map the drawn path does not reach (a correction): the body still drops out
## of sight below the bottom.
func _drop_out_of_sight(id: String, pos: Vector2) -> void:
	var view = _views[id]
	if view.falling_out() or view.walk.falls_out():
		return
	var g := GameData.gravity()
	var below := Vector2(pos.x, pos.y + WalkPath.OUT_DROP)
	var drop := maxf(below.y - view.position.y, 1.0)
	view.move_to(below, sqrt(2.0 * drop / g) if g > 0.0 else 0.3, Tween.TRANS_QUAD, Tween.EASE_IN)


## The shell leaves from the server's position: a walk still under way to it ends within
## SNAP_WALK_SEC; a shooter drawn anywhere else is put there before the replay starts.
func _snap_to_server(id: String) -> void:
	if _views.has(id) and _players.has(id) and _players[id].has("position"):
		var view = _views[id]
		if view.walk.active() and view.walk.target() == _pos(id):
			view.hurry_walk(SNAP_WALK_SEC)
		else:
			view.move_to(_pos(id), 0.0)


func _on_shot_event(e: Dictionary) -> void:
	var id := str(e.get("playerId", ""))
	match str(e.get("type", "")):
		"explode":
			_finish_digs() # the shell explodes at the end of its tunnel: all of it is open
			if not BlastEvents.blast_of(e).is_empty():
				_unit_blast(e)
				return
			if e.get(Shockwave.STEP_KEY, false):
				_wave_step(e)
				return
			var p := _vec(e["position"])
			var radius := float(e.get("radius", 0.0))
			# crater: the shape (always a bowl now; a circle is still carved). The view uploads
			# only the tiles the crater and its scorched edge touched.
			_mask.carve(str(e.get("crater", TerrainMask.CRATER_BOWL)), p.x, p.y, radius)
			_terrain_view.refresh()
			var fx := ExplosionFx.new()
			# The burst covers the crater and the damage area (the blast radius can be the larger)
			fx.radius = maxf(radius, _shot_timeline.blast_radius(str(e.get("projectileId", ""))) if _shot_timeline != null else 0.0)
			var reach = e.get("blastRadius") # a boss's slam: its blast's reach (radius is the crater)
			if (reach is int or reach is float) and float(reach) > fx.radius:
				fx.radius = float(reach)
			var unit_kind := _shot_timeline.kind_of(str(e.get("projectileId", ""))) if _shot_timeline != null else ""
			if UnitShell.is_kind(unit_kind): # a boss's / minion's own projectile: its own impact
				var hit := UnitImpact.new(unit_kind, fx.radius)
				hit.position = p
				_fx_layer.add_child(hit)
				fx.free()
				_hold_focus({"pos": p}, CameraModel.HOLD_SEC)
				_cam.shake(hit.radius * 0.6)
				_check_terrain_version(e)
				if _skill_view != null:
					_skill_view.on_event(e)
				return
			fx.kind = str(_shot_player.style.get("kind", ""))
			fx.tier = str(_shot_player.style.get("tier", ""))
			fx.skill = bool(_shot_player.style.get("skill", false))
			fx.position = p
			if fx.kind == WATER_GUN and _skill_view == null: # the water orb bursts: a splash over its impact
				var burst := WaterSplash.new()
				burst.big = true
				burst.radius = maxf(fx.radius * 1.3, 46.0)
				burst.position = p
				_fx_layer.add_child(burst)
			if _skill_view != null:
				_skill_view.explosion(e, fx)
			_fx_layer.add_child(fx)
			_hold_focus({"pos": p}, CameraModel.HOLD_SEC)
			_cam.shake(fx.radius)
			_check_terrain_version(e)
		"damage":
			_set_hp(id, int(e.get("hp", 0)))
			if e.get("shield") is int or e.get("shield") is float:
				_set_shield(id, int(e["shield"]))
			var crit := bool(e.get("critical", false))
			if str(e.get("cause", "")) == OUT_OF_MAP:
				pass # fell out of the bottom: no number, the body drops out of sight
			elif _skill_view != null and _skill_view.merges_damage():
				_tally(id, int(e.get("amount", 0)), crit, DamagePopup.effect_of(e))
			elif _boss.active and id == _boss.player_id and _boss.armored(): # the armour took most of it
				_popup(id, DamagePopup.damage_text(int(e.get("amount", 0))), Color.WHITE, Vector2.ZERO,
					DamagePopup.armored_style(DamagePopup.effect_of(e), crit, not _armor_tagged))
				_armor_tagged = true
			else:
				_damage_popup(id, int(e.get("amount", 0)), crit, DamagePopup.effect_of(e)) # elementEffect styles it
			if str(e.get("cause", "")) == ERUPTION and _views.has(id): # thrown up a little (cosmetic)
				_views[id].hop()
			elif str(e.get("cause", "")) == GLOBAL:
				_global_hit(id)
			elif str(e.get("cause", "")) == ROLL and _views.has(id): # crushed by the boulder
				_views[id].hop(22.0, 0.32)
			if not _drain.is_empty() and _views.has(id) and id != _boss.player_id:
				_drain_from(id, float(e.get("t", 0.0)))
			_show_energies(_energy_reveal.on_event(e)) # the hit's +10, after the HP drop
		"heal":
			_set_hp(id, int(e.get("hp", 0)))
			var amount := int(e.get("amount", 0))
			if amount > 0:
				_popup(id, DamagePopup.heal_text(amount), DamagePopup.HEAL)
			if _views.has(id) and str(e.get("cause", "")) in [DRAIN, REGEN]: # the boss heals: its glow
				_views[id].heal_glow()
				if str(e.get("cause", "")) == REGEN:
					_links.pulse_regen()
		"shield": # Flora's bloom: the bubble in the caster's gun tier colour
			if e.get("shield") is int or e.get("shield") is float:
				_set_shield(id, int(e["shield"]), _shot_timeline.shooter_id if _shot_timeline != null else "")
			var gained := int(e.get("amount", 0))
			if gained > 0:
				_popup(id, shield_text(gained), Color(0.62, 0.9, 1.0), Vector2(0, -28))
		"cleanse":
			if _players.has(id):
				_players[id]["statusEffects"] = Status.remove(_players[id].get("statusEffects"), e.get("effectIds"))
				_views[id].set_status(_players[id]["statusEffects"])
				if id == _me:
					_refresh_controls()
		"fall":
			var to := _vec(e["to"])
			_set_pos(id, to)
			if _views.has(id):
				var sec := float(e.get("duration", 0.0))
				var drawn_to := to
				if to.y >= _mask.height and _mask.height > 0:
					# Out of the bottom of the map: on down past it with the same gravity, out of
					# sight (the view fades below the bottom); its damage and die come at the bottom.
					drawn_to.y += WalkPath.OUT_DROP
					if e.get("from") is Dictionary:
						var drop := to.y - _vec(e["from"]).y
						if drop > 0.0:
							sec *= sqrt((drop + WalkPath.OUT_DROP) / drop)
				_views[id].move_to(drawn_to, sec, Tween.TRANS_QUAD, Tween.EASE_IN)
				_hold_focus({"view": _views[id]}, sec + FALL_TAIL)
		"teleport":
			var to := _vec(e["to"])
			_set_pos(id, to)
			if _views.has(id):
				if e.get("from") is Dictionary:
					_views[id].position = _vec(e["from"])
				_views[id].move_to(to, TELEPORT_SEC, Tween.TRANS_SINE)
				_hold_focus({"view": _views[id]}, TELEPORT_SEC + CameraModel.HOLD_SEC)
		"beam": # the laser: the camera looks along it to its end, the shooter kept in view
			if e.get("from") is Dictionary and e.get("to") is Dictionary:
				_hold_focus({"pos": _cam.keep_in_view(_vec(e["to"]), _vec(e["from"]))}, float(e.get("duration", 0.0)) + CameraModel.HOLD_SEC)
		"die":
			_kill(id)
		"strike": # a nuke's / laser's signal landed: the camera stays on the target until the hit
			if e.get("position") is Dictionary:
				_hold_focus({"pos": _vec(e["position"]) + LOOK_LIFT}, float(e.get("duration", 0.0)) + CameraModel.HOLD_SEC)
		"drill":
			_drill(e)
		"bounce": # the water orb bounces off the ground: a splash where it touched
			if e.get("position") is Dictionary:
				var splash := WaterSplash.new()
				splash.radius = 42.0
				splash.position = _vec(e["position"])
				_fx_layer.add_child(splash)
				_cam.shake(4.0)
		"summon":
			_summon(e)
		"rain":
			if _skill_view != null and not _skill_view.tracks_shells() and e.get("position") is Dictionary:
				# a boss's shells fall from above the map: the camera looks at where they land
				_hold_focus({"pos": _vec(e["position"]) + LOOK_LIFT * 2.0}, int(e.get("count", 1)) * 0.08 + 1.4)
		"lava":
			var zone := _lava.add_event(e, _boss.boss_round)
			if not zone.is_empty():
				_lava_view.show_zone(zone, true)
		"mark":
			var m := _marks.add_event(e, _boss.boss_round)
			if not m.is_empty():
				_mark_view.show_mark(m, true)
		"eruption":
			_erupt(e)
		"ground_strike":
			if e.get("position") is Dictionary:
				var vines := VineStrikeFx.new(float(e.get("radius", 60.0)))
				vines.position = _vec(e["position"])
				_fx_layer.add_child(vines)
				_cam.shake(14.0)
		"spore":
			if e.get("position") is Dictionary:
				var cloud := SporeFx.new(SporeFx.PUFF, float(e.get("radius", 120.0)))
				cloud.position = _vec(e["position"]) - Vector2(0, 16)
				_fx_layer.add_child(cloud)
				if _views.has(id):
					_views[id].puff()
				_hold_focus({"pos": _vec(e["position"]) + LOOK_LIFT}, 1.0)
		"airburst":
			_airburst(e)
		"move":
			_path_walk(e)
		"pincer":
			_pincer(e)
		"global":
			_global_start(e)
		"roll":
			_roll(e)
		"pull":
			_pull(e)
		"status":
			if _players.has(id):
				_players[id]["statusEffects"] = Status.apply(_players[id].get("statusEffects"), str(e.get("effectId", "")), int(e.get("turns", 1)))
				_views[id].set_status(_players[id]["statusEffects"])
			var text := Skills.status_label(str(e.get("effectId", "")))
			if text != "":
				# over the running damage number, or the one just shown (a nova's hit and freeze land together)
				_popup(id, text, DamagePopup.POISON if str(e.get("effectId", "")) == POISON else Color(0.7, 0.85, 1),
					Vector2(0, -64) if _has_tally(id) or _just_popped(id) else Vector2.ZERO)
	# beam, flare, rain (and the rest): the skill draws them
	if _skill_view != null:
		_skill_view.on_event(e)


## A drill event: the bit bores into the ground. The mask takes its version step now and the
## tunnel bit by bit as the bit goes (_step_digs()); dirt and dust at the hole, grit at the bit
## (DrillFx).
func _drill(e: Dictionary) -> void:
	var dig = TunnelDig.from_event(e)
	if dig == null:
		return
	dig.start(_mask)
	_digs.append(dig)
	_terrain_view.refresh()
	_fx_layer.add_child(DrillFx.new(dig))
	_cam.shake(DRILL_SHAKE)
	_check_terrain_version(e)


## Opens the drill tunnels as far as the bit has bored (the replay's time).
func _step_digs() -> void:
	if _digs.is_empty():
		return
	if not _shot_player.is_playing():
		_finish_digs()
		return
	var now := _shot_player.time()
	var changed := false
	for dig in _digs:
		if dig.advance(_mask, now - dig.t):
			changed = true
	_digs = _digs.filter(func(d): return not d.done())
	if changed:
		_terrain_view.refresh()


## Opens the rest of every drill tunnel (the shell explodes, the replay ends).
func _finish_digs() -> void:
	if _digs.is_empty():
		return
	for dig in _digs:
		dig.finish(_mask)
	_digs.clear()
	_terrain_view.refresh()


## "+120 khiên": a shield gain's floating number.
static func shield_text(amount: int) -> String:
	return DamagePopup.heal_text(amount) + " khiên"


## The lead-in is over, the shot leaves: the skill's shooter spends its energy (its aura goes)
## and the shooter's badge pops up (a skill or a shot item; none for a normal shot).
func _on_shot_fired() -> void:
	_show_energies(_energy_reveal.fired())
	var shooter := str(_shot_badge.get("shooter", ""))
	var content: Dictionary = _shot_badge.get("content", {})
	# The badge held since the arming goes on as the shot's (show_badge keeps it); the shot owns it now
	var held: Dictionary = _held_badges.get(shooter, {})
	_held_badges.erase(shooter)
	if _views.has(shooter):
		if not held.is_empty() and held != content:
			_views[shooter].release_held_badge(held)
		if not content.is_empty():
			_views[shooter].show_badge(content)


## An explode's terrainVersion against the mask's: a drift asks for MatchStateSync (Reconnect),
## but only once the replay is over (the snapshot rebuilds the match and would cut off the rest
## of the shot's damage and HP events).
func _check_terrain_version(e: Dictionary) -> void:
	var server_version := int(e.get("terrainVersion", _mask.version))
	if server_version == _mask.version:
		return
	_mask.version = server_version
	if _shot_player.is_playing():
		_resync_after_shot = true
	else:
		GameSocket.send("Reconnect", {}) # terrain drifted: ask for MatchStateSync


func _on_shot_finished() -> void:
	_finish_digs()
	_moves_fx.finish() # every walk / drag / roll on its end
	for n in _fx_layer.get_children():
		if n is RollingBoulderView:
			n.settle()
	_quake_until = -1.0
	if _resync_after_shot:
		_resync_after_shot = false
		GameSocket.send("Reconnect", {}) # the terrain drifted during the replay
	_skill_view = null
	_drain = {}
	_cam.unframe()
	if _shot_timeline != null and _shot_timeline.action_mode in [SUMMON, TURN_START] and _views.has(_current) and not _ended:
		_cam.pan_to(_pos(_current) + _look_lift(_current)) # the summon played: back on the boss for its attack
	if _wave_fx != null and is_instance_valid(_wave_fx):
		_wave_fx.release()
	_wave_fx = null
	_show_energies(_energy_reveal.finish()) # what changed without a hit on screen
	var shooter := str(_shot_badge.get("shooter", ""))
	var content: Dictionary = _shot_badge.get("content", {})
	if not content.is_empty() and _views.has(shooter):
		_views[shooter].release_badge()
	_shot_badge = {}
	for view in _views.values():
		view.clear_aim()
	_flush_deferred()
	_refresh_controls()


func _on_match_ended(d: Dictionary) -> void:
	_ended = true
	_countdown.stop()
	_show_countdown()
	for id in _held_badges.keys(): # an armed skill / item never fired
		_hold_badge(id, {})
	for view in _views.values():
		view.set_active(false)
		view.clear_aim()
	_refresh_controls()
	if str(d.get("result", "")) == "no_contest":
		_hud.show_result("Trận bị huỷ", str(d.get("message", "")))
		return
	if RankModel.is_ranked_mode(_mode):
		PlayerState.load_rank() # Home shows the new rank
		PlayerState.stones_dirty() # the ranked stone rolls
	if _boss.active or GameData.is_boss_queue(_mode):
		PlayerState.boss_runs_stale() # the Boss tab reloads the runs left
		PlayerState.chests_dirty() # a bonus run's chests
	var info := result_info(d)
	# A Timer child: leaving the screen during the wait frees it with the screen, nothing fires.
	var delay := Timer.new()
	delay.name = "ResultDelay"
	delay.one_shot = true
	delay.wait_time = RESULT_DELAY_SEC
	delay.autostart = true
	delay.timeout.connect(func() -> void:
		delay.queue_free()
		show_result_screen(info))
	add_child(delay)


## The result screen's data (ResultScreen.setup()) for a MatchEnded {winningTeam, rewards,
## stats?, mvpPlayerId?}. The server sends "rewards": null when granting them failed: shown as
## such, never as +0.
func result_info(d: Dictionary) -> Dictionary:
	var my_team := int(_players.get(_me, {}).get("teamId", -1))
	var winning_team := int(d.get("winningTeam", 0)) # 0: no team left alive
	var rewards = d.get("rewards")
	var reward = rewards.get(_me) if rewards is Dictionary else null
	var stats = d.get("stats")
	var sides := ResultModel.sides(_players, _me, winning_team)
	var order: Array = sides["left"] + sides["right"]
	var my_badge := PlayerState.rank_badge()
	var entries := {"left": [], "right": []}
	for side in entries:
		for id in sides[side]:
			entries[side].append(ResultModel.entry(id, _players[id], _roster.get(id, {}), _me, PlayerState.level(), my_badge,
				ResultModel.damage_of(id, stats, _damage_by)))
	var char_id := str(_players.get(_me, {}).get("characterId", ""))
	if d.get("boss") is Dictionary or (_boss.active and d.has("result")):
		return boss_result_info(d, reward, char_id)
	return {"outcome": ResultModel.outcome(my_team, winning_team), "left": entries["left"], "right": entries["right"],
		"mvp": ResultModel.mvp(_players, order, stats, d.get("mvpPlayerId"), _damage_by),
		"reward": ResultModel.reward(reward, _mode),
		"exp": {"level": PlayerState.level(), "exp": PlayerState.player_exp()} if PlayerState.is_loaded() else {},
		"char_name": LobbyModel.character_info(char_id, null)["name"],
		"again": "" if _party_member() else ResultModel.again_text(_mode, not Router.last_quick_play.is_empty())}


## The party's member: no "Chơi tiếp" (the host starts the queue; Home keeps me in the party, ready).
static func _party_member() -> bool:
	return Router.party != null and Router.party.model.is_member()


## The boss result screen's data (BossResultScreen.setup(): BossResultModel.info() and the
## buttons) for a boss MatchEnded.
func boss_result_info(d: Dictionary, reward: Variant, char_id: String) -> Dictionary:
	var info := BossResultModel.info(d, _players, _me, _boss.boss_id, reward)
	info["boss_mode"] = true
	info["exp"] = {"level": PlayerState.level(), "exp": PlayerState.player_exp()} if PlayerState.is_loaded() else {}
	info["char_name"] = LobbyModel.character_info(char_id, null)["name"]
	info["character_id"] = char_id
	info["again"] = "" if _party_member() else ResultModel.again_text(_mode, false)
	return info


## The full-screen result over the match (its own layer, over the HUD); a boss match's is the
## boss result screen (same signals).
func show_result_screen(info: Dictionary) -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var screen = BossResultScreen.new() if info.get("boss_mode", false) else ResultScreen.new()
	screen.setup(info)
	screen.home_pressed.connect(_on_leave)
	screen.again_pressed.connect(_on_again.bind(screen))
	layer.add_child(screen)
	return screen


## "Chơi tiếp" (a queue mode: back into its queue with the same loadout) / "Chơi lại" (the same
## Quick Play again; the server already took me out of this room).
func _on_again(screen: Control) -> void:
	if RankModel.is_queue_mode(_mode):
		# The lobby is kept after the match (ReturnToLobby): Matchmaking's CreateLobby gets it back.
		Router.queue = _mode
		Router.go(Router.MATCHMAKING if not Router.ranked_loadout.is_empty() else Router.LOADOUT)
		return
	if _replay == null:
		_replay = QuickPlay.new()
		add_child(_replay)
		_replay.changed.connect(func() -> void: screen.set_status(_replay.status, _replay.pending))
	if not _replay.request(Router.last_quick_play):
		screen.set_status("Mất kết nối, hãy thử lại khi online", false)


# ── Local actions ────────────────────────────────────────────────────────────

func _on_fire(angle: float, power: float) -> void:
	if not _can_act():
		_clear_my_aim()
		return
	var data := {"angle": angle, "power": power, "actionMode": WEAPON}
	if _armed == SKILL:
		data["actionMode"] = SKILL
	elif Items.is_known(_armed):
		data = Items.shot_payload(_armed, angle, power)
	await _fire(data)


## air_strike: the release point's x is the drop column.
func _on_fire_column(target_x: float) -> void:
	if not _can_act() or not Items.needs_target_x(_armed):
		return
	await _fire(Items.shot_payload(_armed, 0.0, 0.0, target_x))


## The armed special stays armed (ActionLock): a Shoot the server drops or never answers does not
## give the normal shot back this turn; the next turn starts on it.
func _fire(data: Dictionary) -> void:
	_hud.pause_timer() # the server stops the clock once it takes the shot
	var sent: bool = await _commit_action("Shoot", data)
	if not sent and not _turn_resolved:
		_clear_my_aim() # never sent: the gun goes away


## An aimed skill toggles skill mode; one without aim (healing_bloom) is used at once, through
## the same commit path as a shot.
func _on_skill_pressed() -> void:
	var skill := _my_skill()
	var charged := Skills.is_ready(int(_players.get(_me, {}).get("skillEnergy", 0)))
	if not _can_act() or _is_frozen() or skill.is_empty() or not charged:
		_refresh_controls()
		return
	if ActionLock.locked(_armed):
		_refresh_controls() # another special (or the skill itself) is armed: kept
		return
	if bool(skill["needs_aim"]):
		_armed = ActionLock.press(_armed, SKILL)
		_refresh_controls()
		return
	# Fired at the tap (no SelectAction: the Shoot follows at once); my badge shows right away
	_hold_badge(_me, UseBadge.content(SKILL, str(skill.get("id", "")), ""))
	await _fire({"angle": GameData.no_aim_angle(), "power": GameData.no_aim_power(), "actionMode": SKILL})
	if not _commit_sent and not _turn_resolved and _armed == WEAPON:
		_hold_badge(_me, {}) # never sent


## An instant item is used at once (UseItem; the turn goes on). A shot item arms the next shot
## for good this turn (ActionLock: no going back to the normal shot, no switch to another
## special; _refresh_controls drops it if it can no longer be fired).
func _on_item_pressed(item_id: String) -> void:
	var items = _players.get(_me, {}).get("items")
	if not _can_act() or not items is Array or not items.has(item_id):
		_refresh_controls()
		return
	if Items.is_instant(item_id):
		await _commit_action("UseItem", {"itemId": item_id}, item_id)
		return
	if _is_frozen(): # a shot item cannot be fired while frozen (instant ones can)
		_refresh_controls()
		return
	_armed = ActionLock.press(_armed, item_id)
	_refresh_controls()


## Sends Shoot/EndTurn/UseItem once:
## - every Move has been answered (MoveSync.is_settled), so the server fires from the position
##   on screen; a dropped Move is re-sent first;
## - _action_interval() has passed since the last action; and
## - MOVE_ACK_GAP has passed since the last PlayerMoved for my Moves was handled. Spacing sends
##   alone does not survive jitter: a Move delayed on the way can reach the server less than
##   150 ms before the Shoot, which is then dropped. The server processed that Move before it
##   sent the answer, and the answer is handled after it arrives, so a Shoot sent >= 160 ms
##   (wall clock) after that reaches the server >= 160 ms after it processed the Move, whatever
##   the latency in either direction or the length of the frame that read the answer.
## All are re-checked every frame (process_frame fires before _process), so a Move re-send
## cannot slip in between. The wait is bounded by MoveSync's re-send limit (about 3 s). The
## answer timeout starts only once the command is actually sent. If MoveSync loses track of
## the server (needs_resync), the pending command is cancelled instead (see _request_resync).
## instant_item names the item of a UseItem: it does not end the turn, so Moves may follow once
## its ItemUsed (or ITEM_ACK_TIMEOUT) unlocks input; Shoot/EndTurn stop Moves for the turn.
## Returns whether the command was sent.
func _commit_action(event: String, data: Dictionary, instant_item: String = "") -> bool:
	_committing = true
	_hold_dir = 0
	_moves.release()
	_refresh_controls()
	while _committing and _is_my_turn() and not _turn_resolved and (not _moves.is_settled() \
			or _since(_action_at) < _action_interval() or _since(_move_ack_at) < MOVE_ACK_GAP):
		await get_tree().process_frame
	if not _is_my_turn() or not _committing or _turn_resolved:
		return false
	if instant_item == "":
		_commit_sent = true
		_awaiting_ack = SHOT_ACK_TIMEOUT
	else:
		_awaiting_item = instant_item
		_awaiting_ack = ITEM_ACK_TIMEOUT
	_cmd_sent = true
	GameSocket.send(event, data)
	_mark_action()
	return true


## The server's position is unknown (Moves unanswered after every re-send). Cancel any
## Shoot/EndTurn/UseItem still waiting to be sent, keep input locked (_can_act) and ask for a full MatchStateSync,
## repeating every RESYNC_RETRY seconds. The snapshot's lastMoveSeq tells MoveSync which Moves
## it covers (MoveSync.apply_snapshot).
func _request_resync(delta: float) -> void:
	if _committing and not _cmd_sent:
		_committing = false # the waiting _commit_action returns without sending
	_resync_in -= delta
	if _resync_in > 0.0:
		return
	GameSocket.send("Reconnect", {})
	_resync_in = RESYNC_RETRY
	_refresh_controls()


func _mark_action() -> void:
	_action_at = Time.get_ticks_usec()


## Seconds since a Time.get_ticks_usec() stamp.
static func _since(usec: int) -> float:
	return (Time.get_ticks_usec() - usec) / 1_000_000.0


func _on_leave() -> void:
	if not _disconnected: # a new connection is not in this room; Leave would only be rejected
		GameSocket.send("Leave", {})
		if RankModel.is_queue_mode(_mode) and not (Router.party != null and Router.party.model.in_party()):
			_leave_lobby() # a party stays together for the next match
	Router.go(Router.HOME)


## Adds a shot's damage to the other team to its shooter's tally (_damage_by).
func _count_damage(shooter: String, events: Variant) -> void:
	if not events is Array or not _players.has(shooter):
		return
	var team := int(_players[shooter].get("teamId", 0))
	for e in events:
		if e is Dictionary and str(e.get("type", "")) == "damage":
			var target := str(e.get("playerId", ""))
			if _players.has(target) and int(_players[target].get("teamId", 0)) != team:
				_damage_by[shooter] = int(_damage_by.get(shooter, 0)) + int(e.get("amount", 0))


## Leaves the ranked queue's solo lobby once, going back to Home (the server keeps it after the
## match for "Chơi tiếp"; a solo lobby disbands). A party (two in the lobby) is never left here.
func _leave_lobby() -> void:
	if not _lobby_left:
		_lobby_left = true
		Router.party.leave()


## The server treats a lost connection as Leave, so the match cannot be resumed (M2).
func _on_disconnected() -> void:
	_disconnected = true
	if _ended:
		return # the result is already on screen
	_ended = true
	_refresh_controls()
	_hud.show_result("Mất kết nối với trận đấu", "Về sảnh để bắt đầu trận mới")


# ── Boss mode ────────────────────────────────────────────────────────────────

const SUMMON := "summon" # a boss's free summon (ShotResolved / ActionSelected actionMode)
const SUMMON_TEXT := "Triệu hồi"
const SHIELD_ON := "Khiên bảo vệ!"
const SHIELD_OFF := "Phá khiên!"
const TURN_START := "turn_start" # boss v4: the boss's turn start (eruptions, regen) before its summon and attack
const SPORE := "spore" # a poison mushroom's turn (ShotResolved actionMode)
const ERUPTION := "eruption" # a damage cause / event type
const DRAIN := "drain" # heal causes
const REGEN := "regen"
const POISON := "poison" # the status / the PlayerDamaged type
const GLOBAL := "global" # boss v5 damage causes
const ROLL := "roll"
const ARMOR_ON := "Giáp đá!"
const ARMOR_OFF := "Phá giáp!"


## A snapshot's boss fight: the bar, the lava pools (a boss snapshot without lavaZones has none)
## and the shield on the boss's body (set without its pop).
func _load_boss(snap: Dictionary) -> void:
	if not _boss.load_snapshot(snap):
		_hud.set_boss({})
		_marks.clear()
		_mark_view.sync({})
		_links.set_links([], [], false)
		return
	_lava.set_all(snap.get("lavaZones", []))
	_lava_view.sync(_lava.zones)
	var marks = snap["boss"].get("marks") # the marks waiting for the boss's next turn (none: a server without them)
	_marks.set_all(marks if marks is Array else [])
	if not _boss.alive:
		_marks.clear()
	_mark_view.sync(_marks.marks)
	if _views.has(_boss.player_id):
		_views[_boss.player_id].set_shielded(_boss.shielded and _boss.alive, false)
	_sync_aura(false, _boss.armored())
	_armor_tagged = false
	_hud.set_boss(_boss.state())


## BossShieldChanged: the bubble pops on or off the boss, a line says so; the auras it carries
## (boss v4) set the links and the plates (_sync_aura()).
func _on_boss_shield(d: Variant) -> void:
	var was_shielded := _boss.shielded
	var was_armored := _boss.armored()
	if not _boss.on_shield(d):
		return
	_hud.set_boss(_boss.state())
	_sync_aura(true, was_armored)
	var id := _boss.player_id
	if _views.has(id) and _boss.shielded != was_shielded:
		_views[id].set_shielded(_boss.shielded)
		_popup(id, SHIELD_ON if _boss.shielded else SHIELD_OFF, Color(0.6, 0.92, 1.0) if _boss.shielded else LobbyUi.GOLD,
			Vector2(0, -_views[id].body_size * 40.0))


## The minion auras on screen (boss v4) from BossHudModel: the links (new ones grow, gone ones snap
## when animate), the boss's stone plates; the armour going on or off pops a line over the boss.
func _sync_aura(animate: bool, was_armored: bool) -> void:
	_links.views = _views
	_links.boss_id = _boss.player_id
	_links.set_links(_boss.armor_minions, _boss.regen_minions, animate)
	var now := _boss.armored()
	var id := _boss.player_id
	if _views.has(id):
		_views[id].set_armored(now, animate)
	if now == was_armored:
		return
	_hud.set_boss(_boss.state())
	if now:
		_armor_tagged = false
	if animate and _views.has(id) and _boss.alive:
		_popup(id, ARMOR_ON if now else ARMOR_OFF, LobbyUi.GOLD if not now else Color(1.0, 0.8, 0.4), Vector2(0, -_views[id].body_size * 40.0))


## The links and plates (tests, the harness).
func aura_links() -> AuraLinks:
	return _links


## The eruption marks held / drawn (tests, the harness).
func marks() -> BossMarks:
	return _marks


func mark_view() -> MarkView:
	return _mark_view


## Boss v4 at the start of a boss shot's replay: the marks it erupts rumble until then, the life a
## regen heal takes rises from the mushrooms into the boss on its way (it lands with the heal), a
## drain beam's life flow is set up (_drain: until the beam ends).
func _begin_v4(timeline, shooter: String) -> void:
	_drain = {}
	for e in timeline.events:
		if not e is Dictionary:
			continue
		var t := float(e.get("t", 0.0))
		match str(e.get("type", "")):
			ERUPTION:
				_mark_view.charge(str(e.get("markId", "")), t)
			"heal":
				if str(e.get("cause", "")) == REGEN and _views.has(str(e.get("playerId", ""))):
					var sources: Array = []
					for mid in _boss.regen_minions:
						if _views.has(mid) and not _views[mid].is_dead():
							sources.append(_views[mid])
					if not sources.is_empty():
						var stream := LifeStreamFx.new(LifeStreamFx.REGEN)
						stream.sources = sources
						stream.target = _views[str(e["playerId"])]
						stream.emit_sec = maxf(t * 0.6, 0.2)
						stream.travel_sec = maxf(t, 0.45)
						_fx_layer.add_child(stream)
	var skill := GameData.boss_skill(_boss.boss_id, timeline.skill_id) if shooter == _boss.player_id else {}
	var pct = skill.get("drainPct")
	if (pct is int or pct is float) and float(pct) > 0.0:
		var until := 0.0
		for e in timeline.events:
			if e is Dictionary and str(e.get("type", "")) in ["beam", "heal"]:
				until = maxf(until, float(e.get("t", 0.0)) + (float(e.get("duration", 0.0)) if str(e.get("type", "")) == "beam" else 0.0))
		_drain = {"until": until}


## A drained member's life flows into the boss's heart from its hit (t) until the beam ends.
func _drain_from(id: String, t: float) -> void:
	if not _views.has(_boss.player_id):
		return
	var stream := LifeStreamFx.new(LifeStreamFx.DRAIN)
	stream.sources = [_views[id]]
	stream.target = _views[_boss.player_id]
	stream.emit_sec = maxf(float(_drain.get("until", t)) - t, 0.25)
	stream.travel_sec = 0.55
	_fx_layer.add_child(stream)


## An eruption event {playerId, position, radius, markId}: its mark flashes out, stone spikes burst
## up across it.
func _erupt(e: Dictionary) -> void:
	var id := str(e.get("markId", ""))
	var m := _marks.erupt(id)
	_mark_view.erupt(id)
	var at: Vector2 = _vec(e["position"]) if e.get("position") is Dictionary else m.get("position", Vector2.INF)
	if at == Vector2.INF:
		return
	var radius := float(e.get("radius", m.get("radius", 70.0)))
	var fx := BombChainFx.new()
	_mark_view.add_child(fx) # on the ground, under the players: they stand in front of the spikes
	fx.z_index = 0
	fx.erupt(at, radius, func(x: float) -> float: return _ground_y(x, at.y))
	fx.finish()
	_cam.shake(radius * 0.5)


## The ground's top at x near y (the surface under a point a little above it); y when nothing is there.
func _ground_y(x: float, y: float) -> float:
	if _mask.width <= 0:
		return y
	var g: float = _mask.get_landing_y(clampf(x, 0.0, _mask.width - 1.0), maxf(y - 40.0, 0.0))
	return g if g < _mask.height and absf(g - y) < 90.0 else y


## Frames the ground a shot acts on (boss v4: its marks, eruptions, ground strikes): the camera
## holds their middle for sec, zoomed out until they all fit.
func _frame_ground(events: Array, sec: float) -> void:
	var box := Rect2()
	var any := false
	for e in events:
		if e is Dictionary and str(e.get("type", "")) in ["mark", ERUPTION, "ground_strike"] and e.get("position") is Dictionary:
			var p := _vec(e["position"])
			box = box.expand(p) if any else Rect2(p, Vector2.ZERO)
			any = true
	if not any:
		return
	box = box.grow(150.0)
	var view := _cam.world_view()
	if box.size.x > view.x * 0.92 or box.size.y > view.y * 0.92:
		_cam.frame_size(box.size)
	_hold_focus({"pos": box.get_center() + LOOK_LIFT}, sec)


## A summon event {playerId, minionId, position, hp, maxHp, displayName, teamId, bodySize, flying,
## behavior, movement}: a new minion of the boss's team pops in where it lands (what the event
## leaves out from its game data type: summon_player()); the camera shows it.
func _summon(e: Dictionary) -> void:
	var id := str(e.get("playerId", ""))
	if id == "" or not e.get("position") is Dictionary:
		return
	var pos := _vec(e["position"])
	if _views.has(id): # already known (a sync): it stands there again
		_set_pos(id, pos)
		_views[id].move_to(pos, 0.0)
		return
	var minion_id := str(e.get("minionId", ""))
	var p := summon_player(e, _boss.boss_id, int(_players.get(_boss.player_id, {}).get("teamId", 2)))
	_players[id] = p
	var view := PlayerView.new()
	view.walk.terrain = _mask
	_players_layer.add_child(view)
	view.setup(p, false, int(_players.get(_me, {}).get("teamId", -1)))
	view.face(1.0 if pos.x < _mask.width / 2.0 else -1.0)
	_views[id] = view
	view.scale = Vector2.ONE * 0.2
	view.create_tween().tween_property(view, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var art := BossArt.art_of("", minion_id)
	if art == "stone_totem": # it rises out of the ground, the earth breaking round it
		view.scale = Vector2.ONE
		view.rise()
		var quake := BombChainFx.new()
		_fx_layer.add_child(quake)
		quake.quake(pos, 14.0, func(x: float) -> float: return _ground_y(x, pos.y), 1)
		quake.finish()
	else:
		var fx := PopFx.new()
		fx.position = pos - Vector2(0, PlayerView.BODY.y * view.body_size * 0.6)
		fx.color = BossArt.accent(art)
		_fx_layer.add_child(fx)
		if art == "poison_mushroom": # it pops up in a puff of spores
			var poof := SporeFx.new(SporeFx.TICK, 40.0)
			poof.position = pos - Vector2(0, 14)
			_fx_layer.add_child(poof)
	_hold_focus({"pos": pos + _view_lift(view)}, 0.6)
	var was_armored := _boss.armored()
	if _boss.minion_summoned(id, GameData.boss_minion(_boss.boss_id, minion_id)):
		_sync_aura(true, was_armored)


## The BattlePlayerState of a summoned minion from its summon event: the event's fields (the full
## unit since boss mode v2), the game data's minion type for what it leaves out (an older server:
## its name, hp, bodySize, behavior, movement), the boss's team when it has no teamId.
static func summon_player(e: Dictionary, boss_id: String, boss_team: int) -> Dictionary:
	var minion_id := str(e.get("minionId", ""))
	var kind := GameData.boss_minion(boss_id, minion_id)
	var hp := int(_num(e, "hp", float(kind.get("hp", 1))))
	var pos: Dictionary = e.get("position", {"x": 0.0, "y": 0.0})
	var name := str(e["displayName"]) if e.get("displayName") is String and e["displayName"] != "" else str(kind.get("name", minion_id))
	var p := {"playerId": str(e.get("playerId", "")), "displayName": name, "teamId": int(_num(e, "teamId", boss_team)),
		"role": "minion", "bossId": boss_id, "minionId": minion_id,
		"bodySize": _num(e, "bodySize", GameData.body_size_of(kind)), "characterId": str(e.get("characterId", "")),
		"hp": hp, "maxHp": maxi(int(_num(e, "maxHp", hp)), 1), "isAlive": true, "isBot": true,
		"position": {"x": float(pos.get("x", 0.0)), "y": float(pos.get("y", 0.0))}, "statusEffects": [], "items": [], "skillEnergy": 0}
	for key in ["behavior", "movement"]:
		var v = e.get(key)
		p[key] = str(v) if v is String and v != "" else str(kind.get(key, ""))
	p["flying"] = bool(e["flying"]) if e.get("flying") is bool else str(p["movement"]) == "fly"
	if e.get("element") is String and e["element"] != "": # its element (its boss's); without it GameData.unit_element() reads the boss's
		p["element"] = str(e["element"])
	return p


static func _num(d: Dictionary, key: String, fallback: float) -> float:
	var v = d.get(key)
	return float(v) if v is int or v is float else fallback


# ── Boss v5 (063): airburst, the pincer walk, global, roll, pull ─────────────

## Bom mù bursts (airburst {position, radius}): a white flash and shock ring over the target
## area, the screen blinks white; the blind comes in its status events.
func _airburst(e: Dictionary) -> void:
	if not e.get("position") is Dictionary:
		return
	var fx := AirburstFx.new(float(e.get("radius", 200.0)))
	fx.position = _vec(e["position"])
	_fx_layer.add_child(fx)
	if _screen_fx != null:
		_screen_fx.add_child(AirburstFx.ScreenFlash.new(0.22, 0.45))
	_hold_focus({"pos": fx.position}, AirburstFx.LIFE * 0.6)
	_cam.shake(fx.radius * 0.3)


## A unit walks along the ground (move {playerId, from, to, duration, path}: the crab to its
## pincer grab): its view follows the path on the replay's clock, the camera with it; the
## server's position is `to` from now on.
func _path_walk(e: Dictionary) -> void:
	var id := str(e.get("playerId", ""))
	if e.get("to") is Dictionary:
		_set_pos(id, _vec(e["to"]))
	var view = _views.get(id)
	if view == null:
		return
	var m = _moves_fx.add(view, e)
	_hold_focus({"view": view}, m.duration + CameraModel.HOLD_SEC)


## The crab's claw grabs (pincer {playerId: the crab, targetId, position: the target's body
## centre}): the claw snaps shut on the target from the crab's side, the target jolts.
func _pincer(e: Dictionary) -> void:
	var target := str(e.get("targetId", ""))
	var at := Vector2.INF
	if e.get("position") is Dictionary:
		at = _vec(e["position"])
	elif _views.has(target):
		at = _views[target].body_centre()
	if at == Vector2.INF:
		return
	var crab = _views.get(str(e.get("playerId", "")))
	var side := 1.0 if crab == null or crab.position.x >= at.x else -1.0
	if crab != null:
		crab.face(-side)
	var fx := PincerFx.new(side)
	fx.position = at
	_fx_layer.add_child(fx)
	if _views.has(target):
		_views[target].hop(10.0, 0.22)
	_hold_focus({"pos": at}, PincerFx.LIFE)
	_cam.shake(24.0)


## A global skill starts (global {skillId, duration}): without projectiles (the earthquake) the
## camera shakes for its duration; the storm of the others is the skill view's.
func _global_start(e: Dictionary) -> void:
	if _shot_timeline != null and not _shot_timeline.projectiles.is_empty():
		return
	_quake_until = _clock + maxf(float(e.get("duration", 0.0)), 0.3)
	_quake_next = _clock


## A member hit by a global skill: its projectile (an ice shard, a poison thorn) bursts on it, or,
## with none (the earthquake), the ground splits under it and it is thrown up a little.
func _global_hit(id: String) -> void:
	var view = _views.get(id)
	if view == null:
		return
	var kind := ""
	if _shot_timeline != null:
		for p in _shot_timeline.projectiles:
			if p is Dictionary and str(p.get("hitPlayerId", "")) == id:
				kind = str(p.get("kind", ""))
	if kind != "":
		if UnitShell.is_kind(kind):
			var hit := UnitImpact.new(kind, 34.0)
			hit.position = view.body_centre()
			_fx_layer.add_child(hit)
		return
	var crack := GroundCrackFx.new(170.0 * maxf(view.body_size, 1.0), absi(hash(id)) % 997)
	crack.position = view.position
	_mark_view.add_child(crack) # on the ground, under the players
	view.hop(14.0, 0.3)


## The giant's boulder lands and rolls (roll {from, to, duration, path, radius}): the same
## boulder rolls on along the ground path on the replay's clock, the camera with it.
func _roll(e: Dictionary) -> void:
	var r := float(e.get("radius", 60.0))
	var boulder := RollingBoulderView.new(r)
	_fx_layer.add_child(boulder)
	var m = _moves_fx.add(boulder, e)
	_hold_focus({"view": boulder}, m.duration + CameraModel.HOLD_SEC)
	_cam.shake(r * 0.5)


## The tree's roots drag a member (pull {playerId, from, to, duration, path}): roots burst under
## it and haul it along the ground toward the tree on the replay's clock; its position is `to`.
func _pull(e: Dictionary) -> void:
	var id := str(e.get("playerId", ""))
	if e.get("to") is Dictionary:
		_set_pos(id, _vec(e["to"]))
	var view = _views.get(id)
	if view == null:
		return
	var from: Vector2 = _vec(e["from"]) if e.get("from") is Dictionary else view.position
	var burst := VineStrikeFx.new(50.0)
	burst.position = from
	_fx_layer.add_child(burst)
	var m = _moves_fx.add(view, e)
	_mark_view.add_child(RootDragFx.new(m.points, view, m.duration))
	_hold_focus({"view": view}, m.duration + CameraModel.HOLD_SEC)
	_cam.shake(16.0)


## The boss's summon as its kit names it (bosses[].summon.name, 063: "Gọi drone"), else "Triệu hồi".
func _summon_name() -> String:
	var sm = GameData.boss(_boss.boss_id).get("summon")
	var n = sm.get("name") if sm is Dictionary else null
	return str(n) if n is String and n != "" else SUMMON_TEXT


## The boss v5 movers (tests).
func boss_moves() -> BossMoves:
	return _moves_fx


## UnitFlew {playerId, from, to, duration}: the unit flies there (PlayerView.fly()), the camera
## goes with it; the events after it wait until it lands (_flight_hold).
func _on_unit_flew(d: Variant) -> void:
	if not d is Dictionary:
		return
	var id := str(d.get("playerId", ""))
	var flight = FlightModel.from_event(d)
	if flight == null or not _players.has(id):
		return
	_set_pos(id, flight.to)
	var view = _views.get(id)
	if view == null or not view.has_method("fly"):
		return
	view.fly(flight.from, flight.to, flight.duration)
	if view.in_flight():
		_flight_hold = true
		_hold_focus({"view": view}, flight.duration + FALL_TAIL)


## The flights are drawn: what waited behind them.
func _release_flight_hold() -> void:
	if not _flight_hold:
		return
	for view in _views.values():
		if view.has_method("in_flight") and view.in_flight():
			return
	_flight_hold = false
	_flush_deferred()
	_refresh_controls()


## Every bomber's warning: its red pulse while a living player of the other team is within its
## detonateRange (the positions on screen: it warns as it walks or flies in).
func _update_bombers() -> void:
	if not _boss.active:
		return
	for id in _views:
		var view = _views[id]
		if not view.has_method("is_bomber") or not view.is_bomber() or view.is_dead():
			continue
		var team := int(_players.get(id, {}).get("teamId", 2))
		var targets: Array = []
		for other in _views:
			var o: Dictionary = _players.get(other, {})
			if int(o.get("teamId", team)) != team and bool(o.get("isAlive", false)) and not _views[other].is_dead():
				targets.append(_views[other].position)
		view.set_warning(BomberModel.warning(view.position, targets, GameData.unit_detonate_range(_players.get(id, {}))))


## Marks the shot's minion blasts (BlastEvents.tag()) and, for a detonation, swells the bomber
## until the blast.
func _tag_blasts(timeline, shooter: String) -> void:
	if BlastEvents.tag(timeline.events, _players, shooter, timeline.action_mode) == 0:
		return
	var at := BlastEvents.detonation_time(timeline.events)
	if at > 0.05 and _views.has(shooter) and _views[shooter].has_method("prime"):
		_views[shooter].prime(at)


## A minion blows up (its detonation or death blast; explode {playerId, position, radius: the
## crater, crater: "bowl", terrainVersion, blastRadius}): the crater (radius in the event's shape;
## a crater number carves that radius), the body gone at once, its big burst as wide as the
## blast (blastRadius, else its type's explodeRadius) with a shockwave ring, and a hard shake.
func _unit_blast(e: Dictionary) -> void:
	var blast := BlastEvents.blast_of(e)
	var id := str(blast.get("minion", ""))
	var p := _vec(e["position"])
	var radius := float(e.get("radius", 0.0))
	var crater = e.get("crater")
	if crater is int or crater is float:
		if float(crater) > 0.0:
			_mask.carve(TerrainMask.CRATER_BOWL, p.x, p.y, float(crater))
	elif radius > 0.0:
		_mask.carve(str(crater) if crater is String else TerrainMask.CRATER_BOWL, p.x, p.y, radius)
	_terrain_view.refresh()
	var unit: Dictionary = _players.get(id, {})
	var art := BossArt.art_of("", str(unit.get("minionId", "")))
	var look := BossArt.blast_look(art)
	var b = e.get("blastRadius") # the blast's damage reach (radius is the crater)
	var reach := float(b) if (b is int or b is float) and b > 0 else maxf(radius, GameData.unit_explode_radius(unit))
	if _views.has(id) and _views[id].has_method("vanish"):
		_views[id].vanish()
	if look.get("spore", false): # a poison mushroom bursts into spores
		var cloud := SporeFx.new(SporeFx.BURST, reach)
		cloud.position = p - Vector2(0, 14)
		_fx_layer.add_child(cloud)
	else:
		var fx := ExplosionFx.new()
		fx.radius = reach
		fx.kind = str(look["kind"])
		fx.tier = str(look["tier"])
		fx.position = p
		_fx_layer.add_child(fx)
	var wave := BlastFx.new()
	wave.radius = reach
	wave.icy = bool(look["icy"])
	wave.color = BossArt.accent(art)
	wave.position = p
	_fx_layer.add_child(wave)
	_hold_focus({"pos": p + LOOK_LIFT}, CameraModel.HOLD_SEC + 0.3)
	_cam.shake(reach * 2.0)
	_check_terrain_version(e)


## A ground shockwave in a boss shot (Shockwave.detect(): its steps tagged): its ripple and dust
## (ShockwaveFx, synced to the replay). Returns whether there is one.
func _start_shockwave(timeline) -> bool:
	var wave := Shockwave.detect(timeline.events, true)
	if wave.is_empty():
		return false
	_wave_fx = ShockwaveFx.new()
	_wave_fx.setup(wave, _mask, BossArt.accent(BossArt.art_of(_boss.boss_id)))
	_fx_layer.add_child(_wave_fx)
	return true


## A shockwave step's explode: its crater (ShockwaveFx draws the ripple and the dust), a small
## shake, the terrain version kept.
func _wave_step(e: Dictionary) -> void:
	var p := _vec(e["position"])
	var radius := float(e.get("radius", 0.0))
	if radius > 0.0:
		_mask.carve(str(e.get("crater", TerrainMask.CRATER_BOWL)) if e.get("crater") is String else TerrainMask.CRATER_BOWL, p.x, p.y, radius)
		_terrain_view.refresh()
	_cam.shake(maxf(radius, 30.0))
	_check_terrain_version(e)


## UnitJumped {playerId, from, to, duration, height}: a leaper's arc jump (PlayerView.jump()), the
## camera with it; the events after it wait until it lands (_flight_hold). It glows from now
## until its next turn ends (LeapWarning).
func _on_unit_jumped(d: Variant) -> void:
	if not d is Dictionary:
		return
	var id := str(d.get("playerId", ""))
	var jump = JumpModel.from_event(d)
	if jump == null or not _players.has(id):
		return
	_set_pos(id, jump.to)
	# a leaper that blows up after its leap glows until then; the snowman (063: leapDetonateNextTurn
	# false) leaps once and shoots snowballs after it: no warning
	var detonates := GameData.minion_leap_detonates(str(_players[id].get("bossId", "")), str(_players[id].get("minionId", "")))
	if detonates:
		_players[id]["leapt"] = true
		_leaps.on_jump(id, _turn_index)
	var view = _views.get(id)
	if view == null or not view.has_method("jump"):
		return
	view.set_leapt(detonates)
	view.jump(jump.from, jump.to, jump.duration, jump.height)
	_cam.sky = true # its arc may top out above the map (this turn's follow rises with it)
	if view.in_flight():
		_flight_hold = true
		_hold_focus({"view": view}, jump.duration + FALL_TAIL)


## The witch's blizzard (projectiles of kind ice_shard leaving a ring round her, server launchFrom
## boss): her orbiting shards spin up and multiply until the first one leaves, whirl while they
## leave one after another, then regrow (BossBody.cast_shards()).
func _cast_shards(shooter: String, timeline) -> void:
	var view = _views.get(shooter)
	if view == null or not view.is_boss_side() or not view.figure().has_method("cast_shards"):
		return
	var first := INF
	var last := -INF
	for i in timeline.projectiles.size():
		if timeline.kind(i) == UnitShell.ICE_SHARD:
			first = minf(first, timeline.launch_time(i))
			last = maxf(last, timeline.launch_time(i))
	if first < INF:
		view.figure().cast_shards(first, last - first)


## A drawn boss (BossBody.has_frames(): the witch's frames) plays its shot's animation, its peak
## on the shot's moment (BossAnim.action_for(): the burst's flash on the beams, the summon on the
## summon, the cast / the blizzard on the first projectile leaving).
func _play_boss_action(shooter: String, timeline) -> void:
	var view = _views.get(shooter)
	if view == null or not view.is_boss() or not view.figure().has_method("play_action") or not view.figure().has_frames():
		return
	var boss_id := str(_players.get(shooter, {}).get("bossId", ""))
	var launches: Array = []
	for i in timeline.projectiles.size():
		launches.append(timeline.launch_time(i))
	view.figure().play_action(BossAnim.action_for(timeline.action_mode, timeline.skill_id, GameData.boss_skill(boss_id, timeline.skill_id),
		timeline.events, launches))


## A summon's minions appear farther apart than the view is wide.
func _summons_spread(events: Array) -> bool:
	var lo := INF
	var hi := -INF
	for e in events:
		if e is Dictionary and str(e.get("type", "")) == "summon" and e.get("position") is Dictionary:
			lo = minf(lo, float(e["position"].get("x", 0.0)))
			hi = maxf(hi, float(e["position"].get("x", 0.0)))
	return hi - lo > _cam.world_view().x * 0.8


## The turn turn_index of player id ended: a leap before it is spent (its glow goes off).
func _end_leap(id: String, turn_index: int) -> void:
	if _leaps.on_turn_end(id, turn_index):
		if _players.has(id):
			_players[id]["leapt"] = false
		if _views.has(id):
			_views[id].set_leapt(false)


## The leapt snowmen (tests, the harness).
func leap_state() -> LeapWarning:
	return _leaps


## The boss fight's HUD state (BossHudModel.state(); tests, the harness).
func boss_state() -> Dictionary:
	return _boss.state()


## The lava pools held (tests, the harness).
func lava_ids() -> Array:
	return _lava.ids()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _my_skill() -> Dictionary:
	return Skills.for_character(str(_players.get(_me, {}).get("characterId", "")))


func _pos(id: String) -> Vector2:
	return _vec(_players[id]["position"])


func _set_pos(id: String, p: Vector2) -> void:
	if _players.has(id):
		_players[id]["position"] = {"x": p.x, "y": p.y}


## Shows skill energies, {playerId: energy}: the players' values, their auras and (mine) the
## skill slot.
func _show_energies(energies: Dictionary) -> void:
	var mine := false
	for id in energies:
		var value = energies[id]
		if not _players.has(id) or not (value is int or value is float):
			continue
		_players[id]["skillEnergy"] = int(value)
		if _views.has(id):
			_views[id].set_skill_energy(int(value))
		mine = mine or id == _me
	if mine:
		_refresh_controls()


## A player's shield now (caster: who gave it, the shield event's shooter; "" for every other
## change): the HP bar's segment, and the bubble (ShieldState: popping in on a new shield in the
## caster's gun tier colour, out when it breaks).
func _set_shield(id: String, shield: int, caster: String = "") -> void:
	if not _players.has(id):
		return
	_players[id]["shield"] = shield
	var caster_tier := _gun_tier(caster) if caster != "" and _players.has(caster) else ""
	var change := _shields.update(id, shield, caster_tier, _gun_tier(id))
	if (change == ShieldState.GAIN or (change == ShieldState.KEEP and caster_tier != "")) and _views[id].has_method("set_shield_tint"):
		_views[id].set_shield_tint(_shields.colour_of(id))
	_views[id].set_shield(shield)


## Each player's badge (rankBadge, the name's badge): the BattlePlayerState's, else the MatchFound
## card's (Router.match_roster), mine else the profile's.
func _fill_badges() -> void:
	for id in _players:
		var p = _players[id]
		if not p is Dictionary or str(p.get("role", "")) != "" or str(p.get("rankBadge", "")) != "":
			continue
		var badge := str(_roster.get(id, {}).get("rankBadge", ""))
		if badge == "" and id == _me:
			badge = PlayerState.rank_badge()
		if badge != "":
			p["rankBadge"] = badge


## The tier of the gun a player brought (its weaponItemId; "basic" for its character's own gun).
func _gun_tier(id: String) -> String:
	return str(EquipmentModel.player_gun(_players.get(id, {}), PlayerState.catalog).get("tier", ""))


## The shield bubbles' state (tests, the harness).
func shield_state() -> ShieldState:
	return _shields


## A lost turn (TurnStarted skipped + skipAfter): its countdown over the unit (a ring and the
## seconds left, no text) and, for my own, dead centre on the HUD; a TurnStarted held back by a
## replay counts from its arrival. Anything else (a normal turn, a snapshot) stops it.
func _start_countdown(data: Dictionary) -> void:
	var elapsed := _since(int(data["receivedAt"])) if data.get("receivedAt") is int else 0.0
	if _ended or not _countdown.start(data, _skip, elapsed):
		_countdown.stop()
	if _unit_ring != null and is_instance_valid(_unit_ring):
		_unit_ring.queue_free()
	_unit_ring = null
	var view = _views.get(_countdown.player_id)
	if _countdown.active() and view != null and view.has_method("overhead_point"):
		_unit_ring = CountdownRing.new()
		_unit_ring.radius = UNIT_RING_RADIUS * clampf(view.body_size, 1.0, 1.6) if "body_size" in view else UNIT_RING_RADIUS
		_unit_ring.position = view.overhead_point(_unit_ring.radius)
		_unit_ring.z_index = 5
		view.add_child(_unit_ring)
	_show_countdown()


func _step_countdown(delta: float) -> void:
	if _countdown.total <= 0.0:
		return
	var before := _countdown.number()
	_countdown.step(delta)
	if _countdown.number() != before or _countdown.active():
		_show_countdown()
	if not _countdown.active():
		_countdown.stop()
		_show_countdown()


func _show_countdown() -> void:
	var n := _countdown.number()
	if _unit_ring != null and is_instance_valid(_unit_ring):
		_unit_ring.show_time(_countdown.effect, n, _countdown.fraction())
		if n <= 0:
			_unit_ring.queue_free()
			_unit_ring = null
	var mine := _countdown.player_id == _me and _me != ""
	_hud.show_countdown(_countdown.effect, n if mine else 0, _countdown.fraction())


## The countdown (tests): {active, effect, player, number, fraction, unit_ring}.
func countdown_state() -> Dictionary:
	return {"active": _countdown.active(), "effect": _countdown.effect, "player": _countdown.player_id,
		"number": _countdown.number(), "fraction": _countdown.fraction(),
		"unit_ring": _unit_ring != null and is_instance_valid(_unit_ring) and _unit_ring.visible}


## My blind white-out: on while BlindOverlay.wanted() (my turn, blinded, before my shot is answered).
func _refresh_blind(delta: float) -> void:
	if _blind == null:
		return
	_blind.set_on(BlindOverlay.wanted(_is_my_turn(), _players.get(_me, {}).get("statusEffects"), _turn_resolved))
	_blind.step(delta)


func blind_overlay() -> BlindOverlay:
	return _blind


func _set_hp(id: String, hp: int) -> void:
	if not _players.has(id):
		return
	_players[id]["hp"] = hp
	_views[id].set_hp(hp)
	if _boss.set_hp(id, hp):
		_hud.set_boss(_boss.state())


func _tick_status(id: String) -> void:
	_players[id]["statusEffects"] = Status.tick(_players[id].get("statusEffects"))
	_views[id].set_status(_players[id]["statusEffects"])


func _kill(id: String) -> void:
	if not _players.has(id):
		return
	_players[id]["isAlive"] = false
	_views[id].set_dead()
	if _leaps.clear(id):
		_views[id].set_leapt(false)
	var was_armored := _boss.armored()
	if _boss.kill(id):
		_views[id].set_shielded(false)
		_marks.clear() # the marks vanish with the boss
		_mark_view.clear()
		_sync_aura(true, was_armored)
		_hud.set_boss(_boss.state())
	elif _boss.minion_died(id): # its aura goes at once: its link snaps (the last totem: the plates break)
		_sync_aura(true, was_armored)


## A hit in a multi-hit skill shot: added to the player's running number (DamageTally), a new
## one when it has none or its last one is already fading.
func _tally(id: String, amount: int, critical: bool, element_effect: String = "") -> void:
	if not _views.has(id):
		return
	if not _has_tally(id):
		var t := DamageTally.new()
		t.follow = _views[id]
		_fx_layer.add_child(t)
		_tallies[id] = t
	_tallies[id].add(amount, critical, element_effect)


func _has_tally(id: String) -> bool:
	var t = _tallies.get(id)
	return t != null and is_instance_valid(t) and not t.is_queued_for_deletion() and not t.is_fading()


## A shot's damage number: DamagePopup.style() of the event's elementEffect and critical.
func _damage_popup(id: String, amount: int, critical: bool, element_effect: String) -> void:
	_popup(id, DamagePopup.damage_text(amount), Color.WHITE, Vector2.ZERO, DamagePopup.style(element_effect, critical))


## A number popped over player id a moment ago (DamagePopup.STACK_MS).
func _just_popped(id: String) -> bool:
	var last: Array = _popup_row.get(id, [-100000, 0])
	return Time.get_ticks_msec() - int(last[0]) < DamagePopup.STACK_MS


func _popup(id: String, text: String, color: Color, offset: Vector2 = Vector2.ZERO, st: Dictionary = {}) -> void:
	if not _views.has(id):
		return
	var label := DamagePopup.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	if not st.is_empty():
		label.set_style(st)
	var now := Time.get_ticks_msec()
	var last: Array = _popup_row.get(id, [-100000, 0])
	var n: int = int(last[1]) + 1 if now - int(last[0]) < DamagePopup.STACK_MS else 0
	_popup_row[id] = [now, n]
	label.position = _views[id].position + Vector2(0, -140) + offset + DamagePopup.stagger(n)
	_fx_layer.add_child(label)


# ── Visual only (no game state) ──────────────────────────────────────────────

## My character draws its gun when a drag starts (power 0: no direction yet, so no turn), then
## turns to the side I aim at and points the gun there (snapped to its 7 directions, AimSnap; the
## aim line and the Shoot keep the real angle).
func _face_aim(angle: float, power: float) -> void:
	if not _views.has(_me):
		return
	if power <= 0.0:
		_views[_me].draw_gun()
		return
	_views[_me].face_angle(angle)
	_views[_me].aim(angle)


func _clear_my_aim() -> void:
	if _views.has(_me):
		_views[_me].clear_aim()


## The shooter turns towards where its first projectile leaves, points its gun along it and
## fires it; the projectiles are drawn leaving from the muzzle (ShotPlayer). A holstered gun
## (remote and bot shots, never aimed here) is drawn fast first: returns that wait, the replay's
## lead-in, so the shell appears as the gun is out. A shot that does not start at the shooter
## (air strike from the sky) only plays the body's recoil, the gun stays away.
func _show_shooting(shooter: String, timeline) -> float:
	if not _views.has(shooter):
		return 0.0
	if timeline.projectiles.is_empty():
		# Nothing leaves the gun: a skill may still point it (the laser along its beam)
		var beam: float = _skill_view.aim_angle(timeline) if _skill_view != null else NAN
		if is_nan(beam):
			_views[shooter].clear_aim()
			return 0.0
		_views[shooter].face_angle(beam)
		_views[shooter].aim(beam)
		return _views[shooter].shoot()
	var view = _views[shooter]
	if view.is_boss():
		# A boss's projectiles leave from where the server starts them (above the map, a ring of
		# ice shards round the witch), never blended from a muzzle.
		view.shoot(false)
		return 0.0
	var start: Vector2 = timeline.sample(0, 0.0)
	var d: Vector2 = timeline.sample(0, 0.05) - start
	var near := start.distance_to(view.position) <= ShotPlayer.SPAWN_NEAR
	if near and d.length() > 0.01:
		var angle := rad_to_deg(atan2(-d.y, d.x))
		view.face_angle(angle) # the gun shows the snapped direction (AimSnap), the shell flies the real one
		view.aim(angle)
	if not near:
		view.shoot(false)
		return 0.0
	var lead_in: float = view.shoot()
	_shot_player.muzzle = _fx_layer.to_local(view.fire_muzzle_position()) # the recoiled gun's, once out
	return lead_in


# ── Camera ──────────────────────────────────────────────────────────────────

func _set_map_size(map_size: Vector2) -> void:
	if _camera != null:
		_camera.set_map(map_size)
	else:
		_cam.setup(map_size, _cam.view_size)


## Feeds the camera what it follows this frame (CameraModel: each call only acts in its own
## mode, so a manual look stays until the next take): my aim drag (its start takes the camera;
## column mode scrolls at the screen's sides), a remote aim's sweep, the replay's live shells and
## held points, the current player walking.
func _track_camera(delta: float) -> void:
	_clock += delta
	if _aim != null:
		_aim.view_top = _cam.view_rect().position.y
		var dragging := _aim.is_dragging()
		if dragging:
			var anchor := _aim.shooter_pos + Trajectory.shot_offset()
			var look = _aim.look_point()
			if not _aim_dragging:
				_cam.start_aim(anchor, _cam.center if _aim.target_column or look == null else look)
			elif _aim.target_column:
				_cam.column_scroll(_aim.pointer_screen().x, delta)
			elif look != null:
				_cam.aim_at(anchor, look)
		elif _aim_dragging:
			_cam.release() # stays until the shot plays
		_aim_dragging = dragging
	if _current != _me and _views.has(_current):
		var angle: float = _views[_current].sweep_angle()
		if not is_nan(angle):
			var from: Vector2 = _views[_current].position + Trajectory.shot_offset()
			_cam.aim_at(from, from + _aim_dir(angle) * REMOTE_LOOK)
	if (_shot_player != null and _shot_player.is_playing()) or not _focus.is_empty():
		var follow_shells: bool = _shot_player != null and (_skill_view == null or _skill_view.tracks_shells())
		var points := _shot_player.live_positions() if follow_shells else PackedVector2Array()
		var kept: Array = []
		for f in _focus:
			if float(f["until"]) < _clock:
				continue
			kept.append(f)
			if f.has("view"):
				if is_instance_valid(f["view"]):
					points.append(f["view"].position + _view_lift(f["view"]))
			else:
				points.append(f["pos"])
		_focus = kept
		_cam.track(points)
	if _views.has(_current):
		_cam.retarget(_views[_current].position + _view_lift(_views[_current]))
	if _markers != null and _hud != null and _hud.is_inside_tree():
		_markers.avoid = _hud.marker_avoid()


## Keeps the camera on a point (pos) or a player (view) for sec, and the next pan waits for it.
func _hold_focus(f: Dictionary, sec: float) -> void:
	f["until"] = _clock + sec
	_focus.append(f)
	_cam.hold(sec)


## The camera's point above a player's feet: LOOK_LIFT, higher for a big body (a boss: about the
## middle of its figure, so all of it is framed).
func _look_lift(id: String) -> Vector2:
	return _view_lift(_views.get(id))


func _view_lift(view) -> Vector2:
	if view == null or not is_instance_valid(view) or not view.is_boss_side():
		return LOOK_LIFT
	return Vector2(0, minf(LOOK_LIFT.y, -PlayerView.BODY.y * view.body_size * PlayerView.BOSS_ART_PER_BODY * 0.6))


## The unit direction of an aim angle (degrees, 0 right, 90 up).
static func _aim_dir(angle: float) -> Vector2:
	return Vector2(cos(deg_to_rad(angle)), -sin(deg_to_rad(angle)))


## A tap on a player's off-screen marker: the camera pans there and stays.
func _on_marker_tapped(id: String) -> void:
	if _views.has(id):
		_cam.look_at(_views[id].position + _view_lift(_views[id]))


func _show_wind() -> void:
	_sky.wind_dir = int(_wind.get("direction", 0))
	_sky.wind_power = float(_wind.get("power", 0.0))


static func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d["x"]), float(d["y"]))
