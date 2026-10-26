# Ảnh nền màn hình: prompt tạo ảnh

Thay nền đêm tối `env/lobby_bg.png` (đang dùng chung cho sảnh, ghép trận và kết quả) bằng nền sáng,
mỗi màn một ảnh. Prompt bằng tiếng Anh (model hiểu tốt nhất), giải thích bằng tiếng Việt. Không thêm
tên game / tên hãng / "in the style of <game>".

| # | Màn | File trong game |
|---|-----|-----------------|
| 1 | Sảnh | `assets/env/lobby_bg.png` (thay ảnh cũ) |
| 2 | Ghép trận PvP | `assets/env/matchmaking_pvp.png` |
| 3a–e | Ghép trận boss | `assets/env/matchmaking_boss_<bossId>.png`: `ice_witch`, `lava_crab`, `steel_robot`, `rock_giant`, `tree_spirit` |
| 4 | Kết quả sau trận | `assets/env/result.png` (dùng cho cả thắng / thua / hoà, game tự phủ tối và mưa khi thua) |

## Cách dùng

1. Mỗi prompt = **khối STYLE chung** (mục 0) + **phần riêng** của ảnh. Dán cả hai.
2. Đính kèm `art_source/characters/lineup_v1.png` làm ảnh tham chiếu nét vẽ và nói "same art style as
   the attached characters" (nền phải hợp với nhân vật, nhưng **không vẽ nhân vật**).
3. **Khung:** ngang siêu rộng **21:9**, càng lớn càng tốt (ví dụ 2560×1100). Màn hình từ 16:9 (máy tính)
   tới 19.5:9 (iPhone) nên game cắt bớt hai mép: mọi thứ quan trọng nằm trong **70% chiều ngang ở giữa**.
4. **Độ sáng:** sáng sủa, ban ngày, màu tươi nhưng **không trắng loá**. Các panel UI màu xanh đen và chữ
   trắng nằm đè lên, nên dải trên cùng (tên, tiền) và các vùng đặt panel nên ở **độ sáng vừa**, ít chi tiết.
5. Không có chữ, logo, nhân vật, boss, khung viền, UI. Dấu ✦ của AI ở góc thì cắt đi (nằm ở phần mép bị cắt).

---

## 0. Khối STYLE chung (dán vào đầu mọi prompt)

```
2D mobile game background art, bright cheerful cartoon style for a cute military artillery
game: clean shapes with soft dark-blue outlines on the near elements and none on the far ones,
flat cel-shaded colours with one shade and one highlight tone, gentle atmospheric perspective
(far layers lighter and bluer), sunny daytime light, vivid but soft saturated colours, crisp
vector-like edges, no texture noise, no painterly brush strokes. Ultra-wide 21:9 landscape,
everything important inside the middle 70% of the width. No characters, no people, no
creatures, no text, no letters, no logo, no UI, no frame border, no watermark.
```

## 1. Sảnh

Bố cục UI: góc trên trái thẻ người chơi + bảng chỉ số bên trái; giữa là nhân vật đứng trên bệ tròn
(bệ do game vẽ, ở khoảng 60–85% chiều cao); cột nút tròn bên phải; khung chat dưới trái; nút "BẮT ĐẦU"
dưới phải.

```
A sunny hilltop army training camp seen from a low angle: bright blue sky with big soft
white clouds, distant green hills and a faint mountain range, far in the background small
canvas tents, a wooden watchtower, sandbag walls and little flags fluttering, a few cartoon
artillery practice targets. The lower third is a wide flat grassy plateau with a few small
rocks and flowers at the far left and right edges, its centre left open and even (a round
stage will be placed there). Calm, open centre; the left and right thirds of the sky and the
bottom corners are simple and mid-toned so dark UI panels sit on them cleanly. Morning light
from the upper right, warm and friendly.
```

## 2. Ghép trận PvP

Bố cục UI: trái 2 thẻ đội mình, phải 2 thẻ đối thủ, giữa biểu tượng VS + tên chế độ + "Đang ghép...",
dưới là mẹo + nút "Hủy ghép". Bố cục **đối xứng gương**: hai nửa bằng nhau quanh tâm.

