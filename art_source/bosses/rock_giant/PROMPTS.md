# Khổng Lồ Đá (boss hệ Thổ, `rock_giant`): prompt tạo ảnh boss

**Hình hiện tại đến từ ảnh của người dùng**, `concept/ram_golem_v1.png`: người khổng lồ đá nâu mặc
giáp đá cổ viền xám, mũ giáp che mặt với mắt vàng sáng, cặp sừng cừu vàng xoắn lớn, viên ngọc hổ phách
giữa ngực, đai và vai khắc hoa văn, nắm đấm to; **nhìn thẳng (mặt trước)**, đứng yên. Mọi frame trong
game do `make_frames.py` cắt ảnh này thành từng phần rồi gắn xương mà dựng (xem `README.txt`); không có
sheet nào do AI vẽ. Thiết kế "khổng lồ ghép tảng đá sa thạch" cũ trong file này đã bỏ.

Prompt dưới đây **chỉ dùng khi muốn AI vẽ lại** một sheet đẹp hơn cách dựng bằng phần (vd. chân co thật
khi dậm, tay vung ra sau đầu có phối cảnh, chết vỡ thành đá vẽ tay). Ảnh AI vẽ xong nhập bằng
`tools/import_boss_frames.gd` như Phù Thuỷ Băng, thay cho sheet do script làm (bỏ animation đó khỏi
`ANIMS` của script và thêm mục của nó vào phần `import.json` mà script viết ra).

Prompt viết bằng tiếng Anh vì model hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế
là của riêng game: không thêm tên game / tên hãng / "in the style of <game>" vào prompt.

## Cách dùng

1. **Luôn đính kèm `concept/ram_golem_v1.png` làm ảnh tham chiếu** (`--ref` của `tools/gen_image.py`).
2. Mỗi prompt = **[STYLE]** (mục 0) + **[BOSS]** (mục 0b) + phần riêng của ảnh đó. Dán nguyên văn.
3. **Mặt trước**: khổng lồ luôn nhìn thẳng ra người xem như ảnh gốc. Hành động "về phía trước" (ném,
   đẩy) hướng sang **PHẢI** màn hình; game tự lật ảnh khi boss quay sang trái.
4. **Nền**: xanh lá đặc **#00FF00**, một màu phẳng (khổng lồ không có màu xanh lá nào), **không vẽ bóng
   đổ dưới chân** (game tự vẽ bóng), không vẽ mặt đất.
5. **Khung**: sprite sheet **một hàng**, mỗi frame 1024×1024, khổng lồ giữa ô, cao khoảng 70 % ô, chừa
   chỗ trên đầu cho tay giơ lên; chân chạm cùng một đường ngang ở mọi frame.
6. **Không vẽ hiệu ứng game tự vẽ**: đá bay, đá lăn, gai đá, trụ đá, sóng chấn động, bụi lớn, nứt
   đất, chớp trắng khi trúng đòn, khiên, giáp đá của trụ, ánh hồi máu, chữ, icon. Ánh sáng (mắt, ngọc,
   hoa văn, vết nứt) nằm trong viền đen.
7. Đặt file vào `art_source/bosses/rock_giant/<thư mục ở từng mục>/sheet_v2.png` (không ghi đè `_v1`).
   Dấu ✦ của AI ở góc: ghi toạ độ vào `watermark` trong `import.json`.

---

## 0. [STYLE]

```
2D mobile game boss art, cartoon style for a cute military artillery game: bold clean
dark navy outlines of even thickness, flat cel-shaded colours with one shade tone and one
highlight tone, chunky heroic proportions, crisp vector-like edges, no texture noise, no
painterly brush strokes, no text, no watermark, no frame border, no drop shadow, no ground.
Solid flat green background #00FF00. Front view, the character facing the viewer.
```

## 0b. [BOSS] (giữ cố định ở mọi prompt)

```
BOSS: "Rock Giant", an ancient stone guardian. A huge brown stone body (#5B4939, shade
#40302A) in ancient stone armour with grey trims (#918A82): wide shoulder pads, thick
bracers, a carved belt and a short plated skirt, armoured boots. A closed stone helmet hides
the face, only two glowing yellow eyes (#FFE96D) show through the visor. Two huge curled
golden ram horns (#F5D460 with tan shade #C0944F, dark segment lines) on the helmet's sides.
An amber gem (#FFC23D, white inner light) set in the middle of the chest in a grey frame.
Thin light carved meander patterns on the chest bands and the belt. Very big stone fists with
lighter knuckles. Standing wide and still, heavy and calm. No moss, no green, no blue.
```

---

## 1. Ảnh đứng yên và chân dung: `portrait/`

- `portrait/portrait_v2.png`: `[STYLE] [BOSS] Full body, standing still, arms hanging at its sides, the gem glowing softly. Centred on a 1024x1024 canvas.`
- `portrait/bust_v2.png`: `[STYLE] [BOSS] Close-up of the helmet with both golden ram horns and the top of the shoulder pads, eyes glowing. Centred on a 1024x1024 canvas.`

## 2. Animation (một hàng, mỗi frame 1024×1024)

Số frame giữ đúng như dưới (khớp `ANIMS` trong `make_frames.py`); chân ở cùng chỗ trong mọi ô.

