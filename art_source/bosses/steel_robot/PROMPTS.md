# Rô-bốt Thép: prompt tạo ảnh boss

Dùng cho AI vẽ ảnh (GPT-image / Gemini / Midjourney / Flux…). Prompt viết bằng tiếng Anh vì các model
hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế là thiết kế riêng của game, không
lấy theo game nào khác: đừng thêm tên game / tên hãng / "in the style of <game>" vào prompt.

Hiện game vẽ Rô-bốt Thép và Drone bằng code (`match/boss/boss_art.gd`). Ảnh dưới đây thay phần đó:
`tools/import_boss_frames.gd` cắt ảnh thành frame, `match/boss/boss_body.gd` chạy animation (giống
Phù Thuỷ Băng, `art_source/bosses/ice_witch/`).

## Cách dùng

1. **Tạo ảnh thiết kế gốc (mục 1) trước**, chọn 1 bản ưng nhất. Từ đó về sau luôn **đính kèm ảnh gốc
   làm ảnh tham chiếu** cho mọi prompt khác.
2. Mỗi prompt = **[STYLE]** (mục 0) + **[ROBOT]** (mục 0b) + **[GRID-6]** hoặc **[GRID-4]** (mục 0c)
   + phần riêng của ảnh đó. **Dán nguyên văn cả khối, không rút gọn, không viết lại**: khối ROBOT
   càng giống hệt nhau giữa các lần tạo thì rô-bốt càng không bị đổi thiết kế.
3. **Thứ tự frame**: luôn đọc **trái sang phải, hàng trên rồi hàng dưới**. Frame 1 = ô trên cùng bên
   trái. Mỗi phần riêng liệt kê từng frame theo đúng thứ tự đó.
4. **Nền**: xanh lá đặc **#00FF00**, một màu phẳng. Rô-bốt **không có màu xanh lá / xanh nõn chuối
   nào** (lõi cam, kính xanh lơ, đèn đỏ), nên tool xoá nền sạch. Ánh sáng (lõi, kính, nòng súng) phải
   **nằm trong viền đen**, không toả ra nền: quầng sáng cam / xanh lơ trộn với nền xanh lá sẽ thành
   viền bẩn không xoá được. Dấu ✦ của AI ở góc tool tự xoá.
5. **Không vẽ hiệu ứng game tự vẽ**: đạn pháo, tia laze, chớp nòng dạng đám lửa, khói, hơi nước, tia
   lửa, drone (khi triệu hồi), khiên tròn, sao choáng, bóng đổ dưới chân, mặt đất. Ảnh chỉ có rô-bốt
   và ánh sáng nằm trên người nó. Hiệu ứng tràn ra ngoài cũng là lý do chính khiến các frame dính nhau.
6. **Nếu model cứ vẽ các frame dính nhau / tràn ô** (phương án B, mục 3): tạo **mỗi frame một ảnh
   riêng** bằng khối [SINGLE] thay cho [GRID-…]. Tool nhận cả hai cách (mục 5).

### Animation game cần (và chỉ những cái này)

| Thư mục | Tên animation trong game | Frame | Lưới | Lặp | Peak | Game chạy khi |
|---|---|---|---|---|---|---|
| `side_idle/` | `idle` | 6 | 3×2 | lặp | | đứng yên (chậm lại và lắc nhẹ khi bị choáng / đóng băng) |
| `side_cast/` | `cast` | 6 | 3×2 | không | frame 3 | bắn thường bằng pháo tay **và** kỹ năng Mưa đạn pháo (`shell_barrage`, kind rain) |
| `side_burst/` | `burst` | 6 | 3×2 | không | frame 4 (giữ lâu) | kỹ năng Tia laze nghiền (`laser_beam`, kind beam: game vẽ 5 tia ngang map) |
| `side_summon/` | `summon` | 4 | 2×2 | không | frame 3 | đầu lượt boss thả drone miễn phí |
| `side_hurt/` | `hurt` | 4 | 2×2 | không | | trúng đòn; **frame 1 cũng là ảnh khởi đầu cảnh chết** (game tự làm cảnh chết từ frame này) |

