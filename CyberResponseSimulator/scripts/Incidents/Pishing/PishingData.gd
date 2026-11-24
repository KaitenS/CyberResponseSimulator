class_name PhishingData
extends IncidentData

@export var daily_summary: DailySummary

@export var emails: Array[PhishingEmail] = []

# Variantes compatibles; el controlador elige una al iniciar.
@export var variants: Array[PhishingData] = []
