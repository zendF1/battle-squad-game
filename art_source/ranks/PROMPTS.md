# Cấp bậc quân hàm: prompt khung (khung thẻ) và huy hiệu

Dùng cho AI vẽ ảnh (GPT-image / Midjourney / Flux / Gemini…). Prompt viết bằng tiếng Anh vì các model
hiểu tiếng Anh tốt nhất; phần giải thích bằng tiếng Việt. Thiết kế là thiết kế riêng của game
(quân đội giả tưởng, hoạt hình): không thêm tên game / tên hãng / "in the style of …", không chép
nguyên quốc huy, cờ hay quân hàm thật của nước nào.

Mỗi cấp có **2 ảnh**:

- **Khung** (`frames/frame_<grade>.png`): viền quanh thẻ người chơi ở ô đội (sảnh) và thẻ VS / Tìm
  trận. Giữa khung là **ô trống** (lỗ cửa sổ) để game đặt thẻ vào.
- **Huy hiệu** (`badges/badge_<grade>.png`): biểu tượng nhỏ cạnh tên người chơi trong trận (24 px),
  màn kết quả (40–92 px) và trên đỉnh khung.

Tổng: **18 khung + 18 huy hiệu = 36 ảnh**.

## Cách dùng

1. **Mỗi nhóm làm ảnh "mẫu" trước** (mục 3: sheet ý tưởng, tuỳ chọn): một ảnh có đủ các khung của
   nhóm đứng cạnh nhau, chỉ để chốt kiểu dáng / màu cho đồng đều. Bỏ vào `concept/`, tool **không**
   nhập ảnh này (mỗi khung trong sheet chỉ rộng ~300 px, quá nhỏ cho game).
2. **Vẽ từng khung riêng ở độ phân giải đầy đủ**, theo thứ tự trong nhóm: khung đầu tiên của nhóm
   trước, chọn bản ưng nhất, rồi **đính kèm nó (và ảnh sheet mẫu) làm ảnh tham chiếu** khi vẽ các khung
   sau của nhóm với câu "same frame design, same proportions and position, only change: …". Cách này
   giữ đồng bộ tốt như sheet mà vẫn đủ nét. (Model nào ra được sheet mà mỗi ô ≥ 768 px ngang thì vẽ
   sheet cũng được: khai báo trong `ranks.json` `"sheets"`, xem mục 5.)
3. Mỗi prompt = **khối STYLE** (mục 0) + **khối bố cục** (FRAME hoặc BADGE) + **khối nhóm** (mục 1) +
   **phần riêng của cấp đó**. Dán đủ cả bốn.
4. **Nền**: hồng tím đặc **#FF00FF** (magenta), một màu phẳng, kể cả **bên trong ô cửa sổ** của khung.
   Không dùng màu hồng / tím / tím than trên khung hay huy hiệu (tool sẽ xoá nhầm). Không dùng nền
   xanh lá (lẫn với vải ô-liu và ngọc lục bảo), không dùng nền trắng (lẫn với bạc / tia sáng).
5. **Khung (canvas)**: khung **1024×1280** (dọc, tỉ lệ 4:5). Model chỉ ra được 1024×1536 thì vẫn
   vẽ khung tỉ lệ 4:5 ở giữa, phần thừa trên dưới để nền: tool tự đo ô cửa sổ và căn lại. Huy hiệu:
   **1024×1024 hoặc 512×512** vuông.
6. Ảnh xong bỏ vào `art_source/ranks/frames/` và `art_source/ranks/badges/` đúng tên file, rồi chạy
   lệnh ở mục 5.

## Bố cục khung (quan trọng: mọi khung giống nhau)

Toạ độ trên canvas 1024×1280:

