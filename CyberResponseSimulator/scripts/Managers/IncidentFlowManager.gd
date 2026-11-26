
extends Node


# ==========================================
# CONFIGURACIÓN
# ==========================================

@export var first_incident_delay: float = 5.0
## Intervalo entre sorteos mientras quede espacio para otro incidente.
@export_range(1.0, 300.0, 1.0) var idle_incident_delay: float = 20.0
## Reintento cuando todavía no hay un computador disponible.
@export_range(1.0, 30.0, 1.0) var retry_delay: float = 5.0

## Opción de compatibilidad: garantía de DDoS desactivada por defecto.
## El flujo normal ahora sortea los tres tipos mientras haya una plaza disponible.
@export var ddos_garantizado_en: float = 0.0
## Ya no se lanza un DDoS garantizado si quedan menos segundos que estos.
@export var ddos_tiempo_minimo: float = 100.0
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
var _hubo_ddos: bool = false
var _was_at_capacity: bool = false
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

	setup_incidents()
	GameManager.game_ended.connect(_on_game_ended)

	for node in get_tree().get_nodes_in_group("computers"):

		if node is Computer:
			computers.append(node)

	print(
		"Computadores encontrados: ",
		computers.size()
	)

	if GameManager.game_active:
		start_incident_test()
		_programar_ddos_garantizado()


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
	# El computador no debe abrir otro Phishing por su temporizador local.
	return not _practice_only


func _refresh_computers() -> void:
	computers.clear()
	for node in get_tree().get_nodes_in_group("computers"):
		if node is Computer:
			computers.append(node)


func _at_incident_capacity() -> bool:
	# Incluye incidentes activos que se hayan iniciado fuera del sorteo normal.
	var running := 1 if IncidenteDDoS.activo else 0
	for computer in computers:
		if not is_instance_valid(computer):
			continue
		if computer.phishing_active:
			running += 1
		if computer.malware_active:
			running += 1
	return maxi(running, IncidentManager.active_incidents.size()) >= IncidentManager.MAX_ACTIVE_INCIDENTS


func _process(_delta: float) -> void:
	if not GameManager.game_active:
		_schedule_timer.stop()
		return
	if _practice_only:
		return
	_refresh_computers()
	var at_capacity := _at_incident_capacity()
	if at_capacity:
		_schedule_timer.stop()
		_was_at_capacity = true
		return
	if _was_at_capacity or _schedule_timer.is_stopped():
		if IncidentManager.active_incidents.is_empty():
			active_incident = null
		_schedule_timer.start(idle_incident_delay)
	_was_at_capacity = false


func _on_schedule_timeout() -> void:
	if not GameManager.game_active or _at_incident_capacity():
		return
	if not create_incident() and not _practice_only:
		_schedule_timer.start(retry_delay)


func _on_game_ended() -> void:
	_schedule_timer.stop()


func create_incident() -> bool:
	if not GameManager.game_active or _at_incident_capacity():
		return false
	_refresh_computers()
	var free: Array[Computer] = []
	for computer in computers:
		if computer.is_available_for_incident():
			free.append(computer)
	var choices: Array[IncidentData] = []
	for incident in available_incidents:
		if incident == null or incident in IncidentManager.active_incidents:
			continue
		if incident.incident_id == "ddos":
			if not computers.is_empty() and not IncidenteDDoS.activo:
				choices.append(incident)
		elif (incident is PhishingData or incident is MalwareIncidentData) and not free.is_empty():
			choices.append(incident)
	if choices.is_empty():
		return false
	var incident: IncidentData = choices.pick_random()
	var computer: Computer = computers.pick_random() if incident.incident_id == "ddos" else free.pick_random()
	if not IncidentManager.start_incident(incident):
		return false
	active_incident = incident
	if incident is PhishingData:
		computer.activate_phishing(incident)
	elif incident is MalwareIncidentData:
		computer.activate_malware(incident)
	else:
		_hubo_ddos = true
		DDoSEnMapa.iniciar_en_escena(get_parent(), incident)
	_was_at_capacity = _at_incident_capacity()
	if _practice_only or _was_at_capacity:
		_schedule_timer.stop()
	else:
		_schedule_timer.start(idle_incident_delay)
	show_incident_notification(incident)
	print("NUEVO INCIDENTE: ", incident.incident_name, " | Equipo: ", computer.name)
	return true


# ==========================================
# NOTIFICACIÓN
# ==========================================

func show_incident_notification(_incident: IncidentData) -> void:
	# La alerta orienta sin revelar el diagnóstico ni alterar el incidente.
	notification_panel.call("show_alert")


# Consecuencia solicitada por Phishing; reutiliza los puntos de entrada existentes.
func start_phishing_consequence(computer: Computer) -> void:
	if not GameManager.game_active or not is_instance_valid(computer):
		return
	var choices: Array[String] = []
	if malware_data != null and not (is_instance_valid(computer.malware_controller) and not computer.malware_controller.finished):
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
		_hubo_ddos = true
		DDoSEnMapa.iniciar_en_escena(get_parent(), incident)
	show_incident_notification(incident)


# ==========================================
# DDOS GARANTIZADO
# ==========================================

func _programar_ddos_garantizado() -> void:
	if ddos_garantizado_en <= 0.0 or DDoSEnMapa.modo_practica:
		return
	# Si el sorteo esta forzado a otro incidente (pruebas), se respeta.
	if forzar_incidente != "" and forzar_incidente != "ddos":
		return

	await get_tree().create_timer(ddos_garantizado_en, false).timeout

	# Espera su turno: nunca entra encima de otro incidente en curso.
	while GameManager.game_active and not _hubo_ddos:
		if GameManager.time_remaining < ddos_tiempo_minimo:
			return
		if IncidentManager.active_incidents.is_empty() and not IncidenteDDoS.activo:
			_lanzar_ddos_garantizado()
			return
		await get_tree().create_timer(3.0, false).timeout


func _lanzar_ddos_garantizado() -> void:
	var incident := IncidentData.new()
	incident.incident_id = "ddos"
	incident.incident_name = "DDoS"
	incident.difficulty = 3
	if not IncidentManager.start_incident(incident):
		return
	_hubo_ddos = true
	DDoSEnMapa.iniciar_en_escena(get_parent(), incident)
	show_incident_notification(incident)
