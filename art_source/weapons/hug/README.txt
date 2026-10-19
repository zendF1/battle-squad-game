Súng ôm (dáng ngắm quỳ): mỗi súng một ảnh <loại>_<cấp>.png, vd. bazooka_iron.png, cannon_steel.png, seed_launcher_dragon.png.
loại = bazooka, cannon, shock_rifle, seed_launcher, blaster; cấp = basic (súng khởi đầu), iron, steel, mithril, dragon (blaster
thêm silver, gold, titan, diamond).
- súng nằm ngang, nòng sang PHẢI, không có tay cầm, nền một màu đặc: xanh lá HOẶC hồng tím (magenta)
  đều được, tool lấy màu ở 4 góc làm màu nền (dấu ✦ của AI tool tự xoá)
- có ảnh: bazooka_iron.png (ô liu), bazooka_mithril.png (pha lê xanh), bazooka_dragon.png (rồng đỏ cam);
  cannon_iron.png (thân xám, nòng ô liu), cannon_steel.png (thân cam, ô liu), cannon_mithril.png (xanh
  nhạt), cannon_dragon.png (đỏ vàng, nòng là đầu rồng: điểm bắn ở miệng rồng);
  nền magenta: seed_launcher_iron.png (nắp xám, ống ô liu, lá ngắm, hạt xanh), seed_launcher_steel.png
  (nắp hồng đỏ, ống bạc), seed_launcher_mithril.png (xanh trời hoa văn vàng, pha lê ngọc phát sáng),
  seed_launcher_dragon.png (đỏ thẫm vòng vàng, đầu rồng ngậm hạt lửa)
- cấp chỉ khác màu không cần ảnh: hug.json "bazooka_basic" / "bazooka_steel" = {"from": "iron",
  "recolour": {...}} (đổi màu ảnh iron: basic nhạt màu như basic.png cũ, steel ô liu đậm hơn như steel.png
  cũ); đủ 5 cấp bazooka. Chạy lại tool với bazooka_iron là làm lại cả basic, steel. "cannon_basic" =
  cannon_iron nhạt màu y như basic.png cũ của cannon; "seed_launcher_basic" cũng vậy với seed_launcher_iron.
- đại pháo dài 58 px trong trận (bazooka 57), mọi cấp như nhau; muzzle từng ảnh = tâm lỗ nòng
- súng hạt của Flora dài 45 px (điểm ôm của Flora thấp: dài hơn thì ngắm thẳng lên đuôi súng chui
  xuống đất), mọi cấp như nhau (đầu rồng tính vào độ dài); muzzle = giữa hạt / pha lê / hạt lửa
- nền magenta: viền hồng tự khử (phần đỏ + lam vượt lục bị trừ đi, màu đỏ của súng giữ nguyên);
  "despill": {"hueRange": [270, 320]} làm đen các điểm viền ám tím, không đụng màu hồng / đỏ của súng
- quầng sáng vẽ lẫn vào nền (pha lê mithril, hạt lửa dragon): hug.json "background": {"glow": {"colour":
  [r, g, b]}} = màu quầng; tool tách quầng khỏi nền thành đúng màu đó, trong suốt dần (không ám hồng;
  "alpha": 0 thì xoá hẳn quầng), đo độ dài súng không tính quầng

Chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_hug_guns.gd
Ghi assets/weapons/<loại>/hug_<cấp>.png + assets/weapons/hug.json. Độ dài mặc định: hug.json "length"
(57 px trong trận); chỉnh cỡ / chỗ trong editor ở scenes/character/poses/<id>_ready.tscn (GunSocket).
Cũng ghi icon trang bị assets/icons/equipment/weapon_bazooka_<…>.png, weapon_cannon_<…>.png,
weapon_launcher_<iron|steel|mithril|dragon>.png từ chính các
ảnh này (hug.json "icons"; nghiêng, lề, cỡ như icon các súng khác trong guns_v1.json "icons").
Bazooka, đại pháo và súng hạt chỉ còn ảnh ôm này: súng trên bệ ở Sảnh / Chuẩn bị / Nhân vật cũng là
hug_<cấp>.png; ảnh cũ có tay cầm (assets/weapons/bazooka/<cấp>.png, cannon/<cấp>.png,
seed_launcher/<cấp>.png, cắt từ guns_v1.png) đã xoá.
