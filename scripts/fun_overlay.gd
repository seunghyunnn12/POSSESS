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

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for i in 3:
		var label := Label.new()
		label.position = Vector2(40 + i * 92, 112)
		label.size = Vector2(80, 42)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		add_child(label)
		map_labels.append(label)
	hint = Label.new()
	hint.position = Vector2(32, 180)
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
		map_labels[i].text = ("● " if state.room == i + 1 else "") + ("✓" if state.cleared[i] else (str(i + 1) if state.visited[i] else "?"))
		map_labels[i].modulate = Color("76e6cd") if state.room == i + 1 else Color("9aaeb8")
	hint.text = ""
	if state.tutorial:
		hint.text = "[Tab] 건너뛰기\n" + ("좌클릭으로 앞의 병사를 약화하세요" if state.tutorial_step == 0 else "가까이 다가가 우클릭으로 빙의하세요")
	elif state.reward_ready:
		hint.text = "[F] 증강 선택 · 문으로 걸어서 다음 방 이동"
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
		draw_rect(Rect2(40 + i * 92, 112, 80, 42), Color("1b303b"))
		if i < 2: draw_line(Vector2(120 + i * 92, 133), Vector2(132 + i * 92, 133), Color("76e6cd"), 2)
	var bar := Rect2(140, 674, 240, 12)
	draw_rect(bar, Color("15232e"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(model.life_fraction, 0, 1), 12)), Color("e8a14b") if model.body else Color("70e6d0"))
	for chunk in damage_chunks:
		draw_rect(Rect2(bar.position + Vector2(chunk.from * 240, 0), Vector2(maxf(0, chunk.to - chunk.from) * 240, 12)), Color(1, 0.15, 0.12, minf(1, chunk.left * 6)))
	if direction_left > 0:
		draw_arc(Vector2(640, 360), 280, angle - 0.22, angle + 0.22, 18, Color(1, 0.18, 0.12, direction_left / 0.6), 9, true)
