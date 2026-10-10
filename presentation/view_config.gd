## Shared sizes for the board view.
extends RefCounted

const CELL := 24
const BODY_WIDTH := CELL * 0.78
const INK_WIDTH := 3.0
const ZOOM := 1.7  # camera zoom; keeps the snake and prey readable on screen
const EAT_PULSE := 0.25  # seconds the head stays swollen after a gulp
const SHAKE_TIME := 0.35


static func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
