extends Node2D
class_name CutScene

signal cutscene_finished()

# UI Elements
var background: TextureRect
var dialogue_box: Panel
var name_box: Panel
var name_label: Label
var dialogue_label: RichTextLabel
var continue_indicator: Label

# Character portraits
var left_characters: Dictionary = {}  # character_id -> Sprite2D
var right_characters: Dictionary = {}

# Cutscene data
var cutscene_data: Dictionary = {}
var current_frame: int = 0
var is_waiting_for_input: bool = false
var is_playing: bool = false

# Audio
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# Animation
var text_speed: float = 0.03  # Seconds per character
var text_timer: float = 0.0
var current_text: String = ""
var displayed_text: String = ""
var is_text_animating: bool = false

# Constants
const DIALOGUE_BOX_HEIGHT = 180
const NAME_BOX_WIDTH = 200
const NAME_BOX_HEIGHT = 50
const CHARACTER_SLIDE_SPEED = 400.0
const CHARACTER_SPACING = 80  # Offset for multiple characters

func _ready():
	print("DEBUG CutScene: _ready() called")
	setup_ui()
	setup_audio()
	
	current_frame = 0
	is_playing = true
	
	# Wait a frame then start
	await get_tree().process_frame
	print("DEBUG CutScene: About to call process_next_frame")
	process_next_frame()

func setup_ui():
	# Background
	background = TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.z_index = -1
	add_child(background)
	
	# Dialogue box (bottom of screen)
	dialogue_box = Panel.new()
	dialogue_box.z_index = 10
	var dialogue_style = StyleBoxFlat.new()
	dialogue_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	dialogue_style.border_color = Color(0.4, 0.4, 0.5)
	dialogue_style.set_border_width_all(3)
	dialogue_box.add_theme_stylebox_override("panel", dialogue_style)
	add_child(dialogue_box)
	
	# Name box (upper left of dialogue box)
	name_box = Panel.new()
	var name_style = StyleBoxFlat.new()
	name_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	name_style.border_color = Color(0.5, 0.5, 0.6)
	name_style.set_border_width_all(2)
	name_box.add_theme_stylebox_override("panel", name_style)
	dialogue_box.add_child(name_box)
	
	# Name label
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	name_box.add_child(name_label)
	
	# Dialogue text
	dialogue_label = RichTextLabel.new()
	dialogue_label.bbcode_enabled = true
	dialogue_label.fit_content = true
	dialogue_label.scroll_active = false
	dialogue_label.add_theme_font_size_override("normal_font_size", 16)
	dialogue_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.95))
	dialogue_box.add_child(dialogue_label)
	
	# Continue indicator
	continue_indicator = Label.new()
	continue_indicator.text = "▼"
	continue_indicator.add_theme_font_size_override("font_size", 20)
	continue_indicator.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
	continue_indicator.visible = false
	dialogue_box.add_child(continue_indicator)
	
	dialogue_box.visible = true
	name_box.visible = true
	name_label.visible = true
	dialogue_label.visible = true
	
	print("DEBUG: UI setup complete")
	
	update_ui_layout()

func setup_audio():
	# Music player
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	
	# SFX player
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

func update_ui_layout():
	var viewport_size = get_viewport_rect().size
	
	# Background fills screen
	background.size = viewport_size
	background.position = Vector2.ZERO
	
	# Dialogue box at bottom
	dialogue_box.size = Vector2(viewport_size.x, DIALOGUE_BOX_HEIGHT)
	dialogue_box.position = Vector2(0, viewport_size.y - DIALOGUE_BOX_HEIGHT)
	
	# Name box (upper left of dialogue box, extends above it)
	name_box.size = Vector2(NAME_BOX_WIDTH, NAME_BOX_HEIGHT)
	name_box.position = Vector2(20, -NAME_BOX_HEIGHT + 10)
	
	# Name label
	name_label.size = name_box.size
	name_label.position = Vector2.ZERO
	
	# Dialogue text
	dialogue_label.position = Vector2(30, 30)
	dialogue_label.size = Vector2(viewport_size.x - 60, DIALOGUE_BOX_HEIGHT - 60)
	
	# Continue indicator (bottom right)
	continue_indicator.position = Vector2(viewport_size.x - 50, DIALOGUE_BOX_HEIGHT - 40)

