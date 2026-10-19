extends RefCounted
## Test fixture: a character look WITHOUT a drawn ready pose, for the tests of the code gun draw
## (scenes/character/character.gd: the gun drawn up from the low carry, turned to the aim, the
## grip hand over it; out of the match the gun always in hand). Every character now has its side
## view with a kneeling ready pose, so no real one takes that path; it is still the fallback of a
## side view without a ready picture and of the code-baked frames (tools/bake_art.gd, a character
## without hand-drawn art). The look is Rookie's side view with its ready pose taken out (no
## draw / fire frames, no readyPose, gun_draw.gd's default timings, the anchors of idle / walk /
## shoot / hurt / die), cached under a real id (ui/art.gd maps unknown ids to Rookie), so a
## Character / PlayerView with that id draws it. install() returns the Callable that puts the
## cache back.

const Art := preload("res://ui/art.gd")


static func install(id: String) -> Callable:
	var had_look: Variant = Art._looks.get(id)
	var had_pose: Variant = Art._ready_poses.get(id)
	var look: Dictionary = Art.side_view(Art.DEFAULT_CHARACTER).duplicate()
	look["ready"] = {}
	look["draw_frames"] = false
	look["fire_frames"] = false
	look["gun_draw"] = {}
	var anchors := {}
	for anim in Art.ANIMS:
		anchors[anim] = look["anchors"].get(anim, [])
	look["anchors"] = anchors
	Art._looks[id] = look
	Art._ready_poses[id] = {}
	return func() -> void:
		if had_look == null:
			Art._looks.erase(id)
		else:
			Art._looks[id] = had_look
		if had_pose == null:
			Art._ready_poses.erase(id)
		else:
			Art._ready_poses[id] = had_pose
