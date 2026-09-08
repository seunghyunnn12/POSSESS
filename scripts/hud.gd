extends Control
## Resolution-independent HUD drawn on a 1280 x 720 design canvas.
const Authority = preload("res://scripts/authority.gd")
const Traits = preload("res://scripts/traits.gd")
const Augments = preload("res://scripts/augments.gd")
signal choice_requested(index: int)
signal continue_requested
var authority
var presentation
var font: Font
var cream := Color("e5eadd")
var muted := Color("7c9398")
var mint := Color("8bffd2")
var orange := Color("ffae79")
var bounds := Vector2(1280, 720)
var target = null
var fps := 0.0
var frame_count := 0
var frame_time := 0.0

func _ready() -> void:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Malgun Gothic"])
	font = system_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(dt: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if authority != null and (not authority.running or authority.get("phase") == "briefing" or not authority.upgrade_choices.is_empty()) and not authority.paused else Control.MOUSE_FILTER_IGNORE
	frame_count += 1
	frame_time += dt
	if frame_time > 0.5:
		fps = frame_count / frame_time
		frame_count = 0
		frame_time = 0.0
	queue_redraw()

func _physics_process(_dt: float) -> void:
	if authority != null and authority.running and not authority.is_frozen():
		target = authority.aimed_actor()

func text_at(value: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_at(value, Vector2((1280.0 - width) * 0.5, y), size, color)

func line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(from, to, color, width, true)

func _draw() -> void:
	if authority == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / bounds)
	if not authority.running:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.04, 0.055, 0.76))
		text_at("AN EXPERIMENT IN BORROWED TIME", Vector2(90, 115), 14, mint)
		text_at("P O S S E S S", Vector2(85, 285), 82, cream)
		text_at("THE BORROWED FLESH", Vector2(92, 329), 24, muted)
		line(Vector2(92, 372), Vector2(420, 372), mint, 2)
		text_at("적의 몸을 빌려, 다음 방으로 살아 나가세요.", Vector2(92, 418), 23, cream)
		text_at("[ ENTER / 클릭 ]  안전한 연습방에서 시작", Vector2(92, 531), 21, mint)
		text_at("[ TAB ]  연습 건너뛰기 · 전투 준비 화면으로", Vector2(92, 575), 16, muted)
		text_at("0.4  /  일곱 구역의 원정 · 비밀 · 조합 · 군주", Vector2(92, 653), 13, muted)
		text_at("ESC  /  정보 · 조작", Vector2(1007, 653), 13, muted)
		if authority.paused:
			draw_pause()
		return
	text_at("P O S S E S S", Vector2(36, 42), 19, cream)
	text_at(authority.room_names[authority.room_index] if authority.get("phase") != null else "01 / THE OSSUARY", Vector2(36, 64), 14, muted)
	text_at("남은 적", Vector2(1125, 36), 13, muted)
	text_at("%02d" % authority.remaining(), Vector2(1160, 65), 25, cream)
	line(Vector2(36, 83), Vector2(1244, 83), Color(0.7, 0.9, 0.85, 0.15))
	var body: bool = authority.state == Authority.State.Body
	var tint := orange if body else mint
	var label: String = ("병사의 몸" if authority.body_kind == "soldier" else "브루트의 몸") if body else "유령"
	var fraction: float = authority.decay / authority.decay_max if body else authority.soul / 20.0
	var seconds: float = authority.decay if body else authority.soul
	text_at(label, Vector2(40, 610), 23, tint)
	text_at("몸의 남은 수명" if body else "유령의 남은 시간", Vector2(40, 637), 13, muted)
	draw_rect(Rect2(40, 652, 320, 7), Color("26373d"))
	draw_rect(Rect2(40, 652, 320 * clampf(fraction, 0, 1), 7), tint if fraction > 0.25 else Color("fa7277"))
	text_at("%04.1fs" % seconds, Vector2(286, 637), 19, cream)
	text_at("빙의 %d회" % authority.possession_count, Vector2(40, 691), 12, muted)
	if body:
		text_at(authority.body_profile.get("name", "일반"), Vector2(40, 580), 14, authority.body_profile.get("color", mint))
		centered("위장 중 · 일반 적은 동료로 인식" if authority.disguised else "정체 노출 · 다른 몸으로 숨어드세요", 117, 16, mint if authority.disguised else orange)
		if authority.detection > 0.0:
			centered("감시자가 영혼을 감지하는 중", 147, 14, Color("d5a0ff"))
			draw_rect(Rect2(520, 157, 240, 5), Color("26373d"))
			draw_rect(Rect2(520, 157, 240 * authority.detection, 5), Color("d5a0ff"))
	text_at("영혼 Lv.%d" % authority.level, Vector2(466, 655), 14, cream)
	text_at("%d / %d" % [authority.xp, authority.xp_next], Vector2(750, 655), 13, muted)
	draw_rect(Rect2(466, 667, 350, 4), Color("26373d"))
	draw_rect(Rect2(466, 667, 350.0 * authority.xp / authority.xp_next, 4), Color("b7adff"))
	if body and authority.body_kind == "soldier":
		text_at("연발총 · 좌클릭", Vector2(1080, 610), 14, muted)
		text_at("%02d" % authority.ammo, Vector2(1098, 655), 40, cream)
		text_at("/ 18", Vector2(1170, 653), 20, muted)
		if authority.reload_left > 0.0:
			text_at("재장전 중", Vector2(1100, 680), 12, orange)
	elif body:
		text_at("망치 · 좌클릭", Vector2(1070, 625), 16, orange)
	else:
		text_at("유령탄 · 좌클릭", Vector2(1070, 625), 16, mint)
	text_at("%03d FPS   /   ESC" % roundi(fps), Vector2(1117, 704), 11, muted)
	# Minimal contextual reticle: availability is shape and color, not instructions.
	var reachable := false
	if is_instance_valid(target):
		reachable = authority.eye().distance_to(target.position + Vector3.UP) <= 6.0
	var center := Vector2(640, 360)
	var reticle := mint if reachable else cream
	draw_circle(center, 2.0, reticle)
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		line(center + axis * 8, center + axis * 14, reticle, 1.5)
	if reachable:
		draw_arc(center, 23, -PI * 0.5, TAU * authority.capture_chance(target) - PI * 0.5, 48, mint, 2, true)
		# A right-button mouse glyph teaches the affordance without tutorial prose.
		draw_style_box(mouse_glyph(), Rect2(664, 375, 14, 21))
		draw_rect(Rect2(672, 377, 4, 7), mint)
	if is_instance_valid(target):
		centered(Traits.host_name(target.kind, target.profile), 413, 15, target.profile.color)
		draw_rect(Rect2(591, 428, 98, 3), Color("29383e"))
		draw_rect(Rect2(591, 428, 98 * target.hp / target.max_hp, 3), reticle)
		centered("빙의 %.1f%%  /  %.1fm" % [authority.capture_chance(target) * 100, authority.eye().distance_to(target.position + Vector3.UP)], 451, 15, reticle)
		if target.profile.special:
			centered("빙의 저항 %d%%" % roundi(target.profile.resistance * 100), 475, 12, muted)
	if authority.can_open_supply():
		centered("[ F 길게 ]  보존제 · 몸의 수명 +8초", 542, 16, mint)
		draw_rect(Rect2(540, 556, 200, 4), Color("26373d"))
		draw_rect(Rect2(540, 556, 200 * minf(authority.opening, 1), 4), mint)
	if presentation.hit_marker > 0.0:
		for v in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			line(center + v * 7, center + v * 13, orange, 2)
	if presentation.notice_left > 0.0:
		centered(presentation.notice, 507, 14, orange)
	if authority.outcome != "":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.04, 0.055, 0.86))
		var won: bool = authority.outcome == "CLEAR"
		centered("여정을 마쳤습니다" if won else "영혼의 시간이 다했습니다", 225, 19, mint if won else orange)
		centered("CLEAR" if won else "DISSOLVED", 330, 78, cream)
		centered("%02d TRANSFERS     /     %02d KILLS     /     %.1fs" % [authority.possession_count, authority.kills, authority.elapsed], 394, 19, muted)
		centered("[ R ]   ANOTHER LIFE", 501, 21, mint)
		centered("ESC · 마지막 몸과 이번 판의 증강 확인", 540, 15, muted)
	if not authority.upgrade_choices.is_empty():
		draw_choices()
	if authority.get("phase") != null and authority.upgrade_choices.is_empty() and authority.outcome == "":
		draw_journey()
	if authority.paused:
		draw_pause()
	if authority.get("journal_open") == true:
		draw_journal()
	if authority.get("plans") != null and authority.outcome != "" and not authority.paused and not authority.journal_open:
		centered("보스 %d / 2 · 비밀 %d · 완성한 조합 %d · 의뢰 %s" % [authority.bosses_defeated, authority.secrets_found, authority.completed_combos.size(), "완료" if authority.quest_complete else "미완료"], 445, 18, cream)
		centered("[ J ] 이번 원정의 경로와 완성한 빌드 보기", 590, 17, mint)

