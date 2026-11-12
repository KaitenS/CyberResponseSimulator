extends Control

@onready var menu_sfx: AudioStreamPlayer = $MenuSFX

@export var hover_sound: AudioStream
@export var click_sound: AudioStream

var initializing_menu := true


func _ready():
	$OptionsPanel.visible = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	$OptionsPanel/OptionsContainer/FullScreenRow/FullScreenCheck.button_pressed = fullscreen

	# El menú ya terminó de inicializarse
	initializing_menu = false

	# Conectar sonidos de hover
	var play_button = get_node_or_null("CenterContainer/Menu/PlayButton")
	var exit_button = get_node_or_null("CenterContainer/Menu/ExitButton")

	if play_button:
		play_button.mouse_entered.connect(_on_button_mouse_entered)

	if exit_button:
		exit_button.mouse_entered.connect(_on_button_mouse_entered)

	_agregar_boton_practica(play_button)


func _on_button_mouse_entered():
	print(">>> HOVER DETECTADO <<<")
	play_hover_sound()


func _on_options_button_mouse_entered() -> void:
	print(">>> OPTIONS HOVER <<<")
	play_hover_sound()


func play_hover_sound():
	if hover_sound:
		menu_sfx.stream = hover_sound
		menu_sfx.play()


func play_click_sound():
	if click_sound:
		menu_sfx.stream = click_sound
		menu_sfx.play()


func _on_options_button_pressed():
	play_click_sound()

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
	play_click_sound()

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


func _on_play_button_pressed():
	play_click_sound()

	GameManager.start_game()
	get_tree().change_scene_to_file("res://scenes/Game/Game.tscn")


func _on_exit_button_pressed():
	play_click_sound()
	get_tree().quit()


func _on_volume_slider_value_changed(value):
	var volume_db = linear_to_db(value / 100.0)

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		volume_db
	)


func _on_full_screen_check_toggled(toggled_on: bool) -> void:
	# No reproducir sonido durante la inicialización
	if not initializing_menu:
		play_click_sound()

	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ==========================================
# PRACTICA DDOS (boton creado por codigo)
# ==========================================

func _agregar_boton_practica(play_button: Button) -> void:
	if play_button == null:
		return

	# Copia del boton "Iniciar simulacion" (mismo estilo), sin sus conexiones.
	var practica: Button = play_button.duplicate()
	practica.name = "PracticeDDoSButton"
	practica.text = "◈ PRACTICAR DDoS"
	play_button.get_parent().add_child(practica)
	play_button.get_parent().move_child(practica, play_button.get_index() + 1)

	for c in practica.pressed.get_connections():
		practica.pressed.disconnect(c["callable"])

	practica.pressed.connect(_on_practice_ddos_pressed)
	practica.mouse_entered.connect(_on_button_mouse_entered)

	# Boton de dificultad (cicla Facil / Normal / Dificil y lo recuerda)
	var dificultad: Button = practica.duplicate()
	dificultad.name = "DifficultyDDoSButton"
	dificultad.text = "◈ DIFICULTAD DDoS: %s" % DDoSEnMapa.nombre_dificultad().to_upper()
	play_button.get_parent().add_child(dificultad)
	play_button.get_parent().move_child(dificultad, practica.get_index() + 1)
	for c in dificultad.pressed.get_connections():
		dificultad.pressed.disconnect(c["callable"])
	dificultad.pressed.connect(func():
		dificultad.text = "◈ DIFICULTAD DDoS: %s" % DDoSEnMapa.ciclar_dificultad().to_upper()
	)
	dificultad.mouse_entered.connect(_on_button_mouse_entered)


func _on_practice_ddos_pressed() -> void:
	DDoSEnMapa.forzar_siguiente = "ddos"
	_on_play_button_pressed()
