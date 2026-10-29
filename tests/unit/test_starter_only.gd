extends "res://tests/test_case.gd"
## No character is free (the server's starter-only rule): a player owns the starter picked at
## onboarding and what they bought, Rookie (the game data's defaultCharacterId) included. The
## lobby's start character is an owned one, the Shop sells Rookie like the others, and the cards
## mark it not owned; ONBOARDING_REQUIRED (the player owns nothing yet) opens the starter pick.

const LoadoutModel := preload("res://screens/loadout_model.gd")
const LobbyModel := preload("res://screens/home/lobby_model.gd")
const ShopModel := preload("res://screens/home/character_shop_model.gd")
const GameData := preload("res://autoload/game_data_model.gd")
const OnboardingModel := preload("res://screens/onboarding_model.gd")
const ErrorText := preload("res://screens/home/error_text.gd")

const TEST_SETTINGS := "user://test_starter_only_loadout.cfg"

## GET /player/characters of a player who picked Spark at onboarding: only Spark's row.
const SPARK_ONLY := {"characters": [{"characterId": "spark", "level": 1, "exp": 0, "power": 1234}], "baseStats": {
	"rookie": {"maxHp": 1500, "defense": 50, "damageBonus": 0, "moveEnergy": 100, "skillPowerBonus": 0, "terrainDamageBonus": 0, "weaponDamage": 480},
	"spark": {"maxHp": 1250, "defense": 30, "damageBonus": 0, "moveEnergy": 120, "skillPowerBonus": 0, "terrainDamageBonus": 0, "weaponDamage": 620},
}}
const NONE_OWNED := {"characters": []}

## The server's character_unlock offers (configs/shop.yaml), Rookie's added by the starter-only change.
const OFFERS := [
	{"offerId": "unlock_rookie_coin", "itemId": "rookie", "offerType": "character_unlock", "priceCurrency": "coin", "priceAmount": 5000, "quantity": 1, "limitPerPlayer": 1},
	{"offerId": "unlock_rookie_gem", "itemId": "rookie", "offerType": "character_unlock", "priceCurrency": "gem", "priceAmount": 300, "quantity": 1, "limitPerPlayer": 1},
	{"offerId": "unlock_tanko_coin", "itemId": "tanko", "offerType": "character_unlock", "priceCurrency": "coin", "priceAmount": 5000, "quantity": 1, "limitPerPlayer": 1},
]


func _clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func _save(id: String) -> void:
	var m := LoadoutModel.new()
	m.select_character(id)
	m.remember(TEST_SETTINGS)


func test_start_character_is_an_owned_one() -> void:
	_clear()
	eq(LoadoutModel.start_character(TEST_SETTINGS, {"currentCharacterId": "spark"}, SPARK_ONLY), "spark",
		"nothing saved: the profile's main character")
	eq(LoadoutModel.start_character(TEST_SETTINGS, {}, SPARK_ONLY), "spark", "no profile field: the first owned")
	eq(LoadoutModel.start_character(TEST_SETTINGS, {"currentCharacterId": "rookie"}, SPARK_ONLY), "spark",
		"the profile's character not owned: the first owned, never Rookie")
	eq(LoadoutModel.start_character(TEST_SETTINGS, {}, NONE_OWNED), "", "nothing owned (not onboarded): none")
	eq(LoadoutModel.start_character(TEST_SETTINGS, {}, null), "", "nothing known: none")
	_save("rookie") # another account's choice on this device
	eq(LoadoutModel.start_character(TEST_SETTINGS, {"currentCharacterId": "spark"}, SPARK_ONLY), "spark",
		"the device's Rookie not owned: the profile's Spark")
	eq(LoadoutModel.start_character(TEST_SETTINGS, {"currentCharacterId": "spark"}, null), "rookie",
		"ownership not loaded yet: the device's choice stands (checked again once loaded)")
	_save("spark")
	eq(LoadoutModel.start_character(TEST_SETTINGS, {"currentCharacterId": "tanko"}, SPARK_ONLY), "spark",
		"the device's owned choice wins")
	_clear()


