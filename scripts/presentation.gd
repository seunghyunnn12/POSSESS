extends Node3D
## Reads authority state. Camera, art, animation, sound and transient VFX only.
const Arena = preload("res://scripts/arena.gd")
const Authority = preload("res://scripts/authority.gd")
const Sound = preload("res://scripts/sound.gd")
const Visuals = preload("res://scripts/visuals.gd")
const UiText = preload("res://scripts/ui_text.gd")
var authority
var camera: Camera3D
var hands: Node3D
var soul_hands: Node3D
var rifle: Node3D
var hammer: Node3D
var shotgun: Node3D
var bow: Node3D
var staff: Node3D
var spell_orb: MeshInstance3D
var projectile_visuals: Dictionary = {}
var skin: StandardMaterial3D
var shader: ShaderMaterial
var sound
var hit_marker := 0.0
var pulse := 0.0
var pain := 0.0
var recoil := 0.0
var shake := 0.0
var swing := 0.0
var clock := 0.0
var displayed_soul := 1.0
var random := RandomNumberGenerator.new()
var fragments: Dictionary = {}
var fx_tweens: Array[Tween] = []
var fx_paused: Array[Tween] = []
var transient_root: Node3D
var impact_tweens: Dictionary = {}
var reaction_left: Dictionary = {}
var flash_left: Dictionary = {}
var actor_meshes: Dictionary = {}
var particles: Array[GPUParticles3D] = []
var camera_kick := Vector3.ZERO
var weapon_tween: Tween
var weapon_paused := false
var particle_texture: GradientTexture2D
var weapon_offset := Vector3.ZERO
var weapon_rotation := Vector3.ZERO
var previous_room := -1
var step_clock := 0.0
var white_flash: StandardMaterial3D


func setup(simulation, cam: Camera3D) -> void:
	authority = simulation
	camera = cam
	random.randomize()
	sound = Sound.new()
	add_child(sound)
	authority.feedback.connect(on_feedback)
	transient_root = Node3D.new()
	transient_root.name = "TransientEffects"
	add_child(transient_root)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var filter := ColorRect.new()
	filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader = ShaderMaterial.new()
	shader.shader = preload("res://shaders/perception.gdshader")
	filter.material = shader
	layer.add_child(filter)
	white_flash = Arena.material(Color.WHITE, 1.0)
	white_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	build_hands()

func build_hands() -> void:
	hands = Node3D.new()
	camera.add_child(hands)
	skin = Arena.material(Color("b6ac90"))
	var glow := Arena.material(Color(0.35, 0.95, 0.85, 0.46), 1.3)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soul_hands = Node3D.new()
	hands.add_child(soul_hands)
	for side in [-1.0, 1.0]:
		var palm := Arena.sphere(soul_hands, 0.10, Vector3(side * 0.34, -0.28, -0.53), glow)
		palm.scale = Vector3(0.8, 0.7, 1.5)
		for finger in 3:
			var digit := Arena.sphere(soul_hands, 0.035, Vector3(side * (0.27 + finger * 0.065), -0.26, -0.68), glow)
			digit.scale.z = 2.3
	rifle = prop("soldier", Vector3(0.28, -0.28, -0.52), 0.52)
	shotgun = prop("shotgun", Vector3(0.29, -0.29, -0.55), 0.56)
	hammer = prop("brute", Vector3(0.53, -0.45, -0.87), 0.52)
	bow = prop("archer", Vector3(0.24, -0.27, -0.55), 0.54)
	staff = prop("mage", Vector3(0.51, -0.48, -0.86), 0.52)
	spell_orb = Arena.sphere(staff, 0.055, Vector3(0.51, 0.30, -0.86), Arena.material(Color("ff602f"), 0.7))

func prop(role: String, at: Vector3, size: float) -> Node3D:
	var holder := Node3D.new()
	hands.add_child(holder)
	var model = load(Visuals.PROPS[role]).instantiate()
	holder.add_child(model)
	model.position = at
	model.rotation.y = PI
	model.scale = Vector3.ONE * size
	return holder

