extends RefCounted
## Presentation-only set dressing for the expedition floor.
## Walls, floors and doors keep their simple collision boxes; this adds the
## dungeon on top: pillars, torches, banners, props, ceilings and dust.

const DUNGEON := "res://assets/env/dungeon/%s.glb"
const HALLOWEEN := "res://assets/env/halloween/%s.gltf"
const PILLAR_SCALE := Vector3(1.2, 1.75, 1.2)
const ZONE_BANNER := ["blue", "green", "red"]
const ZONE_TORCH := [Color("9fd6ff"), Color("ffcf8a"), Color("ff7a45")]
## Per-zone fog tint, fog density, ambient colour, ambient energy.
const ZONE_MOOD := [
	[Color("5d7c93"), 0.028, Color("7f97ad"), 0.55],
	[Color("6f7f5e"), 0.032, Color("8f9a78"), 0.5],
	[Color("8a4a35"), 0.034, Color("a3705d"), 0.5],
]

var arena
var rng := RandomNumberGenerator.new()
var cache := {}
var flicker: Array[Dictionary] = []

func _init(owner, seed_value: int) -> void:
	arena = owner
	rng.seed = seed_value

func model(path: String) -> PackedScene:
	if not cache.has(path): cache[path] = load(path)
	return cache[path]

func place(path: String, at: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE) -> Node3D:
	var scene := model(path)
	if scene == null: return null
	var node: Node3D = scene.instantiate()
	node.position = at
	node.rotation.y = yaw
	node.scale = scale
	arena.add_child(node)
	return node

func dungeon(name: String, at: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE) -> Node3D:
	return place(DUNGEON % name, at, yaw, scale)

func spooky(name: String, at: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE) -> Node3D:
	return place(HALLOWEEN % name, at, yaw, scale)

func blocker(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)
	body.position = at
	arena.add_child(body)

## Yaw that turns a model's +Z toward the room from a wall on side `dir`.
static func facing(dir: Vector2i) -> float:
	if dir == Vector2i.RIGHT: return -PI * 0.5
	if dir == Vector2i.LEFT: return PI * 0.5
	if dir == Vector2i.DOWN: return PI
	return 0.0

static func wall_length(dir: Vector2i) -> float:
	return 24.0 if dir.x != 0 else 22.0

## Point on the inner face of wall `dir`, `along` metres from its centre, `inset` into the room.
static func wall_point(center: Vector3, dir: Vector2i, along: float, inset: float) -> Vector3:
	if dir.x != 0: return center + Vector3(dir.x * (10.75 - inset), 0, along)
	return center + Vector3(along, 0, dir.y * (11.75 - inset))

func torch(at: Vector3, yaw: float, colour: Color) -> void:
	dungeon("torch_mounted", at, yaw, Vector3.ONE * 1.5)
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	var flame := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.26
	flame.mesh = ball
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.albedo_color = colour.lerp(Color(1, 0.85, 0.5), 0.5)
	fire.emission_enabled = true
	fire.emission = colour
	fire.emission_energy_multiplier = 5.0
	flame.material_override = fire
	flame.position = at + forward * 0.62 + Vector3.UP * 1.02
	flame.set_meta("keep_material", true)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(flame)
	var lamp := OmniLight3D.new()
	lamp.position = at + forward * 0.7 + Vector3.UP * 0.9
	lamp.light_color = colour
	lamp.light_energy = 1.7
	lamp.omni_range = 8.5
	lamp.omni_attenuation = 1.3
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 34.0
	lamp.distance_fade_length = 8.0
	arena.add_child(lamp)
	flicker.append({"light": lamp, "base": 1.7, "phase": rng.randf() * 100.0, "flame": flame})

