# Video giới thiệu game cho cửa hàng: prompt và kịch bản

Hai loại video, dùng ở hai nơi khác nhau:

| Loại | Dùng ở đâu | Làm bằng gì |
|---|---|---|
| **A. Trailer điện ảnh** (30–45 s) | Google Play (link YouTube), TikTok / Facebook / YouTube Shorts, quảng cáo | AI video (Veo 3, Sora, Kling, Runway, Hailuo…) theo các shot bên dưới, ghép lại trong CapCut / Premiere |
| **B. App Preview** (15–30 s) | App Store | **Quay màn hình game thật** (Apple chỉ nhận video quay từ chính app: cảnh dựng bằng AI không có trong game sẽ bị từ chối). Kịch bản ở mục B |

Prompt bằng tiếng Anh (model hiểu tốt nhất), giải thích bằng tiếng Việt. Thiết kế là của riêng game:
không đưa tên game khác, tên hãng hay "in the style of …" vào prompt.

## 0. Khối dùng chung

### 0a. STYLE (dán vào đầu mọi prompt)

```
2D cartoon game art brought to life, bold dark-navy outlines, flat cel shading with soft highlights,
saturated cheerful colours (sky blue, grass green, warm gold, orange), chibi proportions (big heads,
expressive faces), clean readable shapes, smooth 2.5D camera moves, bright daylight, playful but
action-packed mood, 16:9, 1920x1080, 24 fps, no text, no watermark, no logos.
```

### 0b. NHÂN VẬT (dán đúng đoạn của nhân vật có trong shot, giữ nguyên chữ để model vẽ giống nhau giữa các shot)

```
ROOKIE: a cheerful boy soldier, brown hair, olive-green cap with a gold star, blue jacket, brown
belt with grenades, carries a big olive bazooka on his shoulder.
FLORA: a fierce girl, black hair, dark-green bandana with a pink flower, green armoured outfit,
holds a leafy green seed launcher made of vines.
TANKO: a stocky grumpy soldier, grey steel helmet, olive vest with grenades, arms crossed, drags a
heavy dark-grey cannon.
SPARK: a cocky young man, spiky bright-yellow hair, purple vest, winks a lot, holds a pale-blue
electric laser rifle crackling with sparks.
TIDE: a cheerful girl, short navy-blue hair, white-and-teal sailor uniform, a water tank on her
back, aims a teal water blaster.
```

### 0c. BOSS

```
STEEL ROBOT: a giant blocky steel robot with a glowing cyan visor, shoulder cannons, launches drones.
LAVA CRAB: a huge red-black crab with glowing magma cracks, giant pincers, throws lava bombs.
ICE WITCH: a tall pale witch in icy blue robes, crystal staff, snowflakes swirling around her.
ROCK GIANT: a towering giant of desert boulders with glowing amber eyes, stone pillars rise around him.
TREE SPIRIT: an ancient living tree with a face in the bark, vine arms, poisonous purple mushrooms at its roots.
```

### 0d. NEGATIVE (ô "negative prompt" nếu công cụ có)

```
realistic, photorealistic, 3D render, gore, blood, text, letters, subtitles, watermark, logo,
extra fingers, deformed hands, distorted faces, blurry, low quality, flicker, morphing characters
```

**Mẹo giữ nhân vật giống nhau:** dùng chế độ **image-to-video** khi có thể. Khung đầu lấy từ ảnh có sẵn:
nền đăng nhập (`branding/` login background: đủ 5 nhân vật), chân dung nhân vật trong `art_source/characters/`,
ảnh boss trong `art_source/bosses/`, nền tải dữ liệu (hai đảo đối đầu). Tạo 3–4 bản mỗi shot, chọn bản
mặt và vũ khí đúng nhất.

## A. Trailer (≈ 40 s, 9 shot)

Nhịp: mở êm → dồn dập → boss → đỉnh điểm → logo. Mỗi shot 3–6 s; tạo dài hơn một chút rồi cắt.

**Shot 1 — Mở đầu (4 s)**
```
[STYLE] Sunrise over a bright cartoon world of floating grassy islands drifting above a sea of clouds,
a winding dirt path, distant snowy peak, smoking volcano, giant tree and a factory on the horizon.
Slow camera push-in from high above, clouds parting, birds flying past, warm golden light.
```

**Shot 2 — Đội hình xuất hiện (5 s)** *(image-to-video từ nền đăng nhập)*
```
[STYLE] [ROOKIE] [FLORA] [TANKO] [SPARK] [TIDE] The five heroes stand on a grassy hilltop facing the
camera. One by one they strike a pose: Rookie waves and shoulders his bazooka, Flora punches the air,
Tanko cracks his knuckles, Spark winks and spins his rifle, Tide points forward. Light breeze in hair
and grass, slow dolly-in.
```

**Shot 3 — Ngắm bắn (4 s)**
```
[STYLE] [ROOKIE] Close-up side view: Rookie on the edge of a floating island adjusts the angle of his
bazooka, a glowing dotted trajectory arc curves across the sky toward an enemy island, a wind flag
flutters. He squints, tongue out in concentration, then fires: muzzle flash, smoke ring, camera
follows the rocket into the sky.
```

**Shot 4 — Phá địa hình (4 s)**
```
[STYLE] The rocket arcs across a bright sky and slams into an enemy island with red sandbag forts:
a big cartoon explosion bites a round crater out of the ground, chunks of dirt and grass fly, a
red-flag soldier tumbles off the edge with a comic yelp. Slight camera shake, slow-motion on impact.
```

