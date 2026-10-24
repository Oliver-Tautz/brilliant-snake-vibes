## Player settings (spec §13), saved locally (browser storage in the web build). Autoloaded as Settings.
extends Node

signal changed

const PATH := "user://settings.cfg"

var path := PATH  ## overridden by tests
var gore := true  ## blood and bones; off swaps them for a dust puff and stars
var show_arrows := true  ## on-screen D-pad on touch screens


func _ready() -> void:
	load_settings()


## Reads the saved values. Missing file or wrong-typed values keep the defaults.
func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	var saved_gore: Variant = file.get_value("game", "gore", gore)
	if typeof(saved_gore) == TYPE_BOOL:
		gore = saved_gore
	var saved_arrows: Variant = file.get_value("game", "show_arrows", show_arrows)
	if typeof(saved_arrows) == TYPE_BOOL:
		show_arrows = saved_arrows


func set_gore(on: bool) -> void:
	gore = on
	save()
	changed.emit()


func set_show_arrows(shown: bool) -> void:
	show_arrows = shown
	save()
	changed.emit()


## Writes both values to path.
func save() -> void:
	var file := ConfigFile.new()
	file.set_value("game", "gore", gore)
	file.set_value("game", "show_arrows", show_arrows)
	file.save(path)
