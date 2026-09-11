extends Node
## Read-only adapter: existing feedback + snapshots become UI signals.
## No simulation mutation, input submission, RNG, or gameplay timers here.
const Authority = preload("res://scripts/authority.gd")
const Weapons = preload("res://scripts/weapons.gd")
const Augments = preload("res://scripts/augments.gd")
const Text = preload("res://scripts/ui_text.gd")
signal snapshot_changed(state: Dictionary)
signal toast_requested(key: String)
signal impact_requested
var authority
var ghost_progress
var camera: Camera3D
var details_key := ""
var details: Dictionary = {}

func setup(source, view: Camera3D) -> void:
	authority = source
	camera = view
	authority.feedback.connect(on_feedback)

func _process(_dt: float) -> void:
	if authority != null: refresh()

func room_name(index: int) -> String:
	if authority.get("plans") != null and index > 0:
		var plan: Dictionary = authority.plans[index]
		return tr("ROOM_" + (plan.boss if plan.boss != "" else plan.layout).to_upper())
	if authority.get("phase") != null:
		return tr("ROOM_TRAINING") if index == 0 else tr("ROOM_HALL" if index == 1 else "ROOM_VAULT")
	return tr("ROOM_OSSUARY")

func refresh() -> void:
	var a = authority
	var phase: String = a.get("phase") if a.get("phase") != null else "combat"
	var journal: bool = a.get("journal_open") == true
	var body: bool = a.state == Authority.State.Body
	var modal := "pause" if a.paused or journal else ("title" if not a.running or phase == "briefing" or a.outcome != "" else ("augment" if not a.upgrade_choices.is_empty() else ""))
	var index: int = a.get("room_index") if a.get("room_index") != null else 1
	var total: int = a.get("room_total") if a.get("room_total") != null else 1
	var weapon := Weapons.info(a.body_kind)
	var state := {"modal": modal, "phase": phase, "running": a.running, "outcome": a.outcome,
		"body": body, "kind": a.body_kind, "stage": tr("ROOM_NUMBER") % [index, total, room_name(index)], "enemies": "%02d" % a.remaining(),
		"host": Text.data(weapon.name) if body else tr("SOUL"), "life": tr("SECONDS") % (a.decay if body else a.soul),
		"life_fraction": a.decay / maxf(a.decay_max, 0.01) if body else a.soul / 20.0,
		"weapon": Text.data(weapon.weapon) if body else tr("GHOST_WEAPON"),
		"ammo": (tr("AMMO") % [a.ammo, weapon.magazine]) if body and weapon.magazine > 0 else tr("UNLIMITED"),
		"reload": 1.0 - a.reload_left / maxf(a.current_stats().reload, 0.01) if a.reload_left > 0 else 0.0,
		"soul": tr("SOUL_LEVEL") % [a.level, a.xp, a.xp_next], "xp": float(a.xp) / maxf(a.xp_next, 1),
		"interaction": "", "hold": 0.0, "reachable": false, "chance": 0.0, "target_hp": -1.0,
		"hazards": [], "travel": clampf(1 - absf(a.get("travel_left") - 0.6) / 0.6, 0, 1) if phase == "travel" else 0.0,
		"journal": journal, "choices": [], "rerolls": a.get("rerolls") if a.get("rerolls") != null else -1,
		"end_stats": tr("END_STATS") % [a.possession_count, a.kills, a.elapsed]}
	state.ghost_selection = a.get("ghost_id") != null and not a.running
	state.ghost_id = a.get("ghost_id") if a.get("ghost_id") != null else "wanderer"
	state.ghost_unlocked = ghost_progress.unlocked.duplicate() if ghost_progress != null else ["wanderer"]
	state.ghost_save_failed = ghost_progress != null and ghost_progress.save_error != OK
	state.ghost_charge = a.get("ghost_charge") if a.get("ghost_charge") != null else 0.0
	state.chapter = index
	state.end_build = tr("STORY_BUILD") % [tr("GHOST_NAME_" + state.ghost_id.to_upper()), a.upgrades.size(), a.get("completed_combos").size() if a.get("completed_combos") != null else 0]
	state.passage_index = index + (0 if a.get("room_loaded") == true else 1)
	if not body and a.get("ghost_id") != null:
		state.host = tr("GHOST_NAME_" + state.ghost_id.to_upper())
		state.weapon = tr("GHOST_ATTACK_" + state.ghost_id.to_upper())
	if modal == "":
		if a.has_method("can_leave_room") and a.can_leave_room():
			state.interaction = tr("DOOR_END" if index == total else "DOOR")
			state.hold = a.gate_hold / 0.65
		elif a.has_method("can_find_secret") and a.can_find_secret():
			state.interaction = tr("SECRET")
			state.hold = a.secret_hold
		elif a.can_open_supply():
			state.interaction = tr("SUPPLY")
			state.hold = a.opening
		var target = a.aimed_actor()
		if is_instance_valid(target):
			state.reachable = a.eye().distance_to(target.position + Vector3.UP) <= 6.0
			state.chance = a.capture_chance(target)
			state.target_hp = target.hp / target.max_hp
		if a.get("hazards") != null:
			for hazard in a.hazards:
				var segments: Array = []
				if hazard.get("kind", "") == "line":
					var direction: Vector3 = (hazard.end - hazard.at).normalized()
					var side := Vector3(-direction.z, 0, direction.x) * 1.15
					project_segment(segments, hazard.at + side, hazard.end + side)
					project_segment(segments, hazard.at - side, hazard.end - side)
				else:
					for i in 48:
						project_segment(segments, hazard.at + Vector3(cos(i * TAU / 48), 0.04, sin(i * TAU / 48)) * hazard.radius, hazard.at + Vector3(cos((i + 1) * TAU / 48), 0.04, sin((i + 1) * TAU / 48)) * hazard.radius)
				state.hazards.append_array(segments)
	if modal == "augment":
		for id in a.upgrade_choices:
			var item: Dictionary = Augments.DEFINITIONS[id]
			var combo_text := ""
			if a.get("plans") != null:
				for combo in a.COMBOS.values():
					if id in [combo[1], combo[2]]:
						var partner: String = combo[2] if id == combo[1] else combo[1]
						combo_text = tr("COMBO_READY") % Text.data(combo[0]) if a.rank_of(partner) > 0 else tr("COMBO_NEED") % [Text.data(combo[0]), Text.data(Augments.DEFINITIONS[partner].name)]
			state.choices.append({"id": id, "name": Text.data(item.name), "tag": Text.data(item.tag), "description": Text.data(item.description), "effect": Text.effect(id, a.rank_of(id) + 1), "rank": a.rank_of(id) + 1, "combo": combo_text})
	if modal == "pause":
		var key := str([a.body_kind, a.get("ghost_id"), a.body_profile, a.upgrades, a.state, a.decay, a.soul, a.get("relics"), a.get("quest_progress"), index, TranslationServer.get_locale()])
		if key != details_key:
			details_key = key
			details = make_details(index)
		state.merge(details)
	snapshot_changed.emit(state)

