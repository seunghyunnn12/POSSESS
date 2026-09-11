extends "res://tests/journey.gd"

func capture_story(label: String) -> void:
	game.ui_presenter.refresh()
	for i in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v10-" + label + ".png")

func run() -> void:
	game = Main.new()
	game.run_seed = 731
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	await settle()
	check(game.hud.screens.title.get_node("Description").text == tr("STORY_OPEN"), "title establishes player purpose before combat")
	check(game.hud.screens.title.get_node("KeyArt").texture != null, "illustration loads from project assets")
	await capture_story("title")
	game.begin()
	sim.lesson = 7
	sim.begin_travel()
	game.ui_presenter.refresh()
	check(game.hud.passage.visible and game.hud.passage.last_index == 1, "travel shows destination before loading room")
	var before: float = sim.soul
	sim._physics_process(0.61)
	game.ui_presenter.refresh()
	check(game.hud.passage.last_index == 1 and sim.room_index == 1, "destination remains stable across actual scene swap")
	check(sim.soul == before, "illustrated travel does not consume soul life")
	await capture_story("passage")
	sim.paused = true
	game.ui_presenter.refresh()
	check(not game.hud.passage.visible and game.hud.screens.pause.visible, "pause is never covered by passage artwork")
	sim.paused = false
	sim._physics_process(0.60)
	game.ui_presenter.refresh()
	check(sim.phase == "briefing" and not game.hud.passage.visible, "existing travel duration reaches deliberate first briefing")
	await capture_story("departure")
	sim.confirm_ready()
	check(sim.phase == "combat", "first briefing uses existing continue action")
	game.ui_presenter.on_feedback("combat_start", {})
	sim.room_index = 3
	game.ui_presenter.on_feedback("combat_start", {})
	check(game.hud.toast_key == "BOSS_ENTER_3", "middle boss introduces its narrative role")
	game.ui_presenter.on_feedback("room_clear", {})
	check(game.hud.toast_key == "BOSS_CLEAR_3", "middle boss clear acknowledges opened seal")
	game.ui_presenter.on_feedback("milestone", {})
	check(game.hud.toast_key == "BOSS_CLEAR_3", "same-frame generic reward cannot erase boss resolution")
	game.hud.passage.present(6, game.settings.bindings)
	game.settings.bindings.assign_key("jump", KEY_V)
	game.hud.passage.present(6, game.settings.bindings)
	check("V" in game.hud.passage.tip_label.text, "passage tips respect rebound controls")
	sim.room_index = 7
	sim.phase = "rest"
	sim.finish("CLEAR")
	game.ui_presenter.refresh()
	check(game.hud.screens.title.get_node("Subtitle").text == tr("STORY_END_WIN"), "final exit resolves opening narrative")
	check(game.hud.screens.title.get_node("RecordsButton").text == tr("TAB_RECORDS") and game.hud.screens.title.get_node("SettingsButton").text == tr("TAB_SETTINGS"), "result screen keeps menu labels")
	await capture_story("ending")
	game.queue_free()
	await process_frame
	print("STORY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
