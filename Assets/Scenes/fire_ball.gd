extends Area2D

@export var speed: float = 800.0
@export var lifetime: float = 5.0  # How long fireball stays alive
var direction: Vector2 = Vector2.RIGHT
var damage: int = 25
var knockback_force: float = 600.0
var knockback_duration: float = 0.5
var has_hit_player: bool = false

@onready var fireball_sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var life_timer: Timer = $LifeTimer

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Set up lifetime timer
	if life_timer:
		life_timer.wait_time = lifetime
		life_timer.timeout.connect(_on_lifetime_expired)
		life_timer.start()
	
	# Set rotation based on direction
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func setup_fireball(dir: Vector2, dmg: int, knockback: float, kb_duration: float):
	"""Setup fireball with direction, damage and knockback values"""
	direction = dir.normalized()
	damage = dmg
	knockback_force = knockback
	knockback_duration = kb_duration
	
	# Update rotation
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	# Move fireball in direction
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if has_hit_player:
		return
	
	# Check if it's the player
	if body.is_in_group("Player"):
		has_hit_player = true
		
		# Deal damage to player
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Apply knockback to player
		if body.has_method("apply_knockback"):
			var knockback_vector = direction * knockback_force
			body.apply_knockback(knockback_vector, knockback_duration)
			print("Fireball hit player! Damage: ", damage, " Knockback: ", knockback_force)
		
		# Destroy fireball after hitting player
		destroy_fireball()
	
	# Check if it hit a wall or solid object
	elif body.is_in_group("Wall") or body.has_method("_on_fireball_hit"):
		print("Fireball hit wall/obstacle")
		destroy_fireball()

func _on_lifetime_expired():
	"""Called when fireball reaches end of lifetime"""
	print("Fireball lifetime expired")
	destroy_fireball()

func destroy_fireball():
	"""Destroy the fireball"""
	# Disable collision to prevent multiple hits
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# You could add explosion effect here if desired
	add_hit_effect()
	
	# Remove from scene
	queue_free()

# Optional: Add visual effects when fireball is destroyed
func add_hit_effect():
	"""Add visual effect when fireball hits something"""
	# You can add particles, flash, or other effects here
	# For example:
	# var explosion = preload("res://effects/Explosion.tscn").instantiate()
	# get_tree().current_scene.add_child(explosion)
	# explosion.global_position = global_position
	pass
