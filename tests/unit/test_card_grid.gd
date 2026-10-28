extends "res://tests/test_case.gd"

const CardGrid := preload("res://ui/card_grid.gd")


func test_columns() -> void:
	eq(CardGrid.columns_for(1568, 206, 14), 7, "seven 206 px cards in 1568 px")
	eq(CardGrid.columns_for(1000, 206, 14), 4, "four in 1000 px")
	eq(CardGrid.columns_for(100, 206, 14), 1, "always one column")
	eq(CardGrid.columns_for(440, 206, 14), 2, "exact fit counts the gap once")
	eq(CardGrid.columns_for(500, 0, 14), 1, "no cell width")


func test_layout_same_size_rows_aligned() -> void:
	var rects := CardGrid.layout(13, 1568, Vector2(206, 280), 14, 8)
	eq(rects.size(), 13, "one rect per card")
	for r in rects:
		eq(r.size, Vector2(206, 280), "every card the same size")
	# 7 columns: 7 * 206 + 6 * 14 = 1526, centred in 1568 → 21 px each side.
	eq(rects[0].position, Vector2(21, 8), "first card under the top pad, block centred")
	eq(rects[6].position.x + 206 + 21, 1568.0, "mirrored right margin")
	eq(rects[7].position, Vector2(21, 8 + 280 + 14), "second row starts at the first column")
	eq(rects[12].position.x, rects[5].position.x, "columns line up across rows")
	eq(rects[12].position.y, rects[7].position.y, "a row shares its top")


func test_short_row_centred() -> void:
	var rects := CardGrid.layout(3, 1568, Vector2(300, 200), 14, 0)
	var used := 3 * 300 + 2 * 14
	eq(rects[0].position.x, (1568 - used) / 2.0, "three cards centred on themselves")
	eq(1568 - (rects[2].position.x + 300), rects[0].position.x, "mirrored")


func test_height_reaches_last_row() -> void:
	eq(CardGrid.height_for(13, 1568, Vector2(206, 280), 14, 8), 8 * 2 + 2 * 280 + 14.0, "two rows plus pads")
	eq(CardGrid.height_for(14, 1000, Vector2(206, 280), 14, 8), 16 + 4 * 280 + 3 * 14.0, "four rows of four")
	eq(CardGrid.height_for(0, 1000, Vector2(206, 280), 14, 8), 16.0, "empty: the pads")


func test_container_sizes_every_card_alike() -> void:
	var g := CardGrid.new()
	g.gap = 10
	g.pad = 0
	g.cell = Vector2(100, 0)
	for h in [40, 90, 60]:
		var c := Control.new()
		c.custom_minimum_size = Vector2(80, h)
		g.add_child(c)
	var wide := Control.new()
	wide.custom_minimum_size = Vector2(130, 10)
	g.add_child(wide)
	eq(g.cell_size(), Vector2(130, 90), "the largest card's minimum, at least the cell")
	g.size = Vector2(290, 0) # two columns of 130 + 10
	eq(g.get_minimum_size(), Vector2(130, 90 * 2 + 10), "two rows")
	g.free()
