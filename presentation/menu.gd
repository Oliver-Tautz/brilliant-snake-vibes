## A menu as a 1920s intertitle card: a heading and a column of buttons (spec §2, §11 UI, §12).
## Buttons work with mouse, touch (any finger) and keyboard focus.
extends "res://presentation/intertitle.gd"


## A button any finger can press, not only the first one (which Godot also turns into a mouse click),
## so a thumb still resting on the screen does not block the menu.
## While a finger is down it shows the pressed (white) look, as a click would.
class TouchButton extends Button:
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			accept_event()
			_show_held(event.pressed)
			if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
			accept_event()  # the same touch again, as a click

	func _show_held(held: bool) -> void:
		if held:
			add_theme_stylebox_override("normal", get_theme_stylebox("pressed"))
			add_theme_color_override("font_color", get_theme_color("font_pressed_color"))
		else:
			remove_theme_stylebox_override("normal")
			remove_theme_color_override("font_color")

const SERIF := preload("res://presentation/fonts/OldStandard-Regular.ttf")
const PADDING := 34.0
const ROW_GAP := 10

var _heading := Label.new()
var _body := Label.new()  # optional smaller text under the heading, e.g. the highscore table
var _list := VBoxContainer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _make_theme()
	_list.add_theme_constant_override("separation", ROW_GAP)
	_list.position = Vector2(PADDING, PADDING)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_size_override("font_size", 30)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 19)
	_list.add_child(_heading)
	_list.add_child(_body)
	add_child(_list)


## Shows a page: a heading, optional body text and one button per [text, callable] item. `focus` is
## the button that gets keyboard focus, so a page rebuilt after a change keeps its place.
func show_page(heading: String, items: Array, focus := 0, text := "") -> void:
	_heading.text = heading
	_body.text = text
	_body.visible = text != ""
	for button in buttons():
		_list.remove_child(button)
		button.queue_free()
	for item in items:
		var button := TouchButton.new()
		button.text = item[0]
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(item[1])
		_list.add_child(button)
	_list.reset_size()
	custom_minimum_size = _list.get_combined_minimum_size() + Vector2.ONE * PADDING * 2.0
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_list.size.x = custom_minimum_size.x - PADDING * 2.0
	show()
	queue_redraw()
	var shown := buttons()
	if not shown.is_empty():
		shown[clampi(focus, 0, shown.size() - 1)].grab_focus()


func focused_index() -> int:
	var shown := buttons()
	for i in shown.size():
		if shown[i].has_focus():
			return i
	return 0


func heading() -> String:
	return _heading.text


func body() -> String:
	return _body.text


func buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child in _list.get_children():
		if child is Button:
			found.append(child)
	return found


## Presses the button with this text, as a click would. For tests and tools.
func press(text: String) -> void:
	for button in buttons():
		if button.text == text:
			button.pressed.emit()
			return
	push_error("no menu button '%s'" % text)


## Black keys with white serif text; the focused or hovered key gets a white frame, a pressed key
## turns white. Black and white only (spec §11).
static func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = SERIF
	t.default_font_size = 26
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.03, 0.03, 0.03)
	normal.content_margin_left = 28.0
	normal.content_margin_right = 28.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var lit := normal.duplicate() as StyleBoxFlat
	lit.border_color = FRAME
	lit.set_border_width_all(2)
	var focus := lit.duplicate() as StyleBoxFlat
	focus.draw_center = false  # drawn over the other states
	var down := normal.duplicate() as StyleBoxFlat
	down.bg_color = FRAME
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", lit)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", down)
	t.set_stylebox("hover_pressed", "Button", down)
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(state, "Button", FRAME)
	t.set_color("font_pressed_color", "Button", Color(0.03, 0.03, 0.03))
	t.set_color("font_hover_pressed_color", "Button", Color(0.03, 0.03, 0.03))
	t.set_color("font_color", "Label", FRAME)
	return t
