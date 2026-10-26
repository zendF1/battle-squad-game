# Cua Dung Nham: prompt tạo ảnh boss

Dùng cho AI vẽ ảnh (GPT-image / Gemini / Midjourney / Flux…). Prompt viết bằng tiếng Anh vì các model
hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế là thiết kế riêng của game, không
lấy theo game nào khác: đừng thêm tên game / tên hãng / "in the style of <game>" vào prompt.

Hiện game vẽ Cua Dung Nham và Cua con bằng code (`match/boss/boss_art.gd`). Ảnh dưới đây thay phần
đó; cách cắt ảnh giống Phù Thuỷ Băng (`art_source/bosses/ice_witch/`, `tools/import_boss_frames.gd`).

## Cách dùng

1. **Tạo ảnh thiết kế gốc (mục 1) trước**, chọn 1 bản ưng nhất. Từ đó về sau luôn **đính kèm ảnh
   gốc làm ảnh tham chiếu** cho mọi prompt khác, để con cua giữ đúng dáng, màu ở mọi frame.
2. Mỗi prompt = **khối STYLE** (mục 0) + **khối BOSS** + phần riêng của ảnh đó. Dán cả ba.
3. **Animation**: tạo kiểu **sprite sheet một hàng** (mọi frame trong một ảnh, cùng cỡ, cách đều).
   Model vẽ lệch giữa các frame thì tạo từng frame với ảnh tham chiếu + câu "same character, same
   scale, same position on the canvas, only the pose changes".
4. **Nền**: xanh lá đặc **#00FF00**, một màu phẳng, không bóng đổ. Con cua toàn màu đá đen, đỏ, cam,
   vàng, không có xanh lá. (Đừng dùng nền magenta: lẫn với ánh đỏ của dung nham.) Dấu ✦ của AI ở
   góc tool tự xoá.
5. **Khung**: mỗi frame 1280×720, con cua **nhìn sang PHẢI** (3/4 về phía người xem), giữa khung.
   Cua rộng hơn cao: cho nó **rộng khoảng 75% khung**. Sheet N frame: N × 1280 ngang, 720 dọc, hoặc
   lưới vuông nếu model không ra được ảnh dài: ghi rõ số hàng / cột.
