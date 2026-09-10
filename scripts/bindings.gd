extends RefCounted
const DEFAULTS = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "interact": KEY_F, "reload": KEY_R, "eject": KEY_E, "dash": KEY_SHIFT, "jump": KEY_SPACE}
const RESERVED = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_TAB, KEY_J, KEY_M, KEY_1, KEY_2, KEY_3, KEY_ALT, KEY_CTRL, KEY_META, KEY_PRINT, KEY_NONE]
var keys: Dictionary = DEFAULTS.duplicate()
var hint_pattern := RegEx.new()

func _init() -> void:
	hint_pattern.compile("\\b(WASD|Shift|Space|F|R|E)\\b")

func assign_key(action: String, code: int) -> bool:
	if not DEFAULTS.has(action) or code in RESERVED or OS.get_keycode_string(code).is_empty(): return false
	for other in keys:
		if other != action and keys[other] == code: return false
	keys[action] = code
	return true

func restore(saved: Variant) -> void:
	keys = DEFAULTS.duplicate()
	if not saved is Dictionary: return
	# Validate the entire map so swapping two defaults can survive reload.
	var candidate := DEFAULTS.duplicate()
	for action in DEFAULTS:
		var code = saved.get(action, DEFAULTS[action])
		if not code is int or code in RESERVED or OS.get_keycode_string(code).is_empty(): return
		candidate[action] = code
	var unique: Dictionary = {}
	for code in candidate.values(): unique[code] = true
	if unique.size() == DEFAULTS.size(): keys = candidate

func pressed(action: String) -> bool:
	return Input.is_physical_key_pressed(keys[action])

func canonical(code: int) -> int:
	for action in keys:
		if keys[action] == code: return DEFAULTS[action]
	return KEY_NONE if code in DEFAULTS.values() else code

func label(action: String) -> String:
	return OS.get_keycode_string(keys[action])

func hint(text: String) -> String:
	if text.is_empty(): return text
	var matches := hint_pattern.search_all(text)
	for i in range(matches.size() - 1, -1, -1):
		var found = matches[i]
		var token: String = found.get_string()
		var replacement := ""
		if token == "WASD":
			replacement = "/".join([label("forward"), label("left"), label("back"), label("right")])
		else:
			replacement = label({"Shift": "dash", "Space": "jump", "F": "interact", "R": "reload", "E": "eject"}[token])
		text = text.substr(0, found.get_start()) + replacement + text.substr(found.get_end())
	return text
