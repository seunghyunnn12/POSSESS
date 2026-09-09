extends Node3D
## Static room and art construction; no gameplay decisions.

const Actor = preload("res://scripts/actor.gd")
const Traits = preload("res://scripts/traits.gd")
var enemies: Array = []
var run_seed := 0
var layout := "ossuary"
var encounter: Dictionary = {}
var practice_marker: MeshInstance3D
var rolls := RandomNumberGenerator.new()
var supply_lid: MeshInstance3D
var supply_glow: MeshInstance3D
var stone := material(Color("222b36"))
var dark := material(Color("101922"))
var brass := material(Color("8c7850"))
var mint := material(Color("65f5c8"), 2.5)
var amber := material(Color("ffad66"), 2.0)

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = mat
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

static func sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	mesh.mesh = ball
	mesh.position = pos
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh

func _ready() -> void:
	if run_seed == 0:
		rolls.randomize()
	else:
		rolls.seed = run_seed
	build_room()
	if not encounter.is_empty():
		spawn_encounter(encounter)
		if encounter.get("secret", false):
			var rune := box(self, Vector3(0.28, 0.28, 0.12), encounter.hidden_at, amber)
			rune.rotation.z = PI * 0.25
			light(encounter.hidden_at + Vector3.UP * 0.2, Color("ffad66"), 1.2, 3)
		return
	if layout == "training":
		spawn("soldier", Vector3(-2.6, 0.05, 0), 1000)
		practice_marker = box(self, Vector3(1.8, 0.025, 1.8), Vector3(0, 0.04, 2.8), mint)
		return
	if layout == "hall":
		spawn("soldier", Vector3(-2.6, 0.05, 0), 3.5)
		spawn("soldier", Vector3(7, 0.05, -6), 5)
		spawn("brute", Vector3(-4, 0.05, -12), 6)
		return
	spawn("soldier", Vector3(-2.6, 0.05, 0.0), 2.0)
	spawn("soldier", Vector3(7, 0.05, -6), 3.1, "swift" if rolls.randf() < 0.5 else "frenzied")
	spawn("soldier", Vector3(-8, 0.05, -8), 4.0, "seer")
	spawn("brute", Vector3(3, 0.05, -4), 2.5)
	spawn("brute", Vector3(-4, 0.05, -12), 3.5, "preserved")

