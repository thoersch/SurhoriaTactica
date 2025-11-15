extends Node2D
class_name LOSOverlay

var grid_size: int = 64
var los_data: Dictionary = {}

func _init(gs: int = 64):
	grid_size = gs
	z_index = 100  # Draw on top of everything

func set_los_data(data: Dictionary):
	los_data = data
	queue_redraw()

func _draw():
	if los_data.is_empty():
		return
	
	if not los_data.has("target_pos"):
		return
	
	var target_pos = los_data["target_pos"]
	var cell_rect = Rect2(
		target_pos.x * grid_size,
		target_pos.y * grid_size,
		grid_size,
		grid_size
	)
	
	# If blocked, draw red X
	if los_data.get("blocked", false):
		draw_blocked_indicator(cell_rect)
		draw_blocked_text(cell_rect)
		return
	
	# If coverage > 0, draw coverage indicator
	var coverage = los_data.get("coverage", 0)
	if coverage > 0:
		draw_coverage_indicator(cell_rect, coverage)
	
	# Draw damage preview if we have target unit
	if los_data.has("target_unit"):
		draw_damage_preview(cell_rect, los_data)

func draw_blocked_indicator(rect: Rect2):
	# Draw red X over the cell
	var color = Color(1.0, 0.2, 0.2, 0.8)
	var padding = grid_size * 0.2
	
	# Draw X with thicker lines for visibility
	draw_line(
		rect.position + Vector2(padding, padding),
		rect.position + rect.size - Vector2(padding, padding),
		color,
		6.0
	)
	draw_line(
		rect.position + Vector2(rect.size.x - padding, padding),
		rect.position + Vector2(padding, rect.size.y - padding),
		color,
		6.0
	)

func draw_blocked_text(rect: Rect2):
	var font = ThemeDB.fallback_font
	var text = "BLOCKED"
	var font_size = 14
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = rect.position + (rect.size - text_size) / 2 + Vector2(0, font_size / 2)
	
	# Draw background with more opacity
	var bg_rect = Rect2(text_pos - Vector2(4, font_size / 2 + 2), text_size + Vector2(8, 4))
	draw_rect(bg_rect, Color(0, 0, 0, 0.9))
	
	# Draw text
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 0.3, 0.3))

func draw_coverage_indicator(rect: Rect2, coverage: int):
	# Draw semi-transparent overlay showing coverage
	var color = Color(1.0, 0.6, 0.2, 0.4)  # Orange, more visible
	draw_rect(rect, color)
	
	# Draw border
	draw_rect(rect, Color(1.0, 0.5, 0.0, 1.0), false, 3.0)

func draw_damage_preview(rect: Rect2, data: Dictionary):
	var font = ThemeDB.fallback_font
	var base_damage = data.get("base_damage", 0)
	var final_damage = data.get("final_damage", 0)
	var coverage = data.get("coverage", 0)
	
	var text = ""
	if coverage > 0:
		# Show damage reduction
		text = str(base_damage) + " → " + str(final_damage)
	else:
		# No coverage, just show damage
		text = str(final_damage)
	
	var font_size = 16
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = rect.position + (rect.size - text_size) / 2 + Vector2(0, font_size / 2 - 10)
	
	# Draw background with more opacity
	var bg_rect = Rect2(text_pos - Vector2(6, font_size / 2 + 2), text_size + Vector2(12, 4))
	draw_rect(bg_rect, Color(0, 0, 0, 0.9))
	
	# Draw damage text
	var damage_color = Color(1.0, 1.0, 0.3) if coverage == 0 else Color(1.0, 0.7, 0.3)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, damage_color)
	
	# Draw coverage percentage below if applicable
	if coverage > 0:
		var coverage_text = str(coverage) + "% cover"
		var coverage_font_size = 12
		var coverage_text_size = font.get_string_size(coverage_text, HORIZONTAL_ALIGNMENT_CENTER, -1, coverage_font_size)
		var coverage_text_pos = rect.position + Vector2(
			(rect.size.x - coverage_text_size.x) / 2,
			rect.size.y / 2 + 10
		)
		
		# Background for coverage text
		var coverage_bg_rect = Rect2(coverage_text_pos - Vector2(4, coverage_font_size / 2 + 2), coverage_text_size + Vector2(8, 4))
		draw_rect(coverage_bg_rect, Color(0, 0, 0, 0.9))
		
		draw_string(font, coverage_text_pos, coverage_text, HORIZONTAL_ALIGNMENT_CENTER, -1, coverage_font_size, Color(1.0, 0.6, 0.2))