func _process(dt: float) -> void:
	if authority == null:
		return
	var frozen: bool = authority.is_frozen()
	# Corpses can remain in the previous room while the player crosses a door.
	var animated_actors: Array = authority.world.enemies if authority.get("fun_mode") == true else authority.actors
	for actor in animated_actors:
		if not actor.visible: continue
		if actor.animation != null:
			var distant: bool = actor.alive and actor.global_position.distance_squared_to(camera.global_position) > 144.0
			actor.animation.speed_scale = 0.0 if authority.animation_frozen() or distant else (1.3 if actor.has_meta("fodder") and actor.animation_state == "walk" else 1.0)
	for i in range(fx_tweens.size() - 1, -1, -1):
		var tween := fx_tweens[i]
		if not tween.is_valid():
			fx_tweens.remove_at(i)
			fx_paused.erase(tween)
		elif frozen and tween.is_running():
			tween.pause()
			fx_paused.append(tween)
		elif not frozen and fx_paused.has(tween):
			fx_paused.erase(tween)
			tween.play()
	for i in range(particles.size() - 1, -1, -1):
		if not is_instance_valid(particles[i]): particles.remove_at(i)
		else: particles[i].speed_scale = 0.0 if frozen else 1.0
	if weapon_tween != null and weapon_tween.is_valid():
		if frozen and weapon_tween.is_running():
			weapon_tween.pause()
			weapon_paused = true
		elif not frozen and weapon_paused:
			weapon_tween.play()
			weapon_paused = false
	sound.crowd(0 if frozen or not authority.running else nearby_fodder())
	if frozen:
		return
	clock += dt
	camera_kick = camera_kick.move_toward(Vector3.ZERO, dt * 1.1)
	if authority.running and authority.get("room_index") != null:
		var room: int = authority.room_index
		if previous_room != -1 and room != previous_room: sound.play("door", -5)
		previous_room = room
	step_clock -= dt
	if step_clock <= 0 and authority.running:
		var closest = nearest_fodder()
		if closest != null:
			sound.step(closest.global_position, camera.global_position)
			step_clock = 0.26 if nearby_fodder() > 5 else 0.48
	for id in reaction_left.keys():
		reaction_left[id] -= dt
		if reaction_left[id] <= 0: reaction_left.erase(id)
	for id in flash_left.keys():
		flash_left[id] -= dt
		if flash_left[id] <= 0:
			for mesh in actor_meshes.get(id, []):
				if is_instance_valid(mesh): mesh.material_overlay = null
			flash_left.erase(id)
	if authority.get("projectiles") != null:
		var ids: Dictionary = {}
		for p in authority.projectiles:
			ids[p.id] = true
			if not projectile_visuals.has(p.id):
				if not p.friendly: sound.play({"fire":"fire", "ice":"arrow", "shock":"storm"}.get(p.element, "shot"), -10)
				var color := Color("82e2c3") if p.element == "soul" else (Color("78dfff") if p.element == "ice" else (Color("ff8660") if p.element == "fire" else Color("c6a0ff")))
				if authority.get("fun_mode") == true and not p.friendly: color = Color("ff5848")
				projectile_visuals[p.id] = Arena.box(self, Vector3(0.03, 0.03, 0.65), p.at, Arena.material(color, 0.6)) if p.element == "ice" else Arena.sphere(self, maxf(0.16, p.get("radius", 0.0)), p.at, Arena.material(color, 0.6))
				if p.element == "fire":
					var trail := emit_particles(p.at, color, "smoke", 12, 0.35)
					trail.reparent(projectile_visuals[p.id])
					trail.position = Vector3.ZERO
					trail.one_shot = false
					trail.explosiveness = 0.0
			projectile_visuals[p.id].position = p.at
			if p.element == "soul":
				# Emerge from the hands before reaching full size; don't cover the aim.
				projectile_visuals[p.id].scale = Vector3.ONE * clampf((4.0 - p.life) / 0.18, 0.08, 1.0)
			if p.element == "ice":
				projectile_visuals[p.id].look_at(p.at + p.velocity, Vector3.RIGHT if absf(p.velocity.normalized().y) > 0.98 else Vector3.UP)
		for id in projectile_visuals.keys():
			if not ids.has(id):
				projectile_visuals[id].queue_free()
				projectile_visuals.erase(id)
	hands.visible = authority.state != Authority.State.Possessing and ((authority.running and authority.outcome == "") or authority.get("fun_mode") != true)
	if authority.state == Authority.State.Possessing:
		pulse = maxf(pulse, 0.75)
	pulse = move_toward(pulse, 0.0, dt * 2.6)
	pain = move_toward(pain, 0.0, dt * 2.0)
	recoil = move_toward(recoil, 0.0, dt * 0.65)
	shake = move_toward(shake, 0.0, dt * 1.0)
	swing = move_toward(swing, 0.0, dt * 2.4)
	hit_marker = maxf(0.0, hit_marker - dt)
	var is_body: bool = authority.state == Authority.State.Body
	var rot: float = 1.0 - authority.decay / authority.decay_max if is_body else 0.0
	displayed_soul = move_toward(displayed_soul, 0.0 if is_body else 1.0, dt * 4.0)
	shader.set_shader_parameter("soul", 0.0 if authority.get("fun_mode") == true else displayed_soul)
	shader.set_shader_parameter("rot", rot)
	shader.set_shader_parameter("pulse", pulse)
	shader.set_shader_parameter("pain", pain)
	shader.set_shader_parameter("clock", clock)
	camera.position = authority.eye()
	camera.rotation = Vector3(authority.pitch + recoil * 0.25, authority.yaw, sin(clock * 35.0) * shake * 0.03) + camera_kick
	camera.position += Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), 0) * shake * 0.035
	camera.fov = lerpf(camera.fov, 82.0 + pulse * 22.0 + (3.0 if not is_body else 0.0), minf(dt * 16.0, 1.0))
	var moving: float = Vector2(authority.player.velocity.x, authority.player.velocity.z).length()
	hands.position = Vector3(sin(clock * 8.0) * moving * 0.0015, -0.07 + sin(clock * 16.0) * moving * 0.0012, -0.24 + recoil * 0.35)
	hands.position += weapon_offset
	hands.rotation = weapon_rotation
	hands.rotation.z += -sin(swing * PI) * 0.95
	hands.rotation.x += -sin(swing * PI) * 0.6
	if authority.reload_left > 0.0:
		var reload_time: float = authority.current_stats().reload
		hands.rotation.z = -0.5 * sin(authority.reload_left / reload_time * PI)
		hands.position.y -= 0.22 * sin(authority.reload_left / reload_time * PI)
	soul_hands.visible = not is_body
	rifle.visible = is_body and authority.body_kind == "soldier"
	hammer.visible = is_body and authority.body_kind == "brute"
	shotgun.visible = is_body and authority.body_kind == "shotgun"
	bow.visible = is_body and authority.body_kind == "archer"
	staff.visible = is_body and authority.body_kind in ["mage", "storm"]
	if bow.visible:
		bow.position.z = authority.get("bow_charge") * 0.12
	if staff.visible:
		spell_orb.material_override.albedo_color = Color("ff8660") if authority.body_kind == "mage" else Color("c6a0ff")
		spell_orb.material_override.emission = spell_orb.material_override.albedo_color
	skin.albedo_color = Color("b6ac90").lerp(Color("624569"), rot)
	var aimed = authority.aimed_actor()
	for actor in authority.actors:
		if not actor.alive or actor.claimed:
			continue
		if actor.has_meta("fodder"):
			actor.label.hide()
			animate(actor)
			continue
		if actor.has_meta("price"):
			actor.label.text = "보존된 " + UiText.data(preload("res://scripts/weapons.gd").info(actor.kind).name) + "
