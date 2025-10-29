extends Node2D
class_name TacticalGrid

const COLOR_GRID = Color(0.3, 0.3, 0.3, 0.3)
const COLOR_MOVE_RANGE = Color(0.3, 0.6, 1.0, 0.4)
const COLOR_ATTACK_RANGE = Color(1.0, 0.3, 0.3, 0.4)
const COLOR_PATH = Color(0.2, 0.8, 0.3, 0.6)
const COLOR_SELECTED = Color(1.0, 1.0, 0.3, 0.8)
const COLOR_BLOCKED = Color(0.4, 0.2, 0.2, 0.6)
const COLOR_MIN_RANGE = Color(0.8, 0.2, 0.2, 0.3)

var grid_width: int
var grid_height: int
var grid_size: int
var terrain_data: Array = []

var selected_unit = null
var move_range_cells = []
var attack_range_cells = []
var aoe_preview_cells = []
var min_range_cells = []
var current_path = []

func _init(width: int, height: int, size: int):
	grid_width = width
	grid_height = height
	grid_size = size

func set_terrain_data(terrain: Array):
	terrain_data = terrain

func is_traversable(grid_pos: Vector2) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= grid_width or grid_pos.y < 0 or grid_pos.y >= grid_height:
		return false
	
	if terrain_data.is_empty():
		return true
	
	var tile = terrain_data[int(grid_pos.y)][int(grid_pos.x)]
	return tile.get("traversable", true)

func draw_grid_display():
	queue_redraw()

func _draw():
	draw_terrain()
	draw_grid_lines()
	draw_move_range()
	draw_min_range()
	draw_attack_range()
	draw_aoe_preview()
	draw_path()
	draw_selection()

func draw_terrain():
	for y in range(grid_height):
		for x in range(grid_width):
			if not terrain_data.is_empty():
				var tile = terrain_data[y][x]
				var tile_type = tile.get("type", "floor")
				var pos = grid_to_world(Vector2(x, y))
				var tile_rect = Rect2(pos - Vector2(grid_size / 2, grid_size / 2), Vector2(grid_size, grid_size))
				
				# Draw different colors based on tile type
				if tile_type == "wall":
					draw_rect(tile_rect, Color(0.2, 0.2, 0.2))
					draw_rect(tile_rect, Color(0.0, 0.0, 0.0), false, 2.0)
				elif tile_type == "crate":
					draw_rect(tile_rect, Color(0.6, 0.4, 0.2))
				elif tile_type == "sandbag":
					draw_rect(tile_rect, Color(0.5, 0.5, 0.3))
				elif tile_type == "door":
					draw_rect(tile_rect, Color(0.4, 0.3, 0.2))
				elif tile_type == "rubble":
					draw_rect(tile_rect, Color(0.4, 0.4, 0.4, 0.5))

func draw_grid_lines():
	for y in range(grid_height + 1):
		draw_line(
			Vector2(0, y * grid_size),
			Vector2(grid_width * grid_size, y * grid_size),
			COLOR_GRID, 1.0
		)
	
	for x in range(grid_width + 1):
		draw_line(
			Vector2(x * grid_size, 0),
			Vector2(x * grid_size, grid_height * grid_size),
			COLOR_GRID, 1.0
		)

func draw_move_range():
	if selected_unit and selected_unit.can_move():
		for cell in move_range_cells:
			var pos = grid_to_world(cell)
			draw_rect(
				Rect2(pos - Vector2(grid_size / 2, grid_size / 2), Vector2(grid_size, grid_size)),
				COLOR_MOVE_RANGE
			)

func draw_min_range():
	if selected_unit and selected_unit.can_attack() and selected_unit.attack_min_range > 0:
		for cell in min_range_cells:
			var pos = grid_to_world(cell)
			draw_rect(
				Rect2(pos - Vector2(grid_size / 2, grid_size / 2), Vector2(grid_size, grid_size)),
				COLOR_MIN_RANGE
			)

func draw_attack_range():
	if selected_unit and selected_unit.can_attack():
		for cell in attack_range_cells:
			var pos = grid_to_world(cell)
			draw_rect(
				Rect2(pos - Vector2(grid_size / 2, grid_size / 2), Vector2(grid_size, grid_size)),
				COLOR_ATTACK_RANGE
			)

func draw_aoe_preview():
	for cell in aoe_preview_cells:
		var pos = grid_to_world(cell)
		draw_circle(pos, grid_size * 0.3, Color(1.0, 0.5, 0.0, 0.3))  # Orange circle

func draw_path():
	if current_path.size() > 1 and selected_unit and selected_unit.can_move():
		for i in range(current_path.size() - 1):
			var start = grid_to_world(current_path[i])
			var end = grid_to_world(current_path[i + 1])
			draw_line(start, end, COLOR_PATH, 4.0)
			draw_circle(end, 6, COLOR_PATH)

func draw_selection():
	if selected_unit:
		var pos = selected_unit.position
		var radius = grid_size * 0.35 + 8
		draw_arc(pos, radius, 0, TAU, 32, COLOR_SELECTED, 3.0)

func grid_to_world(grid_pos: Vector2) -> Vector2:
	return grid_pos * grid_size + Vector2(grid_size / 2, grid_size / 2)

func world_to_grid(world_pos: Vector2) -> Vector2:
	return (world_pos / grid_size).floor()

func set_move_range(cells: Array):
	move_range_cells = cells

func set_attack_range(cells: Array):
	attack_range_cells = cells

func set_path(path: Array):
	current_path = path

func set_selected_unit(unit):
	selected_unit = unit

func set_aoe_preview(cells: Array):
	aoe_preview_cells = cells

func set_min_range(cells: Array):
	min_range_cells = cells
