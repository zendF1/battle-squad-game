# CLAUDE.md

Godot 4.7 client of battle-squad (server: ../battle-squad).

## Builds

An editor run proves nothing about an export. The first iOS build (2026-10) showed matches with no names, HP or boss art, and the lobby with side-view characters holding the default gun, while the editor looked right. Two causes:

- Exports leave out `art_source/`, `docs/` and `tests/` (export_presets.cfg). Runtime code never loads from them. `tools/` stays in the export because `match/views/shield_ball.gd` preloads `tools/art/equipment_painter.gd`. `tests/unit/test_export_safety.gd` checks this.
- An export keeps only the `.import` remap of a PNG, never the PNG itself. At run time, never use `FileAccess.file_exists()` to check for an image: use `Art.has_png()` or `ResourceLoader.exists()`. `FileAccess` is for JSON, cfg and `user://` files.

How to build and check:

- iOS: run `tools/build_ios.sh [host]`. It bakes the server URL into `res://server.cfg`, exports, then runs `tools/check_export.sh`, which compares what the project and the `.pck` resolve (scripts compiling, the art picked) and stops on any difference.
- Any other export: run `tools/check_export.sh <pck>` before handing it over.
- Device log (Developer Mode on): `Documents/logs/godot.log`. Fetch it with `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier com.inspius.battlesquad --source Documents/logs/godot.log --destination <file> --device <id>`.
