# M1: Foundation + First Playable Match — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Godot client that goes Splash → guest Login → Home → Quick Play → a full match against the server bot → result → Home, with no visible lag.

**Architecture:**
- Five autoloads (`Config`, `Session`, `Api`, `GameSocket`, `Router`) wrap REST, the WebSocket and navigation.
- Match logic is split into pure `RefCounted` scripts with no autoload or scene access, so headless tests cover all of it:
  - `TerrainMask`: a byte-exact port of the server terrain
  - `ShotTimeline`
  - `TrajectoryPredictor`: aim preview with the server's integration and collision
  - `MoveSync`: per-command move prediction modelled on `processMove`
- Scene scripts glue those pieces together. The server is authoritative. The client predicts only its own walk (same per-command model, same mask) and replays `ShotResolved`.

**Tech Stack:** Godot 4.7, GDScript, `WebSocketPeer`, `HTTPRequest`, a canvas_item shader. Server side (Go): the refresh-token fix (Task 4b), the `Move.seq` echo (Task 4c) and the fixture exporter test (Task 5).

**Read first:** `docs/superpowers/specs/2026-10-15-godot-client-roadmap-design.md` (flow, milestones, the anti-lag rules this plan implements).

**Conventions:**
- Code and comments are in English. UI strings are in Vietnamese.
- Tabs for indentation, which is the Godot default.
- Pure scripts load each other with `preload()` and never use `class_name`. The headless test runner then needs no global class cache.
- Scene roots are tiny `.tscn` files. Their UI is built in code.

---

## Server facts this plan relies on

All of these are in `../battle-squad`.

**Ports and envelopes**
- Dev ports come from `battle-squad/.env`: API `9090`, game `9091`.
- REST envelope (`internal/shared/model/response.go`):
  - success: `{"success":true,"data":X}`
  - error: `{"success":false,"error":{"code","message"}}`
- WS: `GET /ws?token=<jwt>`. Messages are `{"event": "...", "data": ...}`.
  - The server sends protocol-level pings, which `WebSocketPeer` answers by itself.

**Rate limit**
- The match accepts one action (`Move`/`Shoot`/`UseItem`/`EndTurn`) per player every **150 ms**. Faster actions are dropped silently (`match.go` `actionRateLimit`).

**`QuickPlay {}`**
- The server creates a 1v1 room on `grassland_valley` with a bot, starts it, and sends `MatchStarted`.
- `MatchStarted` and `MatchStateSync` carry the match state plus `terrain`:
  - match state fields: `matchId, players{id: {playerId, displayName, teamId, hp, maxHp, position{x,y}, moveEnergy, isAlive, ...}}, currentPlayerId, wind{direction, power}, turnTimeLeft, status`
  - `terrain` fields: `{width, height, version, solid, destructible}`
- `TurnStarted` arrives right after `MatchStarted`, often in the same network read. That is why `GameSocket.hold()` exists.

**Turn events**
- `TurnStarted {turnIndex, currentPlayerId, wind, moveEnergy, skillEnergy{id: n}}`
- `TurnTimerTick {timeLeft}` once a second. It pauses while a shot resolves.

**Move**
- `Move {direction, targetX, seq?}`. The server walks from its own position toward `targetX`:
  - capped at `moveEnergy*2` px
  - cost `round(dist*0.5)` energy
  - uses `Terrain.WalkTo`
- It then broadcasts `PlayerMoved {playerId, position, moveEnergy, seq?}`. The `seq` echo is added by Task 4c.
- Each command is charged separately: rounding is per command, and the distance is the net distance of that command.
- A rejected `Move` (not your turn, frozen, rate limited) gets no answer at all.

**Shoot**
- `Shoot {angle, power, actionMode:"weapon"}`.
  - angle: degrees, 0 is right, 90 is up.
  - power: 0..100.
- The server answers with one `ShotResolved {shooterId, actionMode, projectiles[{projectileId, path[{position, velocity, time}], explosionPoint?, explosionRadius}], events[{t, type, ...}], duration}`.
- Event types:
  - `explode {projectileId, position, radius, terrainVersion}`
  - `damage {playerId, amount, hp, cause, critical?}`
  - `heal`
  - `status`
  - `fall {from, to, duration}`
  - `die`
  - `teleport`

**Match end**
- `MatchEnded {winningTeam, rewards{playerId: {expGained, coinGained, ...}}, result?}` comes right after the last `ShotResolved`.
- `rewards` is `null` when granting rewards failed on the server (`match.go`, `ProcessMatchRewards` error).

**Terrain coordinates**
- y points down. A player's `position` is the first solid pixel under the feet. The body is 40 px tall (`PlayerHeight`).

---

## File structure

| File | Responsibility |
|------|----------------|
| `project.godot` | Viewport 1600×900, landscape, stretch, autoloads, `battle_squad/*` URLs, main scene |
| `tests/run.sh` | Runs the headless tests and fails on script errors |
| `tests/run_tests.gd` | SceneTree runner: every `test_*` method in `tests/unit/test_*.gd` |
| `tests/test_case.gd` | Assertion helpers (`check`, `eq`, `near`) |
| `tests/fixtures/terrain_parity.json` | Generated by the Go exporter. Never hand-edited |
| `core/uuid.gd` | UUID v4 |
| `core/envelope.gd` | WS `{event,data}` encode/decode |
| `core/api_response.gd` | REST envelope → `{ok, status, code, message, data}` |
| `autoload/config.gd` | API/WS base URLs |
| `autoload/session.gd` | Saved tokens, player id and device install id (`user://session.cfg`) |
| `autoload/api.gd` | REST calls, bearer auth, single-flight refresh on 401 |
| `autoload/game_socket.gd` | WS connection, polling, outbox, backoff reconnect, hold/release |
| `autoload/router.gd` | Scene changes, plus the snapshot handed to Match |
| `ui/ui.gd` | Small UI builders (label, button, centered column) |
| `screens/splash.*`, `screens/login.*`, `screens/home.*` | The demo's flow screens (M1 subset) |
| `match/terrain/terrain_mask.gd` | Port of `terrain.go`: RLE decode, `is_solid`, `destroy_circle`, `get_landing_y`, `walk_to` |
| `match/terrain/terrain_view.gd`, `terrain.gdshader` | Draws the mask (L8 texture plus shader) |
| `match/shot/shot_timeline.gd` | `ShotResolved` data: path sampling (Hermite) and due events |
| `match/shot/shot_player.gd` | Frame-driven replay: projectile views and `event_due` signal |
| `match/aim/trajectory_predictor.gd` | Aim preview, same integration as `SimulateProjectile` |
| `match/aim/aim_input.gd` | Slingshot drag, cancel zone, preview line |
| `match/move/move_sync.gd` | Predicted own walk, one numbered `Move` per segment, rebase on `PlayerMoved` by `seq`, bounded re-send |
| `match/views/*.gd` | Player, projectile, explosion and damage popup visuals |
| `match/hud.gd` | Turn, timer, wind, move buttons, energy, end turn, result panel |
| `match/match_screen.gd`, `match/match_screen.tscn` | Match controller: event routing, deferral during replays, input glue |
| `../battle-squad/internal/game/match/client_fixture_test.go` | Exports the terrain/shot/move parity fixture (server repo, test only) |
| `../battle-squad/internal/shared/auth/jwt.go`, `internal/api/auth/{service,handler}.go` | Unique token IDs; refresh saves the new session before revoking the old; 401 only for unusable tokens (Task 4b) |
| `../battle-squad/internal/game/match/{model,match}.go` | `PlayerMoved` echoes the optional `Move.seq` (Task 4c) |

---

### Task 1: Project settings and the headless test harness

**Files:**
- Modify: `project.godot`
- Create: `tests/run.sh`, `tests/run_tests.gd`, `tests/test_case.gd`, `tests/unit/test_smoke.gd`

- [ ] **Step 1: Locate the Godot binary**

Run: `ls -d /Applications/Godot*.app ~/Applications/Godot*.app ~/Downloads/Godot*.app 2>/dev/null`

Expected: one path, e.g. `/Applications/Godot.app`. Export it for every later step:

```bash
export GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
"$GODOT" --version
```

Expected: a line starting with `4.7`. If the app lives elsewhere, use that path. Every later command assumes `$GODOT` is set.

- [ ] **Step 2: Replace `project.godot`**

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="battle-squad-game"
config/features=PackedStringArray("4.7", "Mobile")
config/icon="res://icon.svg"

[battle_squad]

api_url="http://localhost:9090"
ws_url="ws://localhost:9091"

[display]

window/size/viewport_width=1600
window/size/viewport_height=900
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/handheld/orientation=4

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

rendering_device/driver.windows="d3d12"
renderer/rendering_method="mobile"
```

(`orientation=4` is sensor landscape. Autoloads and the main scene are added in Tasks 4 and 11, once their scripts exist.)

- [ ] **Step 3: Create `tests/test_case.gd`**

```gdscript
extends RefCounted
## Base class for unit tests. Assertions record failures instead of aborting, so one run
## reports every broken expectation.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func eq(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: got %s, want %s" % [message, str(actual), str(expected)])


func near(actual: float, expected: float, epsilon: float, message: String) -> void:
	if absf(actual - expected) > epsilon:
		failures.append("%s: got %f, want %f (±%f)" % [message, actual, expected, epsilon])
```

- [ ] **Step 4: Create `tests/run_tests.gd`**

```gdscript
extends SceneTree
## Headless test runner: runs every test_* method of every res://tests/unit/test_*.gd.
## Use tests/run.sh, which also fails the run on script errors.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var passed := 0
	var failed := 0
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR + "/" + file)
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test = script.new()
			test.call(method_name)
			if test.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL %s::%s" % [file, method_name])
				for failure in test.failures:
					print("    " + failure)
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
```

- [ ] **Step 5: Create `tests/run.sh` and make it executable**

```bash
#!/usr/bin/env bash
# Runs the headless unit tests. Set GODOT to the Godot 4.7 binary.
set -uo pipefail
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
out="$("$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1)"
status=$?
echo "$out"
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Invalid call" <<<"$out"; then
	echo "test run had script errors"
	exit 1
fi
exit $status
```

Run: `chmod +x tests/run.sh`

- [ ] **Step 6: Write the smoke test `tests/unit/test_smoke.gd`**

```gdscript
extends "res://tests/test_case.gd"


func test_runner_reports_assertions() -> void:
	eq(1 + 1, 2, "arithmetic")
```

- [ ] **Step 7: Run the tests**

Run: `tests/run.sh`
Expected: the last line is `1 passed, 0 failed`, and the exit status is 0.

Then make the test fail to check the runner, by changing `2` to `3`.
Run: `tests/run.sh; echo "exit=$?"`
Expected: `FAIL test_smoke.gd::test_runner_reports_assertions`, then `exit=1`.

Change `3` back to `2`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: project settings and headless test harness"
```

---

### Task 2: Core helpers (UUID, WS envelope, REST response)

**Files:**
- Create: `core/uuid.gd`, `core/envelope.gd`, `core/api_response.gd`
- Test: `tests/unit/test_core.gd`

- [ ] **Step 1: Write the failing tests `tests/unit/test_core.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Uuid := preload("res://core/uuid.gd")
const Envelope := preload("res://core/envelope.gd")
const ApiResponse := preload("res://core/api_response.gd")


func test_uuid_v4_format() -> void:
	var re := RegEx.new()
	re.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	var a := Uuid.v4()
	check(re.search(a) != null, "uuid %s is not v4" % a)
	check(a != Uuid.v4(), "two uuids are equal")


func test_envelope_round_trip() -> void:
	var msg := Envelope.decode(Envelope.encode("Move", {"targetX": 12.5}))
	eq(msg.get("event"), "Move", "event")
	eq(msg.get("data", {}).get("targetX"), 12.5, "data.targetX")


func test_envelope_rejects_garbage() -> void:
	eq(Envelope.decode("not json"), {}, "non-json")
	eq(Envelope.decode("{\"data\": 1}"), {}, "missing event")


func test_api_unwraps_success_envelope() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 200,
		"{\"success\":true,\"data\":{\"a\":1}}".to_utf8_buffer())
	check(res.ok, "ok")
	eq(res.data.get("a"), 1.0, "data.a")


func test_api_accepts_plain_body() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 200, "{\"x\":2}".to_utf8_buffer())
	check(res.ok, "ok")
	eq(res.data.get("x"), 2.0, "data.x")


func test_api_maps_error_envelope() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_SUCCESS, 409,
		"{\"success\":false,\"error\":{\"code\":\"ROOM_FULL\",\"message\":\"full\"}}".to_utf8_buffer())
	check(not res.ok, "not ok")
	eq(res.status, 409, "status")
	eq(res.code, "ROOM_FULL", "code")
	eq(res.message, "full", "message")


func test_api_maps_network_error() -> void:
	var res := ApiResponse.parse(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
	check(not res.ok, "not ok")
	eq(res.status, 0, "status")
	eq(res.code, "NETWORK_ERROR", "code")


func test_refresh_outcome_clears_session_only_when_server_rejects_token() -> void:
	var ok := {"ok": true, "status": 200, "data": {"accessToken": "a", "refreshToken": "r"}}
	eq(ApiResponse.refresh_outcome(ok), ApiResponse.REFRESH_OK, "200 with token")
	eq(ApiResponse.refresh_outcome({"ok": true, "status": 200, "data": {}}), ApiResponse.REFRESH_FAILED, "200 without token")
	for status in [400, 401, 403]:
		eq(ApiResponse.refresh_outcome({"ok": false, "status": status, "data": null}), ApiResponse.REFRESH_REJECTED, "status %d" % status)
	for status in [0, 404, 408, 429, 500, 503]:
		eq(ApiResponse.refresh_outcome({"ok": false, "status": status, "data": null}), ApiResponse.REFRESH_FAILED, "status %d" % status)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run.sh`
Expected: script errors about missing `res://core/uuid.gd` (or a similar file), and a non-zero exit.

- [ ] **Step 3: Create `core/uuid.gd`**

```gdscript
extends RefCounted
## Random (version 4) UUIDs, e.g. for the guest deviceInstallId.


static func v4() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
```

- [ ] **Step 4: Create `core/envelope.gd`**

```gdscript
extends RefCounted
## Game server WebSocket messages: {"event": "<Name>", "data": ...} (server: ws.Message).


static func encode(event: String, data = null) -> String:
	var msg := {"event": event}
	if data != null:
		msg["data"] = data
	return JSON.stringify(msg)


## Returns {"event": String, "data": Variant}, or {} when text is not a valid message.
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed = json.data
	if not (parsed is Dictionary) or not (parsed.get("event") is String):
		return {}
	return {"event": parsed["event"], "data": parsed.get("data")}
```

- [ ] **Step 5: Create `core/api_response.gd`**

```gdscript
extends RefCounted
## Turns an HTTPRequest result into {ok, status, code, message, data}. Success bodies use the
## server envelope {"success":true,"data":X} (data = X); errors use {"error":{"code","message"}}.


static func parse(result: int, status: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "code": "NETWORK_ERROR", "message": "network error (%d)" % result, "data": null}

	var parsed = null
	if body.size() > 0:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			parsed = json.data

	if status >= 200 and status < 300:
		var data = parsed
		if parsed is Dictionary and parsed.has("success"):
			data = parsed.get("data")
		return {"ok": true, "status": status, "code": "", "message": "", "data": data}

	var code := "SERVER_ERROR"
	var message := "HTTP %d" % status
	if parsed is Dictionary and parsed.get("error") is Dictionary:
		code = str(parsed["error"].get("code", code))
		message = str(parsed["error"].get("message", message))
	return {"ok": false, "status": status, "code": code, "message": message, "data": null}


const REFRESH_OK := 0
const REFRESH_REJECTED := 1 # the server says the refresh token is unusable: log in again
const REFRESH_FAILED := 2 # network, rate limit or server trouble: keep the tokens, retry later


## Classifies a parsed POST /auth/refresh response. Only 400/401/403 end the session (bad,
## expired, revoked or banned token); the server answers its own failures with 5xx and rate
## limiting with 429, which must not log the player out.
static func refresh_outcome(res: Dictionary) -> int:
	if res.get("ok", false):
		var data = res.get("data")
		if data is Dictionary and str(data.get("accessToken", "")) != "":
			return REFRESH_OK
		return REFRESH_FAILED
	if int(res.get("status", 0)) in [400, 401, 403]:
		return REFRESH_REJECTED
	return REFRESH_FAILED
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `tests/run.sh`
Expected: `9 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add core tests/unit/test_core.gd
git commit -m "feat: uuid, ws envelope and api response helpers"
```

---

### Task 3: Session (persisted login state)

**Files:**
- Create: `autoload/session.gd`
- Test: `tests/unit/test_session.gd`

- [ ] **Step 1: Write the failing tests `tests/unit/test_session.gd`**

```gdscript
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run.sh`
Expected: script error, because `res://autoload/session.gd` does not exist yet.

- [ ] **Step 3: Create `autoload/session.gd`**

