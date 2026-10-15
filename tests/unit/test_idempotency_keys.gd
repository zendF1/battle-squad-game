extends "res://tests/test_case.gd"

const IdempotencyKeys := preload("res://core/idempotency_keys.gd")
const TMP := "user://test_idempotency_keys.cfg"


func test_key_kept_until_definite_answer() -> void:
	var keys := IdempotencyKeys.new()
	var k := keys.key_for("p1/offer_a")
	eq(keys.key_for("p1/offer_a"), k, "same key while pending")
	check(k != keys.key_for("p1/offer_b"), "one key per offer")
	check(k.length() <= 64, "fits the server limit")
	check(not keys.settle("p1/offer_a", 0), "network error keeps it")
	check(not keys.settle("p1/offer_a", 500), "5xx keeps it")
	check(not keys.settle("p1/offer_a", 503), "503 keeps it")
	eq(keys.key_for("p1/offer_a"), k, "retry reuses it")
	check(keys.settle("p1/offer_a", 200), "2xx drops it")
	check(not keys.has_key("p1/offer_a"), "gone")
	check(keys.key_for("p1/offer_a") != k, "next purchase gets a new key")


func test_4xx_is_definite() -> void:
	var keys := IdempotencyKeys.new()
	for status in [400, 404, 409]:
		var k := keys.key_for("x")
		check(keys.settle("x", status), "%d drops it" % status)
		check(keys.key_for("x") != k, "%d: new key" % status)
	check(IdempotencyKeys.is_definite(201), "201")
	check(not IdempotencyKeys.is_definite(302), "302")
	check(not keys.settle("never", 200), "unknown id")


func test_prefix_and_persistence() -> void:
	DirAccess.remove_absolute(TMP)
	var tokens := IdempotencyKeys.new("mock_", TMP)
	var t := tokens.key_for("p1/gems_100")
	check(t.begins_with("mock_") and t.length() == 41, "mock_<uuid>: " + t)
	var reopened := IdempotencyKeys.new("mock_", TMP)
	eq(reopened.key_for("p1/gems_100"), t, "survives a restart")
	reopened.settle("p1/gems_100", 200)
	check(not IdempotencyKeys.new("mock_", TMP).has_key("p1/gems_100"), "drop is saved")
	DirAccess.remove_absolute(TMP)
