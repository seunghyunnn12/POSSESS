extends Node
## Single simulation owner. Input submits intent; presentation observes signals/data.
## A future server receives validated input frames and replicates this state.
## No client-side damage, RNG, possession or lifetime decisions.

const Actor = preload("res://scripts/actor.gd")
const Traits = preload("res://scripts/traits.gd")
const Augments = preload("res://scripts/augments.gd")
enum State { Soul, Possessing, Body, Ejecting }
signal feedback(event: String, data: Dictionary)

var state: State = State.Soul
var player: CharacterBody3D
var actors: Array = []
var running := false
var paused := false
var outcome := ""
var soul := 20.0
var decay := 0.0
var decay_max := 25.0
var body_kind := ""
var body_profile: Dictionary = {}
var disguised := false
var detection := 0.0
var ammo := 18
var reload_left := 0.0
var shot_left := 0.0
var stun_left := 0.0
var transition_left := 0.0
var possession_duration := 0.3
var yaw := 0.0
var pitch := 0.0
var intent := {"move": Vector2.ZERO, "fire": false, "interact": false}
var queued := {"jump": false, "possess": false, "eject": false, "reload": false}
var target = null
var transition_from := Vector3.ZERO
var transition_to := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var possession_count := 0
var kills := 0
var invulnerable := 0.0
var progression_enabled := true
var level := 1
var xp := 0
var xp_next := 30
var pending_levels := 0
var upgrades: Dictionary = {}
var upgrade_choices: Array[String] = []
var fragments: Array[Dictionary] = []
var next_fragment_id := 0
var clear_pending := false
var opening := 0.0
var supply_used := false
var supply_position := Vector3(-6, 0.6, -1)
var offer_rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	offer_rng.randomize()

func configure(body: CharacterBody3D, enemies: Array) -> void:
	player = body
	actors = enemies

func start() -> void:
	if not is_multiplayer_authority():
		return
	running = true
	feedback.emit("start", {})

func is_frozen() -> bool:
	return paused or not upgrade_choices.is_empty()

func animation_frozen() -> bool:
	return is_frozen()

func timers_safe() -> bool:
	return false

func rank_of(id: String) -> int:
	return upgrades.get(id, 0)

func current_stats() -> Dictionary:
	if body_profile.is_empty():
		return {"damage": 14.0 * (1.0 + 0.25 * rank_of("curse")), "move": 8.2, "life": 20.0, "interval": 0.32, "reload": 0.0, "recoil": 0.1, "damage_taken": 1.0, "host_health": 0.0}
	var stats := Traits.stats(body_kind, body_profile)
	stats.life *= 1.0 + 0.2 * rank_of("vigor")
	var rotten := 1.0 - clampf(decay / maxf(decay_max, 0.01), 0.0, 1.0)
	stats.damage *= 1.0 + 0.35 * rank_of("rot") * rotten
	return stats

func capture_chance(actor) -> float:
	var insight := 0.08 if state == State.Body and body_profile.get("id", "") == "seer" else 0.0
	return clampf(actor.chance() + 0.08 * rank_of("mercy") + insight, 0.02, 0.95)

func submit_input(move: Vector2, fire: bool, aim: Vector2, interact: bool = false) -> void:
	# When networking is added, validate sender ownership at this boundary.
	if not is_multiplayer_authority() or is_frozen() or not running or outcome != "":
		return
	intent.move = move.limit_length()
	intent.fire = fire
	intent.interact = interact
	yaw = wrapf(aim.x, -PI, PI)
	pitch = clampf(aim.y, -1.38, 1.38)

func request(action: String) -> void:
	if is_multiplayer_authority() and running and not is_frozen() and outcome == "" and queued.has(action):
		queued[action] = true

func clear_input() -> void:
	intent.move = Vector2.ZERO
	intent.fire = false
	intent.interact = false
	for key in queued:
		queued[key] = false

func eye() -> Vector3:
	return player.position + Vector3.UP * (1.75 if body_kind == "brute" and state == State.Body else 1.5)

func forward() -> Vector3:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3.FORWARD

func ray(from: Vector3, to: Vector3, mask: int = 5) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	return player.get_world_3d().direct_space_state.intersect_ray(query)

func aimed_actor():
	var hit := ray(eye(), eye() + forward() * 45.0)
	if not hit.is_empty() and hit.collider is Actor and hit.collider.alive and not hit.collider.claimed:
		return hit.collider
	return null

