extends GutTest

const SettingsScript := preload("res://presentation/settings.gd")
const TEST_PATH := "user://test_settings.cfg"

var settings: Node


func before_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	settings = SettingsScript.new()
	settings.path = TEST_PATH
	add_child_autofree(settings)


func after_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)


func _reloaded() -> Node:
	var fresh: Node = SettingsScript.new()
	fresh.path = TEST_PATH
	add_child_autofree(fresh)
	fresh.load_settings()
	return fresh


func test_defaults_when_nothing_saved() -> void:
	settings.load_settings()
	assert_true(settings.gore)
	assert_true(settings.show_arrows)


func test_changes_are_saved_and_loaded_again() -> void:
	settings.set_gore(false)
	settings.set_show_arrows(false)
	var fresh := _reloaded()
	assert_false(fresh.gore)
	assert_false(fresh.show_arrows)


func test_changes_emit_changed() -> void:
	watch_signals(settings)
	settings.set_gore(false)
	settings.set_show_arrows(false)
	assert_signal_emit_count(settings, "changed", 2)


func test_corrupt_saved_values_fall_back_to_defaults() -> void:
	var file := ConfigFile.new()
	file.set_value("game", "gore", "lots")
	file.set_value("game", "show_arrows", 12)
	file.save(TEST_PATH)
	var fresh := _reloaded()
	assert_true(fresh.gore)
	assert_true(fresh.show_arrows)


func test_autoload_is_registered() -> void:
	assert_not_null(get_tree().root.get_node_or_null("Settings"))


func test_highscores_start_empty() -> void:
	settings.load_settings()
	assert_eq(settings.highscores.size(), 0)


func test_add_score_keeps_top_ten_sorted_and_returns_rank() -> void:
	for i in 10:
		settings.add_score((i + 1) * 10, 1, "2026-01-01")
	assert_eq(settings.highscores.size(), 10)
	assert_eq(settings.highscores[0]["score"], 100)
	assert_eq(settings.add_score(55, 3, "2026-01-02"), 5)  # between 60 and 50
	assert_eq(settings.highscores.size(), 10)
	assert_eq(settings.highscores[9]["score"], 20)  # 10 dropped off the end
	assert_eq(settings.add_score(5, 1, "2026-01-02"), -1)  # too low to enter
	assert_eq(settings.highscores[5], {"score": 55, "level": 3, "date": "2026-01-02"})


func test_equal_score_ranks_below_the_older_entry() -> void:
	settings.add_score(50, 1, "old")
	assert_eq(settings.add_score(50, 2, "new"), 1)


func test_zero_score_is_not_recorded() -> void:
	assert_eq(settings.add_score(0, 1, "2026-01-01"), -1)
	assert_eq(settings.highscores.size(), 0)


func test_add_score_uses_todays_date_by_default() -> void:
	settings.add_score(10, 1)
	assert_eq(settings.highscores[0]["date"], Time.get_date_string_from_system())


func test_highscores_are_saved_and_loaded_again() -> void:
	settings.add_score(30, 2, "2026-01-01")
	settings.add_score(70, 4, "2026-01-03")
	var fresh := _reloaded()
	assert_eq(fresh.highscores.size(), 2)
	assert_eq(fresh.highscores[0], {"score": 70, "level": 4, "date": "2026-01-03"})


func test_corrupt_highscores_are_dropped() -> void:
	var file := ConfigFile.new()
	file.set_value("scores", "table", [{"score": 40, "level": 2, "date": "x"}, "junk", {"score": "a"}, 7])
	file.save(TEST_PATH)
	var fresh := _reloaded()
	assert_eq(fresh.highscores.size(), 1)
	assert_eq(fresh.highscores[0]["score"], 40)
	file.set_value("scores", "table", "not a list")
	file.save(TEST_PATH)
	assert_eq(_reloaded().highscores.size(), 0)


func test_start_level_and_view_default_and_round_trip() -> void:
	settings.load_settings()
	assert_eq(settings.start_level, 1)
	assert_false(settings.view_fit)
	settings.set_start_level(4)
	settings.set_view_fit(true)
	var fresh := _reloaded()
	assert_eq(fresh.start_level, 4)
	assert_true(fresh.view_fit)


func test_start_level_is_clamped_to_one_to_ten() -> void:
	settings.set_start_level(0)
	assert_eq(settings.start_level, 1)
	settings.set_start_level(15)
	assert_eq(settings.start_level, 10)


func test_start_level_and_view_emit_changed() -> void:
	watch_signals(settings)
	settings.set_start_level(2)
	settings.set_view_fit(true)
	assert_signal_emit_count(settings, "changed", 2)


func test_bad_saved_start_level_and_view_fall_back() -> void:
	var file := ConfigFile.new()
	file.set_value("game", "start_level", 99)
	file.set_value("game", "view_fit", "yes")
	file.save(TEST_PATH)
	var fresh := _reloaded()
	assert_eq(fresh.start_level, 10)
	assert_false(fresh.view_fit)
	file.set_value("game", "start_level", "x")
	file.save(TEST_PATH)
	assert_eq(_reloaded().start_level, 1)


func test_audio_settings_default_and_round_trip() -> void:
	settings.load_settings()
	assert_eq(settings.music_volume, 100)
	assert_eq(settings.sound_volume, 100)
	assert_false(settings.muted)
	settings.set_music_volume(25)
	settings.set_sound_volume(50)
	settings.set_muted(true)
	var fresh := _reloaded()
	assert_eq(fresh.music_volume, 25)
	assert_eq(fresh.sound_volume, 50)
	assert_true(fresh.muted)


func test_volumes_are_clamped_to_zero_to_hundred() -> void:
	settings.set_music_volume(-10)
	assert_eq(settings.music_volume, 0)
	settings.set_sound_volume(250)
	assert_eq(settings.sound_volume, 100)


func test_audio_settings_emit_changed() -> void:
	watch_signals(settings)
	settings.set_music_volume(75)
	settings.set_sound_volume(75)
	settings.set_muted(true)
	assert_signal_emit_count(settings, "changed", 3)


func test_bad_saved_audio_settings_fall_back() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music_volume", "loud")
	file.set_value("audio", "sound_volume", 400)
	file.set_value("audio", "muted", 1)
	file.save(TEST_PATH)
	var fresh := _reloaded()
	assert_eq(fresh.music_volume, 100)
	assert_eq(fresh.sound_volume, 100)
	assert_false(fresh.muted)
