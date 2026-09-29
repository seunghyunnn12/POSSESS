extends Control
## Expedition overlay: current-zone minimap, contextual hint, resources and damage cues.

var model: Dictionary = {}
var damage_chunks: Array = []
var direction_left := 0.0
var angle := 0.0
var source := ""
var map_labels: Array[Label] = []
var map_positions: Array[Vector2] = []
var hint: Label
var status: Label
var bindings
var map
const CELL := Vector2(40, 22)
const STEP := Vector2(44, 26)
const ORIGIN := Vector2(32, 104)
const CAPTION := {"hub": "시작", "boss": "보스", "treasure": "보물", "morgue": "영안실", "sanctuary": "성소", "trial": "시련", "secret": "비밀", "combat": "?"}
const TINT := {"treasure": Color("f0c35a"), "morgue": Color("9fe8c4"), "sanctuary": Color("ffd89a"), "trial": Color("ff9c68"), "boss": Color("ff7a6a"), "secret": Color("d9b36c")}

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	hint = Label.new()
	hint.position = Vector2(32, 432)
	hint.add_theme_font_size_override("font_size", 20)
	add_child(hint)
	status = Label.new()
	status.position = Vector2(140, 526)
	status.add_theme_font_size_override("font_size", 18)
	add_child(status)

func build_labels() -> void:
	for label in map_labels: label.queue_free()
	map_labels.clear()
	map_positions.clear()
	for i in map.size():
		var label := Label.new()
		label.size = CELL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		add_child(label)
		map_labels.append(label)
		map_positions.append(Vector2.ZERO)

## Lay out only the rooms of the zone the player is in, anchored at the top-left.
func layout_zone(zone: int) -> void:
	var low := Vector2i(999, 999)
	for i in map.size():
		if map.zones[i] != zone: continue
		low.x = mini(low.x, map.cells[i].x)
		low.y = mini(low.y, map.cells[i].y)
	for i in map.size():
		var c: Vector2i = map.cells[i] - low
		map_positions[i] = ORIGIN + Vector2(c.x * STEP.x, c.y * STEP.y)
		map_labels[i].position = map_positions[i]

func present(state: Dictionary) -> void:
	model = state
	visible = state.get("fun", false) and state.modal == ""
	if not visible: return
	if map != state.map:
		map = state.map
		build_labels()
	layout_zone(state.zone)
	for i in map_labels.size():
		var room := i + 1
		var shown: bool = map.zones[i] == state.zone and revealed(room)
		map_labels[i].visible = shown
		if not shown: continue
		var kind: String = map.kinds[i]
		var caption: String = CAPTION[kind]
		if kind in ["combat", "trial", "boss"] and state.visited[i]:
			caption = ("✓" if state.rewards[i] else "증강") if state.cleared[i] else ("전투" if kind == "combat" else caption)
		map_labels[i].text = ("● " if state.room == room else "") + caption
		map_labels[i].modulate = Color("76e6cd") if state.room == room else TINT.get(kind, Color("9aaeb8"))
	hint.text = ""
	if state.tutorial:
		hint.text = "[Tab] 건너뛰기\n" + ("WASD 이동 · 마우스로 둘러보고 문을 고르세요" if state.hub else ("WASD 이동 · 좌클릭으로 앞의 병사를 약화하세요" if state.tutorial_step == 0 else "가까이 다가가 우클릭으로 빙의하세요"))
	elif state.hub:
		hint.text = "문을 골라 탐험하세요 · 구역 끝의 보스를 쓰러뜨리면 다음 구역이 열립니다"
	elif state.kind == "treasure" and state.reward_ready:
		hint.text = "상자 앞에서 [F] · 고른 힘은 바로 최대 단계가 됩니다"
	elif state.morgue:
		hint.text = "관 속의 몸을 조준하고 우클릭으로 구매" + ("" if state.potion_used else " · 가운데 방부액 [F] 뼈 동전 15")
	elif state.kind == "sanctuary":
		hint.text = "촛불 앞에서 [F] · 몸의 수명을 되돌립니다"
	elif state.reward_ready:
		hint.text = "[F] 증강 선택" + (" (2개)" if state.kind == "trial" else "") + " · 다른 문으로 탐험을 이어가세요"
	elif state.final_room and state.cleared[map.final - 1]:
		hint.text = "군주의 무덤을 정리했습니다 · 귀환 문으로 이동하세요"
	elif state.kind == "boss" and state.cleared[state.room - 1]:
		hint.text = "보스를 쓰러뜨렸습니다 · 아래쪽 문으로 다음 구역에 내려가세요"
	if bindings != null: hint.text = bindings.hint(hint.text)
	status.text = "열쇠 %d   ·   뼈 동전 %d   ·   유물 %d" % [state.get("keys", 0), state.get("coins", 0), state.get("relics", 0)]
	queue_redraw()

func revealed(room: int) -> bool:
	if model.visited[room - 1]: return true
	if map.kinds[room - 1] == "secret": return false
	for edge in map.links:
		if room in edge and (model.visited[edge[0] - 1] or model.visited[edge[1] - 1]): return true
	return false

func damage(data: Dictionary, yaw: float, player_at: Vector3, maximum: float) -> void:
	if data.body:
		damage_chunks.append({"from": data.after / maximum, "to": data.before / maximum, "left": 0.6})
	var delta: Vector3 = data.from - player_at
	var local: Vector3 = Basis(Vector3.UP, -yaw) * delta
	angle = atan2(local.x, -local.z) - PI / 2
	direction_left = 0.6
	source = data.source

func _process(dt: float) -> void:
	var real_dt := dt / maxf(Engine.time_scale, 0.01)
	direction_left = maxf(0, direction_left - real_dt)
	for chunk in damage_chunks: chunk.left -= real_dt
	damage_chunks = damage_chunks.filter(func(c): return c.left > 0)
	queue_redraw()

func _draw() -> void:
	if not visible or model.is_empty() or map == null: return
	for edge in map.links:
		var a: int = edge[0]
		var b: int = edge[1]
		if map_labels[a - 1].visible and map_labels[b - 1].visible:
			draw_line(map_positions[a - 1] + CELL * 0.5, map_positions[b - 1] + CELL * 0.5, Color("76e6cd"), 2)
	for i in map_labels.size():
		if map_labels[i].visible: draw_rect(Rect2(map_positions[i], CELL), Color("1b303b"))
	var bar := Rect2(140, 674, 240, 12)
	draw_rect(bar, Color("15232e"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(model.life_fraction, 0, 1), 12)), Color("e8a14b") if model.body else Color("70e6d0"))
	for chunk in damage_chunks:
		if not model.body: continue
		draw_rect(Rect2(bar.position + Vector2(chunk.from * 240, 0), Vector2(maxf(0, chunk.to - chunk.from) * 240, 12)), Color(1, 0.15, 0.12, minf(1, chunk.left * 6)))
	if direction_left > 0:
		draw_arc(Vector2(640, 360), 280, angle - 0.22, angle + 0.22, 18, Color(1, 0.18, 0.12, direction_left / 0.6), 9, true)
