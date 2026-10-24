## Recipes for every sound in the game (spec §10), from the "snake-sounds" seed (SoundDirection).
## Each recipe only lists notes and passes into a Synth.Job; the job renders them a chunk at a time.
class_name SoundBank
extends RefCounted

const S := preload("res://presentation/synth.gd")
const D := preload("res://presentation/sound_direction.gd")
## Sound effects that only play with Gore on (spec §11).
const GORE := [&"crunch", &"splat"]
const EFFECTS := [&"click", &"gulp", &"squawk", &"crunch", &"splat", &"crash", &"enemy_die", &"life_lost",
		&"fanfare", &"tick", &"gong"]
const MUSIC := [&"title", &"game"]  # the menu waltz first, it is heard first


## The job that builds a sound: an effect or a music loop.
static func job(sound: StringName) -> S.Job:
	return music(sound) if sound in MUSIC else effect(sound)


static func effect(sound: StringName) -> S.Job:
	var j: S.Job
	match sound:
		&"click":  # a wood block
			j = S.Job.new(0.06)
			j.note(0.0, 0.06, 900.0, S.Wave.TRIANGLE, 0.6, 700.0, 70.0)
		&"gulp":  # a cartoon swallow: two quick drops in pitch (seed[7])
			j = S.Job.new(0.3)
			j.note(0.0, 0.12, 420.0, S.Wave.SINE, 0.9, D.gulp_hz, 12.0)
			j.note(0.1, 0.18, 330.0, S.Wave.SINE, 0.7, D.gulp_hz * 0.8, 10.0)
			j.noise(0.0, 0.05, 0.25, 500.0, 40.0)
		&"squawk":  # a startled chicken (seed[8])
			j = S.Job.new(0.3)
			j.note(0.0, 0.09, D.squawk_hz, S.Wave.SAW, 0.5, D.squawk_hz * 1.3, 8.0, 0.005, 0.08, 30.0)
			j.note(0.11, 0.16, D.squawk_hz * 1.2, S.Wave.SAW, 0.5, D.squawk_hz * 0.8, 8.0, 0.005, 0.08, 30.0)
			j.lowpass(3000.0)
		&"crunch":  # bones snapping (seed[9])
			j = S.Job.new(0.25)
			for k in 5:
				j.noise(k * 0.028, 0.06, 0.8, D.crunch_hz, 60.0, k + 3)
			j.note(0.0, 0.15, 95.0, S.Wave.SINE, 0.8, 60.0, 25.0)
		&"splat":
			j = S.Job.new(0.4)
			j.noise(0.0, 0.4, 0.9, 900.0, 9.0, 11)
			j.note(0.0, 0.2, 180.0, S.Wave.SINE, 0.6, 60.0, 14.0)
		&"crash":
			j = S.Job.new(0.7)
			j.noise(0.0, 0.7, 0.8, 2500.0, 5.0, 13)
			j.note(0.0, 0.45, 70.0, S.Wave.SINE, 1.0, 45.0, 8.0)
			j.note(0.0, 0.3, 300.0, S.Wave.SAW, 0.25, 80.0, 6.0)
		&"enemy_die":  # a falling slide whistle over a crunch (vibrato seed[12])
			j = S.Job.new(0.8)
			j.note(0.0, 0.7, 1400.0, S.Wave.SINE, 0.6, 260.0, 2.0, 0.02, D.vibrato * 2.0, 9.0)
			j.noise(0.05, 0.15, 0.5, D.crunch_hz, 30.0, 17)
		&"life_lost":  # the sad "wah wah wah wahhh" trombone
			j = S.Job.new(1.9)
			var top := D.degree_hz(4, -1)
			for k in 4:
				var length := 0.9 if k == 3 else 0.32
				j.note(k * 0.34, length, top * pow(2.0, -k / 12.0), S.Wave.SAW, 0.6, -1.0, 1.5, 0.06,
						D.vibrato * (3.0 if k == 3 else 1.0), 6.0)
			j.lowpass(1100.0)
		&"fanfare":  # a rising brass arpeggio in the seed's key
			j = S.Job.new(1.4)
			for k in 4:
				var length := 0.7 if k == 3 else 0.14
				j.note(k * 0.14, length, D.degree_hz([0, 2, 4, 7][k]), S.Wave.SQUARE, 0.5, -1.0, 2.0, 0.01,
						D.vibrato if k == 3 else 0.0)
			j.lowpass(2500.0)
			j.echo(0.11, D.echo)
		&"tick":  # a clock tick for the last seconds
			j = S.Job.new(0.05)
			j.note(0.0, 0.04, 1800.0, S.Wave.SINE, 0.7, -1.0, 120.0)
			j.noise(0.0, 0.01, 0.4, 6000.0, 300.0)
		&"gong":  # time up: inharmonic partials ringing out
			j = S.Job.new(2.2)
			var base := D.degree_hz(0, -2)
			for p in [[1.0, 1.0, 1.4], [2.76, 0.5, 2.0], [5.4, 0.25, 3.0], [1.5, 0.3, 1.8]]:
				j.note(0.0, 2.2, base * p[0], S.Wave.SINE, p[1], base * p[0] * 0.99, p[2], 0.002)
			j.noise(0.0, 0.08, 0.3, 3000.0, 40.0)
	return j