Peak = frame game đặt đúng lúc viên đạn đầu rời nòng / tia laze đầu tiên / drone xuất hiện (số frame
đếm từ 1; trong `import.json` là chỉ số từ 0: peak frame 3 → `"peak": 2`). Không có sheet `fly`
(rô-bốt không bay), không có sheet chết riêng, không có sheet choáng. Đạn `steel_shell` / `drone_bolt`
game vẽ bằng code (`match/views/unit_shell.gd`), nên không cần ảnh đạn.

---

## 0. Khối STYLE chung (dán vào đầu mọi prompt)

```
2D mobile game character art, cartoon style for a cute military artillery game: bold
clean near-black outlines (#1E2128) of even thickness around every shape, flat
cel-shaded colours with exactly one shade tone and one highlight tone per material,
slightly chibi proportions, rounded friendly shapes, crisp vector-like edges, no texture
noise, no painterly brush strokes, no transparency, no motion blur, no motion lines.
Every glow stays inside the black outline of the part that glows: no halo, bloom or
light spilling onto the background. Solid flat pure green background #00FF00 everywhere
around the figure: one single colour, no gradient, no vignette, no floor, no ground
shadow, no drop shadow, no text, no numbers, no watermark, no signature, no frame border.
```

## 0b. Khối ROBOT (giữ cố định, dán nguyên văn vào mọi prompt của rô-bốt)

Đơn vị HU = chiều cao cái đầu (từ cằm tới đỉnh mái vòm). Rô-bốt nhìn sang phải, nên phía người xem
thấy là **sườn phải** của nó: tay pháo là tay gần (vẽ trước thân), tay kẹp là tay xa (sau thân), ụ
cối sau lưng nằm **bên trái** hình. Nòng pháo ở khoảng nửa chiều cao, phía trước: đúng chỗ game cho
đạn bắn ra.

```
ROBOT: "Steel Robot", the giant guardian mech of an abandoned iron foundry. Always the
exact same design:
- VIEW: side view facing RIGHT, turned slightly (3/4) towards the viewer so the chest
  core and the visor are visible. The robot's front is on the right of the picture, its
  back on the left.
- PROPORTIONS (1 HU = the head's height): total height from the soles to the top of the
  dome = 5 HU: feet 0.5 HU, legs 1 HU, hip skirt 0.5 HU, torso 2.2 HU, head 0.8 HU
  showing above the shoulders. The whole robot is about as wide (from the back of the
  mortar pods to the cannon's muzzle) as it is tall. Heavy, stocky, low centre of mass.
- HEAD: a small rounded dome helmet, 1.1 HU wide, its lower part sunk between the
  shoulders, no neck. One horizontal visor slit across the front of the dome, glowing
  cyan (#7DF5FF) with a thin white highlight. One thin dark antenna (0.8 HU) on the top
  of the dome towards the back, ending in a round red bulb (#FF3B30). Two round bolts
  where the ears would be.
- TORSO: a barrel-shaped chest, 2.6 HU wide, in steel blue armour (#7F93B2) with a
  darker shade (#56657D) on the lower and back sides and light edges (#C9D6EA); clear
  panel lines and round bolts along the plate seams. In the middle of the chest a round
  reactor core 0.9 HU across: a glowing orange disc (#FF8A1F) with a pale yellow-white
  centre (#FFF2C8), set in a dark gunmetal ring frame (#3A4250) with 4 bolts. Just above
  the core a small rectangular hatch plate with two hinges on its top edge (closed unless
  the prompt says otherwise).
- SHOULDERS: two big rounded pauldrons in the same steel blue; the near one (right
  shoulder, in front) carries the cannon.
- NEAR ARM (the robot's right arm, drawn in front of the body): a short dark piston upper
  arm; the forearm IS a big boxy arm cannon, 2.2 HU long and 0.9 HU thick, steel blue
  with three dark cooling fins on top and a dark gunmetal ring at the muzzle. The muzzle
  is a round dark opening with a faint orange glow deep inside. At rest the cannon points
  forward to the right, level, its muzzle at about half the robot's height.
- FAR ARM (the robot's left arm, behind the body): a dark piston arm ending in a
  three-finger steel claw (two fingers and a thumb), mostly hidden behind the torso, the
  claw visible below and behind the chest.
- BACK (left side of the picture): a backpack frame carrying two square mortar pods side
  by side, each 1 HU square, steel blue with a dark lid rim; each pod has 4 short round
  tubes in a 2x2 pattern pointing straight up, the tube tops reaching about the top of
  the head. In side view the near pod is in front and the far pod peeks out behind it.
- HIPS: a skirt plate with 5 diagonal yellow (#FFC93C) and near-black hazard stripes.
- LEGS: short thick legs, dark gunmetal round knee joints, steel blue shin plates, big
  flat rectangular feet 1.5 HU long with a toe plate and a heel; both soles flat on the
  ground unless the prompt says otherwise.
- WEAR: three small dents and a few short scratches drawn as light lines on the chest
  and the cannon; no rust, no dirt texture.
- COLOURS ONLY FROM THIS LIST: steel blue #7F93B2, shade #56657D, highlight #C9D6EA,
  gunmetal #3A4250, outline #1E2128, hazard yellow #FFC93C, core orange #FF8A1F and
  #FFF2C8, visor cyan #7DF5FF, antenna red #FF3B30. NO green, lime or yellow-green
  anywhere on the robot, no pink or magenta.
- Massive but cute, readable at small size. No text, no numbers, no logos on it.
```