```
      0                     1024
  0   ┌──────────────────────┐   lề trên 154 px: vương miện / tia sáng / cánh (tuỳ nhóm)
      │        ( ghế )       │   GHẾ HUY HIỆU: mặt tròn trơn tâm (512, 154), đường kính ~154 px
154   │  ┌────────────────┐  │   ← mép trên ô cửa sổ
      │  │                │  │
384   │  │   Ô CỬA SỔ     │  │   ┐ đoạn thanh bên TRƠN (y 384–550): game kéo giãn đoạn này
550   │  │  magenta phẳng │  │   ┘
      │  │  778 × 972 px  │  │   ← giữa cạnh bên (y 550–730): được gắn đá / đinh
730   │  │                │  │   ┐ đoạn thanh bên TRƠN (y 730–896)
896   │  │                │  │   ┘
1126  │  └────────────────┘  │   ← mép dưới ô cửa sổ; HUY HIỆU ĐÁY ở giữa (x 410–614)
      │     [huy hiệu đáy]   │   lề dưới 154 px: nguyệt quế / cờ / tua (tuỳ nhóm)
1280  └──────────────────────┘
       lề trái/phải 123 px: cánh, cuộn hoa văn (tuỳ nhóm)
```

- **Ô cửa sổ**: x 123–901, y 154–1126 (cách mỗi mép 12%), góc bo tròn nhẹ (bán kính ~45 px), **bên
  trong là magenta phẳng**: không vẽ chân dung, bóng, ánh sáng hay hoa văn trong đó. Mép trong của
  viền khung nằm đúng trên đường này.
- **Ghế huy hiệu** (giữa cạnh trên): một **mặt tròn trơn bằng kim loại của nhóm, không có hình gì**;
  game vẽ huy hiệu lên đó. Một nửa ghế nằm đè xuống trong ô cửa sổ, là chỗ duy nhất được đè vào ô
  (cùng với huy hiệu đáy chạm nhẹ mép dưới).
- **Hai đoạn thanh bên trơn** (y 384–550 và y 730–896, hai cạnh trái phải): chỉ có thanh viền trơn,
  mặt cắt giống hệt nhau từ trên xuống. Không cánh, không lá, không đinh, không chữ trong đoạn này: thẻ
  VS cao hơn tỉ lệ 4:5 nên game kéo giãn đúng hai đoạn này (tool đo và cảnh báo nếu có hoa văn).
- **Huy hiệu đáy** (giữa cạnh dưới, rộng tối đa x 410–614): một tấm nhỏ mang **số vạch / số sao** của
  cấp (để khung tự phân biệt được các cấp trong nhóm, kể cả khi không có huy hiệu trên ghế).
- **Đối xứng trái phải hoàn toàn.** Mọi thứ nằm trong canvas, cách mép canvas ≥ 2% (4 góc canvas luôn
  là nền magenta: tool lấy màu nền ở đó).
- Cấp càng cao, viền càng dày (5% → 10% chiều ngang), hoa văn càng lan ra lề, bóng dáng càng to.

---

## 0. Khối STYLE chung (dán vào đầu mọi prompt)

```
2D mobile game UI ornament, cartoon military-fantasy style matching a cute artillery game:
bold clean dark outlines (#141220) of even thickness, flat cel-shaded colours with one
soft shade tone and one highlight tone (light from the top-left), crisp vector-like edges,
chunky readable shapes, no texture noise, no painterly brush strokes, no photorealism,
no soft glow or bloom spilling onto the background (light rays, sparkles and shine are
drawn as solid flat shapes with an outline), no text, no letters, no numbers, no
watermark, no drop shadow on the background. Perfectly left-right symmetrical. Solid flat
magenta background #FF00FF everywhere outside the art. No pink, no purple, no violet
anywhere in the art. Original design: no real country's flag, coat of arms or rank
insignia.
```

## Khối FRAME (dán sau STYLE cho mọi khung)

