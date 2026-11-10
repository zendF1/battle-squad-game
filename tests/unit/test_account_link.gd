extends "res://tests/test_case.gd"
## Google sign-in and account linking (spec 2026-10-30-settings-account-link, contract
## ../battle-squad/docs/contracts/account-link.md): PKCE, the URLs, the redirect parsing, the token
## exchange and the link / login with a faked sign-in sheet, Google token endpoint and server, the
## error toasts, and the settings popup's guest / linked states. The fakes answer at once, so the
## flows run to the end inside the test.

const GoogleOAuth := preload("res://core/google_oauth.gd")
const GoogleSignIn := preload("res://core/google_sign_in.gd")
const WebAuthNative := preload("res://core/web_auth_native.gd")
const AccountLink := preload("res://core/account_link.gd")
const SettingsPopup := preload("res://screens/home/settings_popup.gd")
const LoginButton := preload("res://ui/login_button.gd")
const GlyphIcon := preload("res://ui/glyph_icon.gd")
const Login := preload("res://screens/login.gd")

const IOS := "766073933747-o6hvrdm7gm1pm0t45h9f8009fbid28ju.apps.googleusercontent.com"
const MACOS := "766073933747-dsc8mca1ukqsqlk2v8faarr1md1jipj0.apps.googleusercontent.com"
const ID_TOKEN := "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjMifQ.c2ln"


## The sign-in sheet: remembers the URL, answers with `reply(state)`'s result.
class FakeSheet:
	extends RefCounted
	var url := ""
	var scheme := ""
	var reply: Callable

	func run(u: String, s: String) -> Dictionary:
		url = u
		scheme = s
		return reply.call(GoogleOAuth.parse_query(u).get("state", ""))


## The game server: records the request, answers `answer`.
class FakeApi:
	extends RefCounted
	var calls: Array = []
	var answer: Dictionary = {}

	func post_json(path: String, body: Variant = {}) -> Dictionary:
		calls.append({"path": path, "body": body, "auth": true})
		return answer

	func request(method: int, path: String, body: Variant = null, auth: bool = true, _retry: bool = true) -> Dictionary:
		calls.append({"path": path, "body": body, "auth": auth, "method": method})
		return answer


func _redirect(client_id: String, query: String) -> String:
	return GoogleOAuth.redirect_uri(client_id) + "?" + query


## A sign-in with a sheet that comes back with a code and a token endpoint that answers `token_res`;
## `posts` collects the token requests.
func _sign_in(token_res: Dictionary, posts: Array, sheet_reply: Callable = Callable()) -> Array:
	var sheet := FakeSheet.new()
	sheet.reply = sheet_reply if sheet_reply.is_valid() else func(state: String) -> Dictionary:
		return {"status": WebAuthNative.OK_STATUS, "url": _redirect(IOS, "state=%s&code=4%%2F0Ab_c&scope=email" % state), "message": ""}
	var poster := func(url: String, body: String) -> Dictionary:
		posts.append({"url": url, "body": body})
		return token_res
	return [GoogleSignIn.new(IOS, sheet, poster), sheet]


func test_pkce_challenge_matches_rfc_7636() -> void:
	eq(GoogleOAuth.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
		"RFC 7636 appendix B")
	var v := GoogleOAuth.new_verifier()
	eq(v.length(), 43, "32 random bytes → 43 characters")
	var re := RegEx.create_from_string("^[A-Za-z0-9_-]+$")
	check(re.search(v) != null, "verifier is base64url without padding: %s" % v)
	check(GoogleOAuth.new_verifier() != v, "a fresh verifier each time")
	check(GoogleOAuth.new_state() != GoogleOAuth.new_state(), "a fresh state each time")
	check(re.search(GoogleOAuth.new_state()) != null, "state is URL-safe")


func test_client_ids_and_redirects() -> void:
	eq(GoogleOAuth.client_id_for("iOS"), IOS, "iOS client ID from the project settings")
	eq(GoogleOAuth.client_id_for("macOS"), MACOS, "macOS client ID from the project settings")
	for os_name in ["Windows", "Linux", "Android", "Web"]:
		eq(GoogleOAuth.client_id_for(os_name), "", "%s has no client" % os_name)
	eq(GoogleOAuth.callback_scheme(IOS), "com.googleusercontent.apps.766073933747-o6hvrdm7gm1pm0t45h9f8009fbid28ju", "iOS scheme")
	eq(GoogleOAuth.redirect_uri(MACOS), "com.googleusercontent.apps.766073933747-dsc8mca1ukqsqlk2v8faarr1md1jipj0:/oauth2redirect",
		"macOS redirect")
	eq(GoogleOAuth.callback_scheme("not-a-client"), "", "no scheme for a bad ID")
	eq(GoogleOAuth.callback_scheme(".apps.googleusercontent.com"), "", "no scheme for an empty ID")


