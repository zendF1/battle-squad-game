# Mộc Tinh (boss hệ Mộc, `tree_spirit`): prompt tạo ảnh boss

**Hình hiện tại đến từ ảnh của người dùng**, `concept/ancient_tree_v1.png`: cây cổ thụ thân nâu xám xoắn,
khuôn mặt cau có trên thân với hai mắt xanh bạc hà sáng viền tím, tán lá xanh đậm có lá tím, nấm phát
sáng xanh / tím trên thân và cành, vài tinh thể, hai rễ khô cong vểnh hai bên, bộ rễ lớn bám đất; **nhìn
thẳng (mặt trước)**, đứng yên. Mọi frame trong game do `make_frames.py` làm từ ảnh này (tách phần, gắn
xương, uốn mềm như gỗ, vẽ thêm rễ kéo / lá rơi / vết nứt; xem `README.txt`); không có sheet nào do AI
vẽ. Thiết kế "cây có tay cành, tim nhựa hổ phách, quả vàng, hoa kem" cũ trong file này đã bỏ.

Prompt dưới đây **chỉ dùng khi muốn AI vẽ lại** một sheet đẹp hơn cách dựng bằng script (vd. tán lá
rung thật mạnh có lá bay, rễ trườn có phối cảnh, cây chết héo vẽ tay). Ảnh AI vẽ xong nhập bằng
`tools/import_boss_frames.gd` như Phù Thuỷ Băng, thay cho sheet do script làm (bỏ animation đó khỏi
`ANIMS` của script và thêm mục của nó vào phần `import.json` mà script viết ra). Giữ đúng số frame và
frame đỉnh để `side/points.json` và phần game khớp (hoặc cập nhật cả hai).

Prompt viết bằng tiếng Anh vì model hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế
là của riêng game: không thêm tên game / tên hãng / "in the style of <game>" vào prompt.

## Cách dùng

1. **Luôn đính kèm `concept/ancient_tree_v1.png` làm ảnh tham chiếu** (`--ref` của `tools/gen_image.py`).
2. Mỗi prompt = **[STYLE]** (mục 0) + **[BOSS]** (mục 0b) + phần riêng của ảnh đó. Dán nguyên văn.
3. **Mặt trước**: cây luôn nhìn thẳng ra người xem như ảnh gốc. Hành động "về phía trước" (rễ trườn ra)
   hướng sang **PHẢI** màn hình; game tự lật ảnh khi boss quay sang trái (cây gần đối xứng nên lật vẫn ổn).
4. **Nền**: xanh dương đặc **#0000FF**, một màu phẳng: trên cây có xanh lá, tím, nâu, xanh bạc hà nên
   không dùng nền xanh lá hay magenta. **Không vẽ bóng đổ dưới gốc** (game tự vẽ bóng), không vẽ mặt đất.
   Quầng sáng của nấm / tinh thể được phép loang ra nền (tool tách thành lớp sáng mềm), nhưng mảnh, nhỏ.
5. **Khung**: sprite sheet **một hàng**, mỗi frame 1024×1024, cây giữa ô, cao khoảng 72 % ô, gốc chạm
   cùng một đường ngang ở mọi frame; root_drag chừa bên phải cho rễ trườn ra.
6. **Không vẽ hiệu ứng game tự vẽ**: dây leo trồi dưới chân người chơi, gai độc bay, mưa bào tử, tia /
   luồng sinh lực, rễ kéo người chơi ở xa, nấm độc (lính con), chớp trắng khi trúng đòn, khiên, ánh hồi
   máu, chữ, icon. Ánh sáng trên người (mắt, nấm, tinh thể, tim) nằm trong viền đậm.
7. Đặt file vào `art_source/bosses/tree_spirit/<thư mục ở từng mục>/sheet_v2.png` (không ghi đè `_v1`).
   Dấu ✦ của AI ở góc: ghi toạ độ vào `watermark` trong `import.json`.

---

## 0. [STYLE]

