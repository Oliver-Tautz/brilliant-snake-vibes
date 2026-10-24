## Performance overlay, toggled with F3: frames per second, frame time, draw calls and render size.
## The text refreshes twice a second, so the overlay itself costs almost nothing.
extends CanvasLayer

const REFRESH := 0.5

var _elapsed := 0.0
var _frames := 0
var _worst := 0.0

@onready var _label: Label = $Label


func _ready() -> void:
	visible = false


func toggle() -> void:
	visible = not visible
	_elapsed = 0.0
	_frames = 0
	_worst = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _elapsed < REFRESH:
		return
	var size := get_viewport().get_visible_rect().size
	_label.text = "%d fps   avg %.1f ms   worst %.1f ms\n%d draw calls   %dx%d" % [
		roundi(_frames / _elapsed), _elapsed / _frames * 1000.0, _worst * 1000.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		size.x, size.y]
	_elapsed = 0.0
	_frames = 0
	_worst = 0.0
