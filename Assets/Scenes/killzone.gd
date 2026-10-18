extends Area2D

# Killzone Configuration
@export var damage_amount: int = 999  # Instant kill damage
@export var is_instant_kill: bool = true  # If true, kills instantly regardless of health
@export var knockback_force: float = 500.0  # Force applied before death
@export var knockback_duration: float = 0.2  # Brief knockback before death
@export var respawn_delay: float = 2.0  # Delay before respawning/restarting

# Visual and Audio Effects
@export var death_particle_scene: PackedScene  # Optional death particles
@export var screen_shake_intensity: float = 10.0  # Screen shake on death
@export var screen_shake_duration: float = 0.5

# Killzone Types
enum KillzoneType {
	SPIKES,      # Spikes, thorns, sharp objects
	LAVA,        # Lava, fire, acid
	VOID,        # Bottomless pits, void areas
	CRUSHER,     # Crushing traps, moving platforms
	ELECTRIC,    # Electric barriers, lightning
	POISON,      # Poison gas, toxic water
	CUSTOM       # Custom death type
}

@export var killzone_type: KillzoneType = KillzoneType.VOID
@export var death_message: String = "You died!"  # Custom death message

# Internal variables
var affected_bodies: Array[Node2D] = []
var is_active: bool = true

# Node references
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# @onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

# Optional visual effects (commented out for basic setup)
# @onready var particles: GPUParticles2D = $GPUParticles2D
# @onready var sprite: Sprite2D = $Sprite2D
# @onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set up collision detection
	monitoring = true
	monitorable = false  # Killzones don't need to be detected by others
	
	# Optional: Set up visual effects based on killzone type
	_setup_visual_effects()
	
	print("Killzone initialized: ", killzone_type)

func _setup_visual_effects() -> void:
	"""Set up visual effects based on killzone type"""
	# Commented out for basic setup - uncomment when you add visual nodes
	# if animated_sprite:
	# 	match killzone_type:
	# 		KillzoneType.SPIKES:
	# 			animated_sprite.play("spikes_idle")
	# 		KillzoneType.LAVA:
	# 			animated_sprite.play("lava_bubble")
	# 		KillzoneType.ELECTRIC:
	# 			animated_sprite.play("electric_arc")
	# 		KillzoneType.POISON:
	# 			animated_sprite.play("poison_gas")
	# 		_:
	# 			animated_sprite.play("default")
	# 
	# if particles:
	# 	particles.emitting = true
	pass

func _on_body_entered(body: Node2D) -> void:
	"""Handle when a body enters the killzone"""
	if not is_active:
		return
	
	# Check if it's a player or enemy
	if body.is_in_group("Player"):
		print("Player entered killzone: ", killzone_type)
		_kill_player(body)
	elif body.is_in_group("Enemy"):
		print("Enemy entered killzone: ", killzone_type)
		_kill_enemy(body)
	
	# Add to affected bodies list
	if body not in affected_bodies:
		affected_bodies.append(body)

func _on_body_exited(body: Node2D) -> void:
	"""Handle when a body exits the killzone"""
	if body in affected_bodies:
		affected_bodies.erase(body)

func _kill_player(player: Node2D) -> void:
	"""Kill the player with appropriate effects"""
	if not player.has_method("take_damage") or _is_dead(player):
		return
	
	# Mark as dying to prevent other animations
	_set_dying_state(player, true)
	
	# Stop any ongoing animations/movement immediately
	_stop_player_movement(player)
	
	# Cancel any ongoing knockback or hurt animations
	_cancel_knockback_animations(player)
	
	# Play death effects
	_play_death_effects(player.global_position)
	
	# Apply damage/instant kill
	if is_instant_kill:
		# Force kill by setting health to 1 then applying damage
		if _has_health_property(player):
			_set_health(player, 1)  # Set to 1 so take_damage can kill
		player.take_damage(damage_amount)
	else:
		player.take_damage(damage_amount)
	
	# Force death animation immediately
	_force_death_animation(player)
	
	# Ensure player stops moving and animating after death
	await get_tree().process_frame  # Wait one frame for death to register
	if player and is_instance_valid(player):
		_stop_player_movement(player)
		_force_death_state(player)
	
	# Optional: Show death message
	_show_death_message()

