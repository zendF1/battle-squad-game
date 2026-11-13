# Cua Dung Nham (boss hệ Hoả, `lava_crab`): prompt tạo ảnh boss

**Hình hiện tại đến từ ảnh của người dùng**, `concept/lava_crab_v1.png`: con cua mai đá bazan nâu đen nứt
dung nham cam vàng, mắt vàng cau có, hai càng lớn nhỏ giọt dung nham, chân có đốt; **góc 3/4 nhìn sang
phải**, đứng yên. Mọi frame trong game do `make_frames.py` làm từ ảnh này (tách phần cứng theo nét viền,
gắn xương, chân đặt bằng IK, vẽ thêm bốn chân phía sau, giọt rơi, cột dung nham, khói, vết nứt; xem
`README.txt`); không có sheet nào do AI vẽ. Cua con (lính con) cũng dùng chính ảnh này, mai đỏ nâu hơn,
dung nham sáng hơn (`minion/`). Thiết kế cũ trong file này (mai có miệng núi lửa nhỏ, chân đỏ cam, mắt
trên cuống, nhìn thẳng) đã bỏ.

Prompt dưới đây **chỉ dùng khi muốn AI vẽ lại** một sheet đẹp hơn cách dựng bằng script (vd. càng đập
xuống có phối cảnh, cua chết nguội đá vẽ tay). Ảnh AI vẽ xong nhập bằng `tools/import_boss_frames.gd`
như Phù Thuỷ Băng, thay cho sheet do script làm (bỏ animation đó khỏi `ANIMS` của script và thêm mục của
nó vào phần `import.json` mà script viết ra). Giữ đúng số frame và frame đỉnh để `side/points.json` và
phần game khớp (hoặc cập nhật cả hai).

Prompt viết bằng tiếng Anh vì model hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế
là của riêng game: không thêm tên game / tên hãng / "in the style of <game>" vào prompt.

## Cách dùng

1. **Luôn đính kèm `concept/lava_crab_v1.png` làm ảnh tham chiếu** (`--ref` của `tools/gen_image.py`).
2. Mỗi prompt = **[STYLE]** (mục 0) + **[BOSS]** (mục 0b) + phần riêng của ảnh đó. Dán nguyên văn.
3. **Hướng**: góc 3/4, mặt cua nhìn sang **PHẢI** như ảnh gốc; game tự lật khi boss quay sang trái (cua
   lật vẫn ổn: không chữ, hai càng chỉ đổi bên).
4. **Nền**: xanh dương đặc **#0000FF**, một màu phẳng (trên cua không có xanh dương; không dùng magenta:
   lẫn với ánh đỏ cam của dung nham). **Không vẽ bóng đổ dưới chân** (game tự vẽ bóng), không mặt đất.
   Giọt dung nham treo ra ngoài nền phải có viền đỏ nâu rõ, không quầng sáng loang ra nền.
5. **Khung**: sprite sheet **một hàng**, mỗi frame 1536×1024, cua giữa ô, rộng khoảng 70 % ô, đầu các
   chân gần chạm cùng một đường ngang ở mọi frame (trừ chân đang nhấc khi bò); pincer chừa bên phải
   cho càng vươn ra, fire_bombs chừa phía trên cho hai càng giơ cao.
6. **Không vẽ hiệu ứng game tự vẽ**: bom dung nham bay, vũng dung nham, sóng chấn động, bụi đất, đá
   văng, cua con, chớp trắng khi trúng đòn, khiên, ánh hồi máu, chữ, icon. Ánh sáng trên người (vết nứt,
   mắt) nằm trong viền đậm; cột dung nham phun trên mai ở frame đỉnh fire_bombs thì được vẽ.
7. Đặt file vào `art_source/bosses/lava_crab/<thư mục ở từng mục>/sheet_v2.png` (không ghi đè `_v1`).
   Dấu ✦ của AI ở góc: ghi toạ độ vào `watermark` trong `import.json`.

---

## 0. [STYLE]