6. Bỏ ảnh vào `art_source/bosses/lava_crab/<thư mục ghi ở từng mục>/`, tên `sheet_v1.png` (ảnh
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
BOSS: "Lava Crab", a giant crab living in a volcano crater. A wide, low, heavy crab with a
domed shell of dark basalt rock (#3D2926, lighter rock #664237) covered in a few blunt rock
spikes, glowing lava cracks running across the shell (#FF8C1F with a yellow core #FFD95A),
and a small smoking vent like a mini volcano on top of the shell glowing orange inside.
Red-orange armoured legs (#C7421A), three on each side, pointed tips. Two big pincers, the
front one larger, red-orange with dark rock knuckles and glowing cracks on them. Two short
eye stalks with round yellow eyes and black pupils, a grumpy determined look, a little
underside of pale orange plates. Heavy and dangerous but cute and readable at small size.
```

---

## 1. Ảnh thiết kế gốc (model sheet): `concept/`

```
[STYLE] [BOSS]
Character model sheet on one image: the same crab three times side by side, same scale:
(1) front view, both pincers raised, (2) side view facing right, (3) back view showing the
shell and the vent. Neutral standing pose. Canvas 2560x1280.
```

## 2. Chân dung: `portrait/`

Thẻ boss ở tab Boss, màn tìm trận. Ảnh này cũng là dáng đứng yên trong trận (game gắn xương và tự
làm chuyển động thở / vết nứt nhấp nháy), nên vẽ **dáng đứng, mọi chân chạm đất**.

```
[STYLE] [BOSS]
Heroic boss pose for a selection card: standing on all legs, both pincers raised high and
open, the lava cracks and the vent blazing, a little smoke from the vent, the eyes glaring
at the viewer. Full body, centred, square canvas 1024x1024, leave 8% empty margin around it.
```

Ảnh nhỏ cho thanh máu:

```
[STYLE] [BOSS]
Bust icon: the front of the shell with the eye stalks and the front pincer raised beside
them, the glowing cracks readable, facing slightly right. Square 512x512, the crab fills
85% of the canvas.
```

---

## 3. Animation trong trận (nhìn sang phải, 1280×720 mỗi frame)

Mọi sheet thêm khối SHEET:

```
Horizontal sprite sheet, N frames in one row, every frame the same size (1280x720 each),
evenly spaced, the crab at the same scale with its feet on the same ground line and at
the same spot in every frame, only the pose changes between frames.
```

(Thay N bằng số frame của từng mục. Game tự vẽ bom lửa, vũng dung nham, sóng chấn động, bụi:
**không vẽ chúng** trong ảnh, chỉ vẽ dáng và ánh sáng trên người.)

### 3a. Bom dung nham (eruption): `side_eruption/`, 6 frame, không lặp

Bom phun lên từ miệng núi lửa trên mai.

```
[STYLE] [BOSS] [SHEET N=6]
Shell eruption, not looping: frames 1-2 the crab squats low, legs bent, the cracks and the
vent glowing brighter and brighter, frame 3 it pushes up hard, the vent blasts a bright
orange flash straight up, frame 4 a second smaller flash, frames 5-6 it settles back down,
the vent smoking. Do NOT draw the bombs or the lava, only the crab and the glow.
```

### 3b. Cú kẹp đập (slam): `side_slam/`, 6 frame, không lặp

```
[STYLE] [BOSS] [SHEET N=6]
Pincer slam, not looping: frames 1-2 the crab rears up on its back legs and lifts both
pincers high above its shell, frame 3 it smashes both pincers down onto the ground in
front of it to the right, the body slammed low, frame 4 the same with the pincers still on
the ground, frames 5-6 it lifts them back up to the standing pose. Do NOT draw dust, rocks
or a shockwave, only the crab.
```

### 3c. Gọi cua con (summon): `side_summon/`, 4 frame, không lặp

```
[STYLE] [BOSS] [SHEET N=4]
Summon call, not looping: frame 1 the crab clacks its pincers together above its head,
frame 2 it opens them wide with its mouth open as if roaring, frame 3 the same, the vent
puffing, frame 4 back to standing. No small crabs in the image.
```

### 3d. Trúng đòn (hurt): `side_hurt/`, 2 frame

Game làm cảnh chết từ frame đầu của sheet này, không cần sheet chết riêng.

```
[STYLE] [BOSS] [SHEET N=2]
Hit reaction: frame 1 knocked back to the left, rock chips flying off the shell, eyes
squeezed shut, the pincers flung up, frame 2 recovering, eyes narrowed angrily.
```

---

## 4. Cua con (lính con): `minion_crab/`

Cua con bò tới gần người chơi rồi nổ. Nền xanh lá, nhìn sang phải. Mỗi prompt = [STYLE] + khối MINION
dưới đây + phần riêng (cỡ canvas ghi trong phần riêng thay cho 1280×720 của khối STYLE).

```
MINION: "Baby Crab", a small bright lava crab: the same build as the Lava Crab but small and
round, a bright orange-red shell (#D9521F) with a lighter top (#FF8C4D) and one thin glowing
crack, two little pincers raised, three short legs each side, two eye stalks with big round
eyes, a cheeky grin. Cute.
```

- `minion_crab/walk_sheet_v1.png`: `[STYLE] [MINION] Horizontal sprite sheet of 6 frames (1024x1024 each) of a sideways scuttle loop to the right: the legs alternate, the body bobs a little, the pincers sway. Feet on the same ground line in every frame.`
- `minion_crab/alarm_v1.png`: `[STYLE] [MINION] About to blow up: the shell glowing bright red-orange, the crack wide and blazing, the eyes wide in panic. Canvas 1024x1024.`

---

## 5. Đạn và hiệu ứng (nền xanh lá, mỗi cái một ảnh vuông 512×512)

Đạn vẽ **nằm ngang, mũi sang PHẢI** (game tự xoay theo đường bay).

### 5a. Bom dung nham: `fx/magma_bomb.png`

```
[STYLE]
A single round lava bomb flying to the right: a ball of dark cooled rock with bright
orange-yellow molten cracks glowing through it, a short trail of fire and small embers
behind it on the left. Bold black outline on the rock. Centred on a 512x512 canvas, solid
green background #00FF00.
```

### 5b. Đạn của cua con: `fx/crab_spit.png`

```
[STYLE]
A small blob of glowing orange lava spit flying to the right, a rounded front and a few
tiny droplets trailing behind on the left. Centred on a 512x512 canvas, solid green
background #00FF00.
```

---

## 6. Kiểm tra trước khi đưa vào game

- **Nhân vật:** mọi frame cùng một con cua, cùng màu, cùng cỡ; chân chạm cùng một đường đất.
- **Hướng:** nhìn sang phải. Game tự lật ảnh khi quay sang trái.
- **Nền:** chỉ một màu xanh lá phẳng; không có màu xanh lá trên người cua.
- **Nội dung:** không chữ, không viền; không vẽ bom, dung nham, bụi, sóng hay icon trong ảnh cua.
- **Đặt file:** đúng các thư mục ở trên, rồi báo để làm `import.json` và nối ảnh vào trận.
