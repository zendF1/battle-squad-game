Phù Thuỷ Băng (ice_witch): the boss's drawn art.

Source pictures (AI-drawn on flat magenta, facing right; PROMPTS.md has the prompts):
  portrait/portrait_v1.png   full-body hero pose (the Boss tab card, the matchmaking card)
  portrait/bust_v1.png       head and shoulders (the boss HP bar icon, the turn portrait)
  concept/model_sheet_v1.png front / side / back model sheet: its side view (figure 2) is her
                             skinned fly (the glide)
  side_<anim>/sheet_v1.png   one sprite sheet per animation, the frames in one row:
                             cast 6, burst 6, blizzard 6, summon 4, hurt 2
                             (no death sheet: the game makes her death from the first hurt frame)
                             side_idle and side_fly are no longer used: the idle is the portrait
                             and the fly the model sheet's side view, each on a skeleton (the fly
                             frames are still cut, as a fallback the game does not show)

Import (in the battle-squad-game folder; the editor may stay open):

  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- ice_witch

  add  --contact=/some/dir/contact.png  for a contact sheet of every cut frame (the feet as a red
  cross, the body's top as a green line).

It writes assets/bosses/ice_witch/side/<anim>_<i>.png + side.json, assets/bosses/ice_witch/
skin/idle/ and skin/fly/ (body.png, shard_<i>.png, skin.json: the picture, its orbiting shards cut
out as their own sprites, the mesh, bones and weights, made like the lobby characters' full.json)
and assets/bosses/ice_witch/portrait.png, bust.png. With --contact= it also writes <skin>_bones.png
next to the contact sheet (the bones on the picture: move the "joints" if one is off). Everything it does is in import.json here: the frame counts, fps, loop,
the watermark spots, the frame boundaries (found at the empty columns between the figures; give
"cuts" to set them), a frame's feet ("anchors"), "compose" (the cast's flash frame drawn together
with the thrust before it), "height" (the body's px in every animation) and "tone" (a light lift:
lighten / desaturateDark). See the tool's header.

The idle's motion (a 2.4 s float, the cape and mist swaying, the shards drifting) is
match/boss/skin_idle.gd; the glide's (the lean, the streaming cape, the trailing shards, the
landing's overshoot) match/boss/skin_fly.gd.

Replacing a sheet: keep the same frame count and order (or edit "frames" here), the figure facing
right on flat magenta, then re-run. Replacing the portrait or the model sheet: re-check the
"joints" and the shard "centres" (source px) on the <skin>_bones.png debug pictures.
