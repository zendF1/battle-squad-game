extends Control
## A character (scenes/character/character.tscn) fitted into this rect, feet at the bottom
## centre over its shadow. `idle` plays the idle animation and adds a gentle hop (the shadow
## shrinks while the body is up). It holds the gun of the weapon that character wears
## (PlayerState owned equipment + catalog, EquipmentModel.worn_gun()): it changes as soon as the
## owned pieces reload after an equip / unequip / move, and a character not owned (or with no
## weapon) holds its basic gun. hands_free: no gun in hand (the lobby stage shows the gun on its
## own under the pedestal), the free pose instead. Used by the lobby stage, the Nhân vật page and
## the Prep panel: the character's lobby (front-view) rig when it has one (scenes/character
## lobby_rig), drawn 1:1 on the 375x400 stage.

const Art := preload("res://ui/art.gd")
const CharacterScene := preload("res://scenes/character/character.tscn")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")

## The art box in units the rect is fitted to (the art is about 150 units tall).
const UNITS := Vector2(150, 160)
const HOP := 5.0 # units

@export var character_id := Art.DEFAULT_CHARACTER:
	set(value):
		character_id = value
		if _character != null:
			_character.character_id = value
			_show_worn_gun()

## No gun in hand (scenes/character hands_free).
@export var hands_free := false:
	set(value):
		hands_free = value
		if _character != null:
			_character.hands_free = value

## Plays the idle animation and hops (otherwise stands still on its first frame).
@export var idle := false:
	set(value):
		idle = value
		set_process(value)
		_layout()

var _character: Node2D
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_character = CharacterScene.instantiate()
	_character.character_id = character_id
	_character.hands_free = hands_free
	_character.lobby_rig = true
	add_child(_character)
	set_process(idle)
	resized.connect(_layout)
	PlayerState.equipment_changed.connect(_show_worn_gun)
	_show_worn_gun()
	_layout()


## The gun of the weapon the character wears (its basic gun when none or not loaded).
func _show_worn_gun() -> void:
	var g := EquipmentModel.worn_gun(PlayerState.equipment, PlayerState.catalog, character_id)
	_character.set_weapon(g["kind"], g["tier"])


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_layout()


## The character node (play(), shoot() ...).
func character() -> Node2D:
	return _character


func _layout() -> void:
	if _character == null:
		return
	var k := minf(size.x / UNITS.x, size.y / UNITS.y)
	var lift := (sin(_t * 2.4) * 0.5 + 0.5) * HOP if idle else 0.0
	var feet := Vector2(size.x / 2, size.y - 8 * k)
	_character.scale = Vector2.ONE * (k / Art.PX_PER_UNIT)
	_character.position = feet - Vector2(0, lift * k)
	var shadow: Sprite2D = _character.shadow()
	shadow.position = Vector2(0, lift * Art.PX_PER_UNIT) # stays on the ground
	shadow.scale = Vector2.ONE * (1.0 - lift * 0.03)
	if not idle:
		_character.play("idle")
		_character.get_node("Flip/Sprite").stop()