**Shot 5 — Đồng đội 2v2 (5 s)**
```
[STYLE] [FLORA] [TIDE] Fast split-screen style montage on two islands: Flora fires a seed bomb that
bursts into thorny vines, Tide sprays a high arc of water that crashes like a wave, both high-five as
their shots land together on the enemy fort. Quick whip-pans between them, energetic.
```

**Shot 6 — Vật phẩm đặc biệt (5 s)**
```
[STYLE] [TANKO] [SPARK] Tanko fires a red signal flare that lands on the enemy island; a beat later a
huge yellow bomb with a radiation symbol falls from the sky and erupts in a giant cartoon mushroom
cloud and shockwave. Cut to Spark: five pink laser beams sweep in from the sky and converge on one
point with a blinding flash. Bright, punchy, no gore.
```

**Shot 7 — Boss xuất hiện (5 s)**
```
[STYLE] [STEEL ROBOT] Ominous low-angle shot: the ground shakes, a giant steel robot rises behind a
ridge, cyan visor lighting up, shoulder cannons unfold, small drones launch around it. The sky dims
slightly. Dramatic slow push-in.
```

**Shot 8 — Đánh boss bốn người (6 s)**
```
[STYLE] [ROOKIE] [FLORA] [TANKO] [SPARK] Four heroes on separate floating rocks fire at once at a
giant boss: rockets, seed bombs, a cannonball and an electric beam streak across the screen and hit
together; the boss staggers, armour pieces fly off, golden sparkles burst. Quick montage of other
bosses roaring in their arenas: [LAVA CRAB] in a volcano, [ICE WITCH] in a blizzard, [ROCK GIANT]
in a desert canyon, [TREE SPIRIT] in a dark forest.
```

**Shot 9 — Mở rương phần thưởng (4 s)**
```
[STYLE] A wooden treasure chest with steel bands drops onto the grass, wobbles harder and harder with
light leaking from its seams, then bursts open: god rays, confetti, and glowing gems, golden coins
and shiny armour pieces fly out in an arc. The five heroes cheer around it.
```

**Shot cuối — Logo (3–4 s, không cần AI)**
Ghép trong phần mềm dựng: nền trời xanh tia sáng (giống icon app), logo emblem bật vào (scale 0 → 110 % →
100 %), lấp lánh, dưới logo là nút / huy hiệu cửa hàng (App Store, Google Play). Một dòng chữ ngắn tuỳ
chọn: **"Tải ngay!"**.

### Âm thanh

- Nhạc: orchestral-pop vui, nhịp nhanh dần (≈ 120 → 140 BPM), cao trào ở shot 8, dừng một nhịp im lặng
  ngay trước tiếng mở rương ở shot 9. Dùng nhạc có giấy phép (thư viện royalty-free hoặc tự tạo bằng
  AI nhạc có quyền dùng thương mại).
- SFX: gió, bắn, nổ, tiếng đất vỡ, robot gầm, tiếng rương bật, "ting" lấp lánh khi đồ bay ra.
- Không lồng tiếng thuyết minh. Nếu cần chữ trên màn, tối đa 3 câu ngắn, mỗi câu ≤ 3 từ, ví dụ:
  **"Ngắm. Bắn. Phá!"** (shot 3–4), **"Cùng đồng đội"** (shot 5), **"Hạ boss khổng lồ"** (shot 7–8).

### Kích thước xuất

- 1920×1080, 30 fps, H.264, 30–45 s cho YouTube / Google Play.
- Bản dọc 1080×1920 cho TikTok / Shorts: dựng lại, giữ nhân vật ở giữa khung (đa số shot trên đặt
  nhân vật giữa nên crop dọc được).

## B. App Store Preview (25–30 s, quay từ game thật)

Apple yêu cầu video quay từ chính app (được phép cắt ghép, thêm chữ ngắn, nhạc). Quay bằng máy thật
hoặc Simulator (`xcrun simctl io booted recordVideo preview.mov`), landscape, chơi bản build gần nhất.
Kiểm tra kích thước đang yêu cầu trong App Store Connect trước khi xuất (iPhone màn lớn và iPad mỗi
loại một cỡ; video 15–30 s, 30 fps).

| Thời gian | Cảnh quay trong game | Chữ trên màn (tuỳ chọn) |
|---|---|---|
| 0–3 s | Màn sảnh: nhân vật đứng trên bệ, hào quang súng +16 | — |
| 3–8 s | Trận PvP: chỉnh góc, thanh lực, bắn, hố nổ khoét đất, đối thủ rơi khỏi đảo | Ngắm. Bắn. Phá! |
| 8–12 s | Item: bom huỷ diệt rơi xuống + nấm nổ; laze hội tụ | — |
| 12–19 s | Trận boss 4 người: Rô-bốt Thép bắn laze, cả đội bắn trả, thanh máu boss tụt | Hạ boss khổng lồ |
| 19–24 s | Mở rương: rương rung, bật nắp, đồ phát sáng bay ra | — |
| 24–27 s | Bảng xếp hạng: top 3 đứng trên bục | — |
| 27–30 s | Logo emblem trên nền tia sáng | — |

Mẹo quay: dùng tài khoản test có đồ +16 và nhiều item để cảnh đẹp; tắt thông báo hệ thống; quay mỗi
cảnh vài lần rồi chọn đoạn đẹp nhất.
