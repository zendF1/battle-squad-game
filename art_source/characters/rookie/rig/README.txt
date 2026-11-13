Rookie's bone rig: a TEST (not used in matches; the user decides before it replaces the side view).

Source: ../side_idle/idle_v2.png (the user's chibi picture: 1364 x 768, white backdrop, standing,
facing right, no gun). Nothing else is drawn: the far arm's sleeve, the torso's back under the near
sleeve, the neck under the chin, the belt's ends and the thighs under the fists, the joints' caps are
painted by make_rig.py in the picture's outline and flat colours.

Run in battle-squad-game (Python 3 with numpy, scipy, Pillow, OpenCV):

  python3 -I art_source/characters/rookie/rig/make_rig.py [--debug DIR]

Writes assets/characters/rookie/rig/<part>.png (14 parts, half size) and rig.json. --debug DIR adds
part_map.png (which part owns each px), rest_vs_picture.png (the parts re-assembled at rest beside the
picture: they must match) and parts_sheet.png (every part alone, and again with its painted areas
tinted magenta).

What to edit in make_rig.py:
  J        the joints (source px): hips, torso (waist), head (neck), shoulders / elbows / hands (the fist
           centres: the IK puts them on the gun's grips), hips / knees / ankles (knees a little forward
           of the hip-ankle line, so a planted leg bends forward)
  PARTS    the polygon that owns each part's px (cells between outlines go whole to the polygon holding
           most of them; HARD parts are cut px by px); OWN: who owns the outline between two parts
  UNDER    the painted hidden areas per part (polygon, fill, outline: all round / none / along given
           edges only)
  ORDER    the draw order and each part's bone

The motions (code, no frames): scenes/character/rig/rig_motion.gd (idle breathing, raise / aim / shoot,
hurt, walk with planted feet, die), the solver scenes/character/rig/rig_model.gd (IK arms on the gun's
grips along AIM_PATH, IK legs, the fall), the view scenes/character/rig/char_rig.gd. Watch them:
scenes/dev/rig_preview.tscn (F6 in the editor), or record it into frames / a GIF / the key poses:

  tools/record_rig_preview.sh OUT_DIR

Another character needs: its standing picture (facing right, plain backdrop, arms hanging clear of
the body if possible), a copy of this script with its own J / PARTS / UNDER (the cut and the painting
are per picture), and its rig.json goes to assets/characters/<id>/rig/. The motion and solver code is
shared; AIM_PATH / GUN_LENGTH may need tuning per body shape.
