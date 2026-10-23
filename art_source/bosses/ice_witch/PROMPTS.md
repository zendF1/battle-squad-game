# Phù Thuỷ Băng: prompt tạo asset và animation

Dùng cho AI vẽ ảnh (GPT-image / Midjourney / Flux…). Prompt viết bằng tiếng Anh vì các model hiểu
tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế nhân vật là thiết kế riêng của game,
không lấy theo game nào khác: đừng thêm tên game / tên hãng / "in the style of <game>" vào prompt.

## Cách dùng

1. **Tạo ảnh thiết kế gốc (mục 1) trước**, chọn 1 bản ưng nhất. Từ đó về sau luôn **đính kèm ảnh
   gốc này làm ảnh tham chiếu** (image reference / "character reference") cho mọi prompt khác, để
   nhân vật giữ đúng mặt, màu áo, cây trượng ở mọi frame.
2. Mỗi prompt = **khối STYLE chung** (mục 0) + **phần riêng** của asset đó. Dán cả hai.
3. **Animation**: tạo theo kiểu **sprite sheet một hàng** (tất cả frame trong một ảnh, cùng cỡ,
   cách đều) thì nhân vật đồng đều nhất. Nếu model vẽ lệch giữa các frame, tạo từng frame một với
   ảnh tham chiếu + câu "same character, same scale, same position on the canvas, only the pose
   changes".
4. **Nền**: hồng tím đặc **#FF00FF** (magenta), một màu phẳng, không bóng đổ xuống nền. Tool nhập
   ảnh của game tự xoá nền theo màu ở 4 góc (dấu ✦ của AI ở góc cũng tự xoá). Đừng dùng nền
   xanh lá cho phù thuỷ (lẫn với vệt băng phát sáng); đừng dùng nền trắng (lẫn với sương tuyết).
5. **Khung**: mỗi frame 1280×720 (như ảnh nhân vật hiện tại), nhân vật **nhìn sang PHẢI**, đứng giữa
   khung, cao khoảng 80% chiều cao khung, có khoảng trống quanh người cho áo choàng / tay giơ lên.
   Sheet nhiều frame: N × 1280 ngang, 720 dọc (vd. 6 frame = 7680×720), hoặc ảnh vuông lưới nếu model
   không ra được ảnh dài: ghi rõ số hàng / cột.
6. Ảnh làm xong bỏ vào `art_source/bosses/ice_witch/<tên thư mục ghi ở từng mục>/`. Game hiện vẽ
   boss bằng code (`match/boss/boss_art.gd`), nên cần thêm một tool nhập ảnh boss (giống
   `tools/import_frames.gd` của nhân vật) trước khi ảnh hiện trong trận.

---

## 0. Khối STYLE chung (dán vào đầu mọi prompt)

```
2D mobile game character art, cartoon style matching a cute military artillery game:
bold clean black outlines of even thickness, flat cel-shaded colours with one soft shade
tone and one highlight tone, slightly chibi proportions (big head about one third of the
body height, expressive big eyes), rounded friendly shapes, crisp vector-like edges, no
texture noise, no painterly brush strokes, no gradients on the background, no text, no
watermark, no frame border, no drop shadow on the background. Solid flat magenta
background #FF00FF. Character centred, full body visible, facing right (side view, 3/4
towards the viewer), canvas 1280x720.
```

## Thiết kế nhân vật (giữ cố định ở mọi prompt)

```
CHARACTER: "Ice Witch", a boss: a mysterious floating sorceress of an eternal snow peak.
Tall hooded cloak in deep indigo blue (#38338A) with lighter periwinkle folds (#5C7AE0),
a jagged frost-white trim along the hem (#D9F5FF); the cloak hem has no feet, it fades
into curling frost mist because she always hovers above the ground. Pale icy-blue face
inside the hood, two glowing cyan eyes (#73E0FF), a calm confident smirk, a few strands
of silver-white hair. A dark navy belt with a small diamond-shaped ice crystal buckle.
In her front hand a long silver-blue staff topped with a large glowing diamond-shaped ice
crystal (#73E0FF, white inner light). Three small diamond-shaped ice shards orbit around
her chest height. Menacing but cute, readable at small size.
```

---

## 1. Ảnh thiết kế gốc (model sheet): `concept/`

Ảnh tham chiếu cho mọi ảnh sau. Tạo 4–8 bản, chọn 1.

