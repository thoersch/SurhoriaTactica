extends Control
class_name ContainerUI

signal container_closed()
signal items_transferred()

@export var cell_size: int = 48
@export var padding: int = 4

var player_inventory: Inventory
var container_inventory: Inventory
var container_name: String = "Container"

var dragging_item: Item = null
var drag_source: String = ""  # "player" or "container"

var background_overlay: ColorRect
var main_panel: Panel
var container_panel: Panel
var player_panel: Panel
var container_grid: Control
var player_grid: Control
var container_label: Label
var player_label: Label
var close_button: Button

func _ready():
	setup_ui()

func setup_ui():
	# Background overlay
	background_overlay = ColorRect.new()
	background_overlay.color = Color(0, 0, 0, 0.8)
	background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background_overlay)
	
	# Main container panel
	main_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_border_width_all(2)
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)
	
	# Title
	var title = Label.new()
	title.text = "CONTAINER"
	title.position = Vector2(20, 15)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	main_panel.add_child(title)
	
	# Container section
	container_label = Label.new()
	container_label.text = "Container"
	container_label.add_theme_font_size_override("font_size", 16)
	container_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	main_panel.add_child(container_label)
	
	container_panel = Panel.new()
	var container_style = StyleBoxFlat.new()
	container_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	container_panel.add_theme_stylebox_override("panel", container_style)
	main_panel.add_child(container_panel)
	
	container_grid = Control.new()
	container_grid.name = "ContainerGrid"
	container_panel.add_child(container_grid)
	
	# Player section
	player_label = Label.new()
	player_label.text = "Your Inventory"
	player_label.add_theme_font_size_override("font_size", 16)
	player_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	main_panel.add_child(player_label)
	
	player_panel = Panel.new()
	var player_style = StyleBoxFlat.new()
	player_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	player_panel.add_theme_stylebox_override("panel", player_style)
	main_panel.add_child(player_panel)
	
	player_grid = Control.new()
	player_grid.name = "PlayerGrid"
	player_panel.add_child(player_grid)
	
	# Close button
	close_button = Button.new()
	close_button.text = "Close [E]"
	close_button.pressed.connect(_on_close_pressed)
	main_panel.add_child(close_button)

func initialize(player_inv: Inventory, container_inv: Inventory, name_text: String):
	player_inventory = player_inv
	container_inventory = container_inv
	container_name = name_text
	
	container_label.text = container_name
	
	update_layout()
	refresh_display()

func update_layout():
	var viewport_size = get_viewport_rect().size
	
	# Calculate sizes
	var grid_width = Inventory.GRID_WIDTH * cell_size
	var grid_height = Inventory.GRID_HEIGHT * cell_size
	var panel_padding = 20
	var section_spacing = 30
	
	# Main panel size - two inventories side by side
	var main_width = grid_width * 2 + panel_padding * 3 + section_spacing
	var main_height = grid_height + 140
	
	main_panel.size = Vector2(main_width, main_height)
	main_panel.position = (viewport_size - main_panel.size) / 2
	
	# Background overlay
	background_overlay.size = viewport_size
	background_overlay.position = Vector2.ZERO
	
	# Container section (left side)
	container_label.position = Vector2(panel_padding, 50)
	container_panel.position = Vector2(panel_padding, 80)
	container_panel.size = Vector2(grid_width + 10, grid_height + 10)
	container_grid.position = Vector2(5, 5)
	
	# Player section (right side)
	var player_x = panel_padding * 2 + grid_width + section_spacing
	player_label.position = Vector2(player_x, 50)
	player_panel.position = Vector2(player_x, 80)
	player_panel.size = Vector2(grid_width + 10, grid_height + 10)
	player_grid.position = Vector2(5, 5)
	
	# Close button
	close_button.size = Vector2(120, 35)
	close_button.position = Vector2(main_width - 140, 15)

func refresh_display():
	queue_redraw()

func _draw():
	if not player_inventory or not container_inventory:
		return
	
	# Draw container inventory
	draw_inventory(container_inventory, container_grid.global_position - global_position, "container")
	
	# Draw player inventory
	draw_inventory(player_inventory, player_grid.global_position - global_position, "player")
	
	# Draw dragging item
	if dragging_item:
		var mouse_pos = get_local_mouse_position()
		draw_item_at_position(dragging_item, mouse_pos, 0.7)

func draw_inventory(inventory: Inventory, offset: Vector2, source: String):
	# Draw grid cells
	for y in range(Inventory.GRID_HEIGHT):
		for x in range(Inventory.GRID_WIDTH):
			var cell_pos = offset + Vector2(x * cell_size, y * cell_size)
			var cell_rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
			
			# Cell background
			var cell_color = Color(0.2, 0.2, 0.2, 0.8) if source == "container" else Color(0.15, 0.25, 0.15, 0.8)
			draw_rect(cell_rect, cell_color)
			
			# Cell border
			draw_rect(cell_rect, Color(0.3, 0.3, 0.3), false, 1)
	
	# Draw items
	for item_data in inventory.items:
		var item = item_data["item"]
		var grid_x = item_data["x"]
		var grid_y = item_data["y"]
		
		# Skip if currently dragging this item
		if dragging_item == item:
			continue
		
		draw_item(item, grid_x, grid_y, offset)