```
2D mobile game boss art, cartoon style for a cute military artillery game: bold clean
dark navy outlines of even thickness, flat cel-shaded colours with one shade tone and one
highlight tone, chunky readable shapes, crisp vector-like edges, no texture noise, no
painterly brush strokes, no text, no watermark, no frame border, no drop shadow, no ground.
Solid flat pure blue background #0000FF. Front view, the face looking at the viewer.
```

## 0b. [BOSS] (giữ cố định ở mọi prompt)

```
BOSS: "Ancient Tree Spirit", an old living tree. A thick twisted grey-brown trunk (#665A4C,
shade #42383F, olive highlights #706A50) with dark grooves, wide at the base where big
gnarled roots spread over the ground, two thin bare roots curling up at the sides. A grumpy
face in the bark in the middle of the trunk: a heavy frowning brow, two glowing mint-green
eyes (#9AF6B4, white centre) with purple rims (#8847AC), a downturned crack of a mouth.
Thick limbs fork out under a wide round canopy of dark green leaf clumps (#36664E, light
#4F9A66) with some purple leaves (#6E4E8C). Small glowing mint-green mushrooms (#7EF3A3)
and lilac mushrooms (#9C8CD0) grow on the trunk and the limbs, a few pale lilac crystals
in the canopy and on the right limb; one glowing mint crystal leaf in the canopy's left
side. Two small leafy twigs hang off the lower limbs, one each side. Old, grumpy and
menacing but readable at small size.
```

---

## 1. Ảnh đứng yên và chân dung: `portrait/`

- `portrait/portrait_v2.png`: `[STYLE] [BOSS] Full body, standing still, the eyes and the mushrooms glowing softly. Centred on a 1024x1024 canvas.`
- `portrait/bust_v2.png`: `[STYLE] [BOSS] Close-up of the face in the bark with the fork of the limbs above it and the bottom of the canopy, the eyes and the mushrooms glowing. Centred on a 1024x1024 canvas, the face filling the lower middle.`

## 2. Animation (một hàng, mỗi frame 1024×1024)

Số frame và frame đỉnh giữ đúng như dưới (khớp `ANIMS` trong `make_frames.py`); gốc ở cùng chỗ trong
mọi ô; cây không nhấc rễ khỏi đất (trừ hai rễ khô và đầu các rễ ngoài).

- `side_idle/`, 12 frame, lặp: `[STYLE] [BOSS] Horizontal sprite sheet of 12 frames of a slow idle loop: the canopy clumps sway gently one after another, the leafy twigs stir, the bare side roots curl a little, the mushrooms pulse brighter and dimmer, the eyes dim once in frame 9. The trunk and the roots stay put. Frame 12 flows back into frame 1.`
- `side_vine_lash/`, 7 frame (đỉnh frame 4): `[STYLE] [BOSS] Horizontal sprite sheet of 7 frames: frames 2-3 the eyes flare bright mint, the bare side roots writhe upward, the leafy twigs lift; frame 4 the twigs and the canopy whip down hard, the side roots snap down, the eyes blazing; frames 5-6 settle; frame 7 rest. No vines on the ground.`
- `side_poison_thorns/`, 8 frame (đỉnh frame 5): `[STYLE] [BOSS] Horizontal sprite sheet of 8 frames: frame 2 the canopy draws in; frames 3-4 the canopy shakes hard left and right; frame 5 the canopy puffs up and bristles, the clumps flung outward, a few leaves torn off; frames 6-7 it shakes less and settles, the loose leaves drifting down; frame 8 rest. No thorns drawn.`
- `side_life_drain/`, 8 frame (đỉnh frame 4, giữ lâu): `[STYLE] [BOSS] Horizontal sprite sheet of 8 frames: the eyes and every mushroom glow brighter and brighter, a soft mint glow swells on the trunk under the mouth (its heart), the trunk swells slightly as if breathing in, the canopy lifts; strongest in frame 4, a second smaller swell in frame 6, fading to rest in frame 8. No beam, no stream of light.`
- `side_root_drag/`, 8 frame (đỉnh frame 5): `[STYLE] [BOSS] Horizontal sprite sheet of 8 frames: a thick gnarled root snakes out from under the right side of the tree along the ground to the right, longer each frame (frames 2-4), the tree leaning toward it, eyes narrowed; frame 5 the root at full reach, its tip curled up like a hook; frames 6-7 it yanks back fast, the tree leaning back left; frame 8 rest, no root.`
- `side_summon/`, 7 frame (đỉnh frame 3): `[STYLE] [BOSS] Horizontal sprite sheet of 7 frames: the mushrooms on the trunk and the limbs flare bright mint and lilac (strongest in frame 3), the roots shiver, the eyes glow; then the glow fades back to rest. No poison mushroom creatures.`
- `side_hurt/`, 2 frame: `[STYLE] [BOSS] Horizontal sprite sheet of 2 frames: frame 1 the whole tree shudders back to the left, the canopy jolted, the eyes squeezed half shut, a few leaves knocked off; frame 2 half recovered, the leaves falling lower.`
- `side_death/`, 4 frame: `[STYLE] [BOSS] Horizontal sprite sheet of 4 frames: the leaves wither from green to dry brown and orange (a little in frame 1, all brown by frame 3), leaves falling; the eyes and the mushrooms go dark; cracks open in the bark; the canopy and the limbs droop and the tree sags lower each frame. It does not fall apart (the game breaks it into pieces).`

