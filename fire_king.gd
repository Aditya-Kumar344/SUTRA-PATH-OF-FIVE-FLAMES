extends CharacterBody2D

# Enemy Stats
@export var max_health: int = 200
@export var attack1_damage: int = 12
@export var attack2_damage: int = 15
@export var attack3_damage: int = 25
@export var attack4_damage: int = 18
@export var chase_speed: float = 350.0
@export var detection_range: float = 1200.0
@export var attack_range: float = 180.0

# Different knockback forces for each attack
@export var attack1_knockback: float = 250.0  # Light fire attack
@export var attack2_knockback: float = 400.0  # Medium fire burst
@export var attack3_knockback: float = 600.0  # Heavy fire blast
@export var attack4_knockback: float = 450.0  # Fire wave attack
@export var defend_knockback_reduction: float = 0.4  # 60% knockback reduction when defending
@export var knockback_duration: float = 0.35
@export var hurt_invincibility_duration: float = 0.7

# Collectible settings
@export var collectible_scene: PackedScene
@export var next_scene_path: String = "res://scenes/NextLevel.tscn"

# Attack timing settings (1.5x speed for attacks, normal for defend)
@export var attack1_duration: float = 0.67  # 1.0 / 1.5 for 1.5x speed
@export var attack2_duration: float = 0.6   # 0.9 / 1.5 for 1.5x speed
@export var attack3_duration: float = 0.8   # 1.2 / 1.5 for 1.5x speed
@export var attack4_duration: float = 0.67  # 1.0 / 1.5 for 1.5x speed
@export var defend_duration: float = 0.9    # Keep normal speed for defend
@export var attack_cooldown: float = 0.4

# Enhanced defend system
@export var defend_health_threshold: float = 0.5  # Defend more when health < 50%
@export var defend_after_damage_chance: float = 0.35  # 35% chance to defend after taking damage
@export var defend_base_chance: float = 0.12  # Increased base defend chance
@export var defend_low_health_chance: float = 0.28  # Higher chance when low health
@export var min_attacks_before_defend: int = 2  # Minimum attacks before defend is allowed

# Animation speed multipliers
@export var idle_speed: float = 1.0
@export var walk_speed: float = 1.1
@export var attack_speed: float = 1.5  # 1.5x speed for attacks
@export var defend_speed: float = 1.0  # Normal speed for defend
@export var hurt_speed: float = 1.3

# Enemy States
enum State {
	IDLE,
	WALK,
	ATTACK1,
	ATTACK2,
	ATTACK3,
	ATTACK4,
	DEFEND,
	HIT,
	DIE
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
var just_took_damage: bool = false
var attacks_since_defend: int = 0

# Attack rotation system - ensures each attack repeats only after 3 others
var available_attacks: Array[int] = []
var used_attacks: Array[int] = []
var last_attacks: Array[int] = []  # Track last 3 attacks

# Timers
var invincibility_timer: float = 0.0
var knockback_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var action_duration_timer: float = 0.0

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

# Attack movement system - consistent violent movement for attacks only
var attack_movement_velocity: Vector2 = Vector2.ZERO
var attack_movement_timer: float = 0.0
var is_attack_moving: bool = false
@export var base_attack_movement_force: float = 400.0  # Base forward movement during attacks

# Node References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack1_area: Area2D = $AnimatedSprite2D/attack1
@onready var attack2_area: Area2D = $AnimatedSprite2D/attack2
@onready var attack3_area: Area2D = $AnimatedSprite2D/attack3
@onready var attack4_area: Area2D = $AnimatedSprite2D/attack4
@onready var defend_area: Area2D = $AnimatedSprite2D/defend
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	add_to_group("Enemy")
	health = max_health
	_initialize_attack_rotation()
	
	# Find player from global group
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_target = players[0]
	
	# Initialize all attack areas as disabled
	attack1_area.monitoring = false
	attack2_area.monitoring = false
	attack3_area.monitoring = false
	attack4_area.monitoring = false
	defend_area.monitoring = false
	
