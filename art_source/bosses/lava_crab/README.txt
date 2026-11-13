Cua Dung Nham (boss id lava_crab): the boss's drawn art, and its Cua con (minion id crab).

The one source picture (the user's, AI-drawn on flat sky blue with a darker blue ground-shadow
ellipse and the ✦ watermark at the bottom right; kept as it is):
  concept/lava_crab_v1.png   1380 x 752: the crab, a dark basalt shell cracked with glowing orange /
                             yellow lava, a stony face with angry yellow eyes, two big claws (the left
                             one raised, the right one held out) with curved upper pincers and lava
                             dripping off them, segmented legs with lava rings (four drawn); 3/4 VIEW
                             FACING RIGHT, standing

Every other picture is made from it by make_frames.py here (no AI sheets exist for this boss; the
prompts for them, if wanted later, are in PROMPTS.md). Hard shell on hinges: rigid cut-out parts turned
round their joints (as Khổng Lồ Đá), the legs posed by a two-bone IK onto their tips (planted while the
shell moves, stepped by the walk), four far legs added behind the shell (the drawn legs' copies, shaded:
eight legs). The rest pose lowers the crab 44 px onto its legs so their tips reach one ground line
(the picture's far legs stood higher, in perspective).
  side_<anim>/sheet_v1.png   one row per animation, transparent, fixed 780 x 490 cells, the feet (the
                             middle of the legs' ground contact) at (320, 465) of every cell, the body
                             (the raised left claw's top to the ground) 319.5 px (half the source):
                             idle 12 (6 fps, loops: the shell breathes, the lava cracks pulse, the
                               claws sway, the upper pincers open / close a little, each of the five
                               drips stretches and lets a drop fall once a loop, the eyes blink: half
                               7, shut 8, half 9),
                             walk 8 (12 fps, loops: the sideways scuttle in place, the legs in two
                               alternating groups (a, d + far b, c / b, c + far a, d), stance tips
                               sliding back to the left, swing tips lifted forward; the shell bobs twice
                               a loop and rocks; meant to loop while the game moves it),
                             fire_bombs 8 (10 fps, peak 4: crouch (1), both claws rise and spread in
                               a V, the lava blazing (2-3), a column of lava globs bursts out of the
                               shell's top at the peak (4: the bombs leave there, shellTop), smaller
                               (5), settle),
                             claw_slam 9 (10 fps, peak 4: the right claw lifts high on the right side
                               (1-3), slams onto the ground in front at the peak (its knuckle on the
                               ground line), held (5), lifts back),
                             pincer 8 (10 fps, peak 5: the crab lunges right, the right claw reaches
                               far out with the upper pincer opening wide (1-4), snaps shut at the peak,
                               held (6), pulls back (7)),
                             summon 7 (8 fps, peak 3: the shell shakes left / right, the pincers open,
                               the lava flares brightest at the peak),
                             hurt 2 (7 fps: jolted back, the claws flung up, the eyes squeezed; then
                               half recovered; the game draws the white flash),
                             death 5 (6 fps: jolted (0), then the lava cools to grey stone, dark cracks
                               split the shell and the claws, the eyes go dark, the legs buckle outward
                               and the shell sinks low, the claws droop onto the ground, smoke puffs
                               rise (1-4); the game may then break it into parts/)
                             Facing: right (the face and the reaching claw); mirrored it reads the
                             same (no text; only the raised claw swaps sides).
  skin/rest_v1.png           the rest pose at full size in one cell (the feet at (640, 930)): the
                             skinned idle's picture
  portrait/portrait_v1.png   the rest pose, claws a little raised, pincers open, the lava bright (the
                             Boss tab card, the matchmaking card)
  portrait/bust_v1.png       the shell with the face, faded at the sides and under the face (the HP
                             bar icon, the turn portrait)
  parts/<piece>_v1.png       the death's pieces in death frame 4's pose, one full cell each (same feet),
                             back to front: leg_a_lo, leg_a_up, leg_c_lo, leg_c_up, leg_d_lo, leg_d_up,
                             shell_r, shell_l (the shell split along its middle crack), arm_l, leg_b_lo,
                             leg_b_up, claw_l, finger_l, arm_r, palm_r, finger_r (the claws with their
                             cooled drips; every cut edge outlined); drawn together they are death
                             frame 4 without the far legs and the smoke
  minion/side_<anim>/sheet_v1.png  Cua con: the same crab and cells, its basalt warmed to red-brown and
                             its lava brighter: idle 8 (8 fps, loops), walk 8 (14 fps, loops: a faster,
                             higher scuttle), prime 4 (10 fps, loops: shaking, swelling, the lava blazing:
                             about to blow up), hurt 2 (7 fps)
  minion/import.json         its importer config (height 160: half the boss's), written by the script
  rig_v1.json                the points (the unit frame) and the width
  import.json                the importer's config, written by the script (do not edit by hand)

How it is made (make_frames.py header): the sky blue and the shadow ellipse keyed by colour (the crab
has no blue), each edge px un-mixed against its own nearest backdrop colour (the drips over the sky keep
a clean dark orange rim, no blue in it), the light ringing outside the outline and specks cleared, the
✦ painted out first; a rough polygon per part (PARTS) seeds a watershed over the picture's darkness so
the cuts follow the drawn outlines (smoothed; a plate's cut through flat colour gets its own outline);
the hidden areas painted under the parts in front (UNDER: the shell under the claws, the palms and the
lava under the upper pincers, the legs' tops); the drips cut out of their claws (lava colour), hanging
down whatever the claw does. A frame: the skeleton posed (RIG: root → body → arm → claw / palm → upper
pincer, the drips on their claw; the legs by IK onto REST_TIPS + the pose's tips; the far legs FAR
offsets), then the fx (glow / blaze of the lava, cool to stone, eyes, cracks, drops, spout, smoke).

Make and import (in the battle-squad-game folder; the editor may stay open):

  python3 -I art_source/bosses/lava_crab/make_frames.py [--debug /some/dir [--check | --preview walk,pincer,minion]]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- lava_crab lava_crab/minion [--contact=/some/dir/contact.png]

(The minion's config sits in minion/: name it, `lava_crab/minion`; an import with no ids imports only
the top-level art_source/bosses/*/import.json.)

The script also writes assets/bosses/lava_crab/side/points.json and minion/side/points.json (per frame
of every animation, in the unit frame: heart, shellTop, eyes, clawL, clawR (the pincer's grip),
knuckle (the slam's striking point), drip_fl / drip_cl / drip_fr / drip_p1 / drip_p2 (the drips' tips),
glow, eyesLit). The import (import.json: background.key "alpha", the cells as cuts, the feet as anchors,
bodyHeight 319.5 → height 320 texture px) writes assets/bosses/lava_crab/side/<anim>_<i>.png +
side.json (canvas 690 x 431, pivot (279, 423)), portrait.png (512), bust.png (384), parts/<piece>.png +
parts/parts.json (each piece's top-left from the feet and its z, back to front), skin/idle/ (body.png
651 x 375, the body 360 px; skin.json: the mesh, bones (body, arms, claws, upper pincers, the legs),
weights and the breath's tracks (motion "breath": it stands, no float), glow = the shell's middle with
glowBone "body" and glowColour ember (1.0, 0.55, 0.16), eyes); the minion: assets/bosses/lava_crab/
minion/side/<anim>_<i>.png + side.json (canvas 309 x 192, height 160).

The numbers (unit frame: the body 100 tall = the raised left claw's top to the ground at rest, the feet
at the origin, facing right, y down): heart (7.51, -51.96); the eyes (1.53, -49.46) and (25.26, -51.47);
the bombs' burst (shellTop) (5.63, -76.06) at rest, (5.63, -81.65) at fire_bombs' peak; the slam's
impact (81.69, 0.31) at claw_slam's peak; the pincer's grip (119.78, -23.98) at pincer's peak; width
1.768 of the height; the left claw's top 1.0 (fire_bombs' raised claws reach about 1.1).

Changing an animation: edit ANIMS in make_frames.py (pose(): root, body (dx, dy, rot, sy), arm_l /
claw_l / arm_r / palm_r (+ raises), finger_l / finger_r (+ opens), reach, lift_l / lift_r, tips, drips;
fx: glow, blaze, cool, eyes, crack, drops, spout, smoke) and re-run both commands. A new concept picture:
re-check PARTS, BODY, DRIPS, EYE_BOXES, the joints J and REST_TIPS with --debug --check (parts_map.png,
part_*.png, rest_diff.png) first.