func draw_item(item: Item, grid_x: int, grid_y: int, offset: Vector2, alpha: float = 1.0):
	var item_pos = offset + Vector2(grid_x * cell_size, grid_y * cell_size)
	var item_size = Vector2(item.width * cell_size - padding * 2, item.height * cell_size - padding * 2)
	var item_rect = Rect2(item_pos + Vector2(padding, padding), item_size)
	
	# Item background
	var bg_color = get_item_color(item)
	bg_color.a *= alpha
	draw_rect(item_rect, bg_color)
	
	# Item border
	var border_color = Color(0.5, 0.5, 0.5)
	border_color.a *= alpha
	draw_rect(item_rect, border_color, false, 2)
	
	# Item name
	var font = ThemeDB.fallback_font
	var font_size = 12
	var text = item.item_name
	if item.width == 1:
		text = text.substr(0, 1)
	
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = item_rect.position + (item_rect.size - text_size) / 2 + Vector2(0, font_size / 2)
	
	var text_color = Color.WHITE
	text_color.a *= alpha
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, item_rect.size.x, font_size, text_color)
	
	# Stack count
	if item.stackable and item.current_stack > 1:
		var stack_text = "x" + str(item.current_stack)
		var stack_pos = item_rect.position + Vector2(4, item_rect.size.y - 4)
		draw_string(font, stack_pos, stack_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func draw_item_at_position(item: Item, pos: Vector2, alpha: float = 1.0):
	var item_size = Vector2(item.width * cell_size - padding * 2, item.height * cell_size - padding * 2)
	var item_rect = Rect2(pos, item_size)
	
	var bg_color = get_item_color(item)
	bg_color.a *= alpha
	draw_rect(item_rect, bg_color)
	draw_rect(item_rect, Color(0.7, 0.7, 0.7, alpha), false, 2)
	
	var font = ThemeDB.fallback_font
	var text = item.item_name if item.width > 1 else item.item_name.substr(0, 1)
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	var text_pos = item_rect.position + (item_rect.size - text_size) / 2 + Vector2(0, 6)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, item_rect.size.x, 12, Color(1, 1, 1, alpha))

func get_item_color(item: Item) -> Color:
	match item.item_type:
		Item.ItemType.KEY:
			return Color(0.8, 0.7, 0.2, 0.8)
		Item.ItemType.CONSUMABLE:
			return Color(0.3, 0.8, 0.3, 0.8)
		Item.ItemType.WEAPON:
			return Color(0.8, 0.3, 0.3, 0.8)
		Item.ItemType.AMMO:
			return Color(0.7, 0.5, 0.3, 0.8)
		Item.ItemType.DOCUMENT:
			return Color(0.9, 0.9, 0.8, 0.8)
		_:
			return Color(0.5, 0.5, 0.6, 0.8)

func world_to_grid(pos: Vector2, offset: Vector2) -> Vector2:
	return ((pos - offset) / cell_size).floor()

func _input(event):
	if not visible:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		handle_mouse_click(event)
	elif event is InputEventMouseMotion and dragging_item:
		refresh_display()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func handle_mouse_click(event: InputEventMouseButton):
	var local_pos = get_local_mouse_position()
	
	# Check which inventory was clicked
	var container_offset = container_grid.global_position - global_position
	var player_offset = player_grid.global_position - global_position
	
	var container_rect = Rect2(container_offset, Vector2(Inventory.GRID_WIDTH * cell_size, Inventory.GRID_HEIGHT * cell_size))
	var player_rect = Rect2(player_offset, Vector2(Inventory.GRID_WIDTH * cell_size, Inventory.GRID_HEIGHT * cell_size))
	
	if event.pressed:
		# Start drag
		if container_rect.has_point(local_pos):
			var grid_pos = world_to_grid(local_pos, container_offset)
			var item = container_inventory.get_item_at(int(grid_pos.x), int(grid_pos.y))
			if item:
				dragging_item = item
				drag_source = "container"
		elif player_rect.has_point(local_pos):
			var grid_pos = world_to_grid(local_pos, player_offset)
			var item = player_inventory.get_item_at(int(grid_pos.x), int(grid_pos.y))
			if item:
				dragging_item = item
				drag_source = "player"
	else:
		# End drag
		if dragging_item:
			var target_inventory: Inventory = null
			var target_offset: Vector2
			var target_source: String = ""
			
			if container_rect.has_point(local_pos):
				target_inventory = container_inventory
				target_offset = container_offset
				target_source = "container"
			elif player_rect.has_point(local_pos):
				target_inventory = player_inventory
				target_offset = player_offset
				target_source = "player"
			
			if target_inventory:
				var grid_pos = world_to_grid(local_pos, target_offset)
				
				# Check if transferring between inventories
				if target_source != drag_source:
					# Remove from source
					var source_inventory = container_inventory if drag_source == "container" else player_inventory
					source_inventory.remove_item(dragging_item)
					
					# Add to target
					if target_inventory.can_place_item(dragging_item, int(grid_pos.x), int(grid_pos.y)):
						target_inventory.place_item(dragging_item, int(grid_pos.x), int(grid_pos.y))
						items_transferred.emit()
					else:
						# Can't place, find any space
						var space = target_inventory.find_space_for_item(dragging_item)
						if space.x >= 0:
							target_inventory.place_item(dragging_item, int(space.x), int(space.y))
							items_transferred.emit()
						else:
							# No space, return to source
							source_inventory.add_item(dragging_item)
				else:
					# Moving within same inventory
					if target_inventory.can_place_item(dragging_item, int(grid_pos.x), int(grid_pos.y)):
						target_inventory.move_item(dragging_item, int(grid_pos.x), int(grid_pos.y))
			
			dragging_item = null
			drag_source = ""
			refresh_display()

func _on_close_pressed():
	visible = false
	container_closed.emit()