func project_segment(out: Array, from: Vector3, to: Vector3) -> void:
	if camera.is_position_behind(from) or camera.is_position_behind(to): return
	var viewport_size := camera.get_viewport().get_visible_rect().size
	out.append([camera.unproject_position(from) * Vector2(1280, 720) / viewport_size, camera.unproject_position(to) * Vector2(1280, 720) / viewport_size])

func make_details(index: int) -> Dictionary:
	var a = authority
	var stats: Dictionary = a.current_stats()
	var profile: Dictionary = a.body_profile
	var values := [tr("NUM") % stats.damage, tr("LIFE_VALUE") % [a.decay if not profile.is_empty() else a.soul, a.decay_max if not profile.is_empty() else 20], tr("NUM") % (1 / stats.interval), tr("PERCENT") % ((1 - stats.damage_taken) * 100), tr("SPEED") % stats.move, tr("NUM") % stats.host_health, tr("SECONDS") % stats.reload if stats.reload > 0 else tr("NA"), tr("PERCENT") % (profile.get("resistance", 0) * 100)]
	var build: Array[String] = []
	for id in a.upgrades:
		build.append(tr("AUG_OWNED") % [Text.data(Augments.DEFINITIONS[id].name), a.rank_of(id), Text.effect(id, a.rank_of(id))])
	var data := {"detail_name": (Text.data(profile.get("name", "")) + " " + Text.data(Weapons.info(a.body_kind).name)) if not profile.is_empty() else tr("SOUL"),
		"trait": Text.data(profile.description) if not profile.is_empty() else tr("EMPTY_HOST"), "values": values,
		"iv": tr("IV") % [(profile.get("attack_iv", 1) - 1) * 100, (profile.get("move_iv", 1) - 1) * 100, (profile.get("vitality_iv", 1) - 1) * 100],
		"build": tr("BUILD") % tr("SEPARATOR").join(build) if not build.is_empty() else tr("EMPTY_BUILD"),
		"route": "", "combos": "", "relics": "", "quest": "", "has_journal": a.get("plans") != null}
	if profile.is_empty() and a.get("ghost_id") != null:
		data.detail_name = tr("GHOST_NAME_" + a.ghost_id.to_upper())
		data.trait = tr("GHOST_DESC_" + a.ghost_id.to_upper())
	if a.get("plans") != null:
		data.route = tr("ROUTE_TITLE") + "\n\n"
		for i in range(1, 8):
			data.route += tr("ROUTE_ROW") % [tr("ROUTE_DONE" if i < index else ("ROUTE_CURRENT" if i == index else "ROUTE_FUTURE")), i, room_name(i)] + "\n\n"
		data.combos = tr("COMBOS_TITLE") + "\n\n"
		for id in a.COMBOS:
			var c: Array = a.COMBOS[id]
			data.combos += tr("COMBO_ROW") % [tr("ROUTE_DONE" if a.has_combo(id) else "ROUTE_FUTURE"), Text.data(c[0]), Text.data(c[3]), Text.data(c[4])] + "\n"
		data.relics = tr("RELICS_TITLE") + "\n\n"
		for id in a.relics: data.relics += tr("RELIC_ROW") % [Text.data(a.RELICS[id][0]), Text.data(a.RELICS[id][1])] + "\n"
		if a.relics.is_empty(): data.relics += tr("EMPTY_RELICS")
		data.quest = tr("QUEST") % [Text.data(a.quest_text()), a.quest_progress, a.quest_goal(), tr("QUEST_DONE" if a.quest_complete else "QUEST_REWARD")]
	return data

