extends Node
class_name BattleLoader

static func load_battle_data(battle_id: String) -> Dictionary:
	var path = "res://data/battles/" + battle_id + ".json"
	var data = load_json_file(path)
	
	if data.is_empty():
		return {}
	
	# Process terrain data if present
	if data.has("tiles"):
		data["terrain"] = process_terrain_tiles(data["tiles"])
	
	return data

static func process_terrain_tiles(tiles_raw: Array) -> Array:
	"""Convert tile type strings to tile data objects with properties"""
	var tiles_processed = []
	
	for row in tiles_raw:
		var processed_row = []
		for tile_type in row:
			processed_row.append({
				"type": tile_type,
				"traversable": TileTypeManager.is_traversable(tile_type),
				"cover": TileTypeManager.get_cover_value(tile_type)
			})
		tiles_processed.append(processed_row)
	
	return tiles_processed

static func load_terrain_data(battle_data: Dictionary) -> Array:
	"""
	Extract terrain data from battle data.
	This replaces the old separate terrain loading system.
	"""
	if battle_data.has("terrain"):
		return battle_data["terrain"]
	
	if battle_data.has("tiles"):
		return process_terrain_tiles(battle_data["tiles"])
	
	return []

static func load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file: " + path)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("JSON parse error in " + path + ": " + json.get_error_message())
		return {}
	
	return json.data
