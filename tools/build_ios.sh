#!/bin/sh
# Exports the iOS Xcode project into build/ios with the server URLs baked in res://server.cfg.
# Usage: tools/build_ios.sh [host | https://domain]   (default: this Mac's Wi-Fi IP, for phones on the same Wi-Fi)
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
HOST=${1:-$(ipconfig getifaddr en0 || ipconfig getifaddr en1)}
[ -n "$HOST" ] || { echo "no Wi-Fi IP found; pass the server host" >&2; exit 1; }

. tools/server_cfg.sh
write_server_cfg "$HOST"
rm -rf build/ios && mkdir -p build/ios && touch build/.gdignore # keep Godot from importing the build output
"$GODOT" --headless --path . --export-debug "iOS" build/ios/battle-squad.ipa
tools/check_export.sh build/ios/battle-squad.pck
echo "server: $API  $WS"
echo "Xcode project: build/ios/battle-squad.xcodeproj"
