extends Button

# Scene transition settings
@export var target_scene_path: String = "res://scenes/MainMenu.tscn"  # Scene to transition to
@export var fade_out_duration: float = 1.0  # Time for fade out
@export var fade_in_duration: float = 1.0   # Time for fade in
@export var fade_color: Color = Color.BLACK  # Color to fade to
@export var enable_button_feedback: bool = true  # Visual feedback when clicked
@export var disable_during_transition: bool = true  # Disable button during transition

# Button feedback settings
@export var press_scale: Vector2 = Vector2(0.95, 0.95)  # Scale when pressed
@export var press_duration: float = 0.1  # Duration of press animation
@export var hover_scale: Vector2 = Vector2(1.05, 1.05)  # Scale when hovered

# Internal variables
var original_scale: Vector2
var is_hovered: bool = false
var feedback_tween: Tween

func _ready():
	# Store original scale
	original_scale = scale
	
	# Connect button signals
	pressed.connect(_on_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Validate scene path
	if target_scene_path == "":
		print("Warning: No target scene path set for transition button!")
	elif not FileAccess.file_exists(target_scene_path):
		print("Warning: Target scene path does not exist: ", target_scene_path)
	
	print("Scene transition button initialized")
	print("Target scene: ", target_scene_path)
	print("Fade out duration: ", fade_out_duration)
	print("Fade in duration: ", fade_in_duration)

func _on_button_pressed():
	"""Handle button press and scene transition"""
	print("Scene transition button pressed!")
	
	# Check if TransitionManager exists
	if not TransitionManager:
		print("Error: TransitionManager not found! Make sure it's added as AutoLoad.")
		return
	
	# Check if already transitioning
	if TransitionManager.is_fade_active():
		print("Transition already in progress, ignoring button press")
		return
	
	# Validate scene path
	if target_scene_path == "" or target_scene_path == null:
		print("Error: No target scene path set!")
		return
	
	if not FileAccess.file_exists(target_scene_path):
		print("Error: Target scene file does not exist: ", target_scene_path)
		return
	
	# Button feedback animation
	if enable_button_feedback:
		play_press_animation()
	
	# Disable button during transition
	if disable_during_transition:
		disabled = true
	
	# Set fade color
	TransitionManager.set_fade_color(fade_color)
	
	# Start scene transition
	print("Starting scene transition to: ", target_scene_path)
	await TransitionManager.fade_to_scene(target_scene_path, fade_out_duration, fade_in_duration)
	
	# Re-enable button (though we'll be in a new scene)
	if disable_during_transition:
		disabled = false

func _on_mouse_entered():
	"""Handle mouse hover enter"""
	is_hovered = true
	if enable_button_feedback:
		play_hover_animation()

func _on_mouse_exited():
	"""Handle mouse hover exit"""
	is_hovered = false
	if enable_button_feedback:
		play_unhover_animation()

func play_press_animation():
	"""Play button press feedback animation"""
	if feedback_tween:
		feedback_tween.kill()
	
	feedback_tween = create_tween()
	feedback_tween.set_ease(Tween.EASE_OUT)
	feedback_tween.set_trans(Tween.TRANS_BACK)
	
	# Scale down then back up
	feedback_tween.tween_property(self, "scale", original_scale * press_scale, press_duration * 0.5)
	feedback_tween.tween_property(self, "scale", original_scale, press_duration * 0.5)

func play_hover_animation():
	"""Play button hover animation"""
	if feedback_tween:
		feedback_tween.kill()
	
	feedback_tween = create_tween()
	feedback_tween.set_ease(Tween.EASE_OUT)
	feedback_tween.set_trans(Tween.TRANS_SINE)
	
	# Scale up for hover effect
	feedback_tween.tween_property(self, "scale", original_scale * hover_scale, 0.2)

func play_unhover_animation():
	"""Play button unhover animation"""
	if feedback_tween:
		feedback_tween.kill()
	
	feedback_tween = create_tween()
	feedback_tween.set_ease(Tween.EASE_OUT)
	feedback_tween.set_trans(Tween.TRANS_SINE)
	
	# Scale back to original
	feedback_tween.tween_property(self, "scale", original_scale, 0.2)

# Utility functions for dynamic scene setting
func set_target_scene(scene_path: String):
	"""Set the target scene path dynamically"""
	target_scene_path = scene_path
	print("Target scene changed to: ", target_scene_path)

func set_fade_durations(fade_out: float, fade_in: float):
	"""Set fade durations dynamically"""
	fade_out_duration = fade_out
	fade_in_duration = fade_in
	print("Fade durations changed - Out: ", fade_out, ", In: ", fade_in)

func set_fade_color_dynamic(color: Color):
	"""Set fade color dynamically"""
	fade_color = color
	print("Fade color changed to: ", color)

func transition_to_scene_immediate(scene_path: String):
	"""Transition to a specific scene immediately (ignores export settings)"""
	if not TransitionManager:
		print("Error: TransitionManager not found!")
		return
	
	if TransitionManager.is_fade_active():
		print("Transition already in progress")
		return
	
	if not FileAccess.file_exists(scene_path):
		print("Error: Scene file does not exist: ", scene_path)
		return
	
	print("Immediate transition to: ", scene_path)
	TransitionManager.set_fade_color(fade_color)
	await TransitionManager.fade_to_scene(scene_path, fade_out_duration, fade_in_duration)

# Preset transition functions
func transition_to_main_menu():
	"""Quick transition to main menu"""
	await transition_to_scene_immediate("res://scenes/MainMenu.tscn")

func transition_to_game():
	"""Quick transition to game scene"""
	await transition_to_scene_immediate("res://scenes/Game.tscn")

func transition_to_settings():
	"""Quick transition to settings"""
	await transition_to_scene_immediate("res://scenes/Settings.tscn")

func restart_current_scene():
	"""Restart the current scene with fade"""
	if not TransitionManager:
		print("Error: TransitionManager not found!")
		return
	
	if TransitionManager.is_fade_active():
		print("Transition already in progress")
		return
	
	print("Restarting current scene")
	TransitionManager.set_fade_color(fade_color)
	await TransitionManager.restart_current_scene(fade_out_duration, fade_in_duration)

# Alternative method using signals (if you prefer signal-based approach)
signal scene_transition_requested(scene_path: String, fade_out_time: float, fade_in_time: float)

func _on_button_pressed_signal_version():
	"""Alternative version that emits a signal instead of handling directly"""
	print("Scene transition button pressed - emitting signal")
	
	if enable_button_feedback:
		play_press_animation()
	
	# Emit signal for other scripts to handle
	scene_transition_requested.emit(target_scene_path, fade_out_duration, fade_in_duration)

# Example of connecting to external scene manager (if you have one)
func connect_to_scene_manager(scene_manager: Node):
	"""Connect this button to an external scene manager"""
	if scene_manager.has_signal("scene_transition_requested"):
		scene_transition_requested.connect(scene_manager._on_scene_transition_requested)
		print("Connected to external scene manager")
	else:
		print("Scene manager doesn't have expected signal")

# Debug function
func test_transition():
	"""Test the transition without actually changing scenes"""
	print("Testing transition...")
	
	if not TransitionManager:
		print("TransitionManager not found!")
		return
	
	# Test fade out and in without scene change
	TransitionManager.set_fade_color(fade_color)
	await TransitionManager.fade_out(fade_out_duration)
	await get_tree().create_timer(0.5).timeout  # Brief pause
	await TransitionManager.fade_in(fade_in_duration)
	
	print("Transition test completed")

# Function to validate all settings
func validate_settings() -> bool:
	"""Validate all transition settings"""
	var is_valid = true
	
	if target_scene_path == "":
		print("Error: No target scene path set")
		is_valid = false
	elif not FileAccess.file_exists(target_scene_path):
		print("Error: Target scene doesn't exist: ", target_scene_path)
		is_valid = false
	
	if fade_out_duration < 0:
		print("Error: Fade out duration cannot be negative")
		is_valid = false
	
	if fade_in_duration < 0:
		print("Error: Fade in duration cannot be negative")
		is_valid = false
	
	if not TransitionManager:
		print("Error: TransitionManager not found in AutoLoad")
		is_valid = false
	
	return is_valid

# Override the disabled property to handle visual feedback
func _set_disabled(value: bool):
	disabled = value
	if disabled:
		modulate = Color(0.6, 0.6, 0.6, 0.8)  # Dimmed when disabled
	else:
		modulate = Color.WHITE  # Normal when enabled
