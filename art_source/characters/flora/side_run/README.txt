Ảnh chạy góc ngang của flora (dùng trong trận).

Bỏ vào thư mục này: frame_1.png, frame_2.png, ... frame_N.png
- một vòng chạy (frame cuối nối lại frame đầu), nhìn sang PHẢI
- nền trong suốt, cỡ ảnh tuỳ ý (như của Rookie: 1280x720), chân chạm đất ở mọi frame
- dáng đứng yên: ảnh riêng ../side_idle/idle_v1.png (chưa có thì dùng frame_1.png)

Rồi chạy (trong thư mục battle-squad-game):
  /Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- flora

Cấu hình: import.json (mẫu chép từ Rookie). Hướng dẫn đủ: assets/README.md, mục "Thêm ảnh góc ngang cho nhân vật".
