## Playable snake scene: runs SnakeGame on a timer, reacts to the input layer, and drives the views.
extends Node2D

const View := preload("res://presentation/view_config.gd")
const GRID_W := 100
const GRID_H := 100
const MAX_TICKS_PER_FRAME := 5
## Old Standard TT (SIL OFL 1.1), bundled so the web build gets the same period serif.
const SERIF := preload("res://presentation/fonts/OldStandard-Regular.ttf")
const BuildInfo := preload("res://presentation/build_info.gd")
const GITHUB := "https://github.com/Oliver-Tautz/brilliant-snake-vibes"
const VIOLENCE_NAMES := ["Full", "Low", "None"]

enum Screen { TITLE, PLAYING, PAUSED, OPTIONS, OVER }

var game: SnakeGame
var screen := Screen.TITLE
## True whenever the game is frozen: on the title, in a menu, or after the end.
var paused: bool:
	get:
		return screen != Screen.PLAYING

var _accumulator := 0.0
var _shake := 0.0
var _pending_eat := Vector2i(-1, -1)  # eaten prey, burst once the drawn head reaches it
# Last values shown in the HUD; text is only rebuilt when one changes.
var _hud_score := -1
var _hud_lives := -1
var _hud_length := -1
var _options_from := Screen.TITLE  # where Back in the options leads
var _touch_seen := DisplayServer.is_touchscreen_available()

@onready var _camera: Camera2D = $Camera2D
@onready var _floor: Node2D = $Floor
@onready var _gore: Node2D = $Gore
@onready var _world: Node2D = $World
@onready var _status: Label = $HUD/Status/Label
@onready var _menu: Control = $HUD/Menu
@onready var _controls: Node = $Controls
@onready var _dpad: Control = $HUD/DPad
@onready var _pause_button: Control = $HUD/Pause


func _ready() -> void:
	for label in [_status, $HUD/Build]:
		label.add_theme_font_override("font", SERIF)
	$HUD/Build.text = BuildInfo.LABEL
	_floor.size = Vector2(GRID_W, GRID_H) * View.CELL
	_camera.zoom = Vector2(View.ZOOM, View.ZOOM)
	var film := ($Film/Screen as ColorRect).material as ShaderMaterial
	film.set_shader_parameter("grain", Art.film_grain)  # seed[16]
	film.set_shader_parameter("flicker", Art.film_flicker)  # seed[17]
	film.set_shader_parameter("scratches", Art.film_scratches)  # seed[18]
	film.set_shader_parameter("vignette", Art.vignette)  # seed[19]
	_controls.turn.connect(_turn)
	_controls.pause_pressed.connect(_toggle_pause)
	_controls.perf_toggled.connect($PerfOverlay.toggle)
	_controls.touch_seen.connect(_on_touch_seen)
	_controls.attach(_dpad, _pause_button)
	Settings.changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_on_resized)
	_apply_settings()
	_new_game()
	show_title()


func _process(delta: float) -> void:
	if screen == Screen.PLAYING:
		_accumulator += delta
		var ticks := 0
		while _accumulator >= game.tick_interval() and ticks < MAX_TICKS_PER_FRAME:
			_accumulator -= game.tick_interval()
			var head_before := game.body[0]
			game.tick()
			_play_events(head_before)
			ticks += 1
		_accumulator = minf(_accumulator, game.tick_interval())
		if game.game_over:
			_show_over()
	_world.t = clampf(_accumulator / game.tick_interval(), 0.0, 1.0) if game.last_tick_moved else 1.0
	if _pending_eat.x >= 0 and _world.t >= 0.85:
		_burst_pending_eat()
	_world.eat_pulse = maxf(0.0, _world.eat_pulse - delta)
	_shake = maxf(0.0, _shake - delta)
	_camera.position = _world.snake_path()[0]
	_camera.offset = Vector2(randf() - 0.5, randf() - 0.5) * 18.0 * (_shake / View.SHAKE_TIME)
	_world.view_rect = _visible_rect()
	_world.queue_redraw()
	_update_hud()


## Gore for what happened on the last tick: a bloody gulp, or a violent crash.
func _play_events(head_before: Vector2i) -> void:
	if _pending_eat.x >= 0:  # a new tick started before the last gulp finished
		_burst_pending_eat()
	if game.last_eaten.x >= 0:
		_pending_eat = game.last_eaten
		_world.dying_prey = _pending_eat
	if game.last_life_lost:
		var crash := (View.center(head_before) + View.center(game.last_crash)) / 2.0
		_gore.burst(crash, 60, 420.0, 5)
		_shake = View.SHAKE_TIME


func _burst_pending_eat() -> void:
	play_eat_effect(_pending_eat)
	_pending_eat = Vector2i(-1, -1)
	_world.dying_prey = _pending_eat


func play_eat_effect(cell: Vector2i) -> void:
	_gore.burst(View.center(cell), 22, 260.0, 2)
	_world.eat_pulse = View.EAT_PULSE


