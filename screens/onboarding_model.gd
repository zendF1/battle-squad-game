extends RefCounted
## The first-login character pick and name (screens/onboarding.gd), without UI: whether a profile
## still has to go through it (GET /player/profile onboarded false), the starter characters (the
## game data's starterCharacterIds; every character for an older server without them), stepping
## through them with wrap-around, the name rule (ErrorText.name_problem(), the server's), a
## GET /player/name-suggestion answer, the dice's scrambled text, and what a failed
## POST /player/onboarding means for the screen.

const ErrorText := preload("res://screens/home/error_text.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## What the screen does with a failed POST /player/onboarding (error()).
const SHOW_HINT := 0 # the hint under the name field
const SHAKE_NAME := 1 # the hint, the field outlined red and shaken
const GO_LOBBY := 2 # already onboarded (another device, a second tap): refresh and go on

## The dice's scrambled letters (a look only, never sent).
const SCRAMBLE := "ABCDEFGHIKLMNOPQRSTUVXYĐÂÊÔƠƯabcdeghiklmnopqrstuvxyđăâêôơư0123456789"


## The profile has to pick a starter and a name first: its onboarded is false (an older server
## without the field never sends anyone through it).
static func needs_onboarding(profile: Variant) -> bool:
	return profile is Dictionary and profile.get("onboarded") is bool and profile["onboarded"] == false


## The starter characters in display order (starterCharacterIds; without them every character).
static func starters() -> Array:
	var ids := GameData.starter_character_ids()
	return ids if not ids.is_empty() else GameData.character_ids()


## The starter shown first: the profile's currentCharacterId when it is a starter, else the first.
static func first(ids: Array, profile: Variant) -> String:
	if ids.is_empty():
		return ""
	var current = profile.get("currentCharacterId") if profile is Dictionary else null
	return str(current) if current is String and ids.has(current) else str(ids[0])


## The id `delta` steps from `id` in `ids`, wrapping around (an unknown id counts as the first).
static func cycle(ids: Array, id: String, delta: int) -> String:
	if ids.is_empty():
		return id
	return str(ids[posmod(maxi(ids.find(id), 0) + delta, ids.size())])


## Why `raw` cannot be sent as the name ("" when it can).
static func name_problem(raw: String) -> String:
	return ErrorText.name_problem(raw)


## The name of a GET /player/name-suggestion answer; "" when it failed or is not a usable name.
static func suggestion(res: Dictionary) -> String:
	if not res.get("ok", false) or not res.get("data") is Dictionary:
		return ""
	var n = res["data"].get("name")
	if not n is String or name_problem(n) != "":
		return ""
	return n.strip_edges()


## `length` random letters for the name field while the dice tumbles.
static func scramble(length: int, rng: RandomNumberGenerator) -> String:
	var out := ""
	for i in maxi(length, 1):
		out += SCRAMBLE[rng.randi_range(0, SCRAMBLE.length() - 1)]
	return out


## A failed POST /player/onboarding → {action: SHOW_HINT / SHAKE_NAME / GO_LOBBY, text}.
static func error(res: Dictionary) -> Dictionary:
	if int(res.get("status", 0)) == 0:
		return {"action": SHOW_HINT, "text": ErrorText.OFFLINE}
	match str(res.get("code", "")):
		"PLAYER_NAME_TAKEN":
			return {"action": SHAKE_NAME, "text": "Tên này đã có người dùng"}
		"PLAYER_UPDATE_FAILED":
			return {"action": SHAKE_NAME, "text": ErrorText.rename(res)}
		"ONBOARDING_DONE":
			return {"action": GO_LOBBY, "text": ""}
		"ONBOARDING_BAD_CHARACTER":
			return {"action": SHOW_HINT, "text": "Nhân vật này chưa chọn được, hãy chọn nhân vật khác"}
	return {"action": SHOW_HINT, "text": "Chưa vào được trò chơi: %s" % str(res.get("message", ""))}
