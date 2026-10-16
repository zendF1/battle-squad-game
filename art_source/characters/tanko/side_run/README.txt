Ảnh chạy góc ngang của tanko (dùng trong trận).

Bỏ vào thư mục này: frame_1.png, frame_2.png, ... frame_N.png
- một vòng chạy (frame cuối nối lại frame đầu), nhìn sang PHẢI
- nền trong suốt, cỡ ảnh tuỳ ý (như của Rookie: 1280x720), chân chạm đất ở mọi frame
- frame_1.png là dáng đứng thẳng nhất (dùng làm dáng đứng yên)

Rồi chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- tanko

Cấu hình: import.json (mẫu chép từ Rookie). Hướng dẫn đủ: assets/README.md, mục "Thêm ảnh góc ngang cho nhân vật".
