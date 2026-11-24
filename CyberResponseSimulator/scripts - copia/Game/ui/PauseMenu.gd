# PauseMenu.gd
# Menú de pausa: se abre con ESC mientras la partida está activa.
extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/Menu/MainMenu.tscn"

@onready var continue_button: Button = $Center/Panel/Buttons/ContinueButton
@onready var menu_button: Button = $Center/Panel/Buttons/MenuButton


func _ready() -> void:
	visible = false
	continue_button.pressed.connect(close_pause)
	menu_button.pressed.connect(_on_menu_pressed)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return

	if visible:
		close_pause()
	elif GameManager.game_active and not get_tree().paused:
		open_pause()


func open_pause() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_pause() -> void:
	visible = false
	get_tree().paused = false
	# Capturado sirve tanto caminando como dentro del computador,
	# donde el cursor virtual necesita el mouse capturado.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_menu_pressed() -> void:
	# Salir sin pasar por end_game(), porque eso abriría "Resultados del día".
	GameManager.game_active = false
	IncidentManager.active_incidents.clear()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
