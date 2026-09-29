extends RefCounted
## Expedition UI language: no boxed panels, serif headings, shadowed text, the
## frozen dungeon visible behind menus. Works by rewriting a copy of the theme
## plus a few per-screen layout fixes (empty art slots are removed, not shown).

const SERIF_BOLD := "res://assets/fonts/GowunBatang-Bold.ttf"
const BONE := Color("ece3cf")
const MUTED := Color("a79e8c")
const EMBER := Color("e7b464")

static func flat(bg: Color, underline: Color = Color(0, 0, 0, 0), margin := Vector2(14, 8)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = underline
	box.border_width_bottom = 2 if underline.a > 0 else 0
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	return box

static func build_theme(source: Theme) -> Theme:
	var t: Theme = source.duplicate(true)
	var serif: FontFile = load(SERIF_BOLD)
	for kind in ["Title", "Heading", "BodyName", "Subheading", "Effect"]:
		t.set_font("font", kind, serif)
	t.set_color("font_color", "Label", BONE)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_outline_size", "Label", 5)
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("font_color", "Gold", EMBER)
	t.set_color("font_color", "Muted", MUTED)
	t.set_color("font_color", "Small", MUTED)
	t.set_stylebox("panel", "Panel", flat(Color(0.02, 0.02, 0.03, 0.62)))
	t.set_stylebox("panel", "Well", StyleBoxEmpty.new())
	t.set_stylebox("panel", "AccentPanel", flat(Color(0.03, 0.03, 0.04, 0.7), EMBER))
	t.set_stylebox("panel", "Overlay", flat(Color(0.015, 0.015, 0.02, 0.8), Color(0, 0, 0, 0), Vector2.ZERO))
	t.set_stylebox("normal", "Button", flat(Color(0, 0, 0, 0)))
	t.set_stylebox("hover", "Button", flat(Color(1, 1, 1, 0.04), EMBER))
	t.set_stylebox("pressed", "Button", flat(Color(1, 1, 1, 0.06), EMBER))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", flat(Color(0, 0, 0, 0)))
	t.set_color("font_color", "Button", MUTED)
	t.set_color("font_hover_color", "Button", EMBER)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Button", 4)
	t.set_stylebox("normal", "ActiveTab", flat(Color(0, 0, 0, 0), EMBER))
	t.set_color("font_color", "ActiveTab", BONE)
	t.set_stylebox("normal", "PrimaryButton", flat(Color(0, 0, 0, 0), EMBER))
	t.set_color("font_color", "PrimaryButton", EMBER)
	return t

static func hide_empty(node: Node) -> void:
	for child in node.get_children():
		if child.name == "Frame": child.hide()
		elif child is TextureRect and child.texture == null and child.name in ["Art", "Portrait", "Icon"]: child.hide()
		hide_empty(child)

static func apply(hud: Control) -> void:
	var t := build_theme(hud.theme)
	hud.theme = t
	for id in hud.screens:
		hud.screens[id].theme = t
		hide_empty(hud.screens[id])
	# Combat HUD: text straight on the world, no boxes.
	var play: Control = hud.screens.hud
	for path in ["Stage", "Enemies", "Host", "Weapon"]:
		play.get_node(path).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	play.get_node("Host/PortraitFrame").hide()
	# Augment cards: drop the empty art slot and pull the text up.
	var pick: Control = hud.screens.augment
	for i in 3:
		var card: Button = pick.get_node("Card" + str(i))
		var art: Control = card.get_node("Art")
		var lift: float = card.get_node("Tag").position.y - art.position.y
		for child in card.get_children():
			if child != art: child.position.y -= lift
		card.size.y -= lift
		card.position.y += lift * 0.5
		card.add_theme_stylebox_override("normal", flat(Color(0.02, 0.02, 0.03, 0.55)))
		card.add_theme_stylebox_override("hover", flat(Color(0.05, 0.045, 0.04, 0.7), EMBER))
		card.add_theme_stylebox_override("pressed", flat(Color(0.05, 0.045, 0.04, 0.7), EMBER))
	# Pause: no empty portrait column.
	var body: Control = hud.screens.pause.get_node("Body")
	var frame: Control = body.get_node("PortraitFrame")
	var shift: float = body.get_node("Name").position.x - frame.position.x
	frame.hide()
	body.get_node("Portrait").hide()
	var column_edge: float = frame.position.x + frame.size.x - 8.0
	for child in body.get_children():
		# Only the stat column that sat right of the portrait moves; full-width rows stay.
		if child != frame and child.name != "Portrait" and child.position.x >= column_edge: child.position.x -= shift
