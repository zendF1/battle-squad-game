extends "res://tests/test_case.gd"

const ErrorText := preload("res://screens/home/error_text.gd")


static func _err(status: int, code: String, message: String = "x") -> Dictionary:
	return {"ok": false, "status": status, "code": code, "message": message, "data": null}


func test_purchase_messages() -> void:
	eq(ErrorText.purchase(_err(400, "SHOP_INSUFFICIENT_BALANCE"), "coin"), "Không đủ xu", "coin")
	eq(ErrorText.purchase(_err(400, "SHOP_INSUFFICIENT_BALANCE"), "gem"), "Không đủ kim cương", "gem")
	eq(ErrorText.purchase(_err(400, "SHOP_INSUFFICIENT_BALANCE")), "Không đủ xu/kim cương", "unknown currency")
	eq(ErrorText.purchase(_err(409, "SHOP_ITEM_OUT_OF_STOCK")), "Đã hết lượt mua", "limit")
	eq(ErrorText.purchase(_err(409, "SHOP_ALREADY_OWNED")), "Bạn đã có nhân vật này", "owned")
	eq(ErrorText.purchase(_err(404, "SHOP_OFFER_INACTIVE")), "Gói này không còn bán", "inactive")
	eq(ErrorText.purchase(_err(500, "INTERNAL_SERVER_ERROR", "boom")), "Mua thất bại: boom", "other")
	eq(ErrorText.purchase(_err(0, "NETWORK_ERROR")), ErrorText.OFFLINE, "offline")


func test_iap_and_stats_messages() -> void:
	eq(ErrorText.iap(_err(400, "IAP_VERIFICATION_FAILED")), "Giao dịch bị từ chối", "rejected")
	eq(ErrorText.iap(_err(503, "IAP_STORE_NOT_CONFIGURED")), "Chưa nạp được lúc này, hãy thử lại sau", "store")
	eq(ErrorText.iap(_err(409, "WHATEVER", "m")), "Nạp thất bại: m", "other")
	eq(ErrorText.stats(_err(400, "CHARACTER_INSUFFICIENT_BALANCE")), "Không đủ xu để tẩy điểm", "reset fee")
	eq(ErrorText.stats(_err(400, "CHARACTER_INSUFFICIENT_BALANCE"), "gem"), "Không đủ kim cương để tẩy điểm", "gem reset fee")
	eq(ErrorText.stats(_err(400, "CHARACTER_NO_STATS_TO_RESET")), "Chưa có điểm nào để tẩy", "nothing to reset")
	eq(ErrorText.stats(_err(400, "CHARACTER_INSUFFICIENT_STAT_POINTS")), "Không đủ điểm tiềm năng", "points")
	eq(ErrorText.stats(_err(400, "BAD_REQUEST", "Invalid parameters")), "Thao tác thất bại: Invalid parameters", "other")
	eq(ErrorText.load_failed(_err(500, "X", "HTTP 500")), "Không tải được dữ liệu (HTTP 500)", "load")
	eq(ErrorText.load_failed(_err(0, "AUTH_REFRESH_FAILED")), ErrorText.OFFLINE, "load offline")


func test_rename_messages_and_rule() -> void:
	eq(ErrorText.rename(_err(400, "PLAYER_UPDATE_FAILED", "display name cannot be empty")), "Tên không được để trống", "empty")
	eq(ErrorText.rename(_err(400, "PLAYER_UPDATE_FAILED", "display name is too long")), "Tên tối đa 20 ký tự", "long")
	eq(ErrorText.rename(_err(400, "BAD_REQUEST", "Invalid parameters")), "Đổi tên thất bại: Invalid parameters", "other")
	eq(ErrorText.name_problem("   "), "Tên không được để trống", "blank")
	eq(ErrorText.name_problem("  Nguyễn Văn Anh Hùng  "), "", "19 runes after trim")
	eq(ErrorText.name_problem("Nguyễn Văn Anh Hùng Mạnh"), "Tên tối đa 20 ký tự", "too long")


func test_equipment_messages() -> void:
	eq(ErrorText.equipment_buy(_err(400, "SHOP_INSUFFICIENT_BALANCE"), "coin"), "Không đủ xu", "coin")
	eq(ErrorText.equipment_buy(_err(400, "SHOP_INSUFFICIENT_BALANCE"), "gem"), "Không đủ kim cương", "gem")
	eq(ErrorText.equipment_buy(_err(404, "EQUIP_NOT_FOUND")), "Trang bị này không còn bán", "not sold")
	eq(ErrorText.equipment_buy(_err(409, "IDEMPOTENCY_KEY_REUSED")), "Giao dịch bị trùng, hãy thử lại", "key reused")
	eq(ErrorText.equipment_buy(_err(500, "X", "boom")), "Mua thất bại: boom", "other")
	eq(ErrorText.equipment_buy(_err(0, "NETWORK_ERROR")), ErrorText.OFFLINE, "offline")
	eq(ErrorText.equip(_err(400, "EQUIP_LEVEL_REQUIRED")), "Nhân vật chưa đủ cấp để mặc", "level")
	eq(ErrorText.equip(_err(409, "EQUIP_ALREADY_EQUIPPED")), "Trang bị đang được nhân vật khác mặc", "worn")
	eq(ErrorText.equip(_err(400, "EQUIP_WRONG_CHARACTER")), "Trang bị không dành cho nhân vật này", "wrong character")
	eq(ErrorText.equip(_err(404, "CHARACTER_NOT_FOUND")), "Bạn chưa sở hữu nhân vật này", "character")
	eq(ErrorText.equip(_err(403, "EQUIP_NOT_OWNED")), "Bạn không sở hữu trang bị này", "not owned")
	eq(ErrorText.equip(_err(409, "EQUIP_NOT_EQUIPPED")), "Trang bị chưa được mặc", "not worn")
	eq(ErrorText.equip(_err(500, "X", "m")), "Thao tác thất bại: m", "other")
	eq(ErrorText.equip(_err(0, "NETWORK_ERROR")), ErrorText.OFFLINE, "offline")
	eq(ErrorText.equip(_err(409, "EQUIP_SLOT_OCCUPIED")), "Ô này đã có trang bị, hãy tháo ra trước", "slot occupied")
	eq(ErrorText.equip(_err(409, "EQUIP_MODIFIED")), "Trang bị vừa được thay đổi, hãy thử lại", "modified")
	eq(ErrorText.equip(_err(409, "EQUIP_EQUIPPED")), "Trang bị đang được mặc, hãy tháo ra trước", "equipped")
	for code in ["EQUIP_LOCKED", "EQUIP_MAX_UPGRADE", "EQUIP_NO_STONES", "EQUIP_INSUFFICIENT_STONES", "EQUIP_INSUFFICIENT_MATERIALS", "EQUIP_GEM_SLOT_INVALID", "EQUIP_GEM_NOT_OWNED"]:
		check(not ErrorText.equip(_err(400, code)).begins_with("Thao tác thất bại"), code + " mapped")
