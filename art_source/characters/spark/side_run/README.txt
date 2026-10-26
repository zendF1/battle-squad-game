Ảnh chạy góc ngang của spark (dùng trong trận).

Bỏ vào thư mục này: frame_1.png, frame_2.png, ... frame_N.png
- một vòng chạy (frame cuối nối lại frame đầu), nhìn sang PHẢI
- nền trong suốt, cỡ ảnh tuỳ ý (như của Rookie: 1280x720), chân chạm đất ở mọi frame
- dáng đứng yên: ảnh riêng ../side_idle/idle_v1.png (chưa có thì dùng frame_1.png)

Rồi chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- spark

Cấu hình: import.json (height 62.26: đầu cùng cỡ với Rookie; walk 15 fps: chân chạm đất lùi ~6 px mỗi frame). Hướng dẫn đủ: assets/README.md, mục "Thêm ảnh góc ngang cho nhân vật".
