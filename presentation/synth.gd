## A tiny synthesiser (spec §10, §17). A Job collects notes, noise and finishing passes (low-pass,
## echo, crackle), then renders them a chunk of samples at a time into a 16-bit AudioStreamWAV, so
## building sounds never stalls the single-threaded web build. Plain math only: every sound is
## reproducible and costs no download.
class_name Synth
extends RefCounted

const RATE := 22050
const CHUNK := 2048  # samples of work per step: well under a millisecond or two
enum Wave { SINE, TRIANGLE, SAW, SQUARE }
enum Pass { LOWPASS, ECHO, CRACKLE }


class Job extends RefCounted:
	var buf := PackedFloat32Array()
	var stream: AudioStreamWAV
	var _voices: Array = []
	var _passes: Array = []  # [Pass, a, b], applied in order after all voices
	var _loop: bool
	var _peak: float
	var _stage := 0  # 0 voices, 1 passes, 2 peak scan, 3 encode, 4 done
	var _pass := 0
	var _pos := 0
	var _y := 0.0  # low-pass state between chunks
	var _rng := RandomNumberGenerator.new()
	var _top := 0.0001
	var _data := PackedByteArray()

	func _init(seconds: float, loop := false, peak := 0.8) -> void:
		buf.resize(int(seconds * RATE))
		_loop = loop
		_peak = peak

	## A note: `wave` at `freq` Hz (sliding to `freq_end` if given), a short attack, then an exponential
	## decay of `decay` per second. `vib` is vibrato depth as a fraction of the pitch.
	func note(at: float, length: float, freq: float, wave: int, volume: float, freq_end := -1.0, decay := 6.0,
			attack := 0.005, vib := 0.0, vib_hz := 5.5) -> void:
		_voices.append(Voice.new(buf.size(), at, length, freq, freq_end, wave, volume, decay, attack, vib, vib_hz))

	## Noise through a one-pole low-pass at `cutoff` Hz, decaying like a note.
	func noise(at: float, length: float, volume: float, cutoff: float, decay := 10.0, rng_seed := 1) -> void:
		_voices.append(NoiseVoice.new(buf.size(), at, length, volume, cutoff, decay, rng_seed))

	## Takes the fizz off saws and squares.
	func lowpass(cutoff: float) -> void:
		_passes.append([Pass.LOWPASS, 1.0 - exp(-TAU * cutoff / RATE), 0.0])

	## A feedback echo, like a small hall.
	func echo(delay: float, feedback: float) -> void:
		_passes.append([Pass.ECHO, float(int(delay * RATE)), feedback])

	## Gramophone surface noise: a soft hiss and sparse clicks.
	func crackle(amount: float, rng_seed := 7) -> void:
		_passes.append([Pass.CRACKLE, amount, float(rng_seed)])

	## About CHUNK samples of work. Returns true once `stream` is ready.
	func step() -> bool:
		var n := buf.size()
		match _stage:
			0:
				if _voices.is_empty():
					_stage = 1
				elif _voices.back().render(buf, CHUNK):
					_voices.pop_back()
			1:
				if _pass >= _passes.size():
					_stage = 2
				else:
					var p: Array = _passes[_pass]
					if _pos == 0:
						_y = 0.0
						_rng.seed = int(p[2])
					var to := mini(n, _pos + CHUNK)
					_run_pass(p, _pos, to)
					_pos = to
					if _pos >= n:
						_pos = 0
						_pass += 1
			2:
				var to := mini(n, _pos + CHUNK)
				for i in range(_pos, to):
					_top = maxf(_top, absf(buf[i]))
				_pos = to
				if _pos >= n:
					_pos = 0
					_data.resize(n * 2)
					_stage = 3
			3:
				var to := mini(n, _pos + CHUNK)
				var gain := _peak / _top
				for i in range(_pos, to):
					var x := buf[i] * gain
					x = x / (1.0 + absf(x) * 0.25) * 1.25  # soft knee, never above 1
					_data.encode_s16(i * 2, int(clampf(x, -1.0, 1.0) * 32767.0))
				_pos = to
				if _pos >= n:
					_finish()
		return _stage == 4

	## Builds everything at once (tests and tools).
	func finish_now() -> AudioStreamWAV:
		while not step():
			pass
		return stream

	func _run_pass(p: Array, from: int, to: int) -> void:
		match p[0]:
			Pass.LOWPASS:
				var a: float = p[1]
				for i in range(from, to):
					_y += a * (buf[i] - _y)
					buf[i] = _y
			Pass.ECHO:
				var d := int(p[1])
				var fb: float = p[2]
				for i in range(maxi(from, d), to):
					buf[i] += buf[i - d] * fb
			Pass.CRACKLE:
				var amount: float = p[1]
				for i in range(from, to):
					var x := (_rng.randf() - 0.5) * amount * 0.3
					if _rng.randf() < 0.0004:
						x += (_rng.randf() - 0.5) * amount * 12.0
					buf[i] += x

	func _finish() -> void:
		stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = RATE
		stream.stereo = false
		stream.data = _data
		if _loop:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = buf.size()
		_stage = 4