func draw_journey() -> void:
	if authority.get("plans") != null and authority.phase != "training":
		draw_expedition()
		return
	if authority.phase == "training" and authority.state != Authority.State.Possessing:
		panel(Rect2(36, 180, 470, 149))
		text_at("연습 %d / 8 · 시간 제한과 적의 공격 없음" % (authority.lesson + 1), Vector2(54, 205), 13, mint)
		text_at(authority.LESSONS[authority.lesson][0], Vector2(54, 239), 21, cream)
		paragraph(authority.LESSONS[authority.lesson][1], Vector2(54, 270), 432, 15, cream)
		var point: Vector3 = authority.practice_focus() + Vector3.UP * 0.1
		if not presentation.camera.is_position_behind(point) and authority.lesson != 3 and authority.lesson != 6:
			var screen: Vector2 = presentation.camera.unproject_position(point) * bounds / size
			draw_arc(screen, 17, 0, TAU, 32, mint, 2, true)
	if authority.timers_safe():
		text_at("안전 구간 · 남은 시간 유지", Vector2(40, 558), 15, mint)
	if authority.phase == "rest":
		centered("방 정리 완료 · 잠시 쉬어도 괜찮습니다", 200, 26, mint)
		centered("보급과 몸 정보를 확인한 뒤, 앞쪽 빛나는 문으로 이동하세요", 236, 17, cream)
	if authority.can_leave_room():
		centered("[ F 길게 ]  " + ("여정 마치기" if authority.room_index == authority.room_total else "다음 방으로 이동"), 540, 20, mint)
		draw_rect(Rect2(540, 555, 200 * authority.gate_hold / 0.65, 5), mint)
	if authority.upgrade_wait > 0:
		centered("레벨 상승! 곧 증강을 선택합니다 · 시간 정지", 280, 23, mint)
	if authority.state == Authority.State.Possessing:
		centered("영혼이 새 몸으로 들어갑니다", 300, 24, mint)
		var progress: float = 1.0 - authority.transition_left / authority.possession_duration
		for i in 20:
			var direction := Vector2.from_angle(i * TAU / 20.0)
			line(Vector2(640, 360) + direction * (100 + 180 * (1 - progress)), Vector2(640, 360) + direction * 500, Color(0.5, 1, 0.8, sin(progress * PI) * 0.6), 2)
	if authority.phase == "briefing":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.035, 0.05, 0.94))
		centered("전투 준비 · %d / 2" % authority.room_index, 180, 19, mint)
		centered(authority.room_names[authority.room_index], 258, 36, cream)
		centered("적을 약화하고 몸을 빌리세요. 모든 적을 처리하면 출구가 열립니다.", 325, 20, cream)
		centered("유령은 20초, 몸은 남은 수명이 끝나기 전에 갈아타세요.", 365, 18, orange)
		centered("처치 / 첫 빙의 → 경험치 → 시간 정지 후 증강 선택", 405, 18, cream)
		centered("감시자는 위장을 꿰뚫습니다. 기둥 뒤로 시야를 끊으세요." if authority.room_index == 2 else "공격 전에는 위장 상태입니다. 먼저 보급 상자를 찾아도 좋습니다.", 445, 17, mint)
		centered("[ ENTER / 클릭 ]  준비 완료 · 전투 시작", 550, 23, mint)
	if authority.phase == "travel":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.03, 0.04, 1.0 - absf(authority.travel_left - 0.6) / 0.6))

