class_name PhishingData
extends Resource


@export var incident_id: String = ""
@export var incident_name: String = "Phishing"

@export var daily_summary: DailySummary

@export var emails: Array[PhishingEmail] = []
