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

idle_v2.png: the chibi standing picture (797 x 969, pure white backdrop) the match rig is cut from (../rig/make_rig.py).
It is made from idle_v2_ai_source.png (the user's AI picture, 745 x 1000, not chibi) by chibi_edit/make_chibi.py:
head x1.4, width kept, shirt x0.78 and legs x0.62 tall, on a white 797 x 969 canvas
(python3 -I art_source/characters/tide/side_idle/chibi_edit/make_chibi.py [OUT.png]).
