extends Button
## A character's skill as a round picture button: the skill's own code-drawn picture on its disc
## (match/views/skill_glyphs.gd; the generic "skill" icon for a skill without one), its colour as
## the rim. A tap opens the skill's popup (show_popup(): name and description, the game data's).

const Art := preload("res://ui/art.gd")
const Ui := preload("res://ui/ui.gd")
const LobbyUi := preload("res://ui/lobby_ui.gd")
const Modal := preload("res://ui/modal.gd")
const Skills := preload("res://match/skills.gd")
const SkillGlyphs := preload("res://match/views/skill_glyphs.gd")

const OUTLINE := Color(0.07, 0.07, 0.14)

var skill_id := "":
	set(v):
		skill_id = v
		queue_redraw()


## A `px` round skill button.
static func make(px: int = 64) -> Button:
	var b = new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = FOCUS_NONE
	b.flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	return b


func _draw() -> void:
	var c := size / 2.0
	var r := minf(c.x, c.y) - 2.0
	draw_skill(self, skill_id, c, r, 0.8 if is_pressed() else 1.0)


## The disc with the skill's picture, radius r centred at c on ci.
static func draw_skill(ci: CanvasItem, id: String, c: Vector2, r: float, light: float = 1.0) -> void:
	ci.draw_circle(c, r, OUTLINE, true, -1.0, true)
	ci.draw_circle(c, r - 3.0, SkillGlyphs.color(id) * light, true, -1.0, true)
	ci.draw_circle(c, r - 6.0, SkillGlyphs.disc(id) * light, true, -1.0, true)
	if SkillGlyphs.has(id):
		SkillGlyphs.draw(ci, id, c, (r - 6.0) * 1.35)
	else:
		var tex := Art.icon("skill")
		var side := (r - 6.0) * 1.3
		ci.draw_texture_rect(tex, Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side)), false)


## The skill popup of `character_id`'s skill: its picture big, its name as the title, its
## description (the game data's numbers at gun rank `rank`); closed by its X or a tap outside.
static func show_popup(host: Node, character_id: String, rank: int = 0) -> Modal:
	var skill := Skills.for_character(character_id)
	var m := Modal.new()
	m.open(host, str(skill.get("name", "")), 620)
	m.title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_close_x()
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(112, 112)
	pic.size_flags_horizontal = SIZE_SHRINK_CENTER
	var id := str(skill.get("id", ""))
	pic.draw.connect(func() -> void: draw_skill(pic, id, pic.size / 2.0, 54.0))
	m.body.add_child(pic)
	var text := m.add_text(Skills.describe(character_id, rank), 24)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return m
