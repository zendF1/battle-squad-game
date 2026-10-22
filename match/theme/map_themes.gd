extends RefCounted
## Map themes: how a map looks (the server only knows its layout). The maps themselves live in
## the server's DB: MatchStarted / MatchStateSync carry `mapTheme` and `mapName`, and the map
## catalog (match/theme/map_catalog.gd, GET /maps) knows every active map's name and theme for
## the screens outside a match (and a server that sends no mapTheme). The theme ids the server
## accepts and the default one are the game data's (GET /gamedata mapThemes); a theme with no art
## here (a new one an admin added) draws as the default theme (default_theme()), an unknown map
## under its raw id. Only the art is here, keyed by theme id.
##
## A theme (LOOKS) is: a background (match/theme/backdrop_painter.gd draws it once per match, by
## the theme id), clouds (count, tint, height band), particles (match/theme/sky_fx.gdshader mode),
## the soft (destructible) and the hard (indestructible) terrain materials
## (match/theme/material_painter.gd ids) and the bottom of the map: a liquid band (water, or lava
## for the temple) or a dark abyss with fog (match/theme/bottom.gdshader); "none" draws nothing
## (grassland: today's look, its ground reaches the bottom). Falling past the bottom is out of the
## map either way: the bottom is only a look.

const MapCatalog := preload("res://match/theme/map_catalog.gd")
const GameData := preload("res://autoload/game_data_model.gd")

## The look drawn with the match sky picture (today's look), and the art used when even the
## game data's default theme has none here.
const GRASSLAND := "grassland"

## Particle modes of sky_fx.gdshader.
const FX_NONE := 0
const FX_SNOW := 1
const FX_EMBERS := 2
const FX_DUST := 3
const FX_WISPS := 4
const FX_SPARKLE := 5

