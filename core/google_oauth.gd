extends RefCounted
## Google sign-in without the Google SDK (spec 2026-10-30-settings-account-link): OAuth 2.0
## authorization code with PKCE (S256) for Google's iOS-type client IDs, which have no client secret.
## The page opens in ASWebAuthenticationSession (core/web_auth_native.gd) and comes back on
## `<reversed client id>:/oauth2redirect`; the code is exchanged at the token endpoint for the
## `id_token` the server checks (POST /auth/link-provider, /auth/provider-login). Pure functions:
## core/google_sign_in.gd runs the flow.

const AUTH_ENDPOINT := "https://accounts.google.com/o/oauth2/v2/auth"
const TOKEN_ENDPOINT := "https://oauth2.googleapis.com/token"
const SCOPE := "openid email"
const CLIENT_SUFFIX := ".apps.googleusercontent.com"
const SCHEME_PREFIX := "com.googleusercontent.apps."
## The project settings holding each platform's client ID (client config, not game data).
const CLIENT_ID_SETTINGS := {
	"iOS": "battle_squad/google_client_id_ios",
	"macOS": "battle_squad/google_client_id_macos",
}

## parse_callback() outcomes.
const CALLBACK_CODE := "code"
const CALLBACK_CANCELLED := "cancelled"
const CALLBACK_ERROR := "error"


## The client ID for an OS name (OS.get_name()), "" where Google sign-in has no client (Windows, Linux…).
static func client_id_for(os_name: String) -> String:
	var key: String = CLIENT_ID_SETTINGS.get(os_name, "")
	return str(ProjectSettings.get_setting(key, "")).strip_edges() if key != "" else ""


## The reversed client ID: "com.googleusercontent.apps.<id>" for "<id>.apps.googleusercontent.com";
## "" for anything else.
static func callback_scheme(client_id: String) -> String:
	if not client_id.ends_with(CLIENT_SUFFIX) or client_id.length() == CLIENT_SUFFIX.length():
		return ""
	return SCHEME_PREFIX + client_id.trim_suffix(CLIENT_SUFFIX)


static func redirect_uri(client_id: String) -> String:
	var scheme := callback_scheme(client_id)
	return scheme + ":/oauth2redirect" if scheme != "" else ""


## Base64url without padding (RFC 4648 §5), as PKCE and OAuth state use.
static func base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


## A fresh code verifier: 32 random bytes → 43 characters of [A-Za-z0-9-_] (RFC 7636 §4.1).
static func new_verifier() -> String:
	return base64url(Crypto.new().generate_random_bytes(32))


## A fresh state value, checked on the way back.
static func new_state() -> String:
	return base64url(Crypto.new().generate_random_bytes(16))


## The S256 challenge of a verifier: base64url(SHA-256(ASCII(verifier))).
static func challenge(verifier: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(verifier.to_ascii_buffer())
	return base64url(h.finish())


## The authorization URL the sign-in sheet opens.
static func auth_url(client_id: String, code_challenge: String, state: String) -> String:
	return AUTH_ENDPOINT + "?" + query({
		"client_id": client_id,
		"redirect_uri": redirect_uri(client_id),
		"response_type": "code",
		"scope": SCOPE,
		"code_challenge": code_challenge,
		"code_challenge_method": "S256",
		"state": state,
		"prompt": "select_account",
	})


## "k=v&k2=v2", keys in the dictionary's order, values percent-encoded (also a form body).
static func query(fields: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in fields:
		parts.append("%s=%s" % [str(k).uri_encode(), str(fields[k]).uri_encode()])
	return "&".join(parts)


## The query of a URL as a dictionary (values decoded; "+" is a space); {} without one.
static func parse_query(url: String) -> Dictionary:
	var q := url.get_slice("#", 0)
	var at := q.find("?")
	if at < 0:
		return {}
	var out := {}
	for pair in q.substr(at + 1).split("&", false):
		var eq := pair.find("=")
		var k := pair if eq < 0 else pair.substr(0, eq)
		var v := "" if eq < 0 else pair.substr(eq + 1)
		out[k.replace("+", " ").uri_decode()] = v.replace("+", " ").uri_decode()
	return out


## Reads the redirect the sheet returned: {kind: CALLBACK_CODE, code} on success; CALLBACK_CANCELLED
## when the player declined on Google's page (access_denied); CALLBACK_ERROR otherwise (wrong
## redirect, state mismatch, Google's error), with `error` naming why.
static func parse_callback(url: String, client_id: String, expected_state: String) -> Dictionary:
	var want := redirect_uri(client_id)
	if want == "" or not url.begins_with(want):
		return {"kind": CALLBACK_ERROR, "error": "redirect"}
	var q := parse_query(url)
	if expected_state == "" or str(q.get("state", "")) != expected_state:
		return {"kind": CALLBACK_ERROR, "error": "state"}
	var err := str(q.get("error", ""))
	if err == "access_denied":
		return {"kind": CALLBACK_CANCELLED}
	if err != "":
		return {"kind": CALLBACK_ERROR, "error": err}
	var code := str(q.get("code", ""))
	if code == "":
		return {"kind": CALLBACK_ERROR, "error": "code"}
	return {"kind": CALLBACK_CODE, "code": code}


## The token request's form fields (no client secret: iOS-type clients have none).
static func token_form(client_id: String, code: String, verifier: String) -> Dictionary:
	return {
		"code": code,
		"client_id": client_id,
		"redirect_uri": redirect_uri(client_id),
		"grant_type": "authorization_code",
		"code_verifier": verifier,
	}


## The id_token of a token endpoint answer (HTTP status and body text), "" when there is none.
static func id_token_from(status: int, body: String) -> String:
	if status < 200 or status >= 300:
		return ""
	var json := JSON.new()
	if json.parse(body) != OK or not json.data is Dictionary:
		return ""
	var data: Dictionary = json.data
	if data.is_empty():
		return ""
	var token := str(data.get("id_token", ""))
	return token if token.count(".") == 2 else ""
