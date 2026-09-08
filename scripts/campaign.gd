extends "res://scripts/journey.gd"
## One seeded expedition. Encounter decisions and rewards remain authoritative.
const RELICS := {
	"compass": ["영혼 나침반", "빙의 확률 +5%p (최대 95%)"],
	"glass": ["멈춘 모래시계", "새로 빌리는 모든 몸의 최대 수명 +6초"],
	"ember": ["메아리 불씨", "공격 적중 시 4m 내 다른 적 하나에 피해 20% 전이 · 0.7초 간격"]
}
const COMBOS := {
	"infiltrator": ["연쇄 잠입", "ambush", "mercy", "첫 공격 강화 + 빙의 확률 증가", "빙의 확률 추가 +12%p"],
	"undying": ["썩지 않는 분노", "vigor", "rot", "몸 수명 증가 + 부패 공격 강화", "몸 피격으로 잃는 수명 30% 감소"],
	"rebirth": ["불사조의 장례", "curse", "funeral", "유령탄 강화 + 몸 폭발 강화", "E로 직접 이탈해도 강화된 폭발 발생"]
}
var run_seed := 0
var world_rng := RandomNumberGenerator.new()
var plans: Array[Dictionary] = []
var relics: Array[String] = []
var completed_combos: Array[String] = []
var routes: Dictionary = {}
var quest_kind := 0
var quest_progress := 0
var quest_complete := false
var secret_taken := false
var secret_hold := 0.0
var secret_position := Vector3(11, 0.8, -10)
var secrets_found := 0
var wave := 1
var wave_wait := 0.0
var hazards: Array[Dictionary] = []
var boss_clock := 3.0
var summon_clock := 9.0
var chain_clock := 0.0
var chain_active := false
var journal_open := false
var banner := ""
var banner_left := 0.0
var bosses_defeated := 0
var rerolls := 2
var essence := 0

func _ready() -> void:
	super._ready()
	if run_seed == 0:
		world_rng.randomize()
		run_seed = int(world_rng.randi() % 999999) + 1
	world_rng.seed = run_seed
	rng.seed = run_seed + 31
	offer_rng.seed = run_seed + 67
	quest_kind = world_rng.randi_range(0, 2)
	room_total = 7
	room_names = ["깨어나는 방"]
	plans.append({})
	for i in range(1, 8):
		var boss := "warden" if i == 3 else ("sovereign" if i == 7 else "")
		var layout := "hall" if world_rng.randf() < 0.5 else "vault"
		var name := "잊힌 회랑" if layout == "hall" else "감시자의 묘실"
		if boss != "":
			name = "중간 보스 · 묘지기" if i == 3 else "최종 보스 · 공허의 군주"
		var hidden_at := Vector3(11 if world_rng.randf() < 0.5 else -11, 0.8, [-5, -10, -15][world_rng.randi_range(0, 2)])
		plans.append({"layout": layout, "boss": boss, "seed": int(world_rng.randi()), "waves": 1 if i == 1 or boss != "" else 2, "secret": i in [2, 4, 6], "hidden_at": hidden_at, "route": 0})
		room_names.append("%d / 7 · %s" % [i, name])

func is_frozen() -> bool:
	return journal_open or super.is_frozen()

func timers_safe() -> bool:
	return wave_wait > 0 or super.timers_safe()

func room_layout() -> String:
	return plans[room_index].layout

func encounter_spec() -> Dictionary:
	return {"seed": plans[room_index].seed + wave, "count": 3 if room_index == 1 else 4, "boss": plans[room_index].boss if wave == 1 else "", "tier": room_index, "route": plans[room_index].route, "secret": plans[room_index].secret, "hidden_at": plans[room_index].hidden_at}

func begin_travel() -> void:
	wave = 1
	super.begin_travel()

func room_arrived() -> void:
	wave = 1
	wave_wait = 0
	hazards.clear()
	secret_taken = false
	secret_position = plans[room_index].hidden_at
	secret_hold = 0
	boss_clock = 3
	summon_clock = 9
	chain_clock = 0

func route_pending() -> bool:
	return phase == "rest" and room_index in [1, 3, 5] and not routes.has(room_index) and not paused and not journal_open and upgrade_choices.is_empty()

func select_route(index: int) -> void:
	if not is_multiplayer_authority() or not route_pending() or index not in [0, 1]:
		return
	routes[room_index] = index
	plans[room_index + 1].route = index
	plans[room_index + 1].layout = "vault" if index == 1 else "hall"
	room_names[room_index + 1] = "%d / 7 · %s" % [room_index + 1, "시련의 보물고" if index == 1 else "순례자의 회랑"]
	announce("경로 선택: " + ("시련의 보물고 · 적 강화 / 추가 증강" if index == 1 else "순례자의 회랑 · 입장 시 시간 회복"))

