extends "res://tests/test_case.gd"

const SessionScript := preload("res://autoload/session.gd")
const PATH := "user://test_session.cfg"


func _fresh():
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return SessionScript.new(PATH)


func test_tokens_persist_across_instances() -> void:
	var s = _fresh()
	s.set_tokens("access-1", "refresh-1", "player-1", "Bob")
	s.free()
	var again = SessionScript.new(PATH)
	eq(again.access_token, "access-1", "access token")
	eq(again.refresh_token, "refresh-1", "refresh token")
	eq(again.player_id, "player-1", "player id")
	eq(again.display_name, "Bob", "display name")
	check(again.has_token(), "has_token")
	again.free()


func test_device_id_survives_logout() -> void:
	var s = _fresh()
	var id: String = s.ensure_device_id()
	check(id.length() == 36, "device id is a uuid")
	s.set_tokens("a", "r", "p", "n")
	s.clear_tokens()
	check(not s.has_token(), "tokens cleared")
	eq(s.ensure_device_id(), id, "same id after logout")
	s.free()
	var again = SessionScript.new(PATH)
	eq(again.ensure_device_id(), id, "same id after reload")
	again.free()


func test_set_tokens_keeps_player_when_omitted() -> void:
	var s = _fresh()
	s.set_tokens("a", "r", "player-1", "Bob")
	s.set_tokens("a2", "r2")
	eq(s.player_id, "player-1", "player id kept on refresh")
	eq(s.access_token, "a2", "access token replaced")
	s.free()
