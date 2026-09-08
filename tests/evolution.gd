extends "res://tests/smoke.gd"
const Traits = preload("res://scripts/traits.gd")

func fresh() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = Main.new()
	game.guided_run = false
	game.run_seed = 17
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	sim.start()
	for actor in sim.actors:
		actor.attack_clock = 1000.0
	await settle()

func inhabit(index: int = 0) -> void:
	sim.begin_possession(sim.actors[index])
	sim._physics_process(0.31)

func aim_point(point: Vector3) -> void:
	var direction: Vector3 = (point - sim.eye()).normalized()
	sim.yaw = atan2(-direction.x, -direction.z)
	sim.pitch = asin(direction.y)

func run() -> void:
	await fresh()
	var special := 0
	for actor in sim.actors:
		if actor.profile.special:
			special += 1
	check(special == 3 and sim.actors[0].profile.id == "common" and sim.actors[3].profile.id == "common", "room offers three special hosts and two baseline hosts")
	var actor = sim.actors[0]
	actor.set_profile(Traits.profile())
	check(is_equal_approx(sim.capture_chance(actor), 0.15), "common starts at fifteen percent")
	actor.set_profile(Traits.profile("swift"))
	check(is_equal_approx(sim.capture_chance(actor), 0.1125), "special resistance reduces full-health chance")
	actor.hp = 1
	check(sim.capture_chance(actor) < 0.6375 and sim.capture_chance(actor) > 0.6, "weak special remains below common capture ceiling")
	actor.set_profile(Traits.profile("seer"))
	check(is_equal_approx(sim.capture_chance(actor), 0.09), "seer has stronger capture resistance")
	actor.hp = actor.max_hp * 0.5
	check(is_equal_approx(sim.capture_chance(actor), 0.3), "resistance is applied after health weakening")
	sim.upgrades.mercy = 1
	check(is_equal_approx(sim.capture_chance(actor), 0.38), "capture augment adds percentage points after resistance")
	var rolls := RandomNumberGenerator.new()
	rolls.seed = 92
	var profile := Traits.profile("swift", rolls)
	check(profile.attack_iv >= 0.92 and profile.attack_iv <= 1.08 and profile.vitality_iv >= 0.92 and profile.vitality_iv <= 1.08, "individual rolls stay within bounded variation")
	rolls.seed = 92
	check(profile == Traits.profile("swift", rolls), "same seed gives the same individual")

	await fresh()
	sim.progression_enabled = false
	actor = sim.actors[0]
	actor.set_profile(Traits.profile("swift"))
	await inhabit()
	check(sim.disguised and sim.state == Authority.State.Body, "new body starts disguised")
	check(is_equal_approx(sim.current_stats().move, 7.2) and is_equal_approx(sim.decay_max, 20), "swift body inherits speed and short lifetime")
	check(is_equal_approx(actor.attributes.enemy_move, 3.0), "same movement trait also applies to enemy")
	check(is_equal_approx(sim.current_stats().reload, 1.3 / 1.2), "swift reload modifier is effective")
	actor.profile.attack_iv = 2
	check(sim.body_profile.attack_iv == 1.0, "current body keeps an independent immutable snapshot")
	for enemy in sim.actors:
		check(enemy.windup == 0, "possession cancels pending enemy attacks")
	var neutral = sim.actors[1]
	neutral.attack_clock = 0
	neutral.windup = 0.4
	var before: float = sim.decay
	sim.tick_enemy(neutral, 0.6)
	check(sim.decay == before and neutral.windup == 0, "ordinary enemy does not attack disguised ally")
	sim.ammo = 0
	sim.shot_left = 0
	sim.attack()
	check(sim.disguised and sim.reload_left > 0, "empty magazine reload does not break disguise")
	sim.reload_left = 0
	sim.ammo = 18
	sim.yaw = PI
	sim.pitch = 0.8
	sim.attack()
	check(not sim.disguised, "committed attack reveals body even if it misses")
	await inhabit(3)
	check(sim.disguised and sim.body_profile.id == "common", "body transfer restores disguise and replaces old trait")
	check(sim.current_stats().move == 4.5, "previous host speed does not leak into next body")
	var candidate = sim.actors[1]
	game.player.position = candidate.position + Vector3(0, 0, 4)
	await settle()
	aim_at(candidate)
	var probe := RandomNumberGenerator.new()
	var chosen_seed := 0
	while true:
		probe.seed = chosen_seed
		if probe.randf() >= sim.capture_chance(candidate):
			break
		chosen_seed += 1
	sim.rng.seed = chosen_seed
	sim.attempt_possession()
	check(not sim.disguised and sim.stun_left == 0.5 and sim.body_kind == "brute", "failed hostile possession exposes but preserves old body")

	await fresh()
	sim.progression_enabled = false
	await inhabit()
	var seer = sim.actors[2]
	game.player.position = Vector3(0, 0.05, 0)
	seer.position = Vector3(0, 0.05, -5)
	seer.rotation.y = 0
	await settle()
	sim.tick_unaware(seer, 0.9)
	check(sim.disguised and seer.detection > 0.4 and seer.detection < 0.5, "seer telegraphs partial detection before alarm")
	before = seer.detection
	sim.paused = true
	sim._physics_process(8)
	check(seer.detection == before, "inspector freezes detection")
	sim.paused = false
	seer.position = Vector3(0, 0.05, -5)
	seer.rotation.y = 0
	var wall = game.arena.box(game.arena, Vector3(3, 3, 0.5), Vector3(0, 1.5, -2.5), game.arena.stone, true)
	await settle()
	sim.tick_unaware(seer, 0.3)
	check(seer.detection < before and sim.disguised, "wall interrupts detection instead of revealing through walls")
	wall.queue_free()
	seer.position = Vector3(0, 0.05, -5)
	seer.rotation.y = 0
	await settle()
	sim.tick_unaware(seer, 2.1)
	check(not sim.disguised and sim.detection == 0, "completed detection exposes the disguised player")

	await fresh()
	sim.progression_enabled = false
	await inhabit(2)
	actor = sim.actors[0]
	check(is_equal_approx(sim.capture_chance(actor), 0.23), "inhabited seer grants eight percentage points of insight")
	sim.upgrades.mercy = 2
	actor.hp = 1
	check(sim.capture_chance(actor) == 0.95, "capture chance cannot exceed ninety-five percent")
	game.presentation._process(0.02)
	check(actor.label.no_depth_test, "seer body reveals nearby soul labels through walls")
	sim.eject(false)
	sim._physics_process(0.26)
	game.presentation._process(0.02)
	check(not actor.label.no_depth_test, "soul insight ends on leaving seer body")

	await fresh()
	sim.progression_enabled = false
	await inhabit()
	game.player.position = Vector3(-6, 0.05, 1)
	sim.decay = 10
	await settle()
	aim_point(sim.supply_position)
	check(sim.can_open_supply(), "nearby aimed supply can be opened by a body")
	sim.submit_input(Vector2.ZERO, false, Vector2(sim.yaw, sim.pitch), true)
	sim._physics_process(0.4)
	check(sim.opening > 0.39 and not sim.supply_used, "supply requires a sustained hold")
	var opening_before: float = sim.opening
	before = sim.decay
	sim.paused = true
	sim._physics_process(10)
	check(sim.opening == opening_before and sim.decay == before, "menu freezes supply progress and decay together")
	sim.paused = false
	sim._physics_process(0.61)
	check(sim.supply_used and sim.disguised, "opening supply preserves disguise")
	check(is_equal_approx(sim.decay, 16.99), "supply restores eight seconds while time still passes")
	before = sim.decay
	sim.tick_supply(2)
	check(sim.decay == before, "supply is consumed exactly once")
	sim.supply_used = false
	sim.decay = sim.decay_max - 1
	sim.opening = 0.99
	sim.tick_supply(0.02)
	check(sim.decay == sim.decay_max, "supply never exceeds host maximum lifetime")
	sim.supply_used = false
	sim.decay = 10
	sim.opening = 0.5
	sim.intent.fire = true
	sim.tick_supply(0.1)
	check(sim.opening == 0 and not sim.supply_used, "attacking interrupts supply opening")

	await fresh()
	actor = sim.actors[0]
	sim.damage_enemy(actor, 1000)
	check(sim.fragments.size() == 1 and sim.xp == 0, "kill drops experience instead of granting distant XP")
	sim.reward_host(actor, true)
	check(sim.fragments.size() == 1 and sim.xp == 0, "host cannot reward twice through a different method")
	game.player.position = actor.position
	await settle()
	sim.collect_fragments()
	check(sim.fragments.is_empty() and sim.xp == 20, "nearby shard is collected once")
	sim.collect_fragments()
	check(sim.xp == 20, "collected shard cannot reward again")
	sim.begin_possession(sim.actors[3])
	check(sim.upgrade_choices.is_empty(), "level-up cannot interrupt possession entry")
	sim._physics_process(0.31)
	check(sim.state == Authority.State.Body and sim.level == 2 and sim.xp == 10, "capture grants same common-host XP and preserves overflow")
	check(sim.upgrade_choices.size() == 3 and sim.upgrade_choices[0] != sim.upgrade_choices[1] and sim.upgrade_choices[1] != sim.upgrade_choices[2], "level-up offers three distinct upgrades")
	before = sim.decay
	var position_before: Vector3 = game.player.position
	sim._physics_process(9)
	check(sim.decay == before and game.player.position == position_before, "upgrade modal freezes combat and body lifetime")
	game.presentation._process(0.02)
	check(sim.actors[1].animation.speed_scale == 0, "upgrade modal also freezes imported animation")
	sim.submit_input(Vector2.ONE, true, Vector2.ONE, true)
	check(not sim.intent.fire and sim.intent.move == Vector2.ZERO and not sim.intent.interact, "upgrade modal rejects gameplay input")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_ESCAPE
	game._unhandled_input(key)
	check(sim.paused and sim.is_frozen(), "Escape opens inspector on top of upgrade choice")
	sim.choose_upgrade(0)
	check(sim.upgrade_choices.size() == 3, "inspector cannot accidentally select a hidden card")
	game._unhandled_input(key)
	check(not sim.paused and sim.is_frozen(), "leaving inspector returns to mandatory choice")
	sim.choose_upgrade(-1)
	sim.choose_upgrade(99)
	check(sim.upgrade_choices.size() == 3, "invalid choice indices do not consume a level")
	var selected: String = sim.upgrade_choices[0]
	key.physical_keycode = KEY_1
	game._unhandled_input(key)
	check(sim.rank_of(selected) == 1 and not sim.is_frozen(), "number key selects offered upgrade and resumes")
	check(game.suppress_fire and sim.disguised, "choice input cannot fire and break disguise")
	sim.choose_upgrade(0)
	check(sim.rank_of(selected) == 1, "repeated stale selection cannot apply upgrade twice")

	await fresh()
	sim.progression_enabled = false
	await inhabit()
	sim.decay = 10
	sim.upgrade_choices.assign(["vigor", "mercy", "ambush"])
	sim.choose_upgrade(0)
	check(sim.decay_max == 30 and sim.decay == 12, "lifetime augment preserves remaining fraction instead of full healing")
	sim.upgrades.ambush = 1
	actor = sim.actors[1]
	actor.set_profile(Traits.profile())
	actor.position = game.player.position + Vector3(0, 0, -3)
	await settle()
	aim_at(actor)
	sim.shot_left = 0
	sim.attack()
	check(is_equal_approx(actor.hp, 100 - 22 * 1.6), "first betrayal bonus applies to actual first shot")
	sim.shot_left = 0
	sim.attack()
	check(is_equal_approx(actor.hp, 100 - 22 * 2.6), "later shots do not repeat first betrayal bonus")
	sim.upgrades.rot = 1
	sim.decay = sim.decay_max * 0.5
	check(is_equal_approx(sim.current_stats().damage, 22 * 1.175), "decay damage boost matches current inspector stats")
	await inhabit(3)
	check(sim.rank_of("vigor") == 1 and sim.decay_max == 42, "soul upgrades persist across different host kinds")

	await fresh()
	for enemy in sim.actors:
		sim.damage_enemy(enemy, 1000)
	check(sim.clear_pending and sim.fragments.is_empty() and sim.outcome == "", "final kill collects remaining XP before clear")
	check(sim.level == 4 and sim.xp == 10 and sim.pending_levels == 3, "multiple gained levels preserve all XP and choices")
	sim.resolve_flow()
	var choice_count := 0
	while not sim.upgrade_choices.is_empty() and choice_count < 10:
		sim.choose_upgrade(0)
		choice_count += 1
	check(choice_count == 3 and sim.outcome == "CLEAR", "queued upgrade choices complete before room clear")
	var bounded := true
	for id in sim.upgrades:
		bounded = bounded and sim.rank_of(id) <= 2
	check(bounded, "offers respect two-rank maximum")

	await fresh()
	await inhabit()
	actor = sim.actors[1]
	for enemy in sim.actors:
		if enemy != actor:
			enemy.alive = false
			enemy.collision_layer = 0
	actor.set_profile(Traits.profile())
	actor.hp = 1
	actor.position = game.player.position + Vector3(0, 0, -2)
	await settle()
	sim.decay = 0.001
	sim._physics_process(0.02)
	check(sim.state == Authority.State.Ejecting and sim.upgrade_choices.is_empty(), "last explosion finishes before level-up modal")
	sim._physics_process(0.26)
	check(sim.state == Authority.State.Soul and not sim.upgrade_choices.is_empty(), "explosion XP opens choice after soul return")
	sim.choose_upgrade(0)
	check(sim.outcome == "CLEAR", "last explosion resolves choice and clear without deadlock")

	await fresh()
	check(sim.upgrades.is_empty() and sim.level == 1 and not sim.supply_used and sim.body_profile.is_empty(), "new run resets traits, growth, supply and body snapshot")
	sim.gain_xp(30)
	sim.resolve_flow()
	sim.set_multiplayer_authority(2)
	sim.choose_upgrade(0)
	check(sim.upgrades.is_empty() and sim.upgrade_choices.size() == 3, "non-authority cannot choose or mutate upgrades")
	sim.set_multiplayer_authority(1)
	# Exercise actual viewport GUI routing, including resized coordinates.
	var original_size: Vector2i = root.size
	root.size = Vector2i(960, 540)
	await process_frame
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.hud.card_rect(1).get_center() * game.hud.size / game.hud.bounds
	click.global_position = click.position
	var clicked_id: String = sim.upgrade_choices[1]
	root.push_input(click, true)
	await process_frame
	check(sim.rank_of(clicked_id) == 1 and sim.upgrade_choices.is_empty(), "resized viewport click chooses the intended card")
	click.pressed = false
	root.push_input(click, true)
	root.size = original_size
	await fresh()
	sim.progression_enabled = false
	await inhabit()
	sim.gain_xp(30)
	sim.upgrade_choices.assign(["vigor", "mercy", "ambush"])
	game._sync_mouse()
	await process_frame
	key.physical_keycode = KEY_ESCAPE
	game._unhandled_input(key)
	await process_frame
	click.pressed = true
	click.position = game.hud.card_rect(0).get_center() * game.hud.size / game.hud.bounds
	click.global_position = click.position
	root.push_input(click, true)
	check(sim.upgrade_choices.size() == 3 and sim.upgrades.is_empty(), "click through inspector cannot select underlying card")
	click.pressed = false
	root.push_input(click, true)
	game._unhandled_input(key)
	key.physical_keycode = KEY_1
	game._unhandled_input(key)
	if DisplayServer.get_name() != "headless":
		click.pressed = true
		Input.parse_input_event(click.duplicate())
		Input.flush_buffered_events()
		game._physics_process(0.016)
		check(not sim.intent.fire and sim.disguised, "held selection click does not become a world attack")
		click.pressed = false
		Input.parse_input_event(click.duplicate())
		Input.flush_buffered_events()
		game._physics_process(0.016)
		click.pressed = true
		Input.parse_input_event(click.duplicate())
		Input.flush_buffered_events()
		game._physics_process(0.016)
		check(sim.intent.fire, "attack re-arms after mouse release and a new press")
		click.pressed = false
		Input.parse_input_event(click.duplicate())
		Input.flush_buffered_events()
	await fresh()
	for id in preload("res://scripts/augments.gd").DEFINITIONS:
		sim.upgrades[id] = 2
	sim.pending_levels = 1
	sim.resolve_flow()
	check(sim.upgrade_choices.is_empty() and sim.pending_levels == 0 and not sim.is_frozen(), "fully upgraded run cannot get trapped in an empty choice modal")
	print("EVOLUTION RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	quit(0 if failures == 0 else 1)
