# Battle Squad Godot Client — Roadmap & Design

Godot 4.7 (GDScript, Mobile renderer) client for the Go server in `../battle-squad`.
It replaces the Flutter demo `../battle-squad-v1` and keeps its user flow.

## Target

- Mobile, landscape, touch first. On the Mac, the mouse stands in for touch.
- Viewport 1600×900, the server's default map size. Stretch mode `canvas_items` + `expand`.
- Dev servers: API `http://localhost:9090`, game WS `ws://localhost:9091` (from `battle-squad/.env`).

## User flow (same as the Flutter demo)

```
Splash ──token ok──► Home (tabs: Play · Profile · Shop · Missions · Ranking)
   └──no token──► Login (guest) ──► Home
Home/Play ──Quick Play──────────────────────────────► Match ──► Home
Home/Play ──Create/Join room──► Room ──StartMatch──► Match
Home/Play ──Ranked 2v2──► Ranked lobby ──queue──────► Match
Home ──gear──► Settings (gift code, account deletion, logout)
Profile ──► Characters (stat allocation)
```

`MatchStarted` is the only way into Match. Leaving Match always returns to Home.

The full screen and protocol inventory of the demo is in the "Flow reference" section below.

## Milestones

Each milestone gets its own implementation plan in `docs/superpowers/plans/`.

| # | Scope | Server work |
|---|-------|-------------|
| **M1** | Foundation + vertical slice: Splash → guest Login → Home (Play tab: Quick Play) → Match against the bot → result → Home | Refresh: unique token IDs, the new session is saved before the old is revoked, 401 only for unusable tokens. `PlayerMoved` echoes `Move.seq`. Test-only fixture exporter |
| M2 | Robust networking: reconnect mid-match on a **new** connection, terrain resync, token refresh on WS | **Yes, see "M2 server work"** |
| M3 | Rooms (list, create, join, ready, start), Ranked 2v2 lobby + queue, character/item select, skills and items in Match | none |
| M4 | Meta: Profile, Characters, Shop (+ idempotency keys), Missions, Ranking, Settings | none |
| M5 | Art: real brick textures from map tiles, effects, sound, mobile export | `GET /maps/{id}` (tiles + brick types) |

## Gameplay without lag (applies to every milestone)

The server owns all game state. The client predicts only where the result is deterministic, and replays the rest.

1. **Terrain is a byte-exact copy.**
   - `TerrainMask` ports `terrain.go` (`IsSolid`, `GetLandingY`, `DestroyCircle`, `WalkTo`) line for line, with the same rounding.
   - A Go test exports fixtures, and the Godot tests compare against them byte for byte.
   - Decoding the RLE snapshot appends whole runs, never single pixels, so a 1600×900 map decodes in milliseconds.
2. **Own movement is predicted per command.**
   - Holding ←/→ moves the character on the same frame.
   - The walk is cut into one-direction segments. Each segment is sent as one `Move{targetX}`, at most every 250 ms. The server rate-limits at 150 ms, and the demo lost moves by sending every 100 ms.
   - Each segment is simulated exactly as `processMove` does it: clamp to `moveEnergy*2`, then `WalkTo`, then cost `round(|dx|*0.5)` **for that command**. The server rounds per command and charges the net distance of each command. Rounding over the whole walk drifts, so porting `WalkTo` alone is not enough.
   - What is displayed is the last `PlayerMoved` with every unacknowledged command replayed on top of it.
   - Each `Move` carries a `seq`, which the server echoes in `PlayerMoved`. This is an additive protocol change in M1. An answer acknowledges every command up to its `seq`, so a late answer is never taken for a newer command.
   - After 1 s of silence since the newest command left, checked every frame, its target is re-sent under a new `seq`. Older commands stay in the replay. The re-send count resets only when every command is answered, so a round trip longer than 1 s still ends. After 2 unanswered re-sends the server state is treated as **unknown**, not rejected, because the answer may simply be late. The client then keeps the prediction on screen, cancels any pending `Shoot`/`EndTurn`, locks input and requests `MatchStateSync`. It unlocks on the snapshot, or on the newest command's late answer.
   - Each `Reconnect` records the last `seq` sent. Its snapshot covers the commands up to that `seq`; commands sent after the `Reconnect` reach the server after the snapshot was taken, so they are replayed on top of it.
   - `Shoot` and `EndTurn` wait until every `Move` is **answered**, which means the shown position is the server's, until 250 ms have passed since the last action, and until 160 ms have passed since the last `Move` answer arrived.
     - The server sent that answer after it processed the `Move`, so the last condition keeps the next action ≥ 160 ms behind it on the server whatever the jitter.
     - The wait is re-checked every frame, so a `Move` re-send cannot get them dropped by the rate limit.
     - It is bounded by the re-send limit, about 3 s.
   - Energy and position are pushed to the HUD separately, because an answer may correct only the energy.
   - The client's per-command simulation is parity-tested against the real `processMove`.
3. **Opponents are interpolated.** `PlayerMoved` for other players tweens them at walking speed instead of teleporting them.
4. **Aiming is local.**
   - The trajectory preview runs the server's integration on the client, including the 4 px sub-sampling of each segment. Thin walls and crater lips therefore stop the preview exactly where they stop the shell.
   - Parity is tested against `SimulateProjectile`.
   - Drag, preview and the cancel zone never touch the network.
