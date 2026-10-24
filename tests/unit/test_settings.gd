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
	assert_eq(settings.violence, SettingsScript.Violence.FULL)
	assert_true(settings.show_arrows)


func test_changes_are_saved_and_loaded_again() -> void:
	settings.set_violence(SettingsScript.Violence.NONE)
	settings.set_show_arrows(false)
	var fresh := _reloaded()
	assert_eq(fresh.violence, SettingsScript.Violence.NONE)
	assert_false(fresh.show_arrows)


func test_changes_emit_changed() -> void:
	watch_signals(settings)
	settings.set_violence(SettingsScript.Violence.LOW)
	settings.set_show_arrows(false)
	assert_signal_emit_count(settings, "changed", 2)


func test_out_of_range_violence_is_clamped() -> void:
	settings.set_violence(7)
	assert_eq(settings.violence, SettingsScript.Violence.NONE)
	settings.set_violence(-3)
	assert_eq(settings.violence, SettingsScript.Violence.FULL)


func test_corrupt_saved_values_fall_back_to_defaults() -> void:
	var file := ConfigFile.new()
	file.set_value("game", "violence", "lots")
	file.set_value("game", "show_arrows", 12)
	file.save(TEST_PATH)
	var fresh := _reloaded()
	assert_eq(fresh.violence, SettingsScript.Violence.FULL)
	assert_true(fresh.show_arrows)


func test_autoload_is_registered() -> void:
	assert_not_null(get_tree().root.get_node_or_null("Settings"))
