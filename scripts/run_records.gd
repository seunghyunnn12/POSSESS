extends RefCounted
var path := ""
var entries: Array = []
var save_error := OK

func load_records(location: String) -> void:
	path = location
	entries.clear()
	if path.is_empty(): return
	var config := ConfigFile.new()
	if config.load(path) != OK or not config.get_value("records", "entries", null) is Array:
		config = ConfigFile.new()
		if config.load(path + ".bak") != OK: return
	var saved = config.get_value("records", "entries", [])
	if not saved is Array: return
	for entry in saved:
		if not entry is Dictionary: continue
		if not entry.get("ghost", "") in preload("res://scripts/ghosts.gd").IDS: continue
		if entry.get("result", "") not in ["CLEAR", "DEAD"]: continue
		var valid := true
		for key in ["room", "kills", "possessions", "seconds", "seed"]:
			var value = entry.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value < 0: valid = false
		if valid:
			entries.append(entry)
			if entries.size() == 20: break

func record(sim) -> void:
	entries.push_front({"ghost": sim.ghost_id, "result": "CLEAR" if sim.outcome == "CLEAR" else "DEAD", "room": sim.room_index, "kills": sim.kills, "possessions": sim.possession_count, "seconds": snappedf(sim.elapsed, 0.1), "seed": sim.run_seed})
	if entries.size() > 20: entries.resize(20)
	if path.is_empty(): return
	var config := ConfigFile.new()
	config.set_value("records", "entries", entries)
	save_error = config.save(path + ".tmp")
	if save_error != OK: return
	var previous := ConfigFile.new()
	if previous.load(path) == OK and previous.get_value("records", "entries", null) is Array:
		save_error = previous.save(path + ".bak")
		if save_error != OK: return
	save_error = DirAccess.rename_absolute(path + ".tmp", path)
	if save_error == OK and not FileAccess.file_exists(path + ".bak"): save_error = config.save(path + ".bak")

func summary() -> String:
	if entries.is_empty(): return TranslationServer.translate("RECORD_EMPTY")
	var lines: PackedStringArray = []
	for i in mini(entries.size(), 8):
		var entry: Dictionary = entries[i]
		lines.append(TranslationServer.translate("RECORD_ROW") % [i + 1, TranslationServer.translate("GHOST_NAME_" + str(entry.ghost).to_upper()), TranslationServer.translate("RECORD_CLEAR" if entry.result == "CLEAR" else "RECORD_DEAD"), entry.room, entry.kills, entry.possessions, int(entry.seconds / 60), int(entry.seconds) % 60])
	return "\n\n".join(lines)
