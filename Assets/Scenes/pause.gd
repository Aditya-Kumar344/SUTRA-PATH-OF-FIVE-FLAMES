extends Control

@onready var resume_button: Button = $MarginContainer/VBoxContainer/Button
@onready var main_menu_button: Button = $MarginContainer/VBoxContainer/Button2
@onready var quit_button: Button = $MarginContainer/VBoxContainer/Button3

var is_paused = false

func _ready() -> void:
	# Initially hide the pause menu
	visible = false
	
	# Connect button signals
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# Set process mode to always so it works when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Make sure it covers the entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(event: InputEvent) -> void:
	# Don't handle input here - let the player script handle it
	# This prevents double-handling of pause input
	pass

func toggle_pause() -> void:
	is_paused = !is_paused
	
	if is_paused:
		show_pause_menu()
	else:
		hide_pause_menu()

func show_pause_menu() -> void:
	visible = true
	get_tree().paused = true
	
	# Focus on resume button for keyboard navigation
	if resume_button:
		resume_button.grab_focus()
	
	print("Game paused")

func hide_pause_menu() -> void:
	visible = false
	get_tree().paused = false
	print("Game resumed")

func _on_resume_pressed() -> void:
	hide_pause_menu()
	print("Resume button pressed")

func _on_main_menu_pressed() -> void:
	print("Main menu button pressed")
	
	# Unpause before changing scene
	get_tree().paused = false
	
	# Clean up this pause menu instance
	queue_free()
	
	# Change to main menu scene
	if TransitionManager:
		TransitionManager.fade_to_scene("res://Assets/Scenes/main menu.tscn", 1.0, 1.0)
	else:
		get_tree().change_scene_to_file("res://Assets/Scenes/main menu.tscn")

func _on_quit_pressed() -> void:
	print("Quit button pressed")
	_on_quit_confirmed()

func _on_quit_confirmed() -> void:
	get_tree().paused = false
	get_tree().quit()

# Function to be called externally to show pause menu
func show_pause() -> void:
	show_pause_menu()

# Function to be called externally to hide pause menu
func hide_pause() -> void:
	hide_pause_menu()
