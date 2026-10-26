#!/bin/sh
# Runs tools/export_check.gd on the project and on an exported .pck (from an empty folder, user://
# redirected) and fails on any difference: what works in the editor but not in a build (a preload
# from a folder the export leaves out, a FileAccess check on a PNG the export only keeps imported).
# Usage: tools/check_export.sh <exported.pck>
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
[ -f "$1" ] || { echo "usage: tools/check_export.sh <exported.pck>" >&2; exit 2; }
PCK="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/home" "$TMP/empty"
ITEMS='^(script|look|full|portrait|gun|boss) '
HOME="$TMP/home" "$GODOT" --headless --path . --script res://tools/export_check.gd 2>/dev/null | grep -E "$ITEMS" > "$TMP/project.txt" || true
(cd "$TMP/empty" && HOME="$TMP/home" "$GODOT" --headless --main-pack "$PCK" --script res://tools/export_check.gd 2>/dev/null) | grep -E "$ITEMS" > "$TMP/export.txt" || true
if [ ! -s "$TMP/project.txt" ] || ! diff "$TMP/project.txt" "$TMP/export.txt" > "$TMP/diff.txt"; then
	echo "export check FAILED: the build resolves differently from the project (< project, > build):" >&2
	head -40 "$TMP/diff.txt" >&2
	exit 1
fi
echo "export check: $(wc -l < "$TMP/project.txt" | tr -d ' ') items match the project"
