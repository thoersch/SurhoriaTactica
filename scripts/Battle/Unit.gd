extends Node2D
class_name Unit

signal unit_clicked(unit)
signal action_complete(unit)
signal unit_leveled_up(unit)

@export var unit_name: String = "Unit"
@export var move_range: int = 5
@export var attack_range: int = 1
@export var attack_min_range: int = 0
@export var attack_aoe: int = 0  # 0 = single target, 1+ = radius of splash
@export var health: int = 100
@export var max_health: int = 100
@export var attack: int = 10
@export var defense: int = 5
@export var unit_color: Color = Color.BLUE
@export var is_player: bool = true
@export var experience: int = 0
@export var level: int = 1
@export var exp_to_next_level: int = 100

# Skill system
var skill_points: int = 0
var unlocked_skills: Array = []  # Array of skill_ids
var equipped_skills: Dictionary = {}  # skill_id -> Skill instance

var unit_icon: Texture2D = null
var icon_loaded: bool = false

var grid_pos: Vector2
var has_moved: bool = false
var has_attacked: bool = false
var has_acted: bool = false
var is_moving: bool = false
var is_dead: bool = false
var grid_size: int = 64

var facing_angle: float = 0.0  # Current angle in radians
var target_facing_angle: float = 0.0  # Target angle for rotation

func _init(pos: Vector2, color: Color, name: String, move_rng: int = 5, gs: int = 64, player: bool = true):
	grid_pos = pos
	unit_color = color
	unit_name = name
	move_range = move_rng
	grid_size = gs
	is_player = player
	position = grid_to_world(pos)
	
	facing_angle = 0.0 if is_player else PI  # 0 = East, PI = West
	target_facing_angle = facing_angle
	
	exp_to_next_level = calculate_exp_to_next_level()
	
	call_deferred("load_unit_icon")

func _process(delta):
	update_facing_rotation(delta)

func grid_to_world(grid_position: Vector2) -> Vector2:
	return grid_position * grid_size + Vector2(grid_size / 2, grid_size / 2)

func reset_turn():
	has_moved = false
	has_attacked = false
	has_acted = false

func can_act() -> bool:
	return not has_acted and not is_moving and is_alive()

func can_move() -> bool:
	return not has_moved and can_act()

func can_attack() -> bool:
	return not has_attacked and can_act()

func end_turn():
	has_acted = true
	action_complete.emit(self)
	
func calculate_exp_for_level(target_level: int) -> int:
	"""Calculate total XP needed to reach a given level (JRPG curve)"""
	# Formula: XP = baseXP * level^exponent
	# This creates a curve like: 100, 300, 600, 1000, 1500, 2100...
	var base_xp = 100
	var exponent = 1.5
	
	var total_xp = 0
	for lvl in range(1, target_level):
		total_xp += int(base_xp * pow(lvl, exponent))
	
	return total_xp

func calculate_exp_to_next_level() -> int:
	"""Calculate XP needed for next level"""
	var current_level_xp = calculate_exp_for_level(level)
	var next_level_xp = calculate_exp_for_level(level + 1)
	return next_level_xp - current_level_xp

func gain_experience(amount: int):
	"""Add experience and check for level up"""
	if not is_player:
		return  # Only player units gain XP
	
	experience += amount
	exp_to_next_level = calculate_exp_to_next_level()
	
	print(unit_name, " gained ", amount, " XP! (", experience, "/", calculate_exp_for_level(level + 1), ")")
	
	# Check for level up - but only trigger first one
	# (subsequent levels will be triggered after stat choice)
	if experience >= calculate_exp_for_level(level + 1):
		level_up()

func check_for_additional_level_up():
	"""Check if unit can level up again after stat choice"""
	if experience >= calculate_exp_for_level(level + 1):
		level_up()

func level_up():
	"""Level up and emit signal for stat choice"""
	level += 1
	exp_to_next_level = calculate_exp_to_next_level()
	
	skill_points += 1
	print(unit_name, " reached level ", level, "!")
	
	# Emit signal for GameState to handle stat choice UI
	emit_signal("unit_leveled_up", self)

func unlock_skill(skill: Skill) -> bool:
	"""Unlock a skill if requirements met"""
	if skill_points < skill.cost_per_rank:
		return false
	
	if not skill.can_unlock(level, unlocked_skills):
		return false
	
	# Spend skill points
	skill_points -= skill.cost_per_rank
	
	# Unlock rank
	skill.unlock_rank()
	
	# Add to unlocked list if first rank
	if skill.current_rank == 1:
		unlocked_skills.append(skill.skill_id)
	
	# Equip skill
	equipped_skills[skill.skill_id] = skill
	
	print(unit_name, " unlocked ", skill.get_rank_description())
	return true

func has_passive_effect(effect_name: String) -> bool:
	"""Check if unit has a passive effect"""
	for skill in equipped_skills.values():
		if skill.passive_effects.has(effect_name):
			return true
	return false

