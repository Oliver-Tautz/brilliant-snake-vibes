extends GutTest
## Levels, enemy snakes, chickens and points (spec §5, §6, §6b, §8).

const Cfg := preload("res://logic/game_config.gd")
const Enemy := preload("res://logic/enemy_snake.gd")

var game: SnakeGame


func before_each() -> void:
	game = SnakeGame.new(20, 20, 7)


## Free play plus one hand-placed enemy, so tests control every snake.
func _enemy(kind: int, cells: Array[Vector2i], heading: Vector2i) -> Object:
	var enemy := Enemy.new(kind, cells, heading, 1.0)
	for cell in cells:
		game._enemy_cells[game._index(cell)] += 1
	game.enemies.append(enemy)
	return enemy


func _cells(head: Vector2i, length: int, heading: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in length:
		cells.append(head - heading * i)
	return cells


func test_a_fresh_snake_does_not_slide_in_from_the_old_one() -> void:
	game.last_tick_moved = true
	game.tail_vacated = Vector2i(3, 3)
	game.start_level(2)
	assert_false(game.last_tick_moved)
	assert_eq(game.tail_vacated, Vector2i(-1, -1))


func test_eaten_kind_is_reported_for_the_gulp() -> void:
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	game.set_food([Vector2i(11, 10)], SnakeGame.Food.BIG)
	game.tick()
	assert_eq(game.last_eaten_kind, SnakeGame.Food.BIG)


func test_arena_shrinks_ten_percent_per_level_down_to_a_minimum() -> void:
	assert_eq(SnakeGame.arena_size(1), Cfg.ARENA)
	assert_eq(SnakeGame.arena_size(2), Vector2i(54, 36))
	assert_eq(SnakeGame.arena_size(40), Cfg.MIN_ARENA)


func test_start_level_sets_up_three_enemies_and_keeps_score_and_lives() -> void:
	game.score = 42
	game.lives = 2
	game.foods_eaten = 9
	game.start_level(3)
	assert_eq(game.level, 3)
	assert_eq(Vector2i(game.width, game.height), SnakeGame.arena_size(3))
	assert_eq(game.enemies.size(), 3)
	assert_eq(game.enemies_alive(), 3)
	assert_eq(game.score, 42)
	assert_eq(game.lives, 2)
	assert_eq(game.foods_eaten, 0)  # the player's speed starts over
	assert_eq(game.body.size(), Cfg.START_LENGTH)
	assert_eq(game.foods.size(), game.width * game.height / Cfg.CELLS_PER_FOOD)
	for enemy in game.enemies:
		assert_eq(enemy.body.size(), Cfg.ENEMY_START_LENGTH)
		for cell in enemy.body:
			assert_false(game.body.has(cell))


func test_enemies_get_faster_each_level_and_keep_their_order() -> void:
	game.start_level(1)
	var first: Array[float] = []
	for enemy in game.enemies:
		first.append(enemy.interval)
	assert_gt(first[0], first[1])  # anaconda slower than cobra
	assert_gt(first[1], first[2])  # cobra slower than mamba
	game.start_level(4)
	for k in 3:
		assert_lt(game.enemies[k].interval, first[k])


func test_points_scale_with_level() -> void:
	assert_eq(game.points(1), 1)  # free play: level 0
	game.level = 3
	assert_eq(game.points(Cfg.CHICKEN_POINTS), 2)
	assert_eq(game.points(Cfg.BIG_POINTS), 10)
	assert_eq(game.points(Cfg.ENEMY_POINTS), 40)


func test_enemy_points_decay_with_time_but_not_below_the_floor() -> void:
	game.level = 3
	assert_eq(game.enemy_points(), 40)
	game.level_time = 65.0
	assert_eq(game.enemy_points(), 34)
	game.level_time = 10000.0
	assert_eq(game.enemy_points(), Cfg.ENEMY_MIN_POINTS)


func test_big_chicken_grows_three_and_scores_five() -> void:
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	game.set_food([Vector2i(11, 10)], SnakeGame.Food.BIG)
	game.tick()
	assert_eq(game.score, Cfg.BIG_POINTS)
	for i in 3:
		game.tick()
	assert_eq(game.body.size(), 3 + Cfg.BIG_GROWTH)
	game.tick()
	assert_eq(game.body.size(), 3 + Cfg.BIG_GROWTH)


func test_player_into_enemy_body_costs_a_life() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	_enemy(Enemy.Species.ANACONDA, _cells(Vector2i(11, 13), 5, Vector2i.DOWN), Vector2i.DOWN)  # 11,9..13
	game.tick()
	assert_true(game.last_life_lost)
	assert_eq(game.lives, Cfg.LIVES - 1)


func test_biting_a_shorter_enemy_head_kills_it_and_leaves_coloured_chickens() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 6, Vector2i.RIGHT))
	var foe := _enemy(Enemy.Species.COBRA, _cells(Vector2i(11, 10), 4, Vector2i.LEFT), Vector2i.LEFT)
	_enemy(Enemy.Species.MAMBA, _cells(Vector2i(3, 3), 3, Vector2i.RIGHT), Vector2i.RIGHT)  # so the level goes on
	game.tick()
	assert_false(foe.alive)
	assert_false(game.last_life_lost)
	assert_eq(game.enemy_deaths, [Vector2i(11, 10)] as Array[Vector2i])
	assert_eq(game.score, Cfg.ENEMY_POINTS + Cfg.CHICKEN_POINTS)  # and it ate the chicken at the head
	assert_eq(game.food_at(Vector2i(14, 10)), SnakeGame.Food.PURPLE)  # every third segment
	assert_eq(game.food_at(Vector2i(12, 10)), SnakeGame.Food.NONE)
	for x in range(12, 15):
		assert_eq(game._enemy_cells[game._index(Vector2i(x, 10))], 0)


