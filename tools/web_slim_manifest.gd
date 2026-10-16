extends SceneTree
## Packaging-only CLI, never instances Main or writes user:// / project.godot.
## --script tools/web_slim_manifest.gd -- --update
## Refresh after adding runtime content; review unresolved paths before export.
## Pack-only validation: --main-pack <pck> --script <absolute this file> -- --probe <absolute manifest.json>
const PRESET := "Web Slim"
const REPORT := "res://builds/web-slim-audit/source-manifest.json"
var selected: Dictionary = {}
var classes: Dictionary = {}
var pending: Array[String] = []
var unresolved: Array[String] = []
var literals := RegEx.new()
var words := RegEx.new()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--probe":
		_probe(args[1])
		return
	literals.compile("#[^\\n]*|\"((?:[^\"\\\\]|\\\\.)*)\"|'((?:[^'\\\\]|\\\\.)*)'")
	words.compile("\\b[A-Za-z_][A-Za-z_0-9]*\\b")
	var class_pattern := RegEx.new()
	class_pattern.compile("(?m)^class_name\\s+(\\w+)")
	for dir: String in ["res://scripts", "res://blade_dancer_px/scripts"]:
		for path: String in _files(dir):
			if path.ends_with(".gd"):
				var match_class := class_pattern.search(FileAccess.get_file_as_string(path))
				if match_class != null:
					classes[match_class.get_string(1)] = path
	var settings := ConfigFile.new()
	if settings.load("res://project.godot") != OK:
		quit(1)
		return
	_add(str(settings.get_value("application", "run/main_scene")))
	_add(str(settings.get_value("application", "config/icon")))
	for key: String in settings.get_section_keys("autoload"):
		_add(str(settings.get_value("autoload", key)).trim_prefix("*"))
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if path.get_extension() == "json": continue
		for dependency: String in ResourceLoader.get_dependencies(path):
			# Godot returns UID::type::fallback for some dependencies.
			var parts := dependency.split("::")
			_add(parts[-1] if parts.size() > 1 else dependency)
		if path.get_extension() not in ["gd", "tscn", "tres", "gdshader"]: continue
		var text := FileAccess.get_file_as_string(path)
		for quoted: RegExMatch in literals.search_all(text):
			var value := quoted.get_string(1) if not quoted.get_string(1).is_empty() else quoted.get_string(2)
			if value.begins_with("res://"):
				if value == "res://assets/generated/kaji_bird_%d_frame_%d_v1.png":
					# Both merchant loops: 3 variants x 6 frames (not source atlases).
					for variant: int in range(3):
						for frame: int in range(6): _add(value % [variant, frame])
				elif "%" in value:
					unresolved.append(path + ": " + value)
				elif DirAccess.dir_exists_absolute(value):
					# Conservatively retain a whole referenced directory if needed.
					for child: String in _files(value):
						if not child.ends_with(".import") and not child.ends_with(".uid"): _add(child)
				elif FileAccess.file_exists(value): _add(value)
				else: unresolved.append(path + ": " + value)
		if path.ends_with(".gd"):
			for token: RegExMatch in words.search_all(text):
				if classes.has(token.get_string()): _add(classes[token.get_string()])
	var paths := PackedStringArray(selected.keys())
	paths.sort()
	var resources := PackedStringArray()
	var nonresources := PackedStringArray()
	for path: String in paths:
		if path.get_extension() in ["json", "cfg", "txt", "csv"]: nonresources.append(path.trim_prefix("res://"))
		else: resources.append(path)
	if not unresolved.is_empty():
		push_error("Review unresolved references: " + str(unresolved))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://builds/web-slim-audit")
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string(JSON.stringify({"roots": [settings.get_value("application", "run/main_scene"), "autoloads", "application icon"], "paths": paths, "dynamic_birds": 18, "unresolved": unresolved}, "\t"))
	file.close()
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		quit(1)
		return
	var target := ""
	for section: String in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options") and config.get_value(section, "name", "") == PRESET: target = section
	if "--update" in args:
		if target.is_empty():
			var index := 0
			while config.has_section("preset.%d" % index): index += 1
			target = "preset.%d" % index
			for section: String in ["preset.1", "preset.1.options"]:
				var dest := target + (".options" if section.ends_with(".options") else "")
				for key: String in config.get_section_keys(section): config.set_value(dest, key, config.get_value(section, key))
		config.set_value(target, "name", PRESET)
		# Godot serializes EXPORT_SELECTED_RESOURCES as "resources", not its enum name.
		config.set_value(target, "export_filter", "resources")
		config.set_value(target, "exclude_filter", "addons/*,tests/*,builds/*,BladeDancerWeb/*,tools/*,*.ogv")
		config.set_value(target, "export_files", resources)
		config.set_value(target, "include_filter", ",".join(nonresources))
		config.set_value(target, "export_path", "builds/web-slim/index.html")
		config.set_value(target + ".options", "variant/thread_support", false)
		if config.save("res://export_presets.cfg") != OK:
			quit(1)
			return
	else:
		if target.is_empty() or config.get_value(target, "export_filter", "") != "resources" or config.get_value(target, "export_files", PackedStringArray()) != resources or config.get_value(target, "include_filter", "") != ",".join(nonresources) or config.get_value(target + ".options", "variant/thread_support", true):
			push_error("Web Slim selection is stale; run --update and review.")
			quit(1)
			return
	print("WEB SLIM MANIFEST PASS: %d resources; non-resource filters: %s" % [resources.size(), nonresources])
	quit(0)

func _add(path: String) -> void:
	if selected.has(path): return
	if not FileAccess.file_exists(path):
		unresolved.append(path)
		return
	selected[path] = true
	pending.append(path)

func _files(directory: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null: return result
	for file: String in dir.get_files(): result.append(directory.path_join(file))
	for subdir: String in dir.get_directories():
		if not subdir.begins_with("."): result.append_array(_files(directory.path_join(subdir)))
	return result

func _probe(manifest_path: String) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var count := 0
	var streams := 0
	for path: String in manifest["paths"]:
		if path.get_extension() in ["json", "cfg", "txt", "csv"]:
			if not FileAccess.file_exists(path):
				push_error("Missing packaged data: " + path)
				quit(1)
				return
			if path.ends_with("default_global_preset.json"):
				var defaults: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if not defaults is Dictionary or defaults.is_empty():
					push_error("Invalid packaged launch defaults")
					quit(1)
					return
			continue
		var resource := ResourceLoader.load(path)
		if resource == null:
			push_error("Cannot load packaged resource: " + path)
			quit(1)
			return
		if resource is AudioStream:
			if resource.get_length() <= 0.0:
				quit(1)
				return
			var playback: AudioStreamPlayback = resource.instantiate_playback()
			playback.start(resource.get_length() * 0.5)
			var frames := playback.mix_audio(1.0, 4096)
			playback.stop()
			if frames.is_empty():
				quit(1)
				return
			streams += 1
		count += 1
	print("WEB SLIM PACK LOAD PASS: %d resources, %d decoded audio streams; no scene instances / save writes" % [count, streams])
	quit(0)
