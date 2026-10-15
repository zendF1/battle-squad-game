extends Node
## Server base URLs from project settings (battle_squad/*). Override per run with
## user args, e.g. `godot -- --api-url=http://192.168.1.10:9090 --ws-url=ws://192.168.1.10:9091`.

var api_url: String = ProjectSettings.get_setting("battle_squad/api_url", "http://localhost:9090")
var ws_url: String = ProjectSettings.get_setting("battle_squad/ws_url", "ws://localhost:9091")


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--api-url="):
			api_url = arg.trim_prefix("--api-url=")
		elif arg.begins_with("--ws-url="):
			ws_url = arg.trim_prefix("--ws-url=")