func test_auth_url() -> void:
	var url := GoogleOAuth.auth_url(IOS, "CHAL-_x", "st4te")
	check(url.begins_with("https://accounts.google.com/o/oauth2/v2/auth?"), "Google's authorization endpoint")
	var q := GoogleOAuth.parse_query(url)
	eq(q.get("client_id"), IOS, "client_id")
	eq(q.get("redirect_uri"), GoogleOAuth.redirect_uri(IOS), "redirect_uri")
	eq(q.get("response_type"), "code", "authorization code")
	eq(q.get("scope"), "openid email", "scope")
	eq(q.get("code_challenge"), "CHAL-_x", "challenge")
	eq(q.get("code_challenge_method"), "S256", "S256")
	eq(q.get("state"), "st4te", "state")
	check(url.contains("redirect_uri=com.googleusercontent.apps.") and url.contains("%3A%2Foauth2redirect"), "redirect encoded")
	check(url.contains("scope=openid%20email"), "scope encoded")


func test_callback_parsing() -> void:
	var ok := GoogleOAuth.parse_callback(_redirect(IOS, "state=abc&code=4%2F0AbC&scope=email+openid"), IOS, "abc")
	eq(ok, {"kind": GoogleOAuth.CALLBACK_CODE, "code": "4/0AbC"}, "a code, decoded")
	eq(GoogleOAuth.parse_callback(_redirect(IOS, "error=access_denied&state=abc"), IOS, "abc")["kind"],
		GoogleOAuth.CALLBACK_CANCELLED, "declined on Google's page = cancelled")
	var err := GoogleOAuth.parse_callback(_redirect(IOS, "error=invalid_request&state=abc"), IOS, "abc")
	eq([err["kind"], err["error"]], [GoogleOAuth.CALLBACK_ERROR, "invalid_request"], "Google's error")
	eq(GoogleOAuth.parse_callback(_redirect(IOS, "state=evil&code=x"), IOS, "abc")["error"], "state", "state mismatch")
	eq(GoogleOAuth.parse_callback(_redirect(IOS, "code=x"), IOS, "abc")["error"], "state", "state missing")
	eq(GoogleOAuth.parse_callback(_redirect(IOS, "code=x&state="), IOS, "")["error"], "state", "no expected state")
	eq(GoogleOAuth.parse_callback(_redirect(IOS, "state=abc"), IOS, "abc")["error"], "code", "no code")
	eq(GoogleOAuth.parse_callback(_redirect(MACOS, "state=abc&code=x"), IOS, "abc")["error"], "redirect", "another client's redirect")
	eq(GoogleOAuth.parse_callback("https://evil.example/?state=abc&code=x", IOS, "abc")["error"], "redirect", "a web URL")
	eq(GoogleOAuth.parse_callback(_redirect(IOS, "state=abc&code=x#frag"), IOS, "abc")["code"], "x", "fragment ignored")


func test_token_form_and_answer() -> void:
	var form := GoogleOAuth.token_form(IOS, "4/0Ab", "verif")
	eq(form, {"code": "4/0Ab", "client_id": IOS, "redirect_uri": GoogleOAuth.redirect_uri(IOS),
		"grant_type": "authorization_code", "code_verifier": "verif"}, "token request fields, no secret")
	check(not form.has("client_secret"), "no client secret")
	eq(GoogleOAuth.id_token_from(200, JSON.stringify({"access_token": "a", "id_token": ID_TOKEN})), ID_TOKEN, "the id_token")
	eq(GoogleOAuth.id_token_from(400, JSON.stringify({"error": "invalid_grant", "id_token": ID_TOKEN})), "", "an error status")
	eq(GoogleOAuth.id_token_from(200, JSON.stringify({"access_token": "a"})), "", "no id_token")
	eq(GoogleOAuth.id_token_from(200, "not json"), "", "not JSON")
	eq(GoogleOAuth.id_token_from(200, JSON.stringify({"id_token": "opaque"})), "", "not a JWT")


