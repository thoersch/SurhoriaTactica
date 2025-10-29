extends Node2D

var game_state: GameState

func _ready():
	game_state = GameState.new()
	game_state.initialize(self)
	game_state.unit_selected.connect(_on_unit_selected)
	game_state.unit_action_complete.connect(_on_unit_action_complete)
	game_state.battle_loaded.connect(_on_battle_loaded)
	game_state.battle_won.connect(_on_battle_won)
	game_state.battle_lost.connect(_on_battle_lost)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game_state.handle_mouse_click(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		game_state.handle_mouse_motion(get_global_mouse_position())
	
	# Quick battle switching for testing
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			game_state.load_battle("battle_01_outbreak", self)
		elif event.keycode == KEY_2:
			game_state.load_battle("battle_02_campsite", self)
		elif event.keycode == KEY_3:
			game_state.load_battle("battle_03_laboratory", self)
		elif event.keycode == KEY_R and event.shift_pressed:
			PlayerRoster.initialize_default_roster()
			PlayerRoster.save_roster()
			print("Player roster reset! Press 1 to reload battle.")

func _on_unit_selected(unit):
	pass

func _on_unit_action_complete(unit):
	pass

func _on_battle_loaded(battle_id):
	print("Battle loaded: " + battle_id)

func _on_battle_won():
	print("Victory! Battle won!")

func _on_battle_lost():
	print("Defeat! Battle lost!")
