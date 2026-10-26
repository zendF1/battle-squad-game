#!/bin/sh
# Exports the iOS Xcode project into build/ios with the server URLs baked in res://server.cfg.
# Usage: tools/build_ios.sh [server-host]   (default: this Mac's Wi-Fi IP, for phones on the same Wi-Fi)
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
HOST=${1:-$(ipconfig getifaddr en0 || ipconfig getifaddr en1)}
[ -n "$HOST" ] || { echo "no Wi-Fi IP found; pass the server host" >&2; exit 1; }

printf '[server]\n\napi_url="http://%s:9090"\nws_url="ws://%s:9091"\n' "$HOST" "$HOST" > server.cfg
trap 'rm -f server.cfg' EXIT
rm -rf build/ios && mkdir -p build/ios
"$GODOT" --headless --path . --export-debug "iOS" build/ios/battle-squad.ipa
echo "server: http://$HOST:9090  ws://$HOST:9091"
echo "Xcode project: build/ios/battle-squad.xcodeproj"
