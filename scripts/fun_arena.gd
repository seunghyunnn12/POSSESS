extends "res://scripts/arena.gd"

const Expedition = preload("res://scripts/expedition.gd")
const Dresser = preload("res://scripts/dungeon_dresser.gd")
var dresser
var environment_res: Environment
var mood_tween: Tween
var clock := 0.0
var door_trim := material(Color("3aa88a"), 0.35)
var gates: Array = []
var seals: Array = []
var potion: MeshInstance3D
var room_actors: Array = []
var source
var backgrounds: Array[ShaderMaterial] = []
var background_soul := -1.0

func _ready() -> void:
	rolls.seed = run_seed if run_seed != 0 else Time.get_ticks_usec()
	dresser = Dresser.new(self, rolls.seed + 77)
	for room in Expedition.CELLS.size():
		room_actors.append([])
		var center: Vector3 = Expedition.center(room + 1)
		box(self, Vector3(22, 1, 24), center + Vector3(0, -0.5, 0), dark, true)
		var doors: Array = []
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var other: int = Expedition.CELLS.find(Expedition.CELLS[room] + direction) + 1
			for edge in Expedition.LINKS:
				if room + 1 in edge and other in edge: doors.append(direction)
		if room + 1 == Expedition.FINAL: doors.append(Vector2i.DOWN)
		var kind := "hub" if room + 1 in Expedition.HUBS else ("treasure" if room + 1 == Expedition.TREASURE else ("morgue" if room + 1 == Expedition.MORGUE else "combat"))
		dresser.dress_room(center, doors, Expedition.zone(room + 1), kind)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: int = Expedition.CELLS.find(Expedition.CELLS[room] + direction) + 1
			var connected := false
			for edge in Expedition.LINKS:
				if room + 1 in edge and neighbor in edge: connected = true
			if room + 1 == Expedition.FINAL and direction == Vector2i.DOWN: continue
			if connected or (neighbor > 0 and neighbor < room + 1): continue
			wall(center + Vector3(direction.x * 11, 0, direction.y * 12), direction.x != 0)
		light(center + Vector3(0, 5, 0), [Color("b3c5d1"), Color("b5c4b0"), Color("c4aec7")][Expedition.zone(room + 1) - 1], 2.2, 16)
		if room + 1 == Expedition.TREASURE:
			build_treasure(center)
			continue
		if room + 1 == Expedition.MORGUE:
			build_morgue(center, room)
			continue
		if room + 1 in Expedition.HUBS: continue
		for x in [-5, 5]:
			var cover := box(self, Vector3(2, 1.1, 2), center + Vector3(x, 0.55, -2 if room % 2 == 1 else 2), stone, true)
			cover.visible = false
			dresser.spooky("coffin_decorated" if x < 0 else "coffin", cover.position - Vector3.UP * 0.55, PI * 0.5 * (room % 2), Vector3(1.0, 0.85, 0.68))
		for x in [-9, 9]:
			for dz in [-7, 5]:
				dresser.dungeon("floor_tile_grate_open", center + Vector3(x, 0.01, dz), 0.0, Vector3(0.75, 1.0, 0.75))
		var roles := ["soldier", "shotgun", "brute", "mage"] if room % 2 == 1 else ["archer", "storm", "shotgun", "brute"]
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
		for i in (18 if room + 1 == Expedition.FINAL else 30 + (Expedition.zone(room + 1) - 1) * 4):
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
			var model = load(Visuals.MINION.path).instantiate()
			model.scale = Vector3.ONE * Visuals.MINION.scale
			actor.visual.add_child(model)
			actor.animation = find_animation(model)
			tint_minion(model)
			actor.label = Label3D.new()
			actor.add_child(actor.label)
			add_child(actor)
			enemies.append(actor)
			room_actors[room].append(actor)
			set_active(actor, false)
		if room + 1 == Expedition.FINAL:
			spawn("brute", center + Vector3(0, 0.05, 6), 4, "sovereign")
			var boss = enemies[-1]
			boss.visual.get_child(0).scale *= Visuals.BOSS_SCALE
			boss.set_meta("room", room + 1)
			room_actors[room].append(boss)
			set_active(boss, false)
	for edge in Expedition.LINKS:
		var from: Vector3 = Expedition.center(edge[0])
		var to: Vector3 = Expedition.center(edge[1])
		var at := (from + to) * 0.5
		var direction := (to - from).normalized()
		var key_door: bool = gates.size() in Expedition.KEY_DOORS
		door(at, direction.x != 0, not gates.size() in Expedition.LOCKS and not key_door)
		var angle := atan2(-direction.x, -direction.z)
		door_label(Expedition.NAMES[edge[1] - 1] + ("\n열쇠 필요" if key_door else ""), at - direction * 0.3 + Vector3.UP * 4.5, angle)
		door_label(Expedition.NAMES[edge[0] - 1], at + direction * 0.3 + Vector3.UP * 4.5, angle + PI)
	var exit_at := Expedition.center(Expedition.FINAL) + Vector3(0, 0, 12)
	door(exit_at, false, false)
	door_label("귀환", exit_at + Vector3(0, 4.5, -0.3), PI)
	box(self, Vector3(8, 1, 8), exit_at + Vector3(0, -0.5, 4), dark, true)
	for x in [-4, 4]:
		box(self, Vector3(0.5, 7, 8), exit_at + Vector3(x, 3.5, 4), stone, true)
	box(self, Vector3(8, 7, 0.5), exit_at + Vector3(0, 3.5, 8), stone, true)
	var environment := WorldEnvironment.new()
	environment_res = Environment.new()
	var env := environment_res
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("06090d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7f97ad")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.028
	env.volumetric_fog_albedo = Color("5d7c93")
	env.volumetric_fog_emission = Color("0b1218")
	env.volumetric_fog_emission_energy = 0.4
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.35
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.95
	environment.environment = env
	add_child(environment)
	# Only static architecture is desaturated; actors and combat effects retain color.
	for node in get_children():
		if node.has_meta("keep_material"): continue
		if node is MeshInstance3D and node.material_override is StandardMaterial3D:
			var masonry: bool = node.material_override == stone or node.material_override == dark
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/fun_background.gdshader")
			material.set_shader_parameter("pattern", 1 if masonry else 0)
			material.set_shader_parameter("base_color", (Color("5b636b") if node.material_override == stone else Color("474b50")) if masonry else node.material_override.albedo_color)
			if node.material_override.emission_enabled:
				material.set_shader_parameter("glow_color", node.material_override.emission * node.material_override.emission_energy_multiplier)
			node.material_override = material
			backgrounds.append(material)

