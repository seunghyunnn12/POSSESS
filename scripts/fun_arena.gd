extends "res://scripts/arena.gd"

var gates: Array = []
var room_actors: Array = [[], [], []]
var source
var backgrounds: Array[ShaderMaterial] = []

func _ready() -> void:
	rolls.seed = run_seed if run_seed != 0 else Time.get_ticks_usec()
	for room in 3:
		var center: Vector3 = [Vector3.ZERO, Vector3(0, 0, -24), Vector3(22, 0, 0)][room]
		box(self, Vector3(22, 1, 24), center + Vector3(0, -0.5, 0), dark, true)
		if room == 0:
			wall(center + Vector3(-11, 0, 0), true)
			door(Vector3(0, 0, -12), false, true)
			door(Vector3(11, 0, 0), true, true)
			door(Vector3(0, 0, 12), false, false)
		elif room == 1:
			wall(center + Vector3(-11, 0, 0), true)
			wall(center + Vector3(11, 0, 0), true)
			wall(center + Vector3(0, 0, -12), false)
		else:
			wall(center + Vector3(11, 0, 0), true)
			wall(center + Vector3(0, 0, -12), false)
			wall(center + Vector3(0, 0, 12), false)
		light(center + Vector3(0, 5, 0), Color("b3c5d1"), 2.2, 16)
		if room == 0: continue
		for x in [-5, 5]:
			box(self, Vector3(2, 1.1, 2), center + Vector3(x, 0.55, -2), stone, true)
		for x in [-9, 9]:
			for dz in [-7, 5]:
				box(self, Vector3(1.5, 0.025, 1.5), center + Vector3(x, 0.025, dz), amber)
		var roles := ["soldier", "shotgun", "brute", "mage"] if room == 1 else ["archer", "storm", "shotgun", "brute"]
		for i in range(roles.size() - 1, 0, -1):
			var j := rolls.randi_range(0, i)
			var saved = roles[i]
			roles[i] = roles[j]
			roles[j] = saved
		for i in 4:
			spawn(roles[i], center + Vector3([-2, 5, -5, 2][i], 0.05, [3, -5, -6, -8][i]), 2.5 + i * 0.3)
			var actor = enemies[-1]
			actor.set_meta("room", room + 1)
			room_actors[room].append(actor)
			set_active(actor, false)
		for i in 30:
			var actor := Actor.new()
			actor.setup("soldier")
			actor.set_meta("fodder", true)
			actor.set_meta("room", room + 1)
			actor.position = center + Vector3(9 if i % 2 == 0 else -9, 0.05, (5 if i % 4 < 2 else -7))
			actor.home = actor.position
			actor.max_hp = 22
			actor.hp = 22
			actor.visual = Node3D.new()
			actor.add_child(actor.visual)
			box(actor.visual, Vector3(0.55, 0.9, 0.45), Vector3(0, 0.7, 0), stone)
			sphere(actor.visual, 0.24, Vector3(0, 1.4, 0), material(Color("cf6b57")))
			actor.label = Label3D.new()
			actor.add_child(actor.label)
			add_child(actor)
			enemies.append(actor)
			room_actors[room].append(actor)
			set_active(actor, false)
	box(self, Vector3(8, 1, 8), Vector3(0, -0.5, 16), dark, true)
	for x in [-4, 4]:
		box(self, Vector3(0.5, 7, 8), Vector3(x, 3.5, 16), stone, true)
	box(self, Vector3(8, 7, 0.5), Vector3(0, 3.5, 20), stone, true)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("101923")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a5bacf")
	world.environment.ambient_light_energy = 0.75
	add_child(world)
	door_label("회랑", Vector3(0, 4.5, -11.7), 0)
	door_label("묘실", Vector3(10.7, 4.5, 0), -PI / 2)
	door_label("귀환", Vector3(0, 4.5, 11.7), PI)
	# Only static architecture is desaturated; actors and combat effects retain color.
	for node in get_children():
		if node is MeshInstance3D and node.material_override is StandardMaterial3D:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/fun_background.gdshader")
			material.set_shader_parameter("base_color", node.material_override.albedo_color)
			if node.material_override.emission_enabled:
				material.set_shader_parameter("glow_color", node.material_override.emission * node.material_override.emission_energy_multiplier)
			node.material_override = material
			backgrounds.append(material)

func _process(_dt: float) -> void:
	if source == null: return
	for material in backgrounds:
		material.set_shader_parameter("soul", 0.0 if source.state == 2 else 1.0)

func set_active(actor, active: bool) -> void:
	actor.alive = active
	actor.visible = active
	actor.collision_layer = 4 if active else 0
	actor.collision_mask = 7 if active else 0
	if actor.animation != null: actor.animation.active = active

func gate(index: int, opened: bool) -> void:
	var node = gates[index]
	node.visible = not opened
	node.get_child(0).collision_layer = 0 if opened else 1

func wall(at: Vector3, sideways: bool) -> void:
	box(self, Vector3(0.5, 7, 24) if sideways else Vector3(22, 7, 0.5), at + Vector3.UP * 3.5, stone, true)

func door_label(text: String, at: Vector3, angle: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = Visuals.THEME.default_font
	label.font_size = 64
	label.pixel_size = 0.012
	label.position = at
	label.rotation.y = angle
	add_child(label)

func door(at: Vector3, sideways: bool, opened: bool) -> void:
	var width := 24.0 if sideways else 22.0
	var piece := (width - 6.0) * 0.5
	for side in [-1, 1]:
		var offset: float = side * (3 + piece * 0.5)
		box(self, Vector3(0.5, 7, piece) if sideways else Vector3(piece, 7, 0.5), at + Vector3(0 if sideways else offset, 3.5, offset if sideways else 0), stone, true)
	box(self, Vector3(0.5, 2, 6) if sideways else Vector3(6, 2, 0.5), at + Vector3.UP * 6, stone, true)
	var node := box(self, Vector3(0.25, 5, 5.8) if sideways else Vector3(5.8, 5, 0.25), at + Vector3.UP * 2.5, brass, true)
	gates.append(node)
	gate(gates.size() - 1, opened)
	for side in [-1, 1]:
		box(self, Vector3(0.12, 5, 0.12), at + Vector3(0 if sideways else side * 2.92, 2.5, side * 2.92 if sideways else 0), mint)
