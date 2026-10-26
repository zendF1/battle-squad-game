Ảnh chạy góc ngang của tide (dùng trong trận).

Đã có: frame_1.png ... frame_8.png (1280x720, nhìn sang PHẢI, nền trong suốt), chép từ
media-edit/tide-animation-run (cắt từ video bằng ngưỡng trắng chung: lòng trắng mắt, áo / giày trắng
cũng bị xoá; import.json "restoreWhites" làm đặc lại các lỗ kín đó, khe nền giữa tay / chân và thân
vẫn trong suốt). Ảnh chạy chưa vẽ bình nước sau lưng (ảnh quỳ và ảnh sảnh có).
- dáng đứng yên: ảnh riêng ../side_idle/idle_v1.png (chưa có: dùng frame_2.png, anims.idle.fallback)

Chạy (trong thư mục battle-squad-game):
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/import_frames.gd -- tide
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/carry_bob.gd

Cấu hình: import.json (mẫu chép từ Flora: height 64, walk 12 fps, canvas ghim). Hướng dẫn đủ:
assets/README.md, mục "Thêm ảnh góc ngang cho nhân vật" và "Tide's art".
