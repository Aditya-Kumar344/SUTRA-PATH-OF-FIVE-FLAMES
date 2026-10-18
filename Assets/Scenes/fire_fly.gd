extends CharacterBody2D

@export var max_health: int = 100
@export var fireball_scene: PackedScene  # Assign your fireball scene here
@export var fireball_damage: int = 25
@export var knockback_force: float = 600.0
@export var knockback_duration: float = 0.5
@export var attack_range: float = 600.0  # Range within which enemy will attack
@export var min_attack_interval: float = 1.5
@export var max_attack_interval: float = 2.5
@export var fireball_spawn_delay: float = 0.3  # Time after attack animation starts to spawn fireball

# Signal for health bar integration
signal health_changed(new_health: int, max_health: int)

var player: CharacterBody2D = null
var health: int = 100
var is_dead: bool = false
var is_attacking: bool = false
var attack_timer: float = 0.0
var fireball_spawn_timer: float = 0.0
var next_attack_interval: float = 0.0
var facing_direction: int = 1  # 1 for right, -1 for left

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fireball_spawn_point: Marker2D = $AnimatedSprite2D/Marker2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var health_bar: TextureProgressBar = $TextureProgressBar

func _ready():
	add_to_group("Enemy")
	health = max_health
	
	# Find player reference
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D
	
	# Set up health bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	
	# Emit initial health signal for external health bar if needed
	health_changed.emit(health, max_health)
	
	# Set up initial attack timer with random interval
	_set_next_attack_interval()
	attack_timer = next_attack_interval
	
	# Connect animation finished signal
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	# Start with idle animation
	if animated_sprite:
		animated_sprite.play("idle")
	
	print("Flying enemy ready! Will fire first fireball in: ", next_attack_interval, " seconds")

func _physics_process(delta: float) -> void:
	if is_dead or player == null:
		return
	
	# Check if player is within attack range
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Update facing direction based on player position
	var direction_to_player = sign(player.global_position.x - global_position.x)
	if direction_to_player != 0:
		facing_direction = int(direction_to_player)
		
		# Update sprite facing (reversed to match sprite artwork)
		if facing_direction > 0:
			animated_sprite.scale.x = -abs(animated_sprite.scale.x)  # Face right (flipped sprite)
		else:
			animated_sprite.scale.x = abs(animated_sprite.scale.x)  # Face left (normal sprite)
	
	# Only attack if player is within range
	if distance_to_player <= attack_range:
		# Handle attack timing
		if not is_attacking:
			attack_timer -= delta
			if attack_timer <= 0:
				start_attack()
		
		# Handle fireball spawn timing (spawn fireball after delay during attack animation)
		if is_attacking and fireball_spawn_timer > 0:
			fireball_spawn_timer -= delta
			if fireball_spawn_timer <= 0:
				spawn_fireball()
	else:
		# Player is out of range, just idle
		if not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func _set_next_attack_interval():
	"""Set random interval for next attack"""
	next_attack_interval = randf_range(min_attack_interval, max_attack_interval)

func start_attack():
	"""Start the attack sequence"""
	if is_dead or is_attacking:
		return
	
	# Check if player is still in range before starting attack
	if player and global_position.distance_to(player.global_position) > attack_range:
		# Player moved out of range, reset timer for next check
		_set_next_attack_interval()
		attack_timer = next_attack_interval
		return
	
	is_attacking = true
	fireball_spawn_timer = fireball_spawn_delay  # Set timer for fireball spawn
	
	# Play attack animation
	if animated_sprite:
		animated_sprite.play("attack")
	
	print("Enemy starting attack!")

func spawn_fireball():
	"""Spawn the actual fireball projectile after delay"""
	if not fireball_scene:
		print("ERROR: Fireball scene not assigned!")
		return
	
	if not fireball_spawn_point:
		print("ERROR: Fireball spawn point not found!")
		return
	
	# Create fireball instance
	var fireball = fireball_scene.instantiate()
	get_tree().current_scene.add_child(fireball)
	
	# Set fireball position
	fireball.global_position = fireball_spawn_point.global_position
	
	# Set fireball z-index to appear above other objects
	fireball.z_index = 1
	
	# Fire fireball in the direction the enemy is facing
	var fireball_direction: Vector2
	if facing_direction > 0:
		fireball_direction = Vector2.RIGHT
	else:
		fireball_direction = Vector2.LEFT
	
	# Set up fireball with direction, damage, and knockback
	if fireball.has_method("setup_fireball"):
		fireball.setup_fireball(fireball_direction, fireball_damage, knockback_force, knockback_duration)
	else:
		# Fallback setup if method name is different
		fireball.direction = fireball_direction
		fireball.damage = fireball_damage
		fireball.knockback_force = knockback_force
		fireball.knockback_duration = knockback_duration
	
	print("Fireball spawned in direction: ", fireball_direction, " (facing_direction: ", facing_direction, ")")

func _on_animation_finished():
	"""Handle animation finished events"""
	if not animated_sprite:
		return
	
	if animated_sprite.animation == "attack":
		# Attack animation finished, return to idle
		finish_attack()
		animated_sprite.play("idle")
	elif animated_sprite.animation == "die":
		# Death animation finished, remove from scene
		handle_death_complete()

func finish_attack():
	"""Called when attack animation finishes"""
	is_attacking = false
	fireball_spawn_timer = 0.0
	
	# Set up next attack
	_set_next_attack_interval()
	attack_timer = next_attack_interval
	
	print("Attack finished. Next attack in: ", next_attack_interval, " seconds")

func take_damage(damage: int):
	"""Take damage from player attacks"""
	if is_dead:
		return
	
	health -= damage
	print("Flying enemy took ", damage, " damage. Health: ", health)
	
	# Update health bar
	if health_bar:
		health_bar.value = health
	
	# Emit health changed signal for external health bar
	health_changed.emit(health, max_health)
	
	# Play hurt animation briefly if not attacking
	if not is_attacking and animated_sprite:
		animated_sprite.play("hurt")
		# Use a timer to return to idle after hurt animation
		get_tree().create_timer(0.3).timeout.connect(func(): 
			if not is_dead and not is_attacking:
				animated_sprite.play("idle")
		)
	
	if health <= 0:
		die()

func die():
	"""Handle enemy death"""
	if is_dead:
		return
	
	is_dead = true
	is_attacking = false
	attack_timer = 0.0
	fireball_spawn_timer = 0.0
	
	# Update health bar to 0
	if health_bar:
		health_bar.value = 0
	
	# Emit final health signal (0 health)
	health_changed.emit(0, max_health)
	
	# Play death animation
	if animated_sprite:
		animated_sprite.play("die")
	
	# Disable physics processing
	set_physics_process(false)
	
	# Disable collision
	if collision_shape:
		collision_shape.call_deferred("set_disabled", true)
	
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
