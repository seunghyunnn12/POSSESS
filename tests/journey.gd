extends "res://tests/smoke.gd"

func aim_point(point: Vector3) -> void:
	var direction: Vector3 = (point - sim.eye()).normalized()
	sim.yaw = atan2(-direction.x, -direction.z)
	sim.pitch = asin(direction.y)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_input(event)

func ticks(count: int) -> void:
	for i in count:
		sim._physics_process(1.0 / 60)
		await physics_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v03-" + label + ".png")

func run() -> void:
	game = Main.new()
	game.campaign_run = false
	game.run_seed = 17
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	await settle()
	check(not sim.running and sim.phase == "training", "boot waits at title")
	await capture("title")
	key(KEY_ENTER)
	sim._physics_process(30)
	check(sim.soul == 20 and sim.outcome == "" and sim.lesson == 0, "training safe beyond soul lifetime")
	sim.hurt(100)
	check(sim.soul == 20, "training cannot hurt player")
	sim.attempt_possession()
	check(sim.state == Authority.State.Soul, "early possession blocked")
	game.player.position = Vector3(0, 0.05, 2.8)
	await settle()
	sim._physics_process(0.016)
	check(sim.lesson == 1, "movement advances tutorial")
	aim_at(sim.actors[0])
	await capture("lesson")
	for i in 6:
		sim.shot_left = 0
		sim.attack()
	check(sim.lesson == 2 and sim.actors[0].alive, "real shots weaken without killing training host")
	check(sim.capture_chance(sim.actors[0]) == 1, "weakened training capture guaranteed")
	sim.attempt_possession()
	sim._physics_process(0.35)
	check(sim.state == Authority.State.Possessing, "visible transfer takes longer than a blink")
	await capture("possession")
	sim._physics_process(0.41)
	check(sim.lesson == 3 and sim.disguised and sim.xp == 0, "capture teaches disguise without XP menu")
	sim.eject(false)
	check(sim.state == Authority.State.Body, "cannot lose required body before inspection")
	key(KEY_ESCAPE)
	await capture("inspector")
	key(KEY_ESCAPE)
	check(sim.lesson == 4 and is_equal_approx(sim.decay, sim.decay_max - 8), "inspection close prepares supply lesson")
	sim._physics_process(0.7)
	game.player.position = Vector3(-6, 0.05, 1)
	await settle()
	aim_point(sim.supply_position)
	check(sim.can_open_supply(), "training supply reachable through physics ray")
	sim.submit_input(Vector2.ZERO, false, Vector2(sim.yaw, sim.pitch), true)
	await ticks(65)
	check(sim.lesson == 5 and sim.actors.size() == 2 and sim.decay == sim.decay_max, "holding F restores lifetime and introduces second target")
	game.player.position = Vector3(1, 0.05, -1)
	await settle()
	aim_at(sim.actors[1])
	sim.shot_left = 0
	sim.attack()
	check(sim.lesson == 6 and not sim.disguised, "body attack reveals identity and advances")
	key(KEY_E)
	sim._physics_process(0.016)
	sim._physics_process(0.26)
	check(sim.lesson == 7 and sim.state == Authority.State.Soul, "E returns to soul and unlocks exit")
	game.player.position = Vector3(0, 0.05, -17)
	await settle()
	aim_point(Vector3(0, 1.4, -19))
	check(sim.can_leave_room(), "exit is reachable without wall obstruction")
	sim.submit_input(Vector2.ZERO, false, Vector2(sim.yaw, sim.pitch), true)
	await ticks(42)
	check(sim.phase == "travel", "held F deliberately leaves room")
	await ticks(75)
	check(sim.phase == "briefing" and sim.room_index == 1 and sim.remaining() == 3, "first room loaded with three hosts and briefing")
	sim._physics_process(30)
	check(sim.soul == 20 and sim.elapsed == 0, "briefing keeps all clocks stopped")
	await capture("briefing")
	key(KEY_ENTER)
	check(sim.phase == "combat", "Enter explicitly starts combat")
	sim.begin_possession(sim.actors[0])
	sim._physics_process(0.76)
	sim._physics_process(0.66)
	sim.decay = 12
	for actor in sim.actors:
		if actor.alive and not actor.claimed:
			sim.damage_enemy(actor, 1000)
	sim.check_clear()
	sim.resolve_flow()
	check(sim.upgrade_wait > 0 and sim.upgrade_choices.is_empty(), "level notice precedes choice")
	sim._physics_process(1.11)
	check(sim.upgrade_choices.size() == 3, "level notice resolves into three choices")
	await capture("augments")
	sim.choose_upgrade(0)
	check(sim.phase == "rest" and sim.outcome == "", "room clear waits for departure")
	var life: float = sim.decay
	sim._physics_process(30)
	check(sim.decay == life, "room clear allows unhurried rest")
	game.player.position = Vector3(0, 0.05, -17)
	await settle()
	aim_point(Vector3(0, 1.4, -19))
	sim.leave_room()
	await ticks(75)
	check(sim.room_index == 2 and sim.remaining() == 5 and sim.phase == "briefing", "distinct second room waits for ready")
	check(sim.decay == life and sim.upgrades.size() == 1 and sim.state == Authority.State.Body, "body lifetime and augments survive room travel")
	await capture("vault")
	sim.confirm_ready()
	for actor in sim.actors:
		sim.damage_enemy(actor, 1000)
	sim.check_clear()
	sim._physics_process(1.2)
	while not sim.upgrade_choices.is_empty():
		sim.choose_upgrade(0)
	check(sim.phase == "rest" and sim.outcome == "", "last room also waits for deliberate exit")
	game.player.position = Vector3(0, 0.05, -17)
	await settle()
	aim_point(Vector3(0, 1.4, -19))
	sim.leave_room()
	check(sim.outcome == "CLEAR", "final gate completes journey")
	print("JOURNEY RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
