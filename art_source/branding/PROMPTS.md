# Logo, icon app, nền đăng nhập và nền tải dữ liệu: prompt tạo ảnh

Ảnh "ấn tượng đầu tiên" của game: logo, icon app, nền màn **Đăng nhập** (`screens/login.tscn`) và nền
màn **Tải dữ liệu** (`screens/splash.tscn`, màn chạy đầu tiên: tải dữ liệu game rồi kiểm tra phiên đăng
nhập). Hiện hai màn này chỉ có chữ "BATTLE SQUAD" trắng trên nền xám, icon app là icon mặc định của
Godot (`icon.svg`).

Dùng cho AI vẽ ảnh (GPT-image / Midjourney / Flux / Gemini / Ideogram…). Prompt viết bằng tiếng Anh vì
các model hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế là thiết kế riêng của game:
không thêm tên game khác / tên hãng / "in the style of …" vào prompt.

## Tên game (chữ trên logo)

Tên hiển thị trong game là **BATTLE SQUAD** (màn tải dữ liệu, màn đăng nhập, lời chào trong kênh chat
"Chào mừng đến Battle Squad!"). Logo viết in hoa, đúng **11 chữ cái, hai từ**:

```
B A T T L E      S Q U A D
```

Không có tên tiếng Việt, không có khẩu hiệu, không có chữ nào khác trên logo.

**Model vẽ ảnh hay viết sai chữ** (hay gặp: `BATLLE`, `BATTEL`, `BATTLLE`, `SQAUD`, `SOUAD` (chữ Q mất
đuôi thành O), `SQUAU`, thêm chữ lạ dưới logo). Cách xử lý, theo thứ tự:

1. Prompt đã ghi chữ in hoa, đánh vần từng chữ và nói "chữ duy nhất trong ảnh là BATTLE SQUAD". Tạo
   **4–8 bản mỗi lượt**, soát **từng chữ cái** (cả đuôi chữ Q) trước khi chọn. Model mạnh về chữ
   (GPT-image, Ideogram, Flux Pro, Imagen) ra đúng nhanh hơn.
2. Bản đẹp mà sai **một chữ**: dùng **inpaint** (chọn vùng) chỉ chữ đó, prompt "the letter Q, same
   style". Đừng nhờ model "sửa chữ" trên cả ảnh: nó vẽ lại toàn bộ logo.
3. Sau ~3 lượt vẫn sai: **tách đôi**. Vẽ biểu tượng không chữ (mục 1a) và chữ riêng (mục 1c, chỉ có
   chữ thì model dễ đúng hơn), rồi ghép (người nhập ảnh ghép theo bố cục mục 1b).
