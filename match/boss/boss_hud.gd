extends VBoxContainer
## The boss fight's HUD (the Hud pins it at the top centre, under the timer and the wind): the
## boss's head-and-shoulders figure, its element's badge (ElementBadge) and name, "Vòng 3/15" and a big HP bar with "8.400 / 12.000"
## (a pale chunk trails each loss); while the boss is shielded (BossHudModel.shielded) the bar is
## tinted ice blue with moving hex stripes (no icon), the bar flashing when the shield goes on or
## off. Under it, on the boss's turn, its skill's name ("Mưa đạn pháo", from
## ActionSelected and the game data's bosses skills) pops in and fades (announce_skill()).
## Boss v4: a heal (a drain, a regen) fills the bar back up over RISE_SEC with a green glow on the
## part regained; while the boss is armoured (BossHudModel armored: its stone totems stand) the bar
## turns stone grey with amber rune marks moving along it, flashing as the armour goes on or breaks.

const LobbyUi := preload("res://ui/lobby_ui.gd")
const Ui := preload("res://ui/ui.gd")
const BossArt := preload("res://match/boss/boss_art.gd")
const BossArtView := preload("res://match/boss/boss_art_view.gd")
const ElementBadge := preload("res://ui/element_badge.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const BAR := Vector2(560, 30)
const TRAIL_SEC := 0.6
const SKILL_SEC := 2.2
const NAVY := Color(0.06, 0.09, 0.22, 0.82)
const RED := Color(0.92, 0.18, 0.16)
const ORANGE := Color(1.0, 0.55, 0.18)
const SHIELD := Color(0.5, 0.88, 1.0)
const RISE_SEC := 0.7
const HEAL := Color(0.45, 1.0, 0.45)
const STONE_TOP := Color(0.78, 0.68, 0.52)
const STONE_BOTTOM := Color(0.46, 0.38, 0.3)
const RUNE := Color(1.0, 0.78, 0.3)

var _state := {}
var _panel: PanelContainer
var _art: Control
var _name: Label
var _element # ElementBadge: the boss's element before its name
var _round: Label
var _bar: Control
var _hp: Label
var _skill: PanelContainer
var _skill_label: Label
var _skill_tween: Tween
var _shown_ratio := 1.0 # the fill drawn
var _trail := 1.0 # the pale chunk behind it
var _trail_wait := 0.0
var _pop := 0.0 # the bar's flash as the shield goes on / off
var _rise_from := -1.0 # a heal: the fill it rises from (-1 none)
var _rise := 0.0 # 0..1 through the rise
var _pop_color := SHIELD
var _t := 0.0


func _ready() -> void:
	name = "BossHud"
	mouse_filter = MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 8)
	_panel = PanelContainer.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", LobbyUi.box(NAVY, 20, 10, Color(1, 1, 1, 0.18), 2))
	add_child(_panel)
	var row := Ui.hbox(12)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_art = BossArtView.make(BossArt.GENERIC_BOSS, Vector2(70, 70), 1, "bust") # the drawn bust, else the figure
	row.add_child(_art)
	var col := Ui.vbox(4)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(col)
	var top := Ui.hbox(10)
	top.mouse_filter = MOUSE_FILTER_IGNORE
	col.add_child(top)
	_element = ElementBadge.make("", 30)
	_element.name = "ElementBadge"
	top.add_child(_element)
	_name = LobbyUi.text("", 28, Color.WHITE, true)
	_name.size_flags_horizontal = SIZE_EXPAND_FILL
	_name.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_child(_name)
	_round = LobbyUi.text("", 22, LobbyUi.GOLD, true)
	_round.name = "Round"
	_round.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_child(_round)
	_bar = Control.new()
	_bar.name = "BossBar"
	_bar.custom_minimum_size = BAR
	_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	col.add_child(_bar)
	_hp = LobbyUi.text("", 20, Color.WHITE, true)
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_hp.mouse_filter = MOUSE_FILTER_IGNORE
	_bar.add_child(_hp)
	var centre := CenterContainer.new()
	centre.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(centre)
	_skill = PanelContainer.new()
	_skill.name = "SkillBanner"
	_skill.mouse_filter = MOUSE_FILTER_IGNORE
	var box := LobbyUi.box(Color(0.42, 0.06, 0.12, 0.92), 22, 8, Color(1.0, 0.62, 0.3, 0.95), 3)
	box.content_margin_left = 30
	box.content_margin_right = 30
	_skill.add_theme_stylebox_override("panel", box)
	_skill.modulate.a = 0.0
	centre.add_child(_skill)
	_skill_label = LobbyUi.text("", 30, Color(1.0, 0.92, 0.8), true)
	_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_label.mouse_filter = MOUSE_FILTER_IGNORE
	_skill.add_child(_skill_label)
	visible = false


