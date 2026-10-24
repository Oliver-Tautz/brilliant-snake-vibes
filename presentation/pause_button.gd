## Always-visible pause button (spec §3, §12): a small intertitle card with two bars.
extends "res://presentation/intertitle.gd"

signal pressed


## Any finger works; real mouse clicks too, but not the click Godot emulates from the first finger.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		accept_event()
		if event.pressed:
			pressed.emit()
	elif event is InputEventScreenDrag:
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
			pressed.emit()


func _draw() -> void:
	super()
	var c := size / 2.0
	var bar := Vector2(size.x * 0.12, size.y * 0.4)
	draw_rect(Rect2(c + Vector2(-bar.x * 1.6, -bar.y / 2.0), bar), FRAME)
	draw_rect(Rect2(c + Vector2(bar.x * 0.6, -bar.y / 2.0), bar), FRAME)
