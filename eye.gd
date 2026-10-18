extends CharacterBody2D

@export var walk_speed: float = 400.0 # Increased from 200.0
@export var detection_range: float = 800.0 # Increased from 400.0
@export var attack_range: float = 100.0
@export var attack_interval: float = 0.9 # Half of 1.8 seconds (twice the speed)
@export var attack_damage: int = 20 # Increased from 15
@export var knockback_force: float = 300.0
@export var knockback_duration: float = 0.3
@export var health_drop_amount: int = 25

var player: CharacterBody2D = null
var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false
var health: int = 100
var has_damaged: bool = false
var knockback_velocity: float = 0.0
var knockback_timer: float = 0.0

# Nodes
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AnimatedSprite2D/AttackArea
@onready var cooldown: Timer = $AttackCooldown
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	add_to_group("Enemy")
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D
	
	cooldown.wait_time = attack_interval
	cooldown.one_shot = true
	cooldown.timeout.connect(_on_attack_cooldown_timeout)
	
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	sprite.animation_finished.connect(_on_animation_finished)
	anim_player.animation_finished.connect(_on_animplayer_finished)

	# --- Potential Fix for "Damaged at Start" ---
	# Ensure these are reset to their default states at the start
	is_hurt = false
	knockback_velocity = 0.0
	knockback_timer = 0.0
	# --- End Potential Fix ---

func _physics_process(delta: float) -> void:
	if player == null or is_dead:
		return
	
	# Handle knockback
	if is_hurt and knockback_timer > 0:
		knockback_timer -= delta
		velocity.x = knockback_velocity
		move_and_slide()
		if knockback_timer <= 0:
			is_hurt = false
			knockback_velocity = 0
		return
	
	var dist: float = global_position.distance_to(player.global_position)
	var direction: float = sign(player.global_position.x - global_position.x)
	
	# Update sprite facing
	if direction > 0:
		sprite.scale.x = abs(sprite.scale.x) # Face right
	elif direction < 0:
		sprite.scale.x = -abs(sprite.scale.x) # Face left
	
	# Don't move if attacking or hurt
	if is_attacking or is_hurt:
		velocity.x = 0
		move_and_slide()
		return
	
	# Attack logic
	if dist <= attack_range:
		velocity.x = 0
		if cooldown.is_stopped():
			start_attack()
	# Chase player (only X direction - horizontal following)
	elif dist <= detection_range:
		velocity.x = direction * walk_speed
		sprite.play("fly")
	else:
		velocity.x = 0
		sprite.play("fly")
	
	move_and_slide()

func start_attack():
	"""Initiate attack sequence"""
	is_attacking = true
	has_damaged = false
	sprite.play("attack")
	# Ensure anim_player "eye_attack" animation duration matches "attack" sprite animation
	anim_player.play("eye_attack") 
	cooldown.start()

# Functions called by AnimationPlayer keyframes
func enable_attack_collision():
	"""Called by AnimationPlayer when attack should hit"""
	attack_area.monitoring = true
	print("Enemy attack collision enabled")

func disable_attack_collision():
	"""Called by AnimationPlayer when attack ends"""
	attack_area.call_deferred("set_monitoring", false)
	print("Enemy attack collision disabled")

func _on_animation_finished() -> void:
	if sprite.animation == "attack":
		is_attacking = false
	elif sprite.animation == "hit":
		is_hurt = false
	elif sprite.animation == "die":
		# Death animation finished, give health to player and remove from scene
		give_health_to_player()
		queue_free()

func _on_animplayer_finished(anim_name: StringName) -> void:
	"""AnimationPlayer finished - cleanup"""
	if anim_name == "eye_attack":
		attack_area.call_deferred("set_monitoring", false)
		has_damaged = false

func _on_attack_cooldown_timeout() -> void:
	"""Attack cooldown finished"""
	pass

func _on_attack_area_body_entered(body: Node2D) -> void:
	if has_damaged or not attack_area.monitoring:
		return
	
	if body.is_in_group("Player"):
		print("Enemy hit player for ", attack_damage)
		has_damaged = true
		body.take_damage(attack_damage)
		attack_area.call_deferred("set_monitoring", false)

func take_damage(amount: int) -> void:
	if health <= 0 or is_dead:
		return
	
	health -= amount
	print("Enemy took ", amount, " damage! Health: ", health)
	
	if health <= 0:
		die()
	else:
		# Play hurt animation and apply knockback
		play_hurt_animation()

func play_hurt_animation():
	"""Play hurt animation with knockback effect"""
	is_hurt = true
	is_attacking = false # Cancel any ongoing attack
	
	# Calculate knockback direction (away from player)
	if player != null:
		var direction_to_player = sign(player.global_position.x - global_position.x)
		knockback_velocity = -direction_to_player * knockback_force
	else:
		# Default knockback direction
		knockback_velocity = -sprite.scale.x * knockback_force
	
	knockback_timer = knockback_duration
	sprite.play("hit")
	
	# Stop any ongoing attack
	attack_area.call_deferred("set_monitoring", false)
	has_damaged = false

func give_health_to_player() -> void:
	"""Give health to the player when this enemy dies, but only if player is alive"""
	if player == null:
		print("Warning: No player reference found")
		return
	
	# Check if player is alive (health > 0)
	var player_health = 0
	if player.has_method("get_health"):
		player_health = player.get_health()
	elif "health" in player:
		player_health = player.health
	else:
		print("Warning: Cannot check player health")
		return
	
	# Only give health if player is alive
	if player_health > 0:
		if player.has_method("heal"):
			player.heal(health_drop_amount)
			print("Enemy gave ", health_drop_amount, " health to player")
		elif player.has_method("add_health"):
			player.add_health(health_drop_amount)
			print("Enemy gave ", health_drop_amount, " health to player")
		else:
			print("Warning: Player doesn't have heal() or add_health() method")
	else:
		print("Player is dead, no health given")

func die() -> void:
	"""Handle death - play animation and cleanup"""
	is_dead = true
	is_attacking = false
	is_hurt = false
	
	sprite.play("die")
	set_physics_process(false)
	
	# Use call_deferred for collision changes during signal callbacks
	$CollisionShape2D.call_deferred("set_disabled", true)
	attack_area.call_deferred("set_monitoring", false)
	
	# Note: queue_free() and health giving is called in _on_animation_finished() 
	# when the death animation completes
