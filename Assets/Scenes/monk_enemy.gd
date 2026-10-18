extends CharacterBody2D

# Enemy Stats
@export var max_health: int = 100
@export var normal_attack_damage: int = 15
@export var special_attack_damage: int = 25
@export var chase_speed: float = 500.0
@export var detection_range: float = 1200.0
@export var attack_range: float = 140.0  # Reduced from 180.0
@export var knockback_force: float = 300.0
@export var knockback_duration: float = 0.3
@export var hurt_invincibility_duration: float = 0.6

# Collectible settings
@export var collectible_scene: PackedScene
@export var next_scene_path: String = "res://scenes/NextLevel.tscn"

# Attack pattern settings
@export var min_normal_attacks: int = 1
@export var max_normal_attacks: int = 3
@export var attack_cooldown: float = 0.15

# Attack timing settings (base durations at 1x speed)
@export var base_normal_attack_duration: float = 0.7  # Base normal attack duration
@export var base_special_attack_duration: float = 1.3  # Base special attack duration

# Animation speed multipliers
@export var idle_speed: float = 1.2
@export var run_speed: float = 1.4
@export var attack_speed: float = 1.3  # Changed to 1.3x
@export var hurt_speed: float = 1.5

# Enemy States
enum State {
	IDLE,
	CHASE,
	ATTACK,
	SPECIAL_ATTACK,
	HURT,
	DEAD
}

var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var health: int
var is_invincible: bool = false
var has_damaged: bool = false
var facing_direction: int = 1
var player_target: Node2D = null
var is_dead: bool = false
var was_moving: bool = false
var can_attack: bool = true

# Attack pattern tracking
var normal_attacks_done: int = 0
var normal_attacks_needed: int = 0

# Attack duration tracking
var current_attack_duration: float = 0.0
var attack_duration_timer: float = 0.0

# Timers
var invincibility_timer: float = 0.0
var knockback_timer: float = 0.0
var attack_cooldown_timer: float = 0.0

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO

# Node References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var normal_attack_area: Area2D = $AnimatedSprite2D/Area2D
@onready var special_attack_area: Area2D = $AnimatedSprite2D/Area2D2
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	add_to_group("Enemy")
	health = max_health
	
	# Find player from global group
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player_target = players[0]
	
	# Initialize attack areas as disabled
	normal_attack_area.monitoring = false
	special_attack_area.monitoring = false
	
	# Set initial attack pattern
	_reset_attack_pattern()
	
	# Connect signals
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animation_player.animation_finished.connect(_on_animation_player_finished)
	normal_attack_area.body_entered.connect(_on_normal_attack_area_entered)
	normal_attack_area.body_exited.connect(_on_normal_attack_area_exited)
	special_attack_area.body_entered.connect(_on_special_attack_area_entered)
	special_attack_area.body_exited.connect(_on_special_attack_area_exited)
	
	change_state(State.IDLE)

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
	
	# Handle attack duration timer (fallback safety)
	if attack_duration_timer > 0:
		attack_duration_timer -= delta
		if attack_duration_timer <= 0:
			_finish_current_action()
	
	# Handle invincibility with faster flashing
	if invincibility_timer > 0:
		invincibility_timer -= delta
		# Faster flash effect
		animated_sprite.modulate.a = 0.4 + 0.6 * sin(invincibility_timer * 20)
		
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
	
	# Update facing direction only when needed
	if direction != 0 and facing_direction != direction:
		facing_direction = direction
		_update_facing_direction()
	
	# State machine
	match current_state:
		State.IDLE:
			_handle_idle_state(distance)
		State.CHASE:
			_handle_chase_state(distance, direction)
		State.ATTACK, State.SPECIAL_ATTACK:
			_handle_attack_states()
		State.HURT:
			_handle_hurt_state()

func _handle_idle_state(distance: float) -> void:
	var is_moving = abs(velocity.x) > 10.0
	
	# Only update animation if movement state changed
	if was_moving != is_moving:
		was_moving = is_moving
		if not is_moving:
			velocity.x = 0
	
	# Check if player is within detection range
	if distance <= detection_range:
		if distance <= attack_range and can_attack:
			_decide_attack_type()
		else:
			change_state(State.CHASE)