5. **Shots are replayed from one `ShotResolved` message.**
   - Projectiles follow the server path with Hermite interpolation between samples, so they are smooth at any FPS.
   - Timeline events fire at their `t`.
   - Every other match event (`TurnStarted`, `MatchEnded`, …) that arrives during the replay waits until it ends, so the HUD never jumps ahead of the animation.
   - The turn clock pauses from the moment of the shot until the next timer event is applied. The server pauses its clock too.
6. **Terrain updates are cheap.** The solid mask is the L8 image itself: an explosion edits bytes, then does one texture upload. The look comes from a shader, so there is no per-pixel drawing in GDScript.
7. **The network never blocks the frame.**
   - `WebSocketPeer` is polled in `_process`, and its inbound buffer is raised to 4 MB because `MatchStarted` carries the whole terrain.
   - Events that arrive during a scene change are held, then delivered to the next scene.
8. **Version checks catch drift.**
   - Every `explode` event carries `terrainVersion`. On a mismatch the client sends `Reconnect` and rebuilds from the `MatchStateSync` snapshot. M1 includes this check. M2 hardens it.

## M2 server work

The client cannot do M2 alone, because the server treats a lost WebSocket as `Leave`:
- `WSHandler.Unregister` calls `room.Leave` (`internal/game/room/handler.go`).
- During a match, that becomes `processLeave`, which kills the character. A tutorial room is destroyed.
- A new connection has an empty `RoomID`, so the server answers `Reconnect` with `ROOM_REQUIRED`.

Required server changes:
1. **Disconnect is not Leave.**
   - On `Unregister` during a match, mark the player as disconnected and keep their slot for a grace period, e.g. 30 s. Their turns time out as usual.
   - Kill the character, or end the tutorial room, only when the grace period expires.
2. **Hub index `playerID → roomID`.**
   - Maintain it on join, leave and room teardown.
   - When a connection with an empty `RoomID` sends `Reconnect`, look up its room by the authenticated player id. Then re-attach the connection (`processReconnect` already swaps the client and sends `MatchStateSync`) and cancel the grace timer.
3. **Reject `QuickPlay`/`CreateRoom`/`JoinRoom`** from a player the index already places in a room. This stops retries from creating duplicate rooms.

## Out of scope for M1

Reconnect UI, rooms, ranked play, skills, items, meta screens, sound, real textures, store builds.

## Flow reference (from the Flutter demo)

**REST**
- Every response is an envelope: `{"success":true,"data":X}` or `{"success":false,"error":{"code","message"}}`.
- Auth is `Authorization: Bearer <accessToken>`. On a 401 the client calls `POST /auth/refresh {refreshToken}` once and retries.
- Guest login: `POST /auth/guest-login {deviceInstallId}` returns `{accessToken, refreshToken, playerId, displayName, level}`.
  - The id is a UUID v4 generated once and saved. The demo instead used unstable device ids.

**WS**
- Connect to `ws://host:9091/ws?token=<accessToken>`. Messages are `{"event","data"}` envelopes.

**Quick Play**
- Send `QuickPlay {}`.
- `MatchStarted` → open Match. `RoomError` → show the error.
- After 10 s, show a "server is slow" notice and keep waiting. A `MatchStarted` that arrives late is still accepted, because the server really did put the player in that match.
- Allow a retry only once the request is resolved: `MatchStarted`, `RoomError`, or a disconnect (on disconnect the server drops the room).

**Room** (M3)
- Create or join:
  - `CreateRoom {mode, mapId, password?}` → `RoomUpdated`
  - `JoinRoom {roomId, password?}` → `RoomUpdated`
- In the room:
  - `SelectCharacter {characterId}`
  - `SelectItems {items}` (max 3)
  - `Ready {}`, which toggles
  - Host only: `StartMatch {}`
  - `Leave {}`
- `MatchStarted` → open Match.
- Match the `roomId`. The demo did not.

**Ranked** (M3)
- `CreateLobby {}` on open
- `UpdateLoadout {characterId | items}`
- `StartQueue {}` / `CancelQueue {}`
- Server events:
  - `LobbyUpdated {status: preparing|in_queue|in_match}`
  - `QueueStarted`, `QueueCancelled`
  - `MatchFound {roomId}`, then `MatchStarted`
  - `LobbyDisbanded {reason}`
  - `ReturnToLobby {lobbyId}`
- `LeaveLobby {}` on back.

**Meta screens** (M4)
- Profile:
  - `GET /player/profile`
  - `PUT /player/profile {display_name}`
  - `GET /player/inventory`
  - `GET /player/match-history?page=1&limit=20`
- Characters:
  - `GET /player/characters`
  - `POST /player/character/allocate-stats`
  - `POST /player/character/reset-stats`
- Shop:
  - `GET /shop/offers`
  - `POST /shop/purchase {offerId, idempotencyKey}` (reuse the key until a definite answer)
  - `GET /iap/products`, `POST /iap/verify`
- Missions:
  - `GET /missions/daily`, `GET /missions/achievements`
  - `POST /missions/claim {mission_id}`
- Ranking:
  - `GET /rank/seasons/current`
  - `GET /rank/me`
  - `GET /rank/leaderboard?page=1&limit=50`
  - `POST /rank/reward/claim`
- Settings:
  - `POST /giftcode/redeem {code}`
  - `GET /account/deletion/status`, `POST /account/deletion/request`, `POST /account/deletion/cancel`
  - `POST /auth/logout {refreshToken}`
