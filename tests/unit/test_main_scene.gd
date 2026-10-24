extends GutTest

const View := preload("res://presentation/view_config.gd")

const SETTINGS_PATH := "user://test_main_settings.cfg"

var main: Node2D
var world: Node2D
var _saved_settings: Array


func before_all() -> void:
	# Menu tests change settings; keep them away from the player's real settings file.
	_saved_settings = [Settings.path, Settings.gore, Settings.show_arrows, Settings.highscores.duplicate(true)]
	Settings.path = SETTINGS_PATH


func after_all() -> void:
	Settings.path = _saved_settings[0]
	Settings.gore = _saved_settings[1]
	Settings.show_arrows = _saved_settings[2]
	Settings.highscores.assign(_saved_settings[3])
	DirAccess.remove_absolute(SETTINGS_PATH)


func before_each() -> void:
	Settings.gore = true
	Settings.show_arrows = true
	Settings.highscores.clear()
	main = load("res://presentation/main.tscn").instantiate()
	add_child_autofree(main)
	world = main.get_node("World")
	main.start_run()  # most tests are about a run; the title screen has its own tests
	main.set_game(SnakeGame.new(100, 100, 1))  # free play without enemies, so tests control the board


func test_a_run_starts_at_level_one_with_three_enemies() -> void:
	main.start_run()
	assert_eq(main.game.level, 1)
	assert_eq(main.game.enemies_alive(), 3)
	assert_eq(main.game.body.size(), 3)
	assert_eq(main.get_node("Floor").size, Vector2(main.Cfg.ARENA) * View.CELL)
	main._process(0.0)
	assert_string_contains(main._status.text, "LEVEL  1")
	assert_string_contains(main._status.text, "TIME  2:00")
	assert_string_contains(main._status.text, "FOES  3")


func test_enemies_move_during_a_run() -> void:
	main.start_run()
	var head: Vector2i = main.game.enemies[2].body[0]
	for i in 10:
		main._process(0.05)
	assert_ne(main.game.enemies[2].body[0], head)


func test_enemy_death_bursts_and_clears_the_event() -> void:
	main.game.enemy_deaths.append(Vector2i(10, 10))
	main._play_clock_events()
	assert_gt(main.get_node("Gore").active_count(), 0)
	assert_gt(main._shake, 0.0)
	assert_eq(main.game.enemy_deaths.size(), 0)


func test_cleared_level_shows_a_card_and_moves_on_to_a_smaller_arena() -> void:
	main.start_run()
	main.game.score = 77
	main.game.level_won = true
	main._process(0.0)
	assert_eq(main.screen, main.Screen.BREAK)
	assert_string_contains(main._menu.heading(), "LEVEL 1 CLEARED")
	assert_false(main.get_node("HUD/Pause").visible)
	main._menu.press("Next level")
	assert_eq(main.screen, main.Screen.PLAYING)
	assert_eq(main.game.level, 2)
	assert_eq(main.game.score, 77)
	assert_eq(main.get_node("Floor").size, Vector2(SnakeGame.arena_size(2)) * View.CELL)


func test_time_up_shows_a_card_and_the_level_restarts() -> void:
	main.start_run()
	main.game.level_time = main.Cfg.LEVEL_SECONDS - 0.01
	main._process(0.05)
	assert_eq(main.screen, main.Screen.BREAK)
	assert_string_contains(main._menu.heading(), "TIME'S UP")
	assert_eq(main.game.lives, main.Cfg.LIVES - 1)
	main._menu.press("Continue")
	assert_eq(main.screen, main.Screen.PLAYING)
	assert_almost_eq(main.game.time_left(), main.Cfg.LEVEL_SECONDS, 0.01)


func test_game_over_records_the_score_and_marks_it() -> void:
	Settings.add_score(500, 4, "2026-01-01")
	main.game.score = 120
	main.game.game_over = true
	main._process(0.0)
	assert_eq(Settings.highscores.size(), 2)
	assert_string_contains(main._menu.body(), "500")
	assert_string_contains(main._menu.body(), "2.   120   level 0")
	assert_string_contains(main._menu.body(), "new")


