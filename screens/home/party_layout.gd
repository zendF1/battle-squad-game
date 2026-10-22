extends RefCounted
## Where Home puts the teammate slots of a party mode (screens/home/party_slot.gd), without UI: my
## character stays on the centre stage; a party of two (2v2) has one slot right of the stage at
## full slot size, a party of four (a boss) three smaller ones: two right of the stage, one left
## (between the info card and the stage's ◀). Each slot is {x: its centre's offset from the
## screen's centre, y: its bottom's offset from the screen's bottom, scale: of the slot (1 = the
## 2v2 slot, PartySlot.SCALE of the stage), side: -1 left / 1 right}, in the order the teammates
## fill them (the lobby's member order without me).

## The stage's half width (lobby.gd STAGE.x / 2) and the slot's width at scale 1 (PartySlot.SIZE.x).
const STAGE_HALF := 280.0
const SLOT_W := 330.0
## The figure's width in a slot at scale 1 (the character art, its gun): what must not overlap.
const FIGURE_W := 230.0

const ONE := [{"x": STAGE_HALF + 175.0, "y": -240.0, "scale": 1.0, "side": 1}]
const COMPACT := 0.72
const THREE := [
	{"x": STAGE_HALF + 105.0, "y": -232.0, "scale": COMPACT, "side": 1},
	{"x": -(STAGE_HALF + 105.0), "y": -232.0, "scale": COMPACT, "side": -1},
	{"x": STAGE_HALF + 295.0, "y": -232.0, "scale": COMPACT, "side": 1},
]


## The slots of a party of `capacity` (me included): [] solo, ONE for two, THREE for four (a
## party of three uses THREE's first two).
static func slots(capacity: int) -> Array:
	if capacity <= 1:
		return []
	if capacity == 2:
		return ONE.duplicate(true)
	return THREE.slice(0, mini(capacity - 1, THREE.size())).duplicate(true)


## A slot's horizontal span on screen (offsets from the centre) of its figure: [left, right].
static func figure_span(slot: Dictionary) -> Array:
	var half := FIGURE_W * float(slot["scale"]) / 2.0
	return [float(slot["x"]) - half, float(slot["x"]) + half]


## The members shown in the slots: `teammates` (the lobby's members without me) in order, padded
## with {} (an empty "+" slot) to the slot count.
static func fill(teammates: Array, capacity: int) -> Array:
	var n := slots(capacity).size()
	var out: Array = teammates.slice(0, n)
	while out.size() < n:
		out.append({})
	return out