func _handle_chase_state(distance: float, direction: float) -> void:
	# Check if player is too far away
	if distance > detection_range * 1.5:
		change_state(State.IDLE)
		return
	
	# Check if close enough to attack
	if distance <= attack_range and can_attack:
		_decide_attack_type()
		return
	
	# Move towards player
	velocity.x = direction * chase_speed
	was_moving = true

func _handle_attack_states() -> void:
	# Stop movement during attacks
	velocity.x = 0
	was_moving = false

func _handle_hurt_state() -> void:
	# Hurt state transitions are handled by knockback timer and animation callbacks
	was_moving = false

func _decide_attack_type() -> void:
	if not can_attack:
		print("❌ Cannot attack - cooldown active")
		return
	
	print("🎯 DECIDING ATTACK TYPE")
	print("  - Normal attacks done: ", normal_attacks_done, "/", normal_attacks_needed)
	print("  - Player distance: ", global_position.distance_to(player_target.global_position))
	
	# Calculate actual attack durations based on speed multiplier
	if normal_attacks_done >= normal_attacks_needed:
		# Special attack
		current_attack_duration = base_special_attack_duration / attack_speed
		change_state(State.SPECIAL_ATTACK)
		_reset_attack_pattern()
		print("🔥 Starting special attack at ", attack_speed, "x speed (duration: ", current_attack_duration, "s)")
	else:
		# Normal attack
		current_attack_duration = base_normal_attack_duration / attack_speed
		change_state(State.ATTACK)
		normal_attacks_done += 1
		print("⚔️ Starting normal attack (", normal_attacks_done, "/", normal_attacks_needed, ") at ", attack_speed, "x speed (duration: ", current_attack_duration, "s)")
	
	# Set fallback timer (safety net)
	attack_duration_timer = current_attack_duration + 0.1  # Small buffer
	
	# Start attack cooldown
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	print("  - Attack cooldown started: ", attack_cooldown, "s")

func _reset_attack_pattern() -> void:
	normal_attacks_done = 0
	normal_attacks_needed = randi_range(min_normal_attacks, max_normal_attacks)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	# Exit current state cleanup
	match current_state:
		State.ATTACK:
			normal_attack_area.monitoring = false
			# Stop timing animation if running
			if animation_player.is_playing() and animation_player.current_animation == "normal_attack_timing":
				animation_player.stop()
		State.SPECIAL_ATTACK:
			special_attack_area.monitoring = false
			# Stop timing animation if running
			if animation_player.is_playing() and animation_player.current_animation == "special_attack_timing":
				animation_player.stop()
	
	# Store previous state
	previous_state = current_state
	current_state = new_state
	
	# Reset damage flag for new attacks
	if new_state == State.ATTACK or new_state == State.SPECIAL_ATTACK:
		has_damaged = false
		print("Starting new attack - reset has_damaged")
	
	# Handle state-specific setup
	match new_state:
		State.IDLE:
			if previous_state != State.IDLE:
				animated_sprite.play("idle")
				animated_sprite.speed_scale = idle_speed
		State.CHASE:
			if previous_state != State.CHASE:
				animated_sprite.play("run")
				animated_sprite.speed_scale = run_speed
		State.ATTACK:
			animated_sprite.play("attack")
			animated_sprite.speed_scale = attack_speed
			# Set attack animation to not loop
			var sprite_frames = animated_sprite.sprite_frames
			if sprite_frames and sprite_frames.has_animation("attack"):
				sprite_frames.set_animation_loop("attack", false)
			
			# Start the timing animation at the same speed for synchronization
			animation_player.play("normal_attack_timing")
			animation_player.speed_scale = attack_speed
			print("Normal attack started - Visual: ", attack_speed, "x, Timing: ", attack_speed, "x")
		State.SPECIAL_ATTACK:
			animated_sprite.play("sp_attack")
			animated_sprite.speed_scale = attack_speed
			# Set special attack animation to not loop
			var sprite_frames = animated_sprite.sprite_frames
			if sprite_frames and sprite_frames.has_animation("sp_attack"):
				sprite_frames.set_animation_loop("sp_attack", false)
			
			# Start the timing animation at the same speed for synchronization
			animation_player.play("special_attack_timing")
			animation_player.speed_scale = attack_speed
			print("Special attack started - Visual: ", attack_speed, "x, Timing: ", attack_speed, "x")
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

