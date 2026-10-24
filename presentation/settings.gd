## Player settings (spec §13), saved locally (browser storage in the web build). Autoloaded as Settings.
extends Node

signal changed

const PATH := "user://settings.cfg"
const MAX_SCORES := 10
const MAX_START_LEVEL := 10

var path := PATH  ## overridden by tests
var gore := true  ## blood, bones and stains; off shows no gore at all
var show_arrows := true  ## on-screen D-pad on touch screens
var start_level := 1  ## level a new run starts at (spec §5)
var view_fit := false  ## camera shows the whole arena instead of following the snake (spec §4)
var highscores: Array[Dictionary] = []  ## best first: {"score", "level", "date"}


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
	var saved_level: Variant = file.get_value("game", "start_level", start_level)
	if typeof(saved_level) == TYPE_INT:
		start_level = clampi(saved_level, 1, MAX_START_LEVEL)
	var saved_view: Variant = file.get_value("game", "view_fit", view_fit)
	if typeof(saved_view) == TYPE_BOOL:
		view_fit = saved_view
	var saved_table: Variant = file.get_value("scores", "table", [])
	highscores = []
	if typeof(saved_table) == TYPE_ARRAY:
		for entry: Variant in saved_table:
			if highscores.size() >= MAX_SCORES:
				break
			if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("score")) == TYPE_INT \
					and typeof(entry.get("level")) == TYPE_INT and typeof(entry.get("date")) == TYPE_STRING:
				highscores.append(entry)


## Records a score if it makes the top MAX_SCORES. Empty date means today.
## Returns the 0-based rank, or -1 if it did not make the table.
func add_score(score: int, level: int, date := "") -> int:
	if score <= 0:
		return -1
	var rank := 0
	while rank < highscores.size() and highscores[rank]["score"] >= score:
		rank += 1
	if rank >= MAX_SCORES:
		return -1
	var stamp: String = date if date != "" else Time.get_date_string_from_system()
	highscores.insert(rank, {"score": score, "level": level, "date": stamp})
	highscores.resize(mini(highscores.size(), MAX_SCORES))
	save()
	changed.emit()
	return rank


func set_gore(on: bool) -> void:
	gore = on
	save()
	changed.emit()


func set_show_arrows(shown: bool) -> void:
	show_arrows = shown
	save()
	changed.emit()


func set_start_level(level: int) -> void:
	start_level = clampi(level, 1, MAX_START_LEVEL)
	save()
	changed.emit()


func set_view_fit(on: bool) -> void:
	view_fit = on
	save()
	changed.emit()


## Writes both values to path.
func save() -> void:
	var file := ConfigFile.new()
	file.set_value("game", "gore", gore)
	file.set_value("game", "show_arrows", show_arrows)
	file.set_value("game", "start_level", start_level)
	file.set_value("game", "view_fit", view_fit)
	file.set_value("scores", "table", highscores)
	file.save(path)
