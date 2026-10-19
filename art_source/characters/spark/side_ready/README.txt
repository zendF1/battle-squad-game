Dáng ngắm của spark trong trận: nhân vật QUỲ, ôm một khẩu súng to giữa ngực (súng vẽ riêng).

Bỏ vào thư mục này: ready_v1.png
- nhân vật quỳ, nhìn sang PHẢI, hai tay chụm giữa ngực, KHÔNG cầm súng
- cùng nét vẽ với ảnh chạy (../side_run/), nền xanh lá đặc (một màu; dấu ✦ của AI tool tự xoá)

Súng ôm vẽ riêng: art_source/weapons/hug/<loại>_<cấp>.png (vd. bazooka_iron.png): nằm ngang, nòng
sang phải, không tay cầm, nền xanh lá đặc.

Chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- spark
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd

Sau đó trong editor: đợi import xong, mở scenes/character/poses/spark_ready.tscn, kéo / co giãn
GunSocket (bấm vào súng) cho súng che kín hai nắm tay (súng xoay quanh gốc GunSocket), Ctrl+S, F5.