func _physics_process(dt: float) -> void:
	if not is_multiplayer_authority() or not running or is_frozen() or outcome != "":
		return
	resolve_flow()
	if is_frozen() or outcome != "":
		return
	if not timers_safe():
		elapsed += dt
	shot_left = maxf(0.0, shot_left - dt)
	stun_left = maxf(0.0, stun_left - dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	if reload_left > 0.0:
		reload_left -= dt
		if reload_left <= 0.0:
			ammo = 18
			feedback.emit("loaded", {})
	if state == State.Possessing or state == State.Ejecting:
		transition_left -= dt
		if state == State.Possessing:
			var t := 1.0 - clampf(transition_left / possession_duration, 0.0, 1.0)
			player.position = transition_from.lerp(transition_to, t * t * (3.0 - 2.0 * t))
		if transition_left <= 0.0:
			if state == State.Possessing:
				finish_possession()
			else:
				state = State.Soul
				body_kind = ""
				body_profile.clear()
				check_clear()
				resolve_flow()
		clear_input()
		return
	if timers_safe():
		pass
	elif state == State.Soul:
		soul = maxf(0.0, soul - dt)
		if soul <= 0.0:
			finish("DEAD")
			return
	else:
		decay = maxf(0.0, decay - dt)
		if decay <= 0.0:
			eject(true)
			clear_input()
			return
	move_player(dt)
	collect_fragments()
	tick_supply(dt)
	if queued.eject and state == State.Body:
		eject(false)
	elif queued.possess and stun_left <= 0.0:
		attempt_possession()
	elif queued.reload:
		begin_reload()
	if state == State.Soul or state == State.Body:
		if intent.fire and stun_left <= 0.0:
			attack()
		for actor in actors:
			if actor.alive and not actor.claimed:
				tick_enemy(actor, dt)
				if outcome != "" or state == State.Ejecting:
					break
	for key in queued:
		queued[key] = false
	check_clear()
	resolve_flow()

func move_player(dt: float) -> void:
	var speed: float = current_stats().move
	var axis: Vector2 = intent.move
	var direction := Basis(Vector3.UP, yaw) * Vector3(axis.x, 0, axis.y)
	if stun_left <= 0.0:
		player.velocity.x = move_toward(player.velocity.x, direction.x * speed, dt * 42.0)
		player.velocity.z = move_toward(player.velocity.z, direction.z * speed, dt * 42.0)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, dt * 12.0)
		player.velocity.z = move_toward(player.velocity.z, 0.0, dt * 12.0)
	if not player.is_on_floor():
		player.velocity.y -= (12.0 if state == State.Soul else 20.0) * dt
	elif queued.jump and stun_left <= 0.0:
		player.velocity.y = 4.0 if state == State.Soul else 4.4
	player.move_and_slide()
	if player.position.y < -8.0:
		finish("DEAD")

func attempt_possession() -> void:
	# Direct body-to-body transfer keeps the core loop fluid. Old body is consumed.
	if not is_multiplayer_authority() or is_frozen() or outcome != "" or stun_left > 0.0 or (state != State.Soul and state != State.Body):
		return
	var candidate = aimed_actor()
	if candidate == null or eye().distance_to(candidate.position + Vector3.UP) > 6.0:
		feedback.emit("unreachable", {})
		shot_left = maxf(shot_left, 0.15)
		return
	opening = 0.0
	if rng.randf() >= capture_chance(candidate):
		expose("failed")
		stun_left = 0.5
		player.velocity = -forward() * 8.0 + Vector3.UP * 2.0
		feedback.emit("rejected", {"at": candidate.position})
		return
	begin_possession(candidate)

func begin_possession(candidate) -> void:
	if not is_multiplayer_authority() or is_frozen() or outcome != "" or (state != State.Soul and state != State.Body) or not is_instance_valid(candidate) or not candidate.alive or candidate.claimed:
		return
	target = candidate
	candidate.claimed = true
	candidate.label.hide()
	candidate.collision_layer = 0
	candidate.collision_mask = 0
	transition_from = player.position
	transition_to = candidate.position
	# Lift origin slightly to avoid floor precision issues; claimed collider is disabled.
	transition_to.y = maxf(0.05, transition_to.y)
	state = State.Possessing
	transition_left = possession_duration
	player.velocity = Vector3.ZERO
	reload_left = 0.0
	opening = 0.0
	detection = 0.0
	for actor in actors:
		actor.windup = 0.0
		actor.detection = 0.0
		actor.velocity = Vector3.ZERO
	feedback.emit("possess", {"at": candidate.position, "kind": candidate.kind})

