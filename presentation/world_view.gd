## Draws the board contents in the hand-inked style: prey animals, the snake and the walls.
## Which skin, head, prey species and wall style get drawn is decided by the divine_inspiration
## seed (presentation/art_direction.gd); each choice cites its seed position.
extends Node2D

const View := preload("res://presentation/view_config.gd")
const ENEMY_WIDTHS: Array[float] = [1.2, 1.0, 0.85]  # body width by species: thick anaconda, thin mamba

var game: SnakeGame
var t := 1.0  ## progress through the current tick, 0..1
var eat_pulse := 0.0  ## seconds left of the head's gulp swell
var view_rect := Rect2()  ## visible world area, for culling
var dying_prey := Vector2i(-1, -1)  ## eaten prey still drawn until the head reaches it
var dying_kind := 0  ## its SnakeGame.Food, since its cell is already empty
# Layer switches, used by the benchmark to measure each layer's cost.
var show_prey := true
var show_snake := true
var show_walls := true

var _path := PackedVector2Array()
var _enemy_path := PackedVector2Array()
var _coffin := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _coffin_line := PackedVector2Array()
var _inked := PackedVector2Array()
var _tail := PackedVector2Array()
var _snout := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _snout_line := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # for the shared disc texture


## The snake's centre line for this frame. It runs through the real cell centres, so corners stay
## square. Only the head and the tail end slide, which is what makes the movement smooth.
func snake_path() -> PackedVector2Array:
	return _body_path(_path, game.body, game.last_tick_moved, t, game.tail_vacated)


## The same for any snake, written into `out` (reused, so drawing does not allocate).
static func _body_path(out: PackedVector2Array, body: Array[Vector2i], moved: bool, progress: float,
		vacated: Vector2i) -> PackedVector2Array:
	var n := body.size()
	var sliding := moved and progress < 1.0 and n > 1
	var tail_end := sliding and vacated.x >= 0
	out.resize(n + (1 if tail_end else 0))
	for i in n:
		out[i] = View.center(body[i])
	if sliding:
		out[0] = View.center(body[1]).lerp(View.center(body[0]), progress)
	if tail_end:
		out[n] = View.center(vacated).lerp(View.center(body[n - 1]), progress)
	return out


func _draw() -> void:
	if game == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if show_prey:
		for cell in game.foods:
			var c := View.center(cell)
			if view_rect.has_point(c):
				_draw_prey(cell, c, now)
		if dying_prey.x >= 0:
			_draw_prey(dying_prey, View.center(dying_prey), now)
	if show_snake:
		for enemy in game.enemies:
			if enemy.alive:
				_draw_enemy(enemy)
	var blink_off := game.invulnerable_time > 0.0 and int(now * 10.0) % 2 == 0
	if show_snake and not blink_off:
		_draw_snake()
	if show_walls:
		_draw_walls()


func _draw_snake() -> void:
	var path := snake_path()
	var half := View.BODY_WIDTH * 0.5
	var cull := view_rect.grow(View.CELL)
	_draw_hose(path, half, Ink.PAPER, 0)
	_draw_skin(path, half, cull)
	_draw_head(_inked[0])


## An outlined rubber hose along `path`, wobbled into _inked: an ink pass, then the fill on top.
## Segments are square-ended bars and every joint gets a disc, so corners come out round. Everything
## is the same texture, so a whole snake renders in one batch.
func _draw_hose(path: PackedVector2Array, half: float, fill: Color, id: int) -> void:
	var count := path.size()
	_inked.resize(count)
	for i in count:
		_inked[i] = path[i] + Ink.wobble(id + i * 31, 0.8)
	var ink := View.INK_WIDTH
	var cull := view_rect.grow(View.CELL)
	for pass_i in 2:
		var color := Ink.INK if pass_i == 0 else fill
		for i in count:
			if not cull.has_point(_inked[i]):
				continue
			var radius := half
			if pass_i == 0:
				radius += ink * (0.8 + 0.4 * Ink.rand(id + i, Ink.boil_frame()))
			if i + 1 < count:
				Ink.bar(self, _inked[i], _inked[i + 1], radius, color)
			Ink.disc(self, _inked[i], radius, color)


