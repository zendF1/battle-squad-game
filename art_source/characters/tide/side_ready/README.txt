Dáng ngắm của tide trong trận: nhân vật QUỲ, ôm khẩu súng nước giữa ngực (súng vẽ riêng).

Đã có: ready_v1.png (887x1792, quỳ, nhìn sang PHẢI, hai nắm tay chụm trước ngực, không cầm súng, nền
xanh lá #00FF00). Dấu ✦ của AI nằm đè lên mũi giày trước nên đã được gỡ khỏi ảnh trước khi lưu ở đây
(un-blend: độ trong của dấu đo trên nền xanh, lật đối xứng sang phần đè lên giày).

Súng ôm vẽ riêng: art_source/weapons/hug/water_gun_<cấp>.png.

Chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- tide
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd -- water_gun_iron water_gun_steel water_gun_mithril water_gun_dragon

Cấu hình: ../side_run/import.json mục poses.ready (scale 0.36: mặt từ tai đến mũi rộng bằng ảnh chạy;
alignX: giữa mặt trên giữa mặt của frame_1; armFront: tay áo gần, cẳng tay và hai nắm tay vẽ đè lên
súng). Chỗ súng: scenes/character/poses/tide_ready.tscn (GunSocket trên hai nắm tay).
