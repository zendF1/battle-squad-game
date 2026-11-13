Đĩa Bay Thép (boss id steel_robot, it was Rô-bốt Thép): the boss's drawn art.

The one source picture (the user's, AI-drawn on flat sky blue, facing right: the twin cannons on the
right; kept as it is):
  concept/ufo_v1.png         the grey saucer, the green pilot in the glass dome, the twin cannons,
                             two legs and the bottom claw, the thruster jets under them

Every other picture is made from it by make_frames.py here (no AI sheets exist for this boss; the
prompts for them, if wanted later, are in PROMPTS.md). Since round 2 the twin cannon is a turret of its
own (it turns to aim each shot, flare and laser beam): the body frames have no cannon, a round socket
under the bowl's right side instead, and the game draws the turret on it.
  side_<anim>/sheet_v1.png   one row per animation, transparent, fixed 620 x 590 cells, the feet (the
                             claw's bottom centre) at (305, 448) of every cell, the body (dome top to
                             the claw's bottom) 342 px; no cannon:
                             idle 7 (the rim lamps chasing, the ring dots twinkling, the jets
                               flickering, the orange port breathing; loops, 7 fps),
                             fly 4 (long bright jets, the lamps flashing; loops, 10 fps; level: the
                               game leans it into the flight),
                             cast 6 (the port warms, peak 3: every lamp flashes, the jets dip; 10 fps;
                               the turret's recoil and the game's muzzle flash make the shot),
                             burst 6 (the laser: the port charges, peak 2: every lamp and ring dot on,
                               the jets roar; 9 fps; the turret's charge / hot states at the muzzles),
                             summon 4 (the bottom claw opens round its roots, a lit hatch between
                               the jaws, peak 2: wide open, light falling where the drone drops;
                               the centre jet off while it is open; 7 fps),
                             hurt 2 (tilted nose up 9 degrees and knocked back, lamps out, sparks,
                               the jets sputtering; then 3.5 degrees; frame 0 also starts the death;
                               the turret's mount moves and turns with it: turret_v1.json bodyFrames)
  turret/sheet_v1.png        the twin cannon (barrels, collars, the housing between them, a neck and a
                             round hub) pointing straight right, one row of fixed 240 x 170 cells, the
                             hub's centre (the pivot) at (32, 85) of every cell: idle (the muzzles'
                             own orange glow), charge_0 / charge_1 (the muzzles heating, orange rings,
                             then motes drawn in), hot (white-hot cores, held while the beams fire),
                             recoil_0 / recoil_1 (both barrels slid back 24 / 10 source px, hot, then
                             cooling); no muzzle flash or smoke (the game draws them at the tips)
  turret/turret_v1.json      written with it: the pivot in the cell, its mount from the feet, the
                             muzzle tips from the pivot, the recoil per state, the rest angle (20) and
                             the range (10..120 degrees: 0 right, positive down), the mount per body
                             frame (sheet px)
  portrait/portrait_v1.png   the whole craft at rest, full size, the turret at its rest angle (the Boss
                             tab card, the matchmaking card)
  portrait/bust_v1.png       the dome with the pilot, the antenna and the dome ring (the HP bar icon,
                             the turn portrait)
  parts/hull_v1.png          the saucer without the dome (the cockpit open) and without the cannon
                             (the socket stays), one cell
  parts/dome_v1.png          the dome alone, one cell (a death that pops the dome off)
  parts/cannon_v1.png        the turret (idle) pointing right on its mount, one cell (it can fly off
                             too); its hub at (425, 366.5) of the cell (import.json parts.pivots)

How it is cut (make_frames.py header): the ✦ painted out; the backdrop removed by a flood from the
borders that stops at the black outline (the see-through dome shows the same sky blue inside and is
never keyed), the backdrop pockets between the leg struts keyed too, every backdrop px un-mixed
(colour-to-alpha: the lamps' and muzzles' glows keep their colour at soft alpha, no blue fringe), the
faint light specks the un-mixing leaves round the craft cleared (despeckle()); the AI's jets dropped
and painted again so they can flicker. The cannon: cut inside CANNON_CUT under the stripe band's
outline (BAND_EDGE) and within CANNON_HALF of either barrel's axis, the cut edges re-outlined, moved
perpendicular to the barrels so their middle axis runs through PIVOT, turned 19.5 degrees to point
right, a hub and a neck painted behind it. The hull under the band right of HULL_SEAM is refilled
from the craft's own mirror image (MIRROR_X2: the left side's bowl, leg and lamp glows turned over,
cross-faded at the seam), the band's outline drawn again over the seam, the socket painted at PIVOT
(under the band). The barrels, the claw, the lamps, the port, the dome are found by the geometry
constants at the top of the script (source px).

Make and import (in the battle-squad-game folder; the editor may stay open):

  python3 -I art_source/bosses/steel_robot/make_frames.py [--debug /some/dir]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- steel_robot

  --debug writes the keyed picture on dark / orange, the part masks (the cannon cut orange), the
  hull without its cannon and turret_range.txt (the turret's px over the band / the belly per
  angle); add --contact=/some/dir/contact.png to the import for a contact sheet of every frame.

The import (import.json here: background.key "alpha", the cells as cuts, the feet as anchors,
bodyHeight 342 → height 240 texture px) writes assets/bosses/steel_robot/side/<anim>_<i>.png +
side.json (canvas 340 x 320, pivot (169, 277)), portrait.png (512), bust.png (384),
parts/hull.png, parts/dome.png, parts/cannon.png + parts/parts.json (each part's top-left from the
feet: drawn there from the frames' pivot they sit exactly where the frames show them; the cannon's
`pivot`: its hub in its own px) and turret/<state>.png (one canvas, 122 x 87) + turret/turret.json
(the pivot in each picture; mount, tips, recoil, bodyFrames in texture px and the mount and tips in
the unit frame BossArt draws in: the body 100 tall, the feet at the origin, facing right; rest and
range in degrees).

The numbers (round 2, unit frame): the pivot (mount) (35.09, -23.83); pointing right the muzzles'
glowing centres from the pivot: upper (far) barrel (32.61, -4.82), lower (near) barrel (25.94, 4.82),
their middle (29.27, 0): on the line from the pivot, so the middle tip is pivot + 29.27 x (cos a,
sin a) at any angle a. Texture px (x 2.4): pivot from the feet (84.21, -57.19), tips (78.26, -11.58),
(62.26, 11.58), (70.26, 0). Range 10..120 degrees (under 10 the far barrel crosses the stripe band,
over about 135 the turret swings under the belly); rest 20.

Changing an animation: edit ANIMS in make_frames.py (per frame: lamps, dots, jets, port, claw,
hatch, tilt, shift, fx) or TURRET (per state: heat, recoil, fx laser / motes), re-run both
commands; a new frame count also goes in import.json (frames, cuts, anchors). A new concept picture: re-check the geometry constants with
--debug (masks.png) first.