## Keyboard shortcut kept for tests and tools; real input arrives through the Controls node.
func _handle_key(keycode: Key) -> void:
	_controls.handle_key(keycode)


## Esc, P or the pause button: pause and resume a run, or go back out of the options.
func _toggle_pause() -> void:
	match screen:
		Screen.PLAYING:
			_show_pause()
		Screen.PAUSED:
			resume()
		Screen.OPTIONS:
			_options_back()


func _turn(dir: Vector2i) -> void:
	if screen == Screen.PLAYING:
		game.request_turn(dir)


func show_title() -> void:
	_set_screen(Screen.TITLE)
	_menu.show_page("~ BRILLIANT SNAKE VIBES ~", [
		["Play", start_run],
		["Options", _show_options.bind(Screen.TITLE)],
		["GitHub", _open_github],
	])


## A fresh run, straight into play.
func start_run() -> void:
	_new_game()
	_set_screen(Screen.PLAYING)


func resume() -> void:
	_set_screen(Screen.PLAYING)


func _show_pause() -> void:
	_set_screen(Screen.PAUSED)
	_menu.show_page("~ INTERMISSION ~", [
		["Resume", resume],
		["Restart", start_run],
		["Options", _show_options.bind(Screen.PAUSED)],
		["Quit to menu", show_title],
		["GitHub", _open_github],
	])


func _show_over() -> void:
	_set_screen(Screen.OVER)
	_menu.show_page("~ THE END ~\nScore  %d" % game.score, [
		["Restart", start_run],
		["Menu", show_title],
	])


func _show_options(from: Screen, focus := 0) -> void:
	_options_from = from
	_set_screen(Screen.OPTIONS)
	var items := [
		["Violence: %s" % VIOLENCE_NAMES[Settings.violence], _next_violence],
		["Arrows on touch: %s" % ("Shown" if Settings.show_arrows else "Hidden"), _toggle_arrows],
	]
	if can_fullscreen():
		items.append(["Fullscreen: %s" % ("On" if is_fullscreen() else "Off"), _toggle_fullscreen])
	items.append(["Back", _options_back])
	_menu.show_page("~ OPTIONS ~", items, focus)


func _next_violence() -> void:
	Settings.set_violence((Settings.violence + 1) % VIOLENCE_NAMES.size())
	_show_options(_options_from, 0)


func _toggle_arrows() -> void:
	Settings.set_show_arrows(not Settings.show_arrows)
	_show_options(_options_from, 1)


## Not saved: browsers only allow fullscreen right after a click or tap, so it cannot be restored on load.
func _toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_show_options(_options_from, 2)


## iPhone browsers have no fullscreen for a game canvas, so the option is left out there.
func can_fullscreen() -> bool:
	return not OS.has_feature("web_ios")


## Leaving fullscreen with the browser's own Esc resizes the window; keep the options label honest.
func _on_resized() -> void:
	if screen == Screen.OPTIONS:
		_show_options(_options_from, _menu.focused_index())


func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _options_back() -> void:
	if _options_from == Screen.PAUSED:
		_show_pause()
	else:
		show_title()


func _open_github() -> void:
	OS.shell_open(GITHUB)


## Switches screens: the menu card shows for everything but play, gore freezes in the pause menus, and the
## pause button and D-pad only show during a run.
func _set_screen(next: Screen) -> void:
	screen = next
	_menu.visible = next != Screen.PLAYING
	if next == Screen.PLAYING:
		get_viewport().gui_release_focus()
	_gore.set_process(next != Screen.PAUSED and next != Screen.OPTIONS)  # a death splatter still lands
	_pause_button.visible = next == Screen.PLAYING or next == Screen.PAUSED
	_update_dpad()


func _on_touch_seen() -> void:
	_touch_seen = true
	_update_dpad()


func _update_dpad() -> void:
	_dpad.visible = _touch_seen and Settings.show_arrows and screen == Screen.PLAYING


func _apply_settings() -> void:
	_gore.set_violence(Settings.violence)
	_update_dpad()


func _new_game() -> void:
	game = SnakeGame.new(GRID_W, GRID_H, Time.get_ticks_usec())
	_world.game = game
	_gore.clear()
	_pending_eat = Vector2i(-1, -1)
	_world.dying_prey = _pending_eat
	_accumulator = 0.0
	_world.t = 1.0
	_camera.position = View.center(game.body[0])
	_update_hud()


func _update_hud() -> void:
	var length := game.body.size()
	if game.score == _hud_score and game.lives == _hud_lives and length == _hud_length:
		return
	_hud_score = game.score
	_hud_lives = game.lives
	_hud_length = length
	_status.text = "SCORE  %d     LIVES  %d     LENGTH  %d" % [game.score, game.lives, length]


func _visible_rect() -> Rect2:
	var size := get_viewport_rect().size / _camera.zoom
	return Rect2(_camera.get_screen_center_position() - size / 2.0, size).grow(View.CELL)