4. Vẫn không ra: **dựng chữ bằng tay** trong Figma / Illustrator / Inkscape theo đúng khối WORDMARK
   (mục 0c): font chữ in hoa đậm, tròn, giấy phép mở OFL (vd. "Lilita One", "Titan One", "Luckiest
   Guy" trên Google Fonts; kiểm tra giấy phép trước khi dùng), tô vàng trên / cam dưới, viền navy dày,
   viền ngoài xanh thép, xuất PNG nền trong suốt rộng 2048 px, bỏ vào `logo/wordmark_v1.png`. Cách này
   chữ luôn đúng và sắc nét nhất.

## Danh sách ảnh cần tạo

| # | Ảnh | File nguồn (`art_source/…`) | Canvas khi vẽ | Nền | File trong game | Cỡ ship |
|---|-----|-----------------------------|---------------|-----|-----------------|---------|
| 1a | Biểu tượng (không chữ) | `branding/logo/emblem_v1.png` | 1024×1024 | magenta #FF00FF | (nguyên liệu cho 1b / 1d / 2) | không ship riêng |
| 1b | **Logo đầy đủ** | `branding/logo/logo_v1.png` | 1536×1024 (3:2) | magenta #FF00FF | `assets/branding/logo.png` | rộng 1280, cắt sát + lề 2%, nền trong suốt |
| 1c | Chữ riêng (dự phòng) | `branding/logo/wordmark_v1.png` | 1536×1024 hoặc 2048×1024 | magenta #FF00FF | (ghép vào 1b) | không ship riêng |
| 1d | Logo ngang nhỏ (tuỳ chọn) | `branding/logo/logo_horizontal_v1.png` | 2048×640 (hoặc 1536×512) | magenta #FF00FF | `assets/branding/logo_small.png` | rộng 768, nền trong suốt |
| 2 | **Icon app** | `branding/icon/app_icon_v1.png` | 1024×1024 | **đặc, kín mép** (không trong suốt) | `assets/branding/app_icon.png` | 1024×1024, không kênh alpha |
| 3 | **Nền đăng nhập** | `ui/backgrounds/login_bg.png` | 16:9, lớn nhất có thể | đặc (ảnh phong cảnh) | `assets/env/login_bg.png` | 2560×1440 |
| 4 | **Nền tải dữ liệu** | `ui/backgrounds/loading_bg.png` | 16:9, lớn nhất có thể | đặc (ảnh phong cảnh) | `assets/env/loading_bg.png` | 2560×1440 |

Bắt buộc: **1b (hoặc 1a + 1c), 2, 3, 4**. Tuỳ chọn: 1d (chưa màn nào dùng, để dành cho header / màn
giới thiệu). Hai nền đặt cạnh các nền màn hình khác (`art_source/ui/backgrounds/`, cùng quy ước tên
file = tên trong `assets/env/`).

## Cách dùng

1. **Thứ tự**: logo trước (1a → 1b), chọn bản ưng nhất; rồi icon app (2) **đính kèm biểu tượng đã
   chọn làm ảnh tham chiếu**; rồi hai nền (3, 4).
2. Mỗi prompt = **khối STYLE** (mục 0a cho logo / 0b cho icon / 0d cho nền) + **khối thiết kế cố
   định** (EMBLEM / WORDMARK / SQUAD, mục 0) + **phần riêng** của ảnh. Dán đủ.
3. **Ảnh tham chiếu nét vẽ**: đính kèm `art_source/characters/lineup_v1.png` (Rookie, Flora, Spark,
   Tanko) và `art_source/characters/tide/lobby/full_v1.png` (Tide) cho icon B và nền đăng nhập (5 nhân
   vật phải giống y như trong game). Thêm `art_source/ui/backgrounds/lobby_bg.png` để nền mới cùng
   tông với nền sảnh. Súng (tuỳ chọn): `art_source/weapons/hug/bazooka_iron.png`,
   `cannon_iron.png`, `seed_launcher_iron.png`, `shock_rifle_iron.png`, `water_gun_iron.png`.
4. **Nền cắt logo**: magenta đặc **#FF00FF**, một màu phẳng; logo không được có màu hồng / tím (sẽ bị
   xoá nhầm). Không dùng nền xanh lá (mũ lính xanh ô-liu, ngọc hệ Mộc), không dùng nền trắng (vệt
   sáng trắng trên chữ).
5. **Model không ra đúng cỡ** (vd. chỉ có 1536×1024 hay 1024×1024): giữ đúng **tỉ lệ** và **vùng
   trống theo %** ghi trong prompt; người nhập ảnh cắt về tỉ lệ đúng và phóng to. Nền 16:9 mà model
   chỉ ra 3:2 thì vẽ 3:2 rồi cắt bớt trên dưới (nên để trời và đất ở mép trên / dưới đơn giản).
6. Dấu ✦ của AI (thường ở góc dưới phải) để nguyên, người nhập ảnh xoá và vẽ lại phần bên dưới.

---

## 0. Các khối dùng chung

### 0a. Khối STYLE-LOGO (dán đầu prompt 1a, 1b, 1c, 1d)

```
2D mobile game logo art, cartoon military style matching a cute artillery game: bold clean
dark navy outlines (#141B2E) of even thickness, flat cel-shaded colours with one shade tone
and one highlight tone (light from the top-left), chunky readable shapes, crisp vector-like
edges, front view, flat with no perspective tilt, no texture noise, no painterly brush
strokes, no photorealism, no 3D render look. No outer glow, no bloom, no sparkles or stars
floating around the art, no drop shadow on the background, nothing semi-transparent: every
shape ends at a dark outline. Solid flat magenta background #FF00FF everywhere outside the
art, the four canvas corners empty magenta. No pink, no purple, no violet anywhere in the
art. No watermark, no signature, no frame border.
```

### 0b. Khối STYLE-ICON (dán đầu prompt 2, thay cho STYLE-LOGO)