func build_room() -> void:
	if layout == "gallery":
		for x in [-4, 4]:
			box(self, Vector3(0.7, 3.5, 11), Vector3(x, 1.75, -8), stone, true)
			box(self, Vector3(0.08, 0.1, 11), Vector3(x, 3.55, -8), amber)
	elif layout == "crossroads":
		for x in [-8, 8]:
			for z in [-4, -12]:
				box(self, Vector3(8, 3.2, 0.7), Vector3(x, 1.6, z), stone, true)
				box(self, Vector3(7.8, 0.08, 0.08), Vector3(x, 3.23, z), mint)
	elif layout == "terraces":
		for x in [-9, 9]:
			var ramp := box(self, Vector3(4, 0.25, 8), Vector3(x, 0.65, -4), stone, true)
			ramp.rotation.x = atan(1.2 / 8)
			box(self, Vector3(4, 0.4, 7), Vector3(x, 1.05, -11.5), stone, true)
			box(self, Vector3(0.08, 0.08, 7), Vector3(x, 1.3, -11.5), mint)
	if layout == "vault":
		stone = material(Color("352c43"))
		mint = material(Color("bca0ff"), 2.5)
		for x in [-5, 5]:
			box(self, Vector3(2, 3.5, 2), Vector3(x, 1.75, -7), stone, true)
	box(self, Vector3(30, 1, 36), Vector3(0, -0.5, -3), dark, true)
	for x in [-15.0, 15.0]:
		box(self, Vector3(1, 8, 36), Vector3(x, 4, -3), stone, true)
	for z in [-21.0, 15.0]:
		box(self, Vector3(30, 8, 1), Vector3(0, 4, z), stone, true)
	box(self, Vector3(30, 0.5, 36), Vector3(0, 8.25, -3), dark, true)
	# Inlaid floor creates perspective and a readable combat plane.
	for x in range(-14, 15, 2):
		box(self, Vector3(0.025, 0.008, 34), Vector3(x, 0.005, -3), stone)
	for z in range(-20, 15, 2):
		box(self, Vector3(28, 0.008, 0.025), Vector3(0, 0.006, z), stone)
	for x in [-11.8, 11.8]:
		box(self, Vector3(0.06, 0.015, 32), Vector3(x, 0.02, -3), mint)
	for z in [-18.8, 12.8]:
		box(self, Vector3(23.6, 0.015, 0.06), Vector3(0, 0.02, z), mint)
	# Side buttresses leave the central possession lanes unobstructed.
	for x in [-13.5, 13.5]:
		for z in [-16.0, -7.0, 2.0, 11.0]:
			box(self, Vector3(1.8, 6, 1.8), Vector3(x, 3, z), stone, true)
			box(self, Vector3(2.2, 0.35, 2.2), Vector3(x, 0.18, z), brass)
			box(self, Vector3(2.2, 0.35, 2.2), Vector3(x, 5.9, z), brass)
			box(self, Vector3(0.12, 3.0, 0.12), Vector3(x + (1.0 if x < 0 else -1.0), 3.1, z), mint)
			if z in [-16.0, 2.0]:
				light(Vector3(x + (1.5 if x < 0 else -1.5), 3.5, z), Color("71dcc5"), 1.8, 11)
	for pos in [Vector3(-7, 0, 3), Vector3(7, 0, -12)]:
		box(self, Vector3(2.8, 1.2, 1.8), pos + Vector3.UP * 0.6, stone, true)
		box(self, Vector3(2.7, 0.05, 1.7), pos + Vector3.UP * 1.23, brass)
	var supply := box(self, Vector3(1.15, 0.8, 0.75), Vector3(-6, 0.4, -1), brass, true)
	supply.get_child(0).set_meta("supply", true)
	supply_lid = box(self, Vector3(1.2, 0.12, 0.8), Vector3(-6, 0.86, -1), stone)
	supply_glow = box(self, Vector3(0.4, 0.035, 0.2), Vector3(-6, 0.94, -1), mint)
	# Sealed portal: destination, silhouette and focal point.
	box(self, Vector3(6.5, 5.5, 0.3), Vector3(0, 2.75, -20.35), dark)
	for x in [-3.4, 3.4]:
		box(self, Vector3(0.3, 5.8, 0.5), Vector3(x, 2.9, -20.0), brass)
		box(self, Vector3(0.08, 5.2, 0.1), Vector3(x * 0.93, 2.8, -19.7), amber)
	box(self, Vector3(7.1, 0.3, 0.5), Vector3(0, 5.7, -20.0), brass)
	for x in [-1.5, 0.0, 1.5]:
		box(self, Vector3(0.045, 3.4, 0.1), Vector3(x, 2.7, -20.1), amber)
	var title := Label3D.new()
	title.text = {"training": "AWAKENING", "hall": "FORGOTTEN HALL", "vault": "WATCHER'S VAULT"}.get(layout, "THE BORROWED FLESH")
	title.font_size = 48
	title.pixel_size = 0.006
	title.position = Vector3(0, 6.5, -20.1)
	title.modulate = Color("e4d2aa")
	add_child(title)
	light(Vector3(0, 4, -17), Color("ffad66"), 2.0, 12)
	light(Vector3(0, 5, 7), Color("a9c8dc"), 2.0, 18)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101923")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a5bacf")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, -25, 0)
	sun.light_color = Color("9caac4")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)

