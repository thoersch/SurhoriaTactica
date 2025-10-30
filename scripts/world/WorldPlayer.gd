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

func _ready():
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 14
	collision.shape = shape
	add_child(collision)

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
	
	# Move the character
	velocity = direction * speed
	move_and_slide()
	
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
	# Draw player as a circle
	draw_circle(Vector2.ZERO, 14, Color.GREEN)
	
	# Draw direction indicator based on facing direction
	var indicator_pos = facing_direction * 7
	draw_circle(indicator_pos, 3, Color.DARK_GREEN)