```
FRAME LAYOUT: an ornamental portrait card frame, front view, flat (no perspective), on a
1024x1280 canvas. The frame surrounds an EMPTY rectangular window with slightly rounded
corners: the window spans x 123 to 901 and y 154 to 1126 (12% in from every canvas edge,
4:5 proportions), and the window is filled with the same flat magenta #FF00FF as the
background: nothing inside the window, no portrait, no card, no glass, no shadow, no
light. The frame's inner edge sits exactly on the window's edge. At the top centre, sitting
on the window's top edge (centre at x 512, y 154), a plain round medallion about 154 px
across in the frame's metal, completely blank (no symbol on it). At the bottom centre, on
the bottom band, a small emblem plate no wider than 200 px carrying the rank insignia.
On the left and right bands, the stretches from y 384 to 550 and from y 730 to 896 are
plain moulded band only, identical from top to bottom, with nothing attached. Everything
stays inside the canvas with an empty magenta margin of at least 2% along the canvas
edges; the four canvas corners are empty magenta.
```

## Khối BADGE (dán sau STYLE cho mọi huy hiệu)

```
BADGE LAYOUT: a single compact rank emblem, front view, flat, centred on a square
1024x1024 canvas, filling about 85% of it, with an empty magenta margin all round.
Designed to stay readable when shrunk to 24x24 pixels: one strong silhouette, few big
shapes, very thick dark outline around the whole emblem, high contrast between the
insignia and its plate, insignia marks large and chunky with clear gaps between them,
no thin lines, no tiny details, no small text-like engraving.
```

---

## 1. Thang thiết kế theo nhóm (khối nhóm: dán sau khối bố cục)

Nguyên tắc: **vật liệu leo thang** (vải ô-liu sờn + thép xỉn → thép sáng + men xanh → bạc bóng +
ngọc bích → vàng + hồng ngọc → vàng đỏ rực + cánh, nguyệt quế, cờ, tia sáng, vương miện), **độ dày
và mật độ hoa văn leo thang**, **bóng dáng lan rộng dần ra lề canvas**. Trong một nhóm, **số vạch /
số sao** ở huy hiệu đáy (và trên huy hiệu) phân biệt các cấp, cộng một chi tiết nhỏ thêm vào mỗi bậc.

| Nhóm | Cấp | Vật liệu, màu | Hoa văn | Dấu hiệu |
|---|---|---|---|---|
| Hạ sĩ quan, binh sĩ | 1–5 | vải bạt ô-liu sờn #5B6B3A / #8A8A5C, thép xỉn #8C939A, vạch vàng mù tạt #E3B23C | viền mỏng 5%, đinh tán, góc thép, lên dần đồng thau | 1–5 vạch chữ V |
| Học viên | 6 | thép sáng #A9B4BF, men xanh thép #3E6B9E, thanh vàng #F2C14E | viền 6%, nhành lá nhỏ hai bên ghế | 1 thanh ngang |
| Sĩ quan cấp úy | 7–10 | bạc bóng #D8DEE6, men xanh hải quân #24427A, ngọc bích #3F7FE0, sao vàng #FFD45C | viền đôi 7%, một sọc men chạy quanh, góc hoa văn cuộn | 1 sọc, 1–4 sao |
| Sĩ quan cấp tá | 11–14 | vàng #F5C242 / #C8901E, men xanh hoàng gia #1F4FA8, hồng ngọc #D62839 | viền 8–9%, hai sọc men, góc cuộn vàng lớn, nguyệt quế ở góc dưới | 2 sọc, 1–4 sao |
| Tướng (top 10 mùa) | 15–18 | men đỏ #B3141F, vàng rực #FFD24A, ánh vàng trắng #FFF4C2, kim cương trắng, hồng ngọc | viền 10%, vương miện sau ghế, cánh vàng, nguyệt quế, cờ đỏ tua vàng, tia sáng khối | 1–4 sao lớn |

Đại tướng là khung lộng lẫy nhất: vương miện cao nhất, cánh hai lớp, cờ hai bên, tia sáng toả rộng.

### Khối GROUP ENLISTED (cấp 1–5)

