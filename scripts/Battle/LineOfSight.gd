extends RefCounted
class_name LineOfSight

# Coverage percentages
const COVERAGE_BLOCKED = 100  # Wall, crate - no shot
const COVERAGE_HEAVY = 50     # Sandbag - 50% damage reduction
const COVERAGE_LIGHT = 25     # Rubble, window - 25% damage reduction
const COVERAGE_UNIT = 50      # Friendly unit - 50% coverage

# Map terrain cover values to percentages
static func get_coverage_percentage(cover_value: int) -> int:
	match cover_value:
		0: return 0
		1: return COVERAGE_LIGHT
		2: return COVERAGE_BLOCKED
		3: return COVERAGE_HEAVY
		_: return 0

static func check_line_of_sight(from: Vector2, to: Vector2, terrain_data: Array, units: Array, attacker: Unit) -> Dictionary:
	"""
	Returns a dictionary with:
	- blocked: bool - whether shot is completely blocked
	- coverage: int - coverage percentage (0-100)
	- blocking_tile: Vector2 - position of tile providing cover (if any)
	- blocking_type: String - what's blocking ("terrain", "unit", or "")
	"""
	
	# Get all tiles between attacker and target
	var line_tiles = bresenham_line(from, to)
	
	# Remove the first tile (attacker's position) and last tile (target's position)
	if line_tiles.size() > 2:
		line_tiles.remove_at(0)  # Remove attacker tile
		line_tiles.remove_at(line_tiles.size() - 1)  # Remove target tile
	else:
		# Adjacent units - no tiles in between
		return {
			"blocked": false,
			"coverage": 0,
			"blocking_tile": Vector2(-1, -1),
			"blocking_type": ""
		}
	
	var max_coverage = 0
	var blocking_tile = Vector2(-1, -1)
	var blocking_type = ""
	
	# Check each tile along the line
	for tile_pos in line_tiles:
		# Check terrain coverage
		if tile_pos.y >= 0 and tile_pos.y < terrain_data.size():
			if tile_pos.x >= 0 and tile_pos.x < terrain_data[int(tile_pos.y)].size():
				var tile = terrain_data[int(tile_pos.y)][int(tile_pos.x)]
				var cover_value = tile.get("cover", 0)
				var coverage = get_coverage_percentage(cover_value)
				
				if coverage > max_coverage:
					max_coverage = coverage
					blocking_tile = tile_pos
					blocking_type = "terrain"
		
		# Check for friendly units providing cover
		for unit in units:
			if unit == attacker:
				continue
			
			if unit.grid_pos == tile_pos and unit.is_player == attacker.is_player:
				# Friendly unit provides 50% cover
				if COVERAGE_UNIT > max_coverage:
					max_coverage = COVERAGE_UNIT
					blocking_tile = tile_pos
					blocking_type = "unit"
	
	return {
		"blocked": max_coverage >= COVERAGE_BLOCKED,
		"coverage": max_coverage,
		"blocking_tile": blocking_tile,
		"blocking_type": blocking_type
	}

static func bresenham_line(from: Vector2, to: Vector2) -> Array:
	"""
	Bresenham's line algorithm to get all grid positions between two points.
	Returns array of Vector2 positions.
	"""
	var points = []
	
	var x0 = int(from.x)
	var y0 = int(from.y)
	var x1 = int(to.x)
	var y1 = int(to.y)
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	var x = x0
	var y = y0
	
	while true:
		points.append(Vector2(x, y))
		
		if x == x1 and y == y1:
			break
		
		var e2 = 2 * err
		
		if e2 > -dy:
			err -= dy
			x += sx
		
		if e2 < dx:
			err += dx
			y += sy
	
	return points

static func calculate_damage_with_coverage(base_damage: int, coverage: int) -> int:
	"""
	Calculate final damage after applying coverage reduction.
	100% coverage = blocked (0 damage)
	50% coverage = 50% damage
	etc.
	"""
	if coverage >= COVERAGE_BLOCKED:
		return 0
	
	var damage_multiplier = 1.0 - (coverage / 100.0)
	return max(1, int(base_damage * damage_multiplier))
