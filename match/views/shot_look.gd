extends RefCounted
## How a shot looks, from the shooter's GUN (visuals only: the path, timing, crater and damage
## come from the server). style_for() picks {kind, tier, skill, item}; projectile_view.gd and
## explosion_fx.gd draw it from the two tables here:
## - KINDS (gun kind = the bullet's silhouette and the impact's theme): its own images in
##   assets/fx/<kind>/ (projectile, trail particle, impact frames) and how they move;
## - TIERS (gun tier = intensity): colours (the guns' tier palettes, tools/art/weapon_painter.gd),
##   sizes, particle counts and which shared overlays of assets/fx/tiers/ join in. Every tier
##   works with every kind, so 5 kinds × 9 tiers need no image set of their own.
## Particle counts stay capped (MAX_IMPACT_PARTICLES per impact, MAX_TRAIL_PARTICLES live per
## projectile); both views free themselves.

const EquipmentModel := preload("res://screens/home/equipment_model.gd")

const MAX_IMPACT_PARTICLES := 120
const MAX_TRAIL_PARTICLES := 48
## Of those, the kind's own trail particles and the tier's overlay particles (oldest dropped).
const TRAIL_KIND_CAP := 30
const TRAIL_TIER_CAP := 18
const DEFAULT_KIND := "bazooka"
const DEFAULT_TIER := "basic"
## A skill shot: the projectile drawn this much larger, a brighter glow, a bigger impact with
## more particles (still capped).
const SKILL_SCALE := 1.3
const SKILL_GLOW := 0.45
const SKILL_IMPACT := 1.1
const SKILL_PARTICLES := 1.25

const DIRT := [Color(0.42, 0.28, 0.16), Color(0.3, 0.2, 0.12), Color(0.36, 0.6, 0.25)]

## gun kind -> look.
## color: the kind's own accent (basic tier; the tiers blend their colour into it);
## line / line_width: the line trail (null: none); trail: trail particles (assets/fx/<kind>/trail.png,
##   one every `every` world px, life s, size start/end world px, alpha, drift down px/s, jitter
##   sideways px, spin rad/s; tint: particles take the accent colour by this much);
## spin: the projectile turns (rad/s); fuse: the bomb's fuse spark; flicker: the projectile pulses;
## body_tint: how much the projectile itself takes the accent colour (0: its own colours; the
##   blaster bolt is drawn white and takes it fully);
## impact: scale of the burst frames, smoke puffs and colour, bits (count, speed, size, gravity
##   factor, colours, image: "debris" or "trail" = the kind's trail particle), frame_tint.
const KINDS := {
	"bazooka": {"color": Color(1.0, 0.72, 0.32), "line": Color(1.0, 0.85, 0.55), "line_width": 6.0,
		"trail": {"every": 13.0, "life": 0.35, "size": [5.0, 11.0], "alpha": 0.55, "drift": -16.0, "jitter": 2.0, "spin": 1.5, "tint": 0.3},
		"spin": 0.0, "fuse": true, "flicker": false, "body_tint": 0.0,
		"impact": {"scale": 1.0, "smoke": 7, "smoke_color": Color(0.55, 0.52, 0.55, 0.85), "bits": 12,
			"speed": [180.0, 420.0], "bit_size": [2.0, 4.0], "gravity": 1.0, "colors": DIRT, "bit_image": "debris"}},
	"cannon": {"color": Color(1.0, 0.6, 0.25), "line": Color(0.75, 0.74, 0.76), "line_width": 4.0,
		"trail": {"every": 7.0, "life": 0.45, "size": [9.0, 20.0], "alpha": 0.7, "drift": -18.0, "jitter": 0.0, "spin": 0.0, "tint": 0.15},
		"spin": 0.0, "fuse": false, "flicker": false, "body_tint": 0.0,
		"impact": {"scale": 1.2, "smoke": 11, "smoke_color": Color(0.38, 0.36, 0.38, 0.9), "bits": 24,
			"speed": [220.0, 520.0], "bit_size": [2.5, 5.0], "gravity": 1.0, "colors": DIRT, "bit_image": "debris"}},
	"shock_rifle": {"color": Color(0.55, 0.95, 1.0), "line": Color(0.55, 0.95, 1.0), "line_width": 7.0,
		"trail": {"every": 6.0, "life": 0.3, "size": [9.0, 3.0], "alpha": 1.0, "drift": 0.0, "jitter": 9.0, "spin": 0.0, "tint": 0.6},
		"spin": 0.0, "fuse": false, "flicker": true, "body_tint": 0.0,
		"impact": {"scale": 1.0, "smoke": 2, "smoke_color": Color(0.55, 0.8, 0.95, 0.5), "bits": 16,
			"speed": [200.0, 480.0], "bit_size": [3.0, 5.0], "gravity": 0.25,
			"colors": [Color(1.0, 1.0, 0.7), Color(0.6, 0.95, 1.0)], "bit_image": "trail"}},
	"seed_launcher": {"color": Color(0.6, 1.0, 0.5), "line": null, "line_width": 0.0,
		"trail": {"every": 8.0, "life": 0.6, "size": [8.0, 6.0], "alpha": 0.95, "drift": 22.0, "jitter": 6.0, "spin": 9.0, "tint": 0.2},
		"spin": 9.0, "fuse": false, "flicker": false, "body_tint": 0.0,
		"impact": {"scale": 1.0, "smoke": 3, "smoke_color": Color(0.6, 0.85, 0.55, 0.55), "bits": 16,
			"speed": [140.0, 360.0], "bit_size": [4.0, 6.0], "gravity": 0.35,
			"colors": [Color(1, 1, 1), Color(0.65, 1.0, 0.6), Color(1.0, 0.9, 0.6)], "bit_image": "trail"}},
	"blaster": {"color": Color(1.0, 0.42, 0.5), "line": Color(1.0, 0.6, 0.65), "line_width": 5.0,
		"trail": {"every": 7.0, "life": 0.28, "size": [7.0, 2.0], "alpha": 0.9, "drift": 0.0, "jitter": 4.0, "spin": 0.0, "tint": 1.0},
		"spin": 0.0, "fuse": false, "flicker": true, "body_tint": 1.0,
		"impact": {"scale": 1.0, "smoke": 2, "smoke_color": Color(0.8, 0.7, 0.85, 0.45), "bits": 14,
			"speed": [200.0, 460.0], "bit_size": [3.0, 5.0], "gravity": 0.3,
			"colors": [Color(1, 1, 1), Color(1.0, 0.85, 0.9)], "bit_image": "trail", "frame_tint": 1.0}},
}