# Animation callbacks - called by AnimationPlayer keyframes in timing animations
func enable_normal_attack() -> void:
	print("🟢 ENABLE_NORMAL_ATTACK CALLED")
	print("  - Current state: ", State.keys()[current_state])
	print("  - Animation Player: ", animation_player.current_animation)
	
	if current_state == State.ATTACK:
		has_damaged = false  # Reset damage flag when attack becomes active
		normal_attack_area.monitoring = true
		print("  - ✅ Normal attack enabled! has_damaged reset to false, monitoring = true")
	else:
		print("  - ❌ Not in ATTACK state, ignoring enable call")

func disable_normal_attack() -> void:
	print("🔴 DISABLE_NORMAL_ATTACK CALLED")
	print("  - Final has_damaged state: ", has_damaged)
	normal_attack_area.monitoring = false
	print("  - Normal attack disabled, monitoring = false")

func enable_special_attack() -> void:
	if current_state == State.SPECIAL_ATTACK:
		has_damaged = false  # Reset damage flag when attack becomes active
		special_attack_area.monitoring = true
		print("Special attack collision enabled by AnimationPlayer - has_damaged reset to false")

func disable_special_attack() -> void:
	special_attack_area.monitoring = false
	print("Special attack collision disabled by AnimationPlayer - has_damaged: ", has_damaged)

# Fallback function for safety timer
func _finish_current_action() -> void:
	"""Called when attack duration timer expires as fallback"""
	var was_attack_state = current_state in [State.ATTACK, State.SPECIAL_ATTACK]
	
	if was_attack_state:
		print("Attack action completed by fallback timer")
		
		# Make sure attack areas are disabled
		normal_attack_area.monitoring = false
		special_attack_area.monitoring = false
		
		# Stop any running timing animations
		if animation_player.is_playing():
			animation_player.stop()
		
		# Reset animation player speed
		animation_player.speed_scale = 1.0
		
		# Go back to appropriate state after attack
		if player_target and global_position.distance_to(player_target.global_position) <= detection_range:
			change_state(State.CHASE)
		else:
			change_state(State.IDLE)

# Animation finished callbacks
func _on_animation_finished() -> void:
	print("AnimatedSprite2D animation finished: ", animated_sprite.animation)
	
	match animated_sprite.animation:
		"attack", "sp_attack":
			# Visual attack animations finished - pause on last frame until timing completes
			print("Visual attack animation finished, pausing on last frame...")
			animated_sprite.pause()  # Pause the visual animation
		"hurt":
			if health > 0:
				if player_target and global_position.distance_to(player_target.global_position) <= detection_range:
					change_state(State.CHASE)
				else:
					change_state(State.IDLE)
		"die":
			_handle_death()

func _on_animation_player_finished(anim_name: StringName) -> void:
	print("AnimationPlayer finished: ", anim_name, " at ", animation_player.speed_scale, "x speed")
	
	match anim_name:
		"normal_attack_timing":
			# Normal attack timing finished - ensure areas are disabled
			normal_attack_area.monitoring = false
			animation_player.speed_scale = 1.0
			attack_duration_timer = 0.0  # Cancel fallback timer
			print("Normal attack timing completed, final has_damaged: ", has_damaged)
			
			# Resume animation system for state transition
			animated_sprite.play()
			
			if player_target and global_position.distance_to(player_target.global_position) <= detection_range:
				change_state(State.CHASE)
			else:
				change_state(State.IDLE)
				
		"special_attack_timing":
			# Special attack timing finished - ensure areas are disabled
			special_attack_area.monitoring = false
			animation_player.speed_scale = 1.0
			attack_duration_timer = 0.0  # Cancel fallback timer
			print("Special attack timing completed, final has_damaged: ", has_damaged)
			
			# Resume animation system for state transition
			animated_sprite.play()
			
			if player_target and global_position.distance_to(player_target.global_position) <= detection_range:
				change_state(State.CHASE)
			else:
				change_state(State.IDLE)

