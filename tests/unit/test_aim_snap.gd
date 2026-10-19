extends "res://tests/test_case.gd"
## The gun's 7 directions (scenes/character/aim_snap.gd): the snap, the side and the elevation.

const AimSnap := preload("res://scenes/character/aim_snap.gd")


func test_snap_to_the_nearest_direction() -> void:
	var cases := [
		[0.0, 0.0], [10.0, 0.0], [22.4, 0.0], [22.5, 45.0], [30.0, 45.0], [45.0, 45.0], [60.0, 45.0],
		[67.4, 45.0], [67.5, 90.0], [80.0, 90.0], [90.0, 90.0], [100.0, 90.0], [112.5, 90.0],
		[112.6, 135.0], [120.0, 135.0], [135.0, 135.0], [157.5, 135.0], [157.6, 180.0], [170.0, 180.0],
		[180.0, 180.0], [200.0, 180.0], [202.5, 180.0], [202.6, 225.0], [210.0, 225.0], [225.0, 225.0],
		[250.0, 225.0], [-10.0, 0.0], [-22.5, 0.0], [-22.6, -45.0], [-45.0, -45.0], [-60.0, -45.0],
		[-89.0, -45.0], [-90.0, -45.0], [300.0, -45.0], [-135.0, 225.0], [-100.0, 225.0],
		[360.0, 0.0], [405.0, 45.0], [-180.0, 180.0], [450.0, 90.0], [-270.0, 90.0],
	]
	for c in cases:
		near(AimSnap.snap(c[0]), c[1], 1e-6, "snap(%s)" % c[0])


func test_snap_only_gives_the_seven_directions() -> void:
	var a := -720.0
	while a <= 720.0:
		for f in [-1, 0, 1]:
			var s := AimSnap.snap(a, f)
			check(AimSnap.DIRECTIONS.has(s), "snap(%s, %d) = %s is a direction" % [a, f, s])
		a += 0.5


func test_straight_up_and_down_keep_the_facing() -> void:
	near(AimSnap.snap(90.0, -1), 90.0, 1e-6, "up facing left is up")
	near(AimSnap.snap(90.0, 1), 90.0, 1e-6, "up facing right is up")
	near(AimSnap.snap(-90.0), -45.0, 1e-6, "straight down: -45 (no -90)")
	near(AimSnap.snap(-90.0, 1), -45.0, 1e-6, "straight down facing right: -45")
	near(AimSnap.snap(-90.0, -1), 225.0, 1e-6, "straight down facing left: 225")
	near(AimSnap.snap(270.0, -1), 225.0, 1e-6, "270 facing left: 225")
	near(AimSnap.snap(270.0), -45.0, 1e-6, "270 facing right: -45")


func test_side() -> void:
	eq(AimSnap.side(10.0, -1), 1, "right of up faces right")
	eq(AimSnap.side(89.0, -1), 1, "just right of up")
	eq(AimSnap.side(91.0, 1), -1, "just left of up")
	eq(AimSnap.side(100.0, 1), -1, "100 faces left (the gun still points up)")
	eq(AimSnap.side(90.0, -1), -1, "straight up keeps left")
	eq(AimSnap.side(90.0, 1), 1, "straight up keeps right")
	eq(AimSnap.side(-90.0, -1), -1, "straight down keeps left")
	eq(AimSnap.side(270.0, 1), 1, "270 keeps right")
	eq(AimSnap.side(-60.0, -1), 1, "below level on the right")
	eq(AimSnap.side(-120.0, 1), -1, "below level on the left")
	eq(AimSnap.side(450.0, -1), -1, "450 is straight up")


func test_elevation_towards_the_facing_side() -> void:
	near(AimSnap.elevation(30.0, 1), 45.0, 1e-6, "30 right: 45 up")
	near(AimSnap.elevation(150.0, -1), 45.0, 1e-6, "150 left: 45 up")
	near(AimSnap.elevation(100.0, -1), 90.0, 1e-6, "100 left: up")
	near(AimSnap.elevation(210.0, -1), -45.0, 1e-6, "210 left: -45")
	near(AimSnap.elevation(-90.0, 1), -45.0, 1e-6, "straight down: -45")
	near(AimSnap.elevation(140.0, 1), 90.0, 1e-6, "behind and up (facing right): held up")
	near(AimSnap.elevation(200.0, 1), -45.0, 1e-6, "behind and down: held at -45")
	for a in [-80.0, -45.0, 0.0, 20.0, 45.0, 70.0, 90.0, 100.0, 135.0, 160.0, 200.0, 230.0]:
		var f := AimSnap.side(a, 1)
		var e := AimSnap.elevation(a, f)
		near(e if f > 0 else 180.0 - e, AimSnap.snap(a), 1e-6, "elevation agrees with snap at %s" % a)