func light(pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	add_child(lamp)

func spawn(kind: String, pos: Vector3, delay: float, trait_id: String = "common") -> void:
	var actor := Actor.new()
	actor.name = "%s_%d" % [kind, enemies.size()]
	actor.setup(kind)
	actor.set_profile(Traits.profile(trait_id, rolls if trait_id != "common" else null))
	actor.position = pos
	actor.home = pos
	actor.attack_clock = delay
	add_child(actor)
	enemies.append(actor)
	var path := "res://assets/characters/skeletons/Skeleton_Warrior.glb" if kind in ["brute", "shotgun"] else ("res://assets/characters/skeletons/Skeleton_Mage.glb" if kind in ["mage", "storm"] else "res://assets/characters/skeletons/Skeleton_Rogue.glb")
	var packed = load(path)
	actor.visual = Node3D.new()
	actor.add_child(actor.visual)
	if packed is PackedScene:
		var model = packed.instantiate()
		actor.visual.add_child(model)
		# Source heights: Rogue 2.308m, Warrior 2.590m. Match hit capsules.
		model.scale = Vector3.ONE * (0.88 if kind == "brute" else 0.79)
		actor.animation = find_animation(model)
	else:
		box(actor.visual, Vector3(0.75, 1.3, 0.5), Vector3(0, 0.9, 0), brass)
		sphere(actor.visual, 0.3, Vector3(0, 1.8, 0), stone)
	# Primitive weapon silhouettes remain readable with the supplied fantasy models.
	if kind in ["soldier", "shotgun"]:
		box(actor.visual, Vector3(0.16, 0.16, 0.85), Vector3(0.36, 1.1, 0.4), dark)
		box(actor.visual, Vector3(0.58, 0.08, 0.13), Vector3(0.36, 1.1, 0.67), brass)
		if kind == "shotgun":
			box(actor.visual, Vector3(0.24, 0.20, 0.7), Vector3(0.36, 1.1, 0.45), brass)
	elif kind == "archer":
		for i in 9:
			var angle := -PI / 2 + i * PI / 8
			var piece := box(actor.visual, Vector3(0.06, 0.17, 0.05), Vector3(0.4 + cos(angle) * 0.3, 1.2 + sin(angle) * 0.55, 0.35), mint)
			piece.rotation.z = angle
		box(actor.visual, Vector3(0.015, 1.1, 0.015), Vector3(0.4, 1.2, 0.35), brass)
	elif kind in ["mage", "storm"]:
		box(actor.visual, Vector3(0.08, 1.4, 0.08), Vector3(0.5, 1.1, 0.2), brass)
		sphere(actor.visual, 0.21, Vector3(0.5, 1.9, 0.2), material(Color("ff8660") if kind == "mage" else Color("c6a0ff"), 2.0))
	else:
		box(actor.visual, Vector3(0.12, 1.4, 0.12), Vector3(0.7, 1.0, 0.25), brass)
		box(actor.visual, Vector3(0.75, 0.5, 0.25), Vector3(0.7, 1.65, 0.25), dark)
	var core_mat := material(Color("ff9e68") if kind == "brute" else Color("79edca"), 1.5)
	sphere(actor.visual, 0.12, Vector3(0, 1.35 if kind == "brute" else 1.05, 0.22), core_mat)
	actor.label = Label3D.new()
	actor.label.position.y = (2.85 if kind == "brute" else 2.25) + (0.2 if actor.profile.special else 0.0)
	actor.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.label.font_size = 42
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic"])
	actor.label.font = font
	actor.label.outline_size = 10
	actor.label.pixel_size = 0.01 if actor.profile.special else 0.006
	actor.label.no_depth_test = false
	actor.add_child(actor.label)
	if actor.profile.special:
		var emblem := box(actor.visual, Vector3(0.14, 0.14, 0.14), Vector3(0, 2.48 if kind == "brute" else 2.02, 0), material(actor.profile.color, 2.0))
		emblem.rotation.z = PI * 0.25

func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := find_animation(child)
		if found != null:
			return found
	return null

func spawn_encounter(spec: Dictionary, summoned: bool = false) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = spec.seed
	rolls.seed = spec.seed
	var slots := [Vector3(-2.5, 0.05, -1), Vector3(8, 0.05, -7), Vector3(-8, 0.05, -9), Vector3(2, 0.05, -16), Vector3(-8, 0.05, -17)]
	if layout == "terraces":
		slots = [Vector3(-2, 0.05, -1), Vector3(2, 0.05, -4), Vector3(-2, 0.05, -8), Vector3(2, 0.05, -13), Vector3(0, 0.05, -17)]
	for i in int(spec.count):
		var slot: Vector3 = slots[i % slots.size()] + Vector3(random.randf_range(-1, 1), 0, random.randf_range(-1, 1))
		var trait_id: String = ["common", "swift", "preserved", "frenzied", "seer"][random.randi_range(0, 4)] if spec.tier > 1 else "common"
		var role := "soldier" if i == 0 or random.randf() < 0.6 else "brute"
		if spec.get("varied", false):
			role = ["soldier", "brute", "shotgun", "archer", "mage", "storm"][(i + int(spec.seed) % 6) % 6]
		spawn(role, slot, 3 + i * 0.7, trait_id)
		var actor = enemies[-1]
		if spec.route == 1:
			actor.profile.health = actor.profile.get("health", 1.0) * 1.35
			actor.attributes = Traits.stats(actor.kind, actor.profile)
			actor.max_hp = actor.attributes.host_health
			actor.hp = actor.max_hp
		actor.rewarded = summoned
	if spec.boss != "":
		spawn("brute", Vector3(0, 0.05, -13), 4, spec.boss)
		enemies[-1].scale = Vector3.ONE * 1.4
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 6.0
		torus.outer_radius = 6.08
		ring.mesh = torus
		ring.material_override = amber
		ring.position = Vector3(0, 0.04, -9)
		ring.scale.y = 0.15
		add_child(ring)
