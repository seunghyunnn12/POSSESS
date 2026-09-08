extends SceneTree
## Input-only bot: no teleports, HP changes, forced possession or invulnerability.
const Main = preload("res://scripts/main.gd")
const Authority = preload("res://scripts/authority.gd")
var game
var sim
var target = null
var last_attempt := -1.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = Main.new()
	game.guided_run = "--journey" in OS.get_cmdline_user_args() or "--campaign" in OS.get_cmdline_user_args()
	game.campaign_run = "--campaign" in OS.get_cmdline_user_args()
	game.run_seed = 17
	root.add_child(game)
	game.set_physics_process(false)
	sim = game.authority
	if not game.campaign_run:
		sim.rng.seed = 17
	if game.guided_run:
		sim.skip_training()
	else:
		sim.start()
	sim.feedback.connect(report)
	for tick in (36000 if game.campaign_run else 9000):
		await physics_frame
		if sim.outcome != "":
			break
		drive()
	var success: bool = sim.outcome == "CLEAR" and sim.possession_count >= 3
	print("PLAYTHROUGH: outcome=%s transfers=%d kills=%d time=%.2fs soul=%.2f" % [sim.outcome, sim.possession_count, sim.kills, sim.elapsed, sim.soul])
	print("PLAYTHROUGH RESULT: ", "PASS" if success else "FAIL")
	game.queue_free()
	await process_frame
	await create_timer(0.4).timeout
	quit(0 if success else 1)

func drive() -> void:
	if game.guided_run:
		if game.campaign_run and sim.route_pending():
			sim.select_route(0)
		if sim.phase == "travel":
			target = null
			return
		if sim.phase == "briefing":
			var ready := InputEventKey.new()
			ready.physical_keycode = KEY_ENTER
			ready.pressed = true
			game._unhandled_input(ready)
			return
		if sim.phase == "rest":
			var delta: Vector3 = Vector3(0, 1.4, -19) - sim.eye()
			var look := Vector2(atan2(-delta.x, -delta.z), asin(delta.normalized().y))
			sim.submit_input(Vector2(0, -1 if delta.length() > 2.2 else 0), false, look, true)
			return
	if not sim.upgrade_choices.is_empty():
		var choice := InputEventKey.new()
		choice.physical_keycode = KEY_1
		choice.pressed = true
		game._unhandled_input(choice)
		return
	if sim.state == Authority.State.Possessing or sim.state == Authority.State.Ejecting:
		return
	if not is_instance_valid(target) or not target.alive or target.claimed:
		target = null
		var nearest := INF
		for actor in sim.actors:
			if actor.alive and not actor.claimed:
				var distance: float = game.player.position.distance_to(actor.position)
				if distance < nearest:
					nearest = distance
					target = actor
	if target == null:
		return
	var delta: Vector3 = target.position + Vector3.UP * 1.1 - sim.eye()
	var look := Vector2(atan2(-delta.x, -delta.z), asin(delta.normalized().y))
	if "--decay" in OS.get_cmdline_user_args() and sim.state == Authority.State.Body and sim.possession_count <= 3:
		# Let the body genuinely expire while evading. No lifetime manipulation.
		var radial := Vector2(game.player.position.x, game.player.position.z + 3)
		var tangent := Vector2(-radial.y, radial.x).normalized()
		var desired := tangent - radial.normalized() * (radial.length() - 8.0) * 0.5
		var local: Vector3 = Basis(Vector3.UP, look.x).inverse() * Vector3(desired.x, 0, desired.y)
		sim.submit_input(Vector2(local.x, local.z), false, look)
		return
	var brute: bool = sim.state == Authority.State.Body and sim.body_kind == "brute"
	var next_damage: float = sim.current_stats().damage * (1.0 + sim.rank_of("ambush") * 0.6 if sim.disguised else 1.0)
	var safe_health: float = maxf(target.max_hp * 0.3, next_damage + 1.0)
	if target.profile.get("boss", false):
		safe_health = maxf(target.max_hp * 0.15, next_damage + 1.0)
	var needs_weakening: bool = target.hp > safe_health
	var desired_range := 2.5 if brute and needs_weakening else 4.7
	var move := Vector2(0.35 * sin(sim.elapsed * 1.2), -1 if delta.length() > desired_range else 0)
	if delta.length() < 2.0 and not brute:
		move.y = 0.6
	if game.campaign_run:
		for hazard in sim.hazards:
			if game.player.position.distance_to(hazard.at) < hazard.radius + 0.5:
				move = Vector2(1, 0)
	sim.submit_input(move, needs_weakening, look)
	if not needs_weakening and delta.length() < 5.8 and sim.stun_left <= 0 and sim.elapsed - last_attempt > 0.6:
		sim.request("possess")
		last_attempt = sim.elapsed

func report(event: String, data: Dictionary) -> void:
	if event in ["inhabit", "rejected", "eject", "end"]:
		print("EVENT %.2f: %s %s" % [sim.elapsed, event, data])
