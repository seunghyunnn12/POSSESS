extends RefCounted
## Level-up pool. Each entry: [name, group, short effect, who it favours, description].
## Groups: gun / melee / bow / magic (the borrowed body's weapon), soul (the ghost's
## own shot), neutral (survival), weapon (soul weapons that follow you between bodies),
## evo (evolutions: offered once both ingredients are at max rank).

const DATA := {
	# Borrowed-body weapons
	"mag": ["넉넉한 탄창", "gun", "탄창 +50% / +100%", "연발병·산탄병", "재장전 전에 더 많은 적을 처리합니다."],
	"pierce": ["관통탄", "gun", "탄환이 적 1명 / 2명 관통", "연발병·산탄병", "앞의 적을 뚫고 뒤의 적까지 맞힙니다."],
	"rapid": ["빠른 손", "gun", "총기 연사 속도 +20% / +40%", "연발병·산탄병", "같은 시간에 더 많은 탄을 쏟아냅니다."],
	"shockwave": ["충격파", "melee", "근접 범위 +40% / +80%", "망치병", "한 번의 휘두르기로 넓은 무리를 공격합니다."],
	"leech": ["흡수", "melee", "근접 처치 수명 +2초 / +4초", "망치병", "굶주린 것은 회복량 25%. 최대 수명까지만 회복합니다."],
	"bulwark": ["철벽", "melee", "근접 몸 피격 손실 −30% / −60%", "망치병", "무리 한가운데로 뛰어들어도 몸이 버팁니다."],
	"quickdraw": ["속사", "bow", "활 충전 시간 −40% / −70%", "서리 궁수", "짧게 당겨도 완전히 충전된 화살을 발사합니다."],
	"deepfreeze": ["동결", "bow", "화살 적중 시 1.2초 / 2초 정지", "서리 궁수", "접근하는 적을 묶고 다음 공격을 준비합니다."],
	"volley": ["쌍시", "bow", "화살 +1발 / +2발", "서리 궁수", "부채꼴로 여러 발을 동시에 날립니다."],
	"bigblast": ["대폭발", "magic", "화염 폭발 반경 +50% / +100%", "화염 술사", "밀집한 무리와 벽 근처를 노리세요."],
	"chain": ["긴 사슬", "magic", "번개 연쇄 +1명 / +3명", "번개 술사", "가까운 적이 많을수록 한 번의 공격이 강해집니다."],
	"wildfire": ["들불", "magic", "화상이 3m / 5m 안 적에게 번짐", "화염 술사", "불붙은 적 하나가 무리 전체를 태웁니다."],
	# The ghost's own shot
	"curse": ["유령탄 강화", "soul", "유령 피해 +25% / +50%", "몸이 없을 때", "더 빨리 약화해 다음 몸을 얻습니다."],
	"s_split": ["영혼 분열", "soul", "영혼탄 +1발 / +2발", "몸이 없을 때", "영혼탄이 부채꼴로 갈라져 나갑니다."],
	"s_pierce": ["꿰뚫는 영혼", "soul", "영혼탄이 1명 / 3명 관통", "몸이 없을 때", "줄지어 오는 무리를 한 번에 약화합니다."],
	"s_seek": ["추적하는 영혼", "soul", "영혼탄이 적을 약하게 / 강하게 추적", "몸이 없을 때", "대충 쏴도 가까운 적에게 휘어 들어갑니다."],
	"s_rate": ["영혼 연사", "soul", "영혼탄 발사 간격 −20% / −40%", "몸이 없을 때", "유령 상태에서 더 빠르게 쏩니다."],
	"soul_time": ["질긴 영혼", "soul", "유령 시간 +5초 / +10초", "몸이 없을 때", "몸을 잃어도 다음 몸을 찾을 여유가 생깁니다."],
	"wraith": ["유령 걸음", "soul", "유령 이동 속도 +20% / +40%", "몸이 없을 때", "무리 사이를 빠져나가 다음 몸에 닿습니다."],
	# Survival, any body
	"mercy": ["빙의 확률 증가", "neutral", "빙의 확률 +8%p / +16%p", "모든 몸", "같은 체력에서도 빙의하기 쉬워집니다. 최대 95%."],
	"harvest": ["수확", "neutral", "처치 수명 +0.5초 / +1초", "모든 몸", "굶주린 것은 회복량 25%. 전투로 현재 몸을 유지합니다."],
	"glasscannon": ["유리 몸", "neutral", "피해 +50% / +100% · 수명 −30% / −50%", "빠르게 처치하는 모든 몸", "현재 몸에도 즉시 적용됩니다. 남은 수명 비율은 유지합니다."],
	"vigor": ["질긴 몸", "neutral", "몸 수명 +20% / +40%", "모든 몸", "마음에 든 몸을 더 오래 씁니다."],
	"embalm": ["방부", "neutral", "새 몸 수명 +5초 / +10초", "자주 갈아타는 모든 몸", "빙의할 때마다 수명을 더 얹어 시작합니다."],
	"funeral": ["장례", "neutral", "몸 폭발 피해 +40% / +80% · 2단계: E로 나와도 폭발", "몸을 버리는 플레이", "다 쓴 몸을 무리 한가운데서 터뜨리세요."],
	# Soul weapons: they follow the soul from body to body
	"orbit": ["맴도는 해골", "weapon", "해골 1개 / 2개가 주위를 돌며 피해", "모든 몸과 유령", "새 무기. 몸을 바꿔도 따라다닙니다."],
	"lance": ["영혼 창", "weapon", "2.4초 / 1.4초마다 가까운 적에게 관통 창", "모든 몸과 유령", "새 무기. 조준하지 않아도 자동으로 발사됩니다."],
	# Evolutions
	"storm_soul": ["영혼 폭풍", "evo", "2초마다 추적 영혼탄 8발 방출", "진화", "영혼 분열과 추적하는 영혼이 하나가 되었습니다."],
	"bone_crown": ["해골 왕관", "evo", "해골 4개 · 해골 피해 2배", "진화", "맴도는 해골이 유령탄의 저주를 입었습니다."],
	"undying": ["썩지 않는 껍데기", "evo", "몸 부패 속도 절반 · 처치 회복 2배", "진화", "질긴 몸과 수확이 하나가 되었습니다."],
}