func finish_possession() -> void:
	if not is_instance_valid(target):
		state = State.Soul
		soul = 20.0
		body_kind = ""
		body_profile.clear()
		return
	body_kind = target.kind
	body_profile = target.profile.duplicate(true)
	decay_max = current_stats().life
	decay = decay_max
	ammo = 18
	shot_left = 0.2
	state = State.Body
	disguised = true
	possession_count += 1
	invulnerable = 0.5
	target.alive = false
	target.hide()
	reward_host(target, true)
	target = null
	feedback.emit("inhabit", {"kind": body_kind})
	check_clear()
	resolve_flow()

func begin_reload() -> void:
	if state == State.Body and body_kind == "soldier" and ammo < 18 and reload_left <= 0.0:
		reload_left = current_stats().reload
		feedback.emit("reload", {})

func attack() -> void:
	if not is_multiplayer_authority() or is_frozen() or outcome != "" or (state != State.Soul and state != State.Body) or shot_left > 0.0 or reload_left > 0.0:
		return
	if state == State.Body and body_kind == "soldier" and ammo <= 0:
		begin_reload()
		return
	var opening_multiplier := 1.0 + 0.6 * rank_of("ambush") if disguised else 1.0
	var stats := current_stats()
	expose("attack")
	opening = 0.0
	if state == State.Body and body_kind == "brute":
		shot_left = stats.interval
		var count := 0
		for actor in actors:
			if not actor.alive or actor.claimed:
				continue
			var delta: Vector3 = actor.position + Vector3.UP - eye()
			if delta.length() < 3.2 and forward().dot(delta.normalized()) > 0.35:
				var hit := ray(eye(), actor.position + Vector3.UP)
				if not hit.is_empty() and hit.collider == actor:
					damage_enemy(actor, stats.damage * opening_multiplier)
					count += 1
		feedback.emit("swing", {"hit": count > 0})
		return
	var is_soul := state == State.Soul
	if not is_soul:
		if ammo <= 0:
			begin_reload()
			return
		ammo -= 1
	shot_left = stats.interval
	var from := eye()
	var end := from + forward() * 45.0
	var hit := ray(from, end)
	var connected := false
	if not hit.is_empty():
		end = hit.position
		if hit.collider is Actor and hit.collider.alive and not hit.collider.claimed:
			damage_enemy(hit.collider, stats.damage * opening_multiplier)
			connected = true
	feedback.emit("shot", {"from": from, "to": end, "soul": is_soul, "hit": connected})

func damage_enemy(actor, amount: float) -> void:
	if not actor.alive or actor.claimed:
		return
	actor.hp = maxf(0.0, actor.hp - amount)
	actor.flash = 0.12
	feedback.emit("hit", {"at": actor.position + Vector3.UP, "dead": actor.hp <= 0.0})
	if actor.hp <= 0.0:
		actor.alive = false
		actor.collision_layer = 0
		actor.collision_mask = 0
		actor.hide()
		kills += 1
		reward_host(actor, false)
		check_clear()

func hurt(amount: float) -> void:
	if outcome != "" or invulnerable > 0.0 or state == State.Possessing or state == State.Ejecting:
		return
	feedback.emit("hurt", {"amount": amount})
	if state == State.Body:
		decay = maxf(0.0, decay - amount * current_stats().damage_taken)
		if decay <= 0.0:
			eject(true)
	else:
		soul = maxf(0.0, soul - amount)
		if soul <= 0.0:
			finish("DEAD")

func eject(explode: bool) -> void:
	if state != State.Body:
		return
	state = State.Ejecting
	disguised = false
	detection = 0.0
	opening = 0.0
	transition_left = 0.25
	soul = 20.0
	invulnerable = 0.75
	reload_left = 0.0
	shot_left = 0.2
	feedback.emit("eject", {"at": player.position + Vector3.UP, "explode": explode})
	if explode:
		var radius := 4.5 * (1.0 + 0.3 * rank_of("funeral"))
		var damage := 60.0 * (1.0 + 0.4 * rank_of("funeral"))
		for actor in actors:
			if actor.alive and not actor.claimed and actor.position.distance_to(player.position) < radius:
				var hit := ray(eye(), actor.position + Vector3.UP)
				if not hit.is_empty() and hit.collider == actor:
					damage_enemy(actor, damage)

