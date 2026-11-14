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
| idle (`idle_gun`) | standing, breathing, the gun slung on the back |
| `draw_gun()` / `aim(angle)` / a remote `aim_sweep()` | the arms raise to the grips, the gun follows the real aim -30..90 (`rig_elevation()`, not snapped to 7 directions) |
| `shoot()` | the gun up: recoil and flash at once (returns 0); still down: raised fast (`fastRaiseSec` 0.12 s) and the aim eased onto its target, the return value is that lead-in, so the shell leaves the drawn muzzle; held up `fireHoldSec` after the shot |
| `shoot(false)` (air strike) | the body's recoil only, the gun stays down |
| `hurt()` | knocked back, plus the red hurt flash (tint on the whole rig) |
| `set_walking()` | the walk cycle (the gun on the back) |
| `die()` | knees buckle, falls on its back, slid forward to lie over its feet; grey tint |
| `face()` | mirrored round the feet |
| `muzzle_position()` / `fire_muzzle_position()` | the rig gun's tip now / once up on the aim at the shot's first instant |
| `set_weapon()` | the kind / tier's hug art (`Art.hug_gun()` fallbacks, so any kind) on the rig's gun socket, every kind 3/4 of the ready pose's length |
| `art_height()` | unchanged: the rig is scaled to the side view's height, so the name, HP bar, title, status effects, shield bubble, auras, badges and chat bubble keep their places |

Aiming 55 degrees and up (`CharRig.HEAD_OVER_DEG`) the tube is drawn right under the head (it passes
behind the head instead of over the face); the fists stay over both.

## Known limits

- Aiming near vertical (about 80-90 degrees) the tube's top sits behind the cap: the warhead is hidden
  and the shell and flash appear over the head. The chibi's short arms cannot hold the tube far enough
  back or high enough to clear the cap (`rig_model.gd` AIM_PATH).
- The rig's flash is its own drawn one (`char_rig.gd` `_draw_flash()`, FLASH_SIZE), not the side view's
  muzzle sprite.

Tests: `tests/unit/test_match_rig.gd` (the switch, the muzzle on the rig gun, the head over the tube,
the events, swapped weapons); the rig itself: `tests/unit/test_char_rig.gd`.
