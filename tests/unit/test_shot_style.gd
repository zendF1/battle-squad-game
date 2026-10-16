extends "res://tests/test_case.gd"

const ProjectileView := preload("res://match/views/projectile_view.gd")
const ExplosionFx := preload("res://match/views/explosion_fx.gd")
const Art := preload("res://ui/art.gd")


func test_style_by_shooter_character() -> void:
	eq(ProjectileView.style_for("rookie", "weapon", ""), {"kind": "rookie", "skill": false, "item": ""}, "rookie bomb")
	eq(ProjectileView.style_for("tanko", "weapon", "")["kind"], "tanko", "tanko cannonball")
	eq(ProjectileView.style_for("spark", "skill", ""), {"kind": "spark", "skill": true, "item": ""}, "skill shot")
	eq(ProjectileView.style_for("flora", "item", "freeze_bomb"), {"kind": "flora", "skill": false, "item": "freeze_bomb"}, "item keeps the shooter's projectile")
	eq(ProjectileView.style_for("tanko", "item", "air_strike")["kind"], "rookie", "air strike keeps the bomb")
	eq(ProjectileView.style_for("", "weapon", "")["kind"], "rookie", "unknown shooter: bomb")
	eq(ProjectileView.style_for("nope", "weapon", "spider_net")["item"], "", "itemId ignored outside item shots")


func test_every_kind_has_projectile_and_impact_looks() -> void:
	for kind in ProjectileView.STYLES:
		check(ExplosionFx.STYLES.has(kind), "%s has an impact" % kind)
		if kind != "rookie":
			check(Art.SHOT_KINDS.has(kind), "%s has art" % kind)
	for kind in Art.SHOT_KINDS:
		check(ProjectileView.STYLES.has(kind), "art kind %s is drawn" % kind)
		var img := Image.load_from_file(ProjectSettings.globalize_path(Art.shot_path(kind, "impact_0")))
		check(img != null and img.get_size() == Vector2i(256, 256), "%s impact frame size" % kind)
	for item in ProjectileView.ITEM_LOOKS:
		check(preload("res://match/items.gd").BY_ID.has(item), "item look %s is an item" % item)


func test_shot_art_falls_back() -> void:
	var bomb := Art.fx("bomb")
	check(Art.shot("rookie", "projectile", bomb) == bomb, "rookie shoots the bomb")
	check(Art.shot("nope", "projectile", bomb) == bomb, "unknown kind: fallback")
	eq(Art.shot_path("spark", "trail"), "res://assets/fx/spark/trail.png", "shot path")