```
GROUP ENLISTED: humble field gear. The band is a narrow strip (about 5% of the canvas
width) of worn olive-drab canvas (#5B6B3A, lighter #8A8A5C) with visible stitched edges,
held by dull gunmetal steel rivets (#8C939A). The top medallion is dull brushed steel. The
bottom emblem is a small olive cloth tab with mustard-yellow chevrons (#E3B23C) pointing
up, thick and tightly stacked. Simple, practical, no gems, no gold, almost nothing reaches
into the outer margin.
```

### Khối GROUP CADET (cấp 6)

```
GROUP CADET: an academy frame, a step up from field gear. The band (about 6% of the canvas
width) is clean bright brushed steel (#A9B4BF, highlight #E6ECF2) with a thin steel-blue
enamel inlay line (#3E6B9E) running all round it; small round steel corner caps with a blue
enamel dot. The top medallion is polished steel with a small pair of steel laurel sprigs
on either side of it. The bottom emblem is a steel tab with one wide horizontal gold bar
(#F2C14E). Neat and promising, still modest.
```

### Khối GROUP COMPANY (cấp 7–10)

```
GROUP COMPANY OFFICER: polished silver dress frame. The band (about 7% of the canvas
width) is a double silver moulding (#D8DEE6, bright highlight #FFFFFF, shade #8F99A8) with
ONE navy-blue enamel stripe (#24427A) running all the way round between the mouldings.
Each corner carries a silver scrollwork corner piece set with a faceted sapphire
(#3F7FE0). The top medallion is polished silver with a fine rope-twist rim. The bottom
emblem is a navy enamel plate edged in silver with a row of chunky five-point gold stars
(#FFD45C). Elegant, clearly richer than the cadet frame.
```

### Khối GROUP FIELD (cấp 11–14)

```
GROUP FIELD OFFICER: ornate gold frame. The band (about 8-9% of the canvas width) is
gleaming gold (#F5C242, deep gold shade #C8901E, highlight #FFF0B0) with TWO parallel
royal-blue enamel stripes (#1F4FA8) running all the way round. The corners are large
curling gold scrollwork pieces, each set with an oval ruby (#D62839), reaching well into
the outer margin. Gold laurel sprigs wrap the two lower corners (staying below y 900).
The top medallion is gold with a beaded rim. The bottom emblem is a royal-blue enamel
plate edged in gold with two short gold bars under a row of chunky gold stars. Rich and
imposing.
```

### Khối GROUP GENERAL (cấp 15–18)

```
GROUP GENERAL: a radiant ceremonial frame for the season's top ten. The band (about 10% of
the canvas width) is deep red enamel (#B3141F, shade #7A0A12) between two thick bright
gold mouldings (#FFD24A, highlight #FFF4C2, shade #C8901E), studded with small rubies. A
gold crown-like crest with pointed tips rises behind the top medallion; the medallion is
bright gold with a ring of tiny white diamonds. Golden feathered wings grow from the two
upper corners, spreading up and outwards (staying above y 384). A gold laurel wreath wraps
the two lower corners; crimson banners with gold fringe hang below the lower corners
(staying below y 896). The bottom emblem is a red enamel plate edged in gold with a row of
large bold gold stars. Majestic, triumphant, the grandest frames of the game.
```

---

## 2. Khung (18 ảnh): `art_source/ranks/frames/`

Mọi khung: canvas 1024×1280, nền magenta **#FF00FF** (kể cả trong ô cửa sổ). Prompt =
`[STYLE] [FRAME] [GROUP …]` + đoạn riêng dưới đây. **Không vẽ**: chữ, số, tên cấp, chân dung hay
thẻ trong ô cửa sổ, hình trên mặt tròn ghế huy hiệu (game vẽ huy hiệu lên đó), hiệu ứng lấp lánh rời
rạc bay quanh (game tự thêm hiệu ứng nếu cần), bất cứ thứ gì trên hai đoạn thanh bên trơn.

### 2.1 Binh nhì: `frame_binh_nhi.png`

