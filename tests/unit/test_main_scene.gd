extends GutTest

var main: Node2D


func before_each() -> void:
	main = load("res://presentation/main.tscn").instantiate()
	add_child_autofree(main)


func test_scene_starts_a_game() -> void:
	assert_not_null(main.game)
	assert_eq(main.game.width, main.GRID_W)
	assert_eq(main.game.body.size(), 3)


func test_arrow_key_queues_turn() -> void:
	main._handle_key(KEY_UP)
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.UP)


func test_pause_toggles_and_blocks_turns() -> void:
	main._handle_key(KEY_P)
	assert_true(main.paused)
	main._handle_key(KEY_UP)
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.RIGHT)
	main._handle_key(KEY_ESCAPE)
	assert_false(main.paused)


func test_restart_only_after_game_over() -> void:
	main.game.score = 50
	main._handle_key(KEY_ENTER)
	assert_eq(main.game.score, 50)
	main.game.game_over = true
	main._handle_key(KEY_ENTER)
	assert_eq(main.game.score, 0)
	assert_false(main.game.game_over)


func test_process_advances_the_game() -> void:
	var head: Vector2i = main.game.body[0]
	main._process(main.game.tick_interval() + 0.001)
	assert_ne(main.game.body[0], head)


func test_draw_does_not_error() -> void:
	main._process(0.0)
	main.queue_redraw()
	await wait_process_frames(2)
	assert_true(is_instance_valid(main))


func _key_event(keycode: Key, pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


func test_key_event_turns_snake() -> void:
	main._unhandled_input(_key_event(KEY_W))
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.UP)


func test_key_release_and_echo_are_ignored() -> void:
	main._unhandled_input(_key_event(KEY_W, false))
	main._unhandled_input(_key_event(KEY_W, true, true))
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.RIGHT)


func test_banner_shows_pause_and_game_over() -> void:
	main._handle_key(KEY_P)
	main._process(0.0)
	assert_string_contains(main._banner.text, "PAUSED")
	main._handle_key(KEY_P)
	main.game.game_over = true
	main._process(0.0)
	assert_string_contains(main._banner.text, "GAME OVER")
	main._handle_key(KEY_KP_ENTER)
	main._process(0.0)
	assert_eq(main._banner.text, "")


func test_hud_shows_score_and_lives() -> void:
	main.game.score = 30
	main.game.lives = 2
	main._process(0.0)
	assert_string_contains(main._status.text, "Score 30")
	assert_string_contains(main._status.text, "Lives 2")


func test_draw_while_invulnerable() -> void:
	main.game.invulnerable_time = 5.0
	main.queue_redraw()
	await wait_process_frames(2)
	assert_true(is_instance_valid(main))


func test_snake_slides_between_cells() -> void:
	main.game.set_food([Vector2i(0, 0)])
	main.game.tick()
	main._t = 0.5
	var head: Vector2 = main._part_position(0)
	var cur := Vector2(main.game.body[0]) + Vector2(0.5, 0.5)
	var prev := Vector2(main.game.body[1]) + Vector2(0.5, 0.5)
	assert_eq(head, (prev + cur) / 2.0 * main.CELL)


func test_no_slide_when_snake_did_not_move() -> void:
	main.game.last_tick_moved = false
	main._t = 0.5
	assert_eq(main._part_position(0), main._cell_center(main.game.body[0]))


func test_food_and_snake_draw_with_many_foods() -> void:
	main.queue_redraw()
	await wait_process_frames(2)
	assert_gt(main.game.foods.size(), 10)


func test_tail_stays_put_when_snake_grows() -> void:
	var head: Vector2i = main.game.body[0]
	main.game.set_food([head + Vector2i.RIGHT])
	main.game.tick()
	main._t = 0.5
	var last: int = main.game.body.size() - 1
	assert_eq(main._part_position(last), main._cell_center(main.game.body[last]))


func test_tail_slides_from_vacated_cell() -> void:
	main.game.set_food([Vector2i(0, 0)])
	main.game.tick()
	main._t = 0.5
	var last: int = main.game.body.size() - 1
	var expected := (Vector2(main.game.tail_vacated) + Vector2(main.game.body[last])) / 2.0
	assert_eq(main._part_position(last), (expected + Vector2(0.5, 0.5)) * main.CELL)
