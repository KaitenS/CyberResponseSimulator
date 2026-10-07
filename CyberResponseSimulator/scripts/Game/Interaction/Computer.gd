class_name Computer
extends Interactable


var phishing_active: bool = false
var active_incident: IncidentData = null


func activate_phishing(incident: IncidentData) -> void:
	phishing_active = true
	active_incident = incident

	print("PHISHING ACTIVADO EN: ", name)


func has_active_incident() -> bool:
	return active_incident != null


func interact() -> void:
	if phishing_active:
		print("PHISHING DETECTADO EN: ", name)

		# Por ahora solamente mostramos que este
		# computador tiene el incidente.
		print("INTERFAZ DE PHISHING ABIERTA")

		return

	print("INTERACCIÓN: ", name)
