extends RefCounted

const DATA := {
	"mag": ["넉넉한 탄창", "gun", "탄창 +50% / +100%", "연발병·산탄병", "재장전 전에 더 많은 적을 처리합니다."],
	"pierce": ["관통탄", "gun", "탄환이 적 1명 / 2명 관통", "연발병·산탄병", "앞의 적을 뚫고 뒤의 적까지 맞힙니다."],
	"shockwave": ["충격파", "melee", "근접 범위 +40% / +80%", "망치병", "한 번의 휘두르기로 넓은 무리를 공격합니다."],
	"leech": ["흡수", "melee", "근접 처치 수명 +2초 / +4초", "망치병", "굶주린 것은 회복량 25%. 최대 수명까지만 회복합니다."],
	"quickdraw": ["속사", "bow", "활 충전 시간 −40% / −70%", "서리 궁수", "짧게 당겨도 완전히 충전된 화살을 발사합니다."],
	"deepfreeze": ["동결", "bow", "화살 적중 시 1.2초 / 2초 정지", "서리 궁수", "접근하는 적을 묶고 다음 공격을 준비합니다."],
	"bigblast": ["대폭발", "magic", "화염 폭발 반경 +50% / +100%", "화염 술사", "밀집한 무리와 벽 근처를 노리세요."],
	"chain": ["긴 사슬", "magic", "번개 연쇄 +1명 / +3명", "번개 술사", "가까운 적이 많을수록 한 번의 공격이 강해집니다."],
	"curse": ["유령탄 강화", "neutral", "유령 피해 +25% / +50%", "모든 몸을 찾는 유령", "더 빨리 약화해 다음 몸을 얻습니다."],
	"mercy": ["빙의 확률 증가", "neutral", "빙의 확률 +8%p / +16%p", "모든 몸", "같은 체력에서도 빙의하기 쉬워집니다. 최대 95%."],
	"harvest": ["수확", "neutral", "처치 수명 +0.5초 / +1초", "모든 몸", "굶주린 것은 회복량 25%. 전투로 현재 몸을 유지합니다."],
	"glasscannon": ["유리 몸", "neutral", "피해 +50% / +100% · 수명 −30% / −50%", "빠르게 처치하는 모든 몸", "현재 몸에도 즉시 적용됩니다. 남은 수명 비율은 유지합니다."]
}

static func family(kind: String) -> String:
	return {"soldier": "gun", "shotgun": "gun", "brute": "melee", "archer": "bow", "mage": "magic", "storm": "magic"}.get(kind, "gun")

static func effect(id: String, rank: int) -> String:
	match id:
		"mag": return "탄창 +%d%%" % (rank * 50)
		"pierce": return "탄환이 적 %d명 관통" % rank
		"shockwave": return "근접 범위 +%d%%" % (rank * 40)
		"leech": return "근접 처치 수명 +%d초" % (rank * 2)
		"quickdraw": return "활 충전 시간 −%d%%" % (40 if rank == 1 else 70)
		"deepfreeze": return "화살 적중 시 %.1f초 정지" % (1.2 if rank == 1 else 2.0)
		"bigblast": return "화염 폭발 반경 +%d%%" % (rank * 50)
		"chain": return "번개 연쇄 +%d명" % (1 if rank == 1 else 3)
		"curse": return "유령 피해 +%d%%" % (rank * 25)
		"mercy": return "빙의 확률 +%d%%p" % (rank * 8)
		"harvest": return "처치 수명 +%.1f초" % (rank * 0.5)
		"glasscannon": return "피해 +%d%% · 수명 −%d%%" % [rank * 50, 30 if rank == 1 else 50]
	return ""
