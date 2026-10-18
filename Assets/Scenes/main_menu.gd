extends CanvasLayer

# Export variables for easy scene configuration
@export var first_level_scene: String = "res://Assets/Scenes/level1.tscn"  # Set your first level path
@export var fade_out_duration: float = 1.0
@export var fade_in_duration: float = 1.0

# Button references
@onready var start_button: Button = $Button  # Adjust path to match your scene
@onready var quit_button: Button =  $Button2  # Adjust path to match your scene

var is_transitioning = false

func _ready():
	print("Main Menu initialized")
	
	# Connect button signals
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
		start_button.grab_focus()  # Start button focused by default
		print("Start button connected")
	else:
		print("Warning: Start button not found!")
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		print("Quit button connected")
	else:
		print("Warning: Quit button not found!")
	
	# Setup button effects and borders
	setup_button_effects()
	setup_button_borders()

func setup_button_borders():
	"""Add white borders to both buttons"""
	# Setup Start Button Border
	if start_button:
		# Normal state
		var start_normal_style = StyleBoxFlat.new()
		start_normal_style.border_width_left = 2
		start_normal_style.border_width_right = 2
		start_normal_style.border_width_top = 2
		start_normal_style.border_width_bottom = 2
		start_normal_style.border_color = Color.WHITE
		start_normal_style.corner_radius_top_left = 5
		start_normal_style.corner_radius_top_right = 5
		start_normal_style.corner_radius_bottom_left = 5
		start_normal_style.corner_radius_bottom_right = 5
		start_normal_style.bg_color = Color(0, 0, 0, 0.7)  # Dark semi-transparent background
		
		# Hover/Focus state (slightly thicker border)
		var start_hover_style = StyleBoxFlat.new()
		start_hover_style.border_width_left = 3
		start_hover_style.border_width_right = 3
		start_hover_style.border_width_top = 3
		start_hover_style.border_width_bottom = 3
		start_hover_style.border_color = Color.WHITE
		start_hover_style.corner_radius_top_left = 5
		start_hover_style.corner_radius_top_right = 5
		start_hover_style.corner_radius_bottom_left = 5
		start_hover_style.corner_radius_bottom_right = 5
		start_hover_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Lighter dark background on hover
		
		# Apply styles to start button
		start_button.add_theme_stylebox_override("normal", start_normal_style)
		start_button.add_theme_stylebox_override("hover", start_hover_style)
		start_button.add_theme_stylebox_override("focus", start_hover_style)
		start_button.add_theme_stylebox_override("pressed", start_hover_style)
	
	# Setup Quit Button Border
	if quit_button:
		# Normal state
		var quit_normal_style = StyleBoxFlat.new()
		quit_normal_style.border_width_left = 2
		quit_normal_style.border_width_right = 2
		quit_normal_style.border_width_top = 2
		quit_normal_style.border_width_bottom = 2
		quit_normal_style.border_color = Color.WHITE
		quit_normal_style.corner_radius_top_left = 5
		quit_normal_style.corner_radius_top_right = 5
		quit_normal_style.corner_radius_bottom_left = 5
		quit_normal_style.corner_radius_bottom_right = 5
		quit_normal_style.bg_color = Color(0, 0, 0, 0.7)  # Dark semi-transparent background
		
		# Hover/Focus state (slightly thicker border)
		var quit_hover_style = StyleBoxFlat.new()
		quit_hover_style.border_width_left = 3
		quit_hover_style.border_width_right = 3
		quit_hover_style.border_width_top = 3
		quit_hover_style.border_width_bottom = 3
		quit_hover_style.border_color = Color.WHITE
		quit_hover_style.corner_radius_top_left = 5
		quit_hover_style.corner_radius_top_right = 5
		quit_hover_style.corner_radius_bottom_left = 5
		quit_hover_style.corner_radius_bottom_right = 5
		quit_hover_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Lighter dark background on hover
		
		# Apply styles to quit button
		quit_button.add_theme_stylebox_override("normal", quit_normal_style)
		quit_button.add_theme_stylebox_override("hover", quit_hover_style)
		quit_button.add_theme_stylebox_override("focus", quit_hover_style)
		quit_button.add_theme_stylebox_override("pressed", quit_hover_style)
	
	print("White borders applied to both buttons")

func setup_button_effects():
	"""Add hover effects and sounds to buttons"""
	if start_button:
		start_button.mouse_entered.connect(_on_start_button_hovered)
		start_button.focus_entered.connect(_on_start_button_focused)
	
	if quit_button:
		quit_button.mouse_entered.connect(_on_quit_button_hovered)
		quit_button.focus_entered.connect(_on_quit_button_focused)

