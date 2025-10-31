extends Node2D

var player: WorldPlayer
var world_state: WorldState
var current_map_data: Dictionary = {}
var tile_size: int = 32
var collision_tiles: Array = []
var interactables: Array = []  # Array of Interactable objects

# UI for messages
var message_label: Label
var message_layer: CanvasLayer
var inventory_ui: InventoryUI
var container_ui: ContainerUI
var document_ui: DocumentUI

# Rendering
var tile_colors = {
	"wall": Color(0.2, 0.2, 0.2),
	"floor": Color(0.6, 0.6, 0.6),
	"door": Color(0.5, 0.3, 0.2),
	"door_open": Color(0.7, 0.5, 0.3),
	"stairs_up": Color(0.4, 0.4, 0.8),
	"stairs_down": Color(0.3, 0.3, 0.6)
}

# Object rendering emojis (matching the editor)
var object_emojis = {
	"item": "📦",
	"npc": "👤",
	"battle_trigger": "⚔️",
	"event": "⭐",
	"examine": "🔍"
}

func _ready():
	print("WorldScene _ready() called")
	
	# Initialize item database
	ItemDatabase.load_items()
	
	# Initialize world state
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		world_state = gm.world_state
	else:
		world_state = WorldState.new()
	
	# Setup UI
	setup_message_ui()
	setup_inventory_ui()
	setup_container_ui()
	setup_document_ui()
	
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
	
	# Add some test items if inventory is empty (new game)
	if world_state.inventory.items.is_empty():
		print("Adding starting items to inventory...")
		
		# Add some healing items
		var herbs = ItemDatabase.create_item("health_herb", 3)
		if herbs:
			world_state.inventory.add_item(herbs)
		
		# Add some ammo
		var ammo = ItemDatabase.create_item("ammo_handgun", 15)
		if ammo:
			world_state.inventory.add_item(ammo)
	
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
	# Create a CanvasLayer so messages are always in screen space
	message_layer = CanvasLayer.new()
	message_layer.layer = 100  # High layer for visibility
	add_child(message_layer)
	
	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.visible = false
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_layer.add_child(message_label)

func setup_inventory_ui():
	# Create a CanvasLayer so inventory is always in screen space
	var inventory_layer = CanvasLayer.new()
	inventory_layer.name = "InventoryLayer"
	inventory_layer.layer = 100
	add_child(inventory_layer)
	
	inventory_ui = preload("res://scripts/inventory/InventoryUI.gd").new()
	inventory_ui.visible = false
	inventory_ui.item_used.connect(_on_item_used)
	inventory_layer.add_child(inventory_ui)
	
	# Initialize with world state's inventory
	inventory_ui.initialize(world_state.inventory)

func setup_container_ui():
	var container_layer = CanvasLayer.new()
	container_layer.name = "ContainerLayer"
	container_layer.layer = 101  # Above inventory
	add_child(container_layer)
	
	container_ui = preload("res://scripts/inventory/ContainerUI.gd").new()
	container_ui.visible = false
	container_ui.container_closed.connect(_on_container_closed)
	container_ui.items_transferred.connect(_on_items_transferred)
	container_layer.add_child(container_ui)

func setup_document_ui():
	var document_layer = CanvasLayer.new()
	document_layer.name = "DocumentLayer"
	document_layer.layer = 102  # Above containers
	add_child(document_layer)
	
	document_ui = preload("res://scripts/inventory/DocumentUI.gd").new()
	document_ui.visible = false
	document_ui.document_closed.connect(_on_document_closed)
	document_layer.add_child(document_ui)

func _input(event):
	# Toggle inventory with Tab or I key
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_TAB):
		if inventory_ui:
			inventory_ui.toggle_visibility()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_I:
		if inventory_ui:
			inventory_ui.toggle_visibility()
			get_viewport().set_input_as_handled()

func _on_item_used(item: Item):
	if item.item_type == Item.ItemType.CONSUMABLE:
		# For now, just show a message
		# In the future, this could heal player units in the roster
		show_message("Used " + item.item_name)
		
		# Remove the item (or decrease stack)
		if item.stackable:
			item.remove_from_stack(1)
			if item.current_stack <= 0:
				world_state.inventory.remove_item(item)
		else:
			world_state.inventory.remove_item(item)
		
		# Save state
		world_state.save_to_file()

