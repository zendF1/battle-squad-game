extends Node
## Scene navigation (the demo's GoRouter) and the payload handed to the next scene.

const SPLASH := "res://screens/splash.tscn"
const LOGIN := "res://screens/login.tscn"
const HOME := "res://screens/home.tscn"
const MATCH := "res://match/match_screen.tscn"

## MatchStarted payload for the Match scene (match state + terrain snapshot).
var match_snapshot: Dictionary = {}


func go(scene: String) -> void:
	get_tree().call_deferred("change_scene_to_file", scene)