func test_sign_in_exchanges_the_code_with_the_verifier() -> void:
	var posts: Array = []
	var made := _sign_in({"ok": true, "status": 200, "body": JSON.stringify({"id_token": ID_TOKEN})}, posts)
	var r: Dictionary = await made[0].sign_in()
	eq(r.get("ok"), true, "signed in")
	eq(r.get("id_token"), ID_TOKEN, "the id_token")
	var sheet: FakeSheet = made[1]
	eq(sheet.scheme, GoogleOAuth.callback_scheme(IOS), "the sheet waits for the reversed client ID")
	eq(posts.size(), 1, "one token request")
	eq(posts[0]["url"], "https://oauth2.googleapis.com/token", "Google's token endpoint")
	var form := GoogleOAuth.parse_query("?" + str(posts[0]["body"]))
	eq(form.get("code"), "4/0Ab_c", "the code from the redirect")
	eq(form.get("grant_type"), "authorization_code", "grant type")
	eq(GoogleOAuth.challenge(str(form.get("code_verifier"))), GoogleOAuth.parse_query(sheet.url).get("code_challenge"),
		"the verifier matches the challenge sent")


func test_sign_in_failures() -> void:
	var posts: Array = []
	var cancel := func(_s: String) -> Dictionary: return {"status": WebAuthNative.CANCELLED, "url": "", "message": ""}
	var r: Dictionary = await _sign_in({}, posts, cancel)[0].sign_in()
	eq([r["ok"], r["cancelled"]], [false, true], "sheet closed: cancelled")
	var denied := func(s: String) -> Dictionary: return {"status": 0, "url": _redirect(IOS, "error=access_denied&state=" + s), "message": ""}
	r = await _sign_in({}, posts, denied)[0].sign_in()
	eq(r["cancelled"], true, "declined on Google's page: cancelled")
	var forged := func(_s: String) -> Dictionary: return {"status": 0, "url": _redirect(IOS, "state=forged&code=x"), "message": ""}
	r = await _sign_in({}, posts, forged)[0].sign_in()
	eq([r["cancelled"], r["code"]], [false, GoogleSignIn.CALLBACK_FAILED], "state mismatch refused")
	var broke := func(_s: String) -> Dictionary: return {"status": WebAuthNative.FAILED, "url": "", "message": "boom"}
	r = await _sign_in({}, posts, broke)[0].sign_in()
	eq(r["code"], GoogleSignIn.SHEET_FAILED, "the sheet failed")
	eq(posts.size(), 0, "no token request without a code")
	r = await _sign_in({"ok": false, "status": 0, "body": ""}, posts)[0].sign_in()
	eq(r["code"], GoogleSignIn.NETWORK, "token endpoint unreachable")
	r = await _sign_in({"ok": true, "status": 400, "body": "{\"error\":\"invalid_grant\"}"}, posts)[0].sign_in()
	eq(r["code"], GoogleSignIn.TOKEN_FAILED, "token refused")
	r = await GoogleSignIn.new("", FakeSheet.new()).sign_in()
	eq(r["code"], GoogleSignIn.UNAVAILABLE, "no client ID")


func test_link_google_posts_the_id_token() -> void:
	var api := FakeApi.new()
	api.answer = {"ok": true, "status": 200, "data": {"linkedProviders": ["google"]}}
	var r: Dictionary = await AccountLink.link_google(_sign_in({"ok": true, "status": 200, "body": JSON.stringify({"id_token": ID_TOKEN})}, [])[0], api)
	eq(r.get("ok"), true, "linked")
	eq(r.get("linked_providers"), ["google"] as Array[String], "the new providers")
	eq(api.calls.size(), 1, "one server call")
	eq(api.calls[0]["path"], "/auth/link-provider", "link endpoint")
	eq(api.calls[0]["body"], {"provider": "google", "idToken": ID_TOKEN}, "provider and id token")
	for code in ["AUTH_PROVIDER_ALREADY_LINKED", "AUTH_ACCOUNT_ALREADY_LINKED", "AUTH_PROVIDER_TOKEN_INVALID", "AUTH_PROVIDER_DISABLED",
			"AUTH_PROVIDER_UNAVAILABLE"]:
		api.answer = {"ok": false, "status": 409, "code": code, "data": null}
		r = await AccountLink.link_google(_sign_in({"ok": true, "status": 200, "body": JSON.stringify({"id_token": ID_TOKEN})}, [])[0], api)
		eq([r["ok"], r["code"]], [false, code], "%s passed on" % code)
		eq(AccountLink.error_text(r), AccountLink.ERRORS[code], "%s toast" % code)
	var cancel := func(_s: String) -> Dictionary: return {"status": WebAuthNative.CANCELLED, "url": "", "message": ""}
	var before := api.calls.size()
	r = await AccountLink.link_google(_sign_in({}, [], cancel)[0], api)
	eq(api.calls.size(), before, "a cancel never reaches the server")
	eq(AccountLink.error_text(r), "", "a cancel shows nothing")


