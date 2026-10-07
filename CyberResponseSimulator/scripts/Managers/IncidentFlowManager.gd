extends Node


@export var first_incident_delay: float = 5.0

var computers: Array[Computer] = []
var phishing_incident: IncidentData = null

@onready var notification_panel: Panel = $"../GameHUD/IncidentNotification"
@onready var incident_label: Label = $"../GameHUD/IncidentNotification/IncidentLabel"


func _ready() -> void:
	notification_panel.visible = false

	# Buscamos todos los computadores de la escena.
	for node in get_tree().get_nodes_in_group("computers"):
		if node is Computer:
			computers.append(node)

	print("Computadores encontrados: ", computers.size())

	if GameManager.game_active:
		start_incident_test()


func start_incident_test() -> void:
	await get_tree().create_timer(first_incident_delay).timeout

	if not GameManager.game_active:
		return

	create_phishing_incident()


func create_phishing_incident() -> void:
	if computers.is_empty():
		print("ERROR: No hay computadores disponibles.")
		return

	# Crear los datos del incidente.
	var incident := IncidentData.new()

	incident.incident_id = "phishing_test"
	incident.incident_name = "Phishing"
	incident.difficulty = 1

	# Registrar el incidente en IncidentManager.
	if not IncidentManager.start_incident(incident):
		print("No se pudo iniciar el incidente.")
		return

	phishing_incident = incident

	# Elegir computador aleatoriamente.
	var computer: Computer = computers.pick_random()

	computer.activate_phishing(incident)

	print("================================")
	print("NUEVO INCIDENTE: PHISHING")
	print("COMPUTADOR AFECTADO: ", computer.name)
	print("================================")

	show_incident_notification(incident)


func show_incident_notification(incident: IncidentData) -> void:
	incident_label.text = "⚠ NUEVO INCIDENTE\n\n%s\n\nSe requiere atención." % incident.incident_name

	notification_panel.visible = true

	await get_tree().create_timer(4.0).timeout

	notification_panel.visible = false