func dress_room(center: Vector3, doors: Array, hidden: Array, zone: int, kind: String) -> void:
	var zone_index := clampi(zone - 1, 0, 2)
	# Ceiling closes the box so fog and torchlight have something to catch.
	var ceiling: MeshInstance3D = arena.box(arena, Vector3(22, 0.6, 24), center + Vector3(0, 7.3, 0), arena.dark)
	ceiling.set_meta("masonry", true)
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var half := wall_length(dir) * 0.5
		var has_door: bool = dir in doors or dir in hidden
		var spots := [-(half - 1.4), half - 1.4]
		if has_door: spots.append_array([-4.2, 4.2])
		else: spots.append(0.0)
		for along in spots:
			var at := wall_point(center, dir, along, 0.9)
			dungeon("pillar", at, 0.0, PILLAR_SCALE)
			blocker(at + Vector3.UP * 3.5, Vector3(1.8, 7, 1.8))
			var flank: bool = dir in doors and absf(along) < 5.0
			if flank or (not has_door and along == 0.0 and kind != "hub"):
				torch(wall_point(center, dir, along, 1.8) + Vector3.UP * 2.6, facing(dir), ZONE_TORCH[zone_index])
		if not has_door:
			var banner_colour: String = {"treasure": "yellow", "morgue": "white", "sanctuary": "white", "secret": "brown", "trial": "red", "boss": "red"}.get(kind, ZONE_BANNER[zone_index])
			for along in [-half * 0.5, half * 0.5]:
				dungeon("banner_patternA_" + banner_colour if rng.randf() < 0.5 else "banner_" + banner_colour, wall_point(center, dir, along, 0.05) + Vector3.UP * 1.3, facing(dir), Vector3.ONE * 1.3)
			if zone_index == 1 and kind == "combat":
				for along in [-half * 0.5 - 2.4, half * 0.5 + 2.4]:
					var shelf_at := wall_point(center, dir, along, 0.4)
					dungeon("shelf_large" if rng.randf() < 0.5 else "shelves", shelf_at, facing(dir), Vector3.ONE * 1.2)
	scatter(center, zone_index, kind)
	dust(center, zone_index)

func scatter(center: Vector3, zone_index: int, kind: String) -> void:
	var common := ["bone_A", "bone_B", "bone_C", "skull", "ribcage"]
	var count := 14 if kind in ["combat", "trial", "boss"] else 6
	for i in count:
		var at := center + Vector3(rng.randf_range(-9.0, 9.0), 0, rng.randf_range(-10.0, 10.0))
		if absf(at.x - center.x) < 3.0 and absf(at.z - center.z) < 3.0: continue
		spooky(common[rng.randi_range(0, common.size() - 1)], at + Vector3.UP * 0.12, rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.7, 1.0))
	# Wall-hugging clutter: barrels, crates, candles and rubble by zone.
	var clutter: Array = [["barrel_large", 0.8], ["barrel_small_stack", 0.9], ["box_stacked", 0.9], ["candle_triple", 1.3]]
	if zone_index == 1: clutter.append_array([["table_medium_broken", 1.0], ["candle_melted", 1.3]])
	if zone_index == 2: clutter.append_array([["rubble_half", 0.6], ["sword_shield_broken", 1.0]])
	if kind == "hub": clutter = [["candle_triple", 1.3], ["candle_melted", 1.3]]
	for i in (8 if kind in ["combat", "trial", "boss"] else 4):
		var dir: Vector2i = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][rng.randi_range(0, 3)]
		var along := rng.randf_range(-6.5, 6.5)
		if absf(along) < 3.6: along = signf(along) * 3.8 if along != 0.0 else 3.8
		var pick: Array = clutter[rng.randi_range(0, clutter.size() - 1)]
		dungeon(pick[0], wall_point(center, dir, along, 1.2), facing(dir) + rng.randf_range(-0.4, 0.4), Vector3.ONE * float(pick[1]))

func dust(center: Vector3, zone_index: int) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 60 if zone_index != 2 else 45
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.visibility_aabb = AABB(Vector3(-12, -1, -13), Vector3(24, 9, 26))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(10, 3, 11)
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 0.02
	process.initial_velocity_max = 0.12
	process.gravity = Vector3(0, 0.12 if zone_index == 2 else -0.01, 0)
	process.scale_min = 0.5
	process.scale_max = 1.2
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.25, 0.9) if zone_index == 2 else Color(0.85, 0.92, 1.0, 0.35)
	if zone_index == 2:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.45, 0.15)
		mat.emission_energy_multiplier = 3.0
	quad.material = mat
	particles.draw_pass_1 = quad
	particles.position = center + Vector3(0, 3.2, 0)
	arena.add_child(particles)

func tick(time: float) -> void:
	for f in flicker:
		var light: OmniLight3D = f.light
		var t: float = time * 7.0 + f.phase
		var k: float = 0.86 + 0.08 * sin(t) + 0.06 * sin(t * 2.7 + 1.3)
		light.light_energy = f.base * k
		f.flame.scale = Vector3(1.0, 0.8 + k * 0.35, 1.0)

static func mood(zone: int) -> Array:
	return ZONE_MOOD[clampi(zone - 1, 0, 2)]