## An enemy snake (spec §6b): a hose in its colour and a head for its species. The anaconda is thick,
## the mamba thin.
func _draw_enemy(enemy) -> void:
	var progress: float = clampf(enemy.clock / enemy.interval, 0.0, 1.0)
	var path := _body_path(_enemy_path, enemy.body, enemy.last_moved, progress, enemy.tail_vacated)
	if not view_rect.grow(View.CELL * 4.0).has_point(path[0]) and not view_rect.has_point(path[path.size() - 1]):
		if not _any_visible(path):
			return
	var id: int = 5000 + enemy.species * 1000
	var fill: Color = Ink.SNAKE_COLORS[enemy.species]
	_draw_hose(path, View.BODY_WIDTH * 0.5 * ENEMY_WIDTHS[enemy.species], fill, id)
	var at := _inked[0]
	var fwd := Vector2(enemy.direction)
	var side := fwd.orthogonal()
	var angle := fwd.angle()
	var r := View.CELL * 0.45
	var ink := View.INK_WIDTH
	match enemy.species:
		0:  # anaconda: broad, heavy, flat head with a long grim mouth
			Ink.blob(self, at, Vector2(r * 1.15, r * 1.25), fill, ink, id, angle)
			draw_arc(at + fwd * r * 0.1, r * 0.95, angle - 0.75, angle + 0.75, 10, Ink.INK, ink * 0.8, true)
		1:  # king cobra: a spread hood behind the head, with eye-spots
			Ink.blob(self, at - fwd * r * 0.4, Vector2(r * 0.8, r * 1.9), fill.darkened(0.25), ink, id + 1, angle)
			for s in 2:
				Ink.disc(self, at - fwd * r * 0.5 + side * (s * 2 - 1) * r * 1.05, r * 0.22, Ink.INK)
			Ink.blob(self, at + fwd * r * 0.3, Vector2(r * 1.0, r * 0.8), fill, ink, id + 2, angle)
		_:  # black mamba: a narrow coffin-shaped head with a gaping black mouth
			_coffin[0] = at - fwd * r * 0.9 - side * r * 0.45
			_coffin[1] = at - fwd * r * 0.2 - side * r * 0.75
			_coffin[2] = at + fwd * r * 1.3 - side * r * 0.4
			_coffin[3] = at + fwd * r * 1.3 + side * r * 0.4
			_coffin[4] = at - fwd * r * 0.2 + side * r * 0.75
			_coffin[5] = at - fwd * r * 0.9 + side * r * 0.45
			draw_colored_polygon(_coffin, fill)
			_coffin_line.resize(7)
			for i in 6:
				_coffin_line[i] = _coffin[i]
			_coffin_line[6] = _coffin[0]
			draw_polyline(_coffin_line, Ink.PAPER, 1.5, true)  # a pale rim, so black reads on black
			Ink.triangle(self, at + fwd * r * 1.35 - side * r * 0.32, at + fwd * r * 1.35 + side * r * 0.32,
					at + fwd * r * 0.55, Ink.INK)
	var eye_at := at + fwd * r * (0.45 if enemy.species == 1 else 0.2)
	Ink.pie_eye(self, eye_at + side * r * 0.45, r * 0.32, fwd, id + 3)
	Ink.pie_eye(self, eye_at - side * r * 0.45, r * 0.32, fwd, id + 4)


func _any_visible(path: PackedVector2Array) -> bool:
	var cull := view_rect.grow(View.CELL)
	for p in path:
		if cull.has_point(p):
			return true
	return false


## Skin markings (seed[2]). Mark i sits i cells behind the head, so during a tick every mark slides
## one cell forward along the body together with the head; tied to cells they would hop each tick.
## Marks are left out around corners.
func _draw_skin(path: PackedVector2Array, half: float, cull: Rect2) -> void:
	var count := path.size()
	if Art.skin == Art.SkinPattern.STRIPE:
		for i in range(1, count - 2):
			if cull.has_point(_inked[i]):
				draw_line(_inked[i], _inked[i + 1], Ink.INK, 2.0, true)
		return
	var body := game.body
	var lag := 1.0 - t if game.last_tick_moved else 0.0
	for i in range(2, body.size() - 2):
		var a := i + int(lag >= 0.5)  # the cell the mark is nearest to
		if a + 1 >= body.size() or not _is_straight(body, a):
			continue
		var at := skin_mark_at(i) + Ink.wobble(i * 31, 0.8).lerp(Ink.wobble((i + 1) * 31, 0.8), lag)  # boil with the hose
		if not cull.has_point(at):
			continue
		var across := Vector2(body[i] - body[i + 1]).orthogonal() * half
		match Art.skin:
			Art.SkinPattern.BANDS:
				if i % 3 == 0:
					draw_line(at - across * 0.8, at + across * 0.8, Ink.INK, 2.0, true)
			Art.SkinPattern.DIAMONDS:
				if i % 2 == 0:
					Ink.diamond(self, at, Vector2.ONE * half * 0.45, Ink.INK, 1.8)
			Art.SkinPattern.SPOTS:
				if i % 2 == 1:
					var sway := 0.35 if i % 4 == 1 else -0.35
					Ink.disc(self, at + across * sway, half * 0.22, Ink.INK)


