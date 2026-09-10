extends Control
signal changed(key: String, value: Variant)
signal reset_requested
var fields: Dictionary = {}
var captions: Dictionary = {}
var status: Label
var reset: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keys := ["sensitivity", "volume", "fullscreen", "resolution", "invert_y", "vsync"]
	for i in keys.size():
		var key: String = keys[i]
		var label := Label.new()
		label.position = Vector2(66, 218 + i * 56)
		label.size = Vector2(400, 42)
		add_child(label)
		captions[key] = label
		var field: Control
		if key in ["sensitivity", "volume"]:
			var slider := HSlider.new()
			slider.min_value = 0.25 if key == "sensitivity" else 0.0
			slider.max_value = 3.0 if key == "sensitivity" else 100.0
			slider.step = 0.05 if key == "sensitivity" else 1.0
			slider.value_changed.connect(func(value): changed.emit(key, value))
			field = slider
		elif key == "resolution":
			var options := OptionButton.new()
			for resolution in preload("res://scripts/settings.gd").RESOLUTIONS:
				options.add_item("%d × %d" % [resolution.x, resolution.y])
			options.item_selected.connect(func(index): changed.emit(key, index))
			field = options
		else:
			var toggle := CheckButton.new()
			toggle.toggled.connect(func(enabled): changed.emit(key, enabled))
			field = toggle
		field.position = Vector2(510, 218 + i * 56)
		field.size = Vector2(640, 42)
		add_child(field)
		fields[key] = field
	reset = Button.new()
	reset.position = Vector2(66, 580)
	reset.size = Vector2(280, 48)
	reset.pressed.connect(func(): reset_requested.emit())
	add_child(reset)
	status = Label.new()
	status.position = Vector2(66, 642)
	status.size = Vector2(1150, 40)
	status.theme_type_variation = "Muted"
	add_child(status)

func present(values: Dictionary, failed: bool) -> void:
	for key in fields:
		captions[key].text = tr("SETTING_" + key.to_upper())
		var field = fields[key]
		if field is Range:
			field.set_value_no_signal(values[key])
			captions[key].text += "  %.2f×" % values[key] if key == "sensitivity" else "  %d%%" % values[key]
		elif field is OptionButton:
			field.select(values[key])
			field.disabled = values.fullscreen
		else:
			field.set_pressed_no_signal(values[key])
			field.text = tr("SETTING_ON" if values[key] else "SETTING_OFF")
	reset.text = tr("SETTING_RESET")
	status.text = tr("SETTING_SAVE_ERROR" if failed else "SETTING_SAVED")
