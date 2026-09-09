extends Control
## UI frame geometry, not an illustration. Reserved TextureRects remain empty.
@export var layout := "title"

func _draw() -> void:
	var gold := get_theme_color("gold", "Palette")
	var line := get_theme_color("line", "Palette")
	var mint := get_theme_color("mint", "Palette")
	if layout == "title":
		draw_line(Vector2(36, 86), Vector2(36, 617), line, 1, true)
		for y in [86, 343, 617]: diamond(Vector2(36, y), 4, gold)
		draw_line(Vector2(64, 352), Vector2(442, 352), line, 1, true)
		draw_line(Vector2(64, 352), Vector2(164, 352), gold, 2, true)
		# Architectural frame outside the replaceable key-art slot.
		draw_polyline(PackedVector2Array([Vector2(712, 682), Vector2(700, 670), Vector2(700, 50), Vector2(724, 26), Vector2(1230, 26), Vector2(1246, 42), Vector2(1246, 664), Vector2(1230, 694), Vector2(736, 694)]), line, 1, true)
		for x in [724, 1230]: diamond(Vector2(x, 26), 5, gold)
	elif layout == "augment":
		draw_line(Vector2(50, 190), Vector2(1230, 190), line, 1, true)
		draw_line(Vector2(50, 190), Vector2(200, 190), gold, 2, true)
		for i in 3:
			var x := 48 + i * 402
			diamond(Vector2(x + 190, 202), 5, gold)
			draw_line(Vector2(x + 18, 630), Vector2(x + 362, 630), line, 1, true)
	elif layout == "pause":
		draw_line(Vector2(48, 194), Vector2(1230, 194), line, 1, true)
		draw_line(Vector2(48, 194), Vector2(326, 194), gold, 2, true)
		diamond(Vector2(1230, 194), 4, gold)
	elif layout == "hud":
		for point in [Vector2(32, 28), Vector2(1092, 28), Vector2(32, 558), Vector2(998, 574)]:
			draw_line(point + Vector2(0, -3), point + Vector2(30, -3), mint if point.y > 500 else gold, 2, true)

func diamond(at: Vector2, radius: float, tint: Color) -> void:
	draw_polyline(PackedVector2Array([at + Vector2.UP * radius, at + Vector2.RIGHT * radius, at + Vector2.DOWN * radius, at + Vector2.LEFT * radius, at + Vector2.UP * radius]), tint, 1, true)