뼈 동전 %d" % actor.get_meta("price")
			actor.label.font_size = 20
			actor.label.modulate = Color("84ffd4") if authority.get("coins") >= actor.get_meta("price") else Color("ff9c68")
			actor.label.visible = authority.running and not authority.is_frozen() and aimed == actor
			animate(actor)
			continue
		actor.flash = maxf(0.0, actor.flash - dt)
		var probability: float = authority.capture_chance(actor)
		actor.label.text = tr("TARGET") % (probability * 100)
		if authority.get("action_mode") == true:
			actor.label.text = UiText.data(actor.profile.name if actor.profile.get("boss", false) else preload("res://scripts/weapons.gd").info(actor.kind).name) + "\n" + tr("TARGET") % (probability * 100)
			if actor.burn_left > 0: actor.label.text += " · " + tr("TARGET_STATUS_FIRE")
			if actor.frost_left > 0: actor.label.text += " · " + tr("TARGET_STATUS_ICE")
		actor.label.font_size = 30 if actor.profile.special else 42
		actor.label.no_depth_test = is_body and authority.body_profile.get("id", "") == "seer" and actor.position.distance_to(authority.player.position) < 12.0
		actor.label.visible = authority.running and not authority.is_frozen() and (aimed == actor or actor.label.no_depth_test)
		var ready_color: Color = actor.profile.color if actor.profile.special else (Color("84ffd4") if probability > 0.5 else Color("e4e6dd"))
		actor.label.modulate = Color("ff9c68") if actor.windup > 0.0 else ready_color
		actor.visual.scale = Vector3.ONE * (1.045 if actor.flash > 0.0 else 1.0)
		animate(actor)
	for orb in fragments.values():
		if is_instance_valid(orb):
			orb.rotation.y += dt * 1.5