```
2D mobile game app icon, cartoon military style matching a cute artillery game: bold clean
dark navy outlines (#141B2E), very thick, flat cel-shaded colours with one shade tone and one
highlight tone (light from the top-left), chunky shapes, crisp vector-like edges, no texture
noise, no painterly brush strokes, no photorealism, no 3D render look. Square 1024x1024,
full bleed: the background fills the whole square edge to edge, no transparency, no rounded
corners drawn, no border, no frame (the phone rounds the corners itself). Everything
important inside the central 80% of the square. Must stay readable at 48x48 pixels: one
strong silhouette, at most three big shapes, high contrast against the background, no thin
lines, no tiny details. No text, no letters, no numbers, no watermark, no signature.
```

### 0c. Thiết kế cố định của logo (giữ nguyên ở mọi prompt logo / icon)

Biểu tượng: khiên tròn đầu màu xanh thép, viền vàng, giữa là mũ lính ô-liu có ngôi sao vàng, sau mũ hai
quả đạn pháo bắt chéo, trên viền khiên 5 viên ngọc nhỏ = 5 hệ (Kim bạc trắng, Mộc xanh lá, Thủy xanh
dương, Hỏa đỏ cam, Thổ vàng hổ phách). Chữ: hai dòng BATTLE / SQUAD, chữ khối tròn đậm vàng-cam, viền
navy dày.

```
EMBLEM: a round-topped heraldic shield badge, front view, flat, perfectly left-right
symmetrical. The shield is steel blue (#3C6FB4, light #6FA3E0, dark #24477A) with a thick
gold rim (#FFC23D, shade #D68A1A, highlight #FFE58A). In the middle, a cute cartoon army
helmet in olive green (#6B8E3A, light #94B85A, dark #44602A) with a rounded dome, a short
brim and a big bright yellow five-point star on its front. Behind the helmet, two crossed
artillery shells forming an X, brass casings (#E0A43A) with rounded red-orange tips
(#E8542B), their tips poking out above the shield's shoulders. Along the top arc of the
gold rim, five small round gems evenly spaced, from left to right: silver-white (#E8EEF5),
leaf green (#4FB83D), water blue (#2E9BE6), fire red-orange (#F2552C), earth amber
(#E3A12E), each with a white highlight dot. No ribbon, no banner, no text on the emblem.
```

```
WORDMARK: the two words BATTLE and SQUAD stacked on two lines and centred, BATTLE on the top
line, SQUAD on the bottom line, spelled exactly B-A-T-T-L-E and S-Q-U-A-D (eleven capital
letters in total, nothing else). Chunky heavy rounded sans-serif display capitals, thick
and solid, letters close together but not touching, the two lines slightly arched upward in
the middle. Both lines have the same overall width, so the letters of SQUAD come out a bit
larger than those of BATTLE. Letter fill: flat bright gold (#FFD24A) on the upper half and
warm orange (#FF9A1F) on the lower half, split by a clean horizontal edge, a thin white
highlight stripe along the top of each letter, a very thick dark navy outline (#141B2E)
around each letter, then a second outer outline in steel blue (#3C6FB4) that joins all the
letters of a word into one solid shape, then a final thin dark navy edge around that. The
Q has a clear, bold tail at its bottom right so it never reads as an O. The only text in
the image is BATTLE SQUAD.
```

### 0d. Khối STYLE-BG (dán đầu prompt 3, 4)

Giống khối STYLE của các nền màn hình (`art_source/ui/backgrounds/PROMPTS.md`) để hai màn đầu cùng nét
với sảnh / ghép trận / kết quả; khác ở tỉ lệ **16:9** (màn này hiện cả trên iPad 4:3) và vùng an toàn.

```
2D mobile game key art background, bright cheerful cartoon style for a cute military
artillery game: clean shapes with soft dark-blue outlines on the near elements and none on
the far ones, flat cel-shaded colours with one shade and one highlight tone, gentle
atmospheric perspective (far layers lighter and bluer), sunny light, vivid but soft
saturated colours, crisp vector-like edges, no texture noise, no painterly brush strokes.
Widescreen 16:9 landscape, 2560x1440. The outer edges are decoration only: the left and
right 12% of the width and the top and bottom 12% of the height may be cut off on some
screens, so everything important sits inside the central box. No text, no letters, no
numbers, no logo, no UI, no buttons, no frame border, no watermark, no signature.
```

### 0e. Khối SQUAD (dán sau STYLE-BG cho prompt 3)