```
2D mobile game boss art, cartoon style for a cute military artillery game: bold clean
dark outlines of even thickness, flat cel-shaded colours with one shade tone and one
highlight tone, chunky readable shapes, crisp vector-like edges, no texture noise, no
painterly brush strokes, no text, no watermark, no frame border, no drop shadow, no ground.
Solid flat pure blue background #0000FF. Three-quarter view, the creature facing right.
```

## 0b. [BOSS] (giữ cố định ở mọi prompt)

```
BOSS: "Lava Crab", a giant crab of black volcanic rock. A wide domed shell of dark basalt
plates (#504039, shade #3C2A28, highlight #645250) split by a network of glowing lava
cracks (orange #E8600C with a yellow core #FCCC18), a stony face on the front of the shell
with two narrow angry glowing yellow eyes under heavy rock brows. Two big rock claws on
segmented arms, the left one raised high, the right one held out to the side, each with a
curved upper pincer over a spiky lower pincer, molten orange lava inside the claws and
thick lava drops (orange with a dark red-brown rim and a yellow highlight) dripping from
the pincers. Long segmented rock legs with glowing lava rings at the joints and pointed
dark tips, the body held high above the ground. Heavy, angry and menacing but readable at
small size.
```

---

## 1. Ảnh đứng yên và chân dung: `portrait/`

- `portrait/portrait_v2.png`: `[STYLE] [BOSS] Full body, standing on all legs, both claws a little raised with the upper pincers open, the lava cracks glowing brightly. Centred on a 1024x1024 canvas.`
- `portrait/bust_v2.png`: `[STYLE] [BOSS] Close-up of the front of the shell with the angry glowing eyes and the cracked rock face, the roots of both claws at the sides. Centred on a 1024x1024 canvas, the eyes in the middle.`

## 2. Animation (một hàng, mỗi frame 1536×1024)

Số frame và frame đỉnh giữ đúng như dưới (khớp `ANIMS` trong `make_frames.py`); thân ở cùng chỗ trong
mọi ô (trừ khi bài tả nó nhổm / chồm).

- `side_idle/`, 12 frame, lặp: `[STYLE] [BOSS] Horizontal sprite sheet of 12 frames of a slow idle loop: the shell rises and sinks a little as if breathing, the lava cracks pulse brighter and dimmer, the claws sway slightly and the upper pincers open and close a little, lava drops grow at the pincer tips and fall one at a time, the eyes blink once (half shut in frame 8, shut in frame 9, half in frame 10). The legs stay planted. Frame 12 flows back into frame 1.`
- `side_walk/`, 8 frame, lặp: `[STYLE] [BOSS] Horizontal sprite sheet of 8 frames of a sideways crab scuttle loop, in place: eight legs (four each side, the far ones darker behind) step in two alternating groups, one group planted and sliding back while the other lifts and swings forward; the shell bobs twice per loop and rocks slightly; the claws bob a little behind. Frame 8 flows back into frame 1.`
- `side_fire_bombs/`, 8 frame (đỉnh frame 5): `[STYLE] [BOSS] Horizontal sprite sheet of 8 frames: frame 2 the crab crouches, claws pulled in; frames 3-4 both claws rise high and spread in a V, pincers opening, the lava cracks blazing yellow-white; frame 5 the crab pushes up and a column of molten lava globs bursts straight up out of the top of the shell; frame 6 the burst smaller; frames 7-8 the claws come down and the glow fades. No bombs in the air.`
- `side_claw_slam/`, 9 frame (đỉnh frame 5): `[STYLE] [BOSS] Horizontal sprite sheet of 9 frames: frames 2-4 the right claw lifts high up on the right side, the body leaning back; frame 5 the claw smashes down onto the ground in front to the right, the body thrown forward and low, the lava flaring; frame 6 the claw still on the ground; frames 7-9 it lifts back to rest. No dust, no rocks, no shockwave.`
- `side_pincer/`, 8 frame (đỉnh frame 6): `[STYLE] [BOSS] Horizontal sprite sheet of 8 frames: frames 2-5 the crab lunges to the right and stretches the right claw far out, the upper pincer opening wide; frame 6 the pincer snaps shut hard; frame 7 held shut; frame 8 pulling back. Nothing in the claw.`
- `side_summon/`, 7 frame (đỉnh frame 4): `[STYLE] [BOSS] Horizontal sprite sheet of 7 frames: the shell shakes left and right, the claws lift and the pincers open, the lava cracks flare brightest in frame 4, then it calms down to rest. No small crabs in the image.`
- `side_hurt/`, 2 frame: `[STYLE] [BOSS] Horizontal sprite sheet of 2 frames: frame 1 jolted back to the left, the shell tilted back, the claws flung up, the eyes squeezed half shut; frame 2 half recovered.`
- `side_death/`, 5 frame: `[STYLE] [BOSS] Horizontal sprite sheet of 5 frames: frame 1 jolted back; frames 2-5 the lava cools from glowing orange to dull grey stone, dark cracks split the shell, the eyes go dark, the legs buckle outward and the body sinks low, the claws droop onto the ground, grey smoke puffs rise from the shell. It does not fall apart (the game may break it into pieces).`

