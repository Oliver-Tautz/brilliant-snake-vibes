## A 1920s intertitle card: black panel with an ornate double white frame. The corner ornament
## style comes from the divine_inspiration seed (seed[21]).
extends Control

const FRAME := Color(0.92, 0.92, 0.9)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.03, 0.03, 0.03))
	draw_rect(r.grow(-5.0), FRAME, false, 2.0)
	draw_rect(r.grow(-10.0), FRAME, false, 1.0)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var inward: Vector2 = (r.get_center() - corner).sign() * 10.0
		match Art.ornament:
			Art.OrnamentStyle.DOTS:
				draw_circle(corner + inward, 3.5, FRAME, true, -1.0, true)
				draw_circle(corner + inward * 1.7, 1.5, FRAME, true, -1.0, true)
			Art.OrnamentStyle.DIAMONDS:
				Ink.diamond(self, corner + inward, Vector2(4.0, 6.0), FRAME)
				Ink.diamond(self, corner + inward * 1.9, Vector2(2.0, 3.0), FRAME)
			Art.OrnamentStyle.SCROLLS:
				var start: float = (corner - r.get_center()).angle() + PI * 0.75
				draw_arc(corner + inward * 1.4, 6.0, start, start + PI * 1.5, 12, FRAME, 1.5, true)
	if Art.ornament == Art.OrnamentStyle.DIAMONDS:  # a centre jewel on the top and bottom rules
		Ink.diamond(self, Vector2(r.get_center().x, 5.0), Vector2(7.0, 4.0), FRAME)
		Ink.diamond(self, Vector2(r.get_center().x, r.end.y - 5.0), Vector2(7.0, 4.0), FRAME)
