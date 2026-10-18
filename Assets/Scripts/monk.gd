extends CharacterBody2D

const SPEED = 800.0
const JUMP_VELOCITY = -600.0

@export var max_health: int = 100
@export var attack_damage: int = 25
@export var knockback_force: float = 400.0
@export var knockback_duration: float = 0.5
@export var hurt_invincibility_duration: float = 1.0

# New arrow shooting system variables
@export var arrow_enabled: bool = false  # Initially disabled
@export var arrow_scene: PackedScene = preload("res://Assets/Scenes/arrow.tscn")  # Update path
@export var arrow_speed: float = 600.0
@export var arrow_damage: int = 30  # Separate damage value for arrows (can be different from melee)
@export var arrow_max_count: int = 2  # Can shoot 2 arrows before cooldown
@export var arrow_cooldown: float = 10.0  # Cooldown in seconds after shooting 2 arrows
@export var shoot_duration: float = 0.8  # Duration of shoot animation

# NEW: Defend skill variables
@export var defend_enabled: bool = false  # Initially disabled
@export var defend_duration: float = 1.0  # How long the defend state lasts
@export var defend_knockback_bonus: float = 20.0  # Extra knockback when defending successfully
@export var defend_cooldown: float = 5.0  # Cooldown between defend uses

# Attack timing variables - BALANCED TIMING
@export var normal_attack_duration: float = 1.1  # Good balance - not too fast, not too slow

# Pause system variables
@export var pause_menu_scene: PackedScene = preload("res://Assets/Scenes/pause.tscn")
var pause_menu_instance: Control = null

var is_rolling = false
var is_attacking = false
var is_shooting = false
var is_defending = false  # NEW: Defend state
var is_hurt = false
var is_dead = false
var is_invincible = false
var has_damaged = false
var health: int = 100
var score = 0
var knockback_velocity: float = 0.0
var knockback_timer: float = 0.0
var invincibility_timer: float = 0.0

# New arrow shooting variables
var arrows_shot: int = 0
var arrow_cooldown_timer: float = 0.0
var shoot_timer: float = 0.0  # Timer for arrow spawn timing

# NEW: Defend skill variables
var defend_timer: float = 0.0
var defend_cooldown_timer: float = 0.0

# Achievement indicator persistence
var achievement_indicator_persistent: bool = false

# NEW: Second achievement indicator persistence
var achievement_indicator2_persistent: bool = false

# NEW: Third achievement indicator persistence
var achievement_indicator3_persistent: bool = false

@onready var animated: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_idle = $CollisionIdle
@onready var collision_roll = $CollisionRoll
@onready var ray_head_check = $RayCast2D
@onready var attack_area = $AnimatedSprite2D/AttackArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_label: Label = $CanvasLayer/Label
@onready var achievement_indicator: AnimatedSprite2D = $CanvasLayer/AnimatedSprite2D2

# NEW: Second achievement indicator
@onready var achievement_indicator2: AnimatedSprite2D = $CanvasLayer/AnimatedSprite2D

# NEW: Third achievement indicator (add this as another AnimatedSprite2D child of CanvasLayer)
@onready var achievement_indicator3: AnimatedSprite2D = $CanvasLayer/AnimatedSprite2D3

# Arrow spawn point (add this as a Marker2D child of AnimatedSprite2D)
@onready var arrow_spawn_point = $AnimatedSprite2D/ArrowSpawnPoint

func _set_collision_state(rolling: bool) -> void:
	collision_idle.set_deferred("disabled", rolling)
	collision_roll.set_deferred("disabled", not rolling)

func _ready():
	add_to_group("Player")
	_set_collision_state(false)
	attack_area.monitoring = false
	
	# Load saved skills state
	_load_arrow_skill_state()
	_load_defend_skill_state()  # NEW
	
	# Create pause menu instance and add to player's CanvasLayer
	if pause_menu_scene:
		pause_menu_instance = pause_menu_scene.instantiate()
		# Add to player's CanvasLayer so it follows the camera
		$CanvasLayer.add_child(pause_menu_instance)
		pause_menu_instance.visible = false
		# Set it to be on top of everything
		pause_menu_instance.z_index = 1000
	
	health = max_health
	
	animated.animation_finished.connect(_on_animation_finished)
	anim_player.animation_finished.connect(_on_animplayer_finished)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	# IMPORTANT: Set AnimationPlayer speeds to match our desired durations
	_setup_animation_speeds()
	
	if interaction_label:
		interaction_label.visible = false
	if achievement_indicator:
		achievement_indicator.visible = false
	
	# NEW: Initialize second achievement indicator
	if achievement_indicator2:
		achievement_indicator2.visible = false
		
	# NEW: Initialize third achievement indicator
	if achievement_indicator3:
		achievement_indicator3.visible = false
		
	# Check if achievement indicators should be persistent
	_check_achievement_persistence()
	_check_achievement2_persistence()  # NEW
	_check_achievement3_persistence()  # NEW