func load_cutscene(cutscene_id: String) -> bool:
	var path = "res://data/cutscenes/" + cutscene_id + ".json"
	
	print("DEBUG: Attempting to load cutscene from: ", path)
	print("DEBUG: File exists: ", FileAccess.file_exists(path))
	
	if not FileAccess.file_exists(path):
		push_error("Cutscene not found: " + path)
		print("ERROR: File does not exist at path: ", path)
		return false
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open cutscene file")
		print("ERROR: FileAccess.open returned null")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	print("DEBUG: Loaded JSON string length: ", json_string.length())
	print("DEBUG: JSON content: ", json_string)
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Failed to parse cutscene JSON: " + json.get_error_message())
		print("ERROR: JSON parse failed with error: ", json.get_error_message())
		return false
	
	cutscene_data = json.data
	print("DEBUG: Cutscene data: ", cutscene_data)
	print("DEBUG: Frames in data: ", cutscene_data.get("frames", []))
	print("DEBUG: Frame count: ", cutscene_data.get("frames", []).size())
	
	current_frame = 0
	
	# Load background
	if cutscene_data.has("background"):
		print("DEBUG: Has background field: ", cutscene_data["background"])
		var bg_texture = load(cutscene_data["background"])
		if bg_texture:
			background.texture = bg_texture
			print("DEBUG: Background texture loaded and assigned")
		else:
			print("WARNING: Background path exists but texture failed to load")
	else:
		print("DEBUG: No background field in cutscene data")
	
	# Load and play music
	if cutscene_data.has("music"):
		print("DEBUG: Loading music: ", cutscene_data["music"])
		var music = load(cutscene_data["music"])
		if music:
			music_player.stream = music
			music_player.volume_db = cutscene_data.get("music_volume", -10)
			music_player.play()
			print("DEBUG: Music started playing")
	
	print("DEBUG: load_cutscene returning true")
	return true

func play_cutscene(cutscene_id: String):
	print("DEBUG: play_cutscene called with ID: ", cutscene_id)
	
	if load_cutscene(cutscene_id):
		print("DEBUG: Cutscene loaded successfully, starting playback")
		is_playing = true
		await get_tree().process_frame
		process_next_frame()
	else:
		print("ERROR: Failed to load cutscene: ", cutscene_id)

func process_next_frame():
	print("DEBUG: process_next_frame called, frame: ", current_frame, ", is_playing: ", is_playing)
	
	if not is_playing:
		print("DEBUG: Not playing, returning")
		return
	
	var frames = cutscene_data.get("frames", [])
	print("DEBUG: Total frames: ", frames.size())
	
	if current_frame >= frames.size():
		print("DEBUG: Reached end of cutscene")
		end_cutscene()
		return
	
	var frame = frames[current_frame]
	var action = frame.get("action", "")
	
	print("DEBUG: Processing frame ", current_frame, " with action: ", action)
	
	match action:
		"character_enter":
			await handle_character_enter(frame)
			current_frame += 1
			process_next_frame()
		"character_exit":
			await handle_character_exit(frame)
			current_frame += 1
			process_next_frame()
		"dialogue":
			handle_dialogue(frame)
		"fade_out":
			await handle_fade_out(frame)
			current_frame += 1
			process_next_frame()
		"wait":
			await get_tree().create_timer(frame.get("duration", 1.0)).timeout
			current_frame += 1
			process_next_frame()
		_:
			print("ERROR: Unknown action: ", action)
			current_frame += 1
			process_next_frame()

