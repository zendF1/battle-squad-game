# Khổng Lồ Đá (boss hệ Thổ, mới): prompt tạo ảnh boss

Dùng cho AI vẽ ảnh (GPT-image / Gemini / Midjourney / Flux…). Prompt viết bằng tiếng Anh vì các model
hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế là thiết kế riêng của game, không
lấy theo game nào khác: đừng thêm tên game / tên hãng / "in the style of <game>" vào prompt.

Boss mới, chưa có trong game; tên và kỹ năng theo bản thiết kế đang chờ duyệt (đổi thì sửa file
này). Kỹ năng trong trận: **Mưa đá tảng** (đá tảng rơi quanh cả đội), **Gai đá trồi** (đánh dấu
dưới chân từng người, lượt sau gai đá trồi lên), **Ném tảng đá khổng lồ** (một tảng đá to đập một
người), và gọi **Trụ đá** (lính con đứng yên, còn trụ thì boss được giáp đá).

## Cách dùng

1. **Tạo ảnh thiết kế gốc (mục 1) trước**, chọn 1 bản ưng nhất. Từ đó về sau luôn **đính kèm ảnh
   gốc làm ảnh tham chiếu** cho mọi prompt khác, để khổng lồ giữ đúng dáng, màu ở mọi frame.
2. Mỗi prompt = **khối STYLE** (mục 0) + **khối BOSS** + phần riêng của ảnh đó. Dán cả ba.
3. **Animation**: tạo kiểu **sprite sheet một hàng** (mọi frame trong một ảnh, cùng cỡ, cách đều).
   Model vẽ lệch giữa các frame thì tạo từng frame với ảnh tham chiếu + câu "same character, same
   scale, same position on the canvas, only the pose changes".
4. **Nền**: xanh lá đặc **#00FF00**, một màu phẳng, không bóng đổ. Khổng lồ toàn màu đá nâu, vàng
   đất, hổ phách, **không có rêu / lá xanh** (để khác hẳn boss hệ Mộc và để tool xoá nền sạch). Dấu
   ✦ của AI ở góc tool tự xoá.
5. **Khung**: mỗi frame 1280×720, khổng lồ **nhìn sang PHẢI** (3/4 về phía người xem), giữa khung,
   cao khoảng 80% khung, chừa chỗ trên đầu cho tay giơ lên. Sheet N frame: N × 1280 ngang, 720
   dọc, hoặc lưới vuông nếu model không ra được ảnh dài: ghi rõ số hàng / cột.
6. Bỏ ảnh vào `art_source/bosses/rock_giant/<thư mục ghi ở từng mục>/`, tên `sheet_v1.png` (ảnh
   chân dung: `portrait_v1.png`, `bust_v1.png`).

---

## 0. Khối STYLE chung (dán vào đầu mọi prompt)

```
2D mobile game character art, cartoon style matching a cute military artillery game:
bold clean black outlines of even thickness, flat cel-shaded colours with one soft shade
tone and one highlight tone, slightly chibi proportions, rounded friendly shapes, crisp
vector-like edges, no texture noise, no painterly brush strokes, no gradients on the
background, no text, no watermark, no frame border, no drop shadow on the background.
Solid flat green background #00FF00. Character centred, full body visible, facing right
(side view, 3/4 towards the viewer), canvas 1280x720.
```

## Khối BOSS (giữ cố định ở mọi prompt)

```
BOSS: "Rock Giant", the ancient guardian of a desert canyon, a living giant built of big
rounded boulders stacked together. Warm sandstone body (#B07A45) with darker brown shade
(#6E4A2E) and light ochre highlights (#D9A766), a few horizontal rock strata lines on the
boulders. A huge chest boulder with a glowing amber gem set in the middle (#FFC23D, white
inner light) and thin glowing amber rune lines running from it across the chest and the
arms. Very long heavy arms ending in enormous round boulder fists (bigger than its head),
short stumpy legs on flat stone feet. A small head boulder sunk between the shoulders,
a heavy overhanging brow, two glowing amber eyes, a stern frown. Clusters of amber-yellow
quartz crystals growing from both shoulders. No moss, no plants, no green anywhere. Huge
and slow but cute and readable at small size.
```

