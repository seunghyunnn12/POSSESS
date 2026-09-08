extends Node3D
## Reads authority state. Camera, art, animation, sound and transient VFX only.
const Arena = preload("res://scripts/arena.gd")
const Authority = preload("res://scripts/authority.gd")
const Sound = preload("res://scripts/sound.gd")
var authority
var camera: Camera3D
var hands: Node3D
var soul_hands: Node3D
var rifle: Node3D
var hammer: Node3D
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
var notice := ""
var notice_left := 0.0
var random := RandomNumberGenerator.new()
var fragments: Dictionary = {}
var fx_tweens: Array[Tween] = []
var fx_paused: Array[Tween] = []

func setup(simulation, cam: Camera3D) -> void:
	authority = simulation
	camera = cam
	random.randomize()
	sound = Sound.new()
	add_child(sound)
	authority.feedback.connect(on_feedback)
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
	build_hands()

func build_hands() -> void:
	hands = Node3D.new()
	camera.add_child(hands)
	skin = Arena.material(Color("b6ac90"))
	var iron := Arena.material(Color("263642"))
	var trim := Arena.material(Color("aa8758"))
	var glow := Arena.material(Color("70f4d4"), 2.0)
	soul_hands = Node3D.new()
	hands.add_child(soul_hands)
	for side in [-1.0, 1.0]:
		var palm := Arena.sphere(soul_hands, 0.10, Vector3(side * 0.34, -0.28, -0.53), glow)
		palm.scale = Vector3(0.8, 0.7, 1.5)
		for finger in 3:
			var digit := Arena.sphere(soul_hands, 0.035, Vector3(side * (0.27 + finger * 0.065), -0.26, -0.68), glow)
			digit.scale.z = 2.3
	rifle = Node3D.new()
	hands.add_child(rifle)
	Arena.box(rifle, Vector3(0.14, 0.16, 0.44), Vector3(0.30, -0.28, -0.43), skin)
	Arena.box(rifle, Vector3(0.13, 0.14, 0.32), Vector3(0.15, -0.31, -0.66), skin).rotation.z = -0.35
	Arena.box(rifle, Vector3(0.17, 0.21, 0.56), Vector3(0.28, -0.20, -0.68), iron)
	Arena.box(rifle, Vector3(0.065, 0.065, 0.48), Vector3(0.28, -0.17, -1.12), trim)
	Arena.box(rifle, Vector3(0.40, 0.045, 0.09), Vector3(0.28, -0.19, -0.94), trim)
	Arena.box(rifle, Vector3(0.075, 0.12, 0.08), Vector3(0.28, -0.07, -0.7), iron)
	Arena.box(rifle, Vector3(0.018, 0.035, 0.018), Vector3(0.28, -0.008, -0.7), glow)
	hammer = Node3D.new()
	hands.add_child(hammer)
	Arena.box(hammer, Vector3(0.17, 0.18, 0.35), Vector3(0.4, -0.32, -0.5), skin)
	Arena.box(hammer, Vector3(0.075, 0.95, 0.075), Vector3(0.43, -0.01, -0.7), trim)
	Arena.box(hammer, Vector3(0.48, 0.25, 0.23), Vector3(0.43, 0.43, -0.7), iron)
	Arena.box(hammer, Vector3(0.51, 0.055, 0.25), Vector3(0.43, 0.43, -0.7), glow)