func _on_start_pressed():
	"""Handle start button press with fade transition"""
	if is_transitioning:
		print("Already transitioning, ignoring start button")
		return
	
	print("Start button pressed - beginning transition")
	is_transitioning = true
	
	# Disable buttons during transition
	disable_buttons()
	
	# Optional: Play button sound
	# AudioManager.play_sound("button_click")
	
	# Check if the scene path exists
	if first_level_scene.is_empty():
		print("Error: No first level scene path set!")
		enable_buttons()
		is_transitioning = false
		return
	
	if not FileAccess.file_exists(first_level_scene):
		print("Error: First level scene not found at: ", first_level_scene)
		enable_buttons()
		is_transitioning = false
		return
	
	# Use TransitionManager to fade to the first level
	if TransitionManager:
		print("Using TransitionManager to load first level: ", first_level_scene)
		TransitionManager.fade_to_scene(first_level_scene, fade_out_duration, fade_in_duration)
	else:
		print("Error: TransitionManager not found!")
		# Fallback: direct scene change
		get_tree().change_scene_to_file(first_level_scene)

func _on_quit_pressed():
	"""Handle quit button press"""
	if is_transitioning:
		print("Already transitioning, ignoring quit button")
		return
	
	print("Quit button pressed")
	is_transitioning = true
	
	# Disable buttons during transition
	disable_buttons()
	
	# Optional: Play button sound
	# AudioManager.play_sound("button_click")
	
	# Optional: Fade out before quitting
	if TransitionManager:
		print("Fading out before quit")
		await TransitionManager.fade_out(fade_out_duration)
	
	# Quit the game
	print("Quitting game...")
	get_tree().quit()

func disable_buttons():
	"""Disable all buttons during transitions"""
	if start_button:
		start_button.disabled = true
	if quit_button:
		quit_button.disabled = true

func enable_buttons():
	"""Re-enable all buttons"""
	if start_button:
		start_button.disabled = false
	if quit_button:
		quit_button.disabled = false

# Optional hover/focus effects
func _on_start_button_hovered():
	print("Start button hovered")
	# Optional: Play hover sound
	# AudioManager.play_sound("button_hover")

func _on_start_button_focused():
	print("Start button focused")
	# Optional: Visual feedback for controller users

func _on_quit_button_hovered():
	print("Quit button hovered")
	# Optional: Play hover sound
	# AudioManager.play_sound("button_hover")

func _on_quit_button_focused():
	print("Quit button focused")
	# Optional: Visual feedback for controller users

# Handle keyboard input for menu navigation
func _input(event):
	if is_transitioning:
		return
	
	# Enter key to start game
	if event.is_action_pressed("ui_accept"):
		if start_button and start_button.has_focus():
			_on_start_pressed()
		elif quit_button and quit_button.has_focus():
			_on_quit_pressed()
	
	# Escape key to quit
	elif event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()

# Optional: Add a settings button or credits
func add_settings_button():
	"""Example of how to add more buttons"""
	pass

func add_credits_button():
	"""Example of how to add more buttons"""
	pass

# Debug function to test scene loading
func test_scene_loading():
	print("Testing scene loading...")
	print("First level scene: ", first_level_scene)
	print("Scene exists: ", FileAccess.file_exists(first_level_scene))
	print("TransitionManager available: ", TransitionManager != null)

# Optional: Create buttons programmatically if needed
func create_menu_buttons():
	"""Create buttons programmatically if not in scene"""
	# Create VBoxContainer for button layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(vbox)
	
	# Create Start button
	start_button = Button.new()
	start_button.text = "Start Game"
	start_button.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(start_button)
	
	# Create Quit button
	quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(200, 50)
	vbox.add_child(quit_button)
	
	# Connect signals
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Setup borders for programmatically created buttons
	setup_button_borders()
	
	# Focus start button
	start_button.grab_focus()

# Optional: Handle scene transitions from other sources
func go_to_scene(scene_path: String):
	"""Generic function to go to any scene with fade"""
	if is_transitioning:
		return
	
	is_transitioning = true
	disable_buttons()
	
	if TransitionManager:
		TransitionManager.fade_to_scene(scene_path, fade_out_duration, fade_in_duration)
	else:
		get_tree().change_scene_to_file(scene_path)

# Optional: Return to menu function (for other scenes to use)
func return_to_menu():
	"""Function that other scenes can call to return to main menu"""
	if TransitionManager:
		TransitionManager.fade_to_scene(get_scene_file_path(), fade_out_duration, fade_in_duration)
	else:
		get_tree().change_scene_to_file(get_scene_file_path())
