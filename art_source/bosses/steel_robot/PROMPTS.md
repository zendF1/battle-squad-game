# Rô-bốt Thép: prompt tạo ảnh boss

Dùng cho AI vẽ ảnh (GPT-image / Gemini / Midjourney / Flux…). Prompt viết bằng tiếng Anh vì các model
hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế là thiết kế riêng của game, không
lấy theo game nào khác: đừng thêm tên game / tên hãng / "in the style of <game>" vào prompt.

Hiện game vẽ Rô-bốt Thép và Drone bằng code (`match/boss/boss_art.gd`). Ảnh dưới đây thay phần đó;
cách cắt ảnh giống Phù Thuỷ Băng (`art_source/bosses/ice_witch/`, `tools/import_boss_frames.gd`).

## Cách dùng

1. **Tạo ảnh thiết kế gốc (mục 1) trước**, chọn 1 bản ưng nhất. Từ đó về sau luôn **đính kèm ảnh
   gốc làm ảnh tham chiếu** cho mọi prompt khác, để rô-bốt giữ đúng dáng, màu, vũ khí ở mọi frame.
2. Mỗi prompt = **khối STYLE** (mục 0) + **khối BOSS** + phần riêng của ảnh đó. Dán cả ba.
3. **Animation**: tạo kiểu **sprite sheet một hàng** (mọi frame trong một ảnh, cùng cỡ, cách đều).
   Model vẽ lệch giữa các frame thì tạo từng frame với ảnh tham chiếu + câu "same character, same
   scale, same position on the canvas, only the pose changes".
4. **Nền**: xanh lá đặc **#00FF00**, một màu phẳng, không bóng đổ. Rô-bốt không có màu xanh lá
   nào trên người (lõi cam, kính xanh lơ), nên tool xoá nền sạch. Dấu ✦ của AI ở góc tool tự xoá.
5. **Khung**: mỗi frame 1280×720, rô-bốt **nhìn sang PHẢI**, đứng giữa khung, cao khoảng 80% khung.
   Sheet N frame: N × 1280 ngang, 720 dọc (vd. 6 frame = 7680×720), hoặc lưới vuông nếu model không
   ra được ảnh dài: ghi rõ số hàng / cột.
