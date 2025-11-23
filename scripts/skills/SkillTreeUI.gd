extends Control
class_name SkillTreeUI

signal skill_unlocked(unit_data: Dictionary, skill_id: String)
signal back_to_roster()

var current_unit_data: Dictionary = {}
var available_skills: Array = []  # Array of Skill objects
var unit_equipped_skills: Dictionary = {}  # skill_id -> Skill

# UI Elements
var background: ColorRect
var main_panel: Panel
var title_label: Label
var stats_panel: Panel
var stats_label: RichTextLabel
var skills_scroll: ScrollContainer
var skills_grid: GridContainer
var back_button: Button

func _ready():
	setup_ui()

func setup_ui():
	# Background
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Main panel
	main_panel = Panel.new()
	main_panel.size = Vector2(900, 650)
	add_child(main_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.98)
	style.border_color = Color(0.4, 0.6, 1.0)
	style.set_border_width_all(3)
	main_panel.add_theme_stylebox_override("panel", style)
	
	# Title
	title_label = Label.new()
	title_label.text = "SKILL TREE"
	title_label.position = Vector2(20, 15)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	main_panel.add_child(title_label)
	
	# Stats panel (top)
	stats_panel = Panel.new()
	stats_panel.position = Vector2(20, 60)
	stats_panel.size = Vector2(860, 100)
	
	var stats_style = StyleBoxFlat.new()
	stats_style.bg_color = Color(0.15, 0.15, 0.18, 0.95)
	stats_style.border_color = Color(0.3, 0.4, 0.5)
	stats_style.set_border_width_all(2)
	stats_panel.add_theme_stylebox_override("panel", stats_style)
	main_panel.add_child(stats_panel)
	
	# Stats label
	stats_label = RichTextLabel.new()
	stats_label.position = Vector2(15, 10)
	stats_label.size = Vector2(830, 80)
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.scroll_active = false
	stats_panel.add_child(stats_label)
	
	# Skills scroll container
	skills_scroll = ScrollContainer.new()
	skills_scroll.position = Vector2(20, 180)
	skills_scroll.size = Vector2(860, 420)
	main_panel.add_child(skills_scroll)
	
	# Skills grid
	skills_grid = GridContainer.new()
	skills_grid.columns = 3
	skills_grid.add_theme_constant_override("h_separation", 15)
	skills_grid.add_theme_constant_override("v_separation", 15)
	skills_scroll.add_child(skills_grid)
	
	# Back button
	back_button = Button.new()
	back_button.text = "← Back to Roster"
	back_button.position = Vector2(20, 610)
	back_button.size = Vector2(150, 30)
	back_button.pressed.connect(_on_back_pressed)
	main_panel.add_child(back_button)
	
	visible = false

func show_for_unit(unit_data: Dictionary):
	current_unit_data = unit_data
	
	# Get unit's class/name to load appropriate skill tree
	var unit_class = unit_data.get("name", "Rifleman")
	print("DEBUG: Loading skills for class: ", unit_class)
	
	# Try to get skills
	available_skills = SkillDatabase.get_skill_tree(unit_class)
	print("DEBUG: Found ", available_skills.size(), " skills")
	
	# If no skills found, try without spaces/special chars
	if available_skills.is_empty():
		print("DEBUG: No skills found, checking available trees...")
		print("DEBUG: Available skill trees: ", SkillDatabase.skill_trees.keys())
		
		# Try to find a matching tree
		for tree_name in SkillDatabase.skill_trees.keys():
			if tree_name.to_lower().contains(unit_class.to_lower()) or unit_class.to_lower().contains(tree_name.to_lower()):
				available_skills = SkillDatabase.get_skill_tree(tree_name)
				print("DEBUG: Matched tree: ", tree_name, " with ", available_skills.size(), " skills")
				break
	
	# Load unit's equipped skills
	load_unit_skills(unit_data)
	
	# Update UI
	update_stats_display()
	refresh_skill_tree()
	
	center_on_screen()
	visible = true

func load_unit_skills(unit_data: Dictionary):
	"""Load the unit's current skills"""
	unit_equipped_skills.clear()
	
	var skills_data = unit_data.get("skills", [])
	for skill_data in skills_data:
		var skill_id = skill_data.get("id", "")
		# Find the skill template
		for skill_template in available_skills:
			if skill_template.skill_id == skill_id:
				var skill = Skill.new(skill_template.to_dict())
				skill.current_rank = skill_data.get("current_rank", 0)
				unit_equipped_skills[skill_id] = skill
				break

func center_on_screen():
	var viewport_size = get_viewport_rect().size
	main_panel.position = (viewport_size - main_panel.size) / 2
	background.size = viewport_size
	background.position = Vector2.ZERO

func update_stats_display():
	var name = current_unit_data.get("name", "Unknown")
	var level = current_unit_data.get("level", 1)
	var sp = current_unit_data.get("skill_points", 0)
	var hp = current_unit_data.get("health", 100)
	var max_hp = current_unit_data.get("max_health", 100)
	var atk = current_unit_data.get("attack", 10)
	var def = current_unit_data.get("defense", 5)
	
	stats_label.text = "[b][font_size=18]" + name + "[/font_size][/b]  |  Level " + str(level) + "\n\n"
	stats_label.text += "HP: [color=green]" + str(hp) + "/" + str(max_hp) + "[/color]  |  "
	stats_label.text += "Attack: [color=red]" + str(atk) + "[/color]  |  "
	stats_label.text += "Defense: [color=cyan]" + str(def) + "[/color]\n"
	stats_label.text += "[color=yellow]Available Skill Points: " + str(sp) + "[/color]"