Năm nhân vật đúng như trong game (đính kèm ảnh tham chiếu ở mục "Cách dùng"). Nhân vật giữ nét viền
đen đậm của ảnh tham chiếu; phong cảnh giữ viền xanh đậm mềm của khối STYLE-BG.

```
THE SQUAD: five chibi soldier characters exactly as in the attached reference pictures,
same faces, hair, outfits and colours, slightly chibi proportions (big head about one third
of the body height, big expressive eyes), bold black outlines like the reference:
- Rookie: a brown-haired boy in an olive green cap with a yellow star, a blue jumpsuit, green
  grenades on his chest straps, a brown utility belt; carries a chunky olive bazooka.
- Flora: a girl with short black hair, a dark green bandana with a pink flower, an olive
  green combat suit with shoulder pads and knee pads; carries a green leafy seed launcher.
- Spark: a boy with spiky bright yellow hair, a purple sleeveless vest, dark purple trousers,
  wristbands; carries a blue-white electric shock rifle with tiny sparks on it.
- Tanko: a big stocky soldier with a grey steel helmet, a green armoured vest with
  grenades, a grumpy determined face; carries a heavy short cannon.
- Tide: a cheerful girl with a translucent teal hood shaped like a curling water wave, short
  dark navy hair, a white sailor blouse with a teal collar, a silver-teal water tank on her
  back with a teal hose; carries a water gun.
```

---

## 1. Logo

### 1a. Biểu tượng không chữ: `logo/emblem_v1.png`

Dùng làm ảnh tham chiếu cho icon và logo ngang, và để ghép với chữ nếu cần (bước 3 ở mục "Tên game").

```
[STYLE-LOGO] [EMBLEM]
Only the emblem, no text, no letters: centred on a square 1024x1024 canvas, filling about
80% of it, with an empty magenta margin all round.
```

### 1b. Logo đầy đủ: `logo/logo_v1.png`

Logo chính, hiện giữa phía trên màn đăng nhập và màn tải dữ liệu (cao khoảng 300–380 px trên màn
1600×900).

```
[STYLE-LOGO] [EMBLEM] [WORDMARK]
Game title logo, one compact centred shape: the emblem at the top centre, about half the
height of the whole logo, and the two-line wordmark below it, overlapping the bottom third of
the emblem (the wordmark in front of the emblem). The wordmark is wider than the emblem.
Canvas 1536x1024, the logo filling about 88% of the width, an empty magenta margin of at
least 5% on every side. The only text in the image is BATTLE SQUAD.
```

Nếu ghép từ 1a + 1c: chữ rộng khoảng 1,7 lần biểu tượng, đè lên 1/3 dưới của khiên, căn giữa.

### 1c. Chữ riêng (dự phòng): `logo/wordmark_v1.png`

```
[STYLE-LOGO] [WORDMARK]
Only the wordmark, nothing else: no emblem, no shapes behind the letters. Centred on a
1536x1024 canvas, filling about 85% of the width, an empty magenta margin all round.
```

### 1d. Logo ngang nhỏ (tuỳ chọn): `logo/logo_horizontal_v1.png`

Biểu tượng bên trái, chữ **một dòng** bên phải; dùng cho chỗ thấp (header, góc màn hình).

```
[STYLE-LOGO] [EMBLEM] [WORDMARK]
Override the wordmark layout: the words BATTLE SQUAD on ONE single line, with a clear space
between the two words. Horizontal compact logo: the emblem on the left, the one-line
wordmark to its right, vertically centred on the emblem, the emblem about as tall as the
letters plus 40%. Canvas 2048x640, the logo filling about 90% of the width, an empty
magenta margin of at least 5% on every side. The only text in the image is BATTLE SQUAD.
```

---

## 2. Icon app: `icon/app_icon_v1.png`

Icon trên màn hình điện thoại / dock máy Mac, và icon cửa sổ khi chạy trên máy tính. **Không chữ**
(ở 48 px chữ không đọc được). Nền **đặc kín mép**, không trong suốt (App Store từ chối icon có kênh
alpha), không tự vẽ góc bo (iOS / macOS tự bo). Làm **cả hai phương án**, chọn bản dễ nhận nhất khi thu
nhỏ còn 48 px.

**Phương án A: biểu tượng** (đính kèm `emblem_v1.png` đã chọn):

