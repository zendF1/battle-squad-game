extends RefCounted
## What a unit's status effects look like on its body (match/views/status_fx.gd draws it, one
## per PlayerView; no icons beside the HP bar): each active effect (match/status_effects.gd
## active()) maps to one look, drawn on the figure:
## - "ice" (freeze): the body frozen inside a cluster of faceted crystals grown from the ground at
##   its feet (a tall see-through one over the body, smaller ones fanned round its base, behind
##   and in front), a cool glow, sparkles and frost; popping out it cracks and sheds fragments;
## - "flames" (burn): small flames licking up the body, embers rising off it;
## - "web" (net): a web wrapped over the body;
## - "vines" (root): vines and roots wound round the feet;
## - "stars" (stun): stars circling the head;
## - "aura": a good effect (an armed shot item: power_shot, drill_bomb, spider_net, freeze_bomb,
##   air_strike; wind_stop): a soft glow round the body in the effect's colour (AURA_COLORS; the
##   colours of several mixed); a bad effect with no look of its own (one the game data adds)
##   shows as a dull violet aura (CURSE).
## The shield keeps its own bubble (match/views/shield_ball.gd). Each look pops in over POP_IN s
## when its effect starts and pops out over pop_out_sec() s when it ends (set_effects(), clear()
## on death); step() moves them on. Looks stack in ORDER, back to front. Pure: no nodes.

const Status := preload("res://match/status_effects.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const POP_IN := 0.28
const POP_OUT := 0.22
## A look that takes longer to leave (s): the ice cracks, then its fragments fall.
const POP_OUT_OF := {"ice": 0.55}
## The look of an effect with its own picture on the body.
const LOOKS := {"freeze": "ice", "burn": "flames", "net": "web", "root": "vines", "stun": "stars"}
## Back to front: the aura behind the body, the vines at its feet, the flames on it, the web over
## it, the ice crystals over everything on the body, the stars round the head.
const ORDER := ["aura", "vines", "flames", "web", "ice", "stars"]
## A good effect's aura colour (DEFAULT_AURA for one not listed).
const AURA_COLORS := {
	"power_shot": Color(1.0, 0.42, 0.18),
	"drill_bomb": Color(1.0, 0.78, 0.3),
	"spider_net": Color(0.86, 0.86, 0.96),
	"freeze_bomb": Color(0.45, 0.85, 1.0),
	"air_strike": Color(1.0, 0.3, 0.32),
	"wind_stop": Color(0.55, 1.0, 0.78),
}
const DEFAULT_AURA := Color(1.0, 0.86, 0.4)
const CURSE := Color(0.62, 0.4, 0.86)

## look -> {k: 0..1 shown, dir: +1 popping in / shown, -1 popping out, color}
var _layers := {}


## The look an effect id is drawn with: LOOKS, else "aura".
static func look_of(effect_id: String) -> String:
	return LOOKS.get(effect_id, "aura")


## The aura colour of an effect: its own for a good one, CURSE for a bad one without a look.
static func aura_color(effect_id: String) -> Color:
	if GameData.status_bad(effect_id):
		return CURSE
	return AURA_COLORS.get(effect_id, DEFAULT_AURA)


## The looks of a statusEffects list, in ORDER: {look: aura colour (white for the others)}.
static func looks_of(effects: Variant) -> Dictionary:
	var auras: Array = []
	var on := {}
	for id in Status.active(effects):
		var look := look_of(str(id))
		if look == "aura":
			auras.append(aura_color(str(id)))
		on[look] = Color.WHITE
	if not auras.is_empty():
		var c := Color(0, 0, 0, 0)
		for a in auras:
			c += a
		on["aura"] = c / float(auras.size())
	var out := {}
	for look in ORDER:
		if on.has(look):
			out[look] = on[look]
	return out


## Takes the unit's effects now: new looks pop in, looks whose effect ended pop out.
func set_effects(effects: Variant) -> void:
	var want := looks_of(effects)
	for look in want:
		var l: Dictionary = _layers.get(look, {"k": 0.0, "dir": 1, "color": want[look]})
		l["dir"] = 1
		l["color"] = want[look]
		_layers[look] = l
	for look in _layers:
		if not want.has(look):
			_layers[look]["dir"] = -1


## Every look pops out (the unit died).
func clear() -> void:
	set_effects([])


## Moves the pops on by dt seconds; a look fully popped out is dropped.
func step(dt: float) -> void:
	for look in _layers.keys():
		var l: Dictionary = _layers[look]
		if int(l["dir"]) > 0:
			l["k"] = minf(1.0, float(l["k"]) + dt / POP_IN)
		else:
			l["k"] = maxf(0.0, float(l["k"]) - dt / pop_out_sec(look))
			if float(l["k"]) <= 0.0:
				_layers.erase(look)


## The looks drawn now, back to front: [{look, k, popping_out, scale, alpha, color}].
func layers() -> Array:
	var out: Array = []
	for look in ORDER:
		if not _layers.has(look):
			continue
		var l: Dictionary = _layers[look]
		var k := float(l["k"])
		var leaving := int(l["dir"]) < 0
		out.append({"look": look, "k": k, "popping_out": leaving, "scale": pop_scale(k, leaving),
			"alpha": pop_alpha(k, leaving), "color": l["color"]})
	return out


## The looks drawn now (popping in, shown or popping out), back to front.
func looks() -> Array:
	return layers().map(func(l): return l["look"])


## The look is drawn (shown or popping in / out).
func has(look: String) -> bool:
	return _layers.has(look)


## The look is fully shown (popped in, not leaving).
func shown(look: String) -> bool:
	return _layers.has(look) and float(_layers[look]["k"]) >= 1.0 and int(_layers[look]["dir"]) > 0


## Nothing to draw.
func is_empty() -> bool:
	return _layers.is_empty()


## Still popping in or out (the drawing needs the frames).
func animating() -> bool:
	for look in _layers:
		var l: Dictionary = _layers[look]
		if int(l["dir"]) < 0 or float(l["k"]) < 1.0:
			return true
	return false


## How long a look takes to pop out (s): POP_OUT_OF, else POP_OUT.
static func pop_out_sec(look: String) -> float:
	return float(POP_OUT_OF.get(look, POP_OUT))


## The size a look is drawn at through its pop: in, it overshoots a little and settles (ease out
## back from 0.4); out, it swells slightly as it fades.
static func pop_scale(k: float, leaving: bool) -> float:
	k = clampf(k, 0.0, 1.0)
	if leaving:
		return 1.0 + (1.0 - k) * 0.18
	var c1 := 1.9
	var c3 := c1 + 1.0
	var e := 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)
	return lerpf(0.4, 1.0, e)


static func pop_alpha(k: float, leaving: bool) -> float:
	k = clampf(k, 0.0, 1.0)
	return k if leaving else minf(1.0, k * 2.5)
