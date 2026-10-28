extends "res://tests/test_case.gd"
## The login screen's buttons and terms tick: one handler per provider, the marks drawn for each, the
## tick remembered on the device, the legal links from the project settings.

const Login := preload("res://screens/login.gd")
const LoginButton := preload("res://ui/login_button.gd")
const LoginMark := preload("res://ui/login_mark.gd")
const ConsentRow := preload("res://ui/consent_row.gd")
const Consent := preload("res://core/consent.gd")

const TEST_PATH := "user://test_login_consent.cfg"


func test_every_provider_has_a_handler_and_a_mark() -> void:
	var methods := {}
	var script: Script = load("res://screens/login.gd")
	for m in script.get_script_method_list():
		methods[m["name"]] = true
	eq(Login.PROVIDERS.size(), 4, "four login buttons")
	eq(Login.PROVIDERS[-1][0], "guest", "the guest button last")
	for p in Login.PROVIDERS:
		check(methods.has("_login_" + p[0]), "_login_%s exists" % p[0])
		check(LoginMark.KINDS.has(p[0]), "%s has a mark" % p[0])


func test_consent_is_remembered() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var other := ConfigFile.new()
	other.set_value("audio", "music", 0.5)
	other.save(TEST_PATH)
	var c := Consent.new(TEST_PATH)
	check(not c.accepted, "not ticked at first")
	c.set_accepted(true)
	check(Consent.new(TEST_PATH).accepted, "ticked after a restart")
	var cfg := ConfigFile.new()
	cfg.load(TEST_PATH)
	eq(cfg.get_value("audio", "music", 0.0), 0.5, "the file's other settings kept")
	c.set_accepted(false)
	check(not Consent.new(TEST_PATH).accepted, "unticked after a restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_legal_links_come_from_the_project_settings() -> void:
	for key in ["battle_squad/terms_url", "battle_squad/privacy_url"]:
		check(str(ProjectSettings.get_setting(key, "")).begins_with("https://"), "%s is an https URL" % key)
	var row := ConsentRow.new(400.0, false, "https://t", "https://p")
	eq(row.url_for("terms"), "https://t", "terms link")
	eq(row.url_for("privacy"), "https://p", "privacy link")
	row.free()


func test_consent_row_toggles() -> void:
	var row := ConsentRow.new(400.0, false)
	var seen: Array = []
	row.toggled.connect(func(on: bool) -> void: seen.append(on))
	row.set_accepted(true)
	check(row.accepted, "ticked")
	eq(seen, [true], "toggled reported")
	row.free()
	check(ConsentRow.new(400.0, true).accepted, "starts ticked when remembered")


func test_login_button_centres_its_text() -> void:
	var b := LoginButton.new("google", "Đăng nhập với Google")
	var box: StyleBox = b.get_theme_stylebox("normal")
	eq(box.content_margin_left, box.content_margin_right, "equal side margins: the text centred")
	check(box.content_margin_left >= LoginButton.MARK_INSET + LoginButton.MARK_PX, "the text clear of the mark")
	eq(b.custom_minimum_size, LoginButton.SIZE, "one size for every button")
	b.free()


func test_apple_mark_shape() -> void:
	var shape := LoginMark.apple_shape()
	check(shape.size() > 20, "a smooth outline")
	check(Geometry2D.is_point_in_polygon(Vector2(0.0, 0.2), shape), "the body is filled")
	check(not Geometry2D.is_point_in_polygon(Vector2(0.7, -0.12), shape), "the bite is cut out")
	for p in shape + LoginMark.apple_leaf():
		check(absf(p.x) <= 1.0 and absf(p.y) <= 1.0, "inside the unit box: %s" % p)
