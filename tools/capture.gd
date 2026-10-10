## Renders the main scene in a staged state and saves a screenshot.
## Usage: godot --path . -s tools/capture.gd -- <out.png> [scenario]
## Scenarios: start, paused, play (runs live), corners (long snake with turns, mid-tick), eat (gore),
## edge (snake near the top-left wall). Optional third arg: a WallStyle index to override the seed.
extends SceneTree

const FRAMES := 30
const PLAY_FRAMES := 150

var _main: Node2D
var _viewport: SubViewport
var _frame := 0
var _out := "user://capture.png"
var _scenario := "corners"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_scenario = args[1]
	if args.size() > 2:
		Art.wall = int(args[2])
	# Fixed-size offscreen viewport, so the window manager cannot change the capture size.
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1152, 648)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_main = load("res://presentation/main.tscn").instantiate()
	_viewport.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_stage()
	if _frame > 2 and _scenario != "paused":
		_main.get_node("HUD/Banner").visible = false
	if _frame < (PLAY_FRAMES if _scenario == "play" else FRAMES):
		return false
	_viewport.get_texture().get_image().save_png(_out)
	print("saved ", _out)
	return true


func _stage() -> void:
	if _scenario == "play":  # unstaged: the game simply runs until the capture frame
		_main.game.request_turn(Vector2i.UP)
		return
	_main.paused = true
	var game: SnakeGame = _main.game
	if _scenario == "start" or _scenario == "paused":
		return
	# A long snake with several corners around the centre (or near the top-left wall for "edge").
	var cells: Array[Vector2i] = []
	var c := Vector2i(14, 5) if _scenario == "edge" else Vector2i(50, 50)
	for i in 6:
		cells.append(c - Vector2i(i, 0))
	for i in range(1, 5):
		cells.append(c - Vector2i(5, -i))
	for i in range(1, 7):
		cells.append(c - Vector2i(5 + i, -4))
	for i in range(1, 4):
		cells.append(c - Vector2i(11, -4 + i))
	game.set_food([])
	game.set_body(cells)
	game.set_food([c + Vector2i(3, 0), c + Vector2i(4, -3), c + Vector2i(-2, 3), c + Vector2i(8, 4),
			c + Vector2i(-9, -2), c + Vector2i(2, -6)])
	game.direction = Vector2i.RIGHT
	game.last_tick_moved = true
	game.tail_vacated = c - Vector2i(11, 0)
	_main._accumulator = game.tick_interval() * 0.5
	if _scenario == "eat":
		_main.play_eat_effect(c + Vector2i(1, 0))
		_main.play_eat_effect(c + Vector2i(-3, 2))
