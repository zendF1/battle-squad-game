# CLAUDE.md

Godot 4.7 client of battle-squad (server: ../battle-squad).

## Docs

How work is split and run (agents, branches from `feat/dev`, worktrees, merge back): `../battle-squad/docs/agents.md`; read it before starting a feature.

Everything agreed with the user goes into docs in the same change: specs and the decision log live in the server repo (`../battle-squad/docs/specs/`, `../battle-squad/docs/product-decisions.md`); client-only details (art prompts, screen behaviour) in this repo's docs / `art_source/*/PROMPTS.md`.

## UI

Show things in game with pictures (icon, colour, shape, animation), not words or numbers. Add a number only when a picture cannot carry it (a quantity, a timer), and never repeat what the picture already says (a stone's look shows its level: no level badge on it).

Rewards are always shown with the one reward effect, `ui/reward_reveal.gd` (`RewardReveal.open(host, tiles, opts)`: the chest / gift box bursts open, glowing tiles with icon + "×N" only fly out; tiles from `ui/reward_model.gd`); a list of rewards that is not being granted uses its glowing tiles (`ui/reward_strip.gd`).

## Builds

An editor run proves nothing about an export. The first iOS build (2026-10) showed matches with no names, HP or boss art, and the lobby with side-view characters holding the default gun, while the editor looked right. Two causes:

- Exports leave out `art_source/`, `docs/` and `tests/` (export_presets.cfg). Runtime code never loads from them. `tools/` stays in the export because `match/views/shield_ball.gd` preloads `tools/art/equipment_painter.gd`. `tests/unit/test_export_safety.gd` checks this.
- An export keeps only the `.import` remap of a PNG, never the PNG itself. At run time, never use `FileAccess.file_exists()` to check for an image: use `Art.has_png()` or `ResourceLoader.exists()`. `FileAccess` is for JSON, cfg and `user://` files.

How to build and check:

- iOS: run `tools/build_ios.sh [host | https://domain]`; macOS: `tools/build_macos.sh [host | https://domain]`. They bake the server into `res://server.cfg` (a host: `http://host:9090` / `ws://host:9091`; a URL: the API on it, the socket on `wss://domain/ws`), export, then run `tools/check_export.sh`, which compares what the project and the `.pck` resolve (scripts compiling, the art picked) and stops on any difference.
- Production server: `https://battlesquad.chuongnguyen.online` (contabo, `deploy/docker-compose.prod.yml` in the server repo).
- Any other export: run `tools/check_export.sh <pck>` before handing it over.
- Device log (Developer Mode on): `Documents/logs/godot.log`. Fetch it with `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier com.inspius.battlesquad --source Documents/logs/godot.log --destination <file> --device <id>`.

## Native plugin (Google sign-in sheet)

`addons/web_auth` is a GDExtension (Objective-C++ on godot-cpp) that shows `ASWebAuthenticationSession` for the Google sign-in (`core/google_sign_in.gd`; spec `../battle-squad/docs/specs/2026-10-30-settings-account-link.md`). Its source and build live in `native/web_auth` (hidden from Godot by `native/.gdignore`); the built binaries are committed: `addons/web_auth/bin/libweb_auth.macos.dylib` (universal: editor, editor runs, macOS export) and `web_auth.ios.xcframework` (iOS device + simulator, the extension and its godot-cpp in one static library, linked by Godot's iOS export). Other platforms have no library: `Engine.has_singleton("WebAuth")` is false and the Google buttons say "Sắp ra mắt", as in headless tests.

- Rebuild after changing `native/web_auth/src`: `native/web_auth/build.sh [macos|ios|all]` (needs Xcode at /Applications/Xcode.app and `pip3 install --user scons`; it fetches godot-cpp `godot-4.5-stable` into `native/web_auth/godot-cpp`, ignored). Restart the editor to load a new dylib.
- No export preset change: the macOS ad-hoc export adds the "Disable Library Validation" entitlement itself; iOS needs no URL scheme (the session catches `<reversed client id>:/oauth2redirect`) and the library pulls in AuthenticationServices.
- Client IDs: project settings `battle_squad/google_client_id_ios` / `_macos` (iOS-type OAuth clients, no secret).
