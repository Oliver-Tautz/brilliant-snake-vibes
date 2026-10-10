## Playable snake scene: draws SnakeGame state and feeds it keyboard input and time.
extends Node2D

const CELL := 24
const GRID_W := 100
const GRID_H := 100
const MAX_TICKS_PER_FRAME := 5

const COLOR_FLOOR := Color(0.07, 0.07, 0.07)
const COLOR_GRID := Color(0.14, 0.14, 0.14)
const COLOR_WALL := Color(0.9, 0.9, 0.9)
const COLOR_BODY := Color(0.82, 0.82, 0.82)
const COLOR_HEAD := Color(1, 1, 1)
const COLOR_FOOD := Color(0.8, 0.05, 0.05)

var game: SnakeGame
var paused := false

var _accumulator := 0.0
# Last values shown in the HUD; text is only rebuilt when one changes.
var _hud_score := -1
var _hud_lives := -1
var _hud_length := -1
var _hud_state := -1

@onready var _camera: Camera2D = $Camera2D
@onready var _status: Label = $HUD/Status
@onready var _banner: Label = $HUD/Banner


func _ready() -> void:
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
			game.tick()
			ticks += 1
		_accumulator = minf(_accumulator, game.tick_interval())
	_camera.position = _cell_center(game.body[0])
	_update_hud()
	queue_redraw()


func _draw() -> void:
	var grid_px := Vector2(GRID_W, GRID_H) * CELL
	draw_rect(Rect2(Vector2.ZERO, grid_px), COLOR_FLOOR)
	var view := _visible_cells()
	for x in range(view.position.x, view.end.x + 1):
		draw_line(Vector2(x, view.position.y) * CELL, Vector2(x, view.end.y) * CELL, COLOR_GRID)
	for y in range(view.position.y, view.end.y + 1):
		draw_line(Vector2(view.position.x, y) * CELL, Vector2(view.end.x, y) * CELL, COLOR_GRID)
	draw_rect(Rect2(Vector2.ZERO, grid_px), COLOR_WALL, false, 4.0)

	if game.food.x >= 0:
		draw_circle(_cell_center(game.food), CELL * 0.4, COLOR_FOOD)

	var blink_off := game.invulnerable_time > 0.0 and int(Time.get_ticks_msec() / 100.0) % 2 == 0
	if blink_off:
		return
	for i in game.body.size():
		var cell := game.body[i]
		if view.has_point(cell):
			var color := COLOR_HEAD if i == 0 else COLOR_BODY
			draw_rect(Rect2(Vector2(cell) * CELL + Vector2.ONE, Vector2.ONE * (CELL - 2)), color)


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
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_R:
			if game.game_over:
				_new_game()


func _turn(dir: Vector2i) -> void:
	if not paused and not game.game_over:
		game.request_turn(dir)


func _new_game() -> void:
	game = SnakeGame.new(GRID_W, GRID_H, Time.get_ticks_usec())
	paused = false
	_accumulator = 0.0
	_camera.position = _cell_center(game.body[0])
	_camera.reset_smoothing()
	_update_hud()
	queue_redraw()


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
	_status.text = "Score %d   Lives %d   Length %d" % [game.score, game.lives, game.body.size()]
	if game.game_over:
		_banner.text = "GAME OVER\nScore %d\n\nEnter / Space to restart" % game.score
	elif paused:
		_banner.text = "PAUSED\n\nEsc / P to resume"
	else:
		_banner.text = ""


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func _visible_cells() -> Rect2i:
	var size := get_viewport_rect().size / _camera.zoom
	var top_left := _camera.get_screen_center_position() - size / 2.0
	var first := Vector2i((top_left / CELL).floor()) - Vector2i.ONE
	var last := Vector2i(((top_left + size) / CELL).ceil()) + Vector2i.ONE
	first = first.clamp(Vector2i.ZERO, Vector2i(GRID_W, GRID_H))
	last = last.clamp(Vector2i.ZERO, Vector2i(GRID_W, GRID_H))
	return Rect2i(first, last - first)