## theme -> look. clouds: [count, tint, y from, y to] (y in map heights); fx: [mode, colour,
## density]; soft / hard: material ids; bottom: {kind: none | water | lava | abyss, colours}.
const LOOKS := {
	"grassland": {
		"clouds": [8, Color(1, 1, 1, 1), 0.14, 0.4],
		"fx": [FX_NONE, Color(1, 1, 1, 0), 0.0],
		"soft": "grass_dirt", "hard": "mossy_stone",
		"bottom": {"kind": "none"},
	},
	"ice": {
		"clouds": [6, Color(0.92, 0.96, 1.0, 0.9), 0.08, 0.3],
		"fx": [FX_SNOW, Color(1, 1, 1, 0.9), 1.0],
		"soft": "snow", "hard": "ice_block",
		"bottom": {"kind": "water", "top": Color(0.62, 0.86, 1.0), "deep": Color(0.07, 0.2, 0.48), "foam": Color(0.93, 0.98, 1.0)},
	},
	"beach": {
		"clouds": [7, Color(1, 1, 1, 0.95), 0.06, 0.28],
		"fx": [FX_SPARKLE, Color(1, 1, 0.9, 0.0), 0.0],
		"soft": "sand", "hard": "driftwood",
		"bottom": {"kind": "water", "top": Color(0.45, 0.93, 0.92), "deep": Color(0.06, 0.52, 0.72), "foam": Color(1, 1, 1)},
	},
	"graveyard": {
		"clouds": [5, Color(0.42, 0.55, 0.55, 0.55), 0.06, 0.26],
		"fx": [FX_WISPS, Color(0.6, 1.0, 0.75, 0.85), 0.6],
		"soft": "grave_soil", "hard": "tomb_brick",
		"bottom": {"kind": "abyss", "fog": Color(0.05, 0.12, 0.11), "glow": Color(0.35, 0.8, 0.6)},
	},
	"desert": {
		"clouds": [3, Color(1.0, 0.93, 0.8, 0.6), 0.06, 0.2],
		"fx": [FX_DUST, Color(1.0, 0.86, 0.6, 0.55), 0.7],
		"soft": "dune_sand", "hard": "sandstone",
		"bottom": {"kind": "abyss", "fog": Color(0.24, 0.12, 0.05), "glow": Color(0.95, 0.6, 0.3)},
	},
	"sky": {
		"clouds": [10, Color(1, 1, 1, 0.97), 0.05, 0.55],
		"fx": [FX_SPARKLE, Color(1, 1, 0.85, 0.0), 0.0],
		"soft": "sky_earth", "hard": "marble",
		"bottom": {"kind": "water", "top": Color(0.5, 0.88, 1.0), "deep": Color(0.1, 0.45, 0.8), "foam": Color(1, 1, 1)},
	},
	"temple": {
		"clouds": [5, Color(0.55, 0.18, 0.12, 0.7), 0.04, 0.22],
		"fx": [FX_EMBERS, Color(1.0, 0.62, 0.2, 0.95), 0.8],
		"soft": "basalt", "hard": "temple_gold",
		"bottom": {"kind": "lava", "top": Color(1.0, 0.86, 0.32), "deep": Color(0.85, 0.22, 0.05), "foam": Color(1.0, 0.96, 0.7)},
	},
	"steel": {
		"clouds": [5, Color(0.86, 0.94, 0.94, 0.75), 0.06, 0.28],
		"fx": [FX_DUST, Color(0.85, 0.92, 0.9, 0.35), 0.4],
		"soft": "gravel", "hard": "steel_plate",
		"bottom": {"kind": "water", "top": Color(0.42, 0.66, 0.68), "deep": Color(0.08, 0.2, 0.26), "foam": Color(0.85, 0.95, 0.95)},
	},
	"city_night": {
		"clouds": [6, Color(0.55, 0.35, 0.95, 0.75), 0.05, 0.3],
		"fx": [FX_SPARKLE, Color(1, 1, 1, 0.9), 0.5],
		"soft": "asphalt", "hard": "girder",
		"bottom": {"kind": "water", "top": Color(0.3, 0.3, 0.7), "deep": Color(0.03, 0.04, 0.16), "foam": Color(0.75, 0.6, 1.0)},
	},
	"stone": {
		"clouds": [6, Color(1, 1, 0.97, 0.9), 0.06, 0.3],
		"fx": [FX_NONE, Color(1, 1, 1, 0), 0.0],
		"soft": "rock_soil", "hard": "stone_tile",
		"bottom": {"kind": "abyss", "fog": Color(0.1, 0.12, 0.1), "glow": Color(0.6, 0.7, 0.5)},
	},
	"cave": {
		"clouds": [0, Color(1, 1, 1, 0), 0.0, 0.0],
		"fx": [FX_DUST, Color(0.75, 0.65, 1.0, 0.45), 0.6],
		"soft": "cave_rock", "hard": "boulder",
		"bottom": {"kind": "abyss", "fog": Color(0.04, 0.02, 0.08), "glow": Color(0.55, 0.35, 0.95)},
	},
}


## A theme this client has art for.
static func is_theme(id: String) -> bool:
	return LOOKS.has(id)


## The theme drawn when a map's has no art: the game data's default (mapThemes.default), else
## GRASSLAND.
static func default_theme() -> String:
	var d := GameData.default_theme()
	return d if is_theme(d) else GRASSLAND


## The theme of a MatchStarted / MatchStateSync: its mapTheme when the client has its art, else
## the catalog's for its mapId, else default_theme().
static func theme_of(snap: Dictionary) -> String:
	var t := str(snap.get("mapTheme", ""))
	if is_theme(t):
		return t
	t = MapCatalog.theme_of(str(snap.get("mapId", "")))
	return t if is_theme(t) else default_theme()


## The map's Vietnamese name: the snapshot's mapName, else the catalog's, else the raw id.
static func name_of(snap: Dictionary) -> String:
	var n = snap.get("mapName")
	if n is String and n.strip_edges() != "":
		return n.strip_edges()
	return MapCatalog.name_of(str(snap.get("mapId", "")))


static func look(theme: String) -> Dictionary:
	return LOOKS.get(theme, LOOKS[default_theme()])
