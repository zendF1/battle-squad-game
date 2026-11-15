# The chibi bone rigs in matches (Rookie, Spark, Tanko, Flora, Tide)

Specs: battle-squad `docs/specs/2026-11-14-nhan-vat-khung-xuong-thu.vi.md` (Rookie, "Vòng 2") and
`docs/specs/2026-11-14-spark-chibi-khung-xuong.vi.md` (Spark), `docs/specs/2026-11-14-tanko-chibi-khung-xuong.vi.md`
(Tanko), `docs/specs/2026-11-14-flora-chibi-khung-xuong.vi.md` (Flora), `docs/specs/2026-11-15-tide-chibi-khung-xuong.vi.md`
(Tide), and the final set `docs/specs/2026-11-15-bo-chibi-chot.vi.md` (all five re-cut from the user's final
pictures, the frame run). Client only, no server change: aim, power and trajectories stay server-computed;
only the drawing changes.

## Picture, bones and frames (the user's split)

- **Standing** is the user's final chibi picture itself (`art_source/characters/<id>/side_idle/idle_final.png`:
  the rig at rest reproduces it, with a gentle breathing), the gun slung on the back.
- **The bones** move only for the gun (drawn off the back and aimed -30..90), the shot (recoil), a hit
  (hurt) and the fall (die).
- **Walking moves no bone.** It plays the run frames (`assets/characters/<id>/rig/run.json` +
  `run/run_<i>.png`, `char_rig.gd` `load_run()` / `run_frames_shown()`): the parts are hidden, the frame drawn
  over the slung gun (which rides the frame's `bob`), at `fps` (12); a hit while running shows the rig's hurt
  for `RUN_HURT_SEC` (0.6 s), then the frames again. **Until a character has run frames** (none yet), walking
  shows the standing picture lifting a little with each step (`rig_motion.gd` `walkBob` 6 rig px, the whole
  figure, never under the ground), arms and legs still. Frames switch on by themselves once `run.json` exists.
- **The run stops the moment the walk does** (2026-11-16). `player_view.gd` reads walking from the walk
  itself (`WalkPath.striding()`), not from x changes: the local player's walk (`follow_walk()`, MoveSync's
  prediction) runs only while the move button is down (`hold_walk()`, set by `match_screen.gd` every frame);
  let go, the run frames go within a frame (`run_frames_shown()` needs `motion.walk_target > 0`, so the 0.18 s
  blend out no longer keeps them) and the few px the drawn walk trailed the prediction ease in standing
  (`WalkPath.settle()`, a correction's `SETTLE_SEC`; a fall still ahead is walked and drawn as it is). A
  server answer moving it after the release eases in standing too. Another player's walk (`walk_to()`)
  runs while it walks and stands for its last step (`STRIDE_STEPS` 1 px) of ease-in. Tweens and flights
  (knockback, a shot's fall, a jump) still count as walking from their x changes (`WALK_HOLD` 0.12 s).
  Measured (`tests/unit/test_walk_stop.gd`, 60 fps): release to idle 0.68 s before (the drawn walk trails
  the prediction by ~6 px and crawled in for 0.48 s, + `WALK_HOLD`, + the blend), now the first frame.
- **Every move input walks** (`match_screen.gd`): the on-screen arrows (`_connect_moves()`), and from
  `_input()` (before the GUI, which would move the focus with them; not while the chat field has the
  focus) the arrow keys and gamepad d-pad / stick (`ui_left` / `ui_right`) and A / D; the newest one held
  wins, letting it go hands over to one still down. All set `_hold_dir`, which `_step_my_walk()` turns
  into MoveSync's prediction and `hold_walk()`. Before this the match read no keys at all.

### Where the run frames go

The user's run pictures: `art_source/characters/<id>/side_run_v2/sheet.png` (8 frames as a 4 x 2 grid of
equal cells, thin light-grey borders, white gutters, read left to right, top row first) or the frames cut
already, `frame_1.png` .. `frame_8.png`. White (or transparent) background, facing right, the character
about 80 % of the cell's height, **no gun** (the game draws the slung gun behind the frames). Then:

    python3 -I art_source/characters/make_run_frames.py <id>     # [--fps 12] [--scale 1.0] [--debug DIR]

From a video (the way the run frames are made now, 2026-11-16): an AI image-to-video clip of the idle picture
running in place, camera locked, plain white background. One command finds the cleanest loop (any length,
14-40 video frames: no fixed frame count), writes every frame of it as side_run_v2/frame_1..N.png and imports
it at the video's fps:

    python3 -I art_source/characters/cut_run_video.py <id> <video.mp4>   # [--min 14] [--max 40] [--no-import]


It cuts the cells (by the white gutters, else 4 x 2 equal cells), keys the white by flood from each cell's
border (the near-white clothes inside their outlines stay; an enclosed gap between an arm and the body stays
white unless listed in `side_run_v2/holes.json` `{"frame_3": [[x, y]]}`), scales so the tallest frame is as
tall as the standing rig (`--scale` to change), puts every frame's lowest px on the ground and its head's
centre over the standing head's, and writes `assets/characters/<id>/rig/run/run_<i>.png` (rig px, with
their `.import` files) and `run.json`. Focus the editor so it imports them. Delete `run.json` and `run/` to go
back to the standing picture's step lift.

## The switch