func _process(dt: float) -> void:
	clock += dt
	if dresser != null: dresser.tick(clock)
	if source == null: return
	var soul := 0.0 if source.state == 2 else 1.0
	if soul == background_soul: return
	background_soul = soul
	for material in backgrounds:
		material.set_shader_parameter("soul", soul)

## Retint fog and ambient light for the zone the player is standing in.
func set_zone(zone: int) -> void:
	if environment_res == null: return
	var mood: Array = Dresser.mood(zone)
	if mood_tween != null and mood_tween.is_valid(): mood_tween.kill()
	mood_tween = create_tween().set_parallel(true)
	mood_tween.tween_property(environment_res, "volumetric_fog_albedo", mood[0], 1.5)
	mood_tween.tween_property(environment_res, "volumetric_fog_density", mood[1], 1.5)
	mood_tween.tween_property(environment_res, "ambient_light_color", mood[2], 1.5)
	mood_tween.tween_property(environment_res, "ambient_light_energy", mood[3], 1.5)

func tint_minion(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original = node.get_active_material(surface)
			if original is StandardMaterial3D:
				var tinted = original.duplicate()
				tinted.albedo_color = Color("89858b")
				node.set_surface_override_material(surface, tinted)
	for child in node.get_children(): tint_minion(child)

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

## The bell's soul ward: a visible barrier that holds ghosts and bodies alike.
func seal(index: int, sealed: bool) -> void:
	var node = seals[index]
	node.visible = sealed
	node.get_child(0).collision_layer = 1 if sealed else 0

func is_blocked(index: int) -> bool:
	return gates[index].visible or seals[index].visible

func ward_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.86, 1.0, 0.38)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color("6fdcff")
	mat.emission_energy_multiplier = 1.6
	return mat

