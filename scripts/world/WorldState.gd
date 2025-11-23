extends RefCounted
class_name WorldState

# Current world state
var current_map_id: String = "mansion_f1"
var player_position: Vector2 = Vector2.ZERO
var door_states: Dictionary = {}
var door_unlocked_states: Dictionary = {}
var interactable_states: Dictionary = {}  # Track state of interactables by ID
var explored_tiles: Dictionary = {}
var collected_items: Array = []
var killed_enemies: Array = []
var completed_events: Array = []
var visited_maps: Array = []
var inventory: Inventory

func _init():
	inventory = Inventory.new()

static func vector_to_key(pos: Vector2) -> String:
	return str(int(pos.x)) + "," + str(int(pos.y))

static func key_to_vector(key: String) -> Vector2:
	var parts = key.split(",")
	if parts.size() == 2:
		return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO

func mark_tile_explored(map_id: String, position: Vector2):
	var key = map_id + ":" + vector_to_key(position)
	explored_tiles[key] = true

func is_tile_explored(map_id: String, position: Vector2) -> bool:
	var key = map_id + ":" + vector_to_key(position)
	return explored_tiles.get(key, false)

func explore_room(map_id: String, start_pos: Vector2, tiles: Array):
	"""Flood fill to explore all connected floor tiles from start position"""
	var to_explore = [start_pos]
	var explored_set = {}
	
	while not to_explore.is_empty():
		var pos = to_explore.pop_back()
		var key = str(int(pos.x)) + "," + str(int(pos.y))
		
		# Skip if already explored in this flood fill
		if explored_set.has(key):
			continue
		
		# Check bounds
		if pos.y < 0 or pos.y >= tiles.size():
			continue
		if pos.x < 0 or pos.x >= tiles[int(pos.y)].size():
			continue
		
		var tile_type = tiles[int(pos.y)][int(pos.x)]
		
		# Skip walls
		if tile_type == "wall":
			continue
		
		# Skip closed doors (but mark the door itself as explored)
		if tile_type == "door" and not is_door_open(pos):
			mark_tile_explored(map_id, pos)
			continue
		
		# Mark as explored
		explored_set[key] = true
		mark_tile_explored(map_id, pos)
		
		# Add neighbors
		to_explore.append(pos + Vector2(1, 0))
		to_explore.append(pos + Vector2(-1, 0))
		to_explore.append(pos + Vector2(0, 1))
		to_explore.append(pos + Vector2(0, -1))

func to_dict() -> Dictionary:
	return {
		"current_map_id": current_map_id,
		"player_position": {
			"x": player_position.x,
			"y": player_position.y
		},
		"door_states": door_states,
		"door_unlocked_states": door_unlocked_states,
		"interactable_states": interactable_states,
		"collected_items": collected_items,
		"killed_enemies": killed_enemies,
		"completed_events": completed_events,
		"visited_maps": visited_maps,
		"explored_tiles": explored_tiles,  # Add this
		"inventory": inventory.to_dict()
	}

func from_dict(data: Dictionary):
	current_map_id = data.get("current_map_id", "mansion_f1")
	
	var pos = data.get("player_position", {"x": 0, "y": 0})
	player_position = Vector2(pos.x, pos.y)
	
	door_states = data.get("door_states", {})
	door_unlocked_states = data.get("door_unlocked_states", {})
	interactable_states = data.get("interactable_states", {})
	collected_items = data.get("collected_items", [])
	killed_enemies = data.get("killed_enemies", [])
	completed_events = data.get("completed_events", [])
	visited_maps = data.get("visited_maps", [])
	explored_tiles = data.get("explored_tiles", {})  # Add this
	
	# Load inventory
	if data.has("inventory"):
		inventory.from_dict(data["inventory"])

# Save/Load from file
func save_to_file(path: String = "user://world_state.json") -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: " + path)
		return false
	
	var json_string = JSON.stringify(to_dict(), "\t")
	file.store_string(json_string)
	file.close()
	print("World state saved to: ", path)
	return true

func load_from_file(path: String = "user://world_state.json") -> bool:
	if not FileAccess.file_exists(path):
		print("No save file found at: ", path)
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open file for reading: " + path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Failed to parse world state JSON: " + json.get_error_message())
		return false
	
	from_dict(json.data)
	print("World state loaded from: ", path)
	return true

# Helper methods - now use string keys
func mark_door_open(position: Vector2, is_open: bool):
	var key = vector_to_key(position)
	door_states[key] = is_open

func is_door_open(position: Vector2) -> bool:
	var key = vector_to_key(position)
	return door_states.get(key, false)
	
func mark_door_unlocked(position: Vector2, is_unlocked: bool):
	var key = vector_to_key(position)
	door_unlocked_states[key] = is_unlocked

func is_door_unlocked(position: Vector2) -> bool:
	var key = vector_to_key(position)
	return door_unlocked_states.get(key, false)

func collect_item(item_id: String):
	if not collected_items.has(item_id):
		collected_items.append(item_id)
		print("Collected item: ", item_id)

func has_item(item_id: String) -> bool:
	return collected_items.has(item_id)

func mark_enemy_killed(enemy_id: String):
	if not killed_enemies.has(enemy_id):
		killed_enemies.append(enemy_id)
		print("Enemy killed: ", enemy_id)

func is_enemy_killed(enemy_id: String) -> bool:
	return killed_enemies.has(enemy_id)

func complete_event(event_id: String):
	if not completed_events.has(event_id):
		completed_events.append(event_id)
		print("Event completed: ", event_id)

func is_event_completed(event_id: String) -> bool:
	return completed_events.has(event_id)

func visit_map(map_id: String):
	if not visited_maps.has(map_id):
		visited_maps.append(map_id)

func has_visited_map(map_id: String) -> bool:
	return visited_maps.has(map_id)

func reset():
	current_map_id = "mansion_f1"
	player_position = Vector2.ZERO
	door_states.clear()
	interactable_states.clear()
	collected_items.clear()
	killed_enemies.clear()
	completed_events.clear()
	visited_maps.clear()
	inventory.clear_grid()
	print("World state reset")

# Interactable state management
func save_interactable_state(interactable: Interactable):
	interactable_states[interactable.interactable_id] = interactable.to_dict()

func load_interactable_state(interactable: Interactable) -> bool:
	if interactable_states.has(interactable.interactable_id):
		interactable.from_dict(interactable_states[interactable.interactable_id])
		return true
	return false

func get_interactable_state(interactable_id: String) -> Dictionary:
	return interactable_states.get(interactable_id, {})
