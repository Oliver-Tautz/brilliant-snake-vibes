extends GutTest

const View := preload("res://presentation/view_config.gd")

var main: Node2D
var world: Node2D


func before_each() -> void:
	main = load("res://presentation/main.tscn").instantiate()
	add_child_autofree(main)
	world = main.get_node("World")


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
	assert_string_contains(main._banner.text, "INTERMISSION")
	assert_true(main._banner_card.visible)
	main._handle_key(KEY_P)
	main.game.game_over = true
	main._process(0.0)
	assert_string_contains(main._banner.text, "THE END")
	main._handle_key(KEY_KP_ENTER)
	main._process(0.0)
	assert_eq(main._banner.text, "")
	assert_false(main._banner_card.visible)


func test_hud_shows_score_and_lives() -> void:
	main.game.score = 30
	main.game.lives = 2
	main._process(0.0)
	assert_string_contains(main._status.text, "SCORE  30")
	assert_string_contains(main._status.text, "LIVES  2")


func test_draw_while_invulnerable() -> void:
	main.game.invulnerable_time = 5.0
	main.queue_redraw()
	await wait_process_frames(2)
	assert_true(is_instance_valid(main))


func test_head_slides_between_cells() -> void:
	main.game.set_food([Vector2i(0, 0)])
	main.game.tick()
	world.t = 0.5
	var path: PackedVector2Array = world.snake_path()
	var cur := View.center(main.game.body[0])
	var prev := View.center(main.game.body[1])
	assert_eq(path[0], (prev + cur) / 2.0)


func test_path_keeps_corners_on_cell_centres() -> void:
	main.game.set_food([])
	main.game.set_body([Vector2i(5, 5), Vector2i(4, 5), Vector2i(4, 6), Vector2i(4, 7)])
	main.game.last_tick_moved = true
	main.game.tail_vacated = Vector2i(4, 8)
	world.t = 0.25
	var path: PackedVector2Array = world.snake_path()
	assert_eq(path.size(), 5)
	assert_eq(path[1], View.center(Vector2i(4, 5)))  # the corner itself
	assert_eq(path[2], View.center(Vector2i(4, 6)))
	assert_eq(path[3], View.center(Vector2i(4, 7)))
	assert_eq(path[4], View.center(Vector2i(4, 8)).lerp(View.center(Vector2i(4, 7)), 0.25))


func test_no_slide_when_snake_did_not_move() -> void:
	main.game.last_tick_moved = false
	world.t = 0.5
	var path: PackedVector2Array = world.snake_path()
	assert_eq(path.size(), main.game.body.size())
	assert_eq(path[0], View.center(main.game.body[0]))


func test_food_and_snake_draw_with_many_foods() -> void:
	main.queue_redraw()
	await wait_process_frames(2)
	assert_gt(main.game.foods.size(), 10)


func test_tail_stays_put_when_snake_grows() -> void:
	var head: Vector2i = main.game.body[0]
	main.game.set_food([head + Vector2i.RIGHT])
	main.game.tick()
	world.t = 0.5
	var path: PackedVector2Array = world.snake_path()
	assert_eq(path.size(), main.game.body.size())
	assert_eq(path[path.size() - 1], View.center(main.game.body.back()))


func test_eating_bursts_when_head_reaches_prey() -> void:
	var head: Vector2i = main.game.body[0]
	main.game.set_food([head + Vector2i.RIGHT])
	main._process(main.game.tick_interval() + 0.001)
	assert_eq(world.dying_prey, head + Vector2i.RIGHT)  # still drawn, not yet torn apart
	assert_eq(main.get_node("Gore").active_count(), 0)
	main._process(main.game.tick_interval() * 0.9)
	assert_eq(world.dying_prey, Vector2i(-1, -1))
	assert_gt(world.eat_pulse, 0.0)
	assert_gt(main.get_node("Gore").active_count(), 0)


func test_crash_triggers_gore_and_shake() -> void:
	main.game.set_body([Vector2i(99, 50), Vector2i(98, 50), Vector2i(97, 50)])
	main._process(main.game.tick_interval() + 0.001)
	assert_eq(main.game.lives, 2)
	assert_gt(main._shake, 0.0)
	assert_gt(main.get_node("Gore").active_count(), 20)


func test_gore_pools_are_capped() -> void:
	var gore = main.get_node("Gore")
	for i in 50:
		gore.burst(Vector2(100, 100), 60, 400.0, 5)
	assert_lte(gore._drop_count, gore.MAX_DROPS)
	assert_lte(gore._bone_count, gore.MAX_BONES)
	assert_lte(gore._splat_count, gore.MAX_SPLATS)


func test_gore_settles_into_fading_splats() -> void:
	var gore = main.get_node("Gore")
	gore.burst(Vector2(100, 100), 10, 200.0, 1)
	for i in 10:
		gore._process(0.1)
	assert_eq(gore._drop_count, 0)
	assert_gt(gore._splat_count, 1)
	gore._process(gore.SPLAT_LIFETIME + 1.0)
	gore.queue_redraw()
	await wait_process_frames(2)
	assert_true(is_instance_valid(gore))


func test_eat_effect_draws() -> void:
	main.play_eat_effect(main.game.body[0] + Vector2i(2, 0))
	await wait_process_frames(3)
	assert_true(is_instance_valid(main))


func test_crash_gore_lands_at_the_wall_hit() -> void:
	main.game.set_body([Vector2i(50, 0), Vector2i(50, 1), Vector2i(50, 2)])
	main.game.direction = Vector2i.UP
	main._process(main.game.tick_interval() + 0.001)
	var gore = main.get_node("Gore")
	var expected := (View.center(Vector2i(50, 0)) + View.center(Vector2i(50, -1))) / 2.0
	assert_eq(gore._splat_pos[0], expected)


func test_gore_stops_redrawing_once_faded() -> void:
	var gore = main.get_node("Gore")
	gore.burst(Vector2(100, 100), 5, 100.0, 0)
	assert_true(gore.is_active())
	gore._process(gore.SPLAT_LIFETIME + 1.0)
	gore._process(gore.SPLAT_LIFETIME + 1.0)
	assert_false(gore.is_active())


func test_gore_freezes_while_paused_and_clears_on_restart() -> void:
	var gore = main.get_node("Gore")
	gore.burst(Vector2(100, 100), 5, 100.0, 1)
	main._handle_key(KEY_P)
	assert_false(gore.is_processing())
	main._handle_key(KEY_P)
	assert_true(gore.is_processing())
	main.game.game_over = true
	main._handle_key(KEY_ENTER)
	assert_eq(gore.active_count(), 0)


func test_hud_uses_bundled_serif_font() -> void:
	assert_eq(main._status.get_theme_font("font"), main.SERIF)
	assert_eq(main._banner.get_theme_font("font"), main.SERIF)


func test_every_scene_script_loads() -> void:
	# A script with a parse error would silently drop off its node; catch that here.
	for path in ["Floor", "Gore", "World", "HUD/Status", "HUD/Banner"]:
		assert_not_null(main.get_node(path).get_script(), path)