```
[STYLE-ICON] [EMBLEM]
App icon: the emblem's helmet with its yellow star and the two crossed shells behind it,
big in the centre, filling about 70% of the square; drop the shield and the gems (too small
at icon size). Background: a radial sunburst, bright sky blue (#5CC2F2) in the centre to a
deeper blue (#2A6FC9) at the edges, with broad soft rays in two close blue tones. The
helmet slightly tilted, cheerful and bold.
```

**Phương án B: Rookie** (đính kèm `lineup_v1.png`, nhân vật đầu tiên bên trái):

```
[STYLE-ICON]
App icon: the head and shoulders of Rookie from the attached reference (a brown-haired chibi
boy in an olive green cap with a yellow star, blue jumpsuit collar), big in the centre,
filling about 75% of the square, a confident grin, one eye winking, the chunky olive tip of
his bazooka poking up over his shoulder at the right. Same face, hair and colours as the
reference, bold black outline. Background: a radial sunburst from warm gold (#FFC94D) in
the centre to orange (#F28A1F) at the edges, with broad soft rays.
```

---

## 3. Nền đăng nhập: `ui/backgrounds/login_bg.png` → `assets/env/login_bg.png`

Ý tưởng: **lời mời vào game**. Buổi sáng sớm nắng vàng, cả đội 5 người đứng trên đồi cỏ, chào người
chơi; phía sau là cả thế giới phiêu lưu: đồi xanh, đảo đất nổi (đúng kiểu địa hình phá huỷ được trong
trận), xa tít ở chân trời là năm vùng đất của năm boss (núi tuyết, núi lửa, cây cổ thụ khổng lồ, hẻm đá
đỏ, nhà máy thép), nhỏ và mờ, **không vẽ boss**. Ở giữa để trống cho logo (trên) và nút đăng nhập
(dưới).

Bố cục (toạ độ trên canvas 2560×1440; màn 1600×900 = canvas × 0,625):

```
 x:  0    320   800                       1760  2240  2560
y:0  ┌─────┬─────────────────────────────────────┬─────┐  mép trên: trời, chỉ trang trí
 180 │     ├─────┬─────────────────────┬─────────┤     │  ← mép trên vùng an toàn (màn 19.5:9 / 21:9 cắt phần trên)
 200 │     │     │  LOGO               │         │     │
     │ bị  │ NHÓM│  trời trơn, ánh     │  NHÓM   │ bị  │
     │ cắt │ TRÁI│  bình minh nhẹ      │  PHẢI   │ cắt │
 700 │ trên│ x   ├─────────────────────┤  x      │ trên│
 860 │ 4:3 │ 333–│  NÚT ĐĂNG NHẬP      │  1715–  │ 4:3 │
     │     │ 845 │  sườn cỏ phẳng,     │  2227   │     │
     │     │     │  độ sáng vừa        │         │     │
1240 │     │     └─────────────────────┘         │     │
1260 │     ├─────────────────────────────────────┤     │  ← mép dưới vùng an toàn
1440 └─────┴─────────────────────────────────────┴─────┘  mép dưới: cỏ, chỉ trang trí
```

- **Vùng an toàn** x 320–2240, y 180–1260 (giữa 1920×1080): mọi thứ quan trọng nằm trong đó (iPad 4:3 cắt
  mỗi bên 320 px; iPhone 19.5:9 cắt trên dưới ~130 px; màn 21:9 cắt ~170 px).
- **Vùng logo** x 800–1760, y 200–700: trời trơn, sáng vừa, ánh bình minh vàng nhẹ phía sau (logo có viền
  navy dày nên nổi trên trời sáng). Không mây dày, không vật thể.
- **Vùng nút** x 800–1760, y 860–1240: nút "Chơi với tư cách khách" (520×96 trên màn 1600×900, sau này
  thêm nút Google / Apple xếp dưới) và dòng báo lỗi. Sườn cỏ phẳng, **độ sáng vừa**, ít chi tiết.
- **Hai nhóm nhân vật** đứng trong vùng an toàn, bên trái và bên phải, không lấn vào cột giữa.

