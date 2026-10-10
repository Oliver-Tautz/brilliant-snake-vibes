## The board floor: one rectangle drawn with the floor shader (no node or rect per cell).
extends Node2D

var size := Vector2.ZERO:
	set(value):
		size = value
		queue_redraw()


func _ready() -> void:
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("pattern", Art.floor_pattern)  # seed[0]
	mat.set_shader_parameter("contrast", Art.floor_contrast)  # seed[1]
	mat.set_shader_parameter("tone", Art.floor_tone)  # seed[24]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
