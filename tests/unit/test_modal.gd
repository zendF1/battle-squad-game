extends "res://tests/test_case.gd"
## ui/modal.gd: the optional close X in the card's top-right corner.

const Modal := preload("res://ui/modal.gd")


func _modal(host: Control) -> Modal:
	var m := Modal.new()
	m.open(host, "Mũ Rồng +3", 880)
	return m


func test_close_x_top_right() -> void:
	var host := Control.new()
	var m := _modal(host)
	check(m.close_x == null, "no X unless asked")
	var x := m.add_close_x()
	check(x != null and m.close_x == x, "the X")
	check(m.add_close_x() == x, "only one X")
	eq([x.anchor_left, x.anchor_right, x.anchor_top, x.anchor_bottom], [1.0, 1.0, 0.0, 0.0], "anchored to the top-right")
	var right_inset: float = Modal.PADDING - x.offset_right
	var top_inset: float = Modal.PADDING + x.offset_top
	near(right_inset, top_inset, 0.01, "the same inset from the top and the right")
	check(right_inset > 0.0 and right_inset < Modal.PADDING + 10, "in the corner")
	eq(Vector2(x.offset_right - x.offset_left, x.offset_bottom - x.offset_top), Vector2(Modal.CLOSE_SIZE, Modal.CLOSE_SIZE), "a square")
	var row_h := maxf(m.title.get_combined_minimum_size().y, Modal.CLOSE_SIZE * 0.8)
	near(x.offset_top + Modal.CLOSE_SIZE / 2.0, row_h / 2.0, 1.0, "on the title's row")
	check(x.icon != null, "an X icon")
	var normal := x.get_theme_stylebox("normal")
	check(normal is StyleBoxTexture, "the dialog buttons' rounded-square box, not a circle")
	var room = m.title.get_parent()
	check(room is MarginContainer, "the title sits in a margin")
	eq(room.get_theme_constant("margin_left"), room.get_theme_constant("margin_right"), "same room on both sides: centred")
	check(room.get_theme_constant("margin_right") >= Modal.CLOSE_SIZE - x.offset_right, "clear of the X")
	eq(m.title.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "centred")
	check(x.get_parent().get_parent() == m._card, "on the card")
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


static func _click(pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e


func test_backdrop_tap_closes() -> void:
	var host := Control.new()
	var m := _modal(host)
	m.backdrop.gui_input.emit(_click(true))
	m.backdrop.gui_input.emit(_click(false))
	check(not m.is_queued_for_deletion(), "no backdrop close without asking")
	m.add_close_x()
	eq(m.backdrop.mouse_filter, Control.MOUSE_FILTER_STOP, "the backdrop takes taps")
	eq(m._card.mouse_filter, Control.MOUSE_FILTER_STOP, "the card keeps taps inside it")
	check(not m._card.is_ancestor_of(m.backdrop) and not m.backdrop.is_ancestor_of(m._card), "card taps never bubble to the backdrop")
	eq(m._card.get_parent().mouse_filter, Control.MOUSE_FILTER_IGNORE, "the centring box lets outside taps through")
	# Inside the card: nothing closes.
	m._card.gui_input.emit(_click(true))
	m._card.gui_input.emit(_click(false))
	check(not m.is_queued_for_deletion(), "a tap inside the card keeps it open")
	# The release of the click that opened it (no press on the backdrop first) does nothing.
	m.backdrop.gui_input.emit(_click(false))
	check(not m.is_queued_for_deletion(), "not the click that opened it")
	# Busy: off.
	m.set_busy(true)
	m.backdrop.gui_input.emit(_click(true))
	m.backdrop.gui_input.emit(_click(false))
	check(not m.is_queued_for_deletion(), "not while a request runs")
	m.set_busy(false)
	m.backdrop.gui_input.emit(_click(true))
	m.backdrop.gui_input.emit(_click(false))
	check(m.is_queued_for_deletion(), "a tap outside closes it")
	host.free()


func test_backdrop_tap_cancels_confirmation() -> void:
	# A confirmation over a popup: the tap outside runs its Huỷ, the popup underneath stays.
	var host := Control.new()
	var popup := _modal(host)
	popup.add_close_x()
	var c := Modal.new()
	c.open(host, "Bán Mũ Rồng +3?", 760)
	var cancelled := [false]
	c.close_on_backdrop(func() -> void:
		cancelled[0] = true
		c.close())
	c.backdrop.gui_input.emit(_click(true))
	c.backdrop.gui_input.emit(_click(false))
	check(cancelled[0] and c.is_queued_for_deletion(), "the confirmation's Huỷ")
	check(not popup.is_queued_for_deletion(), "the popup underneath stays open")
	check(c.get_index() > popup.get_index(), "the confirmation is on top (takes the tap)")
	host.free()
