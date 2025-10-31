extends Control
class_name InventoryUI

signal item_selected(item: Item)
signal item_used(item: Item)

@export var cell_size: int = 48
@export var padding: int = 4

var inventory: Inventory
var selected_item: Item = null
var dragging_item: Item = null
var drag_start_pos: Vector2 = Vector2.ZERO

# UI Elements
var background_overlay: ColorRect  # Darkens the screen behind inventory
var grid_container: Control
var info_panel: Panel
var info_label: RichTextLabel
var close_button: Button
var use_button: Button
var drop_button: Button

func _ready():
	setup_ui()
	
func setup_ui():
	# Background overlay (darkens screen, blocks interaction with world)
	background_overlay = ColorRect.new()
	background_overlay.name = "BackgroundOverlay"
	background_overlay.color = Color(0, 0, 0, 0.25)  # Semi-transparent black
	background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Blocks clicks to world
	add_child(background_overlay)
	background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill entire screen
	
	# Main panel background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	
	# Grid container
	grid_container = Control.new()
	grid_container.name = "GridContainer"
	grid_container.position = Vector2(20, 60)
	add_child(grid_container)
	
	# Title label
	var title = Label.new()
	title.text = "INVENTORY"
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	add_child(title)
	
	# Info panel (right side)
	info_panel = Panel.new()
	info_panel.name = "InfoPanel"
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	info_style.border_color = Color(0.3, 0.3, 0.3)
	info_style.set_border_width_all(1)
	info_panel.add_theme_stylebox_override("panel", info_style)
	info_panel.visible = false
	add_child(info_panel)
	
	# Info label
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.scroll_active = false
	info_label.position = Vector2(10, 10)
	info_panel.add_child(info_label)
	
	# Use button
	use_button = Button.new()
	use_button.text = "Use"
	use_button.pressed.connect(_on_use_button_pressed)
	info_panel.add_child(use_button)
	
	# Drop button
	drop_button = Button.new()
	drop_button.text = "Drop"
	drop_button.pressed.connect(_on_drop_button_pressed)
	info_panel.add_child(drop_button)
	
	# Close button
	close_button = Button.new()
	close_button.text = "Close [Tab]"
	close_button.pressed.connect(_on_close_button_pressed)
	add_child(close_button)

func initialize(inv: Inventory):
	inventory = inv
	inventory.inventory_changed.connect(_on_inventory_changed)
	update_size()
	refresh_display()

func update_size():
	if not inventory:
		return
	
	var grid_width = Inventory.GRID_WIDTH * cell_size
	var grid_height = Inventory.GRID_HEIGHT * cell_size
	
	# Main panel size
	size = Vector2(grid_width + 400, grid_height + 120)
	
	# Info panel position and size
	info_panel.position = Vector2(grid_width + 40, 60)
	info_panel.size = Vector2(320, grid_height)
	
	# Info label size
	info_label.size = Vector2(300, grid_height - 120)
	
	# Button positions
	use_button.position = Vector2(10, grid_height - 100)
	use_button.size = Vector2(300, 40)
	
	drop_button.position = Vector2(10, grid_height - 50)
	drop_button.size = Vector2(300, 40)
	
	# Close button
	close_button.position = Vector2(size.x - 120, 20)
	close_button.size = Vector2(100, 30)
	
	# Center on screen - call this whenever we need to recenter
	center_on_screen()

func center_on_screen():
	# Get the actual viewport size (window size)
	var viewport_size = get_viewport_rect().size
	position = (viewport_size - size) / 2
	
	# Ensure background overlay fills the entire screen
	if background_overlay:
		background_overlay.size = viewport_size
		background_overlay.position = -position  # Offset to fill screen from inventory's position

func refresh_display():
	queue_redraw()

func _draw():
	if not inventory:
		return
	
	var grid_offset = grid_container.position
	
	# Draw grid cells
	for y in range(Inventory.GRID_HEIGHT):
		for x in range(Inventory.GRID_WIDTH):
			var cell_pos = grid_offset + Vector2(x * cell_size, y * cell_size)
			var cell_rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
			
			# Cell background
			draw_rect(cell_rect, Color(0.2, 0.2, 0.2, 0.8))
			
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
		
		draw_item(item, grid_x, grid_y, grid_offset)
	
	# Draw dragging item (on top)
	if dragging_item:
		var mouse_pos = get_local_mouse_position()
		var grid_pos = world_to_grid(mouse_pos - grid_offset)
		
		# Draw semi-transparent at mouse position
		var item_pos = grid_offset + grid_pos * cell_size
		draw_item(dragging_item, grid_pos.x, grid_pos.y, grid_offset, 0.6)
		
		# Show if placement is valid
		var can_place = inventory.can_place_item(dragging_item, int(grid_pos.x), int(grid_pos.y))
		var indicator_color = Color.GREEN if can_place else Color.RED
		var item_rect = Rect2(
			item_pos,
			Vector2(dragging_item.width * cell_size, dragging_item.height * cell_size)
		)
		draw_rect(item_rect, indicator_color, false, 3)

