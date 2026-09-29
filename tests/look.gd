extends "res://tests/journey.gd"
## Atmosphere capture: one frame per room kind with the real renderer, plus frame timing.
## Run (not headless): godot --path . -s tests/look.gd -- --fun
var frames: Array[float] = []
var map

func snap(label: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa-output/v16-" + label + ".png")

func first_of(kind: String, zone: int) -> int:
	for room in range(1, map.size() + 1):
		if map.kind(room) == kind and map.zone(room) == zone: return room
	return 1

func stand(room: int, offset: Vector3, look: Vector3) -> void:
	sim.player.position = map.center(room) + offset + Vector3(0, 0.05, 0)
	sim.enter_room(room)
	aim_point(map.center(room) + look)

func run() -> void:
	game = Main.new()
	game.run_seed = 17
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
	stand(1, Vector3(0, 0, 6), Vector3(0, 2, -8))
	await snap("start")
	for zone in [1, 2, 3]:
		stand(first_of("combat", zone), Vector3(0, 0, 8), Vector3(0, 1.6, -6))
		for i in 60: await physics_frame
		await snap("zone%d" % zone)
	stand(first_of("treasure", 1), Vector3(5, 0, 3), Vector3(0, 1.2, 0))
	await snap("treasure")
	stand(first_of("sanctuary", 2), Vector3(0, 0, 6), Vector3(0, 1.2, 0))
	await snap("sanctuary")
	stand(first_of("trial", 2), Vector3(0, 0, 8), Vector3(0, 1.6, -6))
	await snap("trial")
	stand(first_of("secret", 1), Vector3(0, 0, 5), Vector3(0, 1.0, -1))
	await snap("secret")
	stand(first_of("boss", 3), Vector3(0, 0, -9), Vector3(0, 2, 6))
	for i in 30: await physics_frame
	await snap("boss")
	var busy := 1
	for room in range(1, map.size() + 1):
		if map.kind(room) == "combat" and map.zone(room) == 3 and not sim.visited[room - 1]: busy = room
	stand(busy, Vector3(0, 0, 6), Vector3(0, 1.6, -6))
	await ticks(360)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 30: await process_frame
	var last := Time.get_ticks_usec()
	for i in 300:
		sim._physics_process(1.0 / 60)
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	frames.sort()
	var total := 0.0
	for f in frames: total += f
	print("FRAMES(vsync off, %d live enemies) avg=%.2fms p95=%.2fms p99=%.2fms" % [sim.remaining(), total / frames.size(), frames[int(frames.size() * 0.95)], frames[int(frames.size() * 0.99)]])
	game.queue_free()
	await process_frame
	quit(0)