func test_a_tie_head_on_goes_to_the_player() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 4, Vector2i.RIGHT))
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(11, 10), 4, Vector2i.LEFT), Vector2i.LEFT)
	game.tick()
	assert_false(foe.alive)


func test_biting_a_longer_enemy_head_costs_a_life() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(11, 10), 6, Vector2i.LEFT), Vector2i.LEFT)
	game.tick()
	assert_true(foe.alive)
	assert_true(game.last_life_lost)


func test_enemy_running_into_the_player_body_dies() -> void:
	game.set_food([])
	game.set_body([Vector2i(10, 10), Vector2i(10, 11), Vector2i(10, 12), Vector2i(10, 13)])
	# Boxed in: walls of its own and the player's body leave only the move into the player.
	var foe := _enemy(Enemy.Species.ANACONDA, _cells(Vector2i(11, 11), 3, Vector2i.LEFT), Vector2i.LEFT)
	game._enemy_cells[game._index(Vector2i(11, 10))] += 1
	game._enemy_cells[game._index(Vector2i(11, 12))] += 1
	game._step_enemy(foe)
	assert_false(foe.alive)  # no free move at all: it dies
	assert_eq(game.enemy_deaths.size(), 1)


func test_enemy_heads_for_the_nearest_chicken() -> void:
	game.set_body(_cells(Vector2i(2, 18), 3, Vector2i.RIGHT))
	game.set_food([Vector2i(15, 5)])
	var foe := _enemy(Enemy.Species.ANACONDA, _cells(Vector2i(10, 5), 3, Vector2i.RIGHT), Vector2i.RIGHT)
	for i in 5:
		game._step_enemy(foe)
	assert_eq(foe.body[0], Vector2i(15, 5))
	assert_eq(foe.body.size(), 4)  # grew from the chicken
	assert_eq(game.score, 0)  # enemies' meals score nothing


func test_shorter_enemy_avoids_the_player_head() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 6, Vector2i.RIGHT))
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(10, 8), 3, Vector2i.DOWN), Vector2i.DOWN)
	game._step_enemy(foe)
	assert_ne(foe.body[0], Vector2i(10, 9))  # next to the head
	assert_eq(game.lives, Cfg.LIVES)