```
[STYLE-BG] [SQUAD]
Heroic welcome scene at early morning golden hour. A wide grassy hilltop in the foreground,
seen from a slightly low angle; beyond it a huge open cartoon world: rolling green valleys,
chunky floating islands of earth and grass hanging in the air (like destructible battle
terrain: layered brown soil on their cut sides, a few round craters and dug tunnels), a
winding dirt road, tiny army tents and little flags far below. On the far horizon, small,
pale and hazy, five distant lands side by side: a snowy mountain peak with a thin ice spire,
a smoking volcano by the sea, an enormous ancient tree, red sandstone mesas, and a steel
factory with cranes and chimneys, hinting at the adventures ahead, with no creatures in
them. Sky: a warm golden sunrise glow low in the centre behind the horizon, fading up to a
clear bright blue, a few big soft white clouds only at the top left and top right.
The squad stands on the hilltop in two groups, full bodies, facing the viewer, confident
and friendly. Left group, between 13% and 33% of the image width: Rookie in front, waving,
his bazooka on his shoulder, and Flora just behind him with a fist raised. Right group,
between 67% and 87% of the width: Tanko in front with his cannon resting at his side, arms
crossed, Spark behind him grinning with his rifle over his shoulder, and Tide pointing
toward the horizon. Their feet on the grass at about 85% of the image height, their heads
no higher than 45% of the height, everyone the same scale.
The centre column, the middle 38% of the width, stays open and calm: above, from 14% to
48% of the height, plain bright sky with the soft sunrise glow and nothing in it (a logo
will be placed there); below, from 60% to 86% of the height, a smooth even grassy slope
with a gentle path, mid-toned and uncluttered (buttons will be placed there). Inviting,
adventurous, bright and warm, never dark.
```

Không vẽ: logo, chữ, nút, thanh tải, khung viền, boss. Nhân vật không bắn, không có vụ nổ / tia đạn
(ảnh nền phải yên, chữ và nút nằm trên).

---

## 4. Nền tải dữ liệu: `ui/backgrounds/loading_bg.png` → `assets/env/loading_bg.png`

Ý tưởng: **chiến trường đang chờ trận**. Toàn cảnh rộng lúc bình minh, nhìn từ trên cao ngang tầng mây:
hai đảo đất nổi đối mặt nhau (đảo trái cờ xanh, đảo phải cờ đỏ, giống hai phe trong trận), mặt cắt đất
có hố đạn và đường hầm, thùng tiếp tế thả dù, một vệt đường đạn chấm chấm vắt ngang trời, xa xa sau
biển mây là bóng mờ một con rô-bốt khổng lồ (gợi ý boss, chỉ là bóng, một khe mắt sáng xanh). **Không
nhân vật**: màn này hiện mỗi lần mở game nên phải yên, gọn, đọc được chữ.

Ảnh này cũng dùng làm **màn khởi động** (boot splash) của Godot / màn khởi chạy iOS (mục 6), nên phải
đẹp cả khi chưa có logo và chữ đè lên.

Bố cục (toạ độ trên canvas 2560×1440; vùng an toàn như mục 3):

```
 x:  0    320   640   800              1760  1920  2240  2560
y:0  ┌─────┬─────────────────────────────────────────┬─────┐
 180 │     ├─────────────────────────────────────────┤     │  ← mép trên vùng an toàn
 200 │     │  ĐẢO     ┌──────────────────┐    ĐẢO    │     │
     │     │  TRÁI    │  LOGO            │    PHẢI   │     │
     │     │  (xanh)  │  trời trơn, ánh  │    (đỏ)   │     │
 700 │     │          └──────────────────┘   bóng    │     │
     │     │                                rô-bốt   │     │
1000 │     │     ┌────────────────────────────┐      │     │
     │     │     │ CHỮ TRẠNG THÁI + THANH TẢI │      │     │
     │     │     │ dải tối hơn, trơn          │      │     │
1240 │     │     └────────────────────────────┘      │     │
1260 │     ├─────────────────────────────────────────┤     │  ← mép dưới vùng an toàn
1440 └─────┴─────────────────────────────────────────┴─────┘
```

- **Vùng logo** x 800–1760, y 200–700: trời trơn, mặt trời / ánh vàng nhẹ phía sau, không vật thể (vệt
  đường đạn đi **phía trên** vùng này).
- **Vùng chữ + thanh tải** x 640–1920, y 1000–1240: chữ trắng "Đang tải dữ liệu trò chơi…", thanh tiến
  độ, nút "Thử lại" khi lỗi. Dải **tối hơn và trơn** (mặt mây trong bóng râm hoặc gờ cỏ gần) để chữ
  trắng đọc được.

