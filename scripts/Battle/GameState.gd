extends Node
class_name GameState

signal unit_selected(unit)
signal unit_action_complete(unit)
signal battle_loaded(battle_id)
signal battle_won()
signal battle_lost()

# Grid settings
var grid_width: int = 12
var grid_height: int = 8
var grid_size: int = 64

# Current battle
var current_battle_id: String = ""
var current_battle_data: Dictionary = {}
var terrain_data: Array = []

# Game data
var units: Array = []
var player_units: Array = []
var enemy_units: Array = []
var astar: AStar2D

# Turn management
var turn_manager: TurnManager

# References
var grid: TacticalGrid
var ui_panel: Panel
var ui_label: RichTextLabel
var battle_label: Label
var turn_label: Label
var action_buttons: Control
var game_root: Node

func _init():
	astar = AStar2D.new()
	turn_manager = TurnManager.new()

func initialize(game_root_node: Node):
	game_root = game_root_node
	TileTypeManager.load_tile_types()
	setup_ui(game_root)
	PlayerRoster.load_roster()
	
	turn_manager.turn_changed.connect(_on_turn_changed)
	turn_manager.phase_changed.connect(_on_phase_changed)
	
	load_battle("battle_01_outbreak", game_root)

func load_battle(battle_id: String, game_root: Node):
	clear_battle()
	
	var battle_data = BattleLoader.load_battle_data(battle_id)
	if battle_data.is_empty():
		push_error("Failed to load battle: " + battle_id)
		return
	
	current_battle_id = battle_id
	current_battle_data = battle_data
	
	grid_width = current_battle_data.get("grid_width", 12)
	grid_height = current_battle_data.get("grid_height", 8)
	
	terrain_data = BattleLoader.load_terrain_data(current_battle_data)
	
	setup_grid(game_root)
	setup_astar()
	
	var player_positions = parse_positions(current_battle_data.get("player_positions", []))
	var enemies = current_battle_data.get("enemies", [])
	
	spawn_player_units(game_root, player_positions)
	spawn_enemy_units(game_root, enemies)
	
	update_battle_info()
	turn_manager.start_battle()
	update_turn_label()
	battle_loaded.emit(battle_id)
	refresh_display()

func parse_positions(positions: Array) -> Array:
	var result = []
	for pos in positions:
		result.append(Vector2(pos.get("x", 0), pos.get("y", 0)))
	return result

func clear_battle():
	for unit in units:
		unit.queue_free()
	units.clear()
	player_units.clear()
	enemy_units.clear()
	
	if grid:
		grid.queue_free()
		grid = null
	
	terrain_data = []

func setup_grid(parent: Node):
	grid = TacticalGrid.new(grid_width, grid_height, grid_size)
	grid.set_terrain_data(terrain_data)
	parent.add_child(grid)

func setup_astar():
	astar.clear()
	
	# Add all points
	for y in range(grid_height):
		for x in range(grid_width):
			var id = y * grid_width + x
			astar.add_point(id, Vector2(x, y))
			
			# Disable non-traversable tiles ONLY
			var pos = Vector2(x, y)
			if not grid.is_traversable(pos):
				astar.set_point_disabled(id, true)
	
	# Connect adjacent traversable tiles
	for y in range(grid_height):
		for x in range(grid_width):
			var id = y * grid_width + x
			
			if astar.is_point_disabled(id):
				continue
			
			# Right
			if x < grid_width - 1:
				var right_id = id + 1
				if not astar.is_point_disabled(right_id):
					astar.connect_points(id, right_id)
			
			# Down
			if y < grid_height - 1:
				var down_id = id + grid_width
				if not astar.is_point_disabled(down_id):
					astar.connect_points(id, down_id)

