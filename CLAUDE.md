# CLAUDE.md

Godot 4.7 client of battle-squad (server: ../battle-squad).

## Docs

How work is split and run (agents, working on `feat/dev` in the checkout, no worktrees): `../battle-squad/docs/agents.md`; read it before starting a feature.

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