func test_first_owned_follows_the_game_data_order() -> void:
	_clear()
	var two := {"characters": [{"characterId": "tide"}, {"characterId": "tanko"}]}
	eq(LoadoutModel.start_character(TEST_SETTINGS, {}, two), "tanko", "tanko comes before tide in the roster")
	_clear()


func test_loadout_restore_without_a_save_keeps_the_placeholder() -> void:
	_clear()
	eq(LoadoutModel.saved_character(TEST_SETTINGS), "", "nothing saved: the Loadout asks start_character()")
	_save("spark")
	var m := LoadoutModel.new()
	m.restore(TEST_SETTINGS)
	eq(m.character_id, "spark", "the lobby's saved pick")
	_clear()


func test_shop_sells_rookie_when_not_owned() -> void:
	var owned = LoadoutModel.parse_characters(SPARK_ONLY)
	var rookie := ShopModel.card("rookie", OFFERS, [], owned)
	eq(rookie["state"], ShopModel.BUY, "Rookie not owned: on sale")
	eq(rookie["offers"].map(func(o): return o["offerId"]), ["unlock_rookie_coin", "unlock_rookie_gem"], "both prices, server order")
	eq(ShopModel.buy_button(rookie), {"text": "5.000", "icon": "coin", "enabled": true}, "the coin price first")
	eq(ShopModel.other_prices(rookie), [{"text": "300", "icon": "gem"}], "the gem price beside it")
	eq(ShopModel.card("spark", OFFERS, [], owned)["state"], ShopModel.OWNED, "the starter owned")
	eq(ShopModel.card("rookie", null, null, null)["state"], ShopModel.UNKNOWN, "not loaded: unknown, not owned")
	eq(ShopModel.card("rookie", OFFERS, [], ["rookie", "spark"])["state"], ShopModel.OWNED, "bought: owned")
	var bought := [{"offerId": "unlock_rookie_coin", "status": "completed"}, {"offerId": "unlock_rookie_gem", "status": "completed"}]
	eq(ShopModel.card("rookie", OFFERS, bought, owned)["state"], ShopModel.NOT_FOR_SALE, "limit used up: not for sale")


func test_lobby_card_marks_rookie_not_owned() -> void:
	var rookie := LobbyModel.character_info("rookie", SPARK_ONLY)
	eq(rookie["owned"], false, "Rookie not in the list: not owned")
	eq(LobbyModel.level_text(rookie), LoadoutModel.NOT_OWNED, "Chưa sở hữu")
	eq(rookie["power"], -1, "no Lực chiến")
	check(not rookie["stats"].is_empty(), "its base stats still shown")
	var spark := LobbyModel.character_info("spark", SPARK_ONLY)
	eq([spark["owned"], spark["level"], spark["power"]], [true, 1, 1234], "Spark owned at level 1")


func test_onboarding_required_routes_to_the_pick() -> void:
	var err := {"error": {"code": "ONBOARDING_REQUIRED", "message": "Pick your starter character first", "correlationId": "ws-error"}}
	check(OnboardingModel.is_required_error("RoomError", err), "QuickPlay / CreateRoom / JoinRoom refused")
	check(OnboardingModel.is_required_error("LobbyError", err), "CreateLobby / JoinLobby / an accepted invite refused")
	check(OnboardingModel.is_required_error("Error", {"code": "ONBOARDING_REQUIRED"}), "a flat payload")
	check(not OnboardingModel.is_required_error("RoomError", {"error": {"code": "LOADOUT_INVALID"}}), "another refusal")
	check(not OnboardingModel.is_required_error("MatchStarted", err), "not an error event")
	check(not OnboardingModel.is_required_error("RoomError", null), "no payload")
	eq(ErrorText.room_error(err), "Hãy chọn nhân vật khởi đầu trước", "the QuickPlay status in Vietnamese")
	eq(ErrorText.lobby_error(err), "Hãy chọn nhân vật khởi đầu trước", "the lobby toast in Vietnamese")
	eq(ErrorText.room_error({"error": {"code": "LOADOUT_INVALID", "message": "You do not own character: rookie"}}),
		"Bạn chưa sở hữu nhân vật này", "Rookie not owned is refused like any other")
