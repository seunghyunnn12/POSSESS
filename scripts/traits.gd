extends RefCounted
## Immutable definitions. Each host gets its own rolled profile exactly once.
const DEFINITIONS := {
	"warden": {"name": "묘지기", "description": "중간 보스의 몸. 피해 +40%, 수명 +60%. 이동 -15%.", "boss": true, "resistance": 0.5, "color": Color("ffca70"), "power": 1.4, "life": 1.6, "move": 0.85, "health": 5.0},
	"sovereign": {"name": "공허의 군주", "description": "최종 보스의 몸. 피해 +80%, 수명 +100%. 이동 -20%.", "boss": true, "resistance": 0.6, "color": Color("ea87ff"), "power": 1.8, "life": 2.0, "move": 0.8, "health": 9.0},
	"common": {"name": "일반", "description": "특별한 특성 없이 균형 잡힌 몸.", "resistance": 0.0, "color": Color("b5d8cd")},
	"swift": {"name": "날렵한", "description": "이동 +20%, 재장전 +20%. 몸의 수명 -20%.", "resistance": 0.25, "color": Color("69d8ff"), "move": 1.2, "reload": 1.2, "life": 0.8},
	"preserved": {"name": "보존된", "description": "몸의 수명 +30%. 이동 -15%.", "resistance": 0.25, "color": Color("b9eb83"), "life": 1.3, "move": 0.85},
	"frenzied": {"name": "흉포한", "description": "공격 속도 +25%. 반동 +50%, 몸의 수명 -10%.", "resistance": 0.25, "color": Color("ffb277"), "rate": 1.25, "recoil": 1.5, "life": 0.9},
	"seer": {"name": "영혼 감시자", "description": "적일 때 위장을 탐지. 빙의하면 벽 너머 영혼 감지와 빙의 +8%p. 이동 -10%.", "resistance": 0.4, "color": Color("d5a0ff"), "move": 0.9}
}

static func profile(id: String = "common", random: RandomNumberGenerator = null) -> Dictionary:
	var result: Dictionary = DEFINITIONS.get(id, DEFINITIONS.common).duplicate(true)
	result.id = id if DEFINITIONS.has(id) else "common"
	result.special = result.id != "common"
	result.attack_iv = random.randf_range(0.92, 1.08) if random != null else 1.0
	result.move_iv = random.randf_range(0.92, 1.08) if random != null else 1.0
	result.vitality_iv = random.randf_range(0.92, 1.08) if random != null else 1.0
	return result

static func stats(kind: String, individual: Dictionary) -> Dictionary:
	var brute := kind == "brute"
	var attack: float = individual.get("attack_iv", 1.0)
	var movement: float = individual.get("move_iv", 1.0) * individual.get("move", 1.0)
	var vitality: float = individual.get("vitality_iv", 1.0)
	return {
		"damage": (68.0 if brute else 22.0) * attack * individual.get("power", 1.0),
		"move": (4.5 if brute else 6.0) * movement,
		"life": (35.0 if brute else 25.0) * vitality * individual.get("life", 1.0),
		"interval": (0.8 if brute else 0.13) / individual.get("rate", 1.0),
		"reload": 1.3 / individual.get("reload", 1.0),
		"recoil": (0.24 if brute else 0.19) * individual.get("recoil", 1.0),
		"damage_taken": 0.6 if brute else 1.0,
		"host_health": (160.0 if brute else 100.0) * vitality * individual.get("health", 1.0),
		"enemy_move": (2.8 if brute else 2.5) * movement,
		"enemy_damage": (4.0 if brute else 2.0) * attack,
		"enemy_interval": (2.5 if brute else 2.4) / individual.get("rate", 1.0)
	}

static func host_name(kind: String, individual: Dictionary) -> String:
	return "%s %s" % [individual.get("name", "일반"), "브루트" if kind == "brute" else "병사"]