func test_highscores_page_from_the_title() -> void:
	main.show_title()
	main._menu.press("Highscores")
	assert_string_contains(main._menu.heading(), "HIGHSCORES")
	assert_eq(main._menu.body(), "No scores yet")
	Settings.add_score(90, 2, "2026-02-02")
	main._menu.press("Back")
	main._menu.press("Highscores")
	assert_string_contains(main._menu.body(), "1.   90   level 2   2026-02-02")
	main._menu.press("Back")
	assert_eq(main.screen, main.Screen.TITLE)
	assert_true(main._menu.buttons()[2].has_focus())


func test_gore_switch_is_on_the_title() -> void:
	main.show_title()
	main._menu.press("Gore: On")
	assert_false(Settings.gore)
	assert_eq(main._menu.buttons()[1].text, "Gore: Off")
	assert_true(main._menu.buttons()[1].has_focus())


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


func test_game_over_card_restarts() -> void:
	main.game.score = 50
	main.game.game_over = true
	main._process(0.0)
	assert_eq(main.screen, main.Screen.OVER)
	assert_string_contains(main._menu.heading(), "THE END")
	assert_string_contains(main._menu.heading(), "50")
	main._menu.press("Restart")
	assert_eq(main.screen, main.Screen.PLAYING)
	assert_eq(main.game.score, 0)
	assert_false(main.game.game_over)


func test_game_over_card_leads_to_title() -> void:
	main.game.game_over = true
	main._process(0.0)
	main._menu.press("Menu")
	assert_eq(main.screen, main.Screen.TITLE)


func test_starts_on_the_title_card_with_a_frozen_game() -> void:
	var fresh: Node2D = load("res://presentation/main.tscn").instantiate()
	add_child_autofree(fresh)
	assert_eq(fresh.screen, fresh.Screen.TITLE)
	assert_true(fresh._menu.visible)
	assert_false(fresh.get_node("HUD/Pause").visible)
	var head: Vector2i = fresh.game.body[0]
	fresh._process(fresh.game.tick_interval() * 3.0)
	assert_eq(fresh.game.body[0], head)
	fresh._menu.press("Play")
	assert_eq(fresh.screen, fresh.Screen.PLAYING)
	assert_false(fresh._menu.visible)


func test_title_has_play_options_and_github() -> void:
	main.show_title()
	var texts: Array[String] = []
	for button in main._menu.buttons():
		texts.append(button.text)
	assert_eq(texts, ["Play", "Gore: On", "Highscores", "Options", "GitHub"] as Array[String])
	assert_true(main._menu.buttons()[0].has_focus())  # keyboard players can press Enter right away


func test_pause_menu_items_and_quit_to_menu() -> void:
	main._handle_key(KEY_P)
	var texts: Array[String] = []
	for button in main._menu.buttons():
		texts.append(button.text)
	assert_eq(texts, ["Resume", "Restart", "Options", "Quit to menu", "GitHub"] as Array[String])
	main._menu.press("Quit to menu")
	assert_eq(main.screen, main.Screen.TITLE)
	assert_false(main.get_node("HUD/Pause").visible)


func test_pause_menu_resume_and_restart() -> void:
	main.game.score = 30
	main._handle_key(KEY_P)
	main._menu.press("Resume")
	assert_false(main.paused)
	assert_eq(main.game.score, 30)
	main._handle_key(KEY_P)
	main._menu.press("Restart")
	assert_false(main.paused)
	assert_eq(main.game.score, 0)


func test_options_switch_gore_and_save_it() -> void:
	main._handle_key(KEY_P)
	main._menu.press("Options")
	assert_eq(main.screen, main.Screen.OPTIONS)
	main._menu.press("Gore: On")
	assert_false(Settings.gore)
	assert_false(main.get_node("Gore").gore)
	main._menu.press("Gore: Off")
	assert_true(Settings.gore)
	assert_true(main._menu.buttons()[0].has_focus())  # rebuilt page keeps the keyboard's place
	var saved := ConfigFile.new()
	assert_eq(saved.load(SETTINGS_PATH), OK)
	assert_true(saved.get_value("game", "gore"))


