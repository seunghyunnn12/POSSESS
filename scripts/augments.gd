extends RefCounted
## Run-level soul powers. Host traits are deliberately stored elsewhere.
const DEFINITIONS := {
	"ambush": {"name": "첫 공격 강화", "tag": "몸의 무기", "description": "빙의 후 위장을 깨는 첫 공격이 강해집니다.\n새 몸마다 한 번. 빗나가도 소모됩니다."},
	"vigor": {"name": "몸 수명 증가", "tag": "몸 유지", "description": "빌린 몸을 더 오래 사용할 수 있습니다.\n현재 몸에도 적용. 유령의 20초는 그대로입니다."},
	"mercy": {"name": "빙의 확률 증가", "tag": "우클릭 빙의", "description": "같은 체력의 적에게 빙의하기 쉬워집니다.\n특별 개체에도 적용. 최대 확률은 95%입니다."},
	"curse": {"name": "유령탄 강화", "tag": "유령의 좌클릭", "description": "몸이 없을 때 쏘는 탄환이 강해집니다.\n적의 체력을 더 빨리 깎아 빙의를 준비합니다."},
	"rot": {"name": "부패 공격 강화", "tag": "몸의 무기", "description": "몸의 남은 시간이 적을수록 강해집니다.\n새 몸에서는 0%, 시간이 줄며 점점 증가합니다."},
	"funeral": {"name": "몸 폭발 강화", "tag": "수명 종료", "description": "몸의 시간이 다 됐을 때 폭발이 강해집니다.\nE로 직접 나오거나 갈아탈 때는 폭발하지 않습니다."}
}

static func description(id: String, rank: int = 1) -> String:
	var item: Dictionary = DEFINITIONS[id]
	return "%s %d" % [item.name, rank]

static func effect(id: String, rank: int) -> String:
	match id:
		"ambush": return "첫 공격 +%d%%" % (60 * rank)
		"vigor": return "몸 수명 +%d%%" % (20 * rank)
		"mercy": return "빙의 +%d%%p" % (8 * rank)
		"curse": return "저주탄 +%d%%" % (25 * rank)
		"rot": return "부패 공격 최대 +%d%%" % (35 * rank)
		"funeral": return "폭발 +%d%% · 범위 +%d%%" % [40 * rank, 30 * rank]
	return ""

static func preview(id: String, rank: int) -> String:
	var next := rank + 1
	match id:
		"ambush": return "기본 피해 20인 몸의 첫 공격\n%.0f → %.0f 피해" % [20 * (1 + 0.6 * rank), 20 * (1 + 0.6 * next)]
		"vigor": return "기본 수명 25초인 몸\n%.0f → %.0f초 (남은 비율 유지)" % [25 * (1 + 0.2 * rank), 25 * (1 + 0.2 * next)]
		"mercy": return "증강 전 확률이 50%%인 적\n%d%% → %d%%" % [50 + 8 * rank, 50 + 8 * next]
		"curse": return "유령탄 한 발 피해\n%.1f → %.1f" % [14 * (1 + 0.25 * rank), 14 * (1 + 0.25 * next)]
		"rot": return "몸 수명의 절반이 남았을 때\n추가 피해 %.1f%% → %.1f%%" % [17.5 * rank, 17.5 * next]
		"funeral": return "폭발 피해 %.0f → %.0f\n반경 %.2fm → %.2fm" % [60 * (1 + 0.4 * rank), 60 * (1 + 0.4 * next), 4.5 * (1 + 0.3 * rank), 4.5 * (1 + 0.3 * next)]
	return ""