- `side_idle/`, 10 frame, lặp: `[STYLE] [BOSS] Horizontal sprite sheet of 10 frames of a slow breathing idle loop: the chest rises a little and falls, the shoulders and arms follow, the gem glows brighter then dimmer, the eyes blink dim once in frame 7. Feet never move. Frame 10 flows back into frame 1.`
- `side_throw/`, 8 frame (đỉnh frame 5): `[STYLE] [BOSS] Horizontal sprite sheet of 8 frames: frame 1 standing; frames 2-4 the right arm (screen right) lifts a rough boulder out to the side and swings it back over the helmet, the body leaning away; frame 5 the arm whips forward and up to the right, the hand empty, the body leaning into the throw; frames 6-7 follow-through; frame 8 standing. The boulder only in frames 2-4.`
- `side_roll/`, 7 frame (đỉnh frame 4): `[STYLE] [BOSS] Horizontal sprite sheet of 7 frames: the giant bends forward, both fists together low in front of the belt, then shoves both arms forward and to the right as if pushing a rolling boulder (no boulder drawn), then straightens up.`
- `side_stomp/`, 9 frame (đỉnh frame 5): `[STYLE] [BOSS] Horizontal sprite sheet of 9 frames: the giant shifts its weight left, lifts its right knee high (arms out for balance), stomps the right foot down hard in frame 5 (crouched, heavy), its body shakes left and right in frames 6-8, standing in frame 9. No dust, no cracks.`
- `side_spikes/`, 7 frame (đỉnh frame 4): `[STYLE] [BOSS] Horizontal sprite sheet of 7 frames: both fists rise above the shoulders, then the giant crouches and punches both fists into the ground in frame 4; the carved patterns on its chest and belt glow bright gold from frame 2, strongest in frames 4-5, fading in 6-7. No spikes drawn.`
- `side_summon/`, 6 frame (đỉnh frame 3): `[STYLE] [BOSS] Horizontal sprite sheet of 6 frames: the giant raises both arms up and out beside its horns, the chest gem flares with a bright amber-white light in frames 3-4, then lowers its arms. No pillars drawn.`
- `side_hurt/`, 2 frame: `[STYLE] [BOSS] Horizontal sprite sheet of 2 frames: frame 1 jolted back, head thrown back, arms flung out, eyes dim; frame 2 half recovered.`
- `side_death/`, 3 frame: `[STYLE] [BOSS] Horizontal sprite sheet of 3 frames: glowing amber cracks spread over the armour from the gem (few in frame 1, many in frame 3), the giant sags lower each frame, the gem and the eyes fade out. It does not fall apart yet (the game breaks it into pieces).`

---

## 3. Trụ đá (lính con): `minion_totem/`

```
MINION: "Stone Totem", a short chunky stone pillar of the Rock Giant: three stacked brown
stone blocks with grey trims, the top block carved with a grumpy face with two glowing
amber eyes, a glowing amber rune on the middle block (#FFC23D), a small amber crystal on the
top, a flat base on the ground. No moss, no green. Cute and stubborn.
```

- `minion_totem/idle_sheet_v1.png`: `[STYLE] [MINION] Horizontal sprite sheet of 4 frames (1024x1024 each) of an idle loop: the totem stays still, only the eyes, the rune and the crystal glow brighter in frames 2-3 and dimmer in frames 1 and 4. Same ground line in every frame.`
- `minion_totem/shoot_sheet_v1.png`: `[STYLE] [MINION] Horizontal sprite sheet of 3 frames (1024x1024 each): frame 1 the top block leans back, frame 2 it nods forward hard to the right with its mouth open, frame 3 upright. No projectile.`

## 4. Đạn (mỗi cái một ảnh 512×512; đạn nằm ngang, mũi sang PHẢI; gai dựng đứng)

- `fx/boulder.png`: `[STYLE] A single round lumpy brown stone boulder flying to the right with one crack and a few chips, a short dust trail on the left. Centred on a 512x512 canvas, solid green background #00FF00.`
- `fx/giant_boulder.png`: `[STYLE] A huge round brown stone boulder with glowing amber cracks, chunks missing, a thick dust trail on the left. Centred on a 512x512 canvas, solid green background #00FF00.`
- `fx/stone_spike.png`: `[STYLE] A cluster of three sharp brown stone spikes pointing straight up, the middle one tallest, amber crystal tips, a flat broken base. Centred on a 512x512 canvas, solid green background #00FF00.`
- `fx/pebble.png`: `[STYLE] A small sharp stone pebble flying to the right with a tiny glowing amber chip and a short dust trail on the left. Centred on a 512x512 canvas, solid green background #00FF00.`

---

## 5. Kiểm tra trước khi đưa vào game

- Cùng một khổng lồ ở mọi frame (sừng, mũ, ngọc, hoa văn, màu), cùng cỡ, chân trên cùng một đường.
- Mặt trước; hành động hướng về bên PHẢI màn hình (game tự lật).
- Nền một màu xanh lá phẳng; không bóng đổ, không mặt đất, không chữ, không viền.
- Không vẽ đá bay / đá lăn / gai / trụ / bụi / nứt đất (trừ tảng đá cầm trên tay ở throw frame 2-4).
- Dấu ✦ ghi vào `watermark`; đặt file `_v2` đúng thư mục rồi chạy lại import.
