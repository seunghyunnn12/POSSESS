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
	if modal == "augment" and a.get("fun_mode") != true:
		for id in a.upgrade_choices:
			var item: Dictionary = Augments.DEFINITIONS.get(id, {"name": "", "tag": "", "description": ""})
			var combo_text := ""
			if a.get("plans") != null and a.get("fun_mode") != true:
				for combo in a.COMBOS.values():
					if id in [combo[1], combo[2]]:
						var partner: String = combo[2] if id == combo[1] else combo[1]
						combo_text = tr("COMBO_READY") % Text.data(combo[0]) if a.rank_of(partner) > 0 else tr("COMBO_NEED") % [Text.data(combo[0]), Text.data(Augments.DEFINITIONS[partner].name)]
			state.choices.append({"id": id, "name": Text.data(item.name), "tag": Text.data(item.tag), "description": Text.data(item.description), "effect": Text.effect(id, a.rank_of(id) + 1), "rank": a.rank_of(id) + 1, "combo": combo_text})
	if a.get("fun_mode") == true: fun_snapshot(state)
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
	var values := [tr("NUM") % stats.damage, tr("LIFE_VALUE") % [a.decay if not profile.is_empty() else a.soul, a.decay_max if not profile.is_empty() else (a.soul_max() if a.has_method("soul_max") else 20.0)], tr("NUM") % (1 / stats.interval), tr("PERCENT") % ((1 - stats.damage_taken) * 100), tr("SPEED") % stats.move, tr("NUM") % stats.host_health, tr("SECONDS") % stats.reload if stats.reload > 0 else tr("NA"), tr("PERCENT") % (profile.get("resistance", 0) * 100)]
	var build: Array[String] = []
	for id in a.upgrades:
		if a.rank_of(id) <= 0: continue
		build.append(tr("AUG_OWNED") % [(preload("res://scripts/fun_augments.gd").DATA[id][0] if a.get("fun_mode") == true else Text.data(Augments.DEFINITIONS[id].name)), a.rank_of(id), (preload("res://scripts/fun_augments.gd").effect(id, a.rank_of(id)) if a.get("fun_mode") == true else Text.effect(id, a.rank_of(id)))])
	var data := {"detail_name": (Text.data(profile.get("name", "")) + " " + Text.data(Weapons.info(a.body_kind).name)) if not profile.is_empty() else tr("SOUL"),
		"trait": Text.data(profile.description) if not profile.is_empty() else tr("EMPTY_HOST"), "values": values,
		"iv": tr("IV") % [(profile.get("attack_iv", 1) - 1) * 100, (profile.get("move_iv", 1) - 1) * 100, (profile.get("vitality_iv", 1) - 1) * 100],
		"build": tr("BUILD") % tr("SEPARATOR").join(build) if not build.is_empty() else tr("EMPTY_BUILD"),
		"route": "", "combos": "", "relics": "", "quest": "", "has_journal": a.get("plans") != null and a.get("fun_mode") != true}
	if profile.is_empty() and a.get("ghost_id") != null:
		data.detail_name = tr("GHOST_NAME_" + a.ghost_id.to_upper())
		data.trait = tr("GHOST_DESC_" + a.ghost_id.to_upper())
	if a.get("plans") != null and a.get("fun_mode") != true:
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
	if authority.get("fun_mode") == true and event in ["room_clear", "combat_start", "start", "reinforcements"]: return
	if authority.get("fun_mode") == true and authority.tutorial and event in ["exposed", "inhabit"]: return
	if authority.get("fun_mode") == true and event == "rejected":
		toast_requested.emit("빙의 실패 (확률 %d%%) · 적을 더 약하게 만든 뒤 다시 우클릭" % roundi(maxf(0.0, authority.last_try_chance) * 100))
		return
	if authority.get("fun_mode") == true and event == "tutorial_done":
		toast_requested.emit("튜토리얼 완료 · 이제 문을 지나 탐험하세요")
		return
	if event in ["hit", "weapon_fire", "shot"] and data.get("hit", event == "hit"):
		impact_requested.emit()
	var messages := {"reinforce": "TOAST_REINFORCE", "level_up": "TOAST_LEVELUP", "secret_found": "TOAST_SECRET", "wall_broken": "TOAST_WALL", "blessing": "TOAST_BLESSING", "need_body": "TOAST_NEED_BODY", "sealed": "TOAST_SEALED", "unsealed": "TOAST_UNSEALED", "key_found": "TOAST_KEY", "door_unlocked": "TOAST_DOOR_UNLOCKED", "door_needs_key": "TOAST_NEED_KEY", "purchase": "TOAST_PURCHASE", "too_poor": "TOAST_TOO_POOR", "potion": "TOAST_POTION", "inhabit": "TOAST_INHABIT", "exposed": "TOAST_EXPOSED", "rejected": "TOAST_REJECTED", "unreachable": "TOAST_UNREACHABLE", "soul_focus": "TOAST_FOCUS", "supply": "TOAST_SUPPLY", "room_clear": "TOAST_CLEAR", "reinforcements": "TOAST_WAVE", "loaded": "TOAST_LOADED", "upgrade_chosen": "TOAST_UPGRADE", "milestone": "TOAST_MILESTONE", "element_notice": "TOAST_ELEMENT", "detection": "TOAST_DETECTION", "start": "TOAST_START", "combat_start": "TOAST_COMBAT", "level_ready": "TOAST_LEVEL", "boss_warning": "TOAST_BOSS"}
	if event == "lesson":
		toast_requested.emit(["TRAIN_MOVE", "TRAIN_WEAKEN", "TRAIN_POSSESS", "TRAIN_INSPECT", "TRAIN_SUPPLY", "TRAIN_ATTACK", "TRAIN_EJECT", "TRAIN_DOOR"][data.step])
	elif event == "combat_start" and authority.get("room_index") in [3, 7]:
		toast_requested.emit("BOSS_ENTER_%d" % authority.room_index)
	elif event == "room_clear" and authority.get("room_index") in [3, 7]:
		toast_requested.emit("BOSS_CLEAR_%d" % authority.room_index)
	elif messages.has(event):
		toast_requested.emit(messages[event])

