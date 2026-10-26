Dáng đứng yên của spark trong trận (idle; cũng là thân khi bắn / trúng đạn / ngã).

Bỏ vào thư mục này: idle_v1.png
- nhân vật ĐỨNG THẲNG, hai chân chạm đất, nhìn sang PHẢI, không cầm súng
- cùng nét vẽ với ảnh chạy (../side_run/), nền trong suốt hoặc TRẮNG (ảnh hiện tại: 1024x765 nền trắng)
Chưa có ảnh này thì dáng đứng yên là một frame chạy (import.json anims.idle.fallback).

Rồi chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- spark

Cấu hình: ../side_run/import.json, mục poses.stand (px của idle_v1.png):
  background  nền trắng: {"key": [255, 255, 255], "tolerance": 12, "soft": 36, "holeMin": 100000000}
              chỉ xoá phần trắng nối với mép ảnh (nét viền đen chặn lại), chỗ trắng / sáng bên trong
              người giữ nguyên; ảnh đã trong suốt thì bỏ mục này
  scale   cỡ so với ảnh chạy (Spark 0.97: đầu rộng hơn ảnh chạy 4 % để dáng đứng cao gần bằng ảnh chạy,
          đầu không tụt khi đứng <-> chạy; Rookie 1.02, Flora 0.985, Tanko 1.0)
  alignX  [x trên idle_v1.png, x trên frame_1.png]: tai trên tai, đầu không nhảy khi đứng <-> chạy <-> quỳ
          (dáng quỳ ../side_ready/ready_v1.png dùng cùng scale / alignX: đầu vẽ cùng chỗ, cùng cỡ)
Chân tự đặt lên mặt đất. Ảnh đứng phải nằm trong khung chung (import.json canvas), nếu không lệnh in
"canvas ... grown" và mọi ảnh chạy / quỳ đổi theo: khi đó giảm scale một chút.
Xem kết quả: assets/characters/spark/side/idle_0.png (cùng khung với walk_0.png; phóng to xem không còn
viền trắng).