func get_passive_value(effect_name: String) -> int:
	"""Get total value of a passive effect"""
	var total = 0
	for skill in equipped_skills.values():
		if skill.passive_effects.has(effect_name):
			total += skill.passive_effects[effect_name] * skill.current_rank
	return total

func apply_stat_increase(stat_name: String):
	"""Apply chosen stat increase"""
	match stat_name:
		"health":
			max_health += 10
			health += 10  # Also heal the unit
			print(unit_name, " gained +10 Max HP!")
		"attack":
			attack += 3
			print(unit_name, " gained +3 Attack!")
		"defense":
			defense += 2
			print(unit_name, " gained +2 Defense!")
	
	draw_unit()

func snap_to_cardinal_direction(direction: Vector2) -> float:
	"""Snap any direction to nearest cardinal direction (N, E, S, W)"""
	if direction == Vector2.ZERO:
		return facing_angle  # Keep current facing if no direction
	
	# Calculate angle from direction
	var angle = direction.angle()
	
	# Define the 4 cardinal angles
	var EAST = 0.0           # Right
	var SOUTH = PI / 2       # Down
	var WEST = PI            # Left
	var NORTH = -PI / 2      # Up
	
	# Find closest cardinal direction
	var angles = [EAST, SOUTH, WEST, NORTH]
	var closest_angle = EAST
	var min_diff = abs(angle_difference(angle, EAST))
	
	for cardinal_angle in angles:
		var diff = abs(angle_difference(angle, cardinal_angle))
		if diff < min_diff:
			min_diff = diff
			closest_angle = cardinal_angle
	
	return closest_angle

func angle_difference(a: float, b: float) -> float:
	"""Calculate shortest difference between two angles"""
	var diff = fmod(b - a + PI, TAU) - PI
	return diff if diff >= -PI else diff + TAU

func set_facing_direction(direction: Vector2):
	"""Set facing to nearest cardinal direction"""
	if direction == Vector2.ZERO:
		return
	
	# Snap to cardinal direction
	target_facing_angle = snap_to_cardinal_direction(direction)

func update_facing_rotation(delta: float):
	"""Smoothly rotate to target cardinal direction"""
	if abs(angle_difference(facing_angle, target_facing_angle)) < 0.01:
		facing_angle = target_facing_angle
		return
	
	# Smooth rotation
	var rotation_speed = 15.0  # Higher = faster rotation
	var diff = angle_difference(facing_angle, target_facing_angle)
	facing_angle += diff * delta * rotation_speed
	draw_unit()

func draw_unit():
	queue_redraw()

func _draw():
	var radius = grid_size * 0.35
	
	if is_dead:
		# Draw dark circle background
		draw_circle(Vector2.ZERO, radius, Color(0.2, 0.2, 0.2))
		
		# Draw X mark for corpse (larger and more visible)
		var x_size = radius * 1.2
		draw_line(Vector2(-x_size, -x_size), Vector2(x_size, x_size), Color(0.6, 0.0, 0.0), 6.0)
		draw_line(Vector2(x_size, -x_size), Vector2(-x_size, x_size), Color(0.6, 0.0, 0.0), 6.0)
		
		# Optional: Add a circle outline
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.4, 0.0, 0.0), 2.0)
		return
	
	# Dimmed if already acted
	var color = unit_color
	if has_acted:
		color = Color(unit_color.r * 0.5, unit_color.g * 0.5, unit_color.b * 0.5)
	
	draw_circle(Vector2.ZERO, radius, color)
	
	# Draw unit - either icon or circle
	if unit_icon:
		# Apply rotation transform (locked to 4 cardinal directions)
		draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)
		
		# Draw icon
		var icon_size = grid_size * 0.6
		draw_texture_rect(
			unit_icon,
			Rect2(
				Vector2(-icon_size / 2, -icon_size / 2),
				Vector2(icon_size, icon_size)
			),
			false,
			color if has_acted else Color.WHITE
		)
		
		# Reset transform before drawing UI elements
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		
		# Draw border (not rotated)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 2.0)
		
		# Team color indicator (not rotated)
		var indicator_color = Color.BLUE if is_player else Color.RED
		draw_circle(Vector2(0, radius - 8), 5, indicator_color)
		draw_circle(Vector2(0, radius - 8), 5, Color.WHITE, false, 1.5)
	else:
		# Fallback: draw colored circle
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 2.0)
	
	# Health bar
	var bar_width = grid_size * 0.6
	var bar_height = 6
	var bar_pos = Vector2(-bar_width / 2, -radius - 12)
	
	# Background
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.2, 0.2, 0.2))
	
	# Health fill
	var health_percent = float(health) / float(max_health)
	var health_color = Color.GREEN
	if health_percent < 0.3:
		health_color = Color.RED
	elif health_percent < 0.6:
		health_color = Color.YELLOW
	
	draw_rect(Rect2(bar_pos, Vector2(bar_width * health_percent, bar_height)), health_color)
	
	# Level indicator for player units
	if is_player:
		var font = ThemeDB.fallback_font
		var font_size = 12
		var text = "Lv" + str(level)
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, Vector2(-text_size.x / 2, radius + 20), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		unit_clicked.emit(self)

