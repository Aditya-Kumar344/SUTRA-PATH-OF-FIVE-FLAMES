extends CharacterBody2D

# Enemy Stats
@export var max_health: int = 150
@export var attack1_damage: int = 10
@export var attack2_damage: int = 20
@export var attack3_damage: int = 30
@export var chase_speed: float = 400.0
@export var detection_range: float = 1000.0
@export var attack_range: float = 150.0

# Different knockback forces for each attack
@export var attack1_knockback: float = 200.0  # Light attack, less knockback
@export var attack2_knockback: float = 500.0  # Heavy hammer attack, strong knockback
@export var attack3_knockback: float = 350.0  # Medium knockback
@export var knockback_duration: float = 0.3
@export var hurt_invincibility_duration: float = 0.6

# Collectible settings - NEW
@export var collectible_scene: PackedScene
@export var next_scene_path: String = "res://scenes/NextLevel.tscn"

# Attack timing settings (halved to double the speed)
@export var attack1_duration: float = 0.3  # Was 0.6, now doubled speed
@export var attack2_duration: float = 0.8  # Was 1.6, now doubled speed
@export var attack3_duration: float = 0.7  # Was 1.4, now doubled speed
@export var defend_duration: float = 0.8
@export var attack_cooldown: float = 0.3

# Smart defend system
@export var defend_health_threshold: float = 0.4  # Defend more when health < 40%
@export var defend_after_damage_chance: float = 0.25  # 25% chance to defend after taking damage
@export var defend_base_chance: float = 0.05  # Base defend chance (reduced)
@export var defend_low_health_chance: float = 0.20  # Higher chance when low health (reduced)
@export var min_attacks_before_defend: int = 2  # Minimum attacks before defend is allowed

# Animation speed multipliers (doubled for faster attacks)
@export var idle_speed: float = 1.0
@export var run_speed: float = 1.2
@export var attack_speed: float = 2.0  # Doubled from 1.0 to 2.0
@export var hurt_speed: float = 1.5

# Enemy States
enum State {
	IDLE,
	CHASE,
	ATTACK1,
	ATTACK2,
	ATTACK3,
	DEFEND,
	HURT,
	DEAD
}

var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var health: int
var is_invincible: bool = false
var is_defending: bool = false
var has_damaged: bool = false
var facing_direction: int = 1
var player_target: Node2D = null
var is_dead: bool = false
var can_attack: bool = true
var just_took_damage: bool = false  # Track if just took damage for smart defend
var last_attack_type: int = 0  # Track last attack to prevent consecutive same attacks
var attacks_since_defend: int = 0  # Track attacks since last defend

# Camera shake for attack2
var camera_node: Camera2D = null
var original_camera_offset: Vector2 = Vector2.ZERO
var is_shaking_camera: bool = false

# Timers
var invincibility_timer: float = 0.0
var knockback_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var action_duration_timer: float = 0.0
var camera_shake_timer: float = 0.0
var attack2_shake_delay: float = 0.0  # Timer for attack2 shake delay

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

# Node References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack1_area: Area2D = $AnimatedSprite2D/attack1_area
@onready var attack2_area: Area2D = $AnimatedSprite2D/attack2_area
@onready var attack3_area: Area2D = $AnimatedSprite2D/attack3_area
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	add_to_group("Enemy")
	health = max_health
	
	# Find player from global group
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_target = players[0]
		# Find camera node (child of player)
		_find_camera_node()
	
	# Initialize all attack areas as disabled
	attack1_area.monitoring = false
	attack2_area.monitoring = false
	attack3_area.monitoring = false
	
	# Connect signals
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animation_player.animation_finished.connect(_on_animation_player_finished)
	attack1_area.body_entered.connect(_on_attack1_area_entered)
	attack2_area.body_entered.connect(_on_attack2_area_entered)
	attack3_area.body_entered.connect(_on_attack3_area_entered)
	
	change_state(State.IDLE)