func tick_enemy(actor, dt: float) -> void:
	if state == State.Body and disguised:
		tick_unaware(actor, dt)
		return
	actor.detection = 0.0
	actor.attack_clock -= dt
	var delta: Vector3 = player.position - actor.position
	delta.y = 0.0
	var distance := delta.length()
	var direction := delta.normalized()
	var speed := 0.0
	var desired := Vector3.ZERO
	if actor.windup > 0.0:
		actor.windup -= dt
		if actor.kind == "brute":
			desired = actor.charge_direction * 8.5 if actor.windup < 0.32 else Vector3.ZERO
		if actor.windup <= 0.0:
			var from: Vector3 = actor.position + Vector3.UP * 1.3
			var hit := ray(from, eye(), 1 | 2)
			if not hit.is_empty() and hit.collider == player:
				if actor.kind == "soldier":
					# Aim locks when telegraph begins: strafing avoids the shot.
					var aim: Vector3 = actor.charge_direction
					var aim_hit := ray(from, from + aim * 35.0, 1 | 2)
					var end: Vector3 = from + aim * 35.0
					if not aim_hit.is_empty():
						end = aim_hit.position
						if aim_hit.collider == player:
							hurt(actor.attributes.enemy_damage)
					feedback.emit("enemy_shot", {"from": from, "to": end})
				elif distance < 2.6:
					hurt(actor.attributes.enemy_damage)
					feedback.emit("slam", {"at": actor.position})
	else:
		if actor.kind == "soldier":
			speed = actor.attributes.enemy_move
			if distance > 9.0:
				desired = direction * speed
			elif distance < 4.0:
				desired = -direction * speed * 0.7
			if actor.attack_clock <= 0.0 and distance < 19.0:
				var from: Vector3 = actor.position + Vector3.UP * 1.3
				var sight := ray(from, eye(), 1 | 2)
				if not sight.is_empty() and sight.collider == player:
					actor.windup = 0.55
					actor.charge_direction = (eye() - from).normalized()
					actor.attack_clock = actor.attributes.enemy_interval + rng.randf_range(-0.2, 0.4)
		else:
			desired = direction * float(actor.attributes.enemy_move)
			if distance < 6.5 and actor.attack_clock <= 0.0:
				actor.windup = 0.85
				actor.charge_direction = direction
				actor.attack_clock = actor.attributes.enemy_interval
	actor.velocity.x = desired.x
	actor.velocity.z = desired.z
	actor.velocity.y -= 20.0 * dt
	actor.move_and_slide()
	if direction.length_squared() > 0.01:
		actor.rotation.y = atan2(direction.x, direction.z)

func remaining() -> int:
	var count := 0
	for actor in actors:
		if actor.alive and not actor.claimed:
			count += 1
	return count

func check_clear() -> void:
	if remaining() == 0:
		clear_pending = true
		collect_fragments(true)

func finish(result: String) -> void:
	if outcome != "":
		return
	outcome = result
	if result == "DEAD":
		upgrade_choices.clear()
		pending_levels = 0
	clear_input()
	feedback.emit("end", {"result": result})

func expose(reason: String) -> void:
	if not disguised:
		return
	disguised = false
	detection = 0.0
	for actor in actors:
		actor.detection = 0.0
		actor.attack_clock = maxf(actor.attack_clock, 0.4)
	feedback.emit("exposed", {"reason": reason})

