class_name TileTypeManager

static var tile_types: Dictionary = {}

static func load_tile_types():
	var path = "res://data/tile_types.json"
	
	if not FileAccess.file_exists(path):
		print("Tile types file not found, using defaults")
		initialize_default_types()
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Failed to open tile types file")
		initialize_default_types()
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		print("Failed to parse tile types JSON")
		initialize_default_types()
		return
	
	var data = json.data
	tile_types = data.get("tile_types", {})
	print("Loaded ", tile_types.size(), " tile types")

static func initialize_default_types():
	tile_types = {
		"floor": {
			"traversable": true,
			"cover": 0,
			"description": "Open floor"
		},
		"wall": {
			"traversable": false,
			"cover": 0,
			"description": "Solid wall"
		},
		"door": {
			"traversable": true,
			"cover": 0,
			"description": "Doorway"
		},
		"crate": {
			"traversable": false,
			"cover": 2,
			"description": "Wooden crate"
		},
		"sandbag": {
			"traversable": false,
			"cover": 3,
			"description": "Sandbag barricade"
		},
		"rubble": {
			"traversable": true,
			"cover": 1,
			"description": "Rubble - difficult terrain"
		}
	}

static func is_traversable(tile_type: String) -> bool:
	if not tile_types.has(tile_type):
		return true  # Default to traversable if type unknown
	
	return tile_types[tile_type].get("traversable", true)

static func get_cover_value(tile_type: String) -> int:
	if not tile_types.has(tile_type):
		return 0
	
	return tile_types[tile_type].get("cover", 0)

static func get_tile_description(tile_type: String) -> String:
	if not tile_types.has(tile_type):
		return "Unknown tile"
	
	return tile_types[tile_type].get("description", "")