## 0c. Khối lưới (chọn một, dán sau khối ROBOT)

Mỗi ô **512×512**, rô-bốt **nhỏ trong ô** (khoảng 320 px cao), quanh nó **ít nhất 56 px nền xanh
trống** về mọi phía, nên hai rô-bốt cạnh nhau cách nhau ít nhất 112 px: tool cắt ở khoảng trống đó.
Cùng một đường chân (56 px trên đáy ô) và cùng cỡ ở mọi ô, nên rô-bốt không giật khi chạy animation.
Hai lưới dùng cùng cỡ ô, nên mọi sheet cùng tỉ lệ.

**[GRID-6]** (6 frame, ảnh 1536×1024, 3 cột × 2 hàng):

```
LAYOUT: a sprite sheet of 6 frames on one 1536x1024 canvas, laid out as a grid of 3
columns and 2 rows of equal square cells, each cell 512x512 px. Reading order: top row
left to right = frames 1, 2, 3; bottom row left to right = frames 4, 5, 6. Each frame is
its own separate, complete drawing of the whole robot, like 6 small separate stickers on
one green sheet. Every frame stays fully inside its own cell: nothing crosses a cell
border, and there is at least 56 px of empty flat green between the robot (antenna,
cannon, claw and mortar pods included) and every edge of its cell, so two neighbouring
robots are always at least 112 px apart and never touch or overlap. Same scale in every
cell: the robot is about 320 px tall from the soles to the top of the dome and about
350 px wide. Same position in every cell: the torso's centre line at the horizontal
middle of the cell, the soles on an invisible ground line 56 px above the bottom edge of
the cell (y = 456 in the top row, y = 968 in the bottom row), the feet on that line in
every frame. Do NOT draw the grid, cell borders, dividing lines, frame numbers, a floor
or a shadow: only flat green #00FF00 between the robots. No glow, effect or part of one
frame reaches into another cell.
```

**[GRID-4]** (4 frame, ảnh 1024×1024, 2 cột × 2 hàng):