---

## 1. Ảnh thiết kế gốc (model sheet): `concept/`

```
[STYLE] [BOSS]
Character model sheet on one image: the same giant three times side by side, same scale:
(1) front view, (2) side view facing right, (3) back view. Neutral standing pose, the
fists resting on the ground beside its feet. Canvas 2560x1280.
```

## 2. Chân dung: `portrait/`

Thẻ boss ở tab Boss, màn tìm trận. Ảnh này cũng là dáng đứng yên trong trận (game gắn xương và tự
làm chuyển động thở / viên ngọc nhấp nháy), nên vẽ **dáng đứng, hai chân chạm đất**.

```
[STYLE] [BOSS]
Heroic boss pose for a selection card: standing wide on both feet, both giant fists raised
and clenched in front of its chest, the gem and the runes blazing, a few small pebbles
floating around its fists, glaring at the viewer. Full body, centred, square canvas
1024x1024, leave 8% empty margin around it.
```

Ảnh nhỏ cho thanh máu:

```
[STYLE] [BOSS]
Head-and-shoulders bust icon: the head boulder with the glowing eyes and the heavy brow,
the shoulder crystals, the top of the chest gem, facing slightly right. Square 512x512,
the giant fills 85% of the canvas.
```

---

## 3. Animation trong trận (nhìn sang phải, 1280×720 mỗi frame)

Mọi sheet thêm khối SHEET:

```
Horizontal sprite sheet, N frames in one row, every frame the same size (1280x720 each),
evenly spaced, the giant at the same scale with its feet on the same ground line and at
the same spot in every frame, only the pose changes between frames.
```

(Thay N bằng số frame của từng mục. Game tự vẽ đá rơi, gai đá, bụi, vết nứt: **không vẽ chúng**
trong ảnh, chỉ vẽ dáng và ánh sáng trên người.)

### 3a. Mưa đá tảng (boulder rain): `side_rain/`, 6 frame, không lặp

```
[STYLE] [BOSS] [SHEET N=6]
Boulder rain, not looping: frames 1-2 the giant raises both fists high above its head,
the runes glowing brighter, frame 3 it smashes both fists together above its head with a
bright amber flash between them, frame 4 the fists apart again, arms still high, frames
5-6 it lowers its arms back to standing. Do NOT draw falling rocks, only the giant.
```

### 3b. Gai đá trồi (stone spikes): `side_spikes/`, 6 frame, không lặp

```
[STYLE] [BOSS] [SHEET N=6]
Ground punch, not looping: frames 1-2 the giant lifts both fists to one side, frame 3 it
punches both fists deep into the ground in front of it, the body bent forward, frame 4 the
fists still in the ground, the gem and the runes flashing, frames 5-6 it pulls the fists
out and stands back up. Do NOT draw spikes, cracks or dust, only the giant.
```

### 3c. Ném tảng đá khổng lồ (throw): `side_throw/`, 6 frame, không lặp

Tảng đá to cầm trên tay ở frame 1–3; từ frame 4 tay đã ném, không còn đá (game vẽ tảng đá bay).

```
[STYLE] [BOSS] [SHEET N=6]
Giant boulder throw, not looping: frame 1 the giant grips a huge round boulder (as big as
its own chest) with both hands at its belly, frame 2 it heaves the boulder up above its
head, frame 3 it leans back with the boulder high behind its head, frame 4 it throws:
arms stretched forward to the right, hands now empty, frames 5-6 it recovers to standing.
```

### 3d. Gọi trụ đá (summon): `side_summon/`, 4 frame, không lặp

```
[STYLE] [BOSS] [SHEET N=4]
Summon stomp, not looping: frame 1 the giant lifts one foot high, frame 2 it stomps it
down hard, its body jolted, frame 3 it raises one open hand upward, palm up, the gem and
the runes glowing brightly, frame 4 back to standing. No totems, no dust in the image.
```

### 3e. Trúng đòn (hurt): `side_hurt/`, 2 frame