## Shows BossHudModel.state(); {} or inactive hides it.
func set_state(s: Dictionary) -> void:
	var was_shielded := bool(_state.get("shielded", false))
	var was_armored := bool(_state.get("armored", false))
	var first := _state.is_empty() or str(_state.get("boss_id", "")) != str(s.get("boss_id", ""))
	_state = s.duplicate()
	visible = bool(s.get("active", false))
	if not visible:
		return
	var art := BossArt.art_of(str(s.get("boss_id", "")))
	_art.art = art
	_name.text = str(s.get("name", ""))
	_element.element_id = GameData.boss_element(str(s.get("boss_id", "")))
	_element.visible = _element.element_id != ""
	_name.add_theme_color_override("font_color", BossArt.accent(art).lightened(0.25))
	_round.text = str(s.get("round_text", ""))
	_hp.text = str(s.get("hp_text", ""))
	var ratio := float(s.get("ratio", 1.0))
	if first:
		_shown_ratio = ratio
		_trail = ratio
	elif ratio < _shown_ratio:
		_trail = maxf(_trail, drawn_ratio())
		_trail_wait = 0.35
		_rise_from = -1.0
	elif ratio > _shown_ratio + 0.0001: # a heal: the fill rises from where it is drawn
		_rise_from = drawn_ratio()
		_rise = 0.0
		_trail = minf(_trail, ratio)
	_shown_ratio = ratio
	if bool(s.get("shielded", false)) != was_shielded and not first:
		_pop = 1.0
		_pop_color = SHIELD
	if bool(s.get("armored", false)) != was_armored and not first:
		_pop = 1.0
		_pop_color = RUNE
	_bar.queue_redraw()


## The state shown ({} none).
func state() -> Dictionary:
	return _state


## The boss's skill name under the bar: pops in, holds, fades.
## The skill's name goes now (fast): a map-wide skill's replay frames the whole map, its top
## under the name.
func fade_skill() -> void:
	if _skill_tween:
		_skill_tween.kill()
	if not is_inside_tree() or _skill.modulate.a <= 0.0:
		_skill.modulate.a = 0.0
		return
	_skill_tween = create_tween()
	_skill_tween.tween_property(_skill, "modulate:a", 0.0, 0.25)


