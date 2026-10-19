# assets/

Every image the game shows is a file here. The current files are placeholder art drawn in
code (`tools/art/*.gd`) and baked by `tools/bake_art.gd`. `ui/art.gd` is the one place that maps
ids to these paths; a missing file never crashes (a character falls back to rookie, an icon to
`icons/unknown.png`, anything else to a small grey square, with a warning).

Total about 3.8 MB of PNG (the full-body pictures about 0.45 MB of it).

## Replacing art

- **Overwrite a PNG with the same name and the same size** (and, for characters, the same pivot).
  The editor re-imports it; nothing else changes. A different size works for icons, effects,
  clouds and backgrounds (they are drawn to a fixed on-screen size), but keep character frames on
  the shared canvas below.
- **Characters (lobby)**: the screens outside the match draw the skinned full-body picture
  `characters/<id>/lobby/full.png` + `full.json`; without one, the baked side-view frames. Re-cut
  the full-body pictures from a new lineup image with `tools/cut_sheet.gd` (below).
- **Characters (match), drawn frames**: drop hand-drawn side-view frames in and run the importer
  (`characters/<id>/side/`, below): Rookie's match art is made this way; any character switches by
  getting a `side/` folder, the code needs no change.
- **Characters (match), baked frames**: either overwrite the frame PNGs, or open
  `characters/<id>/<id>.tres` (SpriteFrames) in the editor and change frames, counts, speed or
  loop flags. The animation names must stay `idle`, `walk`, `shoot`, `hurt`, `die`. If you change
  the canvas size or pivot, update `FRAME_SIZE` / `FRAME_PIVOT` / `PX_PER_UNIT` in `ui/art.gd`
  (the code sets the sprite's offset to -pivot; `scenes/character/character.tscn` only previews
  Rookie's side idle in the editor, its own SpriteFrames, replaced at runtime). The frames draw no
  gun: replace a frame **and its entry in `characters/<id>/gun_anchors.json`** together (where
  the hand holds the gun in that frame), and keep one entry per frame.
- **Guns**: imported from a hand-made sheet (`art_source/weapons/guns_v1.png`) by
  `tools/import_guns.gd` (config `art_source/weapons/guns_v1.json`, below): edit the config or the
  sheet and re-run it. It writes `weapons/<kind>/<tier>.png`, `weapons/weapons.json` and the weapon
  equipment icons, for every kind but the bazooka, the cannon and the seed launcher: Rookie's
  bazooka, Tanko's cannon and Flora's seed launcher are only hug art (`art_source/weapons/hug/`, `tools/import_hug_guns.gd`, which writes their icons too). A hand-replaced gun works too: overwrite the PNG and, when the grip or muzzle
  moved, its entry in `weapons/weapons.json`. Any canvas size works (the grip pivot places it);
  `pxPerUnit` (texture px per art unit, every gun) sets the drawn size.
- **9-patches** (`ui/`): keep the corners inside the texture margins listed below
  (`ui/art.gd` `UI_BOXES`), or change the margins there.
- Import settings: icons, effects and clouds are imported with mipmaps (they are shown smaller
  than drawn); the rest without. Re-baking never touches an existing `.import` file.

## Thêm ảnh góc ngang cho nhân vật

Ảnh trong trận của từng nhân vật: Rookie, Tanko, Flora và Spark đều đã có (cấu hình của họ làm mẫu
khi thay ảnh / thêm nhân vật). Mỗi nhân vật `<id>` có thư mục ảnh và cảnh dáng ngắm; không cần sửa code.

1. **Bỏ ảnh vào** `art_source/characters/<id>/`:
   - `side_run/frame_1.png`, `frame_2.png` … `frame_N.png`: một vòng chạy, nhìn sang phải, nền trong
     suốt, chân chạm đất ở mọi frame.
   - `side_idle/idle_v1.png`: dáng **đứng yên** = nhân vật đứng thẳng, hai chân chạm đất, nhìn sang
     phải, không cầm súng, cùng nét vẽ và cỡ ảnh với ảnh chạy, nền trong suốt hoặc **trắng** (Spark:
     `poses.stand.background` xoá phần trắng nối với mép ảnh; chưa có thì dáng đứng yên là một frame
     chạy: `anims.idle.fallback`, `frame_1`; Tanko `frame_7`).
   - `side_ready/ready_v1.png`: dáng ngắm = nhân vật **quỳ**, nhìn sang phải, **hai tay chụm giữa
     ngực, KHÔNG cầm súng**, nền **xanh lá đặc** (một màu; dấu ✦ của AI ở góc tool tự xoá).
2. **Súng ôm** (vẽ riêng, mỗi súng một ảnh): `art_source/weapons/hug/<loại>_<cấp>.png` (vd.
   `cannon_iron.png`, loại = `bazooka` `cannon` `shock_rifle` `seed_launcher` `blaster`): súng nằm
   ngang, **nòng sang phải**, **không có tay cầm**, nền một màu đặc: xanh lá hoặc **hồng tím
   (magenta)** đều được (tool lấy màu ở 4 góc; quầng sáng của pha lê / hạt lửa trên nền khai báo
   `"glow"`, xem dưới). Cấp nào chỉ khác màu (vd.
   `basic`, `steel` của bazooka, `basic` của cannon và seed_launcher) không cần ảnh: khai báo trong `hug.json` `"<loại>_<cấp>": {"from":
   "iron", "recolour": {...}}` là tool tự đổi màu từ ảnh cấp đó.
3. **Chạy** (trong thư mục `battle-squad-game`, editor mở cũng được):
   ```
   /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- <id>
   /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd
   ```
   Lệnh 1 ghi `assets/characters/<id>/side/` (PNG + `side.json`, `gun_anchors.json`), lệnh 2 ghi
   `assets/weapons/<loại>/hug_<cấp>.png` + `assets/weapons/hug.json` (và icon trang bị
   `assets/icons/equipment/weapon_<…>_<cấp>.png` của các súng khai báo trong `hug.json` `"icons"`, hiện
   là bazooka, cannon và seed_launcher: `weapon_launcher_<cấp>`); không bao giờ ghi đè cảnh `.tscn`. Nhân vật có dáng ngắm chỉ cầm súng ở dáng đó: không
   cần `hand.png` (tool không cắt).
   Chưa có `ready_v1.png` thì chỉ nhập ảnh chạy (súng rút kiểu cũ, chưa có dáng ngắm).
4. Quay lại editor, đợi nó import xong các PNG.
5. **Mở** `scenes/character/poses/<id>_ready.tscn`: `Body` tự đổi sang dáng quỳ mới (trước khi có ảnh
   nó là frame đứng cũ, chỉ để xem).
6. **Kéo / co giãn `GunSocket`** (bấm vào khẩu súng) cho súng che kín hai nắm tay; gốc của socket là
   điểm ôm (giữa hai nắm tay): súng xoay quanh điểm đó khi ngắm (-45°, 0°, 45°, 90°). Trong trận súng
   hiện **đúng như trong editor** ở 0° (cả `Preview` kéo lệch / co giãn không đều cũng giữ nguyên).
   (Tanko đã có súng ôm `cannon/hug_iron.png`, Flora `seed_launcher/hug_iron.png`: `Preview` trống,
   `offset` = −`hold`, editor import xong thì `pose_gun.gd` hiện ảnh. Một `Preview` đang là súng cầm
   cũ của loại đó (`<loại>/iron.png`) là ảnh tạm: có súng ôm thì `pose_gun.gd` tự thay. Spark: `Preview`
   là súng điện cũ `shock_rifle/iron.png` (chưa có súng ôm `shock_rifle_<cấp>.png`), tâm ảnh trên điểm ôm.)
7. **`Ctrl+S`**, rồi **`F5`** vào trận để xem: nhân vật tự dùng ảnh góc ngang (có `side.json` là dùng).

**Tay ôm súng (tự cắt, không cần vẽ thêm)**: cánh tay gần (tay áo từ vai tới nắm tay + cả hai nắm
tay) được cắt tự động từ `ready_v1.png` thành `side/ready_arm_front.png` (cùng khung với `ready_0.png`)
và vẽ **đè lên súng**, nên hai nắm tay luôn ôm súng ở mọi hướng ngắm. Cấu hình ở
`art_source/characters/<id>/side_run/import.json`, mục `poses.ready.armFront` (Rookie có sẵn; nhân vật
mới thì chép mục đó của Rookie vào), toạ độ là px của `ready_v1.png`:
- `polygon`: vùng tối đa được cắt (bao quanh vai, tay áo, hai nắm tay; không cần sát, nét viền đen sẽ
  tự giới hạn).
- `seeds`: mỗi mảng bị nét viền đen chia ra cần một điểm nằm bên trong (vd. bắp tay, cẳng tay, nắm
  tay); điểm phải nằm trên màu, không nằm trên nét đen.
- `darkMax` (độ sáng tối đa của nét viền), `grow` (bề dày viền giữ lại), `feather` (mép mềm).
Chạy lại lệnh ở bước 3 rồi xem `ready_arm_front.png`: thiếu một mảng tay → thêm `seed` vào mảng đó;
lẹm vào áo / ngực → thu `polygon` lại chỗ đó. Bỏ mục `armFront` = không có lớp tay (súng đè lên người).
Trong editor: thêm node `ArmFront` vào cảnh dáng ngắm (sau `GunSocket`, như cảnh của Rookie) để thấy tay
đè lên súng như trong trận.

`art_source/characters/<id>/side_run/import.json` là cấu hình chép từ Rookie (chiều cao 60 px trong
trận, cách xoá viền, `poses.ready.scale` = cỡ dáng quỳ so với ảnh chạy, …). Nếu dáng quỳ lệch cỡ /
lệch chỗ so với dáng đứng thì chỉnh `scale` (mũ / đầu rộng bằng ảnh chạy) / `alignX`, đặt `gun.grip`
= điểm giữa hai nắm tay (px của ảnh), và đổi `background` sang kiểu nền xanh như Rookie
(`"key": "corners"`), rồi chạy lại lệnh ở bước 3. Flora / Tanko là mẫu cho ảnh 1024x765: `height`
để đầu cùng cỡ với Rookie (cùng px ảnh nguồn mỗi px trong trận), `alignX` = tai trên tai của dáng
đứng, `anims.idle.fallback` = frame gọn nhất khi chưa có `side_idle/idle_v1.png` (Tanko: `[6]`);
`poses.stand` (dáng đứng yên, `idle_v1.png`): `scale` = mũ / đầu rộng bằng ảnh chạy (Rookie 1.02,
Flora 0.985, Tanko 1.0; Spark 0.97: đầu rộng hơn ảnh chạy 4 % để dáng đứng cao gần bằng, đầu không
tụt khi đứng <-> chạy; dáng quỳ của Spark cùng `scale` / `alignX` vì vẽ cùng cỡ đầu), `alignX` = tai trên
tai của `frame_1` (Tanko: `frame_7` dời theo stabilise), không có `background` (ảnh đã trong suốt: xoá
viền như ảnh chạy; Spark nền trắng: `{"key": [255, 255, 255], "tolerance": 12, "soft": 36, "holeMin":
100000000}`: chỉ xoá trắng nối với mép ảnh, nét viền đen chặn lại, chỗ sáng / trắng bên trong người giữ
nguyên, nền trắng không bị khử màu viền),
`anims.walk.fps` theo bước chân (lệnh in "walk soles": chân chạm đất lùi bao nhiêu px mỗi frame →
fps = 90 / số đó; Flora 13, Tanko 15, Spark 15, Rookie 20), `background` `holeMin` 15 / `holePure` 0 /
`spillFrom` `"keyed"` khi còn viền xanh ở khe tóc (xem `ready_0.png` phóng to).

## Re-baking the placeholder art

Run windowed (a headless run has no renderer), from the project folder:

```
$GODOT --path . -s tools/bake_art.gd                 # everything
$GODOT --path . -s tools/bake_art.gd -- icons ui     # only some groups
```

Groups: `characters`, `weapons`, `env`, `terrain`, `fx`, `icons`, `ui`, `equipment`. It overwrites the
PNGs (and the characters' `.tres` and `gun_anchors.json`, the guns' `weapons.json`), prints each file with
its size and quits. Then let the editor import them
(or run `$GODOT --headless --path . --import` while no editor is open). Baking overwrites
replaced art too: only re-bake the groups you have not replaced. Exception: while
`weapons/weapons.json` has a `"source"` (the guns are imported art, `tools/import_guns.gd`), the
`weapons` group and the weapon icons of `equipment` (`weapon_<tier>`, `weapon_<kind>_<tier>`) are
skipped.

## Files

### characters/<id>/side/ (the match side view from drawn frames: `tools/import_frames.gd`, loaded by `ui/art.gd` `side_view()`)

A character with `side/side.json` is drawn in the match (and the fallback outside it) from these
frames instead of the baked ones below (`ui/art.gd` `character_look()`: side view → baked frames →
Rookie's → empty). Today: **every character** (the same files: Flora's `flora/side/` 89x128,
walk at 13 fps; Tanko's `tanko/side/` 93x126, walk at 15 fps; Spark's `spark/side/` 94x134, walk at
15 fps; every idle is its own standing picture; heads the size of Rookie's, Tanko a little shorter
and broader, Spark a little taller (the spiky hair); no `hand.png`, they hold their gun only hugged). Facing left is the same frames mirrored round the feet
(`Flip` scale x -1): no separate files, no jump on a turn, the gun anchors and the muzzle mirror
with them and the gun stays the right way up.

| File | Size | Notes |
|---|---|---|
| `rookie/side/walk_0..7.png` | 112x130 (15–17 KB each) | the run cycle, loops at **20 fps** (the planted foot moves back about 4.5 world px a frame, so at the 90 px/s walk the feet barely slide) |
| `rookie/side/idle_0.png` | 112x130 | the standing picture (`art_source/characters/rookie/side_idle/idle_v1.png`, `import.json` `poses.stand`: scaled so the cap and the face are as wide as in the run frames, the ear over `frame_1`'s, the soles on the pivot row; the same canvas, so the run / ready PNGs did not change, and inside the run frames' `extent`); idle breathes in code (a ~1.5 % vertical stretch over 2.4 s); shoot / hurt / die reuse it |
| `rookie/side/side.json` | 1 KB | `size`, `pivot` (the feet, texture px: the same in every frame), `pxPerUnit` (0.7 = 2 texture px per world px at the match's 0.35 px per unit), `height` (figure px), `extent` {`back`, `front`, `top`} px from the pivot, `hand` (a side view without a ready pose: `hand.png`, the fist the importer cuts for the grip of a held gun; Rookie has none), `anims` {name: {`frames` (PNG names, without .png, in this folder), `fps`, `loop`, `motion`}} for `idle`, `walk`, `shoot`, `hurt`, `die` |
| `rookie/side/gun_anchors.json` | 2 KB | the baked format (below), px in these frames: the grip follows the near fist in the walk (damped, so the gun is carried at the hip and sways a little), tilted ±4° with the swing |

`motion` (`scenes/character/character.gd` `motion_pose()`, on `Flip` round the feet, mirrored with the
facing): `breathe` (idle), `recoil` (shoot: kicked back and leaning back, the gun kicks up from the
anchors, muzzle flash on frame 0), `knockback` (hurt: pushed back, squashed, a dying wobble; the red
flash is the usual tint), `fall` (die: falls on its back round the heels, lifted by `extent.back`, the
gun lying behind; then grey). Rookie's shoot / hurt / die are the idle frame with these motions, so
the whole match look is one style.

The frames are baked at **2 texture px per world px** (the figure 120 px tall, 60 world px on
screen, a bit taller than the baked characters' 52), linear filter, no mipmaps: sharper at the
match's 1:1 than an exact 1x bake (which blurs on the sub-pixel feet positions).

**Drop in new side-view frames (any character)**: put the source frames (any size, transparent
background, facing right, the feet on the ground in every frame, a loop for the walk) in
`art_source/characters/<id>/side_<name>/` with an `import.json` like Rookie's
(`art_source/characters/rookie/side_run/import.json`): `id`, `out` (`res://assets/characters/<id>/side/`),
`frames` (source files in cycle order), `alphaCut`, `keepPieces`, `defringe` {`band`, `outline`
colour, `maxChroma`}, `stabilise` {`rows` (0 top .. 1 soles: the torso band matched between frames),
`search` px}, `hipRows`, `height` (world px), `oversample`, `worldPxPerUnit`, `pad`, `anims`
(`frames`: source indices, or `"idle"` + `count` to reuse the idle PNG with a code `motion`; `fps`,
`loop`, `motion`, `swing`, per-frame `angle` / `flash`, `front`), `gun` {`fists` (the near fist
centre per source frame, source px), `carry` (source px from the pivot), `follow` (0..1),
`swingDeg`}, `hand` {`frame`, `center`, `radius`, `feather`} (cut into `hand.png` only while there is no ready pose), optional `canvas` [x, y, w, h] (source px
always inside the shared canvas) and `poses` (single drawn frames placed into the run frames' space
by `scale` / `alignX`, the soles on the soles' row: `stand`, the standing idle from
`../side_idle/idle_v1.png`, transparent, cleaned like the run frames, counted in the `extent`, used
by `anims.idle` `"frames": ["stand"]` with `"fallback"` (the run frame while that picture is missing);
`ready`, the ready pose, below: the one the `draw` anim shows). Then

```
$GODOT --headless --path . -s tools/import_frames.gd -- <id>          # one character (its side*/import.json)
$GODOT --headless --path . -s tools/import_frames.gd -- <config.json> # one config
$GODOT --headless --path . -s tools/import_frames.gd                  # every character
```

and let the editor import the PNGs. `frames` may be a pattern (`"frame_*.png"`: every match in natural
order) and an anim's `frames` `"all"` (every source frame); every character's config uses both.
A config whose source frames are not there yet is skipped; a pose whose picture is missing is left out
with the animations showing it and `gunDraw`. It writes PNG and JSON only. Per frame it clears alpha below `alphaCut`, keeps only the big
connected pieces (the stray pixels near the canvas edges go), turns the white halo round the black
outline into a soft dark edge, finds the soles (lowest row: the ground contact) and the torso's
column profile; every frame is shifted so its soles sit on frame 0's row and its torso best matches
frame 0's (the cycle runs in place, no left / right jitter); the pivot is the median hip centre on
the soles' row; one canvas round all frames; one Lanczos downscale on premultiplied colour. It
prints the shifts, the pivot and where the soles touch per walk frame (to tune `fps`: the planted
foot should move back by walk speed / fps per frame). Without a `side/` folder the character keeps
its baked frames; `tools/bake_art.gd` bakes only those (and every portrait).

**The gun in the match is holstered except to shoot** (`scenes/character/gun_draw.gd`, shown by
`scenes/character/character.gd` with `holster` on; every character). Idle and walk show no gun and
no `hand.png` over its grip, only the character's own drawn arms. A drag-to-aim draws it (holstered
→ drawing → aiming), the release fires it (firing: the usual recoil and muzzle flash) and it goes
away (holstering → holstered); a cancel holsters at once, walking with it out holsters first, and a
drag during holstering reverses from where it is. Remote and bot shots draw it fast first and their
shell appears as it is out (the replay waits that long). A character with a drawn ready pose (Rookie,
below) holds its gun only in that pose: on any other animation (hurt just after a shot, idle with
`holster` off) the gun is put away, never held in a hand. While the gun is out the body holds the
idle frame (no walk swing). Air strikes keep it holstered. The timings and the pose are one table,
`gun_draw.gd` `TIMINGS` (any side view may override keys in its `side.json` `"gunDraw": {...}`):

| Key | Default | |
|---|---|---|
| `drawSec` | 0.22 | drag start → the gun is out |
| `fastDrawSec` | 0.12 | a shot that leaves with the gun away (remote / bot shots) |
| `holsterSec` | 0.2 | put away (the reverse of the draw) |
| `fireHoldSec` | 0.4 | firing → holstering starts (the recoil is 0.33 s) |
| `carryAngle` | 75 | degrees the barrel points down in the low carry the draw starts from |
| `carryScale` | 0.55 | the gun's size in the low carry |
| `carryOffset` | [-0.05, 0.08] | the low carry from the grip: back / down, of the figure height |
| `fadeIn` | 0.35 | part of the draw the gun fades in over |
| `leanDeg` | 3 | the ready stance leans forward round the feet |
| `crouch` | 0.015 | and squats (scale y) |
| `squash` | 0.03 | a squash-and-stretch bump through the middle of the draw |

Without drawn frames the draw is that code transition (eased out: the gun turns up from the low
carry to the aim, grows and fades in; the body leans and squats into the ready stance).

**Drawn draw frames (optional, a side view)**: add `side/draw_0.png .. draw_N.png` (same canvas and
pivot as the other frames) and list them in `side.json` `anims`: `"draw": {"frames": ["draw_0", ...]}`
(no `fps`: they are shown by the draw's progress, so holstering plays them backwards and a reverse
never jumps). Frame 0 is the holstered stance (the idle pose), the last frame the ready-to-shoot
stance, which is also held while aiming (instead of the idle frame) and has no code lean. Give them
gun anchors in `gun_anchors.json` `"draw": [...]` (one per frame, as the other animations: `grip`,
`angle`, `front`, `flash` 0) to have the gun follow the drawn hand (from the hip or the back, `front`
false while it is behind the body; the aim angle blends in towards the last frame); without anchors
the gun does the code transition on top of the drawn body. A broken set (a missing PNG) is skipped
with a warning and the code transition plays.

**Rookie's ready pose (kneeling, hugging a big gun)**: `side/ready_0.png` is the kneeling pose cut
from `art_source/characters/rookie/side_ready/ready_v1.png` (882x1024: kneeling, facing right, both
fists together in front of the chest, no gun, on a flat green backdrop). `import.json`
`poses.ready`: `background` `{"key": "corners", tolerance, soft, holeMin, spill}` keys the backdrop
out (`tools/import_frames.gd` `key_background()`: the key is the median corner colour; the backdrop is
what is near it and touches the border plus big enclosed pure-key holes; alpha ramps over `soft`, the
colour is un-blended from the key and the key channel is capped in the `spill` px next to it: no green
rim; `"spillFrom": "keyed"` measures that band from every keyed pixel, the partly keyed ones too:
Flora's and Tanko's, whose thin wedges of backdrop between hair strands kept a green tip; a white or
grey key has no spill: nothing is capped, Spark's standing picture `poses.stand.background` `{"key":
[255, 255, 255]}` with a `holeMin` too big for any enclosed white to go), then `clean()` with the pose's own `alphaCut` / `keepPieces` drops the small detached pieces
(the AI "✦" sparkle), trimmed, scaled by `scale` so the cap and the head are as wide as in the run
frames (the kneeling figure is nearly as tall as the standing one: its head is drawn bigger), the
belt buckle over `frame_1`'s (`alignX`), the knee and the boot on the same ground. `gun.grip` is
the hug point (the middle of the two fists, pose px): the fallback seat in `gun_anchors.json`
`"draw"` / `"fire"` / `"ready"`. `canvas` pins the shared canvas to the earlier one, so the run frames'
PNGs did not change. No hand cut-outs. In `side.json`: `"draw": ["ready_0"]`, `"fire"` (it with the
recoil, played for the shot instead of `shoot`), `"gunDraw"` all 0 s (idle ↔ ready switch at once, no
transition; back to idle `fireHoldSec` after the shot or at once on a cancel) and `"readyPose"`
{`anims`, `scene`, `armFront`}.

**The front arm over the gun**: `poses.ready.armFront` cuts the near arm (the sleeve from the
shoulder to the fist, and both fists) out of the cleaned pose into `side/ready_arm_front.png`, same
canvas / pivot / scale as `ready_0.png` (`tools/import_frames.gd` `arm_mask()`, pose px of
`ready_v1.png`): a flood fill from `seeds` (one point inside each piece the outline walls in: the upper
arm, the forearm, the fists) through the non-dark pixels inside `polygon` (the most it may take), the
dark outline (max channel ≤ `darkMax`) the barrier, grown `grow` px over the outline so the arm keeps
its own black edge, the holes it encloses filled, the edge feathered `feather` px inward; then
resampled like `ready_0`. The game draws it over the hugged gun (`character.gd` Flip/ArmFront, at the
body's place, mirrored with it), so the fists stay on the gun at every direction (the gun turns
round the point between them); the body under it still has the arm (no hole). A new character: copy
Rookie's `armFront`, set the polygon and seeds on its picture, re-import and look at the PNG (a piece
missing: a seed in it; torso cut: tighten the polygon there). No `armFront`: no arm layer.

| File | Size | Notes |
|---|---|---|
| `rookie/side/ready_0.png` | 112x130 | the kneeling ready pose, fists on the chest, no gun (same canvas / pivot as the run frames) |
| `rookie/side/ready_arm_front.png` | 112x130 | the near arm and both fists cut from it, drawn over the gun (same canvas) |

**The hug gun**: on the ready pose the character hugs a big gun against the middle of the chest
(`weapons/<kind>/hug_<tier>.png`, below), drawn in front of the body and under the front arm (no hand
sprites, no grip hand), turned round the hug point to the snapped direction (`aim_snap.gd`: -45, 0,
45, 90 above level towards the facing side; facing left is mirrored; the shot, the aim line, the
power and the network keep the real angle). Which gun (`ui/art.gd` `hug_gun()`): the equipped
weapon's hug art (its kind / tier, `screens/home/equipment_model.gd` `gun()`) → the kind's hug art in
another tier (iron first) → the weapon's held gun sprite turned round its own centre; no weapon (bots,
the starter gun) = the kind's `basic`. Rookie's bazooka, Tanko's cannon and Flora's seed launcher have hug art in all five
tiers (basic, iron, steel, mithril, dragon), all the same length per kind, so a tier swap does not
resize or move the gun. A gun other than the Preview's is drawn as
long as the Preview's, its pivot (hold / centre) on the Preview gun's. The shot kicks the gun back
along its axis (`character.gd` `HUG_KICK` = 5 % of its length × the fire frame's flash 1 / 0.35 / 0)
on top of the body's `recoil` motion; the muzzle flash is at the turned muzzle.

**Placing the hug gun in the ready pose (editor)**: each character with a ready pose has its own pose
scene, `scenes/character/poses/<id>_ready.tscn` (side.json `readyPose.scene`; all four exist and are
used. A `Body` with `pose_body.gd` (editor only: Flora, Tanko, Spark) shows the ready frame by itself once
the editor has imported it, or the baked idle frame while there is no side view). It is the character's `Flip` space at the match's scale (the root is the feet, locked;
`Body` = the ready frame, locked). One `GunSocket` (Node2D, grouped: a click on the gun selects it):
its origin is the hug point the gun turns round; its `Preview` child (Sprite2D) is the gun at 0°,
horizontal, facing right, centred on its hold (`offset` = −`hold` of `weapons/hug.json`; Rookie's has
`pose_gun.gd`: it shows the `kind` / `tier` hug gun as soon as the editor has imported it, since a
scene can only name an imported picture (Tanko's and Flora's: empty, the offset already −`hold` of
the hug cannon / seed launcher, until then); a Preview showing its kind's held iron gun sprite is a
stand-in `pose_gun.gd` swaps for the hug gun once the kind has one: Spark's iron shock rifle, its
centre on the hug point, `offset` = −size / 2). Move / scale / rotate `GunSocket` (or the `Preview` inside
it, even non-uniformly) until the gun covers the fists, `Ctrl+S`, `F5`: **the match draws the gun
exactly as the Preview shows it at 0°** (the Preview's position / scale / offset and the socket's,
`ui/art.gd` `ready_pose()` / `gun_transform()`), and turns the whole socket round its origin. Check it
at level, 45 and straight up. Every scene also has `ArmFront` after `GunSocket` (locked, the Body's
scale / offset; `pose_arm.gd` shows `ready_arm_front.png` once imported): the front arm over the gun,
as in the match. No JSON to edit; `tools/import_frames.gd` never writes the scene. Without
the scene (or a node) the gun sits on `gun_anchors.json` `"ready".grip` (the hug point), the
character's iron hug gun at the weapons' scale, level.

### characters/ (baked frames, scene: `scenes/character/character.tscn`)

The frames draw the character with its hands free (the front arm reaches forward, the hand at the gun's
grip); the gun is a separate sprite (`weapons/`) the scene draws at the hand, so it changes with the
equipped weapon.

| File | Size | Notes |
|---|---|---|
| `<id>/idle_0..3.png` | 512x400 each | loops, 2.5 fps; upper body breathing |
| `<id>/walk_0..5.png` | 512x400 each | loops, 9 fps; leg swing, bob, forward lean |
| `<id>/shoot_0..2.png` | 512x400 each | once, 9 fps; the hand recoils (the muzzle flash is drawn at the gun's muzzle from the anchors' `flash`) |
| `<id>/hurt_0..2.png` | 512x400 each | once, 7 fps; knocked back, wobble, squint (the red flash is code) |
| `<id>/die_0..3.png` | 512x400 each | once, 8 fps, holds the last frame; falls on its back (the grey tint is code) |
| `<id>/<id>.tres` | – | SpriteFrames of the five animations |
| `<id>/gun_anchors.json` | 2 KB | per animation, one entry per frame: `grip` [x, y] px in the frame (the hand's centre, where the gun's grip goes), `angle` degrees (0 = level, + turns the muzzle down; recoil kick, walk lean, hurt wobble), `front` (gun over the body; `false` in `die`: behind), `flash` 0..1 (muzzle flash) |
| `<id>/portrait.png` | 128x128 | head and shoulders: Profile and Shop character cards |
| `shadow.png` | 160x38 | ground shadow under every character, centred on the feet |
| `hand.png` | 32x32 (0.5 KB) | the hand drawn over the gun's grip, centred on the grip (shared) |

No character has these frames today (every one has a side view: only its `portrait.png` is baked); they
are what `tools/bake_art.gd` draws for a character without a side view and the match's fallback when a
side view is missing or broken (about 13–24 KB per frame). **Every frame**: canvas
512x400, transparent, **feet at pixel (256, 360)** (bottom centre, the same pixel in every frame),
facing right, drawn at 1.6 px per art unit (the character is about 150 units = 240 px tall).
The game flips it for facing left. The match (`match/views/player_view.gd`, 0.35 px per unit,
about 52 px tall, feet on the server position) and the fallback of the screens outside it
(`ui/character_view.gd`, about 2.5 and 1.5 px per unit, when a character has no full-body
picture; the lobby stage's `hands_free` hides the gun, the bare hand stays).

### characters/<id>/lobby/full.* (the full-body picture: `scenes/character/full_body.gd`, loaded by `ui/art.gd` `lobby_full()`)

Outside the match (lobby stage, Prep, Nhân vật: `ui/character_view.gd` turns
`scenes/character/character.gd` `lobby_full` on) a character is **one coherent
full-body drawing** cut from `art_source/characters/lineup_v1.png` (1024x765, the four characters
side by side on white), skinned on a skeleton: a Polygon2D mesh over the picture weighted to
Bone2Ds under a Skeleton2D. It has no gun hand, so no gun is drawn on it: the worn gun rests on
the pedestal beside it (`screens/home/pedestal_gun.gd`, on the lobby, the Nhân vật page and Prep
scaled to its stage). It only idles (breathing, a head nod and tilt, a slight arm sway, plus one
per-character flourish: Rookie waves the raised hand, Spark wiggles the V-sign, Flora nudges her
fist, Tanko breathes heavier with his shoulders); feet stay planted. The match is unchanged.
Missing or broken full.json / full.png → the frames above.

| File | Size | Notes |
|---|---|---|
| `<id>/lobby/full.png` | 190–224 x 363–392 (110–120 KB) | transparent, the figure 346–375 px tall, drawn 1:1 on the lobby stage (scale 0.64 × the stage's 1.5625) |
| `<id>/lobby/full.json` | 33–36 KB | generated: `size`, `pivot` (the feet: the middle of the boots' outer edges, the soles' bottom, px in full.png), `height`, `scale` (full.png px → character px), `bones` (`name`, `parent`, `at` the joint, `tip` the end of its segment, `strength`; px in full.png), `anims` (this character's tracks), `mesh` (`vertices` px = uv, `triangles` 3 indices each), `weights` (per vertex: bone index, weight, …; at most 4, summing to 1) |
| `lobby_full_anims.json` | 1 KB | the idle every full-body picture plays (per animation `length` (s), `loop`, `tracks`: bone → `t` key times and `rot` degrees added to the rest rotation, `x` / `y` px added to the rest position, `sx` / `sy` scale, one value per key; bones `root`, `hips`, `chest`, `head`, `arm_l_upper` / `arm_l_fore` / `hand_l`, `arm_r_*`, `leg_l_thigh` / `leg_l_shin` / `foot_l`, `leg_r_*`; l / r = the picture's left / right); a full.json's `anims` replace or add tracks by bone |

**Re-cutting / a better picture**: put the new lineup (or one picture per character) in
`art_source/characters/`, edit `art_source/characters/lineup_parts.json` (`sheet`; per figure its
`rect` [x, y, w, h] in sheet px (loose is fine) / a `seed` point on it / `holes` (enclosed whites to clear) / optional `clip` (a convex polygon, with `feather` px of soft edge), `scale` so the figure comes out at most about
375 px tall, the `joints` in sheet px: `hips`, `chest`, `neck`, `crown`, `l_` / `r_` `shoulder`,
`elbow`, `wrist`, `hand`, `hip`, `knee`, `ankle`, `toe`, and its `anims` flourish), then run
`$GODOT --headless --path . -s tools/cut_sheet.gd [-- <id> ...]` and let the editor import
the PNGs. It writes full.png and full.json (mesh and weights by `tools/full_mesh.gd`: outline
points every 5 px round the figure grown 2 px plus an inner grid, Delaunay-triangulated, kept
inside the figure so the gaps between an arm and the body stay out of the mesh, every visible
pixel covered; weights by the distance through the figure's own pixels, so a raised hand next to
the head does not drag the head). Keep the motion small: an arm drawn over the body has no body
pixels under it, so a large arm move stretches the body with it.

### weapons/ (the held guns: `scenes/character/character.gd` Flip/Gun, paths in `ui/art.gd`)

```
weapons/
  weapons.json                      grip + muzzle of every sprite, pxPerUnit
  bazooka/        hug_basic hug_iron hug_steel hug_mithril hug_dragon   (Rookie's: hug art only, below)
  cannon/         hug_basic hug_iron hug_steel hug_mithril hug_dragon   (Tanko's: hug art only, below)
  shock_rifle/    basic iron steel mithril dragon          (Spark's)
  seed_launcher/  hug_basic hug_iron hug_steel hug_mithril hug_dragon   (Flora's: hug art only, below)
  blaster/        basic iron steel mithril dragon silver gold titan diamond   (generic + crafted)
  hug.json                          size + hold + muzzle of every hug gun
  <kind>/hug_<tier>.png             the hug guns of the ready pose (today: bazooka/, cannon/ and seed_launcher/ hug_basic, iron, steel, mithril, dragon)
```

| File | Size | Notes |
|---|---|---|
| `<kind>/<tier>.png` | shock_rifle 75x39, blaster 68x36 (4–6 KB, 14 files; no bazooka, cannon, seed launcher) | side view facing right, transparent, cut from `art_source/weapons/guns_v1.png` by `tools/import_guns.gd`; one canvas per kind with every tier's grip on the same px. Baked at 2 texture px per match world px (like Rookie's side frames): the iron gun is 34 (shock rifle), 31 (blaster) world px long next to a ~60 px character, its pistol grip about the size of a side view's `hand.png`. Kind = silhouette (sheet row; the seed launcher, bazooka and cannon rows are not cut any more), tier = look (sheet column: iron, steel, mithril, dragon); `basic` = iron desaturated (the character's starter gun); the blaster is the shock-rifle row, its crafted tiers palette swaps of the mithril one (silver cool grey-white, gold warm gold, titan dark gunmetal purple, diamond icy white-cyan with sparkles) |
| `weapons.json` | 4 KB | `{"source": "art_source/weapons/guns_v1.json", "pxPerUnit": 0.7, "guns": {kind: {tier: {"size": [w, h], "grip": [x, y], "muzzle": [x, y]}}}}`, px in the image. `pxPerUnit` = texture px per art unit (the gun is drawn at 1.6 / pxPerUnit character px per texture px: 0.7 = 2 texture px per match world px). `grip` is the pivot (placed on the frame's anchor: the fist's centre on the pistol grip / rear handle), `muzzle` is where the flash starts (the barrel opening, the rocket / barrel tip, the dragon's mouth; visual only). `source` marks imported art (`tools/bake_art.gd` then skips the guns) |

**Importing the gun sheet** (`$GODOT --headless --path . -s tools/import_guns.gd`, ~20 s): per cell of
`guns_v1.json` (`rect`, `grip`, `muzzle`, `keep`, sheet px) the white background is flood-filled from the
cell border, enclosed pure-white areas of `holeMinArea`+ px are holes too (the trigger guard's inside, a
dragon's open mouth) except the ones under `keep` (the rocket's stripes, a screen's line); the edge is
un-blended from white (no halo). Each tier gets its `recolour` at sheet resolution (`basic`: HSV
multipliers; the crafted blasters: ramp rules mapping a hue range onto a palette by luminance, keeping the
shading and the outline), the kind's tiers go on one grip-aligned canvas and are scaled once (Lanczos, the
kind's iron gun `length` world px × `texPxPerWorldPx`). The icons: the same canvas turned `tiltDeg` (muzzle
up), each file group fitted into 128 − 2 × `margin`. New PNGs get an `.import` (mipmaps for icons); an
existing one is kept.

Which gun: `screens/home/equipment_model.gd` `gun()` maps a weapon item to {kind, tier}
(`rookie_weapon_lv30` → bazooka/mithril, `crafted_weapon_gold` → blaster/gold, `normal_weapon_lv10` →
blaster/iron, no weapon → the character's kind/basic). `ui/art.gd` `gun()`: the kind / tier's held sprite,
else its hug art (a kind with no held sprites: the bazooka, the cannon, the seed launcher; its hold as the grip); a missing tier falls back
to the kind's `basic`, a missing kind to `blaster/basic`. Lobby, Prep and the Nhân vật page show the weapon the
character wears: with the full-body pictures (no gun hand) the worn gun rests on the pedestal at the
character's left on all three (Prep: scaled to its small stage, without the label; with the frames fallback
Prep and Nhân vật show it in hand, `ui/character_view.gd`, except a character with a ready pose, every one today: theirs only in that pose), lying diagonally with the muzzle up-left, its name and
"+N" under it (`screens/home/pedestal_gun.gd`, a soft glow in the tier's colour); the match shows the one each player brought (`weaponItemId`), and its
shots look like that gun (`fx/` below).
The JSON files are read with `FileAccess` (an export that filters resources must keep `*.json`).

**Hug guns** (the big gun a drawn ready pose hugs, `ui/art.gd` `hug_gun()`, Rookie's pose above):
`<kind>/hug_<tier>.png` (bazooka: `hug_basic`, `hug_iron`, `hug_steel`, `hug_mithril` 118x41,
`hug_dragon` 118x42, 7–9 KB; cannon: `hug_basic`, `hug_iron`, `hug_steel`, `hug_mithril` 108x54,
`hug_dragon` 108x57, 10–13 KB; seed launcher: `hug_basic`, `hug_iron`, `hug_steel`, `hug_mithril`
94x42, `hug_dragon` 94x44, 6–8 KB) cut from `art_source/weapons/hug/<kind>_<tier>.png` (the gun alone,
horizontal, muzzle right, no hand grips, a flat backdrop, green or magenta (the key is the corners'
colour): `bazooka_iron`, `bazooka_mithril` (blue
crystal), `bazooka_dragon` (red / orange dragon); on magenta the short, very thick riveted
cannons `cannon_iron` (gunmetal grey breech and bands, olive barrel), `cannon_steel` (orange breech and
bands, olive barrel), `cannon_mithril` (ice blue with frost engravings, silver bands), `cannon_dragon`
(crimson with gold riveted bands, a dragon's head muzzle with fire in its mouth); `seed_launcher_iron` (grey back cap, olive tube, a leaf sight,
a green seed pod), `seed_launcher_steel` (pink-red cap, silver tube, pale pod), `seed_launcher_mithril`
(sky blue with gold swirls, a glowing turquoise crystal), `seed_launcher_dragon` (deep red with gold
bands, a dragon's head with a fiery seed in its mouth)) by

```
$GODOT --headless --path . -s tools/import_hug_guns.gd                    # every picture there
$GODOT --headless --path . -s tools/import_hug_guns.gd -- bazooka_iron    # some
```

(`art_source/weapons/hug/hug.json`: `length` world px, 57 = about 1.5 × Rookie's kneeling body width;
the keying options; per gun `length`, `hold`, `muzzle` overrides in source px, `background` key options
over the shared ones and `despill` (no key colour left anywhere: `bazooka_dragon`, a shaded pocket of
backdrop between its collar and head, `holeMin` 15 / `holePure` 0), and `from` + `recolour` for a tier
made from another tier's picture: the same shape, hold and muzzle, recoloured by `tools/import_guns.gd`
`recolour()` (the held guns' specs, plus `hue` shift and `hueRange`). `bazooka_basic` = iron × the held
guns' `basic` (saturation 0.55, value 0.94, as the held guns' `basic.png` is made from `iron.png`);
`bazooka_steel` = iron with the olive (hue 45–135°) shifted −4.5°, saturation × 1.25, value × 0.975, the
red warhead kept (fitted from the old held bazooka `steel.png` against `iron.png` on matching pixels);
`cannon_basic` = iron × the same `basic` (the old held cannon `basic.png` against `iron.png`: saturation
× 0.553, value × 0.934). The cannon is 52 world px long (every tier, the dragon's head counted; the
bazooka 57) and about 25 thick: short and very thick, a big heavy gun on Tanko that still leaves his
face clear at 0°; no longer, or its back end would sink below his soles aiming straight up (his hug
point is 119.43 pose px above the soles = 52.25 world px of half-length; 52 leaves it 0.6 pose px
above). Held in the middle; its `muzzle` the centre of the bore opening (inside the muzzle ring; the
dark bore is part of the gun), the dragon's open mouth; magenta keyed with `despill` `hueRange`
270–320 like the seed launcher; `cannon_dragon` `holeMin` 15 / `holePure` 0 (the pockets between the
teeth and round the horns), the fire in its mouth is solid art inside the outline (no glow), the small
ember sparks floating past the mouth are dropped as stray pieces. The seed launcher is 45 world px long (every tier, the dragon's head
counted): Flora's hug point is lower still (104.96 pose px above her soles = 45.9 world px of tube),
so aiming straight up its back end stays just above the ground; held in the middle, its `muzzle` the
middle of what sits in the bore (the pod, the crystal, the dragon's seed), `seed_launcher_basic` = iron
× `basic` (fitted on the old held `basic.png`: × 0.552 / × 0.936). On magenta the spill is the part of
red and blue above green (`key_background()`: a pink rim turns grey, a red keeps its red), `despill`
`{"hueRange": [270, 320]}` blackens the purple-tinted outline pixels only (the steel cap's pink is hue
335+, the dragon's crimson 340+, untouched); `seed_launcher_dragon` keys small pockets (horn / tube,
between the teeth) as holes (`holeMin` 15, `holePure` 0). A glow painted into the backdrop (the
mithril crystal, the dragon's seed): `background.glow` {`colour`}: each pixel on the line from the key
to that colour is un-mixed into the colour at the alpha of how far along it is (no pink halo; `alpha`
0 keys it away); the gun is measured without it (the tube as long as the other tiers') and the glow
fades out over the pad round it, so every tier's PNG is as wide. Naming a picture on the command line also re-makes the tiers made from it). It keys the backdrop
out like the ready pose (`key_background()`), drops the detached pieces (the "✦" sparkle), trims,
finds the hold (the middle of the gun at the tube's height: the median of the columns' middles, so a
sight does not lift it) and the muzzle (the right end on that axis) and scales once to `length` ×
2 texture px per world px. `hug.json` `{"source", "pxPerUnit": 0.7, "guns": {kind: {tier: {"size",
"hold", "muzzle"}}}}` (px in the PNG; the guns not imported in a run are kept). New PNGs get an
`.import`; let the editor import them (until then the game reads the PNG). The bazooka, the cannon
and the seed launcher have no held sprites (`bazooka/<tier>.png`, `cannon/<tier>.png`,
`seed_launcher/<tier>.png` were the old guns with hand grips, cut from `guns_v1.png`): wherever a gun is shown it is the hug art. The pedestal gun of the lobby, Prep and
the Nhân vật page is `hug_<tier>.png` (`gun()`), the same lean and fit as the other guns; Rookie,
Tanko and Flora never hold it outside the ready pose (put away, above); another character with one
of these guns (the server lets only Rookie / Tanko / Flora equip theirs, `CanEquipOnCharacter`; bots
carry their character's basic gun) would hold the hug gun by its middle.

**Their icons** (hug.json `icons` {`files` {`weapon_bazooka_<tier>`, `weapon_cannon_<tier>`, `weapon_launcher_<tier>`: {gun, tiers}}}): each tier's picture
keyed and cleaned as above, scaled at source resolution so every tier's tube is as long as the first's,
lined up on the hold, then turned, fitted and scaled exactly like the held guns' icons
(`tools/import_guns.gd` `icons()`, with `guns_v1.json`'s `size` 128, `margin` 6, `tiltDeg` −14 unless
hug.json sets them): `icons/equipment/weapon_bazooka_<iron|steel|mithril|dragon>.png` and
`weapon_cannon_<…>.png`, `weapon_launcher_<…>.png`, rewritten by every run that imports a gun of that kind.

### env/

| File | Size | Pivot / layout | Used by |
|---|---|---|---|
| `lobby_bg.png` | 1600x900 (176 KB) | stretched over the screen | `ui/backdrop.gd` (lobby, Profile, Shop, Prep) |
| `lobby_ground.png` | 1600x360 (7 KB) | the bottom 40% of the lobby screen (hill + stage ovals), transparent above | `ui/backdrop.gd` (lobby only) |
| `pedestal.png` | 400x112 (5 KB) | the feet stand at (200, 52) | lobby stage, Prep panel (drawn at 0.66x0.6) |
| `sky_match.png` | 1600x512 (29 KB) | stretched over the map plus 600 px each side (2800x900 for the default map); sun and hills included | `match/views/sky_view.gd` |
| `cloud_0..2.png` | 288x160 (6–9 KB) | centred; drawn at half size times a random 0.7–1.4 scale | `match/views/sky_view.gd` |

### terrain/ (`match/terrain/terrain.gdshader`, set by `terrain_view.gd`)

| File | Size | Layout |
|---|---|---|
| `dirt.png` | 128x128 (12 KB) | tiles both ways, one texel per world px; the shader darkens it with depth and adds the burnt crater rim |
| `grass_edge.png` | 128x24 (1 KB) | tiles horizontally. Rows 0–5: tufts in the air above a surface (row 5 touches it). Rows 6–23: the grass band from the surface down. Transparent = air (tufts) / dirt (band) |

The terrain mask stays the source of truth: the shader only decides colours per mask pixel.

### fx/ (shots: `match/views/projectile_view.gd`, `explosion_fx.gd`; looks in `match/views/shot_look.gd`)

A shot looks like the shooter's **gun**: its weapon's kind and tier (`weaponItemId` → `EquipmentModel.gun()`;
no weapon or a bot → its character's kind, `basic`). The **kind** is the bullet and the impact's theme, one
folder each; the **tier** is the intensity, from one table (`ShotLook.TIERS`) and the shared overlays in
`tiers/`, so no tier has images of its own. Visuals only: the path, timing, crater and damage are the server's.

```
fx/
  common/          bomb.png, smoke.png, debris.png, muzzle.png
  bazooka/         projectile.png (a rocket), trail.png, impact_0..5.png (fire explosion)   ← its impact is every fallback
  cannon/          projectile.png, trail.png, impact_0..5.png
  shock_rifle/     projectile.png, trail.png, impact_0..5.png
  seed_launcher/   projectile.png, trail.png, impact_0..5.png
  blaster/         projectile.png, trail.png, impact_0..5.png
  tiers/           glow, sparkle, ember, coin, shard, ring, flare, crack (.png)
```

| File | Size | Notes |
|---|---|---|
| `common/bomb.png` | 48x48 (2 KB) | the round bomb: ball centred, flying towards +x, fuse behind; 2 px per world px. What an air strike drops (with the basic bazooka's trail and fire explosion) and the fallback projectile of a kind whose own file is missing |
| `common/muzzle.png` | 64x64 (5 KB) | a flash star: the bomb's fuse spark, the rocket's flickering exhaust flame (stretched), the guns' muzzle flash |
| `common/smoke.png` | 128x128 (21 KB) | soft puff, light grey (tinted and faded in code) |
| `common/debris.png` | 24x24 (1 KB) | light grey chunk (tinted dirt/grass in code) |
| `bazooka/projectile.png` | 88x40 (3 KB) | a rocket in the hug bazooka's colours (red warhead with two white stripes, olive body, three tail fins, dark nozzle, a short exhaust flame), thick dark outline, cel shaded; flying towards +x, its middle centred, 2 px per world px (44x20 world px). The game turns it to the flight direction (every projectile is) |
| `<kind>/projectile.png` | 64x64 (1–6 KB) | centred, flying towards +x, 2 px per world px: `cannon/` heavy iron ball, `shock_rifle/` cyan plasma orb with arcs, `seed_launcher/` seed pod with a leaf, `blaster/` an energy bolt drawn **white** (the game colours it with the tier) |
| `<kind>/trail.png` | 32x32 (0.5–2 KB) | the trail particle: bazooka a lumpy white-grey exhaust puff (coloured in code from fire to grey smoke over its life, `ShotLook.KINDS` trail `hot` / `cool`), cannon grey smoke, shock rifle cyan spark, seed launcher pink petal, blaster white spark (tinted) |
| `<kind>/impact_0..5.png` | 256x256 (10–71 KB) | the burst, centred, drawn for a radius-60 crater (scaled to the real radius times the tier's scale), played over 0.5 s: bazooka fire explosion, cannon heavy dark-orange blast with soot (drawn 1.2x, more debris), shock rifle electric burst, seed launcher green flash with petals, blaster white energy burst (tinted). A missing file falls back to the bazooka's |
| `tiers/glow.png` | 64x64 (2 KB) | soft round glow, white: projectile halo, impact flash, the lobby gun's glow |
| `tiers/sparkle.png` | 32x32 (1 KB) | four-point star, white: mithril / silver trails, impact sparkles (diamond's linger) |
| `tiers/ember.png` | 32x32 (1 KB) | hot ember, white: dragon / titan trails and impacts (tinted fire) |
| `tiers/coin.png` | 32x32 (1 KB) | a gold coin (own colours): gold trail and impact |
| `tiers/shard.png` | 32x32 (1 KB) | crystal shard, white: diamond trail and impact (rainbow tints) |
| `tiers/ring.png` | 256x256 (20 KB) | shockwave ring (band at 0.86 of the half size), white |
| `tiers/flare.png` | 256x256 (9 KB) | lens-flare burst (streaks, star, ghost rings), white |
| `tiers/crack.png` | 256x256 (29 KB) | dark ground cracks radiating out of a transparent middle (titan) |

Every overlay is optional: a missing one is left out. The tier table (`ShotLook.TIERS`; colours from the
guns' tier palettes, `tools/art/weapon_painter.gd` / `equipment_painter.gd`):

| Tier | Projectile | Impact |
|---|---|---|
| basic, iron | the kind's own look | the kind's burst |
| steel | 1.05x, a little glow, brighter wider trail | 1.05x, a blue flash |
| mithril | 1.1x, teal glow, sparkle trail | 1.12x, teal flash, 14 sparkles |
| dragon | 1.15x, fire glow, ember trail | 1.25x, fire flash, a shockwave ring, 22 embers |
| silver | 1.12x, silver glow, glint trail | 1.18x, a ring, 20 sparkles, a small flare |
| gold | 1.18x, golden trail, coin sparks, a hot core | 1.3x, bright flash, a ring, 18 coins, 14 sparkles, flare, faint gold screen tint |
| titan | 1.22x, heavy thick trail, embers | 1.4x, double ring, 26 embers, more debris, ground cracks, orange screen flash |
| diamond | 1.25x, rainbow glow, crystal-shard trail | 1.45x, double rainbow ring, 18 shards, 24 sparkles that linger, lens flare, screen flash |

A skill shot is 1.3x with a brighter glow and a 1.1x impact with more particles; an item shot keeps its item
tint and mark on top. Particles stay within 120 per impact and 48 per projectile.

### icons/ (96x96 each, 1–7 KB, transparent, dark outline)

| Icon | Used by |
|---|---|
| `gem`, `coin`, `plus` | wallet pills, Shop prices and gem packs |
| `characters`, `inventory`, `history`, `shop` | lobby right column |
| `arrow_left`, `arrow_right` | lobby character arrows, match move buttons, the wind direction |
| `swap` | lobby mode switch |
| `send` | lobby chat box |
| `back` | "Sảnh" buttons (Home pages, Prep) |
| `close` | match "Thoát" |
| `end_turn` | match "Hết lượt" |
| `weapon` | match "Vũ khí" |
| `skill` | match skill button, lobby / Prep skill line |
| `battle` | Prep mode pill |
| `check` | Prep: a picked item |
| `medkit`, `teleport`, `power_shot`, `drill_bomb`, `spider_net`, `freeze_bomb`, `air_strike`, `wind_stopper` | item cards (Prep, Profile inventory, Shop) and match item buttons; the file name is the item id |
| `unknown` | fallback for a missing icon or an unknown item |

### icons/equipment/ (`tools/art/equipment_painter.gd`, paths in `ui/art.gd` EQUIP_*)

| File | Size | Notes | Used by |
|---|---|---|---|
| `<slot>_<tier>.png` | 128x128 (1.5–3 KB) | one per slot × tier, transparent, dark outline. Slots `weapon`, `armor`, `helmet`, `pants`, `boots`, `gloves`; tiers `iron` (Sắt, grey), `steel` (Thép, blue steel), `mithril` (teal), `dragon` (Rồng, red + gold) for shop items, `silver` (Bạc), `gold` (Vàng), `titan`, `diamond` (Kim cương) for crafted ones. A normal item's tier comes from its name / id (`screens/home/equipment_model.gd` `tier()`); an unknown tier draws as iron | Shop → Trang bị, Túi đồ, Nhân vật slots and list, piece popup, Prep gear row |
| `weapon_<tier>.png` | 128x128 (10–15 KB) | cut from the blaster guns (`tools/import_guns.gd`, tilted 14°, muzzle up); weapons are guns: the generic blaster per tier (retired generic weapons, crafted Silver/Gold/Titan/Diamond Blaster); also the empty weapon slot's shape | as above |
| `weapon_<kind>_<iron\|steel\|mithril\|dragon>.png` | 128x128 (9–17 KB) | cut from that kind's held guns (`tools/import_guns.gd`, as above; the bazooka's and the cannon's from their hug art, `tools/import_hug_guns.gd`, the same look); each character's gun in the shop tiers: `bazooka` (Rookie), `cannon` (Tanko, đại pháo), `rifle` (Spark, súng điện), `launcher` (Flora, súng hạt). The kind comes from the item's `characterId` (`equipment_model.gd` `weapon_kind()`); a missing or not yet imported file falls back to `weapon_<tier>.png` | as above |
| `slot_<slot>.png` | 128x128 (1 KB) | the slot's shape in plain white; the UI tints it faint blue for an empty slot | Nhân vật slots, Prep gear row |
| `hex_empty.png`, `hex_filled.png`, `hex_selected.png` | 132x152 (7 KB) | pointy-top hexagon (radius 70) centred: empty (dark, faint rim), filled (blue, light rim), selected (gold rim + glow); stretched to the slot size | Nhân vật slots (shown at 0.85), piece popup, Prep gear row |
| `badge.png` | 52x32 | the "+N" pill (dark, gold rim); 9-patch, texture margins 15 all (`EQUIP_BADGE_MARGINS`) | upgrade level on every equipment icon |

### ui/ (9-patches, `StyleBoxTexture` via `ui/art.gd` `ui_box()`)

| File | Size | Texture margins (l, t, r, b) | Used by |
|---|---|---|---|
| `button_primary.png` | 104x110 | 36, 36, 36, 42 (+12 glow outside the button) | the big yellow buttons (BẮT ĐẦU, VÀO TRẬN, Về sảnh) |
| `button_primary_pressed.png` | 104x110 | 36, 36, 36, 42 (+12 glow) | the same, pressed |
| `button_navy.png` | 64x64 | 18 all | default Button of the Home theme (Profile, Shop, dialogs) |
| `button_orange.png` | 80x80 | 26, 26, 26, 30 | match "Hết lượt" |
| `button_disabled.png` | 64x64 | 18 all | disabled state of the textured buttons |
| `panel.png` | 72x72 | 22 all | lobby / Prep / chat panels |
| `panel_selected.png` | 64x64 | 20 all | Prep: a picked item card and a filled slot |
| `pill.png` | 56x56 | 27 all | wallet pills, "Sảnh" buttons |
| `avatar_frame.png` | 96x96 | 24 all | the frame over the lobby avatar |

Hover and pressed states are the same image, lighter or darker (`modulate`). Panels in other
colours (HUD, cards) stay plain `StyleBoxFlat` in code.
