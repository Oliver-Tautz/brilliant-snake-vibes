## Playable snake scene: runs SnakeGame on a timer, feeds it keyboard input, and drives the views.
extends Node2D

const View := preload("res://presentation/view_config.gd")
const GRID_W := 100
const GRID_H := 100
const MAX_TICKS_PER_FRAME := 5
## Old Standard TT (SIL OFL 1.1), bundled so the web build gets the same period serif.
const SERIF := preload("res://presentation/fonts/OldStandard-Regular.ttf")

var game: SnakeGame
var paused := false

var _accumulator := 0.0
var _shake := 0.0
var _pending_eat := Vector2i(-1, -1)  # eaten prey, burst once the drawn head reaches it
# Last values shown in the HUD; text is only rebuilt when one changes.
var _hud_score := -1
var _hud_lives := -1
var _hud_length := -1
var _hud_state := -1

@onready var _camera: Camera2D = $Camera2D
@onready var _floor: Node2D = $Floor
@onready var _gore: Node2D = $Gore
@onready var _world: Node2D = $World
@onready var _status: Label = $HUD/Status/Label
@onready var _banner_card: Control = $HUD/Banner
@onready var _banner: Label = $HUD/Banner/Label


func _ready() -> void:
	for label in [_status, _banner]:
		label.add_theme_font_override("font", SERIF)
	_floor.size = Vector2(GRID_W, GRID_H) * View.CELL
	_camera.zoom = Vector2(View.ZOOM, View.ZOOM)
	_new_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.physical_keycode)


func _process(delta: float) -> void:
	if not paused and not game.game_over:
		_accumulator += delta
		var ticks := 0
		while _accumulator >= game.tick_interval() and ticks < MAX_TICKS_PER_FRAME:
			_accumulator -= game.tick_interval()
			var head_before := game.body[0]
			game.tick()
			_play_events(head_before)
			ticks += 1
		_accumulator = minf(_accumulator, game.tick_interval())
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


func _handle_key(keycode: Key) -> void:
	match keycode:
		KEY_UP, KEY_W:
			_turn(Vector2i.UP)
		KEY_DOWN, KEY_S:
			_turn(Vector2i.DOWN)
		KEY_LEFT, KEY_A:
			_turn(Vector2i.LEFT)
		KEY_RIGHT, KEY_D:
			_turn(Vector2i.RIGHT)
		KEY_ESCAPE, KEY_P:
			if not game.game_over:
				paused = not paused
				_gore.set_process(not paused)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_R:
			if game.game_over:
				_new_game()


func _turn(dir: Vector2i) -> void:
	if not paused and not game.game_over:
		game.request_turn(dir)


func _new_game() -> void:
	game = SnakeGame.new(GRID_W, GRID_H, Time.get_ticks_usec())
	_world.game = game
	paused = false
	_gore.set_process(true)
	_gore.clear()
	_pending_eat = Vector2i(-1, -1)
	_world.dying_prey = _pending_eat
	_accumulator = 0.0
	_world.t = 1.0
	_camera.position = View.center(game.body[0])
	_update_hud()


func _update_hud() -> void:
	var state := 2 if game.game_over else (1 if paused else 0)
	var length := game.body.size()
	if (game.score == _hud_score and game.lives == _hud_lives
			and length == _hud_length and state == _hud_state):
		return
	_hud_score = game.score
	_hud_lives = game.lives
	_hud_length = length
	_hud_state = state
	_status.text = "SCORE  %d     LIVES  %d     LENGTH  %d" % [game.score, game.lives, length]
	if game.game_over:
		_banner.text = "~ THE END ~\n\nScore  %d\n\nPress Enter to begin anew" % game.score
	elif paused:
		_banner.text = "~ INTERMISSION ~\n\nPress Esc to resume"
	else:
		_banner.text = ""
	_banner_card.visible = _banner.text != ""


func _visible_rect() -> Rect2:
	var size := get_viewport_rect().size / _camera.zoom
	return Rect2(_camera.get_screen_center_position() - size / 2.0, size).grow(View.CELL)
