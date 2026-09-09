extends Control
## Four retained Control scenes. Receives only presenter signals and emits intents.
signal choice_requested(index: int)
signal continue_requested
signal key_requested(code: int)
const THEME = preload("res://theme/possess.tres")
const Reticle = preload("res://scripts/ui_marks.gd")
const Art = preload("res://scripts/ui_art.gd")
var bounds := Vector2(1280, 720)
var target = null # Legacy scene swap compatibility; never reads actors.
var canvas: Control
var screens: Dictionary = {}
var model: Dictionary = {}
var marks
var toast_left := 0.0
var toast_key := ""
var selected_tab := "Body"
var was_journal := false
var last_locale := ""
var art_key := ""

func _ready() -> void:
	theme = THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.size = bounds
	add_child(canvas)
	marks = Reticle.new()
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(marks)
	for id in ["hud", "title", "augment", "pause"]:
		var screen: Control = load("res://scenes/ui/" + id + ".tscn").instantiate()
		canvas.add_child(screen)
		screens[id] = screen
	screens.title.get_node("Continue").pressed.connect(func():
		if model.get("outcome", "") != "": key_requested.emit(KEY_R)
		else: continue_requested.emit())
	screens.title.get_node("Skip").pressed.connect(func(): key_requested.emit(KEY_TAB))
	for i in 3:
		screens.augment.get_node("Card" + str(i)).pressed.connect(func(): choice_requested.emit(i))
	screens.augment.get_node("Reroll").pressed.connect(func(): key_requested.emit(KEY_R))
	screens.pause.get_node("Resume").pressed.connect(func(): key_requested.emit(KEY_ESCAPE))
	for tab in ["Body", "Journal", "Controls"]:
		screens.pause.get_node(tab + "Tab").pressed.connect(func(): selected_tab = tab; update_tab())
	for id in screens: screens[id].hide()
	Art.bind(screens.title.get_node("KeyArt"), "key_art/title")
	Art.bind(screens.hud.get_node("Stage/Icon"), "icons/stage")
	Art.bind(screens.hud.get_node("Enemies/Icon"), "icons/enemy")
	Art.bind(screens.hud.get_node("Interaction/Icon"), "icons/interact")
	localize()

func bind(presenter: Node) -> void:
	presenter.snapshot_changed.connect(present)
	presenter.toast_requested.connect(show_toast)
	presenter.impact_requested.connect(func(): marks.hit_left = 0.16)
	presenter.refresh()

func localize() -> void:
	last_locale = TranslationServer.get_locale()
	var labels := {"hud": {"Stage/Caption": "STAGE", "Enemies/Caption": "ENEMIES", "Host/Caption": "HOST"}, "title": {"Logo": "GAME_TITLE", "Eyebrow": "TITLE_EYEBROW", "Subtitle": "TITLE_SUB", "Description": "TITLE_DESC", "Continue": "START", "Skip": "SKIP", "Footer": "FOOTER"}, "augment": {"Eyebrow": "AUG_EYEBROW", "Title": "AUG_TITLE", "Subtitle": "AUG_SUB", "Footer": "AUG_FOOTER"}, "pause": {"Eyebrow": "PAUSE_EYEBROW", "Title": "PAUSE_TITLE", "Resume": "RESUME", "BodyTab": "TAB_BODY", "JournalTab": "TAB_JOURNAL", "ControlsTab": "TAB_CONTROLS", "Controls/Keys": "CONTROLS"}}
	for screen in labels:
		for path in labels[screen]: put(screen, path, tr(labels[screen][path]))
	var stats := ["DAMAGE", "LIFE", "RATE", "REDUCTION", "MOVE", "HEALTH", "RELOAD", "RESIST"]
	for i in stats.size(): put("pause", "Body/StatLabel" + str(i), tr(stats[i]))
	if toast_key != "": put("hud", "Toast/Message", tr(toast_key))

func put(screen: String, path: String, value: String) -> void:
	var node = screens[screen].get_node(path)
	if node.text != value: node.text = value

