extends "res://tests/journey.gd"
## Atmosphere capture: one frame per representative room with the real renderer.
## Run (not headless): godot --path . -s tests/look.gd -- --fun
const Expedition = preload("res://scripts/expedition.gd")
var frames: Array[float] = []

func snap(label: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa-output/v15-" + label + ".png")

func stand(room: int, offset: Vector3, look: Vector3) -> void:
	sim.player.position = Expedition.center(room) + offset + Vector3(0, 0.05, 0)
	sim.enter_room(room)
	aim_point(Expedition.center(room) + look)

func run() -> void:
	game = Main.new()
	game.run_seed = 17
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	await settle()
	sim.learned = true
	game.begin()
	sim.invulnerable = 9999
	stand(1, Vector3(0, 0, 8), Vector3(0, 2, -8))
	await snap("start")
	stand(2, Vector3(0, 0, 9), Vector3(0, 1.6, -6))
	for i in 90: await physics_frame
	await snap("zone1")
	stand(5, Vector3(7, 0, 0), Vector3(-6, 1.8, 0))
	await snap("zone2")
	stand(9, Vector3(-7, 0, 0), Vector3(6, 1.8, 0))
	await snap("zone3")
	stand(11, Vector3(6, 0, 3), Vector3(0, 1.2, 0))
	await snap("treasure")
	stand(12, Vector3(0, 0, 0), Vector3(7, 1.5, 0))
	await snap("morgue")
	stand(10, Vector3(0, 0, -9), Vector3(0, 2, 6))
	await snap("boss")
	# Frame pacing in a busy zone-1 fight with torches, fog and dust.
	stand(2, Vector3(0, 0, 6), Vector3(0, 1.6, -6))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 30: await process_frame
	var last := Time.get_ticks_usec()
	for i in 300:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	frames.sort()
	var total := 0.0
	for f in frames: total += f
	print("FRAMES(vsync off) avg=%.2fms p95=%.2fms p99=%.2fms" % [total / frames.size(), frames[int(frames.size() * 0.95)], frames[int(frames.size() * 0.99)]])
	game.queue_free()
	await process_frame
	quit(0)
