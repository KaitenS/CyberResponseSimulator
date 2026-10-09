class_name Computer
extends Interactable

const CYBER_DESK_SCENE := preload("res://scenes/Game/Computer/CyberDesk.tscn")

var phishing_active: bool = false
var active_incident: IncidentData = null
var cyber_desk: Control = null

var malware_active: bool = false
var malware_incident: MalwareIncidentData = null
var malware_controller: MalwareIncidentController = null

var cursor_position := Vector2(320.0, 320.0)
var custom_cursor: TextureRect = null

const CYBER_DESK_SIZE := Vector2(640.0, 640.0)
const CURSOR_SIZE := Vector2(24.0, 24.0)
const CURSOR_SENSITIVITY := 1.0

@onready var cyber_desk_viewport: SubViewport = $Area3D/MonitorContainer/CyberDeskViewport
@onready var computer_screen: MeshInstance3D = $Area3D/MonitorContainer/ComputerScreen
@onready var computer_screen_black: MeshInstance3D = $Area3D/MonitorContainer/ComputerScreenBlack


func _ready() -> void:
	# El computador comienza con la pantalla apagada.
	computer_screen.visible = false
	computer_screen_black.visible = true


func activate_phishing(incident: IncidentData) -> void:
	phishing_active = true
	active_incident = incident

func activate_malware(data: MalwareIncidentData) -> void:
	malware_active = true
	malware_incident = data

	var machine := IncidentStateMachine.new()
	add_child(machine)

	malware_controller = MalwareIncidentController.new()
	add_child(malware_controller)
	malware_controller.setup(data, machine)

func has_active_incident() -> bool:
	return active_incident != null


func interact() -> void:
	if cyber_desk != null:
		return

	print("INTERACCIÓN: Computer")

	open_cyber_desk()


func open_cyber_desk() -> void:
	cyber_desk = CYBER_DESK_SCENE.instantiate()

	cyber_desk_viewport.add_child(cyber_desk)

	# Mostrar la pantalla del CyberDesk.
	computer_screen_black.visible = false
	computer_screen.visible = true

	var cyber_desk_root: Control = cyber_desk.get_node("CyberDesk")
	
	cyber_desk_root.set_malware_controller(malware_controller)

	cyber_desk_root.close_requested.connect(
		_on_cyber_desk_close_requested
	)

	var close_button: TextureButton = cyber_desk.get_node(
		"CyberDesk/TaskBar/HBoxContainer/CloseButton"
	)

	close_button.mouse_filter = Control.MOUSE_FILTER_STOP

	close_button.gui_input.connect(
		_on_close_button_gui_input
	)

	setup_computer_screen()
	setup_custom_cursor()

	var player = get_tree().current_scene.get_node_or_null("Player")

	if player:
		var camera_point: Marker3D = $CameraPoint
		player.enter_computer_view(camera_point)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func setup_computer_screen() -> void:
	var material := StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = cyber_desk_viewport.get_texture()

	material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	material.uv1_offset = Vector3(1.0, 0.0, 0.0)

	computer_screen.material_override = material


func setup_custom_cursor() -> void:
	if cyber_desk == null:
		return

	custom_cursor = cyber_desk.get_node_or_null(
		"CyberDesk/CustomCursor"
	)

	if custom_cursor == null:
		return

	cursor_position = CYBER_DESK_SIZE / 2.0

	custom_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_cursor.size = CURSOR_SIZE
	custom_cursor.z_index = 100
	custom_cursor.visible = true

	var half_cursor := CURSOR_SIZE / 2.0

	custom_cursor.position = cursor_position - half_cursor


func _input(event: InputEvent) -> void:
	if cyber_desk == null:
		return

	if event is InputEventMouseMotion:
		move_custom_cursor(event.relative)

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		var close_button: TextureButton = cyber_desk.get_node(
			"CyberDesk/TaskBar/HBoxContainer/CloseButton"
		)

		var close_rect := close_button.get_global_rect()
		var inside_button := close_rect.has_point(cursor_position)

		if inside_button and event.pressed:
			print("CLICK EN CLOSE BUTTON")
			print("RECT: ", close_rect)
			print("CURSOR: ", cursor_position)

			var cyber_desk_root: Control = cyber_desk.get_node(
				"CyberDesk"
			)

			print("LLAMANDO DIRECTAMENTE A _on_close_button_pressed()")

			cyber_desk_root._on_close_button_pressed()

		var virtual_click := InputEventMouseButton.new()

		virtual_click.button_index = MOUSE_BUTTON_LEFT
		virtual_click.pressed = event.pressed
		virtual_click.position = cursor_position

		print("ENVIANDO CLICK AL CYBERDESK: ", cursor_position)

		cyber_desk_viewport.push_input(
			virtual_click,
			true
		)


func move_custom_cursor(relative: Vector2) -> void:
	if custom_cursor == null:
		return

	cursor_position += relative * CURSOR_SENSITIVITY

	var half_cursor := CURSOR_SIZE / 2.0

	cursor_position.x = clamp(
		cursor_position.x,
		half_cursor.x,
		CYBER_DESK_SIZE.x - half_cursor.x
	)

	cursor_position.y = clamp(
		cursor_position.y,
		half_cursor.y,
		CYBER_DESK_SIZE.y - half_cursor.y
	)

	custom_cursor.position = cursor_position - half_cursor


func _on_close_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		print("CLOSE BUTTON GUI INPUT: ", event)


func _on_cyber_desk_close_requested() -> void:
	print("===== CERRANDO CYBERDESK =====")

	if cyber_desk == null:
		print("ERROR: CyberDesk ya no existe.")
		return

	var player = get_tree().current_scene.get_node_or_null("Player")

	if player:
		player.exit_computer_view()

	# Ocultar completamente la pantalla del CyberDesk.
	computer_screen.visible = false

	# Mostrar la pantalla negra.
	computer_screen_black.visible = true

	cyber_desk.queue_free()
	cyber_desk = null
	custom_cursor = null

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	print("CYBERDESK CERRADO")
	print("============================")