```gdscript
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tests/run.sh`
Expected: `12 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add autoload/session.gd tests/unit/test_session.gd
git commit -m "feat: persisted session with stable guest device id"
```

---

### Task 4: Config, Api, GameSocket and Router autoloads

These scripts are thin wrappers around engine networking. They are checked by loading the project headless here, and end to end in Task 15.

**Files:**
- Create: `autoload/config.gd`, `autoload/api.gd`, `autoload/game_socket.gd`, `autoload/router.gd`
- Modify: `project.godot` (add `[autoload]`)

- [ ] **Step 1: Create `autoload/config.gd`**

```gdscript
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
```

- [ ] **Step 2: Create `autoload/api.gd`**

```gdscript
extends Node
## REST client for cmd/api. Adds the bearer token, unwraps the envelope (core/api_response.gd)
## and retries once after refreshing the token on 401. Concurrent 401s share one refresh.
## A 401 is returned to callers only when the session is really gone (no refresh token, or the
## server rejected it); a refresh that failed for network/server reasons is reported as
## AUTH_REFRESH_FAILED (status 0) and keeps the tokens, so callers show "retry", not Login.

signal _refresh_done(outcome: int)

const ApiResponse := preload("res://core/api_response.gd")
const TIMEOUT_SEC := 10.0

var _refreshing := false


func get_json(path: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, path)


func post_json(path: String, body: Variant = {}) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, path, body)


func request(method: int, path: String, body: Variant = null, auth: bool = true, retry: bool = true) -> Dictionary:
	var res := await _send(method, path, body, auth)
	if res.status == 401 and auth and retry and Session.refresh_token != "":
		match await refresh_tokens():
			ApiResponse.REFRESH_OK:
				res = await _send(method, path, body, auth)
			ApiResponse.REFRESH_FAILED:
				res = {"ok": false, "status": 0, "code": "AUTH_REFRESH_FAILED",
					"message": "không làm mới được phiên đăng nhập", "data": null}
			# REFRESH_REJECTED: refresh_tokens() cleared the session; the 401 stands.
	return res


## Exchanges the refresh token for new tokens. Returns an ApiResponse.REFRESH_* outcome; only
## REFRESH_REJECTED clears the session.
func refresh_tokens() -> int:
	if _refreshing:
		return await _refresh_done
	_refreshing = true
	var res := await _send(HTTPClient.METHOD_POST, "/auth/refresh", {"refreshToken": Session.refresh_token}, false)
	var outcome := ApiResponse.refresh_outcome(res)
	match outcome:
		ApiResponse.REFRESH_OK:
			Session.set_tokens(str(res.data["accessToken"]), str(res.data.get("refreshToken", Session.refresh_token)))
		ApiResponse.REFRESH_REJECTED:
			Session.clear_tokens()
	_refreshing = false
	_refresh_done.emit(outcome)
	return outcome


func _send(method: int, path: String, body: Variant, auth: bool) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth and Session.access_token != "":
		headers.append("Authorization: Bearer " + Session.access_token)
	var text := "" if body == null else JSON.stringify(body)
	if req.request(Config.api_url + path, headers, method, text) != OK:
		req.queue_free()
		return ApiResponse.parse(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
	var result: Array = await req.request_completed
	req.queue_free()
	return ApiResponse.parse(result[0], result[1], result[3])
```

- [ ] **Step 3: Create `autoload/game_socket.gd`**

```gdscript
extends Node
## WebSocket link to cmd/game (/ws?token=). Polled every frame; each server message is emitted
## as event_received(event, data). Messages sent while connecting wait in a small outbox; the
## outbox is dropped when a connection closes, because commands meant for the old connection
## (a QuickPlay, a Move) must not replay on the next one. Reconnects with backoff, reading the
## current token each time and refreshing it every third failure; stops when the session is
## gone. hold()/release() buffer events across a scene change (MatchStarted is followed by
## TurnStarted in the same read).

signal connected
signal disconnected
signal event_received(event: String, data: Variant)

const Envelope := preload("res://core/envelope.gd")
const MAX_BACKOFF_SEC := 10.0
const MAX_OUTBOX := 32
const INBOUND_BUFFER := 4 * 1024 * 1024 # MatchStarted carries the whole terrain snapshot

var _ws := WebSocketPeer.new()
var _want_open := false
var _was_open := false
var _dialing := false
var _retry_in := -1.0
var _failures := 0
var _outbox: Array[String] = []
var _held := false
var _held_events: Array = []


func is_open() -> bool:
	return _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func open() -> void:
	_want_open = true
	_failures = 0
	_retry_in = -1.0
	_dial()


func close() -> void:
	_want_open = false
	_retry_in = -1.0
	_outbox.clear()
	_ws.close()


func send(event: String, data: Variant = {}) -> void:
	var text := Envelope.encode(event, data)
	if is_open():
		_ws.send_text(text)
	elif _want_open and _outbox.size() < MAX_OUTBOX:
		_outbox.append(text)


## Buffers incoming events until release(); used while switching to a scene that consumes them.
func hold() -> void:
	_held = true


func release() -> void:
	_held = false
	var events := _held_events
	_held_events = []
	for e in events:
		event_received.emit(e[0], e[1])


func _process(delta: float) -> void:
	if _retry_in >= 0.0:
		_retry_in -= delta
		if _retry_in < 0.0:
			_redial()
		return

	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				_failures = 0
				for text in _outbox:
					_ws.send_text(text)
				_outbox.clear()
				connected.emit()
			while _ws.get_available_packet_count() > 0:
				var msg := Envelope.decode(_ws.get_packet().get_string_from_utf8())
				if not msg.is_empty():
					_emit(msg["event"], msg["data"])
		WebSocketPeer.STATE_CLOSED:
			if _was_open:
				_was_open = false
				_outbox.clear()
				disconnected.emit()
			if _want_open and not _dialing and _retry_in < 0.0:
				_failures += 1
				_retry_in = minf(pow(2.0, _failures - 1), MAX_BACKOFF_SEC)


func _emit(event: String, data: Variant) -> void:
	if _held:
		_held_events.append([event, data])
	else:
		event_received.emit(event, data)


func _redial() -> void:
	_dialing = true
	if _failures % 3 == 0 and Session.refresh_token != "":
		await Api.refresh_tokens()
	_dialing = false
	if not Session.has_token():
		_want_open = false # refresh was rejected: the session is gone (Splash/Login takes over)
		return
	if _want_open:
		_dial()


func _dial() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = INBOUND_BUFFER
	_ws.max_queued_packets = 4096
	var url := "%s/ws?token=%s" % [Config.ws_url, Session.access_token.uri_encode()]
	if _ws.connect_to_url(url) != OK:
		_failures += 1
		_retry_in = minf(pow(2.0, _failures - 1), MAX_BACKOFF_SEC)
```

- [ ] **Step 4: Create `autoload/router.gd`**

```gdscript
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
```

- [ ] **Step 5: Register the autoloads in `project.godot`**

Insert this section after the `[application]` section:

```ini
[autoload]

Config="*res://autoload/config.gd"
Session="*res://autoload/session.gd"
Api="*res://autoload/api.gd"
GameSocket="*res://autoload/game_socket.gd"
Router="*res://autoload/router.gd"
```

- [ ] **Step 6: Load the project headless and check for errors**

Run: `"$GODOT" --headless --path . --quit 2>&1 | grep -iE "error|failed" || echo "clean"`
Expected: `clean`.

Run: `tests/run.sh`
Expected: `12 passed, 0 failed`.

- [ ] **Step 7: Commit**

```bash
git add autoload project.godot
git commit -m "feat: config, api, game socket and router autoloads"
```

---

### Task 4b: Server — refresh keeps the session usable on server failures (server repo)

The server's `RefreshToken` has three problems that break Task 4's rule ("clear the session only when the server rejects the token"):

1. **It maps every error to 401** (`internal/api/auth/handler.go`). That includes a Redis outage (`Get` failing with something other than `redis.Nil`) and DB errors, so the client cannot tell "log in again" from "try later".
2. **It revokes the old session before saving the new one.** `Del(old)` runs, and only then does `generateLoginTokens` call `Set(new)`. If `Set` fails, the server answers 5xx but the old token is already gone, so the next retry gets 401 and the player is logged out.
3. **Tokens have no unique ID.** Two refresh tokens signed in the same second with the same claims are identical strings. So the fix for problem 2 ("save new, then delete old") would delete the session it just saved whenever a refresh happens in the same second as a login. Every token therefore gets a random `jti`.

**Files:**
- Modify: `../battle-squad/internal/shared/auth/jwt.go` (`Generate`)
- Test: `../battle-squad/internal/shared/auth/jwt_test.go`
- Modify: `../battle-squad/internal/api/auth/service.go` (`Service`, `NewService`, `RefreshToken`)
- Modify: `../battle-squad/internal/api/auth/handler.go` (`RefreshToken`)
- Test: `../battle-squad/internal/api/auth/handler_test.go`, `../battle-squad/internal/api/auth/service_test.go`

- [ ] **Step 1: Write the failing tests**

`../battle-squad/internal/shared/auth/jwt_test.go`:

```go
package auth

import (
	"testing"
	"time"
)

func TestGenerateTokensAreUniqueWithinOneSecond(t *testing.T) {
	m := NewJWTManager("secret", time.Hour)
	a, err := m.Generate("acc-1", "player-1", "player")
	if err != nil {
		t.Fatal(err)
	}
	b, err := m.Generate("acc-1", "player-1", "player")
	if err != nil {
		t.Fatal(err)
	}
	if a == b {
		t.Fatal("two tokens with the same claims in the same second are identical")
	}
	if _, err := m.Verify(a); err != nil {
		t.Fatalf("token with jti does not verify: %v", err)
	}
}
```

`../battle-squad/internal/api/auth/handler_test.go`:

```go
package auth

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"

	"battle-squad/internal/shared/auth"
	"battle-squad/internal/shared/database"
)

// newRefreshHandler wires a Service whose Redis is unreachable, so any lookup fails with a
// connection error (not redis.Nil).
func newRefreshHandler() (*Handler, *auth.JWTManager) {
	jwtRefresh := auth.NewJWTManager("test-refresh-secret", time.Hour)
	deadRedis := &database.RedisClient{Client: redis.NewClient(&redis.Options{
		Addr:        "127.0.0.1:1",
		DialTimeout: 50 * time.Millisecond,
		MaxRetries:  -1,
	})}
	svc := NewService(nil, deadRedis, auth.NewJWTManager("test-access-secret", time.Hour), jwtRefresh)
	return NewHandler(svc), jwtRefresh
}

func postRefresh(h *Handler, token string) *httptest.ResponseRecorder {
	body, _ := json.Marshal(RefreshTokenRequest{RefreshToken: token})
	rec := httptest.NewRecorder()
	h.RefreshToken(rec, httptest.NewRequest(http.MethodPost, "/auth/refresh", bytes.NewReader(body)))
	return rec
}

func TestRefreshRejectsMalformedTokenWith401(t *testing.T) {
	h, _ := newRefreshHandler()
	if rec := postRefresh(h, "not-a-jwt"); rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want 401", rec.Code)
	}
}

func TestRefreshReportsSessionStoreFailureAs500(t *testing.T) {
	h, jwtRefresh := newRefreshHandler()
	token, err := jwtRefresh.Generate("acc-1", "player-1", "player")
	if err != nil {
		t.Fatal(err)
	}
	if rec := postRefresh(h, token); rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500 (Redis down is not an invalid token)", rec.Code)
	}
}
```

`../battle-squad/internal/api/auth/service_test.go`:

