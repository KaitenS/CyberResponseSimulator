
class_name PishingIncidentController
extends Node

signal email_received(email: PhishingEmail)
signal email_resolved(email: PhishingEmail, accepted: bool)
signal incident_finished(completed: bool)
signal time_updated(time_remaining: float)

const INCIDENT_DURATION: float = 120.0
const MIN_EMAIL_INTERVAL: float = 10.0
const MAX_EMAIL_INTERVAL: float = 25.0
const MAX_EMAILS: int = 5

var phishing_data: PhishingData = null

var incident_active: bool = false
var time_remaining: float = 0.0

var selected_emails: Array[PhishingEmail] = []
var received_emails: Array[PhishingEmail] = []
var resolved_emails: Array[PhishingEmail] = []

var next_email_timer: float = 0.0
var decisions: Array[Dictionary] = []
var last_result: Dictionary = {}


func _ready() -> void:
	add_to_group("phishing_controllers")


func start_incident(data: PhishingData) -> void:
	if incident_active:
		return

	if data == null or data.emails.is_empty():
		push_error("Phishing: No hay correos disponibles.")
		return

	phishing_data = data

	selected_emails.clear()
	received_emails.clear()
	resolved_emails.clear()
	decisions.clear()
	last_result.clear()

	var available_emails: Array[PhishingEmail] = []

	for email in phishing_data.emails:
		if email != null:
			available_emails.append(email)

	if available_emails.is_empty():
		push_error("Phishing: Todos los correos son inválidos.")
		return

	available_emails.shuffle()

	var email_count: int = randi_range(
		1,
		mini(MAX_EMAILS, available_emails.size())
	)

	for i in range(email_count):
		selected_emails.append(available_emails[i])

	time_remaining = INCIDENT_DURATION
	incident_active = true

	print("=== PHISHING ACTIVADO ===")
	print("Correos seleccionados: ", selected_emails.size())

	_deliver_next_email()
	_schedule_next_email()


func _process(delta: float) -> void:
	if not incident_active:
		return

	time_remaining -= delta
	time_remaining = maxf(time_remaining, 0.0)

	time_updated.emit(time_remaining)

	if time_remaining <= 0.0:
		finish_incident(false)
		return

	if received_emails.size() >= selected_emails.size():
		return

	next_email_timer -= delta

	if next_email_timer <= 0.0:
		_deliver_next_email()
		_schedule_next_email()


func _deliver_next_email() -> void:
	if not incident_active:
		return

	if received_emails.size() >= selected_emails.size():
		return

	var email: PhishingEmail = selected_emails[
		received_emails.size()
	]

	received_emails.append(email)

	print("Nuevo correo recibido: ", email.subject)

	email_received.emit(email)


func _schedule_next_email() -> void:
	next_email_timer = randf_range(
		MIN_EMAIL_INTERVAL,
		MAX_EMAIL_INTERVAL
	)


func resolve_email(
	email: PhishingEmail,
	accepted: bool
) -> void:
	if not incident_active:
		return

	if email not in received_emails:
		return

	if email in resolved_emails:
		return

	resolved_emails.append(email)
	decisions.append({
		"email_id": email.email_id,
		"subject": email.subject,
		"sender": email.sender_address,
		"accepted": accepted,
		"is_phishing": email.is_phishing,
		"correct": accepted != email.is_phishing,
		"explanation": _explain(email),
	})

	email_resolved.emit(email, accepted)

	print(
		"Correo respondido: ",
		email.subject,
		" | Aceptado: ",
		accepted
	)

	if (
		resolved_emails.size() == selected_emails.size()
		and received_emails.size() == selected_emails.size()
	):
		finish_incident(true)


func finish_incident(completed: bool) -> void:
	if not incident_active:
		return

	incident_active = false
	next_email_timer = 0.0

	print("=== PHISHING FINALIZADO ===")
	print("Completado: ", completed)
	print("Correos respondidos: ", resolved_emails.size())
	print("Correos totales: ", selected_emails.size())

	last_result = get_result()
	last_result["success"] = completed and last_result["correct"] == selected_emails.size()
	incident_finished.emit(last_result["success"])


func get_received_emails() -> Array[PhishingEmail]:
	return received_emails.duplicate()


func is_email_resolved(email: PhishingEmail) -> bool:
	return email in resolved_emails


func _explain(email: PhishingEmail) -> String:
	if not email.explanation.is_empty():
		return email.explanation
	if email.is_phishing:
		return "Este correo está clasificado como fraudulento. Contrasta el remitente, la solicitud y los adjuntos con el resumen diario antes de aceptarlo."
	return "Este correo está clasificado como legítimo en el escenario. Contrasta siempre el remitente y la solicitud con el contexto del día."


# Devuelve una copia independiente; no cierra el incidente al consultar el resultado.
func get_result() -> Dictionary:
	var correct := 0
	for decision in decisions:
		if decision["correct"]:
			correct += 1
	var pending := received_emails.size() - decisions.size()
	var details: Array[Dictionary] = decisions.duplicate(true)
	for email in received_emails:
		if email not in resolved_emails:
			details.append({
				"email_id": email.email_id,
				"subject": email.subject,
				"sender": email.sender_address,
				"accepted": null,
				"is_phishing": email.is_phishing,
				"correct": false,
				"explanation": _explain(email),
			})
	var total := selected_emails.size()
	var points := roundi(100.0 * correct / total) if total > 0 else 0
	return {
		"incident_name": phishing_data.incident_name if phishing_data != null else "Phishing",
		"correct": correct,
		"incorrect": decisions.size() - correct,
		"pending": pending,
		"not_received": total - received_emails.size(),
		"total": total,
		"points": points,
		"success": not incident_active and total > 0 and correct == total,
		"status": "En curso al terminar el día" if incident_active else ("Tiempo agotado" if time_remaining <= 0.0 else "Finalizado"),
		"decisions": details,
	}