func test_options_hide_the_arrows() -> void:
	var dpad: Control = main.get_node("HUD/DPad")
	main._on_touch_seen()
	assert_true(dpad.visible)
	main._handle_key(KEY_P)
	assert_false(dpad.visible)  # never over a menu
	main._menu.press("Options")
	main._menu.press("Arrows on touch: Shown")
	assert_false(Settings.show_arrows)
	assert_true(main._menu.buttons()[1].has_focus())
	main._menu.press("Back")
	main._menu.press("Resume")
	assert_false(dpad.visible)


func test_options_back_returns_where_they_came_from() -> void:
	main.show_title()
	main._menu.press("Options")
	main._menu.press("Back")
	assert_eq(main.screen, main.Screen.TITLE)
	main.start_run()
	main._handle_key(KEY_P)
	main._menu.press("Options")
	main._handle_key(KEY_ESCAPE)  # Esc goes back too
	assert_eq(main.screen, main.Screen.PAUSED)


func test_fullscreen_option_shows_the_window_state() -> void:
	main.show_title()
	main._menu.press("Options")
	var label := "Fullscreen: %s" % ("On" if main.is_fullscreen() else "Off")
	assert_eq(main._menu.buttons()[2].text, label)
	main._menu.press(label)  # headless has no real window; this must just not fail
	assert_eq(main.screen, main.Screen.OPTIONS)
	assert_true(main._menu.buttons()[2].has_focus())


func test_turns_are_ignored_outside_a_run() -> void:
	main.show_title()
	main._handle_key(KEY_UP)
	main.start_run()
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.RIGHT)


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
	main.get_node("Controls")._unhandled_input(_key_event(KEY_W))
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.UP)


func test_key_release_and_echo_are_ignored() -> void:
	main.get_node("Controls")._unhandled_input(_key_event(KEY_W, false))
	main.get_node("Controls")._unhandled_input(_key_event(KEY_W, true, true))
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.RIGHT)


func test_menu_card_shows_pause_and_hides_in_play() -> void:
	main._handle_key(KEY_P)
	assert_string_contains(main._menu.heading(), "INTERMISSION")
	assert_true(main._menu.visible)
	main._handle_key(KEY_P)
	assert_false(main._menu.visible)


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


func test_skin_marks_slide_with_the_head() -> void:
	main.game.set_food([])
	main.game.set_body([Vector2i(9, 5), Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5), Vector2i(5, 5)])
	main.game.last_tick_moved = true
	world.t = 0.0  # start of the tick: where the mark was at the end of the last one
	assert_eq(world.skin_mark_at(2), View.center(Vector2i(6, 5)))
	world.t = 0.5
	assert_eq(world.skin_mark_at(2), (View.center(Vector2i(7, 5)) + View.center(Vector2i(6, 5))) / 2.0)
	world.t = 1.0
	assert_eq(world.skin_mark_at(2), View.center(Vector2i(7, 5)))
	main.game.last_tick_moved = false
	world.t = 0.5
	assert_eq(world.skin_mark_at(2), View.center(Vector2i(7, 5)))


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
	main._process(0.0)
	main._menu.press("Restart")
	assert_eq(gore.active_count(), 0)


func test_hud_uses_bundled_serif_font() -> void:
	assert_eq(main._status.get_theme_font("font"), main.SERIF)
	assert_eq(main._menu.buttons()[0].get_theme_font("font"), main.SERIF)


func test_every_scene_script_loads() -> void:
	# A script with a parse error would silently drop off its node; catch that here.
	for path in ["Floor", "Gore", "World", "HUD/Status", "HUD/Menu", "PerfOverlay", "Controls", "HUD/DPad",
			"HUD/Pause"]:
		assert_not_null(main.get_node(path).get_script(), path)


