extends RefCounted
## Turns an HTTPRequest result into {ok, status, code, message, data}. Success bodies use the
## server envelope {"success":true,"data":X} (data = X); errors use {"error":{"code","message"}}
## (and its "details" object, when it has one, as `details`).
## 304 Not Modified (a conditional GET: Api.get_cached()) is ok with no data.


static func parse(result: int, status: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "network error (%d)" % result, "data": null}

	var parsed = null
	if body.size() > 0:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			parsed = json.data

	if status == 304:
		return {"ok": true, "status": 304, "code": "", "message": "", "data": null}
	if status >= 200 and status < 300:
		var data = parsed
		if parsed is Dictionary and parsed.has("success"):
			data = parsed.get("data")
		return {"ok": true, "status": status, "code": "", "message": "", "data": data}

	var code := "SERVER_ERROR"
	var message := "HTTP %d" % status
	if parsed is Dictionary and parsed.get("error") is Dictionary:
		code = str(parsed["error"].get("code", code))
		message = str(parsed["error"].get("message", message))
		if parsed["error"].get("details") is Dictionary:
			return {"ok": false, "status": status, "code": code, "message": message, "data": null, "details": parsed["error"]["details"]}
	return {"ok": false, "status": status, "code": code, "message": message, "data": null}


## The value of a response header (name case-insensitive), "" when absent.
static func header(headers: PackedStringArray, header_name: String) -> String:
	var want := header_name.to_lower() + ":"
	for h in headers:
		if h.to_lower().begins_with(want):
			return h.substr(want.length()).strip_edges()
	return ""


const REFRESH_OK := 0
const REFRESH_REJECTED := 1 # the server says the refresh token is unusable: log in again
const REFRESH_FAILED := 2 # network, rate limit or server trouble: keep the tokens, retry later


## Classifies a parsed POST /auth/refresh response. Only 400/401/403 end the session (bad,
## expired, revoked or banned token); the server answers its own failures with 5xx and rate
## limiting with 429, which must not log the player out.
static func refresh_outcome(res: Dictionary) -> int:
	if res.get("ok", false):
		var data = res.get("data")
		if data is Dictionary and str(data.get("accessToken", "")) != "":
			return REFRESH_OK
		return REFRESH_FAILED
	if int(res.get("status", 0)) in [400, 401, 403]:
		return REFRESH_REJECTED
	return REFRESH_FAILED
