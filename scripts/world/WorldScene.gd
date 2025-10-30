extends Node2D

var player: WorldPlayer  # Changed from ExplorationPlayer
var world_state: WorldState
var current_map_data: Dictionary = {}
var tile_size: int = 32
var collision_tiles: Array = []

# Rendering
var tile_colors = {
	"wall": Color(0.2, 0.2, 0.2),
	"floor": Color(0.6, 0.6, 0.6),
	"door": Color(0.5, 0.3, 0.2),
	"door_open": Color(0.7, 0.5, 0.3),
	"stairs_up": Color(0.4, 0.4, 0.8),
	"stairs_down": Color(0.3, 0.3, 0.6)
}

func _ready():
	print("WorldScene _ready() called")
	
	# Initialize world state
	world_state = WorldState.new()
	
	# Check if we're returning from battle
	var returning_from_battle = false
	var state_loaded = false
	
	if has_node("/root/GameManager"):
		print("GameManager found")
		var gm = get_node("/root/GameManager")
		print("return_to_world_after_battle: ", gm.return_to_world_after_battle)
		if gm.return_to_world_after_battle:
			returning_from_battle = true
			gm.return_to_world_after_battle = false
			print("Returning from battle!")
	else:
		print("GameManager NOT found")
	
	# Load state if returning from battle
	if returning_from_battle:
		print("Loading world state...")
		state_loaded = world_state.load_from_file()
		if state_loaded:
			print("State loaded successfully")
		else:
			print("No saved state, using defaults")
	
	# Load the map (pass whether we have saved state)
	load_map(world_state.current_map_id, state_loaded)
	spawn_player()
	
	# Apply position
	if player:
		if returning_from_battle and world_state.player_position != Vector2.ZERO:
			# Returning from battle - use saved position
			player.position = world_state.player_position
			print("Player at saved position: ", player.position)
		else:
			# New game or map transition - use map's spawn point
			world_state.player_position = player.position
			print("Player at spawn point: ", player.position)
	
	if player:
		player.battle_triggered.connect(_on_battle_triggered)
		player.interaction_requested.connect(_on_interaction_requested)

func load_map(map_id: String, preserve_state: bool = false):
	world_state.current_map_id = map_id
	world_state.visit_map(map_id)
	
	current_map_data = WorldMap.load_map_data(map_id)
	
	if current_map_data.is_empty():
		push_error("Failed to load map: " + map_id)
		return
	
	tile_size = current_map_data.get("tile_size", 32)
	
	# Only initialize door states from map if we're NOT preserving saved state
	if not preserve_state:
		print("Initializing door states from map data")
		var doors = current_map_data.get("doors", [])
		for door in doors:
			var pos = Vector2(door.position.x, door.position.y)
			world_state.mark_door_open(pos, door.get("is_open", false))
	else:
		print("Preserving loaded door states")
		# Make sure any NEW doors (not in saved state) get default values
		var doors = current_map_data.get("doors", [])
		for door in doors:
			var pos = Vector2(door.position.x, door.position.y)
			var key = WorldState.vector_to_key(pos)
			if not world_state.door_states.has(key):
				world_state.mark_door_open(pos, door.get("is_open", false))
	
	create_collision()
	
	print("Loaded map: ", current_map_data.get("name", "Unknown"))
	print("Door states: ", world_state.door_states)
	queue_redraw()

func create_collision():
	# Clear existing collision
	for collision_body in collision_tiles:
		collision_body.queue_free()
	collision_tiles.clear()
	
	var tiles = current_map_data.get("tiles", [])
	
	for y in range(tiles.size()):
		var row = tiles[y]
		for x in range(row.size()):
			var tile_type = row[x]
			var tile_pos = Vector2(x, y)
			
			# Create collision for walls
			if tile_type == "wall":
				create_collision_tile(x, y)
			
			# Create collision for closed doors
			elif tile_type == "door" and not world_state.is_door_open(tile_pos):
				create_collision_tile(x, y)

func create_collision_tile(x: int, y: int):
	var static_body = StaticBody2D.new()
	static_body.position = Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size / 2)
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(tile_size, tile_size)
	collision_shape.shape = shape
	
	static_body.add_child(collision_shape)
	add_child(static_body)
	collision_tiles.append(static_body)

func spawn_player():
	if player:
		player.queue_free()
	
	player = WorldPlayer.new()
	player.tile_size = tile_size
	
	# Always spawn at the map's defined spawn point
	var spawn = current_map_data.get("spawn_point", {"x": 2, "y": 10})
	player.position = Vector2(spawn.x * tile_size + tile_size / 2, spawn.y * tile_size + tile_size / 2)
	
	add_child(player)
	
	# Setup camera
	var camera = Camera2D.new()
	camera.enabled = true
	player.add_child(camera)