## One piano note in the seed's piano style (seed[4]), with strings out of tune by seed[3] cents.
static func piano(j: S.Job, at: float, hz: float, length: float, volume: float) -> void:
	var off := pow(2.0, D.detune / 1200.0)
	match D.piano:
		D.Piano.TOY:
			j.note(at, length, hz, S.Wave.SINE, volume, -1.0, 7.0)
			j.note(at, length, hz * 2.01, S.Wave.SINE, volume * 0.35, -1.0, 9.0)
		D.Piano.HONKY_TONK:
			j.note(at, length, hz * off, S.Wave.TRIANGLE, volume * 0.6, -1.0, 4.0)
			j.note(at, length, hz / off, S.Wave.TRIANGLE, volume * 0.6, -1.0, 4.0)
		_:
			j.note(at, length, hz * off, S.Wave.SINE, volume, -1.0, 9.0)
			j.note(at, length, hz * 4.0, S.Wave.SINE, volume * 0.25, -1.0, 14.0)


## A music loop: "title" is a slow minor waltz (seed[1]), "game" a fast stride-piano rag (seed[0]).
## Chord roots as scale degrees: i iv V i VI iv V i, the rag twice as long with each chord held.
static func music(name: StringName) -> S.Job:
	var waltz := name == &"title"
	var beats := 3 if waltz else 2
	var beat := 60.0 / (D.waltz_bpm if waltz else D.rag_bpm)
	var bars: Array = [0, 3, 4, 0, 5, 3, 4, 0] if waltz else [0, 0, 3, 3, 0, 0, 4, 4, 5, 5, 3, 3, 4, 4, 0, 0]
	var j := S.Job.new(bars.size() * beats * beat, true, 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = D.melody_seed + (1 if waltz else 2)
	var melody := 0  # scale degree of the melody's random walk
	for index in bars.size():
		var chord: int = bars[index]
		var start := index * beats * beat
		# Bass on the first beat, chord stabs on the others: oom-pah-pah, or the rag's oom-pah.
		piano(j, start, D.degree_hz(chord, -2), beat * 0.9, 0.7)
		for b in range(1, beats):
			for k in 3:
				piano(j, start + b * beat, D.degree_hz(chord + k * 2, -1), beat * 0.5, 0.25)
		# Melody: a random walk over the scale that leans towards chord tones. The rag plays eighths,
		# off-beats a little late (swing, seed[6]); the waltz one note per beat.
		var notes := beats * (1 if waltz else 2)
		var step_len := beat * beats / notes
		for n in notes:
			if not waltz and rng.randf() < 0.2:
				continue  # a rest keeps the rag jumpy
			melody = clampi(melody + rng.randi_range(-2, 2), -2, 9)
			if n == 0 and posmod(melody - chord, 2) == 1:
				melody += 1
			var late := step_len * D.swing if n % 2 == 1 else 0.0
			var last := index == bars.size() - 1 and n == notes - 1
			piano(j, start + n * step_len + late, D.degree_hz(melody, 0), step_len * (2.5 if last else 1.2), 0.45)
	j.echo(beat * 0.75, D.echo * 0.5)
	j.crackle(D.crackle)
	return j
