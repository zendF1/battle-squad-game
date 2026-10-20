extends SceneTree
## Writes the walk bob of each side view's back carry (assets/characters/<id>/side/carry.json
## back.bob, read by ui/art.gd parse_carry(); scenes/character/character.gd slings the gun across
## the back while walking): per walk frame, how far the upper body (the opaque pixels from the top
## of the figure down BAND of its height) has its centre from the idle frame's, texture px, so the
## gun rides with the body. Everything else in carry.json is hand-written and kept. Runs headless
## (only Image is used; the editor may stay open):
##
##   $GODOT --headless --path . -s tools/carry_bob.gd
##
## Rerun after the walk or idle frames change.

const Art := preload("res://ui/art.gd")
const BAND := 0.45 # the upper body: this part of the figure's height from its top
const ALPHA := 0.5


func _initialize() -> void:
	for id in Art.CHARACTERS:
		var dir := Art.side_dir(id)
		var path := dir + "carry.json"
		if not FileAccess.file_exists(path) or not FileAccess.file_exists(dir + "side.json"):
			continue
		var side = JSON.parse_string(FileAccess.get_file_as_string(dir + "side.json"))
		var carry = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not side is Dictionary or not carry is Dictionary or not carry.get("back") is Dictionary:
			push_warning("carry_bob: %s skipped" % id)
			continue
		var feet := float(side["pivot"][1])
		var idle := _centre(dir + str(side["anims"]["idle"]["frames"][0]) + ".png", feet)
		var bob: Array = []
		for stem in side["anims"]["walk"]["frames"]:
			var c := _centre(dir + str(stem) + ".png", feet) - idle
			bob.append([snappedf(c.x, 0.01), snappedf(c.y, 0.01)])
		carry["back"]["bob"] = bob
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(carry, "\t", false) + "\n")
		f.close()
		print("carry_bob: %s %s" % [id, bob])
	quit(0)


## The centre of the opaque pixels in the figure's upper band (texture px).
func _centre(png: String, feet: float) -> Vector2:
	var img := Image.load_from_file(ProjectSettings.globalize_path(png))
	if img == null or img.is_empty():
		push_error("carry_bob: cannot read %s" % png)
		return Vector2.ZERO
	img.convert(Image.FORMAT_RGBA8)
	var top := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= ALPHA:
				top = y
				break
		if top >= 0:
			break
	if top < 0:
		return Vector2.ZERO
	var bottom := int(top + (feet - top) * BAND)
	var sum := Vector2.ZERO
	var n := 0
	for y in range(top, mini(bottom + 1, img.get_height())):
		for x in img.get_width():
			if img.get_pixel(x, y).a >= ALPHA:
				sum += Vector2(x, y)
				n += 1
	return sum / maxf(1.0, n)