```go
package auth

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"

	"battle-squad/internal/shared/auth"
	"battle-squad/internal/shared/database"
)

// fakeAccounts satisfies accountLookup without a database.
type fakeAccounts struct{}

func (fakeAccounts) FindAccountByID(_ context.Context, accountID string) (*Account, error) {
	return &Account{AccountID: accountID, Status: "active", Role: "player"}, nil
}

func (fakeAccounts) GetPlayerProfileByAccountID(_ context.Context, _ string) (string, string, int, error) {
	return "player-1", "Bob", 3, nil
}

// fakeRedis answers GET/SET/DEL from a map without a server (the hook never calls next).
// SET fails when failSet is true.
type fakeRedis struct {
	data    map[string]string
	failSet bool
}

func (f *fakeRedis) DialHook(next redis.DialHook) redis.DialHook { return next }

func (f *fakeRedis) ProcessPipelineHook(next redis.ProcessPipelineHook) redis.ProcessPipelineHook {
	return next
}

func (f *fakeRedis) ProcessHook(redis.ProcessHook) redis.ProcessHook {
	return func(_ context.Context, cmd redis.Cmder) error {
		key := fmt.Sprint(cmd.Args()[1])
		switch c := cmd.(type) {
		case *redis.StringCmd: // GET
			if v, ok := f.data[key]; ok {
				c.SetVal(v)
			} else {
				c.SetErr(redis.Nil)
			}
		case *redis.StatusCmd: // SET
			if f.failSet {
				c.SetErr(errors.New("set failed"))
			} else {
				f.data[key] = fmt.Sprint(cmd.Args()[2])
				c.SetVal("OK")
			}
		case *redis.IntCmd: // DEL
			if _, ok := f.data[key]; ok {
				delete(f.data, key)
				c.SetVal(1)
			}
		default:
			cmd.SetErr(fmt.Errorf("unexpected command %v", cmd.Args()))
		}
		return cmd.Err()
	}
}

// newRotationService returns a Service holding one valid session for the returned refresh token.
func newRotationService(t *testing.T, failSet bool) (*Service, *fakeRedis, string) {
	t.Helper()
	fr := &fakeRedis{data: map[string]string{}, failSet: failSet}
	client := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1"})
	client.AddHook(fr)
	jwtRefresh := auth.NewJWTManager("test-refresh-secret", time.Hour)
	svc := &Service{
		accounts:   fakeAccounts{},
		redis:      &database.RedisClient{Client: client},
		jwtAccess:  auth.NewJWTManager("test-access-secret", time.Hour),
		jwtRefresh: jwtRefresh,
	}
	old, err := jwtRefresh.Generate("acc-1", "player-1", "player")
	if err != nil {
		t.Fatal(err)
	}
	fr.data["session:"+old] = "acc-1:player-1"
	return svc, fr, old
}

func TestRefreshKeepsOldSessionWhenSavingNewFails(t *testing.T) {
	svc, fr, old := newRotationService(t, true)
	_, err := svc.RefreshToken(context.Background(), old)
	if err == nil || errors.Is(err, ErrInvalidRefreshToken) {
		t.Fatalf("err = %v, want a server failure", err)
	}
	if _, ok := fr.data["session:"+old]; !ok {
		t.Fatal("old session revoked although the new one was not saved: the player gets logged out on retry")
	}
}

func TestRefreshRotatesSession(t *testing.T) {
	svc, fr, old := newRotationService(t, false)
	resp, err := svc.RefreshToken(context.Background(), old)
	if err != nil {
		t.Fatal(err)
	}
	if resp.RefreshToken == old {
		t.Fatal("new refresh token equals the old one")
	}
	if _, ok := fr.data["session:"+old]; ok {
		t.Fatal("old session still valid after rotation")
	}
	if _, ok := fr.data["session:"+resp.RefreshToken]; !ok {
		t.Fatal("new session not saved")
	}
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (in `../battle-squad`): `go test ./internal/shared/auth/ ./internal/api/auth/ -v 2>&1 | grep -E "^(---|ok|FAIL)|want|unknown field|undefined"`

Expected:
- the auth package fails to compile with `unknown field accounts`;
- `TestGenerateTokensAreUniqueWithinOneSecond` FAILS (`identical`).

- [ ] **Step 3: Give every token a random `jti` in `jwt.go`**

Add `"crypto/rand"` and `"encoding/hex"` to the imports. Then replace `Generate`:

```go
func (m *JWTManager) Generate(accountID, playerID, role string) (string, error) {
	// A random ID keeps tokens with the same claims signed in the same second distinct, so a
	// refresh can store the new session before revoking the old one.
	id := make([]byte, 16)
	if _, err := rand.Read(id); err != nil {
		return "", err
	}
	claims := Claims{
		AccountID: accountID,
		PlayerID:  playerID,
		Role:      role,
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        hex.EncodeToString(id),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(m.tokenDuration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.secretKey)
}
```

- [ ] **Step 4: Refresh: errors classified, new session saved before the old is revoked (`service.go`)**

Add `"github.com/redis/go-redis/v9"` and `"battle-squad/internal/shared/observability"` to the imports. Replace the `Service` struct and `NewService`:

```go
// accountLookup is the part of Repository that RefreshToken needs (faked in tests).
type accountLookup interface {
	FindAccountByID(ctx context.Context, accountID string) (*Account, error)
	GetPlayerProfileByAccountID(ctx context.Context, accountID string) (string, string, int, error)
}

type Service struct {
	repo       *Repository
	accounts   accountLookup
	redis      *database.RedisClient
	jwtAccess  *auth.JWTManager
	jwtRefresh *auth.JWTManager
}

func NewService(repo *Repository, redis *database.RedisClient, jwtAccess, jwtRefresh *auth.JWTManager) *Service {
	return &Service{
		repo:       repo,
		accounts:   repo,
		redis:      redis,
		jwtAccess:  jwtAccess,
		jwtRefresh: jwtRefresh,
	}
}
```

Replace the whole `RefreshToken` function, and add the sentinels above it:

```go
// ErrInvalidRefreshToken means the refresh token is malformed, expired, revoked or names no
// account: the client must log in again. Any other RefreshToken error is a server failure.
var ErrInvalidRefreshToken = errors.New("invalid refresh token")

// ErrAccountBanned means the token is valid but the account may not get new tokens.
var ErrAccountBanned = errors.New("account banned")

func (s *Service) RefreshToken(ctx context.Context, refreshToken string) (*LoginResponse, error) {
	// Verify refresh token structure
	claims, err := s.jwtRefresh.Verify(refreshToken)
	if err != nil {
		return nil, ErrInvalidRefreshToken
	}

	// Check if refresh token is in Redis (revocation check)
	redisKey := "session:" + refreshToken
	_, err = s.redis.Client.Get(ctx, redisKey).Result()
	if errors.Is(err, redis.Nil) {
		return nil, ErrInvalidRefreshToken
	}
	if err != nil {
		return nil, fmt.Errorf("check refresh session: %w", err)
	}

	// Get account details (for role)
	acc, err := s.accounts.FindAccountByID(ctx, claims.AccountID)
	if err != nil {
		return nil, err
	}
	if acc == nil {
		return nil, ErrInvalidRefreshToken
	}
	if acc.Status == "banned" {
		return nil, ErrAccountBanned
	}

	// Get player details
	playerID, displayName, level, err := s.accounts.GetPlayerProfileByAccountID(ctx, claims.AccountID)
	if err != nil {
		return nil, err
	}

	// Save the new session before revoking the old one: if saving fails, the old refresh token
	// still works and the client can retry.
	resp, err := s.generateLoginTokens(ctx, claims.AccountID, playerID, acc.Role, displayName, level)
	if err != nil {
		return nil, err
	}
	if err := s.redis.Client.Del(ctx, redisKey).Err(); err != nil {
		// The old token stays valid until its TTL; better than failing a refresh that succeeded.
		log := observability.FromContext(ctx)
		log.Warn().Err(err).Str("accountId", claims.AccountID).Msg("refresh: old session not revoked")
	}
	return resp, nil
}
```

- [ ] **Step 5: Map the errors in `handler.go`**

Add `"errors"` and `"battle-squad/internal/shared/observability"` to the imports. Then replace the error branch of `RefreshToken`:

```go
	resp, err := h.service.RefreshToken(r.Context(), req.RefreshToken)
	switch {
	case errors.Is(err, ErrInvalidRefreshToken):
		model.WriteError(w, r, model.ErrUnauthorized)
		return
	case errors.Is(err, ErrAccountBanned):
		model.WriteError(w, r, model.ErrBanned)
		return
	case err != nil:
		log := observability.FromContext(r.Context())
		log.Error().Err(err).Msg("refresh token failed")
		model.WriteError(w, r, model.ErrInternalServer)
		return
	}

	model.WriteOK(w, resp)
```

- [ ] **Step 6: Run the tests to verify they pass**

Run (in `../battle-squad`): `go test ./internal/shared/auth/ ./internal/api/auth/ -v && go build ./... && go vet ./internal/shared/auth/ ./internal/api/auth/`

Expected: all 5 tests PASS (`TestGenerateTokensAreUnique…`, `TestRefreshRejects…`, `TestRefreshReports…`, `TestRefreshKeepsOldSession…`, `TestRefreshRotatesSession`), and the build is clean.

- [ ] **Step 7: Commit (server repo)**

```bash
cd ../battle-squad
git add internal/shared/auth internal/api/auth
git commit -m "fix: refresh rotation keeps the old session until the new one is saved; 401 only for unusable tokens"
```

---

### Task 4c: Server — `PlayerMoved` echoes the `Move` sequence number (server repo, protocol addition)

`PlayerMoved` does not say which `Move` it answers. Once the client re-sends a command after a timeout, a late answer to an older command would be taken as the answer to the re-sent one: the character jumps back, then forward again. To fix that, the client numbers each `Move` and the server echoes the number.

**Protocol change (backward compatible):**
- `Move` gains an optional `seq` (int ≥ 1).
- `PlayerMoved` that answers a `Move` carrying a `seq` includes the same `seq`. When there is no `seq`, nothing changes: older clients and bot moves keep the old payload.
- A rejected `Move` (not your turn, frozen, rate limited, NaN) still gets no answer, as before. After a bounded number of re-sends, the client treats its position as unknown and fetches `MatchStateSync`.

**Files:**
- Modify: `../battle-squad/internal/game/match/model.go` (`MoveAction`)
- Modify: `../battle-squad/internal/game/match/match.go` (`processMove` broadcast)
- Test: `../battle-squad/internal/game/match/move_seq_test.go`
- Modify: `../battle-squad/docs/technical-documentation.md` (client events table)

- [ ] **Step 1: Write the failing test `../battle-squad/internal/game/match/move_seq_test.go`**

```go
package match

import (
	"encoding/json"
	"testing"
	"time"

	"battle-squad/internal/game/ws"
)

func nextPlayerMoved(t *testing.T, c *ws.Client) map[string]any {
	t.Helper()
	select {
	case msg := <-c.Send:
		if msg.Event != "PlayerMoved" {
			t.Fatalf("got %s, want PlayerMoved", msg.Event)
		}
		var data map[string]any
		if err := json.Unmarshal(msg.Data, &data); err != nil {
			t.Fatal(err)
		}
		return data
	case <-time.After(time.Second):
		t.Fatal("no PlayerMoved")
		return nil
	}
}

func TestPlayerMovedEchoesMoveSeq(t *testing.T) {
	m, clients := newFlowMatch(t)
	cur := m.State.CurrentPlayerID
	p := m.State.Players[cur]
	p.Position.Y = m.Terrain.GetLandingY(p.Position.X, 0)
	p.MoveEnergy = 100
	watcher := clients[m.other(cur)]
	drain(watcher)

	send(m, clients[cur], "Move", MoveAction{TargetX: p.Position.X + 20, Seq: 7})
	if got := nextPlayerMoved(t, watcher)["seq"]; got != float64(7) {
		t.Fatalf("seq = %v, want 7", got)
	}

	send(m, clients[cur], "Move", MoveAction{TargetX: p.Position.X + 20})
	if data := nextPlayerMoved(t, watcher); data["seq"] != nil {
		t.Fatalf("seq = %v, want absent for a Move without seq", data["seq"])
	}
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run (in `../battle-squad`): `go test ./internal/game/match/ -run TestPlayerMovedEchoesMoveSeq -v`
Expected: a build failure with `unknown field Seq in struct literal of type MoveAction`.

- [ ] **Step 3: Add the field in `model.go`**

```go
type MoveAction struct {
	Direction       string  `json:"direction"` // left, right
	TargetX         float64 `json:"targetX"`
	Seq             int     `json:"seq,omitempty"` // client command number, echoed in PlayerMoved
	ClientTimestamp int64   `json:"clientTimestamp"`
}
```

- [ ] **Step 4: Echo it in `processMove` (`match.go`)**

Replace the `// Broadcast PlayerMoved` block at the end of `processMove`:

```go
	// Broadcast PlayerMoved; seq tells the mover which of its commands this answers
	moved := map[string]interface{}{
		"playerId":   player.PlayerID,
		"position":   player.Position,
		"moveEnergy": player.MoveEnergy,
	}
	if action.Seq > 0 {
		moved["seq"] = action.Seq
	}
	payload, _ := json.Marshal(moved)
	m.broadcast(ws.Message{
		Event: "PlayerMoved",
		Data:  payload,
	})
```

- [ ] **Step 5: Document it in `../battle-squad/docs/technical-documentation.md`**

In the client → server table, change the `Move` row to:

```
| `Move` | `{direction, targetX, seq?}` | Di chuyển trái/phải; `seq` (tuỳ chọn) được trả lại trong `PlayerMoved` |
```

In the server → client table, change the `PlayerMoved` row to:

```
| `PlayerMoved` | `{playerId, position, moveEnergy, seq?}` | Player di chuyển; có `seq` khi trả lời `Move` có `seq` |
```

- [ ] **Step 6: Run the tests to verify they pass**

Run (in `../battle-squad`): `go test ./internal/game/match/ && go build ./...`
Expected: `ok`.

- [ ] **Step 7: Commit (server repo)**

```bash
cd ../battle-squad
git add internal/game/match/model.go internal/game/match/match.go internal/game/match/move_seq_test.go docs/technical-documentation.md
git commit -m "feat: PlayerMoved echoes the optional Move seq"
```

---

### Task 5: Parity fixture exporter (server repo)

The client terrain, shot preview and move prediction must match the server exactly, or predicted walks, craters and aim lines drift. This Go test writes a fixture from the real server code: `Terrain`, `SimulateProjectile` and `processMove`. The Godot tests replay it.

**Files:**
- Create: `../battle-squad/internal/game/match/client_fixture_test.go`
- Create (generated): `tests/fixtures/terrain_parity.json`

- [ ] **Step 1: Create `../battle-squad/internal/game/match/client_fixture_test.go`**

```go
package match

import (
	"context"
	"encoding/json"
	"math"
	"math/rand"
	"os"
	"testing"

	"battle-squad/internal/game/gamedata"
)

type fixtureOp struct {
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	Radius float64 `json:"radius"`
}

type fixtureLanding struct {
	X      float64 `json:"x"`
	StartY float64 `json:"startY"`
	Y      float64 `json:"y"`
}

type fixtureWalk struct {
	StartX  float64 `json:"startX"`
	StartY  float64 `json:"startY"`
	TargetX float64 `json:"targetX"`
	X       float64 `json:"x"`
	Y       float64 `json:"y"`
}

// fixtureShot is SimulateProjectile against terrain only. The initial velocity is recorded,
// not the angle, so the client parity test avoids Go-vs-C differences in cos/sin.
type fixtureShot struct {
	X         float64 `json:"x"`
	Y         float64 `json:"y"`
	VX        float64 `json:"vx"`
	VY        float64 `json:"vy"`
	WindForce float64 `json:"windForce"`
	Hit       bool    `json:"hit"`
	HitX      float64 `json:"hitX"`
	HitY      float64 `json:"hitY"`
}

type fixtureMoveStep struct {
	TargetX float64 `json:"targetX"`
	X       float64 `json:"x"`
	Y       float64 `json:"y"`
	Energy  int     `json:"energy"`
}

// fixtureMoveSeq is a series of Move commands run through the real processMove.
type fixtureMoveSeq struct {
	StartX float64           `json:"startX"`
	StartY float64           `json:"startY"`
	Energy int               `json:"energy"`
	Steps  []fixtureMoveStep `json:"steps"`
}

// TestExportClientFixture writes parity cases for the Godot client's port of snapshot decoding,
// DestroyCircle, GetLandingY, WalkTo, the shot integration and processMove. It runs only when
// CLIENT_FIXTURE_OUT names the output file.
func TestExportClientFixture(t *testing.T) {
	out := os.Getenv("CLIENT_FIXTURE_OUT")
	if out == "" {
		t.Skip("set CLIENT_FIXTURE_OUT to export the client terrain fixture")
	}

	const cols, rows, cell = 40, 24, 16
	rng := rand.New(rand.NewSource(7))

	// Rolling destructible ground on an indestructible bedrock row, plus floating blocks.
	tiles := make([][]int, rows)
	for r := range tiles {
		tiles[r] = make([]int, cols)
	}
	ground := 14
	for c := 0; c < cols; c++ {
		ground += rng.Intn(3) - 1
		if ground < 8 {
			ground = 8
		}
		if ground > 20 {
			ground = 20
		}
		for r := ground; r < rows-1; r++ {
			tiles[r][c] = 1
		}
		tiles[rows-1][c] = 2
		if rng.Intn(6) == 0 {
			tiles[4+rng.Intn(3)][c] = 1
		}
	}
	bricks := map[int]gamedata.BrickTypeConfig{
		1: {BrickTypeID: 1, Destructible: true},
		2: {BrickTypeID: 2, Destructible: false},
	}
	terrain := NewTerrainWithBricks(gamedata.MapConfig{
		MapID: "client_fixture", GridWidth: cols, GridHeight: rows, CellSize: cell, Tiles: tiles,
	}, bricks)
	before := terrain.Snapshot()

	var ops []fixtureOp
	for i := 0; i < 12; i++ {
		x := rng.Float64() * float64(terrain.Width)
		ops = append(ops, fixtureOp{X: x, Y: terrain.GetLandingY(x, 0) + rng.Float64()*20 - 10, Radius: 15 + rng.Float64()*30})
	}
	ops = append(ops,
		fixtureOp{X: 2, Y: terrain.GetLandingY(2, 0), Radius: 30},               // clipped at the left edge
		fixtureOp{X: 320, Y: float64(terrain.Height - 8), Radius: 40},           // hits indestructible bedrock
		fixtureOp{X: 100.5, Y: terrain.GetLandingY(100, 0) + 0.5, Radius: 20.5}, // half-pixel rounding
	)
	for _, op := range ops {
		terrain.DestroyCircle(op.X, op.Y, op.Radius)
	}
	after := terrain.Snapshot()

	var landings []fixtureLanding
	for i := 0; i < 40; i++ {
		x := rng.Float64()*float64(terrain.Width+20) - 10
		startY := rng.Float64() * float64(terrain.Height)
		landings = append(landings, fixtureLanding{X: x, StartY: startY, Y: terrain.GetLandingY(x, startY)})
	}

	var walks []fixtureWalk
	for len(walks) < 40 {
		sx := float64(rng.Intn(terrain.Width))
		sy := terrain.GetLandingY(sx, 0)
		if sy >= float64(terrain.Height) {
			continue
		}
		tx := sx + float64(rng.Intn(401)-200)
		x, y := terrain.WalkTo(sx, sy, tx)
		walks = append(walks, fixtureWalk{StartX: sx, StartY: sy, TargetX: tx, X: x, Y: y})
	}

	// Shots use the getPhysics() defaults the client preview assumes.
	savedPhysics := gamedata.Physics
	gamedata.Physics = nil
	defer func() { gamedata.Physics = savedPhysics }()
	_, _, windScale, _, _, _ := getPhysics()
	weapon := gamedata.WeaponConfig{ExplosionRadius: 20, ProjectileWeight: 1, WindInfluence: 1}
	var shots []fixtureShot
	for len(shots) < 60 {
		w := walks[len(shots)%len(walks)]
		angle := rng.Float64() * 180
		power := 10 + rng.Float64()*90
		wind := WindState{Direction: rng.Intn(3) - 1, Power: rng.Float64() * 4}
		r := SimulateProjectile("shooter", 1, Vector2{X: w.StartX, Y: w.StartY}, angle, power, weapon, wind,
			terrain, map[string]*BattlePlayerState{}, 0)
		rad := angle * math.Pi / 180.0
		shot := fixtureShot{
			X: w.StartX, Y: w.StartY,
			VX: power * 6.0 * math.Cos(rad), VY: -power * 6.0 * math.Sin(rad),
			WindForce: float64(wind.Direction) * wind.Power * windScale * weapon.WindInfluence,
		}
		if r.ExplosionPoint != nil {
			shot.Hit, shot.HitX, shot.HitY = true, r.ExplosionPoint.X, r.ExplosionPoint.Y
		}
		shots = append(shots, shot)
	}

	// Move sequences through the real processMove, with direction changes and energy limits.
	m, _ := newFlowMatch(t)
	m.Terrain = terrain
	mover := m.State.Players[m.State.CurrentPlayerID]
	var moves []fixtureMoveSeq
	for len(moves) < 6 {
		w := walks[rng.Intn(len(walks))]
		seq := fixtureMoveSeq{StartX: w.StartX, StartY: w.StartY, Energy: 60 + rng.Intn(41)}
		mover.Position = Vector2{X: w.StartX, Y: w.StartY}
		mover.MoveEnergy = seq.Energy
		for i := 0; i < 12; i++ {
			tx := mover.Position.X + float64(rng.Intn(51)-25)
			if i == 10 {
				tx = mover.Position.X + float64(rng.Intn(601)-300) // beyond the energy budget
			}
			m.processMove(context.Background(), nil, MoveAction{TargetX: tx})
			seq.Steps = append(seq.Steps, fixtureMoveStep{TargetX: tx, X: mover.Position.X, Y: mover.Position.Y, Energy: mover.MoveEnergy})
		}
		moves = append(moves, seq)
	}

	data, err := json.MarshalIndent(map[string]any{
		"before":   before,
		"ops":      ops,
		"after":    after,
		"landings": landings,
		"walks":    walks,
		"shots":    shots,
		"moves":    moves,
	}, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(out, data, 0o644); err != nil {
		t.Fatal(err)
	}
	t.Logf("wrote %s (%dx%d, %d ops, %d landings, %d walks, %d shots, %d move sequences)",
		out, terrain.Width, terrain.Height, len(ops), len(landings), len(walks), len(shots), len(moves))
}
```

- [ ] **Step 2: Check that the test is skipped by default**

Run (in `../battle-squad`): `go test ./internal/game/match/ -run TestExportClientFixture -v`
Expected: `--- SKIP: TestExportClientFixture`.

- [ ] **Step 3: Generate the fixture into the client repo**

```bash
mkdir -p ../battle-squad-game/tests/fixtures
cd ../battle-squad && CLIENT_FIXTURE_OUT="$(cd ../battle-squad-game && pwd)/tests/fixtures/terrain_parity.json" \
  go test ./internal/game/match/ -run TestExportClientFixture -v
```

Expected: `wrote .../terrain_parity.json (640x384, 15 ops, 40 landings, 40 walks, 60 shots, 6 move sequences)` and `PASS`.

- [ ] **Step 4: Commit in both repos**

```bash
cd ../battle-squad && git add internal/game/match/client_fixture_test.go && git commit -m "test: export terrain, shot and move parity fixture for the Godot client"
cd ../battle-squad-game && git add tests/fixtures/terrain_parity.json && git commit -m "test: parity fixture from the server"
```

(Server repo rule from its CLAUDE.md: the commit message lists changes only, with no Co-Authored-By line.)

---

### Task 6: TerrainMask — snapshot decoding and craters

**Files:**
- Create: `match/terrain/terrain_mask.gd`
- Test: `tests/unit/test_terrain_mask.gd`

- [ ] **Step 1: Write the failing tests `tests/unit/test_terrain_mask.gd`**

```gdscript
extends "res://tests/test_case.gd"

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const FIXTURE := "res://tests/fixtures/terrain_parity.json"


func _fixture() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))


func _diff_count(a: PackedByteArray, b: PackedByteArray) -> int:
	if a.size() != b.size():
		return -1
	var n := 0
	for i in a.size():
		if a[i] != b[i]:
			n += 1
	return n


func test_decode_rle_runs_start_with_air() -> void:
	# air 2, solid 3, air 1 → varints [2, 3, 1]
	var bytes := TerrainMask.decode_rle(Marshalls.raw_to_base64(PackedByteArray([2, 3, 1])), 6)
	eq(bytes, PackedByteArray([0, 0, 255, 255, 255, 0]), "decoded mask")


func test_decode_rle_multibyte_varint() -> void:
	# 300 = 0xAC 0x02 as an unsigned varint, then a 1-pixel solid run
	var bytes := TerrainMask.decode_rle(Marshalls.raw_to_base64(PackedByteArray([0xAC, 0x02, 1])), 301)
	eq(bytes.size(), 301, "size")
	eq(bytes[299], 0, "last air pixel")
	eq(bytes[300], 255, "solid pixel")


func test_load_snapshot_rejects_wrong_size() -> void:
	var m := TerrainMask.new()
	var ok := m.load_snapshot({"width": 4, "height": 2, "version": 0,
		"solid": Marshalls.raw_to_base64(PackedByteArray([3])), "destructible": Marshalls.raw_to_base64(PackedByteArray([3]))})
	check(not ok, "3 pixels for a 4x2 map must be rejected")


func test_is_solid_bounds() -> void:
	var m := TerrainMask.new()
	m.load_snapshot({"width": 2, "height": 2, "version": 0,
		"solid": Marshalls.raw_to_base64(PackedByteArray([2, 2])), "destructible": Marshalls.raw_to_base64(PackedByteArray([4]))})
	check(not m.is_solid(0, 0), "top row is air")
	check(m.is_solid(1, 1), "bottom row is solid")
	check(not m.is_solid(-1, 1), "left of map is air")
	check(not m.is_solid(2, 1), "right of map is air")
	check(not m.is_solid(0, -1), "sky is air")
	check(m.is_solid(0, 5), "below map is solid floor")


func test_destroy_circle_matches_server() -> void:
	var f := _fixture()
	var m := TerrainMask.new()
	check(m.load_snapshot(f["before"]), "load before snapshot")
	for op in f["ops"]:
		m.destroy_circle(float(op["x"]), float(op["y"]), float(op["radius"]))
	var n := m.width * m.height
	eq(_diff_count(m.solid, TerrainMask.decode_rle(f["after"]["solid"], n)), 0, "solid pixels differing from server")
	eq(_diff_count(m.destructible, TerrainMask.decode_rle(f["after"]["destructible"], n)), 0, "destructible pixels differing")
	eq(m.version, int(f["after"]["version"]), "version after ops")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run.sh`
Expected: script error, because `res://match/terrain/terrain_mask.gd` does not exist yet.

- [ ] **Step 3: Create `match/terrain/terrain_mask.gd`**

```gdscript
extends RefCounted
## Client copy of the server terrain (battle-squad internal/game/match/terrain.go). Every query
## must match the Go code exactly, including rounding: the server decides, the client predicts
## and draws. Parity is tested against tests/fixtures/terrain_parity.json.
##
## Masks are row-major (index = y * width + x), one byte per pixel: SOLID or 0. The solid bytes
## double as the L8 image the terrain view uploads.

const SOLID := 255
const PLAYER_HEIGHT := 40 # match.PlayerHeight
const MAX_CLIMB_PER_STEP := 3 # Terrain.WalkTo maxClimbPerStep

var width := 0
var height := 0
var version := 0
var solid := PackedByteArray()
var destructible := PackedByteArray()


## Loads a TerrainSnapshot {width, height, version, solid, destructible}. Returns false if the
## encoded masks do not cover width * height pixels.
func load_snapshot(snap: Dictionary) -> bool:
	var w := int(snap.get("width", 0))
	var h := int(snap.get("height", 0))
	var n := w * h
	var s := decode_rle(str(snap.get("solid", "")), n)
	var d := decode_rle(str(snap.get("destructible", "")), n)
	if n <= 0 or s.size() != n or d.size() != n:
		return false
	width = w
	height = h
	version = int(snap.get("version", 0))
	solid = s
	destructible = d
	return true


## Decodes the server's mask encoding: alternating air/solid run lengths (air first) as unsigned
## varints, base64 (std). Whole runs are appended at once, so large maps decode quickly.
static func decode_rle(encoded: String, n: int) -> PackedByteArray:
	var raw := Marshalls.base64_to_raw(encoded)
	var zeros := PackedByteArray()
	zeros.resize(n)
	zeros.fill(0)
	var ones := PackedByteArray()
	ones.resize(n)
	ones.fill(SOLID)

	var out := PackedByteArray()
	var current_solid := false
	var value := 0
	var shift := 0
	for b in raw:
		value |= (b & 0x7F) << shift
		if b & 0x80:
			shift += 7
			continue
		if value > 0:
			if out.size() + value > n:
				return PackedByteArray()
			out.append_array(ones.slice(0, value) if current_solid else zeros.slice(0, value))
		current_solid = not current_solid
		value = 0
		shift = 0
	return out


## Terrain.IsSolid: outside left/right and above the map is air; below the map is solid floor.
func is_solid(x: float, y: float) -> bool:
	var ix := roundi(x)
	var iy := roundi(y)
	if ix < 0 or ix >= width:
		return false
	if iy < 0:
		return false
	if iy >= height:
		return true
	return solid[iy * width + ix] != 0


## Terrain.DestroyCircle: clears destructible solid pixels within radius of (cx, cy).
func destroy_circle(cx: float, cy: float, radius: float) -> void:
	version += 1
	var icx := roundi(cx)
	var icy := roundi(cy)
	var ir := roundi(radius)
	var r2 := radius * radius
	for y in range(maxi(icy - ir, 0), mini(icy + ir, height - 1) + 1):
		var dy := float(y - icy)
		var row := y * width
		for x in range(maxi(icx - ir, 0), mini(icx + ir, width - 1) + 1):
			var dx := float(x - icx)
			if dx * dx + dy * dy <= r2:
				var i := row + x
				if destructible[i] != 0:
					solid[i] = 0
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tests/run.sh`
Expected: `17 passed, 0 failed`. If `test_destroy_circle_matches_server` reports differing pixels, compare the rounding with Go's `math.Round` (half away from zero, same as `roundi`) and the loop bounds with `terrain.go`. Do not loosen the test.

- [ ] **Step 5: Commit**

```bash
git add match/terrain/terrain_mask.gd tests/unit/test_terrain_mask.gd
git commit -m "feat: terrain mask snapshot decoding and craters with server parity"
```

---

### Task 7: TerrainMask — landing and walking

**Files:**
- Modify: `match/terrain/terrain_mask.gd` (append functions)
- Test: `tests/unit/test_terrain_mask.gd` (append tests)

- [ ] **Step 1: Append the failing tests to `tests/unit/test_terrain_mask.gd`**

```gdscript
func _after_mask(f: Dictionary):
	var m := TerrainMask.new()
	m.load_snapshot(f["after"])
	return m


func test_get_landing_y_matches_server() -> void:
	var f := _fixture()
	var m = _after_mask(f)
	for c in f["landings"]:
		eq(m.get_landing_y(float(c["x"]), float(c["startY"])), float(c["y"]),
			"landing at x=%s startY=%s" % [c["x"], c["startY"]])


func test_walk_to_matches_server() -> void:
	var f := _fixture()
	var m = _after_mask(f)
	for c in f["walks"]:
		eq(m.walk_to(float(c["startX"]), float(c["startY"]), float(c["targetX"])), Vector2(float(c["x"]), float(c["y"])),
			"walk %s,%s -> %s" % [c["startX"], c["startY"], c["targetX"]])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run.sh`
Expected: `Invalid call. Nonexistent function 'get_landing_y'`, which counts as a script error, and a non-zero exit.

- [ ] **Step 3: Append to `match/terrain/terrain_mask.gd`**

```gdscript
## Terrain.GetLandingY: first solid pixel at or below start_y in column x; height if none.
func get_landing_y(x: float, start_y: float) -> float:
	var ix := roundi(x)
	if ix < 0 or ix >= width:
		return float(height)
	var iy := maxi(roundi(start_y), 0)
	while iy < height:
		if solid[iy * width + ix] != 0:
			return float(iy)
		iy += 1
	return float(height)


## Terrain.WalkTo: walks column by column toward target_x along the surface; stops at walls
## taller than MAX_CLIMB_PER_STEP or where the body does not fit. Returns the end position.
func walk_to(start_x: float, start_y: float, target_x: float) -> Vector2:
	var cur_x := roundi(start_x)
	var cur_y := roundi(start_y)
	var end_x := roundi(target_x)
	if cur_x == end_x:
		return Vector2(start_x, start_y)
	var dir := 1 if end_x > cur_x else -1
	while cur_x != end_x:
		var next_x := cur_x + dir
		if next_x < 0 or next_x >= width:
			break
		var next_y := _step_surface(next_x, cur_y, MAX_CLIMB_PER_STEP)
		if next_y < 0:
			break
		cur_x = next_x
		cur_y = next_y
	return Vector2(cur_x, cur_y)


## Terrain.hasHeadroom: the PLAYER_HEIGHT pixels above surface_y in column x are free.
func _has_headroom(x: int, surface_y: int) -> bool:
	var y := maxi(surface_y - PLAYER_HEIGHT, 0)
	while y < surface_y and y < height:
		if solid[y * width + x] != 0:
			return false
		y += 1
	return true


## Terrain.stepSurface: surface Y after stepping into column x from cur_y, or -1 when blocked.
func _step_surface(x: int, cur_y: int, max_climb: int) -> int:
	var feet := cur_y - 1
	if feet >= height:
		return height
	if feet < 0 or solid[feet * width + x] == 0:
		# Flat or downhill: cross at the current height, then drop to the first solid pixel.
		if not _has_headroom(x, cur_y):
			return -1
		return int(get_landing_y(x, feet))
	# Uphill: climb to the top of the solid run, up to max_climb pixels.
	var y := feet
	while y > 0 and solid[(y - 1) * width + x] != 0:
		y -= 1
		if cur_y - y > max_climb:
			return -1
	if cur_y - y > max_climb or not _has_headroom(x, y):
		return -1
	return y
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tests/run.sh`
Expected: `19 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add match/terrain/terrain_mask.gd tests/unit/test_terrain_mask.gd
git commit -m "feat: terrain landing and walking with server parity"
```

---

### Task 8: ShotTimeline

**Files:**
- Create: `match/shot/shot_timeline.gd`
- Test: `tests/unit/test_shot_timeline.gd`

- [ ] **Step 1: Write the failing tests `tests/unit/test_shot_timeline.gd`**

```gdscript
extends "res://tests/test_case.gd"

const ShotTimeline := preload("res://match/shot/shot_timeline.gd")


func _step(t: float, x: float, y: float, vx: float, vy: float) -> Dictionary:
	return {"time": t, "position": {"x": x, "y": y}, "velocity": {"x": vx, "y": vy}}


func _timeline(path: Array):
	return ShotTimeline.new({
		"shooterId": "p1",
		"duration": 2.0,
		"projectiles": [{"projectileId": "a", "path": path}],
		"events": [
			{"t": 1.0, "type": "explode"},
			{"t": 1.0, "type": "damage"},
			{"t": 1.5, "type": "fall", "duration": 0.5},
		],
	})


func test_sample_interpolates_straight_flight() -> void:
	var tl = _timeline([_step(0, 0, 0, 10, 0), _step(1, 10, 0, 10, 0)])
	var p: Vector2 = tl.sample(0, 0.5)
	near(p.x, 5.0, 1e-6, "x at t=0.5")
	near(p.y, 0.0, 1e-6, "y at t=0.5")


func test_sample_follows_velocity_curve() -> void:
	# Up then down between two samples at the same point: Hermite puts the apex at -2.5.
	var tl = _timeline([_step(0, 0, 0, 0, -10), _step(1, 0, 0, 0, 10)])
	near(tl.sample(0, 0.5).y, -2.5, 1e-6, "apex")


func test_sample_clamps_outside_path() -> void:
	var tl = _timeline([_step(0, 0, 0, 10, 0), _step(1, 10, 0, 10, 0)])
	eq(tl.sample(0, -1.0), Vector2(0, 0), "before start")
	eq(tl.sample(0, 5.0), Vector2(10, 0), "after end")
	near(tl.projectile_end(0), 1.0, 1e-9, "projectile end")


func test_pop_due_returns_each_event_once_in_order() -> void:
	var tl = _timeline([_step(0, 0, 0, 10, 0), _step(1, 10, 0, 10, 0)])
	eq(tl.pop_due(0.5).size(), 0, "nothing before 1.0")
	var due: Array = tl.pop_due(1.0)
	eq(due.size(), 2, "two events at 1.0")
	eq(due[0]["type"], "explode", "explode first")
	eq(due[1]["type"], "damage", "damage second")
	eq(tl.pop_due(2.0).size(), 1, "fall at 1.5")
	eq(tl.pop_due(9.0).size(), 0, "nothing left")
	near(tl.duration, 2.0, 1e-9, "duration")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run.sh`
Expected: script error, because `shot_timeline.gd` does not exist yet.

- [ ] **Step 3: Create `match/shot/shot_timeline.gd`**

```gdscript
extends RefCounted
## Read-only view of a ShotResolved payload (server: internal/game/match/model.go). Positions
## between recorded path samples use cubic Hermite interpolation with the recorded velocities,
## so the projectile curve stays smooth at any frame rate.

var shooter_id := ""
var projectiles: Array = []
var events: Array = []
var duration := 0.0

var _cursor := 0


func _init(payload: Dictionary) -> void:
	shooter_id = str(payload.get("shooterId", ""))
	projectiles = payload.get("projectiles", [])
	events = payload.get("events", [])
	duration = float(payload.get("duration", 0.0))


func projectile_end(i: int) -> float:
	var path: Array = projectiles[i].get("path", [])
	return 0.0 if path.is_empty() else float(path[-1]["time"])


func sample(i: int, t: float) -> Vector2:
	var path: Array = projectiles[i].get("path", [])
	if path.is_empty():
		return Vector2.ZERO
	if t <= float(path[0]["time"]):
		return _vec(path[0]["position"])
	for k in range(path.size() - 1):
		var a: Dictionary = path[k]
		var b: Dictionary = path[k + 1]
		var ta := float(a["time"])
		var tb := float(b["time"])
		if t >= tb:
			continue
		var h := tb - ta
		if h <= 0.0:
			return _vec(b["position"])
		var s := (t - ta) / h
		var s2 := s * s
		var s3 := s2 * s
		return (2.0 * s3 - 3.0 * s2 + 1.0) * _vec(a["position"]) \
			+ (s3 - 2.0 * s2 + s) * h * _vec(a["velocity"]) \
			+ (-2.0 * s3 + 3.0 * s2) * _vec(b["position"]) \
			+ (s3 - s2) * h * _vec(b["velocity"])
	return _vec(path[-1]["position"])


## Returns the events with t <= time that were not returned before, in timeline order.
func pop_due(time: float) -> Array:
	var due := []
	while _cursor < events.size() and float(events[_cursor]["t"]) <= time:
		due.append(events[_cursor])
		_cursor += 1
	return due


static func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d["x"]), float(d["y"]))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tests/run.sh`
Expected: `23 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add match/shot/shot_timeline.gd tests/unit/test_shot_timeline.gd
git commit -m "feat: shot timeline with hermite path sampling"
```

---

### Task 9: TrajectoryPredictor (aim preview with server collision)

**Files:**
- Create: `match/aim/trajectory_predictor.gd`
- Test: `tests/unit/test_trajectory_predictor.gd`

- [ ] **Step 1: Write the failing tests `tests/unit/test_trajectory_predictor.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Trajectory := preload("res://match/aim/trajectory_predictor.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const FIXTURE := "res://tests/fixtures/terrain_parity.json"


func _flat(w: int, h: int, ground_y: int):
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for y in range(ground_y, h):
		for x in w:
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func test_first_step_matches_server_integration() -> void:
	# SimulateProjectile: v = power*6 = 60 up; v.y += 200*0.02 → -56; y += -56*0.02 = -1.12
	var pts := Trajectory.predict(Vector2.ZERO, 90.0, 10.0, 0, 0.0, null, 10)
	eq(pts[0], Vector2.ZERO, "starts at origin")
	near(pts[1].y, -1.12, 1e-6, "first step y")
	near(pts[1].x, 0.0, 1e-6, "first step x")


func test_wind_pushes_projectile() -> void:
	var calm := Trajectory.predict(Vector2.ZERO, 45.0, 50.0, 0, 0.0, null, 60)
	var windy := Trajectory.predict(Vector2.ZERO, 45.0, 50.0, 1, 2.0, null, 60)
	check(windy[-1].x > calm[-1].x, "right wind moves the end point right")


func test_stops_at_terrain() -> void:
	var m = _flat(400, 100, 60)
	var pts := Trajectory.predict(Vector2(100, 59), 45.0, 20.0, 0, 0.0, m, 500)
	check(m.is_solid(pts[-1].x, pts[-1].y), "last point is inside the ground")
	check(pts.size() < 500, "stopped before the point limit")


func test_thin_wall_inside_one_step_stops_preview() -> void:
	# 600 px/s moves 12 px per step: 100 → 112 (gravity adds 0.08 px down, so the segment is
	# 12.0003 px → 4 samples). The server samples x = 103, 106, 109, 112 and hits the 2 px wall
	# at x = 108..109 on the 109 sample; checking only the step end (112) would fly through it.
	var m = _flat(400, 100, 90)
	for y in range(0, 90):
		m.solid[y * m.width + 108] = TerrainMask.SOLID
		m.solid[y * m.width + 109] = TerrainMask.SOLID
	var pts := Trajectory.simulate(100.0, 50.0, 600.0, 0.0, 0.0, m, 50)
	near(pts[-1].x, 109.0, 1e-3, "stops at the wall")
	eq(pts.size(), 2, "hit during the first step")


func test_matches_server_shots() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var m := TerrainMask.new()
	m.load_snapshot(f["after"])
	var hits := 0
	for s in f["shots"]:
		if not s["hit"]:
			continue
		hits += 1
		var pts := Trajectory.simulate(float(s["x"]), float(s["y"]), float(s["vx"]), float(s["vy"]),
			float(s["windForce"]), m, 100000)
		near(pts[-1].x, float(s["hitX"]), 1e-3, "hit x of shot from %s,%s" % [s["x"], s["y"]])
		near(pts[-1].y, float(s["hitY"]), 1e-3, "hit y of shot from %s,%s" % [s["x"], s["y"]])
	check(hits >= 30, "fixture has enough hitting shots (%d)" % hits)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run.sh`
Expected: a script error, because `trajectory_predictor.gd` does not exist yet.

- [ ] **Step 3: Create `match/aim/trajectory_predictor.gd`**

```gdscript
extends RefCounted
## Aim preview that uses the same integration and terrain collision as the server's
## SimulateProjectile (shooting.go), with the getPhysics() defaults:
## - semi-implicit Euler steps of TIME_STEP;
## - each step's segment is sampled every 4 px or less, so thin walls and crater lips stop the
##   preview where they stop the shell.
## Players, drills, weapon weight and wind influence are not modelled (weight 1, influence 1),
## so the preview is a guide, not a promise.
##
## The math uses GDScript floats (64-bit, like Go's float64). Vector2 (32-bit) is used only for
## the returned points.

const TIME_STEP := 0.02
const GRAVITY := 200.0
const WIND_SCALE := 30.0
const MAX_FLIGHT := 6.0
const SAMPLE_PX := 4.0 # checkSegmentCollisions sub-step


static func predict(origin: Vector2, angle_deg: float, power: float, wind_dir: int, wind_power: float, terrain, max_points: int = 90) -> PackedVector2Array:
	var a := deg_to_rad(angle_deg)
	var speed := power * 6.0
	return simulate(origin.x, origin.y, speed * cos(a), -speed * sin(a), wind_dir * wind_power * WIND_SCALE, terrain, max_points)


## Integrates from (x, y) with velocity (vx, vy). The flight ends at whichever comes first:
## - the terrain hit point (the server's explosion point);
## - leaving the map bounds;
## - MAX_FLIGHT seconds;
## - max_points points.
static func simulate(x: float, y: float, vx: float, vy: float, wind_force: float, terrain, max_points: int) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x, y)])
	var t := 0.0
	while t < MAX_FLIGHT and pts.size() < max_points:
		var prev_x := x
		var prev_y := y
		vx += wind_force * TIME_STEP
		vy += GRAVITY * TIME_STEP
		x += vx * TIME_STEP
		y += vy * TIME_STEP
		t += TIME_STEP
		if terrain != null:
			var hit = _segment_hit(prev_x, prev_y, x, y, terrain)
			if hit != null:
				pts.append(hit)
				return pts
		pts.append(Vector2(x, y))
		if terrain != null and (x < -100.0 or x > terrain.width + 100.0 or y > terrain.height + 50.0):
			break
	return pts


## The terrain part of checkSegmentCollisions: returns the first solid sample along
## (px, py) → (cx, cy), or null if there is none.
static func _segment_hit(px: float, py: float, cx: float, cy: float, terrain):
	var dx := cx - px
	var dy := cy - py
	var steps := maxi(ceili(sqrt(dx * dx + dy * dy) / SAMPLE_PX), 1)
	for i in range(1, steps + 1):
		var frac := float(i) / float(steps)
		var sx := px + dx * frac
		var sy := py + dy * frac
		if terrain.is_solid(sx, sy):
			return Vector2(sx, sy)
	return null
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tests/run.sh`
Expected: `28 passed, 0 failed`.

If `test_matches_server_shots` fails, the port has drifted from `SimulateProjectile`/`checkSegmentCollisions`. Compare the order of operations: velocity first, then position, then `t`, then the hit check before the bounds check. Do not loosen the tolerance.

- [ ] **Step 5: Commit**

```bash
git add match/aim/trajectory_predictor.gd tests/unit/test_trajectory_predictor.gd
git commit -m "feat: local trajectory preview with server integration and segment collision"
```

---

### Task 10: MoveSync (instant own movement, per-command server model)

Porting `WalkTo` alone does not make the prediction match the server. `processMove` treats each `Move{targetX}` as one command:
- it clamps the target to `moveEnergy*2` px from the **server** position;
- it walks with `WalkTo`;
- it charges `round(|dx|*0.5)` energy on the **net** distance of that command.

Rounding over the total walk drifts. For example, four commands of 22/23/22/23 px cost 46 on the server, but rounding once over the total gives 45. Walking back and forth inside one send interval also costs differently.

**What MoveSync does:**
- It cuts the walk into one-direction segments. Each segment becomes one numbered `Move{targetX, seq}`.
- It simulates every command exactly like `processMove`.
- The displayed state is the latest `PlayerMoved` with all unanswered commands replayed on top of it.
- `PlayerMoved.seq` (Task 4c) says which command an answer belongs to. An answer acknowledges every command up to and including its `seq`, because the server handles one connection's messages in order. A late answer to an old command therefore never consumes a newer one.

**Re-sends:**
- After 1 s of silence, the newest command's target is re-sent under a new `seq`. The server may have dropped it under its rate limit even though the client spaced its sends, because packets can bunch up on the way.
- The older commands stay in the replay list. If the server did apply them, the late answers line up and nothing jumps; if it dropped them, the re-send's answer shows the real state.
- A `Move` the server rejects (frozen, not your turn) is never answered. But silence is not proof of rejection: the server may have applied the `Move` and only the answer is late.
- So after `MAX_RETRIES` re-sends, MoveSync reports `needs_resync()`:
  - it stops sending and keeps the prediction on screen, with no rollback;
  - it stays unsettled until a `MatchStateSync` resets it, or until the answer to the newest command arrives.

**What the controller relies on:**
- `is_settled()` gates `Shoot`/`EndTurn` until every `Move` is answered, so the shell starts where the character is shown.
- `needs_resync()` makes the controller cancel a pending `Shoot`/`EndTurn`, lock input and request `MatchStateSync`.
- `take_changes()` reports position and energy separately, so an answer that only fixes the energy still updates the HUD.

**Files:**
- Create: `match/move/move_sync.gd`
- Test: `tests/unit/test_move_sync.gd`

- [ ] **Step 1: Write the failing tests `tests/unit/test_move_sync.gd`**

```gdscript
extends "res://tests/test_case.gd"

const MoveSync := preload("res://match/move/move_sync.gd")
const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const FIXTURE := "res://tests/fixtures/terrain_parity.json"


func _flat(w: int, h: int, ground_y: int):
	var m := TerrainMask.new()
	m.width = w
	m.height = h
	m.solid.resize(w * h)
	m.solid.fill(0)
	for y in range(ground_y, h):
		for x in w:
			m.solid[y * w + x] = TerrainMask.SOLID
	m.destructible = m.solid.duplicate()
	return m


func _sync(x: float, energy: int):
	var s := MoveSync.new()
	s.terrain = _flat(400, 100, 60)
	s.reset(Vector2(x, 60), energy)
	return s


## Sends A (→130) then B (←120), like walking right 30 px and back 10 px.
func _send_right_then_left(s) -> void:
	s.walk_px(1, 30)
	s.walk_px(-1, 10)
	s.release()
	eq(s.update(0.0, true), {"direction": "right", "targetX": 130.0, "seq": 1}, "A")
	eq(s.update(0.3, true), {"direction": "left", "targetX": 120.0, "seq": 2}, "B")


func test_walk_shows_immediately() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 45)
	eq(s.position, Vector2(145, 60), "moved before any server answer")
	eq(s.energy, 77, "100 - round(45 * 0.5)")


func test_hold_converts_time_to_pixels() -> void:
	var s = _sync(100, 100)
	s.hold(1, 0.25) # 22.5 px: 22 now, 0.5 carried
	s.hold(1, 0.25) # 22.5 + 0.5 → 23
	eq(s.position.x, 145.0, "90 px/s for 0.5 s")


func test_energy_rounds_per_command_like_server() -> void:
	var s = _sync(100, 100)
	var targets := []
	var now := 0.0
	for px in [22, 23, 22, 23]:
		s.walk_px(1, px)
		s.release()
		targets.append(s.update(now, true).get("targetX"))
		now += 0.3
	eq(targets, [122.0, 145.0, 167.0, 190.0], "one command per segment")
	eq(s.energy, 54, "server cost 11 + 12 + 11 + 12 (not round(90 * 0.5) = 45)")
	eq(s.position, Vector2(190, 60), "position")


func test_direction_change_splits_commands() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	eq(s.position, Vector2(120, 60), "net position")
	eq(s.energy, 80, "15 for the right leg + 5 for the left leg, as the server charges")
	eq(s.update(0.6, true), {}, "nothing left to send")


func test_nothing_sent_while_rate_limited() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	eq(s.update(0.0, false), {}, "caller's rate limit is running")
	check(s.has_unsent(), "walk still pending")
	eq(s.update(0.1, true).get("targetX"), 120.0, "sent once allowed")
	check(not s.has_unsent(), "nothing pending")


func test_ack_rebases_on_server_state() -> void:
	var s = _sync(100, 100)
	s.walk_px(1, 40)
	s.release()
	eq(s.update(0.0, true).get("seq"), 1, "command sent")
	s.walk_px(1, 20) # still walking on top of the unacknowledged command
	s.on_server_moved(Vector2(138, 60), 79, 1) # server ended 2 px short
	eq(s.position, Vector2(158, 60), "open walk replayed from the server position")
	eq(s.energy, 69, "79 - round(20 * 0.5)")


func test_late_answers_after_resend_do_not_jump() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	var resend: Dictionary = s.update(1.5, true)
	eq([resend.get("targetX"), resend.get("seq")], [120.0, 3], "B's target re-sent under a new seq after 1 s of silence")
	eq(s.energy, 80, "re-send keeps A and B in the replay: energy unchanged")
	s.on_server_moved(Vector2(130, 60), 85, 1) # late answer to A
	eq(s.position, Vector2(120, 60), "no jump back to 130")
	eq(s.energy, 80, "energy after late A")
	s.on_server_moved(Vector2(120, 60), 80, 2) # late answer to B
	s.on_server_moved(Vector2(120, 60), 80, 3) # answer to the re-send
	eq(s.position, Vector2(120, 60), "settled")
	eq(s.energy, 80, "settled energy")


func test_resend_answer_shows_state_when_originals_were_dropped() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	s.update(1.5, true) # re-send seq 3
	s.on_server_moved(Vector2(120, 60), 90, 3) # A and B never arrived; server walked 100 → 120
	eq(s.position, Vector2(120, 60), "server position")
	eq(s.energy, 90, "server charged only the re-send")


func _silence_until_resync(s) -> void:
	s.walk_px(1, 20)
	s.release()
	eq(s.update(0.0, true).get("seq"), 1, "sent")
	eq(s.update(1.1, true).get("seq"), 2, "re-send 1")
	eq(s.update(2.2, true).get("seq"), 3, "re-send 2")
	eq(s.update(3.3, true), {}, "no more re-sends")


func test_silence_after_resends_needs_resync_not_rollback() -> void:
	# No answer is not proof of rejection: the server may have walked to 120 and only the
	# answers are late. The state is unknown, so nothing may be fired from a guessed position.
	var s = _sync(100, 100)
	_silence_until_resync(s)
	check(s.needs_resync(), "server state unknown")
	check(not s.is_settled(), "Shoot must not go out")
	eq(s.position, Vector2(120, 60), "no rollback to the last confirmed 100")
	eq(s.update(9.0, true), {}, "nothing is sent while waiting for a resync")
	s.reset(Vector2(120, 60), 90) # MatchStateSync
	check(not s.needs_resync(), "resynced")
	check(s.is_settled(), "Shoot may go out after the snapshot")


func test_late_answer_to_newest_command_ends_resync() -> void:
	var s = _sync(100, 100)
	_silence_until_resync(s)
	s.on_server_moved(Vector2(120, 60), 90, 3) # the newest re-send's answer finally arrives
	check(not s.needs_resync(), "state known again")
	check(s.is_settled(), "nothing left in flight")
	eq(s.position, Vector2(120, 60), "server position")


func test_unanswered_move_blocks_commit_until_resolved() -> void:
	# The last Move is dropped by the server's rate limit. A Shoot sent now would fire from the
	# server's old position while the client shows (and previews from) the predicted one.
	var s = _sync(100, 100)
	s.walk_px(1, 20)
	s.release()
	eq(s.update(0.0, true).get("seq"), 1, "sent, then dropped by the server")
	check(not s.has_unsent(), "everything is sent...")
	check(not s.is_settled(), "...but not answered: Shoot must wait")
	eq(s.update(0.3, true), {}, "nothing new to send at 0.3 s")
	check(not s.is_settled(), "still waiting at 0.3 s")
	eq(s.update(1.1, true).get("seq"), 2, "re-sent after 1 s of silence")
	s.on_server_moved(Vector2(120, 60), 90, 2)
	check(s.is_settled(), "answered: Shoot may go out")
	eq(s.position, Vector2(120, 60), "shown position is the server's")


func test_changes_report_energy_even_when_position_is_unchanged() -> void:
	var s = _sync(100, 100)
	_send_right_then_left(s)
	eq(s.take_changes(), {"position": Vector2(120, 60), "energy": 80}, "first report")
	s.update(1.5, true) # re-send of B
	eq(s.take_changes(), {}, "re-send changes nothing visible")
	s.on_server_moved(Vector2(120, 60), 90, 3) # A and B were dropped: same spot, more energy
	eq(s.take_changes(), {"energy": 90}, "energy-only correction still reaches the HUD")


func test_simulate_matches_server_process_move() -> void:
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var s := MoveSync.new()
	s.terrain = TerrainMask.new()
	s.terrain.load_snapshot(f["after"])
	for seq in f["moves"]:
		var pos := Vector2(float(seq["startX"]), float(seq["startY"]))
		var energy := int(seq["energy"])
		for step in seq["steps"]:
			var r: Array = s.simulate(pos, energy, float(step["targetX"]))
			pos = r[0]
			energy = r[1]
			eq(pos, Vector2(float(step["x"]), float(step["y"])), "position after Move to %s" % step["targetX"])
			eq(energy, int(step["energy"]), "energy after Move to %s" % step["targetX"])
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run.sh`
Expected: a script error, because `move_sync.gd` does not exist yet.

- [ ] **Step 3: Create `match/move/move_sync.gd`**

```gdscript
extends RefCounted
## Predicts the local player's walk, so the character moves on the frame the button is held,
## and decides which Move commands to send.
##
## Each command is modelled exactly as the server's processMove handles it:
##   1. clamp the target to moveEnergy * 2 px from the server's position;
##   2. walk with Terrain.WalkTo;
##   3. charge round(|dx| * 0.5) energy, capped at what is left.
##
## The walk is cut into segments that each go in one direction. Each segment becomes one
## Move{targetX, seq}; its target is the segment's end, so the server walks exactly that far.
## The displayed state is the last PlayerMoved plus every unanswered command replayed on top.
##
## PlayerMoved.seq answers every command up to that seq, because the server handles a
## connection's messages in order.
##
## After ACK_TIMEOUT of silence, the newest target is re-sent under a new seq. Older commands
## stay in the replay, so late answers line up instead of jumping. Silence after MAX_RETRIES
## re-sends does not prove the server rejected the move: it may have applied it and the answer
## is late. MoveSync then stops sending, keeps the prediction on screen and reports
## needs_resync(); the caller must not shoot and must fetch a MatchStateSync (reset()), unless
## the answer to the newest command arrives first.

const SPEED := 90.0 # px/s while a move button is held
const PX_PER_ENERGY := 2.0 # server processMove: maxDist = moveEnergy * 2
const ENERGY_PER_PX := 0.5 # server processMove: cost = round(dist * 0.5)
const ACK_TIMEOUT := 1.0 # seconds of silence before the newest Move is re-sent
const MAX_RETRIES := 2

var terrain
var position := Vector2.ZERO # displayed (predicted) position
var energy := 0 # displayed (predicted) move energy

var _server_pos := Vector2.ZERO
var _server_energy := 0
var _acked_seq := 0
var _next_seq := 1
var _retries := 0
var _in_flight: Array = [] # [{"seq": int, "target_x": float, "sent_at": float}], oldest first
var _queued: Array[float] = [] # closed segment targets (and re-sends) not sent yet
var _base_pos := Vector2.ZERO # predicted state after the in-flight and queued commands
var _base_energy := 0
var _seg_dir := 0 # open segment: direction and requested distance from _base_pos
var _seg_px := 0
var _carry := 0.0
var _reported_pos := Vector2.INF # last values handed out by take_changes()
var _reported_energy := -1
var _lost := false # re-sends exhausted: the server state is unknown until resync


## Starts from an authoritative state (turn start) and forgets all pending commands.
func reset(pos: Vector2, move_energy: int) -> void:
	_server_pos = pos
	_server_energy = move_energy
	_reported_pos = Vector2.INF
	_reported_energy = -1
	_lost = false
	_in_flight.clear()
	_queued.clear()
	_retries = 0
	_seg_dir = 0
	_seg_px = 0
	_carry = 0.0
	_rebase()


## Holds a move button for dt seconds in dir (-1 left, 1 right).
func hold(dir: int, dt: float) -> void:
	_carry += SPEED * dt
	var whole := int(_carry)
	_carry -= whole
	walk_px(dir, whole)


## Extends the walk by px pixels in dir. A direction change closes the open segment first.
func walk_px(dir: int, px: int) -> void:
	if px <= 0:
		return
	if _seg_dir != 0 and dir != _seg_dir:
		_close_segment()
	_seg_dir = dir
	_seg_px = mini(_seg_px + px, int(_base_energy * PX_PER_ENERGY))
	_update_display()


## Ends the current walk. Its segment is sent on a later update().
func release() -> void:
	_close_segment()
	_carry = 0.0


## True while part of the walk has not been sent yet.
func has_unsent() -> bool:
	return _seg_px > 0 or not _queued.is_empty()


## True when every command has been sent and answered: the shown position is the server's, so
## a Shoot fired now starts where the player sees the character.
func is_settled() -> bool:
	return not _lost and not has_unsent() and _in_flight.is_empty()


## True when re-sends ran out without an answer: the server's position is unknown. The caller
## must cancel any pending Shoot/EndTurn and request a MatchStateSync, then call reset().
func needs_resync() -> bool:
	return _lost


## Returns what changed since the last call, as {"position": Vector2} and/or {"energy": int}.
## The two are reported separately: an answer may fix the energy without moving the character.
func take_changes() -> Dictionary:
	var out := {}
	if position != _reported_pos:
		_reported_pos = position
		out["position"] = position
	if energy != _reported_energy:
		_reported_energy = energy
		out["energy"] = energy
	return out


## Call every frame. Returns the Move to send now as {"direction", "targetX", "seq"}, or {}.
## can_send is false while the caller's action rate limit is still running.
func update(now: float, can_send: bool) -> Dictionary:
	if _lost:
		return {}
	if not _in_flight.is_empty() and now - float(_in_flight[-1]["sent_at"]) > ACK_TIMEOUT:
		if _retries >= MAX_RETRIES:
			# Unknown, not rejected: the Move may have been applied with the answer still late.
			_lost = true
			return {}
		else:
			_retries += 1
			_in_flight[-1]["sent_at"] = now # one re-send per silence window
			_queued.push_front(float(_in_flight[-1]["target_x"]))
			_rebase()
	if not can_send:
		return {}
	if _queued.is_empty() and _seg_px > 0:
		_close_segment() # keep the server close behind a long hold
	if _queued.is_empty():
		return {}
	var prev_x := _server_pos.x if _in_flight.is_empty() else float(_in_flight[-1]["target_x"])
	var target: float = _queued.pop_front()
	var seq := _next_seq
	_next_seq += 1
	_in_flight.append({"seq": seq, "target_x": target, "sent_at": now})
	return {"direction": "right" if target >= prev_x else "left", "targetX": target, "seq": seq}


## Applies the server's PlayerMoved for the local player. seq is the answered command (0 if
## the server did not send one: then the oldest in-flight command is assumed).
func on_server_moved(pos: Vector2, move_energy: int, seq: int) -> void:
	if seq > 0 and seq < _acked_seq:
		return # older than an answer already applied
	_server_pos = pos
	_server_energy = move_energy
	if seq > 0:
		_acked_seq = seq
		while not _in_flight.is_empty() and int(_in_flight[0]["seq"]) <= seq:
			_in_flight.pop_front()
		_retries = 0
	elif not _in_flight.is_empty():
		_in_flight.pop_front()
	if _in_flight.is_empty():
		_lost = false # the newest command is answered: the server state is known again
	_rebase()


## processMove for one Move{targetX} from (pos, move_energy). Returns [end_pos, energy_left].
func simulate(pos: Vector2, move_energy: int, target_x: float) -> Array:
	var max_dist := move_energy * PX_PER_ENERGY
	var target := target_x
	if absf(target - pos.x) > max_dist:
		target = pos.x + max_dist if target > pos.x else pos.x - max_dist
	var end: Vector2 = terrain.walk_to(pos.x, pos.y, target)
	var cost := mini(roundi(absf(end.x - pos.x) * ENERGY_PER_PX), move_energy)
	return [end, move_energy - cost]


func _close_segment() -> void:
	if _seg_px > 0:
		var r := simulate(_base_pos, _base_energy, _base_pos.x + _seg_dir * _seg_px)
		if r[0].x != _base_pos.x:
			_queued.append(r[0].x)
			_base_pos = r[0]
			_base_energy = r[1]
	_seg_dir = 0
	_seg_px = 0
	_update_display()


func _rebase() -> void:
	var pos := _server_pos
	var e := _server_energy
	for c in _in_flight:
		var r := simulate(pos, e, float(c["target_x"]))
		pos = r[0]
		e = r[1]
	for t in _queued:
		var r := simulate(pos, e, t)
		pos = r[0]
		e = r[1]
	_base_pos = pos
	_base_energy = e
	_seg_px = mini(_seg_px, int(_base_energy * PX_PER_ENERGY))
	_update_display()


func _update_display() -> void:
	if _seg_px > 0:
		var r := simulate(_base_pos, _base_energy, _base_pos.x + _seg_dir * _seg_px)
		position = r[0]
		energy = r[1]
	else:
		position = _base_pos
		energy = _base_energy
```

(The server's ice slide only applies to legacy maps with terrain zones. Tile maps such as `grassland_valley` have no zones, so it is not modelled. If it ever happens, the next `PlayerMoved` rebases the prediction.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tests/run.sh`
Expected: `41 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add match/move/move_sync.gd tests/unit/test_move_sync.gd
git commit -m "feat: per-command move prediction with seq-matched acks"
```

---

### Task 11: Splash, Login and Home screens

**Files:**
- Create: `ui/ui.gd`, `screens/splash.gd`, `screens/splash.tscn`, `screens/login.gd`, `screens/login.tscn`, `screens/home.gd`, `screens/home.tscn`
- Modify: `project.godot` (main scene)

- [ ] **Step 1: Create `ui/ui.gd`**

```gdscript
extends RefCounted
## Small builders for code-built UI.


static func label(text: String, font_size: int = 24) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	return l


static func button(text: String, font_size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, 72)
	return b


## Full-rect CenterContainer holding a VBoxContainer; returns the column.
static func center_column(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	center.add_child(col)
	return col
```

- [ ] **Step 2: Create the three scene files**

`screens/splash.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://screens/splash.gd" id="1"]

[node name="Splash" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

`screens/login.tscn` is identical, except `path="res://screens/login.gd"` and `[node name="Login" type="Control"]`.

`screens/home.tscn` is identical, except `path="res://screens/home.gd"` and `[node name="Home" type="Control"]`.

- [ ] **Step 3: Create `screens/splash.gd`**

```gdscript
extends Control
## Startup (demo splash_screen.dart): restore the saved session, then Home or Login.

const Ui := preload("res://ui/ui.gd")

var _status: Label
var _retry: Button


func _ready() -> void:
	var col := Ui.center_column(self)
	col.add_child(Ui.label("BATTLE SQUAD", 64))
	_status = Ui.label("", 28)
	col.add_child(_status)
	_retry = Ui.button("Thử lại")
	_retry.pressed.connect(_check_auth)
	col.add_child(_retry)
	_check_auth()


func _check_auth() -> void:
	_retry.visible = false
	_status.text = "Đang kết nối..."
	if not Session.has_token():
		Router.go(Router.LOGIN)
		return
	var res: Dictionary = await Api.get_json("/player/profile")
	if res.ok and res.data is Dictionary:
		Session.set_profile(str(res.data.get("playerId", "")), str(res.data.get("displayName", "")))
		GameSocket.open()
		Router.go(Router.HOME)
	elif res.status == 401:
		Session.clear_tokens()
		Router.go(Router.LOGIN)
	else:
		_status.text = "Không kết nối được server (%s)" % res.message
		_retry.visible = true
```

- [ ] **Step 4: Create `screens/login.gd`**

```gdscript
extends Control
## Guest login (demo login_screen.dart). Google/Apple come with provider login later.

const Ui := preload("res://ui/ui.gd")

var _guest: Button
var _error: Label


func _ready() -> void:
	var col := Ui.center_column(self)
	col.add_child(Ui.label("BATTLE SQUAD", 64))
	_guest = Ui.button("Chơi với tư cách khách", 32)
	_guest.custom_minimum_size = Vector2(520, 96)
	_guest.pressed.connect(_on_guest)
	col.add_child(_guest)
	_error = Ui.label("", 24)
	_error.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	col.add_child(_error)


func _on_guest() -> void:
	_guest.disabled = true
	_error.text = ""
	var res: Dictionary = await Api.request(HTTPClient.METHOD_POST, "/auth/guest-login",
		{"deviceInstallId": Session.ensure_device_id()}, false, false)
	var d = res.data if res.ok else null
	if d is Dictionary and str(d.get("accessToken", "")) != "" and str(d.get("playerId", "")) != "":
		Session.set_tokens(str(d["accessToken"]), str(d.get("refreshToken", "")), str(d["playerId"]), str(d.get("displayName", "")))
		GameSocket.open()
		Router.go(Router.HOME)
		return
	_error.text = res.message if not res.ok else "Phản hồi không hợp lệ từ server"
	_guest.disabled = false
```

- [ ] **Step 5: Create `screens/home.gd`**

```gdscript
extends Control
## Home shell with the demo's five tabs (app_router.dart HomeShell). M1 implements
## Play → Quick Play; the other tabs arrive in M3/M4.
##
## A Quick Play request stays pending until it is resolved. The server handles a client's
## messages in order and always answers QuickPlay with MatchStarted or RoomError, so a late
## answer is still accepted: the server really did put the player in that match. The only other
## way a request ends is a disconnect, after which the server drops the room (and the outbox
## drops an unsent QuickPlay). Retrying earlier could create a second room.

const Ui := preload("res://ui/ui.gd")
const TABS := ["Chơi", "Hồ sơ", "Cửa hàng", "Nhiệm vụ", "Xếp hạng"]
const SLOW_NOTICE_SEC := 10.0

var _pages: Array[Control] = []
var _conn: Label
var _quick_play: Button
var _status: Label
var _timer: Timer
var _pending := false


func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Ui.label("Battle Squad  ·  %s" % Session.display_name, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	_conn = Ui.label("", 22)
	header.add_child(_conn)

	var pages := Control.new()
	pages.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(pages)
	for i in TABS.size():
		var page := Control.new()
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		page.visible = i == 0
		pages.add_child(page)
		_pages.append(page)
	_build_play_page(_pages[0])
	for i in range(1, TABS.size()):
		Ui.center_column(_pages[i]).add_child(Ui.label("%s — sắp có" % TABS[i], 32))

	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	for i in TABS.size():
		var b := Ui.button(TABS[i], 26)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 90
		b.pressed.connect(_show_tab.bind(i))
		tabs.add_child(b)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_slow)
	add_child(_timer)

	GameSocket.connected.connect(_update_conn)
	GameSocket.disconnected.connect(_on_disconnected)
	GameSocket.event_received.connect(_on_event)
	_update_conn()


func _build_play_page(page: Control) -> void:
	var col := Ui.center_column(page)
	_quick_play = Ui.button("Chơi nhanh (Luyện tập)", 34)
	_quick_play.custom_minimum_size = Vector2(560, 110)
	_quick_play.pressed.connect(_on_quick_play)
	col.add_child(_quick_play)
	_status = Ui.label("", 24)
	col.add_child(_status)


func _show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index


func _update_conn() -> void:
	_conn.text = "● Online" if GameSocket.is_open() else "○ Đang kết nối..."


func _on_quick_play() -> void:
	if _pending:
		return
	_pending = true
	_quick_play.disabled = true
	_status.text = "Đang tạo trận..."
	_timer.start(SLOW_NOTICE_SEC)
	GameSocket.send("QuickPlay", {})


func _on_slow() -> void:
	if _pending:
		_status.text = "Server phản hồi chậm, vẫn đang chờ..."


func _on_event(event: String, data: Variant) -> void:
	match event:
		"MatchStarted":
			# The only way into Match. Accepted even after the slow notice.
			_pending = false
			_timer.stop()
			GameSocket.hold() # TurnStarted follows immediately; Match releases it
			Router.match_snapshot = data
			Router.go(Router.MATCH)
		"RoomError":
			if _pending:
				_resolve(_error_message(data))


func _on_disconnected() -> void:
	_update_conn()
	if _pending:
		_resolve("Mất kết nối, hãy thử lại khi online")


func _resolve(message: String) -> void:
	_pending = false
	_timer.stop()
	_status.text = message
	_quick_play.disabled = false


static func _error_message(data: Variant) -> String:
	if data is Dictionary:
		if data.get("error") is Dictionary:
			return str(data["error"].get("message", "Lỗi phòng"))
		return str(data.get("message", "Lỗi phòng"))
	return "Lỗi phòng"
```

- [ ] **Step 6: Set the main scene in `project.godot`**

Add this line under `[application]`:

```ini
run/main_scene="res://screens/splash.tscn"
```

- [ ] **Step 7: Load the project headless and run the tests**

Run: `"$GODOT" --headless --path . --quit 2>&1 | grep -iE "error|failed" || echo "clean"`
Expected: `clean`.

Run: `tests/run.sh`
Expected: `41 passed, 0 failed`.

- [ ] **Step 8: Check Login and Home by hand**

Start the server first:

```bash
cd ../battle-squad && docker compose up -d postgres redis && go run ./cmd/migrate && (go run ./cmd/api &) && go run ./cmd/game
```

In another terminal: `"$GODOT" --path ../battle-squad-game`

Expected:
1. Login appears.
2. "Chơi với tư cách khách" leads to Home with "● Online".
3. After quitting and relaunching, Splash goes straight to Home, because the session was saved.

- [ ] **Step 9: Commit**

```bash
git add ui screens project.godot
git commit -m "feat: splash, guest login and home with quick play"
```

---

### Task 12: Match visuals (terrain, players, projectile, effects)

**Files:**
- Create: `match/terrain/terrain.gdshader`, `match/terrain/terrain_view.gd`, `match/views/player_view.gd`, `match/views/projectile_view.gd`, `match/views/explosion_fx.gd`, `match/views/damage_popup.gd`

- [ ] **Step 1: Create `match/terrain/terrain.gdshader`**

```glsl
shader_type canvas_item;

// TEXTURE is the L8 solid mask: 1 = ground, 0 = air.
uniform vec4 grass_color : source_color = vec4(0.36, 0.62, 0.25, 1.0);
uniform vec4 dirt_top : source_color = vec4(0.55, 0.38, 0.22, 1.0);
uniform vec4 dirt_bottom : source_color = vec4(0.30, 0.20, 0.12, 1.0);
uniform float grass_px = 6.0;

void fragment() {
	if (texture(TEXTURE, UV).r < 0.5) {
		discard;
	}
	float above = texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y * grass_px)).r;
	COLOR = above < 0.5 ? grass_color : mix(dirt_top, dirt_bottom, UV.y);
}
```

- [ ] **Step 2: Create `match/terrain/terrain_view.gd`**

```gdscript
extends Sprite2D
## Draws a TerrainMask: the solid bytes are an L8 image colored by terrain.gdshader. An explosion
## costs one byte edit pass (TerrainMask.destroy_circle) and one texture upload (refresh).

var _mask
var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://match/terrain/terrain.gdshader")
	material = mat


func show_mask(mask) -> void:
	_mask = mask
	_image = Image.create_from_data(mask.width, mask.height, false, Image.FORMAT_L8, mask.solid)
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture


func refresh() -> void:
	if _mask == null:
		return
	_image.set_data(_mask.width, _mask.height, false, Image.FORMAT_L8, _mask.solid)
	_texture.update(_image)
```

- [ ] **Step 3: Create `match/views/player_view.gd`**

```gdscript
extends Node2D
## One player, drawn at its feet (server Position is the first solid pixel under the feet).

const BODY := Vector2(28, 40) # server PlayerHeight = 40
const TEAM_COLORS := {1: Color(0.25, 0.55, 1.0), 2: Color(1.0, 0.35, 0.3)}
const HP_BAR_WIDTH := 50.0

var player_id := ""
var team_id := 1
var is_me := false
var hp := 0
var max_hp := 1

var _tween: Tween


func setup(p: Dictionary, me: bool) -> void:
	player_id = str(p.get("playerId", ""))
	team_id = int(p.get("teamId", 1))
	is_me = me
	position = Vector2(float(p["position"]["x"]), float(p["position"]["y"]))
	var name_label := Label.new()
	name_label.text = str(p.get("displayName", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size = Vector2(160, 24)
	name_label.position = Vector2(-80, -BODY.y - 40)
	add_child(name_label)
	set_hp(int(p.get("hp", 0)), int(p.get("maxHp", 1)))
	if not bool(p.get("isAlive", true)):
		set_dead()


func set_hp(value: int, max_value: int = -1) -> void:
	hp = value
	if max_value > 0:
		max_hp = max_value
	queue_redraw()


func set_dead() -> void:
	modulate.a = 0.35


## Tweens to target over duration seconds (0 = jump there).
func move_to(target: Vector2, duration: float, trans: Tween.TransitionType = Tween.TRANS_LINEAR, ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if _tween:
		_tween.kill()
	if duration <= 0.0:
		position = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(trans).set_ease(ease_type)


func _draw() -> void:
	var body := Rect2(-BODY.x / 2, -BODY.y, BODY.x, BODY.y)
	draw_rect(body, TEAM_COLORS.get(team_id, Color.WHITE))
	if is_me:
		draw_rect(body, Color.WHITE, false, 2.0)
	var bar := Rect2(-HP_BAR_WIDTH / 2, -BODY.y - 12, HP_BAR_WIDTH, 6)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	bar.size.x *= clampf(float(hp) / max_hp, 0.0, 1.0)
	draw_rect(bar, Color(0.3, 0.9, 0.35))
```

- [ ] **Step 4: Create `match/views/projectile_view.gd`**

```gdscript
extends Node2D


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(1, 1, 1, 0.25))
	draw_circle(Vector2.ZERO, 5.0, Color(0.12, 0.12, 0.12))
```

- [ ] **Step 5: Create `match/views/explosion_fx.gd`**

```gdscript
extends Node2D
## Short flash at an explosion; frees itself.

var radius := 30.0


func _ready() -> void:
	scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.18)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	t.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.75, 0.3, 0.85))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.95, 0.7, 0.95))
