extends "res://tests/journey.gd"
## Find hitches: play real rooms with the renderer and log every slow frame with
## what happened in it (room entry, spawns, first projectiles, deaths).
## Run (not headless): godot --path . -s tests/stutter.gd -- --fun
var map
var events: Array[String] = []

func note(text: String) -> void:
	events.append(text)

func frame(label: String) -> float:
	var t0 := Time.get_ticks_usec()
	await process_frame
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	if ms > 25.0: print("SPIKE %6.1fms  %s  %s" % [ms, label, ", ".join(events)])
	events.clear()
	return ms

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
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	sim.feedback.connect(func(e, d): note(e + ("(" + str(d.get("role", d.get("kind", ""))) + ")" if d is Dictionary and (d.has("role") or d.has("kind")) else "")))
	for i in 150: await frame("title (warm-up)")
	sim.learned = true
	game.begin()
	for i in 60: await frame("start room")
	var rooms: Array = []
	for room in range(1, map.size() + 1):
		if map.kind(room) == "combat" and map.zone(room) == 1: rooms.append(room)
	var total := 0
	var slow := 0
	for room in rooms.slice(0, 3):
		sim.player.position = map.center(room) + Vector3(0, 0.05, 7)
		var t0 := Time.get_ticks_usec()
		sim.enter_room(room)
		print("enter_room(%d) took %.1fms, actors=%d" % [room, (Time.get_ticks_usec() - t0) / 1000.0, sim.actors.size()])
		note("ENTER")
		for i in 900:
			sim.invulnerable = 1.0
			sim.soul = 20.0
			var targets: Array = sim.actors.filter(func(a): return a.alive and not a.claimed)
			if not targets.is_empty() and i % 15 == 0: aim_point(targets[0].position + Vector3.UP)
			if i == 200:
				for a in sim.actors:
					if a.alive and not a.has_meta("fodder"):
						sim.begin_possession(a)
						note("POSSESS-START")
						break
			sim.submit_input(Vector2.ZERO, true, Vector2(sim.yaw, sim.pitch))
			var before: int = sim.actors.filter(func(a): return a.alive).size()
			sim._physics_process(1.0 / 60)
			var after: int = sim.actors.filter(func(a): return a.alive).size()
			if after > before: note("spawn+%d" % (after - before))
			var ms: float = await frame("room %d t=%d" % [room, i])
			total += 1
			if ms > 25.0: slow += 1
		sim.spawn_queue.clear()
		for a in sim.actors:
			if a.alive and not a.claimed: sim.damage_enemy(a, 99999)
		sim.check_clear()
		sim.resolve_flow()
		for i in 60: await frame("after clear")
	print("STUTTER: %d/%d frames over 25ms" % [slow, total])
	game.queue_free()
	await process_frame
	quit(0)