```
A perfectly mirror-symmetric battle arena at midday: two grassy hilltops facing each other
across a small valley, the left hill with blue banners and blue sandbag forts, the right hill
with red banners and red sandbag forts, same shapes mirrored left to right. In the exact centre
a bright warm sunburst glow in the sky over the valley, light rays fanning out from it (a VS
emblem will sit there). Sky clear blue fading to a warm golden glow at the centre. The left
and right thirds stay simple behind where team cards go; the bottom strip is plain grass.
Energetic, exciting, about to battle.
```

## 3. Ghép trận boss (mỗi boss một ảnh)

Bố cục UI: trên là tên boss; trái 4 thẻ đội (gọn); phải thẻ boss (game vẽ boss trên nền theo hệ);
giữa "Đang ghép...". **Không vẽ boss**: game tự vẽ. Mỗi ảnh là đấu trường của boss đó lúc **ban ngày,
sáng**, chi tiết tập trung ở xa và ở giữa, hai bên trái phải đơn giản.

**Phần chung cho 3a–e** (dán sau khối STYLE, trước phần riêng của boss):
```
A wide arena landscape where a giant boss is about to appear, seen from far away, with an
empty open space in the middle ground. The left and right thirds are simple and mid-toned
(UI cards go there); the top strip is plain sky for a title. Bright, adventurous, a little
dramatic but never dark.
```

**3a. Phù Thuỷ Băng (`ice_witch`, hệ Thủy)**
```
Frozen snowy mountain valley on a clear bright day: pale blue sky, sparkling snow peaks,
floating ice crystals and frozen icicle arches, a frozen lake in the centre reflecting the
sky, light snowfall, a distant ice spire tower. Colours: icy cyan, white, soft lilac shadows.
```

**3b. Cua Dung Nham (`lava_crab`, hệ Hỏa)**
```
Volcanic seashore at golden afternoon: warm orange-pink sky, a smoking volcano far in the
centre with glowing lava streams running down into the sea, black rock beach with steaming
pools, little embers in the air. Bright and warm, not dark: sunlit rocks, glowing orange
highlights. Colours: coral, orange, gold, warm grey rock.
```

**3c. Rô-bốt Thép (`steel_robot`, hệ Kim)**
```
Giant open-air robot factory yard under a clear sky: huge steel girders, cranes, rows of big
gears and pipes in the far background, a polished metal floor in the centre with yellow-black
hazard stripes at the edges, small sparks and light glints. Clean and shiny, daylight.
Colours: silver, steel blue, violet accents, safety yellow.
```

**3d. Khổng Lồ Đá (`rock_giant`, hệ Thổ)**
```
Sunlit red-rock canyon: tall sandstone mesas and arches, layered amber and ochre rock strata,
ancient carved stone totems standing at the canyon sides, a wide dusty plateau in the centre,
a few dust swirls, blue sky with thin clouds. Colours: amber, ochre, terracotta, sky blue.
```

**3e. Mộc Tinh (`tree_spirit`, hệ Mộc)**
```
Enchanted forest clearing at bright midday: an enormous ancient tree far in the centre with
roots spreading out, golden sunbeams falling through the canopy, glowing spotted mushrooms,
floating pollen sparkles and fireflies, ferns and flowers framing the bottom corners, a mossy
open clearing in the centre. Colours: fresh greens, lime, golden light, soft pink flowers.
```

## 4. Kết quả sau trận

Bố cục UI: trên cùng chữ "CHIẾN THẮNG" / "THẤT BẠI"; đội thắng bên trái trên bục sáng (game vẽ bục và
đèn), đội thua bên phải; thẻ phần thưởng dưới trái; nút dưới phải. Nền **đối xứng**, phần đất dưới
cùng đơn giản (game đặt bục và nhân vật lên đó).

```
A festive open-air army parade ground after a battle, perfectly mirror-symmetric: bright blue
sky with soft clouds, colourful triangle bunting and flags strung across the top corners, a
distant cheering grandstand silhouette with no visible people, a big rounded stone arch
decorated with laurel leaves far in the centre, soft golden light rays from the centre top.
The bottom third is a plain smooth sand-and-grass ground, even and uncluttered (podiums will
be placed there). Joyful, celebratory, bright.
```
