## Writes every synthesised sound as a WAV file, to listen to them outside the game.
## Usage: godot --headless --path . -s tools/export_sounds.gd -- <folder>
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://sounds"
	DirAccess.make_dir_recursive_absolute(folder)
	for name in SoundBank.EFFECTS + SoundBank.MUSIC:
		SoundBank.job(name).finish_now().save_to_wav(folder.path_join(name + ".wav"))
	print("saved ", SoundBank.EFFECTS.size() + SoundBank.MUSIC.size(), " sounds to ", folder)
	quit()