func _kill_enemy(enemy: Node2D) -> void:
	"""Kill an enemy that falls into killzone"""
	if not enemy.has_method("take_damage") or _is_dead(enemy):
		return
	
	# Mark as dying to prevent other animations
	_set_dying_state(enemy, true)
	
	# Stop any ongoing animations/movement immediately
	_stop_enemy_movement(enemy)
	
	# Cancel any ongoing knockback or hurt animations
	_cancel_knockback_animations(enemy)
	
	# Play death effects
	_play_death_effects(enemy.global_position)
	
	# Apply damage/instant kill
	if is_instant_kill:
		# Force kill by setting health to 1 then applying damage
		if _has_health_property(enemy):
			_set_health(enemy, 1)  # Set to 1 so take_damage can kill
		enemy.take_damage(damage_amount)
	else:
		enemy.take_damage(damage_amount)
	
	# Force death animation immediately
	_force_death_animation(enemy)
	
	# Ensure enemy stops moving and animating after death
	await get_tree().process_frame  # Wait one frame for death to register
	if enemy and is_instance_valid(enemy):
		_stop_enemy_movement(enemy)
		_force_death_state(enemy)

func _apply_death_knockback(body: Node2D) -> void:
	"""Apply a brief knockback effect before death"""
	if not body.has_method("play_hurt_animation"):
		return
	
	# Store original knockback values
	var original_knockback_force = 0.0
	var original_knockback_duration = 0.0
	
	# Check and modify knockback properties
	if _has_knockback_force(body):
		original_knockback_force = _get_knockback_force(body)
		_set_knockback_force(body, knockback_force)
	
	if _has_knockback_duration(body):
		original_knockback_duration = _get_knockback_duration(body)
		_set_knockback_duration(body, knockback_duration)
	
	# Trigger hurt animation with knockback
	body.play_hurt_animation()
	
	# Restore original values after a brief delay
	await get_tree().create_timer(knockback_duration + 0.1).timeout
	
	if body and is_instance_valid(body):
		if _has_knockback_force(body):
			_set_knockback_force(body, original_knockback_force)
		if _has_knockback_duration(body):
			_set_knockback_duration(body, original_knockback_duration)

func _play_death_effects(death_position: Vector2) -> void:
	"""Play visual and audio effects at death position"""
	# Play sound effect (commented out for basic setup)
	# if audio_player and audio_player.stream:
	# 	audio_player.play()
	
	# Spawn death particles (commented out for basic setup)
	# if death_particle_scene:
	# 	var particle_instance = death_particle_scene.instantiate()
	# 	get_tree().current_scene.add_child(particle_instance)
	# 	particle_instance.global_position = death_position
	
	# Screen shake effect
	_apply_screen_shake()
	
	# Special effects based on killzone type (commented out for basic setup)
	# match killzone_type:
	# 	KillzoneType.SPIKES:
	# 		_spike_death_effect(death_position)
	# 	KillzoneType.LAVA:
	# 		_lava_death_effect(death_position)
	# 	KillzoneType.ELECTRIC:
	# 		_electric_death_effect(death_position)
	# 	KillzoneType.POISON:
	# 		_poison_death_effect(death_position)

func _spike_death_effect(pos: Vector2) -> void:
	"""Special effect for spike deaths"""
	# Commented out for basic setup
	# if animated_sprite:
	# 	animated_sprite.play("spikes_activate")
	pass

func _lava_death_effect(pos: Vector2) -> void:
	"""Special effect for lava deaths"""
	# Commented out for basic setup
	# if particles:
	# 	particles.emitting = true
	# 	particles.amount = 50
	pass

func _electric_death_effect(pos: Vector2) -> void:
	"""Special effect for electric deaths"""
	# Commented out for basic setup
	# if animated_sprite:
	# 	animated_sprite.play("electric_zap")
	pass

func _poison_death_effect(pos: Vector2) -> void:
	"""Special effect for poison deaths"""
	# Commented out for basic setup
	# if particles:
	# 	particles.emitting = true
	pass

func _apply_screen_shake() -> void:
	"""Apply screen shake effect"""
	# This requires a camera shake system
	# You can implement this by getting the camera and applying shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(screen_shake_intensity, screen_shake_duration)

func _show_death_message() -> void:
	"""Show death message to player"""
	if death_message.length() > 0:
		print("DEATH: ", death_message)
		# You can extend this to show UI message
		# Example: GameManager.show_death_message(death_message)

# Helper functions to safely access properties
func _has_health_property(body: Node2D) -> bool:
	"""Check if body has health property"""
	return "health" in body

func _set_health(body: Node2D, value: int) -> void:
	"""Safely set health property"""
	if _has_health_property(body):
		body.health = value

func _is_dead(body: Node2D) -> bool:
	"""Check if body is dead"""
	if "is_dead" in body:
		return body.is_dead
	return false

func _stop_player_movement(player: Node2D) -> void:
	"""Stop player movement and physics"""
	# Stop velocity
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	
	# Stop any physics movement
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	
	# Stop input processing
	if player.has_method("set_process_input"):
		player.set_process_input(false)
	
	# Stop any timers or tweens
	if player.has_method("stop_all_timers"):
		player.stop_all_timers()

