## Playable snake scene: runs SnakeGame on a timer, reacts to the input layer, and drives the views.
extends Node2D

const View := preload("res://presentation/view_config.gd")
const Cfg := preload("res://logic/game_config.gd")
const MAX_TICKS_PER_FRAME := 5
const HUD_BAND := 76.0  # base pixels the status bar covers at the top of the screen
const HITSTOP := 0.09  # seconds the game freezes when an enemy dies: a cartoon "smack"
## Shouted when the combo multiplier reaches each level (with Gore off the bloodier ones are softened).
const COMBO_NAMES := {2: "CHOMP", 3: "GOBBLE", 4: "GLUTTON", 5: "MASSACRE", 6: "CARNAGE", 7: "BLOODBATH", 8: "APOCALYPSE"}
const SOFT_NAMES := {5: "FEAST", 6: "BANQUET", 7: "STAMPEDE", 8: "APOCALYPSE"}
const FRENZY_FLASH: Array[Color] = [Color(0.78, 0.02, 0.03), Color(0.62, 0.78, 0.42), Color(0.47, 0.34, 0.5)]
## Old Standard TT (SIL OFL 1.1), bundled so the web build gets the same period serif.
const SERIF := preload("res://presentation/fonts/OldStandard-Regular.ttf")
const BuildInfo := preload("res://presentation/build_info.gd")
const GITHUB := "https://github.com/Oliver-Tautz/brilliant-snake-vibes"

enum Screen { TITLE, PLAYING, PAUSED, OPTIONS, OVER, BREAK }  # BREAK: level cleared or time up

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
var _hud_extra := -1  # level, seconds left and foes left, packed into one number
var _options_from := Screen.TITLE  # where Back in the options leads
var _last_tick := -1  # last whole second of the level timer that ticked
var _hitstop := 0.0
var _last_multiplier := 1
var _was_frenzy := false
var _shout: Label
var _shout_tween: Tween
var _chain: Label
var _flash: ColorRect
var _chain_key := -1  # combo, multiplier and tenths of frenzy shown, packed; text is rebuilt only on change
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
	_build_juice()
	_apply_settings()
	_new_game()
	show_title()


## The extra HUD pieces for combos and frenzies: a shouted intertitle, a chain counter under the
## status bar and a full-screen colour flash (under the menus and the film grain).
func _build_juice() -> void:
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.visible = false
	$HUD.add_child(_flash)
	$HUD.move_child(_flash, 0)
	_shout = Label.new()
	_shout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_shout.offset_top = 110.0
	_shout.offset_left = -400.0
	_shout.offset_right = 400.0
	_shout.pivot_offset = Vector2(400.0, 30.0)
	_shout.add_theme_font_override("font", SERIF)
	_shout.add_theme_font_size_override("font_size", 46)
	_shout.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03))
	_shout.add_theme_constant_override("outline_size", 12)
	_shout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shout.modulate.a = 0.0
	$HUD.add_child(_shout)
	_chain = Label.new()
	_chain.position = Vector2(24.0, 70.0)
	_chain.add_theme_font_override("font", SERIF)
	_chain.add_theme_font_size_override("font_size", 24)
	_chain.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03))
	_chain.add_theme_constant_override("outline_size", 8)
	_chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_chain)


