extends RefCounted
## A seeded three-zone floor, grown Isaac-style: each zone is a tree of rooms on a
## grid, its boss room opens onto the next zone's crossroads. Room IDs are 1-based.
## Kinds: hub, combat, trial, treasure, morgue, sanctuary, secret, boss.

const PRICES = {"soldier": 20, "shotgun": 25, "archer": 25, "brute": 25, "mage": 30, "storm": 30}
const POTION_PRICE = 15
const ZONE_ROWS := 5
const X_LIMIT := 3
const BOSS_TYPES := ["warden", "warden", "sovereign"]
const HUB_NAMES := ["시작 방", "지하 교차로", "심층 교차로"]
const BOSS_NAMES := ["묘지기의 방", "잊힌 사서의 무덤", "군주의 무덤"]
const COMBAT_NAMES := [
	["북쪽 회랑", "동쪽 묘실", "얼어붙은 복도", "뼈의 통로", "잠든 회랑", "무너진 계단", "차가운 납골실"],
	["무너진 서고", "잿빛 납골당", "먼지 서가", "금서의 방", "부서진 열람실", "필사실", "잊힌 서가"],
	["불씨 회랑", "잿더미 성소", "불타는 제단", "검은 화로", "재의 회랑", "그을린 묘실", "타오르는 통로"],
]
const SPECIAL_NAMES := {"treasure": "보물고", "morgue": "영안실", "sanctuary": "촛불 성소", "trial": "시련의 방", "secret": "숨겨진 방"}
## Rooms each zone must contain besides its crossroads and boss.
const ZONE_PLAN := [
	{"combat": 5, "dead_ends": ["treasure"], "anywhere": []},
	{"combat": 5, "dead_ends": ["treasure", "morgue"], "anywhere": ["sanctuary", "trial"]},
	{"combat": 5, "dead_ends": ["treasure", "morgue"], "anywhere": ["sanctuary", "trial"]},
]

var cells: Array[Vector2i] = []
var kinds: Array[String] = []
var zones: Array[int] = []
var names: Array[String] = []
var links: Array = []
var key_doors := {}
var secret_doors := {}
var hubs: Array[int] = []
var bosses: Array[int] = []
var final := 0
var rng := RandomNumberGenerator.new()

static func generate(seed_value: int):
	var map = load("res://scripts/expedition.gd").new()
	for attempt in 200:
		map.rng.seed = seed_value * 7919 + attempt
		if map.build(): return map
	push_error("expedition: failed to generate a floor for seed %d" % seed_value)
	return map

func reset() -> void:
	cells.clear()
	kinds.clear()
	zones.clear()
	names.clear()
	links.clear()
	key_doors.clear()
	secret_doors.clear()
	hubs.clear()
	bosses.clear()

func build() -> bool:
	reset()
	var start := Vector2i(0, 0)
	for zone in 3:
		if not grow_zone(zone, start): return false
		start = cells[bosses[-1] - 1] + Vector2i.DOWN
	final = bosses[-1]
	# The exit corridor leaves the final boss room to the south.
	return room_at(cells[final - 1] + Vector2i.DOWN) == 0

func room_at(cell: Vector2i) -> int:
	return cells.find(cell) + 1

func neighbours(cell: Vector2i, pool: Array) -> int:
	var count := 0
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if cell + d in pool: count += 1
	return count

