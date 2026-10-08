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
var orbit_angle := 0.0
var orbit_positions: Array[Vector3] = []
var orbit_cooldowns := {}
var lance_clock := 0.0
var storm_clock := 0.0
var tutor = null
var last_try_chance := -1.0
const PROGRESS_PATH := "user://tutorial.cfg"
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
	tutorial = not learned and not tutorial_finished()
	super.start()
	enter_room(1)
	if tutorial: begin_tutorial()

static func tutorial_finished() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(PROGRESS_PATH) == OK and cfg.get_value("tutorial", "done", false)

func save_tutorial_done() -> void:
	learned = true
	# Test runs never touch the player's real progress file.
	if "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args(): return
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "done", true)
	cfg.save(PROGRESS_PATH)

## Forced tutorial inside the sealed start room: shoot, possess, use the body, eject.
func begin_tutorial() -> void:
	tutorial = true
	tutorial_step = 0
	# A rifle body: hold-to-fire is the easiest weapon to learn on.
	tutor = world.reinforce(1, map.center(1) + Vector3(0, 0.05, -4), "soldier")
	tutor.set_meta("tutor", true)
	tutor.rotation.y = 0.0
	tutor.rewarded = true
	actors = world.room_actors[0]
	phase = "combat"
	for e in map.links.size():
		if 1 in map.links[e]: world.seal(e, true)
	feedback.emit("sealed", {"room": 1})

func end_tutorial(completed: bool) -> void:
	tutorial = false
	tutorial_step = 0
	if is_instance_valid(tutor) and not tutor.claimed:
		tutor.alive = false
		tutor.hide()
		tutor.collision_layer = 0
	phase = "rest"
	refresh_gates()
	if completed:
		save_tutorial_done()
		feedback.emit("tutorial_done", {})

func skip_training() -> void:
	if not is_multiplayer_authority() or is_frozen() or outcome != "": return
	if not running:
		learned = true
		start()
		return
	if tutorial: end_tutorial(false)

## The coach line shown in the middle of the screen during the tutorial.
func tutorial_text() -> String:
	if not tutorial: return ""
	match tutorial_step:
		0: return "좌클릭으로 앞의 해골을 쏘세요\n체력이 줄수록 빙의 확률이 올라갑니다"
		1: return "빙의 확률 100%!\n가까이 다가가 해골을 조준하고 우클릭하세요"
		2: return "빙의 성공! 이제 이 몸이 당신입니다\n좌클릭으로 이 몸의 무기를 쏴보세요"
		3: return "빌린 몸은 계속 썩습니다 (왼쪽 아래 수명)\n썩기 전에 다른 적으로 갈아타세요 · 지금은 E로 몸에서 나와보세요"
	return ""

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
	if tutorial: return true
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
	if tutorial: return
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
		if rank_of("undying") > 0: recovery *= 2.0
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
	var shooter: bool = ghost_id in ["wanderer", "arcanist"]
	for id in Build.DATA:
		if id in Build.PROJECTILE_ONLY and not shooter: continue
		if Build.DATA[id][1] == "evo":
			var ready := rank_of(id) == 0
			for ingredient in Build.EVOLUTIONS[id]:
				if rank_of(ingredient) < Build.max_rank(ingredient): ready = false
			if ready: result.append(id)
		elif rank_of(id) < Build.max_rank(id):
			result.append(id)
	return result

func soul_max() -> float:
	return 20.0 + 5.0 * rank_of("soul_time")

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
	# An evolution that just became possible always takes the first card.
	for id in pool:
		if Build.DATA[id][1] == "evo":
			upgrade_choices.append(id)
			pool.erase(id)
			break
	# Then: something for what you are now, something new, something to survive.
	var now_group: String = Build.family(body_kind) if state == State.Body else "soul"
	for category in [0, 1, 2]:
		if upgrade_choices.size() >= 3: break
		var candidates: Array[String] = []
		for id in pool:
			var group: String = Build.DATA[id][1]
			if group == "evo": continue
			if (category == 0 and group == now_group) or (category == 1 and group != now_group and group != "neutral") or (category == 2 and group == "neutral"):
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
	upgrades[id] = Build.max_rank(id) if map.kind(room_index) == "treasure" and not levelup_offer else mini(Build.max_rank(id), rank_of(id) + 1)
	if id == "soul_time" and state == State.Soul: soul = minf(soul_max(), soul + 5.0)
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
	if body_profile.is_empty():
		stats.move *= 1.0 + 0.2 * rank_of("wraith")
	elif Build.family(body_kind) == "gun":
		stats.interval *= 1.0 - 0.2 * rank_of("rapid")
	elif body_kind == "brute":
		stats.damage_taken *= 1.0 - 0.3 * rank_of("bulwark")
	return stats

func capture_chance(actor) -> float:
	if actor.has_meta("price"): return 1.0
	if actor.has_meta("tutor") and actor.hp <= actor.max_hp * 0.5: return 1.0
	return 0.0 if actor.has_meta("fodder") else super.capture_chance(actor)

func begin_possession(candidate) -> void:
	if not is_instance_valid(candidate) or candidate.has_meta("fodder"): return
	super.begin_possession(candidate)