func on_feedback(event: String, data: Dictionary) -> void:
	if event in ["hit", "weapon_fire", "shot"] and data.get("hit", event == "hit"):
		impact_requested.emit()
	var messages := {"inhabit": "TOAST_INHABIT", "exposed": "TOAST_EXPOSED", "rejected": "TOAST_REJECTED", "unreachable": "TOAST_UNREACHABLE", "soul_focus": "TOAST_FOCUS", "supply": "TOAST_SUPPLY", "room_clear": "TOAST_CLEAR", "reinforcements": "TOAST_WAVE", "loaded": "TOAST_LOADED", "upgrade_chosen": "TOAST_UPGRADE", "milestone": "TOAST_MILESTONE", "element_notice": "TOAST_ELEMENT", "detection": "TOAST_DETECTION", "start": "TOAST_START", "combat_start": "TOAST_COMBAT", "level_ready": "TOAST_LEVEL", "boss_warning": "TOAST_BOSS"}
	if event == "lesson":
		toast_requested.emit(["TRAIN_MOVE", "TRAIN_WEAKEN", "TRAIN_POSSESS", "TRAIN_INSPECT", "TRAIN_SUPPLY", "TRAIN_ATTACK", "TRAIN_EJECT", "TRAIN_DOOR"][data.step])
	elif event == "combat_start" and authority.get("room_index") in [3, 7]:
		toast_requested.emit("BOSS_ENTER_%d" % authority.room_index)
	elif event == "room_clear" and authority.get("room_index") in [3, 7]:
		toast_requested.emit("BOSS_CLEAR_%d" % authority.room_index)
	elif messages.has(event):
		toast_requested.emit(messages[event])
