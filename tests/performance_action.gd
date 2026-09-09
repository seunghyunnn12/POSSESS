extends SceneTree
const Main = preload("res://scripts/main.gd")
var deltas: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var game := Main.new()
	game.run_seed = 731
	root.add_child(game)
	game.set_physics_process(false)
	var sim = game.authority
	sim.room_index = 5
	sim.plans[5].layout = "terraces"
	game._feedback("load_room", {"index": 5})
	for i in 3:
		game.arena.spawn(["mage", "archer", "storm"][i], Vector3(-3 + i * 3, 0.05, -5), 1 + i)
	game.arena.spawn("brute", Vector3(0, 0.05, -13), 2, "sovereign")
	for actor in sim.actors:
		actor.max_hp = 100000
		actor.hp = actor.max_hp
	sim.phase = "combat"
	sim.state = 2
	sim.body_kind = "mage"
	sim.body_profile = preload("res://scripts/traits.gd").profile()
	sim.decay_max = 28
	sim.start()
	var start := Time.get_ticks_usec()
	var previous := start
	var peak_projectiles := 0
	while Time.get_ticks_usec() - start < 18000000:
		sim.paused = false
		sim.decay = 28
		sim.invulnerable = 1
		sim.disguised = false
		var time := float(Time.get_ticks_msec()) * 0.001
		sim.submit_input(Vector2(sin(time) * 0.15, 0), true, Vector2(sin(time * 0.3) * 0.4, -0.04))
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if now - start > 3000000:
			deltas.append(float(now - previous) / 1000)
		previous = now
		peak_projectiles = maxi(peak_projectiles, sim.projectiles.size())
	deltas.sort()
	var total := 0.0
	for delta in deltas: total += delta
	var average := total / deltas.size()
	var report := "GPU: %s\nScenario: 8 enemies including boss, terraces, fire/ice/lightning projectiles\nFrames: %d\nMean: %.2f ms (%.1f FPS)\np95: %.2f ms\np99: %.2f ms\nPeak active projectiles: %d\n" % [RenderingServer.get_video_adapter_name(), deltas.size(), average, 1000 / average, deltas[int(deltas.size() * 0.95)], deltas[int(deltas.size() * 0.99)], peak_projectiles]
	print(report)
	var file := FileAccess.open("res://qa-output/v05-performance.txt", FileAccess.WRITE)
	file.store_string(report)
	file.close()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa-output/v05-stress.png")
	game.queue_free()
	await process_frame
	quit()