func test_f3_toggles_perf_overlay_and_it_reports() -> void:
	var overlay = main.get_node("PerfOverlay")
	assert_false(overlay.visible)
	main._handle_key(KEY_F3)
	assert_true(overlay.visible)
	for i in 3:
		overlay._process(0.2)
	assert_string_contains(overlay.get_node("Label").text, "fps")
	main._handle_key(KEY_F3)
	assert_false(overlay.visible)


func test_world_layers_can_be_switched_off() -> void:
	world.show_prey = false
	world.show_snake = false
	world.show_walls = false
	world.queue_redraw()
	await wait_process_frames(2)
	assert_true(is_instance_valid(world))


func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = pos
	event.pressed = pressed
	return event


func _drag(pos: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.position = pos
	return event


func test_swipe_turns_the_snake() -> void:
	var controls = main.get_node("Controls")
	controls._unhandled_input(_touch(Vector2(500, 300), true))
	controls._unhandled_input(_drag(Vector2(505, 260)))  # mostly up, past the threshold
	controls._unhandled_input(_touch(Vector2(505, 260), false))
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.UP)


func test_one_zig_zag_swipe_queues_two_turns() -> void:
	var controls = main.get_node("Controls")
	controls._unhandled_input(_touch(Vector2(500, 300), true))
	controls._unhandled_input(_drag(Vector2(500, 260)))  # up
	controls._unhandled_input(_drag(Vector2(460, 260)))  # then left
	main.game.tick()
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.LEFT)


func test_short_drag_is_not_a_swipe() -> void:
	var controls = main.get_node("Controls")
	controls._unhandled_input(_touch(Vector2(500, 300), true))
	controls._unhandled_input(_drag(Vector2(510, 300)))
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.RIGHT)


func test_tap_during_play_does_nothing() -> void:
	var controls = main.get_node("Controls")
	main.game.score = 40
	controls._unhandled_input(_touch(Vector2(500, 300), true))
	controls._unhandled_input(_touch(Vector2(500, 300), false))
	assert_false(main.paused)
	assert_eq(main.game.score, 40)


func test_first_touch_shows_the_dpad() -> void:
	var dpad = main.get_node("HUD/DPad")
	main._touch_seen = false
	main._update_dpad()
	assert_false(dpad.visible)
	main.get_node("Controls")._unhandled_input(_touch(Vector2(10, 10), true))
	assert_true(dpad.visible)


func test_dpad_arms_turn_the_snake() -> void:
	var dpad = main.get_node("HUD/DPad")
	dpad.size = Vector2(240, 240)
	assert_eq(dpad.direction_at(Vector2(120, 20)), Vector2i.UP)
	assert_eq(dpad.direction_at(Vector2(220, 120)), Vector2i.RIGHT)
	assert_eq(dpad.direction_at(Vector2(120, 120)), Vector2i.ZERO)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(20, 120)  # left arm
	dpad._gui_input(click)
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.RIGHT)  # left is a reversal, so it is rejected
	click.position = Vector2(120, 220)  # down arm
	dpad._gui_input(click)
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.DOWN)


func test_pause_button_pauses_and_resumes() -> void:
	var button = main.get_node("HUD/Pause")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	button._gui_input(click)
	assert_true(main.paused)
	button._gui_input(click)
	assert_false(main.paused)


func test_touch_ui_draws() -> void:
	main.get_node("HUD/DPad").visible = true
	main.get_node("HUD/DPad").queue_redraw()
	main.get_node("HUD/Pause").queue_redraw()
	await wait_process_frames(2)
	assert_true(is_instance_valid(main))


func _finger(pos: Vector2, pressed: bool, index := 0) -> InputEventScreenTouch:
	var event := _touch(pos, pressed)
	event.index = index
	return event


func _arm(dpad: Control, dir: Vector2i) -> Vector2:
	return dpad.get_global_rect().get_center() + Vector2(dir) * dpad.size.x / 3.0


