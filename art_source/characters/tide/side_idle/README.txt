Dáng đứng yên của tide trong trận (idle; cũng là thân khi bắn / trúng đạn / ngã). CHƯA CÓ.

Bỏ vào thư mục này: idle_v1.png (prompt: ../PROMPTS.md mục 3b)
- nhân vật ĐỨNG THẲNG, hai chân chạm đất, nhìn sang PHẢI, không cầm súng, bình nước sau lưng
- cùng nét vẽ và cùng cỡ ảnh với ảnh chạy (../side_run/, 1280x720), nền trong suốt hoặc trắng
  (nền trắng: thêm "background" như poses.stand của Spark)
Chưa có ảnh này thì dáng đứng yên là frame_2 của ảnh chạy (import.json anims.idle.fallback [1]).

Rồi chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- tide
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/carry_bob.gd

Cấu hình: ../side_run/import.json, mục poses.stand (px của idle_v1.png):
  scale   cỡ so với ảnh chạy: tóc / mặt rộng bằng ảnh chạy
  alignX  [x trên idle_v1.png, x trên frame_1.png]: tai trên tai (tai frame_1 ở x 538)
Sau đó chỉnh lại scenes/character/poses/tide_carry.tscn (CarrySocket trên lưng của idle_0.png mới).
