# Mộc Tinh (boss hệ Mộc, mới): prompt tạo ảnh boss

Dùng cho AI vẽ ảnh (GPT-image / Gemini / Midjourney / Flux…). Prompt viết bằng tiếng Anh vì các model
hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế là thiết kế riêng của game, không
lấy theo game nào khác: đừng thêm tên game / tên hãng / "in the style of <game>" vào prompt.

Boss mới, chưa có trong game; tên và kỹ năng theo bản thiết kế đang chờ duyệt (đổi thì sửa file
này). Mộc Tinh là cây cổ thụ thành tinh, **cắm rễ một chỗ, không di chuyển**. Kỹ năng trong trận:
**Roi dây leo** (dây leo trồi lên dưới chân từng người, có thể trói chân), **Mưa gai độc** (gai rơi
khắp map, gây trúng độc), **Hút sinh lực** (hút máu một người để hồi máu cho mình), và gọi **Nấm
độc** (lính con phun bào tử; còn nấm thì Mộc Tinh hồi máu).

## Cách dùng

1. **Tạo ảnh thiết kế gốc (mục 1) trước**, chọn 1 bản ưng nhất. Từ đó về sau luôn **đính kèm ảnh
   gốc làm ảnh tham chiếu** cho mọi prompt khác, để Mộc Tinh giữ đúng dáng, màu ở mọi frame.
2. Mỗi prompt = **khối STYLE** (mục 0) + **khối BOSS** + phần riêng của ảnh đó. Dán cả ba.
3. **Animation**: tạo kiểu **sprite sheet một hàng** (mọi frame trong một ảnh, cùng cỡ, cách đều).
   Model vẽ lệch giữa các frame thì tạo từng frame với ảnh tham chiếu + câu "same character, same
   scale, same position on the canvas, only the pose changes".
4. **Nền**: hồng tím đặc **#FF00FF** (magenta), một màu phẳng, không bóng đổ. **Không dùng nền xanh
   lá** (lẫn với lá cây). Trên người Mộc Tinh không được có màu hồng / tím (hoa vẽ màu trắng kem),
   vì tool sẽ xoá nhầm. Dấu ✦ của AI ở góc tool tự xoá.
5. **Khung**: mỗi frame 1280×720, Mộc Tinh **nhìn sang PHẢI** (3/4 về phía người xem), giữa khung,
   cao khoảng 85% khung (tán lá là phần cao nhất). Sheet N frame: N × 1280 ngang, 720 dọc, hoặc lưới
   vuông nếu model không ra được ảnh dài: ghi rõ số hàng / cột.
6. Bỏ ảnh vào `art_source/bosses/tree_spirit/<thư mục ghi ở từng mục>/`, tên `sheet_v1.png` (ảnh
   chân dung: `portrait_v1.png`, `bust_v1.png`).

---

## 0. Khối STYLE chung (dán vào đầu mọi prompt)

```
2D mobile game character art, cartoon style matching a cute military artillery game:
bold clean black outlines of even thickness, flat cel-shaded colours with one soft shade
tone and one highlight tone, slightly chibi proportions, rounded friendly shapes, crisp
vector-like edges, no texture noise, no painterly brush strokes, no gradients on the
background, no text, no watermark, no frame border, no drop shadow on the background.
Solid flat magenta background #FF00FF. Character centred, full body visible, facing right
(side view, 3/4 towards the viewer), canvas 1280x720.
```

## Khối BOSS (giữ cố định ở mọi prompt)

```
BOSS: "Tree Spirit", an ancient tree of a deep forest come alive. A thick, short, gnarled
trunk as its body, warm brown bark (#7A5232) with darker grooves (#4D3320) and light bark
edges (#A87A4F), a big round knot in the chest glowing golden-amber (#FFC94D) like a heart
of sap. A face in the bark: two glowing yellow-green eyes (#D6FF66), a heavy bark brow, a
wide mouth like a crack in the wood, a long mossy beard of hanging leaves. Two long branch
arms with twig-like three-finger claws and a few leaves on them. Thick roots spread out on
the ground like feet, firmly rooted. A big round crown of leaves on its head and shoulders
in fresh greens (#4FA83D, light #8FD95A, dark #2E6B2A), a few small cream-white blossoms
and a few small glowing golden fruits hanging in the leaves. No pink or purple anywhere.
Old, wise and menacing but cute and readable at small size.
```

