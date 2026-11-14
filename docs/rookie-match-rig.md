# Rookie's chibi bone rig in matches

Spec: battle-squad `docs/specs/2026-11-14-nhan-vat-khung-xuong-thu.vi.md`, "Vòng 2". Client only, no
server change: aim, power and trajectories stay server-computed; only the drawing changes.

## The switch

- `scenes/character/character.gd` `match_rig` (export, default off). On, and the character has a rig
  (`scenes/character/rig/char_rig.gd` `available(id)`: `assets/characters/<id>/rig/rig.json` exists,
  today only Rookie), the character is drawn by a `CharRig` child instead of `Flip` (the side frames,
  the gun sprite, the ready pose's arm). Flip is hidden but keeps running, so `animation()`,
  `gun_state()` and the gun draw keep their states for the callers.
- Only `match/views/player_view.gd` sets it (every match mode with a map: PvP, boss, practice...).
  The lobby, character select / view, shop, profile, matchmaking card, results and the match's turn
  portrait / HUD use `ui/character_view.gd` or `portrait.png` and never set it: the old art. A
  `lobby_full` picture never uses the rig. Rookie in any outfit uses the same chibi rig.
- Tanko, Spark, Flora and Tide have no rig: unchanged (their guns keep their size).

## What drives it (the same public API the match calls)

| Character call | Rig |
|---|---|
| idle (`idle_gun`) | standing, breathing, the gun slung on the back (see "The back sling") |
| `draw_gun()` / `aim(angle)` / a remote `aim_sweep()` | the gun swings off the shoulder into the grips (`raiseSec` 0.25 s), then follows the real aim -30..90 (`rig_elevation()`, not snapped to 7 directions) |
| `shoot()` | the gun up: recoil and flash at once (returns 0); still down: raised fast (`fastRaiseSec` 0.12 s) and the aim eased onto its target, the return value is that lead-in, so the shell leaves the drawn muzzle; held up `fireHoldSec` after the shot |
| `shoot(false)` (air strike) | the body's recoil only, the gun stays on the back |
| `hurt()` | knocked back, plus the red hurt flash (tint on the whole rig); the gun stays on the back |
| `set_walking()` | the walk cycle, the gun on the back bobbing with the torso |
| `clear_aim()` / the shot's hold over | the gun swings back onto the back |
| `die()` | knees buckle, falls on its back, slid forward to lie over its feet; grey tint; the gun fades out with the fall |
| `face()` | mirrored round the feet |
| `muzzle_position()` / `fire_muzzle_position()` | the rig gun's tip now / once up on the aim at the shot's first instant |
| `set_weapon()` | the kind / tier's hug art (`Art.hug_gun()` fallbacks, so any kind) on the rig's gun socket, every kind the same length: `RigModel.GUN_LENGTH` 0.92 of the height (3/4 × 1.3, about 0.975 of the ready pose's), held and slung |
| `art_height()` | unchanged: the rig is scaled to the side view's height, so the name, HP bar, title, status effects, shield bubble, auras, badges and chat bubble keep their places |

The gun pointing 55 degrees and up (`CharRig.HEAD_OVER_DEG` on `gun_elevation()`: aiming high, or the
swing off the back) is drawn right under the head (it passes behind the head instead of over the face);
the fists stay over both; mid-swap from 30 degrees (`SWAP_HEAD_OVER_DEG`), so the swinging tube never
crosses the face. From 60 degrees up the long tube slides up through the fists (`AIM_PATH`
slide: 70 px at 80, 90 px at 90; the hands stay put), so straight up its tip shows over the cap and its
tail stays off the ground.

## The back sling

While the gun is down (idle, walk, hurt) the one gun is slung across the back, behind the whole body:
the side view's carry (`assets/characters/rookie/side/carry.json` back.scene, `Art.carry_pose()`): its
socket scaled from the side view's height to the rig's, the same point along the gun, the axis tilted
`RigModel.BACK_TILT_DEG` (-30) further back than the side view's -103 (the chibi's big head would hide a
tube at that angle), so the tube shows diagonally over the shoulder, warhead up behind the head
(`Character.rig_back()`, `RigModel.set_back()`). It rides the torso bone (breath, walk, hurt) and mirrors
with the facing. Raising, the same gun swings from the back into the grips (pivot and turn blended by the
raise; the hands' IK target slides from where they hang to the grips), behind the body until
`SWAP_FRONT` (0.4), then in the hands' layer; lowering runs it back.

## Known limits

- The swap is quick (0.25 s) and the arms' IK slides on the way: a fast swing rather than a drawn pose.
- The rig's flash is its own drawn one (`char_rig.gd` `_draw_flash()`, FLASH_SIZE), not the side view's
  muzzle sprite.

Tests: `tests/unit/test_match_rig.gd` (the switch, the muzzle on the rig gun, the head over the tube,
the events, swapped weapons, the back sling, the gun's size); the rig itself: `tests/unit/test_char_rig.gd`.