func can_leave_room() -> bool:
	return not route_pending() and super.can_leave_room()

func confirm_ready() -> void:
	if journal_open:
		return
	var ready := phase == "briefing" and not is_frozen_except_briefing()
	super.confirm_ready()
	if ready and phase == "combat" and plans[room_index].route == 0:
		soul = 20
		if state == State.Body:
			decay = decay_max

func is_frozen_except_briefing() -> bool:
	return paused or journal_open or not upgrade_choices.is_empty()

func _physics_process(dt: float) -> void:
	if not is_multiplayer_authority() or journal_open:
		return
	if running and not is_frozen() and outcome == "":
		banner_left = maxf(0, banner_left - dt)
	if phase == "combat" and not is_frozen() and running and outcome == "" and settle_left <= 0 and upgrade_wait <= 0 and state in [State.Soul, State.Body]:
		chain_clock = maxf(0, chain_clock - dt)
		if wave_wait > 0:
			wave_wait = maxf(0, wave_wait - dt)
			clear_input()
			if wave_wait == 0:
				wave += 1
				feedback.emit("reinforcements", {"spec": encounter_spec()})
				announce("증원 도착 · %d / %d차 전투" % [wave, plans[room_index].waves])
			return
		tick_hazards(dt)
		if outcome != "" or state == State.Ejecting:
			return
	super._physics_process(dt)
	if phase == "rest" and not is_frozen() and outcome == "":
		if can_find_secret() and intent.interact:
			secret_hold += dt
			if secret_hold >= 1:
				secret_taken = true
				secrets_found += 1
				award_relic()
		else:
			secret_hold = 0

func can_find_secret() -> bool:
	if room_index == 0 or phase != "rest" or secret_taken or not plans[room_index].secret:
		return false
	var delta := secret_position - eye()
	return delta.length() < 2.7 and forward().dot(delta.normalized()) > 0.65 and ray(eye(), secret_position, 1).is_empty()

func check_clear() -> void:
	if phase == "combat" and remaining() == 0 and room_index > 0 and wave < plans[room_index].waves:
		collect_fragments(true)
		if wave_wait <= 0:
			wave_wait = 3
		return
	super.check_clear()

func finish(result: String) -> void:
	var cleared := result == "CLEAR" and phase == "combat"
	super.finish(result)
	if cleared:
		hazards.clear()
		if plans[room_index].boss != "":
			bosses_defeated += 1
			award_relic()
		if plans[room_index].route == 1:
			pending_levels += 1
			# A reward selection uses the same safe modal even after combat.
			resolve_flow()

func resolve_flow() -> void:
	if pending_levels > 0 and available_augments().is_empty():
		essence += pending_levels
		pending_levels = 0
		announce("빌드 성장 완료 · 잔향 공격력 +%d%%" % mini(30, essence * 3))
	if phase == "rest" and pending_levels > 0 and not journal_open:
		var previous := phase
		phase = "combat"
		super.resolve_flow()
		phase = previous
		return
	super.resolve_flow()

func available_augments() -> Array[String]:
	var pool := super.available_augments()
	if upgrades.size() >= 4:
		pool = pool.filter(func(id): return upgrades.has(id))
	return pool

func reroll_upgrades() -> void:
	if not is_multiplayer_authority() or paused or journal_open or upgrade_choices.is_empty() or rerolls <= 0:
		return
	rerolls -= 1
	var previous := upgrade_choices.duplicate()
	upgrade_choices.clear()
	var pool := available_augments()
	for pass_index in 2:
		var candidates: Array[String] = pool.filter(func(id): return not previous.has(id) if pass_index == 0 else true)
		while not candidates.is_empty() and upgrade_choices.size() < 3:
			var index := offer_rng.randi_range(0, candidates.size() - 1)
			var id: String = candidates[index]
			upgrade_choices.append(id)
			pool.erase(id)
			candidates.remove_at(index)
	clear_input()
	feedback.emit("upgrade_offer", {})

func quest_text() -> String:
	return ["서로 다른 적에게 8회 빙의", "특별 개체 4명 처치 또는 빙의", "적 10명 직접 처치"][quest_kind]

func quest_goal() -> int:
	return [8, 4, 10][quest_kind]

func reward_host(actor, immediate: bool) -> void:
	var eligible: bool = phase == "combat" and not actor.rewarded
	super.reward_host(actor, immediate)
	if eligible and not quest_complete and ((quest_kind == 0 and immediate) or (quest_kind == 1 and actor.profile.special) or (quest_kind == 2 and not immediate)):
		quest_progress += 1
		if quest_progress >= quest_goal():
			quest_complete = true
			award_relic()
			announce("의뢰 완료! " + quest_text() + " · 유물 획득")

