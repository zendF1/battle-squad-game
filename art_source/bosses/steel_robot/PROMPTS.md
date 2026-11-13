# Đĩa Bay Thép: prompt tạo ảnh boss

Boss id vẫn là `steel_robot` (trước là Rô-bốt Thép): lịch sử trận, thưởng ngày, khoá ảnh đều theo id
này. Nay nó là một **đĩa bay thép lơ lửng**, phi công người ngoài hành tinh xanh lá ngồi trong vòm
kính, hai nòng pháo bên phải, hai chân đỡ và một vuốt kẹp dưới bụng có lửa đẩy.

Dùng cho AI vẽ ảnh (Gemini qua `tools/gen_image.py`, GPT-image, Flux…). Prompt viết bằng tiếng Anh
vì các model hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế là thiết kế riêng của
game, không lấy theo game nào khác: đừng thêm tên game / tên hãng / "in the style of <game>".

**Hiện game đã có đủ ảnh**: `make_frames.py` cắt và vẽ lại mọi frame từ ảnh gốc duy nhất của người
dùng, `concept/ufo_v1.png` (xem `README.txt`). Prompt dưới đây chỉ dùng khi muốn AI vẽ lại các sheet
cho đẹp hơn (vd. đĩa nghiêng thật khi trúng đòn, vuốt mở chi tiết hơn). Ảnh AI vẽ xong thì nhập bằng
`tools/import_boss_frames.gd` như Phù Thuỷ Băng (mục 5), thay cho sheet do script làm.

**Vòng 2 (tháp pháo xoay):** cụm hai nòng nay là một hình riêng (`turret/`), game xoay nó về phía mỗi
phát bắn. Vì vậy mọi sheet thân **không vẽ nòng pháo**: dưới vành bên phải chỉ có một ổ tròn nhỏ (vòng
thép quanh lỗ tối) để tháp pháo gắn vào. Khi dán khối UFO (mục 0b) cho sheet thân, thay dòng `CANNONS`
bằng khối **[NO-CANNON]** (mục 0d). Tháp pháo vẽ riêng ở mục 3g; pháo hiệu và tên lửa (tuỳ chọn) ở mục 4b.
Hiện chưa có key Gemini trong `.env` nên các ảnh này đang do `make_frames.py` cắt từ ảnh gốc.

## Cách dùng

1. **Luôn đính kèm `concept/ufo_v1.png` làm ảnh tham chiếu** (`--ref` của `tools/gen_image.py`) cho
   mọi prompt: nó là thiết kế gốc người dùng đã chọn.
2. Mỗi prompt = **[STYLE]** (mục 0) + **[UFO]** (mục 0b) + **[GRID-6]** hoặc **[GRID-4]** (mục 0c) +
   phần riêng của ảnh đó. **Dán nguyên văn cả khối, không rút gọn, không viết lại**: khối UFO càng
   giống hệt nhau giữa các lần tạo thì đĩa bay càng không bị đổi thiết kế.
3. **Thứ tự frame**: đọc **trái sang phải, hàng trên rồi hàng dưới**. Frame 1 = ô trên cùng bên trái.
4. **Nền**: hồng tím đặc **#FF00FF** (magenta), một màu phẳng. Đĩa bay có xanh lá (phi công), xanh
   trời (vòm kính), cam / đỏ (đèn), vàng (sọc), nên magenta là màu duy nhất không có trên người nó.
   Vòng miệng nòng màu tím xanh (hue ~250) gần magenta: trong `import.json` để `despill.hueRange`
   bắt đầu từ 285. **Vòm kính phải tô màu xanh trời đặc**, không được trong suốt nhìn thấy nền: nền
   magenta lọt qua kính sẽ bị tool xoá thủng vòm.
5. **Không vẽ hiệu ứng game tự vẽ**: đạn pháo, tia laze, chớp nòng dạng đám lửa lớn, khói dày, tia
   lửa lớn, drone (khi thả drone), khiên tròn, sao choáng, bóng đổ, mặt đất. Ánh sáng (đèn viền, cửa
   cam, miệng nòng, lửa đẩy) nằm trong viền đen hoặc sát ngay đó; quầng sáng toả rộng ra nền magenta
   sẽ thành viền bẩn.