func test_new_finger_takes_over_the_swipe() -> void:
	var controls = main.get_node("Controls")
	controls._unhandled_input(_finger(Vector2(100, 500), true, 0))  # resting thumb
	controls._unhandled_input(_finger(Vector2(600, 300), true, 1))
	var drag := _drag(Vector2(600, 260))
	drag.index = 1
	controls._unhandled_input(drag)
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.UP)


## Real touches through a viewport, so GUI routing decides who gets them, as on a tablet. The game
## runs in its own SubViewport so GUT's on-screen runner UI cannot catch the touches.
func _isolated_main() -> Array:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	add_child_autofree(viewport)
	var isolated: Node2D = load("res://presentation/main.tscn").instantiate()
	viewport.add_child(isolated)
	isolated.start_run()
	isolated._on_touch_seen()
	return [viewport, isolated]


func test_dpad_tap_through_viewport_turns() -> void:
	var setup := _isolated_main()
	var viewport: SubViewport = setup[0]
	var game_main: Node2D = setup[1]
	var at := _arm(game_main.get_node("HUD/DPad"), Vector2i.UP)
	viewport.push_input(_finger(at, true), true)
	viewport.push_input(_finger(at, false), true)
	game_main.game.tick()
	assert_eq(game_main.game.direction, Vector2i.UP)  # and the key did turn the snake


func test_second_finger_works_on_dpad_through_viewport() -> void:
	var setup := _isolated_main()
	var viewport: SubViewport = setup[0]
	var game_main: Node2D = setup[1]
	viewport.push_input(_finger(Vector2(300, 300), true, 0), true)  # thumb resting on the board
	var at := _arm(game_main.get_node("HUD/DPad"), Vector2i.UP)
	viewport.push_input(_finger(at, true, 1), true)
	viewport.push_input(_finger(at, false, 1), true)
	viewport.push_input(_finger(Vector2(300, 300), false, 0), true)
	game_main.game.tick()
	assert_eq(game_main.game.direction, Vector2i.UP)


func test_pause_button_tap_through_viewport_pauses_once() -> void:
	var setup := _isolated_main()
	var viewport: SubViewport = setup[0]
	var game_main: Node2D = setup[1]
	var at: Vector2 = game_main.get_node("HUD/Pause").get_global_rect().get_center()
	viewport.push_input(_finger(at, true), true)
	viewport.push_input(_finger(at, false), true)
	assert_true(game_main.paused)


func test_emulated_mouse_click_is_ignored_by_dpad() -> void:
	var dpad = main.get_node("HUD/DPad")
	dpad.size = Vector2(240, 240)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.device = InputEvent.DEVICE_ID_EMULATION
	click.position = Vector2(120, 20)
	dpad._gui_input(click)
	main.game.tick()
	assert_eq(main.game.direction, Vector2i.RIGHT)


