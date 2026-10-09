class_name IncidentData
extends Resource


# ==========================================
# DATOS DEL INCIDENTE
# ==========================================

@export var incident_id: String = ""
@export var incident_name: String = ""
@export var difficulty: int = 1


# ==========================================
# CONSTRUCTORES DE INCIDENTES
# ==========================================
#
# Cada función crea un IncidentData ya configurado.
#
# Esto permite que IncidentFlowManager no tenga
# que conocer los datos internos de cada incidente.
# ==========================================


static func create_phishing() -> IncidentData:
	var incident := IncidentData.new()

	incident.incident_id = "phishing"
	incident.incident_name = "Phishing"
	incident.difficulty = 1

	return incident


static func create_malware() -> IncidentData:
	var incident := IncidentData.new()

	incident.incident_id = "malware"
	incident.incident_name = "Malware"
	incident.difficulty = 2

	return incident


static func create_ddos() -> IncidentData:
	var incident := IncidentData.new()

	incident.incident_id = "ddos"
	incident.incident_name = "DDoS"
	incident.difficulty = 3

	return incident