func setup_ui(parent: Node):
	var panel_x = grid_width * grid_size + 20
	battle_label = Label.new()
	battle_label.position = Vector2(panel_x, 10)
	battle_label.add_theme_font_size_override("font_size", 16)
	parent.add_child(battle_label)
	
	turn_label = Label.new()
	turn_label.position = Vector2(panel_x, 35)
	turn_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(turn_label)
	
	var phase_banner = Panel.new()
	phase_banner.name = "PhaseBanner"
	phase_banner.size = Vector2(400, 100)  # Will be resized dynamically
	phase_banner.visible = false
	phase_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_banner.z_index = 100
	parent.add_child(phase_banner)
	
	var phase_label = Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.position = Vector2(0, 0)
	phase_label.size = Vector2(400, 100)  # Will be resized dynamically
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 48)
	phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_banner.add_child(phase_label)
	
	ui_panel = Panel.new()
	ui_panel.position = Vector2(panel_x, 70)
	ui_panel.size = Vector2(250, 500)
	ui_panel.visible = false
	parent.add_child(ui_panel)
	
	ui_label = RichTextLabel.new()
	ui_label.position = Vector2(10, 10)
	ui_label.size = Vector2(230, 370)
	ui_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	ui_label.bbcode_enabled = true
	ui_label.fit_content = true
	ui_label.scroll_active = false
	ui_panel.add_child(ui_label)
	
	action_buttons = Control.new()
	action_buttons.position = Vector2(10, 390)
	action_buttons.size = Vector2(230, 100)
	ui_panel.add_child(action_buttons)
	
	var pass_button = Button.new()
	pass_button.text = "Pass Turn"
	pass_button.position = Vector2(0, 0)
	pass_button.size = Vector2(230, 40)
	pass_button.pressed.connect(_on_pass_button_pressed)
	action_buttons.add_child(pass_button)
	
	var end_turn_button = Button.new()
	end_turn_button.text = "End Phase"
	end_turn_button.position = Vector2(0, 50)
	end_turn_button.size = Vector2(230, 40)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	action_buttons.add_child(end_turn_button)

