extends Control
## A character (scenes/character/character.tscn) fitted into this rect, feet at the bottom
## centre over its shadow. `idle` plays the idle animation and adds a gentle hop (the shadow
## shrinks while the body is up). It holds the gun of the weapon that character wears
## (PlayerState owned equipment + catalog, EquipmentModel.worn_gun()): it changes as soon as the
## owned pieces reload after an equip / unequip / move, and a character not owned (or with no
## weapon) holds its basic gun. hands_free: no gun in hand (the lobby stage shows the gun on its
## own under the pedestal). Used by the lobby stage, the Nhân vật page and the Prep panel: the
## character's skinned full-body picture (scenes/character lobby_full, full_body.gd), drawn 1:1
## on the 375x400 stage, which has no gun in hand (holds_gun() false: the screens put the gun
## beside it, screens/home/pedestal_gun.gd) and breathes in place instead of hopping; without
## one the side-view frames (hopping). Order: full.png → frames.
## back_aura (the screens with a loadout: lobby stage, Prep, Nhân vật; not the shop cards): the
## worn weapon's +14 / +16 ring turning behind the figure (scenes/character/back_aura.gd), centred
## on the torso, sized to frame it, behind the body (and whatever the screen draws after this
## view, the pedestal gun), updated with the gun on every equipment change (equip, unequip,
## transfer, upgrade).

const Art := preload("res://ui/art.gd")
const CharacterScene := preload("res://scenes/character/character.tscn")
const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const BackAura := preload("res://scenes/character/back_aura.gd")

## The art box in units the rect is fitted to (the art is about 150 units tall).
const UNITS := Vector2(150, 160)
const HOP := 5.0 # units
## The back aura's centre above the feet and its ring picture's width, as shares of the figure's
## height (the ring's hole sits behind the chest, the ring frames the body).
const AURA_CENTRE := 0.57
const AURA_SIZE := 1.08

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

## The worn weapon's +14 / +16 back aura behind the figure.
@export var back_aura := false:
	set(value):
		back_aura = value
		if is_node_ready():
			_show_worn_gun()
			_layout()

var _character: Node2D
var _aura: BackAura
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_character = CharacterScene.instantiate()
	_character.character_id = character_id
	_character.hands_free = hands_free
	_character.lobby_full = true
	_aura = BackAura.new()
	add_child(_aura) # before the character: drawn behind it
	add_child(_character)
	set_process(idle)
	resized.connect(_layout)
	PlayerState.equipment_changed.connect(_show_worn_gun)
	_show_worn_gun()
	_layout()


## The gun of the weapon the character wears (its basic gun when none or not loaded), and its
## back aura (back_aura on).
func _show_worn_gun() -> void:
	var g := EquipmentModel.worn_gun(PlayerState.equipment, PlayerState.catalog, character_id)
	_character.set_weapon(g["kind"], g["tier"])
	_aura.level = worn_weapon_level(PlayerState.equipment, character_id) if back_aura else 0
	_layout()


## The upgrade level of the weapon the character wears, 0 when none (or not loaded).
static func worn_weapon_level(owned: Variant, id: String) -> int:
	var piece: Dictionary = EquipmentModel.worn(owned, id).get("weapon", {})
	return maxi(0, int(piece.get("upgradeLevel", 0)))


## The back aura node (aura() tells which ring shows).
func aura() -> BackAura:
	return _aura


## The figure's height in this view's px (the full-body picture, else the side-view frames).
func figure_height() -> float:
	var full := Art.lobby_full(_character.character_id) if _character.full() != null else {}
	var h: float = float(full["height"]) * float(full["scale"]) if not full.is_empty() else _character.art_height()
	return h * _character.scale.y


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_layout()


## The character node (play(), shoot() ...).
func character() -> Node2D:
	return _character


## A gun is drawn in the character's hand (false on the full-body picture and hands free).
func holds_gun() -> bool:
	return _character != null and _character.holds_gun()


func _layout() -> void:
	if _character == null:
		return
	var k := minf(size.x / UNITS.x, size.y / UNITS.y)
	var hop := HOP if _character.full() == null else 0.0 # the full-body picture breathes, feet planted
	var lift := (sin(_t * 2.4) * 0.5 + 0.5) * hop if idle else 0.0
	var feet := Vector2(size.x / 2, size.y - 8 * k)
	_character.scale = Vector2.ONE * (k / Art.PX_PER_UNIT)
	_character.position = feet - Vector2(0, lift * k)
	if _aura.aura() != "":
		var h := figure_height()
		_aura.position = _character.position - Vector2(0, h * AURA_CENTRE)
		if not is_equal_approx(_aura.diameter, h * AURA_SIZE):
			_aura.diameter = h * AURA_SIZE
	var shadow: Sprite2D = _character.shadow()
	shadow.position = Vector2(0, lift * Art.PX_PER_UNIT) # stays on the ground
	shadow.scale = Vector2.ONE * (1.0 - lift * 0.03)
	if not idle:
		_character.play("idle")
		_character.get_node("Flip/Sprite").stop()
