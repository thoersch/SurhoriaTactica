extends RefCounted
class_name Skill

enum SkillType {
	PASSIVE,
	ACTIVE_HEAL,
	ACTIVE_ATTACK,
	ACTIVE_BUFF
}

var skill_id: String
var skill_name: String
var description: String
var skill_type: SkillType
var max_rank: int = 1
var current_rank: int = 0
var cost_per_rank: int = 1

# Requirements
var required_level: int = 1
var prerequisite_skills: Array = []  # Array of skill_ids

# Passive effects
var passive_effects: Dictionary = {}
# Example: {"defense_in_rubble": 5, "sandbag_penetration": 15}

# Active ability data
var active_data: Dictionary = {}
# Example: {"heal_amount": 30, "range": 1, "aoe": 0}

func _init(data: Dictionary = {}):
	if data.is_empty():
		return
	
	skill_id = data.get("id", "")
	skill_name = data.get("name", "Skill")
	description = data.get("description", "")
	
	var type_str = data.get("type", "passive")
	match type_str:
		"passive":
			skill_type = SkillType.PASSIVE
		"active_heal":
			skill_type = SkillType.ACTIVE_HEAL
		"active_attack":
			skill_type = SkillType.ACTIVE_ATTACK
		"active_buff":
			skill_type = SkillType.ACTIVE_BUFF
	
	max_rank = data.get("max_rank", 1)
	cost_per_rank = data.get("cost_per_rank", 1)
	required_level = data.get("required_level", 1)
	prerequisite_skills = data.get("prerequisites", [])
	passive_effects = data.get("passive_effects", {})
	active_data = data.get("active_data", {})

func can_unlock(unit_level: int, unlocked_skills: Array) -> bool:
	"""Check if skill can be unlocked"""
	# Check level requirement
	if unit_level < required_level:
		return false
	
	# Check if already maxed
	if current_rank >= max_rank:
		return false
	
	# Check prerequisites
	for prereq_id in prerequisite_skills:
		if not prereq_id in unlocked_skills:
			return false
	
	return true

func unlock_rank():
	"""Increase skill rank"""
	if current_rank < max_rank:
		current_rank += 1

func is_unlocked() -> bool:
	return current_rank > 0

func get_rank_description() -> String:
	if max_rank > 1:
		return skill_name + " (Rank " + str(current_rank) + "/" + str(max_rank) + ")"
	return skill_name

func to_dict() -> Dictionary:
	return {
		"id": skill_id,
		"current_rank": current_rank
	}

func from_dict(data: Dictionary):
	skill_id = data.get("id", skill_id)
	current_rank = data.get("current_rank", 0)
