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
var map
var populated: Array = []
var potions := {}
var altars := {}
var morgue_slots := {}
var cracks := {}
var room_actors: Array = []
var source
var backgrounds: Array[ShaderMaterial] = []
var background_soul := -1.0

func _ready() -> void:
	rolls.seed = run_seed if run_seed != 0 else Time.get_ticks_usec()
	if map == null: map = Expedition.generate(rolls.seed)
	dresser = Dresser.new(self, rolls.seed + 77)
	var sides := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for room in range(1, map.size() + 1):
		room_actors.append([])
		populated.append(false)
		var center: Vector3 = map.center(room)
		var kind: String = map.kind(room)
		box(self, Vector3(22, 1, 24), center + Vector3(0, -0.5, 0), dark, true)
		var doors: Array = []
		var hidden: Array = []
		for direction in sides:
			var other: int = map.room_at(map.cells[room - 1] + direction)
			for edge in map.links.size():
				if room in map.links[edge] and other in map.links[edge]:
					if map.secret_doors.has(edge): hidden.append(direction)
					else: doors.append(direction)
		if room == map.final: doors.append(Vector2i.DOWN)
		dresser.dress_room(center, doors, hidden, map.zone(room), kind)
		for direction in sides:
			var neighbor: int = map.room_at(map.cells[room - 1] + direction)
			if direction in doors or direction in hidden: continue
			if neighbor > 0 and neighbor < room: continue
			wall(center + Vector3(direction.x * 11, 0, direction.y * 12), direction.x != 0)
		light(center + Vector3(0, 5, 0), [Color("b3c5d1"), Color("b5c4b0"), Color("c4aec7")][map.zone(room) - 1], 1.6, 16)
		match kind:
			"treasure": build_treasure(center)
			"morgue": build_morgue(center, room)
			"sanctuary": build_sanctuary(center, room)
			"secret": build_secret(center)
			"combat", "trial", "boss":
				for x in [-5, 5]:
					var cover := box(self, Vector3(2, 1.1, 2), center + Vector3(x, 0.55, -2 if room % 2 == 1 else 2), stone, true)
					cover.visible = false
					dresser.spooky("coffin_decorated" if x < 0 else "coffin", cover.position - Vector3.UP * 0.55, PI * 0.5 * (room % 2), Vector3(1.0, 0.85, 0.68))
				for x in [-9, 9]:
					for dz in [-7, 5]:
						dresser.dungeon("floor_tile_grate_open", center + Vector3(x, 0.01, dz), 0.0, Vector3(0.75, 1.0, 0.75))
				if kind == "trial":
					for x in [-7, 7]:
						dresser.spooky("post_skull", center + Vector3(x, 0, 0), 0.0, Vector3.ONE * 1.3)
	for edge in map.links.size():
		var pair: Array = map.links[edge]
		var from: Vector3 = map.center(pair[0])
		var to: Vector3 = map.center(pair[1])
		var at := (from + to) * 0.5
		var direction := (to - from).normalized()
		var secret: bool = map.secret_doors.has(edge)
		var keyed: bool = map.key_doors.has(edge)
		door(at, direction.x != 0, not secret and not keyed, secret)
		if secret:
			build_crack(edge, at, direction, pair)
			continue
		var angle := atan2(-direction.x, -direction.z)
		door_label(door_name(pair[1]), at - direction * 0.3 + Vector3.UP * 4.5, angle)
		door_label(door_name(pair[0]), at + direction * 0.3 + Vector3.UP * 4.5, angle + PI)
	var exit_at: Vector3 = map.center(map.final) + Vector3(0, 0, 12)
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
		morgue_slots[room] = morgue_slots.get(room, []) + [[kinds[i], slot]]
	# Embalming fluid: restores the current body's lifetime once.
	box(self, Vector3(1.2, 0.9, 1.2), center + Vector3(-1, 0.45, 0), stone, true)
	var flask := box(self, Vector3(0.28, 0.5, 0.28), center + Vector3(-1, 1.15, 0), pale)
	flask.set_meta("keep_material", true)
	potions[room] = flask
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
	label.pixel_size = 0.0075
	label.position = at
	label.rotation.y = angle
	add_child(label)

func door_name(room: int) -> String:
	var kind: String = map.kind(room)
	if kind == "treasure": return map.names[room - 1] + "
열쇠 필요"
	if kind == "trial": return map.names[room - 1] + "
강한 적 · 보상 2배"
	if kind == "boss": return map.names[room - 1] + "
보스"
	return map.names[room - 1]

func build_sanctuary(center: Vector3, room: int) -> void:
	dresser.spooky("shrine_candles", center, 0.0, Vector3.ONE * 1.6)
	for spot in [Vector3(-2.2, 0, -1.2), Vector3(2.2, 0, -1.2), Vector3(-1.6, 0, 1.8), Vector3(1.6, 0, 1.8)]:
		dresser.spooky("candle_triple", center + spot, randf() * TAU, Vector3.ONE * 1.1)
	light(center + Vector3(0, 2.2, 0), Color("ffd28a"), 2.4, 9)
	altars[room] = center

func build_secret(center: Vector3) -> void:
	dresser.dungeon("chest", center + Vector3(0, 0, -1), 0.0, Vector3.ONE * 1.2)
	for spot in [Vector3(-1.6, 0, 0.4), Vector3(1.5, 0, -0.2), Vector3(0.3, 0, 1.4)]:
		dresser.dungeon("coin_stack_small", center + spot, randf() * TAU, Vector3.ONE)
	light(center + Vector3(0, 2.2, 0), Color("ffcf73"), 2.0, 8)

