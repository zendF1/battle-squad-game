extends RefCounted
## Vietnamese messages for failed API calls (Api results {ok, status, code, message}) and the
## display-name rule. Codes not listed fall back to "<action> thất bại: <server message>".

const MAX_NAME := 20 # characters; the server counts runes and trims

const OFFLINE := "Không kết nối được server, hãy thử lại"

const PURCHASE := {
	"SHOP_ITEM_OUT_OF_STOCK": "Đã hết lượt mua",
	"SHOP_ALREADY_OWNED": "Bạn đã có nhân vật này",
	"SHOP_OFFER_INACTIVE": "Gói này không còn bán",
}
const IAP := {
	"IAP_VERIFICATION_FAILED": "Giao dịch bị từ chối",
	"IAP_TRANSACTION_CONFLICT": "Giao dịch này đã được dùng cho gói khác",
	"IAP_PRODUCT_INACTIVE": "Gói này không còn bán",
	"IAP_STORE_NOT_CONFIGURED": "Chưa nạp được lúc này, hãy thử lại sau",
}
const STATS := {
	"CHARACTER_NOT_FOUND": "Bạn chưa sở hữu nhân vật này",
	"CHARACTER_INVALID_STATS": "Điểm cộng không hợp lệ",
	"CHARACTER_NO_STATS_ALLOCATED": "Chưa chọn điểm nào để cộng",
	"CHARACTER_INSUFFICIENT_STAT_POINTS": "Không đủ điểm tiềm năng",
	"CHARACTER_NO_STATS_TO_RESET": "Chưa có điểm nào để tẩy",
}
const EQUIP_BUY := {
	"EQUIP_NOT_FOUND": "Trang bị này không còn bán",
	"BAD_REQUEST": "Yêu cầu mua không hợp lệ",
	"IDEMPOTENCY_KEY_REUSED": "Giao dịch bị trùng, hãy thử lại",
}
const EQUIP := {
	"EQUIP_ALREADY_EQUIPPED": "Trang bị đang được nhân vật khác mặc",
	"EQUIP_NOT_EQUIPPED": "Trang bị chưa được mặc",
	"EQUIP_LEVEL_REQUIRED": "Nhân vật chưa đủ cấp để mặc",
	"EQUIP_WRONG_CHARACTER": "Trang bị không dành cho nhân vật này",
	"EQUIP_NOT_OWNED": "Bạn không sở hữu trang bị này",
	"EQUIP_NOT_FOUND": "Không tìm thấy trang bị",
	"CHARACTER_NOT_FOUND": "Bạn chưa sở hữu nhân vật này",
	"EQUIP_SLOT_OCCUPIED": "Ô này đã có trang bị, hãy tháo ra trước",
	"EQUIP_MODIFIED": "Trang bị vừa được thay đổi, hãy thử lại",
	"EQUIP_EQUIPPED": "Trang bị đang được mặc, hãy tháo ra trước",
	"EQUIP_LOCKED": "Trang bị đang bị khoá",
	"EQUIP_MAX_UPGRADE": "Trang bị đã cường hoá tối đa",
	"EQUIP_NO_STONES": "Chưa chọn đá cường hoá",
	"EQUIP_INSUFFICIENT_STONES": "Không đủ đá cường hoá",
	"EQUIP_INSUFFICIENT_MATERIALS": "Không đủ nguyên liệu",
	"EQUIP_GEM_SLOT_INVALID": "Ô ngọc không hợp lệ",
	"EQUIP_GEM_NOT_OWNED": "Bạn không sở hữu viên ngọc này",
}
## POST /player/equipment/sell and dismantle ("Vứt"); other codes as EQUIP.
const EQUIP_REMOVE := {
	"EQUIP_NOT_SELLABLE": "Trang bị này không bán được, chỉ vứt được",
	"EQUIP_LOCKED": "Trang bị đã từng mặc nên không bán được, chỉ vứt được",
	"EQUIP_EQUIPPED": "Trang bị đang được mặc, hãy tháo ra trước",
	"EQUIP_NOT_OWNED": "Trang bị không còn trong túi",
}

