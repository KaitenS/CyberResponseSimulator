extends Node


# ==========================================
# CONFIGURACIÓN
# ==========================================

@export var first_incident_delay: float = 5.0


# ==========================================
# INCIDENTES DISPONIBLES
# ==========================================
#
# Por ahora los creamos aquí como datos.
#
# Más adelante esto puede reemplazarse por
# recursos .tres sin tener que cambiar el flujo.
# ==========================================

var available_incidents: Array[IncidentData] = []


# ==========================================
# ESTADO
# ==========================================

var computers: Array[Computer] = []
var active_incident: IncidentData = null


# ==========================================
# UI
# ==========================================

@onready var notification_panel: Panel = $"../GameHUD/IncidentNotification"

@onready var incident_label: Label = $"../GameHUD/IncidentNotification/IncidentLabel"


# ==========================================
# READY
# ==========================================

func _ready() -> void:

	notification_panel.visible = false

	setup_incidents()

	for node in get_tree().get_nodes_in_group("computers"):

		if node is Computer:
			computers.append(node)

	print(
		"Computadores encontrados: ",
		computers.size()
	)

	if GameManager.game_active:
		start_incident_test()


# ==========================================
# CONFIGURAR INCIDENTES
# ==========================================

func setup_incidents() -> void:

	available_incidents.clear()


	# ------------------------------------------
	# PHISHING
	# ------------------------------------------

	var phishing := IncidentData.new()

	phishing.incident_id = "phishing"
	phishing.incident_name = "Phishing"
	phishing.difficulty = 1

	available_incidents.append(phishing)


	# ------------------------------------------
	# MALWARE
	# ------------------------------------------

	var malware := IncidentData.new()

	malware.incident_id = "malware"
	malware.incident_name = "Malware"
	malware.difficulty = 2

	available_incidents.append(malware)


	# ------------------------------------------
	# DDOS
	# ------------------------------------------

	var ddos := IncidentData.new()

	ddos.incident_id = "ddos"
	ddos.incident_name = "DDoS"
	ddos.difficulty = 3

	available_incidents.append(ddos)


	print(
		"Incidentes disponibles: ",
		available_incidents.size()
	)


	for incident in available_incidents:

		print(
			"- ",
			incident.incident_name,
			" | Dificultad: ",
			incident.difficulty
		)


# ==========================================
# PRIMER INCIDENTE
# ==========================================

func start_incident_test() -> void:

	await get_tree().create_timer(
		first_incident_delay
	).timeout

	if not GameManager.game_active:
		return

	create_incident()


# ==========================================
# CREAR INCIDENTE
# ==========================================

func create_incident() -> void:

	if computers.is_empty():

		print(
			"ERROR: No hay computadores disponibles."
		)

		return


	if available_incidents.is_empty():

		print(
			"ERROR: No hay incidentes disponibles."
		)

		return


	# ==========================================
	# SELECCIONAR INCIDENTE
	# ==========================================

	var incident: IncidentData = (
		available_incidents.pick_random()
	)


	# ==========================================
	# REGISTRAR INCIDENTE
	# ==========================================

	if not IncidentManager.start_incident(incident):

		print(
			"No se pudo iniciar el incidente."
		)

		return


	active_incident = incident


	# ==========================================
	# SELECCIONAR COMPUTADOR
	# ==========================================

	var computer: Computer = computers.pick_random()


	# ==========================================
	# ACTIVAR INCIDENTE
	# ==========================================

	match incident.incident_id:

		"phishing":
			computer.activate_phishing(incident)

		"malware":
			print(
				"TODO: Activar Malware"
			)

		"ddos":
			print(
				"TODO: Activar DDoS"
			)


	# ==========================================
	# DEBUG
	# ==========================================

	print("================================")
	print(
		"NUEVO INCIDENTE: ",
		incident.incident_name
	)

	print(
		"ID: ",
		incident.incident_id
	)

	print(
		"DIFICULTAD: ",
		incident.difficulty
	)

	print(
		"COMPUTADOR AFECTADO: ",
		computer.name
	)

	print("================================")


	show_incident_notification(incident)


# ==========================================
# NOTIFICACIÓN
# ==========================================

func show_incident_notification(
	incident: IncidentData
) -> void:

	incident_label.text = (
		"⚠ NUEVO INCIDENTE\n\n%s\n\nSe requiere atención."
		% incident.incident_name
	)

	notification_panel.visible = true

	await get_tree().create_timer(
		4.0
	).timeout

	notification_panel.visible = false