func show_phase_banner(is_player: bool, parent: Node):
	var banner = parent.get_node_or_null("PhaseBanner")
	if not banner:
		return
	
	var label = banner.get_node("PhaseLabel")
	
	# Get viewport dimensions
	var viewport_width = get_viewport().get_visible_rect().size.x if get_viewport() else 1200
	var banner_height = 100
	var center_y = grid_height * grid_size / 2 - banner_height / 2
	
	# Resize banner to full width
	banner.size = Vector2(viewport_width, banner_height)
	label.size = Vector2(viewport_width, banner_height)
	
	# Set text and color
	if is_player:
		label.text = "PLAYER PHASE"
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.5, 1.0)  # Blue
		banner.add_theme_stylebox_override("panel", style)
	else:
		label.text = "ENEMY PHASE"
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.3, 0.3)  # Red
		banner.add_theme_stylebox_override("panel", style)
	
	# Make label text white and bold
	label.add_theme_color_override("font_color", Color.WHITE)
	
	# Position: start off-screen to the left
	banner.position = Vector2(-viewport_width, center_y)
	banner.visible = true
	banner.modulate.a = 0.9  # Solid, not fading
	
	var tween = parent.create_tween()
	
	# Slide in from left to center over 0.4 seconds
	tween.tween_property(banner, "position:x", 0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Hold for 1.2 seconds
	tween.tween_interval(1.2)
	
	# Slide out to the right over 0.4 seconds
	tween.tween_property(banner, "position:x", viewport_width, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Hide when done
	tween.tween_callback(func(): 
		banner.visible = false
	)

func update_battle_info():
	battle_label.text = "Battle: " + current_battle_data.get("name", "Unknown")

func update_turn_label():
	turn_label.text = turn_manager.get_turn_text()

func spawn_player_units(parent: Node, positions: Array):
	var roster = PlayerRoster.player_units
	var max_units = min(roster.size(), positions.size())
	
	for i in range(max_units):
		var unit_data = roster[i]
		var pos = positions[i]
		var unit = create_unit(parent, pos, Color.BLUE, unit_data, true)
		player_units.append(unit)

func spawn_enemy_units(parent: Node, enemy_data: Array):
	for enemy in enemy_data:
		var pos_dict = enemy.get("position", {"x": 0, "y": 0})
		var pos = Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
		var unit = create_unit(parent, pos, Color.RED, enemy, false)
		enemy_units.append(unit)

func create_unit(parent: Node, grid_pos: Vector2, color: Color, data: Dictionary, is_player: bool):
	var unit = Unit.new(grid_pos, color, data.get("name", "Unit"), data.get("move_range", 5), grid_size, is_player)
	unit.from_dict(data)
	
	var area = Area2D.new()
	area.input_pickable = true
	area.input_event.connect(func(viewport, event, shape_idx): 
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_unit_clicked(unit)
	)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = grid_size * 0.35
	collision.shape = shape
	area.add_child(collision)
	unit.add_child(area)
	
	unit.unit_clicked.connect(_on_unit_clicked)
	unit.action_complete.connect(_on_unit_action_complete)
	
	units.append(unit)
	parent.add_child(unit)
	return unit

func _on_unit_clicked(unit: Unit):
	print("Unit clicked: ", unit.unit_name, " Player: ", unit.is_player, " Turn: ", turn_manager.is_player_turn())
	
	# Can't interact with dead units
	if not unit.is_alive():
		print("Unit is dead!")
		return
	
	if not turn_manager.is_player_turn():
		print("Not player turn!")
		return
	
	if not unit.is_player:
		# Clicked enemy unit - try to attack if player unit selected
		if grid.selected_unit and grid.selected_unit.is_player and grid.selected_unit.can_attack():
			var distance = AIController.manhattan_distance(grid.selected_unit.grid_pos, unit.grid_pos)
			print("Trying to attack enemy. Distance: ", distance, " Range: ", grid.selected_unit.attack_range)
			if distance <= grid.selected_unit.attack_range:
				attack_with_unit(grid.selected_unit, unit.grid_pos)
		return
	
	if not unit.can_act():
		print("Unit cannot act but selecting anyway")
		select_unit(unit)
		return
	
	print("Selecting unit: ", unit.unit_name)
	select_unit(unit)
	
func calculate_min_range_cells(start_pos: Vector2, min_range: int) -> Array:
	var cells = []
	
	if min_range <= 0:
		return cells
	
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2(x, y)
			var distance = abs(pos.x - start_pos.x) + abs(pos.y - start_pos.y)
			
			if distance > 0 and distance <= min_range:
				cells.append(pos)
	
	return cells

func select_unit(unit: Unit):
	print("Selecting unit: ", unit.unit_name)
	grid.set_selected_unit(unit)
	update_unit_info(unit)
	
	if unit.can_move():
		var move_range = calculate_move_range(unit.grid_pos, unit.move_range)
		print("Move range cells: ", move_range.size())
		print("First few cells: ", move_range.slice(0, 5))
		grid.set_move_range(move_range)
		print("Grid move_range_cells size: ", grid.move_range_cells.size())
	else:
		print("Unit cannot move")
		grid.set_move_range([])
	
	if unit.can_attack():
		var attack_range = calculate_attack_range(unit.grid_pos, unit.attack_range)
		var min_range_area = calculate_min_range_cells(unit.grid_pos, unit.attack_min_range)
		print("Attack range cells: ", attack_range.size())
		grid.set_attack_range(attack_range)
		grid.set_min_range(min_range_area)
	else:
		print("Unit cannot attack")
		grid.set_attack_range([])
		grid.set_min_range([])
	
	grid.set_path([])
	unit_selected.emit(unit)
	refresh_display()
	print("Selecting unit: ", unit.unit_name)
	grid.set_selected_unit(unit)
	update_unit_info(unit)
	
	if unit.can_move():
		var move_range = calculate_move_range(unit.grid_pos, unit.move_range)
		grid.set_move_range(move_range)
	else:
		grid.set_move_range([])
	
	if unit.can_attack():
		var attack_range = calculate_attack_range(unit.grid_pos, unit.attack_range)
		grid.set_attack_range(attack_range)
	else:
		grid.set_attack_range([])
	
	grid.set_path([])
	unit_selected.emit(unit)
	refresh_display()

func attack_with_unit(attacker: Unit, target_pos: Vector2):
	# Get the primary target (if any)
	var primary_target = null
	for unit in units:
		if unit.grid_pos == target_pos and unit.is_player != attacker.is_player and unit.is_alive():
			primary_target = unit
			break
	
	# Get all units in AoE
	var targets = []
	if attacker.attack_aoe > 0:
		targets = get_units_in_aoe(target_pos, attacker.attack_aoe)
		# Filter to only living enemy units
		var enemy_targets = []
		for unit in targets:
			if unit.is_player != attacker.is_player and unit.is_alive():
				enemy_targets.append(unit)
		targets = enemy_targets
	elif primary_target:
		targets = [primary_target]
	
	if targets.is_empty():
		return
	
	# Show attack animation
	await attacker.attack_unit(targets[0])
	
	# Apply damage to all targets
	for target in targets:
		var damage = max(1, attacker.attack - target.defense)
		# Reduce splash damage for secondary targets
		if target != primary_target and targets.size() > 1:
			damage = int(damage * 0.7)  # 70% damage to splash targets
		
		target.take_damage(damage)
		
		# Remove enemy units when they die, but keep player units as corpses
		if not target.is_alive() and not target.is_player:
			remove_unit(target)
	
	# Mark as attacked
	attacker.has_attacked = true
	
	# Clear attack range and AoE preview
	grid.set_attack_range([])
	grid.set_min_range([])
	grid.set_aoe_preview([])
	
	# Auto-end turn if unit has both moved and attacked
	if attacker.has_moved and attacker.has_attacked:
		attacker.end_turn()
	
	check_battle_end()
	update_unit_info(attacker)
	refresh_display()

func remove_unit(unit: Unit):
	units.erase(unit)
	player_units.erase(unit)
	enemy_units.erase(unit)
	unit.queue_free()
	
func check_all_player_units_acted():
	if not turn_manager.is_player_turn():
		return
	
	# Check if all living player units have acted
	var all_acted = true
	for unit in player_units:
		if unit.is_alive() and not unit.has_acted:
			all_acted = false
			break
	
	if all_acted:
		print("All player units have acted - auto-ending turn")
		end_player_turn()

func _on_unit_action_complete(unit: Unit):
	if unit.is_player:
		update_player_roster(unit)
	
	unit_action_complete.emit(unit)
	
	if grid.selected_unit == unit:
		grid.set_move_range([])
		grid.set_attack_range([])
	
	refresh_display()
	check_all_player_units_acted()

func _on_pass_button_pressed():
	if grid.selected_unit and grid.selected_unit.can_act():
		grid.selected_unit.end_turn()

func _on_end_turn_button_pressed():
	if turn_manager.is_player_turn():
		end_player_turn()

func end_player_turn():
	turn_manager.end_current_turn()
	grid.set_selected_unit(null)
	grid.set_move_range([])
	grid.set_attack_range([])
	ui_panel.visible = false
	refresh_display()

func _on_turn_changed(is_player_turn: bool):
	update_turn_label()
	
	# Show phase banner
	show_phase_banner(is_player_turn, game_root)
	
	# Reset all units for new turn
	for unit in units:
		unit.reset_turn()
	
	refresh_display()
	
	if not is_player_turn:
		# Wait for banner animation to complete before enemy turn
		await game_root.get_tree().create_timer(1.6).timeout
		
		# Check if scene still exists before executing enemy turn
		if not is_instance_valid(grid) or not is_instance_valid(game_root):
			print("Scene was freed, canceling enemy turn")
			return
		
		# Execute enemy turn - pass the grid's scene tree
		await AIController.execute_enemy_turn(self, grid.get_tree())
		
		# Check again if scene still exists
		if not is_instance_valid(grid):
			print("Scene was freed during enemy turn")
			return
		
		check_battle_end()
		
		# Check if any enemies can still act
		var has_active_enemies = false
		for enemy in enemy_units:
			if enemy.is_alive() and not enemy.has_acted:
				has_active_enemies = true
				break
		
		if not has_active_enemies:
			turn_manager.end_current_turn()

func _on_phase_changed(phase: String):
	pass

func check_battle_end():
	var alive_players = 0
	var alive_enemies = 0
	
	for unit in player_units:
		if unit.is_alive():
			alive_players += 1
	
	for unit in enemy_units:
		if unit.is_alive():
			alive_enemies += 1
	
	if alive_players == 0:
		battle_lost.emit()
		print("Battle Lost!")
	elif alive_enemies == 0:
		battle_won.emit()
		print("Battle Won!")

func update_player_roster(unit: Unit):
	for i in range(PlayerRoster.player_units.size()):
		if PlayerRoster.player_units[i].get("name") == unit.unit_name:
			PlayerRoster.player_units[i] = unit.to_dict()
			PlayerRoster.save_roster()
			break

func update_unit_info(unit: Unit):
	ui_panel.visible = true
	
	var status = "Ready" if unit.can_act() else "Acted"
	var status_color = "[color=green]" if unit.can_act() else "[color=gray]"
	var team = "Player" if unit.is_player else "Enemy"
	
	ui_label.text = "[b]" + unit.unit_name + "[/b]\n"
	ui_label.text += "Team: " + team + "\n"
	ui_label.text += "Status: " + status_color + status + "[/color]\n\n"
	
	if unit.is_player:
		ui_label.text += "Level: " + str(unit.level) + "\n"
		ui_label.text += "EXP: " + str(unit.experience) + "\n\n"
	
	ui_label.text += "Health: " + str(unit.health) + "/" + str(unit.max_health) + "\n"
	ui_label.text += "Attack: " + str(unit.attack) + "\n"
	ui_label.text += "Defense: " + str(unit.defense) + "\n"
	ui_label.text += "Move Range: " + str(unit.move_range) + "\n"
	ui_label.text += "Attack Range: " + str(unit.attack_range) + "\n\n"
	
	if unit.is_player and unit.can_act():
		ui_label.text += "[color=yellow]Actions:[/color]\n"
		if unit.can_move():
			ui_label.text += "- Can Move\n"
		if unit.can_attack():
			ui_label.text += "- Can Attack\n"
	
	# Show/hide action buttons
	action_buttons.visible = unit.is_player and turn_manager.is_player_turn()

func get_units_in_aoe(center: Vector2, radius: int) -> Array:
	var units_hit = []
	
	for unit in units:
		var distance = AIController.manhattan_distance(center, unit.grid_pos)
		if distance <= radius:
			units_hit.append(unit)
	
	return units_hit
	
func calculate_move_range(start_pos: Vector2, range: int) -> Array:
	print("Calculating move range from ", start_pos, " with range ", range)
	var cells = []
	var visited = {}
	var queue = [{pos = start_pos, dist = 0}]
	
	visited[str(start_pos)] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var pos = current["pos"]
		var dist = current["dist"]
		
		if dist > 0 and dist <= range and not is_cell_occupied(pos):
			cells.append(pos)
		
		if dist >= range:
			continue
		
		var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for dir in directions:
			var next_pos = pos + dir
			
			if next_pos.x < 0 or next_pos.x >= grid_width or next_pos.y < 0 or next_pos.y >= grid_height:
				continue
			
			var next_key = str(next_pos)
			if visited.has(next_key):
				continue
			
			if not grid.is_traversable(next_pos):
				continue
			
			visited[next_key] = true
			queue.append({"pos": next_pos, "dist": dist + 1})
	print("Found ", cells.size(), " valid cells")
	return cells

func calculate_attack_range(start_pos: Vector2, range: int) -> Array:
	var cells = []
	var min_range = 0
	
	# Get min range from selected unit
	if grid.selected_unit:
		min_range = grid.selected_unit.attack_min_range
	else:
		# If no selected unit, return empty
		return cells
	
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2(x, y)
			var distance = abs(pos.x - start_pos.x) + abs(pos.y - start_pos.y)
			
			# Check if within min and max range
			if distance > min_range and distance <= range:
				# Show cell if there's an enemy OR if unit has AoE (can target ground)
				var has_enemy = false
				for unit in units:
					if unit.grid_pos == pos and unit.is_player != grid.selected_unit.is_player:
						has_enemy = true
						break
				
				# Allow targeting if enemy present OR attacker has AoE
				if has_enemy or (grid.selected_unit and grid.selected_unit.attack_aoe > 0):
					cells.append(pos)
	
	return cells

func is_cell_occupied(grid_pos: Vector2) -> bool:
	for unit in units:
		if unit.grid_pos == grid_pos:
			return true
	return false

func calculate_path(from: Vector2, to: Vector2) -> Array:
	var from_id = get_point_id(from)
	var to_id = get_point_id(to)
	
	# Validate IDs are within bounds
	if from_id < 0 or to_id < 0 or from_id >= (grid_width * grid_height) or to_id >= (grid_width * grid_height):
		return []
	
	# Validate IDs exist in AStar
	if not astar.has_point(from_id) or not astar.has_point(to_id):
		return []
	
	# Get the path directly - returns empty array if no path exists
	var path_ids = astar.get_id_path(from_id, to_id)
	
	# If no path found, return empty
	if path_ids.is_empty():
		return []
	
	# Convert IDs back to Vector2 positions
	var path = []
	for point_id in path_ids:
		if typeof(point_id) != TYPE_INT:
			push_error("Path contains non-integer: " + str(typeof(point_id)))
			continue
		
		var pos = astar.get_point_position(point_id)
		path.append(pos)
	
	return path

func get_point_id(grid_pos: Vector2) -> int:
	return int(grid_pos.y * grid_width + grid_pos.x)

func handle_mouse_motion(mouse_pos: Vector2):
	var selected = grid.selected_unit
	if selected and selected.can_move() and turn_manager.is_player_turn():
		var mouse_grid = grid.world_to_grid(mouse_pos)
		
		# Validate grid position
		if mouse_grid.x < 0 or mouse_grid.x >= grid_width or mouse_grid.y < 0 or mouse_grid.y >= grid_height:
			grid.set_path([])
			grid.set_aoe_preview([])
			refresh_display()
			return
		
		if mouse_grid in grid.move_range_cells:
			var path = calculate_path(selected.grid_pos, mouse_grid)
			grid.set_path(path)
		else:
			grid.set_path([])
		
		refresh_display()
	
	# Show AoE preview when hovering over attack targets
	if selected and selected.can_attack() and selected.attack_aoe > 0 and turn_manager.is_player_turn():
		var mouse_grid = grid.world_to_grid(mouse_pos)
		
		if mouse_grid in grid.attack_range_cells:
			var aoe_cells = []
			for y in range(grid_height):
				for x in range(grid_width):
					var pos = Vector2(x, y)
					var distance = AIController.manhattan_distance(mouse_grid, pos)
					if distance <= selected.attack_aoe:
						aoe_cells.append(pos)
			grid.set_aoe_preview(aoe_cells)
		else:
			grid.set_aoe_preview([])
		
		refresh_display()

func handle_mouse_click(mouse_pos: Vector2):
	if not turn_manager.is_player_turn():
		return
	
	var selected = grid.selected_unit
	if selected:
		var mouse_grid = grid.world_to_grid(mouse_pos)
		
		if mouse_grid.x < 0 or mouse_grid.x >= grid_width or mouse_grid.y < 0 or mouse_grid.y >= grid_height:
			return
		
		# Check if clicking for movement
		if selected.can_move() and mouse_grid in grid.move_range_cells:
			await selected.move_to(mouse_grid, grid.current_path)
			
			# Auto-end turn if unit has already attacked
			if selected.has_attacked:
				selected.end_turn()
			
			# Update ranges after moving
			if selected.can_attack():
				var attack_range = calculate_attack_range(selected.grid_pos, selected.attack_range)
				grid.set_attack_range(attack_range)
			
			grid.set_move_range([])
			update_unit_info(selected)
			refresh_display()
		
		# Check if clicking for attack (including ground targeting for AoE)
		elif selected.can_attack() and mouse_grid in grid.attack_range_cells:
			attack_with_unit(selected, mouse_grid)  # Pass position

func refresh_display():
	if grid:
		grid.draw_grid_display()
	for unit in units:
		if unit:
			unit.draw_unit()