func mouse_glyph() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.06, 0.06, 0.8)
	style.border_color = mint
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

func draw_expedition() -> void:
	text_at("[ J ] 원정 지도 · 의뢰 · 조합 도감", Vector2(36, 142), 15, mint)
	text_at("의뢰 %d / %d · %s" % [authority.quest_progress, authority.quest_goal(), "완료" if authority.quest_complete else "J로 목표 확인"], Vector2(36, 188), 13, muted)
	if authority.room_index > 0:
		text_at("전투 %d / %d차" % [authority.wave, authority.plans[authority.room_index].waves], Vector2(36, 165), 13, muted)
		for actor in authority.actors:
			if actor.alive and not actor.claimed and actor.profile.get("boss", false):
				centered(actor.profile.name + (" · 격노" if actor.hp <= actor.max_hp * 0.5 else ""), 192, 24, orange)
				draw_rect(Rect2(390, 208, 500, 9), Color("33263b"))
				draw_rect(Rect2(390, 208, 500 * actor.hp / actor.max_hp, 9), orange)
				centered("%.0f / %.0f · 체력 20%% 이하에서 빙의 가능" % [actor.hp, actor.max_hp], 242, 14, cream)
				break
	for hazard in authority.hazards:
		var previous := Vector2.ZERO
		for i in 49:
			var point: Vector3 = hazard.at + Vector3(cos(i * TAU / 48) * hazard.radius, 0.04, sin(i * TAU / 48) * hazard.radius)
			if presentation.camera.is_position_behind(point):
				previous = Vector2.ZERO
				continue
			var screen: Vector2 = presentation.camera.unproject_position(point) * bounds / size
			if previous != Vector2.ZERO:
				line(previous, screen, Color("ff7868"), 3)
			previous = screen
	if not authority.hazards.is_empty():
		centered("보스 공격 예고 · 붉은 원 밖으로 이동!", 290, 21, orange)
	if authority.timers_safe():
		text_at("안전 구간 · 남은 시간 유지", Vector2(40, 558), 15, mint)
	if authority.wave_wait > 0:
		centered("잠시 숨 고르기 · %.1f초 뒤 증원 도착" % authority.wave_wait, 275, 24, mint)
	if authority.phase == "rest":
		centered("구역 확보 · 탐험 후 출구로 이동하세요", 200, 24, mint)
		if authority.plans[authority.room_index].secret and not authority.secret_taken:
			centered("비밀의 흔적: %s 벽 근처, 낮게 빛나는 금빛 문양을 찾아보세요" % ("오른쪽" if authority.secret_position.x > 0 else "왼쪽"), 235, 16, orange)
		if authority.route_pending():
			panel(Rect2(295, 268, 690, 148))
			centered("다음 길을 선택하세요 · 선택 후 출구에서 F", 300, 21, cream)
			centered("[ 1 ] 순례자의 회랑 · 다음 방 입장 시 시간 완전 회복", 344, 18, mint)
			centered("[ 2 ] 시련의 보물고 · 적 체력 +35%, 클리어 시 증강 +1", 382, 18, orange)
	if authority.can_leave_room():
		centered("[ F 길게 ] " + ("원정 마치기" if authority.room_index == 7 else "다음 구역으로 이동"), 538, 20, mint)
		draw_rect(Rect2(540, 552, 200 * authority.gate_hold / 0.65, 4), mint)
	if authority.can_find_secret():
		centered("[ F 길게 ] 숨겨진 유물 봉인 해제", 538, 20, orange)
		draw_rect(Rect2(540, 552, 200 * authority.secret_hold, 4), orange)
	if authority.banner_left > 0:
		panel(Rect2(140, 454, 1000, 44))
		centered(authority.banner, 482, 16, mint)
	if authority.upgrade_wait > 0:
		centered("레벨 상승 · 곧 증강 선택 · 시간 정지", 320, 23, mint)
	if authority.state == Authority.State.Possessing:
		centered("영혼이 새 몸으로 들어갑니다", 300, 24, mint)
		var transfer: float = 1 - authority.transition_left / authority.possession_duration
		for i in 20:
			var direction := Vector2.from_angle(i * TAU / 20)
			line(Vector2(640, 360) + direction * (100 + 180 * (1 - transfer)), Vector2(640, 360) + direction * 500, Color(0.5, 1, 0.8, sin(transfer * PI) * 0.6), 2)
	if authority.phase == "briefing":
		draw_rect(Rect2(0, 0, 1280, 720), Color("0a141e"))
		centered("원정 준비 · 시드 %d" % authority.run_seed, 142, 16, mint)
		centered(authority.room_names[authority.room_index], 215, 34, cream)
		var boss: String = authority.plans[authority.room_index].boss
		if boss != "":
			centered("보스는 위장을 알아봅니다. 붉은 원이 터지기 전에 피하세요.", 292, 21, orange)
			centered("체력 절반 이하에서 공격이 빨라집니다. 군주는 세 곳을 동시에 공격합니다.", 332, 18, cream)
			centered("소환병의 몸을 빌려 버티세요. 소환병은 경험치·의뢰 진행을 주지 않습니다.", 372, 18, cream)
			centered("보스도 체력 20% 이하에서는 빙의할 수 있습니다. 승리 보상: 유물.", 412, 18, mint)
		else:
			centered("%d차 전투를 모두 정리하면 출구가 열립니다." % authority.plans[authority.room_index].waves, 292, 23, cream)
			centered("시련 경로 · 적 체력 +35% / 클리어 보상 증강 +1" if authority.plans[authority.room_index].route == 1 else "순례 경로 · 전투 시작 시 현재 몸 또는 유령 시간 완전 회복", 337, 19, mint)
			centered("적 구성과 개체값, 증강 제안, 의뢰와 유물은 원정마다 달라집니다.", 382, 18, cream)
			centered("이 방에는 숨겨진 유물이 있습니다. 전투 후 벽 주변을 살펴보세요." if authority.plans[authority.room_index].secret else "몸을 바꿔도 증강과 유물, 완성한 조합은 유지됩니다.", 422, 18, orange)
		centered("[ J ] 지도 / 조합 보기     [ ENTER / 클릭 ] 전투 시작", 545, 22, mint)
	if authority.phase == "travel":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.03, 0.04, 1 - absf(authority.travel_left - 0.6) / 0.6))

