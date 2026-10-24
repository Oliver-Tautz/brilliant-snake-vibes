extends GutTest
## The synthesiser, the sound recipes and the Sound autoload (spec §10).

var _saved: Array


func before_all() -> void:
	_saved = [Settings.gore, Settings.music_volume, Settings.sound_volume, Settings.muted]
	Sound.build_all()


func after_all() -> void:
	Settings.gore = _saved[0]
	Settings.music_volume = _saved[1]
	Settings.sound_volume = _saved[2]
	Settings.muted = _saved[3]
	Sound._apply_settings()


func test_every_sound_gets_built() -> void:
	assert_false(Sound.is_building())
	for name in SoundBank.EFFECTS + [&"title", &"game"]:
		assert_true(Sound.has_sound(name), name)


func test_effects_are_short_and_never_silent_or_clipping() -> void:
	for name in SoundBank.EFFECTS:
		var job := SoundBank.effect(name)
		var stream := job.finish_now()
		assert_between(job.buf.size() / float(Synth.RATE), 0.04, 2.5, name)
		var peak := 0.0
		for x in job.buf:
			peak = maxf(peak, absf(x))
		assert_gt(peak, 0.1, name)
		var top := 0
		for i in range(0, stream.data.size(), 2):
			top = maxi(top, absi(stream.data.decode_s16(i)))
		assert_lte(top, 32767, name)
		assert_gt(top, 20000, name)  # normalised


func test_music_loops_follow_the_seed_tempo() -> void:
	var stream := SoundBank.music(&"game").finish_now()
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	var seconds := stream.data.size() / 2.0 / Synth.RATE
	assert_almost_eq(seconds, 16 * 2 * 60.0 / SoundDirection.rag_bpm, 0.01)  # 16 bars of 2/4


func test_every_build_step_is_small() -> void:
	# The web build is single-threaded: no step may stall a frame (budget 4 ms, CHUNK samples a step).
	var worst := 0
	for name in SoundBank.EFFECTS + SoundBank.MUSIC:
		var job := SoundBank.job(name)
		var done := false
		while not done:
			var start := Time.get_ticks_usec()
			done = job.step()
			worst = maxi(worst, Time.get_ticks_usec() - start)
	assert_lt(worst, 15000, "worst step %d us" % worst)


func test_a_voice_renders_at_most_one_chunk_per_step() -> void:
	var buf := PackedFloat32Array()
	buf.resize(Synth.RATE)
	var voice := Synth.Voice.new(buf.size(), 0.0, 1.0, 440.0, -1.0, Synth.Wave.SINE, 1.0, 0.0, 0.005, 0.0, 5.0)
	assert_false(voice.render(buf, Synth.CHUNK))
	assert_eq(buf[Synth.CHUNK + 10], 0.0)  # nothing beyond the chunk yet
	while not voice.render(buf, Synth.CHUNK):
		pass
	assert_ne(buf[Synth.CHUNK + 10], 0.0)


func test_sound_direction_decodes_the_seed() -> void:
	assert_eq(SoundDirection.SEED.length(), 64)
	assert_eq(SoundDirection.value(0), 35)  # 'j'
	assert_between(SoundDirection.rag_bpm, 150.0, 200.0)
	assert_between(SoundDirection.waltz_bpm, 84.0, 120.0)
	assert_almost_eq(SoundDirection.degree_hz(7) / SoundDirection.degree_hz(0), 2.0, 0.001)  # an octave


func test_note_ends_without_a_click() -> void:
	var job := Synth.Job.new(0.2)
	job.note(0.0, 0.1, 440.0, Synth.Wave.SQUARE, 1.0, -1.0, 0.0)
	job.finish_now()
	assert_almost_eq(job.buf[int(0.1 * Synth.RATE) - 1], 0.0, 0.01)


func test_music_resumes_where_it_paused() -> void:
	Sound.play_music(&"game")
	var playback := Sound._music.get_stream_playback()
	Sound.pause_music(true)
	Sound.play_music(&"game")  # what resuming a run does
	Sound.pause_music(false)
	assert_eq(Sound._music.get_stream_playback(), playback)  # same playback, not restarted


func test_gore_sounds_are_skipped_with_gore_off() -> void:
	Settings.gore = false
	var before: Array = []
	for p in Sound._players:
		before.append(p.stream)
	Sound.play(&"splat")
	var after: Array = []
	for p in Sound._players:
		after.append(p.stream)
	assert_eq(after, before)
	Settings.gore = true
	Sound.play(&"splat")
	var used := false
	for p in Sound._players:
		used = used or p.stream == Sound._streams[&"splat"]
	assert_true(used)


func test_volumes_and_mute_reach_the_buses() -> void:
	Settings.music_volume = 50
	Settings.sound_volume = 0
	Settings.muted = false
	Sound._apply_settings()
	var music := AudioServer.get_bus_index("Music")
	var sfx := AudioServer.get_bus_index("SFX")
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), 0.01)
	assert_false(AudioServer.is_bus_mute(music))
	assert_true(AudioServer.is_bus_mute(sfx))  # 0% is silent
	Settings.muted = true
	Sound._apply_settings()
	assert_true(AudioServer.is_bus_mute(music))


func test_music_switches_and_keeps_its_pitch() -> void:
	Sound.play_music(&"game", 1.2)
	assert_eq(Sound.music_name(), &"game")
	assert_eq(Sound._music.stream, Sound._streams[&"game"])
	assert_almost_eq(Sound._music.pitch_scale, 1.2, 0.001)
	Sound.stop_music()
	assert_eq(Sound.music_name(), &"")


func test_music_built_while_paused_starts_paused() -> void:
	Sound.stop_music()
	Sound.pause_music(true)
	Sound._music_name = &"title"
	Sound._start_music()  # what happens when the loop finishes building
	assert_true(Sound._music.stream_paused)
	Sound.pause_music(false)
	Sound.stop_music()
