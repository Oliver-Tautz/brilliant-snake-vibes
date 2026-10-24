## Pure snake rules: no nodes, no scenes. Drive the player with tick() and everything on its own clock
## (enemy snakes, chicken refill and hops, the level timer) with advance(delta).
## A game made with new() is free play without enemies; start_level() sets up a real level.
class_name SnakeGame
extends RefCounted

const Cfg := preload("res://logic/game_config.gd")
const Enemy := preload("res://logic/enemy_snake.gd")
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

## What sits on a food cell. Dead enemies leave chickens in their colour (spec §6b).
enum Food { NONE, CHICKEN, BIG, GREEN, PURPLE, BLACK }

var width: int
var height: int
var body: Array[Vector2i] = []  # head first
var direction := Vector2i.RIGHT
var foods: Array[Vector2i] = []
var lives: int = Cfg.LIVES
var score := 0
var foods_eaten := 0  # this level; sets the player's speed
var invulnerable_time := 0.0  # seconds left
var game_over := false
var level := 0  # 0: free play
var level_time := 0.0  # seconds since the level started
var level_won := false
var enemies: Array = []  # Enemy
## Chickens about to hop or hopping: {cell, dir, steps, windup, slide}. `cell` is where the chicken
## is now; while `slide` > 0 it is still drawn coming from cell - dir.
var hops: Array[Dictionary] = []
# For smooth rendering: did the last tick move the snake, and which tail cell did it vacate?
var last_tick_moved := false
var tail_vacated := Vector2i(-1, -1)
# Events for effects. last_* cover the last tick() or advance() call; enemy_deaths collects the head
# cells of enemies that died until the caller clears it.
var last_eaten := Vector2i(-1, -1)
var last_eaten_kind := 0  # Food of last_eaten, so the gulp can still draw it in its colour
var last_life_lost := false
var last_crash := Vector2i.ZERO  # the cell the head tried to enter when a life was lost
var last_time_up := false
var last_hop := Vector2i(-1, -1)  # a chicken that started winding up a hop in the last advance()
var enemy_deaths: Array[Vector2i] = []

var _pending: Array[Vector2i] = []
var _grow := 0  # ticks left that keep the tail
var _occupied := PackedInt32Array()  # player segments per cell, width * height
var _enemy_cells := PackedInt32Array()  # enemy segments per cell
var _food_cells := PackedByteArray()  # Food per cell
var _food_target := 1
var _refill := 0.0
var _seen := PackedInt32Array()  # flood fill marks, compared with _stamp
var _stamp := 0
var _queue := PackedInt32Array()
var _rng := RandomNumberGenerator.new()


func _init(w: int, h: int, rng_seed: int = 0) -> void:
	_rng.seed = rng_seed
	_queue.resize(Cfg.FLOOD_CAP + 8)
	_reset_arena(w, h)
	_place_snake(Cfg.START_LENGTH)
	_fill_chickens()


## Arena size for a level: 10% smaller each level, down to a minimum (spec §5).
static func arena_size(n: int) -> Vector2i:
	var f := pow(Cfg.ARENA_SHRINK, n - 1)
	return Vector2i(maxi(Cfg.MIN_ARENA.x, roundi(Cfg.ARENA.x * f)), maxi(Cfg.MIN_ARENA.y, roundi(Cfg.ARENA.y * f)))


## Sets up level n: its arena, the player at the start length and speed, three enemies, chickens and
## the clock. Score and lives carry over.
func start_level(n: int) -> void:
	level = n
	level_time = 0.0
	level_won = false
	var size := arena_size(n)
	_reset_arena(size.x, size.y)
	foods_eaten = 0
	invulnerable_time = 0.0
	_grow = 0
	_place_snake(Cfg.START_LENGTH)
	var length := Cfg.ENEMY_START_LENGTH
	var speed := pow(Cfg.ENEMY_SPEEDUP, n - 1)
	var spots: Array[Vector2i] = [Vector2i(width / 5 + length, height / 5), Vector2i(width * 4 / 5 - length, height * 4 / 5),
			Vector2i(width * 4 / 5 - length, height / 5 + 2)]
	var headings: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.LEFT]
	for kind in 3:
		var cells: Array[Vector2i] = []
		for i in length:
			cells.append(spots[kind] - headings[kind] * i)
		var interval := maxf(Cfg.MIN_INTERVAL, Cfg.ENEMY_INTERVAL[kind] * speed)
		var enemy := Enemy.new(kind, cells, headings[kind], interval)
		for cell in cells:
			_enemy_cells[_index(cell)] += 1
		enemies.append(enemy)
	_fill_chickens()