func present(state: Dictionary) -> void:
	if not is_node_ready(): return
	var previous_modal: String = model.get("modal", "")
	model = state
	if last_locale != TranslationServer.get_locale(): localize()
	var modal: String = state.modal
	var next_art_key := str([state.kind, state.body, state.choices])
	if next_art_key != art_key:
		art_key = next_art_key
		var role: String = state.kind if state.body else "soul"
		Art.bind(screens.hud.get_node("Host/PortraitFrame/Portrait"), "portraits/" + role)
		Art.bind(screens.pause.get_node("Body/Portrait"), "portraits/" + role)
		Art.bind(screens.hud.get_node("Weapon/Icon"), "weapons/" + role)
		for i in state.choices.size(): Art.bind(screens.augment.get_node("Card" + str(i) + "/Art"), "augments/" + state.choices[i].id)
	screens.hud.visible = modal == "" and state.phase != "travel"
	for id in ["title", "augment", "pause"]: screens[id].visible = modal == id
	mouse_filter = Control.MOUSE_FILTER_IGNORE if modal == "" else Control.MOUSE_FILTER_STOP
	marks.visible = modal == ""
	marks.model = state
	for pair in [["Stage/Name", "stage"], ["Enemies/Count", "enemies"], ["Host/Name", "host"], ["Host/Life", "life"], ["Weapon/Name", "weapon"], ["Weapon/Ammo", "ammo"], ["SoulLabel", "soul"], ["Interaction/Text", "interaction"]]: put("hud", pair[0], state[pair[1]])
	screens.hud.get_node("Host/LifeBar").value = state.life_fraction * 100
	screens.hud.get_node("SoulBar").value = state.xp * 100
	screens.hud.get_node("Weapon/Reload").value = state.reload * 100
	screens.hud.get_node("Interaction").visible = state.interaction != ""
	screens.hud.get_node("Interaction/Hold").value = state.hold * 100
	if modal == "title":
		var briefing: bool = state.phase == "briefing" and state.running
		var ended: bool = state.outcome != ""
		put("title", "Logo", tr("END_WIN" if state.outcome == "CLEAR" else "END_LOSE") if ended else tr("BRIEF_TITLE" if briefing else "GAME_TITLE"))
		put("title", "Subtitle", tr("END_SUB") if ended else (state.stage if briefing else tr("TITLE_SUB")))
		put("title", "Description", state.end_stats if ended else tr("BRIEF_DESC" if briefing else "TITLE_DESC"))
		put("title", "Continue", tr("RESTART" if ended else ("READY" if briefing else "START")))
		screens.title.get_node("Skip").visible = not briefing and not ended
	if modal == "augment":
		if previous_modal != "augment": screens.augment.get_node("Card0").grab_focus()
		put("augment", "Reroll", tr("REROLL") % maxi(0, state.rerolls))
		screens.augment.get_node("Reroll").disabled = state.rerolls <= 0
		for i in 3:
			var path := "Card" + str(i)
			screens.augment.get_node(path).visible = i < state.choices.size()
			if i >= state.choices.size(): continue
			var item: Dictionary = state.choices[i]
			for field in ["Name", "Description", "Effect", "Combo"]: put("augment", path + "/" + field, item[field.to_lower()])
			put("augment", path + "/Tag", tr("AUG_TAG") % [i + 1, item.tag, item.rank])
			put("augment", path + "/Key", tr("CHOOSE") % (i + 1))
	if modal == "pause":
		if state.journal and not was_journal: selected_tab = "Journal"
		elif not state.journal and was_journal: selected_tab = "Body"
		was_journal = state.journal
		screens.pause.get_node("JournalTab").disabled = not state.has_journal
		for pair in [["Body/Name", "detail_name"], ["Body/Trait", "trait"], ["Body/IV", "iv"], ["Body/Build", "build"], ["Journal/Route", "route"], ["Journal/Combos", "combos"], ["Journal/Relics", "relics"], ["Journal/Quest", "quest"]]: put("pause", pair[0], state[pair[1]])
		put("pause", "Body/StatLabel0", tr("PELLET" if state.kind == "shotgun" else ("CHARGE" if state.kind == "archer" else "DAMAGE")))
		for i in 8: put("pause", "Body/StatValue" + str(i), state.values[i])
		update_tab()

func update_tab() -> void:
	for tab in ["Body", "Journal", "Controls"]:
		screens.pause.get_node(tab).visible = tab == selected_tab
		screens.pause.get_node(tab + "Tab").theme_type_variation = "ActiveTab" if tab == selected_tab else "Button"

func show_toast(key: String) -> void:
	toast_key = key
	toast_left = 1.5
	if is_node_ready(): put("hud", "Toast/Message", tr(key))

func _process(dt: float) -> void:
	canvas.scale = size / bounds
	toast_left = maxf(0, toast_left - dt / maxf(Engine.time_scale, 0.001))
	screens.hud.get_node("Toast").visible = toast_left > 0

func card_rect(index: int) -> Rect2:
	return Rect2(48 + index * 402, 212, 380, 408)
