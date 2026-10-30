#!/bin/sh
# Builds the WebAuth GDExtension (ASWebAuthenticationSession for the Google sign-in) into addons/web_auth/bin:
#   libweb_auth.macos.dylib        macOS universal (editor, editor runs, macOS export)
#   web_auth.ios.xcframework       iOS device arm64 + simulator, WebAuth and godot-cpp in one static library
# Usage: native/web_auth/build.sh [macos|ios|all]   (default all). Needs Xcode and scons (pip3 install --user scons).
set -e
cd "$(dirname "$0")"
GODOT_CPP_TAG=godot-4.5-stable # the extension's compatibility_minimum is 4.5; it loads in 4.5+ (the project runs 4.7)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SCONS="${SCONS:-$(command -v scons || echo "$HOME/Library/Python/3.9/bin/scons")}"
JOBS=$(sysctl -n hw.ncpu)
BIN=../../addons/web_auth/bin
WHAT=${1:-all}

if [ ! -d godot-cpp ]; then
	git clone --depth 1 --branch "$GODOT_CPP_TAG" https://github.com/godotengine/godot-cpp godot-cpp
fi
mkdir -p "$BIN" build
COMMON="target=template_release build_profile=build_profile.json debug_symbols=no -j$JOBS"

if [ "$WHAT" = all ] || [ "$WHAT" = macos ]; then
	"$SCONS" platform=macos arch=universal macos_deployment_target=10.15 $COMMON
	cp build/libweb_auth.macos.dylib "$BIN/"
	codesign --force -s - "$BIN/libweb_auth.macos.dylib"
fi

if [ "$WHAT" = all ] || [ "$WHAT" = ios ]; then
	"$SCONS" platform=ios arch=arm64 ios_simulator=no ios_min_version=14.0 $COMMON
	"$SCONS" platform=ios arch=universal ios_simulator=yes ios_min_version=14.0 $COMMON
	# One static library per slice: WebAuth with its godot-cpp (Godot's iOS export links it into the app).
	mkdir -p build/device build/simulator
	libtool -static -o build/device/libweb_auth.a build/libweb_auth.ios.device.a godot-cpp/bin/libgodot-cpp.ios.template_release.arm64.a
	libtool -static -o build/simulator/libweb_auth.a build/libweb_auth.ios.simulator.a godot-cpp/bin/libgodot-cpp.ios.template_release.universal.simulator.a
	rm -rf "$BIN/web_auth.ios.xcframework"
	xcodebuild -create-xcframework -library build/device/libweb_auth.a -library build/simulator/libweb_auth.a \
		-output "$BIN/web_auth.ios.xcframework"
fi
ls -la "$BIN"
