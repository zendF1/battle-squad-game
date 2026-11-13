Khổng Lồ Đá (boss id rock_giant): the boss's drawn art.

The one source picture (the user's, AI-drawn on flat sky blue with a darker blue ground-shadow
ellipse and the ✦ watermark at the bottom right; kept as it is):
  concept/ram_golem_v1.png   1380 x 752: the brown stone giant in grey-trimmed ancient armour, the
                             helmet with glowing yellow eyes, the golden ram horns, the amber chest
                             gem, the carved chest bands and belt, big fists; FRONT view, standing

Every other picture is made from it by make_frames.py here (no AI sheets exist for this boss; the
prompts for them, if wanted later, are in PROMPTS.md). The figure is cut into parts and posed on a
skeleton (rigid cut-out parts turned round their joints):
  side_<anim>/sheet_v1.png   one row per animation, transparent, fixed 590 x 470 cells, the feet (the
                             midpoint between the soles, on the ground line) at (280, 450) of every
                             cell, the body (the horns' top to the feet) 330 px (half the source):
                             idle 10 (5 fps, loops: a slow breath, the gem pulsing, the eyes dimming
                               once, frame 6),
                             throw 8 (10 fps, peak 4: the right arm lifts a boulder out to the side
                               and back over the helmet (frames 1-3, behind the horns), then whips
                               forward to the upper right, empty-handed at the peak: the game's
                               projectile leaves the knuckles there; follow-through, rest),
                             roll 7 (9 fps, peak 3: it crouches, both fists together low in front,
                               then shoves to the right, the left fist across the belly),
                             stomp 9 (10 fps, peak 4: weight to the left, the right leg lifted (the
                               leg shortened: its knee toward the viewer), stomp, crouch, the body
                               shaking left / right in 5-7),
                             spikes 7 (9 fps, peak 3: both fists up, then crouched with both fists
                               on the ground; the carvings on the chest bands and the belt glow
                               gold from frame 1, full at 3-4),
                             summon 6 (7 fps, peak 2: both arms raised beside the horns, the gem
                               flares amber-white at 2-3),
                             hurt 2 (7 fps: jolted back and down, head thrown back, arms out, eyes
                               dim; then half recovered; the game draws the white flash),
                             death 3 (6 fps: amber cracks spread over the armour from the gem, it
                               sags lower, the gem and the eyes go out; the game then breaks it
                               into parts/)
                             Facing: front view, the actions toward the screen's right (the throw,
                             the push); mirrored it reads the same (only the throwing arm swaps).
  skin/rest_v1.png           the rest pose at full size in one cell (the feet at (560, 900)): the
                             skinned idle's picture
  portrait/portrait_v1.png   the rest pose, gem and eyes lit (the Boss tab card, the matchmaking card)
  portrait/bust_v1.png       the helmet, the horns and the top of the chest, faded out under it (the
                             HP bar icon, the turn portrait)
  parts/<piece>_v1.png       the death's pieces in death frame 2's pose, one full cell each (same
                             feet), back to front: upper_l, upper_r, leg_l, leg_r, pelvis,
                             pelvis_r, chest, chest_l, chest_r, pauldron_l, pauldron_r, fist_l,
                             fore_l, fist_r, fore_r, horn_l, horn_r, helmet (the chest and the belt
                             split along the drawn cracks, the horns off the helmet; every cut edge
                             outlined); drawn together they are death frame 2
  rig_v1.json                the points (source px and the unit frame): heart (the gem), the throw's
                             hand at its peak, the eyes, the width
  import.json                the importer's config, written by the script (do not edit by hand)

How it is cut (make_frames.py header): the sky blue and the shadow ellipse keyed by colour (the giant
has no blue), the edge un-mixed against each px's nearest backdrop colour, specks cleared; the picture
split into its flat-colour cells between the outlines, each cell given to a part by the PARTS polygons
(a cell mostly inside one goes whole: the cuts follow the drawn outlines), the horns by their gold;
the outline between two parts kept on both; the hidden areas painted on the part behind (UNDER: the
torso under the pads, helmet and horns, the belt under the chest, the thighs under the skirt, the upper
arms from the shoulder to the elbow, the wrists, the pads' tops under the horns), only where a part in
front hides them; a part's cuts against the parts in front outlined just past its edge (hidden at
rest); dangling outline bits opened away. The rest pose re-drawn from the parts equals the keyed
picture (--debug writes rest_diff.png: red where it does not).

Make and import (in the battle-squad-game folder; the editor may stay open):

  python3 -I art_source/bosses/rock_giant/make_frames.py [--debug /some/dir [--check | --preview throw,roll]]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- rock_giant [--contact=/some/dir/contact.png]

The script also writes assets/bosses/rock_giant/side/points.json (per frame of every animation, in
the unit frame: the gem, the fists, the throwing knuckles, the eyes, and the chest / pads / belt / head
joints with their turn, for the game's plates and glows). The import (import.json: background.key
"alpha", the cells as cuts, the feet as anchors, bodyHeight 330 → height 320 texture px) writes
assets/bosses/rock_giant/side/<anim>_<i>.png + side.json (canvas 445 x 349, pivot (214, 339)),
portrait.png (512), bust.png (384), parts/<piece>.png + parts/parts.json (each piece's top-left from
the feet and its z, back to front), skin/idle/ (body.png 346 x 374, the body 360 px; skin.json: the
mesh, bones, weights and the breath's tracks (import.json skins.idle.tracks, motion "breath"), glow =
the gem with glowBone "torso" and glowColour amber, eyes).

The numbers (unit frame: the body 100 tall = the horns' top to the soles, the feet at the origin,
facing right, y down): heart (the gem) (6.67, -50.91); the throw's knuckles at its peak (63.95,
-74.94); the eyes (3.33, -75.76) and (13.94, -75.45); width 0.924 of the height; the top of the
horns 1.0 (raised arms reach 1.04).

Changing an animation: edit ANIMS in make_frames.py (pose(): root, drop, chest, head, arm_l / arm_r
(raise, flex, wrist), leg_l / leg_r, fx: gem, flare, eyes, carve, crack, boulder; front_l / front_r:
the forearm over the head) and re-run both commands. A new concept picture: re-check PARTS, UNDER,
the joints J and the boxes with --debug --check (parts_map.png, part_*.png, rest_diff.png) first.
