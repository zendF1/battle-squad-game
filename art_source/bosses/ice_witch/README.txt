Phù Thuỷ Băng (ice_witch): the boss's drawn art.

Source pictures (AI-drawn on flat magenta, facing right; PROMPTS.md has the prompts):
  portrait/portrait_v1.png   full-body hero pose (the Boss tab card, the matchmaking card)
  portrait/bust_v1.png       head and shoulders (the boss HP bar icon, the turn portrait)
  side_<anim>/sheet_v1.png   one sprite sheet per animation, the frames in one row:
                             idle 7, fly 4, cast 6, burst 6, blizzard 6, summon 4, hurt 2
                             (no death sheet: the game makes her death from the first hurt frame)

Import (in the battle-squad-game folder; the editor may stay open):

  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- ice_witch

  add  --contact=/some/dir/contact.png  for a contact sheet of every cut frame (the feet as a red
  cross, the body's top as a green line).

It writes assets/bosses/ice_witch/side/<anim>_<i>.png + side.json and assets/bosses/ice_witch/
portrait.png, bust.png. Everything it does is in import.json here: the frame counts, fps, loop,
the watermark spots, the frame boundaries (found at the empty columns between the figures; give
"cuts" to set them), a frame's feet ("anchors"), "compose" (the cast's flash frame drawn together
with the thrust before it), "height" (the body's px in every animation) and "tone" (a light lift:
lighten / desaturateDark). See the tool's header.

Replacing a sheet: keep the same frame count and order (or edit "frames" here), the figure facing
right on flat magenta, then re-run. The idle sheet (side_idle/sheet_v1.png, 1024x123, about
146x123 per frame) is very small: the tool upscales it (Lanczos) to match the others, but a
higher-resolution idle sheet (each frame at least 250 px tall, the frost mist not touching the
bottom edge) would look much sharper.
