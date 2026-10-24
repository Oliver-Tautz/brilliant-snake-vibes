## A small live picture for How to play: a staged board drawn by the real floor and world view, so it
## always looks like the game. It can replay a few player moves in a loop to show a mechanic.
extends SubViewportContainer

const View := preload("res://presentation/view_config.gd")
const STEP := 0.32  # seconds per replayed move

var game: SnakeGame
var _viewport := SubViewport.new()
var _floor := Node2D.new()
var _world := Node2D.new()
var _camera := Camera2D.new()
var _stage: Callable  # returns a fresh SnakeGame for the picture
var _moves := 0  # player moves per loop; 0 for a still picture
var _done := 0
var _clock := 0.0


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(460, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor.material = ShaderMaterial.new()
	(_floor.material as ShaderMaterial).shader = preload("res://presentation/floor.gdshader")
	_floor.set_script(preload("res://presentation/floor.gd"))
	_world.set_script(preload("res://presentation/world_view.gd"))
	_viewport.add_child(_floor)
	_viewport.add_child(_world)
	_viewport.add_child(_camera)
	add_child(_viewport)


## Shows a staged board. `stage` builds the game; `moves` player moves are replayed, then it starts over.
func show_stage(stage: Callable, moves := 0) -> void:
	_stage = stage
	_moves = moves
	_restart()


func _restart() -> void:
	game = _stage.call()
	_world.game = game
	_world.t = 1.0
	_done = 0
	_clock = 0.0
	var arena := Vector2(game.width, game.height) * View.CELL
	_floor.size = arena
	_camera.position = arena / 2.0
	var zoom := minf(custom_minimum_size.x / arena.x, custom_minimum_size.y / arena.y)
	_camera.zoom = Vector2(zoom, zoom)
	_world.view_rect = Rect2(Vector2.ZERO, arena).grow(View.CELL * 2.0)


## Only runs while it can be seen, e.g. not during a run after the last page's Play.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	if game == null:
		return
	if _moves > 0:
		_clock += delta
		if _clock >= STEP:
			_clock -= STEP
			if _done >= _moves:
				_restart()
			else:
				game.tick()
				_done += 1
		_world.t = clampf(_clock / STEP, 0.0, 1.0) if game.last_tick_moved else 1.0
	_world.queue_redraw()