```
[STYLE] [FRAME] [GROUP ENLISTED]
Rank 1 of the ladder, the plainest frame of all: the narrow worn canvas band only, one
steel rivet in each corner, the plain steel medallion. Bottom emblem: ONE chevron.
```

### 2.2 Binh nhất: `frame_binh_nhat.png`

Đính kèm `frame_binh_nhi.png` làm tham chiếu.

```
[STYLE] [FRAME] [GROUP ENLISTED]
Same frame design as the reference, same proportions and position. Only change: a second
darker stitched line runs along the inside of the band, two rivets in each corner.
Bottom emblem: TWO chevrons.
```

### 2.3 Hạ sĩ: `frame_ha_si.png`

```
[STYLE] [FRAME] [GROUP ENLISTED]
Same frame design as the reference, same proportions and position. Only change: small
L-shaped gunmetal steel brackets clamp the four corners. Bottom emblem: THREE chevrons.
```

### 2.4 Trung sĩ: `frame_trung_si.png`

```
[STYLE] [FRAME] [GROUP ENLISTED]
Same frame design as the reference, same proportions and position. Only change: the corner
brackets are larger and edged in dull brass, plus one brass rivet at the middle of each
side band (between y 560 and y 720). Bottom emblem: FOUR chevrons.
```

### 2.5 Thượng sĩ: `frame_thuong_si.png`

```
[STYLE] [FRAME] [GROUP ENLISTED]
Same frame design as the reference, same proportions and position, the most decorated
enlisted frame: the band slightly wider, brass corner plates, a small pair of olive leaf
sprigs on either side of the medallion, the medallion with a thin brass rim. Bottom
emblem: FIVE chevrons.
```

### 2.6 Học viên: `frame_hoc_vien.png`

```
[STYLE] [FRAME] [GROUP CADET]
Rank 6, the academy cadet: the bright steel band with the blue inlay line, the steel corner
caps, the small laurel sprigs beside the medallion. Bottom emblem: ONE wide gold bar.
```

### 2.7 Thiếu úy: `frame_thieu_uy.png`

```
[STYLE] [FRAME] [GROUP COMPANY]
Rank 7, the first officer: the silver double band with the navy stripe, small silver
scroll corners with one small sapphire each. Bottom emblem: ONE gold star.
```

### 2.8 Trung úy: `frame_trung_uy.png`

Đính kèm `frame_thieu_uy.png`.

```
[STYLE] [FRAME] [GROUP COMPANY]
Same frame design as the reference, same proportions and position. Only change: a sapphire
set in a small silver diamond mount at the middle of each side band (between y 560 and
y 720). Bottom emblem: TWO gold stars.
```

### 2.9 Thượng úy: `frame_thuong_uy.png`

```
[STYLE] [FRAME] [GROUP COMPANY]
Same frame design as the reference, same proportions and position. Only change: small
silver arrowhead finials rise from the two upper corners, the corner scrolls a little
larger. Bottom emblem: THREE gold stars.
```

### 2.10 Đại úy: `frame_dai_uy.png`

```
[STYLE] [FRAME] [GROUP COMPANY]
Same frame design as the reference, same proportions and position, the grandest company
frame: larger corner scrollwork with bigger sapphires, the medallion framed by a silver
sunburst rim of short solid spikes. Bottom emblem: FOUR gold stars.
```

### 2.11 Thiếu tá: `frame_thieu_ta.png`

```
[STYLE] [FRAME] [GROUP FIELD]
Rank 11, the first field officer: the gold band with two blue stripes, gold scroll corners
with rubies, laurel sprigs at the lower corners. Bottom emblem: ONE gold star over two
bars.
```

### 2.12 Trung tá: `frame_trung_ta.png`

Đính kèm `frame_thieu_ta.png`.

```
[STYLE] [FRAME] [GROUP FIELD]
Same frame design as the reference, same proportions and position. Only change: an oval
ruby in a gold mount at the middle of each side band (between y 560 and y 720). Bottom
emblem: TWO gold stars over two bars.
```

