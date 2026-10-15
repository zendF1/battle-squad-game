extends Node
## Persisted login state: tokens, player identity and the device install id that guest login
## needs. The device id is generated once and survives logout, so a guest keeps the account.

const Uuid := preload("res://core/uuid.gd")

var access_token := ""
var refresh_token := ""
var player_id := ""
var display_name := ""
var device_install_id := ""

var _path: String


func _init(path: String = "user://session.cfg") -> void:
	_path = path
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	access_token = cfg.get_value("auth", "access_token", "")
	refresh_token = cfg.get_value("auth", "refresh_token", "")
	player_id = cfg.get_value("auth", "player_id", "")
	display_name = cfg.get_value("auth", "display_name", "")
	device_install_id = cfg.get_value("device", "install_id", "")


func has_token() -> bool:
	return access_token != ""


func set_tokens(access: String, refresh: String, pid: String = "", display: String = "") -> void:
	access_token = access
	refresh_token = refresh
	if pid != "":
		player_id = pid
	if display != "":
		display_name = display
	_save()


func set_profile(pid: String, display: String) -> void:
	if pid != "":
		player_id = pid
	if display != "":
		display_name = display
	_save()


func clear_tokens() -> void:
	access_token = ""
	refresh_token = ""
	player_id = ""
	display_name = ""
	_save()


func ensure_device_id() -> String:
	if device_install_id == "":
		device_install_id = Uuid.v4()
		_save()
	return device_install_id


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "access_token", access_token)
	cfg.set_value("auth", "refresh_token", refresh_token)
	cfg.set_value("auth", "player_id", player_id)
	cfg.set_value("auth", "display_name", display_name)
	cfg.set_value("device", "install_id", device_install_id)
	cfg.save(_path)
