## Draws the board contents in the hand-inked style: prey animals, the snake and the walls.
extends Node2D

const View := preload("res://presentation/view_config.gd")

var game: SnakeGame
var t := 1.0  ## progress through the current tick, 0..1
var eat_pulse := 0.0  ## seconds left of the head's gulp swell
var view_rect := Rect2()  ## visible world area, for culling
var dying_prey := Vector2i(-1, -1)  ## eaten prey still drawn until the head reaches it

var _path := PackedVector2Array()
var _inked := PackedVector2Array()
var _tail := PackedVector2Array()


## The snake's centre line for this frame. It runs through the real cell centres, so corners stay
## square. Only the head and the tail end slide, which is what makes the movement smooth.
func snake_path() -> PackedVector2Array:
	var body := game.body
	var n := body.size()
	var sliding := game.last_tick_moved and t < 1.0 and n > 1
	var tail_end := sliding and game.tail_vacated.x >= 0
	_path.resize(n + (1 if tail_end else 0))
	for i in n:
		_path[i] = View.center(body[i])
	if sliding:
		_path[0] = View.center(body[1]).lerp(View.center(body[0]), t)
	if tail_end:
		_path[n] = View.center(game.tail_vacated).lerp(View.center(body[n - 1]), t)
	return _path


func _draw() -> void:
	if game == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for cell in game.foods:
		var c := View.center(cell)
		if view_rect.has_point(c):
			_draw_prey(cell, c, now)
	if dying_prey.x >= 0:
		_draw_prey(dying_prey, View.center(dying_prey), now)
	var blink_off := game.invulnerable_time > 0.0 and int(now * 10.0) % 2 == 0
	if not blink_off:
		_draw_snake()
	Ink.wobbly_rect(self, Rect2(Vector2.ZERO, Vector2(game.width, game.height) * View.CELL), 10.0, 555)


func _draw_snake() -> void:
	var path := snake_path()
	var count := path.size()
	_inked.resize(count)
	for i in count:
		_inked[i] = path[i] + Ink.wobble(i * 31, 0.8)
	var half := View.BODY_WIDTH * 0.5
	var ink := View.INK_WIDTH
	var cull := view_rect.grow(View.CELL)
	# Ink pass, then paper pass on top, gives an outlined rubber hose. Segments are drawn without
	# caps and every joint gets a circle, so corners come out round.
	for pass_i in 2:
		var color := Ink.INK if pass_i == 0 else Ink.PAPER
		for i in count:
			if not cull.has_point(_inked[i]):
				continue
			var radius := half
			if pass_i == 0:
				radius += ink * (0.8 + 0.4 * Ink.rand(i, Ink.boil_frame()))
			if i + 1 < count:
				draw_line(_inked[i], _inked[i + 1], color, radius * 2.0)
			draw_circle(_inked[i], radius, color, true, -1.0, true)
	# Ink bands across the straight parts of the body every few cells.
	for i in range(3, count - 1, 3):
		var along := path[i - 1] - path[i + 1]
		if cull.has_point(_inked[i]) and (is_zero_approx(along.x) or is_zero_approx(along.y)):
			var across := along.orthogonal().normalized() * half * 0.8
			draw_line(_inked[i] - across, _inked[i] + across, Ink.INK, 2.0, true)
	_draw_head(_inked[0])


func _draw_head(at: Vector2) -> void:
	var fwd := Vector2(game.direction)
	var side := fwd.orthogonal()
	var gulp := eat_pulse / View.EAT_PULSE
	var r := View.BODY_WIDTH * 0.72
	var radii := Vector2(r * (1.2 - 0.15 * gulp), r * (1.0 + 0.35 * gulp))  # squash and stretch
	Ink.blob(self, at, radii, Ink.PAPER, View.INK_WIDTH, 9001, fwd.angle())
	var mouth := at + fwd * r * 1.05
	Ink.fang(self, mouth + side * r * 0.32, mouth + side * r * 0.22 + fwd * r * 0.5, r * 0.17)
	Ink.fang(self, mouth - side * r * 0.32, mouth - side * r * 0.22 + fwd * r * 0.5, r * 0.17)
	Ink.pie_eye(self, at + fwd * r * 0.2 + side * r * 0.5, r * 0.36, fwd, 9002)
	Ink.pie_eye(self, at + fwd * r * 0.2 - side * r * 0.5, r * 0.36, fwd, 9003)


## A small, helpless, trembling critter (tier 1 prey).
func _draw_prey(cell: Vector2i, c: Vector2, now: float) -> void:
	var id := cell.x * 7919 + cell.y * 104729
	var phase := Ink.rand(id, 1) * TAU
	var face := -1.0 if Ink.rand(id, 2) < 0.5 else 1.0
	var hop := absf(sin(now * 3.2 + phase))
	var r := View.CELL * 0.34
	var body := c + Vector2(sin(now * 31.0 + phase) * 0.6, 2.0 - hop * 3.0)
	var squash := 1.0 - 0.12 * hop
	# Curly tail behind.
	_tail.resize(5)
	for i in 5:
		var k := float(i) / 4.0
		_tail[i] = body + Vector2(-face * (r * 0.9 + k * r * 0.9), -k * r * 0.4
				+ sin(now * 6.0 + phase + k * 4.0) * r * 0.35 * k)
	draw_polyline(_tail, Ink.INK, 1.8, true)
	# Ears, body, eyes, nose.
	Ink.blob(self, body + Vector2(face * r * 0.05, -r * 0.85), Vector2(r * 0.42, r * 0.42), Ink.INK, 1.0, id + 1)
	Ink.blob(self, body + Vector2(face * r * 0.65, -r * 0.75), Vector2(r * 0.4, r * 0.4), Ink.INK, 1.0, id + 2)
	Ink.blob(self, body, Vector2(r * 1.1 / squash, r * squash), Ink.PAPER, 2.0, id)
	Ink.pie_eye(self, body + Vector2(face * r * 0.2, -r * 0.2), r * 0.32, Vector2(face, -0.3), id + 3)
	Ink.pie_eye(self, body + Vector2(face * r * 0.65, -r * 0.2), r * 0.32, Vector2(face, -0.3), id + 4)
	draw_circle(body + Vector2(face * r * 1.1, r * 0.15), 2.2, Ink.INK, true, -1.0, true)
