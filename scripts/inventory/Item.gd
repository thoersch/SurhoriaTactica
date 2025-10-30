extends RefCounted
class_name Item

enum ItemType {
	KEY,
	CONSUMABLE,
	QUEST_ITEM,
	WEAPON,
	AMMO,
	DOCUMENT
}

var item_id: String
var item_name: String
var description: String
var item_type: ItemType
var icon_path: String  # Path to icon texture
var width: int = 1  # Inventory grid width
var height: int = 1  # Inventory grid height
var stackable: bool = false
var max_stack: int = 1
var current_stack: int = 1

# Key-specific properties
var key_id: String = ""  # For KEY type - which doors it opens

# Consumable-specific properties
var heal_amount: int = 0
var effect_description: String = ""

func _init(data: Dictionary = {}):
	if data.is_empty():
		return
	
	item_id = data.get("id", "")
	item_name = data.get("name", "Unknown Item")
	description = data.get("description", "")
	
	# Parse item type
	var type_str = data.get("type", "quest_item")
	match type_str:
		"key":
			item_type = ItemType.KEY
		"consumable":
			item_type = ItemType.CONSUMABLE
		"quest_item":
			item_type = ItemType.QUEST_ITEM
		"weapon":
			item_type = ItemType.WEAPON
		"ammo":
			item_type = ItemType.AMMO
		"document":
			item_type = ItemType.DOCUMENT
		_:
			item_type = ItemType.QUEST_ITEM
	
	icon_path = data.get("icon", "")
	width = data.get("width", 1)
	height = data.get("height", 1)
	stackable = data.get("stackable", false)
	max_stack = data.get("max_stack", 1)
	current_stack = data.get("current_stack", 1)
	
	# Type-specific data
	key_id = data.get("key_id", "")
	heal_amount = data.get("heal_amount", 0)
	effect_description = data.get("effect_description", "")

func to_dict() -> Dictionary:
	var type_str = "quest_item"
	match item_type:
		ItemType.KEY:
			type_str = "key"
		ItemType.CONSUMABLE:
			type_str = "consumable"
		ItemType.QUEST_ITEM:
			type_str = "quest_item"
		ItemType.WEAPON:
			type_str = "weapon"
		ItemType.AMMO:
			type_str = "ammo"
		ItemType.DOCUMENT:
			type_str = "document"
	
	var dict = {
		"id": item_id,
		"name": item_name,
		"description": description,
		"type": type_str,
		"icon": icon_path,
		"width": width,
		"height": height,
		"stackable": stackable,
		"max_stack": max_stack,
		"current_stack": current_stack
	}
	
	# Add type-specific data
	if item_type == ItemType.KEY:
		dict["key_id"] = key_id
	elif item_type == ItemType.CONSUMABLE:
		dict["heal_amount"] = heal_amount
		dict["effect_description"] = effect_description
	
	return dict

func can_stack_with(other: Item) -> bool:
	if not stackable or not other.stackable:
		return false
	if item_id != other.item_id:
		return false
	if current_stack >= max_stack:
		return false
	return true

func add_to_stack(amount: int) -> int:
	"""Add to stack, returns amount that couldn't be added"""
	var space_left = max_stack - current_stack
	var amount_to_add = min(amount, space_left)
	current_stack += amount_to_add
	return amount - amount_to_add

func remove_from_stack(amount: int) -> int:
	"""Remove from stack, returns amount actually removed"""
	var amount_to_remove = min(amount, current_stack)
	current_stack -= amount_to_remove
	return amount_to_remove

func is_key() -> bool:
	return item_type == ItemType.KEY

func get_key_id() -> String:
	return key_id if item_type == ItemType.KEY else ""