```

- [ ] **Step 6: Create `match/views/damage_popup.gd`**

```gdscript
extends Label
## Floating number above a player; set text and font color before adding it, frees itself.


func _ready() -> void:
	add_theme_font_size_override("font_size", 30)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size = Vector2(160, 40)
	position -= Vector2(80, 0)
	var t := create_tween()
	t.tween_property(self, "position:y", position.y - 60.0, 0.9)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.3)
	t.tween_callback(queue_free)
```

- [ ] **Step 7: Load the project headless**

Run: `"$GODOT" --headless --path . --quit 2>&1 | grep -iE "error|failed" || echo "clean"`
Expected: `clean`.

- [ ] **Step 8: Commit**

```bash
git add match/terrain/terrain.gdshader match/terrain/terrain_view.gd match/views
git commit -m "feat: terrain, player, projectile and effect views"
```

---

### Task 13: ShotPlayer, AimInput and HUD

**Files:**
- Create: `match/shot/shot_player.gd`, `match/aim/aim_input.gd`, `match/hud.gd`

- [ ] **Step 1: Create `match/shot/shot_player.gd`**

```gdscript
extends Node
## Replays one ShotResolved: moves projectile views along the server paths and emits each
## timeline event when its time comes. Driven by frame delta, so it is smooth at any FPS.

