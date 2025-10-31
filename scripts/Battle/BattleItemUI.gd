extends Control
class_name BattleItemUI

signal item_selected(item: Item)
signal ui_closed()

var inventory: Inventory
var selected_unit: Unit

# UI Elements
var background: ColorRect
var item_list: VBoxContainer
var title_label: Label
var close_button: Button
var scroll_container: ScrollContainer

func _ready():
	setup_ui()

func setup_ui():
	# Semi-transparent background overlay
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Main panel
	var panel = Panel.new()
	panel.position = Vector2(400, 200)
	panel.size = Vector2(400, 400)
	add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.border_color = Color(0.4, 0.6, 1.0)
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)
	
	# Title
	title_label = Label.new()
	title_label.text = "Use Item"
	title_label.position = Vector2(20, 15)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	panel.add_child(title_label)
	
	# Close button
	close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(360, 10)
	close_button.size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	panel.add_child(close_button)
	
	# Scroll container for items
	scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(20, 60)
	scroll_container.size = Vector2(360, 310)
	panel.add_child(scroll_container)
	
	# Item list
	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(item_list)
	
	visible = false

func show_for_unit(unit: Unit, inv: Inventory):
	selected_unit = unit
	inventory = inv
	refresh_items()
	visible = true
	
	# Center on screen
	var viewport_size = get_viewport_rect().size
	var panel = get_child(1) as Panel
	if panel:
		panel.position = (viewport_size - panel.size) / 2

func refresh_items():
	# Clear existing items
	for child in item_list.get_children():
		child.queue_free()
	
	if not inventory:
		return
	
	# Get usable items (consumables only)
	var usable_items = []
	for item_data in inventory.items:
		var item = item_data["item"] as Item
		if item.item_type == Item.ItemType.CONSUMABLE:
			usable_items.append(item)
	
	if usable_items.is_empty():
		var no_items_label = Label.new()
		no_items_label.text = "No usable items available"
		no_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_items_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_list.add_child(no_items_label)
		return
	
	# Create item buttons
	for item in usable_items:
		create_item_button(item)

func create_item_button(item: Item):
	var item_button = Button.new()
	item_button.custom_minimum_size = Vector2(340, 60)
	
	# Create item display
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Item icon/color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(40, 40)
	color_rect.color = get_item_color(item)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(color_rect)
	
	# Item info
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var name_label = Label.new()
	name_label.text = item.item_name
	if item.stackable:
		name_label.text += " x" + str(item.current_stack)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = item.effect_description if item.effect_description != "" else item.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)
	
	hbox.add_child(vbox)
	item_button.add_child(hbox)
	
	# Connect button press
	item_button.pressed.connect(func(): _on_item_button_pressed(item))
	
	item_list.add_child(item_button)

func get_item_color(item: Item) -> Color:
	return Color(0.3, 0.8, 0.3, 0.8)  # Green for consumables

func _on_item_button_pressed(item: Item):
	item_selected.emit(item)
	visible = false

func _on_close_pressed():
	ui_closed.emit()
	visible = false

func _input(event):
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
