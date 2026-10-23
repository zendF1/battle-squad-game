# Tide: prompt tạo ảnh nhân vật

Dùng cho AI vẽ ảnh (GPT-image / Midjourney / Flux…). Prompt viết bằng tiếng Anh vì các model hiểu
tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Tide là thiết kế riêng của game, không lấy theo
game nào khác: đừng thêm tên game / tên hãng / "in the style of <game>" vào prompt.

Hiện Tide dùng ảnh tạm: ảnh của Flora đổi màu xanh ngọc / trắng (`assets/characters/tide/`, xem
`assets/README.md` mục "Tide's placeholder art"). Làm xong các ảnh dưới đây thì thay ảnh tạm.

## Cách dùng

1. **Tạo ảnh thiết kế gốc (mục 1) trước**, chọn 1 bản ưng nhất. Từ đó về sau luôn **đính kèm ảnh
   gốc này làm ảnh tham chiếu** (image reference / "character reference") cho mọi prompt khác, để
   Tide giữ đúng mặt, mũ trùm nước, bình nước sau lưng và màu áo ở mọi ảnh.
2. Mỗi prompt = **khối STYLE chung** (mục 0) + **khối thiết kế nhân vật** + **phần riêng** của ảnh đó.
   Dán cả ba.
3. **Nét vẽ phải giống 4 nhân vật đang có** (Rookie, Tanko, Spark, Flora): đính kèm thêm
   `art_source/characters/lineup_v1.png` khi tạo ảnh gốc và nói "same art style as the attached
   characters".
4. **Nền** (mỗi mục ghi rõ):
   - ảnh chạy và ảnh đứng: **nền trong suốt** (như của Flora), hoặc trắng đặc nếu model không ra được
     nền trong suốt;
   - ảnh quỳ và súng: **xanh lá đặc #00FF00** (một màu phẳng, không bóng đổ xuống nền). Tool nhập ảnh
     lấy màu ở 4 góc làm màu nền (dấu ✦ của AI ở góc cũng tự xoá);
   - không dùng nền xanh ngọc / xanh dương (lẫn với áo và nước của Tide).
5. **Hướng và khung:** nhân vật **nhìn sang PHẢI** (góc ngang, hơi quay 3/4 về phía người xem), cả người
   trong khung, chân chạm cùng một đường đất ở mọi ảnh.
6. **Không vẽ** chữ, viền khung, bóng đổ trên nền, hiệu ứng kỹ năng (bông tuyết, vòng băng, tia nước):
   game tự vẽ hết.

---

## 0. Khối STYLE chung (dán vào đầu mọi prompt)

```
2D mobile game character art, cartoon style matching a cute military artillery game:
bold clean black outlines of even thickness, flat cel-shaded colours with one soft shade
tone and one highlight tone, slightly chibi proportions (big head about one third of the
body height, expressive big eyes), rounded friendly shapes, crisp vector-like edges, no
texture noise, no painterly brush strokes, no gradients on the background, no text, no
watermark, no frame border, no drop shadow on the background.
```

## Thiết kế nhân vật (giữ cố định ở mọi prompt)

```
CHARACTER: "Tide", a young cheerful sailor-girl water mage, a soldier of a cute artillery
squad, the same height and build as a teenage girl soldier (slim, energetic).
- A hood made of living water over her head: a translucent teal-blue hood (#2FB8C8 with
  lighter #8FE6F0 highlights) shaped like a curling wave, its tip curling forward over her
  forehead like a breaking wave crest, a few water droplets floating off it; her face and
  short dark navy-blue bob hair (#1E2C5A) visible under it.
- Big friendly eyes, sea-green (#2BC4A6), a confident grin, light freckles.
- Sailor outfit: a white sailor blouse (#F4FBFF) with a teal sailor collar with two white
  stripes (#1F9EB0), a small navy neckerchief knot, white and teal combat shorts over dark
  navy tights, a teal utility belt with a round silver buckle shaped like a water drop.
- On her back a rounded metal water tank (silver-teal #9FD9E0, two brass bands, a little
  glass window showing blue water inside) on two shoulder straps; a ribbed hose (teal,
  #1F9EB0) runs from the bottom of the tank over her hip to her gun.
- Teal knee pads and white-teal boots with navy soles.
- Colour scheme teal and white, small navy and brass accents. No green, no pink.
Cute, brave, readable at small size.
```

---

## 1. Ảnh thiết kế gốc (model sheet): `concept/`

Ảnh tham chiếu cho mọi ảnh sau. Tạo 4–8 bản, chọn 1.

