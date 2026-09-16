extends "res://scripts/action.gd"

const Build = preload("res://scripts/fun_augments.gd")
var learned := false
var fun_mode := true
var world
var visited := [false, false, false]
var cleared := [true, false, false]
var rewards := [true, false, false]
var spawn_queue: Array = []
var spawn_clock := 0.0
var tutorial := false
var tutorial_step := 0
var last_body := "soldier"
var damage_from := Vector3.ZERO
var damage_source := ""
var death_reason := ""
var broken_by := ""
var hitstop_left := 0.0
var hitstop_cooldown := 0.0

func _ready() -> void:
	super._ready()
	room_total = 3
	room_index = 1
	phase = "rest"
	rerolls = 0
	for plan in plans:
		if not plan.is_empty():
			plan.boss = ""
			plan.waves = 1
			plan.secret = false

func start() -> void:
	if running or not is_multiplayer_authority(): return
	tutorial = not learned and not get_tree().has_meta("fun_tutorial_seen")
	get_tree().set_meta("fun_tutorial_seen", true)
	learned = true
	super.start()
	enter_room(1)

func skip_training() -> void:
	if not is_multiplayer_authority() or is_frozen() or outcome != "": return
	learned = true
	tutorial = false
	if not running: start()
	activate_hosts()

func enter_room(index: int) -> void:
	if not is_multiplayer_authority() or index < 1 or index > 3: return
	room_index = index
	actors = world.room_actors[index - 1]
	phase = "rest" if cleared[index - 1] else "combat"
	if index == 1:
		visited[0] = true
		spawn_queue.clear()
		return
	if visited[index - 1]: return
	visited[index - 1] = true
	spawn_queue = actors.filter(func(a): return a.has_meta("fodder"))
	spawn_clock = 2.0
	activate_hosts()
	world.gate(index - 2, false)
	clear_pending = false
	invulnerable = maxf(invulnerable, 1)

func activate_hosts() -> void:
	if room_index == 1: return
	for i in 4:
		if tutorial and i > 0: continue
		var actor = actors[i]
		if not actor.claimed and not actor.rewarded:
			world.set_active(actor, true)

func timers_safe() -> bool:
	return state == State.Soul and phase != "combat"

func route_pending() -> bool:
	return false

func can_find_secret() -> bool:
	return false

func can_open_supply() -> bool:
	return false

func can_leave_room() -> bool:
	return false # Physical doors own traversal, no hold-to-travel interaction.

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next += 20
	# Keep the existing automatic essence growth; XP never opens a combat menu.
	essence = mini(10, level - 1)

func resolve_flow() -> void:
	if clear_pending and state in [State.Soul, State.Body]: finish("CLEAR")

func check_clear() -> void:
	if phase == "combat" and spawn_queue.is_empty() and remaining() == 0:
		clear_pending = true
		collect_fragments(true)

func finish(result: String) -> void:
	if result == "CLEAR":
		phase = "rest"
		cleared[room_index - 1] = true
		# Whichever branch is explored first supplies the next fight's augment.
		if cleared[1] and cleared[2]: rewards[room_index - 1] = true
		clear_pending = false
		projectiles.clear()
		world.gate(room_index - 2, true)
		world.gate(2, cleared[1] and cleared[2])
		feedback.emit("room_clear", {"index": room_index})
		return
	if death_reason.is_empty():
		death_reason = "유령의 전투 시간이 다했습니다." if broken_by.is_empty() else broken_by + " 이후 다음 몸을 얻지 못했습니다."
	super.finish(result)

func reward_host(actor, immediate: bool) -> void:
	if actor.rewarded: return
	actor.rewarded = true
	var small: bool = actor.has_meta("fodder")
	var amount := 3 if small else 25
	if state == State.Body:
		var recovery := 0.5 * rank_of("harvest")
		if body_kind == "brute": recovery += 2.0 * rank_of("leech")
		decay = minf(decay_max, decay + (0.1 if small else 1.5) + recovery * (0.25 if small else 1.0))
	if immediate:
		gain_xp(amount)
	else:
		var fragment := {"id": next_fragment_id, "position": actor.position + Vector3.UP * 0.5, "amount": amount}
		next_fragment_id += 1
		fragments.append(fragment)
		feedback.emit("fragment", fragment)

func available_augments() -> Array[String]:
	var result: Array[String] = []
	for id in Build.DATA:
		if rank_of(id) < 2: result.append(id)
	return result

func open_reward() -> void:
	if not is_multiplayer_authority() or not running or outcome != "" or is_frozen() or phase != "rest" or rewards[room_index - 1]: return
	var pool := available_augments()
	var family := Build.family(body_kind if state == State.Body else last_body)
	for category in [0, 1, 2]:
		var candidates: Array[String] = []
		for id in pool:
			var group: String = Build.DATA[id][1]
			if (category == 0 and group == family) or (category == 1 and group != family and group != "neutral") or (category == 2 and group == "neutral"):
				candidates.append(id)
		if candidates.is_empty(): candidates = pool.duplicate()
		if candidates.is_empty(): break
		var selected: String = candidates[offer_rng.randi_range(0, candidates.size() - 1)]
		upgrade_choices.append(selected)
		pool.erase(selected)
	clear_input()
	feedback.emit("upgrade_offer", {})

func choose_upgrade(index: int) -> void:
	if not is_multiplayer_authority() or not running or outcome != "" or paused or journal_open or index < 0 or index >= upgrade_choices.size(): return
	var old_max := decay_max
	var old_mag := magazine_size()
	var id := upgrade_choices[index]
	upgrades[id] = rank_of(id) + 1
	rewards[room_index - 1] = true
	if state == State.Body:
		decay_max = current_stats().life
		decay = decay / maxf(old_max, 0.01) * decay_max
		ammo += maxi(0, magazine_size() - old_mag)
	upgrade_choices.clear()
	clear_input()
	feedback.emit("upgrade_chosen", {"id": id})

