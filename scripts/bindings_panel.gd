extends Control
signal requested(action: String)
signal reset_requested
var buttons: Dictionary = {}
var labels: Dictionary = {}
var message: Label
var reset: Button
var waiting := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i := 0
	for action in preload("res://scripts/bindings.gd").DEFAULTS:
		var column := i / 5
		var row := i % 5
		var label := Label.new()
		label.position = Vector2(66 + column * 580, 215 + row * 62)
		label.size = Vector2(240, 42)
		add_child(label)
		labels[action] = label
		var button := Button.new()
		button.position = label.position + Vector2(250, 0)
		button.size = Vector2(240, 42)
		button.pressed.connect(func(): requested.emit(action))
		add_child(button)
		buttons[action] = button
		i += 1
	reset = Button.new()
	reset.position = Vector2(66, 550)
	reset.size = Vector2(300, 44)
	reset.pressed.connect(func(): reset_requested.emit())
	add_child(reset)
	message = Label.new()
	message.position = Vector2(66, 610)
	message.size = Vector2(1140, 85)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.theme_type_variation = "Muted"
	add_child(message)

func present(bindings, notice: String = "BIND_HELP") -> void:
	for action in buttons:
		labels[action].text = tr("BIND_" + action.to_upper())
		buttons[action].text = tr("BIND_WAIT") if action == waiting else bindings.label(action)
	reset.text = tr("BIND_RESET")
	message.text = tr(notice)