func fun_snapshot(state: Dictionary) -> void:
	var a = authority
	state.fun = true
	state.tutorial_done = a.learned or a.tutorial_finished()
	var map = a.map
	state.map = map
	state.zone = map.zone(a.room_index)
	state.kind = map.kind(a.room_index)
	state.stage = "%d / 3구역 · %s" % [state.zone, map.names[a.room_index - 1]]
	state.hub = state.kind == "hub"
	state.final_room = a.room_index == map.final
	state.zone_ready = false
	state.rewards = a.rewards.duplicate()
	state.enemies = str(a.remaining() + a.spawn_queue.size())
	state.soul = "영혼 Lv.%d · 피해 +%d%% · %d/%d" % [a.level, a.essence * 3, a.xp, a.xp_next]
	state.life = "%.1f / %.0f초" % [a.decay if state.body else a.soul, a.decay_max if state.body else a.soul_max()]
	state.life_fraction = a.decay / maxf(a.decay_max, 0.01) if state.body else a.soul / a.soul_max()
	if state.body and a.magazine_size() > 0: state.ammo = "%d / %d" % [a.ammo, a.magazine_size()]
	state.visited = a.visited.duplicate()
	state.cleared = a.cleared.duplicate()
	state.room = a.room_index
	state.tutorial = a.tutorial
	state.tutorial_step = a.tutorial_step
	state.reward_ready = a.phase == "rest" and not a.rewards[a.room_index - 1]
	state.death_reason = a.death_reason
	state.keys = a.keys
	state.coins = a.coins
	state.treasure = state.kind == "treasure"
	state.morgue = state.kind == "morgue"
	state.potion_used = a.used_potions.has(a.room_index)
	state.relic_count = a.relics.size()
	state.no_host = a.phase == "combat" and a.state == a.State.Soul and not a.tutorial and not a.host_available()
	state.levelup = a.levelup_offer
	state.coach = a.tutorial_text()
	state.level = a.level
	var hint: String = a.context_hint()
	if hint != "" and state.interaction == "": state.interaction = hint
	var aimed = a.aimed_actor()
	if is_instance_valid(aimed) and aimed.has_meta("price"):
		state.interaction = "우클릭 · 뼈 동전 %d로 이 몸 사기" % aimed.get_meta("price") if a.coins >= aimed.get_meta("price") else "뼈 동전 부족 · %d / %d" % [a.coins, aimed.get_meta("price")]
	if is_instance_valid(aimed) and aimed.has_meta("fodder"):
		state.reachable = false
		state.interaction = "굶주린 것 · 빙의 불가"
	state.choices.clear()
	if state.modal == "augment":
		for id in a.upgrade_choices:
			var item: Array = preload("res://scripts/fun_augments.gd").DATA[id]
			var build = preload("res://scripts/fun_augments.gd")
			var card_hint: String = "→ " + item[3] + "에 유리"
			var evo: String = build.evolution_of(id)
			if item[1] == "evo":
				card_hint = "진화 완성 · %s + %s" % [build.DATA[build.EVOLUTIONS[id][0]][0], build.DATA[build.EVOLUTIONS[id][1]][0]]
			elif evo != "":
				var partner: String = build.EVOLUTIONS[evo][1] if build.EVOLUTIONS[evo][0] == id else build.EVOLUTIONS[evo][0]
				card_hint = "진화 재료 · %s (%s와 함께 최대 단계)" % [build.DATA[evo][0], build.DATA[partner][0]]
			state.choices.append({"id": id, "name": item[0], "tag": build.tag(item[1]), "description": item[4], "effect": build.effect(id, a.rank_of(id) + 1), "rank": a.rank_of(id) + 1, "combo": card_hint})
			if id == "mag" and state.body and a.magazine_size() > 0:
				state.choices[-1].effect += " · %d → %d발" % [a.magazine_size(), int(Weapons.info(a.body_kind).magazine * (1 + 0.5 * (a.rank_of(id) + 1)))]