func animate(actor) -> void:
	if actor.animation == null or reaction_left.has(actor.get_instance_id()):
		return
	var desired := "attack" if actor.windup > 0.0 else ("walk" if actor.velocity.length() > 0.4 else "idle")
	if actor.animation_state == desired:
		return
	actor.animation_state = desired
	var chosen: String = (Visuals.MINION if actor.has_meta("fodder") else Visuals.host(actor.kind))[desired]
	if actor.animation.has_animation(chosen):
		var animation: Animation = actor.animation.get_animation(chosen)
		animation.loop_mode = Animation.LOOP_LINEAR if desired != "attack" else Animation.LOOP_NONE
		actor.animation.play(chosen, 0.15)

func on_feedback(event: String, data: Dictionary) -> void:
	match event:
		"travel":
			sound.play("door", -5)
		"combat_start":
			if authority.get("fun_mode") != true and authority.get("room_index") in [3, 7]: sound.play("bell", -3)
		"room_clear":
			if authority.get("fun_mode") != true and authority.get("room_index") in [3, 7]: sound.play("bell", -8)
		"load_room":
			clear_effects()
		"sealed":
			sound.play("bell", -2)
			shake = maxf(shake, 0.18)
		"unsealed":
			sound.play("bell", -9)
			sound.play("clear", -6)
		"key_found":
			sound.play("loaded", 2)
			pulse = maxf(pulse, 0.25)
		"door_unlocked":
			sound.play("door", -2)
		"door_needs_key", "too_poor":
			sound.play("rejected", -6)
		"purchase":
			sound.play("clear", -4)
		"potion", "blessing":
			sound.play("inhabit", -2)
			pulse = maxf(pulse, 0.3)
		"secret_found":
			sound.play("clear", -2)
			sound.play("loaded", 0)
		"wall_broken":
			sound.play("eject", 2)
			shake = maxf(shake, 0.8)
		"need_body":
			sound.play("rejected", -6)
		"tracer":
			if data.color.b > 0.8 and data.color.r > 0.5:
				var midpoint: Vector3 = data.from.lerp(data.to, 0.5) + Vector3(random.randf_range(-0.2, 0.2), 0.12, 0)
				beam(data.from, midpoint, data.color, 0.09)
				beam(midpoint, data.to, data.color, 0.09)
				emit_particles(data.to, data.color, "spark", 5, 0.15)
			else: beam(data.from, data.to, data.color, 0.09)
		"weapon_fire":
			weapon_reaction()
			muzzle(Color("ffb86e") if data.role not in ["mage", "storm"] else Color("c6a0ff"))
			recoil = 0.48 if data.role == "shotgun" else 0.2
			shake = 0.25 if data.role == "shotgun" else 0.06
			hit_marker = 0.16 if data.hit else 0
			sound.play({"shotgun": "shotgun", "archer": "arrow", "mage": "fire", "storm": "storm"}.get(data.role, "rifle"))
		"element_burst":
			emit_particles(data.at, data.color, "spark", 16, 0.4)
			sound.play("fire", -7)
			burst(data.at, data.color, 1.1)
		"dash":
			pulse = 0.2
			sound.play("swing", -4)
		"fallen":
			var actor = data.actor
			stop_impact(actor)
			reaction_left.erase(actor.get_instance_id())
			actor.label.hide()
			actor.show()
			var duration := reaction(actor, Visuals.DEATH_CLIPS)
			var tween := create_tween()
			fx_tweens.append(tween)
			if duration <= 0:
				tween.tween_property(actor.visual, "rotation:x", -PI * 0.48, 0.28)
			else: tween.tween_interval(duration)
			tween.tween_interval(1.5)
			tween.tween_method(func(value: float):
				for mesh in meshes(actor): mesh.transparency = value, 0.0, 1.0, 0.45)
			tween.tween_callback(actor.hide)
			if actor.has_meta("fodder"): emit_particles(actor.position + Vector3.UP * 0.65, Color("b8b0a0"), "bone", 9, 0.7)
		"impact":
			var actor = data.actor
			stop_impact(actor)
			reaction_left[actor.get_instance_id()] = reaction(actor, Visuals.HIT_CLIPS)
			flash_left[actor.get_instance_id()] = 0.08
			for mesh in meshes(actor): mesh.material_overlay = white_flash
			var away: Vector3 = actor.global_position - camera.global_position
			away.y = 0
			actor.visual.position = actor.global_basis.inverse() * away.normalized() * 0.15
			var tween := create_tween()
			fx_tweens.append(tween)
			impact_tweens[actor.get_instance_id()] = tween
			tween.tween_property(actor.visual, "position", Vector3.ZERO, 0.15)
			tween.tween_callback(func(): impact_tweens.erase(actor.get_instance_id()))
			if actor.frost_left > 0: emit_particles(actor.position + Vector3.UP, Color("8ce5ff"), "spark", 10, 0.3)
		"milestone":
			pulse = 0.35
			sound.play("clear", -3)
		"boss_warning":
			sound.play("rejected", -4)
		"shot":
			weapon_reaction()
			muzzle(Color("82e2c3") if data.soul else Color("ffb86e"))
			recoil = authority.current_stats().recoil
			beam(data.from + Vector3(0, -0.12, 0), data.to, Color("92ffe4") if data.soul else Color("ffd494"), 0.08)
			sound.play("shot" if data.soul else "rifle")
			if data.hit:
				hit_marker = 0.16
		"hit":
			emit_particles(data.at, Color("ffc58b"), "spark", 8, 0.22)
			burst(data.at, Color("ffac70") if data.dead else Color("9bf7d4"), 0.5 if data.dead else 0.16)
			sound.play("kill" if data.dead else "hit", -6)
		"possess":
			pulse = 1.0
			burst(data.at + Vector3.UP, Color("81ffcc"), 1.0)
			sound.play("possess", 2)
		"inhabit":
			emit_particles(camera.global_position + camera.global_basis.z * -1.6, Color("82ffe0"), "inward", 28, 0.38)
			pulse = 0.65
			shake = 0.4
			sound.play("inhabit", 2)
		"rejected":
			pain = 0.5
			shake = 0.65
			sound.play("rejected")
		"eject":
			emit_particles(data.at + Vector3.UP, Color("b7d4cf"), "smoke", 20, 0.7)
			ring(data.at + Vector3.UP * 0.15)
			pulse = 0.7
			shake = 0.7 if data.explode else 0.25
			burst(data.at, Color("bf8fd7") if data.explode else Color("7cffd3"), 3.0 if data.explode else 0.8)
			sound.play("eject" if data.explode else "possess")
		"swing":
			weapon_reaction()
			if data.hit: sound.play("melee", -2)
			swing = 1.0
			shake = 0.4
			hit_marker = 0.2 if data.hit else 0.0
			sound.play("swing")
		"damage_detail":
			var direction: Vector3 = camera.global_basis.inverse() * (data.from - camera.global_position).normalized()
			camera_kick = Vector3(-0.045, direction.x * 0.025, -direction.x * 0.08)
		"soul_focus":
			pulse = 1.0
			shake = 0.6
		"hurt":
			pain = 1.0
			shake = 0.4
			sound.play("hurt")
		"enemy_shot":
			beam(data.from, data.to, Color("ff765b"), 0.12)
			sound.play("rifle", -10)
		"slam":
			sound.play("melee", -7)
			emit_particles(data.at, Color("ffc58b"), "spark", 12, 0.25)
			burst(data.at, Color("ff9b66"), 0.7)
		"reload", "loaded":
			sound.play(event)
		"exposed":
			if data.reason == "seer":
				sound.play("rejected")
		"detection":
			sound.play("loaded", -4)
		"supply":
			sound.play("inhabit", -3)
		"fragment":
			var orb := Arena.box(self, Vector3.ONE * 0.18, data.position, Arena.material(Color("a8a1ff"), 2.0))
			orb.rotation.z = PI * 0.25
			fragments[data.id] = orb
		"collected":
			if fragments.has(data.id):
				fragments[data.id].queue_free()
				fragments.erase(data.id)
			sound.play("loaded", -8)
		"upgrade_offer":
			sound.play("clear", -3)
		"upgrade_chosen":
			sound.play("inhabit", -3)
		"end":
			sound.play("clear" if data.result == "CLEAR" else "dead", 1)

