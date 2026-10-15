extends RefCounted
## Number and date text for the Vietnamese UI.


## 1250 → "1.250" (Vietnamese thousands separator).
static func thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## 12 → "+12", -8 → "-8", 0 → "0".
static func signed(n: int) -> String:
	return "+%d" % n if n > 0 else str(n)


## An RFC 3339 timestamp ("2026-10-15T08:05:09.123Z", "...+07:00"; no zone means UTC) as
## "dd/MM HH:mm" in the zone `bias_minutes` east of UTC (Time.get_time_zone_from_system().bias).
## "" when it cannot be parsed.
static func short_date(iso: String, bias_minutes: int) -> String:
	var re := RegEx.new()
	re.compile("^(\\d{4})-(\\d{2})-(\\d{2})[T ](\\d{2}):(\\d{2}):(\\d{2})(?:\\.\\d+)?(Z|[+-]\\d{2}:?\\d{2})?$")
	var m := re.search(iso.strip_edges())
	if m == null:
		return ""
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": int(m.get_string(1)), "month": int(m.get_string(2)), "day": int(m.get_string(3)),
		"hour": int(m.get_string(4)), "minute": int(m.get_string(5)), "second": int(m.get_string(6)),
	})
	var zone := m.get_string(7)
	if zone != "" and zone != "Z":
		var hm := zone.substr(1).replace(":", "")
		var offset := int(hm.substr(0, 2)) * 60 + int(hm.substr(2, 2))
		unix -= (offset if zone[0] == "+" else -offset) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias_minutes * 60)
	return "%02d/%02d %02d:%02d" % [d.day, d.month, d.hour, d.minute]
