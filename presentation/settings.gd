## Player settings (spec §13), saved locally (browser storage in the web build). Autoloaded as Settings.
extends Node

signal changed

enum Violence { FULL, LOW, NONE }

const PATH := "user://settings.cfg"

var path := PATH  ## overridden by tests
var violence: int = Violence.FULL
var show_arrows := true  ## on-screen D-pad on touch screens


func _ready() -> void:
	load_settings()


## Reads the saved values. Missing file or wrong-typed values keep the defaults.
func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	var saved_violence: Variant = file.get_value("game", "violence", violence)
	if typeof(saved_violence) == TYPE_INT:
		violence = clampi(saved_violence, Violence.FULL, Violence.NONE)
	var saved_arrows: Variant = file.get_value("game", "show_arrows", show_arrows)
	if typeof(saved_arrows) == TYPE_BOOL:
		show_arrows = saved_arrows


func set_violence(level: int) -> void:
	violence = clampi(level, Violence.FULL, Violence.NONE)
	save()
	changed.emit()


func set_show_arrows(shown: bool) -> void:
	show_arrows = shown
	save()
	changed.emit()


## Writes both values to path.
func save() -> void:
	var file := ConfigFile.new()
	file.set_value("game", "violence", violence)
	file.set_value("game", "show_arrows", show_arrows)
	file.save(path)
