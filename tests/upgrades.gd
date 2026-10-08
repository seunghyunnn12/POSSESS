extends "res://tests/journey.gd"
## Level-up pool v2: soul-shot shaping, soul weapons, survival picks, evolutions.
## Run: godot --headless --path . -s tests/upgrades.gd -- --fun
const Build = preload("res://scripts/fun_augments.gd")
var map
var room := -1

func setup() -> void:
	game = Main.new()
	game.run_seed = 41
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	map = sim.map
	await settle()
	sim.learned = true
	game.begin()
	for r in range(1, map.size() + 1):
		if map.kind(r) == "combat" and map.zone(r) == 1: room = r
	sim.player.position = map.center(room) + Vector3(0, 0.05, 6)
	sim.enter_room(room)
	sim.spawn_queue.clear()
	sim.invulnerable = 9999

func hosts() -> Array:
	return sim.actors.filter(func(a): return a.alive and not a.claimed and not a.has_meta("fodder"))

func reset_shots() -> void:
	sim.projectiles.clear()
	sim.shot_left = 0
	sim.settle_left = 0

func run() -> void:
	await setup()
	check(Build.DATA.size() == 30, "pool holds 30 entries (%d)" % Build.DATA.size())
	var groups := {}
	for id in Build.DATA: groups[Build.DATA[id][1]] = groups.get(Build.DATA[id][1], 0) + 1
	check(groups.get("soul", 0) == 7 and groups.get("weapon", 0) == 2 and groups.get("evo", 0) == 3, "pool has ghost shots, soul weapons and evolutions %s" % groups)
	check(not sim.available_augments().has("storm_soul"), "an evolution is locked until both ingredients are maxed")

	# Soul shot shaping.
	sim.state = sim.State.Soul
	sim.body_profile.clear()
	sim.upgrades["s_split"] = 2
	reset_shots()
	sim.attack_ghost()
	check(sim.projectiles.size() == 3, "영혼 분열 2: three shots per click (%d)" % sim.projectiles.size())
	sim.upgrades["s_pierce"] = 2
	sim.upgrades["s_seek"] = 1
	reset_shots()
	sim.attack_ghost()
	check(sim.projectiles.all(func(p): return p.pierce == 3 and p.homing == 4.0), "꿰뚫는 영혼 / 추적하는 영혼 shape every shot")
	sim.upgrades["s_split"] = 0

	# Piercing: two enemies in a line both take damage from one shot.
	var line: Array = hosts().slice(0, 2)
	var origin: Vector3 = map.center(room) + Vector3(0, 0.05, 4)
	line[0].position = origin + Vector3(0, 0, -4)
	line[1].position = origin + Vector3(0, 0, -7)
	sim.player.position = origin
	await physics_frame
	await physics_frame
	aim_point(line[0].position + Vector3.UP)
	sim.upgrades["s_seek"] = 0
	var hp0: float = line[0].hp
	var hp1: float = line[1].hp
	reset_shots()
	sim.attack_ghost()
	for i in 40:
		sim.tick_projectiles(1.0 / 60)
		await physics_frame
	check(line[0].hp < hp0 and line[1].hp < hp1, "a piercing soul shot hits both enemies in a line")

	# Homing: a shot fired well off to the side curves into the target.
	sim.upgrades["s_pierce"] = 0
	sim.upgrades["s_seek"] = 2
	var mark = line[0]
	mark.position = origin + Vector3(0, 0, -6)
	line[1].position = origin + Vector3(30, 0, 30)
	await physics_frame
	sim.yaw += 0.5
	var hpm: float = mark.hp
	reset_shots()
	sim.attack_ghost()
	for i in 60:
		sim.tick_projectiles(1.0 / 60)
		await physics_frame
	check(mark.hp < hpm, "추적하는 영혼 2 bends a missed shot into the enemy")

	# Soul weapons.
	sim.upgrades["orbit"] = 1
	sim.tick_soul_weapons(1.0 / 60)
	check(sim.orbit_positions.size() == 1, "맴도는 해골 1: one skull circles the player")
	var victim = mark
	victim.position = sim.orbit_positions[0] - Vector3.UP
	await physics_frame
	var hpv: float = victim.hp
	sim.tick_soul_weapons(1.0 / 60)
	check(victim.hp < hpv, "the skull damages an enemy it passes through")
	sim.upgrades["lance"] = 1
	sim.lance_clock = 0
	reset_shots()
	victim.position = sim.player.position + Vector3(0, 0, -6)
	await physics_frame
	sim.tick_soul_weapons(1.0 / 60)
	check(sim.projectiles.size() >= 1 and sim.projectiles[-1].get("pierce", 0) == 3, "영혼 창 fires a piercing lance at the nearest enemy by itself")

	# Survival picks.
	sim.upgrades["soul_time"] = 2
	check(is_equal_approx(sim.soul_max(), 30.0), "질긴 영혼 2 raises the ghost clock to 30 s")
	sim.upgrades["embalm"] = 1
	var body_host = hosts()[0]
	sim.player.position = body_host.position + Vector3(0, 0, 3)
	sim.begin_possession(body_host)
	await ticks(50)
	sim.pending_levels = 0
	while not sim.upgrade_choices.is_empty(): sim.choose_upgrade(0)
	var base_life: float = sim.current_stats().life
	check(sim.state == sim.State.Body and is_equal_approx(sim.decay_max, base_life + 5.0), "방부 1 adds 5 s to a fresh body (%.1f vs %.1f)" % [sim.decay_max, base_life])
	sim.upgrades["funeral"] = 2
	var exploded := [false]
	sim.feedback.connect(func(e, d): if e == "eject" and d.get("explode", false): exploded[0] = true)
	sim.eject(false)
	await ticks(30)
	check(exploded[0], "장례 2: leaving with E still detonates the body")
	check(sim.soul > 29.0, "after leaving a body the ghost refills to its raised cap (%.2f)" % sim.soul)

	# Volley: an archer body fires extra arrows.
	var archer = null
	for a in sim.actors:
		if a.alive and not a.claimed and a.kind == "archer": archer = a
	if archer == null:
		archer = sim.world.reinforce(room, map.center(room) + Vector3(3, 0.05, 0), "archer")
		sim.actors = sim.world.room_actors[room - 1]
	sim.begin_possession(archer)
	await ticks(50)
	sim.pending_levels = 0
	while not sim.upgrade_choices.is_empty(): sim.choose_upgrade(0)
	sim.upgrades["volley"] = 2
	reset_shots()
	sim.bow_charge = 1.0
	sim.fire_arrow()
	check(sim.projectiles.size() == 3, "쌍시 2: three arrows per draw (%d)" % sim.projectiles.size())

	# Evolution: both ingredients maxed -> offered first.
	sim.upgrades["s_split"] = 2
	sim.upgrades["s_seek"] = 2
	check(sim.available_augments().has("storm_soul"), "maxing both ingredients unlocks 영혼 폭풍")
	sim.upgrade_choices.clear()
	sim.offer_augments(sim.available_augments())
	check(sim.upgrade_choices[0] == "storm_soul" and sim.upgrade_choices.size() == 3, "the evolution takes the first card")
	sim.levelup_offer = true
	sim.choose_upgrade(0)
	check(sim.rank_of("storm_soul") == 1 and not sim.available_augments().has("storm_soul"), "an evolution is taken once")
	reset_shots()
	sim.storm_clock = 0
	sim.tick_soul_weapons(1.0 / 60)
	check(sim.projectiles.size() >= 8, "영혼 폭풍 releases a ring of homing shards")
	sim.upgrades["orbit"] = 2
	sim.upgrades["curse"] = 2
	sim.upgrades["bone_crown"] = 1
	sim.tick_soul_weapons(1.0 / 60)
	check(sim.orbit_positions.size() == 4, "해골 왕관 crowns the player with four skulls")

	game.queue_free()
	await process_frame
	print("UPGRADES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
