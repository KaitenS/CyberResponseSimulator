extends Control

func _ready():
	$OptionsPanel.visible = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	$OptionsPanel/OptionsContainer/FullScreenRow/FullScreenCheck.button_pressed = fullscreen

func _on_options_button_pressed():
	var panel = $OptionsPanel
	
	panel.visible = true
	panel.modulate.a = 0.0
	
	var original_position = panel.position
	
	var tween = create_tween()
	
	# Aparición
	tween.tween_property(panel, "modulate:a", 1.0, 0.05)
	
	# Glitches horizontales
	tween.tween_property(panel, "position:x", original_position.x + 12, 0.04)
	tween.tween_property(panel, "position:x", original_position.x - 8, 0.04)
	tween.tween_property(panel, "position:x", original_position.x + 5, 0.03)
	tween.tween_property(panel, "position:x", original_position.x, 0.06)


func _on_back_button_pressed():
	var panel = $OptionsPanel
	
	var original_position = panel.position
	
	var tween = create_tween()
	
	# Glitches antes de desaparecer
	tween.tween_property(panel, "position:x", original_position.x - 10, 0.04)
	tween.tween_property(panel, "position:x", original_position.x + 7, 0.04)
	tween.tween_property(panel, "position:x", original_position.x - 4, 0.03)
	tween.tween_property(panel, "modulate:a", 0.0, 0.08)
	
	tween.tween_callback(func():
		panel.visible = false
		panel.position = original_position
	)


func _on_exit_button_pressed():
	get_tree().quit()


func _on_volume_slider_value_changed(value):
	var volume_db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		volume_db
	)

func _on_full_screen_check_toggled(toggled_on: bool) -> void:
	print("CHECKBOX: ", toggled_on)

	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	print("MODO ACTUAL: ", DisplayServer.window_get_mode())
