
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

	incident_finished.emit(completed)


func get_received_emails() -> Array[PhishingEmail]:
	return received_emails.duplicate()


func is_email_resolved(email: PhishingEmail) -> bool:
	return email in resolved_emails
