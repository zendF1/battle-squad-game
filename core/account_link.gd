extends RefCounted
## Linking a guest account to Google, and signing in with Google (contract
## ../battle-squad/docs/contracts/account-link.md). The Google part is core/google_sign_in.gd; then
## POST /auth/link-provider {provider, idToken} (the settings popup, screens/home/settings_popup.gd) or
## /auth/provider-login (the login screen). Results: {ok, cancelled, code, …}; a cancel shows nothing,
## any other failure the short toast of error_text(code). The profile's `linkedProviders` (empty: a
## guest) decides what the settings popup shows.

const GoogleSignIn := preload("res://core/google_sign_in.gd")

## Providers the settings popup offers, in its order.
const PROVIDERS := ["apple", "google"] # the login screen's order

## Short Vietnamese toasts by error code (server codes, then the Google sign-in's own).
const ERRORS := {
	"AUTH_PROVIDER_ALREADY_LINKED": "Tài khoản Google này đã thuộc người chơi khác",
	"AUTH_ACCOUNT_ALREADY_LINKED": "Tài khoản đã liên kết Google khác",
	"AUTH_PROVIDER_TOKEN_INVALID": "Đăng nhập Google không hợp lệ, thử lại nhé",
	"AUTH_PROVIDER_DISABLED": "Đăng nhập Google đang tạm đóng",
	"AUTH_PROVIDER_UNAVAILABLE": "Google đang bận, thử lại sau",
	"AUTH_ACCOUNT_BANNED": "Tài khoản đã bị khoá",
	"AUTH_FORBIDDEN": "Tài khoản không dùng được",
	"NETWORK_ERROR": "Mất kết nối",
	"AUTH_REFRESH_FAILED": "Mất kết nối",
	GoogleSignIn.UNAVAILABLE: "Sắp ra mắt",
	GoogleSignIn.SHEET_FAILED: "Không mở được trang Google",
	GoogleSignIn.CALLBACK_FAILED: "Đăng nhập Google không thành công",
	GoogleSignIn.TOKEN_FAILED: "Đăng nhập Google không thành công",
	GoogleSignIn.NETWORK: "Không kết nối được Google",
}
const FALLBACK := "Có lỗi, thử lại sau"


## The providers linked to the profile's account (known ones only, in PROVIDERS order).
static func linked_providers(profile: Variant) -> Array[String]:
	var out: Array[String] = []
	var raw = profile.get("linkedProviders") if profile is Dictionary else null
	if raw is Array:
		for p in PROVIDERS:
			if raw.has(p):
				out.append(p)
	return out


## A guest: no provider linked (also a profile from before the field existed).
static func is_guest(profile: Variant) -> bool:
	return linked_providers(profile).is_empty()


## The toast for a failed result; "" for a cancel (nothing shows).
static func error_text(result: Dictionary) -> String:
	if result.get("ok", false) or result.get("cancelled", false):
		return ""
	return ERRORS.get(str(result.get("code", "")), FALLBACK)


## Google sign-in, then the id_token linked to the signed-in account. {ok, linked_providers} or a
## failure. `api`: the Api autoload or a fake with post_json(path, body).
static func link_google(sign_in: RefCounted, api: Object) -> Dictionary:
	var g: Dictionary = await sign_in.sign_in()
	if not g.get("ok", false):
		return g
	var res: Dictionary = await api.post_json("/auth/link-provider", {"provider": "google", "idToken": g["id_token"]})
	if not res.get("ok", false):
		return {"ok": false, "cancelled": false, "code": str(res.get("code", ""))}
	return {"ok": true, "cancelled": false, "code": "", "linked_providers": linked_providers(res.get("data"))}


## Google sign-in, then POST /auth/provider-login (public). {ok, data: the login answer} or a failure.
## `api`: the Api autoload or a fake with request(method, path, body, auth, retry).
static func login_google(sign_in: RefCounted, api: Object) -> Dictionary:
	var g: Dictionary = await sign_in.sign_in()
	if not g.get("ok", false):
		return g
	var res: Dictionary = await api.request(HTTPClient.METHOD_POST, "/auth/provider-login",
		{"provider": "google", "idToken": g["id_token"]}, false, false)
	var d = res.get("data")
	if res.get("ok", false) and d is Dictionary and str(d.get("accessToken", "")) != "" and str(d.get("playerId", "")) != "":
		return {"ok": true, "cancelled": false, "code": "", "data": d}
	return {"ok": false, "cancelled": false, "code": str(res.get("code", "")) if not res.get("ok", false) else "BAD_RESPONSE"}