func _find_camera_node():
	"""Find the camera node as child of player"""
	if player_target:
		for child in player_target.get_children():
			if child is Camera2D:
				camera_node = child
				original_camera_offset = camera_node.offset
				print("Camera found for shake effects")
				break

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD or player_target == null or is_dead:
		return
	
	# Update timers
	_update_timers(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0
	
	# Handle knockback
	if knockback_timer > 0:
		velocity.x = knockback_velocity.x
	else:
		# Normal movement and state logic
		_handle_movement_and_states(delta)
	
	move_and_slide()

func _update_timers(delta: float) -> void:
	# Handle attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			can_attack = true
	
	# Handle action duration
	if action_duration_timer > 0:
		action_duration_timer -= delta
		if action_duration_timer <= 0:
			_finish_current_action()
	
	# Handle attack2 shake delay (adjusted for doubled speed)
	if attack2_shake_delay > 0:
		attack2_shake_delay -= delta
		if attack2_shake_delay <= 0:
			_start_camera_shake(0.15)  # Shake for 0.15 seconds (halved for doubled speed)
	
	# Handle camera shake
	if camera_shake_timer > 0:
		camera_shake_timer -= delta
		if camera_shake_timer > 0:
			_apply_camera_shake()
		else:
			_stop_camera_shake()
	
	# Handle invincibility with flashing effect
	if invincibility_timer > 0:
		invincibility_timer -= delta
		animated_sprite.modulate.a = 0.4 + 0.6 * sin(invincibility_timer * 15)
		
		if invincibility_timer <= 0:
			is_invincible = false
			animated_sprite.modulate.a = 1.0
	
	# Handle knockback
	if knockback_timer > 0:
		knockback_timer -= delta
		if knockback_timer <= 0:
			knockback_velocity = Vector2.ZERO

func _handle_movement_and_states(_delta: float) -> void:
	# Get distance to player and direction
	var distance = global_position.distance_to(player_target.global_position)
	var direction = sign(player_target.global_position.x - global_position.x)
	
	# Update facing direction
	if direction != 0 and facing_direction != direction:
		facing_direction = direction
		_update_facing_direction()
	
	# State machine
	match current_state:
		State.IDLE:
			_handle_idle_state(distance)
		State.CHASE:
			_handle_chase_state(distance, direction)
		State.ATTACK1, State.ATTACK2, State.ATTACK3, State.DEFEND:
			_handle_action_states()
		State.HURT:
			_handle_hurt_state()

func _handle_idle_state(distance: float) -> void:
	velocity.x = 0
	
	# Check if player is within detection range
	if distance <= detection_range:
		if distance <= attack_range and can_attack:
			_decide_action()
		else:
			change_state(State.CHASE)

func _handle_chase_state(distance: float, direction: float) -> void:
	# Check if player is too far away
	if distance > detection_range * 1.5:
		change_state(State.IDLE)
		return
	
	# Check if close enough to attack or defend
	if distance <= attack_range and can_attack:
		_decide_action()
		return
	
	# Move towards player
	velocity.x = direction * chase_speed

func _handle_action_states() -> void:
	# Stop movement during actions
	velocity.x = 0

func _handle_hurt_state() -> void:
	# Hurt state is handled by knockback timer and animation callbacks
	pass

func _get_different_attack() -> int:
	"""Get a random attack type that's different from the last one"""
	var available_attacks = []
	
	# Add all attacks except the last one used
	for i in range(1, 4):  # 1, 2, 3
		if i != last_attack_type:
			available_attacks.append(i)
	
	# If no last attack (first attack), use all attacks
	if last_attack_type == 0:
		available_attacks = [1, 2, 3]
	
	# Return random attack from available options
	return available_attacks[randi() % available_attacks.size()]

func _decide_action() -> void:
	if not can_attack:
		return
	
	# Smart defend decision (only allow if enough attacks have passed)
	var should_defend = attacks_since_defend >= min_attacks_before_defend and _should_defend()
	
	if should_defend:
		change_state(State.DEFEND)
		action_duration_timer = defend_duration
		attacks_since_defend = 0  # Reset counter after defending
		print("Enemy is defending strategically! (After ", attacks_since_defend, " attacks)")
	else:
		# Choose attack type ensuring it's different from last attack
		var attack_choice = _get_different_attack()
		last_attack_type = attack_choice  # Store for next time
		attacks_since_defend += 1  # Increment attack counter
		
		match attack_choice:
			1:
				change_state(State.ATTACK1)
				action_duration_timer = attack1_duration
				print("Attack 1 chosen (attacks since defend: ", attacks_since_defend, ")")
			2:
				change_state(State.ATTACK2)
				action_duration_timer = attack2_duration
				# Set timer for camera shake at 0.35 seconds (halved from 0.7 for doubled speed)
				attack2_shake_delay = 0.35
				print("Attack 2 chosen (attacks since defend: ", attacks_since_defend, ")")
			3:
				change_state(State.ATTACK3)
				action_duration_timer = attack3_duration
				print("Attack 3 chosen (attacks since defend: ", attacks_since_defend, ")")
	
	# Start action cooldown
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	just_took_damage = false  # Reset damage flag after action decision

func _should_defend() -> bool:
	"""Smart defend logic based on multiple factors"""
	var health_percentage = get_health_percentage()
	var defend_chance = defend_base_chance
	
	# Higher chance to defend when low on health
	if health_percentage < defend_health_threshold:
		defend_chance = defend_low_health_chance
		print("Low health - increased defend chance to ", defend_chance)
	
	# Much higher chance to defend after taking damage
	if just_took_damage:
		defend_chance = defend_after_damage_chance
		print("Just took damage - increased defend chance to ", defend_chance)
	
	# Additional factors could include:
	# - Defend more against stronger attacks (if we track player's attack patterns)
	# - Defend less when player is far away
	# - Defend more when surrounded by multiple threats
	
	var should_defend = randf() < defend_chance
	if should_defend:
		print("Enemy chose to defend (chance was ", defend_chance, ")")
	
	return should_defend

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	# Exit current state cleanup
	match current_state:
		State.ATTACK1:
			attack1_area.monitoring = false
		State.ATTACK2:
			attack2_area.monitoring = false
		State.ATTACK3:
			attack3_area.monitoring = false
		State.DEFEND:
			is_defending = false
	
	# Store previous state
	previous_state = current_state
	current_state = new_state
	has_damaged = false
	
	# Enter new state
	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
			animated_sprite.speed_scale = idle_speed
		State.CHASE:
			animated_sprite.play("run")
			animated_sprite.speed_scale = run_speed
		State.ATTACK1:
			animated_sprite.play("attack1")
			animated_sprite.speed_scale = attack_speed  # Now 2.0 for doubled speed
			animation_player.play("attack1")
			# Set animation player speed to match sprite speed for synchronization
			animation_player.speed_scale = attack_speed
		State.ATTACK2:
			animated_sprite.play("attack2")
			animated_sprite.speed_scale = attack_speed  # Now 2.0 for doubled speed
			animation_player.play("attack2")
			# Set animation player speed to match sprite speed for synchronization
			animation_player.speed_scale = attack_speed
		State.ATTACK3:
			animated_sprite.play("attack3")
			animated_sprite.speed_scale = attack_speed  # Now 2.0 for doubled speed
			animation_player.play("attack3")
			# Set animation player speed to match sprite speed for synchronization
			animation_player.speed_scale = attack_speed
		State.DEFEND:
			animated_sprite.play("defend")
			animated_sprite.speed_scale = attack_speed
			animation_player.play("defend")
			# Set animation player speed to match sprite speed for synchronization
			animation_player.speed_scale = attack_speed
			is_defending = true
		State.HURT:
			animated_sprite.play("hurt")
			animated_sprite.speed_scale = hurt_speed
		State.DEAD:
			animated_sprite.play("die")
			animated_sprite.speed_scale = 1.0
			is_dead = true
			set_physics_process(false)
			collision_shape.set_deferred("disabled", true)

func _update_facing_direction() -> void:
	if facing_direction > 0:
		animated_sprite.scale.x = abs(animated_sprite.scale.x)
	else:
		animated_sprite.scale.x = -abs(animated_sprite.scale.x)

# Animation callbacks - called by AnimationPlayer keyframes
func enable_attack1() -> void:
	if current_state == State.ATTACK1:
		attack1_area.monitoring = true

func disable_attack1() -> void:
	attack1_area.monitoring = false

func enable_attack2() -> void:
	if current_state == State.ATTACK2:
		attack2_area.monitoring = true

func disable_attack2() -> void:
	attack2_area.monitoring = false

func enable_attack3() -> void:
	if current_state == State.ATTACK3:
		attack3_area.monitoring = true

func disable_attack3() -> void:
	attack3_area.monitoring = false

func _finish_current_action() -> void:
	"""Called when action duration timer expires"""
	var was_action_state = current_state in [State.ATTACK1, State.ATTACK2, State.ATTACK3, State.DEFEND]
	
	if was_action_state:
		# Go back to appropriate state after action
		if player_target and global_position.distance_to(player_target.global_position) <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)

