extends SceneTree
## Integration checks run against real Godot physics and the complete scene.
const Main = preload("res://scripts/main.gd")
const Authority = preload("res://scripts/authority.gd")
var game
var sim
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func fresh() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = Main.new()
	game.guided_run = false
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	# Legacy combat regression uses baseline hosts with progression isolated.
	sim.progression_enabled = false
	sim.set_physics_process(false)
	sim.start()
	for actor in sim.actors:
		actor.set_profile(preload("res://scripts/traits.gd").profile())
		actor.attack_clock = 1000.0
	await physics_frame
	await process_frame

func aim_at(actor) -> void:
	var direction: Vector3 = (actor.position + Vector3.UP * 1.1 - sim.eye()).normalized()
	sim.yaw = atan2(-direction.x, -direction.z)
	sim.pitch = asin(direction.y)

func settle() -> void:
	await physics_frame
	await process_frame

func run() -> void:
	await fresh()
	check(sim.remaining() == 5, "room contains exactly five hosts")
	check(sim.state == Authority.State.Soul and is_equal_approx(sim.soul, 20), "initial soul state")
	var soldier = sim.actors[0]
	check(is_equal_approx(soldier.chance(), 0.15), "full health possession chance")
	sim.damage_enemy(soldier, 70)
	check(is_equal_approx(soldier.chance(), 0.64), "weakening raises possession chance")
	game.player.position = soldier.position + Vector3(0, 0, 4)
	await settle()
	aim_at(soldier)
	check(sim.aimed_actor() == soldier, "physics ray selects aimed host")
	var seed_for_failure := 0
	var probe := RandomNumberGenerator.new()
	while true:
		probe.seed = seed_for_failure
		if probe.randf() >= soldier.chance():
			break
		seed_for_failure += 1
	sim.rng.seed = seed_for_failure
	sim.attempt_possession()
	check(sim.state == Authority.State.Soul and is_equal_approx(sim.stun_left, 0.5), "failed possession keeps soul and applies stun")
	check(not soldier.claimed and soldier.alive, "failed possession preserves host")
	sim.stun_left = 0
	var seed_for_success := 0
	while true:
		probe.seed = seed_for_success
		if probe.randf() < soldier.chance():
			break
		seed_for_success += 1
	sim.rng.seed = seed_for_success
	sim.attempt_possession()
	check(sim.state == Authority.State.Possessing and soldier.claimed, "successful attempt reserves host")
	sim._physics_process(0.31)
	check(sim.state == Authority.State.Body and sim.body_kind == "soldier", "possession completes into soldier")
	check(sim.remaining() == 4 and sim.possession_count == 1, "claimed host counted once")
	check(is_equal_approx(sim.decay, 25) and sim.ammo == 18, "soldier lifetime and ammunition")
	sim.ammo = 3
	sim.begin_reload()
	sim._physics_process(1.31)
	check(sim.ammo == 18 and sim.reload_left <= 0, "reload replenishes magazine")
	sim.invulnerable = 0
	sim.hurt(3)
	check(sim.decay < 22, "incoming damage consumes body lifetime")
	var untouched: float = sim.actors[3].hp
	sim.eject(false)
	check(sim.state == Authority.State.Ejecting and sim.soul == 20, "voluntary ejection resets soul")
	check(sim.actors[3].hp == untouched, "voluntary ejection causes no explosion")
	sim._physics_process(0.26)
	check(sim.state == Authority.State.Soul and sim.body_kind == "", "ejection completes to soul")
	var brute = sim.actors[3]
	sim.begin_possession(brute)
	sim._physics_process(0.31)
	check(sim.body_kind == "brute" and sim.decay == 35, "brute lifetime")
	sim.invulnerable = 0
	sim.hurt(5)
	check(is_equal_approx(sim.decay, 32), "brute absorbs forty percent of damage")
	var victim = sim.actors[1]
	victim.position = game.player.position + Vector3(0, 0, -2)
	await settle()
	sim.yaw = 0
	sim.pitch = 0
	sim.shot_left = 0
	sim.attack()
	check(is_equal_approx(victim.hp, 32), "brute melee hits nearby visible target")
	victim.hp = 100
	sim.decay = 0.001
	sim._physics_process(0.02)
	check(sim.state == Authority.State.Ejecting, "expired body enters ejection")
	check(is_equal_approx(victim.hp, 40), "expired body deals radial damage")
	sim._physics_process(0.26)
	check(sim.soul == 20 and sim.state == Authority.State.Soul, "explosion returns to fresh soul")
	sim.paused = true
	sim._physics_process(10)
	check(sim.soul == 20, "pause stops lifetime")
	sim.submit_input(Vector2.ONE, true, Vector2.ONE)
	check(sim.intent.move == Vector2.ZERO, "pause rejects input")
	sim.paused = false
	sim.soul = 0.01
	sim._physics_process(0.02)
	check(sim.outcome == "DEAD", "soul expiration ends run")
	sim.check_clear()
	check(sim.outcome == "DEAD", "outcome cannot be overwritten")

	await fresh()
	soldier = sim.actors[0]
	game.player.position = Vector3(0, 0.05, 6)
	soldier.position = Vector3(0, 0.05, 0)
	await settle()
	aim_at(soldier)
	sim.attempt_possession()
	check(sim.state == Authority.State.Soul and sim.stun_left == 0, "beyond six metre eye distance is rejected without RNG penalty")
	game.player.position.z = 4
	await settle()
	aim_at(soldier)
	sim._physics_process(0.16)
	sim.attack()
	check(is_equal_approx(soldier.hp, 86), "soul attack uses real ray damage")
	soldier.attack_clock = 0
	sim.tick_enemy(soldier, 0.01)
	check(soldier.windup > 0, "soldier telegraphs before shooting")
	var soul_before_shot: float = sim.soul
	sim.tick_enemy(soldier, 0.6)
	check(is_equal_approx(sim.soul, soul_before_shot - 2), "enemy ray can hit player collision layer")
	for actor in sim.actors:
		if actor != soldier:
			sim.damage_enemy(actor, 1000)
	check(sim.remaining() == 1 and sim.outcome == "", "one surviving host prevents early clear")
	sim.begin_possession(soldier)
	check(sim.outcome == "", "final host waits for transition")
	sim._physics_process(0.31)
	check(sim.outcome == "CLEAR" and sim.state == Authority.State.Body, "final host possession clears room")

	await fresh()
	check(sim.soul == 20 and sim.possession_count == 0 and sim.remaining() == 5, "new run resets all state")
	sim.begin_possession(sim.actors[0])
	sim._physics_process(0.31)
	sim.begin_possession(sim.actors[3])
	sim._physics_process(0.31)
	check(sim.body_kind == "brute" and sim.possession_count == 2 and sim.remaining() == 3, "direct body transfer consumes previous host")
	for actor in sim.actors:
		if actor.alive:
			sim.damage_enemy(actor, 1000)
	sim.resolve_flow()
	check(sim.outcome == "CLEAR", "eliminating remaining enemies clears room")

	await fresh()
	soldier = sim.actors[0]
	# The visible head must be shootable, not taller than its hit capsule.
	game.player.position = soldier.position + Vector3(0, 0, 4)
	await settle()
	var head_hit: Dictionary = sim.ray(sim.eye(), soldier.position + Vector3.UP * 1.65)
	check(not head_hit.is_empty() and head_hit.collider == soldier, "visible head has collision coverage")
	# Place a wall between the eye and the host; neither possession nor damage crosses it.
	var blocker = game.arena.box(game.arena, Vector3(3, 3, 0.5), soldier.position + Vector3(0, 1.5, 2), game.arena.stone, true)
	await settle()
	aim_at(soldier)
	check(sim.aimed_actor() == null, "wall occludes host selection")
	sim.attack()
	check(soldier.hp == 100, "wall blocks player shot")
	blocker.queue_free()
	await settle()
	sim.damage_enemy(soldier, 1000)
	check(sim.aimed_actor() == null, "dead enemy cannot be targeted")
	var before_count: int = sim.possession_count
	sim.begin_possession(soldier)
	check(sim.state == Authority.State.Soul and sim.possession_count == before_count, "dead host cannot be reserved")
	# Enemy aim lock is physically dodgeable.
	var shooter = sim.actors[1]
	shooter.position = Vector3(0, 0.05, 0)
	game.player.position = Vector3(0, 0.05, 5)
	shooter.attack_clock = 0
	await settle()
	sim.tick_enemy(shooter, 0.01)
	game.player.position.x = 2.0
	await settle()
	var before_dodge: float = sim.soul
	sim.tick_enemy(shooter, 0.6)
	check(sim.soul == before_dodge, "strafing dodges a telegraphed soldier shot")
	# Authority rejects input when it is not the local server owner.
	sim.set_multiplayer_authority(2)
	sim.submit_input(Vector2.ONE, true, Vector2.ONE)
	sim.request("possess")
	check(sim.intent.move == Vector2.ZERO and not sim.queued.possess, "non-authority cannot submit local state changes")
	sim.set_multiplayer_authority(1)

	# Exercise actual scene reload and keyboard routing, not just constructor reset.
	sim.finish("DEAD")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	# reload_current_scene needs a packed scene source; install it as normal boot does.
	game.queue_free()
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.authority.finish("DEAD")
	game._unhandled_input(key)
	await process_frame
	await process_frame
	game = current_scene
	sim = game.authority
	game.set_physics_process(false)
	sim.set_physics_process(false)
	check(not sim.running and sim.outcome == "" and sim.remaining() == 1, "R returns to title with a fresh training room")
	game.begin()
	key.physical_keycode = KEY_ESCAPE
	game._unhandled_input(key)
	check(sim.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape pauses and releases mouse")
	game._unhandled_input(key)
	check(not sim.paused and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED), "Escape resumes (mouse capture checked with a display)")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(sim.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus loss pauses safely")
	print("SMOKE RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	quit(0 if failures == 0 else 1)