6. Bỏ ảnh vào `art_source/bosses/steel_robot/<thư mục ghi ở từng mục>/`, tên `sheet_v1.png` (ảnh
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
BOSS: "Steel Robot", a giant guardian mech of an abandoned iron foundry. A stocky, heavy
bipedal mech with short thick legs and big flat feet, a barrel-shaped torso in brushed
steel blue-grey (#8F9EB3) with darker plates (#57616F) and light edges (#C7D3E6), bolts
and panel lines. Yellow-black hazard stripes on the pelvis. A round glowing orange
reactor core (#FF8C26, hot white centre) in the middle of the chest behind a ring
frame. A small dome head sunk between the shoulders with one horizontal visor slit
glowing cyan (#8CFFFF) and a short antenna with a red tip. On its back, two square
mortar pods with four short tubes each, pointing up. Front arm (towards the viewer): a
big boxy arm cannon with cooling fins and a dark muzzle glowing orange inside. Back arm:
a three-finger steel claw. Massive but cute and readable at small size, a little
battered: a few dents and scratches.
```

---

## 1. Ảnh thiết kế gốc (model sheet): `concept/`

```
[STYLE] [BOSS]
Character model sheet on one image: the same mech three times side by side, same scale:
(1) front view, (2) side view facing right, (3) back view showing the mortar pods.
Neutral standing pose, the arm cannon lowered. Canvas 2560x1280.
```

## 2. Chân dung: `portrait/`

Thẻ boss ở tab Boss, màn tìm trận. Ảnh này cũng là dáng đứng yên trong trận (game gắn xương và tự
làm chuyển động thở / lõi nhấp nháy), nên vẽ **dáng đứng thẳng, hai chân chạm đất**.

```
[STYLE] [BOSS]
Heroic boss pose for a selection card: standing firm on both feet, the arm cannon raised
diagonally forward and glowing, the claw open beside it, the reactor core blazing, the
mortar pods smoking a little, the visor glaring at the viewer. Full body, centred, square
canvas 1024x1024, leave 8% empty margin around it.
```

Ảnh nhỏ cho thanh máu:

```
[STYLE] [BOSS]
Head-and-shoulders bust icon: the dome head with the glowing visor, the shoulders, the
top of the reactor core and the arm cannon's top at the edge, facing slightly right.
Square 512x512, the mech fills 85% of the canvas.
```

---

## 3. Animation trong trận (nhìn sang phải, 1280×720 mỗi frame)

Mọi sheet thêm khối SHEET:

```
Horizontal sprite sheet, N frames in one row, every frame the same size (1280x720 each),
evenly spaced, the mech at the same scale with its feet on the same ground line and at
the same spot in every frame, only the pose changes between frames.
```

(Thay N bằng số frame của từng mục. Game tự vẽ đạn, tia laze, khói, tia lửa: **không vẽ chúng**
trong ảnh, chỉ vẽ dáng và ánh sáng trên người.)

### 3a. Mưa đạn pháo (barrage): `side_barrage/`, 6 frame, không lặp

Đạn bay lên từ hai ụ cối sau lưng.

```
[STYLE] [BOSS] [SHEET N=6]
Mortar barrage, not looping: frames 1-2 the mech crouches a little and plants its feet,
the mortar pods on its back tilt up and their tubes glow orange inside, frame 3 the pods
recoil down hard with a bright flash at every tube's mouth, frame 4 a second recoil,
frames 5-6 it stands back up, the tubes still glowing faintly. Do NOT draw the shells or
smoke, only the mech.
```

### 3b. Tia laze nghiền (laser): `side_laser/`, 6 frame, không lặp

Game vẽ 5 tia ngang toàn map; ảnh chỉ cần dáng nạp và bắn.

```
[STYLE] [BOSS] [SHEET N=6]
Laser cannon, not looping: frames 1-2 the mech raises the arm cannon straight forward to
the right and braces with the claw on the cannon, the cooling fins open and the muzzle and
the reactor core glow brighter and brighter, frame 3 a bright white-cyan flash at the
muzzle, the whole body pushed back a little by the recoil, frame 4 the same with the glow
fading, frames 5-6 the cannon lowers back, steam vents from the fins. Do NOT draw the beam.
```

### 3c. Thả drone (summon): `side_summon/`, 4 frame, không lặp

```
[STYLE] [BOSS] [SHEET N=4]
Summon signal, not looping: frame 1 the mech lifts its claw high, frame 2 the antenna and
the visor flash red, a hatch on its chest plate above the core opens, frame 3 the hatch
fully open with a red light inside, frame 4 the hatch closes, back to standing. No drones
in the image.
```

### 3d. Trúng đòn (hurt): `side_hurt/`, 2 frame

Game làm cảnh chết từ frame đầu của sheet này (nổ tung và ngã), không cần sheet chết riêng.

```
[STYLE] [BOSS] [SHEET N=2]
Hit reaction: frame 1 knocked back to the left, sparks flying from a dented plate, the
visor flickering, one arm thrown up, frame 2 recovering, the visor narrowed angrily.
```

---

## 4. Drone (lính con): `minion_drone/`

Drone bay lơ lửng, tới gần người chơi thì nổ. Nền xanh lá, nhìn sang phải. Mỗi prompt = [STYLE] + khối MINION
dưới đây + phần riêng (cỡ canvas ghi trong phần riêng thay cho 1280×720 của khối STYLE).

```
MINION: "Drone", a small flying robot of the Steel Robot: a round steel-blue body
(#7A8CA8) like a ball with a darker band around it, one big round red glowing eye on the
front (#FF4D40) with a white highlight, two short arms on top holding small spinning
rotors, two thin landing skids under it, a little hazard stripe on the band. Cute but
mischievous.
```

- `minion_drone/idle_sheet_v1.png`: `[STYLE] [MINION] Horizontal sprite sheet of 4 frames (1024x1024 each) of a hover loop: the body bobs up and down a little, the rotors blur in different positions, the eye blinks in frame 3.`
- `minion_drone/alarm_v1.png`: `[STYLE] [MINION] About to self-destruct: the eye wide and bright red, the body tinted red with warning lights, the rotors spinning fast. Canvas 1024x1024.`

---

## 5. Đạn và hiệu ứng (nền xanh lá, mỗi cái một ảnh vuông 512×512)

Đạn vẽ **nằm ngang, mũi sang PHẢI** (game tự xoay theo đường bay).

### 5a. Đạn cối: `fx/steel_shell.png`

```
[STYLE]
A single chunky cartoon mortar shell flying to the right: steel grey body with a dark
band, a rounded orange-glowing nose on the right, small fins at the back on the left, a
yellow-black hazard ring. Bold black outline. Centred on a 512x512 canvas, solid green
background #00FF00.
```

### 5b. Đạn của drone: `fx/drone_bolt.png`

```
[STYLE]
A small glowing red energy bolt flying to the right: a bright red-orange oval core with a
white centre and a short tapered tail on the left. Centred on a 512x512 canvas, solid
green background #00FF00.
```

---

## 6. Kiểm tra trước khi đưa vào game

- **Nhân vật:** mọi frame cùng một rô-bốt, cùng màu, cùng cỡ; chân chạm cùng một đường đất, nếu
  không rô-bốt sẽ giật khi chạy animation.
- **Hướng:** nhìn sang phải. Game tự lật ảnh khi quay sang trái.
- **Nền:** chỉ một màu xanh lá phẳng; không có màu xanh lá trên người rô-bốt.
- **Nội dung:** không chữ, không viền; không vẽ đạn, tia laze, khói hay icon trong ảnh nhân vật.
- **Đặt file:** đúng các thư mục ở trên, rồi báo để làm `import.json` và nối ảnh vào trận.