func _load_arrow_skill_state():
	"""Load arrow skill state from save file"""
	if FileAccess.file_exists("user://arrow_skill_data.save"):
		var file = FileAccess.open("user://arrow_skill_data.save", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var data = json.data
				if data.has("arrow_enabled"):
					arrow_enabled = data["arrow_enabled"]

# NEW: Load defend skill state
func _load_defend_skill_state():
	"""Load defend skill state from save file"""
	if FileAccess.file_exists("user://defend_skill_data.save"):
		var file = FileAccess.open("user://defend_skill_data.save", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var data = json.data
				if data.has("defend_enabled"):
					defend_enabled = data["defend_enabled"]

func _save_arrow_skill_state():
	"""Save arrow skill state to file"""
	var save_data = {
		"arrow_enabled": arrow_enabled
	}
	var file = FileAccess.open("user://arrow_skill_data.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

# NEW: Save defend skill state
func _save_defend_skill_state():
	"""Save defend skill state to file"""
	var save_data = {
		"defend_enabled": defend_enabled
	}
	var file = FileAccess.open("user://defend_skill_data.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func _check_achievement_persistence():
	"""Check if achievement indicator should be shown from previous level"""
	# Check if we have a GameManager autoload
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("is_achievement_unlocked") and game_manager.is_achievement_unlocked():
			achievement_indicator_persistent = true
			if achievement_indicator:
				achievement_indicator.visible = true
			return
	
	# Check saved file as fallback
	if FileAccess.file_exists("user://achievement_data.save"):
		var file = FileAccess.open("user://achievement_data.save", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var data = json.data
				if data.has("achievement_unlocked") and data["achievement_unlocked"]:
					achievement_indicator_persistent = true
					if achievement_indicator:
						achievement_indicator.visible = true

# NEW: Check if second achievement indicator should be persistent
func _check_achievement2_persistence():
	"""Check if second achievement indicator should be shown from previous level"""
	# Check if we have a GameManager autoload
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("is_achievement2_unlocked") and game_manager.is_achievement2_unlocked():
			achievement_indicator2_persistent = true
			if achievement_indicator2:
				achievement_indicator2.visible = true
			return
	
	# Check saved file as fallback
	if FileAccess.file_exists("user://achievement2_data.save"):
		var file = FileAccess.open("user://achievement2_data.save", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var data = json.data
				if data.has("achievement2_unlocked") and data["achievement2_unlocked"]:
					achievement_indicator2_persistent = true
					if achievement_indicator2:
						achievement_indicator2.visible = true

# NEW: Check if third achievement indicator should be persistent
func _check_achievement3_persistence():
	"""Check if third achievement indicator should be shown from previous level"""
	# Check if we have a GameManager autoload
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("is_achievement3_unlocked") and game_manager.is_achievement3_unlocked():
			achievement_indicator3_persistent = true
			if achievement_indicator3:
				achievement_indicator3.visible = true
			return
	
	# Check saved file as fallback
	if FileAccess.file_exists("user://achievement3_data.save"):
		var file = FileAccess.open("user://achievement3_data.save", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var data = json.data
				if data.has("achievement3_unlocked") and data["achievement3_unlocked"]:
					achievement_indicator3_persistent = true
					if achievement_indicator3:
						achievement_indicator3.visible = true

func _setup_animation_speeds():
	"""Set AnimationPlayer animation speeds to match our desired attack durations"""
	# For normal attack
	if anim_player.has_animation("player attack"):
		anim_player.get_animation("player attack").length = normal_attack_duration
	
	# For shoot animation (if it exists)
	if anim_player.has_animation("player_shoot"):
		anim_player.get_animation("player_shoot").length = shoot_duration
	
	# NEW: For defend animation (if it exists)
	if anim_player.has_animation("player_defend"):
		anim_player.get_animation("player_defend").length = defend_duration

func _input(event: InputEvent) -> void:
	# Handle pause input (ESC key or custom pause action)
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	"""Toggle pause state"""
	if pause_menu_instance:
		if get_tree().paused:
			# Resume game
			pause_menu_instance.visible = false
			get_tree().paused = false
		else:
			# Pause game
			pause_menu_instance.visible = true
			get_tree().paused = true

func _physics_process(delta: float) -> void:
	# Don't process physics when paused
	if get_tree().paused:
		return
		
	if is_dead:
		return
	
	# Handle arrow cooldown
	if arrow_cooldown_timer > 0:
		arrow_cooldown_timer -= delta
		if arrow_cooldown_timer <= 0:
			arrows_shot = 0  # Reset arrow count when cooldown ends
	
	# NEW: Handle defend cooldown
	if defend_cooldown_timer > 0:
		defend_cooldown_timer -= delta
	
	# NEW: Handle defend timer
	if is_defending and defend_timer > 0:
		defend_timer -= delta
		if defend_timer <= 0:
			_finish_defend()
	
	# Handle shoot timer for arrow spawning
	if is_shooting and shoot_timer > 0:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_arrow()  # Spawn arrow after 0.7 seconds
	
	# Handle invincibility timer
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			animated.modulate.a = 1.0
		else:
			# Flashing effect during invincibility
			animated.modulate.a = 0.5 + 0.5 * sin(invincibility_timer * 20)
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle knockback - FIXED: Proper knockback handling
	if is_hurt and knockback_timer > 0:
		knockback_timer -= delta
		velocity.x = knockback_velocity
		
		# FIXED: Only allow very limited movement during knockback
		if knockback_timer <= 0:
			is_hurt = false
			knockback_velocity = 0
		
		move_and_slide()
		return  # Don't process other input during knockback
	
	var direction := Input.get_axis("ui_left", "ui_right")
	
	if direction > 0:
		animated.scale.x = abs(animated.scale.x)
	elif direction < 0:
		animated.scale.x = -abs(animated.scale.x)
	
	# NEW: DEFEND HANDLING - Must be before other actions
	if Input.is_action_just_pressed("defend"):
		if not defend_enabled:
			# Show brief message that skill is locked
			pass
		elif defend_enabled and is_on_floor() and not is_attacking and not is_rolling and not is_hurt and not is_shooting and not is_defending and can_defend():
			start_defend()
	
	# ARROW SHOOTING HANDLING - FIXED
	if Input.is_action_just_pressed("shoot"):
		if not arrow_enabled:
			# Show brief message that skill is locked
			pass
		elif arrow_enabled and is_on_floor() and not is_attacking and not is_rolling and not is_hurt and not is_shooting and not is_defending and can_shoot_arrow():
			start_shoot()
	
	# ATTACK HANDLING
	if Input.is_action_just_pressed("attack") and is_on_floor() and not is_attacking and not is_rolling and not is_hurt and not is_shooting and not is_defending:
		start_attack()
	
	# ROLL HANDLING
	if Input.is_action_just_pressed("roll") and is_on_floor() and not is_rolling and not is_attacking and not is_hurt and not is_shooting and not is_defending:
		is_rolling = true
		animated.play("roll")
		_set_collision_state(true)
	
	if is_rolling:
		if animated.animation == "roll" and not animated.is_playing():
			if ray_head_check.is_colliding():
				animated.play("roll")
			else:
				is_rolling = false
				_set_collision_state(false)
	
	# ANIMATION STATE
	if not is_rolling and not is_attacking and not is_hurt and not is_shooting and not is_defending:
		if not is_on_floor():
			if velocity.y < 0:
				animated.play("jump_up")
			else:
				animated.play("jump_down")
		elif direction == 0:
			animated.play("idle")
		else:
			animated.play("move")
	
	# JUMP
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_rolling and not is_attacking and not is_hurt and not is_shooting and not is_defending:
		velocity.y = JUMP_VELOCITY
	
	# MOVEMENT - FIXED: Allow normal movement unless in hurt state
	if direction and not is_hurt:
		# Reduce movement during attacks/shooting/defending but don't prevent it completely
		if is_attacking or is_shooting:
			velocity.x = direction * SPEED * 0.7  # 70% speed during actions
		elif is_defending:
			velocity.x = direction * SPEED * 0.3  # 30% speed during defend (slower)
		else:
			velocity.x = direction * SPEED
	elif not is_hurt:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()

func start_attack():
	"""Normal attack - balanced timing with proper weight"""
	is_attacking = true
	has_damaged = false
	animated.play("attack")
	anim_player.play("player attack")

func start_shoot():
	"""Start arrow shooting with 0.7 second delay"""
	is_shooting = true
	shoot_timer = 0.7  # Set timer for 0.7 seconds
	
	# Play shoot animation
	animated.play("shoot")  # Make sure you have this animation in your AnimatedSprite2D
	
	# Check if AnimationPlayer has the shoot animation
	if anim_player.has_animation("player_shoot"):
		anim_player.play("player_shoot")

# NEW: Start defend
func start_defend():
	"""Start defending - blocks attacks from front"""
	is_defending = true
	defend_timer = defend_duration
	defend_cooldown_timer = defend_cooldown
	
	# Play defend animation
	animated.play("defend")  # Make sure you have this animation in your AnimatedSprite2D
	
	# Check if AnimationPlayer has the defend animation
	if anim_player.has_animation("player_defend"):
		anim_player.play("player_defend")
	
	print("Player is now defending!")

# NEW: Finish defend
func _finish_defend():
	"""Called when defend duration ends"""
	if is_defending:
		is_defending = false
		defend_timer = 0.0
		print("Defend ended")

func can_shoot_arrow() -> bool:
	"""Check if player can shoot an arrow"""
	return arrows_shot < arrow_max_count and arrow_cooldown_timer <= 0

# NEW: Check if player can defend
func can_defend() -> bool:
	"""Check if player can defend"""
	return defend_cooldown_timer <= 0

func shoot_arrow():
	"""Called after 0.7 second delay to actually spawn the arrow"""
	# Check if we're still in shooting state (might have been interrupted)
	if not is_shooting:
		return
	
	if not arrow_scene:
		print("ERROR: Arrow scene not assigned!")
		return
	
	if not arrow_spawn_point:
		print("ERROR: Arrow spawn point not found!")
		return
	
	# Create arrow instance
	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)
	
	# Set arrow position
	arrow.global_position = arrow_spawn_point.global_position
	
	# Set arrow z-index to 1 (appears above most other objects)
	arrow.z_index = 1
	
	# Set arrow direction and speed
	var direction = 1 if animated.scale.x > 0 else -1
	arrow.setup_arrow(Vector2(direction * arrow_speed, 0), arrow_damage)
	
	# Increment shot count
	arrows_shot += 1
	
	# Start cooldown if max arrows reached
	if arrows_shot >= arrow_max_count:
		arrow_cooldown_timer = arrow_cooldown

# Functions called by AnimationPlayer keyframes
func enable_attack_collision():
	"""Called by AnimationPlayer when normal attack should start hitting"""
	attack_area.monitoring = true

func disable_attack_collision():
	"""Called by AnimationPlayer when normal attack should stop hitting"""
	attack_area.monitoring = false

func _on_animation_finished() -> void:
	"""Handle sprite animation finished"""
	if animated.animation == "hurt":
		# Don't change is_hurt here - let knockback timer handle it
		pass
	elif animated.animation == "die":
		handle_game_over()
	elif animated.animation == "shoot":
		# FIXED: Reset shooting state when sprite animation finishes
		# This handles cases where AnimationPlayer doesn't exist or finish
		if is_shooting:
			is_shooting = false
			shoot_timer = 0.0
	elif animated.animation == "defend":  # NEW
		# Reset defending state when sprite animation finishes
		if is_defending:
			_finish_defend()

func _on_animplayer_finished(anim_name: StringName) -> void:
	"""Handle AnimationPlayer animation finished"""
	# Only process if we're still in the corresponding state (not interrupted by hurt/death)
	if anim_name == "player attack" and is_attacking:
		_finish_normal_attack()
	elif anim_name == "player_shoot" and is_shooting:
		_finish_shoot()
	elif anim_name == "player_defend" and is_defending:  # NEW
		_finish_defend()

func _finish_normal_attack():
	"""Called when normal attack AnimationPlayer finishes"""
	if is_attacking:
		is_attacking = false
		attack_area.set_deferred("monitoring", false)
		has_damaged = false

func _finish_shoot():
	"""Called when shoot AnimationPlayer finishes"""
	if is_shooting:
		is_shooting = false
		shoot_timer = 0.0  # Reset shoot timer

func _on_attack_area_body_entered(body: Node2D) -> void:
	if has_damaged or not attack_area.monitoring:
		return
		
	if body.is_in_group("Enemy"):
		has_damaged = true
		body.take_damage(attack_damage)

# MODIFIED: Enhanced take_damage with defend mechanics
func take_damage(amount: int) -> void:
	if health <= 0 or is_dead or is_invincible:
		return
	
	# NEW: Check if defending and attack is from front
	if is_defending:
		# Get all enemies to find the attacker
		var enemies = get_tree().get_nodes_in_group("Enemy")
		var blocked_attack = false
		
		for enemy in enemies:
			# Check if enemy is in front of player
			var enemy_direction = sign(enemy.global_position.x - global_position.x)
			var player_facing = sign(animated.scale.x)
			
			# If enemy is in front of where player is facing, block the attack
			if enemy_direction == player_facing:
				blocked_attack = true
				print("ATTACK BLOCKED! Enemy was in front.")
				
				# Apply enhanced knockback to the enemy (reflect the attack)
				if enemy.has_method("apply_knockback"):
					var knockback_direction = (enemy.global_position - global_position).normalized()
					var enhanced_knockback = knockback_force + defend_knockback_bonus
					enemy.apply_knockback(knockback_direction * enhanced_knockback, knockback_duration)
					print("Applied enhanced knockback of ", enhanced_knockback, " to enemy!")
				
				# Play defend animation effect (you can add particles, sound, etc.)
				animated.play("defend")
				
				return  # Exit without taking damage
		
		# If no enemy was blocked, take reduced damage
		if not blocked_attack:
			amount = int(amount * 0.5)  # 50% damage reduction for side/back attacks while defending
			print("Partial block - damage reduced to: ", amount)
	
	# Normal damage processing
	health -= amount
	
	if health <= 0:
		die()
	else:
		play_hurt_animation()
		is_invincible = true
		invincibility_timer = hurt_invincibility_duration

# FIXED: New apply_knockback function that properly handles different knockback distances
func apply_knockback(knockback_vector: Vector2, duration: float) -> void:
	"""Apply specific knockback force and duration (called by enemies)"""
	if is_dead:
		return
	
	# NEW: Reduce knockback when defending
	if is_defending:
		knockback_vector *= 0.3  # 70% knockback reduction when defending
		duration *= 0.5  # Shorter knockback duration when defending
		print("Defending - knockback reduced!")
	
	# FIXED: Always apply knockback even if already in knockback
	# This allows different attacks to override with their own knockback values
	knockback_velocity = knockback_vector.x
	knockback_timer = duration
	
	# FIXED: Ensure hurt state is set for proper animation
	if not is_hurt:
		play_hurt_animation()

func play_hurt_animation():
	"""FIXED: Properly handle hurt animation and state changes"""
	# Set hurt state
	is_hurt = true
	
	# Cancel all current actions
	is_attacking = false
	is_rolling = false
	is_shooting = false  # This will prevent arrow from spawning if hurt during shoot animation
	is_defending = false  # NEW: Cancel defend when hurt
	shoot_timer = 0.0  # Reset shoot timer
	defend_timer = 0.0  # NEW: Reset defend timer
	
	# STOP AnimationPlayer when hurt during attacks/shooting/defending
	if anim_player.is_playing():
		anim_player.stop()
	
	_set_collision_state(false)
	
	# FIXED: Don't calculate knockback here - use the values from apply_knockback
	# Only calculate if knockback wasn't already set by apply_knockback
	if knockback_timer <= 0:
		var enemies = get_tree().get_nodes_in_group("Enemy")
		var knockback_direction = 1.0
		
		if enemies.size() > 0:
			var closest_enemy = null
			var closest_distance = INF
			
			for enemy in enemies:
				var distance = global_position.distance_to(enemy.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_enemy = enemy
			
			if closest_enemy:
				knockback_direction = -sign(closest_enemy.global_position.x - global_position.x)
		else:
			knockback_direction = sign(animated.scale.x)
		
		knockback_velocity = knockback_direction * knockback_force
		knockback_timer = knockback_duration
	
	# Play hurt animation
	animated.play("hurt")
	
	# Disable attack areas
	attack_area.set_deferred("monitoring", false)
	has_damaged = false

func heal(amount: int) -> void:
	health = min(health + amount, max_health)

func die() -> void:
	is_dead = true
	is_attacking = false
	is_hurt = false
	is_rolling = false
	is_shooting = false
	is_defending = false  # NEW
	shoot_timer = 0.0
	defend_timer = 0.0  # NEW
	
	# STOP AnimationPlayer when dying
	if anim_player.is_playing():
		anim_player.stop()
	
	animated.play("die")
	set_physics_process(false)
	
	collision_idle.set_deferred("disabled", true)
	collision_roll.set_deferred("disabled", true)
	attack_area.set_deferred("monitoring", false)

func handle_game_over():
	# Clean up pause menu before transitioning
	if pause_menu_instance:
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	get_tree().paused = false
	TransitionManager.restart_current_scene(1.0, 1.0)

func handle_game_over_to_menu():
	# Clean up pause menu before transitioning
	if pause_menu_instance:
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	get_tree().paused = false
	await get_tree().create_timer(1.0).timeout
	TransitionManager.fade_to_scene("res://scenes/MainMenu.tscn", 1.5, 1.0)

func complete_level():
	# Clean up pause menu before transitioning
	if pause_menu_instance:
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	get_tree().paused = false
	TransitionManager.fade_to_scene("res://scenes/Level2.tscn", 1.0, 1.0)

func get_health_percentage() -> float:
	return float(health) / float(max_health)

func can_take_damage() -> bool:
	return not is_invincible and not is_dead

func show_interaction_label(text: String):
	if interaction_label:
		interaction_label.text = text
		interaction_label.visible = true

func hide_interaction_label():
	if interaction_label:
		interaction_label.visible = false

func show_achievement_indicator():
	"""Show achievement indicator with 1 second delay, then make it persistent"""
	if achievement_indicator:
		# Wait 1 second before showing
		await get_tree().create_timer(1.0).timeout
		
		# Make sure we're still valid (scene might have changed)
		if not is_inside_tree() or is_dead:
			return
		
		# Show the indicator
		achievement_indicator.visible = true
		achievement_indicator.modulate.a = 1.0
		achievement_indicator_persistent = true
		
		# Play animation if available
		if achievement_indicator.sprite_frames and achievement_indicator.sprite_frames.has_animation("achievement"):
			achievement_indicator.play("achievement")
		
		# Make it persistent across scenes
		_save_achievement_persistence()

func hide_achievement_indicator():
	if achievement_indicator:
		achievement_indicator.visible = false
		if achievement_indicator.is_playing():
			achievement_indicator.stop()

func show_achievement_indicator2():
	"""Show second achievement indicator immediately (no delay) and make it persistent"""
	if achievement_indicator2:
		# Show the indicator immediately (no delay)
		achievement_indicator2.visible = true
		achievement_indicator2.modulate.a = 1.0
		achievement_indicator2_persistent = true
		
		# Play animation if available
		achievement_indicator2.play("default")
		
		# Make it persistent across scenes immediately
		_save_achievement2_persistence()
		
		print("Achievement indicator 2 shown immediately!")

# Also add this helper function if it doesn't exist:
func show_achievement_indicator2_immediate():
	"""Alternative name for immediate display"""
	show_achievement_indicator2()

func hide_achievement_indicator2():
	"""Hide second achievement indicator"""
	if achievement_indicator2:
		achievement_indicator2.visible = false
		if achievement_indicator2.is_playing():
			achievement_indicator2.stop()

# Add this function after show_achievement_indicator2():
func show_achievement_indicator3():
	"""Show third achievement indicator immediately (no delay) and make it persistent"""
	if achievement_indicator3:
		# Show the indicator immediately (no delay)
		achievement_indicator3.visible = true
		achievement_indicator3.modulate.a = 1.0
		achievement_indicator3_persistent = true
		
		# Play animation if available
		achievement_indicator3.play("default")
		
		# Make it persistent across scenes immediately
		_save_achievement3_persistence()
		
		print("Achievement indicator 3 shown immediately!")

# Add this function after show_achievement_indicator2_immediate():
# Also add this helper function if it doesn't exist:
func show_achievement_indicator3_immediate():
	"""Alternative name for immediate display"""
	show_achievement_indicator3()

# Add this function after hide_achievement_indicator2():
func hide_achievement_indicator3():
	"""Hide third achievement indicator"""
	if achievement_indicator3:
		achievement_indicator3.visible = false
		if achievement_indicator3.is_playing():
			achievement_indicator3.stop()

func _save_achievement_persistence():
	"""Save achievement status so it persists across scenes"""
	# Method 1: Use GameManager if available
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("unlock_achievement"):
			game_manager.unlock_achievement()
			return
	
	# Method 2: Save to file as fallback
	var save_data = {
		"achievement_unlocked": true
	}
	var file = FileAccess.open("user://achievement_data.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

# NEW: Save second achievement persistence
func _save_achievement2_persistence():
	"""Save second achievement status so it persists across scenes"""
	# Method 1: Use GameManager if available
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("unlock_achievement2"):
			game_manager.unlock_achievement2()
			return
	
	# Method 2: Save to file as fallback
	var save_data = {
		"achievement2_unlocked": true
	}
	var file = FileAccess.open("user://achievement2_data.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

# NEW: Save third achievement persistence
func _save_achievement3_persistence():
	"""Save third achievement status so it persists across scenes"""
	# Method 1: Use GameManager if available
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.has_method("unlock_achievement3"):
			game_manager.unlock_achievement3()
			return
	
	# Method 2: Save to file as fallback
	var save_data = {
		"achievement3_unlocked": true
	}
	var file = FileAccess.open("user://achievement3_data.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

# NEW FUNCTION: Enable defend skill (called by collectible)
func enable_defend():
	"""Enable defend skill after collecting the defend collectible"""
	defend_enabled = true
	print("DEFEND UNLOCKED! Press X to defend against frontal attacks!")
	
	# Save the defend skill state immediately
	_save_defend_skill_state()
	
	# Show notification to player
	if interaction_label:
		interaction_label.visible = true
		
		# Hide the notification after 3 seconds
		await get_tree().create_timer(3.0).timeout
		if interaction_label:
			interaction_label.visible = false

# NEW FUNCTION: Enable arrow shooting (called by collectible)
func enable_arrows():
	"""Enable arrow shooting after collecting the first collectible"""
	arrow_enabled = true
	print("ARROWS UNLOCKED! Press L to shoot arrows!")
	
	# Save the arrow skill state immediately
	_save_arrow_skill_state()
	
	# Show notification to player
	if interaction_label:
		interaction_label.visible = true
		
		# Hide the notification after 3 seconds
		await get_tree().create_timer(3.0).timeout
		if interaction_label:
			interaction_label.visible = false

# Function to check if arrows are ready
func are_arrows_ready() -> bool:
	return arrow_enabled and can_shoot_arrow()

# Function to get arrow cooldown remaining
func get_arrow_cooldown_remaining() -> float:
	return max(0, arrow_cooldown_timer)

# Function to get arrows remaining
func get_arrows_remaining() -> int:
	if arrow_cooldown_timer > 0:
		return 0
	return arrow_max_count - arrows_shot

# NEW: Defend skill utility functions
func is_defend_ready() -> bool:
	return defend_enabled and can_defend()

func get_defend_cooldown_remaining() -> float:
	return max(0, defend_cooldown_timer)

# NEW: Achievement indicator utility functions
func is_achievement_indicator_visible() -> bool:
	return achievement_indicator and achievement_indicator.visible

func is_achievement_indicator2_visible() -> bool:
	return achievement_indicator2 and achievement_indicator2.visible

# Update the existing is_achievement_indicator2_visible() function or add after it:
func is_achievement_indicator3_visible() -> bool:
	return achievement_indicator3 and achievement_indicator3.visible

# Update the existing get_achievement_status() function to include the third achievement:
func get_achievement_status() -> Dictionary:
	"""Get status of all achievement indicators"""
	return {
		"achievement1_visible": is_achievement_indicator_visible(),
		"achievement2_visible": is_achievement_indicator2_visible(),
		"achievement3_visible": is_achievement_indicator3_visible(),
		"achievement1_persistent": achievement_indicator_persistent,
		"achievement2_persistent": achievement_indicator2_persistent,
		"achievement3_persistent": achievement_indicator3_persistent
	}

# Optional: Additional pause system functions
func pause_game():
	"""Pause the game (called from other scripts)"""
	if pause_menu_instance and not get_tree().paused:
		pause_menu_instance.visible = true
		get_tree().paused = true

func unpause_game():
	"""Unpause the game (called from other scripts)"""
	if pause_menu_instance and get_tree().paused:
		pause_menu_instance.visible = false
		get_tree().paused = false

# Clean up function called when player is removed from scene
func _exit_tree():
	if pause_menu_instance:
		pause_menu_instance.queue_free()
		pause_menu_instance = null
	get_tree().paused = false