6. Dấu ✦ của AI ở góc: tool tự xoá (ghi toạ độ vào `watermark` trong `import.json`).

### Animation game cần (và chỉ những cái này)

| Thư mục | Animation | Frame | Lưới | Lặp | Peak | Game chạy khi |
|---|---|---|---|---|---|---|
| `side_idle/` | `idle` | 6 | 3×2 | lặp | | lơ lửng tại chỗ (game tự nhấp nhô; chậm lại, lắc nhẹ khi bị choáng / đóng băng) |
| `side_fly/` | `fly` | 4 | 2×2 | lặp | | bay tới chỗ mới đầu lượt boss (`UnitFlew`; game tự nghiêng theo hướng bay) |
| `side_cast/` | `cast` | 6 | 3×2 | không | frame 4 | bắn thường **và** pháo hiệu của Mưa đạn pháo, Bom mù (tháp pháo giật lùi riêng) |
| `side_burst/` | `burst` | 6 | 3×2 | không | frame 3 (giữ lâu) | Tia laze nghiền (game vẽ mỗi tia từ đầu nòng tháp pháo đã xoay) |
| `side_summon/` | `summon` | 4 | 2×2 | không | frame 3 | thả drone |
| `side_hurt/` | `hurt` | 2–4 | 2×2 | không | | trúng đòn; **frame 1 cũng là ảnh khởi đầu cảnh chết** |

Peak đếm từ 1 ở đây; trong `import.json` là chỉ số từ 0 (frame 4 → `"peak": 3`). Không có sheet chết
riêng (game làm cảnh chết từ frame hurt 1 và các mảnh `parts/hull`, `parts/dome`, `parts/cannon`).

---

## 0. Khối STYLE chung (dán vào đầu mọi prompt)

```
2D mobile game art, cartoon style for a cute military artillery game: bold clean
near-black outlines (#1E2128) of even thickness around every shape, flat cel-shaded
colours with exactly one shade tone and one highlight tone per material, rounded
friendly shapes, crisp vector-like edges, no texture noise, no painterly brush strokes,
no motion blur, no motion lines. Lights glow only inside or right at the black outline
of the part that glows: no wide halo, bloom or light spilling onto the background.
Solid flat pure magenta background #FF00FF everywhere around the subject: one single
colour, no gradient, no vignette, no floor, no ground shadow, no drop shadow, no text,
no numbers, no watermark, no signature, no frame border.
```

## 0b. Khối UFO (giữ cố định, dán nguyên văn vào mọi prompt)

```
UFO: "Steel Saucer", a hovering steel flying saucer piloted by a small alien. Always the
exact same design as the attached reference picture:
- VIEW: side view from slightly above, the saucer level, its front on the RIGHT of the
  picture (the twin cannons point right).
- SAUCER: a wide flat disc about 1.3 times as wide as the craft is tall (dome top to
  claw bottom), light steel grey (#9CA3AD) with shade #6E757F and highlight #C8CDD4; on
  its top a raised inner ring with panel seams; a thick vertical rim band with diagonal
  hazard stripes, yellow (#F2C230) and near-black; five round red lamps (#E8402C with an
  orange-yellow centre #FFB347) set in grey bezels along the rim band, a short red glow
  strip under each on the lower hull, and a half-round red lamp peeking out at each end
  of the rim. Under the disc a rounded lower bowl in darker grey.
- PORT: one big round orange disc (#FF9F2E) in a dark grey ring frame on the top of the
  saucer, right of the dome.
- DOME: a glass half-sphere on top in the middle, painted as OPAQUE flat pale sky blue
  (#A9D3F0) with white curved highlight spots (never see-through to the background), set
  in a grey ring with seven small orange dot lights. A thin grey antenna on the dome's
  left side, ending in a round red ball.
- PILOT: a small green alien (#6CC57C, shade #3E9A57) inside the dome: big bald head,
  two big black oval eyes with white highlights, a small smile, a grey padded spacesuit
  with shoulder pads, one hand on a small control stick; a grey seat behind it and a
  console with small red, green and cyan buttons in front.
- CANNONS: a grey mount under the right side of the rim carrying two parallel round
  barrels pointing right and slightly down (about 20 degrees), the upper barrel behind
  and a little further right, the lower in front; each barrel ends in a thick blue-violet
  ring (#6E62B8) around a glowing orange muzzle face (#FF8A1F).
- UNDERSIDE: two jointed grey landing legs (one at the left, one at the right, under
  the bowl) with flat feet, and in the middle a three-armed grey claw on a rod ending
  in a cup-shaped claw head; small pale cyan-white thruster flames (#BFE9FF, white core)
  under the two feet and under the claw head.
- COLOURS ONLY FROM THIS LIST plus the outline. No magenta or pink anywhere.
- Heavy but cute, readable at small size. No text, no numbers, no logos.
```

