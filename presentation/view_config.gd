## Shared sizes for the board view.
extends RefCounted

const CELL := 24
static var BODY_WIDTH: float = CELL * Art.body_width  # seed[3]
static var INK_WIDTH: float = Art.ink_width  # seed[7]
static var ZOOM: float = Art.zoom  # seed[25]
const MIN_ZOOM := 0.6  # whole-arena view: cells never shrink below 14 px at the base resolution (spec §4)
const EAT_PULSE := 0.25  # seconds the head stays swollen after a gulp
const SHAKE_TIME := 0.35


static func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