func draw_item(item: Item, grid_x: int, grid_y: int, offset: Vector2, alpha: float = 1.0):
	var item_pos = offset + Vector2(grid_x * cell_size, grid_y * cell_size)
	var item_size = Vector2(item.width * cell_size - padding * 2, item.height * cell_size - padding * 2)
	var item_rect = Rect2(item_pos + Vector2(padding, padding), item_size)
	
	# Item background color based on type
	var bg_color = get_item_color(item)
	bg_color.a *= alpha
	draw_rect(item_rect, bg_color)
	
	# Item border
	var border_color = Color(0.5, 0.5, 0.5) if item != selected_item else Color(1.0, 1.0, 0.3)
	border_color.a *= alpha
	draw_rect(item_rect, border_color, false, 2)
	
	# Item name (abbreviated if needed)
	var font = ThemeDB.fallback_font
	var font_size = 12
	var text = item.item_name
	if item.width == 1:
		text = text.substr(0, 1)  # First letter only for small items
	
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

func world_to_grid(pos: Vector2) -> Vector2:
	return (pos / cell_size).floor()

func _input(event):
	if not visible or not inventory:
		return
	
	var grid_offset = grid_container.position
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos = get_local_mouse_position()
			var grid_pos = world_to_grid(local_pos - grid_offset)
			
			if event.pressed:
				# Start dragging
				var item = inventory.get_item_at(int(grid_pos.x), int(grid_pos.y))
				if item:
					dragging_item = item
					drag_start_pos = grid_pos
					selected_item = item
					update_info_panel(item)
					refresh_display()
			else:
				# Stop dragging
				if dragging_item:
					# Try to place item at new position
					if inventory.can_place_item(dragging_item, int(grid_pos.x), int(grid_pos.y)):
						inventory.move_item(dragging_item, int(grid_pos.x), int(grid_pos.y))
					
					dragging_item = null
					refresh_display()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right click to select/deselect
			var local_pos = get_local_mouse_position()
			var grid_pos = world_to_grid(local_pos - grid_offset)
			var item = inventory.get_item_at(int(grid_pos.x), int(grid_pos.y))
			
			if item:
				selected_item = item
				update_info_panel(item)
			else:
				selected_item = null
				info_panel.visible = false
			
			refresh_display()
	
	elif event is InputEventMouseMotion:
		if dragging_item:
			refresh_display()

func update_info_panel(item: Item):
	if not item:
		info_panel.visible = false
		return
	
	info_panel.visible = true
	
	# Build info text
	var text = "[b]" + item.item_name + "[/b]\n\n"
	text += item.description + "\n\n"
	
	text += "[color=gray]Type:[/color] " + get_item_type_name(item) + "\n"
	text += "[color=gray]Size:[/color] " + str(item.width) + "x" + str(item.height) + "\n"
	
	if item.stackable:
		text += "[color=gray]Stack:[/color] " + str(item.current_stack) + "/" + str(item.max_stack) + "\n"
	
	if item.item_type == Item.ItemType.CONSUMABLE and item.heal_amount > 0:
		text += "\n[color=green]" + item.effect_description + "[/color]"
	
	info_label.text = text
	
	# Show/hide use button based on item type
	use_button.visible = item.item_type == Item.ItemType.CONSUMABLE
	use_button.disabled = false  # Could add logic for battle-only items

func get_item_type_name(item: Item) -> String:
	match item.item_type:
		Item.ItemType.KEY:
			return "Key"
		Item.ItemType.CONSUMABLE:
			return "Consumable"
		Item.ItemType.WEAPON:
			return "Weapon"
		Item.ItemType.AMMO:
			return "Ammunition"
		Item.ItemType.DOCUMENT:
			return "Document"
		Item.ItemType.QUEST_ITEM:
			return "Quest Item"
		_:
			return "Item"

func _on_inventory_changed():
	refresh_display()
	if selected_item:
		# Check if selected item still exists
		var still_exists = false
		for item_data in inventory.items:
			if item_data["item"] == selected_item:
				still_exists = true
				break
		
		if not still_exists:
			selected_item = null
			info_panel.visible = false

func _on_use_button_pressed():
	if selected_item and selected_item.item_type == Item.ItemType.CONSUMABLE:
		item_used.emit(selected_item)

func _on_drop_button_pressed():
	if selected_item:
		inventory.remove_item(selected_item)
		selected_item = null
		info_panel.visible = false

func _on_close_button_pressed():
	visible = false

func toggle_visibility():
	visible = not visible
	if visible:
		center_on_screen()  # Recenter every time we open
		refresh_display()
