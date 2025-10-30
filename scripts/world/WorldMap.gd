extends RefCounted
class_name WorldMap

static func load_map_data(map_id: String) -> Dictionary:
	var path = "res://data/world_maps/" + map_id + ".json"
	var data = load_json_file(path)
	
	# If loading failed or returned empty, use fallback
	if data.is_empty():
		print("Map file not found, using fallback: " + path)
		return {}
	
	return data

static func load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		print("Map file not found, using fallback: " + path)
		return {}  # Return empty so we use fallback
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("JSON parse error in " + path)
		return {}
	
	var parsed_data = json.data
	
	# If tiles array is empty in JSON, don't use it
	if parsed_data.get("tiles", []).is_empty():
		return {}
	
	return parsed_data