signal event_due(event: Dictionary)
signal finished

const ProjectileView := preload("res://match/views/projectile_view.gd")

var layer: Node2D

var _timeline
var _t := 0.0
var _views: Array = []


func is_playing() -> bool:
	return _timeline != null


func play(timeline) -> void:
	stop()
	_timeline = timeline
	_t = 0.0
	for i in timeline.projectiles.size():
		var view := ProjectileView.new()
		view.position = timeline.sample(i, 0.0)
		layer.add_child(view)
		_views.append(view)


## Drops the replay without emitting the remaining events (a full snapshot replaces it).
func stop() -> void:
	for view in _views:
		if is_instance_valid(view):
			view.queue_free()
	_views.clear()
	_timeline = null


func _process(delta: float) -> void:
	if _timeline == null:
		return
	_t += delta
	for i in _views.size():
		var view = _views[i]
		if view == null:
			continue
		if _t >= _timeline.projectile_end(i):
			view.queue_free()
			_views[i] = null
		else:
			view.position = _timeline.sample(i, _t)
	for event in _timeline.pop_due(_t):
		event_due.emit(event)
		if _timeline == null:
			return
	if _t >= _timeline.duration:
		stop()
		finished.emit()
```

- [ ] **Step 2: Create `match/aim/aim_input.gd`**

```gdscript
extends Node2D
## Slingshot aiming (demo match_screen.dart): drag anywhere, release to fire. Dragging down-right
## shoots up-left. Releasing inside the cancel zone around the shooter cancels. Everything here
## is local; nothing touches the network until fire.

