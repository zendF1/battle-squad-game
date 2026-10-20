extends "res://tests/test_case.gd"
## ui/modal.gd: the optional close X in the card's top-left corner.

const Modal := preload("res://ui/modal.gd")


func _modal(host: Control) -> Modal:
	var m := Modal.new()
	m.open(host, "Mũ Rồng +3", 880)
	return m


func test_close_x_top_left() -> void:
	var host := Control.new()
	var m := _modal(host)
	check(m.close_x == null, "no X unless asked")
	var x := m.add_close_x()
	check(x != null and m.close_x == x, "the X")
	check(m.add_close_x() == x, "only one X")
	eq(x.position, Vector2(Modal.CLOSE_INSET - Modal.PADDING, Modal.CLOSE_INSET - Modal.PADDING), "in the card's top-left corner")
	eq(x.size, Vector2(Modal.CLOSE_SIZE, Modal.CLOSE_SIZE), "round, its size")
	eq(x.get_meta("icon_name", ""), "close", "an X icon")
	check(x.get_parent().get_parent() == m.title.get_parent().get_parent(), "on the card")
	eq((x.get_parent() as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "its layer lets clicks through")
	m.add_button("Tháo", func(): pass)
	check(not m.buttons().has(x), "not one of the row buttons")
	m.set_busy(true)
	check(x.disabled, "off while a request runs")
	m.set_busy(false)
	check(not x.disabled, "on again")
	x.pressed.emit()
	check(m.is_queued_for_deletion(), "the X closes the dialog")
	host.free()


func test_close_x_callback() -> void:
	var host := Control.new()
	var m := _modal(host)
	var closed := [false]
	var x := m.add_close_x(func(): closed[0] = true)
	x.pressed.emit()
	check(closed[0], "the given close action runs")
	check(not m.is_queued_for_deletion(), "instead of close()")
	host.free()
