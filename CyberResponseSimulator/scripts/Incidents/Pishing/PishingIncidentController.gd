
class_name PishingIncidentController
extends Node

signal incident_started(data: PhishingData)
signal summary_read_changed
signal email_state_changed(email: PhishingEmail)
signal email_received(email: PhishingEmail)
signal email_resolved(email: PhishingEmail, accepted: bool)
signal incident_finished(completed: bool)
signal time_updated(time_remaining: float)

const INCIDENT_DURATION: float = 150.0
const MIN_EMAIL_INTERVAL: float = 10.0
const MAX_EMAIL_INTERVAL: float = 25.0
const MAX_EMAILS: int = 5

var phishing_data: PhishingData = null
var summary_read: bool = false

var incident_active: bool = false
var time_remaining: float = 0.0

var selected_emails: Array[PhishingEmail] = []
var received_emails: Array[PhishingEmail] = []
var resolved_emails: Array[PhishingEmail] = []

var next_email_timer: float = 0.0
var decisions: Array[Dictionary] = []
var read_emails: Array[PhishingEmail] = []
var last_result: Dictionary = {}
var compromised: bool = false
var update_remaining: float = 0.0
var update_total: float = 0.0
var updating_email: PhishingEmail = null
var opened_content: Array[String] = []
var action_is_update: bool = false
var action_description: String = ""


func _ready() -> void:
	add_to_group("phishing_controllers")


func start_incident(data: PhishingData) -> void:
	if incident_active:
		return

	if data == null or data.emails.is_empty():
		push_error("Phishing: No hay correos disponibles.")
		return

	var choices: Array[PhishingData] = [data]
	for variant in data.variants:
		if variant != null and not variant.emails.is_empty():
			choices.append(variant)
	phishing_data = choices.pick_random()

	summary_read = false
	selected_emails.clear()
	received_emails.clear()
	resolved_emails.clear()
	decisions.clear()
	read_emails.clear()
	last_result.clear()
	compromised = false
	update_remaining = 0.0
	update_total = 0.0
	updating_email = null
	opened_content.clear()
	action_is_update = false
	action_description = ""

	var available_emails: Array[PhishingEmail] = []

	for email in phishing_data.emails:
		if email != null and email not in available_emails:
			available_emails.append(email)

	if available_emails.is_empty():
		push_error("Phishing: Todos los correos son inválidos.")
		return

	available_emails.shuffle()

	var email_count: int = randi_range(
		1,
		mini(MAX_EMAILS, available_emails.size())
	)

	# Reservar un correo de cada tipo cuando la tanda permita una mezcla.
	# El orden de llegada vuelve a sortearse para no revelar la clasificación.
	var legitimate: Array[PhishingEmail] = []
	var fraudulent: Array[PhishingEmail] = []
	for email in available_emails:
		if email.is_phishing:
			fraudulent.append(email)
		else:
			legitimate.append(email)
	if email_count >= 2 and not legitimate.is_empty() and not fraudulent.is_empty():
		selected_emails.append(legitimate[0])
		selected_emails.append(fraudulent[0])
	for email in available_emails:
		if selected_emails.size() >= email_count:
			break
		if email not in selected_emails:
			selected_emails.append(email)
	selected_emails.shuffle()

	time_remaining = INCIDENT_DURATION
	incident_active = true

	print("=== PHISHING ACTIVADO ===")
	print("Correos seleccionados: ", selected_emails.size())

	incident_started.emit(phishing_data)
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

	if update_remaining > 0.0:
		update_remaining = maxf(0.0, update_remaining - delta)
		if update_remaining == 0.0:
			var email := updating_email
			updating_email = null
			resolve_email(email, true)
			if not incident_active:
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
	if not incident_active or update_remaining > 0.0:
		return

	if email not in received_emails:
		return

	if email in resolved_emails:
		return

	mark_email_read(email)
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

	email_state_changed.emit(email)
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
	update_remaining = 0.0
	updating_email = null

	print("=== PHISHING FINALIZADO ===")
	print("Completado: ", completed)
	print("Correos respondidos: ", resolved_emails.size())
	print("Correos totales: ", selected_emails.size())

	last_result = get_result()
	last_result["success"] = completed and not compromised and last_result["correct"] == selected_emails.size()
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
		"points": 0 if compromised else points,
		"compromised": compromised,
		"success": not compromised and not incident_active and total > 0 and correct == total,
		"status": "Equipo comprometido al abrir contenido fraudulento" if compromised else "En curso al terminar el día" if incident_active else ("Tiempo agotado" if time_remaining <= 0.0 else "Finalizado"),
		"decisions": details,
	}

func mark_email_read(email: PhishingEmail) -> void:
	if email in received_emails and email not in read_emails:
		read_emails.append(email)
		email_state_changed.emit(email)


func get_email_state(email: PhishingEmail) -> String:
	var index := resolved_emails.find(email)
	if index >= 0:
		return "Aceptado" if decisions[index]["accepted"] else "Rechazado"
	return "Leído" if email in read_emails else "Sin leer"


func get_unread_count() -> int:
	var count := 0
	for email in received_emails:
		if email not in read_emails:
			count += 1
	return count

func mark_summary_read() -> void:
	if phishing_data == null or phishing_data.daily_summary == null or summary_read:
		return
	summary_read = true
	summary_read_changed.emit()


func accept_email(email: PhishingEmail) -> void:
	if not incident_active or update_remaining > 0.0 or email not in received_emails or email in resolved_emails:
		return
	var kinds: Array[String] = []
	if email.has_attachment:
		kinds.append("attachment")
	if not email.link_url.is_empty() or _body_has_link(email.body):
		kinds.append("link")
	if kinds.is_empty():
		resolve_email(email, true)
	else:
		_open_payload(email, kinds)


func _body_has_link(body: String) -> bool:
	return "https://" in body.to_lower() or "http://" in body.to_lower()


func open_content(email: PhishingEmail, kind: String) -> void:
	var kinds: Array[String] = [kind]
	_open_payload(email, kinds)


func _open_payload(email: PhishingEmail, kinds: Array[String]) -> void:
	if not incident_active or update_remaining > 0.0 or email not in received_emails or email in resolved_emails:
		return
	var pending: Array[String] = []
	var names := PackedStringArray()
	for kind in kinds:
		if kind not in ["link", "attachment"]:
			continue
		if kind == "attachment" and not email.has_attachment:
			continue
		if kind == "link" and email.link_url.is_empty() and not _body_has_link(email.body):
			continue
		var key := email.email_id + ":" + kind
		if key not in opened_content:
			pending.append(kind)
			opened_content.append(key)
			names.append(email.attachment_name if kind == "attachment" else (email.link_text if not email.link_text.is_empty() else "Enlace del correo"))
	if pending.is_empty():
		return
	mark_email_read(email)
	if email.is_phishing:
		compromised = true
		resolved_emails.append(email)
		decisions.append({
			"email_id": email.email_id, "subject": email.subject,
			"sender": email.sender_address, "accepted": true,
			"is_phishing": true, "correct": false,
			"explanation": "Se abrió contenido fraudulento: " + ", ".join(names) + ". " + _explain(email),
			"action": "+".join(pending),
		})
		finish_incident(false)
	else:
		# La extensión define la presentación; la clasificación del escenario
		# determina si es seguro. Un .exe también puede ser legítimo.
		action_is_update = email.simulates_update or ("attachment" in pending and email.attachment_name.to_lower().ends_with(".exe"))
		action_description = "\n".join(names)
		update_total = maxf(1.0, email.update_duration) if action_is_update else 2.0 * pending.size()
		update_remaining = update_total
		updating_email = email
