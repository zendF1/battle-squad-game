extends Node
## Scene navigation (the demo's GoRouter) and the payload handed to the next scene.

const OnboardingModel := preload("res://screens/onboarding_model.gd")

const SPLASH := "res://screens/splash.tscn"
const LOGIN := "res://screens/login.tscn"
const HOME := "res://screens/home.tscn"
const ONBOARDING := "res://screens/onboarding.tscn"
const LOADOUT := "res://screens/loadout.tscn"
const MATCH := "res://match/match_screen.tscn"
const MATCHMAKING := "res://screens/matchmaking.tscn"

## QuickPlay fields picked on Home for the Loadout scene: {} plays the idle practice target,
## {"bot": "ai"} a bot that moves and shoots.
var quick_play_base: Dictionary = {}
## MatchStarted payload for the Match scene (match state + terrain snapshot).
var match_snapshot: Dictionary = {}
## The Loadout's {characterId, items} for a queue mode (the Matchmaking scene sends it).
var ranked_loadout: Dictionary = {}
## The queue the Matchmaking scene joins (the chosen mode's: ranked_2v2, casual_2v2, ...; "" the
## server's default): set by the Loadout, by the party for its member, by "Chơi tiếp".
var queue := ""
## The last QuickPlay payload sent (the result screen's "Chơi lại"); {} none.
var last_quick_play: Dictionary = {}
## The ranked match's players from MatchFound ({playerId: MatchmakingModel.parse_player()}: level
## and rank for the result screen); the Match scene takes it, {} otherwise.
var match_roster: Dictionary = {}
## A message for Home to show once (a ranked queue that ended with an error); "" none.
var home_notice := ""
## Matchmaking opens as the party's member (the host started the queue, screens/home/party.gd);
## the Matchmaking scene takes it.
var ranked_member := false
## The player picked a lobby mode this session (the mode card / Mode Select, the party's queue;
## screens/home/lobby.gd): the lobby stage shows that mode's background from then on, lobby_bg
## before (LobbyModel.stage_background()). The mode restored from the settings file does not count.
var mode_chosen := false
## The 2v2 party (screens/home/party.gd), kept here so it outlives the scenes.
var party: Node


func go(scene: String) -> void:
	get_tree().call_deferred("change_scene_to_file", scene)


## Where a signed-in player goes: the starter pick while the profile is not onboarded, else Home.
func go_signed_in(profile: Variant) -> void:
	go(ONBOARDING if OnboardingModel.needs_onboarding(profile) else HOME)


func _ready() -> void:
	GameSocket.session_lost.connect(_on_session_lost)
	party = load("res://screens/home/party.gd").new()
	party.name = "Party"
	add_child(party)


func _on_session_lost() -> void:
	go(LOGIN)