### 2.13 Thượng tá: `frame_thuong_ta.png`

```
[STYLE] [FRAME] [GROUP FIELD]
Same frame design as the reference, same proportions and position. Only change: a small
row of gold crown points rises behind the top medallion, the lower laurel sprigs fuller.
Bottom emblem: THREE gold stars over two bars.
```

### 2.14 Đại tá: `frame_dai_ta.png`

```
[STYLE] [FRAME] [GROUP FIELD]
Same frame design as the reference, same proportions and position, the top of the ladder
before the generals: taller gold crown points behind the medallion with a ruby on top,
the largest scroll corners, short gold tassels hanging under the two lower corners.
Bottom emblem: FOUR gold stars over two bars.
```

### 2.15 Thiếu tướng: `frame_thieu_tuong.png`

```
[STYLE] [FRAME] [GROUP GENERAL]
Rank 15, the first general: a small three-point gold crown crest behind the medallion,
small folded gold wings at the upper corners, laurel at the lower corners. No banners, no
light rays yet. Bottom emblem: ONE large gold star.
```

### 2.16 Trung tướng: `frame_trung_tuong.png`

Đính kèm `frame_thieu_tuong.png`.

```
[STYLE] [FRAME] [GROUP GENERAL]
Same frame design as the reference, same proportions and position. Only change: a
five-point crown crest, the wings half open, short crimson banners with gold fringe hang
below the lower corners. Bottom emblem: TWO large gold stars.
```

### 2.17 Thượng tướng: `frame_thuong_tuong.png`

```
[STYLE] [FRAME] [GROUP GENERAL]
Same frame design as the reference, same proportions and position. Only change: the
wings fully spread up into the top margin, longer banners, solid pale-gold light rays
(#FFE9A0, flat wedges with a dark outline) fanning upwards behind the crown crest, rubies
along the whole red band. Bottom emblem: THREE large gold stars.
```

### 2.18 Đại tướng: `frame_dai_tuong.png`

```
[STYLE] [FRAME] [GROUP GENERAL]
Same frame design as the reference, same proportions and position, the single most
spectacular frame of the game: the tallest crown crest with a large white diamond at its
peak, two layers of fully spread golden wings filling the upper margin, a full laurel
wreath around the lower corners, long crimson banners with gold fringe on both sides,
wide solid pale-gold light rays fanning behind the whole top edge, white diamonds and
rubies all along the band. Bottom emblem: FOUR large gold stars.
```

---

## 3. Sheet ý tưởng theo nhóm (tuỳ chọn, chỉ để tham chiếu): `concept/`

Dùng để chốt kiểu dáng chung của một nhóm trước khi vẽ từng khung. Tool không nhập.

```
[STYLE] [GROUP …]
Design sheet: the N frames of this rank group side by side in one row, lowest rank on the
left, same size, same proportions (each a 4:5 portrait card frame around an empty magenta
window), each one a little richer than the previous one as described: … (paste the
grade-specific sentences). Wide canvas.
```

Tên file gợi ý: `concept/enlisted.png`, `cadet.png`, `company.png`, `field.png`, `general.png`.

---

## 4. Huy hiệu (18 ảnh): `art_source/ranks/badges/`

Mọi huy hiệu: canvas vuông 1024×1024 (hoặc 512×512), nền magenta **#FF00FF**, game thu về 256×256.
Prompt = `[STYLE] [BADGE]` + đoạn riêng. Huy hiệu dùng **cùng màu và cùng dấu hiệu** với khung của
nhóm, hình dáng lớn dần theo nhóm: nhóm 1–6 là **tấm cầu vai** (bo tròn, đầu trên nhọn), nhóm cấp úy
và cấp tá là **khiên** viền kim loại, nhóm tướng là **khiên có cánh và vương miện**. **Không vẽ**:
chữ, số, tên cấp, hiệu ứng lấp lánh rời rạc, viền hay nền vuông sau huy hiệu.

