extends Node
class_name BattleLoader

static func load_battle_data(battle_id: String) -> Dictionary:
	var path = "res://data/battles/" + battle_id + ".json"
	return load_json_file(path)

static func load_terrain_data(terrain_id: String) -> Array:
	var path = "res://data/terrain/" + terrain_id + ".json"
	var data = load_json_file(path)
	
	if data.is_empty():
		print("No terrain found for: " + terrain_id)
		return []
	
	# Convert string tile types to tile data objects
	var tiles_raw = data.get("tiles", [])
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
