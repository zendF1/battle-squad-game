Tanko's chibi bone rig: Tanko in every match (scenes/character/character.gd match_rig, set by
match/views/player_view.gd; docs/match-rig.md). Everything outside the match, and the match's turn
portrait / HUD, keep the old Tanko art. The same rig as the other four (the same 14 parts, 15 bones, draw
order and code in scenes/character/rig/; the five make_rig.py share all but their constants).

In a match the rig at rest is the standing picture (breathing); the bones move only for the gun (drawn,
aimed -30..90, the shot's recoil), a hit and the fall. Walking moves no bone: the run frames
(../../make_run_frames.py tanko -> assets/characters/tanko/rig/run.json), or, until they exist, the standing
picture lifting a little with each step.

Source: ../side_idle/idle_final.png (the user's final chibi set, 896 x 1200, pure white backdrop, facing
right, fists down, no gun). The backdrop is keyed by flood from the border, not by a threshold (the light
px inside the outlines stay); No HOLES (the arms and legs touch; the eye white is the eye's). The outline is the darkest ink only (OUTLINE_LUM).
The big steel helmet, the chin strap and its chin cup ride the head (the neck under the strap is the
torso's); the shoulder pads the upper arms; the grenade vest the torso; the knee pads the thighs (round
on the knee joint, they cover the shin's top however the knee bends).
Painted (outline and flat colours, clipped to the picture's own outline so nothing shows at rest): the
shirt under the belt, the neck under the chin, the near shoulder and the shirt's back edge under the near
arm, the belt's back end, the seat, the thighs' hidden edges, the far arm / shoulder behind the chest, the
joint caps (elbow and wrist without an outline; knees, hips). The clear px of each part take their nearest
drawn px's colour (no dark fringe when the sprite is filtered).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/tanko/rig/make_rig.py [--debug DIR]

Writes assets/characters/tanko/rig/<part>.png (14 parts, a third of the source size: 381.7 px tall) and
rig.json. --debug DIR adds part_map.png, rest_vs_picture.png (the parts re-assembled at rest beside the
picture: they must match) and parts_sheet.png (every part alone, and again with its painted areas tinted
magenta).

What to edit in make_rig.py: J (the joints; the far shoulder far enough behind the chest point that the far
arm's IK never flips in the swing off the back or the recoil; the knees slightly forward of the hip-ankle
line so the legs never stretch out at rest), PARTS / HARD / OWN (the cut), UNDER (the painted areas),
HOLES (backdrop seen through the figure), GUN_CHEST / POINTS, RIG_TUNING (written into rig.json: fallDeg
-79, the big helmet on the ground lying down; aimPath: the default's rows at this size, the tube sliding up through the hands from 30 degrees so
its tail stays off the ground). The gun's length and the back sling are not here: they are the carry
scene, scenes/character/poses/tanko_carry.tscn (CarrySocket / Preview).

Watch it: scenes/dev/rig_preview.tscn with the user arg --character=tanko, or
  tools/record_rig_preview.sh OUT_DIR tanko