## The secret doorway is sealed by a cracked wall that a body's explosion can bring down.
func build_crack(edge: int, at: Vector3, direction: Vector3, pair: Array) -> void:
	var toward_combat: Vector3 = direction if map.kind(pair[1]) == "combat" else -direction
	var sideways := absf(direction.x) > 0.5
	var model: Node3D = dresser.dungeon("wall_cracked", at + toward_combat * 0.35, PI * 0.5 if sideways else 0.0, Vector3(1.5, 1.25, 0.35))
	cracks[edge] = {"at": at + toward_combat * 0.6 + Vector3.UP * 1.2, "model": model}

func break_crack(edge: int) -> void:
	if not cracks.has(edge): return
	var info: Dictionary = cracks[edge]
	if is_instance_valid(info.model): info.model.queue_free()
	gate(edge, true)
	dresser.dungeon("rubble_half", info.at - Vector3.UP * 1.2, randf() * TAU, Vector3.ONE * 0.6)
	cracks.erase(edge)

## Enemies and wares are created the first time a room is entered.
func populate(room: int) -> void:
	if populated[room - 1]: return
	populated[room - 1] = true
	var center: Vector3 = map.center(room)
	var kind: String = map.kind(room)
	if kind == "morgue":
		for entry in morgue_slots.get(room, []):
			spawn(entry[0], entry[1] + Vector3(0, 0.05, 0), 999, "preserved")
			var actor = enemies[-1]
			actor.rotation.y = -PI * 0.5
			actor.rewarded = true
			actor.set_meta("price", Expedition.PRICES[entry[0]])
			actor.set_meta("room", room)
			room_actors[room - 1].append(actor)
			set_active(actor, false)
		return
	if not map.fights(room): return
	var zone: int = map.zone(room)
	var roles := ["soldier", "shotgun", "brute", "mage", "archer", "storm"]
	for i in range(roles.size() - 1, 0, -1):
		var j := rolls.randi_range(0, i)
		var saved = roles[i]
		roles[i] = roles[j]
		roles[j] = saved
	var hosts := 5 if kind == "trial" else 4
	var elite := ["swift", "preserved", "frenzied", "seer"]
	for i in hosts:
		var trait_id: String = elite[rolls.randi_range(0, elite.size() - 1)] if kind == "trial" or (zone > 1 and rolls.randf() < 0.25 * (zone - 1)) else "common"
		spawn(roles[i], center + Vector3([-2, 5, -5, 2, 0][i], 0.05, [3, -5, -6, -8, -2][i]), 2.5 + i * 0.3, trait_id)
		var actor = enemies[-1]
		if kind == "trial":
			actor.max_hp *= 1.35
			actor.hp = actor.max_hp
		actor.set_meta("room", room)
		room_actors[room - 1].append(actor)
		set_active(actor, false)
	var fodder := 18 if kind == "boss" else (26 if kind == "trial" else 30 + (zone - 1) * 4)
	for i in fodder:
		var actor := Actor.new()
		actor.setup("soldier")
		actor.set_meta("fodder", true)
		actor.set_meta("room", room)
		actor.position = center + Vector3(9 if i % 2 == 0 else -9, 0.05, (5 if i % 4 < 2 else -7))
		actor.home = actor.position
		actor.max_hp = 22 * (1.5 if kind == "trial" else 1.0) * (1.0 + 0.15 * (zone - 1))
		actor.hp = actor.max_hp
		actor.visual = Node3D.new()
		actor.add_child(actor.visual)
		var body = load(Visuals.MINION.path).instantiate()
		body.scale = Vector3.ONE * Visuals.MINION.scale
		actor.visual.add_child(body)
		actor.animation = find_animation(body)
		tint_minion(body)
		actor.label = Label3D.new()
		actor.add_child(actor.label)
		add_child(actor)
		enemies.append(actor)
		room_actors[room - 1].append(actor)
		set_active(actor, false)
	if kind == "boss":
		spawn("brute", center + Vector3(0, 0.05, 6), 4, Expedition.BOSS_TYPES[zone - 1])
		var boss = enemies[-1]
		boss.visual.get_child(0).scale *= Visuals.BOSS_SCALE
		boss.set_meta("room", room)
		room_actors[room - 1].append(boss)
		set_active(boss, false)

func door(at: Vector3, sideways: bool, opened: bool, secret: bool = false) -> void:
	var width := 24.0 if sideways else 22.0
	var piece := (width - 6.0) * 0.5
	for side in [-1, 1]:
		var offset: float = side * (3 + piece * 0.5)
		box(self, Vector3(0.5, 7, piece) if sideways else Vector3(piece, 7, 0.5), at + Vector3(0 if sideways else offset, 3.5, offset if sideways else 0), stone, true)
	box(self, Vector3(0.5, 2, 6) if sideways else Vector3(6, 2, 0.5), at + Vector3.UP * 6, stone, true)
	var node := box(self, Vector3(0.25, 5, 5.8) if sideways else Vector3(5.8, 5, 0.25), at + Vector3.UP * 2.5, stone if secret else brass, true)
	gates.append(node)
	gate(gates.size() - 1, opened)
	var ward := box(self, Vector3(0.12, 5, 5.9) if sideways else Vector3(5.9, 5, 0.12), at + Vector3.UP * 2.5, ward_material(), true)
	ward.set_meta("keep_material", true)
	seals.append(ward)
	seal(seals.size() - 1, false)
	if secret: return
	for side in [-1, 1]:
		box(self, Vector3(0.12, 5, 0.12), at + Vector3(0 if sideways else side * 2.92, 2.5, side * 2.92 if sideways else 0), door_trim)