---

## 1. Ảnh thiết kế gốc (model sheet): `concept/`

```
[STYLE] [BOSS]
Character model sheet on one image: the same tree spirit three times side by side, same
scale: (1) front view, (2) side view facing right, (3) back view. Neutral standing pose,
the branch arms relaxed at its sides, the roots on the ground. Canvas 2560x1280.
```

## 2. Chân dung: `portrait/`

Thẻ boss ở tab Boss, màn tìm trận. Ảnh này cũng là dáng đứng yên trong trận (game gắn xương và tự
làm tán lá đung đưa, tay cành lắc nhẹ, tim nhựa nhấp nháy), nên vẽ **dáng đứng, rễ bám đất, hai tay
dang ra khỏi thân** (để game tách tay).

```
[STYLE] [BOSS]
Heroic boss pose for a selection card: rooted firmly, both branch arms spread wide away
from the trunk with the twig claws open, the sap heart and the eyes glowing bright, a few
leaves drifting around it, the leaf crown full, glaring at the viewer. Full body, centred,
square canvas 1024x1024, leave 8% empty margin around it.
```

Ảnh nhỏ cho thanh máu:

```
[STYLE] [BOSS]
Head-and-shoulders bust icon: the bark face with the glowing eyes and the leaf beard, the
lower part of the leaf crown, the top of the glowing sap heart, facing slightly right.
Square 512x512, the face fills 85% of the canvas.
```

---

## 3. Animation trong trận (nhìn sang phải, 1280×720 mỗi frame)

Mọi sheet thêm khối SHEET:

```
Horizontal sprite sheet, N frames in one row, every frame the same size (1280x720 each),
evenly spaced, the tree spirit at the same scale with its roots on the same ground line
and at the same spot in every frame, only the pose changes between frames. The roots
never move.
```

(Thay N bằng số frame của từng mục. Game tự vẽ dây leo, gai, bào tử, tia hút máu: **không vẽ
chúng** trong ảnh, chỉ vẽ dáng và ánh sáng trên người.)

### 3a. Roi dây leo (vine lash): `side_vines/`, 6 frame, không lặp

```
[STYLE] [BOSS] [SHEET N=6]
Vine command, not looping: frames 1-2 the tree spirit raises both branch arms high, the
eyes glowing brighter, frame 3 it swings both arms down and forward to the right, claws
pointing at the ground, frame 4 the same with the sap heart flashing, frames 5-6 it lifts
its arms back to standing. Do NOT draw vines on the ground, only the tree spirit.
```

### 3b. Mưa gai độc (thorn rain): `side_thorns/`, 6 frame, không lặp

Gai bắn lên từ tán lá.

```
[STYLE] [BOSS] [SHEET N=6]
Thorn volley, not looping: frames 1-2 the tree spirit leans back and its leaf crown puffs
up and bristles, frame 3 it shakes violently, the crown flung upward, the leaves standing
on end, frame 4 a second smaller shake, frames 5-6 it settles back, a few leaves falling.
Do NOT draw thorns or projectiles, only the tree spirit.
```

### 3c. Hút sinh lực (life drain): `side_drain/`, 6 frame, không lặp

Game vẽ tia sinh lực từ người chơi bay về tim nhựa.

```
[STYLE] [BOSS] [SHEET N=6]
Life drain, not looping: frame 1 it reaches one branch arm forward to the right, claws
open, frame 2 it clenches the claws as if pulling something towards itself, frames 3-4
it draws the arm back to its chest, the sap heart glowing brighter and brighter, small
fresh leaves sprouting on its arms, frames 5-6 it stands tall and satisfied, the glow
fading. Do NOT draw the beam, only the tree spirit.
```

### 3d. Gọi nấm độc (summon): `side_summon/`, 4 frame, không lặp

