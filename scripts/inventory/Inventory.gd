extends RefCounted
class_name Inventory

const GRID_WIDTH = 8
const GRID_HEIGHT = 6

# Grid storage - each cell can reference an item and its position
var grid: Array = []  # 2D array of item references
var items: Array = []  # All items in inventory with their grid positions

signal inventory_changed()
signal item_added(item: Item)
signal item_removed(item: Item)

func _init():
	clear_grid()

func clear_grid():
	grid = []
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append(null)
		grid.append(row)
	items = []

func can_place_item(item: Item, grid_x: int, grid_y: int) -> bool:
	"""Check if item can be placed at position"""
	# Check bounds
	if grid_x < 0 or grid_y < 0:
		return false
	if grid_x + item.width > GRID_WIDTH:
		return false
	if grid_y + item.height > GRID_HEIGHT:
		return false
	
	# Check if cells are empty
	for y in range(item.height):
		for x in range(item.width):
			if grid[grid_y + y][grid_x + x] != null:
				return false
	
	return true

func place_item(item: Item, grid_x: int, grid_y: int) -> bool:
	"""Place item at specific position"""
	if not can_place_item(item, grid_x, grid_y):
		return false
	
	# Mark grid cells as occupied
	for y in range(item.height):
		for x in range(item.width):
			grid[grid_y + y][grid_x + x] = item
	
	# Store item with position
	items.append({
		"item": item,
		"x": grid_x,
		"y": grid_y
	})
	
	item_added.emit(item)
	inventory_changed.emit()
	return true

func find_space_for_item(item: Item) -> Vector2:
	"""Find first available space for item, returns Vector2(-1, -1) if none found"""
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if can_place_item(item, x, y):
				return Vector2(x, y)
	return Vector2(-1, -1)

func add_item(item: Item) -> bool:
	"""Try to add item, automatically finding space or stacking"""
	# Try to stack first if stackable
	if item.stackable:
		for item_data in items:
			var existing_item = item_data["item"]
			if existing_item.can_stack_with(item):
				var leftover = existing_item.add_to_stack(item.current_stack)
				if leftover == 0:
					inventory_changed.emit()
					return true
				else:
					item.current_stack = leftover
					# Continue trying to stack or place
	
	# Find space for item
	var pos = find_space_for_item(item)
	if pos.x >= 0:
		return place_item(item, int(pos.x), int(pos.y))
	
	return false

func remove_item(item: Item) -> bool:
	"""Remove item from inventory"""
	for i in range(items.size()):
		if items[i]["item"] == item:
			var item_data = items[i]
			var grid_x = item_data["x"]
			var grid_y = item_data["y"]
			
			# Clear grid cells
			for y in range(item.height):
				for x in range(item.width):
					grid[grid_y + y][grid_x + x] = null
			
			items.remove_at(i)
			item_removed.emit(item)
			inventory_changed.emit()
			return true
	
	return false

func remove_item_by_id(item_id: String, amount: int = 1) -> int:
	"""Remove items by ID, returns amount actually removed"""
	var removed = 0
	
	for item_data in items.duplicate():  # Duplicate to avoid modification during iteration
		var item = item_data["item"]
		if item.item_id == item_id:
			if item.stackable:
				var to_remove = min(amount - removed, item.current_stack)
				item.remove_from_stack(to_remove)
				removed += to_remove
				
				if item.current_stack <= 0:
					remove_item(item)
				else:
					inventory_changed.emit()
				
				if removed >= amount:
					break
			else:
				remove_item(item)
				removed += 1
				
				if removed >= amount:
					break
	
	return removed

func has_item(item_id: String, amount: int = 1) -> bool:
	"""Check if inventory has at least amount of item"""
	var count = get_item_count(item_id)
	return count >= amount

func get_item_count(item_id: String) -> int:
	"""Get total count of item in inventory"""
	var count = 0
	for item_data in items:
		var item = item_data["item"]
		if item.item_id == item_id:
			count += item.current_stack if item.stackable else 1
	return count

func has_key(key_id: String) -> bool:
	"""Check if player has a specific key"""
	for item_data in items:
		var item = item_data["item"]
		if item.is_key() and item.get_key_id() == key_id:
			return true
	return false

func get_item_at(grid_x: int, grid_y: int) -> Item:
	"""Get item at grid position"""
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		return null
	return grid[grid_y][grid_x]

func move_item(item: Item, new_x: int, new_y: int) -> bool:
	"""Move item to new position"""
	# Find current position
	var old_data = null
	for item_data in items:
		if item_data["item"] == item:
			old_data = item_data
			break
	
	if old_data == null:
		return false
	
	var old_x = old_data["x"]
	var old_y = old_data["y"]
	
	# Clear old position
	for y in range(item.height):
		for x in range(item.width):
			grid[old_y + y][old_x + x] = null
	
	# Check if new position is valid
	if not can_place_item(item, new_x, new_y):
		# Restore old position
		for y in range(item.height):
			for x in range(item.width):
				grid[old_y + y][old_x + x] = item
		return false
	
	# Place at new position
	for y in range(item.height):
		for x in range(item.width):
			grid[new_y + y][new_x + x] = item
	
	old_data["x"] = new_x
	old_data["y"] = new_y
	
	inventory_changed.emit()
	return true

func to_dict() -> Dictionary:
	var items_data = []
	for item_data in items:
		items_data.append({
			"item": item_data["item"].to_dict(),
			"x": item_data["x"],
			"y": item_data["y"]
		})
	
	return {
		"grid_width": GRID_WIDTH,
		"grid_height": GRID_HEIGHT,
		"items": items_data
	}

func from_dict(data: Dictionary):
	clear_grid()
	
	var items_data = data.get("items", [])
	for item_data in items_data:
		var item = Item.new(item_data["item"])
		var x = item_data["x"]
		var y = item_data["y"]
		place_item(item, x, y)

func save_to_file(path: String = "user://inventory.json") -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save inventory")
		return false
	
	var json_string = JSON.stringify(to_dict(), "\t")
	file.store_string(json_string)
	file.close()
	return true

func load_from_file(path: String = "user://inventory.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Failed to parse inventory JSON")
		return false
	
	from_dict(json.data)
	return true
