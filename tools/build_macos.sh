#!/bin/sh
# Exports the macOS app (build/battle-squad.zip, unzipped to build/macos) with the server URLs baked in
# res://server.cfg, then runs tools/check_export.sh on its .pck.
# Usage: tools/build_macos.sh [host | https://domain]   (default: localhost, the dev server)
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
. tools/server_cfg.sh
write_server_cfg "${1:-localhost}"
rm -rf build/macos build/battle-squad.zip && mkdir -p build/macos && touch build/.gdignore
"$GODOT" --headless --path . --export-release "macOS" build/battle-squad.zip
ditto -x -k build/battle-squad.zip build/macos
# Finder caches a blank icon when it looks at the app while it is being unzipped: re-register it
APP_PATH="$(find build/macos -maxdepth 1 -name '*.app' | head -1)"
touch "$APP_PATH" "$APP_PATH/Contents/Info.plist"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH" || true
tools/check_export.sh "$(find build/macos -name '*.pck' | head -1)"
echo "server: $API  $WS"
echo "app: $(find build/macos -maxdepth 1 -name '*.app')"