```
[STYLE] [BOSS] [SHEET N=4]
Summon, not looping: frame 1 it presses both claws down towards its roots, frame 2 its
roots and the bark glow faintly golden, frame 3 the glow peaks, the eyes bright, frame 4
back to standing. No mushrooms in the image.
```

### 3e. Trúng đòn (hurt): `side_hurt/`, 2 frame

Game làm cảnh chết từ frame đầu của sheet này (lá rụng, thân héo), không cần sheet chết riêng.

```
[STYLE] [BOSS] [SHEET N=2]
Hit reaction: frame 1 the trunk jolted back to the left, wood chips and leaves flying
off, eyes squeezed shut, the arms flung up, frame 2 recovering, eyes narrowed angrily.
```

---

## 4. Nấm độc (lính con): `minion_mushroom/`

Nấm mọc lên trên mặt đất, đứng yên, mỗi lượt phun bào tử quanh mình, bị bắn chết thì nổ ra bào tử.
Nền magenta, nhìn sang phải. Mỗi prompt = [STYLE] + khối MINION dưới đây + phần riêng (cỡ canvas
ghi trong phần riêng thay cho 1280×720 của khối STYLE).

```
MINION: "Poison Mushroom", a small mushroom creature of the Tree Spirit: a big round cap in
sickly yellow-green (#B8D936, darker #7A9A1F) with darker olive spots, a cream-white stem
(#F2E6C8) as its body, two small angry eyes and a frown on the stem, two tiny stubby feet,
a few faint yellow-green spores floating around the cap. No pink, no purple. Cute and
nasty.
```

- `minion_mushroom/idle_sheet_v1.png`: `[STYLE] [MINION] Horizontal sprite sheet of 4 frames (1024x1024 each) of an idle loop: the mushroom squashes down a little and stretches back up, the cap wobbling. Feet on the same ground line in every frame.`
- `minion_mushroom/puff_sheet_v1.png`: `[STYLE] [MINION] Horizontal sprite sheet of 3 frames (1024x1024 each): frame 1 it squashes down hard, cheeks puffed, frame 2 it springs up with the cap flung open, frame 3 back to normal. No spore cloud in the image.`

---

## 5. Đạn và hiệu ứng (nền magenta, mỗi cái một ảnh vuông 512×512)

Đạn vẽ **nằm ngang, mũi sang PHẢI** (game tự xoay theo đường bay).

### 5a. Gai độc: `fx/poison_thorn.png`

```
[STYLE]
A single big curved wooden thorn flying to the right, dark brown with a sharp tip on the
right, a drop of glowing yellow-green poison at the tip, two small leaves at the base on
the left. Bold black outline. Centred on a 512x512 canvas, solid magenta background
#FF00FF.
```

### 5b. Dây leo trồi lên: `fx/vine_burst.png`

Dây leo trồi lên khỏi mặt đất; vẽ **dựng đứng, ngọn hướng LÊN**, gốc phẳng (game cắm gốc xuống đất).

```
[STYLE]
Three thick thorny vines bursting straight up out of the ground, twisting around each
other, green stems with brown thorns and a few leaves, the tips curling like grabbing
hands, a flat cut base at the bottom. Bold black outline. Centred on a 512x512 canvas,
solid magenta background #FF00FF.
```

### 5c. Đám bào tử: `fx/spore_cloud.png`

```
[STYLE]
A round puffy cartoon cloud of poison spores, yellow-green with lighter puffs and small
dots inside, soft edges with a thin outline. Centred on a 512x512 canvas, solid magenta
background #FF00FF.
```

---

## 6. Kiểm tra trước khi đưa vào game

- **Nhân vật:** mọi frame cùng một Mộc Tinh, cùng màu, cùng cỡ; rễ ở cùng một chỗ và cùng đường đất.
- **Hướng:** nhìn sang phải. Game tự lật ảnh khi quay sang trái.
- **Nền:** chỉ một màu magenta phẳng; không có màu hồng / tím trên người hay trên nấm.
- **Nội dung:** không chữ, không viền; không vẽ dây leo, gai, bào tử, tia hay icon trong ảnh nhân vật.
- **Đặt file:** đúng các thư mục ở trên, rồi báo để làm `import.json` và nối ảnh vào trận.
