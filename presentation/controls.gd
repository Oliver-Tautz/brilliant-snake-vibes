## Input abstraction (spec §13): keyboard, swipe and the on-screen D-pad all become the same signals.
extends Node

signal turn(dir: Vector2i)
signal pause_pressed
signal perf_toggled
signal touch_seen  ## first touch on this device, so touch-only UI can appear

const SWIPE_MIN := 28.0  ## px in base resolution before a drag counts as a swipe

var _touch_index := -1
var _swipe_origin := Vector2.ZERO
var _touch_reported := false


## Routes the on-screen D-pad and pause button through this node, so every input scheme ends up
## in the same signals and the options menu has one place to switch schemes.
func attach(dpad: Control, pause_button: Control) -> void:
	dpad.direction_pressed.connect(turn.emit)
	pause_button.pressed.connect(pause_pressed.emit)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		handle_key(event.physical_keycode)
	elif event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func handle_key(keycode: Key) -> void:
	match keycode:
		KEY_UP, KEY_W:
			turn.emit(Vector2i.UP)
		KEY_DOWN, KEY_S:
			turn.emit(Vector2i.DOWN)
		KEY_LEFT, KEY_A:
			turn.emit(Vector2i.LEFT)
		KEY_RIGHT, KEY_D:
			turn.emit(Vector2i.RIGHT)
		KEY_ESCAPE, KEY_P:
			pause_pressed.emit()
		KEY_F3:
			perf_toggled.emit()


## A swipe turns as soon as the finger has moved far enough, then measures again from there, so one
## zig-zag gesture can queue several turns. The newest finger is the one tracked, so a thumb resting
## on the screen does not block swipes with the other hand. Menus are buttons, so taps mean nothing here.
func _on_touch(event: InputEventScreenTouch) -> void:
	if not _touch_reported:
		_touch_reported = true
		touch_seen.emit()
	if event.pressed:
		_touch_index = event.index
		_swipe_origin = event.position
	elif event.index == _touch_index:
		_touch_index = -1


func _on_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	var moved := event.position - _swipe_origin
	if moved.length() < SWIPE_MIN:
		return
	if absf(moved.x) > absf(moved.y):
		turn.emit(Vector2i(signi(int(moved.x)), 0))
	else:
		turn.emit(Vector2i(0, signi(int(moved.y))))
	_swipe_origin = event.position
