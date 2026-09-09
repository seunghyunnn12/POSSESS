extends "res://scripts/hud.gd"
const Weapons = preload("res://scripts/weapons.gd")

func draw_journey() -> void:
	if authority.phase == "training":
		centered("WASD 이동  ·  좌클릭으로 약화  ·  우클릭으로 빙의", 200, 22, mint)
		if authority.lesson >= 3:
			centered("몸을 가진 채 문으로 이동 · 가까이서 F", 240, 21, cream)
		centered("안전한 연습 · Enter 없이 직접 움직여 익히세요", 550, 16, muted)
		return
	draw_expedition()

func draw_expedition() -> void:
	if authority.phase == "briefing":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.035, 0.05, 0.9))
		centered("준비되면 출발하세요", 250, 38, cream)
		centered("몸을 빌려 싸우고, 방을 정리한 뒤 성장합니다.", 320, 22, mint)
		centered("[ Enter / 클릭 ] 출발", 540, 23, mint)
		return
	if authority.phase == "travel":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.03, 0.04, 1 - absf(authority.travel_left - 0.6) / 0.6))
		return
	text_at("Shift 회피  ·  J 기록", Vector2(36, 141), 14, muted)
	text_at("회피 준비" if authority.dash_cooldown <= 0 else "회피 %.1f초" % authority.dash_cooldown, Vector2(36, 166), 14, mint)
	if authority.pending_levels > 0 and authority.phase == "combat":
		text_at("성장 획득 · 방 정리 후 선택", Vector2(466, 695), 13, mint)
	if authority.state == Authority.State.Body:
		var weapon := Weapons.info(authority.body_kind)
		centered(weapon.weapon + " · " + weapon.tip, 582, 17, weapon.color)
		if authority.body_kind == "archer":
			draw_rect(Rect2(580, 465, 120 * authority.bow_charge, 4), weapon.color)
	if authority.focus_left > 0 and authority.state == Authority.State.Soul:
		centered("시간이 느려졌습니다 · 다음 몸을 골라 우클릭", 230, 23, mint)
		draw_arc(Vector2(640, 360), 60, -PI / 2, -PI / 2 + TAU * authority.focus_left / 3, 48, mint, 3, true)
	if authority.phase == "rest":
		centered("방 정리 완료 · 현재 몸 그대로 다음 방으로", 210, 24, mint)
		if authority.route_pending():
			centered("출구 F: 회복하며 진행  ·  2: 더 위험한 길 / 추가 성장", 244, 17, muted)
		if authority.plans[authority.room_index].secret and not authority.secret_taken:
			centered("벽 주변의 작은 금빛 문양에 비밀이 있습니다", 279, 15, orange)
	if authority.can_leave_room():
		centered("[ F 길게 ] " + ("원정 마치기" if authority.room_index == authority.room_total else "몸을 유지하고 다음 방으로"), 535, 21, mint)
		draw_rect(Rect2(540, 548, 200 * authority.gate_hold / 0.65, 4), mint)
	if authority.can_find_secret():
		centered("[ F 길게 ] 유물 획득", 535, 20, orange)
	if authority.wave_wait > 0:
		centered("증원 도착 %.1f" % authority.wave_wait, 230, 22, mint)
	for actor in authority.actors:
		if actor.alive and not actor.claimed and actor.profile.get("boss", false):
			centered(actor.profile.name, 183, 23, orange)
			draw_rect(Rect2(410, 197, 460, 7), Color("33263b"))
			draw_rect(Rect2(410, 197, 460 * actor.hp / actor.max_hp, 7), orange)
			break
	for hazard in authority.hazards:
		if hazard.get("kind", "") == "line":
			var direction: Vector3 = (hazard.end - hazard.at).normalized()
			var side := Vector3(-direction.z, 0, direction.x) * 1.15
			world_line(hazard.at + side, hazard.end + side)
			world_line(hazard.at - side, hazard.end - side)
		else:
			for i in 48:
				var start: Vector3 = hazard.at + Vector3(cos(i * TAU / 48), 0.03, sin(i * TAU / 48)) * hazard.radius
				var end: Vector3 = hazard.at + Vector3(cos((i + 1) * TAU / 48), 0.03, sin((i + 1) * TAU / 48)) * hazard.radius
				world_line(start, end)
	if not authority.hazards.is_empty():
		centered("충격파 · Space 점프 / Shift 회피" if authority.hazards[0].get("kind", "") == "ring" else "붉은 표시를 피하세요 · Shift 회피", 252, 18, orange)
	if authority.banner_left > 0 and authority.phase != "combat":
		centered(authority.banner, 483, 15, mint)
	if authority.state == Authority.State.Possessing:
		centered("새 몸으로", 275, 24, mint)

func world_line(from: Vector3, to: Vector3) -> void:
	if presentation.camera.is_position_behind(from) or presentation.camera.is_position_behind(to): return
	line(presentation.camera.unproject_position(from) * bounds / size, presentation.camera.unproject_position(to) * bounds / size, orange, 3)
