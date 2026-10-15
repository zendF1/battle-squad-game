extends RefCounted
## Reads the `exp` claim of a JWT without verifying it (the server is the judge; the client only
## wants to know when to refresh).


## Returns the expiry as unix seconds, or 0 if the token is not a readable JWT with an exp.
static func expires_at(token: String) -> int:
	var parts := token.split(".")
	if parts.size() != 3:
		return 0
	var seg := parts[1]
	for i in seg.length():
		if not (seg[i] in "-_" or (seg[i] >= "0" and seg[i] <= "9") or (seg[i].to_lower() >= "a" and seg[i].to_lower() <= "z")):
			return 0
	if seg.length() % 4 == 1:
		return 0
	var b64 := seg.replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var parser := JSON.new() # parse() reports errors by return code; parse_string() logs them
	if parser.parse(Marshalls.base64_to_raw(b64).get_string_from_utf8()) != OK:
		return 0
	var json = parser.data
	if json is Dictionary and (json.get("exp") is float or json.get("exp") is int):
		return int(json["exp"])
	return 0


## True when the token is a JWT that expires within margin_sec (or already has).
static func expires_within(token: String, margin_sec: int) -> bool:
	var exp := expires_at(token)
	return exp > 0 and exp - int(Time.get_unix_time_from_system()) <= margin_sec