```
LAYOUT: a sprite sheet of 4 frames on one 1024x1024 canvas, laid out as a grid of 2
columns and 2 rows of equal square cells, each cell 512x512 px. Reading order: top row
left to right = frames 1, 2; bottom row left to right = frames 3, 4. Each frame is its
own separate, complete drawing of the whole robot, like 4 small separate stickers on one
green sheet. Every frame stays fully inside its own cell: nothing crosses a cell border,
and there is at least 56 px of empty flat green between the robot (antenna, cannon, claw
and mortar pods included) and every edge of its cell, so two neighbouring robots are
always at least 112 px apart and never touch or overlap. Same scale in every cell: the
robot is about 320 px tall from the soles to the top of the dome and about 350 px wide.
Same position in every cell: the torso's centre line at the horizontal middle of the
cell, the soles on an invisible ground line 56 px above the bottom edge of the cell
(y = 456 in the top row, y = 968 in the bottom row), the feet on that line in every
frame. Do NOT draw the grid, cell borders, dividing lines, frame numbers, a floor or a
shadow: only flat green #00FF00 between the robots. No glow, effect or part of one frame
reaches into another cell.
```

**[SINGLE]** (phương án B, mỗi frame một ảnh 1024×1024; thay `k` và `N`):

```
LAYOUT: one single frame, frame k of N of the animation below, alone on a 1024x1024
canvas. Exactly the same framing as the attached reference frame: the robot about 620 px
tall from the soles to the top of the dome, the torso's centre line at x = 512, the soles
on an invisible ground line at y = 910, at least 90 px of empty flat green #00FF00 on
every side. Only the pose of frame k changes; same robot, same size, same colours.
```

---

## 1. Ảnh thiết kế gốc (model sheet): `concept/model_sheet_v1.png`

Chỉ làm ảnh tham chiếu, không đưa vào game. Tạo 4–8 bản, chọn 1.

```
[STYLE] [ROBOT]
Character model sheet: the same robot three times side by side on a 1536x1024 canvas,
same scale, each in its own third of the canvas with at least 80 px of empty green
between them: (1) left: front view, (2) middle: side view facing right, (3) right: back
view showing the two mortar pods. Neutral standing pose, the cannon level, the claw
relaxed, the hatch closed, both soles flat on one shared invisible ground line.
```

## 2. Chân dung: `portrait/portrait_v1.png` và `portrait/bust_v1.png`

Thẻ boss ở tab Boss và màn tìm trận (`portrait.png`, tool thu về 512 px); icon thanh máu và ảnh lượt
(`bust.png`, 384 px).

```
[STYLE] [ROBOT]
Heroic boss pose for a selection card, alone on a square 1024x1024 canvas: standing firm
on both feet, the arm cannon raised diagonally forward and up, its muzzle glowing orange
inside, the claw open and raised beside the chest, the reactor core blazing, the visor
glaring towards the viewer. Full body including the antenna and the mortar pods, centred,
at least 80 px of empty green on every side.
```

```
[STYLE] [ROBOT]
Head-and-shoulders bust icon, alone on a square 1024x1024 canvas: the dome head with the
glowing cyan visor and the red antenna bulb, both shoulder pauldrons, the top half of the
reactor core, the top of the arm cannon at the right edge, facing slightly right. The
bust fills about 85% of the canvas, at least 60 px of empty green on every side.
```

---

## 3. Animation trong trận

Mỗi sheet: `[STYLE] [ROBOT] [GRID-…]` + phần riêng.

- **Phương án A (mặc định)**: một ảnh lưới, `side_<anim>/sheet_v1.png`.
- **Phương án B**: mỗi frame một ảnh `side_<anim>/frame_1.png` … `frame_N.png`, prompt
  `[STYLE] [ROBOT] [SINGLE]` + dòng "ANIMATION" + đúng dòng "Frame k" của frame đó. Đính kèm ảnh gốc
  **và** frame 1 của idle đã chọn để giữ đúng cỡ và vị trí.

Quy tắc chung cho mọi animation:
- Đế chân đứng yên trên đường chân ở mọi frame (trừ khi ghi khác); chỉ phần trên cơ thể chuyển động.
- Đầu chỉ lên xuống theo thân, tối đa khoảng 5% chiều cao, không nhảy giữa các frame.
- Frame cuối của animation không lặp = dáng idle frame 1, để game nối về idle không giật.

### 3a. Đứng yên (idle): `side_idle/`, 6 frame, [GRID-6], lặp