func draw_journal() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("09131d"))
	text_at("원정 기록 · 시드 %d" % authority.run_seed, Vector2(40, 62), 28, cream)
	text_at("시간 정지 · 증강 슬롯 %d / 4 · 두 종류를 모아 조합 완성 · 잔향 공격력 +%d%%" % [authority.upgrades.size(), mini(30, authority.essence * 3)], Vector2(42, 97), 16, mint)
	panel(Rect2(40, 124, 366, 411))
	panel(Rect2(422, 124, 426, 411))
	panel(Rect2(864, 124, 376, 411))
	text_at("군주에게 이르는 길", Vector2(58, 156), 20, cream)
	for i in range(1, 8):
		var status := "✓ " if i < authority.room_index else ("▶ " if i == authority.room_index else "· ")
		text_at(status + authority.room_names[i], Vector2(58, 195 + i * 36), 14, mint if i == authority.room_index else muted)
	text_at("조합 도감", Vector2(441, 156), 20, cream)
	var y := 195.0
	for id in authority.COMBOS:
		var combo: Array = authority.COMBOS[id]
		text_at(("완성 · " if authority.has_combo(id) else "미완성 · ") + combo[0], Vector2(441, y), 19, mint if authority.has_combo(id) else cream)
		text_at("%s [%d] + %s [%d]" % [Augments.DEFINITIONS[combo[1]].name, authority.rank_of(combo[1]), Augments.DEFINITIONS[combo[2]].name, authority.rank_of(combo[2])], Vector2(441, y + 28), 12, muted)
		paragraph(combo[4], Vector2(441, y + 53), 385, 15, orange)
		y += 106
	text_at("발견한 유물", Vector2(882, 156), 20, cream)
	y = 199
	if authority.relics.is_empty():
		paragraph("보스 승리, 비밀 발견, 의뢰 완료로\n유물을 얻습니다. 같은 유물은 중복되지 않습니다.", Vector2(882, y), 335, 15, muted)
	for id in authority.relics:
		text_at(authority.RELICS[id][0], Vector2(882, y), 19, mint)
		paragraph(authority.RELICS[id][1], Vector2(882, y + 27), 337, 14, cream)
		y += 96
	text_at("이번 원정의 의뢰 · " + authority.quest_text(), Vector2(42, 579), 21, cream)
	text_at("%d / %d · %s" % [authority.quest_progress, authority.quest_goal(), "완료! 유물 지급됨" if authority.quest_complete else "보상: 중복 없는 유물 하나"], Vector2(42, 615), 17, mint)
	centered("[ J / ESC ] 돌아가기 · 비밀 %d · 보스 %d / 2" % [authority.secrets_found, authority.bosses_defeated], 684, 19, mint)