func _process(dt: float) -> void:
	if authority == null:
		return
	var frozen: bool = authority.is_frozen()
	for actor in authority.actors:
		if actor.animation != null:
			actor.animation.speed_scale = 0.0 if authority.animation_frozen() else 1.0
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
	if frozen:
		return
	clock += dt
	hands.visible = authority.state != Authority.State.Possessing
	if authority.state == Authority.State.Possessing:
		pulse = maxf(pulse, 0.75)
	pulse = move_toward(pulse, 0.0, dt * 2.6)
	pain = move_toward(pain, 0.0, dt * 2.0)
	recoil = move_toward(recoil, 0.0, dt * 0.65)
	shake = move_toward(shake, 0.0, dt * 1.0)
	swing = move_toward(swing, 0.0, dt * 2.4)
	hit_marker = maxf(0.0, hit_marker - dt)
	notice_left = maxf(0.0, notice_left - dt)
	var is_body: bool = authority.state == Authority.State.Body
	var rot: float = 1.0 - authority.decay / authority.decay_max if is_body else 0.0
	displayed_soul = move_toward(displayed_soul, 0.0 if is_body else 1.0, dt * 4.0)
	shader.set_shader_parameter("soul", displayed_soul)
	shader.set_shader_parameter("rot", rot)
	shader.set_shader_parameter("pulse", pulse)
	shader.set_shader_parameter("pain", pain)
	shader.set_shader_parameter("clock", clock)
	camera.position = authority.eye()
	camera.rotation = Vector3(authority.pitch + recoil * 0.25, authority.yaw, sin(clock * 35.0) * shake * 0.03)
	camera.position += Vector3(random.randf_range(-1, 1), random.randf_range(-1, 1), 0) * shake * 0.035
	camera.fov = lerpf(camera.fov, 82.0 + pulse * 22.0 + (3.0 if not is_body else 0.0), minf(dt * 16.0, 1.0))
	var moving: float = Vector2(authority.player.velocity.x, authority.player.velocity.z).length()
	hands.position = Vector3(sin(clock * 8.0) * moving * 0.0015, -0.07 + sin(clock * 16.0) * moving * 0.0012, -0.24 + recoil * 0.35)
	hands.rotation.z = -sin(swing * PI) * 0.95
	hands.rotation.x = -sin(swing * PI) * 0.6
	if authority.reload_left > 0.0:
		var reload_time: float = authority.current_stats().reload
		hands.rotation.z = -0.5 * sin(authority.reload_left / reload_time * PI)
		hands.position.y -= 0.22 * sin(authority.reload_left / reload_time * PI)
	soul_hands.visible = not is_body
	rifle.visible = is_body and authority.body_kind == "soldier"
	hammer.visible = is_body and authority.body_kind == "brute"
	skin.albedo_color = Color("b6ac90").lerp(Color("624569"), rot)
	for actor in authority.actors:
		if not actor.alive or actor.claimed:
			continue
		actor.flash = maxf(0.0, actor.flash - dt)
		var probability: float = authority.capture_chance(actor)
		actor.label.text = (actor.profile.name + "\n" if actor.profile.special else "") + "%.1f%%" % (probability * 100)
		actor.label.font_size = 30 if actor.profile.special else 42
		actor.label.no_depth_test = is_body and authority.body_profile.get("id", "") == "seer" and actor.position.distance_to(authority.player.position) < 12.0
		var ready_color: Color = actor.profile.color if actor.profile.special else (Color("84ffd4") if probability > 0.5 else Color("e4e6dd"))
		actor.label.modulate = Color("ff9c68") if actor.windup > 0.0 else ready_color
		actor.visual.scale = Vector3.ONE * (1.045 if actor.flash > 0.0 else 1.0)
		animate(actor)
	for orb in fragments.values():
		if is_instance_valid(orb):
			orb.rotation.y += dt * 1.5

func animate(actor) -> void:
	if actor.animation == null:
		return
	var desired := "attack" if actor.windup > 0.0 else ("walk" if actor.velocity.length() > 0.4 else "idle")
	if actor.animation_state == desired:
		return
	actor.animation_state = desired
	var chosen := "Idle_Combat"
	if desired == "walk":
		chosen = "Walking_A"
	elif desired == "attack":
		chosen = "2H_Melee_Attack_Chop" if actor.kind == "brute" else "2H_Ranged_Shoot"
	if actor.animation.has_animation(chosen):
		var animation: Animation = actor.animation.get_animation(chosen)
		animation.loop_mode = Animation.LOOP_LINEAR if desired != "attack" else Animation.LOOP_NONE
		actor.animation.play(chosen, 0.15)

