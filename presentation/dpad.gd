## On-screen D-pad for touch screens, drawn as four intertitle-style keys around a hub.
extends Control

signal direction_pressed(dir: Vector2i)

const FRAME := Color(0.92, 0.92, 0.9)
const PANEL := Color(0.03, 0.03, 0.03, 0.8)
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var _lit := Vector2i.ZERO  # the key currently held, drawn highlighted


## Any finger presses a key directly (not only the first one, which Godot also turns into a mouse
## click), and real mouse clicks work on desktop. Touches are swallowed here so they do not also
## count as a swipe or tap on the board.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		accept_event()
		_press(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_press(event.position, event.pressed)


func _press(point: Vector2, down: bool) -> void:
	_lit = direction_at(point) if down else Vector2i.ZERO
	if _lit != Vector2i.ZERO:
		direction_pressed.emit(_lit)
	queue_redraw()


## Which arm of the cross a point hits, or ZERO for the hub.
func direction_at(point: Vector2) -> Vector2i:
	var d := point - size / 2.0
	if d.length() < size.x * 0.14:
		return Vector2i.ZERO
	if absf(d.x) > absf(d.y):
		return Vector2i(signi(int(d.x)), 0)
	return Vector2i(0, signi(int(d.y)))


func _draw() -> void:
	var key := size / 3.0
	for dir in DIRS:
		var rect := Rect2(key * (Vector2(dir) + Vector2.ONE), key).grow(-3.0)
		draw_rect(rect, FRAME if dir == _lit else PANEL)
		draw_rect(rect.grow(-3.0), FRAME, false, 2.0)
		var c := rect.get_center()
		var tip := c + Vector2(dir) * key.x * 0.25
		var side := Vector2(dir).orthogonal() * key.x * 0.2
		var back := c - Vector2(dir) * key.x * 0.12
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]),
				PANEL if dir == _lit else FRAME)
