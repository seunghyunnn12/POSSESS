extends "res://tests/journey.gd"
## A stranger's first minutes, with the real renderer and real input: title, the
## forced start-room tutorial (shoot, possess, fire, eject), leaving through a door,
## dying with a reason; then a second game where Tab skips the tutorial.
## Run (not headless): godot --path . -s tests/firstrun.gd -- --fun
var map

func snap(label: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa-output/v20-" + label + ".png")

func boot(seed_value: int) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = Main.new()
	game.run_seed = seed_value
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	map = sim.map
	await settle()

func hold_fire(frames: int) -> void:
	for i in frames:
		sim.submit_input(Vector2.ZERO, true, Vector2(sim.yaw, sim.pitch))
		sim._physics_process(1.0 / 60)
		await physics_frame
	sim.submit_input(Vector2.ZERO, false, Vector2(sim.yaw, sim.pitch))

func walk_to(target: Vector3, max_ticks: int) -> void:
	for i in max_ticks:
		var delta: Vector3 = target - sim.player.position
		delta.y = 0
		if delta.length() < 0.6: break
		game.aim = Vector2(atan2(-delta.x, -delta.z), 0.0)
		sim.submit_input(Vector2(0, -1), false, game.aim)
		sim._physics_process(1.0 / 60)
		await physics_frame
	sim.submit_input(Vector2.ZERO, false, game.aim)

func first_door() -> int:
	for e in map.links.size():
		if 1 in map.links[e] and map.kind(map.other(e, 1)) == "combat": return e
	return -1

func run() -> void:
	await boot(23)
	await snap("title")
	key(KEY_ENTER)
	await process_frame
	check(sim.running and sim.room_index == 1 and sim.tutorial, "a new game starts with the tutorial in the start room")
	var tutor = sim.tutor
	check(is_instance_valid(tutor) and tutor.alive, "a tutorial skeleton stands in the start room")
	var door := first_door()
	check(sim.world.is_blocked(door), "the doors stay warded until the tutorial is done")
	game.ui_presenter.refresh()
	await process_frame
	var overlay = game.hud.canvas.get_node("FunOverlay")
	check(overlay.coach.text.contains("좌클릭"), "step 1 tells the player to left-click: %s" % overlay.coach.text.replace("\n", " / "))
	await snap("tutorial-shoot")
	# 1. Shoot it until the odds jump.
	aim_point(tutor.position + Vector3.UP * 1.1)
	for attempt in 12:
		if sim.tutorial_step >= 1: break
		await hold_fire(40)
		aim_point(tutor.position + Vector3.UP * 1.1)
	check(sim.tutorial_step == 1 and tutor.alive, "shooting weakens the skeleton without killing it (hp %.0f / %.0f)" % [tutor.hp, tutor.max_hp])
	check(sim.capture_chance(tutor) == 1.0, "once weakened, possession is guaranteed")
	game.ui_presenter.refresh()
	await process_frame
	check(overlay.coach.text.contains("우클릭"), "step 2 tells the player to right-click")
	await snap("tutorial-possess")
	# 2. Walk up and right-click.
	await walk_to(tutor.position + Vector3(0, 0, 3.0), 300)
	aim_point(tutor.position + Vector3.UP * 1.1)
	await physics_frame
	sim.request("possess")
	await ticks(70)
	check(sim.state == sim.State.Body and sim.tutorial_step == 2, "right-click takes the body")
	# 3. Fire the borrowed weapon, then eject with E.
	await hold_fire(20)
	check(sim.tutorial_step == 3, "firing the borrowed weapon advances to the eject lesson")
	game.ui_presenter.refresh()
	await process_frame
	check(overlay.coach.text.contains("E"), "step 4 tells the player to press E")
	await snap("tutorial-eject")
	key(KEY_E)
	await ticks(40)
	check(not sim.tutorial and sim.state == sim.State.Soul and not sim.world.is_blocked(door), "E ends the tutorial and the wards fall")
	# Leave through the door with real input.
	var next: int = map.other(door, 1)
	var through: Vector3 = map.center(1) + (map.center(next) - map.center(1)) * 0.62
	await walk_to(map.center(1) + (map.center(next) - map.center(1)) * 0.3, 600)
	await walk_to(through, 600)
	check(sim.room_index == next and sim.phase == "combat", "walking through the door starts the first fight")
	await snap("first-fight")
	# Die.
	for i in 60:
		sim.invulnerable = 0
		sim.hurt(3)
		await ticks(1)
		if sim.outcome != "": break
	await ticks(5)
	check(sim.outcome == "DEAD" and sim.death_reason != "", "dying explains itself: %s" % sim.death_reason)
	await snap("death")

	# A second new game: the tutorial is offered again (never finished in tests) and Tab skips it.
	await boot(31)
	key(KEY_ENTER)
	await process_frame
	check(sim.tutorial, "the tutorial is forced again on a new game")
	key(KEY_TAB)
	await process_frame
	check(not sim.tutorial and not sim.world.is_blocked(first_door()), "Tab skips the tutorial and opens the doors")
	check(sim.learned, "skipping counts as done, so the tutorial is not forced again")

	# Once done, Start goes straight in and the title offers a separate replay.
	await boot(37)
	sim.learned = true
	game.ui_presenter.refresh()
	await process_frame
	var replay: Button = game.hud.screens.title.get_node("Skip")
	check(replay.visible and replay.text == "튜토리얼 다시 하기", "the title offers 튜토리얼 다시 하기 after it is done (%s)" % replay.text)
	replay.pressed.emit()
	await process_frame
	check(sim.running and sim.tutorial and sim.room_index == 1, "튜토리얼 다시 하기 starts a run with the tutorial")
	await boot(41)
	sim.learned = true
	key(KEY_ENTER)
	await process_frame
	check(sim.running and not sim.tutorial, "a player who finished it starts the expedition directly")
	game.queue_free()
	await process_frame
	print("FIRSTRUN: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