## A big intertitle shout that pops in and fades.
func shout(text: String) -> void:
	_shout.text = text
	if _shout_tween:
		_shout_tween.kill()
	_shout.modulate.a = 1.0
	_shout.scale = Vector2(1.5, 1.5)
	_shout_tween = create_tween()
	_shout_tween.tween_property(_shout, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shout_tween.tween_interval(0.7)
	_shout_tween.tween_property(_shout, "modulate:a", 0.0, 0.4)


func shout_text() -> String:
	return _shout.text if _shout.modulate.a > 0.0 else ""


func _process(delta: float) -> void:
	_hitstop = maxf(0.0, _hitstop - delta)
	if screen == Screen.PLAYING and _hitstop <= 0.0:
		_accumulator += delta
		var ticks := 0
		while _accumulator >= game.tick_interval() and ticks < MAX_TICKS_PER_FRAME:
			_accumulator -= game.tick_interval()
			var head_before := game.body[0]
			game.tick()
			_play_events(head_before)
			ticks += 1
		_accumulator = minf(_accumulator, game.tick_interval())
		if not game.game_over:
			game.advance(delta)
			_play_clock_events()
		if game.game_over:
			_show_over()
		elif game.level_won:
			Sound.play(&"fanfare")
			_show_break("~ LEVEL %d CLEARED ~" % game.level, "Next level", _next_level)
		elif game.last_time_up:
			Sound.play(&"gong")
			_show_break("~ TIME'S UP ~\nThe level starts over", "Continue", resume)
		else:
			_tick_last_seconds()
	_world.t = clampf(_accumulator / game.tick_interval(), 0.0, 1.0) if game.last_tick_moved else 1.0
	if _pending_eat.x >= 0 and _world.t >= 0.85:
		_burst_pending_eat()
	_world.eat_pulse = maxf(0.0, _world.eat_pulse - delta)
	_shake = maxf(0.0, _shake - delta)
	_aim_camera()
	_camera.offset = Vector2(randf() - 0.5, randf() - 0.5) * 18.0 * (_shake / View.SHAKE_TIME)
	_world.view_rect = _visible_rect()
	_world.show_markers = Settings.view_fit
	_world.age_popups(delta)
	_update_frenzy_look()
	_world.marker_scale = 1.0 / _camera.zoom.x
	_world.queue_redraw()
	_update_hud()


## Gore for what happened on the last tick: a bloody gulp, or a violent crash.
func _play_events(head_before: Vector2i) -> void:
	if _pending_eat.x >= 0:  # a new tick started before the last gulp finished
		_burst_pending_eat()
	if game.last_eaten.x >= 0:
		Sound.play(&"chime", -9.0, 0.0, 1.0 + 0.05 * mini(game.combo, 16))
		_pending_eat = game.last_eaten
		_world.dying_prey = _pending_eat
		_world.dying_kind = game.last_eaten_kind
	if game.last_life_lost:
		var crash := (View.center(head_before) + View.center(game.last_crash)) / 2.0
		_gore.burst(crash, 60, 420.0, 5)
		_shake = View.SHAKE_TIME
		_play_crash_sounds()


func _play_crash_sounds() -> void:
	Sound.play(&"crash")
	Sound.play(&"splat")
	Sound.play(&"life_lost", -3.0, 0.0)


## A clock tick for each of the last 10 seconds of a level (spec §10).
func _tick_last_seconds() -> void:
	var seconds := int(ceilf(game.time_left()))
	if game.level > 0 and seconds <= 10 and seconds != _last_tick:
		Sound.play(&"tick", 0.0, 0.0)
	_last_tick = seconds


## Gore for what happened on the enemies' and the level's own clock: enemy deaths (also those from
## the player's ticks), the player bitten or out of time.
func _play_clock_events() -> void:
	_play_score_events()
	for cell in game.enemy_deaths:
		_gore.burst(View.center(cell), 50, 380.0, 4)
		_shake = View.SHAKE_TIME * 0.8
		_hitstop = HITSTOP
		Sound.play(&"enemy_die")
		Sound.play(&"splat")
	game.enemy_deaths.clear()
	if game.last_hop.x >= 0 and _world.view_rect.has_point(View.center(game.last_hop)):
		Sound.play(&"squawk", -6.0, 0.15)
	if game.last_time_up:
		_on_level_started()
	elif game.last_life_lost:
		_gore.burst(View.center(game.last_crash), 60, 420.0, 5)
		_shake = View.SHAKE_TIME
		_play_crash_sounds()


## Floating scores, shouted combo levels and the start of a frenzy.
func _play_score_events() -> void:
	for p in game.popups:
		_world.add_popup(View.center(p[0]), "+%d" % p[1])
	game.popups.clear()
	var m := game.multiplier()
	if m > _last_multiplier and m > 1:
		var names: Dictionary = COMBO_NAMES if Settings.gore else COMBO_NAMES.merged(SOFT_NAMES, true)
		shout("%s  x%d!" % [names[m], m])
	_last_multiplier = m
	if game.frenzy_started:
		game.frenzy_started = false
		shout("~ FRENZY! ~")
		Sound.play(&"fanfare", 0.0, 0.0, 1.5)


## During a frenzy: the screen flashes in the accent colours, enemies flash and panic, the music
## races; a chain counter shows under the status bar.
func _update_frenzy_look() -> void:
	var frenzy := game.in_frenzy() and screen == Screen.PLAYING
	_world.frenzy = game.in_frenzy()
	_flash.visible = frenzy
	if frenzy:
		var k := int(Time.get_ticks_msec() / 110) % FRENZY_FLASH.size()
		var ending := game.frenzy_time < 1.5 and int(Time.get_ticks_msec() / 200) % 2 == 0
		_flash.color = Color(FRENZY_FLASH[k], 0.0 if ending else 0.2)
	if frenzy != _was_frenzy and screen == Screen.PLAYING:
		Sound.play_music(&"game", _game_music_pitch() * (1.2 if frenzy else 1.0))
	_was_frenzy = frenzy
	var key := int(game.frenzy_time * 10.0) * 100000 + game.combo * 10 + game.multiplier()
	if key == _chain_key:
		return
	_chain_key = key
	if game.in_frenzy():
		_chain.text = "FRENZY  %.1f" % game.frenzy_time
	elif game.combo > 1:
		_chain.text = "CHAIN  %d     x%d" % [game.combo, game.multiplier()]
	else:
		_chain.text = ""


func _game_music_pitch() -> float:
	return minf(1.3, 1.0 + 0.03 * maxi(0, game.level - 1))


func _burst_pending_eat() -> void:
	play_eat_effect(_pending_eat)
	_pending_eat = Vector2i(-1, -1)
	_world.dying_prey = _pending_eat


func play_eat_effect(cell: Vector2i) -> void:
	_gore.burst(View.center(cell), 22, 260.0, 2)
	Sound.play(&"gulp")
	Sound.play(&"crunch", -4.0)
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


func show_title(focus := 0) -> void:
	_set_screen(Screen.TITLE)
	_menu.show_page("~ BRILLIANT SNAKE VIBES ~", [
		["Play", start_run],
		["How to play", _show_how_to],
		["Gore: %s" % ("On" if Settings.gore else "Off"), _toggle_gore_on_title],
		["Highscores", _show_highscores],
		["Options", _show_options.bind(Screen.TITLE)],
		["GitHub", _open_github],
	], focus)


func _toggle_gore_on_title() -> void:
	Settings.set_gore(not Settings.gore)
	show_title(2)


func _show_highscores() -> void:
	_set_screen(Screen.TITLE)
	_menu.show_page("~ HIGHSCORES ~", [["Back", show_title.bind(3)]], 0, score_table())


const HOW_TO := """Steer with the arrow keys or WASD, by swiping, or with the on-screen arrows.
Eat chickens to grow. Orange ones make you grow three times as much.
Eat again quickly to chain meals: the multiplier climbs, and a long chain sets off a FRENZY.
In a frenzy you are faster, the enemies panic, and a bite anywhere kills them.
Kill all three enemy snakes before the clock runs out to clear the level.
Bite an enemy's glowing head from the side to kill it.
Face to face, the longer snake wins.
Walls, bodies and running out of time cost a life.
Each level the enemies get faster and the arena smaller.
Esc or P pauses."""


func _show_how_to() -> void:
	_set_screen(Screen.TITLE)
	_menu.show_page("~ HOW TO PLAY ~", [["Back", show_title.bind(1)]], 0, HOW_TO)


## The highscore table as lines of text; `mark` is the rank to flag as new.
func score_table(mark := -1) -> String:
	if Settings.highscores.is_empty():
		return "No scores yet"
	var lines: PackedStringArray = []
	for i in Settings.highscores.size():
		var entry: Dictionary = Settings.highscores[i]
		var who: String = entry.get("name", "")
		lines.append("%d.   %s   %d   level %d   %s%s" % [i + 1, who if who != "" else "???", entry.score,
				entry.level, entry.date, "   ~ new ~" if i == mark else ""])
	return "\n".join(lines)


## A fresh run, straight into play.
func start_run() -> void:
	_new_game()
	_set_screen(Screen.PLAYING)
	shout("~ LEVEL %d ~" % game.level)


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


## The end of a run. A score that makes the table first asks for a name (the last one is offered).
func _show_over() -> void:
	_set_screen(Screen.OVER)
	if Settings.rank_for(game.score) < 0:
		_show_end_card(-1)
		return
	_menu.show_page("~ A NEW HIGHSCORE ~\nScore  %d     Level  %d" % [game.score, game.level],
			[["Save", _save_score]], 0, "Your name", true, Settings.player_name)


func _save_score() -> void:
	var name: String = _menu.entry_text()
	Settings.set_player_name(name)
	_show_end_card(Settings.add_score(game.score, game.level, "", name))


func _show_end_card(rank: int) -> void:
	_menu.show_page("~ THE END ~\nScore  %d     Level  %d" % [game.score, game.level], [
		["Restart", start_run],
		["Menu", show_title],
	], 0, score_table(rank))


## Level cleared or time up: a card with one button that carries on.
func _show_break(heading: String, button: String, action: Callable) -> void:
	_set_screen(Screen.BREAK)
	_menu.show_page(heading + "\nScore  %d     Lives  %d" % [game.score, game.lives], [[button, action]])


func _next_level() -> void:
	game.start_level(game.level + 1)
	_on_level_started()
	resume()
	shout("~ LEVEL %d ~" % game.level)


func _show_options(from: Screen, focus := 0) -> void:
	_options_from = from
	_set_screen(Screen.OPTIONS)
	var items := [
		["Gore: %s" % ("On" if Settings.gore else "Off"), _toggle_gore],
		["Arrows on touch: %s" % ("Shown" if Settings.show_arrows else "Hidden"), _toggle_arrows],
		["Start level: %d" % Settings.start_level, _next_start_level],
		["View: %s" % ("Whole arena" if Settings.view_fit else "Follow"), _toggle_view],
		["Graphics: %s" % ("Sharp" if Settings.sharp else "Fast"), _toggle_sharp],
		["Music: %d%%" % Settings.music_volume, _next_music_volume],
		["Sounds: %d%%" % Settings.sound_volume, _next_sound_volume],
		["Mute: %s" % ("On" if Settings.muted else "Off"), _toggle_mute],
	]
	if can_fullscreen():
		items.append(["Fullscreen: %s" % ("On" if is_fullscreen() else "Off"), _toggle_fullscreen])
	items.append(["Back", _options_back])
	_menu.show_page("~ OPTIONS ~", items, focus)


func _toggle_gore() -> void:
	Settings.set_gore(not Settings.gore)
	_show_options(_options_from, 0)


func _toggle_arrows() -> void:
	Settings.set_show_arrows(not Settings.show_arrows)
	_show_options(_options_from, 1)


## The level the next run starts at, 1 to 10 and round again (spec §5).
func _next_start_level() -> void:
	Settings.set_start_level(Settings.start_level % Settings.MAX_START_LEVEL + 1)
	_show_options(_options_from, 2)


func _toggle_view() -> void:
	Settings.set_view_fit(not Settings.view_fit)
	_show_options(_options_from, 3)


## Sharp draws at the screen's own resolution; Fast draws at the base size and scales the picture up,
## which is much cheaper on weak graphics but blurry on big screens.
func _toggle_sharp() -> void:
	Settings.set_sharp(not Settings.sharp)
	_show_options(_options_from, 4)


## Volumes step 100, 75, 50, 25, 0 and round again (spec §10).
func _next_music_volume() -> void:
	Settings.set_music_volume(_step_down(Settings.music_volume))
	_show_options(_options_from, 5)


func _next_sound_volume() -> void:
	Settings.set_sound_volume(_step_down(Settings.sound_volume))
	_show_options(_options_from, 6)


static func _step_down(percent: int) -> int:
	return 100 if percent <= 0 else maxi(0, (percent - 1) / 25 * 25)


func _toggle_mute() -> void:
	Settings.set_muted(not Settings.muted)
	_show_options(_options_from, 7)


## Not saved: browsers only allow fullscreen right after a click or tap, so it cannot be restored on load.
func _toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_show_options(_options_from, 8)


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
	_update_music(next)


## The menu waltz on the title and its options; the rag during a run, a little faster each level,
## held while paused; silence after the end.
func _update_music(next: Screen) -> void:
	var menus := next == Screen.TITLE or (next == Screen.OPTIONS and _options_from == Screen.TITLE)
	if menus:
		Sound.pause_music(false)
		Sound.play_music(&"title")
	elif next == Screen.PLAYING:
		Sound.play_music(&"game", _game_music_pitch() * (1.2 if game.in_frenzy() else 1.0))
		Sound.pause_music(false)
	elif next == Screen.OVER:
		Sound.stop_music()
	else:
		Sound.pause_music(true)


func _on_touch_seen() -> void:
	_touch_seen = true
	_update_dpad()


func _update_dpad() -> void:
	_dpad.visible = _touch_seen and Settings.show_arrows and screen == Screen.PLAYING


func _apply_settings() -> void:
	_gore.set_gore(Settings.gore)
	get_tree().root.content_scale_mode = (Window.CONTENT_SCALE_MODE_CANVAS_ITEMS if Settings.sharp
			else Window.CONTENT_SCALE_MODE_VIEWPORT)
	_update_dpad()


## A new run starts at the chosen start level (spec §5).
func _new_game() -> void:
	var fresh := SnakeGame.new(Cfg.ARENA.x, Cfg.ARENA.y, Time.get_ticks_usec())
	fresh.start_level(Settings.start_level)
	set_game(fresh)


## Shows this game; also used by tests and tools to stage a game of their own.
func set_game(next: SnakeGame) -> void:
	game = next
	_world.game = game
	_on_level_started()


## A new or restarted level: the floor fits the arena, old gore goes, the view jumps to the snake.
func _on_level_started() -> void:
	_floor.size = Vector2(game.width, game.height) * View.CELL
	_gore.clear()
	_pending_eat = Vector2i(-1, -1)
	_world.dying_prey = _pending_eat
	_accumulator = 0.0
	_world.t = 1.0
	_aim_camera()
	_update_hud()


func _update_hud() -> void:
	var length := game.body.size()
	var extra := game.level * 100000 + int(ceilf(game.time_left())) * 10 + game.enemies_alive()
	if game.score == _hud_score and game.lives == _hud_lives and length == _hud_length and extra == _hud_extra:
		return
	_hud_score = game.score
	_hud_lives = game.lives
	_hud_length = length
	_hud_extra = extra
	var text := "SCORE  %d     LIVES  %d     LENGTH  %d" % [game.score, game.lives, length]
	if game.level > 0:
		var seconds := int(ceilf(game.time_left()))
		text += "     LEVEL  %d     TIME  %d:%02d     FOES  %d" % [game.level, seconds / 60, seconds % 60,
				game.enemies_alive()]
	_status.text = text


## Follow view: zoomed in on the head (seed[25]). Whole-arena view (spec §4): the arena fits the
## screen, but never smaller than MIN_ZOOM; if it still does not fit, the camera follows the head.
func _aim_camera() -> void:
	var head: Vector2 = _world.snake_path()[0]
	if not Settings.view_fit:
		_camera.zoom = Vector2(View.ZOOM, View.ZOOM)
		_camera.position = head
		return
	# The arena fits the screen below the status bar, so the bar never covers it.
	var arena := Vector2(game.width, game.height) * View.CELL
	var screen := get_viewport_rect().size - Vector2(0.0, HUD_BAND)
	var zoom := maxf(View.MIN_ZOOM, minf(screen.x / (arena.x + View.CELL * 2.0), screen.y / (arena.y + View.CELL * 2.0)))
	_camera.zoom = Vector2(zoom, zoom)
	var half := screen / zoom / 2.0
	var centre := arena / 2.0
	# Centre the arena, or follow the head along any axis where it is bigger than the screen.
	var aim := Vector2(centre.x if half.x * 2.0 >= arena.x else clampf(head.x, half.x, arena.x - half.x),
			centre.y if half.y * 2.0 >= arena.y else clampf(head.y, half.y, arena.y - half.y))
	_camera.position = aim - Vector2(0.0, HUD_BAND / 2.0 / zoom)  # the screen centre sits half a band higher


func _visible_rect() -> Rect2:
	var size := get_viewport_rect().size / _camera.zoom
	return Rect2(_camera.get_screen_center_position() - size / 2.0, size).grow(View.CELL)