func show_message(text: String, duration: float = 3.0):
	message_label.text = text
	message_label.visible = true
	
	# Position in screen space (CanvasLayer makes this independent of camera)
	var viewport_size = get_viewport_rect().size
	
	# Center horizontally, position in upper-middle of screen
	message_label.position = Vector2(viewport_size.x / 2 - 200, viewport_size.y * 0.25)
	message_label.size = Vector2(400, 60)
	
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
		
		# Explore starting room (from spawn point)
		var spawn = current_map_data.get("spawn_point", {"x": 2, "y": 10})
		var spawn_pos = Vector2(spawn.x, spawn.y)
		var tiles = current_map_data.get("tiles", [])
		world_state.explore_room(map_id, spawn_pos, tiles)
	else:
		print("Preserving loaded door states")
		var doors = current_map_data.get("doors", [])
		for door in doors:
			var pos = Vector2(door.position.x, door.position.y)
			var key = WorldState.vector_to_key(pos)
			if not world_state.door_states.has(key):
				world_state.mark_door_open(pos, door.get("is_open", false))
	
	create_collision()
	load_interactables()
	
	# Load objects if not already loaded
	if not current_map_data.has("objects"):
		current_map_data["objects"] = []
	
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

func load_interactables():
	# Clear existing interactables
	interactables.clear()
	
	var interactables_data = current_map_data.get("interactables", [])
	
	for data in interactables_data:
		var interactable = Interactable.new(data)
		
		# Try to load saved state
		world_state.load_interactable_state(interactable)
		
		interactables.append(interactable)
		
		# Create collision for interactable
		create_interactable_collision(interactable)
	
	print("Loaded ", interactables.size(), " interactables")

func create_interactable_collision(interactable: Interactable):
	var static_body = StaticBody2D.new()
	static_body.position = Vector2(
		interactable.position.x * tile_size + tile_size / 2,
		interactable.position.y * tile_size + tile_size / 2
	)
	
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
	
	# Draw tiles
	for y in range(tiles.size()):
		var row = tiles[y]
		for x in range(row.size()):
			var tile_pos = Vector2(x, y)
			
			# Only draw explored tiles
			if not world_state.is_tile_explored(world_state.current_map_id, tile_pos):
				# Draw black/dark fog
				var rect = Rect2(x * tile_size, y * tile_size, tile_size, tile_size)
				draw_rect(rect, Color(0.05, 0.05, 0.05))
				continue
			
			var tile_type = row[x]
			
			if tile_type == "door" and world_state.is_door_open(tile_pos):
				tile_type = "door_open"
			
			var color = tile_colors.get(tile_type, Color.MAGENTA)
			
			var rect = Rect2(x * tile_size, y * tile_size, tile_size, tile_size)
			draw_rect(rect, color)
			
			# Draw special indicators for stairs
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
			
			# Grid lines
			draw_rect(rect, Color(0.1, 0.1, 0.1), false, 1.0)
	
	# Only draw interactables and objects if their tiles are explored
	for interactable in interactables:
		if world_state.is_tile_explored(world_state.current_map_id, interactable.position):
			draw_interactable(interactable)
	
	# Draw objects (new system) - only if explored
	var objects = current_map_data.get("objects", [])
	var font = ThemeDB.fallback_font
	var font_size = 20
	
	for obj in objects:
		# Skip if object has been collected/interacted with
		if is_object_consumed(obj.id):
			continue
		
		# Skip if not explored
		var obj_pos = Vector2(obj.position.x, obj.position.y)
		if not world_state.is_tile_explored(world_state.current_map_id, obj_pos):
			continue
		
		var pos = obj.position
		var center_x = pos.x * tile_size + tile_size / 2
		var center_y = pos.y * tile_size + tile_size / 2
		
		# Draw white background circle
		draw_circle(Vector2(center_x, center_y), tile_size * 0.4, Color(1.0, 1.0, 1.0, 0.8))
		
		# Draw emoji based on type
		var emoji = object_emojis.get(obj.type, "❓")
		var text_size = font.get_string_size(emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, Vector2(center_x - text_size.x / 2, center_y + text_size.y / 3), 
					emoji, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)

func draw_interactable(interactable: Interactable):
	var pos = Vector2(interactable.position.x * tile_size, interactable.position.y * tile_size)
	var rect = Rect2(pos, Vector2(tile_size, tile_size))
	
	# Draw object as a crate/box
	draw_rect(rect, Color(0.6, 0.5, 0.3))
	
	# Draw darker outline
	draw_rect(rect, Color(0.3, 0.25, 0.15), false, 2.0)
	
	# Draw X pattern on the box
	var padding = 8
	draw_line(
		pos + Vector2(padding, padding),
		pos + Vector2(tile_size - padding, tile_size - padding),
		Color(0.4, 0.3, 0.2), 2.0
	)
	draw_line(
		pos + Vector2(tile_size - padding, padding),
		pos + Vector2(padding, tile_size - padding),
		Color(0.4, 0.3, 0.2), 2.0
	)
	
	# Draw indicator if it has items or documents
	if interactable.has_container:
		# Draw small box icon
		var icon_size = 6
		var icon_pos = pos + Vector2(tile_size - icon_size - 4, 4)
		draw_rect(Rect2(icon_pos, Vector2(icon_size, icon_size)), Color(1.0, 0.8, 0.2))
	
	if interactable.has_document():
		# Draw small document icon
		var icon_size = 6
		var icon_pos = pos + Vector2(4, 4)
		draw_rect(Rect2(icon_pos, Vector2(icon_size, icon_size)), Color(0.9, 0.9, 0.8))

