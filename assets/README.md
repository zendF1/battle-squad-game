# assets/

Every image the game shows is a file here. The current files are placeholder art drawn in
code (`tools/art/*.gd`) and baked by `tools/bake_art.gd`. `ui/art.gd` is the one place that maps
ids to these paths; a missing file never crashes (a character falls back to rookie, an icon to
`icons/unknown.png`, anything else to a small grey square, with a warning).

Total about 4.6 MB of PNG (the lobby rigs about 0.5 MB of it, the full-body pictures about 0.45 MB).

## Replacing art

- **Overwrite a PNG with the same name and the same size** (and, for characters, the same pivot).
  The editor re-imports it; nothing else changes. A different size works for icons, effects,
  clouds and backgrounds (they are drawn to a fixed on-screen size), but keep character frames on
  the shared canvas below.
- **Characters (lobby)**: the screens outside the match draw, in this order of preference,
  (1) the skinned full-body picture `characters/<id>/lobby/full.png` + `full.json`, (2) the
  front-view cutout rig `characters/<id>/lobby/rig.json` + `parts/` (kept as a fallback, unused
  while full.png exists), (3) the baked side-view frames. Re-cut the full-body pictures from a new
  lineup image with `tools/cut_sheet.gd -- lineup` (below).
- **Characters (match)**: either overwrite the frame PNGs, or open
  `characters/<id>/<id>.tres` (SpriteFrames) in the editor and change frames, counts, speed or
  loop flags. The animation names must stay `idle`, `walk`, `shoot`, `hurt`, `die`. If you change
  the canvas size or pivot, update `FRAME_SIZE` / `FRAME_PIVOT` / `PX_PER_UNIT` in `ui/art.gd`
  and the sprite `offset` in `scenes/character/character.tscn` (= -pivot). The frames draw no
  gun: replace a frame **and its entry in `characters/<id>/gun_anchors.json`** together (where
  the hand holds the gun in that frame), and keep one entry per frame.
- **Guns**: overwrite `weapons/<kind>/<tier>.png` and, when the grip or muzzle moved, its entry
  in `weapons/weapons.json`. Any canvas size works (the grip pivot places it); draw it at
  `pxPerUnit` px per art unit (1.6, like the frames) or change `pxPerUnit` (it scales every gun).
- **9-patches** (`ui/`): keep the corners inside the texture margins listed below
  (`ui/art.gd` `UI_BOXES`), or change the margins there.
- Import settings: icons, effects and clouds are imported with mipmaps (they are shown smaller
  than drawn); the rest without. Re-baking never touches an existing `.import` file.

## Re-baking the placeholder art

Run windowed (a headless run has no renderer), from the project folder:

```
$GODOT --path . -s tools/bake_art.gd                 # everything
$GODOT --path . -s tools/bake_art.gd -- icons ui     # only some groups
```