```
[STYLE] [ROBOT] [GRID-6]
ANIMATION: idle breathing loop, 6 frames, the last frame flows back into the first. The
soles never move. Small motions only.
Frame 1: neutral rest pose, cannon level pointing right, claw relaxed behind the chest,
  core at normal brightness, visor open, antenna bulb dim red.
Frame 2: the torso sinks very slightly (about 2% of the height), the knees bend a hair,
  the cannon dips a few degrees, the core a little brighter.
Frame 3: lowest point (about 3% lower than frame 1), the cannon dipped about 5 degrees,
  the core at its brightest.
Frame 4: rising back, the same height as frame 2, the core dimming.
Frame 5: back at the frame 1 height, the visor blinks (the slit narrowed to a thin cyan
  line), the antenna bulb lit bright red.
Frame 6: the same as frame 1 with the visor open again and the antenna bulb dim.
```

### 3b. Bắn pháo / Mưa đạn pháo (cast): `side_cast/`, 6 frame, [GRID-6], không lặp, peak frame 3

Cùng một animation cho phát bắn thường (đạn rời nòng pháo tay) và Mưa đạn pháo (đạn rơi từ trên
trời xuống): cả pháo tay và hai ụ cối đều giật ở frame 3. **Không vẽ đạn, chớp lửa, khói.**

```
[STYLE] [ROBOT] [GRID-6]
ANIMATION: full artillery salvo, 6 frames, not looping. Do NOT draw shells, muzzle fire,
flash clouds, smoke or sparks: only the robot and the glow inside its openings.
Frame 1 (anticipation): the robot lowers its hips a little, the cannon swings up to
  about 30 degrees above level, the mortar pod lids open, the core brightens.
Frame 2 (wind-up): the cannon at about 40 degrees up, its three cooling fins raised, the
  inside of the muzzle and the top of every mortar tube glow bright orange, the torso
  leans back slightly to brace, the claw clenched.
Frame 3 (FIRE, the key frame): recoil: the cannon kicked up and back about 10 degrees,
  the torso pushed back (to the left) a little, the mortar pods jolted down, the muzzle
  and every tube mouth glowing white-hot inside, the visor squinting. Soles still flat.
Frame 4 (follow-through): still pushed back, the glow fading to orange, the fins still
  raised.
Frame 5 (recovery): the cannon lowering to about 15 degrees up, the torso upright again,
  the pod lids closing, faint glow.
Frame 6 (settle): exactly the idle rest pose: cannon level, fins down, lids closed,
  openings dark.
```

### 3c. Tia laze nghiền (burst): `side_burst/`, 6 frame, [GRID-6], không lặp, peak frame 4

Game vẽ 5 tia laze ngang toàn map và giữ frame 4 suốt lúc tia bắn. **Không vẽ tia.**

```
[STYLE] [ROBOT] [GRID-6]
ANIMATION: laser cannon charge and fire, 6 frames, not looping. Do NOT draw any beam,
ray, flash cloud, steam or sparks: only the robot and the glow inside its openings.
Frame 1 (brace): the cannon held level pointing straight right, the claw comes forward
  under the cannon and grips its underside (two-handed brace), the knees bend a little,
  the visor narrows.
Frame 2 (charge): the three cooling fins on the cannon open wide, the inside of the
  muzzle glows cyan-white, the core brighter.
Frame 3 (full charge): the robot crouches a little lower, the muzzle inside, the core and
  the visor all at maximum glow, the core almost white.
Frame 4 (FIRE, the key frame, held on screen): the torso shoved back about 8 degrees by
  the recoil, the cannon still level, a small round white-cyan glow disc filling the
  muzzle opening (inside the outline only), the fins wide open, the soles flat.
Frame 5 (cool down): the glow fading, the fins still open, the torso straightening, the
  claw letting go of the cannon.
Frame 6 (settle): exactly the idle rest pose: fins closed, muzzle dark, claw behind the
  chest.
```

### 3d. Thả drone (summon): `side_summon/`, 4 frame, [GRID-4], không lặp, peak frame 3

Drone hiện ra trên map đúng lúc frame 3. **Không vẽ drone.**

