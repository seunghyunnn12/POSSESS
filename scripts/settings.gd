extends RefCounted
## Local device preferences only; never changes simulation rules or unlocks.
const DEFAULTS = {"sensitivity": 1.0, "volume": 80.0, "fullscreen": false, "invert_y": false, "vsync": true, "resolution": 0}
const RESOLUTIONS = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var values: Dictionary = DEFAULTS.duplicate()
var path := ""
var save_error := OK

func load_preferences(location: String) -> void:
	path = location
	values = DEFAULTS.duplicate()
	if path.is_empty(): return
	var config := ConfigFile.new()
	if config.load(path) != OK or not config.has_section("settings"):
		config = ConfigFile.new()
		if config.load(path + ".bak") != OK or not config.has_section("settings"): return
	for key in DEFAULTS:
		set_value(key, config.get_value("settings", key, DEFAULTS[key]))

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	if key in ["fullscreen", "invert_y", "vsync"]:
		if value is bool: values[key] = value
	elif value is float or value is int:
		if not is_finite(float(value)): return
		match key:
			"sensitivity": values[key] = clampf(float(value), 0.25, 3.0)
			"volume": values[key] = clampf(float(value), 0.0, 100.0)
			"resolution": values[key] = clampi(int(value), 0, RESOLUTIONS.size() - 1)

func save() -> void:
	save_error = OK
	if path.is_empty(): return
	var config := ConfigFile.new()
	for key in DEFAULTS: config.set_value("settings", key, values[key])
	save_error = config.save(path + ".tmp")
	if save_error != OK: return
	var previous := ConfigFile.new()
	if previous.load(path) == OK and previous.has_section("settings"):
		save_error = previous.save(path + ".bak")
		if save_error != OK: return
	save_error = DirAccess.rename_absolute(path + ".tmp", path)
	if save_error == OK and not FileAccess.file_exists(path + ".bak"):
		save_error = config.save(path + ".bak")

func apply_display() -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not values.fullscreen:
		var usable := DisplayServer.screen_get_usable_rect()
		var requested: Vector2i = RESOLUTIONS[values.resolution]
		var available := usable.size - Vector2i(32, 80)
		var ratio := minf(1.0, minf(float(available.x) / requested.x, float(available.y) / requested.y))
		var fitted := Vector2i(Vector2(requested) * maxf(0.1, ratio))
		DisplayServer.window_set_size(fitted)
		DisplayServer.window_set_position(usable.position + (usable.size - fitted) / 2)
