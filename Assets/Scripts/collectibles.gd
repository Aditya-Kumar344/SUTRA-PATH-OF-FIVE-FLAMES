extends Area2D

# Collectible settings
@export var next_scene_path: String = "res://Assets/Scenes/first_flame.tscn"
@export var collection_key: String = "collect"  # Input map action for F key
@export var float_amplitude: float = 10.0
@export var float_speed: float = 3.0
@export var rotate_speed: float = 2.0
@export var unlocks_arrow_skill: bool = true  # Does this collectible unlock arrow skill?

# Internal variables
var player_in_range: bool = false
var original_position: Vector2
var time_elapsed: float = 0.0
var collected: bool = false

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	body_entered.connect(_on_player_entered)
	body_exited.connect(_on_player_exited)
	
	original_position = global_position
	add_to_group("Collectible")
	
	if animated_sprite:
		animated_sprite.play("idle")

func _process(delta: float):
	if collected:
		return
		
	time_elapsed += delta
	
	# Floating animation
	var float_offset = sin(time_elapsed * float_speed) * float_amplitude
	global_position.y = original_position.y + float_offset
	
	# Rotation animation
	if animated_sprite:
		animated_sprite.rotation += rotate_speed * delta
	
	# Check for collection input
	if player_in_range and Input.is_action_just_pressed(collection_key):
		collect_item()

func _on_player_entered(body: Node2D):
	if body.is_in_group("Player") and not collected:
		player_in_range = true
		if body.has_method("show_interaction_label"):
			body.show_interaction_label("Press F to collect")

func _on_player_exited(body: Node2D):
	if body.is_in_group("Player"):
		player_in_range = false
		if body.has_method("hide_interaction_label"):
			body.hide_interaction_label()

func collect_item():
	if collected:
		return
	
	collected = true
	
	# Get player reference
	var player = null
	if player_in_range:
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player = players[0]
		else:
			print("ERROR: No players found in group!")
			return
	else:
		print("ERROR: Player not in range!")
		return
	
	# Hide interaction label on player before scene change
	if player and player.has_method("hide_interaction_label"):
		player.hide_interaction_label()
	
	# Enable arrow skill if this collectible unlocks it
	if unlocks_arrow_skill and player and player.has_method("enable_arrows"):
		# Wait a brief moment for the enable_arrows notification to show
		player.enable_arrows()
	elif unlocks_arrow_skill:
		print("ERROR: Player doesn't have enable_arrows method!")
	
	# Enable achievement indicator in player
	if player and player.has_method("show_achievement_indicator"):
		player.show_achievement_indicator()
	
	# Disable collision to prevent multiple collections
	collision_shape.set_deferred("disabled", true)
	
	# Scene transition after notifications
	if next_scene_path != "" and next_scene_path != null:
		if TransitionManager:
			TransitionManager.fade_to_scene(next_scene_path, 1.0, 1.0)
		else:
			call_deferred("_change_scene")
	else:
		print("Warning: No next scene path set for collectible!")
		queue_free()

func _change_scene():
	"""Fallback method if TransitionManager isn't available"""
	var result = get_tree().change_scene_to_file(next_scene_path)
	if result != OK:
		print("Scene change failed with error code: ", result)
		_try_alternative_scene_change()

func _try_alternative_scene_change():
	if ResourceLoader.exists(next_scene_path):
		var packed_scene = load(next_scene_path)
		if packed_scene and packed_scene is PackedScene:
			get_tree().change_scene_to_packed(packed_scene)
		else:
			print("Failed to load scene as PackedScene")
	else:
		print("Scene resource does not exist at path: ", next_scene_path)

func collect_with_effect():
	"""Alternative collection method with visual effects"""
	if collected:
		return
	
	collected = true
	
	# Get player reference first
	var player = null
	if player_in_range:
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player = players[0]
	
	# Hide interaction label on player
	if player and player.has_method("hide_interaction_label"):
		player.hide_interaction_label()
	
	# Disable collision
	collision_shape.set_deferred("disabled", true)
	
	# Quick scale up effect (very short)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	
	# Wait for brief effect then enable skill
	await tween.finished
	
	# Enable arrow skill if this collectible unlocks it
	if unlocks_arrow_skill and player and player.has_method("enable_arrows"):
		player.enable_arrows()
	
	# Enable achievement indicator in player
	if player and player.has_method("show_achievement_indicator"):
		player.show_achievement_indicator()
	
	# Scene transition after notifications
	if next_scene_path != "" and next_scene_path != null:
		if TransitionManager:
			TransitionManager.fade_to_scene(next_scene_path, 1.0, 1.0)
		else:
			call_deferred("_change_scene")
	else:
		print("Warning: No next scene path set for collectible!")
		queue_free()

# Function to set whether this collectible unlocks arrow skill
func set_unlocks_arrow_skill(unlocks: bool):
	unlocks_arrow_skill = unlocks

# Backward compatibility function
func set_unlocks_l_skill(unlocks: bool):
	set_unlocks_arrow_skill(unlocks)

func set_next_scene(path: String):
	next_scene_path = path

func test_scene_loading():
	if FileAccess.file_exists(next_scene_path):
		if TransitionManager:
			TransitionManager.fade_to_scene(next_scene_path, 1.0, 1.0)
		else:
			_change_scene()
	else:
		print("Scene file not found!")