func is_object_consumed(object_id: String) -> bool:
	"""Check if an object has been consumed/interacted with"""
	return world_state.is_event_completed(object_id)

func _on_interaction_requested(tile_pos: Vector2):
	print("Interaction with tile: ", tile_pos)
	
	if tile_pos.x < 0 or tile_pos.y < 0:
		return
	
	# First check for objects at this position (new system)
	var obj = find_object_at(tile_pos)
	if obj != null:
		handle_object_interaction(obj)
		return
	
	# Check for interactable at this position (containers/documents)
	for interactable in interactables:
		if interactable.position == tile_pos:
			interact_with_object(interactable)
			return
	
	# Then check tiles
	var tiles = current_map_data.get("tiles", [])
	if tile_pos.y >= tiles.size() or tile_pos.x >= tiles[int(tile_pos.y)].size():
		return
	
	var tile_type = tiles[int(tile_pos.y)][int(tile_pos.x)]
	
	if tile_type == "door":
		toggle_door(tile_pos)
	elif tile_type == "stairs_up" or tile_type == "stairs_down":
		use_stairs(tile_pos)

# Object system functions (new)
func find_object_at(tile_pos: Vector2):
	"""Find an object at the given tile position"""
	var objects = current_map_data.get("objects", [])
	for obj in objects:
		if obj.position.x == tile_pos.x and obj.position.y == tile_pos.y:
			# Skip if already consumed
			if is_object_consumed(obj.id):
				continue
			return obj
	return null

func handle_object_interaction(obj: Dictionary):
	"""Handle interaction with an object based on its type"""
	print("Interacting with object: ", obj.id, " (", obj.type, ")")
	
	match obj.type:
		"item":
			handle_item_pickup(obj)
		"npc":
			handle_npc_interaction(obj)
		"battle_trigger":
			handle_battle_trigger(obj)
		"event":
			handle_event_trigger(obj)
		"examine":
			handle_examine(obj)

func handle_item_pickup(obj: Dictionary):
	"""Handle picking up an item"""
	var item_id = obj.get("item_id", "")
	var amount = obj.get("amount", 1)
	var examine_text = obj.get("examine_text", "")
	
	if item_id == "":
		show_message("Error: Item has no item_id!")
		return
	
	# Create the item
	var item = ItemDatabase.create_item(item_id, amount)
	if item == null:
		show_message("Error: Item not found in database: " + item_id)
		return
	
	# Try to add to inventory
	if world_state.inventory.add_item(item):
		var item_name = item.item_name
		if amount > 1:
			show_message("Picked up " + item_name + " x" + str(amount))
		else:
			show_message("Picked up " + item_name)
		
		# Mark as collected
		world_state.complete_event(obj.id)
		world_state.save_to_file()
		queue_redraw()
	else:
		show_message("Inventory full! Cannot pick up " + item.item_name)

func handle_npc_interaction(obj: Dictionary):
	"""Handle talking to an NPC"""
	var npc_name = obj.get("npc_name", "NPC")
	var dialogue = obj.get("dialogue", "...")
	var requires_item = obj.get("requires_item", "")
	
	# Check if requires an item
	if requires_item != "":
		if not world_state.inventory.has_item(requires_item):
			show_message(npc_name + ": I need something from you first...", 4.0)
			return
	
	# Show dialogue
	show_message(npc_name + ": " + dialogue, 5.0)

func handle_battle_trigger(obj: Dictionary):
	"""Handle a battle trigger object"""
	var battle_id = obj.get("battle_id", "battle_01_outbreak")
	var once = obj.get("once", true)
	
	# Mark as triggered if one-time
	if once:
		world_state.complete_event(obj.id)
		world_state.save_to_file()
	
	# Start the battle
	show_message("Battle starting!", 1.0)
	await get_tree().create_timer(1.0).timeout
	transition_to_battle(battle_id)