Ở 24 px chỉ đọc được màu và hình dáng nhóm; số vạch / số sao đọc rõ từ ~40 px (màn kết quả, thẻ),
nên dấu hiệu phải to, dày, cách nhau rõ.

### Khối nhóm của huy hiệu

```
BADGE ENLISTED: an upright olive-drab shoulder board (#5B6B3A, shade #3E4A27) with a
rounded bottom and a pointed top, a gunmetal steel button near the point, a thick dark
outline. On it, mustard-yellow chevrons (#E3B23C, highlight #FFE08A) pointing up, each
chevron as thick as one fifth of the board's width, small gaps between them, the stack
centred on the board.
```

```
BADGE CADET: the same upright shoulder board shape in bright brushed steel (#A9B4BF) with a
steel-blue enamel centre (#3E6B9E), a small pair of steel laurel sprigs at its base. On it,
one wide horizontal gold bar (#F2C14E).
```

```
BADGE COMPANY: a heater shield with a polished silver rim (#D8DEE6), navy-blue enamel field
(#24427A), one vertical silver stripe down the middle of the field, a small sapphire at
the top of the rim. On it, large chunky gold five-point stars (#FFD45C) in one horizontal
row across the upper half, over the stripe.
```

```
BADGE FIELD: a heater shield with a thick gleaming gold rim (#F5C242, shade #C8901E),
royal-blue enamel field (#1F4FA8), two vertical gold stripes down the field, a ruby at the
top of the rim, small gold laurel sprigs hugging the lower sides of the shield. On it,
large chunky gold stars in one horizontal row across the upper half.
```

```
BADGE GENERAL: a broad shield of deep red enamel (#B3141F) with a thick bright gold rim
(#FFD24A, highlight #FFF4C2), a gold crown crest on top, golden feathered wings spread
from both sides of the shield, a gold laurel under it. On it, large bold gold stars with a
dark outline in one horizontal row across the middle.
```

| Cấp | File | Prompt |
|---|---|---|
| Binh nhì | `badge_binh_nhi.png` | `[STYLE] [BADGE] [BADGE ENLISTED]` + `ONE chevron.` |
| Binh nhất | `badge_binh_nhat.png` | … `[BADGE ENLISTED]` + `TWO chevrons.` |
| Hạ sĩ | `badge_ha_si.png` | … `[BADGE ENLISTED]` + `THREE chevrons.` |
| Trung sĩ | `badge_trung_si.png` | … `[BADGE ENLISTED]` + `FOUR chevrons.` |
| Thượng sĩ | `badge_thuong_si.png` | … `[BADGE ENLISTED]` + `FIVE chevrons, a thin brass edge round the board.` |
| Học viên | `badge_hoc_vien.png` | … `[BADGE CADET]` + `ONE bar.` |
| Thiếu úy | `badge_thieu_uy.png` | … `[BADGE COMPANY]` + `ONE star.` |
| Trung úy | `badge_trung_uy.png` | … `[BADGE COMPANY]` + `TWO stars.` |
| Thượng úy | `badge_thuong_uy.png` | … `[BADGE COMPANY]` + `THREE stars.` |
| Đại úy | `badge_dai_uy.png` | … `[BADGE COMPANY]` + `FOUR stars, the silver rim a little wider.` |
| Thiếu tá | `badge_thieu_ta.png` | … `[BADGE FIELD]` + `ONE star.` |
| Trung tá | `badge_trung_ta.png` | … `[BADGE FIELD]` + `TWO stars.` |
| Thượng tá | `badge_thuong_ta.png` | … `[BADGE FIELD]` + `THREE stars.` |
| Đại tá | `badge_dai_ta.png` | … `[BADGE FIELD]` + `FOUR stars, small gold crown points on top of the shield.` |
| Thiếu tướng | `badge_thieu_tuong.png` | … `[BADGE GENERAL]` + `ONE large star, small folded wings, a three-point crown.` |
| Trung tướng | `badge_trung_tuong.png` | … `[BADGE GENERAL]` + `TWO large stars, half-open wings, a five-point crown.` |
| Thượng tướng | `badge_thuong_tuong.png` | … `[BADGE GENERAL]` + `THREE large stars, fully spread wings, solid pale-gold light rays behind the crown.` |
| Đại tướng | `badge_dai_tuong.png` | … `[BADGE GENERAL]` + `FOUR large stars, two layers of fully spread wings, the tallest crown with a white diamond, wide solid light rays behind it, the most splendid emblem.` |