signal aim_changed(angle: float, power: float)
signal fire(angle: float, power: float)

const Trajectory := preload("res://match/aim/trajectory_predictor.gd")
const CANCEL_RADIUS := 60.0
const MIN_POWER := 5.0
const BODY_CENTER := Vector2(0, -20)

var enabled := false:
	set(value):
		enabled = value
		if not value:
			_reset()
var shooter_pos := Vector2.ZERO
var terrain
var wind_dir := 0
var wind_power := 0.0

var _dragging := false
var _start := Vector2.ZERO
var _angle := 0.0
var _power := 0.0
var _in_cancel := false
var _line: Line2D


func _ready() -> void:
	_line = Line2D.new()
	_line.width = 4.0
	_line.default_color = Color(1, 1, 1, 0.55)
	add_child(_line)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_start = get_global_mouse_position()
			_update(_start)
		elif _dragging:
			_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_update(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func _update(pointer: Vector2) -> void:
	var d := pointer - _start
	_angle = clampf(rad_to_deg(atan2(d.y, -d.x)), 0.0, 180.0)
	_power = clampf(d.length() / 2.0, 0.0, 100.0)
	_in_cancel = pointer.distance_to(shooter_pos + BODY_CENTER) <= CANCEL_RADIUS
	_line.points = Trajectory.predict(shooter_pos, _angle, _power, wind_dir, wind_power, terrain)
	queue_redraw()
	aim_changed.emit(_angle, _power)


func _release() -> void:
	var shoot := _power >= MIN_POWER and not _in_cancel
	var angle := _angle
	var power := _power
	_reset()
	if shoot:
		fire.emit(angle, power)


func _reset() -> void:
	_dragging = false
	_in_cancel = false
	if _line:
		_line.points = PackedVector2Array()
	queue_redraw()


func _draw() -> void:
	if not _dragging:
		return
	var c := shooter_pos + BODY_CENTER
	var color := Color(1, 0.3, 0.3, 0.9) if _in_cancel else Color(1, 1, 1, 0.5)
	draw_arc(c, CANCEL_RADIUS, 0.0, TAU, 48, color, 3.0)
	draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), color, 3.0)
	draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), color, 3.0)
