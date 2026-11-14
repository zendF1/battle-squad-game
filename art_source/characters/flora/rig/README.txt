Flora's chibi bone rig: Flora in every match (scenes/character/character.gd match_rig, set by
match/views/player_view.gd; docs/match-rig.md). Everything outside the match, and the match's turn
portrait / HUD, keep the old Flora art. The same rig as Rookie's, Spark's and Tanko's (../../tanko/rig/:
the same 14 parts, 15 bones, draw order and code in scenes/character/rig/).

Source: ../side_idle/idle_v2.png (the user's chibi picture: 1365 x 768, off-white backdrop, a grey column
on the right edge, 3/4 facing right, fists down, no gun, no watermark). The backdrop is keyed against its
own measured colour (no grey fringe); the gaps between the near arm and the waist, between the boots and
a chink between the hair and the near shoulder are backdrop too (HOLES); the grey column is dropped. The
black hair counts as outline: what no cell owns goes by the part polygons (so the hair's ends stay on the
head). The bandana, its flower and its two knotted tails stay on the head (rigid); the shoulder and elbow
pads ride the upper arms (round on the elbow joint, the elbow pad covers the forearm's top however it
bends); the knee pads ride the thighs. Painted (outline and flat colours, clipped to the picture's own
outline so nothing shows at rest): the jumpsuit under the near arm, its shoulder and the belt, the neck
under the chin, the belt's back end under the near fist, the seat, the thighs' hidden backs / fronts, the
far sleeve, shoulder pad and forearm behind the chest, the joint caps (elbow, wrist, knees, hips).

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/flora/rig/make_rig.py [--debug DIR]

Writes assets/characters/flora/rig/<part>.png (14 parts, half size: 305 px tall) and rig.json. --debug DIR
adds part_map.png, rest_vs_picture.png (the parts re-assembled at rest beside the picture: they must
match) and parts_sheet.png (every part alone, and again with its painted areas tinted magenta).

What to edit in make_rig.py: J (the joints; the far arm's two bones kept about equal and slightly bent so
its IK never flips in the swing off the back; the near knee slightly forward so the legs never stretch out
at rest), PARTS / OWN (the cut), UNDER (the painted areas), HOLES (backdrop seen through the figure),
RIG_TUNING (written into rig.json: fallDeg -80, the back of the head on the ground lying down: the
bandana tails dip a little under it; also aimPath, headBackDeg, torsoBackDeg). The gun's length and the
back sling are not here: they are the carry scene, scenes/character/poses/flora_carry.tscn (CarrySocket /
Preview; the Preview starts at the 0.92 default length).

Watch it: scenes/dev/rig_preview.tscn with the user arg --character=flora, or
  tools/record_rig_preview.sh OUT_DIR flora
