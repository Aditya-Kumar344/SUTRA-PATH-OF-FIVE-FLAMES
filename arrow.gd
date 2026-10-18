extends RigidBody2D

@export var arrow_damage: int = 25
@export var lifetime: float = 5.0  # Arrow disappears after 5 seconds

var has_hit: bool = false
var arrow_velocity: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_area: Area2D = $HitArea
@onready var hit_area_collision: CollisionShape2D = $HitArea/CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready():
	# Connect signals
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	
	# Set up physics
	gravity_scale = 0  # Arrows fly straight initially
	lock_rotation = false  # Allow arrow to rotate when it hits
	
	# Play idle animation
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
	
	# Start lifetime timer
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_expired)

func setup_arrow(velocity: Vector2, damage: int):
	"""Called by player to set up the arrow's movement and damage"""
	arrow_velocity = velocity
	arrow_damage = damage
	
	# Set initial velocity
	linear_velocity = arrow_velocity
	
	# Rotate arrow to face movement direction
	if velocity.x != 0:
		rotation = atan2(velocity.y, velocity.x)
	
	# Flip sprite if moving left
	if velocity.x < 0:
		animated_sprite.scale.x = -abs(animated_sprite.scale.x)
	else:
		animated_sprite.scale.x = abs(animated_sprite.scale.x)

func _on_hit_area_body_entered(body: Node2D):
	"""Handle when arrow hits something"""
	if has_hit:
		return
	
	# Check if it's an enemy
	if body.is_in_group("Enemy"):
		# Deal damage to enemy
		if body.has_method("take_damage"):
			body.take_damage(arrow_damage)
		
		# Destroy arrow immediately
		_destroy_arrow()
		
	# Check if it's a wall or solid object
	elif body.is_in_group("Wall") or body.is_in_group("Ground") or body.has_method("is_solid"):
		# Destroy arrow immediately
		_destroy_arrow()
	
	# Check if it's the player (shouldn't hit player, but just in case)
	elif body.is_in_group("Player"):
		# Ignore player collision
		return

func _on_screen_exited():
	"""Handle when arrow goes off screen"""
	_destroy_arrow()

func _on_lifetime_expired():
	"""Handle when arrow's lifetime expires"""
	_destroy_arrow()

func _destroy_arrow():
	"""Safely destroy the arrow"""
	if has_hit:
		return
		
	has_hit = true
	
	if is_inside_tree():
		queue_free()

# Optional: Handle physics collisions for more complex behavior
func _on_body_entered(body: Node2D):
	"""Alternative collision detection using RigidBody2D collision"""
	if has_hit:
		return
	
	# This would be connected to the RigidBody2D's body_entered signal
	# if you enable contact monitoring
	_on_hit_area_body_entered(body)

func _integrate_forces(state: PhysicsDirectBodyState2D):
	"""Custom physics integration for special arrow behavior"""
	# You can add custom physics behavior here if needed
	# For example, making arrows stick into surfaces more realistically
	
	if has_hit and gravity_scale > 0:
		# Arrow has hit and is falling - you could add drag or other effects
		state.linear_velocity.x *= 0.95  # Air resistance
