#!/usr/bin/env bash
# Runs the headless unit tests. Set GODOT to the Godot 4.7 binary.
set -uo pipefail
GODOT="${GODOT:-/Users/inspius/Downloads/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")/.."
out="$("$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1)"
status=$?
echo "$out"
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script|Invalid call" <<<"$out"; then
	echo "test run had script errors"
	exit 1
fi
exit $status
