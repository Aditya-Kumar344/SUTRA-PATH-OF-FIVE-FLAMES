# TransitionManager.gd
# This should be added as an AutoLoad in Project Settings > AutoLoad

extends Node

var fade_rect: ColorRect
var tween: Tween
var is_transitioning = false

func _ready():
	print("TransitionManager initialized")
	setup_fade_overlay()
	
	# Start with fade in on scene load
	call_deferred("fade_in", 1.0)

func setup_fade_overlay():
	"""Create the fade overlay that covers the screen"""
	# Create a CanvasLayer to ensure it's always on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top
	add_child(canvas_layer)
	
	# Create the fade rectangle
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover the entire screen
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Add to the canvas layer
	canvas_layer.add_child(fade_rect)
	
	# Start invisible
	fade_rect.color.a = 0.0

func fade_out(duration: float = 1.0):
	"""Fade to black"""
	if is_transitioning:
		print("Already transitioning, skipping fade_out")
		return
		
	print("Starting fade out with duration: ", duration)
	is_transitioning = true
	
	# Kill existing tween
	if tween:
		tween.kill()
	
	# Create new tween
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Animate from current alpha to 1.0 (fully black)
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	
	await tween.finished
	is_transitioning = false
	print("Fade out completed")

func fade_in(duration: float = 1.0):
	"""Fade from black to transparent"""
	if is_transitioning:
		print("Already transitioning, skipping fade_in")
		return
		
	print("Starting fade in with duration: ", duration)
	is_transitioning = true
	
	# Kill existing tween
	if tween:
		tween.kill()
	
	# Create new tween
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Animate from current alpha to 0.0 (fully transparent)
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	
	await tween.finished
	is_transitioning = false
	print("Fade in completed")

func fade_to_scene(scene_path: String, fade_out_duration: float = 1.0, fade_in_duration: float = 1.0):
	"""Complete transition: fade out, change scene, fade in"""
	if is_transitioning:
		print("Already transitioning, skipping scene change")
		return
	
	print("Transitioning to scene: ", scene_path)
	
	# Fade out
	await fade_out(fade_out_duration)
	
	# Change scene
	var result = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		print("Error changing scene: ", result)
		is_transitioning = false
		return
	
	# Wait for scene to load
	await get_tree().process_frame
	
	# Fade in
	await fade_in(fade_in_duration)

func restart_current_scene(fade_out_duration: float = 1.0, fade_in_duration: float = 1.0):
	"""Restart current scene with fade transition"""
	if is_transitioning:
		print("Already transitioning, skipping restart")
		return
	
	print("Restarting current scene")
	
	# Fade out
	await fade_out(fade_out_duration)
	
	# Restart scene
	var result = get_tree().reload_current_scene()
	if result != OK:
		print("Error restarting scene: ", result)
		is_transitioning = false
		return
	
	# Wait for scene to load
	await get_tree().process_frame
	
	# Fade in
	await fade_in(fade_in_duration)

# Utility functions
func set_fade_color(color: Color):
	if fade_rect:
		fade_rect.color = color
		fade_rect.color.a = fade_rect.color.a  # Preserve alpha

func is_fade_active() -> bool:
	return is_transitioning