func on_feedback(event: String, data: Dictionary) -> void:
	match event:
		"milestone":
			pulse = 0.35
			sound.play("clear", -3)
		"boss_warning":
			sound.play("rejected", -4)
		"shot":
			recoil = authority.current_stats().recoil
			beam(data.from + Vector3(0, -0.12, 0), data.to, Color("92ffe4") if data.soul else Color("ffd494"), 0.08)
			sound.play("shot" if data.soul else "rifle")
			if data.hit:
				hit_marker = 0.16
		"hit":
			burst(data.at, Color("ffac70") if data.dead else Color("9bf7d4"), 0.5 if data.dead else 0.16)
			sound.play("hit", -6)
		"possess":
			pulse = 1.0
			burst(data.at + Vector3.UP, Color("81ffcc"), 1.0)
			sound.play("possess", 2)
		"inhabit":
			pulse = 0.65
			shake = 0.4
			notice = preload("res://scripts/traits.gd").host_name(authority.body_kind, authority.body_profile) + " 빙의 성공 · " + ("좌클릭: 연발총 / R: 재장전" if authority.body_kind == "soldier" else "좌클릭: 망치 공격")
			notice_left = 2.5
			sound.play("inhabit", 2)
		"rejected":
			pain = 0.5
			shake = 0.65
			notice = "빙의 실패 · 위장 해제"
			notice_left = 0.7
			sound.play("rejected")
		"unreachable":
			notice = "OUT OF REACH" if authority.aimed_actor() != null else "NO HOST"
			notice_left = 0.65
		"eject":
			pulse = 0.7
			shake = 0.7 if data.explode else 0.25
			burst(data.at, Color("bf8fd7") if data.explode else Color("7cffd3"), 3.0 if data.explode else 0.8)
			sound.play("eject" if data.explode else "possess")
		"swing":
			swing = 1.0
			shake = 0.4
			hit_marker = 0.2 if data.hit else 0.0
			sound.play("swing")
		"hurt":
			pain = 0.85
			shake = 0.4
			sound.play("hurt")
		"enemy_shot":
			beam(data.from, data.to, Color("ff765b"), 0.12)
			sound.play("rifle", -10)
		"slam":
			burst(data.at, Color("ff9b66"), 0.7)
		"reload", "loaded":
			sound.play(event)
		"exposed":
			notice = "감시자에게 발각됨" if data.reason == "seer" else "정체 노출"
			notice_left = 1.5
			if data.reason == "seer":
				sound.play("rejected")
		"detection":
			sound.play("loaded", -4)
		"supply":
			notice = "보존제 · 수명 +%.1f초" % data.restored
			notice_left = 1.5
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

func beam(from: Vector3, to: Vector3, color: Color, lifetime: float) -> void:
	var distance := from.distance_to(to)
	if distance < 0.01:
		return
	var line := Arena.box(self, Vector3(0.022, 0.022, distance), (from + to) * 0.5, Arena.material(color, 2))
	line.look_at(to, Vector3.RIGHT if absf((to - from).normalized().y) > 0.98 else Vector3.UP)
	var tween := create_tween()
	fx_tweens.append(tween)
	tween.tween_property(line, "scale", Vector3(0.01, 0.01, 1), lifetime)
	tween.tween_callback(line.queue_free)

func burst(pos: Vector3, color: Color, size: float) -> void:
	var mat := Arena.material(color, 1.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var orb := Arena.sphere(self, 0.1, pos, mat)
	var tween := create_tween().set_parallel(true)
	fx_tweens.append(tween)
	tween.tween_property(orb, "scale", Vector3.ONE * size * 10.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tween.chain().tween_callback(orb.queue_free)
