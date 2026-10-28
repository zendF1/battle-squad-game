extends RefCounted
## The login screen's "I agree to the terms" tick, remembered on this device so a returning player does
## not tick it again (user://settings.cfg [consent] accepted; other sections of the file are kept).

const PATH := "user://settings.cfg"
const SECTION := "consent"
const KEY := "accepted"

var accepted := false
var _path: String


func _init(path: String = PATH) -> void:
	_path = path
	var cfg := ConfigFile.new()
	if cfg.load(_path) == OK:
		accepted = bool(cfg.get_value(SECTION, KEY, false))


func set_accepted(value: bool) -> void:
	accepted = value
	var cfg := ConfigFile.new()
	cfg.load(_path) # a missing file starts empty
	cfg.set_value(SECTION, KEY, value)
	cfg.save(_path)
