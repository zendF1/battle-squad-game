# The chibi bone rigs in matches (Rookie, Spark, Tanko)

Specs: battle-squad `docs/specs/2026-11-14-nhan-vat-khung-xuong-thu.vi.md` (Rookie, "Vòng 2") and
`docs/specs/2026-11-14-spark-chibi-khung-xuong.vi.md` (Spark), `docs/specs/2026-11-14-tanko-chibi-khung-xuong.vi.md`
(Tanko). Client only, no server change: aim, power
and trajectories stay server-computed; only the drawing changes.

## The switch

- `scenes/character/character.gd` `match_rig` (export, default off). On, and the character has a rig
  (`scenes/character/rig/char_rig.gd` `available(id)`: `assets/characters/<id>/rig/rig.json` exists,
  today Rookie, Spark and Tanko), the character is drawn by a `CharRig` child instead of `Flip` (the side
  frames, the gun sprite, the ready pose's arm). Flip is hidden but keeps running, so `animation()`,
  `gun_state()` and the gun draw keep their states for the callers.
- Only `match/views/player_view.gd` sets it (every match mode with a map: PvP, boss, practice...).
  The lobby, character select / view, shop, profile, matchmaking card, results and the match's turn
  portrait / HUD use `ui/character_view.gd` or `portrait.png` and never set it: the old art. A
  `lobby_full` picture never uses the rig. Any outfit uses the same chibi rig.
- Flora and Tide have no rig: unchanged.

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
| `die()` | knees buckle, falls on its back (`fallDeg`: Rookie -72, Spark -82 so his spiky hair rests on the ground, Tanko -80 so his big helmet does), slid forward to lie over its feet; grey tint; the gun fades out with the fall |
| `face()` | mirrored round the feet |
| `muzzle_position()` / `fire_muzzle_position()` | the rig gun's tip now / once up on the aim at the shot's first instant |
| `set_weapon()` | the kind / tier's hug art (`Art.hug_gun()` fallbacks, so any kind) on the rig's gun socket, every kind the same length: the carry scene's Preview length (below) |
| `art_height()` | unchanged: the rig is scaled to the side view's height, so the name, HP bar, title, status effects, shield bubble, auras, badges and chat bubble keep their places |

## Layering: who is over the gun

Back to front: the far arm (upper arm, forearm, fist: it holds the tube from behind; its fist stays on
the tube's axis), the legs, the torso, the belt, the head, **the gun**, the near arm (fist, forearm,
upper arm: it hugs the tube). `rig.json` `gunUnder` is `n_fist` (the gun goes right under it). The gun
is drawn over the head at every aim: aiming high (75..90°) the tube covers the face. While it swings
from the back it is behind the whole body until `RigModel.SWAP_FRONT` (0.4 of the raise), then in that
layer.

## Aiming high

`RigModel.AIM_PATH` (or `rig.json` `aimPath`): the tube passes in front of the face at every aim. From
60° up the long tube slides up through the fists (70 px at 80°, 90 px at 90°; the hands stay put), so
straight up its warhead shows over the cap / hair and its tail stays off the ground.

The head tilts back (chin up) and the torso leans back as the aim rises: eased in from `lookUpFrom`
(45°) to 90° (`rig_motion.gd` `look_up`, following the capped aim speed), the head `headBackDeg` (24°)
and the torso `torsoBackDeg` (6°) back at 90°, both per character in `rig.json` (`RigModel.HEAD_BACK_DEG`
/ `TORSO_BACK_DEG` by default). A shot at a steep aim throws them further back for a moment
(`lookUpKick` 0.4); lowering or holstering the gun brings them back.

## The back sling and the gun's size: the carry scene

`scenes/character/poses/<id>_carry.tscn` (`carry.json` `back.scene`), read by the game at runtime
(`Art.carry_pose()` → `character.gd` `rig_back()` → `RigModel.sling()` / `set_back()`): what the scene
shows is what the match draws. Save it (`Ctrl+S`) and run: no export step.

| Node | What it is | What editing it does |
|---|---|---|
| `CarrySocket` (Node2D, grouped) | the hold point on the back; its rotation is the slung gun's angle (the chibi's back tilt is baked in: Rookie's was the side view's -103° + `BACK_TILT_DEG` -30°) | drag: the sling's place (it rides the torso); rotate: the sling's angle; scale: the gun's size, like the Preview's |
| `CarrySocket/Preview` (Sprite2D) | the character's iron hug gun, drawn behind the body exactly as the match slings it; its `offset` puts the gun's point under the socket's origin | its **scale is the single source of the gun's length**, slung and held, every kind (`RigModel.gun_length`, of the figure's height; `GUN_LENGTH` 0.92 when a character has no carry scene); its offset slides the gun along / across the socket |
| `Body` (`poses/carry_rig.gd`, mode rest) | the rig in its rest pose, at the match's scale (the side view's art height), feet at the origin | locked; nothing to edit |
| `HeldPreview` (`carry_rig.gd`, mode held) | the rig holding the gun at 0°, 45°, 90° (`aims`, `spacing`) | follows the Preview live: scale the Preview and watch the held gun's size |
| `WalkPreview` (`carry_rig.gd`, mode walk) | the rig walking in place with the gun slung | follows the socket live |

Scales: scene px are the character's px (the match's character node scales them by 0.35 /
`Art.PX_PER_UNIT` with the body size); the rig is drawn at the side view's art height / the rig's height
(rig px are half the source picture's px). The Preview's scale 2.2265 on Rookie's 285.6 px figure was
0.92 of its height (the user's own tuning in the editor since then is what the game uses).

The other per-character knobs are in `assets/characters/<id>/rig/rig.json` (written by that
character's `make_rig.py`, `RIG_TUNING`): `aimPath`, `fallDeg`, `headBackDeg`, `torsoBackDeg`.

## Known limits

- The swap is quick (0.25 s) and the arms' IK slides on the way: a fast swing rather than a drawn pose.
- The rig's flash is its own drawn one (`char_rig.gd` `_draw_flash()`, FLASH_SIZE), not the side view's
  muzzle sprite.
- Spark's hair and Tanko's helmet ride the head part (no lag of their own).
- Tanko's cannon (the hug art is 108 x 54, twice as thick as the bazooka) at the default length (0.92 of the
  height) covers most of his body held and his whole face aiming 75..90 degrees; his carry scene's Preview
  scale is the knob.

Tests: `tests/unit/test_match_rig.gd` (the switch, the muzzle on the rig gun, the gun over the head and
the far arm behind it, the head tilting back, the events, swapped weapons, the back sling, the carry
scene's gun scale setting the gun's length and muzzle; every rigged character); the rigs themselves:
`tests/unit/test_char_rig.gd`; the carry scenes: `tests/unit/test_gun_draw.gd`
`test_carry_scenes_match_the_game`.
