extends RefCounted
## One connected floor. Room IDs are one-based at the authority boundary.
const CELLS = [Vector2i(0, 0), Vector2i(0, -1), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 1),
	Vector2i(0, 2), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, 3),
	Vector2i(-2, 1), Vector2i(2, 2)]
const LINKS = [[1, 2], [1, 3], [1, 4], [4, 5], [4, 6], [4, 7], [7, 8], [7, 9], [7, 10], [5, 11], [9, 12]]
const LOCKS = {2: [2, 3], 5: [5, 6], 8: [8, 9]}
## Edge index -> room behind a door that costs one key.
const KEY_DOORS = {9: 11}
const HUBS = [1, 4, 7]
const TREASURE = 11
const MORGUE = 12
const SPECIAL = [11, 12]
const NAMES = ["시작 방", "북쪽 회랑", "동쪽 묘실", "지하 교차로", "무너진 서고", "잿빛 납골당", "심층 교차로", "얼어붙은 묘실", "불씨 회랑", "군주의 무덤", "보물고", "영안실"]
const ZONES = [1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 2, 3]
const FINAL = 10
## Bone-coin price of a preserved body in the morgue.
const PRICES = {"soldier": 20, "shotgun": 25, "archer": 25, "brute": 25, "mage": 30, "storm": 30}
const POTION_PRICE = 15

static func center(room: int) -> Vector3:
	var cell: Vector2i = CELLS[room - 1]
	return Vector3(cell.x * 22, 0, cell.y * 24)

static func zone(room: int) -> int:
	return ZONES[room - 1]

static func unlocked(edge: int, cleared: Array) -> bool:
	for room in LOCKS.get(edge, []):
		if not cleared[room - 1]: return false
	return true
