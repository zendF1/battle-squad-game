Súng ôm (dáng ngắm quỳ): mỗi súng một ảnh <loại>_<cấp>.png, vd. bazooka_iron.png, cannon_steel.png.
loại = bazooka, cannon, shock_rifle, seed_launcher, blaster; cấp = basic (súng khởi đầu), iron, steel, mithril, dragon (blaster
thêm silver, gold, titan, diamond).
- súng nằm ngang, nòng sang PHẢI, không có tay cầm, nền xanh lá đặc (dấu ✦ của AI tool tự xoá)
- có ảnh: bazooka_iron.png (ô liu), bazooka_mithril.png (pha lê xanh), bazooka_dragon.png (rồng đỏ cam)
- cấp chỉ khác màu không cần ảnh: hug.json "bazooka_basic" / "bazooka_steel" = {"from": "iron",
  "recolour": {...}} (đổi màu ảnh iron: basic nhạt màu như basic.png cũ, steel ô liu đậm hơn như steel.png
  cũ); đủ 5 cấp bazooka. Chạy lại tool với bazooka_iron là làm lại cả basic, steel.

Chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd
Ghi assets/weapons/<loại>/hug_<cấp>.png + assets/weapons/hug.json. Độ dài mặc định: hug.json "length"
(57 px trong trận); chỉnh cỡ / chỗ trong editor ở scenes/character/poses/<id>_ready.tscn (GunSocket).
Cũng ghi icon trang bị assets/icons/equipment/weapon_bazooka_<iron|steel|mithril|dragon>.png từ chính các
ảnh này (hug.json "icons"; nghiêng, lề, cỡ như icon các súng khác trong guns_v1.json "icons").
Bazooka chỉ còn ảnh ôm này: súng trên bệ ở Sảnh / Chuẩn bị / Nhân vật cũng là hug_<cấp>.png; ảnh
bazooka cũ có 2 tay cầm (assets/weapons/bazooka/<cấp>.png, cắt từ guns_v1.png) đã xoá.
