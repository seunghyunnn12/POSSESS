extends "res://scripts/action.gd"

const Expedition = preload("res://scripts/expedition.gd")
const Build = preload("res://scripts/fun_augments.gd")
var learned := false
var fun_mode := true
var world
var map
var visited: Array = []
var cleared: Array = []
var rewards: Array = []
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
var keys := 0
var coins := 0
var keys_found := 0
var opened_doors := {}
var potion_used := false
var used_potions := {}
var used_altars := {}
var rewards_left := {}
var secrets_opened := 0
var levelup_offer := false
var no_host_clock := 0.0
var reinforcements := 0
var key_warn_clock := 0.0
var loot_rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	if map == null: map = Expedition.generate(run_seed)
	room_total = map.size()
	for room in range(1, room_total + 1):
		visited.append(false)
		cleared.append(map.is_safe(room))
		rewards.append(map.kind(room) in ["hub", "morgue", "sanctuary", "secret"])
		if map.kind(room) == "trial": rewards_left[room] = 2
	loot_rng.seed = run_seed + 911
	while plans.size() <= room_total: plans.append(plans[1].duplicate(true))
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
	if not is_multiplayer_authority() or index < 1 or index > room_total: return
	room_index = index
	world.populate(index)
	actors = world.room_actors[index - 1]
	if world.has_method("set_zone"): world.set_zone(map.zone(index))
	phase = "rest" if cleared[index - 1] else "combat"
	if map.is_safe(index):
		var first: bool = not visited[index - 1]
		visited[index - 1] = true
		spawn_queue.clear()
		if map.kind(index) == "morgue":
			for actor in actors:
				if actor.has_meta("price") and not actor.claimed: world.set_active(actor, true)
		if first and map.kind(index) == "secret":
			secrets_opened += 1
			coins += 10
			award_relic()
			feedback.emit("secret_found", {"room": index})
		return
	if visited[index - 1]: return
	visited[index - 1] = true
	spawn_queue = actors.filter(func(a): return a.has_meta("fodder"))
	spawn_clock = 2.0
	activate_hosts()
	refresh_gates()
	feedback.emit("sealed", {"room": index})
	boss_clock = 3.0
	boss_pattern = 0
	clear_pending = false
	invulnerable = maxf(invulnerable, 1)

func activate_hosts() -> void:
	if map.is_safe(room_index): return
	for actor in actors:
		if actor.has_meta("fodder"): continue
		if tutorial and actor != actors[0]: continue
		if not actor.claimed and not actor.rewarded:
			world.set_active(actor, true)

## Bodies for sale in the morgue are merchandise, not enemies.
func remaining() -> int:
	var count := 0
	for actor in actors:
		if actor.alive and not actor.claimed and not actor.has_meta("price"): count += 1
	return count

func timers_safe() -> bool:
	return state == State.Soul and (phase != "combat" or not host_available())

## Is there a body in this fight the ghost could borrow right now?
func host_available() -> bool:
	for actor in actors:
		if actor.alive and not actor.claimed and not actor.has_meta("fodder") and not actor.has_meta("price") and not actor.profile.get("boss", false):
			return true
	return false

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
		pending_levels += 1
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
		if map.kind(room_index) == "combat": rewards[room_index - 1] = true
		if map.kind(room_index) == "boss":
			bosses_defeated += 1
			award_relic()
		clear_pending = false
		projectiles.clear()
		hazards.clear()
		refresh_gates()
		feedback.emit("room_clear", {"index": room_index})
		feedback.emit("unsealed", {"room": room_index})
		grant_clear_loot()
		return
	if death_reason.is_empty():
		death_reason = "유령의 전투 시간이 다했습니다." if broken_by.is_empty() else broken_by + " 이후 다음 몸을 얻지 못했습니다."
	super.finish(result)

func reward_host(actor, immediate: bool) -> void:
	if actor.rewarded: return
	actor.rewarded = true
	var small: bool = actor.has_meta("fodder")
	var amount := 3 if small else 25
	if small:
		if loot_rng.randf() < 0.1: coins += 1
	elif not immediate:
		coins += 2
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
	if pool.is_empty():
		rewards[room_index - 1] = true
		return
	# A treasure room pays out at its chest, not anywhere in the room.
	if map.kind(room_index) == "treasure" and player.position.distance_to(map.center(room_index)) > 3.5: return
	levelup_offer = false
	offer_augments(pool)

## Level-up: time stops and the soul picks one of three augments, mid-fight.
func open_levelup() -> void:
	var pool := available_augments()
	pending_levels -= 1
	if pool.is_empty(): return
	levelup_offer = true
	offer_augments(pool)
	feedback.emit("level_up", {"level": level})