func handle_event_trigger(obj: Dictionary):
	"""Handle a custom event trigger"""
	var event_type = obj.get("event_type", "message")
	var event_data = obj.get("event_data", {})
	var once = obj.get("once", true)
	
	match event_type:
		"message":
			var message = event_data.get("message", "Something happened...")
			show_message(message, 4.0)
		
		"give_item":
			var item_id = event_data.get("item_id", "")
			var amount = event_data.get("amount", 1)
			if item_id != "":
				var item = ItemDatabase.create_item(item_id, amount)
				if item and world_state.inventory.add_item(item):
					show_message("Received: " + item.item_name)
		
		"spawn_enemies":
			show_message("Enemies are approaching!", 2.0)
			# Could trigger a battle here
		
		"unlock_door":
			var door_x = event_data.get("door_x", 0)
			var door_y = event_data.get("door_y", 0)
			var door_pos = Vector2(door_x, door_y)
			world_state.mark_door_open(door_pos, true)
			show_message("You hear a door unlock in the distance...")
			create_collision()
			queue_redraw()
	
	# Mark as triggered if one-time
	if once:
		world_state.complete_event(obj.id)
		world_state.save_to_file()
		queue_redraw()

func handle_examine(obj: Dictionary):
	"""Handle examining a point of interest"""
	var examine_text = obj.get("examine_text", "Nothing special here.")
	var detail_text = obj.get("detail_text", "")
	
	# Check if already examined once
	if world_state.is_event_completed(obj.id + "_examined"):
		if detail_text != "":
			show_message(detail_text, 5.0)
		else:
			show_message(examine_text, 4.0)
	else:
		show_message(examine_text, 4.0)
		world_state.complete_event(obj.id + "_examined")
		world_state.save_to_file()

# Interactable system functions (existing - containers/documents)
func interact_with_object(interactable: Interactable):
	print("Interacting with: ", interactable.name)
	
	# Mark as examined
	if not interactable.is_examined:
		interactable.examine()
		show_message("Examined: " + interactable.name)
	
	# Show description
	show_message(interactable.description, 4.0)
	
	# Handle container
	if interactable.has_container and interactable.container_inventory:
		# Show container UI
		await get_tree().create_timer(0.5).timeout  # Brief delay after message
		container_ui.initialize(world_state.inventory, interactable.container_inventory, interactable.name)
		container_ui.visible = true
	
	# Handle document (after container is closed, or immediately if no container)
	if interactable.has_document():
		if interactable.has_container:
			# Wait for container to close
			await container_ui.container_closed
		
		# Show document
		var doc_title = interactable.name
		var doc_text = interactable.document_text
		if doc_text != "":
			document_ui.show_document(doc_title, doc_text)
	
	# Save state
	world_state.save_interactable_state(interactable)
	world_state.save_to_file()

func _on_container_closed():
	# Save all interactable states when container closes
	for interactable in interactables:
		world_state.save_interactable_state(interactable)
	world_state.save_to_file()

func _on_items_transferred():
	# Auto-save when items are moved
	for interactable in interactables:
		world_state.save_interactable_state(interactable)
	world_state.save_to_file()

func _on_document_closed():
	pass  # Nothing specific to do

# Door functions
func toggle_door(tile_pos: Vector2):
	var door_data = get_door_data(tile_pos)
	var required_key = door_data.get("required_key", "")
	
	if required_key == "":
		# No key required, open it
		world_state.mark_door_open(tile_pos, true)
		show_message("Door opened.")
		
		# Explore the newly accessible area on BOTH sides of the door
		var tiles = current_map_data.get("tiles", [])
		var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for dir in directions:
			var explore_pos = tile_pos + dir
			world_state.explore_room(world_state.current_map_id, explore_pos, tiles)
		
		create_collision()
		queue_redraw()
		return
	
	# Door requires a key
	if world_state.inventory.has_key(required_key):
		# Player has the key!
		world_state.mark_door_open(tile_pos, true)
		var key_name = get_key_name(required_key)
		show_message("Used the " + key_name + ".")
		
		# Explore the newly accessible area on BOTH sides of the door
		var tiles = current_map_data.get("tiles", [])
		var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for dir in directions:
			var explore_pos = tile_pos + dir
			world_state.explore_room(world_state.current_map_id, explore_pos, tiles)
		
		create_collision()
		queue_redraw()
	else:
		# Player doesn't have the key
		var lock_hint = door_data.get("lock_hint", "")
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
	
	# Save interactable states before transitioning
	for interactable in interactables:
		world_state.save_interactable_state(interactable)
	
	world_state.save_to_file()
	
	load_map(target_map, true)
	
	if player:
		world_state.player_position = Vector2(
			target_position.x * tile_size + tile_size / 2,
			target_position.y * tile_size + tile_size / 2
		)
		player.position = world_state.player_position
		
		# Explore the destination room after transitioning
		var target_pos = Vector2(target_position.x, target_position.y)
		var tiles = current_map_data.get("tiles", [])
		world_state.explore_room(target_map, target_pos, tiles)
		queue_redraw()  # Redraw to show the newly explored area

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
