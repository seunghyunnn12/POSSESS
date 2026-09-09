extends "res://scripts/campaign.gd"
const Weapons = preload("res://scripts/weapons.gd")
var action_mode := true
var projectiles: Array[Dictionary] = []
var projectile_serial := 0
var dash_left := 0.0
var dash_cooldown := 0.0
var dash_direction := Vector3.ZERO
var focus_left := 0.0
var bow_charge := 0.0
var heat := 0.0
var shot_index := 0
var reward_picked := false
var carried: Dictionary = {}
var status_damage := false
var boss_pattern := 0

func _ready() -> void:
	super._ready()
	queued.dash = false
	for i in range(1, plans.size()):
		if plans[i].boss == "":
			plans[i].layout = ["gallery", "crossroads", "terraces"][int(plans[i].seed) % 3]
			room_names[i] = "%d / 7 · %s" % [i, {"gallery": "세 갈래 회랑", "crossroads": "봉인된 교차로", "terraces": "상층 회랑"}[plans[i].layout]]

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func gain_xp(amount: int) -> void:
	super.gain_xp(amount)
	upgrade_wait = 0.0

func resolve_flow() -> void:
	if phase == "combat":
		if clear_pending and state in [State.Soul, State.Body] and settle_left <= 0:
			finish("CLEAR")
		return
	if phase == "rest" and pending_levels > 0:
		var keep := 0 if reward_picked else 1
		essence += maxi(0, pending_levels - keep)
		pending_levels = mini(keep, pending_levels)
	super.resolve_flow()

func finish(result: String) -> void:
	var was_combat := phase == "combat"
	super.finish(result)
	if result == "CLEAR" and was_combat:
		projectiles.clear()
		resolve_flow()
	if outcome != "":
		focus_left = 0
		Engine.time_scale = 1

func choose_upgrade(index: int) -> void:
	var valid := is_multiplayer_authority() and outcome == "" and not paused and not journal_open and index >= 0 and index < upgrade_choices.size()
	if valid:
		reward_picked = true
	super.choose_upgrade(index)

func select_route(index: int) -> void:
	if not route_pending(): return
	var layout: String = plans[room_index + 1].layout
	super.select_route(index)
	plans[room_index + 1].layout = layout

func can_leave_room() -> bool:
	if not running or is_frozen() or outcome != "" or not (phase == "rest" or (phase == "training" and lesson == 7)):
		return false
	var delta := Vector3(0, 1.4, -19) - eye()
	return delta.length() < 3.2 and forward().dot(delta.normalized()) > 0.6 and ray(eye(), Vector3(0, 1.4, -19), 1).is_empty()

func leave_room() -> void:
	if can_leave_room() and route_pending():
		select_route(0)
	super.leave_room()

func begin_travel() -> void:
	carried = {"kind": body_kind, "profile": body_profile.duplicate(true), "decay": decay, "max": decay_max, "ammo": ammo, "state": state}
	projectiles.clear()
	focus_left = 0
	Engine.time_scale = 1
	super.begin_travel()

func room_arrived() -> void:
	super.room_arrived()
	if room_layout() == "terraces" and secret_position.z <= -5:
		secret_position.y = 1.9
	reward_picked = false
	boss_pattern = 0
	if not carried.is_empty() and carried.state == State.Body:
		state = State.Body
		body_kind = carried.kind
		body_profile = carried.profile
		decay = carried.decay
		decay_max = carried.max
		ammo = carried.ammo
		disguised = true
	for actor in actors:
		if actor.profile.get("boss", false):
			actor.profile.health *= 0.75
			actor.attributes = Traits.stats(actor.kind, actor.profile)
			actor.max_hp = actor.attributes.host_health
			actor.hp = actor.max_hp

func encounter_spec() -> Dictionary:
	var spec := super.encounter_spec()
	spec.varied = true
	if room_layout() == "terraces" and spec.hidden_at.z <= -5:
		spec.hidden_at.y = 1.9
	return spec

