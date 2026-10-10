extends GutTest

const Cfg := preload("res://logic/game_config.gd")

var game: SnakeGame


func before_each() -> void:
	game = SnakeGame.new(10, 10, 1)


func _set_body(cells: Array) -> void:
	game.set_body(cells)


func test_initial_state() -> void:
	assert_eq(game.body.size(), Cfg.START_LENGTH)
	assert_eq(game.body[0], Vector2i(5, 5))
	assert_eq(game.lives, Cfg.LIVES)
	assert_eq(game.direction, Vector2i.RIGHT)
	assert_false(game.body.has(game.food))


func test_moves_one_cell_per_tick() -> void:
	game.food = Vector2i(0, 0)
	game.tick()
	assert_eq(game.body[0], Vector2i(6, 5))
	assert_eq(game.body.size(), Cfg.START_LENGTH)


func test_reverse_is_rejected() -> void:
	assert_false(game.request_turn(Vector2i.LEFT))
	assert_true(game.request_turn(Vector2i.UP))
	assert_false(game.request_turn(Vector2i.DOWN))


func test_input_buffer_holds_two_turns() -> void:
	assert_true(game.request_turn(Vector2i.UP))
	assert_true(game.request_turn(Vector2i.LEFT))
	assert_false(game.request_turn(Vector2i.DOWN))


func test_buffered_turns_apply_in_order() -> void:
	game.food = Vector2i(0, 0)
	game.request_turn(Vector2i.UP)
	game.request_turn(Vector2i.LEFT)
	game.tick()
	assert_eq(game.body[0], Vector2i(5, 4))
	game.tick()
	assert_eq(game.body[0], Vector2i(4, 4))


func test_eating_grows_scores_and_respawns_food() -> void:
	game.food = Vector2i(6, 5)
	game.tick()
	assert_eq(game.body.size(), Cfg.START_LENGTH + 1)
	assert_eq(game.score, Cfg.FOOD_SCORE)
	assert_eq(game.foods_eaten, 1)
	assert_ne(game.food, Vector2i(6, 5))
	assert_false(game.body.has(game.food))


func test_wall_hit_costs_life_and_halves_length() -> void:
	_set_body([Vector2i(9, 5), Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5), Vector2i(5, 5),
			Vector2i(4, 5), Vector2i(3, 5), Vector2i(2, 5)])
	game.tick()
	assert_eq(game.lives, Cfg.LIVES - 1)
	assert_eq(game.body.size(), 4)
	assert_eq(game.body[0], Vector2i(5, 5))
	assert_eq(game.invulnerable_time, Cfg.INVULNERABLE_SECONDS)


func test_shrink_never_goes_below_min_length() -> void:
	_set_body([Vector2i(9, 5), Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5)])
	game.tick()
	assert_eq(game.body.size(), Cfg.MIN_LENGTH)


func test_self_hit_costs_life() -> void:
	_set_body([Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4)])
	game.direction = Vector2i.DOWN
	game.tick()
	assert_eq(game.lives, Cfg.LIVES - 1)


func test_moving_into_tail_cell_is_allowed() -> void:
	_set_body([Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2)])
	game.food = Vector2i(9, 9)
	game.direction = Vector2i.DOWN
	game.tick()
	assert_eq(game.lives, Cfg.LIVES)
	assert_eq(game.body[0], Vector2i(1, 2))


func test_invulnerable_wall_blocks_without_life_loss() -> void:
	_set_body([Vector2i(9, 5), Vector2i(8, 5), Vector2i(7, 5)])
	game.invulnerable_time = 1.0
	game.tick()
	assert_eq(game.lives, Cfg.LIVES)
	assert_eq(game.body[0], Vector2i(9, 5))


func test_invulnerable_passes_through_own_body() -> void:
	_set_body([Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4)])
	game.direction = Vector2i.DOWN
	game.invulnerable_time = 1.0
	game.tick()
	assert_eq(game.lives, Cfg.LIVES)
	assert_eq(game.body[0], Vector2i(3, 4))


func test_game_over_when_last_life_lost() -> void:
	game.lives = 1
	_set_body([Vector2i(9, 5), Vector2i(8, 5), Vector2i(7, 5)])
	game.tick()
	assert_true(game.game_over)
	var head := game.body[0]
	game.tick()
	assert_eq(game.body[0], head)


func test_tick_interval_ramps_down_to_floor() -> void:
	var start := game.tick_interval()
	game.foods_eaten = 5
	assert_lt(game.tick_interval(), start)
	game.foods_eaten = 10000
	assert_eq(game.tick_interval(), Cfg.MIN_INTERVAL)


func test_invulnerability_expires_after_seconds() -> void:
	game.food = Vector2i(0, 0)
	game.invulnerable_time = 0.3
	game.tick()
	game.tick()
	assert_lte(game.invulnerable_time, 0.0)


func test_life_loss_respawns_food_that_overlaps_new_snake() -> void:
	_set_body([Vector2i(9, 5), Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5), Vector2i(4, 5)])
	game.food = Vector2i(5, 5)  # the respawn will put the head here
	game.tick()
	assert_false(game.body.has(game.food))


func test_snake_is_cut_short_on_narrow_grid() -> void:
	var narrow := SnakeGame.new(2, 5, 1)
	assert_eq(narrow.body.size(), 2)


func test_food_is_none_when_board_is_full() -> void:
	var tiny := SnakeGame.new(3, 1, 1)
	assert_eq(tiny.food, Vector2i(2, 0))
	tiny.tick()
	assert_eq(tiny.body.size(), 3)
	assert_eq(tiny.food, Vector2i(-1, -1))


func test_food_fallback_scan_finds_last_free_cell() -> void:
	var big := SnakeGame.new(20, 20, 1)
	var cells: Array[Vector2i] = []
	for y in 20:
		for x in 20:
			if Vector2i(x, y) != Vector2i(7, 7):
				cells.append(Vector2i(x, y))
	big.set_body(cells)
	big._spawn_food()
	assert_eq(big.food, Vector2i(7, 7))


func test_non_unit_turns_are_rejected() -> void:
	assert_false(game.request_turn(Vector2i.ZERO))
	assert_false(game.request_turn(Vector2i(1, 1)))
	assert_false(game.request_turn(Vector2i(2, 0)))


func test_large_grid_ticks() -> void:
	var big := SnakeGame.new(500, 500, 1)
	big.food = Vector2i(0, 0)
	for _i in 100:
		big.tick()
	assert_eq(big.body[0], Vector2i(350, 250))
	assert_eq(big.lives, Cfg.LIVES)