## Evolution -> its two ingredients (both must be at max rank).
const EVOLUTIONS := {"storm_soul": ["s_split", "s_seek"], "bone_crown": ["orbit", "curse"], "undying": ["vigor", "harvest"]}
## Shot shaping only makes sense for ghosts that fire projectiles.
const PROJECTILE_ONLY := ["s_split", "s_pierce", "s_seek", "storm_soul"]

static func family(kind: String) -> String:
	return {"soldier": "gun", "shotgun": "gun", "brute": "melee", "archer": "bow", "mage": "magic", "storm": "magic"}.get(kind, "gun")

static func max_rank(id: String) -> int:
	return 1 if DATA[id][1] == "evo" else 2

static func evolution_of(id: String) -> String:
	for evo in EVOLUTIONS:
		if id in EVOLUTIONS[evo]: return evo
	return ""

static func tag(group: String) -> String:
	return {"gun": "총기", "melee": "근접", "bow": "활", "magic": "마법", "soul": "유령", "neutral": "생존", "weapon": "새 무기", "evo": "진화"}[group]

static func effect(id: String, rank: int) -> String:
	match id:
		"mag": return "탄창 +%d%%" % (rank * 50)
		"pierce": return "탄환이 적 %d명 관통" % rank
		"rapid": return "총기 연사 속도 +%d%%" % (rank * 20)
		"shockwave": return "근접 범위 +%d%%" % (rank * 40)
		"leech": return "근접 처치 수명 +%d초" % (rank * 2)
		"bulwark": return "근접 몸 피격 손실 −%d%%" % (rank * 30)
		"quickdraw": return "활 충전 시간 −%d%%" % (40 if rank == 1 else 70)
		"deepfreeze": return "화살 적중 시 %.1f초 정지" % (1.2 if rank == 1 else 2.0)
		"volley": return "화살 +%d발" % rank
		"bigblast": return "화염 폭발 반경 +%d%%" % (rank * 50)
		"chain": return "번개 연쇄 +%d명" % (1 if rank == 1 else 3)
		"wildfire": return "화상이 %dm 안 적에게 번짐" % (3 if rank == 1 else 5)
		"curse": return "유령 피해 +%d%%" % (rank * 25)
		"s_split": return "영혼탄 +%d발" % rank
		"s_pierce": return "영혼탄 %d명 관통" % (1 if rank == 1 else 3)
		"s_seek": return "영혼탄 추적 " + ("약하게" if rank == 1 else "강하게")
		"s_rate": return "영혼탄 발사 간격 −%d%%" % (rank * 20)
		"soul_time": return "유령 시간 +%d초" % (rank * 5)
		"wraith": return "유령 이동 속도 +%d%%" % (rank * 20)
		"mercy": return "빙의 확률 +%d%%p" % (rank * 8)
		"harvest": return "처치 수명 +%.1f초" % (rank * 0.5)
		"glasscannon": return "피해 +%d%% · 수명 −%d%%" % [rank * 50, 30 if rank == 1 else 50]
		"vigor": return "몸 수명 +%d%%" % (rank * 20)
		"embalm": return "새 몸 수명 +%d초" % (rank * 5)
		"funeral": return "몸 폭발 +%d%%" % (rank * 40) + (" · E로 나와도 폭발" if rank >= 2 else "")
		"orbit": return "해골 %d개가 주위를 돌며 피해" % rank
		"lance": return "%.1f초마다 영혼 창 자동 발사" % (2.4 if rank == 1 else 1.4)
		"storm_soul", "bone_crown", "undying": return DATA[id][2]
	return ""
