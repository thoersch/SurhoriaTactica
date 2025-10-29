class_name PlayerRoster

static var player_units: Array = []

static func initialize_default_roster():
	player_units = [
		{
			"name": "Rifleman",
			"move_range": 4,
			"attack_range": 4,
			"attack_min_range": 0,
			"attack_aoe": 0,
			"health": 100,
			"max_health": 100,
			"attack": 25,
			"defense": 10,
			"experience": 0,
			"level": 1
		},
		{
			"name": "Scout",
			"move_range": 7,
			"attack_range": 1,
			"attack_min_range": 0,
			"attack_aoe": 0,
			"health": 80,
			"max_health": 80,
			"attack": 15,
			"defense": 5,
			"experience": 0,
			"level": 1
		},
		{
			"name": "Grenadier",
			"move_range": 3,
			"attack_range": 3,
			"attack_min_range": 2,
			"attack_aoe": 1,
			"health": 70,
			"max_health": 70,
			"attack": 15,
			"defense": 4,
			"experience": 0,
			"level": 1
		}
	]

static func save_roster():
	var path = "user://player_roster.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify({"units": player_units}, "\t")
		file.store_string(json_string)
		file.close()

static func load_roster():
	var path = "user://player_roster.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var error = json.parse(json_string)
			
			if error == OK:
				var data = json.data
				player_units = data.get("units", [])
				return
	
	# If no save exists, initialize default roster
	initialize_default_roster()