func build_treasure(center: Vector3) -> void:
	var gold := material(Color("e6b24f"), 1.4)
	box(self, Vector3(2.2, 0.5, 2.0), center + Vector3(0, 0.25, 0), stone, true)
	dresser.dungeon("chest_gold", center + Vector3(0, 0.5, 0), PI * 0.5, Vector3.ONE * 1.1)
	for spot in [Vector3(-1.9, 0, 1.2), Vector3(1.8, 0, -1.3), Vector3(-1.4, 0, -1.8)]:
		dresser.dungeon("coin_stack_large" if spot.x < 0 else "coin_stack_medium", center + spot, randf() * TAU, Vector3.ONE * 0.8)
	var relic := box(self, Vector3(0.36, 0.36, 0.36), center + Vector3(0, 2.4, 0), gold)
	relic.rotation = Vector3(PI * 0.25, PI * 0.25, 0)
	relic.set_meta("keep_material", true)
	light(center + Vector3(0, 2.6, 0), Color("ffcf73"), 2.6, 9)
	for corner in [Vector3(-8, 0, -9), Vector3(8, 0, -9), Vector3(-8, 0, 9), Vector3(8, 0, 9)]:
		box(self, Vector3(0.8, 3.2, 0.8), center + corner + Vector3.UP * 1.6, stone, true)
		box(self, Vector3(0.9, 0.1, 0.9), center + corner + Vector3.UP * 3.25, gold)

func build_morgue(center: Vector3, room: int) -> void:
	var pale := material(Color("7fe0b0"), 1.6)
	var kinds := ["soldier", "shotgun", "archer", "brute", "mage", "storm"]
	for i in range(kinds.size() - 1, 0, -1):
		var j := rolls.randi_range(0, i)
		var saved = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = saved
	for i in 3:
		var slot := center + Vector3(7.2, 0, [-5.5, 0.0, 5.5][i])
		# Upright coffin behind each preserved body.
		box(self, Vector3(0.6, 3.0, 2.0), slot + Vector3(1.5, 1.5, 0), dark, true).visible = false
		# Stand the coffin on end (pitch) and turn its lid toward the room (yaw); Godot applies Y*X*Z.
		var coffin: Node3D = dresser.spooky("coffin_decorated", slot + Vector3(1.55, 1.5, 0))
		if coffin != null: coffin.rotation = Vector3(PI * 0.5, -PI * 0.5, 0)
		dresser.spooky("candle_triple" if i != 1 else "skull_candle", slot + Vector3(0.9, 0, 1.3), 0.0, Vector3.ONE * 0.9)
		spawn(kinds[i], slot + Vector3(0, 0.05, 0), 999, "preserved")
		var actor = enemies[-1]
		actor.rotation.y = -PI * 0.5
		actor.rewarded = true
		actor.set_meta("price", Expedition.PRICES[kinds[i]])
		actor.set_meta("room", room + 1)
		room_actors[room].append(actor)
		set_active(actor, false)
	# Embalming fluid: restores the current body's lifetime once.
	box(self, Vector3(1.2, 0.9, 1.2), center + Vector3(-1, 0.45, 0), stone, true)
	var flask := box(self, Vector3(0.28, 0.5, 0.28), center + Vector3(-1, 1.15, 0), pale)
	flask.set_meta("keep_material", true)
	potion = flask
	light(center + Vector3(-1, 2.4, 0), Color("7fe0b0"), 1.8, 7)
	light(center + Vector3(6, 3.5, 0), Color("c4aec7"), 1.6, 10)

func wall(at: Vector3, sideways: bool) -> void:
	box(self, Vector3(0.5, 7, 24) if sideways else Vector3(22, 7, 0.5), at + Vector3.UP * 3.5, stone, true)

func door_label(text: String, at: Vector3, angle: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = Visuals.THEME.default_font
	label.font_size = 64
	label.double_sided = false
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
	var ward := box(self, Vector3(0.12, 5, 5.9) if sideways else Vector3(5.9, 5, 0.12), at + Vector3.UP * 2.5, ward_material(), true)
	ward.set_meta("keep_material", true)
	seals.append(ward)
	seal(seals.size() - 1, false)
	for side in [-1, 1]:
		box(self, Vector3(0.12, 5, 0.12), at + Vector3(0 if sideways else side * 2.92, 2.5, side * 2.92 if sideways else 0), door_trim)
