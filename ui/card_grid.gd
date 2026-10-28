extends Container
## A real grid of cards: every card the same size (the largest card's minimum, at least `cell`),
## the same number of columns in every row (as many as the width fits), the rows aligned and the
## whole block centred horizontally, with `pad` above the first row and below the last one so
## inside a ScrollContainer the first row starts clear of what is above and the last row is fully
## reachable. Its minimum height follows its width (it asks for a new one when resized).

## The smallest cell; each axis grows to the largest child's minimum.
var cell := Vector2.ZERO:
	set(v):
		cell = v
		queue_sort()
		update_minimum_size()
## The space between cells, both ways.
var gap := 14:
	set(v):
		gap = v
		queue_sort()
		update_minimum_size()
## The space above the first row and below the last one.
var pad := 8:
	set(v):
		pad = v
		queue_sort()
		update_minimum_size()


## How many cells of width `cell_w` with `gap` between them fit in `width` (at least one).
static func columns_for(width: float, cell_w: float, gap_px: float) -> int:
	if cell_w <= 0.0:
		return 1
	return maxi(1, int(floor((width + gap_px) / (cell_w + gap_px))))


## The rect of each of `count` cells of `cell_size` laid in `width`: `columns_for()` columns, the
## block centred (a single short row centred on its own cards), rows from `top_pad` down.
static func layout(count: int, width: float, cell_size: Vector2, gap_px: float, top_pad: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cols := columns_for(width, cell_size.x, gap_px)
	var shown := clampi(count, 1, cols)
	var used := shown * cell_size.x + (shown - 1) * gap_px
	var left := maxf((width - used) / 2.0, 0.0)
	for i in count:
		var c := i % cols
		var r := i / cols
		out.append(Rect2(Vector2(left + c * (cell_size.x + gap_px), top_pad + r * (cell_size.y + gap_px)), cell_size))
	return out


## The height `count` cells need in `width`, with `pad` above and below.
static func height_for(count: int, width: float, cell_size: Vector2, gap_px: float, pad_px: float) -> float:
	if count <= 0:
		return pad_px * 2.0
	var cols := columns_for(width, cell_size.x, gap_px)
	var rows := int(ceil(float(count) / cols))
	return pad_px * 2.0 + rows * cell_size.y + (rows - 1) * gap_px


func _cards() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		if c is Control and c.visible and not c.is_queued_for_deletion() and not c.top_level:
			out.append(c)
	return out


## The cell every card gets: `cell`, grown to the largest card's minimum.
func cell_size() -> Vector2:
	var s := cell
	for c in _cards():
		s = s.max(c.get_combined_minimum_size())
	return s


func _get_minimum_size() -> Vector2:
	var cards := _cards()
	var s := cell_size()
	return Vector2(s.x, height_for(cards.size(), size.x, s, gap, pad))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN:
			var cards := _cards()
			var rects := layout(cards.size(), size.x, cell_size(), gap, pad)
			for i in cards.size():
				fit_child_in_rect(cards[i], rects[i])
		NOTIFICATION_RESIZED:
			update_minimum_size()