	# Connect signals
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animation_player.animation_finished.connect(_on_animation_player_finished)
	attack1_area.body_entered.connect(_on_attack1_area_entered)
	attack2_area.body_entered.connect(_on_attack2_area_entered)
	attack3_area.body_entered.connect(_on_attack3_area_entered)
	attack4_area.body_entered.connect(_on_attack4_area_entered)
	
	change_state(State.IDLE)

func _initialize_attack_rotation():
	"""Initialize the attack rotation system"""
	available_attacks = [1, 2, 3, 4]
	used_attacks = []
	last_attacks = []

func _physics_process(delta: float) -> void:
	if current_state == State.DIE or player_target == null or is_dead:
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
	elif is_attack_moving and current_state != State.DEFEND:
		# Apply attack movement during attacks only (not during defend)
		velocity.x = attack_movement_velocity.x
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
	
	# Handle attack movement
	if attack_movement_timer > 0:
		attack_movement_timer -= delta
		if attack_movement_timer <= 0:
			attack_movement_velocity = Vector2.ZERO
			is_attack_moving = false
	
	# Handle invincibility with flashing effect
	if invincibility_timer > 0:
		invincibility_timer -= delta
		animated_sprite.modulate.a = 0.4 + 0.6 * sin(invincibility_timer * 12)
		
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
		State.WALK:
			_handle_walk_state(distance, direction)
		State.ATTACK1, State.ATTACK2, State.ATTACK3, State.ATTACK4, State.DEFEND:
			_handle_action_states()
		State.HIT:
			_handle_hit_state()

func _handle_idle_state(distance: float) -> void:
	velocity.x = 0
	
	# Check if player is within detection range
	if distance <= detection_range:
		if distance <= attack_range and can_attack:
			_decide_action()
		else:
			change_state(State.WALK)

func _handle_walk_state(distance: float, direction: float) -> void:
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
	# Attack movement is handled in physics process for attacks only
	# Set velocity to 0 if not performing attack movement or if defending
	if not is_attack_moving or current_state == State.DEFEND:
		velocity.x = 0

func _handle_hit_state() -> void:
	# Hit state is handled by knockback timer and animation callbacks
	pass

func _get_next_attack() -> int:
	"""Get next attack ensuring each attack repeats only after 3 others"""
	# If we have available attacks, pick from them
	if available_attacks.size() > 0:
		var attack_choice = available_attacks[randi() % available_attacks.size()]
		
		# Move attack from available to used
		available_attacks.erase(attack_choice)
		used_attacks.append(attack_choice)
		
		# Track last attacks for rotation
		last_attacks.append(attack_choice)
		if last_attacks.size() > 3:
			last_attacks.pop_front()
		
		print("Selected attack ", attack_choice, " - Available: ", available_attacks, " Used: ", used_attacks)
		return attack_choice
	
	# If no available attacks, reset the system
	if used_attacks.size() > 0:
		available_attacks = used_attacks.duplicate()
		used_attacks.clear()
		return _get_next_attack()
	
	# Fallback - shouldn't happen
	return 1

func _decide_action() -> void:
	if not can_attack:
		return
	
	# Enhanced defend decision
	var should_defend = attacks_since_defend >= min_attacks_before_defend and _should_defend()
	
	if should_defend:
		change_state(State.DEFEND)
		action_duration_timer = defend_duration
		attacks_since_defend = 0
		print("Fire enemy is defending strategically! (After ", attacks_since_defend, " attacks)")
	else:
		# Choose next attack using rotation system
		var attack_choice = _get_next_attack()
		attacks_since_defend += 1
		
		match attack_choice:
			1:
				change_state(State.ATTACK1)
				action_duration_timer = attack1_duration
				print("Fire Attack 1 chosen (attacks since defend: ", attacks_since_defend, ")")
			2:
				change_state(State.ATTACK2)
				action_duration_timer = attack2_duration
				print("Fire Attack 2 chosen (attacks since defend: ", attacks_since_defend, ")")
			3:
				change_state(State.ATTACK3)
				action_duration_timer = attack3_duration
				print("Fire Attack 3 chosen (attacks since defend: ", attacks_since_defend, ")")
			4:
				change_state(State.ATTACK4)
				action_duration_timer = attack4_duration
				print("Fire Attack 4 chosen (attacks since defend: ", attacks_since_defend, ")")
	
