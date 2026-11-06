# Client: rương boss v2 và xác suất cường hóa v2

Ghi chú riêng của client. Quy tắc và trường dữ liệu nằm ở server: đặc tả
`../battle-squad/docs/specs/2026-11-06-dieu-chinh-kinh-te-boss-va-cuong-hoa.vi.md`, hợp đồng
`docs/contracts/boss-chests-upgrade-v2.md` (nhánh `feat/boss-chests-upgrade-v2`). Client không tự
tính quyền nhận rương, không giữ bảng rơi, không giữ số phần trăm tối đa.

## Trang Nâng cấp

`screens/home/upgrade_model.gd`, `screens/home/upgrade_page.gd`.

- `UpgradeModel.chance()` chép đúng phép tính của server bằng số nguyên, đơn vị basis point:
  `stone_bp = floor(min(P, C) × maxPercentBp / C)`, cẩn thận
  `final_bp = min(10000, floor(stone_bp × (10000 + carefulBonusBp) / 10000))`.
  C là `effectiveRequiredPower[slot]`, đã gồm hệ số vũ khí, không nhân lại.
- `UpgradeModel.bp_text()` in chính xác, không làm tròn lên: 16%, 20,8%, 39,99%.
- Catalog không có `probabilityFormulaVersion` (server cũ) chạy công thức 1 qua cùng giao diện.
- Cột phải, từ trên xuống: danh sách đá (Tự chọn / Bỏ chọn nằm trên tiêu đề để nhường chỗ), thanh
  nạp, hai ô tỉ lệ, nút NÂNG CẤP.
- Thanh nạp chỉ nói về sức mạnh: `3.600 / 9.000`, `Đã nạp 40%`. Vàng khi đang nạp, xanh khi đủ, cam
  khi còn thừa nguyên một viên đá. Dòng dưới thanh báo phần thừa.
- Hai ô tỉ lệ đối xứng nhau: Tỉ lệ thường và Tỉ lệ cẩn thận, mỗi ô có mức tối đa. Ô được chọn là tỉ lệ
  sẽ quay, chạm ô kia để đổi. Bước không có cẩn thận chỉ còn một ô, chiếm cả hàng.
- Đá yếu đến mức `final_bp` = 0: nút tắt, dòng lý do "Đá quá yếu, hãy nạp thêm".
- Nạp thừa nguyên viên đá: bấm NÂNG CẤP hiện popup xác nhận (gộp với xác nhận kim cương của cẩn
  thận). Phần thừa nhỏ hơn một viên thì chỉ hiện dòng chữ mờ, không hỏi, vì không bỏ được viên nào.

## Ba rương đá

`ui/chest_icon.gd` (`CHEST_LOOKS`), `ui/reward_box.gd`, `ui/reward_model.gd` (`CHEST_GLOWS`).

- Chưa có ảnh thật: cả rương trong kho, ô thưởng và rương mở trong `ui/reward_reveal.gd` đều vẽ bằng
  code. Đồng: thân đồng đỏ, đai tối, ngọc xanh ngọc. Bạc: thân thép sáng, đai tối, viền nắp, ngọc xanh
  lơ. Vàng: thân vàng, ngọc đỏ, viền nắp, sao trên nắp. Hình khác nhau, không chỉ khác màu.
- `stone_chest` cũ giữ nguyên hình gỗ sồi đai sắt. Id lạ về hình rương đá thường.
- Khi có ảnh: thay trong `ChestIcon._draw()` và `RewardBox` (nắp vẽ riêng vì reveal hất nắp đi), hoặc
  tách ảnh thân / nắp. Mô tả cho người vẽ, nguyên bản, không sao chép game khác:
  `rương báu hoạt hình nhìn thẳng, nét viền đậm, nắp vòm; đồng đỏ đai nâu tối ngọc xanh ngọc / thép
  bạc sáng đai xanh thép ngọc xanh lơ / vàng ròng viền sáng ngọc đỏ, sao trên nắp; nền trong suốt`.

## Boss

`ui/boss_trail_model.gd`, `ui/boss_trail.gd`, `screens/home/boss_card_model.gd`,
`screens/home/mode_select.gd`, `screens/home/lobby.gd`, `match/boss/boss_result_screen.gd`.

- Vệt ba lượt: mỗi pip một lượt (xanh có dấu tích là thắng, đỏ có dấu nhân là thua, vòng rỗng là chưa
  đánh), mũi tên, rồi rương vàng. Rương sáng khi còn cơ hội, xám khi đã mất, sáng kèm dấu tích khi đã
  nhận. Dùng chung cho thẻ boss, thẻ chế độ ở sảnh và màn kết quả.
- Trạng thái rương vàng chỉ đọc `perfectRewardEligible` và `perfectRewardGranted` của server.
- Server chỉ gửi số đếm, không gửi thứ tự lượt, nên pip thắng luôn vẽ trước pip thua.
- `rewardVersion` 1, thiếu hoặc 0: giữ giao diện cũ, hộp quà và "×2".
- Nút "i" của thẻ boss (rules 2) có hàng hình: thắng ra bạc, đủ thắng ra vàng, thua ra đồng, lấy từ
  `chestsV2` của game data.
- Màn kết quả: vệt thay hộp quà, pip của lượt vừa đánh nảy vào, thắng lần ba thì rương vàng nảy theo,
  hai ô rương bạc và vàng nằm cạnh nhau.
- `GET /boss/runs` không được giữ qua `resetAt`: `PlayerState` đổi `resetAt` thành mốc tick đơn điệu
  lúc nhận câu trả lời, nên đồng hồ máy lệch không gây tải lại liên tục.
