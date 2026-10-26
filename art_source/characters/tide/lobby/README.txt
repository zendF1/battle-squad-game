Ảnh toàn thân của tide ở sảnh (Sảnh, Nhân vật, Shop, thẻ đồng đội, chân dung lượt trong trận).

Đã có: full_v1.png (911x1783, nhìn về phía người xem, tay phải chống hông, nền trắng). Chân dung
assets/characters/tide/portrait.png cắt từ chính ảnh này (đầu và vai).

Chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/cut_sheet.gd -- tide

Cấu hình: art_source/characters/lineup_parts.json, figure "tide" ("sheet": "tide/lobby/full_v1.png",
rect / seed / holes (lòng vòng ống nước) / joints / portrait, px của full_v1.png). Nền trắng xoá bằng
loang từ mép rect (áo / giày trắng có viền đen bao nên giữ nguyên).
