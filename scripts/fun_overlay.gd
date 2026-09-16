extends Control

var model: Dictionary = {}
var damage_chunks: Array = []
var direction_left := 0.0
var angle := 0.0
var source := ""
var map_labels: Array[Label] = []
var hint: Label
var status: Label
var bindings
const MAP_POSITIONS := [Vector2(40, 158), Vector2(40, 104), Vector2(132, 158)]

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for i in 3:
		var label := Label.new()
		label.position = MAP_POSITIONS[i]
		label.size = Vector2(80, 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		add_child(label)
		map_labels.append(label)
	hint = Label.new()
	hint.position = Vector2(32, 432)
	hint.add_theme_font_size_override("font_size", 20)
	add_child(hint)
	status = Label.new()
	status.position = Vector2(140, 526)
	status.add_theme_font_size_override("font_size", 18)
	add_child(status)

func present(state: Dictionary) -> void:
	model = state
	visible = state.get("fun", false) and state.modal == ""
	if not visible: return
	for i in 3:
		map_labels[i].text = ("● " if state.room == i + 1 else "") + ("시작" if i == 0 else ("✓" if state.cleared[i] else ("전투" if state.visited[i] else "?")))
		map_labels[i].modulate = Color("76e6cd") if state.room == i + 1 else Color("9aaeb8")
	hint.text = ""
	if state.room == 1:
		hint.text = "두 방을 탐험했습니다 · 뒤쪽 귀환 문으로 나가세요" if state.cleared[1] and state.cleared[2] else "앞쪽 회랑 / 오른쪽 묘실 · 원하는 문으로 이동하세요"
		if state.tutorial: hint.text = "[Tab] 건너뛰기\nWASD 이동 · 마우스로 둘러보고 문을 고르세요"
	elif state.tutorial:
		hint.text = "[Tab] 건너뛰기\n" + ("WASD 이동 · 좌클릭으로 앞의 병사를 약화하세요" if state.tutorial_step == 0 else "가까이 다가가 우클릭으로 빙의하세요")
	elif state.reward_ready:
		hint.text = "[F] 증강 선택 · 들어온 문으로 돌아가 다른 길 탐험"
	if bindings != null: hint.text = bindings.hint(hint.text)
	status.text = ""
	queue_redraw()

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
	if not visible or model.is_empty(): return
	for i in 3:
		draw_rect(Rect2(MAP_POSITIONS[i], Vector2(80, 42)), Color("1b303b"))
	draw_line(Vector2(80, 146), Vector2(80, 158), Color("76e6cd"), 2)
	draw_line(Vector2(120, 179), Vector2(132, 179), Color("76e6cd"), 2)
	var bar := Rect2(140, 674, 240, 12)
	draw_rect(bar, Color("15232e"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(model.life_fraction, 0, 1), 12)), Color("e8a14b") if model.body else Color("70e6d0"))
	for chunk in damage_chunks:
		if not model.body: continue
		draw_rect(Rect2(bar.position + Vector2(chunk.from * 240, 0), Vector2(maxf(0, chunk.to - chunk.from) * 240, 12)), Color(1, 0.15, 0.12, minf(1, chunk.left * 6)))
	if direction_left > 0:
		draw_arc(Vector2(640, 360), 280, angle - 0.22, angle + 0.22, 18, Color(1, 0.18, 0.12, direction_left / 0.6), 9, true)
