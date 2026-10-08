class_name Computer
extends Interactable

const CYBER_DESK_SCENE := preload("res://scenes/Game/Computer/CyberDesk.tscn")

var phishing_active: bool = false
var active_incident: IncidentData = null
var cyber_desk: Control = null

@onready var cyber_desk_viewport: SubViewport = $CyberDeskViewport
@onready var computer_screen: MeshInstance3D = $ComputerScreen


func activate_phishing(incident: IncidentData) -> void:
	phishing_active = true
	active_incident = incident

	print("PHISHING ACTIVADO EN: ", name)


func has_active_incident() -> bool:
	return active_incident != null


func interact() -> void:
	if cyber_desk != null:
		return

	print("INTERACCIÓN: ", name)

	open_cyber_desk()


func open_cyber_desk() -> void:
	cyber_desk = CYBER_DESK_SCENE.instantiate()

	cyber_desk_viewport.add_child(cyber_desk)

	setup_computer_screen()

	var player = get_tree().current_scene.get_node_or_null("Player")

	if player:
		var camera_point: Marker3D = $CameraPoint
		player.enter_computer_view(camera_point)

	print("CYBERDESK ABIERTO EN SUBVIEWPORT")


func setup_computer_screen() -> void:
	var material := StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = cyber_desk_viewport.get_texture()

	material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	material.uv1_offset = Vector3(1.0, 0.0, 0.0)

	computer_screen.material_override = material
