extends RefCounted
class_name Interactable

var interactable_id: String
var name: String
var description: String
var position: Vector2
var has_container: bool = false
var container_inventory: Inventory = null
var document_id: String = ""
var document_text: String = ""
var is_examined: bool = false

func _init(data: Dictionary = {}):
	if data.is_empty():
		return
	
	interactable_id = data.get("id", "interactable_" + str(randi()))
	name = data.get("name", "Object")
	description = data.get("description", "An object.")
	
	var pos_dict = data.get("position", {"x": 0, "y": 0})
	position = Vector2(pos_dict.x, pos_dict.y)
	
	has_container = data.get("has_container", false)
	if has_container:
		container_inventory = Inventory.new()
		
		# Load initial items if specified
		var initial_items = data.get("initial_items", [])
		for item_data in initial_items:
			var item_id = item_data.get("id", "")
			var stack_count = item_data.get("count", 1)
			
			if item_id != "":
				var item = ItemDatabase.create_item(item_id, stack_count)
				if item:
					container_inventory.add_item(item)
	
	# Document setup
	document_id = data.get("document_id", "")
	document_text = data.get("document_text", "")

func to_dict() -> Dictionary:
	var dict = {
		"id": interactable_id,
		"name": name,
		"description": description,
		"position": {
			"x": position.x,
			"y": position.y
		},
		"has_container": has_container,
		"is_examined": is_examined
	}
	
	# Save container contents
	if has_container and container_inventory:
		dict["container_inventory"] = container_inventory.to_dict()
	
	# Save document info
	if document_id != "":
		dict["document_id"] = document_id
	if document_text != "":
		dict["document_text"] = document_text
	
	return dict

func from_dict(data: Dictionary):
	interactable_id = data.get("id", interactable_id)
	name = data.get("name", name)
	description = data.get("description", description)
	
	var pos_dict = data.get("position", {"x": position.x, "y": position.y})
	position = Vector2(pos_dict.x, pos_dict.y)
	
	has_container = data.get("has_container", has_container)
	is_examined = data.get("is_examined", is_examined)
	
	# Load container
	if has_container:
		if not container_inventory:
			container_inventory = Inventory.new()
		
		if data.has("container_inventory"):
			container_inventory.from_dict(data["container_inventory"])
	
	# Load document
	document_id = data.get("document_id", document_id)
	document_text = data.get("document_text", document_text)

func has_document() -> bool:
	return document_id != "" or document_text != ""

func get_display_name() -> String:
	return name if is_examined else "???"

func examine():
	is_examined = true