## Where skin mark i is drawn this frame: on its cell at the end of a tick, one cell further back at
## the start, so marks move with the head.
func skin_mark_at(i: int) -> Vector2:
	var lag := 1.0 - t if game.last_tick_moved else 0.0
	return View.center(game.body[i]).lerp(View.center(game.body[i + 1]), lag)


## True when body[a] is not a corner: its neighbours on both sides lie in one line.
static func _is_straight(body: Array[Vector2i], a: int) -> bool:
	var along := body[a - 1] - body[a + 1]
	return along.x == 0 or along.y == 0


## Head with squash and stretch, pie-cut eyes and fangs. Shape from seed[4], fang length seed[5],
## eye size seed[6].
func _draw_head(at: Vector2) -> void:
	var fwd := Vector2(game.direction)
	var side := fwd.orthogonal()
	var angle := fwd.angle()
	var gulp := eat_pulse / View.EAT_PULSE
	var r := View.CELL * 0.5  # a big cartoon head on a thin hose body
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


## A small, helpless, trembling chicken (spec §6). Big ones are larger and orange; ones left by a dead
## enemy snake take its colour. Before a hop it crouches and shakes, then it slides over in an arc.
## Size seed[13], nervousness seed[12]. The other prey species (seed[10], seed[11]) wait for later tiers.
func _draw_prey(cell: Vector2i, c: Vector2, now: float) -> void:
	var id := cell.x * 7919 + cell.y * 104729
	var phase := Ink.rand(id, 1) * TAU
	var face := -1.0 if Ink.rand(id, 2) < 0.5 else 1.0
	var hop := absf(sin(now * 3.2 * Art.prey_nerves + phase))
	var r := View.CELL * Art.prey_size
	var kind := dying_kind if cell == dying_prey else game.food_at(cell)
	var fill := Ink.PAPER
	match kind:
		SnakeGame.Food.BIG:
			r *= 1.45
			fill = Ink.ORANGE
		SnakeGame.Food.GREEN, SnakeGame.Food.PURPLE, SnakeGame.Food.BLACK:
			fill = Ink.SNAKE_COLORS[kind - SnakeGame.Food.GREEN]
	var squash := 1.0 - 0.12 * hop
	var k := game.hop_at(cell)
	if k >= 0:
		var state: Dictionary = game.hops[k]
		if state.windup > 0.0:  # crouch and shake
			squash = 0.7
			c.x += sin(now * 70.0) * 1.8
			hop = 0.0
		elif state.slide > 0.0:  # in the air, coming from the previous cell
			var left: float = state.slide / SnakeGame.Cfg.HOP_STEP
			c -= Vector2(state.dir) * View.CELL * left
			c.y -= sin((1.0 - left) * PI) * View.CELL * 0.4
			face = signf(state.dir.x) if state.dir.x != 0 else face
	var body := c + Vector2(sin(now * 31.0 + phase) * 0.6 * Art.prey_nerves, 2.0 - hop * 3.0)
	_draw_species(Art.PreySpecies.CHICK, body, r, face, squash, id, now, phase, fill)


## Prey drawings by species. Only chickens are used now (spec §6); the seed's species (seed[10],
## seed[11]) are kept for the later prey tiers.
func _draw_species(species: int, body: Vector2, r: float, face: float, squash: float, id: int, now: float,
		phase: float, fill: Color) -> void:
	match species:
		Art.PreySpecies.MOUSE:
			_draw_mouse(body, r, face, squash, id, now, phase)
		Art.PreySpecies.BEETLE:
			_draw_beetle(body, r, face, squash, id, now, phase)
		Art.PreySpecies.CHICK:
			_draw_chick(body, r, face, squash, id, now, phase, fill)
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
	Ink.disc(self, body + Vector2(face * r * 1.1, r * 0.15), 2.2, Ink.INK)


func _draw_chick(body: Vector2, r: float, face: float, squash: float, id: int, now: float, phase: float,
		fill := Ink.PAPER) -> void:
	# Spindly legs, round fluffy body, a wing stub, a three-hair tuft, a beak.
	for s in 2:
		var x := (s - 0.5) * r * 0.6
		draw_line(body + Vector2(x, r * 0.8), body + Vector2(x + face * r * 0.15, r * 1.25), Ink.INK, 1.6, true)
	Ink.blob(self, body, Vector2(r * 1.0 / squash, r * squash), fill, 2.0, id)
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
	Ink.disc(self, head, r * 0.42, Ink.INK)
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
