Dáng đứng yên của flora trong trận (idle; cũng là thân khi bắn / trúng đạn / ngã).

Bỏ vào thư mục này: idle_v1.png
- nhân vật ĐỨNG THẲNG, hai chân chạm đất, nhìn sang PHẢI, không cầm súng
- cùng nét vẽ và cùng cỡ ảnh với ảnh chạy (../side_run/, 1280x720), nền trong suốt
Chưa có ảnh này thì dáng đứng yên là một frame chạy (import.json anims.idle.fallback).

Rồi chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- flora

Cấu hình: ../side_run/import.json, mục poses.stand (px của idle_v1.png):
  scale   cỡ so với ảnh chạy: mũ / đầu rộng bằng ảnh chạy (Rookie 1.02, Flora 0.985, Tanko 1.0)
  alignX  [x trên idle_v1.png, x trên frame_1.png]: tai trên tai, đầu không nhảy khi đứng <-> chạy <-> quỳ
Chân tự đặt lên mặt đất. Ảnh đứng phải nằm trong khung chung (import.json canvas), nếu không lệnh in
"canvas ... grown" và mọi ảnh chạy / quỳ đổi theo: khi đó giảm scale một chút.
Xem kết quả: assets/characters/flora/side/idle_0.png (cùng khung với walk_0.png).

idle_final.png: the user's final chibi picture, 2026-11-15 (896 x 1200, white backdrop, one set with the other
four). In matches it is the standing picture: the bone rig is cut from it (../rig/make_rig.py). The older
chibi picture idle_v2.png is no longer used.
