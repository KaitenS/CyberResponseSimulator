extends Node3D
## Indicador visual: observa el equipo sin cambiar la lógica de sus incidentes.

func _process(_delta: float) -> void:
	var computer = get_parent()
	if not computer.has_method("activate_phishing"):
		return
	var phishing = computer.get("phishing_controller")
	var malware = computer.get("malware_controller")
	var has_phishing: bool = is_instance_valid(phishing) and phishing.incident_active
	var has_malware: bool = is_instance_valid(malware) and not malware.finished
	visible = GameManager.game_active and (has_phishing or has_malware)