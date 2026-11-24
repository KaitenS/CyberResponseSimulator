# incident_state_machine.gd
# Maneja el flujo de las 6 etapas de un incidente en curso.
# No sabe nada de UI ni de modelos 3D: solo lleva el estado y avisa
# cuando cambia, vía señales.
class_name IncidentStateMachine
extends Node

enum State {
	ALERT_RECEIVED,      # Recepción de la alerta
	INVESTIGATING,       # Investigación
	COLLECTING_EVIDENCE, # Recolección de evidencias
	ANALYZING,           # Análisis
	DECIDING,            # Toma de decisiones
	EVALUATING           # Evaluación
}

signal state_changed(new_state: State)
signal incident_completed(success: bool)

var current_state: State = State.ALERT_RECEIVED
var incident_data: Resource
var collected_evidence: Array[String] = []

func start(data: IncidentData) -> void:
	incident_data = data
	collected_evidence.clear()
	_set_state(State.ALERT_RECEIVED)

func advance_to_investigation() -> void:
	if current_state == State.ALERT_RECEIVED:
		_set_state(State.INVESTIGATING)

func collect_evidence(evidence_id: String) -> void:
	if current_state != State.INVESTIGATING and current_state != State.COLLECTING_EVIDENCE:
		return

	if evidence_id not in collected_evidence:
		collected_evidence.append(evidence_id)

	_set_state(State.COLLECTING_EVIDENCE)

	# Si ya se recolectó toda la evidencia requerida, avanza automáticamente
	if _has_all_required_evidence():
		_set_state(State.ANALYZING)

func make_decision(decision_id: String) -> void:
	if current_state != State.ANALYZING and current_state != State.DECIDING:
		return

	_set_state(State.DECIDING)
	_set_state(State.EVALUATING)

func _has_all_required_evidence() -> bool:
	for id in incident_data.required_evidence_ids:
		if id not in collected_evidence:
			return false
	return true

func _set_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)
	print("Incidente '", incident_data.title, "' -> ", State.keys()[new_state])