func move_to(target_grid: Vector2, path: Array):
	if path.size() < 2:
		return
	
	is_moving = true
	has_moved = true
	
	# Follow the path
	for i in range(1, path.size()):
		# Calculate direction to next position
		var current_pos = path[i - 1]
		var next_pos = path[i]
		var direction = (next_pos - current_pos)
		
		# Set facing to nearest cardinal direction
		if direction != Vector2.ZERO:
			set_facing_direction(direction)
		
		# Small delay to allow rotation
		await get_tree().create_timer(0.15).timeout
		
		var target = grid_to_world(path[i])
		await move_to_position(target)
	
	grid_pos = target_grid
	is_moving = false

func move_to_position(target: Vector2):
	var start = position
	var distance = start.distance_to(target)
	var duration = distance / 300.0
	var elapsed = 0.0
	
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t = elapsed / duration
		position = start.lerp(target, t)
		await get_tree().process_frame
	
	position = target

func attack_unit(target: Unit):
	has_attacked = true
	
	# Face the target (snapped to cardinal direction)
	var direction = target.grid_pos - grid_pos
	set_facing_direction(direction)
	
	# Wait for rotation
	await get_tree().create_timer(0.2).timeout
	
	# Calculate damage
	var damage = max(1, attack - target.defense)
	target.take_damage(damage)
	
	# Visual feedback
	await show_attack_animation(target)

func show_attack_animation(target: Unit):
	# Simple animation - move toward target and back
	var start_pos = position
	var target_pos = target.position
	var mid_pos = start_pos.lerp(target_pos, 0.3)
	
	# Move toward
	var duration = 0.15
	var elapsed = 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t = elapsed / duration
		position = start_pos.lerp(mid_pos, t)
		await get_tree().process_frame
	
	# Move back
	elapsed = 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t = elapsed / duration
		position = mid_pos.lerp(start_pos, t)
		await get_tree().process_frame
	
	position = start_pos

func take_damage(amount: int):
	health -= amount
	if health < 0:
		health = 0
		die()
	draw_unit()
	
func die():
	is_dead = true
	health = 0
	has_acted = true  # Can't act when dead
	draw_unit()

func is_alive() -> bool:
	return health > 0 and not is_dead

func to_dict() -> Dictionary:
	var skills_data = []
	for skill in equipped_skills.values():
		skills_data.append(skill.to_dict())
	
	return {
		"name": unit_name,
		"move_range": move_range,
		"attack_range": attack_range,
		"attack_min_range": attack_min_range,
		"attack_aoe": attack_aoe,
		"health": health,
		"max_health": max_health,
		"attack": attack,
		"defense": defense,
		"experience": experience,
		"level": level,
		"skill_points": skill_points,
		"skills": skills_data
	}

func from_dict(data: Dictionary):
	unit_name = data.get("name", "Unit")
	move_range = data.get("move_range", 5)
	attack_range = data.get("attack_range", 1)
	attack_aoe = data.get("attack_aoe", 0)
	health = data.get("health", 100)
	max_health = data.get("max_health", 100)
	attack = data.get("attack", 10)
	defense = data.get("defense", 5)
	experience = data.get("experience", 0)
	level = data.get("level", 1)
	skill_points = data.get("skill_points", 0)
	
	# Load skills
	var skills_data = data.get("skills", [])
	for skill_data in skills_data:
		var skill_id = skill_data.get("id", "")
		var skill_template = SkillDatabase.get_skill_by_id(skill_id)
		if skill_template:
			var skill = Skill.new(skill_template.to_dict())
			skill.from_dict(skill_data)
			equipped_skills[skill_id] = skill
			if not skill_id in unlocked_skills:
				unlocked_skills.append(skill_id)

func load_unit_icon():
	"""Load icon based on unit name and type"""
	if icon_loaded:
		return
	
	var icon_base_path = "res://assets/icons/units/"
	var unit_folder = "player/" if is_player else "enemy/"
	
	# Convert unit name to lowercase and replace spaces with underscores
	var icon_name = unit_name.to_lower().replace(" ", "_") + "_icon.png"
	var icon_path = icon_base_path + unit_folder + icon_name
	
	if FileAccess.file_exists(icon_path):
		unit_icon = load(icon_path)
		print("Loaded icon for ", unit_name, ": ", icon_path)
	else:
		print("No icon found for ", unit_name, " at ", icon_path)
	
	icon_loaded = true