func _draw():
	if current_map_data.is_empty():
		return
	
	var tiles = current_map_data.get("tiles", [])
	
	for y in range(tiles.size()):
		var row = tiles[y]
		for x in range(row.size()):
			var tile_type = row[x]
			var tile_pos = Vector2(x, y)
			
			# Check if this is a door and if it's open
			if tile_type == "door" and world_state.is_door_open(tile_pos):
				tile_type = "door_open"
			
			var color = tile_colors.get(tile_type, Color.MAGENTA)
			
			var rect = Rect2(x * tile_size, y * tile_size, tile_size, tile_size)
			draw_rect(rect, color)
			
			# Draw special indicators
			if tile_type == "stairs_up":
				# Draw up arrow
				draw_line(
					Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size * 0.3),
					Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size * 0.7),
					Color.WHITE, 3.0
				)
				draw_line(
					Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size * 0.3),
					Vector2(x * tile_size + tile_size * 0.3, y * tile_size + tile_size * 0.5),
					Color.WHITE, 3.0
				)
				draw_line(
					Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size * 0.3),
					Vector2(x * tile_size + tile_size * 0.7, y * tile_size + tile_size * 0.5),
					Color.WHITE, 3.0
				)
			elif tile_type == "stairs_down":
				# Draw down arrow
				draw_line(
					Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size * 0.3),
					Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size * 0.7),
					Color.WHITE, 3.0
				)
				draw_line(
					Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size * 0.7),
					Vector2(x * tile_size + tile_size * 0.3, y * tile_size + tile_size * 0.5),
					Color.WHITE, 3.0
				)
				draw_line(
					Vector2(x * tile_size + tile_size / 2, y * tile_size + tile_size * 0.7),
					Vector2(x * tile_size + tile_size * 0.7, y * tile_size + tile_size * 0.5),
					Color.WHITE, 3.0
				)
			
			# Draw grid lines
			draw_rect(rect, Color(0.1, 0.1, 0.1), false, 1.0)

func _on_interaction_requested(tile_pos: Vector2):
	print("Interaction with tile: ", tile_pos)
	
	if tile_pos.x < 0 or tile_pos.y < 0:
		return
	
	var tiles = current_map_data.get("tiles", [])
	if tile_pos.y >= tiles.size() or tile_pos.x >= tiles[int(tile_pos.y)].size():
		return
	
	var tile_type = tiles[int(tile_pos.y)][int(tile_pos.x)]
	
	# Handle doors
	if tile_type == "door":
		toggle_door(tile_pos)
	
	# Handle stairs
	elif tile_type == "stairs_up" or tile_type == "stairs_down":
		use_stairs(tile_pos)

func toggle_door(tile_pos: Vector2):
	var is_open = world_state.is_door_open(tile_pos)
	world_state.mark_door_open(tile_pos, !is_open)
	
	print("Door ", "opened" if !is_open else "closed")
	
	# Recreate collision to update door collision
	create_collision()
	queue_redraw()

func use_stairs(tile_pos: Vector2):
	var transitions = current_map_data.get("transitions", [])
	
	for transition in transitions:
		var trans_pos = Vector2(transition.position.x, transition.position.y)
		if trans_pos == tile_pos:
			print("Using stairs to: ", transition.target_map)
			transition_to_map(transition.target_map, transition.target_position)
			return

func transition_to_map(target_map: String, target_position: Dictionary):
	# Save current position before transitioning
	if player:
		world_state.player_position = player.position
	
	# Save state
	world_state.save_to_file()
	
	# Load new map - preserve state since we just saved it
	load_map(target_map, true)
	
	# Set player to target position
	if player:
		world_state.player_position = Vector2(
			target_position.x * tile_size + tile_size / 2,
			target_position.y * tile_size + tile_size / 2
		)
		player.position = world_state.player_position

func _on_battle_triggered():
	print("Transitioning to battle...")
	
	# Determine which battle based on current zone
	var battle_id = get_current_zone_battle()
	transition_to_battle(battle_id)

func get_current_zone_battle() -> String:
	var player_tile = Vector2(int(player.position.x / tile_size), int(player.position.y / tile_size))
	var zones = current_map_data.get("encounter_zones", [])
	
	for zone in zones:
		var rect = zone.rect
		if (player_tile.x >= rect.x and player_tile.x < rect.x + rect.width and
			player_tile.y >= rect.y and player_tile.y < rect.y + rect.height):
			var battles = zone.get("possible_battles", [])
			if battles.size() > 0:
				return battles[randi() % battles.size()]
	
	return "battle_01_outbreak"

func transition_to_battle(battle_id: String):
	# Save current position and state
	if player:
		world_state.player_position = player.position
	
	world_state.save_to_file()
	print("World state saved before battle")
	
	# Use GameManager to transition
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_battle(battle_id)
	else:
		# Fallback
		get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
