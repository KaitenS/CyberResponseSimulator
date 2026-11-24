extends Node

const MAX_ACTIVE_INCIDENTS: int = 2

var active_incidents: Array[IncidentData] = []


func start_incident(incident: IncidentData) -> bool:
	if active_incidents.size() >= MAX_ACTIVE_INCIDENTS:
		return false

	active_incidents.append(incident)
	return true


func finish_incident(incident: IncidentData) -> bool:
	if incident not in active_incidents:
		return false

	active_incidents.erase(incident)
	return true
