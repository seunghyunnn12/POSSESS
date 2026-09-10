extends "res://tests/journey.gd"
const Progress = preload("res://scripts/ghost_progress.gd")
const Ghosts = preload("res://scripts/ghosts.gd")

func fresh_ghost(id: String = "wanderer", combat := true) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = Main.new()
	game.run_seed = 731
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	game.ghost_progress.unlock(id)
	game._select_ghost(id)
	if combat:
		sim.room_index = 1
		sim.phase = "combat"
		game.arena.spawn("soldier", Vector3(-11, 0.05, 6), 1000)
		sim.start()
		sim.progression_enabled = false
		for actor in sim.actors: actor.attack_clock = 1000
	await settle()

func capture(label: String) -> void:
	game.ui_presenter.refresh()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v07-" + label + ".png")

func run() -> void:
	var path := "res://qa-output/ghost-progress-%d.cfg" % Time.get_ticks_usec()
	var progress = Progress.new()
	progress.load_progress(path)
	check(progress.unlocked == ["wanderer"] and progress.selected == "wanderer", "new profile opens only default ghost")
	check(not progress.select("gunslinger") and not progress.unlock("unknown"), "locked and unknown IDs cannot be selected or unlocked")
	progress.unlock("reaper")
	check(FileAccess.file_exists(path + ".bak"), "first unlock also creates a recovery copy")
	progress.select("reaper")
	check(progress.save_error == OK, "unlock and selected ghost save to disk across repeated writes")
	var restored = Progress.new()
	restored.load_progress(path)
	check(restored.selected == "reaper" and "reaper" in restored.unlocked, "another profile instance restores selection and unlocks")
	check(not restored.unlock("reaper"), "repeated achievement cannot duplicate unlock")
	progress.unlock("gunslinger")
	restored.unlock("arcanist")
	var merged = Progress.new()
	merged.load_progress(path)
	check("gunslinger" in merged.unlocked and "arcanist" in merged.unlocked, "stale profile saves preserve unlocks from another game window")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("invalid [broken")
	corrupt.close()
	restored.load_progress(path)
	check("reaper" in restored.unlocked, "corrupt primary recovers unlocks from backup")
	restored.unlock("arcanist")
	check(restored.save_error == OK, "recovered profile can save again")
	var bad := ConfigFile.new()
	bad.set_value("progress", "version", 1)
	bad.set_value("progress", "unlocked", ["bad"])
	bad.set_value("progress", "selected", "gunslinger")
	bad.save(path)
	restored.load_progress(path)
	check(restored.unlocked == ["wanderer"] and restored.selected == "wanderer", "malformed IDs cannot unlock or select a ghost")
	await fresh_ghost("wanderer", false)
	check(game.ghost_progress.path.is_empty(), "QA cannot modify the player's real unlock save")
	game.ui_presenter.refresh()
	check(game.hud.screens.title.get_node("GhostSelection").visible, "title offers starting character selection")
	check(game.hud.screens.title.get_node("GhostSelection/reaper").disabled, "locked ghost is visibly disabled")
	game._select_ghost("reaper")
	check(sim.ghost_id == "wanderer", "input handler rejects locked character")
	await capture("selection-locked")
	game.ghost_progress.unlock("reaper")
	game.ui_presenter.refresh()
	game.hud.screens.title.get_node("GhostSelection/reaper").pressed.emit()
	check(sim.ghost_id == "reaper" and game.ghost_progress.selected == "reaper", "character button selects an unlocked starting ghost")
	sim.start()
	game._select_ghost("wanderer")
	check(sim.ghost_id == "reaper", "character cannot change during a run")
	# Each selectable ghost must be able to finish the real practice sequence.
	for id in Ghosts.IDS:
		await fresh_ghost(id, false)
		sim.start()
		sim.advance_lesson(1)
		var training_target = sim.actors[0]
		game.player.position = training_target.position + Vector3(0, 0, 2)
		await settle()
		aim_at(training_target)
		for i in 240:
			sim.submit_input(Vector2.ZERO, true, Vector2(sim.yaw, sim.pitch))
			sim._physics_process(1.0 / 60)
			await physics_frame
			if sim.lesson == 2: break
		check(sim.lesson == 2 and training_target.alive, "%s can weaken the tutorial target without killing it" % id)
		sim.clear_input()
		sim.attempt_possession()
		if sim.state != Authority.State.Possessing:
			print("PRACTICE DEBUG ", id, " hp=", training_target.hp, " chance=", sim.capture_chance(training_target), " aimed=", sim.aimed_actor(), " paused=", sim.paused, " state=", sim.state, " stun=", sim.stun_left)
		await ticks(90)
		if sim.state != Authority.State.Body: print("AFTER TRANSFER ", id, " state=", sim.state, " lesson=", sim.lesson, " paused=", sim.paused, " settle=", sim.settle_left)
		check(sim.lesson == 7 and sim.state == Authority.State.Body and sim.captured_roles.is_empty(), "%s practice capture reaches exit without counting toward unlocks" % id)
	await fresh_ghost()
	var dummy = sim.actors[0]
	game.player.position = Vector3(0, 0.05, 5)
	dummy.position = Vector3(0, 0.05, -1)
	await settle()
	aim_at(dummy)
	var before: float = dummy.hp
	sim.attack()
	check(dummy.hp == before and sim.projectiles.size() == 1, "default ghost emits a traveling shot rather than instant damage")
	check(sim.projectiles[0].velocity.length() == 6 and sim.projectiles[0].radius == 0.3, "default shot is slow and has a real wide collision radius")
	await ticks(12)
	check(dummy.hp == before, "distant enemy is not hit before slow projectile arrives")
	sim.shot_left = 0
	sim.attack()
	check(sim.projectiles.size() == 2, "multiple slow shots can coexist")
	await capture("slow-projectile")
	sim.paused = true
	var at: Vector3 = sim.projectiles[0].at
	sim._physics_process(0.5)
	check(sim.projectiles[0].at == at, "pause freezes ghost projectile flight")
	sim.paused = false
	await ticks(65)
	check(dummy.hp < before, "sphere-swept ghost projectile damages its target on arrival")
	# Offset center line misses the capsule; the projectile's radius still hits.
	sim.projectiles.clear()
	dummy.position = Vector3(0.6, 0.05, -1)
	await settle()
	sim.launch(Vector3(0, 1, 1), Vector3(0, 0, -6), 5, "soul", true, null, 0.3)
	before = dummy.hp
	sim.tick_projectiles(0.6)
	check(dummy.hp < before, "large projectile edge hits even when center ray misses")
	# Wall contact wins before a target beyond it, even at a long frame interval.
	dummy.position = Vector3(0, 0.05, -22)
	await settle()
	before = dummy.hp
	sim.projectiles.clear()
	sim.launch(Vector3(0, 1, -19), Vector3(0, 0, -6), 5, "soul", true, null, 0.3)
	sim.tick_projectiles(1)
	check(dummy.hp == before and sim.projectiles.is_empty(), "wide ghost projectile stops at walls without tunneling")
	await fresh_ghost("reaper")
	dummy = sim.actors[0]
	dummy.position = Vector3(0, 0.05, 3)
	await settle()
	aim_at(dummy)
	before = dummy.hp
	sim.attack()
	check(dummy.hp == before - 27 and sim.projectiles.is_empty(), "reaper strikes nearby enemies with a broad melee attack")
	dummy.position = Vector3(0, 0.05, -1)
	await settle()
	aim_at(dummy)
	sim.shot_left = 0
	before = dummy.hp
	sim.attack()
	check(dummy.hp == before, "reaper cannot hit distant enemies")
	game.player.position = Vector3(0, 0.05, -19.5)
	dummy.position = Vector3(0, 0.05, -21.5)
	await settle()
	aim_at(dummy)
	sim.shot_left = 0
	sim.attack()
	check(dummy.hp == before, "reaper cannot strike through a wall")
	await fresh_ghost("arcanist")
	sim.submit_input(Vector2.ZERO, true, Vector2.ZERO)
	await ticks(24)
	check(sim.ghost_charge > 0 and sim.projectiles.is_empty(), "arcanist must charge before firing")
	await capture("charge")
	sim.paused = true
	var charge: float = sim.ghost_charge
	sim._physics_process(1)
	check(sim.ghost_charge == charge, "pause freezes magic charge")
	sim.paused = false
	sim.submit_input(Vector2.ZERO, false, Vector2.ZERO)
	await ticks(1)
	check(sim.ghost_charge == 0, "releasing early cancels magic charge")
	sim.submit_input(Vector2.ZERO, true, Vector2.ZERO)
	await ticks(50)
	check(sim.projectiles.size() == 1 and sim.projectiles[0].damage == 42, "full magic charge releases a stronger projectile")
	sim.clear_input()
	sim.ghost_charge = 0.5
	sim.begin_possession(sim.actors[0])
	check(sim.ghost_charge == 0, "possession cancels ghost charge")
	await ticks(90)
	check(sim.state == Authority.State.Body and sim.ghost_id == "arcanist" and sim.current_stats().damage == 22, "possessed body uses its own weapon independently of starting ghost")
	sim.eject(false)
	await ticks(20)
	check(sim.state == Authority.State.Soul and sim.ghost_id == "arcanist" and sim.current_stats().damage == 42, "leaving a host restores the selected ghost's attack")
	await fresh_ghost("gunslinger")
	dummy = sim.actors[0]
	aim_at(dummy)
	before = dummy.hp
	sim.attack()
	check(dummy.hp == before - 10 and sim.projectiles.is_empty(), "gunslinger deals weak accurate instant damage")
	sim.upgrades["curse"] = 2
	check(sim.current_stats().damage == 15, "existing soul damage augment scales the chosen ghost")
	sim.essence = 10
	check(is_equal_approx(sim.current_stats().damage, 19.5), "surplus experience damage bonus still stacks with ghost damage augment")
	sim.set_multiplayer_authority(2)
	sim.shot_left = 0
	before = dummy.hp
	sim.attack_ghost()
	check(dummy.hp == before, "non-authority cannot fire the selected ghost attack")
	sim.set_multiplayer_authority(1)
	await fresh_ghost()
	sim.room_index = 1
	for role in ["soldier", "soldier", "brute", "mage"]:
		game.arena.spawn(role, Vector3(3, 0.05, 4), 1000)
		sim.begin_possession(sim.actors[-1])
		await ticks(90)
		if role == "brute": check("arcanist" not in game.ghost_progress.unlocked, "duplicate body types do not advance three-type unlock")
	check("arcanist" in game.ghost_progress.unlocked and sim.captured_roles.size() == 3, "three different combat hosts unlock arcanist")
	await fresh_ghost()
	sim.room_index = 3
	sim.progression_enabled = false
	game._feedback("load_room", {"index": 3})
	sim.phase = "combat"
	for actor in sim.actors.duplicate(): sim.damage_enemy(actor, 99999)
	sim.check_clear()
	sim.resolve_flow()
	check("reaper" in game.ghost_progress.unlocked, "actual middle boss room clear unlocks reaper")
	check("gunslinger" not in game.ghost_progress.unlocked, "middle boss does not grant final-clear character")
	sim.room_index = 7
	sim.phase = "rest"
	sim.upgrade_choices.clear()
	sim.pending_levels = 0
	game.player.position = Vector3(0, 0.05, -20)
	sim.yaw = 0
	sim.pitch = 0
	await settle()
	sim.leave_room()
	check(sim.outcome == "CLEAR" and "gunslinger" in game.ghost_progress.unlocked, "actual final departure saves gunslinger unlock")
	await fresh_ghost("wanderer", false)
	for id in Ghosts.IDS: game.ghost_progress.unlock(id)
	game._select_ghost("arcanist")
	await capture("selection-unlocked")
	game.queue_free()
	await process_frame
	print("GHOST RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
