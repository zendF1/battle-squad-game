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
