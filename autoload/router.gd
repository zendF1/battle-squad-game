extends Node
## Scene navigation (the demo's GoRouter) and the payload handed to the next scene.

const SPLASH := "res://screens/splash.tscn"
const LOGIN := "res://screens/login.tscn"
const HOME := "res://screens/home.tscn"
const LOADOUT := "res://screens/loadout.tscn"
const MATCH := "res://match/match_screen.tscn"

## QuickPlay fields picked on Home for the Loadout scene: {} plays the idle practice target,
## {"bot": "ai"} a bot that moves and shoots.
var quick_play_base: Dictionary = {}
## MatchStarted payload for the Match scene (match state + terrain snapshot).
var match_snapshot: Dictionary = {}


func go(scene: String) -> void:
	get_tree().call_deferred("change_scene_to_file", scene)


func _ready() -> void:
	GameSocket.session_lost.connect(_on_session_lost)


func _on_session_lost() -> void:
	go(LOGIN)
