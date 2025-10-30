extends Node
class_name ItemDatabase

static var items: Dictionary = {}  # item_id -> item template data

static func load_items():
	var path = "res://data/items/items.json"
	
	if not FileAccess.file_exists(path):
		push_error("Items database not found: " + path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open items database")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Failed to parse items JSON")
		return
	
	var data = json.data
	var items_array = data.get("items", [])
	
	items.clear()
	for item_data in items_array:
		var item_id = item_data.get("id", "")
		if item_id != "":
			items[item_id] = item_data
	
	print("Loaded ", items.size(), " items from database")

static func get_item(item_id: String) -> Dictionary:
	"""Get item template data"""
	return items.get(item_id, {})

static func create_item(item_id: String, stack_count: int = 1) -> Item:
	"""Create a new item instance from template"""
	var template = get_item(item_id)
	if template.is_empty():
		push_error("Item not found in database: " + item_id)
		return null
	
	var item_data = template.duplicate(true)
	if item_data.get("stackable", false):
		item_data["current_stack"] = stack_count
	
	return Item.new(item_data)

static func has_item_template(item_id: String) -> bool:
	return items.has(item_id)
