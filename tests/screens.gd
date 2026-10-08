extends "res://tests/journey.gd"
## Capture the in-run screens: combat HUD, augment choice, pause.
## Run (not headless): godot --path . -s tests/screens.gd -- --fun
var map

func snap(label: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa-output/v21-" + label + ".png")

func run() -> void:
	game = Main.new()
	game.run_seed = 23
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	map = sim.map
	await settle()
	sim.learned = true
	game.begin()
	sim.invulnerable = 9999
	var fight := -1
	for e in map.links:
		if 1 in e:
			var o: int = e[1] if e[0] == 1 else e[0]
			if map.kind(o) == "combat": fight = o
	sim.player.position = map.center(fight) + Vector3(0, 0.05, 8)
	sim.enter_room(fight)
	for actor in sim.actors:
		if not actor.has_meta("fodder") and actor.alive:
			sim.begin_possession(actor)
			break
	await ticks(200)
	sim.pending_levels = 0
	while not sim.upgrade_choices.is_empty(): sim.choose_upgrade(0)
	sim.upgrades["orbit"] = 2
	sim.upgrades["lance"] = 1
	await ticks(40)
	aim_point(map.center(fight) + Vector3(0, 1.4, -6))
	sim.decay = sim.decay_max * 0.55
	await snap("hud")
	sim.spawn_queue.clear()
	for actor in sim.actors:
		if actor.alive and not actor.claimed: sim.damage_enemy(actor, 99999)
	sim.check_clear()
	sim.resolve_flow()
	await ticks(10)
	sim.upgrades["curse"] = 2
	sim.phase = "combat"
	sim.upgrade_choices.clear()
	sim.pending_levels = 1
	sim.open_levelup()
	await ticks(2)
	game.ui_presenter.refresh()
	game._sync_mouse()
	await snap("augment")
	sim.choose_upgrade(0)
	key(KEY_ESCAPE)
	await snap("pause")
	game.queue_free()
	await process_frame
	quit(0)