func offer_augments(pool: Array[String]) -> void:
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
	upgrades[id] = 2 if map.kind(room_index) == "treasure" and not levelup_offer else rank_of(id) + 1
	if levelup_offer:
		levelup_offer = false
	elif rewards_left.has(room_index):
		rewards_left[room_index] -= 1
		rewards[room_index - 1] = rewards_left[room_index] <= 0
	else:
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
	if actor.has_meta("price"): return 1.0
	return 0.0 if actor.has_meta("fodder") else super.capture_chance(actor)

func begin_possession(candidate) -> void:
	if not is_instance_valid(candidate) or candidate.has_meta("fodder"): return
	super.begin_possession(candidate)

func attempt_possession() -> void:
	var candidate = aimed_actor()
	if is_instance_valid(candidate) and candidate.has_meta("fodder"):
		feedback.emit("unreachable", {})
		return
	if is_instance_valid(candidate) and candidate.has_meta("price"):
		if stun_left > 0 or state not in [State.Soul, State.Body]: return
		if eye().distance_to(candidate.position + Vector3.UP) > 6.0:
			feedback.emit("unreachable", {})
			return
		var price: int = candidate.get_meta("price")
		if coins < price:
			feedback.emit("too_poor", {"price": price, "coins": coins})
			return
		coins -= price
		candidate.remove_meta("price")
		feedback.emit("purchase", {"kind": candidate.kind, "price": price})
		begin_possession(candidate)
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
	if state != State.Body:
		super.eject(explode)
		return
	var crack := near_crack()
	# Throwing a body against a cracked wall always detonates it: that is how secrets open.
	if crack >= 0: explode = true
	if explode and decay <= 0 and broken_by.is_empty(): broken_by = "자연 부패로 몸이 무너진"
	super.eject(explode)
	if explode and crack >= 0:
		opened_doors[crack] = true
		world.break_crack(crack)
		refresh_gates()
		feedback.emit("wall_broken", {"edge": crack})

func near_crack() -> int:
	for edge in world.cracks:
		if not room_index in map.links[edge]: continue
		var flat: Vector3 = player.position - world.cracks[edge].at
		flat.y = 0
		if flat.length() < 3.6: return edge
	return -1

## Short prompt for whatever the player is standing next to.
func context_hint() -> String:
	if near_crack() >= 0:
		return "금 간 벽 · [E] 몸을 던져 터뜨리기" if state == State.Body else "금 간 벽 · 몸이 있어야 무너뜨릴 수 있다"
	if phase == "rest" and map.kind(room_index) == "sanctuary" and not used_altars.has(room_index) and player.position.distance_to(map.center(room_index)) < 3.2:
		return "[F] 촛불 성소 · 몸의 수명을 모두 되돌린다" if state == State.Body else "촛불 성소 · 몸이 있어야 축복을 받는다"
	if phase == "rest" and map.kind(room_index) == "treasure" and not rewards[room_index - 1] and player.position.distance_to(map.center(room_index)) < 3.5:
		return "[F] 보물 상자 열기"
	return ""