```

- [ ] **Step 3: Create `match/hud.gd`**

```gdscript
extends Control
## Match HUD: turn, timer, wind, move buttons + energy, aim readout, end turn, result panel.
## Layout is containers only, so it adapts to wide phones (stretch aspect "expand").

signal move_pressed(dir: int)
signal move_released
signal end_turn_pressed
signal leave_pressed

const Ui := preload("res://ui/ui.gd")

var _turn: Label
var _timer: Label
var _wind: Label
var _aim: Label
var _energy: ProgressBar
var _left: Button
var _right: Button
var _end_turn: Button
var _result: Control
var _result_title: Label
var _result_detail: Label
var _time_left := 0.0
var _timer_running := true


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)

	var rows: VBoxContainer = _ignore(VBoxContainer.new())
	margin.add_child(rows)

	var top: HBoxContainer = _ignore(HBoxContainer.new())
	rows.add_child(top)
	var leave := Ui.button("Thoát", 24)
	leave.custom_minimum_size = Vector2(120, 60)
	leave.pressed.connect(leave_pressed.emit)
	top.add_child(leave)
	_turn = _expand(Ui.label("", 30))
	top.add_child(_turn)
	_timer = Ui.label("", 40)
	top.add_child(_timer)
	_wind = _expand(Ui.label("", 30))
	top.add_child(_wind)

	rows.add_child(_expand_v(_ignore(Control.new())))

	var bottom: HBoxContainer = _ignore(HBoxContainer.new())
	bottom.add_theme_constant_override("separation", 16)
	rows.add_child(bottom)
	_left = _hold_button("◀", -1)
	bottom.add_child(_left)
	_right = _hold_button("▶", 1)
	bottom.add_child(_right)
	_energy = ProgressBar.new()
	_energy.max_value = 100
	_energy.show_percentage = false
	_energy.custom_minimum_size = Vector2(240, 24)
	_energy.size_flags_vertical = SIZE_SHRINK_CENTER
	_energy.mouse_filter = MOUSE_FILTER_IGNORE
	bottom.add_child(_energy)
	_aim = _expand(Ui.label("", 30))
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(_aim)
	_end_turn = Ui.button("Hết lượt", 28)
	_end_turn.custom_minimum_size = Vector2(200, 110)
	_end_turn.pressed.connect(end_turn_pressed.emit)
	bottom.add_child(_end_turn)

	_build_result_panel()


func _process(delta: float) -> void:
	if _timer_running:
		_time_left = maxf(0.0, _time_left - delta)
	_timer.text = "%d" % ceili(_time_left)


func set_turn(mine: bool, player_name: String) -> void:
	_turn.text = "Lượt của bạn" if mine else "Lượt của %s" % player_name


## Sets the turn clock from a server value and resumes the local countdown.
func set_time(seconds: int) -> void:
	_time_left = seconds
	_timer_running = true


## Freezes the countdown. The server stops TurnTimerTick while a shot resolves, and the next
## set_time() (TurnTimerTick or TurnStarted) resumes it.
func pause_timer() -> void:
	_timer_running = false


func set_wind(direction: int, power: float) -> void:
	var arrow := "→" if direction > 0 else ("←" if direction < 0 else "·")
	_wind.text = "Gió %s %.1f" % [arrow, power]


func set_energy(value: int) -> void:
	_energy.value = value


func set_aim(angle: float, power: float) -> void:
	_aim.text = "%d°  lực %d" % [roundi(angle), roundi(power)]


func set_controls_enabled(enabled: bool) -> void:
	_left.disabled = not enabled
	_right.disabled = not enabled
	_end_turn.disabled = not enabled
	if not enabled:
		_aim.text = ""


func show_result(title: String, detail: String) -> void:
	_result_title.text = title
	_result_detail.text = detail
	_result.visible = true


func _hold_button(text: String, dir: int) -> Button:
	var b := Ui.button(text, 40)
	b.custom_minimum_size = Vector2(120, 110)
	b.button_down.connect(move_pressed.emit.bind(dir))
	b.button_up.connect(move_released.emit)
	return b


func _build_result_panel() -> void:
	_result = CenterContainer.new()
	_result.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_result.visible = false
	add_child(_result)
	var panel := PanelContainer.new()
	_result.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	panel.add_child(col)
	_result_title = Ui.label("", 56)
	col.add_child(_result_title)
	_result_detail = Ui.label("", 28)
	col.add_child(_result_detail)
	var back := Ui.button("Về sảnh", 30)
	back.custom_minimum_size = Vector2(360, 90)
	back.pressed.connect(leave_pressed.emit)
	col.add_child(back)


static func _ignore(c):
	c.mouse_filter = MOUSE_FILTER_IGNORE
	return c


static func _expand(c):
	c.size_flags_horizontal = SIZE_EXPAND_FILL
	return c


static func _expand_v(c):
	c.size_flags_vertical = SIZE_EXPAND_FILL
	return c
```

- [ ] **Step 4: Load the project headless and run the tests**

Run: `"$GODOT" --headless --path . --quit 2>&1 | grep -iE "error|failed" || echo "clean"`
Expected: `clean`.

Run: `tests/run.sh`
Expected: `41 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add match/shot/shot_player.gd match/aim/aim_input.gd match/hud.gd
git commit -m "feat: shot replay, slingshot aiming and match hud"
```

---

### Task 14: Match screen controller

**Files:**
- Create: `match/match_screen.gd`, `match/match_screen.tscn`

- [ ] **Step 1: Create `match/match_screen.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://match/match_screen.gd" id="1"]

