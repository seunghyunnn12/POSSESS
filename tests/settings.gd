extends "res://tests/journey.gd"
const Preferences = preload("res://scripts/settings.gd")

func run() -> void:
	var preferences = Preferences.new()
	var location := "res://qa-output/settings-%d.cfg" % Time.get_ticks_usec()
	preferences.load_preferences(location)
	preferences.set_value("sensitivity", 999)
	preferences.set_value("volume", -5)
	preferences.set_value("fullscreen", "true")
	preferences.set_value("resolution", 999)
	check(preferences.values.sensitivity == 3.0 and preferences.values.volume == 0.0 and not preferences.values.fullscreen and preferences.values.resolution == 2, "invalid preferences are clamped or rejected")
	preferences.set_value("sensitivity", NAN)
	check(preferences.values.sensitivity == 3.0, "nonfinite sensitivity cannot poison camera input")
	preferences.save()
	check(preferences.save_error == OK, "settings save creates primary and recovery copy")
	var restored = Preferences.new()
	restored.load_preferences(location)
	check(restored.values == preferences.values, "settings survive a new preference instance")
	preferences.save()
	check(preferences.save_error == OK, "repeated save replaces an existing preferences file")
	var broken := FileAccess.open(location, FileAccess.WRITE)
	broken.store_string("[unrelated]\nvalue=1\n")
	broken.close()
	restored.load_preferences(location)
	check(restored.values == preferences.values, "invalid settings schema recovers from backup")
	var unavailable = Preferences.new()
	unavailable.load_preferences("res://qa-output/missing-settings-folder/preferences.cfg")
	unavailable.save()
	check(unavailable.save_error != OK, "unwritable destination reports save failure")
	game = Main.new()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	await settle()
	check(game.settings.path.is_empty(), "QA leaves player device settings untouched")
	game.hud.screens.title.get_node("SettingsButton").pressed.emit()
	game.ui_presenter.refresh()
	var panel = game.hud.screens.pause.get_node("Settings")
	check(sim.paused and not sim.running and panel.is_visible_in_tree(), "title settings opens before starting a run")
	panel.fields.sensitivity.value = 2.0
	panel.fields.volume.value = 35.0
	check(game.settings.values.sensitivity == 2.0 and is_equal_approx(game.presentation.sound.master_gain, 0.35), "sliders reach real sensitivity and audio preferences")
	panel.fields.invert_y.button_pressed = true
	check(game.settings.values.invert_y, "invert toggle reaches input preference")
	key(KEY_ESCAPE)
	game.begin()
	game.aim = Vector2.ZERO
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10, 10)
	game._unhandled_input(motion)
	if DisplayServer.get_name() != "headless":
		check(is_equal_approx(game.aim.x, -0.042) and is_equal_approx(game.aim.y, 0.042), "mouse motion applies sensitivity and inversion")
	key(KEY_ESCAPE)
	game.ui_presenter.refresh()
	var aim_before: Vector2 = game.aim
	game._unhandled_input(motion)
	game._physics_process(0.016)
	check(game.aim == aim_before and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "settings pause cannot rotate the player")
	game.hud.selected_tab = "Settings"
	game.hud.update_tab()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var prefix := "v09" if "--v09" in OS.get_cmdline_user_args() else "v08"
		root.get_texture().get_image().save_png("res://qa-output/" + prefix + "-settings.png")
		game._change_setting("fullscreen", true)
		await process_frame
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and panel.fields.resolution.disabled, "fullscreen applies and window-size selector is disabled")
		game._change_setting("fullscreen", false)
		await process_frame
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and not panel.fields.resolution.disabled, "windowed mode restores the size selector")
		game._change_setting("vsync", false)
		check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "vsync option reaches the display server")
	game._reset_settings()
	check(game.settings.values == Preferences.DEFAULTS, "restore defaults resets all device preferences")
	game.queue_free()
	await process_frame
	print("SETTINGS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
