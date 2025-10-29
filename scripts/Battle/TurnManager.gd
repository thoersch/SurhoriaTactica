class_name TurnManager

signal turn_changed(is_player_turn: bool)
signal phase_changed(phase: String)

enum Phase { PLAYER_TURN, ENEMY_TURN }

var current_phase: Phase = Phase.PLAYER_TURN
var turn_number: int = 1

func start_battle():
	turn_number = 1
	current_phase = Phase.PLAYER_TURN
	turn_changed.emit(true)

func is_player_turn() -> bool:
	return current_phase == Phase.PLAYER_TURN

func end_current_turn():
	if current_phase == Phase.PLAYER_TURN:
		current_phase = Phase.ENEMY_TURN
		turn_changed.emit(false)
		phase_changed.emit("enemy")
	else:
		current_phase = Phase.PLAYER_TURN
		turn_number += 1
		turn_changed.emit(true)
		phase_changed.emit("player")

func get_turn_text() -> String:
	if current_phase == Phase.PLAYER_TURN:
		return "Turn " + str(turn_number) + " - Player Phase"
	else:
		return "Turn " + str(turn_number) + " - Enemy Phase"
