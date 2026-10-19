Dáng đứng yên của tanko trong trận (idle; cũng là thân khi bắn / trúng đạn / ngã).

Bỏ vào thư mục này: idle_v1.png
- nhân vật ĐỨNG THẲNG, hai chân chạm đất, nhìn sang PHẢI, không cầm súng
- cùng nét vẽ và cùng cỡ ảnh với ảnh chạy (../side_run/, 1280x720), nền trong suốt
Chưa có ảnh này thì dáng đứng yên là frame_7.png (import.json anims.idle.fallback).

Rồi chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- tanko

Cấu hình: ../side_run/import.json, mục poses.stand (px của idle_v1.png):
  scale   cỡ so với ảnh chạy: mũ / đầu rộng bằng ảnh chạy (Rookie 1.02, Flora 0.985, Tanko 1.0)
  alignX  [x trên idle_v1.png, x trên frame_7.png dời theo stabilise]: tai trên tai, đầu không nhảy khi đứng <-> chạy <-> quỳ
Chân tự đặt lên mặt đất. Ảnh đứng phải nằm trong khung chung (import.json canvas), nếu không lệnh in
"canvas ... grown" và mọi ảnh chạy / quỳ đổi theo: khi đó giảm scale một chút.
Xem kết quả: assets/characters/tanko/side/idle_0.png (cùng khung với walk_0.png).