```
[STYLE] [ROBOT] [GRID-4]
ANIMATION: summon signal, 4 frames, not looping. Do NOT draw drones, light beams, radio
waves or sparks.
Frame 1: the claw rises up above the shoulder, the antenna bulb flashes bright red.
Frame 2: the hatch plate above the core swings open upwards on its hinges, a red light
  glowing inside the hatch opening, the claw high and open.
Frame 3 (the key frame): the hatch fully open with the red light at its brightest, the
  claw pointing forward and up as if giving an order, the visor bright, the chest pushed
  out proudly.
Frame 4: the hatch closed, the claw back down behind the chest: exactly the idle rest
  pose.
```

### 3e. Trúng đòn (hurt): `side_hurt/`, 4 frame, [GRID-4], không lặp

Frame 1 là dáng game dùng làm cảnh chết, nên phải rõ là "bị đánh mạnh".

```
[STYLE] [ROBOT] [GRID-4]
ANIMATION: hit reaction, 4 frames, not looping. Do NOT draw sparks, smoke or impact
stars.
Frame 1 (impact): the whole upper body knocked back to the left about 12 degrees, the
  head snapped back, the visor flickering into a jagged broken line, the cannon flung
  upwards, the claw thrown out behind, the toe of the front foot lifted slightly off the
  ground line, a fresh dent on the chest plate.
Frame 2 (recoil peak): still leaning back but less, the visor dimmed, the cannon coming
  down, both soles flat again.
Frame 3 (recover): leaning slightly forward, the visor narrowed angrily, the cannon back
  to level.
Frame 4 (settle): exactly the idle rest pose with the new dent still visible.
```

---

## 4. Drone (lính con): `art_source/bosses/drone/`

Drone là boss art riêng (`drone`) nên ảnh để trong thư mục riêng `art_source/bosses/drone/` (tool nhập
mỗi thư mục `art_source/bosses/<id>/` ra `assets/bosses/<id>/`). Game tự cho drone nhấp nhô lơ lửng,
phồng lên và chớp đỏ trước khi nổ, nên ảnh **không** vẽ những thứ đó.

```
DRONE: "Drone", the small flying helper robot of the Steel Robot. Always the exact same
design: side view facing RIGHT, turned slightly towards the viewer. A round ball body
(1 unit across) in steel blue (#7F93B2) with shade #56657D and highlight #C9D6EA, a dark
gunmetal band (#3A4250) around its middle with one small yellow (#FFC93C) and near-black
hazard stripe patch, one big round red glowing eye (#FF3B30) on the front (the right
side) with a white highlight, glowing only inside its outline. Two short dark arms on
top, each holding a small four-blade rotor drawn as solid blades (no transparent blur
discs). Two thin dark landing skids under the body. Bold near-black outline (#1E2128).
No green, lime or magenta on it. Cute but mischievous, readable at small size.
```

Mỗi sheet: `[STYLE] [DRONE] [GRID-4]`, trong khối GRID-4 đổi chữ "robot" thành "drone" và câu cỡ thành
"the drone is about 280 px wide, the bottom of its skids on the invisible ground line". Thứ tự frame
như trên. Ảnh tham chiếu: `drone/concept/model_sheet_v1.png` (prompt mục 1 với [DRONE] thay [ROBOT]).

| Thư mục | Animation | Frame | Lặp | Peak |
|---|---|---|---|---|
| `drone/side_idle/` | `idle` | 4 | lặp | |
| `drone/side_fly/` | `fly` (bay tới chỗ mới) | 4 | lặp | |
| `drone/side_cast/` | `cast` (bắn đạn `drone_bolt` từ mắt) | 4 | không | frame 3 |
| `drone/side_hurt/` | `hurt` | 4 | không | |

```
[STYLE] [DRONE] [GRID-4]
ANIMATION: hover idle loop, 4 frames. The body stays exactly in place in every frame.
Frame 1: rotor blades at 0 degrees, eye normal. Frame 2: rotor blades turned 45 degrees.
Frame 3: blades back at 0 degrees, the eye blinks (half closed). Frame 4: blades at 45
degrees, eye normal.
```