func current_stats() -> Dictionary:
	var stats := super.current_stats()
	if not body_profile.is_empty():
		stats.life *= 1.8 * ([1.0, 0.7, 0.5][rank_of("glasscannon")])
	stats.damage *= 1.0 + rank_of("glasscannon") * 0.5
	return stats

func capture_chance(actor) -> float:
	return 0.0 if actor.has_meta("fodder") else super.capture_chance(actor)

func begin_possession(candidate) -> void:
	if not is_instance_valid(candidate) or candidate.has_meta("fodder"): return
	super.begin_possession(candidate)

func attempt_possession() -> void:
	var candidate = aimed_actor()
	if is_instance_valid(candidate) and candidate.has_meta("fodder"):
		feedback.emit("unreachable", {})
		return
	super.attempt_possession()

func finish_possession() -> void:
	super.finish_possession()
	settle_left = 0
	last_body = body_kind
	broken_by = ""
	if tutorial:
		tutorial_step = 2
		tutorial = false
		learned = true
		activate_hosts()
		spawn_clock = 0.5

func hurt(amount: float) -> void:
	if invulnerable > 0 or state not in [State.Soul, State.Body] or outcome != "": return
	var before := decay if state == State.Body else soul
	var body := state == State.Body
	death_reason = ""
	if not body and amount >= soul: death_reason = damage_source + "에 맞아 유령이 소멸했습니다."
	if body and amount * current_stats().damage_taken >= decay: broken_by = damage_source + "에 몸이 무너진"
	super.hurt(amount)
	var after := decay if body else soul
	feedback.emit("damage_detail", {"before": before, "after": after, "body": body, "from": damage_from, "source": damage_source})
	if before - after >= 4 and hitstop_cooldown <= 0:
		hitstop_left = 0.045
		hitstop_cooldown = 0.8

func projectile_source(projectile: Dictionary) -> void:
	damage_from = projectile.at
	damage_source = {"fire": "화염구", "ice": "서리 화살", "shock": "번개"}.get(projectile.element, "투사체")

func eject(explode: bool) -> void:
	if explode and decay <= 0 and broken_by.is_empty(): broken_by = "자연 부패로 몸이 무너진"
	super.eject(explode)

func tick_enemy(actor, dt: float) -> void:
	if phase != "combat": return
	damage_from = actor.position
	damage_source = "굶주린 것의 근접 공격" if actor.has_meta("fodder") else Weapons.info(actor.kind).name + "의 공격"
	if not actor.has_meta("fodder"):
		if tutorial: return
		super.tick_enemy(actor, dt)
		return
	if actor.stagger_left > 0: return
	var delta: Vector3 = player.position - actor.position
	delta.y = 0
	actor.attack_clock -= dt
	var direction := delta.normalized()
	# Spread around the target rather than forming one queue behind the first mob.
	var flank := Vector3(-direction.z, 0, direction.x) * (0.55 if actor.get_index() % 2 == 0 else -0.55)
	actor.velocity = (direction + flank).normalized() * (2.2 if actor.frost_left <= 0 else 0.7) + Vector3.DOWN
	actor.move_and_slide()
	actor.rotation.y = atan2(delta.x, delta.z)
	if actor.windup > 0:
		actor.windup -= dt
		if actor.windup <= 0 and delta.length() < 1.6 and ray(actor.position + Vector3.UP, eye(), 1).is_empty(): hurt(2.5)
	elif delta.length() < 2.0 and actor.attack_clock <= 0:
		actor.windup = 0.45
		actor.attack_clock = 1.8

func _physics_process(dt: float) -> void:
	if not is_multiplayer_authority() or not running or is_frozen() or outcome != "": return
	if hitstop_left > 0:
		hitstop_left -= dt / maxf(Engine.time_scale, 0.01)
		return
	hitstop_cooldown = maxf(0, hitstop_cooldown - dt)
	if phase == "combat" and not tutorial:
		spawn_clock -= dt
		var count := 0
		var hosts := 0
		for actor in actors:
			if actor.alive and actor.has_meta("fodder"): count += 1
			elif actor.alive and not actor.claimed: hosts += 1
		if spawn_clock <= 0 and count < mini(12, 15 - hosts) and not spawn_queue.is_empty():
			var actor = spawn_queue.pop_front()
			if actor.position.distance_to(player.position) < 3:
				spawn_queue.append(actor)
			else:
				world.set_active(actor, true)
				actor.attack_clock = 1
			spawn_clock = 0.4
	if tutorial and not actors.is_empty() and actors[0].hp < actors[0].max_hp * 0.5: tutorial_step = 1
	if tutorial and not actors.is_empty() and not actors[0].alive:
		tutorial = false
		learned = true
		activate_hosts()
	super._physics_process(dt)
	if phase == "rest":
		if intent.interact: open_reward()
		var next := room_index
		if room_index == 1:
			if player.position.z < -13: next = 2
			elif player.position.x > 12: next = 3
		elif room_index == 2 and player.position.z > -11: next = 1
		elif room_index == 3 and player.position.x < 10: next = 1
		if next != room_index:
			enter_room(next)
		if room_index == 1 and cleared[1] and cleared[2] and player.position.z > 15:
			outcome = "CLEAR"
			focus_left = 0
			Engine.time_scale = 1
			clear_input()
			feedback.emit("end", {"result": outcome})
