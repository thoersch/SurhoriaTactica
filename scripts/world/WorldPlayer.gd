extends CharacterBody2D
class_name WorldPlayer

signal battle_triggered()
signal interaction_requested(tile_pos: Vector2)

@export var speed: float = 200.0
@export var encounter_check_interval: float = 1.0

var encounter_timer: float = 0.0
var encounter_chance: float = 0.05
var steps_since_battle: int = 0
var min_steps_between_battles: int = 10
var tile_size: int = 32
var facing_direction: Vector2 = Vector2(0, 1)  # Default facing down

var footstep_timer: float = 0.0
const footstep_interval: float = 0.4
var footstep_trail: Array = []  # Array of {position: Vector2, alpha: float}
var footstep_distance: float = 15.0  # Distance between footsteps
var last_footstep_pos: Vector2 = Vector2.ZERO
var max_footsteps: int = 4  # Maximum number of visible footsteps
var footstep_fade_speed: float = 3  # How fast footsteps fade

func _ready():
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 14
	collision.shape = shape
	add_child(collision)
	last_footstep_pos = position

func _physics_process(delta):
	# Get input direction
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y -= 1
	
	# Normalize to prevent faster diagonal movement
	if direction.length() > 0:
		direction = direction.normalized()
		facing_direction = direction  # Update facing direction
		queue_redraw()  # Redraw to show new direction
	
	var distance = position.distance_to(last_footstep_pos)
	if distance >= footstep_distance:
		add_footstep(position)
		last_footstep_pos = position
		queue_redraw()
		
	if direction.length() > 0:  # When player is moving
		if footstep_timer <= 0:
			AudioManager.play_footstep()
			footstep_timer = footstep_interval

	if footstep_timer > 0:
		footstep_timer -= delta
		
	# Move the character
	velocity = direction * speed
	move_and_slide()
	
	update_footsteps(delta)
	
	# Check for random encounters while moving
	if direction.length() > 0:
		check_for_encounter(delta)

func _input(event):
	# Interaction key (E or Space)
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		# First, check the tile we're standing on
		var current_tile = Vector2(int(position.x / tile_size), int(position.y / tile_size))
		interaction_requested.emit(current_tile)
		
		# Also check the facing tile (for doors, etc.)
		var facing_tile = get_facing_tile()
		if facing_tile != current_tile:
			interaction_requested.emit(facing_tile)

func add_footstep(pos: Vector2):
	"""Add a new footstep at the given position with direction"""
	footstep_trail.append({
		"position": pos,
		"alpha": 1.0,
		"direction": facing_direction  # Store direction for rotation
	})
	
	if footstep_trail.size() > max_footsteps:
		footstep_trail.pop_front()

func update_footsteps(delta: float):
	"""Fade out footsteps over time"""
	var should_redraw = false
	
	for i in range(footstep_trail.size() - 1, -1, -1):
		var footstep = footstep_trail[i]
		footstep.alpha -= footstep_fade_speed * delta
		
		# Remove fully faded footsteps
		if footstep.alpha <= 0:
			footstep_trail.remove_at(i)
			should_redraw = true
		else:
			should_redraw = true
	
	if should_redraw:
		queue_redraw()

func get_facing_tile() -> Vector2:
	# Use the stored facing direction
	var current_tile = Vector2(int(position.x / tile_size), int(position.y / tile_size))
	
	# Round facing direction to nearest cardinal direction
	var cardinal_facing = Vector2.ZERO
	if abs(facing_direction.x) > abs(facing_direction.y):
		cardinal_facing.x = 1 if facing_direction.x > 0 else -1
	else:
		cardinal_facing.y = 1 if facing_direction.y > 0 else -1
	
	return current_tile + cardinal_facing

func check_for_encounter(delta):
	encounter_timer += delta
	steps_since_battle += 1
	
	if encounter_timer >= encounter_check_interval:
		encounter_timer = 0.0
		
		if steps_since_battle >= min_steps_between_battles:
			if randf() < encounter_chance:
				trigger_battle()

func trigger_battle():
	print("Battle triggered!")
	steps_since_battle = 0
	battle_triggered.emit()

func _draw():
	draw_footsteps()
	# Draw player as a circle
	draw_circle(Vector2.ZERO, 14, Color.GREEN)
	
	# Draw direction indicator based on facing direction
	var indicator_pos = facing_direction * 7
	draw_circle(indicator_pos, 3, Color.DARK_GREEN)

func draw_footsteps():
	"""Draw directional footsteps"""
	for i in range(footstep_trail.size()):
		var footstep = footstep_trail[i]
		var local_pos = footstep.position - position
		var alpha = footstep.alpha
		var direction = footstep.get("direction", Vector2(0, 1))
		
		# Footprint color
		var color = Color(0.2, 0.2, 0.2, alpha * 0.8)
		
		# Calculate rotation angle from direction
		var angle = direction.angle() + PI / 2  # Adjust for upward default
		
		# Draw rotated footprints
		var is_left = i % 2 == 0
		var side_offset = 3.0 if is_left else -3.0
		
		# Rotate the offset by the direction angle
		var rotated_offset = Vector2(side_offset, 0).rotated(angle)
		var foot_pos = local_pos + rotated_offset
		
		# Draw foot
		draw_circle(foot_pos, 2.5, color)