func _physics_process(dt: float) -> void:
	if not is_multiplayer_authority() or is_frozen_except_briefing() or not running or outcome != "":
		return
	if phase == "briefing" and room_index > 1:
		confirm_ready()
		announce(room_names[room_index] + " · " + ("현재 몸 유지" if state == State.Body else "유령으로 진입"))
		return
	if phase == "training" and lesson in [3, 4, 5, 6]:
		advance_lesson(7)
	if phase in ["combat", "training", "rest"] and settle_left <= 0 and state in [State.Soul, State.Body]:
		focus_left = maxf(0, focus_left - dt / maxf(Engine.time_scale, 0.01))
		Engine.time_scale = 0.25 if focus_left > 0 and state == State.Soul else 1.0
		dash_cooldown = maxf(0, dash_cooldown - dt)
		heat = maxf(0, heat - dt * 1.8)
		if state == State.Body and body_kind == "archer":
			if intent.fire:
				bow_charge = minf(1, bow_charge + dt / 0.75)
			elif bow_charge > 0:
				fire_arrow()
		tick_projectiles(dt)
		for actor in actors:
			if actor.alive and not actor.claimed:
				actor.frost_left = maxf(0, actor.frost_left - dt)
				actor.stagger_left = maxf(0, actor.stagger_left - dt)
				if actor.burn_left > 0:
					actor.burn_left = maxf(0, actor.burn_left - dt)
					actor.burn_clock -= dt
					if actor.burn_clock <= 0:
						actor.burn_clock = 0.5
						status_damage = true
						damage_enemy(actor, 4)
						status_damage = false
	var was_reload := reload_left > 0
	super._physics_process(dt)
	if was_reload and reload_left <= 0 and state == State.Body:
		ammo = Weapons.info(body_kind).magazine

func move_player(dt: float) -> void:
	if queued.get("dash", false) and dash_cooldown <= 0:
		dash_direction = Basis(Vector3.UP, yaw) * Vector3(intent.move.x, 0, intent.move.y)
		if dash_direction.length() < 0.1:
			dash_direction = Basis(Vector3.UP, yaw) * Vector3.FORWARD
		dash_direction = dash_direction.normalized()
		dash_left = 0.18
		dash_cooldown = 1.8
		invulnerable = maxf(invulnerable, 0.18)
		feedback.emit("dash", {})
	if dash_left > 0:
		dash_left = maxf(0, dash_left - dt)
		player.velocity = dash_direction * 19
		player.move_and_slide()
		return
	super.move_player(dt)

func current_stats() -> Dictionary:
	var stats := super.current_stats()
	if state == State.Soul and focus_left > 0:
		stats.move *= 2.5
	return stats

func eject(explode: bool) -> void:
	var had_body := state == State.Body
	super.eject(explode)
	if had_body and state == State.Ejecting and phase == "combat":
		focus_left = 3.0
		feedback.emit("soul_focus", {})
	bow_charge = 0

func begin_possession(candidate) -> void:
	super.begin_possession(candidate)
	if state == State.Possessing:
		focus_left = 0
		Engine.time_scale = 1
		projectiles = projectiles.filter(func(p): return p.get("source") != candidate)

func finish_possession() -> void:
	super.finish_possession()
	if state == State.Body:
		ammo = Weapons.info(body_kind).magazine
		bow_charge = 0
		heat = 0

func begin_reload() -> void:
	if state == State.Body and Weapons.info(body_kind).magazine > 0 and ammo < Weapons.info(body_kind).magazine and reload_left <= 0:
		reload_left = current_stats().reload
		feedback.emit("reload", {})

