extends "res://tests/test_case.gd"

const Uuid := preload("res://core/uuid.gd")
const Envelope := preload("res://core/envelope.gd")
const ApiResponse := preload("res://core/api_response.gd")


func test_uuid_v4_format() -> void:
	var re := RegEx.new()
	re.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	var a := Uuid.v4()
	check(re.search(a) != null, "uuid %s is not v4" % a)
	check(a != Uuid.v4(), "two uuids are equal")


func test_envelope_round_trip() -> void:
	var msg := Envelope.decode(Envelope.encode("Move", {"targetX": 12.5}))
	eq(msg.get("event"), "Move", "event")
	eq(msg.get("data", {}).get("targetX"), 12.5, "data.targetX")


func test_envelope_rejects_garbage() -> void:
	eq(Envelope.decode("not json"), {}, "non-json")
	eq(Envelope.decode("{\"data\": 1}"), {}, "missing event")


func test_api_unwraps_success_envelope() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 200,
		"{\"success\":true,\"data\":{\"a\":1}}".to_utf8_buffer())
	check(res.ok, "ok")
	eq(res.data.get("a"), 1.0, "data.a")


func test_api_accepts_plain_body() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 200, "{\"x\":2}".to_utf8_buffer())
	check(res.ok, "ok")
	eq(res.data.get("x"), 2.0, "data.x")


func test_api_maps_error_envelope() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 409,
		"{\"success\":false,\"error\":{\"code\":\"ROOM_FULL\",\"message\":\"full\"}}".to_utf8_buffer())
	check(not res.ok, "not ok")
	eq(res.status, 409, "status")
	eq(res.code, "ROOM_FULL", "code")
	eq(res.message, "full", "message")


func test_api_maps_network_error() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
	check(not res.ok, "not ok")
	eq(res.status, 0, "status")
	eq(res.code, "NETWORK_ERROR", "code")


func test_refresh_outcome_clears_session_only_when_server_rejects_token() -> void:
	var ok := {"ok": true, "status": 200, "data": {"accessToken": "a", "refreshToken": "r"}}
	eq(ApiResponse.refresh_outcome(ok), ApiResponse.REFRESH_OK, "200 with token")
	eq(ApiResponse.refresh_outcome({"ok": true, "status": 200, "data": {}}), ApiResponse.REFRESH_FAILED, "200 without token")
	for status in [400, 401, 403]:
		eq(ApiResponse.refresh_outcome({"ok": false, "status": status, "data": null}), ApiResponse.REFRESH_REJECTED, "status %d" % status)
	for status in [0, 404, 408, 429, 500, 503]:
		eq(ApiResponse.refresh_outcome({"ok": false, "status": status, "data": null}), ApiResponse.REFRESH_FAILED, "status %d" % status)