# Attack collision callbacks with improved damage detection
func _on_normal_attack_area_entered(body: Node2D) -> void:
	print("🔥 NORMAL ATTACK COLLISION DETECTED 🔥")
	print("  - Body: ", body.name)
	print("  - Current State: ", State.keys()[current_state])
	print("  - Area Monitoring: ", normal_attack_area.monitoring)
	print("  - Has Damaged: ", has_damaged)
	print("  - Body in Player group: ", body.is_in_group("Player"))
	print("  - Animation Player current: ", animation_player.current_animation)
	print("  - Animation Player playing: ", animation_player.is_playing())
	
	if current_state != State.ATTACK:
		print("❌ Not in ATTACK state, ignoring collision")
		return
		
	if not normal_attack_area.monitoring:
		print("❌ Normal attack area not monitoring, ignoring collision")
		return
		
	if has_damaged:
		print("❌ Already damaged this attack, ignoring collision")
		return
	
	if body.is_in_group("Player"):
		has_damaged = true
		if body.has_method("take_damage"):
			body.take_damage(normal_attack_damage)
			print("✅ Normal attack hit player for ", normal_attack_damage, " damage - has_damaged set to true")
		else:
			print("❌ Player doesn't have take_damage method!")
	else:
		print("❌ Body not in Player group: ", body.name)

func _on_special_attack_area_entered(body: Node2D) -> void:
	print("Special attack area entered - State: ", current_state, ", Monitoring: ", special_attack_area.monitoring, ", Has_damaged: ", has_damaged)
	
	if current_state != State.SPECIAL_ATTACK:
		print("Not in SPECIAL_ATTACK state, ignoring collision")
		return
		
	if not special_attack_area.monitoring:
		print("Special attack area not monitoring, ignoring collision")
		return
		
	if has_damaged:
		print("Already damaged this attack, ignoring collision")
		return
	
	if body.is_in_group("Player"):
		has_damaged = true
		body.take_damage(special_attack_damage)
		print("✅ Special attack hit player for ", special_attack_damage, " damage - has_damaged set to true")
	else:
		print("Body not in Player group: ", body.name)

# Area exit callbacks - allow for re-entry damage during same attack
func _on_normal_attack_area_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and current_state == State.ATTACK:
		# Reset damage flag when player exits, allowing for re-entry damage
		has_damaged = false
		print("Player exited normal attack area - has_damaged reset to false")

func _on_special_attack_area_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and current_state == State.SPECIAL_ATTACK:
		# Reset damage flag when player exits, allowing for re-entry damage
		has_damaged = false
		print("Player exited special attack area - has_damaged reset to false")

# Damage system
func take_damage(amount: int) -> void:
	if health <= 0 or is_invincible or is_dead:
		return
	
	health -= amount
	print("Boss took ", amount, " damage! Health: ", health, "/", max_health)
	
	if health <= 0:
		change_state(State.DEAD)
	else:
		# Apply knockback away from player
		var knockback_direction = Vector2.ZERO
		if player_target:
			knockback_direction = (global_position - player_target.global_position).normalized()
		else:
			knockback_direction = Vector2(-facing_direction, 0)
		
		knockback_velocity = knockback_direction * knockback_force
		knockback_timer = knockback_duration
		
		# Start invincibility
		is_invincible = true
		invincibility_timer = hurt_invincibility_duration
		
		change_state(State.HURT)

func _handle_death() -> void:
	print("Boss defeated!")
	_spawn_collectible()
	
	await get_tree().create_timer(1.5).timeout
	queue_free()

func _spawn_collectible() -> void:
	if collectible_scene == null:
		print("No collectible scene assigned")
		return
	
	var collectible_instance = collectible_scene.instantiate()
	collectible_instance.global_position = global_position
	
	if collectible_instance.has_method("set_next_scene"):
		collectible_instance.set_next_scene(next_scene_path)
	
	get_parent().add_child(collectible_instance)
	print("Collectible spawned at boss position")

# Utility functions
func get_health_percentage() -> float:
	return float(health) / float(max_health)

func is_player_in_range() -> bool:
	if not player_target:
		return false
	return global_position.distance_to(player_target.global_position) <= attack_range
