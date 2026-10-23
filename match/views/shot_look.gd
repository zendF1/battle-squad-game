extends RefCounted
## How a shot looks, from the shooter's GUN (visuals only: the path, timing, crater and damage
## come from the server). style_for() picks {kind, tier, skill, item}; projectile_view.gd and
## explosion_fx.gd draw it from the two tables here:
## - KINDS (gun kind = the bullet's silhouette and the impact's theme): its own images in
##   assets/fx/<kind>/ (projectile, trail particle, impact frames) and how they move;
## - TIERS (gun tier = intensity): colours (the guns' tier palettes, tools/art/weapon_painter.gd),
##   sizes, particle counts and which shared overlays of assets/fx/tiers/ join in. Every tier
##   works with every kind, so 5 kinds × 9 tiers need no image set of their own.
## - THEMES (the four normal tiers only): how the shell flies, on top of every kind: iron a thick
##   grey smoke trail, steel shed sparks, mithril an icy-blue light streak with ice glints, dragon
##   a flickering fire tail with embers (projectile_view.gd). Basic and the crafted tiers have none
##   and fly as before; the muzzle flash and the impact are the same for every theme.
## Particle counts stay capped (MAX_IMPACT_PARTICLES per impact, MAX_TRAIL_PARTICLES live per
## projectile); both views free themselves.

const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const Art := preload("res://ui/art.gd")
const Items := preload("res://match/items.gd")