Game làm cảnh chết từ frame đầu của sheet này (vỡ vụn thành đá), không cần sheet chết riêng.

```
[STYLE] [BOSS] [SHEET N=2]
Hit reaction: frame 1 knocked back slightly to the left, a few rock chips breaking off
its chest, eyes squeezed shut, one fist thrown up, frame 2 recovering, eyes narrowed
angrily.
```

---

## 4. Trụ đá (lính con): `minion_totem/`

Trụ đá mọc lên từ mặt đất, đứng yên, bắn sỏi; còn trụ nào đứng thì boss được giáp đá (game vẽ
giáp và dây sáng nối tới boss). Nền xanh lá, nhìn sang phải. Mỗi prompt = [STYLE] + khối MINION
dưới đây + phần riêng (cỡ canvas ghi trong phần riêng thay cho 1280×720 của khối STYLE).

```
MINION: "Stone Totem", a short chunky stone pillar of the Rock Giant: three stacked
sandstone blocks (#B07A45, darker #6E4A2E), the top block carved with a grumpy face with
two glowing amber eyes, a glowing amber rune on the middle block (#FFC23D), a small amber
crystal on the top, a flat base on the ground. No moss, no green. Cute and stubborn.
```

- `minion_totem/idle_sheet_v1.png`: `[STYLE] [MINION] Horizontal sprite sheet of 4 frames (1024x1024 each) of an idle loop: the totem stays still, only the eyes, the rune and the crystal glow brighter in frames 2-3 and dimmer in frames 1 and 4. The base on the same ground line in every frame.`
- `minion_totem/shoot_sheet_v1.png`: `[STYLE] [MINION] Horizontal sprite sheet of 3 frames (1024x1024 each): frame 1 the top block leans back, frame 2 it nods forward hard to the right with its mouth open, frame 3 back upright. No projectile.`

---

## 5. Đạn và hiệu ứng (nền xanh lá, mỗi cái một ảnh vuông 512×512)

Đạn vẽ **nằm ngang, mũi sang PHẢI** (game tự xoay theo đường bay).

### 5a. Đá tảng (mưa đá): `fx/boulder.png`

```
[STYLE]
A single round lumpy sandstone boulder flying to the right, brown and ochre with one
crack and a few small chips, a short dust trail behind it on the left. Bold black outline.
Centred on a 512x512 canvas, solid green background #00FF00.
```

### 5b. Tảng đá khổng lồ (ném): `fx/giant_boulder.png`

```
[STYLE]
A huge round sandstone boulder with glowing amber rune lines cracked across it, chunks
missing, a thick dust trail behind it on the left. Bold black outline. Centred on a
512x512 canvas, solid green background #00FF00.
```

### 5c. Gai đá: `fx/stone_spike.png`

Gai đá trồi lên khỏi mặt đất; vẽ **dựng đứng, mũi hướng LÊN**, đáy phẳng (game cắm đáy xuống đất).

```
[STYLE]
A cluster of three sharp sandstone spikes pointing straight up, the middle one tallest,
brown and ochre with amber crystal tips, a flat broken base at the bottom. Bold black
outline. Centred on a 512x512 canvas, solid green background #00FF00.
```

### 5d. Viên sỏi của trụ đá: `fx/pebble.png`

```
[STYLE]
A small sharp sandstone pebble flying to the right with a tiny glowing amber chip inside
and a short dust trail on the left. Centred on a 512x512 canvas, solid green background
#00FF00.
```

---

## 6. Kiểm tra trước khi đưa vào game

- **Nhân vật:** mọi frame cùng một khổng lồ, cùng màu, cùng cỡ; chân chạm cùng một đường đất.
- **Hướng:** nhìn sang phải. Game tự lật ảnh khi quay sang trái.
- **Nền:** chỉ một màu xanh lá phẳng; không có rêu / lá / màu xanh lá trên người.
- **Nội dung:** không chữ, không viền; không vẽ đá rơi, gai, bụi hay icon trong ảnh nhân vật (trừ
  tảng đá cầm trên tay ở 3c).
- **Đặt file:** đúng các thư mục ở trên, rồi báo để làm `import.json` và nối ảnh vào trận.
