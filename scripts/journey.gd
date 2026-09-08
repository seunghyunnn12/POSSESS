extends "res://scripts/authority.gd"
## Owns the guided run: safe practice, deliberate room entry, two combat rooms.
const LESSONS := [
	["먼저 움직여 보세요", "W A S D 로 바닥의 빛나는 표시까지 이동하세요.\n마우스를 움직이면 주위를 볼 수 있습니다."],
	["병사를 약하게 만드세요", "빛나는 원 위 병사를 조준하고 좌클릭하세요.\n적의 체력이 낮아질수록 빙의 확률이 올라갑니다."],
	["이제 몸을 빌려 보세요", "병사에게 6m 안으로 다가가 조준한 뒤 우클릭하세요.\n이 연습에서는 충분히 약화한 병사에게 반드시 성공합니다."],
	["당신이 병사가 되었습니다", "Esc를 눌러 빌린 몸의 능력과 특성을 확인하세요.\n읽은 뒤 Esc를 다시 누르면 다음 연습으로 넘어갑니다."],
	["몸이 썩으면 남은 시간이 줄어듭니다", "연습용으로 몸의 수명을 8초 줄였습니다.\n빛나는 상자를 가까이서 조준하고 F를 길게 눌러 회복하세요."],
	["빌린 몸의 무기를 써 보세요", "새로 나타난 표적을 조준하고 좌클릭하세요.\n공격하기 전에는 동료로 보지만, 공격하면 정체가 드러납니다."],
	["몸에서 나와 보세요", "E를 누르면 유령으로 돌아옵니다.\n실전에서 몸의 시간이 다 되면 폭발하며 자동으로 나오게 됩니다."],
	["준비가 되면 문으로 이동하세요", "앞쪽 빛나는 문 가까이에서 F를 길게 누르세요.\n연습방을 떠난 뒤에도 준비를 마쳐야 전투가 시작됩니다."]
]
var phase := "training"
var room_index := 0
var room_total := 2
var lesson := 0
var lesson_age := 0.0
var inspected := false
var settle_left := 0.0
var upgrade_wait := 0.0
var travel_left := 0.0
var room_loaded := false
var gate_hold := 0.0
var room_names := ["깨어나는 방", "첫 번째 전투 · 잊힌 회랑", "두 번째 전투 · 감시자의 묘실"]

func _ready() -> void:
	super._ready()
	possession_duration = 0.75

func is_frozen() -> bool:
	return super.is_frozen() or phase == "briefing" or phase == "travel"

func animation_frozen() -> bool:
	return is_frozen() or settle_left > 0.0 or upgrade_wait > 0.0

func timers_safe() -> bool:
	return phase != "combat"

func _physics_process(dt: float) -> void:
	if not is_multiplayer_authority() or not running or paused or not upgrade_choices.is_empty() or outcome != "":
		return
	if phase == "travel":
		travel_left = maxf(0.0, travel_left - dt)
		if travel_left <= 0.6 and not room_loaded:
			room_loaded = true
			room_index += 1
			clear_input()
			clear_pending = false
			opening = 0.0
			supply_used = false
			detection = 0.0
			reload_left = 0.0
			if room_index == 1:
				state = State.Soul
				body_kind = ""
				body_profile.clear()
				soul = 20.0
				possession_count = 0
				kills = 0
				elapsed = 0.0
			disguised = state == State.Body
			feedback.emit("load_room", {"index": room_index})
		if travel_left <= 0.0:
			phase = "briefing"
			feedback.emit("briefing", {})
		return
	if phase == "briefing":
		return
	if settle_left > 0.0:
		settle_left = maxf(0.0, settle_left - dt)
		clear_input()
		if settle_left == 0.0:
			resolve_flow()
		return
	if upgrade_wait > 0.0:
		upgrade_wait = maxf(0.0, upgrade_wait - dt)
		clear_input()
		if upgrade_wait == 0.0:
			resolve_flow()
		return
	lesson_age += dt
	super._physics_process(dt)
	if phase == "training":
		if lesson == 0 and player.position.distance_to(Vector3(0, 0, 2.8)) < 1.25:
			advance_lesson(1)
		elif lesson == 4 and supply_used:
			advance_lesson(5)
		elif lesson == 6 and state == State.Soul:
			advance_lesson(7)
	if can_leave_room() and intent.interact:
		gate_hold += dt
		if gate_hold >= 0.65:
			leave_room()
	else:
		gate_hold = 0.0

