extends "res://tests/journey.gd"
## Generated floor: seals, keys & coins, treasure, morgue, secret wall, sanctuary,
## trial, bosses and lazy spawning. Rooms are found by kind, never by fixed index.
## Run: godot --headless --path . -s tests/rooms.gd -- --fun
const Expedition = preload("res://scripts/expedition.gd")
var world
var map

func shot(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v16-" + label + ".png")

func first_of(kind: String, zone: int) -> int:
	for room in range(1, map.size() + 1):
		if map.kind(room) == kind and map.zone(room) == zone: return room
	return -1

func edge_between(a: int, b: int) -> int:
	for i in map.links.size():
		if a in map.links[i] and b in map.links[i]: return i
	return -1

func put(room: int, offset: Vector3 = Vector3.ZERO) -> void:
	sim.player.position = map.center(room) + offset + Vector3(0, 0.05, 0)
	sim.player.velocity = Vector3.ZERO

func go(room: int, offset: Vector3 = Vector3.ZERO) -> void:
	put(room, offset)
	sim.enter_room(room)

func clear_current() -> void:
	drain_levelups()
	sim.spawn_queue.clear()
	for actor in sim.actors:
		if actor.alive and not actor.claimed and not actor.has_meta("price"): sim.damage_enemy(actor, 99999)
	sim.check_clear()
	sim.resolve_flow()
	drain_levelups()

func drain_levelups() -> void:
	sim.pending_levels = 0
	while not sim.upgrade_choices.is_empty(): sim.choose_upgrade(0)

func possess_here() -> void:
	var host = null
	for actor in sim.actors:
		if not actor.has_meta("fodder") and not actor.profile.get("boss", false) and actor.alive and not actor.claimed:
			host = actor
			break
	if host == null: return
	sim.begin_possession(host)
	await ticks(60)
	drain_levelups()

func run() -> void:
	game = Main.new()
	game.run_seed = 17
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	world = sim.world
	map = sim.map
	await settle()
	check(sim.get("fun_mode") == true and map == world.map, "authority and arena share one generated floor")
	check(map.size() == 33 and map.hubs.size() == 3 and map.bosses.size() == 3, "floor has three zones and 33 rooms")
	sim.learned = true
	game.begin()
	await physics_frame
	check(world.seals.size() == map.links.size() + 1 and world.gates.size() == world.seals.size(), "every door has a gate and a bell ward")
	for e in map.key_doors: check(world.is_blocked(e), "treasure doors start locked")
	for e in map.secret_doors: check(world.is_blocked(e) and world.cracks.has(e), "secret doorways start as cracked walls")

	# Lazy spawning + bell seal on the first fight next to the start.
	var fight := -1
	for e in map.links:
		if 1 in e:
			var other: int = e[1] if e[0] == 1 else e[0]
			if map.kind(other) == "combat": fight = other
	check(fight > 0, "a fight opens off the start room")
	check(world.room_actors[fight - 1].is_empty(), "rooms are empty until first entered")
	go(fight)
	await physics_frame
	var door := edge_between(1, fight)
	check(not world.room_actors[fight - 1].is_empty(), "entering spawns the room's enemies")
	check(sim.phase == "combat" and world.seals[door].visible and not world.gates[door].visible, "the ward rises on the doorway")
	await shot("seal")
	clear_current()
	check(sim.phase == "rest" and not world.seals[door].visible and sim.keys == 1 and sim.coins >= 5, "clearing drops the ward and pays a key and coins")

	# Treasure of zone 1 behind a key door.
	var treasure := first_of("treasure", 1)
	var key_edge: int = map.edge_to(treasure)
	var gate_room: int = map.other(key_edge, treasure)
	go(gate_room)
	if sim.phase == "combat": clear_current()
	var at: Vector3 = (map.center(gate_room) + map.center(treasure)) * 0.5
	sim.player.position = at.lerp(map.center(gate_room), 0.12) + Vector3(0, 0.05, 0)
	var keys_before: int = sim.keys
	sim.tick_key_doors()
	check(sim.opened_doors.has(key_edge) and sim.keys == keys_before - 1 and not world.is_blocked(key_edge), "a key opens the treasure door")
	go(treasure, Vector3(5, 0, 3))
	sim.open_reward()
	check(sim.upgrade_choices.is_empty(), "the chest must be reached before it opens")
	put(treasure, Vector3(2, 0, 0))
	sim.open_reward()
	check(sim.upgrade_choices.size() == 3, "the chest offers three augments")
	var picked: String = sim.upgrade_choices[0]
	sim.choose_upgrade(0)
	check(sim.rank_of(picked) == 2, "treasure augments arrive at max rank")

	# Secret wall: needs a body thrown against it.
	var secret_edge: int = map.secret_doors.keys()[0]
	var secret: int = map.secret_doors[secret_edge]
	var host_room: int = map.other(secret_edge, secret)
	# Borrow a body in any unfought room, then carry it to the cracked wall.
	for room in range(1, map.size() + 1):
		if map.kind(room) == "combat" and not sim.visited[room - 1]:
			go(room)
			await possess_here()
			clear_current()
			break
	go(host_room)
	if sim.phase == "combat": clear_current()
	check(sim.state == sim.State.Body, "player carries a borrowed body to the secret")
	sim.player.position = world.cracks[secret_edge].at - Vector3.UP * 1.1
	check(sim.context_hint().contains("금 간 벽"), "standing at the crack prompts to throw the body")
	await shot("crack")
	sim.eject(false)
	await ticks(30)
	check(sim.state == sim.State.Soul, "the ghost comes out after the blast")
	check(not world.is_blocked(secret_edge) and not world.cracks.has(secret_edge), "the body's blast brings the cracked wall down")
	var relics_before: int = sim.relics.size()
	var coins_before: int = sim.coins
	go(secret)
	check(sim.relics.size() == relics_before + 1 and sim.coins == coins_before + 10, "the secret room pays a relic and coins")

	# Zone 1 boss: relic, key, and the way down.
	var boss := first_of("boss", 1)
	go(boss)
	await physics_frame
	check(sim.actors.any(func(a): return a.profile.get("boss", false)), "the zone boss is present")
	var keys_mid: int = sim.keys
	relics_before = sim.relics.size()
	clear_current()
	check(sim.bosses_defeated == 1 and sim.keys == keys_mid + 1 and sim.relics.size() == relics_before + 1, "a zone boss pays a relic and a key")
	check(not world.is_blocked(edge_between(boss, map.hubs[1])), "the boss room opens onto the next zone")

	# Zone 2 specials.
	var trial := first_of("trial", 2)
	go(trial)
	check(sim.actors.filter(func(a): return not a.has_meta("fodder")).all(func(a): return a.profile.get("special", false)), "trial hosts are all elites")
	clear_current()
	sim.open_reward()
	sim.choose_upgrade(0)
	check(not sim.rewards[trial - 1], "a trial still owes a second augment")
	sim.open_reward()
	sim.choose_upgrade(0)
	check(sim.rewards[trial - 1], "a trial pays exactly two augments")

	var sanctuary := first_of("sanctuary", 2)
	go(sanctuary, Vector3(1.5, 0, 0))
	sim.state = sim.State.Soul
	sim.pray()
	check(not sim.used_altars.has(sanctuary), "a ghost cannot use the sanctuary")
	var host_again := first_of("combat", 2)
	go(host_again)
	await possess_here()
	clear_current()
	go(sanctuary, Vector3(1.5, 0, 0))
	sim.decay = sim.decay_max * 0.2
	sim.pray()
	check(is_equal_approx(sim.decay, sim.decay_max), "the sanctuary restores the body")
	sim.decay = 1.0
	sim.pray()
	check(sim.decay == 1.0, "each sanctuary blesses once")

	var morgue := first_of("morgue", 2)
	go(morgue, Vector3(2, 0, 0))
	await physics_frame
	await physics_frame
	var wares: Array = sim.actors.filter(func(a): return a.has_meta("price"))
	check(wares.size() == 3 and sim.remaining() == 0, "the morgue sells three bodies, none counted as enemies")
	var ware = wares[1]
	var price: int = ware.get_meta("price")
	sim.state = sim.State.Soul
	sim.body_profile.clear()
	sim.body_kind = ""
	sim.coins = price - 1
	sim.player.position = ware.position + Vector3(-5.0, 0, 0)
	await physics_frame
	aim_point(ware.position + Vector3.UP * 1.1)
	await physics_frame
	sim.attempt_possession()
	check(sim.state == sim.State.Soul and sim.coins == price - 1, "too few coins refuses the purchase")
	await shot("morgue")
	sim.coins = price + 20
	sim.attempt_possession()
	check(sim.state == sim.State.Possessing and sim.coins == 20, "buying spends exactly the price")
	await ticks(60)
	check(sim.state == sim.State.Body and sim.body_kind == ware.kind, "the bought body becomes the host")
	var flask = world.potions[morgue]
	sim.decay = sim.decay_max * 0.3
	sim.coins = Expedition.POTION_PRICE + 5
	sim.player.position = Vector3(flask.global_position.x - 1.2, 0.05, flask.global_position.z)
	sim.buy_potion()
	check(is_equal_approx(sim.decay, sim.decay_max) and sim.coins == 5, "embalming fluid restores the body for its price")

	# Level-up mid-fight: time stops for a three-way augment choice.
	var arena_room := -1
	for room in range(1, map.size() + 1):
		if map.kind(room) == "combat" and not sim.visited[room - 1]: arena_room = room
	go(arena_room)
	drain_levelups()
	sim.state = sim.State.Soul
	sim.body_profile.clear()
	sim.body_kind = ""
	var level_before: int = sim.level
	sim.gain_xp(sim.xp_next)
	await ticks(2)
	check(sim.level == level_before + 1 and sim.upgrade_choices.size() == 3 and sim.levelup_offer and sim.is_frozen(), "a level-up mid-fight freezes time and offers three augments")
	var lvl_pick: String = sim.upgrade_choices[0]
	var lvl_rank: int = sim.rank_of(lvl_pick)
	sim.choose_upgrade(0)
	check(sim.rank_of(lvl_pick) == lvl_rank + 1 and not sim.is_frozen() and not sim.levelup_offer, "picking resumes the fight and raises the augment one rank")
	check(not sim.rewards[arena_room - 1], "a level-up does not use up the room's own reward slot")

	# A ghost with nothing to borrow is off the clock, and a body walks in.
	for actor in sim.actors:
		if actor.alive and not actor.has_meta("fodder"): sim.damage_enemy(actor, 99999)
	var fodder_left: Array = sim.actors.filter(func(a): return a.alive and a.has_meta("fodder"))
	if fodder_left.is_empty() and not sim.spawn_queue.is_empty():
		sim.world.set_active(sim.spawn_queue.pop_front(), true)
	sim.invulnerable = 999
	sim.soul = 12.0
	check(not sim.host_available() and sim.timers_safe(), "no borrowable body: the ghost clock stops")
	await ticks(60)
	check(is_equal_approx(sim.soul, 12.0), "ghost time does not drain while nothing can be borrowed")
	await ticks(120)
	drain_levelups()
	check(sim.host_available() and sim.reinforcements >= 1, "a borrowable body walks in")
	await ticks(30)
	check(sim.soul < 12.0, "with a body to borrow, the ghost clock runs again")
	sim.invulnerable = 0
	clear_current()
	go(morgue, Vector3(2, 0, 0))

	game.ui_presenter.refresh()
	await process_frame
	var overlay = game.hud.canvas.get_node("FunOverlay")
	check(overlay.status.text.contains("열쇠") and overlay.status.text.contains("유물"), "HUD shows keys, coins and relics")
	check(overlay.map_labels[morgue - 1].visible and overlay.map_labels[morgue - 1].text.contains("영안실"), "minimap shows the current zone's special rooms")
	check(not overlay.map_labels[treasure - 1].visible, "minimap hides other zones")

	game.queue_free()
	await process_frame
	print("ROOMS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
