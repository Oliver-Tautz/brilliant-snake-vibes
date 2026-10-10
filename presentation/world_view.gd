## Draws the board contents in the hand-inked style: prey animals, the snake and the walls.
## Which skin, head, prey species and wall style get drawn is decided by the divine_inspiration
## seed (presentation/art_direction.gd); each choice cites its seed position.
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
var _snout := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _snout_line := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


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
	_draw_walls()


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
	_draw_skin(path, half, cull)
	_draw_head(_inked[0])


## Skin markings on the straight parts of the body (seed[2]).
func _draw_skin(path: PackedVector2Array, half: float, cull: Rect2) -> void:
	var count := path.size()
	if Art.skin == Art.SkinPattern.STRIPE:
		for i in range(1, count - 2):
			if cull.has_point(_inked[i]):
				draw_line(_inked[i], _inked[i + 1], Ink.INK, 2.0, true)
		return
	for i in range(2, count - 1):
		var along := path[i - 1] - path[i + 1]
		if not cull.has_point(_inked[i]) or not (is_zero_approx(along.x) or is_zero_approx(along.y)):
			continue
		var across := along.orthogonal().normalized() * half
		match Art.skin:
			Art.SkinPattern.BANDS:
				if i % 3 == 0:
					draw_line(_inked[i] - across * 0.8, _inked[i] + across * 0.8, Ink.INK, 2.0, true)
			Art.SkinPattern.DIAMONDS:
				if i % 2 == 0:
					Ink.diamond(self, _inked[i], Vector2.ONE * half * 0.45, Ink.INK, 1.8)
			Art.SkinPattern.SPOTS:
				if i % 2 == 1:
					var sway := 0.35 if i % 4 == 1 else -0.35
					draw_circle(_inked[i] + across * sway, half * 0.22, Ink.INK, true, -1.0, true)


## Head with squash and stretch, pie-cut eyes and fangs. Shape from seed[4], fang length seed[5],
## eye size seed[6].
func _draw_head(at: Vector2) -> void:
	var fwd := Vector2(game.direction)
	var side := fwd.orthogonal()
	var angle := fwd.angle()
	var gulp := eat_pulse / View.EAT_PULSE
	var r := View.BODY_WIDTH * 0.72
	var ink := View.INK_WIDTH
	var radii := Vector2(r * (1.2 - 0.15 * gulp), r * (1.0 + 0.35 * gulp))  # squash and stretch
	var front := r * 1.05
	match Art.head:
		Art.HeadShape.ROUND:
			Ink.blob(self, at, radii, Ink.PAPER, ink, 9001, angle)
		Art.HeadShape.VIPER:
			# A wide ellipse with a pointed snout, inked in one outline.
			_snout[0] = at + side * radii.y * 1.0 + fwd * r * 0.1
			_snout[1] = at + fwd * r * 2.0
			_snout[2] = at - side * radii.y * 1.0 + fwd * r * 0.1
			for i in 3:
				_snout_line[i] = _snout[i] + Ink.wobble(9010 + i, 0.6)
			_snout_line[3] = _snout_line[0]
			Ink.ellipse(self, at, radii * Vector2(1.0, 1.1) + Vector2(ink, ink), Ink.INK, angle)
			draw_polyline(_snout_line, Ink.INK, ink * 2.0, true)
			draw_colored_polygon(_snout, Ink.PAPER)
			Ink.ellipse(self, at, radii * Vector2(1.0, 1.1), Ink.PAPER, angle)
			front = r * 1.2
			# Angry brows above the eyes.
			for s in 2:
				var sgn := 1.0 if s == 0 else -1.0
				var eye := at + fwd * r * 0.2 + side * sgn * r * 0.5
				draw_line(eye + side * sgn * r * 0.4 - fwd * r * 0.35, eye - side * sgn * r * 0.1 + fwd * r * 0.05,
						Ink.INK, ink * 0.8, true)
		Art.HeadShape.BIG_JAW:
			Ink.blob(self, at, Vector2(radii.x, radii.y * 1.3), Ink.PAPER, ink, 9001, angle)
			draw_arc(at + fwd * r * 0.3, r * 0.75, angle - 0.9, angle + 0.9, 10, Ink.INK, ink * 1.4, true)
	# Fangs sprout from the sides of the jaw and curve forward.
	var mouth := at + fwd * front
	var fang := r * Art.fang_length * 1.4
	var spread := 0.5 if Art.head == Art.HeadShape.VIPER else 0.32
	for s in 2:
		var sgn := 1.0 if s == 0 else -1.0
		var base := mouth + side * sgn * r * spread
		Ink.fang(self, base, base + side * sgn * r * 0.15 + fwd * fang, r * 0.17)
	Ink.pie_eye(self, at + fwd * r * 0.2 + side * r * 0.5, r * Art.eye_size, fwd, 9002)
	Ink.pie_eye(self, at + fwd * r * 0.2 - side * r * 0.5, r * Art.eye_size, fwd, 9003)


