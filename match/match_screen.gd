extends Node2D
## Match against the server. The server is authoritative: this screen renders its snapshot,
## replays ShotResolved, and predicts only the local player's walk (MoveSync). Every match
## event that arrives during a replay waits until the replay ends, and the turn clock is paused
## from the shot until the next timer event, so the HUD never runs ahead of the animation.
## Items: instant ones (medkit, wind_stopper) go out as UseItem through the same commit path as
## a shot but leave the turn open; shot items arm the next Shoot (actionMode "item").
## See docs/superpowers/specs/2026-10-15-godot-client-roadmap-design.md.

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const ProjectileView := preload("res://match/views/projectile_view.gd")
const DamagePopup := preload("res://match/views/damage_popup.gd")
const SkyView := preload("res://match/views/sky_view.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const MoveSync := preload("res://match/move/move_sync.gd")
const Hud := preload("res://match/hud.gd")
const Skills := preload("res://match/skills.gd")
const Items := preload("res://match/items.gd")
const Status := preload("res://match/status_effects.gd")

const ACTION_INTERVAL := 0.25 # server drops actions closer than 150 ms
const MOVE_ACK_GAP := 0.16 # Shoot/EndTurn/UseItem wait this long after the last answer to a Move
# Both waits are measured with Time.get_ticks_usec() from the moment they start, not by summing
# frame deltas: a long frame right before an answer is read would count time from before it.
const OTHER_WALK_SPEED := 90.0
const OTHER_WALK_MAX_SEC := 1.0 # a bot fires 1.5 s after its Move: finish the walk before that
const SHOT_ACK_TIMEOUT := 3.0
const ITEM_ACK_TIMEOUT := 1.5 # input waits this long for ItemUsed after a UseItem
const TELEPORT_SEC := 0.3
const WEAPON := "weapon"
const SKILL := "skill"
const RESYNC_RETRY := 3.0 # re-ask for MatchStateSync if none arrived
const TURN_SECONDS := 20

var _me := ""
var _players := {} # playerId -> server BattlePlayerState
var _views := {} # playerId -> PlayerView
var _current := ""
var _wind := {"direction": 0, "power": 0.0}
var _ended := false
var _deferred: Array = []
var _awaiting_ack := 0.0 # seconds left for the server to answer a sent Shoot/EndTurn/UseItem
var _awaiting_item := "" # the instant item a sent UseItem waits for ("" for Shoot/EndTurn)
var _committing := false # an action requested: input locked until it is answered
var _commit_sent := false # a Shoot/EndTurn sent: no more Moves this turn
var _cmd_sent := false # the pending commit (Shoot/EndTurn/UseItem) has actually been sent
var _resync_in := 0.0 # seconds before asking for MatchStateSync again
var _turn_resolved := false # this turn's shot was answered: the server takes no more actions
var _move_ack_at := -10_000_000 # Time.get_ticks_usec() when the last PlayerMoved for my Moves was handled
var _disconnected := false
var _armed := WEAPON # what my next Shoot fires: WEAPON, SKILL or a shot item id; local only
var _turn_index := -1

var _mask := TerrainMask.new()
var _moves := MoveSync.new()
var _sky: SkyView
var _terrain_view: TerrainView
var _players_layer: Node2D
var _fx_layer: Node2D
var _aim: AimInput
var _shot_player: ShotPlayer
var _hud: Hud

var _hold_dir := 0
var _action_at := -10_000_000 # Time.get_ticks_usec() when my last Move/Shoot/EndTurn/UseItem was sent


func _ready() -> void:
	_me = Session.player_id
	_sky = SkyView.new()
	_sky.size = get_viewport_rect().size
	add_child(_sky)
	_terrain_view = TerrainView.new()
	add_child(_terrain_view)
	_players_layer = Node2D.new()
	add_child(_players_layer)
	_fx_layer = Node2D.new()
	add_child(_fx_layer)
	_aim = AimInput.new()
	add_child(_aim)
	_shot_player = ShotPlayer.new()
	_shot_player.layer = _fx_layer
	add_child(_shot_player)
	var ui := CanvasLayer.new()
	add_child(ui)
	_hud = Hud.new()
	ui.add_child(_hud)

	_moves.terrain = _mask
	_aim.fire.connect(_on_fire)
	_aim.aim_changed.connect(_hud.set_aim)
	_aim.aim_changed.connect(_face_aim)
	_aim.column_changed.connect(_hud.set_column)
	_shot_player.event_due.connect(_on_shot_event)
	_shot_player.finished.connect(_on_shot_finished)
	_hud.move_pressed.connect(func(dir: int) -> void: _hold_dir = dir)
	_hud.move_released.connect(func() -> void: _hold_dir = 0)
	_hud.end_turn_pressed.connect(_on_end_turn)
	_hud.weapon_pressed.connect(_on_weapon_pressed)
	_hud.skill_pressed.connect(_on_skill_pressed)
	_hud.item_pressed.connect(_on_item_pressed)
	_aim.fire_column.connect(_on_fire_column)
	_hud.leave_pressed.connect(_on_leave)

	var snap: Dictionary = Router.match_snapshot
	Router.match_snapshot = {} # consumed: a later Match scene must not start from it
	_load_snapshot(snap, false)
	GameSocket.event_received.connect(_on_event)
	GameSocket.disconnected.connect(_on_disconnected)
	GameSocket.release()


func _process(delta: float) -> void:
	if _awaiting_ack > 0.0:
		_awaiting_ack -= delta
		if _awaiting_ack <= 0.0:
			# The server ignored the Shoot/EndTurn/UseItem: give control back.
			_committing = false
			_commit_sent = false
			_cmd_sent = false
			_awaiting_item = ""
			_refresh_controls()
	# Once the shot is answered the server takes no Moves until TurnStarted: sending one (e.g.
	# a walk after SHOT_ACK_TIMEOUT gave control back, then a late ShotResolved) would only
	# lose it and send Reconnect in the middle of the replay.
	if not _is_my_turn() or _commit_sent or _turn_resolved:
		return
	if _hold_dir != 0 and _can_act():
		_moves.hold(_hold_dir, delta)
	# Runs while a Shoot/EndTurn waits too, so the rest of the walk (and a re-send of an
	# unanswered Move) still goes out before it; _commit_action waits for them.
	var cmd := _moves.update(Time.get_ticks_msec() / 1000.0, _since(_action_at) >= ACTION_INTERVAL)
	if not cmd.is_empty():
		GameSocket.send("Move", cmd)
		_mark_action()
	if _moves.needs_resync():
		_request_resync(delta)
	if not _shot_player.is_playing():
		var changes := _moves.take_changes()
		if changes.has("position"):
			_views[_me].position = changes["position"]
			_aim.shooter_pos = changes["position"]
		if changes.has("energy"): # may change alone, e.g. when dropped Moves were not charged
			_hud.set_energy(changes["energy"])


# ── Snapshot and turn state ──────────────────────────────────────────────────

## Rebuilds the match from a snapshot: MatchStarted (is_sync false) or a MatchStateSync. A
## MatchStateSync for the current player continues the turn: during mine MoveSync replays the
## Moves the snapshot does not show yet on top of it, and a resolved shot keeps input locked
## and the clock paused.
func _load_snapshot(snap: Dictionary, is_sync: bool) -> void:
	var current := str(snap.get("currentPlayerId", ""))
	var continuing := is_sync and current == _current
	_shot_player.stop()
	_deferred.clear()
	var terrain: Dictionary = snap.get("terrain", {})
	if not terrain.is_empty() and _mask.load_snapshot(terrain):
		_terrain_view.show_mask(_mask)
		_sky.size = Vector2(_mask.width, _mask.height)
	for view in _views.values():
		view.queue_free()
	_views.clear()
	_players = snap.get("players", {}).duplicate(true)
	var my_team := int(_players.get(_me, {}).get("teamId", -1))
	for id in _players:
		var view := PlayerView.new()
		_players_layer.add_child(view)
		view.setup(_players[id], id == _me, my_team)
		view.face(1.0 if view.position.x < _mask.width / 2.0 else -1.0) # towards the middle
		_views[id] = view
	_wind = snap.get("wind", _wind)
	_turn_index = int(snap.get("turnIndex", _turn_index))
	var energy := int(_players.get(_me, {}).get("moveEnergy", 0))
	if is_sync and _players.has(_me) and _players[_me].has("position"):
		# Every MatchStateSync goes through MoveSync. lastMoveSeq (absent on an older server: -1)
		# says which of my Moves the snapshot already shows.
		var last_seq = snap.get("lastMoveSeq")
		_moves.apply_snapshot(_pos(_me), energy, int(last_seq) if (last_seq is int or last_seq is float) else -1)
	_hud.set_time(int(snap.get("turnTimeLeft", TURN_SECONDS)))
	if continuing and _turn_resolved:
		_hud.pause_timer() # this turn's shot is resolving: the server clock waits for TurnStarted
	_set_current(current, energy, continuing)


## continuing: the same turn goes on (a MatchStateSync for the current player), so MoveSync, a
## sent Shoot/EndTurn and a resolved shot are kept; otherwise a new turn starts.
func _set_current(player_id: String, move_energy: int, continuing: bool = false) -> void:
	_current = player_id
	_hold_dir = 0
	_resync_in = 0.0
	if not continuing:
		_armed = WEAPON # every turn starts with the weapon
		_awaiting_ack = 0.0
		_awaiting_item = ""
		_committing = false
		_commit_sent = false
		_cmd_sent = false
		_turn_resolved = false
		if _is_my_turn():
			_moves.reset(_pos(_me), move_energy)
	if _views.has(_me) and _players[_me].has("position"):
		# Leaving my turn with Moves unanswered or unsent (or with my last PlayerMoved in the
		# same frame) leaves the view on the prediction: walk it to the server's position.
		var view = _views[_me]
		var to := _pos(_me)
		view.move_to(to, 0.0 if _is_my_turn() else view.position.distance_to(to) / OTHER_WALK_SPEED)
	_hud.set_turn(_is_my_turn(), str(_players.get(player_id, {}).get("displayName", "")))
	_hud.set_wind(int(_wind.get("direction", 0)), float(_wind.get("power", 0.0)))
	_show_wind()
	for id in _views:
		_views[id].set_active(id == player_id and not _ended)
	_hud.set_energy(move_energy if _is_my_turn() else 0)
	_refresh_controls()


func _is_my_turn() -> bool:
	return not _ended and _current == _me and bool(_players.get(_me, {}).get("isAlive", false))


func _can_act() -> bool:
	return _is_my_turn() and not _shot_player.is_playing() and not _committing and not _turn_resolved \
		and not _moves.needs_resync()


func _is_frozen() -> bool:
	return Status.has(_players.get(_me, {}).get("statusEffects"), "freeze")


## Also drops the armed mode back to the weapon when it can no longer be fired: not my turn, the
## turn resolved, I am frozen, the skill is not charged, or the armed item is no longer in
## players[me].items. A temporary input lock (pending UseItem ack, commit wait, shot animation,
## resync) keeps the armed mode: the buttons are disabled meanwhile but the choice survives.
func _refresh_controls() -> void:
	var can := _can_act()
	var me: Dictionary = _players.get(_me, {})
	# The server takes no Shoot from a frozen player (only EndTurn and UseItem).
	var frozen := Status.has(me.get("statusEffects"), "freeze")
	var can_shoot := can and not frozen
	var may_shoot := _is_my_turn() and not _turn_resolved and not frozen # armed mode may stay
	_hud.set_controls_enabled(can)
	var skill := _my_skill()
	var energy := int(me.get("skillEnergy", 0))
	var skill_usable := can_shoot and not skill.is_empty() and Skills.is_ready(energy)
	var armed_ok := _armed == WEAPON or (_armed == SKILL and may_shoot and not skill.is_empty() and Skills.is_ready(energy))
	var buttons: Array = []
	for it in Items.hand(me.get("items")):
		var usable := can if Items.is_instant(it["id"]) else can_shoot
		buttons.append({"id": it["id"], "label": Items.button_label(it["id"], it["count"]), "enabled": usable})
		if it["id"] == _armed and may_shoot and not Items.is_instant(it["id"]):
			armed_ok = true
	if not armed_ok:
		_armed = WEAPON
	_hud.set_actions("" if skill.is_empty() else Skills.button_label(skill, energy), can, skill_usable, _armed, buttons)
	var offsets: Array = skill["offsets"] if _armed == SKILL else [0.0]
	if _aim.preview_offsets != offsets:
		_aim.preview_offsets = offsets
	_aim.target_column = Items.needs_target_x(_armed)
	_aim.enabled = can_shoot
	if can:
		_aim.shooter_pos = _views[_me].position
		_aim.terrain = _mask
		_aim.wind_dir = int(_wind.get("direction", 0))
		_aim.wind_power = float(_wind.get("power", 0.0))
	else:
		_hold_dir = 0


# ── Server events ────────────────────────────────────────────────────────────

func _on_event(event: String, data: Variant) -> void:
	if event == "MatchStateSync":
		_load_snapshot(data, true)
		return
	if _shot_player.is_playing():
		_deferred.append([event, data])
		return
	_apply(event, data)


func _apply(event: String, data: Variant) -> void:
	match event:
		"TurnStarted":
			_wind = data.get("wind", _wind)
			var index := int(data.get("turnIndex", _turn_index + 1))
			if index > _turn_index and _players.has(_current):
				_tick_status(_current) # the server ticks the effects at the end of their target's turn
			_turn_index = maxi(index, _turn_index)
			var energies: Dictionary = data.get("skillEnergy", {})
			for id in energies:
				if _players.has(id):
					_players[id]["skillEnergy"] = energies[id]
			_hud.set_time(TURN_SECONDS)
			_set_current(str(data.get("currentPlayerId", "")), int(data.get("moveEnergy", 0)))
		"TurnTimerTick":
			_hud.set_time(int(data.get("timeLeft", 0)))
		"PlayerMoved":
			_on_player_moved(data)
		"ShotResolved":
			_awaiting_ack = 0.0
			var shooter := str(data.get("shooterId", ""))
			if _players.has(shooter) and data.has("skillEnergy"):
				_players[shooter]["skillEnergy"] = int(data["skillEnergy"]) # 0 after a skill
			_turn_resolved = true # the server takes no more actions until TurnStarted
			_hud.pause_timer() # resumed by the next TurnTimerTick / TurnStarted
			_snap_to_server(shooter)
			var timeline := ShotTimeline.new(data)
			_show_shooting(shooter, timeline)
			# Each gun has its own projectile and impact (visuals only), picked by the shooter's
			# character; rookie's bomb when unknown.
			var shooter_char := str(_players.get(shooter, {}).get("characterId", ""))
			_shot_player.style = ProjectileView.style_for(shooter_char, str(data.get("actionMode", "")), str(data.get("itemId", "")))
			_shot_player.play(timeline)
			_refresh_controls()
		"PlayerDamaged": # lava at turn start (shot damage comes in ShotResolved)
			for e in data:
				_set_hp(str(e.get("playerId", "")), int(e.get("hp", 0)))
				if not bool(e.get("isAlive", true)):
					_kill(str(e.get("playerId", "")))
		"ItemUsed":
			_on_item_used(data)
		"MatchEnded":
			_on_match_ended(data)


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
			if not bool(p.get("isAlive", true)):
				_views[id].set_dead()
	_hud.set_wind(int(_wind.get("direction", 0)), float(_wind.get("power", 0.0)))
	_show_wind()
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
		return
	var view = _views[id]
	view.move_to(pos, minf(view.position.distance_to(pos) / OTHER_WALK_SPEED, OTHER_WALK_MAX_SEC))


## The shell leaves from the server's position: stop a walk still under way and put the
## shooter there before the replay starts.
func _snap_to_server(id: String) -> void:
	if _views.has(id) and _players.has(id) and _players[id].has("position"):
		_views[id].move_to(_pos(id), 0.0)


func _on_shot_event(e: Dictionary) -> void:
	var id := str(e.get("playerId", ""))
	match str(e.get("type", "")):
		"explode":
			var p := _vec(e["position"])
			var radius := float(e.get("radius", 0.0))
			_mask.destroy_circle(p.x, p.y, radius)
			_terrain_view.refresh()
			var fx := ExplosionFx.new()
			fx.radius = radius
			fx.kind = str(_shot_player.style.get("kind", "rookie"))
			fx.position = p
			_fx_layer.add_child(fx)
			var server_version := int(e.get("terrainVersion", _mask.version))
			if server_version != _mask.version:
				_mask.version = server_version
				GameSocket.send("Reconnect", {}) # terrain drifted: ask for MatchStateSync
		"damage":
			_set_hp(id, int(e.get("hp", 0)))
			var crit := bool(e.get("critical", false))
			_popup(id, "-%d" % int(e.get("amount", 0)), Color(1, 0.85, 0.2) if crit else Color(1, 0.3, 0.3))
		"heal":
			_set_hp(id, int(e.get("hp", 0)))
			var amount := int(e.get("amount", 0))
			if amount > 0:
				_popup(id, "+%d" % amount, Color(0.4, 1, 0.5))
		"fall":
			var to := _vec(e["to"])
			_set_pos(id, to)
			if _views.has(id):
				_views[id].move_to(to, float(e.get("duration", 0.0)), Tween.TRANS_QUAD, Tween.EASE_IN)
		"teleport":
			var to := _vec(e["to"])
			_set_pos(id, to)
			if _views.has(id):
				if e.get("from") is Dictionary:
					_views[id].position = _vec(e["from"])
				_views[id].move_to(to, TELEPORT_SEC, Tween.TRANS_SINE)
		"die":
			_kill(id)
		"status":
			if _players.has(id):
				_players[id]["statusEffects"] = Status.apply(_players[id].get("statusEffects"), str(e.get("effectId", "")), int(e.get("turns", 1)))
				_views[id].set_status(_players[id]["statusEffects"])
			var text := Skills.status_label(str(e.get("effectId", "")))
			if text != "":
				_popup(id, text, Color(0.7, 0.85, 1))


func _on_shot_finished() -> void:
	while not _deferred.is_empty() and not _shot_player.is_playing():
		var item: Array = _deferred.pop_front()
		_apply(item[0], item[1])
	_refresh_controls()


func _on_match_ended(d: Dictionary) -> void:
	_ended = true
	for view in _views.values():
		view.set_active(false)
	_refresh_controls()
	if str(d.get("result", "")) == "no_contest":
		_hud.show_result("Trận bị huỷ", str(d.get("message", "")))
		return
	var my_team := int(_players.get(_me, {}).get("teamId", -1))
	var winning_team := int(d.get("winningTeam", 0)) # 0: no team left alive
	var title := "Hoà"
	if winning_team != 0:
		title = "Chiến thắng!" if winning_team == my_team else "Thất bại"
	# The server sends "rewards": null when granting them failed; never show that as +0.
	var rewards = d.get("rewards")
	var reward = rewards.get(_me) if rewards is Dictionary else null
	var detail := "Chưa lấy được phần thưởng của trận này"
	if reward is Dictionary:
		detail = "+%d EXP   +%d xu" % [int(reward.get("expGained", 0)), int(reward.get("coinGained", 0))]
	_hud.show_result(title, detail)


# ── Local actions ────────────────────────────────────────────────────────────

func _on_fire(angle: float, power: float) -> void:
	if not _can_act():
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


func _fire(data: Dictionary) -> void:
	_armed = WEAPON # back to the weapon after a fire, even if the server drops the Shoot
	_hud.pause_timer() # the server stops the clock once it takes the shot
	await _commit_action("Shoot", data)


func _on_weapon_pressed() -> void:
	_armed = WEAPON
	_refresh_controls()


## An aimed skill toggles skill mode; one without aim (healing_bloom) is used at once, through
## the same commit path as a shot.
func _on_skill_pressed() -> void:
	var skill := _my_skill()
	var charged := Skills.is_ready(int(_players.get(_me, {}).get("skillEnergy", 0)))
	if not _can_act() or _is_frozen() or skill.is_empty() or not charged:
		_refresh_controls()
		return
	if bool(skill["needs_aim"]):
		_armed = WEAPON if _armed == SKILL else SKILL
		_refresh_controls()
		return
	await _fire({"angle": Skills.NO_AIM_ANGLE, "power": Skills.NO_AIM_POWER, "actionMode": SKILL})


## An instant item is used at once (UseItem; the turn goes on). A shot item toggles armed mode
## (_refresh_controls drops it again if it cannot be fired).
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
	_armed = WEAPON if _armed == item_id else item_id
	_refresh_controls()


func _on_end_turn() -> void:
	if not _can_act():
		return
	await _commit_action("EndTurn", {})


## Sends Shoot/EndTurn/UseItem once:
## - every Move has been answered (MoveSync.is_settled), so the server fires from the position
##   on screen; a dropped Move is re-sent first;
## - ACTION_INTERVAL has passed since the last action; and
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
func _commit_action(event: String, data: Dictionary, instant_item: String = "") -> void:
	_committing = true
	_hold_dir = 0
	_moves.release()
	_refresh_controls()
	while _committing and _is_my_turn() and not _turn_resolved and (not _moves.is_settled() \
			or _since(_action_at) < ACTION_INTERVAL or _since(_move_ack_at) < MOVE_ACK_GAP):
		await get_tree().process_frame
	if not _is_my_turn() or not _committing or _turn_resolved:
		return
	if instant_item == "":
		_commit_sent = true
		_awaiting_ack = SHOT_ACK_TIMEOUT
	else:
		_awaiting_item = instant_item
		_awaiting_ack = ITEM_ACK_TIMEOUT
	_cmd_sent = true
	GameSocket.send(event, data)
	_mark_action()


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
	Router.go(Router.HOME)


## The server treats a lost connection as Leave, so the match cannot be resumed (M2).
func _on_disconnected() -> void:
	_disconnected = true
	if _ended:
		return # the result is already on screen
	_ended = true
	_refresh_controls()
	_hud.show_result("Mất kết nối với trận đấu", "Về sảnh để bắt đầu trận mới")


# ── Helpers ──────────────────────────────────────────────────────────────────

func _my_skill() -> Dictionary:
	return Skills.for_character(str(_players.get(_me, {}).get("characterId", "")))


func _pos(id: String) -> Vector2:
	return _vec(_players[id]["position"])


func _set_pos(id: String, p: Vector2) -> void:
	if _players.has(id):
		_players[id]["position"] = {"x": p.x, "y": p.y}


func _set_hp(id: String, hp: int) -> void:
	if not _players.has(id):
		return
	_players[id]["hp"] = hp
	_views[id].set_hp(hp)


func _tick_status(id: String) -> void:
	_players[id]["statusEffects"] = Status.tick(_players[id].get("statusEffects"))
	_views[id].set_status(_players[id]["statusEffects"])


func _kill(id: String) -> void:
	if not _players.has(id):
		return
	_players[id]["isAlive"] = false
	_views[id].set_dead()


func _popup(id: String, text: String, color: Color) -> void:
	if not _views.has(id):
		return
	var label := DamagePopup.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.position = _views[id].position + Vector2(0, -140)
	_fx_layer.add_child(label)


# ── Visual only (no game state) ──────────────────────────────────────────────

## My character turns to the side I aim at.
func _face_aim(angle: float, _power: float) -> void:
	if _views.has(_me):
		_views[_me].face_angle(angle)


## The shooter turns towards where its first projectile leaves and plays its shoot animation.
func _show_shooting(shooter: String, timeline) -> void:
	if not _views.has(shooter) or timeline.projectiles.is_empty():
		return
	var d: Vector2 = timeline.sample(0, 0.05) - timeline.sample(0, 0.0)
	if absf(d.x) > 0.5:
		_views[shooter].face(d.x)
	_views[shooter].shoot()


func _show_wind() -> void:
	_sky.wind_dir = int(_wind.get("direction", 0))
	_sky.wind_power = float(_wind.get("power", 0.0))


static func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d["x"]), float(d["y"]))