## gun tier -> intensity, escalating with rank (basic and iron plain ... diamond grandest).
## color / color2: the tier's colours (from its gun palette; null = the kind's own) and mix, how
## much color replaces the kind's accent in the trail, glow and burst;
## scale: projectile size; glow: halo behind the projectile (0..1); line: line trail width factor;
## trail_fx: extra trail particles from an overlay (assets/fx/tiers/<tex>.png) with `every`,
##   life, size, gravity-ish drift, jitter, spin; prismatic: colours cycle through the rainbow;
## impact: burst scale (visual only), flash (the glow burst 0..1), rings (shockwaves, 0..2),
##   sparkles / embers / coins / shards (particle counts), bits (factor on the kind's debris),
##   flare (lens-flare burst 0..1), crack (ground-crack decal), screen (screen tint alpha),
##   linger (s the sparkles keep twinkling after the burst).
const TIERS := {
	"basic": {"rank": 0, "color": null, "color2": null, "mix": 0.0, "scale": 1.0, "glow": 0.0, "line": 1.0, "trail_fx": {},
		"prismatic": false, "impact": {"scale": 1.0, "flash": 0.0, "rings": 0, "sparkles": 0, "embers": 0, "coins": 0,
			"shards": 0, "bits": 1.0, "flare": 0.0, "crack": false, "screen": 0.0, "linger": 0.0}},
	"iron": {"rank": 1, "color": Color(0.84, 0.86, 0.9), "color2": Color(0.6, 0.62, 0.66), "mix": 0.1, "scale": 1.0, "glow": 0.0,
		"line": 1.0, "trail_fx": {}, "prismatic": false, "impact": {"scale": 1.0, "flash": 0.0, "rings": 0, "sparkles": 0,
			"embers": 0, "coins": 0, "shards": 0, "bits": 1.0, "flare": 0.0, "crack": false, "screen": 0.0, "linger": 0.0}},
	"steel": {"rank": 2, "color": Color(0.72, 0.84, 0.97), "color2": Color(0.42, 0.58, 0.82), "mix": 0.45, "scale": 1.05, "glow": 0.25,
		"line": 1.3, "trail_fx": {}, "prismatic": false, "impact": {"scale": 1.05, "flash": 0.35, "rings": 0, "sparkles": 0,
			"embers": 0, "coins": 0, "shards": 0, "bits": 1.1, "flare": 0.0, "crack": false, "screen": 0.0, "linger": 0.0}},
	"mithril": {"rank": 3, "color": Color(0.62, 0.96, 0.9), "color2": Color(0.85, 0.96, 1.0), "mix": 0.7, "scale": 1.1, "glow": 0.55,
		"line": 1.4, "trail_fx": {"tex": "sparkle", "every": 9.0, "life": 0.5, "size": [7.0, 2.0], "drift": 0.0, "jitter": 9.0, "spin": 4.0},
		"prismatic": false, "impact": {"scale": 1.12, "flash": 0.55, "rings": 0, "sparkles": 14, "embers": 0, "coins": 0,
			"shards": 0, "bits": 1.1, "flare": 0.0, "crack": false, "screen": 0.0, "linger": 0.0}},
	"dragon": {"rank": 4, "color": Color(1.0, 0.62, 0.28), "color2": Color(1.0, 0.8, 0.22), "mix": 0.85, "scale": 1.15, "glow": 0.7,
		"line": 1.6, "trail_fx": {"tex": "ember", "every": 6.0, "life": 0.55, "size": [8.0, 2.5], "drift": -40.0, "jitter": 7.0, "spin": 2.0},
		"prismatic": false, "impact": {"scale": 1.25, "flash": 0.75, "rings": 1, "sparkles": 6, "embers": 22, "coins": 0,
			"shards": 0, "bits": 1.2, "flare": 0.0, "crack": false, "screen": 0.0, "linger": 0.0}},
	"silver": {"rank": 5, "color": Color(0.98, 0.99, 1.0), "color2": Color(0.52, 0.74, 1.0), "mix": 0.8, "scale": 1.12, "glow": 0.6,
		"line": 1.5, "trail_fx": {"tex": "sparkle", "every": 7.0, "life": 0.55, "size": [9.0, 2.0], "drift": 0.0, "jitter": 10.0, "spin": 5.0},
		"prismatic": false, "impact": {"scale": 1.18, "flash": 0.7, "rings": 1, "sparkles": 20, "embers": 0, "coins": 0,
			"shards": 0, "bits": 1.2, "flare": 0.3, "crack": false, "screen": 0.0, "linger": 0.0}},
	"gold": {"rank": 6, "color": Color(1.0, 0.76, 0.2), "color2": Color(1.0, 0.94, 0.58), "mix": 0.9, "scale": 1.18, "glow": 0.85,
		"line": 1.8, "trail_fx": {"tex": "coin", "every": 10.0, "life": 0.6, "size": [6.0, 4.0], "drift": 60.0, "jitter": 8.0, "spin": 9.0},
		"prismatic": false, "impact": {"scale": 1.3, "flash": 1.0, "rings": 1, "sparkles": 14, "embers": 0, "coins": 18,
			"shards": 0, "bits": 1.2, "flare": 0.6, "crack": false, "screen": 0.08, "linger": 0.0}},
	"titan": {"rank": 7, "color": Color(1.0, 0.56, 0.16), "color2": Color(0.63, 0.61, 0.74), "mix": 0.85, "scale": 1.22, "glow": 0.8,
		"line": 2.1, "trail_fx": {"tex": "ember", "every": 5.0, "life": 0.6, "size": [10.0, 3.0], "drift": -30.0, "jitter": 9.0, "spin": 2.0},
		"prismatic": false, "impact": {"scale": 1.4, "flash": 1.0, "rings": 2, "sparkles": 0, "embers": 26, "coins": 0,
			"shards": 0, "bits": 1.5, "flare": 0.4, "crack": true, "screen": 0.22, "linger": 0.0}},
	"diamond": {"rank": 8, "color": Color(0.55, 0.88, 1.0), "color2": Color(0.9, 0.99, 1.0), "mix": 0.9, "scale": 1.25, "glow": 1.0,
		"line": 2.0, "trail_fx": {"tex": "shard", "every": 6.0, "life": 0.6, "size": [8.0, 3.0], "drift": 10.0, "jitter": 10.0, "spin": 6.0},
		"prismatic": true, "impact": {"scale": 1.45, "flash": 1.0, "rings": 2, "sparkles": 24, "embers": 0, "coins": 0,
			"shards": 18, "bits": 1.2, "flare": 1.0, "crack": false, "screen": 0.15, "linger": 1.2}},
}
## The impact particle groups counted against MAX_IMPACT_PARTICLES.
const PARTICLE_GROUPS := ["smoke", "bits", "sparkles", "embers", "coins", "shards"]