## POST /player/equipment/upgrade; other codes as EQUIP.
const UPGRADE := {
	"EQUIP_MAX_UPGRADE": "Trang bị đã đạt +16, không nâng cấp thêm được",
	"EQUIP_NO_STONES": "Chưa chọn đá nâng cấp",
	"EQUIP_INSUFFICIENT_STONES": "Không đủ đá nâng cấp, hãy chọn lại",
	"EQUIP_MODIFIED": "Trang bị vừa được nâng cấp ở nơi khác, hãy thử lại",
	"EQUIP_NOT_OWNED": "Trang bị không còn trong túi",
	"NOT_FOUND": "Loại đá này không tồn tại",
	"EQUIP_CAREFUL_UNAVAILABLE": "Cấp này không có Nâng cấp cẩn thận",
	"SHOP_INSUFFICIENT_BALANCE": "Không đủ kim cương cho Nâng cấp cẩn thận",
}
## POST /shop/stones/buy.
const STONE_BUY := {
	"BAD_REQUEST": "Đá này không bán, chỉ ghép được",
	"NOT_FOUND": "Đá này không còn bán",
	"IDEMPOTENCY_KEY_REUSED": "Giao dịch bị trùng, hãy thử lại",
}
## POST /merge/stone.
const MERGE := {
	"MERGE_MIN_COUNT": "Cần bỏ vào ít nhất 2 viên",
	"MERGE_MAX_COUNT": "Chỉ bỏ vào tối đa 4 viên",
	"MERGE_MAX_LEVEL": "Đá cấp 12 là cao nhất, không ghép tiếp được",
	"EQUIP_INSUFFICIENT_STONES": "Không đủ đá để ghép",
}


## POST /shop/purchase failure. currency is the offer's priceCurrency ("coin" | "gem").
static func purchase(res: Dictionary, currency: String = "") -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	var code := str(res.get("code", ""))
	if code == "SHOP_INSUFFICIENT_BALANCE":
		match currency:
			"coin": return "Không đủ xu"
			"gem": return "Không đủ kim cương"
		return "Không đủ xu/kim cương"
	return PURCHASE.get(code, "Mua thất bại: %s" % res.get("message", ""))


## POST /shop/equipment/buy failure. currency is what the item costs ("coin" | "gem").
static func equipment_buy(res: Dictionary, currency: String = "") -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	var code := str(res.get("code", ""))
	if code == "SHOP_INSUFFICIENT_BALANCE":
		return purchase(res, currency)
	return EQUIP_BUY.get(code, "Mua thất bại: %s" % res.get("message", ""))


## POST /player/equipment/equip or unequip failure.
static func equip(res: Dictionary) -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return EQUIP.get(str(res.get("code", "")), "Thao tác thất bại: %s" % res.get("message", ""))


## POST /player/equipment/sell (sell = true) or dismantle failure, or the unequip before it.
static func equipment_remove(res: Dictionary, sell: bool) -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	var code := str(res.get("code", ""))
	if EQUIP_REMOVE.has(code):
		return EQUIP_REMOVE[code]
	if EQUIP.has(code):
		return EQUIP[code]
	return "%s thất bại: %s" % ["Bán" if sell else "Vứt", res.get("message", "")]


## POST /iap/verify failure.
static func iap(res: Dictionary) -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return IAP.get(str(res.get("code", "")), "Nạp thất bại: %s" % res.get("message", ""))


## POST /player/character/allocate-stats or reset-stats failure. currency is the reset fee's.
static func stats(res: Dictionary, currency: String = "coin") -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	if str(res.get("code", "")) == "CHARACTER_INSUFFICIENT_BALANCE":
		return "Không đủ %s để tẩy điểm" % ("kim cương" if currency == "gem" else "xu")
	return STATS.get(str(res.get("code", "")), "Thao tác thất bại: %s" % res.get("message", ""))


## PUT /player/profile failure. PLAYER_UPDATE_FAILED carries the reason in English.
static func rename(res: Dictionary) -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	var message := str(res.get("message", ""))
	if str(res.get("code", "")) == "PLAYER_UPDATE_FAILED":
		if message.contains("empty"):
			return "Tên không được để trống"
		if message.contains("too long"):
			return "Tên tối đa %d ký tự" % MAX_NAME
	return "Đổi tên thất bại: %s" % message


## A GET that failed: shown next to "Thử lại".
static func load_failed(res: Dictionary) -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return "Không tải được dữ liệu (%s)" % res.get("message", "")


## The problem with a display name before it is sent (trimmed like the server), or "".
static func name_problem(raw: String) -> String:
	var name := raw.strip_edges()
	if name == "":
		return "Tên không được để trống"
	if name.length() > MAX_NAME:
		return "Tên tối đa %d ký tự" % MAX_NAME
	return ""


## POST /player/equipment/upgrade failure.
static func upgrade(res: Dictionary) -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	var code := str(res.get("code", ""))
	if UPGRADE.has(code):
		return UPGRADE[code]
	return EQUIP.get(code, "Nâng cấp thất bại: %s" % res.get("message", ""))


## POST /shop/stones/buy failure. currency is what the stone costs ("coin" | "gem").
static func stone_buy(res: Dictionary, currency: String = "") -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	var code := str(res.get("code", ""))
	if code == "SHOP_INSUFFICIENT_BALANCE":
		return purchase(res, currency)
	return STONE_BUY.get(code, "Mua đá thất bại: %s" % res.get("message", ""))


## POST /merge/stone failure.
static func merge(res: Dictionary) -> String:
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return MERGE.get(str(res.get("code", "")), "Ghép đá thất bại: %s" % res.get("message", ""))
