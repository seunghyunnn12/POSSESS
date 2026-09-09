extends "res://tests/journey.gd"
const Weapons = preload("res://scripts/weapons.gd")

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa-output/v05-" + label + ".png")

func inhabit_role(role: String) -> void:
	game.arena.spawn(role, Vector3(5, 0.05, 5), 1000)
	sim.begin_possession(sim.actors[-1])
	sim._physics_process(0.76)
	sim._physics_process(0.66)
	game.player.position = Vector3(0, 0.05, 5)
	sim.shot_left = 0
	sim.clear_input()
	await settle()

func run() -> void:
	game = Main.new()
	game.run_seed = 731
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	sim = game.authority
	sim.set_physics_process(false)
	await settle()
	sim.start()
	sim.advance_lesson(1)
	sim.damage_enemy(sim.actors[0], 70)
	sim.begin_possession(sim.actors[0])
	sim._physics_process(0.76)
	sim._physics_process(0.66)
	check(sim.lesson == 7 and sim.state == Authority.State.Body, "practice only requires weakening and possessing, not eight chores")
	await capture("short-practice")
	game.player.position = Vector3(0, 0.05, -17)
	await settle()
	aim_point(Vector3(0, 1.4, -19))
	sim.leave_room()
	await ticks(80)
	check(sim.phase == "briefing" and sim.state == Authority.State.Body and sim.body_kind == "soldier", "training body survives first doorway")
	await capture("departure")
	sim.confirm_ready()
	for actor in sim.actors: actor.attack_clock = 1000
	sim.gain_xp(200)
	sim.resolve_flow()
	check(sim.pending_levels > 1 and sim.upgrade_choices.is_empty() and sim.upgrade_wait == 0, "multiple levels never open or delay combat")
	var before: float = sim.decay
	sim._physics_process(0.1)
	check(sim.decay < before and not sim.is_frozen(), "combat clock continues after level-up")
	game.arena.spawn("soldier", Vector3(0, 0.05, -2), 1000)
	var dummy = sim.actors[-1]
	dummy.max_hp = 5000
	dummy.hp = 5000
	for role in Weapons.DATA:
		await inhabit_role(role)
		check(sim.body_kind == role and sim.ammo == Weapons.info(role).magazine, "inhabit %s supplies its own weapon and magazine" % role)
		check(is_equal_approx(sim.current_stats().damage, Weapons.info(role).damage), "host stats use %s weapon definition" % role)
		aim_at(dummy)
		if role == "shotgun":
			var hp: float = dummy.hp
			var pitch_before: float = sim.pitch
			sim.attack()
			check(dummy.hp < hp and sim.ammo == 5, "shotgun hits with pellets and spends one shell")
			check(sim.pitch > pitch_before and is_equal_approx(game.aim.y, sim.pitch), "recoil changes actual aim and remains synchronized with input")
			sim.ammo = 0
			sim.begin_reload()
			sim._physics_process(1.7)
			check(sim.ammo == 6, "shotgun reload fills six shells instead of rifle eighteen")
		elif role == "archer":
			var hp: float = dummy.hp
			sim.bow_charge = 0.8
			sim.fire_arrow()
			check(sim.projectiles.size() > 0 and dummy.hp == hp, "arrow travels through world rather than immediate hitscan")
			var position_before: Vector3 = sim.projectiles[-1].at
			sim.paused = true
			sim._physics_process(1)
			check(sim.projectiles[-1].at == position_before, "pause freezes projectile movement")
			sim.paused = false
			await ticks(25)
			check(dummy.hp < hp and dummy.frost_left > 0, "arrow collides and applies frost")
		elif role == "mage":
			var hp: float = dummy.hp
			dummy.frost_left = 2
			sim.attack()
			await ticks(30)
			check(dummy.hp <= hp - 54, "fire projectile creates thermal shock on frozen target")
			sim.element_hit(dummy, 1, "fire")
			hp = dummy.hp
			await ticks(35)
			check(dummy.hp < hp and dummy.burn_left > 0, "fire leaves real damage over time")
		elif role == "storm":
			game.arena.spawn("soldier", Vector3(2, 0.05, -2), 1000)
			var neighbor = sim.actors[-1]
			var hp: float = neighbor.hp
			sim.attack()
			check(neighbor.hp < hp, "lightning chains into another nearby enemy")
		await capture(role)
	await inhabit_role("soldier")
	sim.upgrades.clear()
	sim.eject(false)
	sim._physics_process(0.26)
	sim._physics_process(0.016)
	check(sim.focus_left > 0 and is_equal_approx(Engine.time_scale, 0.25), "body loss creates three real seconds of slow-motion selection")
	var focus: float = sim.focus_left
	sim.paused = true
	sim._physics_process(1)
	check(sim.focus_left == focus, "pause does not consume soul focus")
	sim.paused = false
	await capture("soul-focus")
	sim.begin_possession(dummy)
	check(Engine.time_scale == 1 and sim.focus_left == 0, "possession restores normal time immediately")
	sim._physics_process(0.76)
	sim._physics_process(0.66)
	game.player.position = Vector3(0, 0.05, -19)
	await settle()
	sim.yaw = 0
	sim.pitch = 0
	sim.request("dash")
	sim._physics_process(0.1)
	check(sim.dash_cooldown > 1.5 and game.player.position.z > -20.2, "dash has cooldown and respects wall collision")
	game.arena.spawn("soldier", Vector3(2, 0.05, 2), 1000)
	var victim = sim.actors[-1]
	sim.damage_enemy(victim, 9999)
	check(not victim.alive and victim.visible and victim.collision_layer == 0, "dead enemy remains visible for collapse but cannot block shots")
	for actor in sim.actors.duplicate():
		if actor.alive and not actor.claimed: sim.damage_enemy(actor, 9999)
	sim.check_clear()
	sim.resolve_flow()
	check(sim.phase == "rest" and sim.upgrade_choices.size() > 0, "growth selection waits until entire room clear")
	await capture("room-reward")
	sim.choose_upgrade(0)
	check(sim.upgrade_choices.is_empty() and sim.pending_levels == 0 and sim.upgrades.size() == 1, "one room produces only one choice; surplus growth is automatic")
	check(sim.essence > 0, "surplus experience is preserved as strength")
	sim.ammo = 7
	var host: Dictionary = sim.body_profile.duplicate(true)
	game.player.position = Vector3(0, 0.05, -17)
	await settle()
	aim_point(Vector3(0, 1.4, -19))
	check(sim.can_leave_room() and sim.route_pending(), "optional route menu never blocks ordinary exit")
	sim.leave_room()
	await ticks(82)
	check(sim.room_index == 2 and sim.phase == "combat", "next room flows directly into combat without briefing modal")
	check(sim.state == Authority.State.Body and sim.body_profile == host and sim.ammo == 7, "body identity, traits and magazine survive travel")
	check(sim.projectiles.is_empty(), "old room projectiles do not follow player")
	sim.invulnerable = 0
	sim.decay = 20
	game.player.position = Vector3(0, 0.05, 5)
	sim.hazards.assign([{"kind": "line", "at": Vector3.ZERO, "end": Vector3(0, 0, 10), "radius": 6.0, "left": 0.1, "damage": 4.0}])
	sim.tick_hazards(0.2)
	check(sim.decay < 20, "boss line attack damages inside its strip")
	sim.decay = 20
	game.player.position = Vector3(6, 0.4, 0)
	sim.hazards.assign([{"kind": "ring", "at": Vector3.ZERO, "radius": 6.0, "left": 0.1, "damage": 4.0}])
	sim.tick_hazards(0.2)
	check(sim.decay == 20, "jump height can clear the boss shockwave")
	game.arena.spawn("brute", Vector3(0, 0.05, -10), 1000, "warden")
	var boss = sim.actors[-1]
	sim.hazards.clear()
	sim.boss_pattern = 0
	for pattern in 3:
		sim.boss_clock = 0
		sim.tick_enemy(boss, 0.01)
	check(sim.hazards[0].get("kind") == "line" and sim.hazards[1].get("kind") == "ring" and not sim.hazards[2].has("kind"), "boss alternates line, shockwave and aimed ground strike")
	sim.phase = "rest"
	sim.journal_open = true
	await capture("record")
	game.queue_free()
	await process_frame
	check(Engine.time_scale == 1, "scene disposal restores global time")
	print("ACTION RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
