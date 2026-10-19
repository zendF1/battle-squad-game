Súng ôm (dáng ngắm quỳ): mỗi súng một ảnh <loại>_<cấp>.png, vd. bazooka_iron.png, cannon_steel.png.
loại = bazooka, cannon, shock_rifle, seed_launcher, blaster; cấp = basic (súng khởi đầu), iron, steel, mithril, dragon (blaster
thêm silver, gold, titan, diamond).
- súng nằm ngang, nòng sang PHẢI, không có tay cầm, nền xanh lá đặc (dấu ✦ của AI tool tự xoá)
- có ảnh: bazooka_iron.png (ô liu), bazooka_mithril.png (pha lê xanh), bazooka_dragon.png (rồng đỏ cam);
  cannon_iron.png (thân xám, nòng ô liu), cannon_steel.png (thân cam, ô liu), cannon_mithril.png (xanh
  nhạt), cannon_dragon.png (đỏ vàng, nòng là đầu rồng: điểm bắn ở miệng rồng)
- cấp chỉ khác màu không cần ảnh: hug.json "bazooka_basic" / "bazooka_steel" = {"from": "iron",
  "recolour": {...}} (đổi màu ảnh iron: basic nhạt màu như basic.png cũ, steel ô liu đậm hơn như steel.png
  cũ); đủ 5 cấp bazooka. Chạy lại tool với bazooka_iron là làm lại cả basic, steel. "cannon_basic" =
  cannon_iron nhạt màu y như basic.png cũ của cannon.
- đại pháo dài 58 px trong trận (bazooka 57), mọi cấp như nhau; muzzle từng ảnh = tâm lỗ nòng

Chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd
Ghi assets/weapons/<loại>/hug_<cấp>.png + assets/weapons/hug.json. Độ dài mặc định: hug.json "length"
(57 px trong trận); chỉnh cỡ / chỗ trong editor ở scenes/character/poses/<id>_ready.tscn (GunSocket).
Cũng ghi icon trang bị assets/icons/equipment/weapon_bazooka_<…>.png, weapon_cannon_<iron|steel|mithril|dragon>.png từ chính các
ảnh này (hug.json "icons"; nghiêng, lề, cỡ như icon các súng khác trong guns_v1.json "icons").
Bazooka và đại pháo chỉ còn ảnh ôm này: súng trên bệ ở Sảnh / Chuẩn bị / Nhân vật cũng là hug_<cấp>.png;
ảnh cũ có tay cầm (assets/weapons/bazooka/<cấp>.png, cannon/<cấp>.png, cắt từ guns_v1.png) đã xoá.