func _click(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.global_position = pos
	event.pressed = pressed
	return event


func test_menu_button_click_through_viewport() -> void:
	# A tap on a phone reaches buttons as this click (Godot turns the first finger into the mouse).
	var setup := _isolated_main()
	var viewport: SubViewport = setup[0]
	var game_main: Node2D = setup[1]
	game_main._handle_key(KEY_P)
	await wait_process_frames(1)  # let the card lay out
	var resume: Button = game_main._menu.buttons()[0]
	var at := resume.get_global_rect().get_center()
	viewport.push_input(_click(at, true), true)
	viewport.push_input(_click(at, false), true)
	assert_false(game_main.paused)


func test_dpad_highlight_follows_each_finger() -> void:
	var setup := _isolated_main()
	var viewport: SubViewport = setup[0]
	var dpad: Control = setup[1].get_node("HUD/DPad")
	var up := _arm(dpad, Vector2i.UP)
	var left := _arm(dpad, Vector2i.LEFT)
	viewport.push_input(_finger(up, true, 0), true)
	viewport.push_input(_finger(left, true, 1), true)
	assert_eq(dpad.lit(), Vector2i.LEFT)
	viewport.push_input(_finger(left, false, 1), true)
	assert_eq(dpad.lit(), Vector2i.UP)  # finger 0 still holds UP
	viewport.push_input(_finger(up, false, 0), true)
	assert_eq(dpad.lit(), Vector2i.ZERO)


func test_build_label_shows_which_build_this_is() -> void:
	var label: Label = main.get_node("HUD/Build")
	assert_eq(label.text, preload("res://presentation/build_info.gd").LABEL)
	assert_ne(label.text, "")


func test_gore_off_shows_nothing() -> void:
	var gore = main.get_node("Gore")
	gore.set_gore(false)
	gore.burst(Vector2(100, 100), 20, 200.0, 3)
	assert_eq(gore.active_count(), 0)
	assert_false(gore.is_active())


func test_switching_gore_off_wipes_the_blood() -> void:
	var gore = main.get_node("Gore")
	gore.burst(Vector2(100, 100), 20, 200.0, 2)
	assert_gt(gore.active_count(), 0)
	Settings.set_gore(false)
	assert_false(gore.gore)
	assert_eq(gore.active_count(), 0)


func test_death_splatter_keeps_flying_behind_the_end_card() -> void:
	main.game.lives = 1
	main.game.set_body([Vector2i(99, 50), Vector2i(98, 50), Vector2i(97, 50)])
	main._process(main.game.tick_interval() + 0.001)
	assert_eq(main.screen, main.Screen.OVER)
	assert_true(main.get_node("Gore").is_processing())
	main._handle_key(KEY_P)  # no pause menu over the end card
	assert_eq(main.screen, main.Screen.OVER)


func test_any_finger_presses_a_menu_button() -> void:
	main._handle_key(KEY_P)
	var resume: Button = main._menu.buttons()[0]
	resume.size = Vector2(200, 40)
	var touch := _finger(Vector2(20, 20), true, 1)  # second finger; the first rests elsewhere
	resume._gui_input(touch)
	assert_true(main.paused)  # pressing down alone does nothing
	resume._gui_input(_finger(Vector2(20, 20), false, 1))
	assert_false(main.paused)


func test_finger_slid_off_a_menu_button_does_not_press_it() -> void:
	main._handle_key(KEY_P)
	var resume: Button = main._menu.buttons()[0]
	resume.size = Vector2(200, 40)
	resume._gui_input(_finger(Vector2(20, 20), true))
	resume._gui_input(_finger(Vector2(20, 300), false))
	assert_true(main.paused)


func test_emulated_click_on_a_menu_button_is_ignored() -> void:
	main._handle_key(KEY_P)
	var resume: Button = main._menu.buttons()[0]
	resume.size = Vector2(200, 40)
	var click := _click(Vector2(20, 20), false)
	click.device = InputEvent.DEVICE_ID_EMULATION
	resume._gui_input(click)
	assert_true(main.paused)  # the touch itself already counted


func test_options_label_follows_window_changes() -> void:
	main.show_title()
	main._menu.press("Options")
	main._menu.buttons()[1].grab_focus()
	main._on_resized()
	assert_true(main._menu.buttons()[1].has_focus())
	assert_true(main.can_fullscreen())  # not an iPhone browser


func test_second_finger_presses_a_menu_button_through_viewport() -> void:
	var setup := _isolated_main()
	var viewport: SubViewport = setup[0]
	var game_main: Node2D = setup[1]
	game_main._handle_key(KEY_P)
	await wait_process_frames(1)  # let the card lay out
	var resume: Button = game_main._menu.buttons()[0]
	var at := resume.get_global_rect().get_center()
	viewport.push_input(_finger(Vector2(100, 600), true, 0), true)  # thumb resting on the board
	viewport.push_input(_finger(at, true, 1), true)
	assert_true(resume.has_theme_stylebox_override("normal"))  # shows pressed while held
	viewport.push_input(_finger(at, false, 1), true)
	assert_false(resume.has_theme_stylebox_override("normal"))
	assert_false(game_main.paused)
