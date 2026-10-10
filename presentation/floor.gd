## The board floor: one rectangle drawn with the floor shader (no node or rect per cell).
extends Node2D

var size := Vector2.ZERO:
	set(value):
		size = value
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
