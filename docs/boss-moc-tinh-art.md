# Mộc Tinh's drawn art in a match (2026-11-14)

Server: `battle-squad` spec `docs/specs/2026-11-13-moc-tinh-hinh-moi.vi.md` (only the picture
changes: same id `tree_spirit`, skills, numbers, poison mushrooms, arena). The art:
`assets/bosses/tree_spirit/` (commit 0397862, `art_source/bosses/tree_spirit/README.txt`). The client
only replays the events; this note is what it draws and why. Wired like Khổng Lồ Đá
(`docs/boss-khong-lo-da-art.md`): the same points per frame, skin glow / eyes, no hover, BossAnim
mapping and fallback, BossArt.DEATH.

## Standing, glow, eyes, leaves

- It stands on its roots: its skinned idle (`skin.json` motion `breath`: the canopy clumps, twigs and
  side roots sway) does not float (`SkinIdle.hovers()` false), the frames do not bob.
- The skin's glow follows `glowBone` trunk in `glowColour` mint (`BossArt.MINT`, 0.6 / 1.0 / 0.78): the
  heart on the trunk under the mouth; its two `eyes` flicker (`SkinIdle.eyes()`).
- Now and then (every 2.4–5 s, `BossArt.LEAVES`) a leaf (green or lilac) falls off one side of the
  canopy, flutters down beside the trunk, lies a moment and fades (`match/boss/falling_leaves.gd`,
  drawn over the figure by BossBody). Client only, cosmetic.

## Points per frame

- `side/points.json` (`Art.boss_points()`): per frame `heart`, `canopy` (where the thorns leave),
  `eyes`, `mushrooms`, the levels `glow` / `eyesLit` (kept as floats) and `rootTip` (root_drag frames
  1–6, on the ground line), unit frame.
- `heart_position()` (the drain's end: LifeStreamFx DRAIN and REGEN end there) and the heal's light on
  the heart: the shown frame's heart, the light mint (`BossArt.heart_light()`; the giant's gem stays
  amber). The heal's green halo behind the figure is kept round the body (not sunk under the ground
  by the tree's low heart).
- `muzzle_position()`: the shown frame's `canopy` while poison_thorns shows (`BossArt.MUZZLE_FOLLOW`,
  as the giant's throwing knuckles), else `BossArt.MUZZLE` (0, −85.19). The thorns (`poison_thorn`)
  are drawn leaving the canopy and ease onto the server's paths (`boss_global.gd`, `UnitShell.lead`).
- `root_tip_position()`: the dragging root's tip while root_drag shows it (Vector2.INF otherwise).
- `BossArt`: HEART (0.85, −21.65), MUZZLE (0, −85.19), TOP 1.0 (the drawn canopy: the name sits just
  over it), WIDTH 1.067 (the status effects' width, the shield ball), ACCENT mint (the HUD bar's name,
  the shield's tint, matching its glows). The code art (no frames) keeps its shadow (58).

## Skills → animations (`BossAnim`)

| skill (`skillId`) | animation | peak on |
|---|---|---|
| vine_lash | vine_lash | the `ground_strike` event (the vines burst under the members) |
| poison_thorns | poison_thorns | the first thorn leaving (they leave the canopy) |
| life_drain | life_drain | the first `beam`, held over it (`BEAM_HOLD`, like the witch's burst); the second swell after |
| root_drag | root_drag | the `pull` event: the root at full reach, held 0.75 of the pull's duration (`PEAK_HOLD`), yanked back as the member arrives |
| summon (mushrooms) | summon | the first `summon` |
| a hit | hurt | |

`BossAnim.FALLBACK` lists per missing animation the ones to try: a plain `cast` (or `blizzard`) →
throw (the giant) or poison_thorns (the tree); `burst` → throw or life_drain.

RootDragFx: when the drag ends within `JOIN_PX` (360 px) of the tree's drawn root tip
(`RootDragFx.tree`, the boss's view), the ground root runs on along the ground into that tip (no knot
diving in), so the two read as one root; farther away it dives into the ground past the drag's end as
before.

## Death: wither (`BossArt.DEATH` "wither")

`death_phase()`: `wither` (death frames 0–3: the leaves brown and fall, the glows go out, the bark
cracks; withered leaves shower off the canopy, `WITHER_LEAF_EVERY`) → `drop` (`WITHER_HOLD` 0.25 s after
frame 3 shows, the 11 parts of `parts/` take over, posed as that frame; the frame itself stays drawn
over them for `WITHER_COVER` 0.22 s, fading, so the pieces' cut-edge outlines never show assembled
across the canopy; the four canopy clumps and the two twigs drop off one after another
(`WITHER_DROP`), pushed out to the sides, tumbling slowly, settle on the ground with a dust puff; the
trunk, the side roots and the outer roots stay and sag toward the feet (`WITHER_SAG` 6 %); a shower of
withered leaves and a little dust at the foot; `WITHER_FALL` 1.5 s) → `fade` (`WITHER_FADE` 0.7 s, the
leaves with it) → `gone`. The witch keeps her shatter, the saucer its crash, the giant its crumble.

Tests: `tests/unit/test_boss_tree_art.gd`.