# Animation finished callbacks
func _on_animation_finished() -> void:
	match animated_sprite.animation:
		"hurt":
			if health > 0:
				if player_target and global_position.distance_to(player_target.global_position) <= detection_range:
					change_state(State.CHASE)
				else:
					change_state(State.IDLE)
		"die":
			_handle_death()

func _on_animation_player_finished(anim_name: StringName) -> void:
	match anim_name:
		"attack1":
			attack1_area.monitoring = false
			has_damaged = false
		"attack2":
			attack2_area.monitoring = false
			has_damaged = false
		"attack3":
			attack3_area.monitoring = false
			has_damaged = false
		"defend":
			is_defending = false

# Attack collision callbacks with different knockback forces
func _on_attack1_area_entered(body: Node2D) -> void:
	if has_damaged or not attack1_area.monitoring or current_state != State.ATTACK1:
		return
	
	if body.is_in_group("Player"):
		has_damaged = true
		body.take_damage(attack1_damage)
		_apply_knockback_to_player(body, attack1_knockback)

func _on_attack2_area_entered(body: Node2D) -> void:
	if has_damaged or not attack2_area.monitoring or current_state != State.ATTACK2:
		return
	
	if body.is_in_group("Player"):
		has_damaged = true
		body.take_damage(attack2_damage)
		_apply_knockback_to_player(body, attack2_knockback)

