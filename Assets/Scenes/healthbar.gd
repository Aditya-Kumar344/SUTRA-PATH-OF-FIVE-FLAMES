extends TextureProgressBar

@export var player: CharacterBody2D  # Drag your player node here in the inspector
@export var animation_duration: float = 0.5  # How long the health change animation takes
@export var damage_flash_duration: float = 0.15  # Duration of damage flash effect
@export var heal_flash_duration: float = 0.3  # Duration of heal flash effect

# Or use node path if you prefer:
# @export var player_path: NodePath = "../Player"

var pulse_timer: float = 0.0  # Custom timer for pulsing effect
var current_displayed_health: float = 0.0  # What the bar currently shows
var target_health: float = 0.0  # What the bar should show
var previous_health: float = 0.0  # Track previous health to detect changes
var health_tween: Tween  # Tween for smooth health transitions
var flash_tween: Tween  # Tween for flash effects

# Adaptive properties for different enemy types
var player_max_health: int = 100  # Default fallback value
var initial_health: int = 100  # Store initial health for enemies without max_health

func _ready():
	# If using node path instead of direct reference:
	# player = get_node(player_path)
	
	# Make sure we have a player reference
	if not player:
		# Try to find player in the scene
		player = get_tree().get_first_node_in_group("Player")
	
	if player:
		# Detect and set max health based on available properties
		_detect_and_set_max_health()
		
		# Set initial values
		var current_health = _get_current_health()
		current_displayed_health = float(current_health)
		target_health = float(current_health)
		previous_health = float(current_health)
		value = current_displayed_health
		
		# Optional: Connect to player signals if you want instant updates
		# You'll need to add these signals to your player script
		# player.health_changed.connect(_on_player_health_changed)
	else:
		print("Warning: No player found for health bar!")

func _detect_and_set_max_health():
	"""Detect the type of entity and set appropriate max health"""
	if "max_health" in player:
		# Entity has max_health property (like fire enemy)
		player_max_health = player.max_health
		print("Health bar: Using max_health property: ", player_max_health)
	elif "health" in player:
		# Entity only has health property (like bat enemy)
		# Use current health as max health (assuming it starts at full health)
		initial_health = player.health
		player_max_health = initial_health
		print("Health bar: Using initial health as max: ", player_max_health)
	else:
		# Fallback - try to find any health-related property
		print("Warning: No health properties found, using default max_health: ", player_max_health)
	
	max_value = player_max_health

func _get_current_health() -> int:
	"""Get current health from the entity"""
	if "health" in player:
		return max(0, player.health)
	else:
		print("Warning: No health property found!")
		return 0

func _get_max_health() -> int:
	"""Get max health from the entity"""
	if "max_health" in player:
		return player.max_health
	else:
		# For entities without max_health, use the stored initial health
		return player_max_health

func _process(delta):
	# Update pulse timer
	pulse_timer += delta
	
	# Update health bar with smooth transitions
	if player:
		var actual_health = _get_current_health()
		var current_max_health = _get_max_health()
		
		# Update max_value if it has changed (for dynamic max health)
		if current_max_health != max_value:
			max_value = current_max_health
			player_max_health = current_max_health
		
		# Check if health has changed
		if actual_health != previous_health:
			target_health = float(actual_health)
			
			# Determine if it's damage or healing
			var is_healing = actual_health > previous_health
			var is_damage = actual_health < previous_health
			
			# Start smooth transition
			animate_health_change(current_displayed_health, target_health, is_healing, is_damage)
			
			previous_health = float(actual_health)
		
		# Update the visual bar value (this will be smoothly animated)
		value = current_displayed_health
		
		# Optional: Add visual feedback based on health percentage
		var health_percent = current_displayed_health / max_value
		
		# Change tint color based on health (only if not flashing)
		if not flash_tween or not flash_tween.is_valid():
			update_health_color(health_percent)
		
		# Optional: Add pulsing effect when health is critically low
		if health_percent < 0.2 and health_percent > 0:
			# Pulse the alpha of the progress tint
			var alpha = 0.7 + 0.3 * sin(pulse_timer * 8)
			var current_color = tint_progress
			current_color.a = alpha
			tint_progress = current_color
		elif not flash_tween or not flash_tween.is_valid():
			# Reset alpha when not in critical state and not flashing
			var current_color = tint_progress
			current_color.a = 1.0
			tint_progress = current_color

