Dáng ngắm của tanko trong trận: nhân vật QUỲ, ôm một khẩu súng to giữa ngực (súng vẽ riêng).

Bỏ vào thư mục này: ready_v1.png
- nhân vật quỳ, nhìn sang PHẢI, hai tay chụm giữa ngực, KHÔNG cầm súng
- cùng nét vẽ với ảnh chạy (../side_run/), nền xanh lá đặc (một màu; dấu ✦ của AI tool tự xoá)

Súng ôm vẽ riêng: art_source/weapons/hug/<loại>_<cấp>.png (vd. bazooka_iron.png): nằm ngang, nòng
sang phải, không tay cầm, nền xanh lá đặc.

Chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- tanko
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd

Sau đó trong editor: đợi import xong, mở scenes/character/poses/tanko_ready.tscn, kéo / co giãn
GunSocket (bấm vào súng) cho súng che kín hai nắm tay (súng xoay quanh gốc GunSocket), Ctrl+S, F5.

Tay ôm súng (vẽ đè lên súng, tự cắt từ ready_v1.png, không cần vẽ thêm): đã cấu hình ở
../side_run/import.json mục poses.ready.armFront (polygon: vai + tay áo gần + hai nắm tay; seeds: một
điểm bên trong mỗi mảng; px của ready_v1.png) và tanko_ready.tscn đã có node ArmFront. Đổi ảnh thì chỉnh
polygon / seeds, chạy lại import_frames, xem assets/characters/tanko/side/ready_arm_front.png; thiếu
mảng → thêm seed, lẹm áo → thu polygon.