	# Start action cooldown
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	just_took_damage = false

func _should_defend() -> bool:
	"""Enhanced defend logic with higher rates"""
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
	
	var should_defend = randf() < defend_chance
	if should_defend:
		print("Fire enemy chose to defend (chance was ", defend_chance, ")")
	
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
		State.ATTACK4:
			attack4_area.monitoring = false
		State.DEFEND:
			is_defending = false
			defend_area.monitoring = false
	
	# Store previous state
	previous_state = current_state
	current_state = new_state
	has_damaged = false
	
	# Enter new state
	match new_state:
		State.IDLE:
			animated_sprite.play("idle")
			animated_sprite.speed_scale = idle_speed
		State.WALK:
			animated_sprite.play("walk")
			animated_sprite.speed_scale = walk_speed
		State.ATTACK1:
			animated_sprite.play("attack1")
			animated_sprite.speed_scale = attack_speed  # 1.5x speed
			animation_player.play("attack1_fire")
			animation_player.speed_scale = attack_speed  # Sync with sprite speed
			_start_attack_movement()
		State.ATTACK2:
			animated_sprite.play("attack2")
			animated_sprite.speed_scale = attack_speed  # 1.5x speed
			animation_player.play("attack2_fire")
			animation_player.speed_scale = attack_speed  # Sync with sprite speed
			_start_attack_movement()
		State.ATTACK3:
			animated_sprite.play("attack3")
			animated_sprite.speed_scale = attack_speed  # 1.5x speed
			animation_player.play("attack3_fire")
			animation_player.speed_scale = attack_speed  # Sync with sprite speed
			_start_attack_movement()
		State.ATTACK4:
			animated_sprite.play("attack4")
			animated_sprite.speed_scale = attack_speed  # 1.5x speed
			animation_player.play("attack4_fire")
			animation_player.speed_scale = attack_speed  # Sync with sprite speed
			_start_attack_movement()
		State.DEFEND:
			animated_sprite.play("defend")
			animated_sprite.speed_scale = defend_speed  # 1.0 normal speed
			animation_player.play("defend_fire")
			animation_player.speed_scale = defend_speed  # Sync with sprite speed
			is_defending = true
			defend_area.monitoring = true
			# No movement during defend - movement system will handle this
		State.HIT:
			animated_sprite.play("hit")
			animated_sprite.speed_scale = hurt_speed
		State.DIE:
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

func enable_attack4() -> void:
	if current_state == State.ATTACK4:
		attack4_area.monitoring = true

func disable_attack4() -> void:
	attack4_area.monitoring = false

func enable_defend() -> void:
	if current_state == State.DEFEND:
		defend_area.monitoring = true

func disable_defend() -> void:
	defend_area.monitoring = false

func _start_attack_movement() -> void:
	"""Start consistent violent movement for attacks only (not defend)"""
	if player_target and current_state != State.DEFEND:
		# Always move towards player direction with consistent force
		var direction_to_player = sign(player_target.global_position.x - global_position.x)
		attack_movement_velocity = Vector2(direction_to_player * base_attack_movement_force, 0)
		attack_movement_timer = 0.4  # Slightly longer for more dramatic effect
		is_attack_moving = true
		print("Violent movement started: ", base_attack_movement_force, " force towards player")

func _finish_current_action() -> void:
	"""Called when action duration timer expires"""
	var was_action_state = current_state in [State.ATTACK1, State.ATTACK2, State.ATTACK3, State.ATTACK4, State.DEFEND]
	
