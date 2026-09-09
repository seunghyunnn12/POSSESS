extends "res://tests/journey.gd"
const Visuals = preload("res://scripts/visuals.gd")

func capture(label: String) -> void:
	game.ui_presenter.refresh()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v06-" + label + ".png")

func run() -> void:
	game = Main.new()
	game.run_seed = 731
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	await settle()
	check(game.hud.screens.size() == 4, "four retained Control scenes loaded")
	check(game.hud.screens.title.visible, "title is the only initial screen")
	var slots: Array[Node] = game.hud.find_children("*", "TextureRect", true, false)
	check(slots.size() == 10 and slots.all(func(slot): return slot.texture == null), "ten art placeholders remain empty and ready for replacement")
	var shared: Theme = load("res://theme/possess.tres")
	for screen in game.hud.screens.values():
		check(screen.theme == shared, "%s uses the shared Theme" % screen.name)
	check(shared.default_font is FontVariation and shared.default_font.base_font is FontFile and shared.default_font.has_char("몸".unicode_at(0)) and shared.default_font.has_char("A".unicode_at(0)), "bundled TTF covers Hangul and Latin")
	check(FileAccess.file_exists("res://assets/fonts/OFL.txt"), "font license ships with TTF")
	check(not shared.default_font.base_font.allow_system_fallback, "font never falls back to an installed system font")
	var csv := FileAccess.open("res://locale/ko.csv", FileAccess.READ)
	var missing := ""
	var english_empty := true
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() < 3: continue
		english_empty = english_empty and row[2].is_empty()
		for character in row[1]:
			if character not in ["\n", "\r", "\t"] and not shared.default_font.has_char(character.unicode_at(0)) and character not in missing: missing += character
	check(english_empty, "English CSV column remains empty for translation handoff")
	check(missing.is_empty(), "all authored characters have bundled glyphs" + (": " + missing if not missing.is_empty() else ""))
	await capture("title")
	TranslationServer.set_locale("en")
	game.ui_presenter.refresh()
	check(game.hud.screens.title.get_node("Continue").text == TranslationServer.translate("START"), "empty English translation falls back to Korean")
	var sample := Translation.new()
	sample.set_locale("en")
	sample.add_message("START", "Start test")
	TranslationServer.add_translation(sample)
	TranslationServer.set_locale("ko")
	game.ui_presenter.refresh()
	TranslationServer.set_locale("en")
	game.ui_presenter.refresh()
	check(game.hud.screens.title.get_node("Continue").text == "Start test", "live language switch updates existing Control text")
	TranslationServer.remove_translation(sample)
	TranslationServer.set_locale("ko")
	game.ui_presenter.refresh()
	check(game.hud.screens.title.get_node("Continue").text != "Start test", "Korean can be restored without rebuilding scenes")
	for role in Visuals.MODELS:
		var binding: Dictionary = Visuals.host(role)
		var packed = load(binding.path)
		check(packed is PackedScene and binding.scale > 0, "%s model binding loads" % role)
		var model = packed.instantiate()
		var animation = game.arena.find_animation(model)
		check(animation != null and animation.has_animation(binding.idle) and animation.has_animation(binding.walk) and animation.has_animation(binding.attack), "%s animation bindings exist" % role)
		model.free()
	game.hud.screens.title.get_node("Continue").pressed.emit()
	check(sim.running, "title button reaches existing start handler")
	sim.advance_lesson(1)
	sim.damage_enemy(sim.actors[0], 70)
	sim.begin_possession(sim.actors[0])
	sim._physics_process(0.76)
	sim._physics_process(0.66)
	game.hud.toast_left = 0
	game.player.position = Vector3(0, 0.05, 5)
	game.ui_presenter.refresh()
	await capture("hud")
	check(game.hud.screens.hud.visible and not game.hud.screens.hud.get_node("Interaction").visible, "ordinary HUD has no persistent interaction instructions")
	var allowed := ["Stage", "Enemies", "Host", "Weapon", "SoulLabel"]
	var unexpected := 0
	for label in game.hud.screens.hud.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree(): continue
		var top: Node = label
		while top.get_parent() != game.hud.screens.hud: top = top.get_parent()
		if not str(top.name) in allowed: unexpected += 1
	check(unexpected == 0, "persistent HUD text is confined to four zones and soul bar")
	game.hud.show_toast("TOAST_INHABIT")
	game.hud.show_toast("TOAST_EXPOSED")
	check(game.hud.toast_key == "TOAST_EXPOSED" and game.hud.toast_left == 1.5, "toast replaces previous message with one 1.5 second line")
	game.hud._process(1.51)
	check(not game.hud.screens.hud.get_node("Toast").visible, "toast disappears after 1.5 seconds")
	game.hud.show_toast("TOAST_FOCUS")
	Engine.time_scale = 0.25
	game.hud._process(0.38)
	check(game.hud.toast_left == 0, "soul slow-motion does not extend toast beyond 1.5 real seconds")
	Engine.time_scale = 1
	game.player.position = Vector3(0, 0.05, -20.05)
	sim.yaw = 0
	sim.pitch = 0
	await settle()
	sim.gate_hold = 0.3
	game.ui_presenter.refresh()
	check(game.hud.screens.hud.get_node("Interaction").visible and game.hud.screens.hud.get_node("Interaction/Hold").value > 40, "door interaction and hold progress survive UI replacement")
	await capture("door")
	sim.gate_hold = 0
	sim.upgrade_choices.assign(["ambush", "vigor", "mercy"])
	game._sync_mouse()
	game.ui_presenter.refresh()
	await capture("augment")
	check(game.hud.screens.augment.visible and not game.hud.screens.hud.visible, "upgrade modal hides combat HUD")
	key(KEY_ESCAPE)
	game.ui_presenter.refresh()
	await capture("pause")
	check(game.hud.screens.pause.visible and not game.hud.screens.augment.visible, "pause hides underlying cards and blocks click-through")
	game.hud.screens.pause.get_node("JournalTab").pressed.emit()
	check(game.hud.screens.pause.get_node("Journal").visible, "journal tab displays existing run data")
	await capture("journal")
	game.hud.screens.pause.get_node("ControlsTab").pressed.emit()
	check(game.hud.screens.pause.get_node("Controls").visible, "controls tab displays bindings")
	game.hud.screens.pause.get_node("Resume").pressed.emit()
	check(not sim.paused, "resume button reaches existing pause input")
	game.ui_presenter.refresh()
	game.hud.screens.augment.get_node("Card1").pressed.emit()
	check(sim.rank_of("vigor") == 1, "card button forwards choice without simulation access")
	# Showcase the ordinary combat HUD after transient possession effects finish.
	sim.room_index = 2
	game._feedback("load_room", {"index": 2})
	sim.phase = "combat"
	sim.state = Authority.State.Body
	sim.body_kind = "shotgun"
	sim.body_profile = preload("res://scripts/traits.gd").profile("preserved")
	sim.decay = 18.4
	sim.decay_max = sim.current_stats().life
	sim.ammo = 4
	game.player.position = Vector3(0, 0.05, 3)
	sim.yaw = 0
	sim.pitch = -0.04
	game.hud.toast_left = 0
	for i in 35: await process_frame
	await capture("hud")
	key(KEY_ESCAPE)
	game.hud.screens.pause.get_node("BodyTab").pressed.emit()
	await capture("pause")
	game.queue_free()
	await process_frame
	game = Main.new()
	root.add_child(game)
	current_scene = game
	await settle()
	game.hud.screens.title.get_node("Continue").grab_focus()
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab, true)
	check(game.authority.phase == "travel" and game.authority.running, "real Tab input skips practice even with a focused title button")
	tab.pressed = false
	root.push_input(tab, true)
	game.queue_free()
	await process_frame
	print("UI RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
