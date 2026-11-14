Tanko's chibi bone rig: Tanko in every match (scenes/character/character.gd match_rig, set by
match/views/player_view.gd; docs/match-rig.md). Everything outside the match, and the match's turn
portrait / HUD, keep the old Tanko art. The same rig as Rookie's and Spark's (../../spark/rig/: the same
14 parts, 15 bones, draw order and code in scenes/character/rig/).

Source: ../side_idle/idle_v2.png (the user's chibi picture: 1365 x 768, off-white backdrop, a grey column
on the right edge, 3/4 facing right, fists down, no gun, no watermark). The backdrop is keyed against its
own measured colour (no grey fringe), the gaps between the near arm and the chest and between the boots are
backdrop too (HOLES), the grey column is dropped. The big steel helmet and the chin strap stay on the head;
the shoulder pads ride the upper arms; the knee pads ride the thighs (round on the knee joint: they cover
the shin's top however the knee bends). Painted (outline and flat colours, clipped to the picture's own
outline so nothing shows at rest): the shirt under the near arm and the belt, the near shoulder under its
pad, the neck under the chin strap, the belt's back end under the near sleeve, the seat, the thighs'
hidden backs / fronts, the far sleeve and shoulder pad behind the chest, the joint caps (elbow, wrist,
knees, hips).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/tanko/rig/make_rig.py [--debug DIR]

Writes assets/characters/tanko/rig/<part>.png (14 parts, half size: 306 px tall) and rig.json. --debug DIR
adds part_map.png, rest_vs_picture.png (the parts re-assembled at rest beside the picture: they must
match) and parts_sheet.png (every part alone, and again with its painted areas tinted magenta).

What to edit in make_rig.py: J (the joints; the far arm's two bones kept about equal so its IK never
flips), PARTS / OWN (the cut), UNDER (the painted areas), HOLES (backdrop seen through the figure),
RIG_TUNING (written into rig.json: fallDeg -80, so the big helmet rests on the ground lying down; also
aimPath, headBackDeg, torsoBackDeg). The gun's length and the back sling are not here: they are the carry
scene, scenes/character/poses/tanko_carry.tscn (CarrySocket / Preview; the Preview starts at the 0.92
default length, tilted like Rookie's and Spark's slings).

Watch it: scenes/dev/rig_preview.tscn with the user arg --character=tanko, or
  tools/record_rig_preview.sh OUT_DIR tanko