func animate_health_change(from_health: float, to_health: float, is_healing: bool, is_damage: bool):
	"""Smoothly animate health bar changes"""
	
	# Stop any existing health animation
	if health_tween:
		health_tween.kill()
	
	# Create new tween for health animation
	health_tween = create_tween()
	health_tween.set_ease(Tween.EASE_OUT)
	health_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Animate the displayed health value
	health_tween.tween_method(
		func(health_val: float): current_displayed_health = health_val,
		from_health,
		to_health,
		animation_duration
	)
	
	# Add flash effect based on change type
	if is_damage:
		flash_damage()
	elif is_healing:
		flash_heal()

func update_health_color(health_percent: float):
	"""Update the health bar color based on health percentage"""
	if health_percent > 0.6:
		tint_progress = Color.GREEN
	elif health_percent > 0.3:
		# For better yellow with colored textures, use a brighter/more saturated yellow
		tint_progress = Color(1.2, 1.2, 0.0)  # Brighter yellow (values can go above 1.0)
	elif health_percent > 0:
		tint_progress = Color.RED
	else:
		tint_progress = Color.DARK_RED  # Dead

func flash_damage():
	"""Flash effect when player takes damage"""
	if flash_tween:
		flash_tween.kill()
	
	flash_tween = create_tween()
	
	# Store the current color to return to it
	var current_color = tint_progress
	
	# Quick white flash then back to current color
	#flash_tween.tween_property(self, "tint_progress", Color.WHITE, damage_flash_duration * 0.5)
	#flash_tween.tween_property(self, "tint_progress", current_color, damage_flash_duration * 0.5)
	
	# Optional: Add slight screen shake effect (if you have a camera shake system)
	# CameraShake.shake(0.1, 5.0)

func flash_heal():
	"""Flash effect when player heals"""
	if flash_tween:
		flash_tween.kill()
	
	flash_tween = create_tween()
	flash_tween.set_parallel(true)
	
	# Flash to bright green then fade back
	var original_color = tint_progress
	
	# Gentle green glow effect
	flash_tween.tween_property(self, "tint_progress", Color(0.5, 2.0, 0.5), heal_flash_duration * 0.4)
	flash_tween.tween_property(self, "tint_progress", Color.GREEN, heal_flash_duration * 0.6).set_delay(heal_flash_duration * 0.4)

# Alternative method using signals (more efficient)
# Add this to your player script if you want to use signals instead of _process:
# signal health_changed(new_health, max_health)
# Then emit it whenever health changes: health_changed.emit(health, max_health)
func _on_player_health_changed(new_health: int, max_health: int):
	"""Connect this to player's health_changed signal for instant updates"""
	max_value = max_health
	player_max_health = max_health
	target_health = float(new_health)
	
	# Determine change type
	var is_healing = new_health > previous_health
	var is_damage = new_health < previous_health
	
	# Start animation
	animate_health_change(current_displayed_health, target_health, is_healing, is_damage)
	previous_health = float(new_health)

# Additional methods for more advanced effects
func set_health_bar_style(style: String):
	"""Call this to change the visual style"""
	match style:
		"normal":
			tint_progress = Color.GREEN
		"warning":
			tint_progress = Color(1.0, 1.0, 0.0)  # Pure bright yellow
		"danger":
			tint_progress = Color.RED
		"critical":
			tint_progress = Color.DARK_RED
			# Add screen shake or other effects here

func instant_update():
	"""Force instant health bar update (skip animation)"""
	if player:
		var current_health = _get_current_health()
		current_displayed_health = float(current_health)
		target_health = current_displayed_health
		previous_health = current_displayed_health
		value = current_displayed_health
		
		# Stop any ongoing animations
		if health_tween:
			health_tween.kill()
		if flash_tween:
			flash_tween.kill()

# Method to manually set max health (useful for entities that change their max health)
func set_max_health(new_max_health: int):
	"""Manually set the max health for the health bar"""
	player_max_health = new_max_health
	max_value = new_max_health
	print("Health bar: Max health manually set to: ", new_max_health)

# Method to refresh health detection (call this if entity properties change)
func refresh_health_detection():
	"""Re-detect health properties - useful if entity changes at runtime"""
	if player:
		_detect_and_set_max_health()
		instant_update()

# Call this if you want to preview the health bar animations in editor
func _preview_damage(amount: int = 20):
	"""Preview damage animation (for testing)"""
	if player:
		animate_health_change(current_displayed_health, current_displayed_health - amount, false, true)

func _preview_heal(amount: int = 30):
	"""Preview heal animation (for testing)"""
	if player:
		var new_health = min(current_displayed_health + amount, max_value)
		animate_health_change(current_displayed_health, new_health, true, false)