func grow_zone(zone: int, start: Vector2i) -> bool:
	var plan: Dictionary = ZONE_PLAN[zone]
	var target: int = 2 + plan.combat + plan.dead_ends.size() + plan.anywhere.size()
	var top := start.y
	var local: Array[Vector2i] = [start]
	var parent := {start: start}
	var queue: Array[Vector2i] = [start]
	var guard := 0
	while local.size() < target and guard < 400:
		guard += 1
		if queue.is_empty(): queue = local.duplicate()
		var c: Vector2i = queue.pop_front()
		var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]
		for i in range(dirs.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = dirs[i]
			dirs[i] = dirs[j]
			dirs[j] = t
		for d in dirs:
			if local.size() >= target: break
			var n: Vector2i = c + d
			if n in local or n in cells: continue
			if n.y < top or n.y >= top + ZONE_ROWS or absi(n.x) > X_LIMIT: continue
			# Tree growth: a new room may touch only its parent (Isaac rule).
			if neighbours(n, local) > 1 or neighbours(n, cells) > 0: continue
			if rng.randf() < 0.45: continue
			local.append(n)
			parent[n] = c
			queue.append(n)
	if local.size() < target: return false
	var dead_ends: Array[Vector2i] = []
	for c in local:
		if c != start and neighbours(c, local) == 1: dead_ends.append(c)
	# Boss: a dead end whose south cell is free, preferring the deepest one.
	var boss := Vector2i(999, -999)
	for c in dead_ends:
		var south: Vector2i = c + Vector2i.DOWN
		if south in local or parent[c] == south: continue
		if boss.x == 999 or c.y > boss.y or (c.y == boss.y and absi(c.x) < absi(boss.x)): boss = c
	if boss.x == 999: return false
	dead_ends.erase(boss)
	if dead_ends.size() < plan.dead_ends.size(): return false
	var assigned := {start: "hub", boss: "boss"}
	for kind in plan.dead_ends:
		var pick: Vector2i = dead_ends.pop_at(rng.randi_range(0, dead_ends.size() - 1))
		assigned[pick] = kind
	var free: Array[Vector2i] = []
	for c in local:
		if not assigned.has(c): free.append(c)
	for kind in plan.anywhere:
		var pick: Vector2i = free.pop_at(rng.randi_range(0, free.size() - 1))
		assigned[pick] = kind
	# Register rooms in BFS order so the crossroads is first in each zone.
	var first := cells.size() + 1
	for c in local:
		cells.append(c)
		kinds.append(assigned.get(c, "combat"))
		zones.append(zone + 1)
	var used_names: Array = COMBAT_NAMES[zone].duplicate()
	for i in range(first, cells.size() + 1):
		var kind: String = kinds[i - 1]
		var label: String
		if kind == "hub": label = HUB_NAMES[zone]
		elif kind == "boss": label = BOSS_NAMES[zone]
		elif kind == "combat": label = used_names.pop_at(rng.randi_range(0, used_names.size() - 1)) if not used_names.is_empty() else "이름 없는 방"
		else: label = SPECIAL_NAMES[kind]
		names.append(label)
	hubs.append(first)
	bosses.append(room_at(boss))
	for c in local:
		if c == start: continue
		link(room_at(parent[c]), room_at(c))
	if zone > 0: link(bosses[zone - 1], first)
	for i in range(first, cells.size() + 1):
		if kinds[i - 1] == "treasure": key_doors[edge_to(i)] = i
	return place_secret(zone, first)

func link(a: int, b: int) -> void:
	links.append([a, b])

func edge_to(room: int) -> int:
	for i in links.size():
		if room in links[i]: return i
	return -1

## A hidden room behind a cracked wall, touching exactly one combat room of this zone.
func place_secret(zone: int, first: int) -> bool:
	var options: Array = []
	for i in range(first, cells.size() + 1):
		if kinds[i - 1] != "combat": continue
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = cells[i - 1] + d
			if n in cells or absi(n.x) > X_LIMIT + 1: continue
			if n.y < cells[first - 1].y: continue
			if neighbours(n, cells) != 1: continue
			options.append([n, i])
	if options.is_empty(): return false
	var pick: Array = options[rng.randi_range(0, options.size() - 1)]
	cells.append(pick[0])
	kinds.append("secret")
	zones.append(zone + 1)
	names.append(SPECIAL_NAMES.secret)
	link(pick[1], cells.size())
	secret_doors[links.size() - 1] = cells.size()
	return true

func size() -> int:
	return cells.size()

func center(room: int) -> Vector3:
	var cell: Vector2i = cells[room - 1]
	return Vector3(cell.x * 22, 0, cell.y * 24)

func zone(room: int) -> int:
	return zones[room - 1]

func kind(room: int) -> String:
	return kinds[room - 1]

func is_safe(room: int) -> bool:
	return kinds[room - 1] in ["hub", "treasure", "morgue", "sanctuary", "secret"]

func fights(room: int) -> bool:
	return kinds[room - 1] in ["combat", "trial", "boss"]

func exit_door() -> int:
	return links.size()

func other(edge: int, room: int) -> int:
	return links[edge][1] if links[edge][0] == room else links[edge][0]
