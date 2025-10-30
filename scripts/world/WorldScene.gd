extends Node2D

var player: WorldPlayer
var world_state: WorldState
var current_map_data: Dictionary = {}
var tile_size: int = 32
var collision_tiles: Array = []

# UI for messages
var message_label: Label

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
	
	# Initialize item database
	ItemDatabase.load_items()
	
	# Initialize world state
	world_state = WorldState.new()
	
	# Setup message label
	setup_message_ui()
	
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
			player.position = world_state.player_position
			print("Player at saved position: ", player.position)
		else:
			world_state.player_position = player.position
			print("Player at spawn point: ", player.position)
	
	if player:
		player.battle_triggered.connect(_on_battle_triggered)
		player.interaction_requested.connect(_on_interaction_requested)

func setup_message_ui():
	message_label = Label.new()
	message_label.position = Vector2(20, 20)
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.visible = false
	add_child(message_label)

func show_message(text: String, duration: float = 3.0):
	message_label.text = text
	message_label.visible = true
	
	# Hide after duration
	await get_tree().create_timer(duration).timeout
	if message_label:
		message_label.visible = false

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
	for collision_body in collision_tiles:
		collision_body.queue_free()
	collision_tiles.clear()
	
	var tiles = current_map_data.get("tiles", [])
	
	for y in range(tiles.size()):
		var row = tiles[y]
		for x in range(row.size()):
			var tile_type = row[x]
			var tile_pos = Vector2(x, y)
			
			if tile_type == "wall":
				create_collision_tile(x, y)
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
	
	var spawn = current_map_data.get("spawn_point", {"x": 2, "y": 10})
	player.position = Vector2(spawn.x * tile_size + tile_size / 2, spawn.y * tile_size + tile_size / 2)
	
	add_child(player)
	
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
			
			if tile_type == "door" and world_state.is_door_open(tile_pos):
				tile_type = "door_open"
			
			var color = tile_colors.get(tile_type, Color.MAGENTA)
			
			var rect = Rect2(x * tile_size, y * tile_size, tile_size, tile_size)
			draw_rect(rect, color)
			
			# Draw special indicators
			if tile_type == "stairs_up":
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
			
			draw_rect(rect, Color(0.1, 0.1, 0.1), false, 1.0)

func _on_interaction_requested(tile_pos: Vector2):
	print("Interaction with tile: ", tile_pos)
	
	if tile_pos.x < 0 or tile_pos.y < 0:
		return
	
	var tiles = current_map_data.get("tiles", [])
	if tile_pos.y >= tiles.size() or tile_pos.x >= tiles[int(tile_pos.y)].size():
		return
	
	var tile_type = tiles[int(tile_pos.y)][int(tile_pos.x)]
	
	if tile_type == "door":
		toggle_door(tile_pos)
	elif tile_type == "stairs_up" or tile_type == "stairs_down":
		use_stairs(tile_pos)

func toggle_door(tile_pos: Vector2):
	var is_open = world_state.is_door_open(tile_pos)
	
	if is_open:
		# Close door
		world_state.mark_door_open(tile_pos, false)
		show_message("Door closed.")
		create_collision()
		queue_redraw()
		return
	
	# Try to open door - check if locked
	var door_data = get_door_data(tile_pos)
	if door_data == null:
		# No door data, just open it
		world_state.mark_door_open(tile_pos, true)
		show_message("Door opened.")
		create_collision()
		queue_redraw()
		return
	
	var required_key = door_data.get("required_key", "")
	var lock_hint = door_data.get("lock_hint", "This door is locked.")
	
	if required_key == "":
		# No key required, open it
		world_state.mark_door_open(tile_pos, true)
		show_message("Door opened.")
		create_collision()
		queue_redraw()
		return
	
	# Door requires a key
	if world_state.inventory.has_key(required_key):
		# Player has the key!
		world_state.mark_door_open(tile_pos, true)
		var key_name = get_key_name(required_key)
		show_message("Used the " + key_name + ".")
		create_collision()
		queue_redraw()
	else:
		# Player doesn't have the key
		show_message(lock_hint, 4.0)

func get_door_data(tile_pos: Vector2) -> Dictionary:
	"""Get door data from map"""
	var doors = current_map_data.get("doors", [])
	for door in doors:
		var door_pos = Vector2(door.position.x, door.position.y)
		if door_pos == tile_pos:
			return door
	return {}

func get_key_name(key_id: String) -> String:
	"""Get display name for a key"""
	var item_data = ItemDatabase.get_item("key_" + key_id)
	if not item_data.is_empty():
		return item_data.get("name", key_id.capitalize() + " Key")
	return key_id.capitalize() + " Key"

func use_stairs(tile_pos: Vector2):
	var transitions = current_map_data.get("transitions", [])
	
	for transition in transitions:
		var trans_pos = Vector2(transition.position.x, transition.position.y)
		if trans_pos == tile_pos:
			print("Using stairs to: ", transition.target_map)
			transition_to_map(transition.target_map, transition.target_position)
			return

func transition_to_map(target_map: String, target_position: Dictionary):
	if player:
		world_state.player_position = player.position
	
	world_state.save_to_file()
	
	load_map(target_map, true)
	
	if player:
		world_state.player_position = Vector2(
			target_position.x * tile_size + tile_size / 2,
			target_position.y * tile_size + tile_size / 2
		)
		player.position = world_state.player_position

func _on_battle_triggered():
	print("Transitioning to battle...")
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
	if player:
		world_state.player_position = player.position
	
	world_state.save_to_file()
	print("World state saved before battle")
	
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").start_battle(battle_id)
	else:
		get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