func announce_skill(text: String) -> void:
	if text == "":
		return
	_skill_label.text = text
	if _skill_tween:
		_skill_tween.kill()
	if not is_inside_tree():
		_skill.modulate.a = 1.0
		return
	_skill.pivot_offset = _skill.size / 2.0
	_skill.scale = Vector2.ONE * 0.6
	_skill.modulate.a = 1.0
	_skill_tween = create_tween()
	_skill_tween.tween_property(_skill, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_skill_tween.tween_interval(SKILL_SEC)
	_skill_tween.tween_property(_skill, "modulate:a", 0.0, 0.4)


## The skill name shown ("" none).
func skill_text() -> String:
	return _skill_label.text if _skill.modulate.a > 0.01 else ""


## The fill drawn now (0..1): a heal's rise eases up to the HP.
func drawn_ratio() -> float:
	if _rise_from < 0.0:
		return _shown_ratio
	var e := 1.0 - pow(1.0 - clampf(_rise, 0.0, 1.0), 3.0)
	return lerpf(_rise_from, _shown_ratio, e)


## A heal's rise is under way (tests).
func rising() -> bool:
	return _rise_from >= 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _rise_from >= 0.0:
		_rise += delta / RISE_SEC
		if _rise >= 1.0 + 0.5: # the green glow lingers a little after it is full
			_rise_from = -1.0
	_pop = maxf(0.0, _pop - delta * 2.0)
	if _trail > _shown_ratio:
		_trail_wait -= delta
		if _trail_wait <= 0.0:
			_trail = maxf(_shown_ratio, _trail - delta / TRAIL_SEC)
	_bar.queue_redraw()


func _draw_bar() -> void:
	var s := _bar.size
	var shielded := bool(_state.get("shielded", false))
	var r := Rect2(Vector2.ZERO, s)
	_bar.draw_style_box(LobbyUi.box(Color(0.02, 0.02, 0.06, 0.92), 9, 0, Color(1, 1, 1, 0.25), 2), r)
	var inner := r.grow(-3.0)
	if _trail > _shown_ratio:
		_bar.draw_rect(Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), Color(1.0, 0.92, 0.8, 0.8))
	var armored := bool(_state.get("armored", false))
	var fill := Rect2(inner.position, Vector2(inner.size.x * drawn_ratio(), inner.size.y))
	if fill.size.x > 0.0:
		var top := ORANGE.lerp(SHIELD, 0.75) if shielded else (ORANGE.lerp(STONE_TOP, 0.7) if armored else ORANGE)
		var bottom := RED.lerp(Color(0.2, 0.45, 0.9), 0.75) if shielded else (RED.lerp(STONE_BOTTOM, 0.7) if armored else RED)
		_bar.draw_polygon(PackedVector2Array([fill.position, Vector2(fill.end.x, fill.position.y), fill.end, Vector2(fill.position.x, fill.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))
		_bar.draw_rect(Rect2(fill.position, Vector2(fill.size.x, 3)), Color(1, 1, 1, 0.35))
		if shielded: # moving hex-ish stripes
			var x := fill.position.x - fmod(_t * 30.0, 18.0)
			while x < fill.end.x:
				var a := Vector2(maxf(x, fill.position.x), fill.position.y)
				var b := Vector2(minf(x + 9.0, fill.end.x), fill.end.y)
				if b.x > a.x:
					_bar.draw_line(a, b, Color(1, 1, 1, 0.22), 3.0, true)
				x += 18.0
		elif armored: # amber rune marks moving along the stone
			var x := fill.position.x + fmod(_t * 22.0, 46.0)
			var cy := fill.position.y + fill.size.y * 0.5
			while x < fill.end.x - 4.0:
				var s2 := 5.0 + 1.5 * sin(_t * 4.0 + x * 0.1)
				_bar.draw_colored_polygon(PackedVector2Array([Vector2(x, cy - s2), Vector2(x + s2 * 0.7, cy), Vector2(x, cy + s2),
					Vector2(x - s2 * 0.7, cy)]), Color(RUNE, 0.75))
				x += 46.0
	if _rise_from >= 0.0: # the part a heal regained, glowing green
		var from_x := inner.size.x * _rise_from
		var glow := clampf(1.5 - _rise, 0.0, 1.0)
		var w := fill.size.x - from_x
		if w > 0.5:
			_bar.draw_rect(Rect2(inner.position + Vector2(from_x, 0), Vector2(w, inner.size.y)), Color(HEAL, 0.75 * glow))
			_bar.draw_rect(Rect2(inner.position + Vector2(from_x, 0), Vector2(w, 3)), Color(1, 1, 1, 0.5 * glow))
	if _pop > 0.0:
		_bar.draw_style_box(LobbyUi.box(Color(_pop_color, 0.45 * _pop), 9, 0, Color(1, 1, 1, 0.8 * _pop), 2), r)
