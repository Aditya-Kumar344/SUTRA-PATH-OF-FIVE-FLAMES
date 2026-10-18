extends CharacterBody2D

@export var walk_speed: float = 250.0
@export var detection_range: float = 700.0
@export var attack_range: float = 150.0
@export var attack_interval: float = 1.0  # seconds per attack
@export var attack_damage: int = 10
@export var knockback_force: float = 200.0  # How far to push back when hurt
@export var knockback_duration: float = 0.4  # How long the knockback lasts
@export var platform_anim: AnimationPlayer

var player: CharacterBody2D = null
var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false
var max_health: int = 100  # Added max_health property
var health: int = 100
var has_damaged: bool = false
var knockback_velocity: float = 0.0
var knockback_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Optional: Signal for health changes (more efficient than _process)
signal health_changed(new_health: int, max_health: int)

# Nodes
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: Area2D = $"AnimatedSprite2D/Hit Area"
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Find player from global group
	add_to_group("Enemy")
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D
	
	# Hit area setup
	hit_area.monitoring = false  # Starts off
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	
	# Animation connections
	sprite.animation_finished.connect(_on_animation_finished)
	anim_player.animation_finished.connect(_on_animplayer_finished)
	
	# Debug platform_anim connection
	if platform_anim:
		print("Platform AnimationPlayer found and connected")
	else:
		print("WARNING: platform_anim is null! Check if it's assigned in the inspector")
	
	# Initialize health (ensure max_health is set properly)
	health = max_health
	# Emit initial health signal
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	if player == null or is_dead:
		return
	
	# Gravity application
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0
	
	# Handle knockback
	if is_hurt and knockback_timer > 0:
		knockback_timer -= delta
		velocity.x = knockback_velocity
		move_and_slide()
		if knockback_timer <= 0:
			is_hurt = false
			knockback_velocity = 0
		return
	
	# Handle attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	var dist: float = global_position.distance_to(player.global_position)
	var direction: float = sign(player.global_position.x - global_position.x)
	var facing_left: bool = direction < 0
	
	# Flip sprite and its children (including HitArea)
	sprite.scale.x = -3.75 if facing_left else 3.75
	
	# Don't move if in middle of attack or hurt
	if is_attacking or is_hurt:
		velocity.x = 0
		move_and_slide()
		return
	
	# Attack logic
	if dist <= attack_range and is_on_floor() and player.is_on_floor():
		velocity.x = 0
		if attack_cooldown_timer <= 0:
			start_attack()
	# Movement logic (chase if in detection range)
	elif dist <= detection_range and is_on_floor() and player.is_on_floor():
		velocity.x = direction * walk_speed
		sprite.play("walk")
	else:
		velocity.x = 0
		sprite.play("idle")
	
	move_and_slide()

func start_attack():
	"""Initiate attack sequence"""
	is_attacking = true
	has_damaged = false
	sprite.play("attack")           # Visual attack animation
	anim_player.play("attack_blue")  # Controls hitbox timing
	attack_cooldown_timer = attack_interval  # Start cooldown timer

# Functions called by AnimationPlayer keyframes
func enable_attack_collision():
	"""Called by AnimationPlayer when attack should hit"""
	hit_area.monitoring = true
	print("Character enemy attack collision enabled")

func disable_attack_collision():
	"""Called by AnimationPlayer when attack ends"""
	hit_area.monitoring = false
	print("Character enemy attack collision disabled")

func _on_animation_finished() -> void:
	# Reset attack state only if attack was playing
	if sprite.animation == "attack":
		is_attacking = false
	elif sprite.animation == "hurt":
		is_hurt = false
	elif sprite.animation == "die":
		# Death animation finished, remove from scene
		queue_free()

func _on_animplayer_finished(anim_name: StringName) -> void:
	"""AnimationPlayer finished - cleanup"""
	if anim_name == "attack_blue":
		# FIX: Use set_deferred during signal callbacks
		hit_area.set_deferred("monitoring", false)
		has_damaged = false

func _on_hit_area_body_entered(body: Node2D) -> void:
	if has_damaged or not hit_area.monitoring:
		return
	
	if body.is_in_group("Player"):
		print("Character enemy hit player for ", attack_damage)
		has_damaged = true
		body.take_damage(attack_damage)
		# FIX: Use set_deferred during signal callbacks
		hit_area.set_deferred("monitoring", false)

func take_damage(amount: int) -> void:
	if health <= 0 or is_dead:
		return
	
	health -= amount
	# Clamp health to prevent negative values
	health = max(health, 0)
	print("Character enemy took ", amount, " damage! Health: ", health, "/", max_health)
	
	# Emit health changed signal for health bar
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()
	else:
		# Play hurt animation and apply knockback
		play_hurt_animation()

func play_hurt_animation():
	"""Play hurt animation with knockback effect"""
	is_hurt = true
	is_attacking = false  # Cancel any ongoing attack
	
	# Calculate knockback direction (away from player)
	if player != null:
		var direction_to_player = sign(player.global_position.x - global_position.x)
		knockback_velocity = -direction_to_player * knockback_force
	else:
		# Default knockback direction based on sprite facing
		knockback_velocity = knockback_force if sprite.scale.x > 0 else -knockback_force
	
	knockback_timer = knockback_duration
	sprite.play("hurt")
	
	# Stop any ongoing attack
	hit_area.set_deferred("monitoring", false)
	has_damaged = false

func die() -> void:
	"""Handle death - play animation and cleanup"""
	print("Character enemy dying...")
	is_dead = true
	is_attacking = false
	is_hurt = false
	
	sprite.play("die")
	set_physics_process(false)
	# FIX: Use set_deferred for collision changes during signal callbacks
	$CollisionShape2D.set_deferred("disabled", true)
	hit_area.set_deferred("monitoring", false)
	
	# Trigger platform appearance with better error handling
	if platform_anim:
		print("Attempting to play platform animation...")
		if platform_anim.has_animation("Platform appear"):
			platform_anim.play("Platform appear")
			print("Platform animation started successfully")
		else:
			print("ERROR: Animation 'Platform appear' not found in platform_anim!")
			print("Available animations: ", platform_anim.get_animation_list())
	else:
		print("ERROR: platform_anim is null! Cannot trigger platform appearance.")
	
	# Note: queue_free() is now called in _on_animation_finished() 
	# when the death animation completes

# Health utility functions for health bar compatibility
func get_health_percentage() -> float:
	"""Returns current health as percentage (0.0 to 1.0)"""
	if max_health > 0:
		return float(health) / float(max_health)
	return 0.0

func is_enemy_dead() -> bool:
	"""Returns true if enemy is dead"""
	return is_dead

func get_current_health() -> int:
	"""Returns current health value"""
	return health

func get_max_health() -> int:
	"""Returns maximum health value"""
	return max_health

# Optional: Method to set max health (useful for different enemy types)
func set_max_health(new_max_health: int) -> void:
	"""Set new max health and adjust current health proportionally"""
	if new_max_health > 0:
		var health_ratio = get_health_percentage()
		max_health = new_max_health
		health = int(health_ratio * max_health)
		health_changed.emit(health, max_health)

# Optional: Method to heal the enemy
func heal(amount: int) -> void:
	"""Heal the enemy by specified amount"""
	if is_dead:
		return
	
	health = min(health + amount, max_health)
	print("Character enemy healed for ", amount, "! Health: ", health, "/", max_health)
	health_changed.emit(health, max_health)
