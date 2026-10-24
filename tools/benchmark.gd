## Frame-time benchmark: renders a heavy, staged scene offscreen and measures each layer's cost.
## Usage: godot --path . -s tools/benchmark.gd -- [width] [height] [frames]
## Worst case for weak GPUs: prefix with LIBGL_ALWAYS_SOFTWARE=1 (Mesa software rendering).
## Prints, per variant: average and 95th-percentile frame time in ms, and draw calls.
## Note: the game itself renders at the 1152x648 base resolution (viewport stretch), so pass 1152 648 for
## what players get; larger sizes are a worst case.
extends SceneTree

const WARMUP := 30
const VARIANTS := ["all", "no film", "no floor", "no gore", "no prey", "no snake", "no walls",
		"dense prey"]

var _size := Vector2i(1920, 1080)
var _frames := 200
var _viewport: SubViewport
var _main: Node2D
var _world: Node2D
var _variant := 0
var _frame := -2
var _last_usec := 0
var _times := PackedFloat32Array()
var _draw_calls := 0
var _results: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		_size = Vector2i(int(args[0]), int(args[1]))
	if args.size() >= 3:
		_frames = int(args[2])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_viewport = SubViewport.new()
	_viewport.size = _size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_main = load("res://presentation/main.tscn").instantiate()
	_viewport.add_child(_main)
	_world = _main.get_node("World")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == -1:
		_stage()
		_apply(VARIANTS[_variant])
		return false
	_drive()
	if _frame <= WARMUP:
		_last_usec = Time.get_ticks_usec()
		return false
	var now := Time.get_ticks_usec()
	_times.append((now - _last_usec) / 1000.0)
	_last_usec = now
	_draw_calls = maxi(_draw_calls, RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if _times.size() < _frames:
		return false
	_report(VARIANTS[_variant])
	_variant += 1
	if _variant >= VARIANTS.size():
		print("\n%s at %dx%d, %d frames each:" % ["Brilliant Snake Vibes benchmark", _size.x, _size.y, _frames])
		for line in _results:
			print(line)
		return true
	_apply(VARIANTS[_variant])
	_frame = 0
	_times.clear()
	_draw_calls = 0
	return false


## A long snake winding around the camera, normal prey density, and steady gore.
func _stage() -> void:
	_main.set_process(false)  # the benchmark drives redraws itself; the game does not tick
	_main.get_node("HUD/Menu").visible = false
	_main.set_game(SnakeGame.new(100, 100, 1))
	var game: SnakeGame = _main.game
	var cells: Array[Vector2i] = []
	for row in 12:
		for col in 30:
			var x := 35 + (col if row % 2 == 0 else 29 - col)
			cells.append(Vector2i(x, 44 + row))
	cells.reverse()
	game.set_food([])
	game.set_body(cells)
	game.set_food(_free_cells(game, 125, 0, 100))
	_world.t = 0.5
	var camera: Camera2D = _main.get_node("Camera2D")
	camera.position = (Vector2(50, 50) + Vector2(0.5, 0.5)) * 24.0
	_world.view_rect = Rect2(camera.position - Vector2(_size) / camera.zoom / 2.0,
			Vector2(_size) / camera.zoom).grow(24.0)


func _drive() -> void:
	_world.queue_redraw()
	if _frame % 8 == 0:  # keep blood flying, as during a feeding frenzy
		var gore: Node2D = _main.get_node("Gore")
		gore.burst(_world.view_rect.get_center() + Vector2(randf_range(-300, 300), randf_range(-150, 150)),
				22, 260.0, 2)


func _apply(variant: String) -> void:
	_main.get_node("Film").visible = variant != "no film"
	_main.get_node("Floor").visible = variant != "no floor"
	_main.get_node("Gore").visible = variant != "no gore"
	_world.show_prey = variant != "no prey"
	_world.show_snake = variant != "no snake"
	_world.show_walls = variant != "no walls"
	if variant == "dense prey":
		var game: SnakeGame = _main.game
		game.set_food(_free_cells(game, 400, 30, 70))


func _free_cells(game: SnakeGame, count: int, lo: int, hi: int) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out: Array[Vector2i] = []
	while out.size() < count:
		var cell := Vector2i(rng.randi_range(lo, hi - 1), rng.randi_range(lo, hi - 1))
		if not game.body.has(cell) and not out.has(cell):
			out.append(cell)
	return out


func _report(variant: String) -> void:
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in _times:
		total += t
	var avg := total / _times.size()
	var p95 := sorted[int(sorted.size() * 0.95)]
	_results.append("  %-11s avg %6.2f ms  p95 %6.2f ms  (%5.0f fps)  draw calls %d" % [variant, avg, p95,
			1000.0 / avg, _draw_calls])
