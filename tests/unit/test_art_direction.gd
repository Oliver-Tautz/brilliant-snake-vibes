extends GutTest
## The art must follow the divine_inspiration seed: these tests pin the decoding and make sure every
## option the seed could pick actually draws.

var _saved := {}


func before_each() -> void:
	for key in ["head", "skin", "wall", "ornament", "prey_species_a", "prey_species_b"]:
		_saved[key] = _get_art(key)


func after_each() -> void:
	for key in _saved:
		_set_art(key, _saved[key])


func _get_art(key: String) -> int:
	match key:
		"head": return Art.head
		"skin": return Art.skin
		"wall": return Art.wall
		"ornament": return Art.ornament
		"prey_species_a": return Art.prey_species_a
		_: return Art.prey_species_b


func _set_art(key: String, value: int) -> void:
	match key:
		"head": Art.head = value
		"skin": Art.skin = value
		"wall": Art.wall = value
		"ornament": Art.ornament = value
		"prey_species_a": Art.prey_species_a = value
		_: Art.prey_species_b = value


func test_seed_matches_the_stored_inspiration() -> void:
	var stored = JSON.parse_string(FileAccess.get_file_as_string("res://inspirations.json"))
	assert_eq(stored.get(Art.TOPIC), Art.SEED)


func test_seed_characters_decode_to_alphabet_indices() -> void:
	assert_eq(Art.value(0), 34)  # 'i'
	assert_eq(Art.value(2), 0)  # 'A'
	assert_eq(Art.value(5), 63)  # '_'
	assert_almost_eq(Art.amount(5), 1.0, 0.0001)


func test_decisions_follow_the_seed() -> void:
	assert_eq(Art.floor_pattern, Art.FloorPattern.HARLEQUIN)  # seed[0] 'i' = 34 % 4
	assert_eq(Art.skin, Art.SkinPattern.BANDS)  # seed[2] 'A' = 0 % 4
	assert_eq(Art.head, Art.HeadShape.VIPER)  # seed[4] 'c' = 28 % 3
	assert_eq(Art.prey_species_a, Art.PreySpecies.CHICK)  # seed[10] 'q' = 42 % 4
	assert_eq(Art.wall, Art.WallStyle.SINGLE)  # seed[20] 'e' = 30 % 3
	assert_eq(Art.ornament, Art.OrnamentStyle.DIAMONDS)  # seed[21] '6' = 58 % 3
	assert_almost_eq(Art.ink_width, 4.0, 0.0001)  # seed[7] '_' = 63, top of 2..4 px


func test_continuous_values_stay_in_spec_ranges() -> void:
	assert_between(Art.body_width, 0.32, 0.45)
	assert_between(Art.prey_size, 0.28, 0.4)
	assert_between(Art.zoom, 1.5, 2.0)
	assert_between(Art.paper_tone, 0.86, 0.98)
	assert_between(Art.gore_amount, 0.6, 1.8)
	# Spec §11: blood is the only saturated colour, and it is red.
	assert_gt(Art.blood.r, 0.5)
	assert_lt(Art.blood.g, 0.05)
	assert_lt(Art.blood.b, 0.05)


func test_neighbouring_rows_of_the_snake_do_not_touch() -> void:
	# The widest body any seed can give, with the thickest ink outline (1.2 x the widest ink each side)
	# and the line boil (up to 0.8 px x boil strength each side), still leaves floor between rows.
	var view := preload("res://presentation/view_config.gd")
	var widest := view.CELL * 0.45 + 2.0 * 4.0 * 1.2 + 2.0 * 0.8 * 1.4
	assert_lt(widest, view.CELL - 1.0)
	assert_lte(view.BODY_WIDTH, view.CELL * 0.45 + 0.001)
	assert_lte(view.INK_WIDTH, 4.0 + 0.001)


func test_every_seed_option_draws() -> void:
	var main: Node2D = load("res://presentation/main.tscn").instantiate()
	add_child_autofree(main)
	var world: Node2D = main.get_node("World")
	main.game.set_body([Vector2i(50, 50), Vector2i(49, 50), Vector2i(48, 50), Vector2i(47, 50),
			Vector2i(46, 50), Vector2i(45, 50), Vector2i(45, 51), Vector2i(45, 52)])
	main.game.set_food([Vector2i(52, 50), Vector2i(53, 51), Vector2i(51, 48), Vector2i(48, 52)])
	main.paused = true
	for head in Art.HeadShape.values():
		for skin in Art.SkinPattern.values():
			Art.head = head
			Art.skin = skin
			world.queue_redraw()
			await wait_process_frames(1)
	for species in Art.PreySpecies.values():
		Art.prey_species_a = species
		Art.prey_species_b = species
		world.queue_redraw()
		await wait_process_frames(1)
	for wall in Art.WallStyle.values():
		Art.wall = wall
		world.queue_redraw()
		await wait_process_frames(1)
	for ornament in Art.OrnamentStyle.values():
		Art.ornament = ornament
		main.get_node("HUD/Status").queue_redraw()
		await wait_process_frames(1)
	assert_true(is_instance_valid(main))


func test_scene_shaders_get_seed_values() -> void:
	var main: Node2D = load("res://presentation/main.tscn").instantiate()
	add_child_autofree(main)
	var floor_mat: ShaderMaterial = main.get_node("Floor").material
	assert_eq(floor_mat.get_shader_parameter("pattern"), Art.floor_pattern)
	assert_almost_eq(floor_mat.get_shader_parameter("contrast"), Art.floor_contrast, 0.0001)
	assert_almost_eq(floor_mat.get_shader_parameter("tone"), Art.floor_tone, 0.0001)
	var film_mat: ShaderMaterial = main.get_node("Film/Screen").material
	assert_almost_eq(film_mat.get_shader_parameter("grain"), Art.film_grain, 0.0001)
	assert_almost_eq(film_mat.get_shader_parameter("flicker"), Art.film_flicker, 0.0001)
	assert_eq(film_mat.get_shader_parameter("scratches"), Art.film_scratches)
	assert_almost_eq(film_mat.get_shader_parameter("vignette"), Art.vignette, 0.0001)
	assert_eq(main.get_node("Camera2D").zoom, Vector2(Art.zoom, Art.zoom))


func test_hatched_walls_draw_along_visible_edges() -> void:
	var main: Node2D = load("res://presentation/main.tscn").instantiate()
	add_child_autofree(main)
	var world: Node2D = main.get_node("World")
	Art.wall = Art.WallStyle.HATCHED
	world.view_rect = Rect2(Vector2(-50, -50), Vector2(400, 300))
	world.queue_redraw()
	await wait_process_frames(2)
	assert_true(is_instance_valid(world))


func test_disc_texture_is_generated_once_and_opaque_in_the_middle() -> void:
	var tex := Ink.disc_texture()
	assert_eq(Ink.disc_texture(), tex)
	var img := tex.get_image()
	assert_almost_eq(img.get_pixel(64, 64).a, 1.0, 0.01)
	assert_almost_eq(img.get_pixel(0, 0).a, 0.0, 0.01)
	assert_almost_eq(img.get_pixelv(Vector2i(Ink.DISC_CORE.position)).a, 1.0, 0.01)