func _on_attack3_area_entered(body: Node2D) -> void:
	if has_damaged or not attack3_area.monitoring or current_state != State.ATTACK3:
		return
	
	if body.is_in_group("Player"):
		has_damaged = true
		body.take_damage(attack3_damage)
		_apply_knockback_to_player(body, attack3_knockback)

func _apply_knockback_to_player(player_body: Node2D, knockback_strength: float):
	"""Apply specific knockback force to player based on attack type"""
	if player_body.has_method("apply_knockback"):
		var knockback_direction = (player_body.global_position - global_position).normalized()
		player_body.apply_knockback(knockback_direction * knockback_strength, knockback_duration)
		print("Applied ", knockback_strength, " knockback to player")

# Damage system
func take_damage(amount: int) -> void:
	if health <= 0 or is_invincible or is_dead:
		return
	
	# Reduce damage if defending
	if is_defending:
		amount = int(amount * 0.3)  # 70% damage reduction when defending
		print("Defending! Damage reduced to: ", amount)
	
	health -= amount
	just_took_damage = true  # Set flag for smart defend system
	
	if health <= 0:
		change_state(State.DEAD)
	else:
		# Apply knockback away from player (now applies even when defending)
		var knockback_direction = Vector2.ZERO
		if player_target:
			knockback_direction = (global_position - player_target.global_position).normalized()
		else:
			knockback_direction = Vector2(-facing_direction, 0)
		
		knockback_velocity = knockback_direction * 300.0  # Standard enemy knockback
		knockback_timer = knockback_duration
		
		# Start invincibility
		is_invincible = true
		invincibility_timer = hurt_invincibility_duration
		
		# Only change to hurt state if not defending
		if not is_defending:
			change_state(State.HURT)

# NEW: Handle death and spawn collectible
func _handle_death() -> void:
	# Spawn collectible at enemy position
	_spawn_collectible()
	
	# Remove enemy after delay
	await get_tree().create_timer(1.5).timeout
	queue_free()

# NEW: Spawn collectible function
func _spawn_collectible() -> void:
	if collectible_scene == null:
		print("Warning: No collectible scene assigned to enemy!")
		return
	
	# Instantiate the collectible
	var collectible_instance = collectible_scene.instantiate()
	
	# Set its position to the enemy's position
	collectible_instance.global_position = global_position
	
	# Set the next scene path if the collectible has the function
	if collectible_instance.has_method("set_next_scene"):
		collectible_instance.set_next_scene(next_scene_path)
	
	# Set that this collectible unlocks defend skill
	if collectible_instance.has_method("set_unlocks_defend_skill"):
		collectible_instance.set_unlocks_defend_skill(true)
	
	# Add to the same parent as the enemy (usually the main scene)
	get_parent().add_child(collectible_instance)
	
	print("Collectible spawned at enemy death location!")

# Utility functions
func get_health_percentage() -> float:
	return float(health) / float(max_health)

func is_player_in_range() -> bool:
	if not player_target:
		return false
	return global_position.distance_to(player_target.global_position) <= attack_range

func get_current_state_name() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.CHASE: return "CHASE"
		State.ATTACK1: return "ATTACK1"
		State.ATTACK2: return "ATTACK2"
		State.ATTACK3: return "ATTACK3"
		State.DEFEND: return "DEFEND"
		State.HURT: return "HURT"
		State.DEAD: return "DEAD"
		_: return "UNKNOWN"

# Camera shake functions for attack2
func _start_camera_shake(duration: float):
	"""Start camera shake effect"""
	if camera_node:
		is_shaking_camera = true
		camera_shake_timer = duration
		print("Camera shake started for ", duration, " seconds")

func _apply_camera_shake():
	"""Apply random offset to camera during shake"""
	if camera_node and is_shaking_camera:
		var shake_strength = 8.0  # Adjust shake intensity
		var random_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		camera_node.offset = original_camera_offset + random_offset

func _stop_camera_shake():
	"""Stop camera shake and reset position"""
	if camera_node:
		is_shaking_camera = false
		camera_node.offset = original_camera_offset
		print("Camera shake stopped")