const MAX_IMPACT_PARTICLES := 120
const MAX_TRAIL_PARTICLES := 48
## Of those, the kind's own trail particles and the tier's overlay particles (oldest dropped).
const TRAIL_KIND_CAP := 30
const TRAIL_TIER_CAP := 18
const DEFAULT_KIND := "bazooka"
const DEFAULT_TIER := "basic"
## Every shell drawn in flight (projectile_view.gd: the kinds' and the tiers' own pictures, their
## trails, halos and tails, the skills' shells: bomb chain, rain, bloom seeds; laser_fx.gd's
## charge orb) is this big; the explosions are not scaled (playtest round 3: was 1, too big).
const SHELL_SCALE := 0.7
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
##   one every `every` world px, born `back` world px behind the centre (default 0), life s, size
##   start/end world px, alpha, drift down px/s, jitter sideways px, spin rad/s; tint: particles
##   take the accent colour by this much; optional hot / cool: each particle's colour goes from
##   hot to cool over the first cool_at of its life, e.g. exhaust fire turning into grey smoke);
## spin: the projectile turns (rad/s) on top of facing its flight; fuse: the bomb's fuse spark;
## exhaust: a flickering flame at the rocket's nozzle; flicker: the projectile pulses;
## body_tint: how much the projectile itself takes the accent colour (0: its own colours; the
##   blaster bolt is drawn white and takes it fully);
## tier_body_scale: a tier's own shell picture (projectile_<tier>.png) is drawn this much larger
##   than fitted into projectile.png's drawn part (the long seeds would look tiny in the round pod's box);
## impact: scale of the burst frames, size (optional, 1: the whole impact drawn this much smaller,
##   its radius and its debris spread; the cannon 0.75 after playtest 4), smoke puffs and colour, bits (count, speed, size, gravity
##   factor, colours, image: "debris" or "trail" = the kind's trail particle), frame_tint, lum (the
##   frames' luminance range, dark smoke .. white core, for the burst palettes' gradient map).
const KINDS := {
	"bazooka": {"color": Color(1.0, 0.72, 0.32), "line": Color(1.0, 0.8, 0.4), "line_width": 5.0,
		"trail": {"every": 7.0, "back": 12.0, "life": 0.5, "size": [5.0, 15.0], "alpha": 0.7, "drift": -14.0, "jitter": 2.5, "spin": 1.5, "tint": 0.3,
			"hot": Color(1.0, 0.82, 0.35), "cool": Color(0.62, 0.6, 0.62), "cool_at": 0.35},
		"spin": 0.0, "fuse": false, "exhaust": true, "flicker": false, "body_tint": 0.0,
		"impact": {"scale": 1.0, "smoke": 7, "smoke_color": Color(0.55, 0.52, 0.55, 0.85), "bits": 12,
			"speed": [180.0, 420.0], "bit_size": [2.0, 4.0], "gravity": 1.0, "colors": DIRT, "bit_image": "debris", "lum": [0.3, 0.98]}},
	"cannon": {"color": Color(1.0, 0.6, 0.25), "line": Color(0.75, 0.74, 0.76), "line_width": 4.0,
		"trail": {"every": 7.0, "life": 0.45, "size": [9.0, 20.0], "alpha": 0.7, "drift": -18.0, "jitter": 0.0, "spin": 0.0, "tint": 0.15},
		"spin": 0.0, "fuse": false, "exhaust": false, "flicker": false, "body_tint": 0.0,
		"impact": {"scale": 1.2, "size": 0.75, "smoke": 11, "smoke_color": Color(0.38, 0.36, 0.38, 0.9), "bits": 24,
			"speed": [220.0, 520.0], "bit_size": [2.5, 5.0], "gravity": 1.0, "colors": DIRT, "bit_image": "debris", "lum": [0.15, 0.93]}},
	"shock_rifle": {"color": Color(0.55, 0.95, 1.0), "line": Color(0.55, 0.95, 1.0), "line_width": 7.0,
		"trail": {"every": 6.0, "life": 0.3, "size": [9.0, 3.0], "alpha": 1.0, "drift": 0.0, "jitter": 9.0, "spin": 0.0, "tint": 0.6},
		"spin": 0.0, "fuse": false, "exhaust": false, "flicker": true, "body_tint": 0.0,
		"impact": {"scale": 1.0, "smoke": 2, "smoke_color": Color(0.55, 0.8, 0.95, 0.5), "bits": 16,
			"speed": [200.0, 480.0], "bit_size": [3.0, 5.0], "gravity": 0.25,
			"colors": [Color(1.0, 1.0, 0.7), Color(0.6, 0.95, 1.0)], "bit_image": "trail", "lum": [0.7, 0.98]}},
	"seed_launcher": {"color": Color(0.6, 1.0, 0.5), "line": null, "line_width": 0.0, "tier_body_scale": 1.45,
		"trail": {"every": 8.0, "life": 0.6, "size": [8.0, 6.0], "alpha": 0.95, "drift": 22.0, "jitter": 6.0, "spin": 9.0, "tint": 0.2},
		"spin": 9.0, "fuse": false, "exhaust": false, "flicker": false, "body_tint": 0.0,
		"impact": {"scale": 1.0, "smoke": 3, "smoke_color": Color(0.6, 0.85, 0.55, 0.55), "bits": 16,
			"speed": [140.0, 360.0], "bit_size": [4.0, 6.0], "gravity": 0.35,
			"colors": [Color(1, 1, 1), Color(0.65, 1.0, 0.6), Color(1.0, 0.9, 0.6)], "bit_image": "trail", "lum": [0.62, 0.97]}},
	"water_gun": {"color": Color(0.55, 0.88, 1.0), "line": Color(0.7, 0.92, 1.0), "line_width": 3.0,
		"trail": {"every": 6.0, "life": 0.45, "size": [6.0, 3.0], "alpha": 0.9, "drift": 90.0, "jitter": 4.0, "spin": 0.0, "tint": 0.25},
		"spin": 0.0, "fuse": false, "exhaust": false, "flicker": false, "body_tint": 0.0,
		"impact": {"scale": 1.0, "smoke": 2, "smoke_color": Color(0.75, 0.9, 1.0, 0.45), "bits": 18,
			"speed": [160.0, 420.0], "bit_size": [3.0, 6.0], "gravity": 0.9,
			"colors": [Color(0.85, 0.96, 1.0), Color(0.5, 0.82, 1.0), Color(1, 1, 1)], "bit_image": "trail", "lum": [0.4, 0.98]}},
	"blaster": {"color": Color(1.0, 0.42, 0.5), "line": Color(1.0, 0.6, 0.65), "line_width": 5.0,
		"trail": {"every": 7.0, "life": 0.28, "size": [7.0, 2.0], "alpha": 0.9, "drift": 0.0, "jitter": 4.0, "spin": 0.0, "tint": 1.0},
		"spin": 0.0, "fuse": false, "exhaust": false, "flicker": true, "body_tint": 1.0,
		"impact": {"scale": 1.0, "smoke": 2, "smoke_color": Color(0.8, 0.7, 0.85, 0.45), "bits": 14,
			"speed": [200.0, 460.0], "bit_size": [3.0, 5.0], "gravity": 0.3,
			"colors": [Color(1, 1, 1), Color(1.0, 0.85, 0.9)], "bit_image": "trail", "frame_tint": 1.0, "lum": [0.84, 1.0]}},
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

## The flight themes' own colours (not the tier palettes: smoke is grey, sparks white-hot, ice blue).
const SMOKE := Color(0.5, 0.5, 0.54)
const SMOKE_DARK := Color(0.33, 0.33, 0.36)
const SPARK := Color(1.0, 0.72, 0.18)
const SPARK_WHITE := Color(1.0, 0.98, 0.86)
const ICE := Color(0.35, 0.85, 1.0)
const ICE_DEEP := Color(0.1, 0.35, 0.95)
const ICE_WHITE := Color(0.88, 0.97, 1.0)
## Flame from its hot core to its smoke (fire()).
const FIRE := [Color(1.0, 0.98, 0.8), Color(1.0, 0.84, 0.3), Color(1.0, 0.5, 0.1), Color(0.86, 0.18, 0.05), Color(0.26, 0.2, 0.2)]

## gun tier -> how its shell flies (only the four normal tiers; tier_theme() is {} for the others):
## trail: the flight particles, instead of TIERS.trail_fx (its keys, plus mode "puff" (a texture,
##   tex: an assets/fx/tiers/ overlay or an assets/fx/common/ effect, tex2: every other one) or
##   "streak" (a velocity-stretched line: length s of its speed, size = width), shed [back, side]
##   px/s thrown off the shell, gravity px/s², color / color2 (alternating), glow (drawn in the
##   glow layer behind the shell)); no trail: the tier's own trail_fx;
## ribbon: a tail along the recent path ({}: none): style "light" (a glowing line, mithril) or
##   "fire" (layered flame puffs, dragon), points kept one every `every` px, width px.
const THEMES := {
	"iron": {
		"trail": {"mode": "puff", "tex": "smoke", "every": 12.0, "life": 1.0, "size": [12.0, 34.0], "alpha": 0.6, "drift": -10.0,
			"jitter": 4.0, "spin": 1.2, "color": SMOKE, "color2": SMOKE_DARK, "glow": false},
		"ribbon": {}},
	"steel": {
		"trail": {"mode": "streak", "every": 9.0, "life": 0.38, "size": [3.6, 1.8], "length": 0.07, "alpha": 1.0,
			"shed": [260.0, 200.0], "gravity": 700.0, "jitter": 3.0, "color": SPARK, "color2": SPARK_WHITE, "glow": true},
		"ribbon": {}},
	"mithril": {
		"trail": {"mode": "puff", "tex": "shard", "tex2": "sparkle", "every": 8.0, "life": 0.55, "size": [8.0, 3.0], "alpha": 1.0,
			"drift": 8.0, "jitter": 11.0, "spin": 5.0, "color": ICE_WHITE, "color2": ICE, "glow": true},
		"ribbon": {"style": "light", "points": 30, "every": 8.0, "width": 14.0}},
	"dragon": {
		"ribbon": {"style": "fire", "points": 30, "every": 7.0, "width": 19.0}},
}
## Ribbon points kept at most (they are path points, not particles).
const MAX_RIBBON_POINTS := 32

## The burst's colours follow the SHELL (burst_palette()): the fireball frames are gradient-mapped
## (explosion_fx.gd) from the kind's own colours onto smoke -> outer -> mid -> core by their
## luminance (KINDS impact "lum": the frames' dark .. bright range), and the flash, rings, sparks,
## embers, the kind's sparks / petals, the debris and (subtly) the smoke take the palette too.
## Keys: body (the shell's dominant colour, checked against projectile_<tier>.png by the tests),
## core / mid / outer / smoke (the ramp), flash (glow flash, first ring, screen tint), spark /
## spark2 (sparkles, embers, the kind's sparks / petals), bits (mixed into the debris: shrapnel,
## ice chips, lava), lava (half the embers fall as heavy glowing lava blobs).
## A family per normal tier (iron grey-steel with a white-hot core, mithril icy cyan-white, dragon
## red lava); BURST overrides it per kind with the colours sampled from that kind's shell.
const BURST_FAMILIES := {
	"iron": {"core": Color(1.0, 0.99, 0.95), "mid": Color(0.88, 0.9, 0.94), "outer": Color(0.6, 0.65, 0.72),
		"smoke": Color(0.3, 0.32, 0.37), "flash": Color(0.92, 0.95, 1.0), "spark": Color(1.0, 0.86, 0.55),
		"spark2": Color(0.88, 0.9, 0.95), "bits": [Color(0.66, 0.68, 0.72), Color(0.42, 0.43, 0.47)], "lava": false},
	"steel": {"core": Color(0.98, 0.99, 1.0), "mid": Color(0.78, 0.82, 0.88), "outer": Color(0.45, 0.5, 0.58),
		"smoke": Color(0.25, 0.27, 0.3), "flash": Color(0.85, 0.9, 1.0), "spark": Color(1.0, 0.9, 0.6),
		"spark2": Color(0.86, 0.88, 0.92), "bits": [Color(0.7, 0.72, 0.76)], "lava": false},
	"mithril": {"core": Color(1.0, 1.0, 1.0), "mid": Color(0.86, 0.97, 1.0), "outer": Color(0.4, 0.83, 0.95),
		"smoke": Color(0.48, 0.66, 0.78), "flash": Color(0.6, 0.94, 1.0), "spark": Color(0.9, 0.99, 1.0),
		"spark2": Color(0.36, 0.86, 0.98), "bits": [Color(0.86, 0.97, 1.0), Color(0.5, 0.86, 0.96)], "lava": false},
	"dragon": {"core": Color(1.0, 0.82, 0.32), "mid": Color(0.98, 0.32, 0.04), "outer": Color(0.6, 0.05, 0.03),
		"smoke": Color(0.16, 0.08, 0.07), "flash": Color(1.0, 0.36, 0.06), "spark": Color(1.0, 0.56, 0.1),
		"spark2": Color(1.0, 0.84, 0.3), "bits": [Color(1.0, 0.5, 0.1), Color(0.3, 0.06, 0.04)], "lava": true},
}
## kind -> normal tier -> the palette from that kind's shell (projectile_<tier>.png), over its family.
const BURST := {
	"bazooka": {
		"iron": {"body": Color(0.53, 0.54, 0.25), "outer": Color(0.62, 0.65, 0.6), "spark": Color(0.96, 0.3, 0.22),
			"bits": [Color(0.66, 0.68, 0.72), Color(0.53, 0.54, 0.25)]},
		"steel": {"body": Color(0.26, 0.41, 0.23), "core": Color(0.95, 1.0, 0.88), "mid": Color(0.58, 0.82, 0.46),
			"outer": Color(0.2, 0.46, 0.18), "smoke": Color(0.14, 0.22, 0.13), "flash": Color(0.5, 0.86, 0.4),
			"spark": Color(0.96, 0.28, 0.22), "spark2": Color(0.86, 0.88, 0.92), "bits": [Color(0.26, 0.41, 0.23), Color(0.75, 0.76, 0.78)]},
		"mithril": {"body": Color(0.8, 0.95, 0.98)},
		"dragon": {"body": Color(0.52, 0.09, 0.07)}},
	"cannon": {
		"iron": {"body": Color(0.39, 0.38, 0.37)},
		"steel": {"body": Color(0.91, 0.4, 0.08), "core": Color(1.0, 0.97, 0.75), "mid": Color(1.0, 0.66, 0.2),
			"outer": Color(0.95, 0.4, 0.04), "smoke": Color(0.36, 0.22, 0.12), "flash": Color(1.0, 0.58, 0.12),
			"spark": Color(1.0, 0.82, 0.36), "spark2": Color(0.8, 0.81, 0.84), "bits": [Color(0.91, 0.4, 0.08), Color(0.5, 0.5, 0.52)]},
		"mithril": {"body": Color(0.78, 0.88, 0.92), "outer": Color(0.42, 0.74, 0.88)},
		"dragon": {"body": Color(0.64, 0.13, 0.11)}},
	"shock_rifle": {
		"iron": {"body": Color(0.26, 1.0, 1.0), "core": Color(1.0, 1.0, 1.0), "mid": Color(0.5, 1.0, 1.0),
			"outer": Color(0.0, 0.78, 0.95), "smoke": Color(0.28, 0.52, 0.64), "flash": Color(0.15, 0.92, 1.0),
			"spark": Color(1.0, 1.0, 0.4), "spark2": Color(0.55, 1.0, 1.0), "bits": []},
		"steel": {"body": Color(0.8, 0.36, 1.0), "core": Color(1.0, 0.94, 1.0), "mid": Color(0.86, 0.56, 1.0),
			"outer": Color(0.56, 0.16, 0.98), "smoke": Color(0.36, 0.22, 0.52), "flash": Color(0.72, 0.32, 1.0),
			"spark": Color(1.0, 0.96, 1.0), "spark2": Color(0.86, 0.56, 1.0), "bits": []},
		"mithril": {"body": Color(0.83, 1.0, 0.98), "spark": Color(1.0, 0.95, 0.55), "bits": []},
		"dragon": {"body": Color(0.63, 0.03, 0.0), "core": Color(1.0, 0.9, 0.45), "mid": Color(1.0, 0.6, 0.12), "bits": []}},
	"seed_launcher": {
		"iron": {"body": Color(0.46, 0.67, 0.09), "core": Color(0.96, 1.0, 0.78), "mid": Color(0.56, 0.84, 0.18),
			"outer": Color(0.24, 0.5, 0.03), "smoke": Color(0.3, 0.36, 0.16), "flash": Color(0.62, 0.88, 0.2),
			"spark": Color(0.8, 0.94, 0.3), "spark2": Color(0.7, 0.5, 0.28), "bits": []},
		"steel": {"body": Color(0.7, 0.82, 0.35), "core": Color(1.0, 1.0, 0.88), "mid": Color(0.86, 0.94, 0.52),
			"outer": Color(0.56, 0.74, 0.2), "smoke": Color(0.4, 0.46, 0.3), "flash": Color(0.82, 0.94, 0.42),
			"spark": Color(0.96, 0.45, 0.62), "spark2": Color(0.86, 0.88, 0.92), "bits": []},
		"mithril": {"body": Color(0.84, 0.95, 0.96), "spark": Color(1.0, 0.82, 0.3), "bits": []},
		"dragon": {"body": Color(0.62, 0.13, 0.1), "bits": []}},
}
## The crafted tiers (any kind; their shell is the blaster bolt in the tier's colour): their own
## palette, keeping their identity (silver ring, gold coins, titan cracks, diamond prism).
const CRAFTED_BURST := {
	"silver": {"body": Color(0.98, 0.99, 1.0), "core": Color(1.0, 1.0, 1.0), "mid": Color(0.9, 0.94, 1.0),
		"outer": Color(0.52, 0.7, 1.0), "smoke": Color(0.5, 0.56, 0.68), "flash": Color(0.92, 0.96, 1.0),
		"spark": Color(1.0, 1.0, 1.0), "spark2": Color(0.52, 0.74, 1.0), "bits": [], "lava": false},
	"gold": {"body": Color(1.0, 0.76, 0.2), "core": Color(1.0, 1.0, 0.84), "mid": Color(1.0, 0.84, 0.32),
		"outer": Color(0.94, 0.58, 0.06), "smoke": Color(0.48, 0.38, 0.18), "flash": Color(1.0, 0.8, 0.28),
		"spark": Color(1.0, 0.94, 0.58), "spark2": Color(1.0, 0.76, 0.2), "bits": [], "lava": false},
	"titan": {"body": Color(1.0, 0.56, 0.16), "core": Color(1.0, 0.94, 0.74), "mid": Color(1.0, 0.6, 0.18),
		"outer": Color(0.78, 0.34, 0.08), "smoke": Color(0.36, 0.34, 0.42), "flash": Color(1.0, 0.56, 0.16),
		"spark": Color(1.0, 0.66, 0.24), "spark2": Color(0.7, 0.68, 0.82), "bits": [Color(0.63, 0.61, 0.74)], "lava": false},
	"diamond": {"body": Color(0.55, 0.88, 1.0), "core": Color(1.0, 1.0, 1.0), "mid": Color(0.84, 0.97, 1.0),
		"outer": Color(0.42, 0.8, 1.0), "smoke": Color(0.58, 0.7, 0.82), "flash": Color(0.55, 0.88, 1.0),
		"spark": Color(0.9, 0.99, 1.0), "spark2": Color(0.55, 0.88, 1.0), "bits": [], "lava": false},
}
## The palette keys every burst palette has.
const BURST_KEYS := ["body", "core", "mid", "outer", "smoke", "flash", "spark", "spark2", "bits", "lava"]
## How much the kind's smoke colour takes the palette's (subtle).
const BURST_SMOKE_MIX := 0.45

static var _palettes := {} # "kind/tier" -> burst_palette()


## Who fires, how: the gun the shooter brought (match player dict: weaponItemId, characterId;
## catalog for the weapon's entry; no weapon / a bot → its character's gun, basic), whether it is
## a skill shot, and the item (only for an item shot). Air strikes (targetX items) drop plain bombs (the basic
## bazooka's trail and fire explosion; projectile_view.gd ITEM_LOOKS draws the round bomb).
static func style_for(player: Dictionary, action_mode: String, item_id: String, catalog: Variant = null) -> Dictionary:
	var g := EquipmentModel.player_gun(player, catalog)
	var it := item_id if action_mode == "item" else ""
	var out := {"kind": known_kind(str(g["kind"])), "tier": known_tier(str(g["tier"])), "skill": action_mode == "skill", "item": it}
	if Items.needs_target_x(it): # dropped from the sky (the air strike), not fired from the gun
		out["kind"] = DEFAULT_KIND
		out["tier"] = DEFAULT_TIER
	return out


## A tier's flight theme (THEMES), {} for basic, the crafted tiers and an unknown tier.
static func tier_theme(tier: String) -> Dictionary:
	return THEMES.get(known_tier(tier), {})


## The flight particles of a tier: its theme's, else its TIERS trail_fx ({} none).
static func trail_fx(tier: String) -> Dictionary:
	var th := tier_theme(tier)
	return th["trail"] if th.has("trail") else TIERS[known_tier(tier)]["trail_fx"]


## Flame colour at heat h (1 the hot core .. 0 its smoke), through FIRE.
static func fire(h: float) -> Color:
	var x := (1.0 - clampf(h, 0.0, 1.0)) * (FIRE.size() - 1)
	var i := mini(int(x), FIRE.size() - 2)
	return Color(FIRE[i]).lerp(FIRE[i + 1], x - i)


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


## The kind's whole-impact size (KINDS impact "size", 1 when unset): ExplosionFx draws everything
## for radius × this and throws its debris and particles this much less far.
static func impact_size(kind: String) -> float:
	return float(KINDS[known_kind(kind)]["impact"].get("size", 1.0))


## How long an impact of this tier stays on screen (s): the base life plus the lingering sparkles.
static func impact_life(tier: String, base: float) -> float:
	var t: Dictionary = TIERS[known_tier(tier)]["impact"]
	return base + float(t["linger"]) + (0.6 if bool(t["crack"]) else 0.0)


## The burst palette of kind × tier (BURST_KEYS plus smoke_color: the kind's smoke tinted by it),
## computed once and cached; {} keeps the kind's own colours: basic, a normal tier without its own
## shell picture (the blaster: its bolt takes the accent, and so does its burst) or without a BURST row.
static func burst_palette(kind: String, tier: String) -> Dictionary:
	kind = known_kind(kind)
	tier = known_tier(tier)
	var key := kind + "/" + tier
	if not _palettes.has(key):
		_palettes[key] = burst_palette_for(kind, tier, Art.tier_projectile(kind, tier) != null)
	return _palettes[key]


## burst_palette() for a shell picture there (has_shell) or not (a new dict, not cached).
static func burst_palette_for(kind: String, tier: String, has_shell: bool) -> Dictionary:
	kind = known_kind(kind)
	tier = known_tier(tier)
	var pal := {}
	if CRAFTED_BURST.has(tier):
		pal = CRAFTED_BURST[tier].duplicate()
	elif has_shell and BURST_FAMILIES.has(tier) and BURST.get(kind, {}).has(tier):
		pal = BURST_FAMILIES[tier].duplicate()
		pal.merge(BURST[kind][tier], true)
	if pal.is_empty():
		return pal
	var sc: Color = KINDS[kind]["impact"]["smoke_color"]
	pal["smoke_color"] = Color(Color(sc.r, sc.g, sc.b).lerp(pal["smoke"], BURST_SMOKE_MIX), sc.a)
	return pal

