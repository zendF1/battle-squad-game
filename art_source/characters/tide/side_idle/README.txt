Dáng đứng yên của tide trong trận (idle; cũng là thân khi bắn / trúng đạn / ngã).

Đã có: idle_v1.png (298x735, nền trong suốt): hình giữa (góc ngang, nhìn sang PHẢI, tay chống hông,
bình nước sau lưng) của ảnh AI 3 góc nhìn 1024x765, cắt trước khi lưu: nền ảnh đó trắng bên trái và
xanh lá #00FF00 từ x~512, hình giữa nằm vắt qua ranh giới; xoá cả hai (nền trắng loang từ ngoài vào nên
áo / quần / giày trắng có viền đen giữ nguyên; các túi nền xanh giữa tóc, bình nước và hai chân cũng
xoá; lòng vòng ống nước là nền trắng). Ảnh không có dấu ✦.

Rồi chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- tide
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/carry_bob.gd

Cấu hình: ../side_run/import.json, mục poses.stand (px của idle_v1.png):
  scale   0.91: mặt từ tai đến mũi rộng bằng ảnh chạy (117 / 130 px), dáng đứng cao bằng frame_1
  alignX  [193, 596.5]: giữa mặt trên giữa mặt của frame_1 (đầu không nhảy khi đứng <-> chạy <-> quỳ)
Súng đeo sau lưng: scenes/character/poses/tide_carry.tscn (CarrySocket sau bình nước của idle_0.png).