## Who fires, how: the gun the shooter brought (match player dict: weaponItemId, characterId;
## catalog for the weapon's entry; no weapon / a bot → its character's gun, basic), whether it is
## a skill shot, and the item (only for an item shot). Air strikes drop plain bombs.
static func style_for(player: Dictionary, action_mode: String, item_id: String, catalog: Variant = null) -> Dictionary:
	var g := EquipmentModel.player_gun(player, catalog)
	var it := item_id if action_mode == "item" else ""
	var out := {"kind": known_kind(str(g["kind"])), "tier": known_tier(str(g["tier"])), "skill": action_mode == "skill", "item": it}
	if it == "air_strike":
		out["kind"] = DEFAULT_KIND
		out["tier"] = DEFAULT_TIER
	return out


static func known_kind(kind: String) -> String:
	return kind if KINDS.has(kind) else DEFAULT_KIND


static func known_tier(tier: String) -> String:
	return tier if TIERS.has(tier) else DEFAULT_TIER


## The accent colour of kind × tier: the kind's own, blended towards the tier's colour.
static func accent(kind: String, tier: String) -> Color:
	var k: Dictionary = KINDS[known_kind(kind)]
	var t: Dictionary = TIERS[known_tier(tier)]
	var base: Color = k["color"]
	return base if t["color"] == null else base.lerp(t["color"], float(t["mix"]))