```
[STYLE-BG]
A wide calm panoramic battlefield at sunrise, seen from high up at the level of the clouds,
majestic and quiet, waiting for the battle to begin. In the middle distance two big chunky
floating islands of earth and grass face each other across the scene: one on the left side
with little blue flags and blue sandbag forts on top, one on the right side with little red
flags and red sandbag forts, the same size and shape, mirrored. Their cut-away sides show
layered brown soil and rocks, a few round shell craters and dug tunnels (destructible
terrain). A few small wooden supply crates drift down on white parachutes between them. One
dotted cartoon arc trail crosses the sky high above the centre, from the left island toward
the right one (the path of a shell, no shell, no explosion). Far away on the horizon at the
right, behind a sea of soft clouds, the pale hazy silhouette of a giant stocky robot, only a
soft blue-grey shape with one thin glowing cyan visor slit, mysterious and too far to show
details. Warm sunrise: the sun just above the cloud horizon in the centre, a golden-peach
glow fading to clear bright blue at the top.
Layout: the centre of the sky, from 14% to 48% of the height across the middle 38% of the
width, is calm soft glow with no objects in it (a logo will be placed there; the arc trail
passes above it). A calm, slightly darker, even band from 68% to 88% of the height across
the middle half of the width: the soft tops of clouds in light shadow, or a plain grassy
ledge in the near foreground, with no details (white text and a progress bar will be placed
there). No characters, no people, no creatures apart from the faint distant silhouette.
Peaceful, hopeful, bright.
```

Không vẽ: logo, chữ, thanh tải, phần trăm, nút, khung viền, nhân vật, vụ nổ.

---

## 5. Nhập ảnh vào game

Chưa có tool riêng cho logo / icon / hai nền này (chúng là ảnh đơn, không có khung hình hay toạ độ).
Gửi ảnh vào đúng thư mục ở bảng trên rồi nhờ người phụ trách ảnh (asset pipeline) nhập; việc cần làm:

- **Logo** (`logo_v1.png`, hoặc ghép `emblem_v1.png` + `wordmark_v1.png` theo bố cục 1b): xoá nền magenta
  lấy màu ở 4 góc, gỡ viền hồng trên mép (tách màu khỏi magenta ở điểm bán trong suốt), xoá dấu ✦, cắt
  sát + lề 2%, thu nhỏ Lanczos về **rộng 1280 px** → `assets/branding/logo.png` (nền trong suốt). Logo
  hiện rộng ~760 px trên màn 1600×900, tức ~1216 px ở cửa sổ 2560×1440, nên 1280 là đủ, không cần lớn
  hơn. Import: lọc tuyến tính, **có mipmap** (trên điện thoại nhỏ logo bị thu nhỏ), nén lossless.
- **Logo ngang** (nếu có): như trên, rộng **768 px** → `assets/branding/logo_small.png`.
- **Icon app**: xoá dấu ✦ (nằm ngoài vùng giữa 80%: vẽ lại bằng nền), bỏ kênh alpha, đúng
  **1024×1024** → `assets/branding/app_icon.png`. Kiểm tra bản thu nhỏ 48 / 64 / 128 px.
- **Hai nền**: xoá dấu ✦ và vẽ lại phần bên dưới, cắt đúng 16:9, phóng to (upscale 2×, không thêm chi
  tiết lạ) về **2560×1440** → `assets/env/login_bg.png`, `assets/env/loading_bg.png`, ảnh đặc (không
  alpha). Import như các nền khác (`lobby_bg.png.import`): lossless, **không mipmap**, lọc tuyến tính.
  2560×1440 vượt mốc 2048 px nhưng cần thiết (nền phủ cả màn ở cửa sổ 2560×1440); hai ảnh chỉ hiện ở
  màn đầu.
- Ảnh gốc giữ trong `art_source/` (thư mục export đã loại trừ `art_source/*`).

## 6. Nối vào code (đã làm 2026-10, xem `assets/README.md` mục Branding)

Hiện `screens/splash.gd` và `screens/login.gd` chỉ dựng một cột giữa (`Ui.center_column`) với nhãn chữ
"BATTLE SQUAD" cỡ 64; không có nền, không có thanh tiến độ; `project.godot` dùng `icon.svg` mặc định,
không đặt boot splash; `export_presets.cfg` chưa có icon iOS / macOS. Cần:

