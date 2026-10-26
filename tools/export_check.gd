extends SceneTree
## Export check: prints what the game resolves at run time, one line per item: every runtime script
## and whether it compiles, the art ui/art.gd picks for each character, gun and boss.
## tools/build_ios.sh runs it on the project and on the exported .pck (from an empty folder, so
## nothing falls back to the project's files) and stops the build on any difference: what works in
## the editor but not in a build (a preload from a folder the export leaves out, a FileAccess check on
## a PNG the export only keeps imported).
## Usage: $GODOT --headless --path . --script res://tools/export_check.gd
##        $GODOT --headless --main-pack <pck> --script res://tools/export_check.gd

const Art := preload("res://ui/art.gd")
const RUNTIME := ["autoload", "core", "match", "screens", "scenes", "ui"]


func _initialize() -> void:
	var out := PackedStringArray()
	for dir in RUNTIME:
		_scripts("res://%s/" % dir, out)
	for id in Art.CHARACTERS:
		out.append("look %s: %s" % [id, _desc(Art.character_look(id))])
		out.append("full %s: %s" % [id, _desc(Art.lobby_full(id))])
		out.append("portrait %s: %s" % [id, _tex(Art.portrait(id))])
	for kind in Art.GUN_TIERS:
		for tier in Art.GUN_TIERS[kind]:
			var g := Art.gun(kind, tier)
			out.append("gun %s %s: %s ui=%s" % [kind, tier, _desc(g), _tex(Art.ui_gun_texture(g))])
	for boss in DirAccess.get_directories_at(Art.ROOT + "bosses"):
		out.append("boss %s side: %s" % [boss, _desc(Art.boss_side(boss))])
		out.append("boss %s skin: %s" % [boss, _desc(Art.boss_skin(boss))])
		for pic in ["portrait", "bust"]:
			out.append("boss %s %s: %s" % [boss, pic, _tex(Art.boss_picture(boss, pic))])
	print("\n".join(out))
	quit()


## Each script under dir (an export lists x.gd.remap / x.gdc for x.gd) and whether it compiles.
func _scripts(dir: String, out: PackedStringArray) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scripts(dir + sub + "/", out)
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".remap")
		if name.get_extension() != "gd":
			continue
		var s = load(dir + name)
		out.append("script %s: %s" % [dir + name, "ok" if s is GDScript and s.can_instantiate() else "BROKEN"])


func _desc(v: Variant) -> String:
	if v is Texture2D or v == null:
		return _tex(v)
	if v is SpriteFrames:
		var anims := PackedStringArray()
		for a in v.get_animation_names():
			anims.append("%s:%d:%s" % [a, v.get_frame_count(a), _tex(v.get_frame_texture(a, 0)) if v.get_frame_count(a) > 0 else ""])
		anims.sort()
		return "frames[%s]" % ",".join(anims)
	if v is Dictionary:
		var keys: Array = v.keys()
		keys.sort()
		var parts := PackedStringArray()
		for k in keys:
			parts.append("%s=%s" % [k, _desc(v[k])])
		return "{%s}" % ", ".join(parts)
	if v is Array or (typeof(v) >= TYPE_PACKED_BYTE_ARRAY and typeof(v) <= TYPE_PACKED_VECTOR4_ARRAY):
		return "[%d]" % v.size()
	return str(v)


func _tex(t: Variant) -> String:
	if t == null:
		return "null"
	if t == Art.placeholder():
		return "PLACEHOLDER"
	if t is Texture2D and t.resource_path != "":
		return t.resource_path
	return "%s %s" % [t.get_class(), t.get_size()] if t is Texture2D else str(t)
