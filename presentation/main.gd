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
const COLOR_EYE := Color(0.05, 0.05, 0.05)
const COLOR_FOOD := Color(0.8, 0.05, 0.05)
const BODY_WIDTH := CELL * 0.78

var game: SnakeGame
var paused := false

var _accumulator := 0.0
var _t := 1.0  # progress through the current tick, 0..1, for smooth movement
var _points := PackedVector2Array()  # reused every frame
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
	_t = clampf(_accumulator / game.tick_interval(), 0.0, 1.0) if game.last_tick_moved else 1.0
	_camera.position = _part_position(0)
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

	var now := Time.get_ticks_msec() / 1000.0
	for cell in game.foods:
		if view.has_point(cell):
			var pulse := 1.0 + 0.12 * sin(now * 6.0 + cell.x * 0.7 + cell.y * 1.3)
			draw_circle(_cell_center(cell), CELL * 0.36 * pulse, COLOR_FOOD, true, -1.0, true)

	var blink_off := game.invulnerable_time > 0.0 and int(now * 10.0) % 2 == 0
	if not blink_off:
		_draw_snake()


## Draws the snake as a smooth rounded tube, sliding between cells over each tick.
func _draw_snake() -> void:
	var count := game.body.size()
	_points.resize(count)
	for i in count:
		_points[i] = _part_position(i)
	if count > 1:
		draw_polyline(_points, COLOR_BODY, BODY_WIDTH, true)
	var radius := BODY_WIDTH / 2.0
	var view := Rect2(_camera.get_screen_center_position() - get_viewport_rect().size / _camera.zoom / 2.0,
			get_viewport_rect().size / _camera.zoom).grow(CELL)
	for i in range(count - 1, 0, -1):
		if view.has_point(_points[i]):
			draw_circle(_points[i], radius, COLOR_BODY, true, -1.0, true)
	var head := _points[0]
	draw_circle(head, radius * 1.15, COLOR_HEAD, true, -1.0, true)
	var forward := Vector2(game.direction)
	var side := forward.orthogonal()
	var eye_base := head + forward * radius * 0.35
	draw_circle(eye_base - side * radius * 0.5, radius * 0.22, COLOR_EYE, true, -1.0, true)
	draw_circle(eye_base + side * radius * 0.5, radius * 0.22, COLOR_EYE, true, -1.0, true)


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
	_t = 1.0
	_camera.position = _cell_center(game.body[0])
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


## Position of snake part k, interpolated from where it was one tick ago.
func _part_position(k: int) -> Vector2:
	var cur := game.body[k]
	var prev := cur
	if _t < 1.0 and game.last_tick_moved:
		if k < game.body.size() - 1:
			prev = game.body[k + 1]
		elif game.tail_vacated.x >= 0:
			prev = game.tail_vacated
	if prev == cur or absi(prev.x - cur.x) + absi(prev.y - cur.y) != 1:
		return _cell_center(cur)
	return (Vector2(prev).lerp(Vector2(cur), _t) + Vector2(0.5, 0.5)) * CELL


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
