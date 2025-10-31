extends Node

var player_roster: Array = []
var current_world_map: String = "facility_floor1"
var world_position: Vector2 = Vector2.ZERO
var pending_battle_id: String = ""
var return_to_world_after_battle: bool = false
var world_state: WorldState = null

func _ready():
	PlayerRoster.load_roster()
	world_state = WorldState.new()

func start_battle(battle_id: String):
	pending_battle_id = battle_id
	return_to_world_after_battle = true
	print("GameManager: Starting battle ", battle_id)
	call_deferred("change_to_battle")

func change_to_battle():
	var error = get_tree().change_scene_to_file("res://scenes/BattleScene.tscn")
	if error != OK:
		push_error("Failed to load BattleScene: " + str(error))

func return_to_world():
	print("GameManager: Returning to world")
	call_deferred("change_to_world")

func change_to_world():
	var error = get_tree().change_scene_to_file("res://scenes/WorldScene.tscn")
	if error != OK:
		push_error("Failed to load WorldScene. Error: " + str(error))

func get_pending_battle() -> String:
	var battle = pending_battle_id
	pending_battle_id = ""
	return battle