## 0c. Khối lưới (chọn một, dán sau khối UFO)

Mỗi ô **512×512**, đĩa bay **nhỏ trong ô** (rộng khoảng 400 px), quanh nó **ít nhất 48 px nền magenta
trống**: tool cắt ở khoảng trống đó. Cùng cỡ, cùng chỗ trong mọi ô (đáy vuốt ở cùng một độ cao), nên
đĩa không giật khi chạy animation.

**[GRID-6]** (6 frame, ảnh 1536×1024, 3 cột × 2 hàng):

```
LAYOUT: a sprite sheet of 6 frames on one 1536x1024 canvas, a grid of 3 columns and 2
rows of equal square cells, each 512x512 px. Reading order: top row left to right =
frames 1, 2, 3; bottom row left to right = frames 4, 5, 6. Each frame is its own
complete drawing of the whole saucer, like separate stickers on one magenta sheet. Every
frame stays inside its own cell with at least 48 px of empty flat magenta between the
saucer (antenna, cannons, legs, claw and flames included) and every edge of the cell.
Same scale in every cell: the saucer about 400 px wide and 300 px tall from the dome's
top to the claw's bottom. Same position: the dome's centre 40 px left of the cell's
middle, the claw's bottom 90 px above the bottom edge of the cell. Do NOT draw the grid,
cell borders, frame numbers, a floor or a shadow.
```

**[GRID-4]** (4 frame, ảnh 1024×1024, 2 cột × 2 hàng): như GRID-6, thay câu đầu bằng
`a sprite sheet of 4 frames on one 1024x1024 canvas, a grid of 2 columns and 2 rows ... top row
= frames 1, 2; bottom row = frames 3, 4.`

---

## 0d. Khối NO-CANNON (thay dòng CANNONS của khối UFO trong mọi sheet thân)

```
CANNONS: NONE on the saucer in this picture (the game draws the cannon separately).
Under the right side of the rim, on the lower bowl, only a small round turret socket:
a steel grey ring (#6E757F, highlight #C8CDD4) round a dark hole (#2E3240), about a
fifth of the bowl's height, outlined like everything else. Nothing sticks out of it.
```

---

## 1. Ảnh thiết kế gốc: `concept/ufo_v1.png`

Đã có (ảnh người dùng gửi). Không vẽ lại; mọi prompt khác đính kèm nó.

## 2. Chân dung: `portrait/portrait_v2.png` và `portrait/bust_v2.png`

Hiện `portrait_v1.png` / `bust_v1.png` do `make_frames.py` làm từ ảnh gốc. Bản AI (nếu muốn) đặt tên
`_v2` rồi sửa `src` trong `import.json`. Canvas vuông 1024×1024, nền magenta.

```
[STYLE] [UFO]
PICTURE: hero portrait, the whole saucer a little more dramatic, tilted 8 degrees
towards the viewer, all rim lamps lit, the port glowing, small thruster flames. Square
canvas 1024x1024, the saucer about 900 px wide, centred, 60 px of magenta around it.
```

```
[STYLE] [UFO]
PICTURE: bust: only the glass dome with the alien pilot, the antenna and the dome's grey
ring with its seven orange dot lights, cut off cleanly below the ring with the ring's
black outline closing the shape. The pilot looks out to the right with a confident grin.
Square canvas 1024x1024, the dome about 760 px wide, centred, 80 px of magenta around.
```

---

## 3. Animation trong trận

Mọi sheet: `[STYLE] [UFO] [GRID-6]` (hoặc `[GRID-4]`) + đoạn ANIMATION dưới đây. Đặt tên `sheet_v2.png`
trong thư mục của nó (`gen_image.py --out` không ghi đè).

### 3a. Lơ lửng (idle): `side_idle/`, 6 frame, lặp