func draw_pause() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.035, 0.05, 0.96))
	text_at("빌린 몸, 남아 있는 영혼", Vector2(42, 72), 32, cream)
	text_at("시간 정지 · 전투와 부패가 멈췄습니다", Vector2(43, 98), 14, mint)
	panel(Rect2(40, 122, 738, 493))
	panel(Rect2(800, 122, 440, 493))
	var stats: Dictionary = authority.current_stats()
	var has_body: bool = not authority.body_profile.is_empty()
	var individual: Dictionary = authority.body_profile
	text_at("현재 몸" if has_body else "현재 상태", Vector2(63, 152), 13, muted)
	text_at(Traits.host_name(authority.body_kind, individual) if has_body else "유령 · 아직 빌린 몸이 없습니다", Vector2(63, 188), 27, individual.get("color", mint))
	paragraph(individual.get("description", "약한 저주탄으로 적을 약화하고 몸을 빌립니다. 유령의 능력은 이번 판의 증강에 따라 성장합니다."), Vector2(63, 216), 680, 15, cream)
	line(Vector2(63, 257), Vector2(752, 257), Color("294049"))
	var status := "위장 중" if authority.disguised else "정체 노출"
	if authority.state == Authority.State.Possessing:
		status = "빙의 전환 중 · 완료 후 새 몸 적용"
	elif authority.state == Authority.State.Ejecting:
		status = "이탈 중 · 유령으로 복귀 중"
	elif not has_body:
		status = "유령"
	stat_row("신분", status, Vector2(63, 285), 285)
	stat_row("현재 공격 피해", "%.1f" % stats.damage, Vector2(63, 322), 285)
	stat_row("공격 속도", "초당 %.2f회" % (1.0 / stats.interval), Vector2(63, 359), 285)
	stat_row("이동 속도", "%.2f m/s" % stats.move, Vector2(63, 396), 285)
	stat_row("재장전", "%.2f초" % stats.reload if has_body and authority.body_kind == "soldier" else "해당 없음", Vector2(63, 433), 285)
	stat_row("남은 부패" if has_body else "남은 소멸", "%.1f / %.1f초" % [authority.decay if has_body else authority.soul, authority.decay_max if has_body else 20], Vector2(429, 285), 295)
	stat_row("피격 부패 감소", "%d%%" % roundi((1.0 - stats.damage_taken) * 100) if has_body else "해당 없음", Vector2(429, 322), 295)
	stat_row("원래 적의 체력", "%.1f" % stats.host_health if has_body else "—", Vector2(429, 359), 295)
	stat_row("개체 빙의 저항", "%d%%" % roundi(individual.get("resistance", 0.0) * 100) if has_body else "—", Vector2(429, 396), 295)
	stat_row("위장 첫 공격", "+%d%%" % (authority.rank_of("ambush") * 60) if has_body else "해당 없음", Vector2(429, 433), 295)
	line(Vector2(63, 455), Vector2(752, 455), Color("294049"))
	text_at("개체 수치 · 같은 종류의 기준 대비", Vector2(63, 483), 13, muted)
	if has_body:
		text_at("공격 %+.1f%%     이동 %+.1f%%     활력 %+.1f%%" % [(individual.attack_iv - 1) * 100, (individual.move_iv - 1) * 100, (individual.vitality_iv - 1) * 100], Vector2(63, 514), 17, cream)
	else:
		text_at("몸을 빌리면 개체 수치와 특성을 확인할 수 있습니다.", Vector2(63, 514), 16, muted)
	paragraph("공격 수치는 개체와 증강을 반영합니다. 위장 첫 공격 보너스는 별도입니다. 몸은 갈아타면 바뀌며, 유령의 증강은 유지됩니다.", Vector2(63, 550), 675, 13, muted)
	text_at("이번 판의 영혼", Vector2(824, 159), 21, cream)
	text_at("Lv.%d   ·   경험치 %d / %d" % [authority.level, authority.xp, authority.xp_next], Vector2(824, 188), 14, mint)
	var y := 223.0
	if authority.upgrades.is_empty():
		paragraph("아직 증강이 없습니다. 처치하거나 처음 빙의한 적에게서 영혼 조각을 얻습니다.", Vector2(824, y), 385, 14, muted)
	for id in authority.upgrades:
		text_at(Augments.description(id, authority.rank_of(id)) + " · " + Augments.effect(id, authority.rank_of(id)), Vector2(824, y), 13, Color("c6baff"))
		y += 23
	line(Vector2(824, 367), Vector2(1216, 367), Color("294049"))
	text_at("조작", Vector2(824, 399), 18, cream)
	var rows := ["WASD 이동 · 마우스 시점", "좌클릭 공격 · 우클릭 빙의", "F 길게 보급품 · E 몸 이탈", "R 재장전 / 결과 화면에서 재시작", "Space 점프 · M 효과음 켜기/끄기"]
	for i in rows.size():
		text_at(rows[i], Vector2(824, 433 + i * 29), 14, muted)
	centered("[ ESC ]  증강 선택으로 돌아가기" if not authority.upgrade_choices.is_empty() else "[ ESC ]  돌아가기", 667, 20, mint)