func refresh_skill_tree():
	# Clear existing
	for child in skills_grid.get_children():
		child.queue_free()
	
	# Create skill nodes
	for skill_template in available_skills:
		create_skill_node(skill_template)

func create_skill_node(skill_template: Skill):
	var node = Panel.new()
	node.custom_minimum_size = Vector2(270, 150)
	
	# Check if unlocked
	var equipped_skill = unit_equipped_skills.get(skill_template.skill_id)
	var is_unlocked = equipped_skill != null and equipped_skill.is_unlocked()
	var current_rank = equipped_skill.current_rank if equipped_skill else 0
	
	# Get unlocked skill IDs
	var unlocked_ids = []
	for skill_id in unit_equipped_skills.keys():
		if unit_equipped_skills[skill_id].is_unlocked():
			unlocked_ids.append(skill_id)
	
	# Check if can unlock
	var can_unlock = skill_template.can_unlock(
		current_unit_data.get("level", 1),
		unlocked_ids
	) and current_unit_data.get("skill_points", 0) >= skill_template.cost_per_rank
	
	# Style based on state
	var node_style = StyleBoxFlat.new()
	if is_unlocked:
		node_style.bg_color = Color(0.2, 0.4, 0.25, 0.95)  # Green tint
		node_style.border_color = Color(0.3, 0.8, 0.4)
	elif can_unlock:
		node_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
		node_style.border_color = Color(0.6, 0.6, 1.0)
	else:
		node_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
		node_style.border_color = Color(0.3, 0.3, 0.35)
	node_style.set_border_width_all(2)
	node.add_theme_stylebox_override("panel", node_style)
	
	# Skill name
	var name_label = Label.new()
	name_label.text = skill_template.skill_name
	if skill_template.max_rank > 1 and is_unlocked:
		name_label.text += " (" + str(current_rank) + "/" + str(skill_template.max_rank) + ")"
	name_label.position = Vector2(10, 10)
	name_label.add_theme_font_size_override("font_size", 14)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	elif can_unlock:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	node.add_child(name_label)
	
	# Description
	var desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = skill_template.description
	desc_label.position = Vector2(10, 35)
	desc_label.size = Vector2(250, 55)
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.add_theme_font_size_override("normal_font_size", 11)
	if is_unlocked or can_unlock:
		desc_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
	else:
		desc_label.add_theme_color_override("default_color", Color(0.4, 0.4, 0.4))
	node.add_child(desc_label)
	
	# Requirements
	var req_label = Label.new()
	req_label.text = "Requires: Level " + str(skill_template.required_level)
	if not skill_template.prerequisite_skills.is_empty():
		req_label.text += "\nPrerequisites: " + str(skill_template.prerequisite_skills.size()) + " skill(s)"
	req_label.position = Vector2(10, 95)
	req_label.add_theme_font_size_override("font_size", 9)
	req_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	node.add_child(req_label)
	
	# Unlock button
	var unlock_button = Button.new()
	if is_unlocked and current_rank >= skill_template.max_rank:
		unlock_button.text = "MAXED"
		unlock_button.disabled = true
	elif is_unlocked:
		unlock_button.text = "Upgrade (SP: " + str(skill_template.cost_per_rank) + ")"
	else:
		unlock_button.text = "Unlock (SP: " + str(skill_template.cost_per_rank) + ")"
	
	unlock_button.position = Vector2(10, 115)
	unlock_button.size = Vector2(250, 25)
	unlock_button.disabled = not can_unlock or (is_unlocked and current_rank >= skill_template.max_rank)
	
	unlock_button.pressed.connect(func(): _on_unlock_skill(skill_template))
	node.add_child(unlock_button)
	
	skills_grid.add_child(node)

func _on_unlock_skill(skill_template: Skill):
	var sp = current_unit_data.get("skill_points", 0)
	
	if sp < skill_template.cost_per_rank:
		print("Not enough skill points!")
		return
	
	# Deduct skill points
	current_unit_data["skill_points"] = sp - skill_template.cost_per_rank
	
	# Unlock or upgrade skill
	if unit_equipped_skills.has(skill_template.skill_id):
		unit_equipped_skills[skill_template.skill_id].unlock_rank()
	else:
		var new_skill = Skill.new(skill_template.to_dict())
		new_skill.unlock_rank()
		unit_equipped_skills[skill_template.skill_id] = new_skill
	
	# Update unit data with new skill
	update_unit_skills_data()
	
	# Emit signal to save
	skill_unlocked.emit(current_unit_data, skill_template.skill_id)
	
	# Refresh display
	update_stats_display()
	refresh_skill_tree()

func update_unit_skills_data():
	"""Update the unit_data dictionary with current skills"""
	var skills_array = []
	for skill in unit_equipped_skills.values():
		if skill.is_unlocked():
			skills_array.append(skill.to_dict())
	current_unit_data["skills"] = skills_array

func _on_back_pressed():
	visible = false
	back_to_roster.emit()

func _input(event):
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
