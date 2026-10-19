Súng ôm (dáng ngắm quỳ): mỗi súng một ảnh <loại>_<cấp>.png, vd. bazooka_iron.png, cannon_steel.png.
loại = bazooka, cannon, shock_rifle, seed_launcher, blaster; cấp = iron, steel, mithril, dragon (blaster
thêm silver, gold, titan, diamond).
- súng nằm ngang, nòng sang PHẢI, không có tay cầm, nền xanh lá đặc (dấu ✦ của AI tool tự xoá)

Chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd
Ghi assets/weapons/<loại>/hug_<cấp>.png + assets/weapons/hug.json. Độ dài mặc định: hug.json "length"
(57 px trong trận); chỉnh cỡ / chỗ trong editor ở scenes/character/poses/<id>_ready.tscn (GunSocket).