- `scenes/character/character.gd` `match_rig` (export, default off). On, and the character has a rig
  (`scenes/character/rig/char_rig.gd` `available(id)`: `assets/characters/<id>/rig/rig.json` exists,
  today all five: Rookie, Spark, Tanko, Flora and Tide), the character is drawn by a `CharRig` child instead of `Flip` (the side
  frames, the gun sprite, the ready pose's arm). Flip is hidden but keeps running, so `animation()`,
  `gun_state()` and the gun draw keep their states for the callers.
- Only `match/views/player_view.gd` sets it (every match mode with a map: PvP, boss, practice...).
  The lobby, character select / view, shop, profile, matchmaking card, results and the match's turn
  portrait / HUD use `ui/character_view.gd` or `portrait.png` and never set it: the old art. A
  `lobby_full` picture never uses the rig. Any outfit uses the same chibi rig.
- Every character has a rig now; an id without `rig.json` would keep its side frames.

## What drives it (the same public API the match calls)

| Character call | Rig |
|---|---|
| idle (`idle_gun`) | standing, breathing, the gun slung on the back (see "The back sling") |
| `draw_gun()` / `aim(angle)` / a remote `aim_sweep()` | the gun swings off the shoulder into the grips (`raiseSec` 0.25 s), then follows the real aim -30..90 (`rig_elevation()`, not snapped to 7 directions) |
| `shoot()` | the gun up: recoil and flash at once (returns 0); still down: raised fast (`fastRaiseSec` 0.12 s) and the aim eased onto its target, the return value is that lead-in, so the shell leaves the drawn muzzle; held up `fireHoldSec` after the shot |
| `shoot(false)` (air strike) | the body's recoil only, the gun stays on the back |
| `hurt()` | knocked back, plus the red hurt flash (tint on the whole rig); the gun stays on the back |
| `set_walking()` | no bones: the run frames over the slung gun, or (no frames yet) the standing picture lifting with each step |
| `clear_aim()` / the shot's hold over | the gun swings back onto the back |
| `die()` | knees buckle, falls on its back (`fallDeg`: Rookie -75 so the back of his cap rests on the ground, Spark -89 so his spiky hair does, Tanko -79 so his big helmet does, Flora -71 so the back of her head does, Tide -73 so the back of her big bob does, the heels on or just off the ground), slid forward to lie over its feet; grey tint; the gun fades out with the fall |
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

`RigModel.AIM_PATH` (or `rig.json` `aimPath`): the tube passes in front of the face at every aim. The long
tube slides up through the fists (the hands stay put), so straight up its warhead shows over the cap / hair
and its tail stays off the ground. The five rigs (about 380 px tall) carry their own rows: the default's at
their size, the slide starting at 30° (18 px, 36 at 45°, 55 at 60°, 81 at 80°, 105 at 90°).

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
| `WalkPreview` (`carry_rig.gd`, mode walk) | walking in place with the gun slung (the run frames, or the standing picture lifting with each step) | follows the socket live |

Scales: scene px are the character's px (the match's character node scales them by 0.35 /
`Art.PX_PER_UNIT` with the body size); the rig is drawn at the side view's art height / the rig's height
(rig px are a third of the source picture's px). The final pictures kept every carry scene's socket and
Preview: the slung guns sit on the new backs as they were (no edit). Without a carry scene the sling is
`RigModel.BACK_POS` scaled to the figure's height. The Preview's scale 2.2265 on Rookie's 285.6 px figure was
0.92 of its height (the user's own tuning in the editor since then is what the game uses).

The other per-character knobs are in `assets/characters/<id>/rig/rig.json` (written by that
character's `make_rig.py`, `RIG_TUNING`): `aimPath`, `fallDeg`, `headBackDeg`, `torsoBackDeg`.

## Known limits

- The swap is quick (0.25 s) and the arms' IK slides on the way: a fast swing rather than a drawn pose.
- The rig's flash is its own drawn one (`char_rig.gd` `_draw_flash()`, FLASH_SIZE), not the side view's
  muzzle sprite.
- Spark's hair, Tanko's helmet, Flora's bandana with its two tails and Tide's bob ride the head part (rigid, no lag
  of their own).
- Lying down a hanging fist can touch the ground line by a px or two (only the head and back points rest on it).
- Her water gun (a thick tube with a tank on top) at the default
  length covers her body held, and her face from 75°; her carry scene's Preview scale is the knob.
- Tide's hands are open (her picture's): held, the near palm lies on the tube, fingers up across it; no
  separate gripping hand is drawn.
- Tanko's cannon (the hug art is 108 x 54, twice as thick as the bazooka) at the default length (0.92 of the
  height) covers most of his body held and his whole face aiming 75..90 degrees; his carry scene's Preview
  scale is the knob.

Tests: `tests/unit/test_match_rig.gd` (the switch, the muzzle on the rig gun, the gun over the head and
the far arm behind it, the head tilting back, the events, swapped weapons, the back sling, the carry
scene's gun scale setting the gun's length and muzzle, standing as the picture and the bones only for the
gun / hit / fall, walking without frames lifting the picture, run frames replacing the parts; every rigged
character); the rigs themselves (walking moves no bone):
`tests/unit/test_char_rig.gd`; the carry scenes: `tests/unit/test_gun_draw.gd`
`test_carry_scenes_match_the_game`.
