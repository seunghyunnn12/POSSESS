extends Control
## Full-screen interstitial during the existing safe travel window only.
var heading: Label
var story: Label
var tip_label: Label
var route: Label
var caption: Label
var illustration: TextureRect
var last_index := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	illustration = TextureRect.new()
	illustration.texture = preload("res://scripts/story.gd").ART
	illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.size = size
	illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(illustration)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.04, 0.22)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	caption = label_at(Vector2(64, 124), Vector2(600, 30), "Gold")
	heading = label_at(Vector2(60, 176), Vector2(690, 72), "Heading")
	story = label_at(Vector2(64, 277), Vector2(570, 138), "Subheading")
	route = label_at(Vector2(64, 490), Vector2(650, 40), "Accent")
	tip_label = label_at(Vector2(64, 604), Vector2(1120, 65), "Muted")
	hide()

func label_at(at: Vector2, extent: Vector2, variation: String) -> Label:
	var label := Label.new()
	label.position = at
	label.size = extent
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func present(index: int, bindings) -> void:
	var chapter := preload("res://scripts/story.gd").chapter(index)
	caption.text = tr("PASSAGE_CAPTION") % chapter
	heading.text = tr("CHAPTER_%d" % chapter)
	story.text = tr("CHAPTER_STORY_%d" % chapter)
	tip_label.text = tr(preload("res://scripts/story.gd").tip(chapter))
	if bindings != null: tip_label.text = bindings.hint(tip_label.text)
	var steps: PackedStringArray = []
	for i in range(1, 8): steps.append("◆" if i == chapter else ("—" if i < chapter else "◇"))
	route.text = "   ".join(steps)
	last_index = chapter