func test_longer_enemy_wins_face_to_face() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(11, 10), 6, Vector2i.LEFT), Vector2i.LEFT)
	game._step_enemy(foe)
	assert_true(game.last_life_lost)
	assert_true(foe.alive)


func test_enemy_into_the_player_head_from_the_side_dies() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	_enemy(Enemy.Species.MAMBA, _cells(Vector2i(3, 3), 3, Vector2i.RIGHT), Vector2i.RIGHT)
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(10, 9), 6, Vector2i.DOWN), Vector2i.DOWN)
	game._move_enemy(foe, Vector2i.DOWN)  # the AI avoids this; the rule still has to hold
	assert_false(foe.alive)
	assert_false(game.last_life_lost)


func test_longer_enemy_does_not_lunge_from_the_side() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(10, 9), 6, Vector2i.DOWN), Vector2i.DOWN)
	game._step_enemy(foe)
	assert_ne(foe.body[0], Vector2i(10, 10))
	assert_false(game.last_life_lost)


func test_enemies_move_on_their_own_clock() -> void:
	game.set_food([])
	var foe := _enemy(Enemy.Species.ANACONDA, _cells(Vector2i(5, 3), 3, Vector2i.RIGHT), Vector2i.RIGHT)
	game.advance(0.5)
	assert_eq(foe.body[0], Vector2i(5, 3))
	assert_almost_eq(foe.clock, 0.5, 0.001)
	game.advance(0.6)
	assert_ne(foe.body[0], Vector2i(5, 3))
	assert_true(foe.last_moved)


func test_level_is_won_when_the_last_enemy_dies() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 6, Vector2i.RIGHT))
	_enemy(Enemy.Species.COBRA, _cells(Vector2i(11, 10), 3, Vector2i.LEFT), Vector2i.LEFT)
	var other := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(3, 3), 3, Vector2i.RIGHT), Vector2i.RIGHT)
	other.alive = false
	game.tick()
	assert_true(game.level_won)
	var head := game.body[0]
	game.tick()
	game.advance(1.0)
	assert_eq(game.body[0], head)  # everything waits for the next level


func test_time_up_costs_a_life_and_restarts_the_level_keeping_the_score() -> void:
	game.start_level(2)
	game.score = 30
	game.enemies[0].alive = false
	game.advance(Cfg.LEVEL_SECONDS + 0.1)
	assert_true(game.last_time_up)
	assert_eq(game.lives, Cfg.LIVES - 1)
	assert_eq(game.score, 30)
	assert_eq(game.enemies_alive(), 3)
	assert_almost_eq(game.time_left(), Cfg.LEVEL_SECONDS, 0.001)


func test_time_up_on_the_last_life_ends_the_game() -> void:
	game.start_level(1)
	game.lives = 1
	game.advance(Cfg.LEVEL_SECONDS + 0.1)
	assert_true(game.game_over)


func test_respawn_avoids_enemies() -> void:
	game.set_food([])
	_enemy(Enemy.Species.ANACONDA, _cells(Vector2i(11, 10), 6, Vector2i.RIGHT), Vector2i.RIGHT)  # centre row
	game.set_body(_cells(Vector2i(19, 2), 3, Vector2i.RIGHT))
	game.tick()  # wall
	assert_true(game.last_life_lost)
	for cell in game.body:
		assert_eq(game._enemy_cells[game._index(cell)], 0)


func test_chicken_winds_up_then_hops() -> void:
	game.set_body(_cells(Vector2i(2, 18), 3, Vector2i.RIGHT))
	game.set_food([Vector2i(10, 5)])
	game.hops.append({"cell": Vector2i(10, 5), "dir": Vector2i.RIGHT, "steps": 2, "windup": Cfg.HOP_WINDUP, "slide": 0.0})
	game._step_hops(Cfg.HOP_WINDUP * 0.5)
	assert_eq(game.foods[0], Vector2i(10, 5))  # still crouching
	for i in 20:
		game._step_hops(0.1)
	assert_eq(game.foods[0], Vector2i(12, 5))
	assert_eq(game.food_at(Vector2i(12, 5)), SnakeGame.Food.CHICKEN)
	assert_eq(game.food_at(Vector2i(10, 5)), SnakeGame.Food.NONE)
	assert_eq(game.hops.size(), 0)


