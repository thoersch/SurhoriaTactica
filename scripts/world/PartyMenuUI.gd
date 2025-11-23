extends Control
class_name PartyMenuUI

signal unit_selected(unit_data: Dictionary)
signal menu_closed()

var roster_data: Array = []

# UI Elements
var background: ColorRect
var main_panel: Panel
var title_label: Label
var unit_list: VBoxContainer
var scroll_container: ScrollContainer
var close_button: Button

func _ready():
	setup_ui()

func setup_ui():
	# Background overlay
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Main panel
	main_panel = Panel.new()
	main_panel.size = Vector2(800, 600)
	add_child(main_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.98)
	style.border_color = Color(0.4, 0.6, 1.0)
	style.set_border_width_all(3)
	main_panel.add_theme_stylebox_override("panel", style)
	
	# Title
	title_label = Label.new()
	title_label.text = "PARTY ROSTER"
	title_label.position = Vector2(20, 15)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	main_panel.add_child(title_label)
	
	# Scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(20, 70)
	scroll_container.size = Vector2(760, 480)
	main_panel.add_child(scroll_container)
	
	# Unit list
	unit_list = VBoxContainer.new()
	unit_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_list.add_theme_constant_override("separation", 10)
	scroll_container.add_child(unit_list)
	
	# Close button
	close_button = Button.new()
	close_button.text = "Close [ESC]"
	close_button.position = Vector2(680, 560)
	close_button.size = Vector2(100, 30)
	close_button.pressed.connect(_on_close_pressed)
	main_panel.add_child(close_button)
	
	visible = false

func show_party(roster: Array):
	roster_data = roster
	refresh_unit_list()
	center_on_screen()
	visible = true

func center_on_screen():
	var viewport_size = get_viewport_rect().size
	main_panel.position = (viewport_size - main_panel.size) / 2
	background.size = viewport_size
	background.position = Vector2.ZERO

func refresh_unit_list():
	# Clear existing
	for child in unit_list.get_children():
		child.queue_free()
	
	# Add unit entries
	for unit_data in roster_data:
		create_unit_entry(unit_data)

func create_unit_entry(unit_data: Dictionary):
	var entry = Panel.new()
	entry.custom_minimum_size = Vector2(740, 100)
	
	var entry_style = StyleBoxFlat.new()
	entry_style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	entry_style.border_color = Color(0.3, 0.3, 0.35)
	entry_style.set_border_width_all(2)
	entry.add_theme_stylebox_override("panel", entry_style)
	
	# Unit name
	var name_label = Label.new()
	name_label.text = unit_data.get("name", "Unknown")
	name_label.position = Vector2(15, 10)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	entry.add_child(name_label)
	
	# Level
	var level_label = Label.new()
	level_label.text = "Level " + str(unit_data.get("level", 1))
	level_label.position = Vector2(15, 40)
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	entry.add_child(level_label)
	
	# Stats
	var stats_label = Label.new()
	var hp = unit_data.get("health", 100)
	var max_hp = unit_data.get("max_health", 100)
	var atk = unit_data.get("attack", 10)
	var def = unit_data.get("defense", 5)
	stats_label.text = "HP: %d/%d  |  ATK: %d  |  DEF: %d" % [hp, max_hp, atk, def]
	stats_label.position = Vector2(15, 65)
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	entry.add_child(stats_label)
	
	# XP Progress
	var exp = unit_data.get("experience", 0)
	var level = unit_data.get("level", 1)
	var next_level_xp = calculate_exp_for_level(level + 1)
	var current_level_xp = calculate_exp_for_level(level)
	var progress = exp - current_level_xp
	var needed = next_level_xp - current_level_xp
	
	var xp_label = Label.new()
	xp_label.text = "EXP: %d / %d" % [progress, needed]
	xp_label.position = Vector2(350, 40)
	xp_label.add_theme_font_size_override("font_size", 13)
	xp_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	entry.add_child(xp_label)
	
	# Skill points
	var sp = unit_data.get("skill_points", 0)
	var sp_label = Label.new()
	sp_label.text = "Skill Points: " + str(sp)
	sp_label.position = Vector2(350, 65)
	sp_label.add_theme_font_size_override("font_size", 13)
	if sp > 0:
		sp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	else:
		sp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	entry.add_child(sp_label)
	
	# View button
	var view_button = Button.new()
	view_button.text = "View Skills"
	view_button.position = Vector2(600, 30)
	view_button.size = Vector2(120, 40)
	view_button.pressed.connect(func(): _on_unit_selected(unit_data))
	entry.add_child(view_button)
	
	unit_list.add_child(entry)

func calculate_exp_for_level(target_level: int) -> int:
	"""Calculate total XP needed to reach a given level"""
	var base_xp = 100
	var exponent = 1.5
	
	var total_xp = 0
	for lvl in range(1, target_level):
		total_xp += int(base_xp * pow(lvl, exponent))
	
	return total_xp

func _on_unit_selected(unit_data: Dictionary):
	unit_selected.emit(unit_data)

func _on_close_pressed():
	visible = false
	menu_closed.emit()

func _input(event):
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
