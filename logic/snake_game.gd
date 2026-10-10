## Pure snake rules: no nodes, no scenes. Drive it by calling tick().
class_name SnakeGame
extends RefCounted

const Cfg := preload("res://logic/game_config.gd")

var width: int
var height: int
var body: Array[Vector2i] = []  # head first
var direction := Vector2i.RIGHT
var food := Vector2i(-1, -1)
var lives: int = Cfg.LIVES
var score := 0
var foods_eaten := 0
var invulnerable_time := 0.0  # seconds left
var game_over := false

var _pending: Array[Vector2i] = []
var _occupied := PackedInt32Array()  # snake segments per cell, width * height
var _rng := RandomNumberGenerator.new()


func _init(w: int, h: int, rng_seed: int = 0) -> void:
	width = w
	height = h
	_rng.seed = rng_seed
	_occupied.resize(w * h)
	_place_snake(Cfg.START_LENGTH)
	_spawn_food()


## Replaces the snake (head first) and rebuilds the occupancy grid.
func set_body(cells: Array) -> void:
	body.assign(cells)
	_occupied.fill(0)
	for cell in body:
		assert(_in_bounds(cell), "set_body: cell out of bounds")
		_occupied[_index(cell)] += 1


## Queues a turn. Returns false if it is a no-op, a reversal, or the buffer is full.
func request_turn(dir: Vector2i) -> bool:
	if absi(dir.x) + absi(dir.y) != 1:
		return false
	var last: Vector2i = _pending.back() if not _pending.is_empty() else direction
	if dir == last or dir == -last or _pending.size() >= Cfg.INPUT_BUFFER:
		return false
	_pending.append(dir)
	return true


func tick() -> void:
	if game_over:
		return
	if not _pending.is_empty():
		direction = _pending.pop_front()
	var invulnerable := invulnerable_time > 0.0
	if invulnerable:
		invulnerable_time -= tick_interval()
	var new_head := body[0] + direction
	if not _in_bounds(new_head):
		if not invulnerable:
			_lose_life()
		return
	var eats := new_head == food
	# The tail cell is vacated this tick, so moving into it is safe unless we grow.
	var allowed := 1 if (not eats and new_head == body.back()) else 0
	if not invulnerable and _occupied[_index(new_head)] > allowed:
		_lose_life()
		return
	body.push_front(new_head)
	_occupied[_index(new_head)] += 1
	if eats:
		foods_eaten += 1
		score += Cfg.FOOD_SCORE
		_spawn_food()
	else:
		_occupied[_index(body.pop_back())] -= 1


## Seconds between ticks; shrinks as food is eaten, down to a floor.
func tick_interval() -> float:
	return maxf(Cfg.MIN_INTERVAL, Cfg.BASE_INTERVAL - foods_eaten * Cfg.INTERVAL_DECAY)


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func _lose_life() -> void:
	lives -= 1
	if lives <= 0:
		game_over = true
		return
	_place_snake(mini(body.size(), maxi(Cfg.MIN_LENGTH, body.size() / 2)))
	invulnerable_time = Cfg.INVULNERABLE_SECONDS
	if food == Vector2i(-1, -1) or _occupied[_index(food)] > 0:
		_spawn_food()


## Lays the snake out horizontally ending at the grid centre, heading right.
func _place_snake(length: int) -> void:
	direction = Vector2i.RIGHT
	_pending.clear()
	var cells: Array[Vector2i] = []
	var head := Vector2i(width / 2, height / 2)
	for i in length:
		var cell := head - Vector2i(i, 0)
		if cell.x < 0:
			break
		cells.append(cell)
	set_body(cells)


func _spawn_food() -> void:
	for _i in 100:
		var cell := Vector2i(_rng.randi_range(0, width - 1), _rng.randi_range(0, height - 1))
		if _occupied[_index(cell)] == 0:
			food = cell
			return
	for i in _occupied.size():
		if _occupied[i] == 0:
			food = Vector2i(i % width, i / width)
			return
	food = Vector2i(-1, -1)
