extends Node2D
## Dev preview of a character's bone rig (Rookie by default, the user arg --character=<id>: spark; used
## in matches: character.gd match_rig; this preview is not reachable from the game's screens): plays every motion
## in turn over a ground line, at the match's size (left) and at 3× (right): idle → raise the gun → aim
## sweep -30° .. 90° → two shots → lower → hurt → walk → die. Run it from the editor (F6 on
## scenes/dev/rig_preview.tscn), or record it: tools/record_rig_preview.sh (PNG frames, GIF).
## Ends after the sequence with the user arg --quit-at-end (the recorder); otherwise loops.
## With the user args --poses --out=<png> it draws the key poses side by side instead, big (POSES), into
## an off-screen viewport, saves it to the png and quits (the recorder's contact sheet).

const CharRig := preload("res://scenes/character/rig/char_rig.gd")

const SIZE := Vector2(960, 540)
const GROUND_Y := 452.0
const MATCH_HEIGHT := 62.0 # px: the ~62 px match body (character.gd art_height × the match scale)
const ZOOM := 3.0
const BG := Color(0.80, 0.87, 0.93)
const GROUND := Color(0.47, 0.37, 0.27)
const INK := Color(0.12, 0.13, 0.17)

## [time s, action, arg]: actions call the rig's motion; "label" names the stretch.
const SEQUENCE := [
	[0.0, "label", "đứng yên"],
	[1.6, "label", "giương súng"], [1.6, "aim", 10.0], [1.6, "raise", true],
	[2.2, "label", "ngắm -30° … 90°"], [2.2, "aim", -30.0], [3.1, "aim", 90.0], [4.2, "aim", 45.0], [4.8, "aim", 20.0],
	[5.2, "label", "bắn"], [5.3, "shoot", null], [5.95, "shoot", null],
	[6.7, "label", "hạ súng"], [6.7, "raise", false],
	[7.2, "label", "trúng đạn"], [7.25, "hurt", null],
	[8.3, "label", "đi"], [8.3, "walk", true], [10.7, "walk", false],
	[11.1, "label", "ngã"], [11.2, "die", null],
	[13.4, "end", null],
]

## [label, [[t, action, arg], ...], seconds simulated]: one still per key pose.
const POSES := [
	["đứng yên", [], 1.0],
	["giương súng (giữa)", [[0.0, "raise", true]], 0.13],
	["ngắm -30°", [[0.0, "raise", true], [0.0, "aim", -30.0]], 1.5],
	["ngắm 0°", [[0.0, "raise", true], [0.0, "aim", 0.0]], 1.5],
	["ngắm 45°", [[0.0, "raise", true], [0.0, "aim", 45.0]], 1.5],
	["ngắm 60°", [[0.0, "raise", true], [0.0, "aim", 60.0]], 1.5],
	["ngắm 75°", [[0.0, "raise", true], [0.0, "aim", 75.0]], 1.5],
	["ngắm 90°", [[0.0, "raise", true], [0.0, "aim", 90.0]], 1.5],
	["bắn 90°: giật", [[0.0, "raise", true], [0.0, "aim", 90.0], [1.5, "shoot", null]], 1.57],
	["bắn: giật", [[0.0, "raise", true], [0.0, "aim", 20.0], [1.0, "shoot", null]], 1.06],
	["bắn: hồi", [[0.0, "raise", true], [0.0, "aim", 20.0], [1.0, "shoot", null]], 1.22],
	["trúng đạn", [[0.0, "hurt", null]], 0.09],
	["trúng đạn: hồi", [[0.0, "hurt", null]], 0.32],
	["đi (bước 1)", [[0.0, "walk", true]], 0.75],
	["đi (bước 2)", [[0.0, "walk", true]], 0.9],
	["đi (bước 3)", [[0.0, "walk", true]], 1.05],
	["ngã: khuỵu", [[0.0, "die", null]], 0.3],
	["ngã: đổ", [[0.0, "die", null]], 0.6],
	["ngã: nằm", [[0.0, "die", null]], 2.0],
]
const POSE_CELL := Vector2(380, 330)
const POSE_COLS := 6

var rigs: Array = []
var _poses := false
var _frames := 0
var _sheet_vp: SubViewport
var _sheet: Node2D
var _t := 0.0
var _next := 0
var _label := ""
var _start_x: Array = []
var _quit_at_end := false
var _character := "rookie"


func _ready() -> void:
	_quit_at_end = OS.get_cmdline_user_args().has("--quit-at-end")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--character="):
			_character = a.trim_prefix("--character=")
	if OS.get_cmdline_user_args().has("--poses"):
		_build_poses()
		return
	for i in 2:
		var r := _rig()
		add_child(r)
		rigs.append(r)
	var h: float = rigs[0].height()
	rigs[0].scale = Vector2.ONE * (MATCH_HEIGHT / h)
	rigs[1].scale = Vector2.ONE * (MATCH_HEIGHT * ZOOM / h)
	_start_x = [190.0, 600.0]
	_restart()


