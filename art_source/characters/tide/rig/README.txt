Tide's chibi bone rig: Tide in every match (scenes/character/character.gd match_rig, set by
match/views/player_view.gd; docs/match-rig.md). Everything outside the match, and the match's turn
portrait / HUD, keep the old Tide art. The same rig as Rookie's, Spark's, Tanko's and Flora's
(../../flora/rig/: the same 14 parts, 15 bones, draw order and code in scenes/character/rig/).

Source: ../side_idle/idle_v2.png (797 x 969, pure white backdrop, facing right, open hands down, no gun),
made chibi from the user's picture by ../side_idle/chibi_edit/make_chibi.py (head x1.4, shirt and legs
squashed). Before the cut, the chibi edit's two seams are mended (mend_seams): the head layer's shaded
neck graded column by column into the light neck under it, the neck's front outline redrawn as one
stroke over the jog; the faint line across the shorts' teal trim smoothed away. The backdrop is keyed by
flood from the border, not by a threshold (the near-white shirt, shorts and boots stay: they are inside
their outlines); the gaps between the near arm and the waist and between the legs are backdrop too
(HOLES). The outline is the darkest ink only (OUTLINE_LUM 24): the navy hair and leggings are cells.
The whole bob rides the head (rigid, its back part too when she looks up); the head's polygon cuts px by
px (HARD: the face and the shaded neck are one cell; the neck under the jaw line is the torso's). The
sleeves ride the upper arms, the knee pads the thighs, the open hands stay open (n_fist, f_fist: held,
the near palm lies on the tube, fingers up across it). Painted (outline and flat colours, clipped to the
picture's own outline so nothing shows at rest): the shirt under the belt, the neck under the chin, the
near shoulder under the sleeve and the shirt's back edge under the near arm, the seat, the shorts' edges
under the hands, the thighs' hidden backs, the far sleeve with its cuff and the far arm behind the chest,
the joint caps (elbow and wrist without an outline: bare skin; knees under the pads, hips). The clear px
of each part take their nearest drawn px's colour (no dark fringe when the sprite is filtered).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/tide/rig/make_rig.py [--debug DIR]

Writes assets/characters/tide/rig/<part>.png (14 parts, half size: 420 px tall) and rig.json. --debug DIR
adds part_map.png, rest_vs_picture.png (the parts re-assembled at rest beside the picture: they must
match) and parts_sheet.png (every part alone, and again with its painted areas tinted magenta).

What to edit in make_rig.py: J (the joints; the far arm's two bones about equal and slightly bent so its
IK never flips in the swing off the back; the knees slightly forward so the legs never stretch out at
rest), PARTS / HARD / OWN (the cut), UNDER (the painted areas), HOLES (backdrop seen through the figure),
mend_seams (the chibi edit's seams), RIG_TUNING (written into rig.json: fallDeg -72, the back of the bob
on the ground lying down; aimPath: the tube slides up through the hands from 30 degrees, 40 px at 45, so
its tail stays off the ground from her low chest). The gun's length and the back sling are not here: they
are the carry scene, scenes/character/poses/tide_carry.tscn (CarrySocket / Preview; the Preview starts at
the 0.92 default length, the socket at Tanko's and Flora's tilt).

Watch it: scenes/dev/rig_preview.tscn with the user arg --character=tide, or
  tools/record_rig_preview.sh OUT_DIR tide
