extends Control

@onready var summary: Label = $Summary
@onready var review_button: Button = $ReviewButton
@onready var detail_panel: Panel = $DetailPanel
@onready var details: RichTextLabel = $DetailPanel/Details


func _ready() -> void:
	review_button.pressed.connect(_open_review)
	$DetailPanel/BackButton.pressed.connect(detail_panel.hide)


func _open_review() -> void:
	detail_panel.show()


func build(reports: Array[Dictionary]) -> void:
	detail_panel.hide()
	visible = not reports.is_empty()
	var correct := 0
	var incorrect := 0
	var pending := 0
	var not_received := 0
	var sections := PackedStringArray()
	for report in reports:
		correct += int(report["correct"])
		incorrect += int(report["incorrect"])
		pending += int(report["pending"])
		not_received += int(report["not_received"])
		sections.append("%s — %s\nAciertos: %d | Errores: %d | Sin responder: %d | No recibidos: %d" % [
			report["incident_name"], report["status"], report["correct"], report["incorrect"], report["pending"], report["not_received"],
		])
		for decision in report["decisions"]:
			var action := "Sin responder"
			var outcome := "PENDIENTE"
			if decision["accepted"] != null:
				action = "Aceptaste" if decision["accepted"] else "Rechazaste"
				outcome = "ACIERTO" if decision["correct"] else "ERROR"
			var expected := "Rechazar" if decision["is_phishing"] else "Aceptar"
			var classification := "Fraudulento" if decision["is_phishing"] else "Legítimo"
			sections.append("%s · %s\nDe: %s\nTu decisión: %s | Clasificación: %s\nDecisión correcta: %s\n%s" % [
				outcome, decision["subject"], decision["sender"], action, classification, expected, decision["explanation"],
			])
		if int(report["not_received"]) > 0:
			sections.append("Los correos no recibidos no se cuentan como decisiones erróneas y no se revelan en esta revisión.")
	summary.text = "Phishing: %d aciertos · %d errores · %d sin responder" % [correct, incorrect, pending]
	if not_received > 0:
		summary.text += "\nCorreos que aún no habían llegado: %d" % not_received
	details.text = "\n\n".join(sections)