```
[STYLE] [CHARACTER]
Character model sheet on one image: the same character three times side by side, same
scale: (1) front view, (2) side view facing right, (3) back view showing the water tank
and the hose. Neutral standing pose, no weapon in her hands. Plain white background.
Canvas 2560x1280. Same art style as the attached characters.
```

---

## 2. Ảnh toàn thân ở sảnh (lobby): `lobby/full_v1.png`

Hiện ở Sảnh, trang Nhân vật, Shop, thẻ đồng đội, màn tìm trận. Game dựng ảnh này lên bộ xương
(`tools/cut_sheet.gd`, `scenes/character/full_body.gd`) để thở / vẫy tay, nên cần **tay tách khỏi
thân** (có khe hở nền giữa tay và người) và **không cầm súng** (súng game vẽ riêng cạnh bệ).

```
[STYLE] [CHARACTER]
Full-body standing pose facing the viewer (front 3/4), like a character select screen:
one hand waving at shoulder height, the other fist on her hip, feet apart on the ground,
the water tank visible behind her shoulders, the hose hanging at her side, NO weapon in
her hands. Both arms clearly separated from the body by a gap of background. Plain flat
white background #FFFFFF, no shadow. Canvas 1024x765, the character about 80% of the
canvas height, centred. Same art style and same scale as the attached characters.
```

Đặt cạnh 4 nhân vật kia (cùng chiều cao người như trong `lineup_v1.png`).

---

## 3. Góc ngang trong trận (nhìn sang PHẢI, mỗi ảnh 1280×720)

Trong trận game vẽ Tide bằng các ảnh góc ngang, cắt và ráp bởi `tools/import_frames.gd`
(cấu hình `side_run/import.json`, chép từ Flora: `art_source/characters/flora/side_run/import.json`).
Súng vẽ riêng (mục 4), **không vẽ súng trong tay** ở các ảnh dưới. Bình nước sau lưng vẽ trong
ảnh; game tự đeo súng chéo sau lưng khi đi.

### 3a. Chạy: `side_run/frame_1.png` … `frame_8.png`, 8 frame, lặp

```
[STYLE] [CHARACTER]
Horizontal sprite sheet, 8 frames in one row, every frame 1280x720, evenly spaced, the
character at the same scale and with her feet on the same ground line in every frame,
side view facing right (3/4 towards the viewer). A running cycle that loops smoothly from
frame 8 back to frame 1: arms swinging, the water hood bouncing a little, the tank on her
back, the hose swaying. Empty hands (no weapon). Transparent background (or flat white).
```

Cắt sheet thành 8 file `frame_1.png` … `frame_8.png` (mỗi file 1280×720). Nếu model vẽ lệch giữa các
frame, tạo từng frame với ảnh tham chiếu + câu "same character, same scale, same position on the
canvas, only the pose changes".

### 3b. Đứng yên: `side_idle/idle_v1.png`

Dáng đứng trong trận (cũng là thân khi bắn, trúng đạn, ngã).

```
[STYLE] [CHARACTER]
Standing upright, side view facing right (3/4 towards the viewer), both feet on the
ground, arms relaxed at her sides, empty hands (no weapon), the tank on her back, the
hose hanging. Same scale and same ground line as the running frames. Canvas 1280x720,
transparent background (or flat white).
```

### 3c. Quỳ ngắm: `side_ready/ready_v1.png`

Dáng bắn: Tide quỳ, ôm súng giữa ngực. Game đặt súng vào hai nắm tay
(`scenes/character/poses/tide_ready.tscn`) và tự cắt lớp tay gần vẽ đè lên súng.

```
[STYLE] [CHARACTER]
Kneeling aiming pose, side view facing right (3/4 towards the viewer): one knee on the
ground, the back straight, both fists held together in front of her chest as if hugging
a big gun, but NO gun in the image, eyes focused forward to the right, the water tank on
her back, the hose curving from the tank to her fists. Flat solid green background
#00FF00, no shadow. Canvas 1024x765, the same character scale as the standing pose.
```

---

## 4. Súng nước (water gun)

### 4a. Súng ôm: `art_source/weapons/hug/water_gun_<cấp>.png`

Cấp: `iron`, `steel`, `mithril`, `dragon` (cấp `basic` tool tự đổi màu từ `iron`). Súng **nằm ngang,
nòng sang PHẢI, không có tay cầm**, cùng một dáng ở cả 4 cấp, chỉ khác màu và trang trí. Trong trận
súng dài khoảng 45 px như súng hạt của Flora (`art_source/weapons/hug/README.txt`).

