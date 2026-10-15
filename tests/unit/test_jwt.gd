extends "res://tests/test_case.gd"

const Jwt := preload("res://core/jwt.gd")


func _token(payload: Dictionary) -> String:
	var b64 := Marshalls.utf8_to_base64(JSON.stringify(payload)).replace("+", "-").replace("/", "_").rstrip("=")
	return "h.%s.s" % b64


func test_reads_exp() -> void:
	eq(Jwt.expires_at(_token({"exp": 1700000000, "sub": "a?>b"})), 1700000000, "exp")


func test_unreadable_tokens_have_no_expiry() -> void:
	eq(Jwt.expires_at(""), 0, "empty")
	eq(Jwt.expires_at("abc"), 0, "not a jwt")
	eq(Jwt.expires_at("a.!!!.c"), 0, "bad payload")
	eq(Jwt.expires_at(_token({"sub": "x"})), 0, "no exp")
	check(not Jwt.expires_within("new1", 30), "opaque token is never treated as expiring")


func test_expires_within_margin() -> void:
	var now := int(Time.get_unix_time_from_system())
	check(Jwt.expires_within(_token({"exp": now + 10}), 30), "10 s left")
	check(Jwt.expires_within(_token({"exp": now - 5}), 30), "already expired")
	check(not Jwt.expires_within(_token({"exp": now + 900}), 30), "15 min left")
