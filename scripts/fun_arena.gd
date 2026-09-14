extends "res://scripts/arena.gd"

var gates: Array = []
var room_actors: Array = [[], [], []]
var source
var backgrounds: Array[ShaderMaterial] = []

func _ready() -> void:
	rolls.seed = run_seed if run_seed != 0 else Time.get_ticks_usec()
	for room in 3:
		var z := -24.0 * room
		box(self, Vector3(22, 1, 24), Vector3(0, -0.5, z), dark, true)
		for x in [-11, 11]:
			box(self, Vector3(1, 7, 24), Vector3(x, 3.5, z), stone, true)
		for side in [-1, 1]:
			box(self, Vector3(8, 7, 0.5), Vector3(side * 7, 3.5, z - 12), stone, true)
		box(self, Vector3(6, 2, 0.5), Vector3(0, 6, z - 12), stone, true)
		var gate := box(self, Vector3(5.8, 5, 0.25), Vector3(0, 2.5, z - 12), brass, true)
		gates.append(gate)
		for x in [-3.1, 3.1]:
			box(self, Vector3(0.1, 5, 0.1), Vector3(x, 2.5, z - 11.65), mint)
		for x in [-5, 5]:
			box(self, Vector3(2, 1.1 + room * 0.35, 2), Vector3(x, 0.55 + room * 0.175, z - 2), stone, true)
		for x in [-9, 9]:
			for dz in [-7, 5]:
				box(self, Vector3(1.5, 0.025, 1.5), Vector3(x, 0.025, z + dz), amber)
		light(Vector3(0, 5, z), Color("b3c5d1"), 2.2, 16)
		var roles := ["soldier", "shotgun", "brute", "mage"] if room == 0 else (["archer", "storm", "shotgun", "brute"] if room == 1 else ["mage", "soldier", "archer", "storm"])
		for i in range(roles.size() - 1, 0, -1):
			var j := rolls.randi_range(0, i)
			var saved = roles[i]
			roles[i] = roles[j]
			roles[j] = saved
		if room == 0: roles = ["soldier", "shotgun", "brute", "mage"]
		for i in 4:
			spawn(roles[i], Vector3([-2, 5, -5, 2][i], 0.05, z + [3, -5, -6, -8][i]), 2.5 + i * 0.3)
			var actor = enemies[-1]
			actor.set_meta("room", room + 1)
			room_actors[room].append(actor)
			set_active(actor, false)
		for i in 30:
			var actor := Actor.new()
			actor.setup("soldier")
			actor.set_meta("fodder", true)
			actor.set_meta("room", room + 1)
			actor.position = Vector3(9 if i % 2 == 0 else -9, 0.05, z + (5 if i % 4 < 2 else -7))
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
	box(self, Vector3(22, 7, 0.5), Vector3(0, 3.5, 12), stone, true)
	box(self, Vector3(22, 1, 10), Vector3(0, -0.5, -65), dark, true)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("101923")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a5bacf")
	world.environment.ambient_light_energy = 0.75
	add_child(world)
	# Only static architecture is desaturated; actors and combat effects retain color.
	for node in get_children():
		if node is MeshInstance3D and node.material_override is StandardMaterial3D:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/fun_background.gdshader")
			material.set_shader_parameter("base_color", node.material_override.albedo_color)
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