```
[STYLE]
A chunky cartoon water cannon gun, horizontal, the nozzle pointing to the RIGHT, no
hands and no grips: a rounded body with a glass water chamber on top showing blue water
and bubbles, a ribbed hose socket at the back end, a pump ring around the middle, a wide
flared nozzle at the front. {TIER}. Centred on a 1024x1024 canvas, flat solid green
background #00FF00, no shadow.
```

Thay `{TIER}`:
- iron: "plain steel grey body, teal bands, a clear glass chamber";
- steel: "polished light-blue steel body with rivets, white bands, a sapphire glass chamber";
- mithril: "pale ice-blue body with silver wave engravings, a glowing aqua crystal chamber";
- dragon: "deep red body with gold bands, the nozzle shaped like a dragon head spitting a water
  orb from its mouth" (điểm bắn = miệng rồng).

### 4b. Biểu tượng súng trong túi đồ: `art_source/equipment/` (tuỳ chọn)

Dùng ảnh súng ôm ở trên (đã nhập) là được; tool trang bị tự thu nhỏ. Cần icon riêng thì tạo cùng
prompt trên, canvas vuông 512×512, súng chéo 30°.

### 4c. Đạn: `art_source/fx/projectiles/water_gun_<cấp>.png` (tuỳ chọn)

Đạn cấp nào không có ảnh thì game vẽ quả cầu nước mặc định. Chế độ "glow" (nền đen tuyền).

```
[STYLE]
A single round water orb projectile flying to the right: translucent blue water ball
with a bright white highlight on the upper left, a few tiny droplets trailing behind it
on the left, {TIER}. Centred on a 512x256 canvas, pure black background #000000.
```

`{TIER}`: iron "clear blue water"; steel "deeper sapphire water with a white foam ring";
mithril "glowing aqua water with tiny ice crystals inside"; dragon "boiling red-orange water
with golden steam".

---

## 5. Chân dung nhỏ (HUD, thẻ lượt): `portrait/portrait_v1.png`

```
[STYLE] [CHARACTER]
Head-and-shoulders bust icon, facing slightly right, the water hood and her grin clearly
readable, the top of the water tank visible behind one shoulder. Square 512x512, the head
fills 80% of the canvas, plain flat white background.
```

---

## 6. Nhập vào game

1. Bỏ ảnh vào đúng thư mục ở trên (trong `art_source/characters/tide/`, súng trong
   `art_source/weapons/hug/`).
2. Chép `art_source/characters/flora/side_run/import.json` thành
   `art_source/characters/tide/side_run/import.json`, đổi `"id": "tide"`, `"out":
   "res://assets/characters/tide/side/"`, `poses.ready.scene` thành `tide_ready.tscn`; chỉnh `height`,
   `scale`, `alignX` cho khớp ảnh mới (giải thích từng mục ở `assets/README.md`, "Thêm ảnh góc ngang
   cho nhân vật").
3. Chạy (trong thư mục battle-squad-game):
   - `$GODOT --headless --path . -s tools/import_frames.gd -- tide`
   - `$GODOT --headless --path . -s tools/import_hug_guns.gd` (thêm `water_gun` vào
     `art_source/weapons/hug/hug.json` như `seed_launcher`)
   - ảnh sảnh: thêm Tide vào `art_source/characters/lineup_parts.json` (rect / seed / holes / joints) rồi
     `$GODOT --headless --path . -s tools/cut_sheet.gd -- tide`.
4. Trong editor: mở `scenes/character/poses/tide_ready.tscn`, kéo GunSocket cho súng che hai nắm tay;
   mở `tide_carry.tscn`, đặt súng chéo sau lưng (cạnh bình nước). Ctrl+S.
5. Bỏ `"tide"` khỏi `PLACEHOLDER_CHARACTERS` / `PLACEHOLDER_SOURCE` trong `ui/art.gd`, chạy
   `bash tests/run.sh`.

## 7. Kiểm tra trước khi đưa vào game

- **Nhân vật:** mọi ảnh cùng một Tide, cùng màu, cùng cỡ; chân chạm cùng một đường đất (ảnh chạy /
  đứng), nếu không Tide sẽ giật khi chạy animation.
- **Hướng:** nhìn sang phải (ảnh sảnh nhìn về phía người xem). Game tự lật ảnh khi quay sang trái.
- **Nền:** một màu phẳng (hoặc trong suốt), không bóng đổ; không có màu nền lẫn trên người (xanh lá
  #00FF00 không được xuất hiện trên áo / súng).
- **Nội dung:** không chữ, không viền, không cầm súng trong ảnh nhân vật, không vẽ hiệu ứng kỹ năng.
