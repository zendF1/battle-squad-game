Đĩa Bay Thép (boss id steel_robot, it was Rô-bốt Thép): the boss's drawn art.

The one source picture (the user's, AI-drawn on flat sky blue, facing right: the twin cannons on the
right; kept as it is):
  concept/ufo_v1.png         the grey saucer, the green pilot in the glass dome, the twin cannons,
                             two legs and the bottom claw, the thruster jets under them

Every other picture is made from it by make_frames.py here (no AI sheets exist for this boss; the
prompts for them, if wanted later, are in PROMPTS.md):
  side_<anim>/sheet_v1.png   one row per animation, transparent, fixed 620 x 590 cells, the feet (the
                             claw's bottom centre) at (305, 448) of every cell, the body (dome top to
                             the claw's bottom) 342 px:
                             idle 7 (the rim lamps chasing, the ring dots twinkling, the jets
                               flickering, the orange port breathing; loops, 7 fps),
                             fly 4 (long bright jets, the lamps flashing; loops, 10 fps; level: the
                               game leans it into the flight),
                             cast 6 (the muzzles heat, peak 3: both barrels recoil, a muzzle flash,
                               the craft jolts back; then smoke; 10 fps),
                             burst 6 (the laser: the port and the muzzles charge, motes drawn in,
                               peak 2: white-hot cores in the muzzles, held while the beams fire;
                               9 fps),
                             summon 4 (the bottom claw opens round its roots, a lit hatch between
                               the jaws, peak 2: wide open, light falling where the drone drops;
                               the centre jet off while it is open; 7 fps),
                             hurt 2 (tilted nose up 9 degrees and knocked back, lamps out, sparks,
                               the jets sputtering; then 3.5 degrees; frame 0 also starts the death)
  portrait/portrait_v1.png   the whole craft at rest, full size (the Boss tab card, the matchmaking card)
  portrait/bust_v1.png       the dome with the pilot, the antenna and the dome ring (the HP bar icon,
                             the turn portrait)
  parts/hull_v1.png          the saucer without the dome (the cockpit open), one cell
  parts/dome_v1.png          the dome alone, one cell (a death that pops the dome off)

How it is cut (make_frames.py header): the ✦ painted out; the backdrop removed by a flood from the
borders that stops at the black outline (the see-through dome shows the same sky blue inside and is
never keyed), the backdrop pockets between the leg struts keyed too, every backdrop px un-mixed
(colour-to-alpha: the lamps' and muzzles' glows keep their colour at soft alpha, no blue fringe); the
AI's jets dropped and painted again so they can flicker; the barrels, the claw, the lamps, the port,
the dome found by the geometry constants at the top of the script (source px).

Make and import (in the battle-squad-game folder; the editor may stay open):

  python3 -I art_source/bosses/steel_robot/make_frames.py [--debug /some/dir]
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- steel_robot

  --debug writes the keyed picture on dark / orange and the part masks; add
  --contact=/some/dir/contact.png to the import for a contact sheet of every frame.

The import (import.json here: background.key "alpha", the cells as cuts, the feet as anchors,
bodyHeight 342 → height 240 texture px) writes assets/bosses/steel_robot/side/<anim>_<i>.png +
side.json (canvas 373 x 321, pivot (172, 278)), portrait.png (512), bust.png (384) and
parts/hull.png, parts/dome.png + parts/parts.json (each part's top-left from the feet: drawn there
from the frames' pivot they sit exactly where the frames show them).

Changing an animation: edit ANIMS in make_frames.py (per frame: lamps, dots, jets, port, heat,
recoil, claw, hatch, tilt, shift, fx), re-run both commands; a new frame count also goes in
import.json (frames, cuts, anchors). A new concept picture: re-check the geometry constants with
--debug (masks.png) first.
