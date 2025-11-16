extends CanvasLayer

var transition_rect: TextureRect
var shader_material: ShaderMaterial
var is_transitioning: bool = false

signal transition_halfway
signal transition_complete

func _ready():
	layer = 100
	
	# Use TextureRect for shader
	transition_rect = TextureRect.new()
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	transition_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(transition_rect)
	
	var shader = load("res://shaders/swirl_transition.gdshader")
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		shader_material.set_shader_parameter("progress", 0.0)
		shader_material.set_shader_parameter("swirl_strength", 5.0)
		shader_material.set_shader_parameter("center", Vector2(0.5, 0.5))
		shader_material.set_shader_parameter("radius", 1.0)
		transition_rect.material = shader_material
	
	transition_rect.visible = false

func _capture_screen():
	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()
	return ImageTexture.create_from_image(img)

func swirl_to_black(duration: float = 1.0, swirl_amount: float = 5.0):
	if is_transitioning:
		return
	
	is_transitioning = true
	
	await RenderingServer.frame_post_draw
	var screen_tex = _capture_screen()
	transition_rect.texture = screen_tex
	
	transition_rect.visible = true
	
	if shader_material:
		shader_material.set_shader_parameter("progress", 0.0)
		shader_material.set_shader_parameter("swirl_strength", swirl_amount)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	if shader_material:
		tween.tween_method(func(value): 
			shader_material.set_shader_parameter("progress", value),
			0.0, 1.0, duration)
	
	await get_tree().create_timer(duration * 0.5).timeout
	transition_halfway.emit()
	
	await tween.finished
	
	# Leave visible and black - but clear transitioning flag
	is_transitioning = false
	transition_complete.emit()

func set_swirl_center(screen_position: Vector2):
	if shader_material:
		shader_material.set_shader_parameter("center", screen_position)

func hide_black():
	"""Simply hide the black overlay instantly"""
	transition_rect.visible = false
	transition_rect.texture = null
	is_transitioning = false

func fade_to_black(duration: float = 0.5):
	"""Simple fade to black using ColorRect"""
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Create a simple black ColorRect for fading
	var fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 0.0
	add_child(fade_rect)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	
	await get_tree().create_timer(duration * 0.5).timeout
	transition_halfway.emit()
	
	await tween.finished
	
	# Keep the black rect visible, store reference for fade_from_black
	fade_rect.name = "FadeRect"
	is_transitioning = false
	transition_complete.emit()

func fade_from_black(duration: float = 0.5):
	"""Fade from black back to visible"""
	if is_transitioning:
		return
	
	is_transitioning = true
	
	# Find the fade rect (should exist from fade_to_black)
	var fade_rect = get_node_or_null("FadeRect")
	if not fade_rect:
		# Create one if it doesn't exist
		fade_rect = ColorRect.new()
		fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_rect.color = Color.BLACK
		fade_rect.name = "FadeRect"
		add_child(fade_rect)
	
	# Make sure it's fully opaque
	fade_rect.color.a = 1.0
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	
	await tween.finished
	
	# Clean up
	fade_rect.queue_free()
	is_transitioning = false
	transition_complete.emit()

func fade_out_black(duration: float = 1.0):
	"""Fade the black overlay to transparent"""
	print("fade_out_black called")
	
	# Don't check is_transitioning - we want to override any previous transition
	is_transitioning = true
	
	# Hide the swirled texture overlay first
	transition_rect.visible = false
	
	# Create a solid black ColorRect to fade out
	var fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 1.0  # Start fully opaque
	add_child(fade_rect)
	
	# Wait a frame to ensure scene has rendered behind it
	await get_tree().process_frame
	
	print("  Starting fade tween...")
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	
	await tween.finished
	print("  Fade complete")
	
	# Clean up
	fade_rect.queue_free()
	transition_rect.texture = null
	transition_rect.modulate = Color.WHITE
	is_transitioning = false
	transition_complete.emit()