## The second colour (sparkles, coins, ring edges): the tier's color2, else the accent lightened.
static func accent2(kind: String, tier: String) -> Color:
	var t: Dictionary = TIERS[known_tier(tier)]
	return t["color2"] if t["color2"] != null else accent(kind, tier).lightened(0.4)


## A rainbow colour for prismatic tiers (h 0..1, wraps).
static func prism(h: float) -> Color:
	return Color.from_hsv(fposmod(h, 1.0), 0.45, 1.0)


## How many particles of each group an impact of kind × tier throws: {smoke, bits, sparkles,
## embers, coins, shards}, more for a skill shot, scaled down together so the total stays within
## MAX_IMPACT_PARTICLES.
static func impact_counts(kind: String, tier: String, skill: bool = false) -> Dictionary:
	var k: Dictionary = KINDS[known_kind(kind)]["impact"]
	var t: Dictionary = TIERS[known_tier(tier)]["impact"]
	var boost := SKILL_PARTICLES if skill else 1.0
	var out := {"smoke": float(k["smoke"]), "bits": float(k["bits"]) * float(t["bits"]) * boost}
	for g in ["sparkles", "embers", "coins", "shards"]:
		out[g] = float(t[g]) * boost
	var total := 0.0
	for g in out:
		total += out[g]
	var fit := minf(1.0, MAX_IMPACT_PARTICLES / total) if total > 0.0 else 1.0
	var counts := {}
	for g in PARTICLE_GROUPS:
		counts[g] = int(floor(out[g] * fit))
	return counts


## The burst scale of kind × tier (the frames are drawn for the crater radius times this).
static func impact_scale(kind: String, tier: String, skill: bool = false) -> float:
	var s := float(KINDS[known_kind(kind)]["impact"]["scale"]) * float(TIERS[known_tier(tier)]["impact"]["scale"])
	return s * (SKILL_IMPACT if skill else 1.0)


## How long an impact of this tier stays on screen (s): the base life plus the lingering sparkles.
static func impact_life(tier: String, base: float) -> float:
	var t: Dictionary = TIERS[known_tier(tier)]["impact"]
	return base + float(t["linger"]) + (0.6 if bool(t["crack"]) else 0.0)
