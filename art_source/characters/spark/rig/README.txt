Spark's chibi bone rig: Spark in every match (scenes/character/character.gd match_rig, set by
match/views/player_view.gd; docs/match-rig.md). Everything outside the match, and the match's turn
portrait / HUD, keep the old Spark art. The same rig as Rookie's (../../rookie/rig/: the same 14 parts,
15 bones, draw order and code in scenes/character/rig/).

Source: ../side_idle/idle_v2.png (the user's chibi picture: 1199 x 896, off-white JPEG backdrop, 3/4
facing right, fists down, no gun, no watermark). The backdrop is keyed against its own measured colour
(no grey fringe), the gap between the near arm and the waist is backdrop too (HOLES), the grey column on
the picture's right edge is dropped. Painted (outline and flat colours, clipped to the picture's own
outline so nothing shows at rest): the tank top under the near arm and the belt, the neck under the chin,
the pouches' ends under both gloves, the seat, the thighs' hidden backs / fronts, the far upper arm and
forearm behind the chest, the joint caps (elbow, wrist, knees, hips). The spiky hair stays on the head.

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/spark/rig/make_rig.py [--debug DIR]

Writes assets/characters/spark/rig/<part>.png (14 parts, half size: 342 px tall) and rig.json. --debug DIR
adds part_map.png, rest_vs_picture.png (the parts re-assembled at rest beside the picture: they must
match) and parts_sheet.png (every part alone, and again with its painted areas tinted magenta).

What to edit in make_rig.py: J (the joints; the far arm's two bones kept about equal so its IK never
flips), PARTS / OWN (the cut), UNDER (the painted areas), HOLES (backdrop seen through the figure),
RIG_TUNING (written into rig.json: fallDeg -82, so the spiky hair rests on the ground lying down; also
aimPath, headBackDeg, torsoBackDeg). The gun's length and the back sling are not here: they are the carry
scene, scenes/character/poses/spark_carry.tscn (CarrySocket / Preview, tuned in the editor).

Watch it: scenes/dev/rig_preview.tscn with the user arg --character=spark, or
  tools/record_rig_preview.sh OUT_DIR spark