func award_relic() -> void:
	var pool: Array = RELICS.keys().filter(func(id): return not relics.has(id))
	if pool.is_empty():
		pending_levels += 1
		announce("유물 수집 완료 · 추가 증강 획득")
		return
	var id: String = pool[world_rng.randi_range(0, pool.size() - 1)]
	relics.append(id)
	announce("유물 발견 · " + RELICS[id][0] + " / " + RELICS[id][1])

func announce(message: String) -> void:
	banner = message
	banner_left = 5
	feedback.emit("milestone", {"text": message})

func has_combo(id: String) -> bool:
	return rank_of(COMBOS[id][1]) > 0 and rank_of(COMBOS[id][2]) > 0

func choose_upgrade(index: int) -> void:
	if not is_multiplayer_authority() or journal_open:
		return
	if index >= 0 and index < upgrade_choices.size() and upgrades.size() >= 4 and not upgrades.has(upgrade_choices[index]):
		return
	super.choose_upgrade(index)
	for id in COMBOS:
		if has_combo(id) and not completed_combos.has(id):
			completed_combos.append(id)
			announce("조합 완성! " + COMBOS[id][0] + " · " + COMBOS[id][4])

func current_stats() -> Dictionary:
	var stats := super.current_stats()
	stats.damage *= 1 + minf(0.3, essence * 0.03)
	if not body_profile.is_empty():
		if relics.has("glass"):
			stats.life += 6
		if has_combo("undying"):
			stats.damage_taken *= 0.7
	return stats

func capture_chance(actor) -> float:
	if actor.profile.get("boss", false) and actor.hp > actor.max_hp * 0.2:
		return 0
	return minf(0.95, super.capture_chance(actor) + (0.05 if relics.has("compass") else 0) + (0.12 if has_combo("infiltrator") else 0)) if phase != "training" else super.capture_chance(actor)

func attempt_possession() -> void:
	var candidate = aimed_actor()
	if candidate != null and candidate.profile.get("boss", false) and capture_chance(candidate) == 0:
		announce("보스의 의지 · 체력을 20% 이하로 낮추면 빙의 가능")
		return
	super.attempt_possession()

func begin_possession(candidate) -> void:
	if is_instance_valid(candidate) and candidate.profile.get("boss", false) and capture_chance(candidate) == 0:
		return
	super.begin_possession(candidate)

func eject(explode: bool) -> void:
	super.eject(explode or (phase == "combat" and has_combo("rebirth")))

func damage_enemy(actor, amount: float) -> void:
	var can_chain: bool = not chain_active and chain_clock <= 0 and relics.has("ember") and actor.alive and not actor.claimed and phase == "combat"
	super.damage_enemy(actor, amount)
	if can_chain:
		for other in actors:
			if other != actor and other.alive and not other.claimed and other.position.distance_to(actor.position) < 4:
				var sight := ray(actor.position + Vector3.UP, other.position + Vector3.UP)
				if not sight.is_empty() and sight.collider == other:
					chain_clock = 0.7
					chain_active = true
					super.damage_enemy(other, amount * 0.2)
					chain_active = false
					feedback.emit("enemy_shot", {"from": actor.position + Vector3.UP, "to": other.position + Vector3.UP})
					break

func tick_enemy(actor, dt: float) -> void:
	if not actor.profile.get("boss", false) or phase != "combat":
		super.tick_enemy(actor, dt)
		return
	# Boss sight deliberately ignores disguise; its briefing explains this rule.
	var delta: Vector3 = player.position - actor.position
	delta.y = 0
	actor.velocity = delta.normalized() * (1.3 if delta.length() > 6 else 0)
	actor.velocity.y = -1
	actor.move_and_slide()
	actor.rotation.y = atan2(delta.x, delta.z)
	boss_clock -= dt
	summon_clock -= dt
	if summon_clock <= 0:
		summon_clock = 10
		if remaining() < 5:
			feedback.emit("reinforcements", {"spec": {"seed": int(world_rng.randi()), "count": 2, "boss": "", "tier": 1, "route": 0}, "summoned": true})
	if boss_clock <= 0:
		var rage: bool = actor.hp <= actor.max_hp * 0.5
		boss_clock = 2.4 if rage else 4.0
		var count := 3 if actor.profile.id == "sovereign" and rage else 1
		for i in count:
			var at: Vector3 = player.position + Vector3((i - 1) * 4 if count > 1 else 0, 0, 0)
			hazards.append({"at": at, "left": 1.4, "radius": 3.0, "damage": 5.0 if rage else 3.5})
		feedback.emit("boss_warning", {"at": player.position, "rage": rage})

func tick_hazards(dt: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		hazard.left -= dt
		if hazard.left <= 0:
			hazards.remove_at(i)
			feedback.emit("slam", {"at": hazard.at})
			var flat: Vector3 = player.position - hazard.at
			flat.y = 0
			if flat.length() < hazard.radius and ray(hazard.at + Vector3.UP, eye(), 1).is_empty():
				hurt(hazard.damage)
