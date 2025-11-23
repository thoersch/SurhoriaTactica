extends Node
class_name SkillDatabase

static var skill_trees: Dictionary = {}  # class_name -> Array of skills

static func load_skills():
	"""Load all skill trees from JSON"""
	var path = "res://data/skills/skill_trees.json"
	
	if not FileAccess.file_exists(path):
		push_error("Skill trees file not found: " + path)
		initialize_default_skills()
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open skill trees file")
		initialize_default_skills()
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("Failed to parse skill trees JSON")
		initialize_default_skills()
		return
	
	var data = json.data
	skill_trees.clear()
	
	for unit_class  in data.get("skill_trees", {}).keys():
		var skills_data = data["skill_trees"][unit_class ]
		var skills = []
		for skill_data in skills_data:
			skills.append(Skill.new(skill_data))
		skill_trees[unit_class ] = skills
	
	print("Loaded skill trees for ", skill_trees.size(), " classes")

static func initialize_default_skills():
	"""Create default skill trees if file not found"""
	skill_trees = {
		"Rifleman": create_rifleman_skills(),
		"Scout": create_scout_skills(),
		"Grenadier": create_grenadier_skills()
	}

static func create_rifleman_skills() -> Array:
	return [
		Skill.new({
			"id": "rifleman_marksman",
			"name": "Marksman",
			"description": "Gain +2 Attack when at full HP",
			"type": "passive",
			"max_rank": 1,
			"cost_per_rank": 1,
			"required_level": 1,
			"prerequisites": [],
			"passive_effects": {"attack_at_full_hp": 2}
		}),
		Skill.new({
			"id": "rifleman_suppression",
			"name": "Suppression Fire",
			"description": "Reduce enemy defense by 15% when attacking through cover",
			"type": "passive",
			"max_rank": 1,
			"cost_per_rank": 1,
			"required_level": 2,
			"prerequisites": ["rifleman_marksman"],
			"passive_effects": {"cover_penetration": 15}
		}),
		Skill.new({
			"id": "rifleman_headshot",
			"name": "Headshot",
			"description": "Active: Deal 150% damage. Range: 4. Cooldown: 3 turns",
			"type": "active_attack",
			"max_rank": 1,
			"cost_per_rank": 2,
			"required_level": 4,
			"prerequisites": ["rifleman_suppression"],
			"active_data": {"damage_mult": 1.5, "range": 4, "cooldown": 3}
		})
	]

static func create_scout_skills() -> Array:
	return [
		Skill.new({
			"id": "scout_evasion",
			"name": "Evasion",
			"description": "Gain +3 Defense while moving",
			"type": "passive",
			"max_rank": 2,
			"cost_per_rank": 1,
			"required_level": 1,
			"prerequisites": [],
			"passive_effects": {"defense_while_moving": 3}
		}),
		Skill.new({
			"id": "scout_flanking",
			"name": "Flanking Bonus",
			"description": "Deal +20% damage when attacking from behind or sides",
			"type": "passive",
			"max_rank": 1,
			"cost_per_rank": 1,
			"required_level": 2,
			"prerequisites": ["scout_evasion"],
			"passive_effects": {"flanking_bonus": 20}
		}),
		Skill.new({
			"id": "scout_dash",
			"name": "Tactical Dash",
			"description": "Active: Move +3 extra tiles this turn. Cooldown: 4 turns",
			"type": "active_buff",
			"max_rank": 1,
			"cost_per_rank": 2,
			"required_level": 3,
			"prerequisites": ["scout_evasion"],
			"active_data": {"move_bonus": 3, "cooldown": 4}
		})
	]

static func create_grenadier_skills() -> Array:
	return [
		Skill.new({
			"id": "grenadier_blast",
			"name": "Improved Blast",
			"description": "Increase AoE radius by 1",
			"type": "passive",
			"max_rank": 1,
			"cost_per_rank": 1,
			"required_level": 1,
			"prerequisites": [],
			"passive_effects": {"aoe_bonus": 1}
		}),
		Skill.new({
			"id": "grenadier_rubble_expert",
			"name": "Rubble Expert",
			"description": "Gain +5 Defense while standing in rubble",
			"type": "passive",
			"max_rank": 1,
			"cost_per_rank": 1,
			"required_level": 2,
			"prerequisites": ["grenadier_blast"],
			"passive_effects": {"defense_in_rubble": 5}
		}),
		Skill.new({
			"id": "grenadier_breach",
			"name": "Sandbag Breacher",
			"description": "Deal 15% more damage through sandbag cover",
			"type": "passive",
			"max_rank": 1,
			"cost_per_rank": 1,
			"required_level": 2,
			"prerequisites": ["grenadier_blast"],
			"passive_effects": {"sandbag_penetration": 15}
		}),
		Skill.new({
			"id": "grenadier_incendiary",
			"name": "Incendiary Grenade",
			"description": "Active: Deal damage over 2 turns. Range: 3, AoE: 2. Cooldown: 5",
			"type": "active_attack",
			"max_rank": 1,
			"cost_per_rank": 3,
			"required_level": 5,
			"prerequisites": ["grenadier_rubble_expert", "grenadier_breach"],
			"active_data": {"damage": 20, "dot_turns": 2, "range": 3, "aoe": 2, "cooldown": 5}
		})
	]

static func get_skill_tree(unit_class : String) -> Array:
	"""Get all skills for a class"""
	return skill_trees.get(unit_class , [])

static func get_skill_by_id(skill_id: String) -> Skill:
	"""Find a skill by ID across all trees"""
	for tree in skill_trees.values():
		for skill in tree:
			if skill.skill_id == skill_id:
				return skill
	return null