func handle_character_enter(frame: Dictionary):
	var character_id = frame.get("character", "")
	var side = frame.get("side", "left")
	var portrait_path = frame.get("portrait", "")
	var position_index = frame.get("position_index", 0)
	
	# Load portrait
	var portrait_texture = load(portrait_path)
	if not portrait_texture:
		push_error("Failed to load portrait: " + portrait_path)
		return
	
	# Create character sprite
	var character_sprite = Sprite2D.new()
	character_sprite.texture = portrait_texture
	
	# Scale to fit nicely
	var portrait_height = 350
	var scale_factor = portrait_height / portrait_texture.get_height()
	character_sprite.scale = Vector2(scale_factor, scale_factor)
	
	add_child(character_sprite)
	
	# Calculate target position
	var viewport_size = get_viewport_rect().size
	var dialogue_y = viewport_size.y - DIALOGUE_BOX_HEIGHT
	var character_bottom = dialogue_y + 20
	
	var target_x: float
	if side == "left":
		target_x = 150 + (position_index * CHARACTER_SPACING)
		character_sprite.position.x = -portrait_texture.get_width()
	else:
		target_x = viewport_size.x - 150 - (position_index * CHARACTER_SPACING)
		character_sprite.position.x = viewport_size.x + portrait_texture.get_width()
	
	character_sprite.position.y = character_bottom
	
	# Store character
	if side == "left":
		left_characters[character_id] = character_sprite
	else:
		right_characters[character_id] = character_sprite
	
	# Animate slide in
	var tween = create_tween()
	tween.tween_property(character_sprite, "position:x", target_x, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished

func handle_character_exit(frame: Dictionary):
	var character_id = frame.get("character", "")
	var side = frame.get("side", "left")
	
	var character_sprite: Sprite2D = null
	if side == "left" and left_characters.has(character_id):
		character_sprite = left_characters[character_id]
		left_characters.erase(character_id)
	elif side == "right" and right_characters.has(character_id):
		character_sprite = right_characters[character_id]
		right_characters.erase(character_id)
	
	if not character_sprite:
		return
	
	# Animate slide out
	var viewport_size = get_viewport_rect().size
	var target_x = -character_sprite.texture.get_width() if side == "left" else viewport_size.x + character_sprite.texture.get_width()
	
	var tween = create_tween()
	tween.tween_property(character_sprite, "position:x", target_x, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	
	character_sprite.queue_free()

func handle_dialogue(frame: Dictionary):
	var character_name = frame.get("character", "")
	var text = frame.get("text", "")
	var sfx_path = frame.get("sound_effect", "")
	
	# Set character name
	name_label.text = character_name
	
	# Play text sound effect if provided
	if sfx_path != "":
		var sfx = load(sfx_path)
		if sfx:
			sfx_player.stream = sfx
			sfx_player.play()
	
	# Start text animation
	current_text = text
	displayed_text = ""
	is_text_animating = true
	is_waiting_for_input = true
	continue_indicator.visible = false
	text_timer = 0.0

func handle_fade_out(frame: Dictionary):
	var duration = frame.get("duration", 1.0)
	
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.size = get_viewport_rect().size
	add_child(fade_overlay)
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, duration)
	await tween.finished

func _process(delta):
	# Check for viewport size changes
	var viewport_size = get_viewport_rect().size
	if dialogue_box and dialogue_box.position.y != viewport_size.y - DIALOGUE_BOX_HEIGHT:
		update_ui_layout()
	
	if is_text_animating:
		text_timer += delta
		
		if text_timer >= text_speed:
			text_timer = 0.0
			
			if displayed_text.length() < current_text.length():
				displayed_text += current_text[displayed_text.length()]
				dialogue_label.text = displayed_text
			else:
				is_text_animating = false
				continue_indicator.visible = true
				animate_continue_indicator()

func animate_continue_indicator():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(continue_indicator, "modulate:a", 0.3, 0.5)
	tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)

func _input(event):
	if not is_playing:
		return
	
	print("DEBUG: Input received, is_waiting: ", is_waiting_for_input, ", is_animating: ", is_text_animating)
	
	if not is_waiting_for_input:
		return
	
	var should_continue = false
	
	if event.is_action_pressed("ui_accept"):
		should_continue = true
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			should_continue = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		should_continue = true
	
	if should_continue:
		print("DEBUG: Continue pressed")
		if is_text_animating:
			print("DEBUG: Skipping text animation")
			displayed_text = current_text
			dialogue_label.text = displayed_text
			is_text_animating = false
			continue_indicator.visible = true
		else:
			print("DEBUG: Moving to next frame")
			is_waiting_for_input = false
			continue_indicator.visible = false
			current_frame += 1
			call_deferred("process_next_frame")
		
		get_viewport().set_input_as_handled()

func end_cutscene():
	is_playing = false
	
	# Stop music
	if music_player.playing:
		music_player.stop()
	
	# Clear characters
	for character in left_characters.values():
		character.queue_free()
	for character in right_characters.values():
		character.queue_free()
	
	left_characters.clear()
	right_characters.clear()
	
	cutscene_finished.emit()
