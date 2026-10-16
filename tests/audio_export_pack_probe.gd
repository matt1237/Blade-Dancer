extends SceneTree

# CLI only: --headless --main-pack <exported.zip> --script <absolute path>
# Runs no game scene / autoload and never saves project or player data.
func _init() -> void:
	var paths: Array[String] = _paths("res://assets/audio")
	if paths.size() != 55:
		push_error("Pack inventory mismatch: %d" % paths.size())
		quit(1)
		return
	for path: String in paths:
		var stream: AudioStream = load(path) as AudioStream
		if stream == null or stream.get_length() <= 0.0:
			push_error("Pack failed to load stream: " + path)
			quit(1)
			return
		var playback: AudioStreamPlayback = stream.instantiate_playback()
		playback.start(stream.get_length() * 0.5)
		var frames: PackedVector2Array = playback.mix_audio(1.0, 4096)
		playback.stop()
		if frames.is_empty():
			push_error("Pack failed to decode: " + path)
			quit(1)
			return
	print("AUDIO EXPORT LOAD PASS: %d streams from %s" % [paths.size(), OS.get_cmdline_args()])
	quit(0)

func _paths(directory: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null: return result
	for file: String in dir.get_files():
		# Export retains import records, not necessarily original source files.
		if file.ends_with(".import"):
			var source: String = file.trim_suffix(".import")
			if source.get_extension() in ["mp3", "wav", "ogg"]:
				result.append(directory.path_join(source))
	for subdir: String in dir.get_directories():
		result.append_array(_paths(directory.path_join(subdir)))
	return result
