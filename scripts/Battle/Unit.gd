extends Node2D
class_name Unit

signal unit_clicked(unit)
signal action_complete(unit)

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

var grid_pos: Vector2
var has_moved: bool = false
var has_attacked: bool = false
var has_acted: bool = false
var is_moving: bool = false
var grid_size: int = 64

func _init(pos: Vector2, color: Color, name: String, move_rng: int = 5, gs: int = 64, player: bool = true):
	grid_pos = pos
	unit_color = color
	unit_name = name
	move_range = move_rng
	grid_size = gs
	is_player = player
	position = grid_to_world(pos)

func grid_to_world(grid_position: Vector2) -> Vector2:
	return grid_position * grid_size + Vector2(grid_size / 2, grid_size / 2)

func reset_turn():
	has_moved = false
	has_attacked = false
	has_acted = false

func can_act() -> bool:
	return not has_acted and not is_moving

func can_move() -> bool:
	return not has_moved and can_act()

func can_attack() -> bool:
	return not has_attacked and can_act()

func end_turn():
	has_acted = true
	action_complete.emit(self)

func draw_unit():
	queue_redraw()

func _draw():
	var radius = grid_size * 0.35
	
	# Dimmed if already acted
	var color = unit_color
	if has_acted:
		color = Color(unit_color.r * 0.5, unit_color.g * 0.5, unit_color.b * 0.5)
	
	# Unit circle
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
	draw_unit()

func is_alive() -> bool:
	return health > 0

func to_dict() -> Dictionary:
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
		"level": level
	}

func from_dict(data: Dictionary):
	unit_name = data.get("name", "Unit")
	move_range = data.get("move_range", 5)
	attack_range = data.get("attack_range", 1)
	attack_min_range = data.get("attack_min_range", 0)
	attack_aoe = data.get("attack_aoe", 0)
	health = data.get("health", 100)
	max_health = data.get("max_health", 100)
	attack = data.get("attack", 10)
	defense = data.get("defense", 5)
	experience = data.get("experience", 0)
	level = data.get("level", 1)
