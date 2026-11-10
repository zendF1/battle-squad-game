extends RefCounted
## The chat and friends errors as short Vietnamese toasts (the server's codes: contracts chat.md,
## friends.md); the match chat's ChatError codes are the same as the REST ones.

const ErrorText := preload("res://screens/home/error_text.gd")

const CHAT := {
	"CHAT_RATE_LIMITED": "Gửi chậm lại chút nhé",
	"FORBIDDEN": "Bạn không thể nhắn ở đây lúc này",
	"BAD_REQUEST": "Tin nhắn không hợp lệ",
	"INTERNAL_SERVER_ERROR": "Server gặp lỗi, hãy thử lại",
}

## Friend actions: "request" (Kết bạn), "accept", "remove" (Xoá, Từ chối, Huỷ), "nickname".
const FRIEND := {
	"FRIEND_CONFLICT": "Đã là bạn hoặc đã có lời mời",
	"PLAYER_NOT_FOUND": "Không tìm thấy người chơi",
	"INTERNAL_SERVER_ERROR": "Server gặp lỗi, hãy thử lại",
}
const NOT_FOUND := {
	"accept": "Lời mời này không còn",
	"nickname": "Hai bạn không còn là bạn bè",
}
const BAD_REQUEST := {
	"nickname": "Biệt danh không hợp lệ",
}

const SENT := "Đã gửi lời mời kết bạn"
const ACCEPTED := "Đã thành bạn bè"


## A REST chat failure ({status, code, message}).
static func chat(res: Dictionary) -> String:
	if int(res.get("status", 0)) == 0:
		return ErrorText.OFFLINE
	return chat_code(str(res.get("code", "")))


## A chat error code (REST or the match's ChatError).
static func chat_code(code: String) -> String:
	return CHAT.get(code, "Gửi thất bại, hãy thử lại")


## A friends request failure for `action`.
static func friend(res: Dictionary, action: String) -> String:
	if int(res.get("status", 0)) == 0:
		return ErrorText.OFFLINE
	var code := str(res.get("code", ""))
	if code == "NOT_FOUND":
		return NOT_FOUND.get(action, "Không tìm thấy")
	if code == "BAD_REQUEST":
		return BAD_REQUEST.get(action, "Yêu cầu không hợp lệ")
	return FRIEND.get(code, "Thao tác thất bại, hãy thử lại")