func stat_row(label: String, value: String, pos: Vector2, width: float) -> void:
	text_at(label, pos, 14, muted)
	var value_size := 15 if value.length() < 20 else 11
	var value_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x
	text_at(value, pos + Vector2(width - value_width, 0), value_size, cream)

func paragraph(value: String, pos: Vector2, width: float, font_size: int, color: Color) -> void:
	draw_multiline_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, -1, color)

func panel(rect: Rect2, accent: Color = Color("294049")) -> void:
	draw_rect(rect, Color("101f29"))
	draw_rect(rect, accent, false, 1)

func card_rect(index: int) -> Rect2:
	return Rect2(48 + index * 404, 218, 376, 374)

func draw_choices() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.035, 0.05, 0.97))
	centered("영혼이 기억하는 힘", 125, 38, cream)
	centered("Lv.%d  ·  몸을 바꿔도 남는 증강을 선택하세요" % authority.level, 166, 17, Color("c6baff"))
	centered("시간 정지 · 클릭 또는 1 / 2 / 3", 198, 14, muted)
	if authority.get("plans") != null:
		centered("증강 슬롯 %d / 4 · [ R ] 다시 제안 %d회 남음" % [authority.upgrades.size(), authority.rerolls], 76, 16, mint)
	var pointer := get_local_mouse_position() * bounds / size
	for i in authority.upgrade_choices.size():
		var id: String = authority.upgrade_choices[i]
		var data: Dictionary = Augments.DEFINITIONS[id]
		var rect := card_rect(i)
		var hover := rect.has_point(pointer)
		panel(rect, mint if hover else Color("3f405c"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), mint if hover else Color("b1a0e7"))
		var pos := rect.position + Vector2(23, 40)
		text_at("0%d  /  %s" % [i + 1, data.tag], pos, 14, muted)
		text_at(data.name, pos + Vector2(0, 55), 28, cream)
		text_at("%d 단계" % (authority.rank_of(id) + 1), pos + Vector2(0, 85), 14, Color("c6baff"))
		if authority.get("plans") != null:
			for combo in authority.COMBOS.values():
				if id in [combo[1], combo[2]]:
					var partner: String = combo[2] if id == combo[1] else combo[1]
					text_at("조합: " + combo[0] + " / " + ("선택하면 완성!" if authority.rank_of(partner) > 0 else Augments.DEFINITIONS[partner].name + " 필요"), pos + Vector2(0, 105), 11, mint)
		paragraph(data.description, pos + Vector2(0, 126), 328, 14, cream)
		paragraph(Augments.preview(id, authority.rank_of(id)), pos + Vector2(0, 199), 328, 16, mint)
		text_at("적용 후: " + Augments.effect(id, authority.rank_of(id) + 1), pos + Vector2(0, 271), 13, Color("c6baff"))
		text_at("[ %d ]  선택" % (i + 1), pos + Vector2(0, 310), 16, mint)
	centered("[ ESC ]  현재 몸과 증강 확인 · 증강은 다음 방에도 유지됩니다", 635, 16, mint)
	if authority.clear_pending:
		centered("방 정리가 끝났습니다. 선택을 마친 뒤 출구로 이동하세요.", 674, 14, muted)

func _gui_input(event: InputEvent) -> void:
	if authority != null and not authority.paused and (not authority.running or authority.get("phase") == "briefing"):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = event.position * bounds / size
			if Rect2(80, 490, 1120, 75).has_point(point):
				continue_requested.emit()
				accept_event()
		return
	if authority == null or authority.paused or authority.upgrade_choices.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer: Vector2 = event.position * bounds / size
		for i in authority.upgrade_choices.size():
			if card_rect(i).has_point(pointer):
				choice_requested.emit(i)
				accept_event()
				return
