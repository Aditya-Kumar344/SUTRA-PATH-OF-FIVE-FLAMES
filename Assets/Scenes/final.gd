extends AnimatedSprite2D

# Export variables for easy configuration
@export_group("Float Animation")
@export var float_amplitude: float = 20.0  # How high/low it floats
@export var float_speed: float = 2.0       # How fast it floats
@export var float_offset: float = 0.0      # Phase offset for multiple sprites

@export_group("Scene Transition")
@export var target_scene: String = "res://Assets/Scenes/level1.tscn"  # Path to the scene to load
@export var fade_out_duration: float = 1.0
@export var fade_in_duration: float = 1.0

@export_group("Button Configuration")
@export var button_node_path: NodePath = "UI/Button"  # Path to your button node

@export_group("Visual Effects")
@export var hover_scale_factor: float = 1.1   # Scale when hovered
@export var press_scale_factor: float = 0.95  # Scale when pressed
@export var scale_transition_speed: float = 10.0  # How fast scale changes happen

# Internal variables
var original_position: Vector2
var original_scale: Vector2
var time_elapsed: float = 0.0
var button_ref: Button
var is_transitioning: bool = false
var target_scale: Vector2

func _ready():
	print("Floating menu button initialized")
	
	# Store the initial position and scale as the base
	original_position = global_position
	original_scale = scale
	target_scale = original_scale
	
	# Start playing the animation if available
	if sprite_frames and sprite_frames.get_animation_names().size() > 0:
		play()
		print("Animation started")
	
	# Setup button connection
	setup_button()

func setup_button():
	"""Find and connect the button"""
	# Get button by node path
	button_ref = get_node_or_null(button_node_path) as Button
	
	if button_ref:
		print("Button found at: ", button_node_path)
		connect_button_signals()
		setup_button_styling()
	else:
		print("Warning: Button not found at path: ", button_node_path)

func connect_button_signals():
	"""Connect button signals for interaction"""
	if not button_ref:
		return
	
	# Connect signals
	button_ref.pressed.connect(_on_button_pressed)
	button_ref.mouse_entered.connect(_on_button_mouse_entered)
	button_ref.mouse_exited.connect(_on_button_mouse_exited)
	button_ref.button_down.connect(_on_button_down)
	button_ref.button_up.connect(_on_button_up)
	
	print("Button signals connected!")

func setup_button_styling():
	"""Apply white border styling to match your main menu"""
	if not button_ref:
		return
	
	# Create normal state style
	var normal_style = StyleBoxFlat.new()
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color.WHITE
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.corner_radius_bottom_right = 5
	normal_style.bg_color = Color(0, 0, 0, 0.7)
	
	# Create hover state style
	var hover_style = StyleBoxFlat.new()
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color.WHITE
	hover_style.corner_radius_top_left = 5
	hover_style.corner_radius_top_right = 5
	hover_style.corner_radius_bottom_left = 5
	hover_style.corner_radius_bottom_right = 5
	hover_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	
	# Apply styles
	button_ref.add_theme_stylebox_override("normal", normal_style)
	button_ref.add_theme_stylebox_override("hover", hover_style)
	button_ref.add_theme_stylebox_override("focus", hover_style)
	button_ref.add_theme_stylebox_override("pressed", hover_style)
	
	print("Button styling applied")

func _process(delta):
	# Don't float during transitions
	if is_transitioning:
		return
	
	# Update time
	time_elapsed += delta
	
	# Calculate the floating offset using a sine wave
	var float_y = sin(time_elapsed * float_speed + float_offset) * float_amplitude
	
	# Optional: Add slight horizontal bob for more natural floating
	var float_x = sin(time_elapsed * float_speed * 0.7 + float_offset) * (float_amplitude * 0.3)
	
	# Apply the floating motion
	global_position.y = original_position.y + float_y
	global_position.x = original_position.x + float_x
	
	# Handle scale transitions for hover/press effects
	if scale != target_scale:
		scale = scale.lerp(target_scale, scale_transition_speed * delta)

# Button event handlers
func _on_button_pressed():
	"""Handle button press - transition to target scene"""
	if is_transitioning:
		print("Already transitioning, ignoring button press")
		return
	
	print("Menu button pressed! Transitioning to: ", target_scene)
	
	# Validate target scene
	if target_scene.is_empty():
		print("Error: No target scene specified!")
		return
	
	if not FileAccess.file_exists(target_scene):
		print("Error: Target scene not found at: ", target_scene)
		return
	
	# Start transition
	is_transitioning = true
	
	# Disable button during transition
	if button_ref:
		button_ref.disabled = true
	
	# Use TransitionManager if available (matching your main menu style)
	if TransitionManager:
		print("Using TransitionManager to load scene: ", target_scene)
		TransitionManager.fade_to_scene(target_scene, fade_out_duration, fade_in_duration)
	else:
		print("TransitionManager not found, using direct scene change")
		call_deferred("_change_scene")

func _change_scene():
	"""Change to the specified scene"""
	get_tree().change_scene_to_file(target_scene)

func _on_button_mouse_entered():
	"""Handle mouse hover start"""
	target_scale = original_scale * hover_scale_factor
	print("Button hovered")

func _on_button_mouse_exited():
	"""Handle mouse hover end"""
	target_scale = original_scale
	print("Button hover ended")

func _on_button_down():
	"""Handle button press down"""
	target_scale = original_scale * press_scale_factor
	print("Button pressed down")

func _on_button_up():
	"""Handle button press release"""
	target_scale = original_scale * hover_scale_factor  # Return to hover state if still hovering
	print("Button released")

# Handle keyboard input
func _input(event):
	if is_transitioning:
		return
	
	# Allow Enter/Space to trigger button if it has focus
	if event.is_action_pressed("ui_accept"):
		if button_ref and button_ref.has_focus():
			_on_button_pressed()

# Utility functions
func reset_position():
	"""Reset to original position"""
	global_position = original_position
	scale = original_scale
	target_scale = original_scale
	time_elapsed = 0.0

func set_target_scene(new_scene: String):
	"""Change the target scene at runtime"""
	target_scene = new_scene
	print("Target scene changed to: ", target_scene)