func attempt_possession() -> void:
	var candidate = aimed_actor()
	if is_instance_valid(candidate) and candidate.has_meta("fodder"):
		feedback.emit("unreachable", {})
		return
	if is_instance_valid(candidate): last_try_chance = capture_chance(candidate)
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
	if tutorial: tutorial_step = 2
	if state == State.Body and rank_of("embalm") > 0:
		decay_max += 5.0 * rank_of("embalm")
		decay = decay_max

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
	if rank_of("funeral") >= 2: explode = true
	if explode and decay <= 0 and broken_by.is_empty(): broken_by = "자연 부패로 몸이 무너진"
	super.eject(explode)
	soul = soul_max()
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
	tick_soul_weapons(dt)
	if tutorial and tutorial_step == 0 and is_instance_valid(tutor) and tutor.hp <= tutor.max_hp * 0.5: tutorial_step = 1
	if tutorial and tutorial_step >= 2 and state == State.Soul: end_tutorial(true)
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

func damage_enemy(actor, amount: float) -> void:
	if tutorial and actor.has_meta("tutor"):
		amount = minf(amount, maxf(0.0, actor.hp - actor.max_hp * 0.15))
	super.damage_enemy(actor, amount)

func attack() -> void:
	super.attack()
	if tutorial and tutorial_step == 2 and state == State.Body and shot_left > 0: tutorial_step = 3

func attack_ghost() -> void:
	var before := projectiles.size()
	super.attack_ghost()
	if projectiles.size() == before: return
	shot_left *= 1.0 - 0.2 * rank_of("s_rate")
	var shot: Dictionary = projectiles[-1]
	shape_soul_shot(shot)
	var extra := rank_of("s_split")
	for k in extra:
		var angle: float = (0.18 if k % 2 == 0 else -0.18) * (k / 2 + 1)
		launch(shot.at, Basis(Vector3.UP, angle) * shot.velocity, shot.damage, "soul", true, null, shot.radius)
		shape_soul_shot(projectiles[-1])

func shape_soul_shot(shot: Dictionary) -> void:
	shot["pierce"] = [0, 1, 3][rank_of("s_pierce")]
	shot["homing"] = [0.0, 4.0, 9.0][rank_of("s_seek")]

func fire_arrow() -> void:
	var before := projectiles.size()
	super.fire_arrow()
	if projectiles.size() == before or rank_of("volley") == 0: return
	var arrow: Dictionary = projectiles[-1]
	for k in rank_of("volley"):
		var angle: float = 0.12 * (k + 1) * (1 if k % 2 == 0 else -1)
		launch(arrow.at, Basis(Vector3.UP, angle) * arrow.velocity, arrow.damage * 0.8, "ice", true)

func element_hit(actor, amount: float, element: String) -> void:
	super.element_hit(actor, amount, element)
	if element == "fire" and rank_of("wildfire") > 0:
		var reach := 3.0 if rank_of("wildfire") == 1 else 5.0
		for other in actors:
			if other != actor and other.alive and not other.claimed and other.position.distance_to(actor.position) < reach:
				other.burn_left = maxf(other.burn_left, 2.0)

func nearest_enemy(from: Vector3, reach: float):
	var best = null
	var best_d := reach
	for actor in actors:
		if not actor.alive or actor.claimed or actor.has_meta("price"): continue
		var d: float = actor.position.distance_to(from)
		if d < best_d and ray(from, actor.position + Vector3.UP, 1).is_empty():
			best = actor
			best_d = d
	return best

## Soul weapons and evolutions: they work in any body, only while a fight is on.
func tick_soul_weapons(dt: float) -> void:
	orbit_positions.clear()
	if phase != "combat" or tutorial or state not in [State.Soul, State.Body]: return
	var crown := rank_of("bone_crown") > 0
	var skulls := 4 if crown else rank_of("orbit")
	if skulls > 0:
		orbit_angle += dt * 2.6
		for k in skulls:
			var a: float = orbit_angle + TAU * k / skulls
			orbit_positions.append(player.position + Vector3(cos(a) * 2.3, 1.1, sin(a) * 2.3))
		for id in orbit_cooldowns.keys():
			orbit_cooldowns[id] -= dt
			if orbit_cooldowns[id] <= 0: orbit_cooldowns.erase(id)
		for actor in actors:
			if not actor.alive or actor.claimed or actor.has_meta("price") or orbit_cooldowns.has(actor.get_instance_id()): continue
			for skull in orbit_positions:
				if (actor.position + Vector3.UP).distance_to(skull) < 1.1:
					damage_enemy(actor, 14.0 * (2.0 if crown else 1.0))
					orbit_cooldowns[actor.get_instance_id()] = 0.6
					break
	if rank_of("lance") > 0:
		lance_clock -= dt
		if lance_clock <= 0:
			var target = nearest_enemy(eye(), 16.0)
			if target != null:
				var aim_dir: Vector3 = (target.position + Vector3.UP - eye()).normalized()
				launch(eye(), aim_dir * 30.0, 28.0, "soul", true, null, 0.15)
				projectiles[-1]["pierce"] = 3
				feedback.emit("lance", {})
			lance_clock = 2.4 if rank_of("lance") == 1 else 1.4
	if rank_of("storm_soul") > 0:
		storm_clock -= dt
		if storm_clock <= 0:
			storm_clock = 2.0
			for k in 8:
				var dir := Vector3(cos(TAU * k / 8.0), 0.05, sin(TAU * k / 8.0))
				launch(player.position + Vector3.UP * 1.1, dir * 12.0, 16.0, "soul", true, null, 0.2)
				projectiles[-1]["homing"] = 6.0
				projectiles[-1]["pierce"] = 1
	if rank_of("undying") > 0 and state == State.Body and not timers_safe():
		decay = minf(decay_max, decay + dt * 0.5)
