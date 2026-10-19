Dáng ngắm của spark trong trận: nhân vật QUỲ, ôm một khẩu súng to giữa ngực (súng vẽ riêng).

Bỏ vào thư mục này: ready_v1.png
- nhân vật quỳ, nhìn sang PHẢI, hai tay chụm giữa ngực, KHÔNG cầm súng
- cùng nét vẽ với ảnh chạy (../side_run/), nền xanh lá đặc (một màu; dấu ✦ của AI tool tự xoá)

Súng ôm vẽ riêng: art_source/weapons/hug/<loại>_<cấp>.png (vd. shock_rifle_iron.png): nằm ngang, nòng
sang phải, không tay cầm, nền xanh lá hoặc hồng tím đặc. Súng điện có ảnh ôm mọi cấp
(shock_rifle_iron / steel / mithril / dragon.png, basic = iron nhạt màu), dài 55 px trong trận.

Chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- spark
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd

Sau đó trong editor: đợi import xong, mở scenes/character/poses/spark_ready.tscn, kéo / co giãn
GunSocket (bấm vào súng) cho súng che kín hai nắm tay (súng xoay quanh gốc GunSocket), Ctrl+S, F5.
Preview là súng ôm shock_rifle/hug_iron.png (pose_gun.gd tự hiện khi editor import xong).

Tay ôm súng (vẽ đè lên súng, tự cắt từ ready_v1.png, không cần vẽ thêm): đã cấu hình ở
../side_run/import.json mục poses.ready.armFront (polygon: vai + bắp tay trần gần + cẳng tay + găng xanh
+ hai nắm tay; seeds: một điểm bên trong mỗi mảng; px của ready_v1.png; tay xa bên phải nắm tay nằm dưới
súng) và spark_ready.tscn đã có node ArmFront. Đổi ảnh thì chỉnh polygon / seeds, chạy lại
import_frames, xem assets/characters/spark/side/ready_arm_front.png; thiếu mảng → thêm seed, lẹm áo →
thu polygon.