## Replaces the snake (head first) and rebuilds the occupancy grid.
func set_body(cells: Array) -> void:
	body.assign(cells)
	_occupied.fill(0)
	for cell in body:
		assert(_in_bounds(cell), "set_body: cell out of bounds")
		_occupied[_index(cell)] += 1


## Replaces all food items with plain chickens (used by tests and scripted setups).
func set_food(cells: Array, kind := Food.CHICKEN) -> void:
	_food_cells.fill(0)
	foods.assign(cells)
	hops.clear()
	for cell in foods:
		assert(_food_cells[_index(cell)] == 0, "set_food: duplicate cell")
		_food_cells[_index(cell)] = kind


func food_at(cell: Vector2i) -> int:
	return _food_cells[_index(cell)] if _in_bounds(cell) else Food.NONE


## Points for something worth `base` on this level (spec §8).
func points(base: int) -> int:
	return base + roundi(level * Cfg.LEVEL_BONUS * base)


## What killing an enemy is worth right now: it loses 1 per decay step since the level started.
func enemy_points() -> int:
	return maxi(Cfg.ENEMY_MIN_POINTS, points(Cfg.ENEMY_POINTS) - int(level_time / Cfg.ENEMY_DECAY_SECONDS))


func enemies_alive() -> int:
	var count := 0
	for enemy in enemies:
		count += int(enemy.alive)
	return count


func time_left() -> float:
	return maxf(0.0, Cfg.LEVEL_SECONDS - level_time)


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
	last_tick_moved = false
	tail_vacated = Vector2i(-1, -1)
	last_eaten = Vector2i(-1, -1)
	last_life_lost = false
	if game_over or level_won:
		return
	if not _pending.is_empty():
		direction = _pending.pop_front()
	var invulnerable := invulnerable_time > 0.0
	if invulnerable:
		invulnerable_time -= tick_interval()
	var new_head := body[0] + direction
	if not _in_bounds(new_head):
		if not invulnerable:
			last_crash = new_head
			_lose_life()
		return
	var foe = _enemy_bitten(new_head)
	if foe != null:
		# Biting the head from the side always kills it. Only when the heads meet head-on does the
		# longer snake win (a tie goes to the player).
		var head_on: bool = foe.body[0] == new_head and foe.direction == -direction
		if not head_on or body.size() >= foe.body.size():
			_kill_enemy(foe)
			if level_won:
				return
		elif not invulnerable:
			last_crash = new_head
			_lose_life()
			return
		else:
			return
	var i := _index(new_head)
	var kind := _food_cells[i]
	# The tail cell is vacated this tick, so moving into it is safe unless we grow.
	var allowed := 1 if (kind == Food.NONE and _grow == 0 and new_head == body.back()) else 0
	if not invulnerable and (_occupied[i] > allowed or _enemy_cells[i] > 0):
		last_crash = new_head
		_lose_life()
		return
	body.push_front(new_head)
	_occupied[i] += 1
	last_tick_moved = true
	if kind != Food.NONE:
		foods_eaten += 1
		last_eaten = new_head
		last_eaten_kind = kind
		_grow += _eat(new_head)
		score += points(Cfg.BIG_POINTS if kind == Food.BIG else Cfg.CHICKEN_POINTS)
	if _grow > 0:
		_grow -= 1
	else:
		tail_vacated = body.pop_back()
		_occupied[_index(tail_vacated)] -= 1


