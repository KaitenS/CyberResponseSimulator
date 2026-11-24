class_name Phishing
extends Node


@export var phishing_data: PhishingData


func start_incident():
	print("=== PHISHING INICIADO ===")

	if phishing_data == null:
		print("ERROR: No hay PhishingData asignado.")
		return

	print("Incidente: ", phishing_data.incident_name)

	if phishing_data.daily_summary != null:
		print("Resumen: ", phishing_data.daily_summary.title)

	print("Cantidad de correos: ", phishing_data.emails.size())

	for email in phishing_data.emails:
		print(
			"Correo: ",
			email.subject,
			" | De: ",
			email.sender_address,
			" | Phishing: ",
			email.is_phishing
		)