## One oscillator note, rendered a chunk at a time; it keeps its phase and envelope in between.
class Voice extends RefCounted:
	var _start: int
	var _count: int
	var _i := 0
	var _freq: float
	var _slide: float
	var _wave: int
	var _volume: float
	var _fall: float
	var _rise: float
	var _vib: float
	var _vib_hz: float
	var _phase := 0.0
	var _env := 1.0
	var _release := int(0.01 * RATE)  # a quick fade at the end, so notes never click off

	func _init(size: int, at: float, length: float, freq: float, freq_end: float, wave: int, volume: float,
			decay: float, attack: float, vib: float, vib_hz: float) -> void:
		_start = int(at * RATE)
		_count = maxi(0, mini(int(length * RATE), size - _start))
		_freq = freq
		_slide = (freq_end if freq_end > 0.0 else freq) - freq
		_wave = wave
		_volume = volume
		_fall = exp(-decay / RATE)
		_rise = 1.0 / maxf(1.0, attack * RATE)
		_vib = vib
		_vib_hz = vib_hz

	## Renders up to `budget` samples; true when the note is done.
	func render(buf: PackedFloat32Array, budget: int) -> bool:
		var end := mini(_count, _i + budget)
		var phase := _phase
		var env := _env
		var inv_count := 1.0 / maxf(1.0, float(_count))
		for i in range(_i, end):
			var f := _freq + _slide * i * inv_count
			if _vib > 0.0:
				f *= 1.0 + _vib * sin(TAU * _vib_hz * i / RATE)
			phase += f / RATE
			phase -= floorf(phase)
			var s: float
			if _wave == Wave.SINE:
				s = sin(TAU * phase)
			elif _wave == Wave.TRIANGLE:
				s = 4.0 * absf(phase - 0.5) - 1.0
			elif _wave == Wave.SAW:
				s = 2.0 * phase - 1.0
			else:
				s = 1.0 if phase < 0.5 else -1.0
			buf[_start + i] += s * env * minf(1.0, i * _rise) * minf(1.0, float(_count - i) / _release) * _volume
			env *= _fall
		_phase = phase
		_env = env
		_i = end
		return _i >= _count


## Filtered noise, rendered a chunk at a time.
class NoiseVoice extends RefCounted:
	var _start: int
	var _count: int
	var _i := 0
	var _volume: float
	var _a: float
	var _fall: float
	var _y := 0.0
	var _env := 1.0
	var _rng := RandomNumberGenerator.new()

	func _init(size: int, at: float, length: float, volume: float, cutoff: float, decay: float, rng_seed: int) -> void:
		_start = int(at * RATE)
		_count = maxi(0, mini(int(length * RATE), size - _start))
		_volume = volume
		_a = 1.0 - exp(-TAU * cutoff / RATE)
		_fall = exp(-decay / RATE)
		_rng.seed = rng_seed

	func render(buf: PackedFloat32Array, budget: int) -> bool:
		var end := mini(_count, _i + budget)
		for i in range(_i, end):
			_y += _a * (_rng.randf() * 2.0 - 1.0 - _y)
			buf[_start + i] += _y * _env * _volume
			_env *= _fall
		_i = end
		return _i >= _count