Mẹo: vẽ huy hiệu đầu tiên của nhóm trước rồi đính kèm làm tham chiếu ("same emblem, only change the
number of stars to …") để cả nhóm giống nhau.

---

## 5. Nhập vào game

Trong thư mục game (editor mở cũng được, tool chỉ đọc / ghi PNG):

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_rank_art.gd -- --debug=/tmp/rank_debug
```

(thêm id cấp sau `--` để chỉ nhập vài cấp: `-- dai_tuong thieu_tuong --debug=…` nhập khung và huy
hiệu của hai cấp đó). Tool ghi `assets/ranks/frame_<grade>.png` (768×960),
`badge_<grade>.png` (256×256) và `assets/ranks/ranks.json`; rồi **quay lại editor** cho nó import.

Tool tự: xoá nền magenta (cả trong ô cửa sổ), xoá viền hồng, xoá dấu ✦ của AI khi nó nằm trên nền;
căn khung theo ô cửa sổ đo được (mọi khung trùng ô cửa sổ); cắt và căn giữa huy hiệu. Nó in cảnh báo
khi: ô cửa sổ bị vẽ đè, ảnh quá nhỏ (bị phóng to), hoa văn tràn khỏi canvas, hai đoạn thanh bên không
trơn. Xem `/tmp/rank_debug/ladder_frames.png` và `ladder_badges.png` (cả thang cấp, huy hiệu ở 24 /
48 / 96 px) và `<tên>_corner.png` (góc dưới phải: còn ✦ thì khai báo nó trong `ranks.json`
`"files": {"frame_<grade>": {"watermarks": [{"centre": [x, y], "size": [rx, ry]}]}}` bằng toạ độ
ảnh gốc, tool vẽ lại phần bên dưới).

Model ra sheet đủ to: `"sheets": [{"file": "frames_general.png", "kind": "frame", "cols": 4,
"rows": 1, "grades": ["thieu_tuong", "trung_tuong", "thuong_tuong", "dai_tuong"]}]` (mỗi ô phải
≥ 768 px ngang).

---

## 6. Kiểm tra trước khi đưa vào game

- **Tên file / thư mục** đúng như trên (`frames/frame_<grade>.png`, `badges/badge_<grade>.png`).
- **Nền**: một màu magenta phẳng, cả trong ô cửa sổ; 4 góc canvas trống; không có hồng / tím trên
  hình.
- **Ô cửa sổ** (khung): trống hoàn toàn, tỉ lệ 4:5, cách mép canvas 12% mỗi bên; mép trong của viền
  nằm đúng trên đó.
- **Ghế huy hiệu** ở giữa cạnh trên là mặt tròn trơn, không hình; **huy hiệu đáy** đúng số vạch /
  sao của cấp.
- **Hai đoạn thanh bên trơn** (y 384–550 và 730–896) không có gì gắn vào.
- **Đối xứng** trái phải; không chữ, không số; không lấp lánh bay rời.
- **Thang cấp**: xếp 18 khung cạnh nhau (`ladder_frames.png`): cấp sau luôn giàu hơn cấp trước, nhóm
  sau khác hẳn nhóm trước về vật liệu; Đại tướng nổi bật nhất.
- **Huy hiệu ở 24 px** (`ladder_badges.png`): nhận ra nhóm bằng màu và hình; từ 48 px đếm được vạch /
  sao.
