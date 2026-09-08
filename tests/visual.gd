extends SceneTree
## Real renderer capture and fixed-duration combat performance sample.
const Main = preload("res://scripts/main.gd")
var game
var sim
var deltas: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://qa-output/" + label + ".png")
	print("CAPTURE: ", label, " result=", result)

func wait_frames(count: int) -> void:
	for i in count:
		await process_frame

func run() -> void:
	game = Main.new()
	game.guided_run = false
	game.run_seed = 17
	root.add_child(game)
	game.set_physics_process(false)
	sim = game.authority
	sim.progression_enabled = false
	sim.set_physics_process(false)
	await wait_frames(40)
	await screenshot("01-title")
	sim.start()
	game.player.position = Vector3(0, 0.05, 5)
	sim.yaw = 0.25
	await wait_frames(30)
	await screenshot("02-soul")
	sim.begin_possession(sim.actors[0])
	sim._physics_process(0.31)
	game.player.position = Vector3(0, 0.05, 5)
	sim.yaw = -0.3
	await wait_frames(40)
	await screenshot("03-soldier")
	sim.decay = 3.0
	await wait_frames(20)
	await screenshot("04-decay")
	sim.begin_possession(sim.actors[3])
	sim._physics_process(0.31)
	game.player.position = Vector3(0, 0.05, 5)
	await wait_frames(40)
	await screenshot("05-brute")
	sim.paused = true
	await wait_frames(3)
	await screenshot("06-pause")
	sim.paused = false
	sim.begin_possession(sim.actors[2])
	sim._physics_process(0.31)
	game.player.position = Vector3(0, 0.05, 5)
	sim.decay = sim.decay_max * 0.65
	await wait_frames(30)
	await screenshot("08-special-host")
	sim.paused = true
	await wait_frames(3)
	await screenshot("09-host-inspector")
	sim.paused = false
	sim.progression_enabled = true
	sim.gain_xp(30)
	sim.resolve_flow()
	await wait_frames(3)
	await screenshot("10-upgrade-choice")
	sim.paused = true
	await wait_frames(3)
	await screenshot("11-inspector-over-choice")
	sim.paused = false
	sim.choose_upgrade(0)
	# Restore all five enemies for a sustained worst-room-load sample.
	game.queue_free()
	await process_frame
	game = Main.new()
	game.guided_run = false
	root.add_child(game)
	game.set_physics_process(false)
	sim = game.authority
	sim.start()
	await wait_frames(60)
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < 12000000:
		sim.paused = false
		sim.soul = 20.0
		sim.invulnerable = 1.0
		sim.submit_input(Vector2(sin(float(Time.get_ticks_msec()) * 0.001), 0), true, Vector2(0, 0.4))
		await process_frame
		var now := Time.get_ticks_usec()
		deltas.append(float(now - previous) / 1000.0)
		previous = now
	deltas.sort()
	var average := 0.0
	for delta in deltas:
		average += delta
	average /= deltas.size()
	var report := "GPU: %s\nFrames: %d\nMean: %.2f ms (%.1f FPS)\np95: %.2f ms\np99: %.2f ms\n" % [RenderingServer.get_video_adapter_name(), deltas.size(), average, 1000.0 / average, deltas[int(deltas.size() * 0.95)], deltas[int(deltas.size() * 0.99)]]
	print(report)
	var file := FileAccess.open("res://qa-output/performance.txt", FileAccess.WRITE)
	file.store_string(report)
	file.close()
	await screenshot("07-combat")
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	quit()