## Everything that runs on its own clock: enemy moves, chicken hops and refills, the level timer.
func advance(delta: float) -> void:
	last_life_lost = false
	last_time_up = false
	last_hop = Vector2i(-1, -1)
	if game_over or level_won:
		return
	for enemy in enemies:
		if not enemy.alive:
			continue
		enemy.clock += delta
		var steps := 0
		while enemy.clock >= enemy.interval and enemy.alive and steps < 5:
			enemy.clock -= enemy.interval
			_step_enemy(enemy)
			steps += 1
			if game_over or level_won:
				return
		enemy.clock = minf(enemy.clock, enemy.interval)
	_advance_hops(delta)
	if foods.size() < _food_target:
		_refill += delta
		if _refill >= Cfg.REFILL_DELAY:
			_refill = 0.0
			_spawn_food()
	else:
		_refill = 0.0
	if level > 0:
		level_time += delta
		if level_time >= Cfg.LEVEL_SECONDS:  # costs a life and restarts the level, score kept
			last_time_up = true
			last_life_lost = true
			last_crash = body[0]
			lives -= 1
			if lives <= 0:
				game_over = true
			else:
				start_level(level)


## Seconds between ticks; shrinks as food is eaten, down to a floor.
func tick_interval() -> float:
	return maxf(Cfg.MIN_INTERVAL, Cfg.BASE_INTERVAL - foods_eaten * Cfg.INTERVAL_DECAY)


func _reset_arena(w: int, h: int) -> void:
	width = w
	height = h
	_occupied.resize(w * h)  # packed arrays are values, so each is resized by name
	_occupied.fill(0)
	_enemy_cells.resize(w * h)
	_enemy_cells.fill(0)
	_seen.resize(w * h)
	_seen.fill(0)
	_stamp = 0
	_food_cells.resize(w * h)
	_food_cells.fill(0)
	foods.clear()
	hops.clear()
	enemies.clear()
	_food_target = maxi(1, w * h / Cfg.CELLS_PER_FOOD)
	_refill = 0.0


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## Removes the food at `cell` and returns how much it makes a snake grow.
func _eat(cell: Vector2i) -> int:
	var kind := _food_cells[_index(cell)]
	_food_cells[_index(cell)] = Food.NONE
	foods.erase(cell)
	return Cfg.BIG_GROWTH if kind == Food.BIG else 1


func _lose_life() -> void:
	lives -= 1
	last_life_lost = true
	if lives <= 0:
		game_over = true
		return
	_place_snake(mini(body.size(), maxi(Cfg.MIN_LENGTH, body.size() / 2)))
	_grow = 0
	invulnerable_time = Cfg.INVULNERABLE_SECONDS
	_relocate_foods_under_snake()


## Lays the snake out horizontally ending at the grid centre, heading right. Rows above and below are
## tried in turn when an enemy is in the way.
func _place_snake(length: int) -> void:
	direction = Vector2i.RIGHT
	_pending.clear()
	last_tick_moved = false  # a fresh snake does not slide in from where the old one was
	tail_vacated = Vector2i(-1, -1)
	var head := Vector2i(width / 2, height / 2)
	for k in height:
		var row := height / 2 + (k + 1) / 2 * (1 if k % 2 == 1 else -1)
		if row < 0 or row >= height:
			continue
		if _row_is_free(Vector2i(head.x, row), length):
			head.y = row
			break
	var cells: Array[Vector2i] = []
	for i in length:
		var cell := head - Vector2i(i, 0)
		if cell.x < 0:
			break
		cells.append(cell)
	set_body(cells)


func _row_is_free(head: Vector2i, length: int) -> bool:
	for i in mini(length, head.x + 1):
		if _enemy_cells[_index(head - Vector2i(i, 0))] > 0:
			return false
	return true


func _relocate_foods_under_snake() -> void:
	var kept: Array[Vector2i] = []
	var moved := 0
	for cell in foods:
		if _occupied[_index(cell)] > 0:
			_food_cells[_index(cell)] = Food.NONE
			moved += 1
		else:
			kept.append(cell)
	foods = kept
	for _i in moved:
		_spawn_food()


