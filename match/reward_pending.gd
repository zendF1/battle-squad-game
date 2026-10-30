extends HBoxContainer
## The rewards card of a result screen (match/result_screen.gd, match/boss/boss_result_screen.gd)
## while the match's rewards are still on their way (ResultModel.reward()'s pending): an hourglass
## turning over now and then, and ResultModel.PENDING_TEXT, centred in the card (its one focus).
## When PlayerState's watch sees them land (reward_landed), a green tick and
## ResultModel.LANDED_TEXT instead.

const GlyphIcon := preload("res://ui/glyph_icon.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const ResultModel := preload("res://match/result_model.gd")

const TURN_SEC := 0.6
const REST_SEC := 1.4

var glyph: Control
var label: Label
var landed := false
var _px := 44
var _tween: Tween


static func make(px: int = 56, font_size: int = 28) -> HBoxContainer:
	var row = new()
	row._px = px
	row.name = "RewardPending"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.glyph = GlyphIcon.make("hourglass", px)
	row.glyph.name = "Hourglass"
	row.add_child(row.glyph)
	row.label = LobbyUi.text(ResultModel.PENDING_TEXT, font_size, Color.WHITE, true)
	row.label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(row.label)
	return row


func _ready() -> void:
	PlayerState.reward_landed.connect(show_landed)
	if PlayerState.pending_reward_landed:
		show_landed()
	else:
		_turn()


func _exit_tree() -> void:
	if PlayerState.reward_landed.is_connected(show_landed):
		PlayerState.reward_landed.disconnect(show_landed)


## Turns the hourglass over (half a turn further each time, so the sand never jumps), rests, again.
func _turn() -> void:
	glyph.pivot_offset = Vector2(_px, _px) / 2.0
	_tween = create_tween().set_loops()
	_tween.tween_interval(REST_SEC)
	_tween.tween_property(glyph, "rotation", PI, TURN_SEC).as_relative().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)


func show_landed() -> void:
	if landed:
		return
	landed = true
	if _tween != null:
		_tween.kill()
	glyph.rotation = 0.0
	glyph.kind = "check"
	glyph.name = "Landed"
	label.text = ResultModel.LANDED_TEXT
