# Khổng Lồ Đá's drawn art in a match (2026-11-14)

Server: `battle-squad` spec `docs/specs/2026-11-13-khong-lo-da-hinh-moi.vi.md` (only the picture
changes: same id `rock_giant`, skills, numbers, totems, arena). The art: `assets/bosses/rock_giant/`
(commit ed0b5db, `art_source/bosses/rock_giant/README.txt`). The client only replays the events;
this note is what it draws and why.

## Standing, glow, eyes

- It stands on its feet: its skinned idle (`skin.json` motion `breath`) does not float
  (`SkinIdle.hovers()`: only a motion `idle` skin, the witch's, floats); the frames do not bob either.
  Same in the boss card / matchmaking picture (`BossArtView`).
- The skin's glow follows `glowBone` (torso) in `glowColour` (amber): the chest gem; the witch keeps
  the staff and the cyan. Its `eyes` get a flicker (`SkinIdle.eyes()`: a slow pulse, a quick
  flicker, dimmed once a loop with the eye shaded over), carried by the head bone.

## Points per frame

- `side/points.json` (`Art.boss_points()`): per frame the gem (`heart`), the throwing knuckles
  (`hand_r`) and the plates' joints (`chest`, `pauldron_l/r`, `pelvis`, `head`: x, y, degrees) in the
  unit frame; `restJoints`.
- `heart_position()` (the drain's end) and the heal glow: the shown frame's gem.
- `muzzle_position()`: the shown frame's knuckles while a throw shows, else `BossArt.MUZZLE` (the
  throw's peak, 63.95, −74.94). The boulder itself leaves from where the server starts it.
- `BossArt`: HEART (6.67, −50.91), TOP 1.0 (the horns: the name sits just over them), WIDTH 0.92
  (the status effects' width, the shield ball). The code art (no frames) keeps its shadow (58).

## Totem plates

- `BossArt.FRAME_PLATES`: five stone slabs (the shoulder pads, the chest either side of the gem, the
  belt) at their rest centres, each carried by its joint (`frame_plate_pose()`: moved by the joint's
  move from rest and turned round it), drawn over the frame or the skin (on the skin by the bone
  carrying that joint, `BossBody.SKIN_BONE`) by the `Plates` node, under the shield ball. Pop-on and
  break-off as before (`PLATE_BREAK_SEC`); they also break off when it dies.

## Skills → animations (`BossAnim`)

| skill (`skillId`) | animation | peak on |
|---|---|---|
| giant_boulder (boulder_rain, older) | throw | the boulder leaving |
| rolling_boulder | roll | the boulder thrown down |
| earthquake | stomp | the `global` event; at the peak frame dust bursts at the right foot (`BossArt.STOMP`) with pebbles and the game's shockwave ring (`ShockwaveFx`, slam only) |
| stone_spikes | spikes | the first `mark`; on its turn start (actionMode `turn_start`) again on the first `eruption` |
| summon (totem_raise) | summon | the first `summon` |
| a hit | hurt | |

An animation the boss lacks falls back (`BossAnim.FALLBACK`: a plain shot's `cast` → throw).

## Death: crumble (`BossArt.DEATH` "crumble")

`death_phase()`: `crack` (death frames 0–1, the drawn amber cracks) → `crumble` (from death frame 2,
`CRUMBLE_SWAP_FRAME`: the 18 parts of `parts/`, posed as that frame, drawn by their z; they fall
with gravity, pushed out a little from the gem, spinning, bounce once and settle on the ground at a
small depth by z; the helmet `HELMET_DELAY` and the horns `HORN_DELAY` (0.4 s) later, tumbling off;
a dust burst and pebbles at the swap, a puff under each heavy landing; `CRUMBLE_FALL` 1.6 s) →
`fade` (`CRUMBLE_FADE` 0.6 s) → `gone`. The witch keeps her shatter, the saucer its crash; the
stone totems their own crumble.