func stop_impact(actor) -> void:
	var id: int = actor.get_instance_id()
	if impact_tweens.has(id):
		impact_tweens[id].kill()
		impact_tweens.erase(id)
	actor.visual.rotation.z = 0.0
	actor.visual.position = Vector3.ZERO

func clear_effects() -> void:
	for tween in fx_tweens:
		if tween.is_valid(): tween.kill()
	fx_tweens.clear()
	fx_paused.clear()
	impact_tweens.clear()
	reaction_left.clear()
	flash_left.clear()
	for cached in actor_meshes.values():
		for mesh in cached:
			if is_instance_valid(mesh): mesh.material_overlay = null
	actor_meshes.clear()
	particles.clear()
	previous_room = -1
	if weapon_tween != null and weapon_tween.is_valid(): weapon_tween.kill()
	weapon_offset = Vector3.ZERO
	weapon_rotation = Vector3.ZERO
	for effect in transient_root.get_children():
		effect.queue_free()
	for collection in [fragments, projectile_visuals]:
		for effect in collection.values():
			if is_instance_valid(effect): effect.queue_free()
		collection.clear()
	hit_marker = 0.0
	pain = 0.0
	shake = 0.0
	recoil = 0.0
	swing = 0.0

func beam(from: Vector3, to: Vector3, color: Color, lifetime: float) -> void:
	var distance := from.distance_to(to)
	if distance < 0.01:
		return
	var line := Arena.box(transient_root, Vector3(0.022, 0.022, distance), (from + to) * 0.5, Arena.material(color, 2))
	line.look_at(to, Vector3.RIGHT if absf((to - from).normalized().y) > 0.98 else Vector3.UP)
	var tween := create_tween()
	fx_tweens.append(tween)
	tween.tween_property(line, "scale", Vector3(0.01, 0.01, 1), lifetime)
	tween.tween_callback(line.queue_free)