```
ANIMATION: hovering idle loop, 6 frames. The saucer stays exactly in place and level in
every frame (the game adds the bob). Frame k: the rim lamps light up one after another
from left to right (one bright lamp per frame, the others normal), the dome's orange
dots twinkle, the thruster flames flicker between short and a little longer. Frame 6
leads back into frame 1.
```

### 3b. Bay (fly): `side_fly/`, 4 frame, lặp

```
ANIMATION: flying loop, 4 frames. The saucer level (the game tilts it into the flight),
the thruster flames twice as long and brighter, flickering; the rim lamps flash in an
alternating pattern. No speed lines, no trail.
```

### 3c. Bắn pháo / Mưa đạn pháo (cast): `side_cast/`, 6 frame, peak frame 4

```
ANIMATION: firing (the cannon is drawn separately: no barrels, no shells, no flash),
6 frames, not looping, the saucer level and in place in every frame. Frame 1: rest.
Frames 2-3: the orange port warms brighter. Frame 4 (the key frame): every rim lamp
flashes bright, the thruster flames dip short. Frames 5-6: back to rest.
```

### 3d. Tia laze nghiền (burst): `side_burst/`, 6 frame, peak frame 3

```
ANIMATION: laser charge and fire (the cannon is drawn separately: no barrels, no
beams), 6 frames, not looping, the saucer level and in place. Frame 1: the orange port
starts to glow. Frame 2: brighter, all rim lamps lit. Frame 3 (the key frame, held while
the beams fire): the port blazing pale yellow, every rim lamp and dome dot lit, the
thruster flames long. Frames 4-6: the glow fading back to rest.
```

### 3e. Thả drone (summon): `side_summon/`, 4 frame, peak frame 3

```
ANIMATION: the bottom claw opens to drop a drone, 4 frames, not looping. Do NOT draw
the drone. Frame 1: the claw's two halves start to part, a small glowing hatch opens
between their roots. Frame 2: the claw half open, warm light inside the hatch. Frame 3
(the key frame): the claw wide open like jaws, warm light falling down from the hatch,
all rim lamps lit, no flame under the claw. Frame 4: the claw closing again.
```

### 3f. Trúng đòn (hurt): `side_hurt/`, 4 frame (hoặc 2)

```
ANIMATION: hit reaction, 4 frames, not looping. Frame 1: knocked back to the left and
tilted nose up (the right side up) about 10 degrees, the rim lamps dark, the flames
sputtering short, two or three small yellow sparks on the hull at the front. Frame 2:
tilted 4 degrees, lamps flickering. Frame 3: almost level. Frame 4: back to rest.
```

### 3g. Tháp pháo (turret): `turret/sheet_v2.png`, 6 ô ngang

Sheet riêng của cụm hai nòng, **nằm ngang chĩa thẳng sang phải**, cùng chỗ trong mọi ô (game xoay nó
quanh tâm cái trục tròn bên trái). Nền magenta, `--aspect 21:9`, `--ref concept/ufo_v1.png`. Sau khi
vẽ: `make_frames.py` cần đọc sheet này thay cho phần tự cắt (chưa làm: hiện tháp pháo do script cắt).

```
SUBJECT: only the saucer's twin cannon as a separate turret piece, NOT the saucer. Six
cells in one row, the same turret at the same place and size in every cell, pointing
straight RIGHT (perfectly horizontal). From left to right: a round steel hub (a disc
with a small cap in its centre, this is the pivot), a short thick neck, a dark grey
housing block, and from it two parallel round light-grey barrels side by side (the upper
one behind and a little further right, the lower one in front), each ending in a thick
blue-violet ring (#6E62B8) round an orange glowing muzzle face (#FF8A1F).
Cell 1: rest. Cell 2: the muzzle faces brighter orange with a thin orange ring of light.
Cell 3: brighter still, three or four small orange sparks drawn toward each muzzle.
Cell 4: each muzzle face a white-hot core in an orange ring with a short spiky rim.
Cell 5: both barrels slid back into the housing about a quarter of their length, the
muzzles hot orange. Cell 6: the barrels halfway out again, cooling. No flash, no smoke,
no beam, no shell, no saucer.
```

---

## 4. Drone (lính con)

