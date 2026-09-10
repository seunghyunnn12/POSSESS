extends "res://tests/journey.gd"
const Bindings = preload("res://scripts/bindings.gd")
const Records = preload("res://scripts/run_records.gd")

func run() -> void:
	var map = Bindings.new()
	check(not map.assign_key("jump", KEY_ESCAPE) and not map.assign_key("jump", KEY_W), "reserved and duplicate keys are rejected")
	check(map.assign_key("interact", KEY_G) and map.canonical(KEY_G) == KEY_F and map.canonical(KEY_F) == KEY_NONE, "new interaction key replaces old key")
	check(map.hint("F / Shift / Space") == "G / Shift / Space", "context hints show rebound key")
	var saved: Dictionary = map.keys.duplicate()
	map.restore(saved)
	check(map.keys == saved, "binding map reload preserves valid assignments")
	saved.jump = KEY_ESCAPE
	map.restore(saved)
	check(map.keys == Bindings.DEFAULTS, "malformed map safely restores defaults")
	game = Main.new()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	await settle()
	game.begin()
	key(KEY_ESCAPE)
	game.hud.selected_tab = "Controls"
	game.ui_presenter.refresh()
	var panel = game.hud.screens.pause.get_node("Controls/Bindings")
	game._begin_binding("interact")
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_G
	game._input(event)
	check(game.settings.bindings.keys.interact == KEY_G and panel.waiting.is_empty() and sim.paused, "key capture updates map while keeping game paused")
	game._begin_binding("jump")
	event.physical_keycode = KEY_ESCAPE
	game._input(event)
	check(panel.waiting.is_empty() and sim.paused and game.settings.bindings.keys.jump == KEY_SPACE, "Escape cancels capture without resuming")
	game.settings.path = "res://qa-output/bindings-%d.cfg" % Time.get_ticks_usec()
	game.settings.save()
	var restored = preload("res://scripts/settings.gd").new()
	restored.load_preferences(game.settings.path)
	check(restored.bindings.keys.interact == KEY_G, "bindings survive settings file reload")
	key(KEY_ESCAPE)
	game.settings.bindings.assign_key("eject", KEY_Q)
	key(KEY_Q)
	check(sim.queued.eject, "rebound eject key reaches authority intent")
	sim.clear_input()
	key(KEY_E)
	check(not sim.queued.eject, "old eject key no longer submits intent")
	key(KEY_ESCAPE)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v09-bindings.png")
	check(game.records.path.is_empty(), "QA records do not touch player profile")
	sim.room_index = 1
	game._feedback("room_clear", {})
	check(game.records.entries.is_empty(), "room clear never writes a completed run")
	sim.phase = "combat"
	sim.paused = false
	sim.finish("DEAD")
	game._feedback("end", {"result": "DEAD"})
	check(game.records.entries.size() == 1, "terminal run writes only once")
	var history = Records.new()
	var location := "res://qa-output/records-%d.cfg" % Time.get_ticks_usec()
	history.load_records(location)
	sim.outcome = "CLEAR"
	sim.room_index = 7
	history.record(sim)
	var history_copy = Records.new()
	history_copy.load_records(location)
	check(history_copy.entries.size() == 1 and history_copy.entries[0].result == "CLEAR", "clear record survives disk reload")
	var damaged := FileAccess.open(location, FileAccess.WRITE)
	damaged.store_string("[records]\nentries=42\n")
	damaged.close()
	history_copy.load_records(location)
	check(history_copy.entries.size() == 1, "invalid history schema recovers previous copy")
	history.path = ""
	for i in 25: history.record(sim)
	check(history.entries.size() == 20, "history is bounded to twenty completed runs")
	game.records.entries = history.entries
	sim.paused = true
	game.ui_presenter.refresh()
	game.hud.selected_tab = "Records"
	game.hud.update_tab()
	check(game.hud.screens.pause.get_node("Records/List").text.count("\n\n") == 7, "history screen shows eight recent runs")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v09-records.png")
	game.queue_free()
	await process_frame
	print("BINDINGS RECORDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
