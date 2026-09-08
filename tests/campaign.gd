extends "res://tests/journey.gd"
const Campaign = preload("res://scripts/campaign.gd")

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v04-" + label + ".png")

func choices() -> void:
	sim.upgrade_wait = 0
	sim.settle_left = 0
	sim.resolve_flow()
	for i in 30:
		if sim.upgrade_choices.is_empty():
			break
		sim.choose_upgrade(0)

func move_to_gate() -> void:
	game.player.position = Vector3(0, 0.05, -17)
	await settle()
	aim_point(Vector3(0, 1.4, -19))

func run() -> void:
	game = Main.new()
	game.run_seed = 731
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	await settle()
	check(sim.room_total == 7 and sim.plans[3].boss == "warden" and sim.plans[7].boss == "sovereign", "seven-room expedition contains both boss milestones")
	var duplicate := Campaign.new()
	duplicate.run_seed = 731
	root.add_child(duplicate)
	check(duplicate.plans == sim.plans and duplicate.quest_kind == sim.quest_kind, "same seed reproduces rooms and quest")
	duplicate.queue_free()
	var different := Campaign.new()
	different.run_seed = 732
	root.add_child(different)
	check(different.plans != sim.plans, "different seed changes expedition")
	different.queue_free()
	sim.skip_training()
	await ticks(80)
	check(sim.phase == "briefing" and sim.room_index == 1, "skip practice still waits at first briefing")
	key(KEY_J)
	check(sim.journal_open and sim.is_frozen(), "journal pauses expedition")
	sim.confirm_ready()
	check(sim.phase == "briefing", "journal cannot start hidden combat")
	await capture("expedition-journal")
	key(KEY_ESCAPE)
	sim.confirm_ready()
	sim.quest_kind = 2
	# Verify actual combo mechanics while retaining the regular encounter.
	sim.upgrade_choices.assign(["ambush"])
	sim.choose_upgrade(0)
	sim.upgrade_choices.assign(["mercy"])
	sim.choose_upgrade(0)
	check(sim.has_combo("infiltrator") and sim.completed_combos.has("infiltrator"), "pair unlocks and records infiltration combo")
	var common = sim.actors[0]
	check(is_equal_approx(sim.capture_chance(common), common.chance() + 0.20), "combo adds twelve points on top of mercy eight")
	sim.upgrade_choices.assign(["vigor"])
	sim.choose_upgrade(0)
	sim.upgrade_choices.assign(["rot"])
	sim.choose_upgrade(0)
	sim.begin_possession(common)
	sim._physics_process(0.76)
	sim._physics_process(0.66)
	check(is_equal_approx(sim.current_stats().damage_taken, 0.7), "undying combo reduces host lifetime damage")
	check(sim.available_augments().all(func(id): return sim.upgrades.has(id)), "four occupied slots exclude new types from offers")
	sim.upgrade_choices.assign(["curse"])
	sim.choose_upgrade(0)
	check(sim.rank_of("curse") == 0, "fifth distinct augment rejected at authority boundary")
	# Test the third combo in an independent build configuration.
	sim.upgrades.clear()
	sim.completed_combos.clear()
	sim.upgrade_choices.assign(["curse", "funeral", "vigor"])
	var previous_offers: Array = sim.upgrade_choices.duplicate()
	sim.reroll_upgrades()
	check(sim.rerolls == 1 and sim.upgrade_choices != previous_offers and sim.upgrade_choices.size() == 3, "reroll consumes one charge and offers unseen candidates first")
	sim.upgrade_choices.assign(["curse"])
	sim.choose_upgrade(0)
	sim.upgrade_choices.assign(["funeral"])
	sim.choose_upgrade(0)
	var explosions: Array[bool] = []
	sim.feedback.connect(func(event, data):
		if event == "eject": explosions.append(data.explode))
	sim.eject(false)
	check(explosions == [true], "rebirth combo turns manual E into explosion")
	sim._physics_process(0.26)
	check(sim.completed_combos.has("rebirth"), "third combo completion is recorded in its own build")
	for index in range(1, 8):
		check(sim.room_index == index, "arrived at room %d" % index)
		if sim.phase == "briefing": sim.confirm_ready()
		if index in [3, 7]:
			var boss = sim.actors[-1]
			check(boss.profile.get("boss", false), "boss spawned after multi-wave previous room")
			check(sim.capture_chance(boss) == 0, "healthy boss cannot be skipped by lucky possession")
			sim.begin_possession(boss)
			check(sim.state != Authority.State.Possessing, "direct reservation also respects boss threshold")
			sim.boss_clock = 0
			sim.tick_enemy(boss, 0.01)
			check(sim.hazards.size() == 1 and sim.hazards[0].left > 1, "boss attack has readable advance warning")
			key(KEY_J)
			var before: float = sim.hazards[0].left
			sim._physics_process(3)
			check(sim.hazards[0].left == before, "journal freezes boss telegraph")
			key(KEY_J)
			await capture("boss-%d" % index)
			sim.invulnerable = 0
			sim.soul = 20
			sim.tick_hazards(1.5)
			check(sim.soul < 20, "standing in resolved warning applies real damage")
			sim.soul = 20
			var safe_at: Vector3 = game.player.position
			sim.hazards.append({"at": safe_at, "left": 0.1, "radius": 3.0, "damage": 5.0})
			game.player.position += Vector3(5, 0, 0)
			sim.tick_hazards(0.2)
			check(sim.soul == 20, "moving outside telegraph radius avoids damage")
			game.player.position = safe_at
			sim.hazards.clear()
			boss.hp = boss.max_hp * 0.15
			sim.boss_clock = 0
			sim.tick_enemy(boss, 0.01)
			check(sim.hazards.size() == (3 if index == 7 else 1), "boss rage pattern matches role")
			check(sim.capture_chance(boss) > 0, "weakened boss becomes possessable")
			sim.summon_clock = 0
			for actor in sim.actors:
				if actor != boss: actor.alive = false
			sim.tick_enemy(boss, 0.01)
			check(sim.actors[-1].rewarded and not sim.actors[-1].profile.get("boss", false), "summoned replacement bodies cannot farm experience")
			sim.hazards.clear()
		for round_index in 3:
			for actor in sim.actors.duplicate():
				if actor.alive and not actor.claimed: sim.damage_enemy(actor, 9999)
			sim.check_clear()
			await choices()
			if sim.phase == "rest": break
			check(sim.wave_wait > 0 and sim.outcome == "", "room does not finish before its reinforcements")
			sim._physics_process(3.1)
			await settle()
		check(sim.phase == "rest" and sim.outcome == "", "room %d ends in safe exploration" % index)
		if index in [2, 4, 6]:
			game.player.position = Vector3(sim.secret_position.x - signf(sim.secret_position.x) * 1.5, 0.05, sim.secret_position.z)
			await settle()
			aim_point(sim.secret_position)
			check(sim.can_find_secret(), "secret rune can be reached and aimed")
			sim.submit_input(Vector2.ZERO, false, Vector2(sim.yaw, sim.pitch), true)
			await ticks(65)
			check(sim.secret_taken, "held interaction claims secret once")
			check(not sim.can_find_secret(), "secret cannot be farmed")
			await choices()
		if index in [1, 3, 5]:
			await move_to_gate()
			check(sim.route_pending() and not sim.can_leave_room(), "route choice required before departure")
			sim.select_route(1 if index == 1 else 0)
			check(sim.plans[index + 1].route == (1 if index == 1 else 0), "chosen danger-reward route changes next room")
		await move_to_gate()
		sim.leave_room()
		if index < 7: await ticks(80)
	check(sim.outcome == "CLEAR" and sim.bosses_defeated == 2, "final departure completes full expedition")
	check(sim.secrets_found == 3 and sim.relics.size() == 3, "secrets award all unique relics without duplicates")
	check(sim.quest_complete, "run quest completes through actual enemy rewards")
	await capture("expedition-result")
	sim.journal_open = true
	await capture("completed-build")
	print("CAMPAIGN RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
