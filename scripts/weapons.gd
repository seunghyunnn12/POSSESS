extends RefCounted
## Each host is a different weapon, not an extra inventory slot.
const DATA := {
	"soldier": {"name": "연발병", "weapon": "연발총", "tip": "연속 사격 · 오래 쏘면 탄이 퍼집니다", "damage": 22.0, "interval": 0.13, "move": 6.0, "life": 25.0, "health": 100.0, "magazine": 18, "reload": 1.3, "element": "", "color": Color("ffd494")},
	"brute": {"name": "망치병", "weapon": "대형 망치", "tip": "근접 광역 강타 · 밀쳐내기", "damage": 68.0, "interval": 0.8, "move": 4.5, "life": 35.0, "health": 160.0, "magazine": 0, "reload": 0.0, "element": "", "color": Color("ffae79")},
	"shotgun": {"name": "산탄병", "weapon": "쌍열 산탄총", "tip": "가까이 붙어 한 방 · 6발의 산탄", "damage": 11.0, "interval": 0.85, "move": 5.6, "life": 30.0, "health": 135.0, "magazine": 6, "reload": 1.65, "element": "", "color": Color("ffc06f")},
	"archer": {"name": "서리 궁수", "weapon": "서리 활", "tip": "좌클릭 유지 후 놓기 · 적을 느리게 합니다", "damage": 76.0, "interval": 0.3, "move": 6.8, "life": 28.0, "health": 95.0, "magazine": 0, "reload": 0.0, "element": "ice", "color": Color("78dfff")},
	"mage": {"name": "화염 술사", "weapon": "화염구", "tip": "폭발과 화상 · 얼어붙은 적에게 열충격", "damage": 30.0, "interval": 0.65, "move": 5.5, "life": 28.0, "health": 105.0, "magazine": 0, "reload": 0.0, "element": "fire", "color": Color("ff8660")},
	"storm": {"name": "번개 술사", "weapon": "연쇄 번개", "tip": "가까이 모인 적에게 번개가 이어집니다", "damage": 26.0, "interval": 0.55, "move": 6.0, "life": 26.0, "health": 100.0, "magazine": 0, "reload": 0.0, "element": "shock", "color": Color("c6a0ff")}
}

static func info(kind: String) -> Dictionary:
	return DATA.get(kind, DATA.soldier)
