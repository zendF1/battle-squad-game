#!/usr/bin/env bash
# Records the bone rig's dev preview (scenes/dev/rig_preview.tscn) into PNG frames and a GIF, without
# touching the real project's user data: a throwaway mini project (symlinks to the rig's scripts and
# parts, no autoloads, its own user dir) is run windowed in the background with Godot's movie writer.
#   tools/record_rig_preview.sh OUT_DIR [CHARACTER]   (default rookie; spark, tanko, flora)
# The mini project has only the rig: its back sling / gun length are the rig's defaults, not the carry
# scene's (scenes/character/poses/<id>_carry.tscn shows those live in the editor).
# OUT_DIR gets frames/ (30 fps), rig_preview.gif, rig_preview.mp4 when ffmpeg is installed, and
# rig_poses.png (the key poses side by side, big).
# GODOT_BG: the background-only Godot wrapper (default: the server repo's .claude/tools/godot-bg.sh).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:?usage: record_rig_preview.sh OUT_DIR [CHARACTER]}"
who="${2:-rookie}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
bg="${GODOT_BG:-$here/../battle-squad/.claude/tools/godot-bg.sh}"
proj="$(mktemp -d "${TMPDIR:-/tmp}/rig_preview.XXXXXX")"
trap 'rm -rf "$proj"' EXIT
mkdir -p "$proj/scenes/character" "$proj/assets/characters/$who" "$proj/assets/weapons/bazooka"
ln -s "$here/scenes/character/rig" "$proj/scenes/character/rig"
ln -s "$here/scenes/dev" "$proj/scenes/dev"
ln -s "$here/assets/characters/$who/rig" "$proj/assets/characters/$who/rig"
cp "$here/assets/weapons/hug.json" "$proj/assets/weapons/"
cp "$here/assets/weapons/bazooka/hug_iron.png" "$proj/assets/weapons/bazooka/"
cat > "$proj/project.godot" <<'CFG'
config_version=5

[application]
config/name="rig-preview-scratch"
run/main_scene="res://scenes/dev/rig_preview.tscn"
config/use_custom_user_dir=true
config/custom_user_dir_name="rig-preview-scratch"

[display]
window/size/viewport_width=960
window/size/viewport_height=540

[rendering]
renderer/rendering_method="gl_compatibility"
textures/canvas_textures/default_texture_filter=1
CFG
rm -rf "$out/frames"
mkdir -p "$out/frames"
"$bg" --path "$proj" --write-movie "$out/frames/f.png" --fixed-fps 30 --resolution 960x540 -- --quit-at-end --character="$who" >"$out/godot.log" 2>&1 || true
n=$(ls "$out/frames" | wc -l | tr -d ' ')
echo "frames: $n"
"$bg" --path "$proj" --resolution 320x180 -- --poses --out="$out/rig_poses.png" --quit-at-end --character="$who" >>"$out/godot.log" 2>&1 || true
python3 -I "$here/tools/rig_preview_gif.py" "$out/frames" "$out/rig_preview.gif"
if command -v ffmpeg >/dev/null; then
	ffmpeg -loglevel error -y -framerate 30 -i "$out/frames/f%08d.png" -pix_fmt yuv420p "$out/rig_preview.mp4"
fi
