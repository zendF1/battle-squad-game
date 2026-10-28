extends Node2D
## A lost turn's countdown drawn in code (match/skip_countdown.gd holds the time): a dark disc, a
## ring that empties clockwise from the top in the effect's colour (freeze ice blue, stun gold),
## the whole seconds left big in the middle and the effect's small glyph over them (a snowflake,
## a star); each new second pops the number. No text but the digit. Used over the frozen unit
## (match_screen, on its PlayerView) and dead centre on the HUD for my own lost turn (hud.gd).
## Origin at the centre; `radius` px.

const LobbyUi := preload("res://ui/lobby_ui.gd")

const COLORS := {"freeze": Color(0.55, 0.88, 1.0), "stun": Color(1.0, 0.84, 0.3)}
const DEFAULT := Color(0.85, 0.75, 1.0)
const DISC := Color(0.04, 0.06, 0.16, 0.86)
const POP_SEC := 0.22

var radius := 30.0
var effect := ""
var number := 0
var fraction := 0.0
var _pop := 1.0 # 0 → 1 after a new second


## Shows the countdown now (number 0 hides it).
func show_time(effect_id: String, n: int, frac: float) -> void:
	if n != number and n > 0:
		_pop = 0.0
	effect = effect_id
	number = n
	fraction = clampf(frac, 0.0, 1.0)
	visible = n > 0
	queue_redraw()


static func color_of(effect_id: String) -> Color:
	return COLORS.get(effect_id, DEFAULT)


func _process(delta: float) -> void:
	if _pop < 1.0:
		_pop = minf(1.0, _pop + delta / POP_SEC)
		queue_redraw()


func _draw() -> void:
	if number <= 0:
		return
	var col := color_of(effect)
	var r := radius
	var w := maxf(r * 0.2, 3.0)
	draw_circle(Vector2.ZERO, r + w * 0.6, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, r, DISC)
	draw_arc(Vector2.ZERO, r - w * 0.5, 0.0, TAU, 48, Color(col, 0.22), w, true)
	if fraction > 0.0:
		var from := -PI / 2.0
		draw_arc(Vector2.ZERO, r - w * 0.5, from, from + TAU * fraction, maxi(8, int(48 * fraction)), col, w, true)
		var tip := Vector2.from_angle(from + TAU * fraction) * (r - w * 0.5)
		draw_circle(tip, w * 0.62, Color(1, 1, 1, 0.9))
	var font := LobbyUi.bold()
	var fs := int(r * 1.05 * (1.0 + 0.35 * (1.0 - _pop)))
	var text := str(number)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var base := Vector2(-size.x / 2.0, r * 0.12 + fs * 0.36)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 7), Color(0.02, 0.03, 0.1, 0.9))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	_glyph(Vector2(0, -r * 0.56), r * 0.2, col)


## The effect's glyph: a snowflake for freeze, a star for stun.
func _glyph(c: Vector2, s: float, col: Color) -> void:
	if effect == "stun":
		var pts := PackedVector2Array()
		for i in 10:
			pts.append(c + Vector2.from_angle(TAU * i / 10.0 - PI / 2.0) * (s if i % 2 == 0 else s * 0.45))
		draw_colored_polygon(pts, col)
		return
	for i in 3:
		var d := Vector2.from_angle(TAU * i / 6.0 + PI / 2.0) * s
		draw_line(c - d, c + d, col, maxf(1.5, s * 0.22), true)
		for sgn in [-1.0, 1.0]:
			var stem: Vector2 = c + d * (0.55 * sgn)
			var out: Vector2 = d * (0.38 * sgn)
			var side := d.orthogonal() * 0.3
			draw_line(stem, stem + out + side, col, maxf(1.2, s * 0.16), true)
			draw_line(stem, stem + out - side, col, maxf(1.2, s * 0.16), true)
