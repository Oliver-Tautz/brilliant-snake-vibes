## Hand-inked drawing helpers: boiling lines, outlined blobs, pie-cut eyes, bones.
class_name Ink
extends RefCounted

const INK := Color(0.05, 0.05, 0.05)
static var PAPER := Color(Art.paper_tone, Art.paper_tone, Art.paper_tone * 0.99)  # seed[23]

# All procedural wobble and variation is seeded from divine_inspiration("snake-art").
static var _seed: int = Art.SEED.hash()
# Reused scratch arrays so drawing never allocates per frame.
static var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _quad_line := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _fang_line := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _rect_line := PackedVector2Array()


## Frame counter for line boil: lines re-wobble a few times a second (seed[8]), like redrawn cels.
static func boil_frame() -> int:
	return int(Time.get_ticks_msec() * Art.boil_fps / 1000.0)


## Deterministic pseudo-random value in 0..1 from two ints.
static func rand(a: int, b: int) -> float:
	var n := ((a * 73856093) ^ (b * 19349663) ^ _seed) & 0x7FFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	n = n ^ (n >> 16)
	return float(n & 0xFFFFFF) / float(0xFFFFFF)


## A small offset that changes every boil frame, scaled by the seed's boil strength (seed[9]).
static func wobble(id: int, amount: float) -> Vector2:
	var f := boil_frame()
	return Vector2(rand(id, f) - 0.5, rand(id + 7919, f) - 0.5) * 2.0 * amount * Art.boil_amount


## A filled ellipse with an uneven, boiling ink outline.
static func blob(ci: CanvasItem, center: Vector2, radii: Vector2, fill: Color, line: float, id: int,
		angle := 0.0) -> void:
	var c := center + wobble(id, 0.7)
	var w := line * (0.75 + 0.5 * rand(id, boil_frame() + 3))
	ellipse(ci, c, radii + Vector2(w, w), INK, angle)
	ellipse(ci, c, radii, fill, angle)


static func ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, color: Color, angle := 0.0) -> void:
	ci.draw_set_transform(center, angle, radii / 16.0)
	ci.draw_circle(Vector2.ZERO, 16.0, color, true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Rubber-hose eye: white oval, black pupil looking along `look`, with a pie-shaped notch cut out.
static func pie_eye(ci: CanvasItem, center: Vector2, r: float, look: Vector2, id: int) -> void:
	blob(ci, center, Vector2(r * 0.78, r), PAPER, maxf(1.4, r * 0.22), id)
	var p := center + look * r * 0.3 + Vector2(0.0, r * 0.12)
	var pr := r * 0.55
	ci.draw_circle(p, pr, INK, true, -1.0, true)
	_tri[0] = p
	_tri[1] = p + Vector2(pr * 1.15, -pr * 0.5)
	_tri[2] = p + Vector2(pr * 0.45, -pr * 1.15)
	ci.draw_colored_polygon(_tri, PAPER)


## A small triangle (fang or tooth) pointing from `base` towards `tip`, inked.
static func fang(ci: CanvasItem, base: Vector2, tip: Vector2, half_width: float) -> void:
	var side := (tip - base).orthogonal().normalized() * half_width
	_tri[0] = base - side
	_tri[1] = base + side
	_tri[2] = tip
	ci.draw_colored_polygon(_tri, PAPER)
	_fang_line[0] = _tri[0]
	_fang_line[1] = _tri[2]
	_fang_line[2] = _tri[1]
	_fang_line[3] = _tri[0]
	ci.draw_polyline(_fang_line, INK, 1.4, true)


## A cartoon dog-bone, inked, rotated by `angle`.
static func bone(ci: CanvasItem, center: Vector2, angle: float, length: float, alpha: float) -> void:
	var ink := Color(INK, alpha)
	var paper := Color(PAPER, alpha)
	var half := length * 0.5
	var knob := length * 0.2
	ci.draw_set_transform(center, angle, Vector2.ONE)
	for pass_i in 2:
		var grow := 1.6 if pass_i == 0 else 0.0
		var color := ink if pass_i == 0 else paper
		var r := knob * 0.7 + grow
		ci.draw_rect(Rect2(-half, -knob * 0.5 - grow, length, knob + grow * 2.0), color)
		ci.draw_circle(Vector2(-half, -knob * 0.6), r, color, true, -1.0, true)
		ci.draw_circle(Vector2(-half, knob * 0.6), r, color, true, -1.0, true)
		ci.draw_circle(Vector2(half, -knob * 0.6), r, color, true, -1.0, true)
		ci.draw_circle(Vector2(half, knob * 0.6), r, color, true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A thick, wobbling ink rectangle outline, e.g. the arena walls.
static func wobbly_rect(ci: CanvasItem, rect: Rect2, width: float, id: int) -> void:
	var step := 48.0
	var nx := maxi(1, int(rect.size.x / step))
	var ny := maxi(1, int(rect.size.y / step))
	_rect_line.resize((nx + ny) * 2 + 1)
	var k := 0
	for i in nx:
		_rect_line[k] = rect.position + Vector2(rect.size.x * i / nx, 0.0) + wobble(id + k, 1.5)
		k += 1
	for i in ny:
		_rect_line[k] = rect.position + Vector2(rect.size.x, rect.size.y * i / ny) + wobble(id + k, 1.5)
		k += 1
	for i in nx:
		_rect_line[k] = rect.end - Vector2(rect.size.x * i / nx, 0.0) + wobble(id + k, 1.5)
		k += 1
	for i in ny:
		_rect_line[k] = rect.position + Vector2(0.0, rect.size.y - rect.size.y * i / ny) + wobble(id + k, 1.5)
		k += 1
	_rect_line[k] = _rect_line[0]
	ci.draw_polyline(_rect_line, INK, width, true)


## A diamond (rhombus) with half-diagonals `r`, filled or outlined.
static func diamond(ci: CanvasItem, center: Vector2, r: Vector2, color: Color, outline := 0.0) -> void:
	_quad[0] = center + Vector2(0.0, -r.y)
	_quad[1] = center + Vector2(r.x, 0.0)
	_quad[2] = center + Vector2(0.0, r.y)
	_quad[3] = center + Vector2(-r.x, 0.0)
	if outline <= 0.0:
		ci.draw_colored_polygon(_quad, color)
		return
	for i in 4:
		_quad_line[i] = _quad[i]
	_quad_line[4] = _quad[0]
	ci.draw_polyline(_quad_line, color, outline, true)


## A filled ink triangle (beak, snout tip).
static func triangle(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_tri[0] = a
	_tri[1] = b
	_tri[2] = c
	ci.draw_colored_polygon(_tri, color)