	if was_action_state:
		# Go back to appropriate state after action
		if player_target and global_position.distance_to(player_target.global_position) <= detection_range:
			change_state(State.WALK)
		else:
			change_state(State.IDLE)

# Animation finished callbacks
func _on_animation_finished() -> void:
	match animated_sprite.animation:
		"hit":
			if health > 0:
				if player_target and global_position.distance_to(player_target.global_position) <= detection_range:
					change_state(State.WALK)
				else:
					change_state(State.IDLE)
		"die":
			_handle_death()

func _on_animation_player_finished(anim_name: StringName) -> void:
	match anim_name:
		"attack1_fire":
			attack1_area.monitoring = false
			has_damaged = false
		"attack2_fire":
			attack2_area.monitoring = false
			has_damaged = false
		"attack3_fire":
			attack3_area.monitoring = false
			has_damaged = false
		"attack4_fire":
			attack4_area.monitoring = false
			has_damaged = false
		"defend_fire":
			is_defending = false
			defend_area.monitoring = false

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

func _on_attack4_area_entered(body: Node2D) -> void:
	if has_damaged or not attack4_area.monitoring or current_state != State.ATTACK4:
		return
	
	if body.is_in_group("Player"):
		has_damaged = true
		body.take_damage(attack4_damage)
		_apply_knockback_to_player(body, attack4_knockback)

func _apply_knockback_to_player(player_body: Node2D, knockback_strength: float):
	"""Apply specific knockback force to player based on attack type"""
	if player_body.has_method("apply_knockback"):
		var knockback_direction = (player_body.global_position - global_position).normalized()
		player_body.apply_knockback(knockback_direction * knockback_strength, knockback_duration)
		print("Applied ", knockback_strength, " fire knockback to player")

# Enhanced damage system with defend mechanics
func take_damage(amount: int) -> void:
	if health <= 0 or is_invincible or is_dead:
		return
	
	print("Fire enemy got hit! Original damage: ", amount)
	
	# Reduce damage if defending
	if is_defending:
		amount = int(amount * 0.25)  # 75% damage reduction when defending
		print("Defending! Damage reduced to: ", amount)
	
	health -= amount
	just_took_damage = true
	print("Fire enemy health after damage: ", health, "/", max_health)
	
	if health <= 0:
		change_state(State.DIE)
	else:
		# Calculate knockback direction
		var knockback_direction = Vector2.ZERO
		if player_target:
			knockback_direction = (global_position - player_target.global_position).normalized()
		else:
			knockback_direction = Vector2(-facing_direction, 0)
		
		# Apply knockback with reduction if defending
		var knockback_force = 350.0
		if is_defending:
			knockback_force *= defend_knockback_reduction
			print("Defending: Knockback reduced to ", knockback_force)
		
		knockback_velocity = knockback_direction * knockback_force
		knockback_timer = knockback_duration
		
		# Start invincibility
		is_invincible = true
		invincibility_timer = hurt_invincibility_duration
		
		# Only change to hit state if not defending
		if not is_defending:
			change_state(State.HIT)

# Death and collectible handling
func _handle_death() -> void:
	# Spawn collectible at enemy position
	_spawn_collectible()
	
	# Remove enemy after delay
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _spawn_collectible() -> void:
	if collectible_scene == null:
		print("Warning: No collectible scene assigned to fire enemy!")
		return
	
	# Instantiate the collectible
	var collectible_instance = collectible_scene.instantiate()
	
	# Set its position to the enemy's position
	collectible_instance.global_position = global_position
	
	# Set the next scene path if the collectible has the function
	if collectible_instance.has_method("set_next_scene"):
		collectible_instance.set_next_scene(next_scene_path)
	
	# Set special properties for fire enemy collectible
	if collectible_instance.has_method("set_unlocks_fire_skill"):
		collectible_instance.set_unlocks_fire_skill(true)
	
	# Add to the same parent as the enemy
	get_parent().add_child(collectible_instance)
	
	print("Fire collectible spawned at enemy death location!")

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
		State.WALK: return "WALK"
		State.ATTACK1: return "ATTACK1"
		State.ATTACK2: return "ATTACK2"
		State.ATTACK3: return "ATTACK3"
		State.ATTACK4: return "ATTACK4"
		State.DEFEND: return "DEFEND"
		State.HIT: return "HIT"
		State.DIE: return "DIE"
		_: return "UNKNOWN"