func tick_enemy(actor, dt: float) -> void:
	if phase != "combat": return
	damage_from = actor.position
	damage_source = "굶주린 것의 근접 공격" if actor.has_meta("fodder") else Weapons.info(actor.kind).name + "의 공격"
	if not actor.has_meta("fodder"):
		if tutorial: return
		# This floor owns a finite stream of reinforcements at local room positions.
		if actor.profile.get("boss", false): summon_clock = 10000.0
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
	if pending_levels > 0 and not tutorial and state in [State.Soul, State.Body] and upgrade_choices.is_empty():
		open_levelup()
		if is_frozen(): return
	if phase == "combat" and not tutorial and state == State.Soul and not host_available() and (remaining() > 0 or not spawn_queue.is_empty()):
		no_host_clock += dt
		if no_host_clock > 2.5:
			no_host_clock = 0.0
			var slots := [Vector3(-7, 0.05, -8), Vector3(7, 0.05, -8), Vector3(-7, 0.05, 8), Vector3(7, 0.05, 8)]
			var best: Vector3 = slots[0]
			for slot in slots:
				if (map.center(room_index) + slot).distance_to(player.position) > (map.center(room_index) + best).distance_to(player.position): best = slot
			world.reinforce(room_index, map.center(room_index) + best)
			actors = world.room_actors[room_index - 1]
			reinforcements += 1
			feedback.emit("reinforce", {})
	else:
		no_host_clock = 0.0
	if tutorial and not actors.is_empty() and actors[0].hp < actors[0].max_hp * 0.5: tutorial_step = 1
	if tutorial and not actors.is_empty() and not actors[0].alive:
		tutorial = false
		learned = true
		activate_hosts()
	super._physics_process(dt)
	key_warn_clock = maxf(0, key_warn_clock - dt)
	if phase == "rest":
		if intent.interact: open_reward()
		if is_frozen(): return
		tick_key_doors()
		if map.kind(room_index) == "morgue" and intent.interact: buy_potion()
		if map.kind(room_index) == "sanctuary" and intent.interact: pray()
		for edge_index in map.links.size():
			var edge: Array = map.links[edge_index]
			if not room_index in edge or world.is_blocked(edge_index): continue
			var next: int = edge[1] if room_index == edge[0] else edge[0]
			var from: Vector3 = map.center(room_index)
			var to: Vector3 = map.center(next)
			var direction := (to - from).normalized()
			var midpoint := (from + to) * 0.5
			var offset: Vector3 = player.position - midpoint
			if offset.dot(direction) > 1.0 and absf(offset.dot(Vector3(-direction.z, 0, direction.x))) < 3.0:
				enter_room(next)
				break
		if room_index == map.final and cleared[map.final - 1] and player.position.z > map.center(map.final).z + 15:
			outcome = "CLEAR"
			focus_left = 0
			Engine.time_scale = 1
			clear_input()
			feedback.emit("end", {"result": outcome})

func refresh_gates() -> void:
	for i in map.links.size():
		var edge: Array = map.links[i]
		var fighting_here: bool = phase == "combat" and room_index in edge
		var locked: bool = (map.key_doors.has(i) or map.secret_doors.has(i)) and not opened_doors.has(i)
		world.gate(i, not locked)
		world.seal(i, fighting_here and not locked)
	world.gate(map.exit_door(), cleared[map.final - 1])

func grant_clear_loot() -> void:
	if not map.fights(room_index): return
	var boss: bool = map.kind(room_index) == "boss"
	coins += 12 if boss else 3
	var fights_cleared := 0
	for room in range(1, room_total + 1):
		if cleared[room - 1] and map.fights(room): fights_cleared += 1
	# First cleared fight always pays a key; non-final bosses always do; other fights are a gamble.
	if (keys_found == 0 and fights_cleared == 1) or (boss and room_index != map.final) or (not boss and loot_rng.randf() < 0.25):
		keys += 1
		keys_found += 1
		feedback.emit("key_found", {"keys": keys})

func tick_key_doors() -> void:
	for edge_index in map.key_doors:
		if opened_doors.has(edge_index): continue
		var edge: Array = map.links[edge_index]
		if not room_index in edge: continue
		var at: Vector3 = (map.center(edge[0]) + map.center(edge[1])) * 0.5
		var flat: Vector3 = player.position - at
		flat.y = 0
		if flat.length() > 3.5: continue
		if keys > 0:
			keys -= 1
			opened_doors[edge_index] = true
			refresh_gates()
			feedback.emit("door_unlocked", {"room": map.key_doors[edge_index]})
		elif key_warn_clock <= 0:
			key_warn_clock = 2.5
			feedback.emit("door_needs_key", {})

func buy_potion() -> void:
	var flask = world.potions.get(room_index)
	if used_potions.has(room_index) or state != State.Body or not is_instance_valid(flask): return
	if player.position.distance_to(flask.global_position) > 2.8: return
	if coins < Expedition.POTION_PRICE:
		if key_warn_clock <= 0:
			key_warn_clock = 1.5
			feedback.emit("too_poor", {"price": Expedition.POTION_PRICE, "coins": coins})
		return
	coins -= Expedition.POTION_PRICE
	used_potions[room_index] = true
	potion_used = true
	decay = decay_max
	flask.hide()
	feedback.emit("potion", {})

func pray() -> void:
	if used_altars.has(room_index) or player.position.distance_to(map.center(room_index)) > 3.2: return
	if state != State.Body:
		if key_warn_clock <= 0:
			key_warn_clock = 2.0
			feedback.emit("need_body", {})
		return
	used_altars[room_index] = true
	decay = decay_max
	feedback.emit("blessing", {})

## Only three relics exist; once all are owned a relic reward pays bone coins instead.
func award_relic() -> void:
	var owned_all := true
	for id in RELICS:
		if not relics.has(id): owned_all = false
	if not owned_all:
		super.award_relic()
		return
	coins += 20
	announce("유물을 모두 모았습니다 · 대신 뼈 동전 20")