func _stop_enemy_movement(enemy: Node2D) -> void:
	"""Stop enemy movement and AI"""
	# Stop velocity
	if "velocity" in enemy:
		enemy.velocity = Vector2.ZERO
	
	# Stop any physics movement
	if enemy.has_method("set_physics_process"):
		enemy.set_physics_process(false)
	
	# Stop AI processing
	if enemy.has_method("set_process"):
		enemy.set_process(false)

func _set_dying_state(body: Node2D, dying: bool) -> void:
	"""Set the dying state to prevent other animations"""
	if "is_dying" in body:
		body.is_dying = dying
	elif "dying" in body:
		body.dying = dying

func _cancel_knockback_animations(body: Node2D) -> void:
	"""Cancel any ongoing knockback or hurt animations"""
	# Stop hurt animation
	if body.has_method("stop_hurt_animation"):
		body.stop_hurt_animation()
	
	# Reset knockback state
	if "is_hurt" in body:
		body.is_hurt = false
	
	# Stop any knockback timers
	if body.has_method("stop_knockback_timer"):
		body.stop_knockback_timer()
	
	# Cancel any active tweens
	if body.has_method("stop_all_tweens"):
		body.stop_all_tweens()

func _force_death_animation(body: Node2D) -> void:
	"""Force death animation to play immediately"""
	# Try multiple methods to play death animation
	if body.has_method("play_death_animation"):
		body.play_death_animation()
	elif body.has_method("play_animation") and body.has_method("has_animation"):
		if body.has_animation("death"):
			body.play_animation("death")
		elif body.has_animation("die"):
			body.play_animation("die")
	elif body.has_method("set_animation"):
		body.set_animation("death")
	
	# If it has an AnimatedSprite2D, force it directly
	if body.has_node("AnimatedSprite2D"):
		var anim_sprite = body.get_node("AnimatedSprite2D")
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("death"):
			anim_sprite.play("death")
		elif anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("die"):
			anim_sprite.play("die")

func _force_death_state(body: Node2D) -> void:
	"""Force the body into death state"""
	# Set dead flag
	if "is_dead" in body:
		body.is_dead = true
	
	# Clear dying state
	_set_dying_state(body, false)
	
	# Stop all animations first
	if body.has_method("stop_all_animations"):
		body.stop_all_animations()
	
	# Force death animation again
	_force_death_animation(body)
	
	# Make sure collision is disabled
	if body.has_method("set_collision_layer_value"):
		body.set_collision_layer_value(1, false)  # Disable main collision layer
	
	# Disable collision shape if accessible
	if body.has_node("CollisionShape2D"):
		var collision = body.get_node("CollisionShape2D")
		collision.disabled = true

func _has_knockback_force(body: Node2D) -> bool:
	"""Check if body has knockback_force property"""
	return "knockback_force" in body

func _get_knockback_force(body: Node2D) -> float:
	"""Get knockback force value"""
	if _has_knockback_force(body):
		return body.knockback_force
	return 0.0

func _set_knockback_force(body: Node2D, value: float) -> void:
	"""Set knockback force value"""
	if _has_knockback_force(body):
		body.knockback_force = value

func _has_knockback_duration(body: Node2D) -> bool:
	"""Check if body has knockback_duration property"""
	return "knockback_duration" in body

func _get_knockback_duration(body: Node2D) -> float:
	"""Get knockback duration value"""
	if _has_knockback_duration(body):
		return body.knockback_duration
	return 0.0

func _set_knockback_duration(body: Node2D, value: float) -> void:
	"""Set knockback duration value"""
	if _has_knockback_duration(body):
		body.knockback_duration = value

# Public methods for external control
func activate_killzone() -> void:
	"""Activate the killzone"""
	is_active = true
	monitoring = true
	print("Killzone activated")

func deactivate_killzone() -> void:
	"""Deactivate the killzone"""
	is_active = false
	monitoring = false
	print("Killzone deactivated")

func set_damage(new_damage: int) -> void:
	"""Change the damage amount"""
	damage_amount = new_damage
	print("Killzone damage set to: ", damage_amount)

func set_instant_kill(instant: bool) -> void:
	"""Toggle instant kill mode"""
	is_instant_kill = instant
	print("Killzone instant kill: ", instant)

# Utility functions
func get_bodies_in_killzone() -> Array[Node2D]:
	"""Get all bodies currently in the killzone"""
	return affected_bodies.duplicate()

func has_body_type(group_name: String) -> bool:
	"""Check if killzone contains any body from specific group"""
	for body in affected_bodies:
		if body.is_in_group(group_name):
			return true
	return false

func clear_affected_bodies() -> void:
	"""Clear the affected bodies list"""
	affected_bodies.clear()

# Debug functions
func _on_debug_kill_all() -> void:
	"""Debug function to kill all bodies in killzone"""
	for body in affected_bodies:
		if body.is_in_group("Player"):
			_kill_player(body)
		elif body.is_in_group("Enemy"):
			_kill_enemy(body)
