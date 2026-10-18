extends CharacterBody2D

@export var max_health: int = 100
@export var laser_scene: PackedScene  # Assign your laser scene here
@export var laser_damage: int = 25
@export var knockback_force: float = 600.0
@export var knockback_duration: float = 0.5
@export var attack_range: float = 1500.0  # Range within which enemy will attack
@export var min_laser_interval: float = 1.5
@export var max_laser_interval: float = 2.5
@export var laser_spawn_delay: float = 0.6  # Time after laser animation starts to spawn laser

# Signal for health bar integration
signal health_changed(new_health: int, max_health: int)

var player: CharacterBody2D = null
var health: int = 100
var is_dead: bool = false
var is_firing_laser: bool = false
var laser_timer: float = 0.0
var laser_spawn_timer: float = 0.0
var next_laser_interval: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var laser_spawn_point: Marker2D = $AnimatedSprite2D/LaserSpawnPoint
@onready var life_timer: Timer = $LifeTimer

func _ready():
	add_to_group("Enemy")
	health = max_health
	
	# Find player reference
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D
	
	# Emit initial health signal for health bar
	health_changed.emit(health, max_health)
	
	# Set up initial laser timer with random interval
	_set_next_laser_interval()
	laser_timer = next_laser_interval
	
	# Connect animation finished signal
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Start with idle animation
	if animated_sprite:
		animated_sprite.play("idle")
	
	print("Flying enemy ready! Will fire first laser in: ", next_laser_interval, " seconds")

func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return
	
	# Check if player is within attack range
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Update facing direction based on player position (static enemy, no movement)
	var direction = sign(player.global_position.x - global_position.x)
	if direction > 0:
		animated_sprite.scale.x = abs(animated_sprite.scale.x)  # Face right (positive scale)
	elif direction < 0:
		animated_sprite.scale.x = -abs(animated_sprite.scale.x)  # Face left (negative scale)
	
	# Only attack if player is within range
	if distance_to_player <= attack_range:
		# Handle laser timing
		if not is_firing_laser:
			laser_timer -= delta
			if laser_timer <= 0:
				start_laser_attack()
		
		# Handle laser spawn timing (spawn laser after delay during laser animation)
		if is_firing_laser and laser_spawn_timer > 0:
			laser_spawn_timer -= delta
			if laser_spawn_timer <= 0:
				spawn_laser()
	else:
		# Player is out of range, just idle
		if not is_firing_laser and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func _set_next_laser_interval():
	"""Set random interval for next laser attack"""
	next_laser_interval = randf_range(min_laser_interval, max_laser_interval)

func start_laser_attack():
	"""Start the laser attack sequence"""
	if is_dead or is_firing_laser:
		return
	
	# Check if player is still in range before starting attack
	if player and global_position.distance_to(player.global_position) > attack_range:
		# Player moved out of range, reset timer for next check
		_set_next_laser_interval()
		laser_timer = next_laser_interval
		return
	
	is_firing_laser = true
	laser_spawn_timer = laser_spawn_delay  # Set timer for laser spawn
	
	# Play laser animation
	if animated_sprite:
		animated_sprite.play("laser")
	
	print("Enemy starting laser attack!")

func spawn_laser():
	"""Spawn the actual laser projectile after delay"""
	if not laser_scene:
		print("ERROR: Laser scene not assigned!")
		return
	
	if not laser_spawn_point:
		print("ERROR: Laser spawn point not found!")
		return
	
	# Create laser instance
	var laser = laser_scene.instantiate()
	get_tree().current_scene.add_child(laser)
	
	# Set laser position
	laser.global_position = laser_spawn_point.global_position
	
	# Set laser z-index to appear above other objects
	laser.z_index = 1
	
	# Fire laser horizontally based on enemy's facing direction
	var horizontal_direction = Vector2.RIGHT
	if animated_sprite.scale.x < 0:  # Facing left
		horizontal_direction = Vector2.LEFT
	else:  # Facing right
		horizontal_direction = Vector2.RIGHT
	
	# Set up laser with horizontal direction, damage, and knockback
	if laser.has_method("setup_laser"):
		laser.setup_laser(horizontal_direction, laser_damage, knockback_force, knockback_duration)
	else:
		# Fallback setup if method name is different
		laser.direction = horizontal_direction
		laser.damage = laser_damage
		laser.knockback_force = knockback_force
		laser.knockback_duration = knockback_duration
	
	print("Laser spawned horizontally in direction: ", horizontal_direction)

func _on_animation_finished():
	"""Handle animation finished events"""
	if not animated_sprite:
		return
	
	if animated_sprite.animation == "laser":
		# Laser animation finished, return to idle
		finish_laser_attack()
		animated_sprite.play("idle")
	elif animated_sprite.animation == "die":
		# Death animation finished, remove from scene
		handle_death_complete()

func finish_laser_attack():
	"""Called when laser attack animation finishes"""
	is_firing_laser = false
	laser_spawn_timer = 0.0
	
	# Set up next laser attack
	_set_next_laser_interval()
	laser_timer = next_laser_interval
	
	print("Laser attack finished. Next laser in: ", next_laser_interval, " seconds")

func take_damage(damage: int):
	"""Take damage from player attacks"""
	if is_dead:
		return
	
	health -= damage
	print("Flying enemy took ", damage, " damage. Health: ", health)
	
	# Emit health changed signal for health bar
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()

func die():
	"""Handle enemy death"""
	if is_dead:
		return
	
	is_dead = true
	is_firing_laser = false
	laser_timer = 0.0
	laser_spawn_timer = 0.0
	
	# Emit final health signal (0 health)
	health_changed.emit(0, max_health)
	
	# Play death animation
	if animated_sprite:
		animated_sprite.play("die")
	
	# Disable physics processing
	set_physics_process(false)
	
	# Disable collision
	$CollisionShape2D.call_deferred("set_disabled", true)
	
	print("Flying enemy died!")

func handle_death_complete():
	"""Called when death animation finishes"""
	# Remove enemy from scene
	queue_free()

# Note: This enemy doesn't receive knockback as specified
func apply_knockback(knockback_vector: Vector2, duration: float):
	"""Enemy doesn't receive knockback - override to do nothing"""
	pass

func get_health_percentage() -> float:
	"""Get health as percentage for UI purposes"""
	return float(health) / float(max_health)

func can_take_damage() -> bool:
	"""Check if enemy can take damage"""
	return not is_dead
