extends RefCounted
## Versioned unlock-only save. QA runs use memory or their own explicit path.
const Ghosts = preload("res://scripts/ghosts.gd")
var path := ""
var unlocked: Array[String] = ["wanderer"]
var selected := "wanderer"
var save_error := OK

func load_progress(location: String) -> void:
	path = location
	unlocked.assign(["wanderer"])
	selected = "wanderer"
	if path.is_empty(): return
	var config := ConfigFile.new()
	if config.load(path) != OK or config.get_value("progress", "version", 0) != 1 or not config.get_value("progress", "unlocked", null) is Array:
		config = ConfigFile.new()
		if config.load(path + ".bak") != OK or config.get_value("progress", "version", 0) != 1: return
	var saved = config.get_value("progress", "unlocked", [])
	if saved is Array:
		for id in Ghosts.IDS:
			if id in saved and id not in unlocked: unlocked.append(id)
	var candidate = config.get_value("progress", "selected", "wanderer")
	if candidate is String and candidate in unlocked: selected = candidate

func select(id: String) -> bool:
	if id not in unlocked: return false
	selected = id
	save()
	return true

func unlock(id: String) -> bool:
	if id not in Ghosts.IDS or id in unlocked: return false
	unlocked.append(id)
	save()
	return true

func save() -> void:
	if path.is_empty(): return
	# Unlocks are monotonic even if another game window saved a newer profile.
	var previous := ConfigFile.new()
	var previous_valid: bool = previous.load(path) == OK and previous.get_value("progress", "version", 0) == 1 and previous.get_value("progress", "unlocked", null) is Array
	if previous_valid:
		for id in Ghosts.IDS:
			if id in previous.get_value("progress", "unlocked") and id not in unlocked: unlocked.append(id)
	var config := ConfigFile.new()
	config.set_value("progress", "version", 1)
	config.set_value("progress", "unlocked", unlocked)
	config.set_value("progress", "selected", selected)
	save_error = config.save(path + ".tmp")
	if save_error != OK: return
	# Keep a validated previous save; do not overwrite recovery with corrupt bytes.
	if previous_valid:
		save_error = DirAccess.copy_absolute(path, path + ".bak")
		if save_error != OK: return
	save_error = DirAccess.rename_absolute(path + ".tmp", path)
	if save_error == OK and not FileAccess.file_exists(path + ".bak"):
		save_error = DirAccess.copy_absolute(path, path + ".bak")