```
[STYLE] [CHARACTER]
Character model sheet on one image: the same character three times side by side, same
scale: (1) front view, (2) side view facing right, (3) back view. Neutral floating idle
pose, staff held upright in the front hand, the three ice shards around her. Canvas
2560x1280.
```

## 2. Chân dung: `portrait/`

Dùng cho thẻ boss ở tab Boss, màn tìm trận và thanh máu boss.

```
[STYLE] [CHARACTER]
Heroic boss pose for a selection card: floating, staff raised diagonally, the crystal
glowing bright, the three ice shards spread around her, cloak billowing, a little frost
mist under the hem, looking at the viewer with a confident smirk. Full body, centred,
square canvas 1024x1024, leave 8% empty margin around her.
```

Ảnh nhỏ cho thanh máu:

```
[STYLE] [CHARACTER]
Head-and-shoulders bust icon of the character, hood and glowing eyes clearly readable,
the tip of the staff crystal visible at the edge, facing slightly right. Square 512x512,
character fills 85% of the canvas.
```

---

## 3. Animation trong trận (nhìn sang phải, 1280×720 mỗi frame)

Mọi sheet thêm câu này:

```
Horizontal sprite sheet, N frames in one row, every frame the same size (1280x720 each),
evenly spaced, the character at the same scale and the same anchor point in every frame
(the centre of the cloak hem at the same spot), only the pose changes between frames.
The animation loops smoothly from the last frame back to the first.
```

(gọi là khối SHEET; thay N bằng số frame của từng mục; mục không lặp thì bỏ câu cuối. Trong các prompt dưới, [STYLE] = khối mục 0, [CHARACTER] = khối thiết kế nhân vật, [SHEET N=…] = khối này)

### 3a. Đứng lơ lửng (idle): `side_idle/`, 6 frame, lặp

```
[STYLE] [CHARACTER] [SHEET N=6]
Idle hover loop: she floats gently up and down (the whole body rises about 3% of its
height in frames 1-3 and sinks back in frames 4-6), the cloak hem and frost mist ripple,
the three ice shards orbit around her (each frame rotated a sixth of a turn further),
the staff crystal pulses softly brighter in frame 3.
```

### 3b. Bay sang chỗ mới (fly): `side_fly/`, 4 frame, lặp

```
[STYLE] [CHARACTER] [SHEET N=4]
Flying forward loop: she leans forward about 20 degrees, the hood and cloak stream
backwards in the wind, a trail of frost particles behind the hem, the staff held
horizontally behind her, the ice shards trail behind her shoulders.
```

### 3c. Tung chiêu cơ bản (cast): `side_cast/`, 6 frame, không lặp

Dùng cho Gai băng.

```
[STYLE] [CHARACTER] [SHEET N=6]
Spell cast, not looping: frames 1-2 she draws the staff back and the crystal charges
(brighter, small sparkles gather), frame 3 she thrusts the staff forward to the right,
frame 4 a burst of cold light flashes from the crystal, frames 5-6 she recovers back to
the idle pose.
```

### 3d. Tia băng 20 tia (radial burst): `side_burst/`, 6 frame, không lặp

Game tự vẽ 20 tia sáng toả ra; ảnh chỉ cần dáng người. **Không vẽ tia** trong ảnh.

```
[STYLE] [CHARACTER] [SHEET N=6]
Radial burst spell, not looping: frames 1-2 she pulls both arms in and curls slightly,
the staff crystal and her eyes glow intensely, frost energy gathers around her body,
frame 3 she throws both arms and the staff wide open, the cloak flaring out in a circle,
a bright round flash of light centred on her chest, frames 4-6 she slowly settles back
to idle. Do NOT draw any beams or rays, only the pose and the glow on her.
```

### 3e. Bão tuyết (blizzard): `side_blizzard/`, 6 frame, không lặp

Đạn bão tuyết là các mảnh băng bay ra từ quanh người bà ấy.

```
[STYLE] [CHARACTER] [SHEET N=6]
Blizzard summon, not looping: frames 1-2 she raises the staff straight up above her head,
the three orbiting ice shards multiply into a whirling ring of many small shards spinning
fast around her, frames 3-4 the ring of shards expands outward and starts flying away,
snow swirling around her, frames 5-6 only a few shards remain and she lowers the staff
back to idle.
```

### 3f. Triệu hồi người tuyết (summon): `side_summon/`, 4 frame, không lặp

