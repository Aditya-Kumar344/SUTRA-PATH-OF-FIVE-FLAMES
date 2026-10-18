extends AnimatedSprite2D

# Float parameters
@export var float_amplitude: float = 20.0  # How high/low it floats
@export var float_speed: float = 2.0       # How fast it floats
@export var float_offset: float = 0.0      # Phase offset for multiple sprites

# Scene transition
@export var target_scene: String = "res://scenes/NextScene.tscn"  # Path to the scene to load
@export var button_node_path: NodePath = "UI/Button"  # Path to your button node

# Store the original position
var original_position: Vector2
var time_elapsed: float = 0.0
var button_ref: Button

func _ready():
	# Store the initial position as the base position
	original_position = global_position
	
	# Start playing the animation if you have one
	if sprite_frames and sprite_frames.get_animation_names().size() > 0:
		play()
	
	# Get reference to the button and connect the signal
	setup_button()

func setup_button():
	# Method 1: Get button by node path
	button_ref = get_node(button_node_path) as Button
	
	# Method 2: Alternative - find button by name anywhere in the scene
	# button_ref = get_tree().get_first_node_in_group("scene_button") as Button
	# button_ref = find_child("ButtonName", true, false) as Button
	
	if button_ref:
		# Connect the button's pressed signal to our function
		button_ref.pressed.connect(_on_button_pressed)
		print("Button connected successfully!")
	else:
		print("Button not found at path: ", button_node_path)

func _on_button_pressed():
	# This function is called when the button is pressed
	print("Button pressed! Changing scene to: ", target_scene)
	
	# Change to the target scene
	if target_scene != "":
		# Use call_deferred to avoid potential issues with scene changing
		call_deferred("_change_scene")
	else:
		print("No target scene specified!")

func _change_scene():
	# Change to the specified scene
	get_tree().change_scene_to_file(target_scene)

func _process(delta):
	# Update time
	time_elapsed += delta
	
	# Calculate the floating offset using a sine wave
	var float_y = sin(time_elapsed * float_speed + float_offset) * float_amplitude
	
	# Optional: Add slight horizontal bob for more natural floating
	var float_x = sin(time_elapsed * float_speed * 0.7 + float_offset) * (float_amplitude * 0.3)
	
	# Apply the floating motion
	global_position.y = original_position.y + float_y
	global_position.x = original_position.x + float_x
