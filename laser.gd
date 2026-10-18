extends Area2D

@export var speed: float = 800.0
@export var lifetime: float = 5.0  # How long laser stays alive

var direction: Vector2 = Vector2.RIGHT
var damage: int = 25
var knockback_force: float = 600.0
var knockback_duration: float = 0.5
var has_hit_player: bool = false

@onready var laser_sprite: AnimatedSprite2D = $LaserSprite
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
	
	# Play laser animation
	if laser_sprite:
		laser_sprite.play("default")
	
	# Set rotation based on direction
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func setup_laser(dir: Vector2, dmg: int, knockback: float, kb_duration: float):
	"""Setup laser with direction, damage and knockback values"""
	direction = dir.normalized()
	damage = dmg
	knockback_force = knockback
	knockback_duration = kb_duration
	
	# Update rotation
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	# Move laser in direction
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
			print("Laser hit player! Damage: ", damage, " Knockback: ", knockback_force)
		
		# Destroy laser after hitting player
		destroy_laser()
	
	# Check if it hit a wall or solid object
	elif body.is_in_group("Wall") or body.has_method("_on_laser_hit"):
		print("Laser hit wall/obstacle")
		destroy_laser()

func _on_lifetime_expired():
	"""Called when laser reaches end of lifetime"""
	print("Laser lifetime expired")
	destroy_laser()

func destroy_laser():
	"""Destroy the laser"""
	# Disable collision to prevent multiple hits
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# You could add explosion effect here if desired
	
	# Remove from scene
	queue_free()

# Optional: Add visual effects when laser is destroyed
func add_hit_effect():
	"""Add visual effect when laser hits something"""
	# You can add particles, flash, or other effects here
	pass