---

## 3. Nấm độc (lính con): `minion_mushroom/`

Nấm mọc lên trên mặt đất, đứng yên, mỗi lượt phun bào tử quanh mình, bị bắn chết thì nổ ra bào tử.
Hiện nấm vẽ bằng code (giữ như vậy); prompt này chỉ khi muốn có ảnh vẽ. Nấm không có hồng / tím nên
dùng nền magenta **#FF00FF** (thay câu nền và câu "Front view" trong [STYLE]), nhìn sang phải. Mỗi prompt = [STYLE] + khối
MINION dưới đây + phần riêng.

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

## 4. Đạn và hiệu ứng (nền magenta, mỗi cái một ảnh vuông 512×512)

Đạn vẽ **nằm ngang, mũi sang PHẢI** (game tự xoay theo đường bay). Câu nền trong [STYLE] đổi thành
magenta như mục 3 (prompt dưới đã ghi nền magenta); không thêm câu "Front view".

### 4a. Gai độc: `fx/poison_thorn.png`

```
[STYLE]
A single big curved wooden thorn flying to the right, dark brown with a sharp tip on the
right, a drop of glowing yellow-green poison at the tip, two small leaves at the base on
the left. Bold black outline. Centred on a 512x512 canvas, solid magenta background
#FF00FF.
```

### 4b. Dây leo trồi lên: `fx/vine_burst.png`

Dây leo trồi lên khỏi mặt đất; vẽ **dựng đứng, ngọn hướng LÊN**, gốc phẳng (game cắm gốc xuống đất).

```
[STYLE]
Three thick thorny vines bursting straight up out of the ground, twisting around each
other, green stems with brown thorns and a few leaves, the tips curling like grabbing
hands, a flat cut base at the bottom. Bold black outline. Centred on a 512x512 canvas,
solid magenta background #FF00FF.
```

### 4c. Đám bào tử: `fx/spore_cloud.png`

```
[STYLE]
A round puffy cartoon cloud of poison spores, yellow-green with lighter puffs and small
dots inside, soft edges with a thin outline. Centred on a 512x512 canvas, solid magenta
background #FF00FF.
```

---

## 5. Kiểm tra trước khi đưa vào game

- Cùng một Mộc Tinh ở mọi frame (mặt, mắt viền tím, nấm, tinh thể, lá tím, màu), cùng cỡ, gốc trên
  cùng một đường.
- Mặt trước; rễ kéo trườn sang bên PHẢI màn hình (game tự lật).
- Nền một màu xanh dương phẳng #0000FF; không bóng đổ, không mặt đất, không chữ, không viền; quầng sáng
  mềm quanh nấm / tinh thể nhỏ gọn.
- Không vẽ dây leo, gai, bào tử, tia hút, nấm độc lính con trong ảnh boss.
- Dấu ✦ ghi vào `watermark`; đặt file `_v2` đúng thư mục rồi chạy lại import.
