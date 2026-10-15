extends "res://tests/test_case.gd"

const Fmt := preload("res://core/fmt.gd")


func test_thousands() -> void:
	eq(Fmt.thousands(0), "0", "0")
	eq(Fmt.thousands(300), "300", "300")
	eq(Fmt.thousands(1250), "1.250", "1250")
	eq(Fmt.thousands(1234567), "1.234.567", "millions")
	eq(Fmt.thousands(-5000), "-5.000", "negative")


func test_signed() -> void:
	eq(Fmt.signed(12), "+12", "positive")
	eq(Fmt.signed(-8), "-8", "negative")
	eq(Fmt.signed(0), "0", "zero")


func test_short_date() -> void:
	eq(Fmt.short_date("2026-10-15T08:05:09.123456Z", 0), "15/10 08:05", "UTC")
	eq(Fmt.short_date("2026-12-31T20:30:00Z", 420), "01/01 03:30", "crosses midnight")
	eq(Fmt.short_date("2026-10-15T15:05:00+07:00", 0), "15/10 08:05", "offset zone")
	eq(Fmt.short_date("2026-10-15T08:05:00-0230", 0), "15/10 10:35", "negative offset")
	eq(Fmt.short_date("2026-10-15T08:05:00", 60), "15/10 09:05", "no zone is UTC")
	eq(Fmt.short_date("yesterday", 0), "", "garbage")


func test_unix_time() -> void:
	eq(Fmt.unix_time("1970-01-01T00:01:00Z"), 60, "epoch + 1 min")
	eq(Fmt.unix_time("2026-10-15T15:05:00+07:00"), Fmt.unix_time("2026-10-15T08:05:00Z"), "offset")
	eq(Fmt.unix_time("2026-10-15T08:05:00.123456789Z"), Fmt.unix_time("2026-10-15T08:05:00Z"), "nanoseconds (Go time.Time)")
	eq(Fmt.unix_time("nope"), -1, "garbage")
