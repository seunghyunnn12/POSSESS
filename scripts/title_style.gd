extends RefCounted
## Cinematic title: strips the boxed panels off the title scene and lets the live
## dungeon show through. Node names stay the same so hud.gd keeps driving the text.

const LOGO_FONT := "res://assets/fonts/IMFellEnglishSC.ttf"
const SERIF := "res://assets/fonts/GowunBatang-Regular.ttf"
const SERIF_BOLD := "res://assets/fonts/GowunBatang-Bold.ttf"
const BONE := Color("ece3cf")
const MUTED := Color("a79e8c")
const EMBER := Color("e7b464")

static func font(path: String, weight: int = 0) -> Font:
	var base: FontFile = load(path)
	if weight <= 0: return base
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": weight}
	return variation

static func flat() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

static func label(node: Label, at: Vector2, size: Vector2, face: Font, px: int, colour: Color) -> void:
	node.position = at
	node.size = size
	node.add_theme_font_override("font", face)
	node.add_theme_font_size_override("font_size", px)
	node.add_theme_color_override("font_color", colour)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.add_theme_constant_override("shadow_outline_size", 6)

static func menu_button(node: Button, at: Vector2, face: Font, px: int) -> void:
	node.position = at
	node.size = Vector2(360, 42)
	node.theme_type_variation = &""
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		node.add_theme_stylebox_override(state, flat())
	node.add_theme_font_override("font", face)
	node.add_theme_font_size_override("font_size", px)
	node.add_theme_color_override("font_color", MUTED)
	node.add_theme_color_override("font_hover_color", EMBER)
	node.add_theme_color_override("font_focus_color", EMBER)
	node.add_theme_color_override("font_pressed_color", BONE)
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	node.add_theme_constant_override("outline_size", 4)

## Stack the visible menu entries with no gaps (the death screen hides some).
static func reflow(title: Control) -> void:
	var y := 392.0
	for path in ["Continue", "Skip", "RecordsButton", "SettingsButton"]:
		var node: Button = title.get_node(path)
		if not node.visible: continue
		node.position.y = y
		y += 46.0

static func apply(title: Control) -> void:
	var serif := font(SERIF)
	var serif_bold := font(SERIF_BOLD)
	# Latin logo face; Hangul titles (영혼 소멸, 귀환) fall back to the bold serif.
	var logo_face := FontVariation.new()
	logo_face.base_font = load(LOGO_FONT)
	logo_face.fallbacks = [serif_bold]
	logo_face.spacing_glyph = 4
	for path in ["Backdrop", "Frame", "ArtFrame", "KeyArt"]:
		var node = title.get_node_or_null(path)
		if node != null: node.hide()
	# A soft darkening from the left edge so text reads over torchlight and fog.
	var shade := TextureRect.new()
	shade.name = "Shade"
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.03, 0.9))
	gradient.set_color(1, Color(0.02, 0.02, 0.03, 0.0))
	gradient.add_point(0.45, Color(0.02, 0.02, 0.03, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 256
	texture.height = 16
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2.ZERO
	shade.size = Vector2(900, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(shade)
	title.move_child(shade, 0)
	var floor_shade := TextureRect.new()
	var down := Gradient.new()
	down.set_color(0, Color(0.02, 0.02, 0.03, 0.0))
	down.set_color(1, Color(0.02, 0.02, 0.03, 0.85))
	var down_texture := GradientTexture2D.new()
	down_texture.gradient = down
	down_texture.fill_from = Vector2(0.5, 0)
	down_texture.fill_to = Vector2(0.5, 1)
	down_texture.width = 16
	down_texture.height = 128
	floor_shade.texture = down_texture
	floor_shade.stretch_mode = TextureRect.STRETCH_SCALE
	floor_shade.position = Vector2(0, 480)
	floor_shade.size = Vector2(1280, 240)
	floor_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(floor_shade)
	title.move_child(floor_shade, 1)

	label(title.get_node("Eyebrow"), Vector2(98, 150), Vector2(600, 30), serif, 19, EMBER)
	var logo: Label = title.get_node("Logo")
	label(logo, Vector2(90, 176), Vector2(900, 140), logo_face, 118, BONE)
	logo.add_theme_color_override("font_shadow_color", Color(0.45, 0.8, 0.85, 0.18))
	logo.add_theme_constant_override("shadow_offset_y", 0)
	logo.add_theme_constant_override("shadow_outline_size", 14)
	label(title.get_node("Subtitle"), Vector2(98, 318), Vector2(700, 36), serif, 23, BONE)
	var description: Label = title.get_node("Description")
	label(description, Vector2(98, 618), Vector2(760, 60), serif, 15, MUTED)
	label(title.get_node("Footer"), Vector2(880, 682), Vector2(360, 24), serif, 13, Color(MUTED, 0.7))
	title.get_node("Footer").horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var y := 392.0
	for path in ["Continue", "Skip", "RecordsButton", "SettingsButton"]:
		menu_button(title.get_node(path), Vector2(94, y), serif_bold, 25 if path == "Continue" else 21)
		y += 46.0
	var start: Button = title.get_node("Continue")
	start.add_theme_color_override("font_color", BONE)

	# Ghost choice: a quiet list at the lower right instead of four framed cards.
	var ghosts: Control = title.get_node("GhostSelection")
	ghosts.position = Vector2(900, 360)
	label(ghosts.get_node("Heading"), Vector2(0, 0), Vector2(320, 26), serif, 15, EMBER)
	var row := 32.0
	for id in ["wanderer", "reaper", "arcanist", "gunslinger"]:
		var button: Button = ghosts.get_node(id)
		button.position = Vector2(0, row)
		button.size = Vector2(320, 44)
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			button.add_theme_stylebox_override(state, flat())
		var portrait = button.get_node_or_null("Portrait")
		if portrait != null: portrait.hide()
		label(button.get_node("Name"), Vector2(0, 0), Vector2(320, 24), serif_bold, 19, BONE)
		label(button.get_node("Condition"), Vector2(0, 22), Vector2(320, 20), serif, 13, MUTED)
		row += 48.0
	label(ghosts.get_node("Description"), Vector2(0, row + 6), Vector2(320, 80), serif, 14, MUTED)
	ghosts.get_node("Description").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
