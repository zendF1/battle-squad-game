extends Node
## REST client for cmd/api. Adds the bearer token, unwraps the envelope (core/api_response.gd)
## and retries once after refreshing the token on 401. Concurrent 401s share one refresh, and a
## 401 for a request sent with a token that has since been replaced retries without refreshing.
## A 401 is returned to callers only when the session is really gone (no refresh token, or the
## server rejected it); a refresh that failed for network/server reasons is reported as
## AUTH_REFRESH_FAILED (status 0) and keeps the tokens, so callers show "retry", not Login.

signal _refresh_done(outcome: int)

const ApiResponse := preload("res://core/api_response.gd")
const TIMEOUT_SEC := 10.0

var _refreshing := false


func get_json(path: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, path)


## A public conditional GET (no token): sends If-None-Match: `etag` when it is not "" and adds
## the answer's ETag header ("" none) as `etag`. A 304 is {ok: true, status: 304, data: null}.
func get_cached(path: String, etag: String) -> Dictionary:
	var headers := PackedStringArray()
	if etag != "":
		headers.append("If-None-Match: " + etag)
	return await _send(HTTPClient.METHOD_GET, path, null, false, headers)


func post_json(path: String, body: Variant = {}) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, path, body)


func request(method: int, path: String, body: Variant = null, auth: bool = true, retry: bool = true) -> Dictionary:
	var sent_with := Session.access_token
	var res := await _send(method, path, body, auth)
	if res.status == 401 and auth and retry and Session.refresh_token != "":
		if Session.access_token != sent_with and Session.access_token != "":
			# A refresh finished while this request was in flight: just retry with the new token.
			return await _send(method, path, body, auth)
		match await refresh_tokens():
			ApiResponse.REFRESH_OK:
				res = await _send(method, path, body, auth)
			ApiResponse.REFRESH_FAILED:
				res = {"ok": false, "status": 0, "code": "AUTH_REFRESH_FAILED",
					"message": "không làm mới được phiên đăng nhập", "data": null}
			# REFRESH_REJECTED: refresh_tokens() cleared the session; the 401 stands.
	return res


## Exchanges the refresh token for new tokens. Returns an ApiResponse.REFRESH_* outcome; only
## REFRESH_REJECTED clears the session.
func refresh_tokens() -> int:
	if _refreshing:
		return await _refresh_done
	_refreshing = true
	var res := await _send(HTTPClient.METHOD_POST, "/auth/refresh", {"refreshToken": Session.refresh_token}, false)
	var outcome := ApiResponse.refresh_outcome(res)
	match outcome:
		ApiResponse.REFRESH_OK:
			Session.set_tokens(str(res.data["accessToken"]), str(res.data.get("refreshToken", Session.refresh_token)))
		ApiResponse.REFRESH_REJECTED:
			Session.clear_tokens()
	_refreshing = false
	_refresh_done.emit(outcome)
	return outcome


func _send(method: int, path: String, body: Variant, auth: bool, extra: PackedStringArray = PackedStringArray()) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json"])
	headers.append_array(extra)
	if auth and Session.access_token != "":
		headers.append("Authorization: Bearer " + Session.access_token)
	var text := "" if body == null else JSON.stringify(body)
	if req.request(Config.api_url + path, headers, method, text) != OK:
		req.queue_free()
		return ApiResponse.parse(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
	var result: Array = await req.request_completed
	req.queue_free()
	var res := ApiResponse.parse(result[0], result[1], result[3])
	res["etag"] = ApiResponse.header(result[2], "ETag")
	return res
