extends RefCounted
## Vietnamese messages for failed API calls (Api results {ok, status, code, message}) and the
## display-name rule. Codes not listed fall back to "<action> thất bại: <server message>".

const Items := preload("res://match/items.gd")
const GameData := preload("res://autoload/game_data_model.gd")

const MAX_NAME := 20 # characters; the server counts runes and trims

const OFFLINE := "Không kết nối được server, hãy thử lại"

const PURCHASE := {
	"SHOP_ITEM_OUT_OF_STOCK": "Đã hết lượt mua",
	"SHOP_ALREADY_OWNED": "Bạn đã có nhân vật này",
	"SHOP_OFFER_INACTIVE": "Gói này không còn bán",
}
const CHEST := {
	"CHEST_NOT_ENOUGH": "Không đủ rương để mở",
	"CHEST_UNKNOWN": "Rương này không còn",
	"BUSY": "Đang mở rương, chờ chút",
}
const SEASON_REWARD := {
	"SEASON_REWARD_ALREADY_CLAIMED": "Phần thưởng mùa này đã được nhận",
	"SEASON_REWARD_NOT_FOUND": "Không có phần thưởng mùa để nhận",
	"BUSY": "Đang nhận thưởng, chờ chút",
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

## POST /player/equipment/upgrade; other codes as EQUIP. {maxUpgradeLevel}, {mergeMinCount},
## {mergeMaxCount} and {maxStoneLevel} are the game data's equipment limits (limits()).
const UPGRADE := {
	"EQUIP_MAX_UPGRADE": "Trang bị đã đạt +{maxUpgradeLevel}, không nâng cấp thêm được",
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
	"MERGE_MIN_COUNT": "Cần bỏ vào ít nhất {mergeMinCount} viên",
	"MERGE_MAX_COUNT": "Chỉ bỏ vào tối đa {mergeMaxCount} viên",
	"MERGE_MAX_LEVEL": "Đá cấp {maxStoneLevel} là cao nhất, không ghép tiếp được",
	"EQUIP_INSUFFICIENT_STONES": "Không đủ đá để ghép",
}

## POST /milestones/claim and /milestones/claim-all.
const MILESTONE := {
	"MILESTONE_ALREADY_CLAIMED": "Mốc này đã nhận rồi",
	"MILESTONE_NOT_REACHED": "Chưa đạt mốc này",
	"NOT_FOUND": "Mốc thưởng này không còn",
	"BUSY": "Đang nhận thưởng, chờ chút",
}

## POST /missions/claim and /missions/chests/claim (Nhiệm Vụ Ngày).
const MISSION := {
	"MISSION_NOT_FOUND": "Nhiệm vụ này không còn",
	"MISSION_NOT_DONE": "Nhiệm vụ chưa hoàn thành",
	"MISSION_ALREADY_CLAIMED": "Nhiệm vụ này đã nhận rồi",
	"CHEST_NOT_FOUND": "Phần thưởng này không còn",
	"CHEST_LOCKED": "Chưa đủ năng động để nhận",
	"CHEST_ALREADY_CLAIMED": "Phần thưởng này đã nhận rồi",
	"BUSY": "Đang nhận thưởng, chờ chút",
}

## POST /player/titles/equip.
const TITLE := {
	"TITLE_NOT_OWNED": "Bạn chưa có danh hiệu này",
	"BAD_REQUEST": "Danh hiệu không hợp lệ",
	"BUSY": "Đang đổi danh hiệu, chờ chút",
}


## RoomError codes answering QuickPlay (LOADOUT_INVALID has its own texts, room_error()).
const ROOM := {
	"LOADOUT_INVALID": "Nhân vật hoặc vật phẩm không hợp lệ",
	"MATCH_START_FAILED": "Không tạo được trận, hãy thử lại",
	"INTERNAL_SERVER_ERROR": "Server gặp lỗi, hãy thử lại",
}


## A RoomError's data ({"error": {code, message}}, or an older flat {code?, message}) in
## Vietnamese. LOADOUT_INVALID carries the server's English reason (internal/game/room
## loadout.go, room.go reserveItemTx): the known ones are translated, naming the item; any other
## code falls back to the server message.
static func room_error(data: Variant) -> String:
	var err: Dictionary = {}
	if data is Dictionary:
		err = data["error"] if data.get("error") is Dictionary else data
	var code := str(err.get("code", ""))
	var message := str(err.get("message", ""))
	if code == "LOADOUT_INVALID":
		var m := RegEx.create_from_string("^You do not own item: (\\S+)").search(message)
		if m != null:
			return "Bạn chưa sở hữu vật phẩm %s" % Items.label(m.get_string(1))
		m = RegEx.create_from_string("^Only (\\d+) of item (\\S+) available").search(message)
		if m != null:
			return "Không đủ %s (còn %s)" % [Items.label(m.get_string(2)), m.get_string(1)]
		m = RegEx.create_from_string("^item (\\S+) can be brought at most (\\d+)").search(message)
		if m != null:
			return "Mỗi trận chỉ mang được %s %s" % [m.get_string(2), Items.label(m.get_string(1))]
		if message.begins_with("You do not own character"):
			return "Bạn chưa sở hữu nhân vật này"
		m = RegEx.create_from_string("^You can bring at most (\\d+) items").search(message)
		if m != null:
			return "Chỉ mang tối đa %s vật phẩm" % m.get_string(1)
		if message.begins_with("Unknown item"):
			return "Vật phẩm không hợp lệ"
		if message.begins_with("Unknown character"):
			return "Nhân vật không hợp lệ"
	if ROOM.has(code):
		return ROOM[code]
	return message if message != "" else "Lỗi phòng"


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
	if code == "SHOP_STACK_LIMIT": # the bag would pass the stack cap; details.maxQuantity still fit
		var details = res.get("details")
		var left := int(details.get("maxQuantity", 0)) if details is Dictionary else 0
		return "Kho đồ chỉ còn chỗ cho %d" % left if left > 0 else "Kho đồ đã đầy vật phẩm này"
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
		return limits(UPGRADE[code])
	return EQUIP.get(code, "Nâng cấp thất bại: %s" % res.get("message", ""))


## A message with the equipment limits filled in ({maxUpgradeLevel}, {mergeMinCount},
## {mergeMaxCount}, {maxStoneLevel}).
static func limits(text: String) -> String:
	return GameData.fill_template(text, {"maxUpgradeLevel": GameData.max_upgrade_level(),
		"mergeMinCount": GameData.merge_min_count(), "mergeMaxCount": GameData.merge_max_count(),
		"maxStoneLevel": GameData.max_stone_level()})


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
	return limits(MERGE.get(str(res.get("code", "")), "Ghép đá thất bại: %s" % res.get("message", "")))


## POST /milestones/claim or /milestones/claim-all failure.
static func milestone(res: Dictionary) -> String:
	var code := str(res.get("code", ""))
	if code == "BUSY":
		return MILESTONE[code]
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return MILESTONE.get(code, "Nhận thưởng thất bại: %s" % res.get("message", ""))


## POST /chests/open failure.
static func chest(res: Dictionary) -> String:
	var code := str(res.get("code", ""))
	if code == "BUSY":
		return CHEST[code]
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return CHEST.get(code, "Mở rương thất bại: %s" % res.get("message", ""))


## POST /rank/season-rewards/claim failure.
static func season_reward(res: Dictionary) -> String:
	var code := str(res.get("code", ""))
	if code == "BUSY":
		return SEASON_REWARD[code]
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return SEASON_REWARD.get(code, "Nhận thưởng mùa thất bại: %s" % res.get("message", ""))


## POST /player/titles/equip failure.
static func title(res: Dictionary) -> String:
	var code := str(res.get("code", ""))
	if code == "BUSY":
		return TITLE[code]
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return TITLE.get(code, "Đổi danh hiệu thất bại: %s" % res.get("message", ""))


## POST /missions/claim or /missions/chests/claim failure; other codes show the server message.
static func mission(res: Dictionary) -> String:
	var code := str(res.get("code", ""))
	if code == "BUSY":
		return MISSION[code]
	if int(res.get("status", 0)) == 0:
		return OFFLINE
	return MISSION.get(code, "Nhận thưởng thất bại: %s" % res.get("message", ""))


## Ranked lobby / queue errors: LobbyError {"error": {code, message}} (internal/game/lobby
## handler.go) and the lobby's own "Error" {code, message} (lobby.go, lower-case codes).
const LOBBY := {
	"ALREADY_IN_LOBBY": "Bạn vẫn đang ở trong một tổ đội khác",
	"IN_ROOM": "Bạn vẫn đang ở trong một phòng khác",
	"LOBBY_CREATE_FAILED": "Không tạo được tổ đội, hãy thử lại",
	"LOBBY_NOT_FOUND": "Tổ đội không còn tồn tại",
	"LOBBY_REQUIRED": "Tổ đội không còn tồn tại",
	"NOT_HOST": "Chỉ chủ tổ đội mới làm được việc này",
	"INVALID_STATUS": "Tổ đội đang bận, hãy thử lại",
	"QUEUE_FAILED": "Không vào được hàng chờ, hãy thử lại",
	"NOT_IN_QUEUE": "Không còn trong hàng chờ",
	"LOBBY_FULL": "Tổ đội đã đủ người",
	"PLAYER_OFFLINE": "Người chơi này không còn online",
	"PLAYER_BUSY": "Người chơi này đang bận",
	"INVITE_PENDING": "Đã mời người này, hãy chờ trả lời",
	"INVITE_EXPIRED": "Lời mời đã hết hạn",
	"INVALID_PAYLOAD": "Yêu cầu không hợp lệ",
	"MEMBER_NOT_READY": "Đồng đội chưa sẵn sàng",
	"INVALID_QUEUE": "Chế độ này chưa mở, hãy chọn chế độ khác",
	"PARTY_TOO_LARGE": "Đội đông hơn số người của chế độ này",
	"character_not_owned": "Bạn chưa sở hữu nhân vật này",
	"too_many_items": "Chỉ mang tối đa 3 vật phẩm",
	"item_not_owned": "Vật phẩm đã hết hoặc chưa sở hữu",
	"lobby_full": "Tổ đội đã đủ người",
	"lobby_not_open": "Tổ đội đang tìm trận",
}


## The code of a LobbyError / lobby Error payload ("" when none).
static func lobby_code(data: Variant) -> String:
	if not data is Dictionary:
		return ""
	var err: Dictionary = data["error"] if data.get("error") is Dictionary else data
	return str(err.get("code", ""))


## A LobbyError / lobby Error payload in Vietnamese; unknown codes show the server message.
static func lobby_error(data: Variant) -> String:
	var code := lobby_code(data)
	if code == "LOADOUT_INVALID": # the QuickPlay rules and reasons
		return room_error(data)
	if LOBBY.has(code):
		return LOBBY[code]
	var err: Dictionary = {}
	if data is Dictionary:
		err = data["error"] if data.get("error") is Dictionary else data
	var message := str(err.get("message", ""))
	return "Lỗi ghép trận: %s" % message if message != "" else "Lỗi ghép trận, hãy thử lại"
