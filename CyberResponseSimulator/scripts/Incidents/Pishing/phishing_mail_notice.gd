extends Control

var controller: PishingIncidentController = null


func set_controller(value: PishingIncidentController) -> void:
	if is_instance_valid(controller):
		controller.email_received.disconnect(_received)
		controller.email_state_changed.disconnect(_changed)
		controller.incident_started.disconnect(_started)
	controller = value
	if is_instance_valid(controller):
		controller.email_received.connect(_received)
		controller.email_state_changed.connect(_changed)
		controller.incident_started.connect(_started)
	_refresh()


func _received(_email: PhishingEmail) -> void:
	_refresh()


func _changed(_email: PhishingEmail) -> void:
	_refresh()


func _started(_data: PhishingData) -> void:
	_refresh()


func _refresh() -> void:
	var count := controller.get_unread_count() if is_instance_valid(controller) else 0
	$UnreadBadge.visible = count > 0
	$UnreadBadge.text = str(count)
	tooltip_text = "%d correos sin leer" % count