func attack() -> void:
	if phase == "training" and lesson == 0:
		advance_lesson(1)
	if phase == "training" and lesson not in [1, 5]:
		return
	if not is_multiplayer_authority() or is_frozen() or phase == "rest" or outcome != "" or state not in [State.Soul, State.Body] or shot_left > 0 or reload_left > 0 or settle_left > 0:
		return
	if state == State.Soul or body_kind == "brute":
		super.attack()
		return
	if body_kind == "archer":
		if bow_charge >= 1:
			fire_arrow()
		return
	var weapon := Weapons.info(body_kind)
	if weapon.magazine > 0 and ammo <= 0:
		begin_reload()
		return
	var opening_damage := 1 + 0.6 * rank_of("ambush") if disguised else 1.0
	expose("attack")
	var stats := current_stats()
	shot_left = stats.interval
	if weapon.magazine > 0:
		ammo -= 1
	var connected := false
	if body_kind == "mage":
		launch(eye(), forward() * 18, stats.damage * opening_damage, "fire", true)
	elif body_kind == "storm":
		var hit := ray(eye(), eye() + forward() * 32)
		if not hit.is_empty() and hit.collider is Actor:
			element_hit(hit.collider, stats.damage * opening_damage, "shock")
			connected = true
		feedback.emit("tracer", {"from": eye(), "to": hit.get("position", eye() + forward() * 32), "color": weapon.color})
	else:
		var pellets := 6 if body_kind == "shotgun" else 1
		for i in pellets:
			var spread := 0.078 if pellets > 1 else (0.004 + heat * 0.008)
			var direction := (forward() + Basis(Vector3.UP, yaw) * Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread), 0)).normalized()
			var hit := ray(eye(), eye() + direction * 45)
			if not hit.is_empty() and hit.collider is Actor:
				var falloff := clampf(1 - eye().distance_to(hit.position) / 24, 0.3, 1) if pellets > 1 else 1.0
				damage_enemy(hit.collider, stats.damage * opening_damage * falloff)
				if pellets > 1:
					hit.collider.stagger_left = 0.3
				connected = true
			feedback.emit("tracer", {"from": eye() + Vector3(0, -0.1, 0), "to": hit.get("position", eye() + direction * 45), "color": weapon.color})
		heat = minf(3, heat + 0.4)
		yaw += [-0.002, 0.003, 0.004, -0.003][shot_index % 4]
		pitch = minf(1.38, pitch + (0.026 if pellets > 1 else 0.005))
		shot_index += 1
		feedback.emit("kick", {})
	feedback.emit("weapon_fire", {"role": body_kind, "hit": connected})

func fire_arrow() -> void:
	if bow_charge <= 0 or state != State.Body or is_frozen() or shot_left > 0 or phase != "combat":
		bow_charge = 0
		return
	var power := 0.3 + bow_charge * 0.7
	var bonus := 1 + rank_of("ambush") * 0.6 if disguised else 1.0
	expose("attack")
	launch(eye(), forward() * (24 + bow_charge * 20), current_stats().damage * power * bonus, "ice", true)
	bow_charge = 0
	shot_left = current_stats().interval
	feedback.emit("weapon_fire", {"role": "archer", "hit": false})

func launch(at: Vector3, velocity: Vector3, damage: float, element: String, friendly: bool, source = null) -> void:
	if projectiles.size() >= 80:
		return
	projectile_serial += 1
	projectiles.append({"id": projectile_serial, "at": at, "velocity": velocity, "damage": damage, "element": element, "friendly": friendly, "source": source, "life": 4.0})

func tick_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		if i >= projectiles.size():
			continue
		var p: Dictionary = projectiles[i]
		var next: Vector3 = p.at + p.velocity * dt
		var hit := ray(p.at, next, 5 if p.friendly else 3)
		p.life -= dt
		if not hit.is_empty():
			projectiles.remove_at(i)
			if p.friendly and hit.collider is Actor:
				element_hit(hit.collider, p.damage, p.element)
			elif not p.friendly and hit.collider == player:
				hurt(p.damage)
			if p.element == "fire":
				feedback.emit("element_burst", {"at": hit.position, "color": Color("ff8660")})
				if p.friendly:
					for actor in actors:
						if actor != hit.collider and actor.alive and not actor.claimed and actor.position.distance_to(hit.position) < 2.5 and ray(hit.position + Vector3.UP * 0.15, actor.position + Vector3.UP, 1).is_empty():
							element_hit(actor, p.damage * 0.5, "fire")
			continue
		if p.life <= 0:
			projectiles.remove_at(i)
		else:
			p.at = next

func element_hit(actor, amount: float, element: String) -> void:
	if not actor.alive or actor.claimed:
		return
	var thermal: bool = (element == "fire" and actor.frost_left > 0) or (element == "ice" and actor.burn_left > 0)
	if thermal:
		actor.burn_left = 0
		actor.frost_left = 0
		amount += 24
		feedback.emit("element_burst", {"at": actor.position + Vector3.UP, "color": Color("efffff")})
		feedback.emit("element_notice", {"text": "열충격!"})
	elif element == "fire":
		actor.burn_left = 2.0
	elif element == "ice":
		actor.frost_left = 2.5
	damage_enemy(actor, amount)
	if element == "shock":
		var count := 0
		for other in actors:
			if other != actor and other.alive and not other.claimed and other.position.distance_to(actor.position) < 5 and ray(actor.position + Vector3.UP, other.position + Vector3.UP, 1).is_empty():
				damage_enemy(other, amount * 0.45)
				feedback.emit("tracer", {"from": actor.position + Vector3.UP, "to": other.position + Vector3.UP, "color": Color("c6a0ff")})
				count += 1
				if count == 2:
					break

