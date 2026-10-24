## Pooled cartoon gore: blood droplets, flying bones, and floor splats that fade.
## Fixed-size pools, so spawning and drawing never allocate.
extends Node2D

const MAX_DROPS := 256
const MAX_BONES := 24
const MAX_SPLATS := 160
const SPLAT_LIFETIME := 25.0
const BONE_LIFETIME := 3.0
static var BLOOD: Color = Art.blood  # seed[22]
static var BLOOD_DARK: Color = Art.blood.darkened(0.35)

var _drop_pos := PackedVector2Array()
var _drop_vel := PackedVector2Array()
var _drop_life := PackedFloat32Array()
var _drop_size := PackedFloat32Array()
var _drop_count := 0

var _bone_pos := PackedVector2Array()
var _bone_vel := PackedVector2Array()
var _bone_rot := PackedFloat32Array()
var _bone_spin := PackedFloat32Array()
var _bone_age := PackedFloat32Array()
var _bone_count := 0

var _splat_pos := PackedVector2Array()
var _splat_size := PackedFloat32Array()
var _splat_age := PackedFloat32Array()
var _splat_next := 0
var _splat_count := 0
var _since_splat := INF  # seconds since the newest splat; all splats are gone after SPLAT_LIFETIME


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # for the shared disc texture
	_drop_pos.resize(MAX_DROPS)
	_drop_vel.resize(MAX_DROPS)
	_drop_life.resize(MAX_DROPS)
	_drop_size.resize(MAX_DROPS)
	_bone_pos.resize(MAX_BONES)
	_bone_vel.resize(MAX_BONES)
	_bone_rot.resize(MAX_BONES)
	_bone_spin.resize(MAX_BONES)
	_bone_age.resize(MAX_BONES)
	_splat_pos.resize(MAX_SPLATS)
	_splat_size.resize(MAX_SPLATS)
	_splat_age.resize(MAX_SPLATS)


## A spray of blood (and optionally bones) bursting out of `at`. The amount is scaled by the seed's
## gore multiplier (seed[14]) and extra bones (seed[15]).
func burst(at: Vector2, drops: int, force: float, bones: int) -> void:
	drops = int(drops * Art.gore_amount)
	if bones > 0:
		bones += Art.extra_bones
	for i in drops:
		if _drop_count >= MAX_DROPS:
			break
		var angle := randf() * TAU
		_drop_pos[_drop_count] = at
		_drop_vel[_drop_count] = Vector2.from_angle(angle) * force * randf_range(0.25, 1.0)
		_drop_life[_drop_count] = randf_range(0.2, 0.55)
		_drop_size[_drop_count] = randf_range(2.0, 5.0)
		_drop_count += 1
	for i in bones:
		if _bone_count >= MAX_BONES:
			break
		_bone_pos[_bone_count] = at
		_bone_vel[_bone_count] = Vector2.from_angle(randf() * TAU) * force * randf_range(0.4, 0.8)
		_bone_rot[_bone_count] = randf() * TAU
		_bone_spin[_bone_count] = randf_range(-14.0, 14.0)
		_bone_age[_bone_count] = 0.0
		_bone_count += 1
	splat(at, randf_range(10.0, 15.0))


## A blood stain on the floor. Oldest stains are reused once the pool is full.
func splat(at: Vector2, size: float) -> void:
	_splat_pos[_splat_next] = at
	_splat_size[_splat_next] = size
	_splat_age[_splat_next] = 0.0
	_splat_next = (_splat_next + 1) % MAX_SPLATS
	_splat_count = mini(_splat_count + 1, MAX_SPLATS)
	_since_splat = 0.0


func active_count() -> int:
	return _drop_count + _bone_count + _splat_count


## True while anything is still visible, so finished gore stops costing redraws.
func is_active() -> bool:
	return _drop_count > 0 or _bone_count > 0 or _since_splat < SPLAT_LIFETIME


func clear() -> void:
	_drop_count = 0
	_bone_count = 0
	_splat_count = 0
	_splat_next = 0
	_since_splat = INF
	queue_redraw()


func _process(delta: float) -> void:
	var drag := exp(-5.0 * delta)
	var i := 0
	while i < _drop_count:
		_drop_life[i] -= delta
		if _drop_life[i] <= 0.0:
			splat(_drop_pos[i], _drop_size[i] * 1.5)
			_drop_count -= 1
			_drop_pos[i] = _drop_pos[_drop_count]
			_drop_vel[i] = _drop_vel[_drop_count]
			_drop_life[i] = _drop_life[_drop_count]
			_drop_size[i] = _drop_size[_drop_count]
			continue
		_drop_pos[i] += _drop_vel[i] * delta
		_drop_vel[i] *= drag
		i += 1
	i = 0
	while i < _bone_count:
		_bone_age[i] += delta
		if _bone_age[i] >= BONE_LIFETIME:
			_bone_count -= 1
			_bone_pos[i] = _bone_pos[_bone_count]
			_bone_vel[i] = _bone_vel[_bone_count]
			_bone_rot[i] = _bone_rot[_bone_count]
			_bone_spin[i] = _bone_spin[_bone_count]
			_bone_age[i] = _bone_age[_bone_count]
			continue
		_bone_pos[i] += _bone_vel[i] * delta
		_bone_vel[i] *= drag
		_bone_rot[i] += _bone_spin[i] * delta * _bone_vel[i].length() / 200.0
		i += 1
	_since_splat += delta
	for k in _splat_count:
		_splat_age[k] += delta
	if is_active():
		queue_redraw()


func _draw() -> void:
	if not is_active():
		return
	for k in _splat_count:
		var fade := 1.0 - _splat_age[k] / SPLAT_LIFETIME
		if fade <= 0.0:
			continue
		var at := _splat_pos[k]
		var size := _splat_size[k]
		var color := Color(BLOOD_DARK if k % 3 == 0 else BLOOD, fade)
		Ink.disc(self, at, size * 0.6, color)
		for j in 4:  # irregular blob: a few lobes around the centre
			var dir := Vector2.from_angle(Ink.rand(k, j) * TAU)
			Ink.disc(self, at + dir * size * 0.55, size * (0.2 + 0.25 * Ink.rand(k, j + 9)), color)
	# Drops as a short streak of discs along their flight, all one texture so they batch.
	for k in _drop_count:
		var tail := _drop_vel[k].limit_length(_drop_size[k] * 40.0) * 0.012  # keep the dots touching
		for j in 3:
			Ink.disc(self, _drop_pos[k] - tail * j, _drop_size[k] * (0.5 - 0.1 * j), BLOOD)
	for k in _bone_count:
		var alpha := clampf((BONE_LIFETIME - _bone_age[k]) / 0.5, 0.0, 1.0)
		Ink.bone(self, _bone_pos[k], _bone_rot[k], 10.0, alpha)