---

## 3. Cua con (lính con): `minion/`

Cua con bò tới gần người chơi rồi nổ. Hiện dùng chính ảnh Cua Dung Nham thu nhỏ, mai đỏ nâu, dung nham
sáng hơn (`make_frames.py`, `minion/import.json`). Prompt này chỉ khi muốn cua con có ảnh riêng. Mỗi
prompt = [STYLE] + khối MINION + phần riêng.

```
MINION: "Lava Crablet", a small hot lava crab, the same build as the Lava Crab: a domed
shell of red-brown rock (#A84A32, shade #7A3424) with bright yellow-orange lava cracks
(#FFD84A), two small claws with lava drops, segmented legs with glowing joint rings, two
angry glowing yellow eyes. Hot and dangerous, cute at small size.
```

- `minion/side_walk/sheet_v2.png`: `[STYLE] [MINION] Horizontal sprite sheet of 8 frames (1024x1024 each) of a fast sideways scuttle loop, in place: the legs alternate in two groups, the shell bobs. Feet on the same ground line.`
- `minion/side_prime/sheet_v2.png`: `[STYLE] [MINION] Horizontal sprite sheet of 4 frames (1024x1024 each) of a loop about to blow up: the shell swelling and shaking, the cracks blazing white-yellow, the claws raised.`

---

## 4. Đạn và hiệu ứng (nền xanh dương, mỗi cái một ảnh vuông 512×512)

Đạn vẽ **nằm ngang, mũi sang PHẢI** (game tự xoay theo đường bay).

### 4a. Bom dung nham: `fx/magma_bomb.png`

```
[STYLE]
A single round lava bomb flying to the right: a ball of dark basalt rock with bright
orange-yellow molten cracks glowing through it, a short trail of fire and small embers
behind it on the left. Bold dark outline on the rock. Centred on a 512x512 canvas, solid
blue background #0000FF.
```

### 4b. Đạn của cua con: `fx/crab_spit.png`

```
[STYLE]
A small blob of glowing orange lava flying to the right, a rounded front with a dark
red-brown rim and a yellow highlight, a few tiny droplets trailing behind on the left.
Centred on a 512x512 canvas, solid blue background #0000FF.
```

---

## 5. Kiểm tra trước khi đưa vào game

- Cùng một Cua Dung Nham ở mọi frame (mai, mặt đá, mắt vàng, vết nứt, càng, giọt dung nham, màu), cùng
  cỡ, đầu chân trên cùng một đường.
- Góc 3/4 nhìn sang PHẢI (game tự lật).
- Nền một màu xanh dương phẳng #0000FF; không bóng đổ, không mặt đất, không chữ, không viền; giọt dung
  nham treo ra nền có viền đỏ nâu rõ, không quầng sáng loang.
- Không vẽ bom bay, vũng dung nham, sóng chấn động, bụi, cua con trong ảnh boss.
- Dấu ✦ ghi vào `watermark`; đặt file `_v2` đúng thư mục rồi chạy lại import.
