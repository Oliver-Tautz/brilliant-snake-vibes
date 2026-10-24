## Audio service (spec §10, §13 autoload): synthesises every sound at startup, a few small chunks per
## frame, plays effects from a small pool of players and runs the music loop. Volumes and mute come
## from Settings and are applied to the Music and SFX buses.
extends Node

const BUDGET_USEC := 4000  # synthesis time per frame while sounds are still being built
const PLAYERS := 8

var _streams := {}  # StringName -> AudioStreamWAV
var _to_build: Array = SoundBank.EFFECTS + SoundBank.MUSIC  # effects first, then the music
var _job: Synth.Job  # the sound being built now, for _to_build[0]
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music: AudioStreamPlayer
var _music_name := &""  # the loop that should be playing, even if it is not built yet
var _music_pitch := 1.0
var _playing_name := &""  # the loop actually started on the player; browsers may report playing = false
var _music_paused := false  # kept here too, so a loop that finishes building while paused starts paused


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i in PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	Settings.changed.connect(_apply_settings)
	_apply_settings()


## Builds sounds in chunks until this frame's budget is used. A chunk is a couple of thousand samples,
## so the budget is overrun by a millisecond at most.
func _process(_delta: float) -> void:
	var start := Time.get_ticks_usec()
	while is_building() and Time.get_ticks_usec() - start < BUDGET_USEC:
		build_step()
	if not is_building():
		set_process(false)


func is_building() -> bool:
	return not _to_build.is_empty()


## One chunk of synthesis. Returns false when everything is built.
func build_step() -> bool:
	if _to_build.is_empty():
		return false
	var name: StringName = _to_build[0]
	if _job == null:
		_job = SoundBank.job(name)
	if _job.step():
		var stream := _job.stream
		_job = null
		_to_build.pop_front()
		_on_built(name, stream)
	return true


## A sound is ready; a loop that is wanted right now starts playing.
func _on_built(name: StringName, stream: AudioStreamWAV) -> void:
	_streams[name] = stream
	if name == _music_name and name != _playing_name:
		_start_music()


## Builds everything at once (tests and tools).
func build_all() -> void:
	while build_step():
		pass


func has_sound(name: StringName) -> bool:
	return _streams.has(name)


## Plays an effect with a little random pitch, so repeats do not sound mechanical. Gore sounds are
## skipped with Gore off (spec §11).
func play(name: StringName, volume_db := 0.0, pitch_jitter := 0.06, pitch := 1.0) -> void:
	if not _streams.has(name) or (name in SoundBank.GORE and not Settings.gore):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % PLAYERS
	player.stream = _streams[name]
	player.volume_db = volume_db
	player.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	player.play()


## Switches the music loop ("title" or "game"); `pitch` speeds it up. Starts once it is built.
func play_music(name: StringName, pitch := 1.0) -> void:
	_music_pitch = pitch
	_music.pitch_scale = pitch
	_music_name = name  # also when it is not built yet: it starts once it is
	# Already on this loop: carry on where it was. Tracked here, because a paused player, and a looping
	# one in some browsers, reports playing = false.
	if name == _playing_name:
		return
	_start_music()


func stop_music() -> void:
	_music_name = &""
	_playing_name = &""
	_music.stop()


func music_name() -> StringName:
	return _music_name


func pause_music(paused: bool) -> void:
	_music_paused = paused
	_music.stream_paused = paused


func is_music_paused() -> bool:
	return _music_paused


func _start_music() -> void:
	if not _streams.has(_music_name):
		return
	_music.stream = _streams[_music_name]
	_music.pitch_scale = _music_pitch
	_music.play()
	_playing_name = _music_name
	_music.stream_paused = _music_paused


func _apply_settings() -> void:
	for bus in [["Music", Settings.music_volume], ["SFX", Settings.sound_volume]]:
		var index := AudioServer.get_bus_index(bus[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(bus[1] / 100.0, 0.0001)))
		AudioServer.set_bus_mute(index, Settings.muted or bus[1] == 0)
