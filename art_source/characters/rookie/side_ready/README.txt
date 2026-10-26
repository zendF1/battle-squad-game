Dáng ngắm của rookie trong trận: nhân vật QUỲ, ôm một khẩu súng to giữa ngực (súng vẽ riêng).

Bỏ vào thư mục này: ready_v1.png
- nhân vật quỳ, nhìn sang PHẢI, hai tay chụm giữa ngực, KHÔNG cầm súng
- cùng nét vẽ với ảnh chạy (../side_run/), nền xanh lá đặc (một màu; dấu ✦ của AI tool tự xoá)

Súng ôm vẽ riêng: art_source/weapons/hug/<loại>_<cấp>.png (vd. bazooka_iron.png): nằm ngang, nòng
sang phải, không tay cầm, nền xanh lá đặc.

Chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- rookie
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd

Sau đó trong editor: đợi import xong, mở scenes/character/poses/rookie_ready.tscn, kéo / co giãn
GunSocket (bấm vào súng) cho súng che kín hai nắm tay (súng xoay quanh gốc GunSocket), Ctrl+S, F5.

Tay ôm súng: cánh tay gần (tay áo từ vai tới nắm tay + hai nắm tay) tự cắt từ ready_v1.png thành
assets/characters/rookie/side/ready_arm_front.png và vẽ đè lên súng (không cần vẽ thêm). Cấu hình:
../side_run/import.json, mục poses.ready.armFront (px của ready_v1.png):
  polygon  vùng tối đa được cắt (vai, tay áo, hai nắm tay)
  seeds    một điểm bên trong mỗi mảng bị nét đen chia ra (bắp tay, cẳng tay, nắm tay), trên màu
  darkMax  độ sáng tối đa của nét viền; grow: bề dày viền giữ lại; feather: mép mềm
Đổi ảnh: chạy lại lệnh import_frames rồi xem ready_arm_front.png; thiếu mảng tay → thêm seed vào mảng
đó, lẹm vào áo / ngực → thu polygon lại chỗ đó.
