Trang bị (mũ, áo giáp, găng tay, quần, giày): mỗi cấp một ảnh <cấp>.png, cấp = iron, steel, mithril, dragon
(shop), silver, gold, titan, diamond (chế tạo). Vũ khí không nằm ở đây (súng: art_source/weapons/).

Cách vẽ bằng AI (mỗi cấp một lần, cùng một prompt, chỉ đổi chất liệu / màu):
- một ảnh ngang (vd. 1024x572), nền MỘT MÀU hồng tím đặc (magenta, #FF00FF), không bóng đổ, không hoạ tiết nền
- 5 món trên MỘT HÀNG, từ trái sang phải: mũ (helmet), áo giáp (vest có giáp vai, armor), găng tay (một
  đôi = một món, gloves), quần (pants), giày (một đôi = một món, boots); giữa các món chừa khoảng trống
  (không chạm nhau), mỗi đôi găng / giày vẽ sát nhau
- nét viền đen đậm kiểu hoạt hình, cùng nét vẽ và cùng bố cục cho cả 8 cấp (cùng cỡ, cùng chỗ): chỉ đổi
  chất liệu / màu (iron xám + da nâu, steel xanh thép, mithril ngọc lam, dragon đỏ vảy rồng + vàng + sừng,
  silver bạc hoa văn, gold vàng + đỏ, titan đen xám đinh cam, diamond pha lê xanh băng)
- dấu ✦ của AI ở góc, hạt lấm tấm rời: tool tự xoá; nền hồng lọt giữa hai ống quần, trong quai mũ, giữa
  các ngón tay / hai chiếc giày: tool tự xoá (khoảng nền kín từ 15 px)
- màu của món đồ không được gần hồng tím (tool coi là nền)

Chạy (trong thư mục battle-squad-game, editor mở cũng được):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_equipment.gd
Ghi assets/icons/equipment/<món>_<cấp>.png (128x128, nền trong suốt, cùng tên file cũ: Túi đồ, Shop, ô trang
bị ở Nhân vật, Chuẩn bị tự đổi, không sửa code). Cấu hình: equipment.json
- "items": thứ tự món trên ảnh (trái → phải)
- "margin": lề trống quanh món (6 px như icon súng); mỗi món một tỉ lệ chung cho cả 8 cấp (cấp to nhất vừa
  khung), nên đổi cấp món không to / nhỏ, không xê dịch
- "sparkles": ngôi sao lấp lánh trắng theo cấp như icon vẽ code cũ (silver 1, gold 2, diamond 3, dragon 1
  vàng trừ mũ): "stars" [[x, y, bán kính]] px của icon, "nudge" dời sao tối đa bấy nhiêu px ra chỗ trống
- "split": cách tách món; ảnh mới đặt các món sát quá thì thêm "cuts": [x1, x2, x3, x4] (px của ảnh: ranh
  giới giữa các món) để tách theo cột
Thiếu ảnh của một cấp thì icon cấp đó giữ nguyên. tools/bake_art.gd không vẽ đè các icon này (chỉ vẽ
hình bóng ô trống slot_<món>.png, khung lục giác, huy hiệu +N).
