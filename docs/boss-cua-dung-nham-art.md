# Cua Dung Nham's drawn art in a match (2026-11-14)

Server: `battle-squad` spec `docs/specs/2026-11-13-cua-dung-nham-hinh-moi.vi.md` (only the picture
changes: same id `lava_crab`, skills, numbers, minion, arena). The art: `assets/bosses/lava_crab/`
(commit c09b4ea, `art_source/bosses/lava_crab/README.txt`). The client only replays the events; this
note is what it draws and why. Wired like Khổng Lồ Đá (`docs/boss-khong-lo-da-art.md`) and Mộc Tinh
(`docs/boss-moc-tinh-art.md`): the same points per frame, skin glow / eyes, no hover, BossAnim mapping,
BossArt.DEATH.

## Standing, glow, eyes, walking

- It stands on its legs: its skinned idle (`skin.json` motion `breath`) does not float
  (`SkinIdle.hovers()` false), the frames do not bob.
- The skin's glow follows `glowBone` body in `glowColour` ember (`BossArt.EMBER`, 1.0 / 0.55 / 0.16): the
  shell's middle; its two `eyes` flicker (`SkinIdle.eyes()`).
- Walking along the ground (PlayerView sees its x change: the pincer's crawl `move`, `_path_walk` in
  `match/match_screen.gd`) it plays its `walk` loop (8 frames, 12 fps: the sideways scuttle in place
  while the game moves it), back to the idle when it stops: `BossBody.set_walking()` sets
  `BossAnim.set_walking()`, whose base state is fly (flying) > walk (walking) > prime (a primed bomber)
  > idle, each only when the art has it. The code art (no frames) keeps its step wobble.

## Points per frame

- `side/points.json` (`Art.boss_points()`): per frame `heart`, `shellTop` (where the bombs burst out),
  `eyes`, `clawL` / `clawR` (the claws' grips), `knuckle`, the drips' tips `drip_fl` / `drip_cl` /
  `drip_fr` / `drip_p1` / `drip_p2`, the levels `glow` / `eyesLit`; unit frame (body 100, feet at the
  origin, facing right).
- `heart_position()` and the heal's light: the shown frame's heart, the light ember
  (`BossArt.heart_light()`).
- `muzzle_position()`: the shown frame's `shellTop` while fire_bombs shows (`BossArt.MUZZLE_FOLLOW`),
  else `BossArt.MUZZLE` (5.63, −76.06).
- `BossArt`: HEART (7.51, −51.96), MUZZLE the shell top, TOP 1.0 (the raised left claw; fire_bombs'
  raised claws reach about 1.1, under the name), WIDTH 1.768 (the status effects' width, the shield
  ball), ACCENT unchanged. Mirrored (it faces left toward the party) it reads the same.

## Skills → animations (`BossAnim`)

| skill (`skillId`) | animation | peak on |
|---|---|---|
| fire_bombs | fire_bombs | the first bomb leaving (the projectiles); at the peak frame a spout of lava globs shoots up out of the shell top (`BossArt.SPOUT`, drawn by LavaDrips), the bombs then fall from the sky as before |
| claw_slam | claw_slam | the slam's `explode` (the first one: `PEAK_ON`); its peak frame throws basalt chips, embers and dust up at the claw's impact (`BossArt.STOMP` foot = rig_v1.json slamImpact (81.69, 0.31), no ring of its own); the game's shockwave (`ShockwaveFx`) opens its slam ring there (`slammer` = the boss figure, `slam_point()`), the ripples and craters stay on the server's positions |
| pincer | pincer | the `pincer` event; it starts only `PEAK_LEAD` 0.45 s before it (`delay`: the crab crawls first on its walk loop, then reaches and snaps); without a pincer event (out of reach) no animation, it only crawls (`NEEDS_PEAK`) |
| summon (crab_call) | summon | the first `summon` |
| a hit | hurt | |

The grab: `PincerFx` gets `drawn` when the crab is drawn from frames: no code claw (the drawn pincer
snaps at the same moment), the grab reads on the member as two hot jaw arcs closing onto it, the
white clack ring and sparks, the member's jolt. The server stops the crab
`playerHitRadius × (bodySize + 1) + 6` px from its target (about 107 px at bodySize 3.2), while the
drawn grip at the peak is 1.2 body heights (about 220 px) in front of the feet: the drawn claw closes
past the member, over its head; the jaw arcs carry the grab onto the member. A future frame redraw
with a shorter reach would line them up.

## Lava drips

Now and then (every 0.45–1.3 s, `BossArt.DRIPS`) a drop swells off one of the drips' tips of the
shown frame, falls with gravity (stretched along its speed), lands on the ground and sizzles (a flat
glow spreading and cooling, a wisp of steam) (`match/boss/lava_drips.gd`, drawn over the figure by
BossBody). Alive only. Client only, cosmetic.

## Death: cool (`BossArt.DEATH` "cool")

`death_phase()`: `cool` (death frames 0–4: the lava cools to grey stone, cracks, the legs buckle, the
claws droop; grey smoke puffs rise off the shell, `COOL_SMOKE_EVERY`) → `split` (`COOL_HOLD` 0.3 s
after frame 4 shows, the 16 parts of `parts/` take over, posed as that frame; the frame stays over them
`COOL_COVER` 0.22 s, fading, so the cut edges never show assembled; the shell's two halves topple apart
(`COOL_TOPPLE`, sliding out and settling), the claws and pincers drop off tumbling (`COOL_PARTS`), the
legs slump outward (`COOL_LEG`), all settle on the ground; a smoke burst and embers out of the crack;
`COOL_FALL` 1.5 s) → `fade` (`COOL_FADE` 0.7 s) → `gone`. The witch keeps her shatter, the saucer its
crash, the giant its crumble, the tree its wither.

## Cua con (minion `crab`)

- Its art: `assets/bosses/lava_crab/minion/` (`ui/art.gd` `MINION_DIRS`: art id `crab` →
  `lava_crab/minion`; `Art.boss_dir()`), side canvas 309×192, pivot (137, 186), height 160; idle 8
  (8 fps), walk 8 (14 fps), prime 4 (10 fps), hurt 2; the same point keys. `tools/export_check.gd`
  lists it (`minion` lines, compared by `tools/check_export.sh`).
- Its size comes from the game data: bodySize 0.75 → 40 × 0.75 × 1.45 ≈ 43.5 px (the raised claw's
  top), 1.768 × that wide; HEART as the boss's; MUZZLE (16, −43): its mouth under the eyes, where
  `crab_spit` leaves.
- It walks on its walk loop (bomber, movement walk). Warned (a party member within its
  detonateRange) or primed (its detonation's lead-in) it plays `prime` (shaking, swelling, the lava
  blazing) and its frames get the bomber's red pulse (`BomberModel.pulse()`) through the frame
  shader's `tint` (half way to `BossArt.WARN_RED`, as the code art); `prime()` still swells and
  flashes it. Its detonation and death blast are unchanged.
- It dies fading (`BossArt.DEATH` "fade"): its hurt frame sinks, tilts and fades like the code art
  (not the witch's icy shatter).

The code-drawn `_crab()` / `_claw()` stay as the fallback (no frames).

Tests: `tests/unit/test_boss_crab_art.gd`.