func test_login_google_posts_provider_login() -> void:
	var api := FakeApi.new()
	api.answer = {"ok": true, "status": 200, "data": {"accessToken": "a", "refreshToken": "r", "playerId": "p", "displayName": "X", "level": 1}}
	var r: Dictionary = await AccountLink.login_google(_sign_in({"ok": true, "status": 200, "body": JSON.stringify({"id_token": ID_TOKEN})}, [])[0], api)
	eq(r.get("ok"), true, "signed in")
	eq(r["data"]["playerId"], "p", "the login answer")
	eq(api.calls[0]["path"], "/auth/provider-login", "provider login")
	eq(api.calls[0]["auth"], false, "public: no bearer token")
	eq(api.calls[0]["body"], {"provider": "google", "idToken": ID_TOKEN}, "provider and id token")
	api.answer = {"ok": false, "status": 403, "code": "AUTH_ACCOUNT_BANNED", "data": null}
	r = await AccountLink.login_google(_sign_in({"ok": true, "status": 200, "body": JSON.stringify({"id_token": ID_TOKEN})}, [])[0], api)
	eq(AccountLink.error_text(r), "Tài khoản đã bị khoá", "banned")
	api.answer = {"ok": true, "status": 200, "data": {}}
	r = await AccountLink.login_google(_sign_in({"ok": true, "status": 200, "body": JSON.stringify({"id_token": ID_TOKEN})}, [])[0], api)
	eq(r["ok"], false, "an answer without tokens is a failure")


func test_error_texts_are_short_vietnamese() -> void:
	for code in AccountLink.ERRORS:
		var t: String = AccountLink.ERRORS[code]
		check(t != "" and t.length() <= 48, "%s: a short toast (%s)" % [code, t])
	eq(AccountLink.error_text({"ok": false, "cancelled": false, "code": "SOMETHING_NEW"}), AccountLink.FALLBACK, "unknown code")
	eq(AccountLink.error_text({"ok": false, "cancelled": true, "code": ""}), "", "cancel: nothing")
	eq(AccountLink.error_text({"ok": true}), "", "success: nothing")
	eq(AccountLink.error_text({"ok": false, "cancelled": false, "code": GoogleSignIn.UNAVAILABLE}), "Sắp ra mắt", "no sheet here")


func test_guest_and_linked_states() -> void:
	check(AccountLink.is_guest({"linkedProviders": []}), "empty list: guest")
	check(AccountLink.is_guest({}), "no field: guest")
	check(AccountLink.is_guest(null), "no profile: guest")
	check(not AccountLink.is_guest({"linkedProviders": ["google"]}), "google linked")
	eq(AccountLink.linked_providers({"linkedProviders": ["google", "apple", "facebook"]}), ["apple", "google"] as Array[String],
		"known providers in the popup's order")


func test_headless_has_no_sheet() -> void:
	check(not WebAuthNative.available(), "headless: no sign-in sheet")
	check(not GoogleSignIn.available(), "headless: Google shows Sắp ra mắt")


func test_settings_popup_guest_then_linked() -> void:
	var host := Control.new()
	var p = SettingsPopup.new()
	p.sign_in_ready = func(provider: String) -> bool: return provider == "google"
	p.open_for(host)
	p.render({"linkedProviders": []})
	var google = p.section.get_node_or_null("Providers/Row_google")
	var apple = p.section.get_node_or_null("Providers/Row_apple")
	check(google != null and apple != null, "a row for Google and for Apple")
	if google != null:
		check(google.find_child("Link", true, false) is Button, "a guest gets the Google link button")
		eq(google.find_child("Mark", true, false).kind, "google", "the four-colour G")
	p.render({"linkedProviders": ["google"]})
	google = p.section.get_node_or_null("Providers/Row_google")
	check(google != null and google.find_child("Tick", true, false) != null, "linked: the Google mark with the tick")
	check(google != null and google.find_child("Link", true, false) == null, "linked: no link button")
	host.free()


func test_gear_glyph_and_login_google_handler() -> void:
	check(GlyphIcon.KINDS.has("gear"), "the gear glyph")
	var methods := {}
	for m in (load("res://screens/login.gd") as Script).get_script_method_list():
		methods[m["name"]] = true
	check(methods.has("_login_google"), "the Google login handler")
