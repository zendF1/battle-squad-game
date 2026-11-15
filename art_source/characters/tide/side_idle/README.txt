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
Súng đeo sau lưng trong trận: scenes/character/poses/tide_carry.tscn (khung xương chibi, ../rig/).

idle_final.png: the user's final chibi picture, 2026-11-15 (896 x 1200, white backdrop, one set with the other
four). In matches it is the standing picture: the bone rig is cut from it (../rig/make_rig.py). The older
chibi picture idle_v2.png (made from idle_v2_ai_source.png by chibi_edit/) is no longer used.
