extends "res://tests/journey.gd"
## Full-floor soak: several seeds, every room, live AI for a while in each fight,
## rewards, shops, altars, secrets, all bosses, and the exit. Any script error in
## the output fails the run (grep for SCRIPT ERROR in CI).
## Run: godot --headless --path . -s tests/soak.gd -- --fun
var map

func go(room: int) -> void:
	sim.player.position = map.center(room) + Vector3(0, 0.05, 3)
	sim.player.velocity = Vector3.ZERO
	sim.enter_room(room)

func fight(ticks_live: int) -> void:
	# Let the room play itself for a while: spawns, AI, projectiles, the player shooting.
	for i in ticks_live:
		sim.invulnerable = 1.0
		sim.soul = 20.0
		if sim.state == sim.State.Body: sim.decay = maxf(sim.decay, 5.0)
		var targets: Array = sim.actors.filter(func(a): return a.alive and not a.claimed and not a.has_meta("price"))
		if not targets.is_empty() and i % 10 == 0: aim_point(targets[0].position + Vector3.UP)
		if not sim.upgrade_choices.is_empty(): sim.choose_upgrade(i % sim.upgrade_choices.size())
		sim.submit_input(Vector2.ZERO, i % 3 != 0, Vector2(sim.yaw, sim.pitch))
		sim._physics_process(1.0 / 60)
		await physics_frame
		if sim.outcome != "": return
	sim.submit_input(Vector2.ZERO, false, Vector2(sim.yaw, sim.pitch))
	sim.spawn_queue.clear()
	for actor in sim.actors:
		if actor.alive and not actor.claimed and not actor.has_meta("price"): sim.damage_enemy(actor, 99999)
	sim.check_clear()
	sim.resolve_flow()
	await ticks(20)

func take_rewards() -> void:
	sim.pending_levels = 0
	while not sim.upgrade_choices.is_empty(): sim.choose_upgrade(0)
	for n in 2:
		if sim.rewards[sim.room_index - 1]: return
		sim.player.position = map.center(sim.room_index) + Vector3(1.5, 0.05, 0)
		sim.open_reward()
		if sim.upgrade_choices.is_empty(): return
		sim.choose_upgrade(n % sim.upgrade_choices.size())

func borrow_body() -> void:
	for actor in sim.actors:
		if actor.alive and not actor.claimed and not actor.has_meta("fodder") and not actor.profile.get("boss", false) and not actor.has_meta("price"):
			sim.begin_possession(actor)
			await ticks(50)
			while not sim.upgrade_choices.is_empty(): sim.choose_upgrade(0)
			return

func run_seed(seed_value: int) -> void:
	game = Main.new()
	game.run_seed = seed_value
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	map = sim.map
	await settle()
	sim.learned = true
	game.begin()
	# Visit rooms zone by zone in breadth-first order from each crossroads.
	var order: Array = []
	for z in 3:
		var seen := {map.hubs[z]: true}
		var todo := [map.hubs[z]]
		while not todo.is_empty():
			var r: int = todo.pop_front()
			order.append(r)
			for e in map.links:
				if r in e:
					var o: int = e[1] if e[0] == r else e[0]
					if not seen.has(o) and map.zone(o) == z + 1:
						seen[o] = true
						todo.append(o)
	var bosses_before := 0
	for room in order:
		var kind: String = map.kind(room)
		if kind == "secret":
			# Open it the honest way: carry a body to the crack and throw it.
			var edge: int = map.edge_to(room)
			var host: int = map.other(edge, room)
			go(host)
			if sim.state != sim.State.Body:
				for other_room in order:
					if map.kind(other_room) == "combat" and not sim.visited[other_room - 1]:
						go(other_room)
						await borrow_body()
						await fight(10)
						break
				go(host)
			if sim.state == sim.State.Body and world_has_crack(edge):
				sim.player.position = sim.world.cracks[edge].at - Vector3.UP * 1.1
				sim.eject(false)
				await ticks(30)
			check(not sim.world.is_blocked(edge), "seed %d: secret wall %d opened" % [seed_value, edge])
		if map.kind(room) == "treasure":
			sim.opened_doors[map.edge_to(room)] = true
			sim.refresh_gates()
		go(room)
		await ticks(3)
		if map.fights(room) and sim.phase == "combat":
			if kind == "combat" and sim.state != sim.State.Body and randi() % 2 == 0: await borrow_body()
			await fight(150 if kind != "boss" else 240)
		if sim.outcome == "DEAD":
			check(false, "seed %d: died unexpectedly in %s" % [seed_value, kind])
			return
		take_rewards()
		# Open and close the pause screen in every room so its panels render live data.
		key(KEY_ESCAPE)
		game.ui_presenter.refresh()
		await process_frame
		key(KEY_ESCAPE)
		game.ui_presenter.refresh()
		if kind == "morgue":
			sim.coins += 60
			var wares: Array = sim.actors.filter(func(a): return a.has_meta("price"))
			if not wares.is_empty():
				sim.player.position = wares[0].position + Vector3(-4, 0, 0)
				await physics_frame
				aim_point(wares[0].position + Vector3.UP * 1.1)
				await physics_frame
				sim.attempt_possession()
				await ticks(50)
			sim.buy_potion()
		if kind == "sanctuary":
			sim.player.position = map.center(room) + Vector3(1.2, 0.05, 0)
			sim.pray()
		if kind == "boss":
			check(sim.cleared[room - 1] and sim.bosses_defeated == bosses_before + 1, "seed %d: zone boss %d cleared" % [seed_value, map.zone(room)])
			bosses_before = sim.bosses_defeated
	var visited := 0
	for v in sim.visited: if v: visited += 1
	check(visited == map.size(), "seed %d: all %d rooms visited (%d)" % [seed_value, map.size(), visited])
	go(map.final)
	sim.player.position = map.center(map.final) + Vector3(0, 0.05, 16)
	await ticks(5)
	check(sim.outcome == "CLEAR", "seed %d: walking out of the final boss room ends the run (%s)" % [seed_value, sim.outcome])
	print("SEED %d: coins=%d keys=%d relics=%d level=%d augments=%d" % [seed_value, sim.coins, sim.keys, sim.relics.size(), sim.level, sim.upgrades.size()])
	game.queue_free()
	await process_frame
	await process_frame

func world_has_crack(edge: int) -> bool:
	return sim.world.cracks.has(edge)

func run() -> void:
	for seed_value in [3, 11, 29]:
		await run_seed(seed_value)
	print("SOAK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