Drone vẫn vẽ bằng code (`match/boss/boss_art.gd` `_drone`). Nếu sau này cần ảnh: thư mục riêng
`art_source/bosses/drone/`, cùng khối STYLE, thiết kế nhỏ cùng tông thép xám, sọc vàng đen, một mắt đỏ.

## 4b. Pháo hiệu và tên lửa của Mưa đạn pháo (tuỳ chọn)

Hiện game vẽ bằng code. Muốn ảnh thì vẽ trên nền **trắng phẳng** (kiểu "solid" của
`tools/import_projectiles.gd`: viền đen dày, nền trắng loang từ mép), mỗi hình một ảnh, nằm ngang mũi
sang phải; khói màu và tia lửa lấp lánh vẫn để game vẽ (hạt khói bay lên, nhấp nháy). Cần thêm vào
`import_projectiles.gd` một mục cho ảnh của boss (hiện tool chỉ đọc đạn theo loại súng × bậc).

```
SUBJECT: a signal flare canister lying on its side on nothing, pointing right: a short
red-orange cylinder (#E8402C, shade #B02A1E) with two white bands, a dark grey cap at the
left end, and at the right end a small bright burning tip: a yellow-white flame core
(#FFF3B0) inside a short orange flame shape, both outlined. No smoke, no sparks, no glow
halo, no ground, no shadow. Flat pure white background #FFFFFF everywhere around it.
```

```
SUBJECT: a small cartoon missile flying right, horizontal: a light steel grey body
(#9CA3AD, shade #6E757F) with a yellow and near-black hazard stripe ring, a red nose cone
(#E8402C), four small red tail fins (two visible), and a short orange exhaust flame at the
tail (yellow core), all outlined. No smoke trail, no motion lines, no glow halo. Flat pure
white background #FFFFFF everywhere around it.
```

---

## 5. Nhập vào game

Ảnh AI vẽ thay cho sheet do script làm: trong `import.json` sửa mục animation đó thành

- `"src": "side_cast/sheet_v2.png", "grid": [3, 2]` (4 frame: `[2, 2]`), bỏ `cuts`, `anchors`,
  `bodyHeight` của nó; thêm `"background": {"key": "corners", "corner": 8, "tolerance": 40,
  "soft": 45}` vào mục đó và `"despill": {"hueRange": [285, 335]}` ở đầu file; `watermark` nếu có ✦.
- `body` (đo thân): xám thép, hue 0–360, minSat 0, minVal 0.42, maxVal 0.78 (đã có). Nếu tool đo
  sai chân (lửa đẩy bị tính là chân) thì cho `anchors` (đáy vuốt mỗi frame, px của sheet).
- Kiểm tra trên contact sheet: đáy vuốt trên chữ thập đỏ, đỉnh vòm ở vạch xanh như các sheet khác.

```
python3 -I art_source/bosses/steel_robot/make_frames.py      # các sheet còn lại, ảnh, mảnh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- steel_robot --contact=/tmp/steel_robot_contact.png
```

---

## 6. Kiểm tra trước khi đưa vào game

- **Tách frame:** đúng số ô, đúng thứ tự; mỗi đĩa nằm trọn trong ô, hai hình cạnh nhau không chạm
  nhau (kể cả ăng-ten, nòng, lửa đẩy). Không có đường kẻ ô, số frame.
- **Cùng cỡ, cùng chỗ:** đáy vuốt cùng độ cao ở mọi ô, vòm không nhảy giữa các frame.
- **Thiết kế:** nhìn sang phải; sheet thân **không có nòng** (chỉ ổ tròn dưới vành phải), sheet tháp
  pháo chĩa thẳng ngang cùng chỗ mọi ô; vòm kính xanh trời **đặc** (không lộ
  nền), phi công xanh lá; sọc vàng đen, năm đèn đỏ trên vành; cửa cam bên phải vòm.
- **Nền:** một màu #FF00FF phẳng; không quầng sáng lớn toả ra nền.
- **Nội dung:** không chữ, không đạn, không tia laze, không chớp nòng, không drone, không khói dày.
- **Nối animation:** frame cuối của cast / burst / summon / hurt = dáng idle frame 1.
- **Dấu ✦:** ghi toạ độ vào `watermark` khi nhập; nếu đè lên đĩa thì xem lại sau khi xoá.