1. **`ui/art.gd`**: thêm `"login_bg"` và `"loading_bg"` vào `ENV` (đường dẫn
   `res://assets/env/<key>.png`; `background_path()` / `background_key()` đã dùng được, và khi chưa có
   ảnh thì tự rơi về `lobby_bg`, nên code có thể vào trước ảnh). Thêm hàm `logo()` trả
   `assets/branding/logo.png` hoặc `null` khi chưa có file.
2. **`screens/splash.gd`**: thêm `ui/backdrop.gd` phủ cả màn phía sau, `show_image("loading_bg", false)`,
   `top_shade = false` (màn này không có dòng header). Thay nhãn "BATTLE SQUAD" bằng `TextureRect`
   logo (giữ nhãn chữ làm dự phòng khi `logo()` là `null`), đặt giữa ngang, khoảng y 125–440 trên màn
   1600×900 (rộng ~600–760). Chữ trạng thái + **thanh tiến độ** (rộng ~800) + nút "Thử lại" ở khoảng
   y 640–775, chữ trắng có viền / bóng tối. Thanh tiến độ: `PlayerState.load_gamedata()` chưa báo phần
   trăm, nên dùng thanh theo bước (dữ liệu game → phiên đăng nhập → hồ sơ) hoặc thanh chạy vô định.
3. **`screens/login.gd`**: backdrop `show_image("login_bg", false)`, `top_shade = false`; logo như màn
   tải dữ liệu (cùng vị trí, chuyển màn không nhảy logo); nút + dòng lỗi ở khoảng y 540–775.
4. **`project.godot`**: `application/boot_splash/image` = `res://assets/env/loading_bg.png` (hoặc bản
   1920×1080 để khởi động nhanh hơn), chế độ co giãn **Cover** (`application/boot_splash/stretch_mode`),
   `bg_color` = màu trời trung bình của ảnh, `show_image` bật. Màn tải dữ liệu vẽ đúng ảnh đó kiểu
   cover nên từ boot splash sang màn tải dữ liệu không bị giật; logo và thanh tải mờ dần hiện lên.
   `config/icon` = `res://assets/branding/app_icon.png`.
5. **`export_presets.cfg`** (đặt trong hộp thoại Export của editor): iOS → Icons → icon 1024×1024 =
   `app_icon.png` (các cỡ khác tự sinh); iOS → Storyboard (màn khởi chạy) dùng ảnh boot splash, kiểu
   co giãn tương đương cover (aspect fill), màu nền như `bg_color`; macOS → `application/icon` =
   `app_icon.png`.

## 7. Kiểm tra trước khi đưa vào game

- **Tên file / thư mục** đúng như bảng (`branding/logo/…`, `branding/icon/…`,
  `ui/backgrounds/login_bg.png`, `loading_bg.png`).
- **Chữ logo**: đúng `BATTLE SQUAD`, 11 chữ, soát từng chữ (T-T, L-E, Q có đuôi, U-A-D); không có
  chữ nào khác trong ảnh (kể cả chữ lạ trên khiên / dưới logo).
- **Logo**: nền magenta phẳng, 4 góc trống, không hồng / tím trên hình, không quầng sáng / lấp lánh
  rời / bóng đổ ra nền; mọi hình kết thúc bằng viền navy; đối xứng trái phải; 5 viên ngọc đủ 5 màu.
- **Icon**: không chữ; nền kín mép, không trong suốt, không tự bo góc; nhận ra ngay khi thu còn 48 px;
  phần quan trọng trong vùng giữa 80%.
- **Hai nền**: 16:9; không chữ, logo, nút, thanh tải, khung viền; vùng logo (giữa trên) là trời trơn;
  vùng nút / thanh tải (giữa dưới) trơn, độ sáng vừa, chữ trắng đọc được; mọi thứ quan trọng trong
  vùng an toàn (giữa 75% ngang, 75% dọc); sáng sủa, cùng tông với nền sảnh `lobby_bg.png`.
- **Nền đăng nhập**: đủ 5 nhân vật, giống ảnh tham chiếu (mặt, tóc, áo, màu), cùng cỡ, chân cùng mặt
  đất, không lấn vào cột giữa; không boss, chỉ có các vùng đất xa.
- **Nền tải dữ liệu**: không nhân vật; hai đảo đối xứng; bóng rô-bốt ở xa bên phải, mờ, không lấn vào
  vùng logo; đẹp cả khi không có gì đè lên (dùng làm boot splash).
- Dấu ✦ của AI: để người nhập ảnh xoá; báo nếu nó nằm đè lên nhân vật hay chữ logo.
