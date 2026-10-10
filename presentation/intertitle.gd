## A 1920s intertitle card: black panel with an ornate double white frame.
extends Control

const FRAME := Color(0.92, 0.92, 0.9)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.03, 0.03, 0.03))
	draw_rect(r.grow(-5.0), FRAME, false, 2.0)
	draw_rect(r.grow(-10.0), FRAME, false, 1.0)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var inward: Vector2 = (r.get_center() - corner).sign() * 10.0
		draw_circle(corner + inward, 3.5, FRAME, true, -1.0, true)
		draw_circle(corner + inward * 1.7, 1.5, FRAME, true, -1.0, true)