```
[STYLE] [CHARACTER] [SHEET N=4]
Summon gesture, not looping: frame 1 she points the staff down and to the right, frame 2
a swirl of snowflakes spirals out of the crystal, frame 3 the swirl peaks, frame 4 back
to idle. No snowman in the image.
```

### 3g. Trúng đòn (hurt): `side_hurt/`, 2 frame

```
[STYLE] [CHARACTER] [SHEET N=2]
Hit reaction: frame 1 she is knocked back slightly to the left, eyes squeezed shut,
cloak jolted, a few ice chips flying off her, frame 2 recovering, one eye open, annoyed.
```

### 3h. Choáng (stunned): `side_stun/`, 4 frame, lặp

Game tự vẽ sao choáng / khối băng / khiên lên người; ảnh chỉ là dáng.

```
[STYLE] [CHARACTER] [SHEET N=4]
Dizzy loop: she sways left and right while floating lower than usual, hood slightly
tilted, eyes as swirls, the staff drooping, the ice shards wobbling slowly. Do NOT draw
stars or icons, only the pose.
```

### 3i. Chết (death): `side_death/`, 8 frame, không lặp

```
[STYLE] [CHARACTER] [SHEET N=8]
Defeat, not looping: frames 1-2 she recoils with arms out, cracks of light spreading
over the cloak, frames 3-4 her body turns to cracked translucent ice, frames 5-6 she
shatters into many ice fragments flying outward, the staff falling, frames 7-8 only a
few sparkles and a small pile of snow remain where she was.
```

---

## 4. Đạn và hiệu ứng riêng (nền magenta, mỗi cái một ảnh vuông 512×512)

Đạn vẽ **nằm ngang, mũi sang PHẢI** (game tự xoay theo đường bay). Đạn của boss vẽ chi tiết; cỡ
trong trận game tự chỉnh.

### 4a. Mảnh băng quay quanh người, cũng là đạn bão tuyết: `fx/ice_shard.png`

```
[STYLE]
A single small diamond-shaped ice crystal shard, the same shard that orbits the Ice Witch:
faceted, cyan (#73E0FF) with lighter facets and a white inner light line through the
middle, bold black outline, pointing to the right. Centred on a 512x512 canvas, solid
magenta background #FF00FF.
```

Thêm 2 biến thể để đỡ lặp: "slightly longer and thinner" / "slightly chipped on one side".

### 4b. Gai băng: `fx/ice_spike.png`

```
[STYLE]
A long sharp icicle projectile flying to the right: tapered pointed tip on the right,
broken rough base on the left with a few frost crystals, translucent light blue with
cyan facets and an inner glow, bold black outline. Horizontal, centred on a 512x512
canvas, solid magenta background #FF00FF.
```

### 4c. Vụ nổ băng khi trúng: `fx/ice_impact/`, 6 frame

```
[STYLE]
Horizontal sprite sheet of 6 frames (512x512 each): a cartoon ice explosion: frame 1 a
small white-cyan flash, frames 2-3 a star-shaped burst of ice shards and frost cloud
expanding, frames 4-5 shards flying outward and fading, frame 6 a few snowflakes left.
Solid magenta background #FF00FF.
```

### 4d. Vệt sương bay theo đạn / theo người khi bay: `fx/frost_particle.png`

```
[STYLE]
Three small soft frost puff particles and two tiny snowflakes, arranged in a row with
space between them, white with pale cyan shading, simple shapes, no outline on the puffs,
thin outline on the snowflakes. 1024x256 canvas, solid magenta background #FF00FF.
```

---

## 5. Kiểm tra trước khi đưa vào game

- **Nhân vật:** mỗi frame cùng một nhân vật, cùng màu, cùng cỡ. Gấu áo (điểm neo) nằm cùng một
  chỗ, nếu không phù thuỷ sẽ giật khi chạy animation.
- **Hướng:** nhìn sang phải. Game tự lật ảnh khi bà ấy quay sang trái.
- **Nền:**
  - Chỉ một màu magenta phẳng, không có bóng đổ trên nền.
  - Không có màu hồng tím trên người, vì tool sẽ xoá nhầm chỗ đó.
- **Nội dung:** không có chữ, không có viền khung. Chỉ vẽ nhân vật, không vẽ tia hay icon: tia laze,
  sao choáng, khối băng và khiên đều do game tự vẽ.
- **Đặt file:** gửi ảnh vào đúng các thư mục ở trên. Sau đó làm tool nhập ảnh boss và nối vào trận.