## Arena border (seed[20]).
func _draw_walls() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(game.width, game.height) * View.CELL)
	var ink := View.INK_WIDTH
	match Art.wall:
		Art.WallStyle.SINGLE:
			Ink.wobbly_rect(self, rect, ink * 2.5, 555)
		Art.WallStyle.DOUBLE:
			# A second, thinner rule just inside the border, on the floor where it shows.
			Ink.wobbly_rect(self, rect, ink * 1.6, 555)
			Ink.wobbly_rect(self, rect.grow(-ink * 3.0), ink * 1.0, 777)
		Art.WallStyle.HATCHED:
			Ink.wobbly_rect(self, rect, ink * 1.5, 555)
			var cull := view_rect.grow(View.CELL)
			var len := View.CELL * 0.5
			# Diagonal hatching on the inside of each edge, only along the visible stretch.
			_hatch_edge(Vector2(0.0, 0.0), Vector2(rect.size.x, 0.0), Vector2(0.5, 1.0) * len, cull, ink)
			_hatch_edge(Vector2(0.0, rect.size.y), Vector2(rect.size.x, rect.size.y), Vector2(-0.5, -1.0) * len,
					cull, ink)
			_hatch_edge(Vector2(0.0, 0.0), Vector2(0.0, rect.size.y), Vector2(1.0, -0.5) * len, cull, ink)
			_hatch_edge(Vector2(rect.size.x, 0.0), Vector2(rect.size.x, rect.size.y), Vector2(-1.0, 0.5) * len,
					cull, ink)


## Short ink strokes from an axis-aligned edge into the board, limited to the part inside `cull`.
func _hatch_edge(from: Vector2, to: Vector2, inward: Vector2, cull: Rect2, ink: float) -> void:
	var horizontal := is_equal_approx(from.y, to.y)
	var fixed := from.y if horizontal else from.x
	var lo := cull.position.y if horizontal else cull.position.x
	var hi := cull.end.y if horizontal else cull.end.x
	if fixed < lo or fixed > hi:
		return
	var start := maxf(from.x if horizontal else from.y, cull.position.x if horizontal else cull.position.y)
	var end := minf(to.x if horizontal else to.y, cull.end.x if horizontal else cull.end.y)
	var step := View.CELL * 0.6
	var d := ceilf(start / step) * step
	while d <= end:
		var p := Vector2(d, fixed) if horizontal else Vector2(fixed, d)
		draw_line(p, p + inward, Ink.INK, ink * 0.6, true)
		d += step


## A small, helpless, trembling tier-1 prey. Species from seed[10] and seed[11], size seed[13],
## nervousness seed[12].
func _draw_prey(cell: Vector2i, c: Vector2, now: float) -> void:
	var id := cell.x * 7919 + cell.y * 104729
	var phase := Ink.rand(id, 1) * TAU
	var face := -1.0 if Ink.rand(id, 2) < 0.5 else 1.0
	var hop := absf(sin(now * 3.2 * Art.prey_nerves + phase))
	var r := View.CELL * Art.prey_size
	var body := c + Vector2(sin(now * 31.0 + phase) * 0.6 * Art.prey_nerves, 2.0 - hop * 3.0)
	var squash := 1.0 - 0.12 * hop
	var species := Art.prey_species_a if Ink.rand(id, 5) < 0.5 else Art.prey_species_b
	match species:
		Art.PreySpecies.MOUSE:
			_draw_mouse(body, r, face, squash, id, now, phase)
		Art.PreySpecies.BEETLE:
			_draw_beetle(body, r, face, squash, id, now, phase)
		Art.PreySpecies.CHICK:
			_draw_chick(body, r, face, squash, id, now, phase)
		Art.PreySpecies.FROG:
			_draw_frog(body, r, face, squash, id, now, phase)


func _draw_mouse(body: Vector2, r: float, face: float, squash: float, id: int, now: float, phase: float) -> void:
	_tail.resize(5)
	for i in 5:
		var k := float(i) / 4.0
		_tail[i] = body + Vector2(-face * (r * 0.9 + k * r * 0.9), -k * r * 0.4
				+ sin(now * 6.0 + phase + k * 4.0) * r * 0.35 * k)
	draw_polyline(_tail, Ink.INK, 1.8, true)
	Ink.blob(self, body + Vector2(face * r * 0.05, -r * 0.85), Vector2(r * 0.42, r * 0.42), Ink.INK, 1.0, id + 1)
	Ink.blob(self, body + Vector2(face * r * 0.65, -r * 0.75), Vector2(r * 0.4, r * 0.4), Ink.INK, 1.0, id + 2)
	Ink.blob(self, body, Vector2(r * 1.1 / squash, r * squash), Ink.PAPER, 2.0, id)
	Ink.pie_eye(self, body + Vector2(face * r * 0.2, -r * 0.2), r * 0.32, Vector2(face, -0.3), id + 3)
	Ink.pie_eye(self, body + Vector2(face * r * 0.65, -r * 0.2), r * 0.32, Vector2(face, -0.3), id + 4)
	draw_circle(body + Vector2(face * r * 1.1, r * 0.15), 2.2, Ink.INK, true, -1.0, true)


