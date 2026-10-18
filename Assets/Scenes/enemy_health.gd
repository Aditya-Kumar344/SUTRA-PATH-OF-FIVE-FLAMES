extends TextureProgressBar

@export var enemy: CharacterBody2D  # Drag your enemy node here in the inspector
# Or use node path if you prefer:
# @export var enemy_path: NodePath = "../Enemy"

func _ready():
	# If using node path instead of direct reference:
	# enemy = get_node(enemy_path)
	
	# Make sure we have an enemy reference
	if not enemy:
		# Try to find enemy as parent or sibling
		var parent = get_parent()
		if parent.is_in_group("Enemy"):
			enemy = parent
		else:
			# Look for enemy in siblings
			for sibling in parent.get_children():
				if sibling.is_in_group("Enemy"):
					enemy = sibling
					break
	
	if enemy:
		# Set progress bar to work with percentages (0-100)
		min_value = 0
		max_value = 100
		
		# Set initial value based on enemy's health percentage
		if enemy.has_method("get_health_percentage"):
			value = enemy.get_health_percentage() * 100
			print("Health bar initialized using get_health_percentage(): ", value, "%")
		elif "health" in enemy and "max_health" in enemy:
			# Fallback calculation if enemy doesn't have get_health_percentage method
			value = (float(enemy.health) / float(enemy.max_health)) * 100
			print("Health bar initialized - Enemy health: ", enemy.health, "/", enemy.max_health, " (", value, "%)")
		else:
			print("Warning: Enemy doesn't have health or max_health properties!")
			value = 100  # Default to full health
	else:
		print("Warning: No enemy found for health bar!")

func _process(_delta):
	# Update health bar every frame based on percentage
	if enemy:
		# Calculate health percentage (0.0 to 1.0)
		var health_percentage: float
		
		if enemy.has_method("get_health_percentage"):
			health_percentage = enemy.get_health_percentage()
		elif "health" in enemy and "max_health" in enemy:
			# Fallback calculation
			if enemy.max_health > 0:
				health_percentage = float(enemy.health) / float(enemy.max_health)
			else:
				health_percentage = 0.0
		else:
			# If we can't access health properties, assume full health
			health_percentage = 1.0
		
		# Ensure percentage stays within bounds (0.0 to 1.0)
		health_percentage = clamp(health_percentage, 0.0, 1.0)
		
		# Convert to percentage for progress bar (0 to 100)
		value = health_percentage * 100
		
		# Hide health bar when enemy is dead (optional)
		if enemy.has_method("is_dead") and enemy.is_dead:
			visible = false
		elif "is_dead" in enemy and enemy.is_dead:
			visible = false
		elif "health" in enemy and enemy.health <= 0:
			visible = false
		else:
			visible = true

# Alternative method using signals (more efficient)
# Add this to your enemy script if you want to use signals instead of _process:
# signal health_changed(new_health, max_health)
# Then emit it whenever health changes: health_changed.emit(health, max_health)

func _on_enemy_health_changed(new_health: int, max_health: int):
	"""Connect this to enemy's health_changed signal for instant updates"""
	# Always work with percentages
	min_value = 0
	max_value = 100
	
	# Calculate percentage and set value
	if max_health > 0:
		var health_percentage = float(new_health) / float(max_health)
		health_percentage = clamp(health_percentage, 0.0, 1.0)
		value = health_percentage * 100
	else:
		value = 0

# Optional: Show damage numbers when enemy takes damage
func show_damage_number(damage: int):
	"""Call this when enemy takes damage to show floating damage text"""
	# You can implement floating damage numbers here
	pass

# Utility functions for debugging
func get_current_health_percentage() -> float:
	"""Returns current health as percentage (0.0 to 1.0)"""
	return value / 100.0

func debug_health_info():
	"""Print current health information"""
	if enemy:
		print("=== Health Bar Debug ===")
		if "health" in enemy and "max_health" in enemy:
			print("Enemy Health: ", enemy.health, "/", enemy.max_health)
		elif enemy.has_method("get_health_percentage"):
			print("Enemy Health Percentage: ", enemy.get_health_percentage())
		else:
			print("Cannot access enemy health properties")
		print("Health Percentage: ", get_current_health_percentage())
		print("Progress Bar Value: ", value, "/", max_value)
		print("======================")
	else:
		print("No enemy reference found for health bar debug")