func test_hop_stops_at_a_blocked_cell_and_forgets_eaten_chickens() -> void:
	game.set_body(_cells(Vector2i(12, 5), 3, Vector2i.RIGHT))  # 10..12, row 5
	game.set_food([Vector2i(9, 5), Vector2i(3, 3)])
	game.hops.append({"cell": Vector2i(9, 5), "dir": Vector2i.RIGHT, "steps": 1, "windup": 0.0, "slide": 0.0})
	game.hops.append({"cell": Vector2i(3, 3), "dir": Vector2i.UP, "steps": 1, "windup": 1.0, "slide": 0.0})
	game._eat(Vector2i(3, 3))
	game._step_hops(0.01)
	assert_eq(game.hops.size(), 0)
	assert_eq(game.food_at(Vector2i(9, 5)), SnakeGame.Food.CHICKEN)


func test_hops_start_now_and_then() -> void:
	var most := 0
	for i in 200:
		game._advance_hops(0.1)
		most = maxi(most, game.hops.size())
	assert_gt(most, 0)
	assert_lte(most, Cfg.MAX_HOPS)


func test_some_new_chickens_are_big() -> void:
	var big := 0
	for i in 400:
		game._spawn_food()
	for cell in game.foods:
		big += int(game.food_at(cell) == SnakeGame.Food.BIG)
	assert_between(big, 20, 90)  # about one in eight of ~400


func test_flood_fill_is_capped_and_sees_walls() -> void:
	game.set_body(_cells(Vector2i(2, 18), 3, Vector2i.RIGHT))
	assert_eq(game._flood(Vector2i(10, 10)), Cfg.FLOOD_CAP)
	var tight := SnakeGame.new(3, 3, 1)
	tight.set_body([Vector2i(1, 1)])
	assert_eq(tight._flood(Vector2i(0, 0)), 8)


func test_level_ten_is_still_playable() -> void:
	game.start_level(10)
	assert_gte(game.width, Cfg.MIN_ARENA.x)
	for i in 300:  # enemies roam for a while without breaking the grids
		game.advance(0.05)
		if game.level_won or game.game_over:
			break
	for enemy in game.enemies:
		if enemy.alive:
			for cell in enemy.body:
				assert_gt(game._enemy_cells[game._index(cell)], 0)


func test_biting_a_longer_enemy_head_from_the_side_kills_it() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	_enemy(Enemy.Species.MAMBA, _cells(Vector2i(3, 3), 3, Vector2i.RIGHT), Vector2i.RIGHT)  # keeps the level going
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(11, 10), 8, Vector2i.DOWN), Vector2i.DOWN)  # heading down
	game.tick()
	assert_false(foe.alive)
	assert_false(game.last_life_lost)


func test_biting_the_neck_the_head_just_left_kills_it() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	_enemy(Enemy.Species.MAMBA, _cells(Vector2i(3, 3), 3, Vector2i.RIGHT), Vector2i.RIGHT)
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(11, 11), 8, Vector2i.DOWN), Vector2i.DOWN)  # neck at 11,10
	game.tick()
	assert_false(foe.alive)
	assert_false(game.last_life_lost)


func test_biting_further_down_the_body_still_costs_a_life() -> void:
	game.set_food([])
	game.set_body(_cells(Vector2i(10, 10), 3, Vector2i.RIGHT))
	var foe := _enemy(Enemy.Species.MAMBA, _cells(Vector2i(11, 12), 8, Vector2i.DOWN), Vector2i.DOWN)  # 11,10 is 3rd
	game.tick()
	assert_true(foe.alive)
	assert_true(game.last_life_lost)
