class_name AIController

static func execute_enemy_turn(game_state, scene_tree):
	await scene_tree.create_timer(0.5).timeout
	
	for enemy in game_state.enemy_units:
		if not enemy.is_alive() or enemy.has_acted:
			continue
		
		# Simple AI: Move toward nearest player, attack if in range
		var nearest_player = find_nearest_target(enemy, game_state.player_units)
		
		if nearest_player:
			# Check if already in attack range
			var distance = manhattan_distance(enemy.grid_pos, nearest_player.grid_pos)
			
			if distance <= enemy.attack_range:
				# Attack
				await enemy.attack_unit(nearest_player)
				enemy.end_turn()
				game_state.refresh_display()
				await scene_tree.create_timer(0.3).timeout
			else:
				# Move toward player
				var move_cells = game_state.calculate_move_range(enemy.grid_pos, enemy.move_range)
				var best_cell = find_best_move_toward(enemy.grid_pos, nearest_player.grid_pos, move_cells)
				
				if best_cell != Vector2(-1, -1):
					var path = game_state.calculate_path(enemy.grid_pos, best_cell)
					if path.size() > 0:
						await enemy.move_to(best_cell, path)
						game_state.refresh_display()
						await scene_tree.create_timer(0.3).timeout
					
					# Check if now in attack range after moving
					distance = manhattan_distance(enemy.grid_pos, nearest_player.grid_pos)
					if distance <= enemy.attack_range:
						await enemy.attack_unit(nearest_player)
				
				enemy.end_turn()
				game_state.refresh_display()
				await scene_tree.create_timer(0.3).timeout

static func find_nearest_target(unit: Unit, targets: Array) -> Unit:
	var nearest = null
	var min_distance = 9999
	
	for target in targets:
		if not target.is_alive():
			continue
		
		var distance = manhattan_distance(unit.grid_pos, target.grid_pos)
		if distance < min_distance:
			min_distance = distance
			nearest = target
	
	return nearest

static func manhattan_distance(a: Vector2, b: Vector2) -> int:
	return int(abs(a.x - b.x) + abs(a.y - b.y))

static func find_best_move_toward(from: Vector2, to: Vector2, available_cells: Array) -> Vector2:
	var best_cell = Vector2(-1, -1)
	var min_distance = 9999
	
	for cell in available_cells:
		var distance = manhattan_distance(cell, to)
		if distance < min_distance:
			min_distance = distance
			best_cell = cell
	
	return best_cell
