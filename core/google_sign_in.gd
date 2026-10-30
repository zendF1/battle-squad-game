extends RefCounted
## One Google sign-in (core/google_oauth.gd): PKCE verifier and state, the sign-in sheet
## (core/web_auth_native.gd), the redirect checked, the code exchanged at Google's token endpoint for
## the id_token. sign_in() → {ok: true, id_token} or {ok: false, cancelled, code}: `cancelled` (the
## sheet closed or Google's page declined) shows nothing; `code` is one of the GOOGLE_* below for
## core/account_link.gd's toast. The sheet and the HTTP POST are swappable so tests fake them.

const GoogleOAuth := preload("res://core/google_oauth.gd")
const WebAuthNative := preload("res://core/web_auth_native.gd")

const UNAVAILABLE := "GOOGLE_UNAVAILABLE" # no client ID or no sheet on this platform
const SHEET_FAILED := "GOOGLE_SHEET_FAILED" # the sheet could not open or broke
const CALLBACK_FAILED := "GOOGLE_CALLBACK_FAILED" # a redirect we did not ask for, or Google's error
const TOKEN_FAILED := "GOOGLE_TOKEN_FAILED" # the token endpoint refused or answered no id_token
const NETWORK := "GOOGLE_NETWORK" # the token endpoint unreachable
const TIMEOUT_SEC := 15.0

var client_id: String
## Object with run(url, scheme) -> {status, url, message} (WebAuthNative's statuses).
var web_auth: Object
## func(url: String, form_body: String) -> {ok: bool (reached the server), status: int, body: String}.
var post_form: Callable


func _init(id: String = "", sheet: Object = null, poster: Callable = Callable()) -> void:
	client_id = id
	web_auth = sheet if sheet != null else WebAuthNative.new()
	post_form = poster if poster.is_valid() else _http_post


## Google sign-in on this device: a client ID for this OS and the native sheet.
static func available() -> bool:
	return GoogleOAuth.client_id_for(OS.get_name()) != "" and WebAuthNative.available()


## The sign-in for this OS (its project-setting client ID, the native sheet, a real HTTP POST).
static func for_platform() -> RefCounted:
	return new(GoogleOAuth.client_id_for(OS.get_name()))


func sign_in() -> Dictionary:
	var scheme := GoogleOAuth.callback_scheme(client_id)
	if scheme == "":
		return _fail(UNAVAILABLE)
	var verifier := GoogleOAuth.new_verifier()
	var state := GoogleOAuth.new_state()
	var url := GoogleOAuth.auth_url(client_id, GoogleOAuth.challenge(verifier), state)
	var r: Dictionary = await web_auth.run(url, scheme)
	match int(r.get("status", WebAuthNative.FAILED)):
		WebAuthNative.CANCELLED:
			return {"ok": false, "cancelled": true, "code": ""}
		WebAuthNative.OK_STATUS:
			pass
		_:
			push_warning("Google sign-in sheet: %s" % r.get("message", ""))
			return _fail(UNAVAILABLE if str(r.get("message", "")) == "unavailable" else SHEET_FAILED)
	var cb := GoogleOAuth.parse_callback(str(r.get("url", "")), client_id, state)
	match cb["kind"]:
		GoogleOAuth.CALLBACK_CANCELLED:
			return {"ok": false, "cancelled": true, "code": ""}
		GoogleOAuth.CALLBACK_ERROR:
			push_warning("Google sign-in callback: %s" % cb.get("error", ""))
			return _fail(CALLBACK_FAILED)
	var form := GoogleOAuth.query(GoogleOAuth.token_form(client_id, cb["code"], verifier))
	var res: Dictionary = await post_form.call(GoogleOAuth.TOKEN_ENDPOINT, form)
	if not res.get("ok", false):
		return _fail(NETWORK)
	var token := GoogleOAuth.id_token_from(int(res.get("status", 0)), str(res.get("body", "")))
	if token == "":
		push_warning("Google token exchange: HTTP %d %s" % [int(res.get("status", 0)), str(res.get("body", "")).left(200)])
		return _fail(TOKEN_FAILED)
	return {"ok": true, "cancelled": false, "code": "", "id_token": token}


static func _fail(code: String) -> Dictionary:
	return {"ok": false, "cancelled": false, "code": code}


func _http_post(url: String, body: String) -> Dictionary:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	root.add_child(req)
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded", "Accept: application/json"])
	if req.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()
		return {"ok": false, "status": 0, "body": ""}
	var result: Array = await req.request_completed
	req.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "body": ""}
	return {"ok": true, "status": int(result[1]), "body": (result[3] as PackedByteArray).get_string_from_utf8()}