## A rig of _character, its back sling and gun length from its carry scene when the game's code is
## there (character.gd rig_back(); the recorder's mini project has only the rig: its defaults).
func _rig() -> Node2D:
	var r := CharRig.new()
	r.auto = false
	r.character_id = _character
	r.setup()
	if ResourceLoader.exists("res://scenes/character/character.gd") and ResourceLoader.exists("res://ui/art.gd"):
		var sling: Dictionary = load("res://scenes/character/character.gd").rig_back(_character, r.height())
		if not sling.is_empty():
			r.model.set_back(sling["pos"], sling["deg"], sling["frac"], sling["lift"], sling["length"])
	return r


func _restart() -> void:
	_t = 0.0
	_next = 0
	for i in rigs.size():
		var r = rigs[i]
		r.motion = r.motion.get_script().new()
		r.position = Vector2(_start_x[i], GROUND_Y)
		r.refresh()


func _build_poses() -> void:
	_poses = true
	_sheet_vp = SubViewport.new()
	_sheet_vp.size = Vector2i(int(POSE_CELL.x) * POSE_COLS, int(POSE_CELL.y) * ceili(POSES.size() / float(POSE_COLS)))
	_sheet_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sheet_vp)
	_sheet = Node2D.new()
	_sheet.draw.connect(_draw_poses)
	_sheet_vp.add_child(_sheet)
	for i in POSES.size():
		var spec: Array = POSES[i]
		var r := _rig()
		_sheet.add_child(r)
		r.scale = Vector2.ONE * (250.0 / r.height())
		var lying := 150.0 if str(spec[0]).begins_with("ngã: đổ") or str(spec[0]).begins_with("ngã: nằm") else 0.0
		r.position = Vector2((i % POSE_COLS + 0.5) * POSE_CELL.x - 20.0 + lying, (i / POSE_COLS + 1) * POSE_CELL.y - 30.0)
		var t := 0.0
		var k := 0
		var acts: Array = spec[1]
		while t < float(spec[2]) - 1e-6:
			while k < acts.size() and float(acts[k][0]) <= t + 1e-6:
				_apply(r, acts[k][1], acts[k][2])
				k += 1
			r.motion.advance(1.0 / 120.0)
			t += 1.0 / 120.0
		r.refresh()
		rigs.append(r)


func _process(delta: float) -> void:
	if _poses:
		_frames += 1
		if _frames == 4:
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--out="):
					_sheet_vp.get_texture().get_image().save_png(a.trim_prefix("--out="))
			if _quit_at_end:
				get_tree().quit()
		return
	_t += delta
	while _next < SEQUENCE.size() and SEQUENCE[_next][0] <= _t:
		_act(SEQUENCE[_next])
		_next += 1
	for r in rigs:
		var speed: float = r.motion.walk_speed() * r.motion.walk * r.scale.x
		r.position.x += speed * delta
		r.advance(delta)
	queue_redraw()


func _act(step: Array) -> void:
	var what: String = step[1]
	if what == "label":
		_label = step[2]
		return
	if what == "end":
		if _quit_at_end:
			get_tree().quit()
		else:
			_restart()
		return
	for r in rigs:
		_apply(r, what, step[2])


func _apply(r, what: String, arg) -> void:
	match what:
		"aim":
			r.motion.set_aim(arg)
		"raise":
			r.motion.raise_gun(arg)
		"shoot":
			r.motion.shoot()
		"hurt":
			r.motion.hurt()
		"walk":
			r.motion.set_walking(arg)
		"die":
			r.motion.die()


func _draw() -> void:
	if _poses:
		return
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	draw_rect(Rect2(0, GROUND_Y, SIZE.x, SIZE.y - GROUND_Y), GROUND)
	draw_line(Vector2(0, GROUND_Y), Vector2(SIZE.x, GROUND_Y), INK, 2.0)
	draw_line(Vector2(330, 60), Vector2(330, GROUND_Y), Color(INK, 0.25), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 40), _label, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 28, INK)
	draw_string(font, Vector2(0, GROUND_Y + 40), "cỡ trong trận", HORIZONTAL_ALIGNMENT_CENTER, 330, 18, Color(1, 1, 1, 0.85))
	draw_string(font, Vector2(330, GROUND_Y + 40), "phóng to ×3", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x - 330, 18, Color(1, 1, 1, 0.85))
	draw_string(font, Vector2(16, SIZE.y - 14), "%.1f s" % _t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))


func _draw_poses() -> void:
	var rows := ceili(POSES.size() / float(POSE_COLS))
	_sheet.draw_rect(Rect2(Vector2.ZERO, Vector2(POSE_CELL.x * POSE_COLS, POSE_CELL.y * rows)), BG)
	var font := ThemeDB.fallback_font
	for i in POSES.size():
		var o := Vector2((i % POSE_COLS) * POSE_CELL.x, (i / POSE_COLS) * POSE_CELL.y)
		var gy := o.y + POSE_CELL.y - 30.0
		_sheet.draw_rect(Rect2(o.x, gy, POSE_CELL.x, 30.0), GROUND)
		_sheet.draw_rect(Rect2(o, POSE_CELL), Color(INK, 0.3), false, 1.0)
		_sheet.draw_string(font, o + Vector2(10, 26), POSES[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
