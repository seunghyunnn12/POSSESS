extends "res://tests/journey.gd"
## ROOMS_V1 steps 1-3: bell seal, keys & bone coins, treasure room, morgue.
## Run: godot --headless --path . -s tests/rooms.gd -- --fun
const Expedition = preload("res://scripts/expedition.gd")
var world

func shot(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v14-" + label + ".png")

func put(room: int, offset: Vector3 = Vector3.ZERO) -> void:
	sim.player.position = Expedition.center(room) + offset + Vector3(0, 0.05, 0)
	sim.player.velocity = Vector3.ZERO

func clear_current() -> void:
	sim.spawn_queue.clear()
	for actor in sim.actors:
		if actor.alive and not actor.claimed: sim.damage_enemy(actor, 99999)
	sim.check_clear()
	sim.resolve_flow()

func visit_and_clear(room: int) -> void:
	put(room)
	sim.enter_room(room)
	if sim.phase == "combat": clear_current()

func run() -> void:
	game = Main.new()
	game.run_seed = 17
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	world = sim.world
	await settle()
	check(sim.get("fun_mode") == true, "expedition mode is running")
	sim.learned = true
	game.begin()
	await physics_frame
	check(world.seals.size() == world.gates.size() and world.gates.size() == Expedition.LINKS.size() + 1, "every door has a brass gate and a bell ward")
	check(world.is_blocked(9), "treasure door starts locked")

	# 1. Bell seal
	put(2)
	sim.enter_room(2)
	await physics_frame
	aim_point(Vector3(0, 2.2, -12))
	check(sim.phase == "combat" and world.seals[0].visible and not world.gates[0].visible, "entering a fight raises the ward, not the brass gate")
	check(world.seals[0].get_child(0).collision_layer == 1, "the ward physically blocks the doorway")
	await shot("seal")
	var coins_before: int = sim.coins
	clear_current()
	check(sim.phase == "rest" and not world.seals[0].visible, "clearing the room breaks the ward")
	check(sim.keys == 1, "first cleared fight always pays a key")
	check(sim.coins >= coins_before + 5, "room clear pays bone coins")

	# Walk the first two zones to reach the treasure door.
	visit_and_clear(3)
	visit_and_clear(4)
	visit_and_clear(5)
	check(sim.cleared[4], "room 5 cleared")
	var keys_before: int = sim.keys
	check(keys_before >= 1, "player holds a key at the treasure door")
	put(5, Vector3(-8.5, 0, 0))
	sim.tick_key_doors()
	check(sim.opened_doors.has(9) and sim.keys == keys_before - 1 and not world.is_blocked(9), "walking up with a key spends it and opens the treasure door")
	sim.keys = 0
	sim.tick_key_doors()
	check(sim.keys == 0, "an opened door never charges twice")

	# 2. Treasure room
	put(11, Vector3(6, 0, 3))
	sim.enter_room(11)
	await physics_frame
	aim_point(Expedition.center(11) + Vector3(0, 1.2, 0))
	check(sim.phase == "rest" and not sim.rewards[10], "treasure room is safe and holds an unclaimed reward")
	await shot("treasure")
	sim.open_reward()
	check(sim.upgrade_choices.size() == 3, "treasure offers three augments")
	var picked: String = sim.upgrade_choices[0]
	sim.choose_upgrade(0)
	check(sim.rank_of(picked) == 2 and sim.rewards[10], "treasure augment is granted at max rank")

	# 3. Morgue
	put(12, Vector3(2, 0, 0))
	sim.enter_room(12)
	await physics_frame
	await physics_frame
	var bodies: Array = sim.actors.filter(func(a): return a.has_meta("price"))
	check(bodies.size() == 3, "morgue holds three preserved bodies")
	check(sim.remaining() == 0, "bodies for sale are not counted as enemies")
	check(bodies.all(func(a): return a.alive and a.visible), "preserved bodies wake when the morgue is entered")
	check(sim.phase == "rest", "the morgue is not a fight")
	var body = bodies[1]
	var price: int = body.get_meta("price")
	sim.coins = price - 1
	sim.player.position = body.position + Vector3(-5.0, 0, 0)
	await physics_frame
	aim_point(body.position + Vector3.UP * 1.1)
	await physics_frame
	check(sim.aimed_actor() == body, "the preserved body can be targeted")
	sim.attempt_possession()
	check(sim.state == sim.State.Soul and sim.coins == price - 1 and body.has_meta("price"), "too few coins refuses the purchase without charging")
	await shot("morgue")
	sim.coins = price + 20
	sim.attempt_possession()
	check(sim.state == sim.State.Possessing and sim.coins == 20, "buying spends exactly the price and starts possession")
	await ticks(60)
	check(sim.state == sim.State.Body and sim.body_kind == body.kind, "the bought body becomes the player's host")
	check(sim.body_profile.get("id", "") == "preserved", "morgue bodies carry the preserved trait")

	# Embalming fluid
	sim.decay = sim.decay_max * 0.3
	sim.player.position = world.potion.global_position + Vector3(-1.2, -world.potion.global_position.y + 0.05, 0)
	sim.buy_potion()
	check(sim.potion_used and is_equal_approx(sim.decay, sim.decay_max) and sim.coins == 20 - Expedition.POTION_PRICE, "embalming fluid restores the body once for its price")
	sim.decay = 1.0
	sim.buy_potion()
	check(sim.decay == 1.0, "embalming fluid is single-use")

	# HUD snapshot carries the new resources.
	game.ui_presenter.refresh()
	await process_frame
	var overlay = game.hud.canvas.get_node("FunOverlay")
	check(overlay.status.text.contains("열쇠") and overlay.status.text.contains("뼈 동전"), "HUD shows keys and bone coins")
	check(overlay.map_labels[Expedition.MORGUE - 1].text.contains("영안실") and overlay.map_labels[Expedition.TREASURE - 1].text.contains("보물"), "minimap names the special rooms")

	game.queue_free()
	await process_frame
	print("ROOMS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
