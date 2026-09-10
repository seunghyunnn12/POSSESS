extends Node3D
const Arena = preload("res://scripts/arena.gd")
const Authority = preload("res://scripts/authority.gd")
const Journey = preload("res://scripts/journey.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Action = preload("res://scripts/action.gd")
const ActionHud = preload("res://scripts/action_hud.gd")
const Presentation = preload("res://scripts/presentation.gd")
const Hud = preload("res://scripts/hud.gd")
const UiPresenter = preload("res://scripts/ui_presenter.gd")
const GhostProgress = preload("res://scripts/ghost_progress.gd")
const Settings = preload("res://scripts/settings.gd")
var settings = Settings.new()
var ghost_progress = GhostProgress.new()
var ui_presenter
var arena
var authority
var presentation
var hud
var player: CharacterBody3D
var camera: Camera3D
var aim := Vector2(0.48, -0.08)
var run_seed := 0
var guided_run := true
var campaign_run := true
var action_run := true
var suppress_fire := false

func _ready() -> void:
	# Script-driven QA must never unlock characters in the player's real profile.
	ghost_progress.load_progress("" if "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args() else "user://ghost_progress.cfg")
	settings.load_preferences("" if "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args() else "user://settings.cfg")
	if not settings.path.is_empty(): settings.apply_display()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed=") and argument.trim_prefix("--seed=").is_valid_int():
			run_seed = int(argument.trim_prefix("--seed="))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena = Arena.new()
	arena.run_seed = run_seed
	arena.layout = "training" if guided_run else "ossuary"
	arena.name = "Arena"
	add_child(arena)
	player = CharacterBody3D.new()
	player.name = "PlayerBody"
	player.collision_layer = 2
	player.collision_mask = 1 | 4
	player.position = Vector3(0, 0.05, 5)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	shape.position.y = 0.85
	shape.shape = capsule
	player.add_child(shape)
	add_child(player)
	authority = ((Action.new() if action_run else Campaign.new()) if campaign_run else Journey.new()) if guided_run else Authority.new()
	if authority is Campaign:
		authority.run_seed = run_seed
	authority.name = "authority"
	add_child(authority)
	authority.configure(player, arena.enemies)
	if authority is Action: authority.select_ghost(ghost_progress.selected, ghost_progress.unlocked)
	authority.yaw = aim.x
	authority.pitch = aim.y
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.near = 0.04
	camera.far = 80.0
	add_child(camera)
	presentation = Presentation.new()
	presentation.name = "Presentation"
	add_child(presentation)
	presentation.setup(authority, camera)
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	hud = ActionHud.new() if authority is Action else Hud.new()
	hud.choice_requested.connect(_choose_upgrade)
	hud.continue_requested.connect(_continue)
	hud.key_requested.connect(_ui_key)
	hud.ghost_requested.connect(_select_ghost)
	layer.add_child(hud)
	ui_presenter = UiPresenter.new()
	add_child(ui_presenter)
	ui_presenter.setup(authority, camera)
	ui_presenter.ghost_progress = ghost_progress
	hud.bind(ui_presenter)
	hud.screens.pause.get_node("Settings").changed.connect(_change_setting)
	hud.screens.pause.get_node("Settings").reset_requested.connect(_reset_settings)
	_apply_settings()
	authority.feedback.connect(_feedback)
	# QA can bypass the title, while normal play always starts deliberately.
	if "--play" in OS.get_cmdline_user_args():
		begin()

func begin() -> void:
	authority.paused = false
	authority.start()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _change_setting(key: String, value: Variant) -> void:
	settings.set_value(key, value)
	settings.save()
	_apply_settings()
	if key in ["fullscreen", "resolution", "vsync"]: settings.apply_display()

func _reset_settings() -> void:
	settings.values = Settings.DEFAULTS.duplicate()
	settings.save()
	_apply_settings()
	settings.apply_display()

func _apply_settings() -> void:
	presentation.sound.master_gain = settings.values.volume / 100.0
	presentation.sound.muted = false
	hud.screens.pause.get_node("Settings").present(settings.values, settings.save_error != OK)

func _select_ghost(id: String) -> void:
	if authority is Action and authority.select_ghost(id, ghost_progress.unlocked):
		ghost_progress.select(id)
		ui_presenter.refresh()
		if ghost_progress.save_error != OK: hud.show_toast("GHOST_SAVE_ERROR")

func _ui_key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	_unhandled_input(event)

func _physics_process(_dt: float) -> void:
	if guided_run and authority.phase == "training" and is_instance_valid(arena.practice_marker):
		arena.practice_marker.position = authority.practice_focus() + Vector3.UP * 0.04
		arena.practice_marker.visible = authority.lesson not in [3, 6] and authority.state != Authority.State.Possessing
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		suppress_fire = false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		authority.clear_input()
		return
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	authority.submit_input(move, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not suppress_fire, aim, Input.is_physical_key_pressed(KEY_F))

func _input(event: InputEvent) -> void:
	# Preserve the existing title shortcut before Control focus navigation uses Tab.
	if authority != null and not authority.running and not authority.paused and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_unhandled_input(event)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if authority is Campaign and event.physical_keycode == KEY_R and not authority.upgrade_choices.is_empty():
			authority.reroll_upgrades()
			return
		if authority is Campaign and event.physical_keycode == KEY_ESCAPE and authority.journal_open:
			authority.journal_open = false
			_sync_mouse()
			return
		if authority is Campaign and event.physical_keycode == KEY_J:
			if not authority.running:
				return
			authority.journal_open = not authority.journal_open
			authority.clear_input()
			_sync_mouse()
			return
		if authority is Campaign and authority.route_pending() and event.physical_keycode in [KEY_1, KEY_2]:
			authority.select_route(event.physical_keycode - KEY_1)
			return
		if not authority.upgrade_choices.is_empty() and not authority.paused and event.physical_keycode in [KEY_1, KEY_2, KEY_3]:
			_choose_upgrade(event.physical_keycode - KEY_1)
			return
		match event.physical_keycode:
			KEY_ENTER:
				_continue()
			KEY_TAB:
				if guided_run and not authority.running:
					authority.skip_training()
					_sync_mouse()
			KEY_ESCAPE:
				authority.paused = not authority.paused
				if guided_run:
					authority.note_inspection()
				authority.clear_input()
				suppress_fire = true
				_sync_mouse()
			KEY_R:
				if authority.outcome != "":
					get_tree().reload_current_scene()
				else:
					authority.request("reload")
			KEY_E:
				authority.request("eject")
			KEY_SHIFT:
				authority.request("dash")
			KEY_SPACE:
				authority.request("jump")
			KEY_M:
				presentation.sound.muted = not presentation.sound.muted
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion and authority.outcome == "" and not authority.is_frozen():
			aim.x = wrapf(aim.x - event.relative.x * 0.0021 * settings.values.sensitivity, -PI, PI)
			aim.y = clampf(aim.y - event.relative.y * 0.0021 * settings.values.sensitivity * (-1.0 if settings.values.invert_y else 1.0), -1.38, 1.38)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			authority.request("possess")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and authority != null and authority.running and authority.outcome == "":
		authority.paused = true
		authority.clear_input()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _feedback(event: String, data: Dictionary) -> void:
	if authority is Action:
		var unlocked_id: String = data.get("id", "") if event == "ghost_unlock" else ""
		if event == "end" and data.get("result", "") == "CLEAR" and authority.room_index == authority.room_total:
			unlocked_id = "gunslinger"
		if unlocked_id != "" and ghost_progress.unlock(unlocked_id):
			hud.show_toast("GHOST_UNLOCK_" + unlocked_id.to_upper())
			if ghost_progress.save_error != OK: hud.show_toast("GHOST_SAVE_ERROR")
	if event == "kick":
		aim = Vector2(authority.yaw, authority.pitch)
	if event == "load_room":
		remove_child(arena)
		arena.queue_free()
		arena = Arena.new()
		arena.layout = "hall" if data.index == 1 else "vault"
		if authority is Campaign:
			arena.layout = authority.room_layout()
			arena.encounter = authority.encounter_spec()
		arena.run_seed = run_seed
		add_child(arena)
		authority.configure(player, arena.enemies)
		if authority is Campaign:
			authority.room_arrived()
		player.position = Vector3(0, 0.05, 5)
		player.velocity = Vector3.ZERO
		aim = Vector2.ZERO
		authority.yaw = 0
		authority.pitch = 0
		hud.target = null
	if event == "lesson" and data.step == 5:
		arena.spawn("brute", Vector3(1, 0.05, -5), 1000)
	if event == "reinforcements":
		arena.spawn_encounter(data.spec, data.get("summoned", false))
	if event in ["end", "upgrade_offer", "upgrade_chosen", "inhabit", "briefing", "combat_start", "travel"]:
		suppress_fire = true
		_sync_mouse()
	if event == "supply":
		arena.supply_lid.rotation.x = -0.6
		arena.supply_glow.hide()

func _continue() -> void:
	if authority.paused:
		return
	if not authority.running:
		begin()
	elif guided_run:
		authority.confirm_ready()
	_sync_mouse()

func _sync_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if authority.is_frozen() or not authority.running or authority.outcome != "" else Input.MOUSE_MODE_CAPTURED

func _choose_upgrade(index: int) -> void:
	authority.choose_upgrade(index)
	suppress_fire = true
	_sync_mouse()