func advance_lesson(next: int) -> void:
	if next <= lesson or next >= LESSONS.size():
		return
	lesson = next
	lesson_age = 0.0
	clear_input()
	if next == 4:
		decay = maxf(1.0, decay_max - 8.0)
	feedback.emit("lesson", {"step": next})

func note_inspection() -> void:
	if phase == "training" and lesson == 3:
		if paused:
			inspected = true
		elif inspected:
			advance_lesson(4)

func practice_focus() -> Vector3:
	match lesson:
		0: return Vector3(0, 0, 2.8)
		1, 2: return actors[0].position
		4: return supply_position - Vector3.UP * 0.6
		5: return actors[-1].position
		7: return Vector3(0, 0, -18.2)
	return player.position

func capture_chance(actor) -> float:
	if phase == "training" and actor == actors[0] and actor.hp <= actor.max_hp * 0.4:
		return 1.0
	return super.capture_chance(actor)

func attempt_possession() -> void:
	if phase == "training" and lesson != 2:
		return
	if settle_left > 0.0 or upgrade_wait > 0.0:
		return
	super.attempt_possession()

func finish_possession() -> void:
	settle_left = 0.65
	super.finish_possession()
	if phase == "training" and lesson == 2 and state == State.Body:
		advance_lesson(3)

func damage_enemy(actor, amount: float) -> void:
	if phase == "training":
		if lesson == 1 and actor == actors[0]:
			super.damage_enemy(actor, minf(amount, maxf(0.0, actor.hp - actor.max_hp * 0.35)))
			if actor.hp <= actor.max_hp * 0.4:
				advance_lesson(2)
		elif lesson == 5 and actor != actors[0]:
			super.damage_enemy(actor, minf(amount, maxf(0.0, actor.hp - 1.0)))
			advance_lesson(6)
		return
	super.damage_enemy(actor, amount)

func attack() -> void:
	if phase == "training" and lesson != 1 and lesson != 5:
		return
	if phase == "rest" or settle_left > 0.0 or upgrade_wait > 0.0:
		return
	super.attack()

func eject(explode: bool) -> void:
	if phase == "training" and lesson != 6:
		return
	super.eject(explode)

func hurt(amount: float) -> void:
	if timers_safe():
		return
	super.hurt(amount)

func tick_enemy(actor, dt: float) -> void:
	if phase != "combat":
		actor.windup = 0.0
		actor.velocity = Vector3.ZERO
		return
	super.tick_enemy(actor, dt)

func reward_host(actor, immediate: bool) -> void:
	if phase == "training":
		return
	super.reward_host(actor, immediate)

func gain_xp(amount: int) -> void:
	var previous_level := level
	super.gain_xp(amount)
	if level > previous_level:
		upgrade_wait = 1.1
		clear_input()
		feedback.emit("level_ready", {})

func check_clear() -> void:
	if phase == "combat":
		super.check_clear()

func resolve_flow() -> void:
	if phase != "combat" or settle_left > 0.0 or upgrade_wait > 0.0:
		return
	super.resolve_flow()

func finish(result: String) -> void:
	if result == "CLEAR" and phase == "combat":
		phase = "rest"
		clear_pending = false
		clear_input()
		feedback.emit("room_clear", {"index": room_index})
		return
	super.finish(result)

func can_leave_room() -> bool:
	if not running or is_frozen() or outcome != "" or not (phase == "rest" or (phase == "training" and lesson == 7)):
		return false
	var delta := Vector3(0, 1.4, -19) - eye()
	return delta.length() < 3.2 and forward().dot(delta.normalized()) > 0.6 and ray(eye(), Vector3(0, 1.4, -19), 1).is_empty()

func leave_room() -> void:
	if not is_multiplayer_authority() or not can_leave_room():
		return
	if room_index >= room_total:
		super.finish("CLEAR")
		return
	begin_travel()

func begin_travel() -> void:
	phase = "travel"
	travel_left = 1.2
	room_loaded = false
	gate_hold = 0.0
	clear_input()
	feedback.emit("travel", {})

func skip_training() -> void:
	if not running and is_multiplayer_authority():
		start()
		begin_travel()

func confirm_ready() -> void:
	if not is_multiplayer_authority() or paused or phase != "briefing":
		return
	phase = "combat"
	invulnerable = maxf(invulnerable, 1.5)
	for actor in actors:
		actor.attack_clock = maxf(actor.attack_clock, 2.5)
	clear_input()
	feedback.emit("combat_start", {})