Groups: `characters` (includes `poses`), `poses` (only the lobby's no-gun pose), `weapons`, `env`, `terrain`,
`fx`, `icons`, `ui`, `equipment`. It overwrites the
PNGs (and the characters' `.tres` and `gun_anchors.json`, the guns' `weapons.json`), prints each file with
its size and quits. Then let the editor import them
(or run `$GODOT --headless --path . --import` while no editor is open). Baking overwrites
replaced art too: only re-bake the groups you have not replaced.

## Files

### characters/ (scene: `scenes/character/character.tscn`)

The frames draw the character with its hands free (the front arm reaches forward, the hand at the gun's
grip); the gun is a separate sprite (`weapons/`) the scene draws at the hand, so it changes with the
equipped weapon.

| File | Size | Notes |
|---|---|---|
| `<id>/idle_0..3.png` | 512x400 each | loops, 2.5 fps; upper body breathing |
| `<id>/walk_0..5.png` | 512x400 each | loops, 9 fps; leg swing, bob, forward lean |
| `<id>/shoot_0..2.png` | 512x400 each | once, 9 fps; the hand recoils (the muzzle flash is drawn at the gun's muzzle from the anchors' `flash`) |
| `<id>/hurt_0..2.png` | 512x400 each | once, 7 fps; knocked back, wobble, squint (the red flash is code) |
| `<id>/die_0..3.png` | 512x400 each | once, 8 fps, holds the last frame; falls on its back (the grey tint is code) |
| `<id>/idle_free_0..3.png` | 512x400 each (13–17 KB) | the lobby stage's pose without a gun: the idle frames with the front arm hanging like the back one; same canvas, pivot and speed as `idle`. Not in the `.tres` (`ui/art.gd` `free_frames()` builds it, no anchors); missing or not imported yet → the normal idle with the bare hand |
| `<id>/<id>.tres` | – | SpriteFrames of the five animations |
| `<id>/gun_anchors.json` | 2 KB | per animation, one entry per frame: `grip` [x, y] px in the frame (the hand's centre, where the gun's grip goes), `angle` degrees (0 = level, + turns the muzzle down; recoil kick, walk lean, hurt wobble), `front` (gun over the body; `false` in `die`: behind), `flash` 0..1 (muzzle flash) |
| `<id>/portrait.png` | 128x128 | head and shoulders: Profile and Shop character cards |
| `shadow.png` | 160x38 | ground shadow under every character, centred on the feet |
| `hand.png` | 32x32 (0.5 KB) | the hand drawn over the gun's grip, centred on the grip (shared) |

`<id>` is `rookie`, `tanko`, `spark`, `flora` (about 13–24 KB per frame). **Every frame**: canvas
512x400, transparent, **feet at pixel (256, 360)** (bottom centre, the same pixel in every frame),
facing right, drawn at 1.6 px per art unit (the character is about 150 units = 240 px tall).
The game flips it for facing left. The fallback of the lobby stage and the Prep panel
(`ui/character_view.gd`, about 2.5 and 1.5 px per unit; they draw the lobby rig below) and the match (`match/views/player_view.gd`,
0.35 px per unit, about 52 px tall, feet on the server position).

### characters/<id>/lobby/full.* (the full-body picture: `scenes/character/full_body.gd`, loaded by `ui/art.gd` `lobby_full()`)

Outside the match (lobby stage, Prep, Nhân vật: `ui/character_view.gd` turns `lobby_rig` on,
`scenes/character/character.gd` `lobby_full` is on by default) a character is **one coherent
full-body drawing** cut from `art_source/characters/lineup_v1.png` (1024x765, the four characters
side by side on white), skinned on a skeleton: a Polygon2D mesh over the picture weighted to
Bone2Ds under a Skeleton2D. It has no gun hand, so no gun is drawn on it: the worn gun rests on
the pedestal beside it (`screens/home/pedestal_gun.gd`, on the lobby, the Nhân vật page and Prep
scaled to its stage). It only idles (breathing, a head nod and tilt, a slight arm sway, plus one
per-character flourish: Rookie waves the raised hand, Spark wiggles the V-sign, Flora nudges her
fist, Tanko breathes heavier with his shoulders); feet stay planted. The match is unchanged.
Missing or broken full.json / full.png → the rig below, then the frames.

| File | Size | Notes |
|---|---|---|
| `<id>/lobby/full.png` | 190–224 x 363–392 (110–120 KB) | transparent, the figure 346–375 px tall, drawn 1:1 on the lobby stage (scale 0.64 × the stage's 1.5625) |
| `<id>/lobby/full.json` | 33–36 KB | generated: `size`, `pivot` (the feet: the middle of the boots' outer edges, the soles' bottom, px in full.png), `height`, `scale` (full.png px → character px), `bones` (`name`, `parent`, `at` the joint, `tip` the end of its segment, `strength`; px in full.png), `anims` (this character's tracks), `mesh` (`vertices` px = uv, `triangles` 3 indices each), `weights` (per vertex: bone index, weight, …; at most 4, summing to 1) |
| `lobby_full_anims.json` | 1 KB | the idle every full-body picture plays (format of `lobby_anims.json` below; bones `root`, `hips`, `chest`, `head`, `arm_l_upper` / `arm_l_fore` / `hand_l`, `arm_r_*`, `leg_l_thigh` / `leg_l_shin` / `foot_l`, `leg_r_*`; l / r = the picture's left / right); a full.json's `anims` replace or add tracks by bone |

**Re-cutting / a better picture**: put the new lineup (or one picture per character) in
`art_source/characters/`, edit `art_source/characters/lineup_parts.json` (`sheet`; per figure its
`rect` / `seed` / `holes` like a parts sheet below, `scale` so the figure comes out at most about
375 px tall, the `joints` in sheet px: `hips`, `chest`, `neck`, `crown`, `l_` / `r_` `shoulder`,
`elbow`, `wrist`, `hand`, `hip`, `knee`, `ankle`, `toe`, and its `anims` flourish), then run
`$GODOT --headless --path . -s tools/cut_sheet.gd -- lineup [<id> ...]` and let the editor import
the PNGs. It writes full.png and full.json (mesh and weights by `tools/full_mesh.gd`: outline
points every 5 px round the figure grown 2 px plus an inner grid, Delaunay-triangulated, kept
inside the figure so the gaps between an arm and the body stay out of the mesh, every visible
pixel covered; weights by the distance through the figure's own pixels, so a raised hand next to
the head does not drag the head). Keep the motion small: an arm drawn over the body has no body
pixels under it, so a large arm move stretches the body with it.

### characters/<id>/lobby/ (the lobby rig: `scenes/character/rig.gd`, loaded by `ui/art.gd` `rig()`)

Fallback only (the full-body picture above is preferred).

Without a full-body picture (or with `lobby_full` off), outside the match a
character is a **front-view cutout rig** built from its AI-made parts sheet
(`art_source/characters/<id>/<id>_parts_v2.png`, 2400x1792, white background). The match keeps the
side-view frames above. A character without `lobby/rig.json` (or with a part missing) falls back
to the frames.

| File | Notes |
|---|---|
| `<id>/lobby/parts/<part>.png` | one picture per body part, transparent, cut by `tools/cut_sheet.gd` (about 5–25 KB each, 11–12 per character, about 0.5 MB in all) |
| `<id>/lobby/rig.json` | the bones (below) |
| `lobby_anims.json` | the animations every lobby rig plays (below) |

Parts: `head`, `torso`, `hips` (belt and the top of the legs), `thigh_back` / `thigh_front`,
`shin_back` / `shin_front` (with the boots), `arm_back_upper` / `arm_back_fore` (relaxed hand),
`arm_gun_upper` / `arm_gun_fore` (the gripping fist that holds the gun), optionally
`arm_free_upper` / `arm_free_fore` (a second relaxed arm; otherwise the back arm's pictures are used
mirrored) and accessories (`backpack`). "back" is the arm / leg on the far side (drawn behind),
"front" the near one; the character faces +x (the game mirrors it for facing left).

**rig.json**: `scale` (part px → character px; 0.64 draws the parts 1:1 on the 1600x900 lobby
stage, which shows a character at 1.5625 character px per px), `bones` (one per line):
`name`, `parent` (the root has none; its origin is the feet), `part` (picture name, none for
the root), `pivot` [x, y] (the joint, px in this part's picture), `at` [x, y] (where the joint
sits on the parent's picture, px; for the root's children: px from the feet), `rot` (rest
rotation, degrees, + clockwise, around the pivot), `z` (draw order, low first), `flip` (mirror
the picture), `shade` (0..1 darkening, e.g. 0.85 for the far arm), `set` (`gun`: shown only
while holding the gun, `free`: only with the hands free). `gun`: `bone` (the gripping hand),
`at` (the grip point on its picture), `angle` (degrees: the gun's angle to that picture, so the
held gun is level at rest), `z` (drawn between the parts below and above this number). The
equipped gun (`weapons/`) is drawn at that grip, between the back and front parts.

**lobby_anims.json**: per animation `length` (s), `loop`, `tracks`: bone → `t` (key times) and
`rot` (degrees added to the rest rotation), `x` / `y` (px added to the rest position), `sx` / `sy`
(scale), one value per key; `_flash` → `t`, `v` (muzzle flash 0..1). `idle` (holding the gun:
Prep, Nhân vật) and `idle_free` (hands free: the lobby stage) breathe, bob the head and sway the
arms slightly. A rig.json may add or override an animation in its own `anims`. Keep motion small:
the parts are drawn 1:1, every rotation and sub-pixel move resamples them. The same format can
carry a side-view rig later (with walk / shoot / hurt / die).

**Swapping in a better sheet**: put it in `art_source/characters/<id>/`, edit
`art_source/characters/<id>/parts.json` (`sheet`, then per part its `rect` [x, y, w, h] in sheet px
— loose is fine —, a `seed` point on the part, `clip` (a convex polygon to split joined pieces,
with `feather` px of soft edge) and `holes` (enclosed whites to clear, e.g. a fist's hole), and
`scale` so the character comes out about 375 px tall), then run
`$GODOT --headless --path . -s tools/cut_sheet.gd -- <id>` and let the editor import the PNGs.
If the parts keep their layout, rig.json still fits; otherwise move the `pivot` / `at` points
(px in the new pictures). Or drop new PNGs with the same names into `<id>/lobby/parts/` and fix
the pivots. A part not imported yet is read straight from its PNG.

### weapons/ (the held guns: `scenes/character/character.gd` Flip/Gun, paths in `ui/art.gd`)

```
weapons/
  weapons.json                      grip + muzzle of every sprite, pxPerUnit
  bazooka/        basic iron steel mithril dragon          (Rookie's guns)
  cannon/         basic iron steel mithril dragon          (Tanko's)
  shock_rifle/    basic iron steel mithril dragon          (Spark's)
  seed_launcher/  basic iron steel mithril dragon          (Flora's)
  blaster/        basic iron steel mithril dragon silver gold titan diamond   (generic + crafted)
```

| File | Size | Notes |
|---|---|---|
| `<kind>/<tier>.png` | 224x128 (2–13 KB, 29 files) | side view facing right, transparent, drawn at 1.6 px per art unit like the frames; the grip (the hand) at (96, 88). Kind = silhouette, tier = look: `basic` in the character's own gun colours (no weapon equipped), iron/steel/mithril/dragon and silver/gold/titan/diamond in the equipment icons' palettes; mithril, dragon, gold, titan, diamond glow |
| `weapons.json` | 4 KB | `{"pxPerUnit": 1.6, "guns": {kind: {tier: {"size": [w, h], "grip": [x, y], "muzzle": [x, y]}}}}`, px in the image. `grip` is the pivot (placed on the frame's anchor), `muzzle` is where the flash and the shots start (visual only) |

Which gun: `screens/home/equipment_model.gd` `gun()` maps a weapon item to {kind, tier}
(`rookie_weapon_lv30` → bazooka/mithril, `crafted_weapon_gold` → blaster/gold, `normal_weapon_lv10` →
blaster/iron, no weapon → the character's kind/basic). A missing tier falls back to the kind's `basic`, a
missing kind to `bazooka/basic` (`ui/art.gd` `gun()`). Lobby, Prep and the Nhân vật page show the weapon the
character wears: with the full-body pictures (no gun hand) the worn gun rests on the pedestal at the
character's left on all three (Prep: scaled to its small stage, without the label; with the rig fallback
Prep and Nhân vật show it in hand, `ui/character_view.gd`), lying diagonally with the muzzle up-left, its name and
"+N" under it (`screens/home/pedestal_gun.gd`, a soft glow in the tier's colour); the match shows the one each player brought (`weaponItemId`), and its
shots look like that gun (`fx/` below).
The JSON files are read with `FileAccess` (an export that filters resources must keep `*.json`).

### env/

| File | Size | Pivot / layout | Used by |
|---|---|---|---|
| `lobby_bg.png` | 1600x900 (176 KB) | stretched over the screen | `ui/backdrop.gd` (lobby, Profile, Shop, Prep) |
| `lobby_ground.png` | 1600x360 (7 KB) | the bottom 40% of the lobby screen (hill + stage ovals), transparent above | `ui/backdrop.gd` (lobby only) |
| `pedestal.png` | 400x112 (5 KB) | the feet stand at (200, 52) | lobby stage, Prep panel (drawn at 0.66x0.6) |
| `sky_match.png` | 1600x512 (29 KB) | stretched over the map plus 600 px each side (2800x900 for the default map); sun and hills included | `match/views/sky_view.gd` |
| `cloud_0..2.png` | 288x160 (6–9 KB) | centred; drawn at half size times a random 0.7–1.4 scale | `match/views/sky_view.gd` |

### terrain/ (`match/terrain/terrain.gdshader`, set by `terrain_view.gd`)

| File | Size | Layout |
|---|---|---|
| `dirt.png` | 128x128 (12 KB) | tiles both ways, one texel per world px; the shader darkens it with depth and adds the burnt crater rim |
| `grass_edge.png` | 128x24 (1 KB) | tiles horizontally. Rows 0–5: tufts in the air above a surface (row 5 touches it). Rows 6–23: the grass band from the surface down. Transparent = air (tufts) / dirt (band) |

The terrain mask stays the source of truth: the shader only decides colours per mask pixel.

### fx/ (shots: `match/views/projectile_view.gd`, `explosion_fx.gd`; looks in `match/views/shot_look.gd`)

A shot looks like the shooter's **gun**: its weapon's kind and tier (`weaponItemId` → `EquipmentModel.gun()`;
no weapon or a bot → its character's kind, `basic`). The **kind** is the bullet and the impact's theme, one
folder each; the **tier** is the intensity, from one table (`ShotLook.TIERS`) and the shared overlays in
`tiers/`, so no tier has images of its own. Visuals only: the path, timing, crater and damage are the server's.

```
fx/
  common/          smoke.png, debris.png, muzzle.png
  bazooka/         projectile.png (the bomb), trail.png, impact_0..5.png (fire explosion)   ← also every fallback
  cannon/          projectile.png, trail.png, impact_0..5.png
  shock_rifle/     projectile.png, trail.png, impact_0..5.png
  seed_launcher/   projectile.png, trail.png, impact_0..5.png
  blaster/         projectile.png, trail.png, impact_0..5.png
  tiers/           glow, sparkle, ember, coin, shard, ring, flare, crack (.png)
```

| File | Size | Notes |
|---|---|---|
| `common/muzzle.png` | 64x64 (5 KB) | a flash star: the bomb's fuse spark, the guns' muzzle flash |
| `common/smoke.png` | 128x128 (21 KB) | soft puff, light grey (tinted and faded in code) |
| `common/debris.png` | 24x24 (1 KB) | light grey chunk (tinted dirt/grass in code) |
| `bazooka/projectile.png` | 48x48 (2 KB) | the bomb: ball centred, flying towards +x, fuse behind; 2 px per world px. Fallback projectile of every kind |
| `<kind>/projectile.png` | 64x64 (1–6 KB) | centred, flying towards +x, 2 px per world px: `cannon/` heavy iron ball, `shock_rifle/` cyan plasma orb with arcs, `seed_launcher/` seed pod with a leaf, `blaster/` an energy bolt drawn **white** (the game colours it with the tier) |
| `<kind>/trail.png` | 32x32 (0.5–2 KB) | the trail particle: bazooka warm puff, cannon grey smoke, shock rifle cyan spark, seed launcher pink petal, blaster white spark (tinted) |
| `<kind>/impact_0..5.png` | 256x256 (10–71 KB) | the burst, centred, drawn for a radius-60 crater (scaled to the real radius times the tier's scale), played over 0.5 s: bazooka fire explosion, cannon heavy dark-orange blast with soot (drawn 1.2x, more debris), shock rifle electric burst, seed launcher green flash with petals, blaster white energy burst (tinted). A missing file falls back to the bazooka's |
| `tiers/glow.png` | 64x64 (2 KB) | soft round glow, white: projectile halo, impact flash, the lobby gun's glow |
| `tiers/sparkle.png` | 32x32 (1 KB) | four-point star, white: mithril / silver trails, impact sparkles (diamond's linger) |
| `tiers/ember.png` | 32x32 (1 KB) | hot ember, white: dragon / titan trails and impacts (tinted fire) |
| `tiers/coin.png` | 32x32 (1 KB) | a gold coin (own colours): gold trail and impact |
| `tiers/shard.png` | 32x32 (1 KB) | crystal shard, white: diamond trail and impact (rainbow tints) |
| `tiers/ring.png` | 256x256 (20 KB) | shockwave ring (band at 0.86 of the half size), white |
| `tiers/flare.png` | 256x256 (9 KB) | lens-flare burst (streaks, star, ghost rings), white |
| `tiers/crack.png` | 256x256 (29 KB) | dark ground cracks radiating out of a transparent middle (titan) |

Every overlay is optional: a missing one is left out. The tier table (`ShotLook.TIERS`; colours from the
guns' tier palettes, `tools/art/weapon_painter.gd` / `equipment_painter.gd`):

| Tier | Projectile | Impact |
|---|---|---|
| basic, iron | the kind's own look | the kind's burst |
| steel | 1.05x, a little glow, brighter wider trail | 1.05x, a blue flash |
| mithril | 1.1x, teal glow, sparkle trail | 1.12x, teal flash, 14 sparkles |
| dragon | 1.15x, fire glow, ember trail | 1.25x, fire flash, a shockwave ring, 22 embers |
| silver | 1.12x, silver glow, glint trail | 1.18x, a ring, 20 sparkles, a small flare |
| gold | 1.18x, golden trail, coin sparks, a hot core | 1.3x, bright flash, a ring, 18 coins, 14 sparkles, flare, faint gold screen tint |
| titan | 1.22x, heavy thick trail, embers | 1.4x, double ring, 26 embers, more debris, ground cracks, orange screen flash |
| diamond | 1.25x, rainbow glow, crystal-shard trail | 1.45x, double rainbow ring, 18 shards, 24 sparkles that linger, lens flare, screen flash |

A skill shot is 1.3x with a brighter glow and a 1.1x impact with more particles; an item shot keeps its item
tint and mark on top. Particles stay within 120 per impact and 48 per projectile.

### icons/ (96x96 each, 1–7 KB, transparent, dark outline)

| Icon | Used by |
|---|---|
| `gem`, `coin`, `plus` | wallet pills, Shop prices and gem packs |
| `characters`, `inventory`, `history`, `shop` | lobby right column |
| `arrow_left`, `arrow_right` | lobby character arrows, match move buttons, the wind direction |
| `swap` | lobby mode switch |
| `send` | lobby chat box |
| `back` | "Sảnh" buttons (Home pages, Prep) |
| `close` | match "Thoát" |
| `end_turn` | match "Hết lượt" |
| `weapon` | match "Vũ khí" |
| `skill` | match skill button, lobby / Prep skill line |
| `battle` | Prep mode pill |
| `check` | Prep: a picked item |
| `medkit`, `teleport`, `power_shot`, `drill_bomb`, `spider_net`, `freeze_bomb`, `air_strike`, `wind_stopper` | item cards (Prep, Profile inventory, Shop) and match item buttons; the file name is the item id |
| `unknown` | fallback for a missing icon or an unknown item |

### icons/equipment/ (`tools/art/equipment_painter.gd`, paths in `ui/art.gd` EQUIP_*)

| File | Size | Notes | Used by |
|---|---|---|---|
| `<slot>_<tier>.png` | 128x128 (1.5–3 KB) | one per slot × tier, transparent, dark outline. Slots `weapon`, `armor`, `helmet`, `pants`, `boots`, `gloves`; tiers `iron` (Sắt, grey), `steel` (Thép, blue steel), `mithril` (teal), `dragon` (Rồng, red + gold) for shop items, `silver` (Bạc), `gold` (Vàng), `titan`, `diamond` (Kim cương) for crafted ones. A normal item's tier comes from its name / id (`screens/home/equipment_model.gd` `tier()`); an unknown tier draws as iron | Shop → Trang bị, Túi đồ, Nhân vật slots and list, piece popup, Prep gear row |
| `weapon_<tier>.png` | 128x128 | weapons are guns: the generic blaster pistol per tier (retired generic weapons, crafted Silver/Gold/Titan/Diamond Blaster); also the empty weapon slot's shape | as above |
| `weapon_<kind>_<iron\|steel\|mithril\|dragon>.png` | 128x128 (2–4 KB) | each character's gun in the shop tiers: `bazooka` (Rookie), `cannon` (Tanko, đại pháo), `rifle` (Spark, súng điện), `launcher` (Flora, súng hạt). The kind comes from the item's `characterId` (`equipment_model.gd` `weapon_kind()`); a missing or not yet imported file falls back to `weapon_<tier>.png` | as above |
| `slot_<slot>.png` | 128x128 (1 KB) | the slot's shape in plain white; the UI tints it faint blue for an empty slot | Nhân vật slots, Prep gear row |
| `hex_empty.png`, `hex_filled.png`, `hex_selected.png` | 132x152 (7 KB) | pointy-top hexagon (radius 70) centred: empty (dark, faint rim), filled (blue, light rim), selected (gold rim + glow); stretched to the slot size | Nhân vật slots (shown at 0.85), piece popup, Prep gear row |
| `badge.png` | 52x32 | the "+N" pill (dark, gold rim); 9-patch, texture margins 15 all (`EQUIP_BADGE_MARGINS`) | upgrade level on every equipment icon |

### ui/ (9-patches, `StyleBoxTexture` via `ui/art.gd` `ui_box()`)

| File | Size | Texture margins (l, t, r, b) | Used by |
|---|---|---|---|
| `button_primary.png` | 104x110 | 36, 36, 36, 42 (+12 glow outside the button) | the big yellow buttons (BẮT ĐẦU, VÀO TRẬN, Về sảnh) |
| `button_primary_pressed.png` | 104x110 | 36, 36, 36, 42 (+12 glow) | the same, pressed |
| `button_navy.png` | 64x64 | 18 all | default Button of the Home theme (Profile, Shop, dialogs) |
| `button_orange.png` | 80x80 | 26, 26, 26, 30 | match "Hết lượt" |
| `button_disabled.png` | 64x64 | 18 all | disabled state of the textured buttons |
| `panel.png` | 72x72 | 22 all | lobby / Prep / chat panels |
| `panel_selected.png` | 64x64 | 20 all | Prep: a picked item card and a filled slot |
| `pill.png` | 56x56 | 27 all | wallet pills, "Sảnh" buttons |
| `avatar_frame.png` | 96x96 | 24 all | the frame over the lobby avatar |

Hover and pressed states are the same image, lighter or darker (`modulate`). Panels in other
colours (HUD, cards) stay plain `StyleBoxFlat` in code.
