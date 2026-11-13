Mộc Tinh (boss id tree_spirit): the boss's drawn art.

The one source picture (the user's, AI-drawn on flat sky blue with a darker blue ground-shadow
ellipse and the ✦ watermark at the bottom right; kept as it is):
  concept/ancient_tree_v1.png  1380 x 752: the ancient tree, a grumpy face on the trunk (glowing mint
                               eyes with purple rims), a dark green canopy with purple leaves, glowing
                               green / lilac mushrooms on the trunk and the limbs, crystals (one
                               glowing in the canopy, one on top, one on the right limb), two bare
                               side roots curling up, big roots; FRONT view, standing

Every other picture is made from it by make_frames.py here (no AI sheets exist for this boss; the
prompts for them, if wanted later, are in PROMPTS.md). A tree bends, it does not hinge: the frames
are posed by a smooth skin over the whole picture (each px moved by the bones near it, the weights
blurred over a few px, so wood bends at a joint and nothing tears) instead of rigid cut-outs; the
parts are cut along the drawn outlines all the same (they give the weights and the death's pieces).
  side_<anim>/sheet_v1.png   one row per animation, transparent, fixed 550 x 410 cells, the feet (the
                             trunk's foot on the ground line) at (210, 394) of every cell, the body
                             (the canopy's top to the feet) 351 px (half the source):
                             idle 12 (6 fps, loops: the canopy clumps sway one after another, the
                               leafy twigs and the bare side roots stir, the mushrooms and crystals
                               pulse, the eyes dim once, frame 8),
                             vine_lash 7 (10 fps, peak 3: the eyes flare, the side roots writhe up,
                               the twigs lift (1-2), then the twigs and the canopy whip down, the side
                               roots snap down, the eyes blazing (3); settle),
                             poison_thorns 8 (10 fps, peak 4: the canopy draws in, shakes hard left /
                               right (2-3), puffs up with the clumps flung out at the peak, a few
                               leaves torn off and drifting down (4-6); the thorns are the game's),
                             life_drain 8 (8 fps, peak 3, meant to be held: the eyes and every
                               mushroom blaze, the heart glows mint on the trunk under the mouth, the
                               trunk swells; a second smaller swell at 5; the stream is the game's),
                             root_drag 8 (9 fps, peak 4: a painted root snakes out from under the right
                               roots along the ground, the tree leaning after it (1-3), full reach with
                               its tip hooked up at the peak, yanked back with the tree leaning back
                               left (5-6), gone at 7),
                             summon 7 (8 fps, peak 2: the mushrooms and crystals flare with big mint
                               halos, the roots shiver),
                             hurt 2 (7 fps: shudders back to the left, the canopy jolted, eyes half
                               shut, a few leaves knocked off; then half recovered; the game draws
                               the white flash),
                             death 4 (6 fps: the leaves wither to brown / orange and fall, the eyes,
                               the mushrooms and the crystals go out, bark cracks open (1-3), the
                               canopy and the limbs droop, the trunk sags; the game may then break it
                               into parts/)
                             Facing: front view, the root drag toward the screen's right. The tree is
                             near symmetric: mirrored it reads the same (the face, the mushrooms and
                             the crystals swap sides, no text, no handedness).
  skin/rest_v1.png           the rest pose at full size in one cell (the feet at (420, 788)): the
                             skinned idle's picture
  portrait/portrait_v1.png   the rest pose, the glows lit a little more (the Boss tab card, the
                             matchmaking card)
  portrait/bust_v1.png       the face with the fork and the canopy's middle, faded at the sides, over
                             the canopy's top and under the mouth (the HP bar icon, the turn portrait)
  parts/<piece>_v1.png       the death's pieces in death frame 3's pose, one full cell each (same feet),
                             back to front: tendril_l, tendril_r, root_l, root_r, trunk, branch_l,
                             branch_r, canopy_l, canopy_r, canopy_ml, canopy_mr (the four withered
                             canopy clumps grown from a seed each up to the drawn outlines, the leafy
                             twigs, the bare side roots, the outer roots, the trunk with the face,
                             the dead mushrooms and the limb stubs; every cut edge outlined); drawn
                             together they are death frame 3
  rig_v1.json                the points (source px and the unit frame): the heart, the canopy's
                             thorn point, the eyes, the mushroom cluster, the width
  import.json                the importer's config, written by the script (do not edit by hand)

How it is made (make_frames.py header): the sky blue, the shadow ellipse and the soft line between
them keyed by colour (the tree has no such blue); the glows round the mushrooms and the crystals that
sit on the sky kept as their own soft layer (alpha in their own mint colour, un-mixed from the sky,
no blue in it; it dims and brightens with the glow, gone at death); the figure's edge un-mixed against
the colour next to it (sky or glow), darker only (the edge is the outline), specks cleared; the tiny
sky pockets between leaves filled from their neighbours. The picture split into its flat-colour cells
between the outlines; PARTS polygons take the twigs, the side roots and the outer roots; the leaf cells
inside the CANOPY outline go to the four clumps by a watershed from CLUMPS seeds over the outlines; the
rest is the trunk. Weights: each part's px blurred (BLUR), the trunk's weight passed to the crown up
the fork (CROWN_FROM), the side roots split into two bones along their length. A frame: the bones
posed (RIG: root → trunk → crown → canopy clumps; trunk → twigs; root → side roots (2 bones) and
outer roots), the trunk's swell, then the picture inverse-warped into the cell; the fx (eyes, glow,
heart, wither, crack, drag, leaves) tint, glow or draw over it.

Make and import (in the battle-squad-game folder; the editor may stay open):

  python3 -I art_source/bosses/tree_spirit/make_frames.py [--debug /some/dir [--check | --preview vine_lash,root_drag]]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- tree_spirit [--contact=/some/dir/contact.png]

The script also writes assets/bosses/tree_spirit/side/points.json (per frame of every animation, in
the unit frame: the heart, the canopy's thorn point, the eyes' middle, the mushroom cluster, how lit
the glows and the eyes are, and the root drag's root tip while it shows). The import (import.json:
background.key "alpha", the cells as cuts, the feet as anchors, bodyHeight 351 → height 320 texture
px) writes assets/bosses/tree_spirit/side/<anim>_<i>.png + side.json (canvas 478 x 347, pivot
(191, 334)), portrait.png (512), bust.png (384), parts/<piece>.png + parts/parts.json (each piece's
top-left from the feet and its z, back to front), skin/idle/ (body.png 397 x 378, the body 360 px;
skin.json: the mesh, bones, weights and the sway's tracks (import.json skins.idle.tracks, motion
"breath": it stands, no float), glow = the heart with glowBone "trunk" and glowColour mint, eyes).

The numbers (unit frame: the body 100 tall = the canopy's top to the ground line, the feet at the
origin, facing right, y down): heart (0.85, -21.65); the canopy's thorn point (0, -85.19); the eyes
(0.62, -39.02) and (11.74, -38.75); the mushroom cluster in the fork (10.26, -55.84); the root drag's
tip at full reach (86.91, -8.9); width 1.067 of the height; the canopy's top 1.0.

Changing an animation: edit ANIMS in make_frames.py (pose(): trunk, crown, canopy (4 turns), lift,
shift, puff, branch (l, r), tendril_l / tendril_r (base, tip), roots (l, r), root, sag, swell; fx: eyes,
glow, heart, wither, crack, drag (extension, wave, curl), leaves (falling())) and re-run both commands.
A new concept picture: re-check PARTS, CANOPY, CLUMPS, GLOWS, the joints J with --debug --check
(keyed_*.png, halo.png, parts_map.png, leaves.png, weights.png) first.