func burst(pos: Vector3, color: Color, size: float) -> void:
	var mat := Arena.material(color, 1.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var orb := Arena.sphere(transient_root, 0.1, pos, mat)
	var tween := create_tween().set_parallel(true)
	fx_tweens.append(tween)
	tween.tween_property(orb, "scale", Vector3.ONE * size * 10.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tween.chain().tween_callback(orb.queue_free)

func meshes(actor) -> Array:
	var id: int = actor.get_instance_id()
	if not actor_meshes.has(id):
		var result: Array = []
		collect_meshes(actor.visual, result)
		actor_meshes[id] = result
	return actor_meshes[id]

func collect_meshes(node: Node, result: Array) -> void:
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): collect_meshes(child, result)

func reaction(actor, clips: Array) -> float:
	if actor.animation == null: return 0.0
	var clip: String = clips[random.randi_range(0, clips.size() - 1)]
	if not actor.animation.has_animation(clip): return 0.0
	actor.animation_state = "reaction"
	actor.animation.active = true
	actor.animation.speed_scale = 1.0
	actor.animation.get_animation(clip).loop_mode = Animation.LOOP_NONE
	actor.animation.play(clip, 0.1)
	return actor.animation.get_animation(clip).length

func nearby_fodder() -> int:
	var count := 0
	for actor in authority.actors:
		if actor.alive and not actor.claimed and actor.has_meta("fodder") and actor.global_position.distance_squared_to(camera.global_position) < 144: count += 1
	return count

func nearest_fodder():
	var result = null
	var distance := 100.0
	for actor in authority.actors:
		if not actor.alive or not actor.has_meta("fodder") or actor.velocity.length_squared() < 0.1: continue
		var candidate: float = actor.global_position.distance_squared_to(camera.global_position)
		if candidate < distance:
			distance = candidate
			result = actor
	return result

func weapon_reaction() -> void:
	if weapon_tween != null and weapon_tween.is_valid(): weapon_tween.kill()
	weapon_paused = false
	weapon_offset = Vector3(0.012, 0.018, 0.085)
	weapon_rotation = Vector3(0.07, 0.015, -0.025)
	weapon_tween = create_tween().set_parallel(true)
	weapon_tween.tween_property(self, "weapon_offset", Vector3.ZERO, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	weapon_tween.tween_property(self, "weapon_rotation", Vector3.ZERO, 0.1)

func emit_particles(at: Vector3, color: Color, kind: String, count: int, duration: float) -> GPUParticles3D:
	var effect := GPUParticles3D.new()
	transient_root.add_child(effect)
	effect.global_position = at
	effect.amount = count
	effect.lifetime = duration
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.local_coords = false
	effect.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180
	process.initial_velocity_min = 1.5
	process.initial_velocity_max = 4.0
	process.gravity = Vector3(0, -5, 0)
	process.angular_velocity_min = -180
	process.angular_velocity_max = 180
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 1.0))
	gradient.set_color(1, Color(color, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	var mesh: Mesh
	if kind == "bone":
		var bone := BoxMesh.new()
		bone.size = Vector3(0.045, 0.15, 0.05)
		mesh = bone
	else:
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * (0.35 if kind == "smoke" else 0.065)
		mesh = quad
		if kind == "smoke":
			process.gravity = Vector3(0, 0.5, 0)
			process.initial_velocity_min = 0.1
			process.initial_velocity_max = 0.6
			process.scale_min = 0.4
			process.scale_max = 1.4
		if kind == "inward":
			process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
			process.emission_sphere_radius = 1.3
			process.initial_velocity_min = 0
			process.initial_velocity_max = 0
			process.gravity = Vector3.ZERO
			process.radial_velocity_min = -3.5
			process.radial_velocity_max = -3.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	if kind != "bone":
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		if particle_texture == null:
			particle_texture = GradientTexture2D.new()
			particle_texture.width = 32
			particle_texture.height = 32
			particle_texture.fill = GradientTexture2D.FILL_RADIAL
			particle_texture.fill_from = Vector2(0.5, 0.5)
			particle_texture.fill_to = Vector2(1.0, 0.5)
			particle_texture.gradient = Gradient.new()
			particle_texture.gradient.set_color(0, Color.WHITE)
			particle_texture.gradient.set_color(1, Color(1, 1, 1, 0))
		material.albedo_texture = particle_texture
	mesh.material = material
	effect.draw_pass_1 = mesh
	effect.process_material = process
	particles.append(effect)
	effect.emitting = true
	var tween := create_tween()
	fx_tweens.append(tween)
	tween.tween_interval(duration + 0.15)
	var effect_ref: WeakRef = weakref(effect)
	tween.tween_callback(func():
		var remaining = effect_ref.get_ref()
		if remaining != null and remaining.one_shot: remaining.queue_free())
	return effect

func muzzle(color: Color) -> void:
	var at: Vector3 = camera.global_position + camera.global_basis * Vector3(0.22, -0.23, -1.15)
	emit_particles(at, color, "spark", 5, 0.09)
	var light := OmniLight3D.new()
	transient_root.add_child(light)
	light.global_position = at
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 3.0
	light.shadow_enabled = false
	get_tree().process_frame.connect(light.queue_free, CONNECT_ONE_SHOT)

func ring(at: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.0
	mesh.rings = 20
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	transient_root.add_child(node)
	node.position = at
	var material := Arena.material(Color("8be5cd"), 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	node.scale = Vector3.ONE * 0.1
	var tween := create_tween().set_parallel(true)
	fx_tweens.append(tween)
	tween.tween_property(node, "scale", Vector3(2.5, 0.3, 2.5), 0.4)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(node.queue_free)