func damage_enemy(actor, amount: float) -> void:
	var alive: bool = actor.alive and not actor.claimed
	super.damage_enemy(actor, amount)
	if alive:
		if not actor.alive:
			actor.show()
			feedback.emit("fallen", {"actor": actor})
		elif not status_damage:
			feedback.emit("impact", {"actor": actor})

func tick_enemy(actor, dt: float) -> void:
	if actor.stagger_left > 0:
		actor.velocity = Vector3.ZERO
		return
	var original_speed: float = actor.attributes.enemy_move
	if actor.frost_left > 0:
		actor.attributes.enemy_move *= 0.45
	if actor.profile.get("boss", false) and boss_clock - dt <= 0:
		boss_pattern += 1
		if boss_pattern % 3 != 0:
			boss_clock = 3.0
			var at: Vector3 = actor.position
			hazards.append({"at": at, "left": 1.25, "radius": 6.0, "damage": 4.0, "kind": "line" if boss_pattern % 3 == 1 else "ring", "end": player.position + (player.position - at).normalized() * 8})
			feedback.emit("boss_warning", {"at": at, "rage": false})
	if actor.kind in ["soldier", "brute"] or actor.profile.get("boss", false) or phase != "combat":
		super.tick_enemy(actor, dt)
	elif state == State.Body and disguised:
		tick_unaware(actor, dt)
	else:
		actor.attack_clock -= dt
		var delta: Vector3 = player.position - actor.position
		delta.y = 0
		if actor.windup > 0:
			actor.windup -= dt
			if actor.windup <= 0:
				var from: Vector3 = actor.position + Vector3.UP * 1.3
				var element: String = Weapons.info(actor.kind).element
				if actor.kind == "shotgun":
					for n in 5:
						var direction: Vector3 = (actor.charge_direction + Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.03, 0.03), 0)).normalized()
						var hit := ray(from, from + direction * 18, 3)
						if not hit.is_empty() and hit.collider == player: hurt(0.7)
						feedback.emit("tracer", {"from": from, "to": hit.get("position", from + direction * 18), "color": Color("ff8160")})
				else:
					launch(from, actor.charge_direction * (22 if actor.kind == "archer" else 10), 3, element, false, actor)
		else:
			var from: Vector3 = actor.position + Vector3.UP * 1.3
			var sight := ray(from, eye(), 3)
			if actor.attack_clock <= 0 and not sight.is_empty() and sight.collider == player:
				actor.windup = 0.8
				actor.charge_direction = (eye() - from).normalized()
				actor.attack_clock = 2.6
		var desired: Vector3 = delta.normalized() * actor.attributes.enemy_move * (1.0 if delta.length() > 10 else (-0.6 if delta.length() < 4 else 0.0))
		actor.velocity = desired + Vector3.DOWN
		actor.move_and_slide()
		actor.rotation.y = atan2(delta.x, delta.z)
	actor.attributes.enemy_move = original_speed

func tick_hazards(dt: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		if not hazard.has("kind"):
			continue
		hazard.left -= dt
		if hazard.left > 0:
			continue
		hazards.remove_at(i)
		var position2 := Vector2(player.position.x, player.position.z)
		var origin := Vector2(hazard.at.x, hazard.at.z)
		var hit := false
		if hazard.kind == "ring":
			hit = absf(position2.distance_to(origin) - hazard.radius) < 1.15 and player.position.y < 0.25
		else:
			var endpoint := Vector2(hazard.end.x, hazard.end.z)
			var nearest := Geometry2D.get_closest_point_to_segment(position2, origin, endpoint)
			hit = position2.distance_to(nearest) < 1.15
		if hit and ray(hazard.at + Vector3.UP, eye(), 1).is_empty(): hurt(hazard.damage)
		feedback.emit("element_burst", {"at": hazard.at + Vector3.UP * 0.2, "color": Color("ff8660")})
	# Let the inherited circular strike resolve, excluding the other shapes.
	var shaped: Array[Dictionary] = hazards.filter(func(h): return h.has("kind"))
	hazards = hazards.filter(func(h): return not h.has("kind"))
	super.tick_hazards(dt)
	hazards.append_array(shaped)