func _draw_chick(body: Vector2, r: float, face: float, squash: float, id: int, now: float, phase: float) -> void:
	# Spindly legs, round fluffy body, a wing stub, a three-hair tuft, a beak.
	for s in 2:
		var x := (s - 0.5) * r * 0.6
		draw_line(body + Vector2(x, r * 0.8), body + Vector2(x + face * r * 0.15, r * 1.25), Ink.INK, 1.6, true)
	Ink.blob(self, body, Vector2(r * 1.0 / squash, r * squash), Ink.PAPER, 2.0, id)
	# Wing stub on the back: a "(" stroke that flaps.
	var flap := sin(now * 9.0 * Art.prey_nerves + phase) * 0.25
	var back := PI if face > 0.0 else 0.0
	draw_arc(body + Vector2(-face * r * 0.1, r * 0.1), r * 0.45, back - 0.7 + flap, back + 0.7 + flap, 8,
			Ink.INK, 1.8, true)
	for k in 3:
		var base := body + Vector2((k - 1) * r * 0.18, -r * squash)
		draw_line(base, base + Vector2((k - 1) * r * 0.2, -r * 0.45) + Ink.wobble(id + k, 0.5), Ink.INK, 1.4, true)
	# Beak long enough to clear the heavy body outline at small prey sizes.
	var beak := body + Vector2(face * r * 0.95, -r * 0.05)
	Ink.triangle(self, beak + Vector2(0.0, -r * 0.32), beak + Vector2(0.0, r * 0.32), beak + Vector2(face * r * 0.85, 0.0),
			Ink.INK)
	Ink.pie_eye(self, body + Vector2(face * r * 0.15, -r * 0.3), r * 0.3, Vector2(face, -0.2), id + 3)
	Ink.pie_eye(self, body + Vector2(face * r * 0.6, -r * 0.3), r * 0.3, Vector2(face, -0.2), id + 4)


func _draw_beetle(body: Vector2, r: float, face: float, squash: float, id: int, now: float, phase: float) -> void:
	var scuttle := sin(now * 14.0 * Art.prey_nerves + phase) * r * 0.15
	for s in 2:
		var sgn := 1.0 if s == 0 else -1.0
		for k in 3:
			var x := (k - 1) * r * 0.55
			var y := sgn * (scuttle if k % 2 == 0 else -scuttle)
			draw_line(body + Vector2(x, sgn * r * 0.5), body + Vector2(x + y, sgn * r * 1.15), Ink.INK, 1.5, true)
	var head := body + Vector2(face * r * 1.05, 0.0)
	for s in 2:
		var sgn := 1.0 if s == 0 else -1.0
		draw_line(head, head + Vector2(face * r * 0.6, sgn * r * 0.55) + Ink.wobble(id + s, 0.5), Ink.INK, 1.2, true)
	draw_circle(head, r * 0.42, Ink.INK, true, -1.0, true)
	Ink.blob(self, body, Vector2(r * 1.1 / squash, r * 0.85 * squash), Ink.PAPER, 2.0, id)
	draw_line(body - Vector2(face * r * 0.95, 0.0), body + Vector2(face * r * 0.6, 0.0), Ink.INK, 1.5, true)
	Ink.pie_eye(self, head + Vector2(face * r * 0.1, -r * 0.2), r * 0.24, Vector2(face, 0.0), id + 3)
	Ink.pie_eye(self, head + Vector2(face * r * 0.1, r * 0.2), r * 0.24, Vector2(face, 0.0), id + 4)


func _draw_frog(body: Vector2, r: float, face: float, squash: float, id: int, now: float, phase: float) -> void:
	var gulp := 1.0 + 0.15 * absf(sin(now * 5.0 * Art.prey_nerves + phase))  # throat pulse
	for s in 2:
		var sgn := 1.0 if s == 0 else -1.0
		var hip := body + Vector2(-face * r * 0.6, sgn * r * 0.55)
		var knee := hip + Vector2(-face * r * 0.6, sgn * r * 0.35)
		draw_line(hip, knee, Ink.INK, 1.6, true)
		draw_line(knee, hip + Vector2(-face * r * 0.1, sgn * r * 0.75), Ink.INK, 1.6, true)
	Ink.blob(self, body, Vector2(r * 1.2 / squash, r * 0.85 * squash * gulp), Ink.PAPER, 2.0, id)
	draw_arc(body + Vector2(face * r * 0.35, 0.0), r * 0.6, -0.9 if face > 0.0 else PI - 0.9,
			0.9 if face > 0.0 else PI + 0.9, 8, Ink.INK, 1.5, true)
	Ink.pie_eye(self, body + Vector2(face * r * 0.4, -r * 0.7), r * 0.36, Vector2(face, -0.3), id + 3)
	Ink.pie_eye(self, body + Vector2(-face * r * 0.1, -r * 0.75), r * 0.36, Vector2(face, -0.3), id + 4)