func tick_unaware(actor, dt: float) -> void:
	actor.windup = 0.0
	actor.attack_clock = maxf(actor.attack_clock, 0.5)
	if actor.profile.id == "seer":
		var from: Vector3 = actor.position + Vector3.UP * 1.5
		var delta: Vector3 = eye() - from
		var facing: Vector3 = actor.basis.z
		var seen := false
		if delta.length() <= 10.0 and (delta.length() < 2.5 or facing.dot(delta.normalized()) > 0.15):
			var sight := ray(from, eye(), 3)
			seen = not sight.is_empty() and sight.collider == player
		var previous: float = actor.detection
		actor.detection = clampf(actor.detection + (dt / 2.0 if seen else -dt * 0.75), 0.0, 1.0)
		if previous == 0.0 and actor.detection > 0.0:
			feedback.emit("detection", {})
		detection = 0.0
		for other in actors:
			if other.alive and not other.claimed:
				detection = maxf(detection, other.detection)
		if actor.detection >= 1.0:
			expose("seer")
			return
	# Neutral patrols do not follow the player. There is room to slip past them.
	var phase: float = elapsed * 0.25 + actor.get_index()
	var destination: Vector3 = actor.home + Vector3(sin(phase), 0, cos(phase)) * 1.5
	var direction: Vector3 = destination - actor.position
	direction.y = 0
	if direction.length() > 0.2:
		direction = direction.normalized()
		actor.rotation.y = atan2(direction.x, direction.z)
	else:
		direction = Vector3.ZERO
	actor.velocity.x = direction.x * actor.attributes.enemy_move * 0.35
	actor.velocity.z = direction.z * actor.attributes.enemy_move * 0.35
	actor.velocity.y -= dt * 20.0
	actor.move_and_slide()

func can_open_supply() -> bool:
	if supply_used or state != State.Body or decay >= decay_max - 0.1:
		return false
	var delta := supply_position - eye()
	if delta.length() > 2.6 or forward().dot(delta.normalized()) < 0.82:
		return false
	var hit := ray(eye(), supply_position, 5)
	return hit.is_empty() or hit.collider.has_meta("supply")

func tick_supply(dt: float) -> void:
	if intent.interact and not intent.fire and not queued.eject and not queued.possess and can_open_supply():
		opening += dt
		if opening >= 1.0:
			supply_used = true
			opening = 0.0
			var restored := minf(8.0, decay_max - decay)
			decay += restored
			feedback.emit("supply", {"restored": restored})
	else:
		opening = 0.0

func reward_host(actor, immediate: bool) -> void:
	if actor.rewarded or not progression_enabled:
		return
	actor.rewarded = true
	var amount := 30 if actor.profile.special else 20
	if immediate:
		gain_xp(amount)
	else:
		var fragment := {"id": next_fragment_id, "position": actor.position + Vector3.UP * 0.5, "amount": amount}
		next_fragment_id += 1
		fragments.append(fragment)
		feedback.emit("fragment", fragment)

func collect_fragments(all_remaining: bool = false) -> void:
	for i in range(fragments.size() - 1, -1, -1):
		var fragment := fragments[i]
		if not all_remaining:
			if player.position.distance_to(fragment.position) > 2.5:
				continue
			if not ray(eye(), fragment.position, 1).is_empty():
				continue
		fragments.remove_at(i)
		gain_xp(fragment.amount)
		feedback.emit("collected", fragment)

func gain_xp(amount: int) -> void:
	if amount <= 0 or not progression_enabled:
		return
	xp += amount
	feedback.emit("xp", {"amount": amount})
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next += 10
		pending_levels += 1

func resolve_flow() -> void:
	if outcome != "" or state == State.Possessing or state == State.Ejecting or not upgrade_choices.is_empty():
		return
	if pending_levels > 0:
		var available: Array[String] = available_augments()
		while not available.is_empty() and upgrade_choices.size() < 3:
			var index := offer_rng.randi_range(0, available.size() - 1)
			upgrade_choices.append(available[index])
			available.remove_at(index)
		pending_levels -= 1
		if not upgrade_choices.is_empty():
			clear_input()
			feedback.emit("upgrade_offer", {})
			return
		# A fully upgraded run has no remaining choices; do not soft-lock it.
		resolve_flow()
		return
	if clear_pending:
		finish("CLEAR")

func available_augments() -> Array[String]:
	var available: Array[String] = []
	for id in Augments.DEFINITIONS:
		if rank_of(id) < 2:
			available.append(id)
	return available

func choose_upgrade(index: int) -> void:
	if not is_multiplayer_authority() or paused or outcome != "" or index < 0 or index >= upgrade_choices.size():
		return
	var id: String = upgrade_choices[index]
	var old_max := decay_max
	upgrades[id] = rank_of(id) + 1
	if id == "vigor" and state == State.Body:
		decay_max = current_stats().life
		decay = clampf(decay / old_max, 0.0, 1.0) * decay_max
	upgrade_choices.clear()
	clear_input()
	feedback.emit("upgrade_chosen", {"id": id})
	resolve_flow()
