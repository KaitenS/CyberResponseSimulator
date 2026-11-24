
extends Node


# ==========================================
# CONFIGURACIÓN
# ==========================================

@export var first_incident_delay: float = 5.0
## Intervalo entre nuevos sorteos durante una partida normal.
@export_range(1.0, 300.0, 1.0) var min_incident_delay: float = 35.0
@export_range(1.0, 300.0, 1.0) var max_incident_delay: float = 55.0
@export_range(1.0, 30.0, 1.0) var retry_delay: float = 5.0
@export var phishing_data: PhishingData
@export var malware_data: MalwareIncidentData

## Para pruebas: escribe aqui "ddos", "phishing" o "malware" en el Inspector
## y siempre saldra ese incidente. Dejalo VACIO para el sorteo normal.
## (El boton "Practicar DDoS" del menu tambien lo fuerza.)
@export var forzar_incidente: String = ""


# ==========================================
# INCIDENTES DISPONIBLES
# ==========================================

var available_incidents: Array[IncidentData] = []


# ==========================================
# ESTADO
# ==========================================

var computers: Array[Computer] = []
var active_incident: IncidentData = null
var _last_incident_id: String = ""
var _practice_only: bool = false

@onready var _schedule_timer: Timer = $ScheduleTimer


# ==========================================
# UI
# ==========================================

@onready var notification_panel: Panel = $"../GameHUD/IncidentNotification"


# ==========================================
# READY
# ==========================================

func _ready() -> void:

	notification_panel.visible = false
	GameManager.game_ended.connect(_on_game_ended)

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

	if phishing_data != null:
		available_incidents.append(phishing_data)
	else:
		push_error("Falta asignar los datos del incidente de Phishing.")


	# ------------------------------------------
	# MALWARE
	# ------------------------------------------

	if malware_data != null:
		available_incidents.append(malware_data)
	else:
		print("ERROR: Falta asignar los datos del incidente de Malware.")


	# ------------------------------------------
	# DDOS
	# ------------------------------------------

	var ddos := IncidentData.new()

	ddos.incident_id = "ddos"
	ddos.incident_name = "DDoS"
	ddos.difficulty = 3

	available_incidents.append(ddos)

	# Incidente forzado (Inspector o boton "Practicar DDoS"): se consume una vez.
	var forzado := forzar_incidente
	if DDoSEnMapa.forzar_siguiente != "":
		forzado = DDoSEnMapa.forzar_siguiente
		DDoSEnMapa.forzar_siguiente = ""
	if forzado == "phishing" and phishing_data != null:
		forzado = phishing_data.incident_id
	DDoSEnMapa.modo_practica = (forzado == "ddos")
	_practice_only = DDoSEnMapa.modo_practica

	if forzado != "":
		var filtrados: Array[IncidentData] = []
		for inc in available_incidents:
			if inc.incident_id == forzado:
				filtrados.append(inc)
		if filtrados.is_empty():
			print("AVISO: no existe el incidente forzado '%s'." % forzado)
		else:
			available_incidents = filtrados


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
	_schedule_timer.start(maxf(0.01, first_incident_delay))


func manages_incident_schedule() -> bool:
	return not _practice_only


func _on_schedule_timeout() -> void:
	if not GameManager.game_active:
		return
	var created := create_incident()
	# La práctica tiene un único ataque y conserva su reinicio propio.
	if _practice_only:
		return
	if created:
		_schedule_timer.start(randf_range(
			maxf(0.01, minf(min_incident_delay, max_incident_delay)),
			maxf(0.01, maxf(min_incident_delay, max_incident_delay))
		))
	else:
		_schedule_timer.start(maxf(0.01, retry_delay))


func _on_game_ended() -> void:
	_schedule_timer.stop()


func _refresh_computers() -> void:
	computers.clear()
	for node in get_tree().get_nodes_in_group("computers"):
		if node is Computer:
			computers.append(node)


func _free_computers() -> Array[Computer]:
	var free: Array[Computer] = []
	for computer in computers:
		if is_instance_valid(computer) and computer.is_available_for_incident():
			free.append(computer)
	return free


func create_incident() -> bool:
	if not GameManager.game_active or IncidentManager.active_incidents.size() >= IncidentManager.MAX_ACTIVE_INCIDENTS:
		return false
	_refresh_computers()
	if computers.is_empty():
		return false
	var free := _free_computers()
	var choices: Array[IncidentData] = []
	for incident in available_incidents:
		var already_active := false
		for running in IncidentManager.active_incidents:
			if running == incident or running.incident_id == incident.incident_id:
				already_active = true
		if already_active:
			continue
		if incident.incident_id == "ddos":
			if not IncidenteDDoS.activo:
				choices.append(incident)
		elif (incident is PhishingData or incident is MalwareIncidentData) and not free.is_empty():
			choices.append(incident)
	if choices.is_empty():
		return false
	# Favorecer variedad cuando hay más de un tipo elegible.
	if choices.size() > 1:
		choices = choices.filter(func(item: IncidentData): return item.incident_id != _last_incident_id)
	var incident: IncidentData = choices.pick_random()
	var computer: Computer = computers.pick_random() if incident.incident_id == "ddos" else free.pick_random()
	if not IncidentManager.start_incident(incident):
		return false
	active_incident = incident
	_last_incident_id = incident.incident_id
	if incident is PhishingData:
		computer.activate_phishing(incident)
	elif incident is MalwareIncidentData:
		computer.activate_malware(incident)
	else:
		DDoSEnMapa.iniciar_en_escena(get_parent(), incident)
	show_incident_notification(incident)
	print("NUEVO INCIDENTE: ", incident.incident_name, " | Equipo: ", computer.name)
	return true


func show_incident_notification(_incident: IncidentData) -> void:
	# La alerta orienta sin revelar el diagnóstico ni alterar el incidente.
	notification_panel.call("show_alert")


# Consecuencia solicitada por Phishing; reutiliza los puntos de entrada existentes.
func start_phishing_consequence(computer: Computer) -> void:
	if not GameManager.game_active or not is_instance_valid(computer):
		return
	_refresh_computers()
	var choices: Array[String] = []
	if malware_data != null and computer.is_available_for_incident():
		var malware_running := false
		for other in computers:
			if is_instance_valid(other) and is_instance_valid(other.malware_controller) and not other.malware_controller.finished:
				malware_running = true
		if not malware_running:
			choices.append("malware")
	if not IncidenteDDoS.activo:
		choices.append("ddos")
	if choices.is_empty():
		return
	var kind: String = choices.pick_random()
	var incident: IncidentData = malware_data if kind == "malware" else IncidentData.new()
	if kind == "ddos":
		incident.incident_id = "ddos"
		incident.incident_name = "DDoS"
		incident.difficulty = 3
	if not IncidentManager.start_incident(incident):
		return
	if kind == "malware":
		computer.activate_malware(malware_data)
		if is_instance_valid(computer.cyber_desk):
			computer.cyber_desk.get_node("CyberDesk").set_malware_controller(computer.malware_controller)
	else:
		DDoSEnMapa.iniciar_en_escena(get_parent(), incident)
	show_incident_notification(incident)