[node name="Match" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 2: Create `match/match_screen.gd`**

```gdscript
extends Node2D
## Match against the server. The server is authoritative: this screen renders its snapshot,
## replays ShotResolved, and predicts only the local player's walk (MoveSync). Every match
## event that arrives during a replay waits until the replay ends, and the turn clock is paused
## from the shot until the next timer event, so the HUD never runs ahead of the animation.
## See docs/superpowers/specs/2026-10-15-godot-client-roadmap-design.md.

const TerrainMask := preload("res://match/terrain/terrain_mask.gd")
const TerrainView := preload("res://match/terrain/terrain_view.gd")
const PlayerView := preload("res://match/views/player_view.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const DamagePopup := preload("res://match/views/damage_popup.gd")
const ShotTimeline := preload("res://match/shot/shot_timeline.gd")
const ShotPlayer := preload("res://match/shot/shot_player.gd")
const AimInput := preload("res://match/aim/aim_input.gd")
const MoveSync := preload("res://match/move/move_sync.gd")
const Hud := preload("res://match/hud.gd")

const ACTION_INTERVAL := 0.25 # server drops actions closer than 150 ms
const OTHER_WALK_SPEED := 90.0
const SHOT_ACK_TIMEOUT := 3.0
const RESYNC_RETRY := 3.0 # re-ask for MatchStateSync if none arrived
const TURN_SECONDS := 20

var _me := ""
var _players := {} # playerId -> server BattlePlayerState
var _views := {} # playerId -> PlayerView
var _current := ""
var _wind := {"direction": 0, "power": 0.0}
var _ended := false
var _deferred: Array = []
var _awaiting_shot := 0.0 # seconds left for the server to answer a sent Shoot/EndTurn
var _committing := false # Shoot/EndTurn requested: input locked until the turn moves on
var _commit_sent := false # ...and sent: no more Moves this turn
var _resync_in := 0.0 # seconds before asking for MatchStateSync again

var _mask := TerrainMask.new()
var _moves := MoveSync.new()
var _sky: ColorRect
var _terrain_view: TerrainView
var _players_layer: Node2D
var _fx_layer: Node2D
var _aim: AimInput
var _shot_player: ShotPlayer
var _hud: Hud

var _hold_dir := 0
var _since_action := 1.0


func _ready() -> void:
	_me = Session.player_id
	_sky = ColorRect.new()
	_sky.color = Color(0.53, 0.75, 0.92)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)
	_terrain_view = TerrainView.new()
	add_child(_terrain_view)
	_players_layer = Node2D.new()
	add_child(_players_layer)
	_fx_layer = Node2D.new()
	add_child(_fx_layer)
	_aim = AimInput.new()
	add_child(_aim)
	_shot_player = ShotPlayer.new()
	_shot_player.layer = _fx_layer
	add_child(_shot_player)
	var ui := CanvasLayer.new()
	add_child(ui)
	_hud = Hud.new()
	ui.add_child(_hud)

	_moves.terrain = _mask
	_aim.fire.connect(_on_fire)
	_aim.aim_changed.connect(_hud.set_aim)
	_shot_player.event_due.connect(_on_shot_event)
	_shot_player.finished.connect(_on_shot_finished)
	_hud.move_pressed.connect(func(dir: int) -> void: _hold_dir = dir)
	_hud.move_released.connect(func() -> void: _hold_dir = 0)
	_hud.end_turn_pressed.connect(_on_end_turn)
	_hud.leave_pressed.connect(_on_leave)

	_load_snapshot(Router.match_snapshot)
	GameSocket.event_received.connect(_on_event)
	GameSocket.release()


func _process(delta: float) -> void:
	_since_action += delta
	if _awaiting_shot > 0.0:
		_awaiting_shot -= delta
		if _awaiting_shot <= 0.0:
			# The server ignored the Shoot/EndTurn: give control back.
			_committing = false
			_commit_sent = false
			_refresh_controls()
	if not _is_my_turn() or _commit_sent:
		return
	if _hold_dir != 0 and _can_act():
		_moves.hold(_hold_dir, delta)
	# Runs while a Shoot/EndTurn waits too, so the rest of the walk (and a re-send of an
	# unanswered Move) still goes out before it; _commit_action waits for them.
	var cmd := _moves.update(Time.get_ticks_msec() / 1000.0, _since_action >= ACTION_INTERVAL)
	if not cmd.is_empty():
		GameSocket.send("Move", cmd)
		_mark_action()
	if _moves.needs_resync():
		_request_resync(delta)
	if not _shot_player.is_playing():
		var changes := _moves.take_changes()
		if changes.has("position"):
			_views[_me].position = changes["position"]
			_aim.shooter_pos = changes["position"]
		if changes.has("energy"): # may change alone, e.g. when dropped Moves were not charged
			_hud.set_energy(changes["energy"])


# ── Snapshot and turn state ──────────────────────────────────────────────────

func _load_snapshot(snap: Dictionary) -> void:
	_shot_player.stop()
	_deferred.clear()
	var terrain: Dictionary = snap.get("terrain", {})
	if not terrain.is_empty() and _mask.load_snapshot(terrain):
		_terrain_view.show_mask(_mask)
		_sky.size = Vector2(_mask.width, _mask.height)
	for view in _views.values():
		view.queue_free()
	_views.clear()
	_players = snap.get("players", {})
	for id in _players:
		var view := PlayerView.new()
		_players_layer.add_child(view)
		view.setup(_players[id], id == _me)
		_views[id] = view
	_wind = snap.get("wind", _wind)
	_hud.set_time(int(snap.get("turnTimeLeft", TURN_SECONDS)))
	_set_current(str(snap.get("currentPlayerId", "")), int(_players.get(_me, {}).get("moveEnergy", 0)))


func _set_current(player_id: String, move_energy: int) -> void:
	_current = player_id
	_hold_dir = 0
	_awaiting_shot = 0.0
	_committing = false
	_commit_sent = false
	_resync_in = 0.0
	if _is_my_turn():
		_moves.reset(_pos(_me), move_energy)
	_hud.set_turn(_is_my_turn(), str(_players.get(player_id, {}).get("displayName", "")))
	_hud.set_wind(int(_wind.get("direction", 0)), float(_wind.get("power", 0.0)))
	_hud.set_energy(move_energy if _is_my_turn() else 0)
	_refresh_controls()


func _is_my_turn() -> bool:
	return not _ended and _current == _me and bool(_players.get(_me, {}).get("isAlive", false))


func _can_act() -> bool:
	return _is_my_turn() and not _shot_player.is_playing() and not _committing and not _moves.needs_resync()


func _refresh_controls() -> void:
	var can := _can_act()
	_hud.set_controls_enabled(can)
	_aim.enabled = can
	if can:
		_aim.shooter_pos = _views[_me].position
		_aim.terrain = _mask
		_aim.wind_dir = int(_wind.get("direction", 0))
		_aim.wind_power = float(_wind.get("power", 0.0))
	else:
		_hold_dir = 0


# ── Server events ────────────────────────────────────────────────────────────

func _on_event(event: String, data: Variant) -> void:
	if event == "MatchStateSync":
		_load_snapshot(data)
		return
	if _shot_player.is_playing():
		_deferred.append([event, data])
		return
	_apply(event, data)


func _apply(event: String, data: Variant) -> void:
	match event:
		"TurnStarted":
			_wind = data.get("wind", _wind)
			var energies: Dictionary = data.get("skillEnergy", {})
			for id in energies:
				if _players.has(id):
					_players[id]["skillEnergy"] = energies[id]
			_hud.set_time(TURN_SECONDS)
			_set_current(str(data.get("currentPlayerId", "")), int(data.get("moveEnergy", 0)))
		"TurnTimerTick":
			_hud.set_time(int(data.get("timeLeft", 0)))
		"PlayerMoved":
			_on_player_moved(data)
		"ShotResolved":
			_awaiting_shot = 0.0
			_hud.pause_timer() # resumed by the next TurnTimerTick / TurnStarted
			_shot_player.play(ShotTimeline.new(data))
			_refresh_controls()
		"PlayerDamaged": # lava at turn start (shot damage comes in ShotResolved)
			for e in data:
				_set_hp(str(e.get("playerId", "")), int(e.get("hp", 0)))
				if not bool(e.get("isAlive", true)):
					_kill(str(e.get("playerId", "")))
		"ItemUsed":
			_wind = data.get("wind", _wind)
		"MatchEnded":
			_on_match_ended(data)


func _on_player_moved(d: Dictionary) -> void:
	var id := str(d.get("playerId", ""))
	if not _players.has(id):
		return
	var pos := Vector2(float(d["position"]["x"]), float(d["position"]["y"]))
	var energy := int(d.get("moveEnergy", 0))
	_players[id]["position"] = {"x": pos.x, "y": pos.y}
	_players[id]["moveEnergy"] = energy
	if id == _me and _is_my_turn():
		# Rebase: server state plus our unacknowledged commands. _process shows the result;
		# when the prediction was right (the normal case) nothing visibly changes.
		_moves.on_server_moved(pos, energy, int(d.get("seq", 0)))
		return
	var view = _views[id]
	view.move_to(pos, view.position.distance_to(pos) / OTHER_WALK_SPEED)


func _on_shot_event(e: Dictionary) -> void:
	var id := str(e.get("playerId", ""))
	match str(e.get("type", "")):
		"explode":
			var p := _vec(e["position"])
			var radius := float(e.get("radius", 0.0))
			_mask.destroy_circle(p.x, p.y, radius)
			_terrain_view.refresh()
			var fx := ExplosionFx.new()
			fx.radius = radius
			fx.position = p
			_fx_layer.add_child(fx)
			var server_version := int(e.get("terrainVersion", _mask.version))
			if server_version != _mask.version:
				_mask.version = server_version
				GameSocket.send("Reconnect", {}) # terrain drifted: ask for MatchStateSync
		"damage":
			_set_hp(id, int(e.get("hp", 0)))
			var crit := bool(e.get("critical", false))
			_popup(id, "-%d" % int(e.get("amount", 0)), Color(1, 0.85, 0.2) if crit else Color(1, 0.3, 0.3))
		"heal":
			_set_hp(id, int(e.get("hp", 0)))
			_popup(id, "+%d" % int(e.get("amount", 0)), Color(0.4, 1, 0.5))
		"fall":
			var to := _vec(e["to"])
			_set_pos(id, to)
			if _views.has(id):
				_views[id].move_to(to, float(e.get("duration", 0.0)), Tween.TRANS_QUAD, Tween.EASE_IN)
		"teleport":
			var to := _vec(e["to"])
			_set_pos(id, to)
			if _views.has(id):
				_views[id].move_to(to, 0.0)
		"die":
			_kill(id)
		"status":
			_popup(id, str(e.get("effectId", "")), Color(0.7, 0.85, 1))


func _on_shot_finished() -> void:
	while not _deferred.is_empty() and not _shot_player.is_playing():
		var item: Array = _deferred.pop_front()
		_apply(item[0], item[1])
	_refresh_controls()


func _on_match_ended(d: Dictionary) -> void:
	_ended = true
	_refresh_controls()
	if str(d.get("result", "")) == "no_contest":
		_hud.show_result("Trận bị huỷ", str(d.get("message", "")))
		return
	var my_team := int(_players.get(_me, {}).get("teamId", -1))
	var title := "Chiến thắng!" if int(d.get("winningTeam", 0)) == my_team else "Thất bại"
	# The server sends "rewards": null when granting them failed; never show that as +0.
	var rewards = d.get("rewards")
	var reward = rewards.get(_me) if rewards is Dictionary else null
	var detail := "Chưa lấy được phần thưởng của trận này"
	if reward is Dictionary:
		detail = "+%d EXP   +%d xu" % [int(reward.get("expGained", 0)), int(reward.get("coinGained", 0))]
	_hud.show_result(title, detail)


# ── Local actions ────────────────────────────────────────────────────────────

func _on_fire(angle: float, power: float) -> void:
	if not _can_act():
		return
	_hud.pause_timer() # the server stops the clock once it takes the shot
	await _commit_action("Shoot", {"angle": angle, "power": power, "actionMode": "weapon"})


func _on_end_turn() -> void:
	if not _can_act():
		return
	await _commit_action("EndTurn", {})


## Sends Shoot/EndTurn once:
## - every Move has been answered (MoveSync.is_settled), so the server fires from the position
##   on screen; a dropped Move is re-sent first; and
## - ACTION_INTERVAL has passed since the last action.
## Both are re-checked every frame (process_frame fires before _process), so a Move re-send
## cannot slip in between and make the server drop the Shoot under its 150 ms rate limit. The
## wait is bounded by MoveSync's re-send limit (about 3 s). The answer timeout starts only once
## the command is actually sent. If MoveSync loses track of the server (needs_resync), the
## pending command is cancelled instead (see _request_resync).
func _commit_action(event: String, data: Dictionary) -> void:
	_committing = true
	_hold_dir = 0
	_moves.release()
	_refresh_controls()
	while _committing and _is_my_turn() and (not _moves.is_settled() or _since_action < ACTION_INTERVAL):
		await get_tree().process_frame
	if not _is_my_turn() or not _committing:
		return
	_commit_sent = true
	GameSocket.send(event, data)
	_mark_action()
	_awaiting_shot = SHOT_ACK_TIMEOUT


## The server's position is unknown (Moves unanswered after every re-send). Cancel any
## Shoot/EndTurn still waiting, keep input locked (_can_act) and ask for a full MatchStateSync,
## repeating every RESYNC_RETRY seconds. The snapshot resets MoveSync via _set_current.
func _request_resync(delta: float) -> void:
	if _committing and not _commit_sent:
		_committing = false # the waiting _commit_action returns without sending
	_resync_in -= delta
	if _resync_in > 0.0:
		return
	GameSocket.send("Reconnect", {})
	_resync_in = RESYNC_RETRY
	_refresh_controls()


func _mark_action() -> void:
	_since_action = 0.0


func _on_leave() -> void:
	GameSocket.send("Leave", {})
	Router.go(Router.HOME)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _pos(id: String) -> Vector2:
	return _vec(_players[id]["position"])


func _set_pos(id: String, p: Vector2) -> void:
	if _players.has(id):
		_players[id]["position"] = {"x": p.x, "y": p.y}


func _set_hp(id: String, hp: int) -> void:
	if not _players.has(id):
		return
	_players[id]["hp"] = hp
	_views[id].set_hp(hp)


func _kill(id: String) -> void:
	if not _players.has(id):
		return
	_players[id]["isAlive"] = false
	_views[id].set_dead()


func _popup(id: String, text: String, color: Color) -> void:
	if not _views.has(id):
		return
	var label := DamagePopup.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.position = _views[id].position + Vector2(0, -80)
	_fx_layer.add_child(label)


static func _vec(d: Dictionary) -> Vector2:
	return Vector2(float(d["x"]), float(d["y"]))
```

- [ ] **Step 3: Load the project headless and run the tests**

Run: `"$GODOT" --headless --path . --quit 2>&1 | grep -iE "error|failed" || echo "clean"`
Expected: `clean`.

Run: `tests/run.sh`
Expected: `41 passed, 0 failed`.

- [ ] **Step 4: Commit**

```bash
git add match/match_screen.gd match/match_screen.tscn
git commit -m "feat: match screen with shot replay, deferred events and predicted movement"
```

---

### Task 15: End-to-end check against the real server

No new files. This task confirms that M1 is done.

- [ ] **Step 1: Start the server**

```bash
cd ../battle-squad
docker compose up -d postgres redis
go run ./cmd/migrate
go run ./cmd/api &
go run ./cmd/game
```

Expected: the api listens on 9090 and the game listens on 9091 (from `.env`).

- [ ] **Step 2: Run the client**

Run: `"$GODOT" --path ../battle-squad-game`

Go through each item below. Any failure is a bug: fix it in its own commit before ticking the item.

1. **Flow**
   - Splash leads to Login (first run) or Home (saved session).
   - Guest login leads to Home with "● Online".
   - "Chơi nhanh (Luyện tập)" opens Match within 1–2 s.
2. **Terrain**
   - The map fills the window with no gaps.
   - The top edge is grass and the rest is dirt.
3. **First turn**
   - The HUD shows whose turn it is, a countdown and the wind. This confirms that the held `TurnStarted` reached Match.
4. **Movement**
   - Holding ▶ or ◀ moves your character on the same frame, climbing small slopes and stopping at walls.
   - Releasing it does **not** make the character snap back.
   - The energy bar drains, and walking stops when it is empty.
   - Walk right, then left, then right in quick taps. After the final `PlayerMoved`, the character and the energy bar have not jumped. The prediction matched the server's per-command cost.
   - Walk, then immediately drag and fire, or press "Hết lượt". The shot or turn end always goes through. There is no `action rate limited` line in the server log.
   - The shell always leaves from where the character is drawn, even right after walking.
5. **Aiming**
   - Dragging shows the preview arc and the angle/power readout.
   - Releasing inside the circle around your character cancels without firing.
6. **Shot**
   - The projectile flies smoothly, a crater appears where it lands, and a damage number floats over anyone hit.
   - The preview arc ends where the shell actually explodes, including against crater lips.
   - The turn clock stops while the shell flies and while players fall, and only restarts with the next turn.
   - The turn label changes only **after** the animation ends.
7. **Falling**
   - Blowing the ground out under a player makes them fall smoothly. Fall damage shows on landing.
8. **End turn**
   - "Hết lượt" passes the turn.
   - Controls stay disabled during the opponent's turn and during replays.
9. **Match end**
   - Kill the bot, or fall off the map.
   - The result panel shows win or loss and the rewards.
   - "Về sảnh" returns to Home, and Quick Play works again.
   - Stop `cmd/game` while Home shows "Đang tạo trận...". The status becomes "Mất kết nối..." and the button is enabled again only then.
10. **Lag check**
    - While walking and shooting, watch the server log: there must be no `action rate limited` lines.
    - With the Godot debugger open (Debugger → Monitors → Time → FPS), FPS stays at the display rate during explosions.

- [ ] **Step 3: Commit any fixes, then tag the milestone**

```bash
git tag m1
```

---

## Out of scope for M1

These are tracked in the roadmap.

- **M2:** reconnect on a new connection. This needs the server work listed in the roadmap ("M2 server work"): disconnect is not Leave, a grace period, a `playerID → roomID` index, and duplicate-room guards. M1 already rebuilds from `MatchStateSync` on the **same** connection when terrain versions differ.
- **M3:** rooms, ranked play, skills, items and freeze/net effects. M1 relies on the server rejecting illegal actions.
- **M4:** the meta screens.
- **M5:** textures, sound and store builds. Android needs cleartext HTTP allowed, or HTTPS, before it can reach the dev server.