func _fill_chickens() -> void:
	for _i in _food_target:
		_spawn_food()


func _is_free(cell: Vector2i) -> bool:
	var i := _index(cell)
	return _occupied[i] == 0 and _enemy_cells[i] == 0 and _food_cells[i] == Food.NONE


## Adds one chicken (sometimes a big one) on a free cell. Does nothing when the board is full.
func _spawn_food() -> void:
	var kind := Food.BIG if _rng.randf() < Cfg.BIG_CHANCE else Food.CHICKEN
	for _i in 100:
		var cell := Vector2i(_rng.randi_range(0, width - 1), _rng.randi_range(0, height - 1))
		if _is_free(cell):
			_add_food(cell, kind)
			return
	for i in _occupied.size():
		if _is_free(Vector2i(i % width, i / width)):
			_add_food(Vector2i(i % width, i / width), kind)
			return


func _add_food(cell: Vector2i, kind := Food.CHICKEN) -> void:
	foods.append(cell)
	_food_cells[_index(cell)] = kind


## Now and then a chicken crouches, shakes, then hops 1 to 2 cells into free cells (spec §6).
func _advance_hops(delta: float) -> void:
	if hops.size() < Cfg.MAX_HOPS and not foods.is_empty() and _rng.randf() < Cfg.HOP_RATE * delta:
		var cell := foods[_rng.randi_range(0, foods.size() - 1)]
		var dir := DIRS[_rng.randi_range(0, 3)]
		if hop_at(cell) < 0 and _in_bounds(cell + dir) and _is_free(cell + dir):
			last_hop = cell
			hops.append({"cell": cell, "dir": dir, "steps": _rng.randi_range(1, 2), "windup": Cfg.HOP_WINDUP,
					"slide": 0.0})
	_step_hops(delta)


func _step_hops(delta: float) -> void:
	for k in range(hops.size() - 1, -1, -1):
		var hop := hops[k]
		if _food_cells[_index(hop.cell)] == Food.NONE:  # eaten mid-hop
			hops.remove_at(k)
		elif hop.windup > 0.0:
			hop.windup -= delta
		elif hop.slide > 0.0:
			hop.slide -= delta
		elif hop.steps <= 0:
			hops.remove_at(k)
		else:
			var to: Vector2i = hop.cell + hop.dir
			if not _in_bounds(to) or not _is_free(to):
				hops.remove_at(k)
				continue
			_food_cells[_index(to)] = _food_cells[_index(hop.cell)]
			_food_cells[_index(hop.cell)] = Food.NONE
			foods[foods.find(hop.cell)] = to
			hop.cell = to
			hop.steps -= 1
			hop.slide = Cfg.HOP_STEP


## Index into hops of the chicken at `cell`, or -1.
func hop_at(cell: Vector2i) -> int:
	for k in hops.size():
		if hops[k].cell == cell:
			return k
	return -1


## The enemy whose head is at `cell`, or whose head was there a move or two ago (BITE_CELLS): fast
## enemies move up to twice between the player's steps, so a bite aimed at the head still counts.
func _enemy_bitten(cell: Vector2i):
	var foe = _enemy_with_head(cell)
	if foe != null:
		return foe
	for enemy in enemies:
		if enemy.alive:
			for k in range(1, mini(Cfg.BITE_CELLS, enemy.body.size())):
				if enemy.body[k] == cell:
					return enemy
	return null


func _enemy_with_head(cell: Vector2i):
	for enemy in enemies:
		if enemy.alive and enemy.body[0] == cell:
			return enemy
	return null


func _step_enemy(enemy) -> void:
	enemy.last_moved = false
	enemy.tail_vacated = Vector2i(-1, -1)
	var dir := _choose_dir(enemy)
	if dir == Vector2i.ZERO:  # no free move
		_kill_enemy(enemy)
		return
	_move_enemy(enemy, dir)