```
[STYLE] [DRONE] [GRID-4]
ANIMATION: flying forward loop, 4 frames. The body tilted about 15 degrees forward
(towards the right), the rotors tilted with it, the skids trailing slightly behind.
Frames 1-4: the same tilt, the rotor blades turned 0, 45, 0, 45 degrees; the eye wide
open in every frame. No speed lines, no trail.
```

```
[STYLE] [DRONE] [GRID-4]
ANIMATION: eye-shot, 4 frames, not looping. Do NOT draw the bolt or any flash.
Frame 1: the eye narrows, the body leans back a little. Frame 2: the eye glows brighter.
Frame 3 (the key frame): the eye wide open, white-hot red at its brightest, the body
pushed back by the recoil. Frame 4: back to the hover idle frame 1.
```

```
[STYLE] [DRONE] [GRID-4]
ANIMATION: hit reaction, 4 frames, not looping. Frame 1: knocked back to the left and
tilted 20 degrees, the eye flickering into an X shape, one rotor bent. Frame 2: tilted
10 degrees, the eye dim. Frame 3: level again, the eye narrowed angrily. Frame 4: back
to the hover idle frame 1 with the rotor straight.
```

---

## 5. Nhập vào game

Ảnh để trong `art_source/bosses/steel_robot/` (và `art_source/bosses/drone/`). Lần nhập đầu tạo
`import.json` cạnh ảnh (theo mẫu `ice_witch/import.json`), mỗi animation một mục với đúng tên ở bảng
trên (`idle`, `cast`, `burst`, `summon`, `hurt`), `frames`, `loop`, `peak` (chỉ số từ 0) và:

- Phương án A (lưới): `"src": "side_cast/sheet_v1.png", "grid": [3, 2]` (sheet 4 frame: `[2, 2]`).
- Phương án B (mỗi frame một ảnh): `"src": ["side_cast/frame_1.png", ..., "side_cast/frame_6.png"]`.
- Nền xanh lá ở 4 góc (`background.key` "corners"); `body`: màu thép xanh (hue khoảng 205–228,
  minSat khoảng 0.2) để tool đo chiều cao thân và tìm chân.

Lệnh (trong thư mục `battle-squad-game`, editor có thể đang mở):

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_boss_frames.gd -- steel_robot --contact=/tmp/steel_robot_contact.png
```

---

## 6. Kiểm tra trước khi đưa vào game

- **Tách frame:** đúng số ô (6 hoặc 4), đọc trái → phải, trên → dưới đúng thứ tự trong prompt; mỗi
  rô-bốt nằm trọn trong ô của nó, quanh nó còn nền xanh trống, **hai hình cạnh nhau không chạm nhau**
  (kể cả ăng-ten, nòng pháo, ụ cối, vuốt). Không có đường kẻ ô, số frame.
- **Cùng cỡ, cùng đường chân:** đế chân ở cùng độ cao trong mọi ô, đỉnh mái vòm gần như cùng độ cao
  (chỉ thấp hơn chút khi khom); không có frame to / nhỏ hơn hẳn.
- **Thiết kế:** nhìn sang phải; pháo tay ở tay gần (trước thân), vuốt ba ngón ở tay xa; hai ụ cối 4
  ống sau lưng (bên trái hình); lõi cam giữa ngực, kính xanh lơ, ăng-ten đầu đỏ, váy hông sọc vàng
  đen. Không có màu xanh lá, xanh nõn chuối, hồng / tím trên người.
- **Nền:** một màu #00FF00 phẳng, không gradient, không bóng đổ, không sàn; ánh sáng không toả ra nền.
- **Nội dung:** không chữ, không đạn, không tia laze, không chớp lửa / khói / tia lửa, không drone
  trong sheet summon.
- **Nối animation:** frame cuối của cast / burst / summon / hurt = dáng idle frame 1; idle frame 6
  nối mượt về frame 1.
- **Dấu ✦:** cứ để, tool xoá; nếu ✦ nằm đè lên người rô-bốt thì ghi lại vị trí khi nhập.
