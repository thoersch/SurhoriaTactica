extends Control

signal stat_chosen(unit: Unit, stat_name: String)

var current_unit: Unit = null

# UI Elements
var background: ColorRect
var panel: Panel
var title_label: Label
var info_label: RichTextLabel
var button_container: VBoxContainer
var hp_button: Button
var attack_button: Button
var defense_button: Button

func _ready():
	setup_ui()

func setup_ui():
	# Semi-transparent background
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Main panel
	panel = Panel.new()
	panel.position = Vector2(400, 200)
	panel.size = Vector2(400, 300)
	add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.border_color = Color(1.0, 0.8, 0.2)
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	
	# Title
	title_label = Label.new()
	title_label.text = "LEVEL UP!"
	title_label.position = Vector2(20, 20)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	panel.add_child(title_label)
	
	# Info label
	info_label = RichTextLabel.new()
	info_label.position = Vector2(20, 70)
	info_label.size = Vector2(360, 80)
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.scroll_active = false
	panel.add_child(info_label)
	
	# Button container
	button_container = VBoxContainer.new()
	button_container.position = Vector2(20, 160)
	button_container.size = Vector2(360, 120)
	button_container.add_theme_constant_override("separation", 10)
	panel.add_child(button_container)
	
	# HP Button
	hp_button = Button.new()
	hp_button.text = "Increase Max HP (+10)"
	hp_button.custom_minimum_size = Vector2(360, 35)
	hp_button.pressed.connect(func(): _on_stat_chosen("health"))
	button_container.add_child(hp_button)
	
	# Attack Button
	attack_button = Button.new()
	attack_button.text = "Increase Attack (+3)"
	attack_button.custom_minimum_size = Vector2(360, 35)
	attack_button.pressed.connect(func(): _on_stat_chosen("attack"))
	button_container.add_child(attack_button)
	
	# Defense Button
	defense_button = Button.new()
	defense_button.text = "Increase Defense (+2)"
	defense_button.custom_minimum_size = Vector2(360, 35)
	defense_button.pressed.connect(func(): _on_stat_chosen("defense"))
	button_container.add_child(defense_button)
	
	visible = false

func show_for_unit(unit: Unit):
	current_unit = unit
	
	# Update info text
	info_label.text = "[center][b]" + unit.unit_name + "[/b] reached Level " + str(unit.level) + "![/center]\n\n"
	info_label.text += "Choose a stat to increase:"
	
	# Center on screen
	var viewport_size = get_viewport_rect().size
	panel.position = (viewport_size - panel.size) / 2
	
	visible = true

func _on_stat_chosen(stat_name: String):
	if current_unit:
		stat_chosen.emit(current_unit, stat_name)
		visible = false
		current_unit = null
