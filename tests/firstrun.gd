extends "res://tests/journey.gd"
## A stranger's first minutes, with the real renderer: title, start room, walking
## through a door with real input, the tutorial fight, dying, and the result screen.
## Run (not headless): godot --path . -s tests/firstrun.gd -- --fun
var map

func snap(label: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa-output/v17-" + label + ".png")

func walk_to(target: Vector3, max_ticks: int) -> void:
	for i in max_ticks:
		var delta: Vector3 = target - sim.player.position
		delta.y = 0
		if delta.length() < 0.6: break
		var yaw := atan2(-delta.x, -delta.z)
		game.aim = Vector2(yaw, 0.0)
		sim.submit_input(Vector2(0, -1), false, game.aim)
		sim._physics_process(1.0 / 60)
		await physics_frame
	sim.submit_input(Vector2.ZERO, false, game.aim)

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
	await snap("title")
	key(KEY_ENTER)
	await process_frame
	check(sim.running and sim.room_index == 1, "Enter starts the run in the start room")
	await snap("start")
	# Walk through the first door with real movement input.
	var door := -1
	for e in map.links.size():
		if 1 in map.links[e] and map.kind(map.other(e, 1)) == "combat": door = e
	var next: int = map.other(door, 1)
	var through: Vector3 = map.center(1) + (map.center(next) - map.center(1)) * 0.62
	await walk_to(through, 900)
	check(sim.room_index == next, "walking through the door enters the next room (room %d, at %s)" % [sim.room_index, sim.player.position])
	await ticks(30)
	await snap("tutorial")
	check(sim.tutorial and sim.remaining() == 1, "first fight is a one-enemy tutorial")
	# Die: exhaust the ghost.
	sim.invulnerable = 0
	sim.tutorial = false
	sim.activate_hosts()
	for i in 40:
		sim.invulnerable = 0
		sim.hurt(3)
		await ticks(1)
		if sim.outcome != "": break
	await ticks(5)
	check(sim.outcome == "DEAD", "the ghost can die")
	check(sim.death_reason != "", "death explains itself: %s" % sim.death_reason)
	await snap("death")
	game.queue_free()
	await process_frame
	print("FIRSTRUN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
