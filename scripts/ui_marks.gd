extends Control
## Non-text tactical geometry only. No simulation reference or system fonts.
var model: Dictionary = {}
var hit_left := 0.0

func _process(dt: float) -> void:
	hit_left = maxf(0, hit_left - dt)
	queue_redraw()

func _draw() -> void:
	if model.is_empty(): return
	var mint := get_theme_color("mint", "Palette")
	var cream := get_theme_color("text", "Palette")
	var danger := get_theme_color("danger", "Palette")
	var center := Vector2(640, 360)
	var tint := mint if model.reachable else cream
	draw_circle(center, 1.7, tint)
	for axis in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]: draw_line(center + axis * 8, center + axis * 13, tint, 1.5, true)
	if model.reachable: draw_arc(center, 23, -PI / 2, -PI / 2 + TAU * model.chance, 48, mint, 2, true)
	if model.get("ghost_charge", 0.0) > 0: draw_arc(center, 30, -PI / 2, -PI / 2 + TAU * model.ghost_charge, 48, get_theme_color("purple", "Palette"), 3, true)
	if model.target_hp >= 0:
		draw_rect(Rect2(607, 398, 66, 3), get_theme_color("line", "Palette"))
		draw_rect(Rect2(607, 398, 66 * model.target_hp, 3), tint)
	if hit_left > 0:
		for v in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]: draw_line(center + v * 7, center + v * 13, get_theme_color("gold", "Palette"), 2, true)
	for segment in model.hazards: draw_line(segment[0], segment[1], danger, 3, true)
	if model.travel > 0:
		var ink := get_theme_color("ink", "Palette")
		ink.a = model.travel
		draw_rect(Rect2(0, 0, 1280, 720), ink)
