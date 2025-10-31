extends Control
class_name DocumentUI

signal document_closed()

var background_overlay: ColorRect
var document_panel: Panel
var document_title: Label
var document_text: RichTextLabel
var close_button: Button

func _ready():
	setup_ui()

func setup_ui():
	# Background overlay
	background_overlay = ColorRect.new()
	background_overlay.color = Color(0, 0, 0, 0.85)
	background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background_overlay)
	
	# Document panel
	document_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.85, 0.75, 1.0)  # Parchment color
	style.border_color = Color(0.3, 0.25, 0.2)
	style.set_border_width_all(3)
	document_panel.add_theme_stylebox_override("panel", style)
	add_child(document_panel)
	
	# Title
	document_title = Label.new()
	document_title.add_theme_font_size_override("font_size", 24)
	document_title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	document_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	document_panel.add_child(document_title)
	
	# Document text
	document_text = RichTextLabel.new()
	document_text.bbcode_enabled = true
	document_text.fit_content = false
	document_text.scroll_active = true
	document_text.add_theme_font_size_override("normal_font_size", 14)
	document_text.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
	document_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	document_panel.add_child(document_text)
	
	# Close button
	close_button = Button.new()
	close_button.text = "Close [E]"
	close_button.pressed.connect(_on_close_pressed)
	document_panel.add_child(close_button)

func show_document(title: String, text: String):
	document_title.text = title
	document_text.text = format_document_text(text)
	
	update_layout()
	visible = true

func format_document_text(text: String) -> String:
	# Add some basic formatting to make it look nice
	# Replace newlines with proper BBCode formatting
	var formatted = text.replace("\n\n", "\n[color=#00000000].[/color]\n")  # Add spacing
	return formatted

func update_layout():
	var viewport_size = get_viewport_rect().size
	
	# Background fills screen
	background_overlay.size = viewport_size
	background_overlay.position = Vector2.ZERO
	
	# Document panel - 70% of screen width, 80% of height
	var panel_width = int(viewport_size.x * 0.7)
	var panel_height = int(viewport_size.y * 0.8)
	document_panel.size = Vector2(panel_width, panel_height)
	document_panel.position = (viewport_size - document_panel.size) / 2
	
	# Title at top
	document_title.position = Vector2(20, 20)
	document_title.size = Vector2(panel_width - 40, 40)
	
	# Text body
	document_text.position = Vector2(30, 70)
	document_text.size = Vector2(panel_width - 60, panel_height - 140)
	
	# Close button at bottom
	close_button.size = Vector2(120, 40)
	close_button.position = Vector2((panel_width - 120) / 2, panel_height - 60)

func _input(event):
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()

func _on_close_pressed():
	visible = false
	document_closed.emit()