## Moves an enemy one cell and applies the contact rules (spec §6b). The AI never picks a deadly move
## on purpose; the side-bite branch below is the rule for when one happens anyway.
func _move_enemy(enemy, dir: Vector2i) -> void:
	var target: Vector2i = enemy.body[0] + dir
	if target == body[0]:  # face to face the longer snake wins (a tie goes to the player); from the side it dies
		if invulnerable_time > 0.0:
			return
		if dir == -direction and enemy.body.size() > body.size():
			last_crash = target
			_lose_life()
		else:
			_kill_enemy(enemy)
		return
	if _occupied[_index(target)] > 0:  # into the player's body
		_kill_enemy(enemy)
		return
	enemy.direction = dir
	if _food_cells[_index(target)] != Food.NONE:
		enemy.grow += _eat(target)
	enemy.body.push_front(target)
	_enemy_cells[_index(target)] += 1
	if enemy.grow > 0:
		enemy.grow -= 1
	else:
		enemy.tail_vacated = enemy.body.pop_back()
		_enemy_cells[_index(enemy.tail_vacated)] -= 1
	enemy.last_moved = true


## Semi-intelligent and cheap (spec §6b): score the three moves by distance to the nearest chicken,
## room to move (a capped flood fill) and, when shorter than the player, distance from its head.
## Returns ZERO when every move is blocked.
func _choose_dir(enemy) -> Vector2i:
	var head: Vector2i = enemy.body[0]
	var goal := _nearest_food(head)
	var shorter: bool = enemy.body.size() <= body.size()
	var best := Vector2i.ZERO
	var best_score := -INF
	for dir in DIRS:
		if dir == -enemy.direction:
			continue
		var cell := head + dir
		if not _in_bounds(cell) or _enemy_cells[_index(cell)] > 0:
			continue
		var bite := cell == body[0] and dir == -direction  # it only lunges face to face
		if (_occupied[_index(cell)] > 0 and not bite) or (bite and shorter):
			continue
		var value := _rng.randf() * 1.5
		if bite:
			value += 1000.0
		if goal.x >= 0:
			value -= 2.0 * (absi(goal.x - cell.x) + absi(goal.y - cell.y))
		var room := _flood(cell)
		if room < mini(Cfg.FLOOD_CAP, enemy.body.size()):
			value -= 500.0 - room
		var near := absi(body[0].x - cell.x) + absi(body[0].y - cell.y)
		if shorter and near < Cfg.FLEE_RANGE:
			value += near * Cfg.ENEMY_FLEE[enemy.species]
		if value > best_score:
			best_score = value
			best = dir
	return best


func _nearest_food(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cell in foods:
		var d := absi(cell.x - from.x) + absi(cell.y - from.y)
		if d < best_d:
			best_d = d
			best = cell
	return best


## Free cells reachable from `start`, counted up to FLOOD_CAP. Reuses its buffers, so it never allocates.
func _flood(start: Vector2i) -> int:
	_stamp += 1
	var head := 0
	var tail := 0
	_queue[tail] = _index(start)
	tail += 1
	_seen[_index(start)] = _stamp
	while head < tail and tail < Cfg.FLOOD_CAP:
		var i := _queue[head]
		head += 1
		var cell := Vector2i(i % width, i / width)
		for dir in DIRS:
			var next := cell + dir
			if not _in_bounds(next):
				continue
			var j := _index(next)
			if _seen[j] == _stamp or _occupied[j] > 0 or _enemy_cells[j] > 0:
				continue
			_seen[j] = _stamp
			_queue[tail] = j
			tail += 1
			if tail >= Cfg.FLOOD_CAP:
				break
	return tail


## An enemy dies: it scores for the player, its body turns into chickens in its colour, and the
## level is won when it was the last one.
func _kill_enemy(enemy) -> void:
	enemy.alive = false
	enemy_deaths.append(enemy.body[0])
	score += enemy_points()
	for k in enemy.body.size():
		var cell: Vector2i = enemy.body[k]
		_enemy_cells[_index(cell)] -= 1
		if k % Cfg.SEGMENTS_PER_CHICKEN == 0 and _is_free(cell):
			_add_food(cell, Food.GREEN + enemy.species)
	if enemies_alive() == 0:
		level_won = true
