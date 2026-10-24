## One enemy snake (spec §6b): its body and its own move clock. SnakeGame moves it and decides its
## turns, since that needs the shared grids.
extends RefCounted

enum Species { ANACONDA, COBRA, MAMBA }  ## green and slow, purple and faster, black and fast

var species: int
var body: Array[Vector2i] = []  # head first
var direction := Vector2i.RIGHT
var interval := 0.3  ## seconds per move
var clock := 0.0  ## seconds into the current move, for smooth drawing
var alive := true
var grow := 0  ## moves left that keep the tail
# For smooth rendering, like the player's: did the last move happen, and which tail cell did it free?
var last_moved := false
var tail_vacated := Vector2i(-1, -1)


func _init(kind: int, cells: Array[Vector2i], heading: Vector2i, seconds_per_move: float) -> void:
	species = kind
	body = cells
	direction = heading
	interval = seconds_per_move


## True just after a step, until the head is drawn halfway into its new cell: it still looks a cell back.
func head_drawn_behind() -> bool:
	return last_moved and clock < interval * 0.5
