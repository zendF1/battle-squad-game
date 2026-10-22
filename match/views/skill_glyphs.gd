extends RefCounted
## A small code-drawn picture per skill effect type (there is no skill icon file; the HUD's skill
## slot shows the generic "skill" icon), for the use badge over a player (use_badge.gd). A skill
## id is looked up in the game data (its effectType):
## - missile_rain (Mưa tên lửa): three missiles diving with flame tails;
## - bomb_chain (Bom liên hoàn): two round bombs in a row, the front one's fuse lit;
## - laser (Tia laze): a straight beam with a bright core from an emitter to a flash;
## - bloom (Hoa hồi xuân): a five-petal flower with a gold heart.
## A skill of another (or no) effect type draws the generic "skill" icon. Each type also has a
## colour (the badge's rim and its name) and a disc the picture sits on (disc()).

const Art := preload("res://ui/art.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const TYPES := ["missile_rain", "bomb_chain", "laser", "bloom"]
const COLORS := {
	"missile_rain": Color(1.0, 0.55, 0.2),
	"bomb_chain": Color(1.0, 0.72, 0.25),
	"laser": Color(0.45, 0.9, 1.0),
	"bloom": Color(0.5, 0.95, 0.5),
}
const DEFAULT_COLOR := Color(1.0, 0.84, 0.35)
const DISCS := {
	"missile_rain": Color(0.5, 0.16, 0.1),
	"bomb_chain": Color(0.95, 0.6, 0.22),
	"laser": Color(0.08, 0.2, 0.42),
	"bloom": Color(0.18, 0.42, 0.24),
}
const DEFAULT_DISC := Color(0.25, 0.22, 0.1)


## The effect type whose picture a skill gets ("" none).
static func type_of(skill_id: String) -> String:
	var t := GameData.skill_effect_type(skill_id)
	return t if TYPES.has(t) else ""


static func color(skill_id: String) -> Color:
	return COLORS.get(type_of(skill_id), DEFAULT_COLOR)


## The round backdrop under the picture: dark where the picture is bright, bright under the bombs.
static func disc(skill_id: String) -> Color:
	return DISCS.get(type_of(skill_id), DEFAULT_DISC)


static func has(skill_id: String) -> bool:
	return type_of(skill_id) != ""


## Draws skill_id's picture in a square of side size centred at c on ci.
static func draw(ci: CanvasItem, skill_id: String, c: Vector2, size: float) -> void:
	var k := size / 2.0
	match type_of(skill_id):
		"missile_rain": _rain(ci, c, k)
		"bomb_chain": _bombs(ci, c, k)
		"laser": _laser(ci, c, k)
		"bloom": _bloom(ci, c, k)
		_:
			var tex := Art.icon("skill")
			ci.draw_texture_rect(tex, Rect2(c - Vector2(k, k), Vector2(size, size)), false)


## One missile at p diving along dir (unit), length l.
static func _missile(ci: CanvasItem, p: Vector2, dir: Vector2, l: float) -> void:
	var side := dir.orthogonal()
	var w := l * 0.2 # half width
	var tail := p - dir * l * 0.35
	ci.draw_line(tail, tail - dir * l * 0.5, Color(1.0, 0.55, 0.12, 0.9), w * 1.9, true)
	ci.draw_line(tail, tail - dir * l * 0.3, Color(1.0, 0.95, 0.6), w * 0.9, true)
	var body := PackedVector2Array([p + dir * l * 0.5, p + dir * l * 0.22 + side * w,
		tail + side * w, tail - side * w, p + dir * l * 0.22 - side * w])
	ci.draw_colored_polygon(body, Color(0.95, 0.96, 1.0))
	ci.draw_colored_polygon(PackedVector2Array([p + dir * l * 0.5, p + dir * l * 0.22 + side * w,
		p + dir * l * 0.22 - side * w]), Color(1.0, 0.3, 0.22))


static func _rain(ci: CanvasItem, c: Vector2, k: float) -> void:
	var dir := Vector2(-0.35, 1.0).normalized() # diving down-left, like the rain
	_missile(ci, c + Vector2(-0.52, -0.05) * k, dir, k * 1.05)
	_missile(ci, c + Vector2(0.08, -0.3) * k, dir, k * 1.05)
	_missile(ci, c + Vector2(0.6, 0.12) * k, dir, k * 1.05)


static func _bomb(ci: CanvasItem, p: Vector2, r: float, lit: bool) -> void:
	ci.draw_circle(p, r, Color(0.1, 0.1, 0.14))
	ci.draw_circle(p, r * 0.86, Color(0.2, 0.21, 0.27))
	ci.draw_circle(p + Vector2(-0.38, -0.38) * r, r * 0.26, Color(0.75, 0.78, 0.88))
	var dir := Vector2(0.6, -0.8)
	var cap := p + dir * r * 0.92
	ci.draw_line(p + dir * r * 0.7, cap + dir * r * 0.12, Color(0.45, 0.47, 0.55), r * 0.36, true)
	if lit:
		var tip := cap + Vector2(0.42, -0.32) * r
		ci.draw_line(cap, tip, Color(0.85, 0.7, 0.45), maxf(1.5, r * 0.13), true)
		ci.draw_circle(tip, r * 0.3, Color(1.0, 0.5, 0.1))
		ci.draw_circle(tip, r * 0.15, Color(1.0, 1.0, 0.8))


static func _bombs(ci: CanvasItem, c: Vector2, k: float) -> void:
	_bomb(ci, c + Vector2(-0.5, 0.32) * k, k * 0.4, false)
	_bomb(ci, c + Vector2(0.05, 0.16) * k, k * 0.6, true)


static func _laser(ci: CanvasItem, c: Vector2, k: float) -> void:
	var a := c + Vector2(-0.8, 0.5) * k
	var b := c + Vector2(0.85, -0.5) * k
	ci.draw_line(a, b, Color(0.3, 0.8, 1.0, 0.5), k * 0.7, true)
	ci.draw_line(a, b, Color(0.55, 0.95, 1.0), k * 0.36, true)
	ci.draw_line(a, b, Color(0.97, 1.0, 1.0), k * 0.14, true)
	ci.draw_circle(a, k * 0.3, Color(0.8, 0.9, 1.0))
	ci.draw_circle(a, k * 0.14, Color(0.2, 0.5, 0.9))
	var flash := PackedVector2Array()
	for i in 8:
		var ang := TAU * i / 8.0
		flash.append(b + Vector2(cos(ang), sin(ang)) * k * (0.42 if i % 2 == 0 else 0.18))
	ci.draw_colored_polygon(flash, Color(1.0, 1.0, 0.85))


static func _bloom(ci: CanvasItem, c: Vector2, k: float) -> void:
	ci.draw_line(c + Vector2(0.0, 0.3) * k, c + Vector2(0.1, 1.0) * k, Color(0.3, 0.75, 0.3), maxf(1.5, k * 0.14), true)
	for i in 5:
		var a := -PI / 2.0 + TAU * i / 5.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_circle(c + Vector2(0, -0.12) * k + d * k * 0.45, k * 0.36, Color(1.0, 0.55, 0.75))
		ci.draw_circle(c + Vector2(0, -0.12) * k + d * k * 0.5, k * 0.18, Color(1.0, 0.8, 0.9))
	ci.draw_circle(c + Vector2(0, -0.12) * k, k * 0.28, Color(1.0, 0.84, 0.3))
	ci.draw_circle(c + Vector2(-0.08, -0.2) * k, k * 0.1, Color(1.0, 0.97, 0.75))
