## Player settings (spec §13), saved locally (browser storage in the web build). Autoloaded as Settings.
extends Node

signal changed

const PATH := "user://settings.cfg"
const MAX_SCORES := 10
const MAX_START_LEVEL := 10
const MAX_NAME := 12

var path := PATH  ## overridden by tests
var gore := true  ## blood, bones and stains; off shows no gore at all
var show_arrows := true  ## on-screen D-pad on touch screens
var start_level := 1  ## level a new run starts at (spec §5)
var view_fit := true  ## camera shows the whole arena instead of following the snake (spec §4)
var sharp := true  ## draw at the screen's own resolution; off renders at the base size and scales up (faster on weak graphics)
var music_volume := 100  ## percent, 0 to 100
var sound_volume := 100  ## percent, 0 to 100, for sound effects
var muted := false
var player_name := ""  ## last name typed for a highscore, offered again next time
var highscores: Array[Dictionary] = []  ## best first: {"score", "level", "date", "name"}


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
	var saved_sharp: Variant = file.get_value("game", "sharp", sharp)
	if typeof(saved_sharp) == TYPE_BOOL:
		sharp = saved_sharp
	var saved_music: Variant = file.get_value("audio", "music_volume", music_volume)
	if typeof(saved_music) == TYPE_INT:
		music_volume = clampi(saved_music, 0, 100)
	var saved_sound: Variant = file.get_value("audio", "sound_volume", sound_volume)
	if typeof(saved_sound) == TYPE_INT:
		sound_volume = clampi(saved_sound, 0, 100)
	var saved_muted: Variant = file.get_value("audio", "muted", muted)
	if typeof(saved_muted) == TYPE_BOOL:
		muted = saved_muted
	var saved_name: Variant = file.get_value("game", "player_name", player_name)
	if typeof(saved_name) == TYPE_STRING:
		player_name = _clean_name(saved_name)
	var saved_table: Variant = file.get_value("scores", "table", [])
	highscores = []
	if typeof(saved_table) == TYPE_ARRAY:
		for entry: Variant in saved_table:
			if highscores.size() >= MAX_SCORES:
				break
			if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("score")) == TYPE_INT \
					and typeof(entry.get("level")) == TYPE_INT and typeof(entry.get("date")) == TYPE_STRING:
				var saved_entry_name: Variant = entry.get("name")
				var entry_name := _clean_name(saved_entry_name) if typeof(saved_entry_name) == TYPE_STRING else ""
				highscores.append({"score": entry["score"], "level": entry["level"], "date": entry["date"], "name": entry_name})


## 0-based rank add_score would give this score, or -1 if it would not make the table. Changes nothing.
func rank_for(score: int) -> int:
	if score <= 0:
		return -1
	var rank := 0
	while rank < highscores.size() and highscores[rank]["score"] >= score:
		rank += 1
	if rank >= MAX_SCORES:
		return -1
	return rank


## Records a score if it makes the top MAX_SCORES. Empty date means today.
## Returns the 0-based rank, or -1 if it did not make the table.
func add_score(score: int, level: int, date := "", name := "") -> int:
	var rank := rank_for(score)
	if rank < 0:
		return -1
	var stamp: String = date if date != "" else Time.get_date_string_from_system()
	highscores.insert(rank, {"score": score, "level": level, "date": stamp, "name": _clean_name(name)})
	highscores.resize(mini(highscores.size(), MAX_SCORES))
	save()
	changed.emit()
	return rank


## Remembers the name typed for a highscore, cleaned like entry names.
func set_player_name(name: String) -> void:
	player_name = _clean_name(name)
	save()
	changed.emit()


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


func set_sharp(on: bool) -> void:
	sharp = on
	save()
	changed.emit()


func set_music_volume(percent: int) -> void:
	music_volume = clampi(percent, 0, 100)
	save()
	changed.emit()


func set_sound_volume(percent: int) -> void:
	sound_volume = clampi(percent, 0, 100)
	save()
	changed.emit()


func set_muted(on: bool) -> void:
	muted = on
	save()
	changed.emit()


## Trims and caps a name at MAX_NAME characters.
func _clean_name(raw: String) -> String:
	return raw.strip_edges().left(MAX_NAME)


## Writes all settings and the highscores to path.
func save() -> void:
	var file := ConfigFile.new()
	file.set_value("game", "gore", gore)
	file.set_value("game", "player_name", player_name)
	file.set_value("game", "show_arrows", show_arrows)
	file.set_value("game", "start_level", start_level)
	file.set_value("game", "view_fit", view_fit)
	file.set_value("game", "sharp", sharp)
	file.set_value("audio", "music_volume", music_volume)
	file.set_value("audio", "sound_volume", sound_volume)
	file.set_value("audio", "muted", muted)
	file.set_value("scores", "table", highscores)
	file.save(path)
